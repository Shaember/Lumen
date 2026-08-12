package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"lumen-backend/internal/middleware"
)

type DeviceHandler struct {
	DB *sql.DB
}

func (h *DeviceHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	rows, err := h.DB.Query(
		"SELECT id, user_id, name, device_type, push_token, created_at FROM devices WHERE user_id=?",
		userID,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	var devices []map[string]interface{}
	for rows.Next() {
		var id, uid int64
		var name, dtype string
		var pushToken sql.NullString
		var createdAt sql.NullTime
		rows.Scan(&id, &uid, &name, &dtype, &pushToken, &createdAt)
		d := map[string]interface{}{
			"id":          id,
			"user_id":     uid,
			"name":        name,
			"device_type": dtype,
		}
		if pushToken.Valid {
			d["push_token"] = pushToken.String
		}
		if createdAt.Valid {
			d["created_at"] = createdAt.Time
		}
		devices = append(devices, d)
	}
	respondJSON(w, http.StatusOK, devices)
}

func (h *DeviceHandler) Register(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	var req struct {
		Name       string `json:"name"`
		DeviceType string `json:"device_type"`
		PushToken  string `json:"push_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		respondError(w, http.StatusBadRequest, "name required")
		return
	}
	if req.DeviceType == "" {
		req.DeviceType = "ios"
	}
	var pushToken interface{}
	if req.PushToken != "" {
		pushToken = req.PushToken
	}
	result, err := h.DB.Exec(
		"INSERT INTO devices (user_id, name, device_type, push_token) VALUES (?, ?, ?, ?)",
		userID, req.Name, req.DeviceType, pushToken,
	)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "register failed")
		return
	}
	id, _ := result.LastInsertId()
	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"id":   id,
		"name": req.Name,
	})
}

func (h *DeviceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	deviceID, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	result, err := h.DB.Exec("DELETE FROM devices WHERE id=? AND user_id=?", deviceID, userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "delete failed")
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		respondError(w, http.StatusNotFound, "device not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}
