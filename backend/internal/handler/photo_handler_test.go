package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"lumen-backend/internal/db"
	"lumen-backend/internal/middleware"
	"lumen-backend/internal/thumb"
)

func setupTestServer(t *testing.T) (*httptest.Server, func()) {
	t.Helper()
	origDir, _ := os.Getwd()
	os.Chdir("../..")

	testDB, err := db.InitMemory()
	if err != nil {
		os.Chdir(origDir)
		t.Fatalf("InitMemory: %v", err)
	}

	dataDir := t.TempDir()
	thumbDir := filepath.Join(dataDir, "thumbs")
	os.MkdirAll(thumbDir, 0755)
	photoDir := filepath.Join(dataDir, "photos")
	os.MkdirAll(photoDir, 0755)

	thumbQ := thumb.NewQueue(5)

	secret := "test-secret"
	accessTTL := 15 * time.Minute
	refreshTTL := 30 * 24 * time.Hour

	ph := &PhotoHandler{DB: testDB, DataDir: dataDir, ThumbQ: thumbQ}
	ah := &AuthHandler{DB: testDB, AccessTTL: accessTTL, RefreshTTL: refreshTTL, JWTSecret: secret}

	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("POST /api/v1/auth/setup", ah.Setup)
	mux.HandleFunc("POST /api/v1/auth/login", ah.Login)
	mux.HandleFunc("POST /api/v1/auth/refresh", ah.Refresh)

	// Protected routes
	authMw := middleware.AuthMiddleware(secret)
	mux.Handle("POST /api/v1/auth/signup", authMw(http.HandlerFunc(ah.Signup)))
	mux.Handle("POST /api/v1/auth/logout", authMw(http.HandlerFunc(ah.Logout)))
	mux.Handle("GET /api/v1/auth/me", authMw(http.HandlerFunc(ah.Me)))

	mux.Handle("POST /api/v1/photos/upload", authMw(http.HandlerFunc(ph.Upload)))
	mux.Handle("GET /api/v1/photos", authMw(http.HandlerFunc(ph.List)))
	mux.Handle("GET /api/v1/photos/{id}", authMw(http.HandlerFunc(ph.Get)))
	mux.Handle("GET /api/v1/photos/{id}/original", authMw(http.HandlerFunc(ph.ServeOriginal)))
	mux.Handle("GET /api/v1/photos/{id}/thumbnail", authMw(http.HandlerFunc(ph.ServeThumbnail)))
	mux.Handle("PATCH /api/v1/photos/{id}/favorite", authMw(http.HandlerFunc(ph.ToggleFavorite)))
	mux.Handle("DELETE /api/v1/photos/{id}", authMw(http.HandlerFunc(ph.SoftDelete)))
	mux.Handle("POST /api/v1/photos/{id}/restore", authMw(http.HandlerFunc(ph.Restore)))
	mux.Handle("GET /api/v1/photos/trash", authMw(http.HandlerFunc(ph.ListTrash)))

	server := httptest.NewServer(mux)
	cleanup := func() {
		server.Close()
		testDB.Close()
		thumbQ.Close()
		os.Chdir(origDir)
	}
	return server, cleanup
}

func getTokens(t *testing.T, server *httptest.Server) (string, string) {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"username": "admin", "password": "password123"})
	resp, err := http.Post(server.URL+"/api/v1/auth/setup", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("setup: %v", err)
	}
	resp.Body.Close()

	body, _ = json.Marshal(map[string]string{"username": "admin", "password": "password123"})
	resp, err = http.Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	data := result["data"].(map[string]interface{})
	return data["access_token"].(string), data["refresh_token"].(string)
}

func TestUploadAndTimeline(t *testing.T) {
	server, cleanup := setupTestServer(t)
	defer cleanup()

	accessToken, _ := getTokens(t, server)

	// Create a tiny test image (valid PNG header)
	imgData := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52}
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "test.png")
	part.Write(imgData)
	writer.WriteField("taken_at", "2024-06-15T10:30:00Z")
	writer.Close()

	req, _ := http.NewRequest("POST", server.URL+"/api/v1/photos/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("upload: status %d, expected %d", resp.StatusCode, http.StatusCreated)
	}

	var uploadResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&uploadResult)
	data := uploadResult["data"].(map[string]interface{})
	photoID := int64(data["id"].(float64))
	t.Logf("Uploaded photo id=%d", photoID)

	// List timeline
	req, _ = http.NewRequest("GET", server.URL+"/api/v1/photos", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("timeline: %v", err)
	}
	defer resp.Body.Close()

	var listResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&listResult)
	photos := listResult["data"].([]interface{})
	if len(photos) != 1 {
		t.Fatalf("expected 1 photo in timeline, got %d", len(photos))
	}

	// Get single photo
	req, _ = http.NewRequest("GET", fmt.Sprintf("%s/api/v1/photos/%d", server.URL, photoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get photo: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("get photo: status %d", resp.StatusCode)
	}

	// Toggle favorite
	req, _ = http.NewRequest("PATCH", fmt.Sprintf("%s/api/v1/photos/%d/favorite", server.URL, photoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("favorite: %v", err)
	}
	defer resp.Body.Close()
	var favResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&favResult)
	favData := favResult["data"].(map[string]interface{})
	if !favData["is_favorite"].(bool) {
		t.Error("expected is_favorite=true after first toggle")
	}

	// Soft delete
	req, _ = http.NewRequest("DELETE", fmt.Sprintf("%s/api/v1/photos/%d", server.URL, photoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("delete: status %d", resp.StatusCode)
	}

	// Verify deleted from timeline
	req, _ = http.NewRequest("GET", server.URL+"/api/v1/photos", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("list after delete: %v", err)
	}
	defer resp.Body.Close()
	var listResult2 map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&listResult2)
	photos2 := listResult2["data"].([]interface{})
	if len(photos2) != 0 {
		t.Fatalf("expected 0 photos after delete, got %d", len(photos2))
	}

	// Restore
	req, _ = http.NewRequest("POST", fmt.Sprintf("%s/api/v1/photos/%d/restore", server.URL, photoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("restore: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("restore: status %d", resp.StatusCode)
	}

	// Verify restored
	req, _ = http.NewRequest("GET", server.URL+"/api/v1/photos", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("list after restore: %v", err)
	}
	defer resp.Body.Close()
	var listResult3 map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&listResult3)
	photos3 := listResult3["data"].([]interface{})
	if len(photos3) != 1 {
		t.Fatalf("expected 1 photo after restore, got %d", len(photos3))
	}
}

func TestAuthSetupAndLogin(t *testing.T) {
	server, cleanup := setupTestServer(t)
	defer cleanup()

	// No users yet — login should fail
	body, _ := json.Marshal(map[string]string{"username": "admin", "password": "password123"})
	resp, err := http.Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("login before setup: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 before setup, got %d", resp.StatusCode)
	}

	// Setup admin
	resp, err = http.Post(server.URL+"/api/v1/auth/setup", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("setup: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("setup: status %d", resp.StatusCode)
	}

	// Duplicate setup should fail
	resp, _ = http.Post(server.URL+"/api/v1/auth/setup", "application/json", bytes.NewReader(body))
	resp.Body.Close()
	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("duplicate setup: expected 409, got %d", resp.StatusCode)
	}

	// Login succeeds
	resp, err = http.Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login: status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	data := result["data"].(map[string]interface{})
	if data["access_token"] == nil || data["refresh_token"] == nil {
		t.Error("missing tokens in login response")
	}

	// /me endpoint
	accessToken := data["access_token"].(string)
	req, _ := http.NewRequest("GET", server.URL+"/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("me: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("me: status %d", resp.StatusCode)
	}
}
