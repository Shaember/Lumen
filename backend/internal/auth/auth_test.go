package auth

import (
	"testing"
	"time"
)

func TestHashAndVerify(t *testing.T) {
	hash, err := HashPassword("mypassword")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if !VerifyPassword("mypassword", hash) {
		t.Error("VerifyPassword should return true for correct password")
	}
	if VerifyPassword("wrongpassword", hash) {
		t.Error("VerifyPassword should return false for wrong password")
	}
}

func TestJWTGenerateAndValidate(t *testing.T) {
	secret := "test-secret-key"
	ttl := 15 * time.Minute

	token, err := GenerateAccessToken(1, "testuser", true, secret, ttl)
	if err != nil {
		t.Fatalf("GenerateAccessToken: %v", err)
	}
	if token == "" {
		t.Fatal("token should not be empty")
	}

	claims, err := ValidateAccessToken(token, secret)
	if err != nil {
		t.Fatalf("ValidateAccessToken: %v", err)
	}
	if claims.UserID != 1 {
		t.Errorf("expected user_id 1, got %d", claims.UserID)
	}
	if claims.Username != "testuser" {
		t.Errorf("expected username testuser, got %s", claims.Username)
	}
	if !claims.IsAdmin {
		t.Error("expected is_admin true")
	}
}

func TestJWTValidationFailsWithWrongSecret(t *testing.T) {
	token, _ := GenerateAccessToken(1, "user", false, "secret1", 15*time.Minute)
	_, err := ValidateAccessToken(token, "wrong-secret")
	if err == nil {
		t.Error("should fail with wrong secret")
	}
}

func TestRefreshToken(t *testing.T) {
	token, err := GenerateRefreshToken()
	if err != nil {
		t.Fatalf("GenerateRefreshToken: %v", err)
	}
	if len(token) != 64 {
		t.Errorf("expected 64 hex chars, got %d", len(token))
	}
}
