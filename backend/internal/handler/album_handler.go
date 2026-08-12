package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"lumen-backend/internal/middleware"
)

type AlbumHandler struct {
	DB *sql.DB
}

func (h *AlbumHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	rows, err := h.DB.Query(
		`SELECT a.id, a.user_id, a.name, a.cover_photo_id, a.created_at, a.updated_at,
		        COUNT(ap.id) as photo_count
		 FROM albums a LEFT JOIN album_photos ap ON a.id = ap.album_id
		 WHERE a.user_id=? GROUP BY a.id ORDER BY a.updated_at DESC`,
		userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	var albums []map[string]interface{}
	for rows.Next() {
		var id, userID int64
		var name string
		var coverPhotoID sql.NullInt64
		var createdAt, updatedAt time.Time
		var photoCount int
		rows.Scan(&id, &userID, &name, &coverPhotoID, &createdAt, &updatedAt, &photoCount)
		album := map[string]interface{}{
			"id":          id,
			"user_id":     userID,
			"name":        name,
			"created_at":  createdAt,
			"updated_at":  updatedAt,
			"photo_count": photoCount,
		}
		if coverPhotoID.Valid {
			album["cover_photo_id"] = coverPhotoID.Int64
		}
		albums = append(albums, album)
	}
	respondJSON(w, http.StatusOK, albums)
}

func (h *AlbumHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	var req struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		respondError(w, http.StatusBadRequest, "name required")
		return
	}
	result, err := h.DB.Exec(
		"INSERT INTO albums (user_id, name) VALUES (?, ?)", userID, req.Name,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "create failed")
		return
	}
	id, _ := result.LastInsertId()
	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"id":   id,
		"name": req.Name,
	})
}

func (h *AlbumHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	albumIDStr := r.PathValue("id")
	albumID, err := strconv.ParseInt(albumIDStr, 10, 64)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid album id")
		return
	}

	var name string
	var coverPhotoID sql.NullInt64
	var createdAt, updatedAt time.Time
	err = h.DB.QueryRow(
		"SELECT name, cover_photo_id, created_at, updated_at FROM albums WHERE id=? AND user_id=?",
		albumID, userID,
	).Scan(&name, &coverPhotoID, &createdAt, &updatedAt)
	if err == sql.ErrNoRows {
		respondError(w, http.StatusNotFound, "album not found")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}

	// Get photos in album
	rows, err := h.DB.Query(
		`SELECT p.id, p.user_id, p.filename, p.original_path, p.thumbnail_path, p.mime_type,
		        p.file_size, p.width, p.height, p.taken_at, p.is_favorite, p.device_id, p.created_at
		 FROM photos p JOIN album_photos ap ON p.id = ap.photo_id
		 WHERE ap.album_id=? ORDER BY ap.position`,
		albumID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	album := map[string]interface{}{
		"id":         albumID,
		"name":       name,
		"created_at": createdAt,
		"updated_at": updatedAt,
	}
	if coverPhotoID.Valid {
		album["cover_photo_id"] = coverPhotoID.Int64
	}
	album["photos"] = scanPhotos(rows)
	respondJSON(w, http.StatusOK, album)
}

func (h *AlbumHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	albumID, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	var req struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		respondError(w, http.StatusBadRequest, "name required")
		return
	}
	result, err := h.DB.Exec(
		"UPDATE albums SET name=?, updated_at=? WHERE id=? AND user_id=?",
		req.Name, time.Now(), albumID, userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "update failed")
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "album not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "updated"})
}

func (h *AlbumHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	albumID, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	result, err := h.DB.Exec("DELETE FROM albums WHERE id=? AND user_id=?", albumID, userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "delete failed")
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "album not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *AlbumHandler) AddPhotos(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	albumID, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)

	// Verify album ownership
	var count int
	h.DB.QueryRow("SELECT COUNT(*) FROM albums WHERE id=? AND user_id=?", albumID, userID).Scan(&count)
	if count == 0 {
		respondError(w, http.StatusNotFound, "album not found")
		return
	}

	var req struct {
		PhotoIDs []int64 `json:"photo_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.PhotoIDs) == 0 {
		respondError(w, http.StatusBadRequest, "photo_ids required")
		return
	}

	var added int
	for _, photoID := range req.PhotoIDs {
		_, err := h.DB.Exec(
			"INSERT OR IGNORE INTO album_photos (album_id, photo_id) VALUES (?, ?)",
			albumID, photoID,
		)
		if err == nil {
			added++
		}
	}
	respondJSON(w, http.StatusOK, map[string]interface{}{"added": added})
}

func (h *AlbumHandler) RemovePhoto(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	albumID, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	photoID, _ := strconv.ParseInt(r.PathValue("photoId"), 10, 64)

	// Verify album ownership
	var count int
	h.DB.QueryRow("SELECT COUNT(*) FROM albums WHERE id=? AND user_id=?", albumID, userID).Scan(&count)
	if count == 0 {
		respondError(w, http.StatusNotFound, "album not found")
		return
	}

	result, _ := h.DB.Exec(
		"DELETE FROM album_photos WHERE album_id=? AND photo_id=?",
		albumID, photoID,
	)
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "photo not in album")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "removed"})
}
