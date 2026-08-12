package db

import (
	"database/sql"
	"fmt"
	"os"
	"strings"

	_ "modernc.org/sqlite"
)

var Global *sql.DB

func Init(dbPath string) (*sql.DB, error) {
	var err error
	Global, err = sql.Open("sqlite", dbPath+"?_journal_mode=WAL&_busy_timeout=5000&_foreign_keys=on")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	Global.SetMaxOpenConns(1)
	Global.SetMaxIdleConns(1)

	if err := migrate(Global); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return Global, nil
}

func InitMemory() (*sql.DB, error) {
	var err error
	Global, err = sql.Open("sqlite", ":memory:?_foreign_keys=on")
	if err != nil {
		return nil, err
	}
	Global.SetMaxOpenConns(1)
	if err := migrate(Global); err != nil {
		return nil, err
	}
	return Global, nil
}

func migrate(db *sql.DB) error {
	// Try multiple paths for the migration file
	paths := []string{
		"migrations/001_init.sql",
		"backend/migrations/001_init.sql",
		"/app/migrations/001_init.sql",
	}
	var content []byte
	var err error
	for _, p := range paths {
		content, err = os.ReadFile(p)
		if err == nil {
			break
		}
	}
	if content == nil {
		return fmt.Errorf("read migration: %w", err)
	}
	statements := strings.Split(string(content), ";")
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" {
			continue
		}
		if _, err := db.Exec(stmt); err != nil {
			return fmt.Errorf("exec migration: %s: %w", stmt[:min(80, len(stmt))], err)
		}
	}
	return nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
