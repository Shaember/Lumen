package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"lumen-backend/internal/db"
	"lumen-backend/internal/middleware"
	"lumen-backend/internal/thumb"
)

func setupAlbumTestServer(t *testing.T) (*httptest.Server, func()) {
	t.Helper()
	origDir, _ := os.Getwd()
	os.Chdir("../..")

	testDB, err := db.InitMemory()
	if err != nil {
		os.Chdir(origDir)
		t.Fatalf("InitMemory: %v", err)
	}

	dataDir := t.TempDir()
	thumbQ := thumb.NewQueue(5)

	secret := "test-secret"
	ph := &PhotoHandler{DB: testDB, DataDir: dataDir, ThumbQ: thumbQ}
	ah := &AuthHandler{DB: testDB, AccessTTL: 15 * time.Minute, RefreshTTL: 30 * 24 * time.Hour, JWTSecret: secret}
	albH := &AlbumHandler{DB: testDB}

	mux := http.NewServeMux()

	mux.HandleFunc("POST /api/v1/auth/setup", ah.Setup)
	mux.HandleFunc("POST /api/v1/auth/login", ah.Login)

	authMw := middleware.AuthMiddleware(secret)
	mux.Handle("POST /api/v1/photos/upload", authMw(http.HandlerFunc(ph.Upload)))
	mux.Handle("GET /api/v1/photos", authMw(http.HandlerFunc(ph.List)))
	mux.Handle("GET /api/v1/albums", authMw(http.HandlerFunc(albH.List)))
	mux.Handle("POST /api/v1/albums", authMw(http.HandlerFunc(albH.Create)))
	mux.Handle("GET /api/v1/albums/{id}", authMw(http.HandlerFunc(albH.Get)))
	mux.Handle("PATCH /api/v1/albums/{id}", authMw(http.HandlerFunc(albH.Update)))
	mux.Handle("DELETE /api/v1/albums/{id}", authMw(http.HandlerFunc(albH.Delete)))
	mux.Handle("POST /api/v1/albums/{id}/photos", authMw(http.HandlerFunc(albH.AddPhotos)))
	mux.Handle("DELETE /api/v1/albums/{id}/photos/{photoId}", authMw(http.HandlerFunc(albH.RemovePhoto)))

	server := httptest.NewServer(mux)
	cleanup := func() {
		server.Close()
		testDB.Close()
		thumbQ.Close()
		os.Chdir(origDir)
	}
	return server, cleanup
}

func uploadTestPhoto(t *testing.T, server *httptest.Server, token string) int64 {
	t.Helper()
	imgData := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52}
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "test.png")
	part.Write(imgData)
	writer.WriteField("taken_at", "2024-06-15T10:30:00Z")
	writer.Close()

	req, _ := http.NewRequest("POST", server.URL+"/api/v1/photos/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("upload: status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	data := result["data"].(map[string]interface{})
	return int64(data["id"].(float64))
}

func TestAlbumCRUD(t *testing.T) {
	server, cleanup := setupAlbumTestServer(t)
	defer cleanup()

	// Setup + Login
	body, _ := json.Marshal(map[string]string{"username": "admin", "password": "password123"})
	http.Post(server.URL+"/api/v1/auth/setup", "application/json", bytes.NewReader(body))
	resp, _ := http.Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	var loginResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&loginResult)
	resp.Body.Close()
	token := loginResult["data"].(map[string]interface{})["access_token"].(string)

	// Create album
	albumBody, _ := json.Marshal(map[string]string{"name": "Vacation 2024"})
	req, _ := http.NewRequest("POST", server.URL+"/api/v1/albums", bytes.NewReader(albumBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("create album: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create album: status %d", resp.StatusCode)
	}
	var createResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&createResult)
	albumID := int64(createResult["data"].(map[string]interface{})["id"].(float64))

	// Upload a photo
	photoID := uploadTestPhoto(t, server, token)

	// Add photo to album
	addBody, _ := json.Marshal(map[string]interface{}{"photo_ids": []int64{photoID}})
	req, _ = http.NewRequest("POST", fmt.Sprintf("%s/api/v1/albums/%d/photos", server.URL, albumID), bytes.NewReader(addBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("add photos: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("add photos: status %d", resp.StatusCode)
	}

	// Get album
	req, _ = http.NewRequest("GET", fmt.Sprintf("%s/api/v1/albums/%d", server.URL, albumID), nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get album: %v", err)
	}
	defer resp.Body.Close()
	var getResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&getResult)
	albumData := getResult["data"].(map[string]interface{})
	photos := albumData["photos"].([]interface{})
	if len(photos) != 1 {
		t.Fatalf("expected 1 photo in album, got %d", len(photos))
	}

	// List albums
	req, _ = http.NewRequest("GET", server.URL+"/api/v1/albums", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("list albums: %v", err)
	}
	defer resp.Body.Close()
	var listResult map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&listResult)
	albums := listResult["data"].([]interface{})
	if len(albums) != 1 {
		t.Fatalf("expected 1 album, got %d", len(albums))
	}

	// Update album name
	updateBody, _ := json.Marshal(map[string]string{"name": "Summer 2024"})
	req, _ = http.NewRequest("PATCH", fmt.Sprintf("%s/api/v1/albums/%d", server.URL, albumID), bytes.NewReader(updateBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("update album: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update album: status %d", resp.StatusCode)
	}

	// Remove photo from album
	req, _ = http.NewRequest("DELETE", fmt.Sprintf("%s/api/v1/albums/%d/photos/%d", server.URL, albumID, photoID), nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("remove photo: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("remove photo: status %d", resp.StatusCode)
	}

	// Delete album
	req, _ = http.NewRequest("DELETE", fmt.Sprintf("%s/api/v1/albums/%d", server.URL, albumID), nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete album: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("delete album: status %d", resp.StatusCode)
	}
}
