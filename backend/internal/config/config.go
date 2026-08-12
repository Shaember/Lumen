package config

import (
	"os"
	"time"
)

type Config struct {
	DataDir     string
	DBPath      string
	JWTSecret   string
	Port        string
	CORSOrigin  string
	AccessTTL   time.Duration
	RefreshTTL  time.Duration
	ThumbQueueSize int
}

func Load() *Config {
	return &Config{
		DataDir:       envOr("LUMEN_DATA_DIR", "/data"),
		DBPath:        envOr("LUMEN_DB_PATH", "/data/lumen.db"),
		JWTSecret:     envOr("LUMEN_JWT_SECRET", ""),
		Port:          envOr("LUMEN_PORT", "8080"),
		CORSOrigin:    envOr("LUMEN_CORS_ORIGIN", "http://localhost:5173"),
		AccessTTL:     15 * time.Minute,
		RefreshTTL:    30 * 24 * time.Hour,
		ThumbQueueSize: 10,
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
