package handler

import (
	"database/sql"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"lumen-backend/internal/middleware"
	"lumen-backend/internal/thumb"
)

type PhotoHandler struct {
	DB        *sql.DB
	DataDir   string
	ThumbQ    *thumb.Queue
}

var safeNameRe = regexp.MustCompile(`[^a-zA-Z0-9_\-\.]`)

func sanitizeFilename(name string) string {
	return safeNameRe.ReplaceAllString(name, "_")
}

func (h *PhotoHandler) Upload(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	if err := r.ParseMultipartForm(100 << 20); err != nil {
		respondError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		respondError(w, http.StatusBadRequest, "file required")
		return
	}
	defer file.Close()

	// Read first 512 bytes for content sniffing
	buf := make([]byte, 512)
	n, _ := file.Read(buf)
	buf = buf[:n]
	file.Seek(0, 0)

	mimeType := http.DetectContentType(buf)
	if !strings.HasPrefix(mimeType, "image/") {
		respondError(w, http.StatusBadRequest, "only image files are accepted")
		return
	}

	// Parse taken_at
	var takenAt time.Time
	if t := r.FormValue("taken_at"); t != "" {
		parsed, err := time.Parse(time.RFC3339, t)
		if err != nil {
			parsed, err = time.Parse("2006-01-02T15:04:05", t)
		}
		if err == nil {
			takenAt = parsed
		}
	}
	if takenAt.IsZero() {
		takenAt = time.Now()
	}

	// Build storage path: /data/photos/YYYY/YYYY-MM/YYYY-MM-DD_HHMMSS_name.ext
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = "." + strings.TrimPrefix(mimeType, "image/")
	}
	safeName := sanitizeFilename(strings.TrimSuffix(header.Filename, filepath.Ext(header.Filename)))
	filename := takenAt.Format("2006-01-02_150405") + "_" + safeName + ext

	yearDir := takenAt.Format("2006")
	monthDir := takenAt.Format("2006-01")
	storageDir := filepath.Join(h.DataDir, "photos", yearDir, monthDir)
	os.MkdirAll(storageDir, 0755)
	storagePath := filepath.Join(storageDir, filename)

	dst, err := os.Create(storagePath)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to create file")
		return
	}
	written, _ := io.Copy(dst, file)
	dst.Close()

	// Get device_id
	var deviceID *int64
	if did := r.FormValue("device_id"); did != "" {
		v, err := strconv.ParseInt(did, 10, 64)
		if err == nil {
			deviceID = &v
		}
	}

	result, err := h.DB.Exec(
		`INSERT INTO photos (user_id, filename, original_path, mime_type, file_size, taken_at, device_id)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		userID, filename, storagePath, mimeType, written, takenAt, deviceID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to save photo record")
		return
	}
	photoID, _ := result.LastInsertId()

	// Trigger thumbnail generation
	thumbDir := filepath.Join(h.DataDir, "thumbs")
	os.MkdirAll(thumbDir, 0755)
	h.ThumbQ.Submit(thumb.Job{
		PhotoID:   photoID,
		InputPath: storagePath,
		OutputDir: thumbDir,
		OnDone: func(id int64, thumbPath string, err error) {
			if err == nil {
				h.DB.Exec("UPDATE photos SET thumbnail_path=? WHERE id=?", thumbPath, id)
			}
		},
	})

	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"id":       photoID,
		"filename": filename,
	})
}

func (h *PhotoHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	month := r.URL.Query().Get("month")
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	var rows *sql.Rows
	var err error
	if month != "" {
		rows, err = h.DB.Query(
			`SELECT id, user_id, filename, original_path, thumbnail_path, mime_type, file_size,
			        width, height, taken_at, is_favorite, device_id, created_at
			 FROM photos WHERE user_id=? AND is_deleted=FALSE AND taken_at LIKE ?
			 ORDER BY taken_at DESC LIMIT ? OFFSET ?`,
			userID, month+"%", limit, offset,
		)
	} else {
		rows, err = h.DB.Query(
			`SELECT id, user_id, filename, original_path, thumbnail_path, mime_type, file_size,
			        width, height, taken_at, is_favorite, device_id, created_at
			 FROM photos WHERE user_id=? AND is_deleted=FALSE
			 ORDER BY taken_at DESC LIMIT ? OFFSET ?`,
			userID, limit, offset,
		)
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	photos := scanPhotos(rows)
	respondJSON(w, http.StatusOK, photos)
}

func (h *PhotoHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	var p struct {
		ID, UserID                      int64
		Filename, OriginalPath, MimeType string
		ThumbnailPath                   sql.NullString
		FileSize                        int64
		Width, Height                   sql.NullInt64
		TakenAt                         sql.NullTime
		IsFavorite                      bool
		DeviceID                        sql.NullInt64
		CreatedAt                       time.Time
	}

	err := h.DB.QueryRow(
		`SELECT id, user_id, filename, original_path, thumbnail_path, mime_type, file_size,
		        width, height, taken_at, is_favorite, device_id, created_at
		 FROM photos WHERE id=? AND user_id=?`, photoID, userID,
	).Scan(&p.ID, &p.UserID, &p.Filename, &p.OriginalPath, &p.ThumbnailPath, &p.MimeType,
		&p.FileSize, &p.Width, &p.Height, &p.TakenAt, &p.IsFavorite, &p.DeviceID, &p.CreatedAt)
	if err == sql.ErrNoRows {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	respondJSON(w, http.StatusOK, p)
}

func (h *PhotoHandler) ServeOriginal(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	var path, mime string
	err := h.DB.QueryRow(
		"SELECT original_path, mime_type FROM photos WHERE id=? AND user_id=? AND is_deleted=FALSE",
		photoID, userID,
	).Scan(&path, &mime)
	if err != nil {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}
	w.Header().Set("Content-Type", mime)
	http.ServeFile(w, r, path)
}

func (h *PhotoHandler) ServeThumbnail(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	var thumbPath, originalPath, mime sql.NullString
	err := h.DB.QueryRow(
		"SELECT thumbnail_path, original_path, mime_type FROM photos WHERE id=? AND user_id=? AND is_deleted=FALSE",
		photoID, userID,
	).Scan(&thumbPath, &originalPath, &mime)
	if err != nil {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}

	if thumbPath.Valid && thumbPath.String != "" {
		w.Header().Set("Content-Type", "image/jpeg")
		http.ServeFile(w, r, thumbPath.String)
		return
	}
	// No thumbnail yet, serve original
	if originalPath.Valid {
		w.Header().Set("Content-Type", mime.String)
		http.ServeFile(w, r, originalPath.String)
		return
	}
	respondError(w, http.StatusNotFound, "thumbnail not available")
}

func (h *PhotoHandler) ToggleFavorite(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	var isFav bool
	err := h.DB.QueryRow(
		"UPDATE photos SET is_favorite = NOT is_favorite WHERE id=? AND user_id=? RETURNING is_favorite",
		photoID, userID,
	).Scan(&isFav)
	if err != nil {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]bool{"is_favorite": isFav})
}

func (h *PhotoHandler) SoftDelete(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	result, err := h.DB.Exec(
		"UPDATE photos SET is_deleted=TRUE, deleted_at=? WHERE id=? AND user_id=? AND is_deleted=FALSE",
		time.Now(), photoID, userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "delete failed")
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *PhotoHandler) Restore(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	photoID := chiURLParam(r, "id")

	result, err := h.DB.Exec(
		"UPDATE photos SET is_deleted=FALSE, deleted_at=NULL WHERE id=? AND user_id=? AND is_deleted=TRUE",
		photoID, userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "restore failed")
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "photo not found in trash")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "restored"})
}

func (h *PhotoHandler) ListTrash(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	rows, err := h.DB.Query(
		`SELECT id, user_id, filename, original_path, thumbnail_path, mime_type, file_size,
		        width, height, taken_at, is_favorite, device_id, created_at
		 FROM photos WHERE user_id=? AND is_deleted=TRUE
		 ORDER BY deleted_at DESC`,
		userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()
	respondJSON(w, http.StatusOK, scanPhotos(rows))
}

// chiURLParam extracts :id from the URL path manually (avoids importing chi in handlers)
func chiURLParam(r *http.Request, key string) string {
	path := r.URL.Path
	// Handle patterns like /api/v1/photos/123/original
	parts := strings.Split(strings.Trim(path, "/"), "/")
	for i, p := range parts {
		if p == key && i+1 < len(parts) {
			return parts[i+1]
		}
	}
	// Fallback: get last numeric segment
	for i := len(parts) - 1; i >= 0; i-- {
		if _, err := strconv.ParseInt(parts[i], 10, 64); err == nil {
			return parts[i]
		}
	}
	return ""
}

func scanPhotos(rows *sql.Rows) []map[string]interface{} {
	results := make([]map[string]interface{}, 0)
	for rows.Next() {
		var id, userID, fileSize int64
		var filename, originalPath, mimeType string
		var thumbnailPath sql.NullString
		var width, height sql.NullInt64
		var takenAt sql.NullTime
		var isFavorite bool
		var deviceID sql.NullInt64
		var createdAt time.Time

		rows.Scan(&id, &userID, &filename, &originalPath, &thumbnailPath, &mimeType,
			&fileSize, &width, &height, &takenAt, &isFavorite, &deviceID, &createdAt)

		photo := map[string]interface{}{
			"id":         id,
			"user_id":    userID,
			"filename":   filename,
			"mime_type":  mimeType,
			"file_size":  fileSize,
			"is_favorite": isFavorite,
			"created_at": createdAt,
		}
		if thumbnailPath.Valid {
			photo["thumbnail_path"] = thumbnailPath.String
		}
		if width.Valid {
			photo["width"] = width.Int64
		}
		if height.Valid {
			photo["height"] = height.Int64
		}
		if takenAt.Valid {
			photo["taken_at"] = takenAt.Time
		}
		if deviceID.Valid {
			photo["device_id"] = deviceID.Int64
		}
		results = append(results, photo)
	}
	return results
}
