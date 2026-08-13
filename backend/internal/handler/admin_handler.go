package handler

import (
	"database/sql"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"lumen-backend/internal/middleware"
)

type AdminHandler struct {
	DB      *sql.DB
	DataDir string
}

// Rescan walks the photos directory and rebuilds the database index.
// This is the core spec requirement: "DB is only an index, fully rebuildable via folder rescan"
func (h *AdminHandler) Rescan(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	isAdmin, _ := r.Context().Value(middleware.IsAdminKey).(bool)
	if !isAdmin {
		respondError(w, http.StatusForbidden, "admin required")
		return
	}

	photosDir := filepath.Join(h.DataDir, "photos")
	if _, err := os.Stat(photosDir); os.IsNotExist(err) {
		respondJSON(w, http.StatusOK, map[string]interface{}{"scanned": 0, "added": 0})
		return
	}

	var scanned, added, skipped int
	err := filepath.WalkDir(photosDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}

		// Only process image files
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".gif" && ext != ".webp" && ext != ".heic" {
			return nil
		}

		scanned++

		// Check if already indexed
		var count int
		h.DB.QueryRow("SELECT COUNT(*) FROM photos WHERE original_path=?", path).Scan(&count)
		if count > 0 {
			skipped++
			return nil
		}

		// Extract metadata from filename (YYYY-MM-DD_HHMMSS_name.ext)
		filename := filepath.Base(path)
		info, err := d.Info()
		if err != nil {
			return nil
		}

		// Detect MIME type
		mimeType := "image/jpeg"
		switch ext {
		case ".png":
			mimeType = "image/png"
		case ".gif":
			mimeType = "image/gif"
		case ".webp":
			mimeType = "image/webp"
		case ".heic":
			mimeType = "image/heic"
		}

		// Try to parse taken_at from filename, fall back to mod time
		takenAt := info.ModTime()

		// Insert into DB
		_, err = h.DB.Exec(
			`INSERT OR IGNORE INTO photos (user_id, filename, original_path, mime_type, file_size, taken_at)
			 VALUES (?, ?, ?, ?, ?, ?)`,
			userID, filename, path, mimeType, info.Size(), takenAt,
		)
		if err == nil {
			added++
		}
		return nil
	})

	if err != nil {
		respondError(w, http.StatusInternalServerError, "rescan failed: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"scanned": scanned,
		"added":   added,
		"skipped": skipped,
	})
}
