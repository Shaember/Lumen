package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"

	"lumen-backend/internal/config"
	"lumen-backend/internal/db"
	"lumen-backend/internal/handler"
	"lumen-backend/internal/middleware"
	"lumen-backend/internal/thumb"
)

// Chain applies multiple middleware in order (outer first).
func Chain(middlewares ...func(http.Handler) http.Handler) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		for i := len(middlewares) - 1; i >= 0; i-- {
			next = middlewares[i](next)
		}
		return next
	}
}

func main() {
	cfg := config.Load()

	if cfg.JWTSecret == "" {
		log.Fatal("LUMEN_JWT_SECRET is required")
	}

	// Ensure directories
	os.MkdirAll(cfg.DataDir, 0755)
	os.MkdirAll(filepath.Join(cfg.DataDir, "photos"), 0755)
	os.MkdirAll(filepath.Join(cfg.DataDir, "thumbs"), 0755)

	// Init DB
	database, err := db.Init(cfg.DBPath)
	if err != nil {
		log.Fatalf("db init: %v", err)
	}
	defer database.Close()

	// Init thumbnail queue
	thumbQ := thumb.NewQueue(cfg.ThumbQueueSize)
	defer thumbQ.Close()

	// Handlers
	authH := &handler.AuthHandler{
		DB:         database,
		AccessTTL:  cfg.AccessTTL,
		RefreshTTL: cfg.RefreshTTL,
		JWTSecret:  cfg.JWTSecret,
	}
	photoH := &handler.PhotoHandler{
		DB:      database,
		DataDir: cfg.DataDir,
		ThumbQ:  thumbQ,
	}
	albumH := &handler.AlbumHandler{DB: database}
	deviceH := &handler.DeviceHandler{DB: database}

	// Rate limiters
	rlGeneral := middleware.NewRateLimiter(100, 100)
	rlAuth := middleware.NewRateLimiter(10, 20)

	// Router
	mux := http.NewServeMux()

	// Public auth routes (rate limited)
	mux.Handle("POST /api/v1/auth/setup", middleware.RateLimit(rlAuth)(http.HandlerFunc(authH.Setup)))
	mux.Handle("POST /api/v1/auth/login", middleware.RateLimit(rlAuth)(http.HandlerFunc(authH.Login)))
	mux.Handle("POST /api/v1/auth/refresh", middleware.RateLimit(rlAuth)(http.HandlerFunc(authH.Refresh)))

	// Protected routes
	authMw := Chain(
		middleware.AuthMiddleware(cfg.JWTSecret),
		middleware.RateLimit(rlGeneral),
	)

	mux.Handle("POST /api/v1/auth/signup", authMw(http.HandlerFunc(authH.Signup)))
	mux.Handle("POST /api/v1/auth/logout", authMw(http.HandlerFunc(authH.Logout)))
	mux.Handle("GET /api/v1/auth/me", authMw(http.HandlerFunc(authH.Me)))

	mux.Handle("POST /api/v1/photos/upload", authMw(http.HandlerFunc(photoH.Upload)))
	mux.Handle("GET /api/v1/photos", authMw(http.HandlerFunc(photoH.List)))
	mux.Handle("GET /api/v1/photos/{id}", authMw(http.HandlerFunc(photoH.Get)))
	mux.Handle("GET /api/v1/photos/{id}/original", authMw(http.HandlerFunc(photoH.ServeOriginal)))
	mux.Handle("GET /api/v1/photos/{id}/thumbnail", authMw(http.HandlerFunc(photoH.ServeThumbnail)))
	mux.Handle("PATCH /api/v1/photos/{id}/favorite", authMw(http.HandlerFunc(photoH.ToggleFavorite)))
	mux.Handle("DELETE /api/v1/photos/{id}", authMw(http.HandlerFunc(photoH.SoftDelete)))
	mux.Handle("POST /api/v1/photos/{id}/restore", authMw(http.HandlerFunc(photoH.Restore)))
	mux.Handle("GET /api/v1/photos/trash", authMw(http.HandlerFunc(photoH.ListTrash)))

	mux.Handle("GET /api/v1/albums", authMw(http.HandlerFunc(albumH.List)))
	mux.Handle("POST /api/v1/albums", authMw(http.HandlerFunc(albumH.Create)))
	mux.Handle("GET /api/v1/albums/{id}", authMw(http.HandlerFunc(albumH.Get)))
	mux.Handle("PATCH /api/v1/albums/{id}", authMw(http.HandlerFunc(albumH.Update)))
	mux.Handle("DELETE /api/v1/albums/{id}", authMw(http.HandlerFunc(albumH.Delete)))
	mux.Handle("POST /api/v1/albums/{id}/photos", authMw(http.HandlerFunc(albumH.AddPhotos)))
	mux.Handle("DELETE /api/v1/albums/{id}/photos/{photoId}", authMw(http.HandlerFunc(albumH.RemovePhoto)))

	mux.Handle("GET /api/v1/devices", authMw(http.HandlerFunc(deviceH.List)))
	mux.Handle("POST /api/v1/devices/register", authMw(http.HandlerFunc(deviceH.Register)))
	mux.Handle("DELETE /api/v1/devices/{id}", authMw(http.HandlerFunc(deviceH.Delete)))

	// Apply CORS to everything
	handler := middleware.CORSMiddleware(cfg.CORSOrigin)(mux)

	log.Printf("Lumen backend starting on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, handler))
}
