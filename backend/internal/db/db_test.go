package db

import (
	"testing"
	"os"
)

func TestMigration(t *testing.T) {
	// Change to project root so migration file can be found
	origDir, _ := os.Getwd()
	defer os.Chdir(origDir)
	os.Chdir("../..")

	db, err := InitMemory()
	if err != nil {
		t.Fatalf("InitMemory: %v", err)
	}
	defer db.Close()

	// Verify tables exist
	tables := []string{"users", "photos", "albums", "album_photos", "devices", "refresh_tokens"}
	for _, table := range tables {
		var name string
		err := db.QueryRow("SELECT name FROM sqlite_master WHERE type='table' AND name=?", table).Scan(&name)
		if err != nil {
			t.Errorf("table %s not found: %v", table, err)
		}
	}

	// Verify we can insert and query a user
	_, err = db.Exec("INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, ?)", "testuser", "hash123", true)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}

	var username string
	err = db.QueryRow("SELECT username FROM users WHERE username='testuser'").Scan(&username)
	if err != nil {
		t.Fatalf("query user: %v", err)
	}
	if username != "testuser" {
		t.Errorf("expected testuser, got %s", username)
	}
}
