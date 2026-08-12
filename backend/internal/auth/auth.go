package auth

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/argon2"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserExists         = errors.New("username already taken")
	ErrNoUsers            = errors.New("no users exist — use setup endpoint")
	ErrTokenRevoked       = errors.New("token revoked")
	ErrTokenExpired       = errors.New("token expired")
)

type Claims struct {
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
	IsAdmin  bool   `json:"is_admin"`
	DeviceID *int64 `json:"device_id,omitempty"`
	jwt.RegisteredClaims
}

func HashPassword(password string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
	return fmt.Sprintf("$argon2id$v=19$m=65536,t=1,p=4$%s$%s", hex.EncodeToString(salt), hex.EncodeToString(hash)), nil
}

func VerifyPassword(password, encodedHash string) bool {
	parts := strings.Split(encodedHash, "$")
	if len(parts) != 6 {
		return false
	}
	salt, err := hex.DecodeString(parts[4])
	if err != nil {
		return false
	}
	expectedHash, err := hex.DecodeString(parts[5])
	if err != nil {
		return false
	}
	hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
	return hex.EncodeToString(hash) == hex.EncodeToString(expectedHash)
}

func GenerateAccessToken(userID int64, username string, isAdmin bool, secret string, ttl time.Duration) (string, error) {
	claims := &Claims{
		UserID:  userID,
		Username: username,
		IsAdmin: isAdmin,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "lumen",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func GenerateRefreshToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func ValidateAccessToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}
	return claims, nil
}

func SetupAdmin(db *sql.DB, username, password string) error {
	var count int
	db.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if count > 0 {
		return errors.New("users already exist")
	}
	hash, err := HashPassword(password)
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, ?)", username, hash, true)
	return err
}

func Signup(db *sql.DB, username, password string) (int64, error) {
	var count int
	db.QueryRow("SELECT COUNT(*) FROM users WHERE username=?", username).Scan(&count)
	if count > 0 {
		return 0, ErrUserExists
	}
	hash, err := HashPassword(password)
	if err != nil {
		return 0, err
	}
	result, err := db.Exec("INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, ?)", username, hash, false)
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}

func Login(db *sql.DB, username, password string) (*int64, *string, *bool, error) {
	var id int64
	var hash string
	var isAdmin bool
	err := db.QueryRow("SELECT id, password_hash, is_admin FROM users WHERE username=?", username).Scan(&id, &hash, &isAdmin)
	if err == sql.ErrNoRows {
		return nil, nil, nil, ErrInvalidCredentials
	}
	if err != nil {
		return nil, nil, nil, err
	}
	if !VerifyPassword(password, hash) {
		return nil, nil, nil, ErrInvalidCredentials
	}
	return &id, nil, &isAdmin, nil
}

func CreateRefreshToken(db *sql.DB, userID int64, deviceID *int64, ttl time.Duration) (string, error) {
	token, err := GenerateRefreshToken()
	if err != nil {
		return "", err
	}
	_, err = db.Exec("INSERT INTO refresh_tokens (user_id, device_id, token, expires_at) VALUES (?, ?, ?, ?)",
		userID, deviceID, token, time.Now().Add(ttl))
	return token, err
}

func ValidateRefreshToken(db *sql.DB, token string) (*int64, *int64, error) {
	var userID int64
	var deviceID sql.NullInt64
	var expiresAt time.Time
	var revoked bool
	err := db.QueryRow("SELECT user_id, device_id, expires_at, revoked FROM refresh_tokens WHERE token=?", token).
		Scan(&userID, &deviceID, &expiresAt, &revoked)
	if err == sql.ErrNoRows {
		return nil, nil, errors.New("token not found")
	}
	if err != nil {
		return nil, nil, err
	}
	if revoked {
		return nil, nil, ErrTokenRevoked
	}
	if time.Now().After(expiresAt) {
		return nil, nil, ErrTokenExpired
	}
	var did *int64
	if deviceID.Valid {
		did = &deviceID.Int64
	}
	return &userID, did, nil
}

func RevokeRefreshToken(db *sql.DB, token string) error {
	_, err := db.Exec("UPDATE refresh_tokens SET revoked=TRUE WHERE token=?", token)
	return err
}
