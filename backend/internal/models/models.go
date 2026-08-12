package models

import "time"

type User struct {
	ID           int64     `json:"id"`
	Username     string    `json:"username"`
	PasswordHash string    `json:"-"`
	IsAdmin      bool      `json:"is_admin"`
	CreatedAt    time.Time `json:"created_at"`
}

type Photo struct {
	ID            int64      `json:"id"`
	UserID        int64      `json:"user_id"`
	Filename      string     `json:"filename"`
	OriginalPath  string     `json:"-"`
	ThumbnailPath *string    `json:"thumbnail_path,omitempty"`
	MimeType      string     `json:"mime_type"`
	FileSize      int64      `json:"file_size"`
	Width         *int       `json:"width,omitempty"`
	Height        *int       `json:"height,omitempty"`
	TakenAt       *time.Time `json:"taken_at,omitempty"`
	IsFavorite    bool       `json:"is_favorite"`
	IsDeleted     bool       `json:"-"`
	DeletedAt     *time.Time `json:"-"`
	DeviceID      *int64     `json:"device_id,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

type PhotoTimeline struct {
	Month  string  `json:"month"`
	Photos []Photo `json:"photos"`
}

type Album struct {
	ID            int64      `json:"id"`
	UserID        int64      `json:"user_id"`
	Name          string     `json:"name"`
	CoverPhotoID  *int64     `json:"cover_photo_id,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	PhotoCount    int        `json:"photo_count,omitempty"`
}

type AlbumPhoto struct {
	ID        int64     `json:"id"`
	AlbumID   int64     `json:"album_id"`
	PhotoID   int64     `json:"photo_id"`
	Position  int       `json:"position"`
	CreatedAt time.Time `json:"created_at"`
}

type Device struct {
	ID         int64     `json:"id"`
	UserID     int64     `json:"user_id"`
	Name       string    `json:"name"`
	DeviceType string    `json:"device_type"`
	PushToken  *string   `json:"push_token,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

type RefreshToken struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"user_id"`
	DeviceID  *int64    `json:"device_id,omitempty"`
	Token     string    `json:"-"`
	ExpiresAt time.Time `json:"expires_at"`
	Revoked   bool      `json:"-"`
	CreatedAt time.Time `json:"created_at"`
}
