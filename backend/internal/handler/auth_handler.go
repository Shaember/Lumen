package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"lumen-backend/internal/auth"
	"lumen-backend/internal/middleware"
)

type AuthHandler struct {
	DB         *sql.DB
	AccessTTL  time.Duration
	RefreshTTL time.Duration
	JWTSecret  string
}

type APIResponse struct {
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(APIResponse{Data: data})
}

func respondError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(APIResponse{Error: msg})
}

func (h *AuthHandler) Setup(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Username == "" || req.Password == "" {
		respondError(w, http.StatusBadRequest, "username and password required")
		return
	}
	if len(req.Password) < 8 {
		respondError(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}
	if err := auth.SetupAdmin(h.DB, req.Username, req.Password); err != nil {
		respondError(w, http.StatusConflict, err.Error())
		return
	}
	respondJSON(w, http.StatusCreated, map[string]string{"message": "admin created"})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// Check if any users exist (first-run)
	var count int
	h.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if count == 0 {
		respondError(w, http.StatusForbidden, "no users exist — use /api/v1/auth/setup first")
		return
	}

	userID, _, isAdmin, err := auth.Login(h.DB, req.Username, req.Password)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	accessToken, err := auth.GenerateAccessToken(*userID, req.Username, *isAdmin, h.JWTSecret, h.AccessTTL)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	refreshToken, err := auth.CreateRefreshToken(h.DB, *userID, nil, h.RefreshTTL)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to create refresh token")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"access_token":  accessToken,
		"refresh_token": refreshToken,
		"user": map[string]interface{}{
			"id":       *userID,
			"username": req.Username,
			"is_admin": *isAdmin,
		},
	})
}

func (h *AuthHandler) Signup(w http.ResponseWriter, r *http.Request) {
	isAdmin, _ := r.Context().Value(middleware.IsAdminKey).(bool)
	if !isAdmin {
		respondError(w, http.StatusForbidden, "admin required")
		return
	}
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if len(req.Password) < 8 {
		respondError(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}
	userID, err := auth.Signup(h.DB, req.Username, req.Password)
	if err != nil {
		respondError(w, http.StatusConflict, err.Error())
		return
	}
	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"id":       userID,
		"username": req.Username,
	})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	userID, _, err := auth.ValidateRefreshToken(h.DB, req.RefreshToken)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}
	// Revoke old token
	auth.RevokeRefreshToken(h.DB, req.RefreshToken)

	// Get user info
	var username string
	var isAdmin bool
	h.DB.QueryRow("SELECT username, is_admin FROM users WHERE id=?", *userID).Scan(&username, &isAdmin)

	accessToken, err := auth.GenerateAccessToken(*userID, username, isAdmin, h.JWTSecret, h.AccessTTL)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}
	newRefreshToken, err := auth.CreateRefreshToken(h.DB, *userID, nil, h.RefreshTTL)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to create refresh token")
		return
	}
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"access_token":  accessToken,
		"refresh_token": newRefreshToken,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	auth.RevokeRefreshToken(h.DB, req.RefreshToken)
	respondJSON(w, http.StatusOK, map[string]string{"message": "logged out"})
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	var username string
	var isAdmin bool
	err := h.DB.QueryRow("SELECT username, is_admin FROM users WHERE id=?", userID).Scan(&username, &isAdmin)
	if err != nil {
		respondError(w, http.StatusNotFound, "user not found")
		return
	}
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"id":       userID,
		"username": username,
		"is_admin": isAdmin,
	})
}
