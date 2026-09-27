package store

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

func Open(path string) (*Store, error) {
	if strings.TrimSpace(path) == "" {
		return nil, fmt.Errorf("database path is required")
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve database path: %w", err)
	}
	db, err := sql.Open("sqlite", abs)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	db.SetMaxOpenConns(1)
	for _, pragma := range []string{
		"PRAGMA foreign_keys = ON",
		"PRAGMA journal_mode = WAL",
		"PRAGMA synchronous = FULL",
		"PRAGMA busy_timeout = 5000",
	} {
		if _, err := db.Exec(pragma); err != nil {
			db.Close()
			return nil, fmt.Errorf("configure sqlite: %w", err)
		}
	}
	if err := migrate(db); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

func migrate(db *sql.DB) error {
	const schema = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash BLOB NOT NULL,
  is_admin INTEGER NOT NULL DEFAULT 0,
  disabled INTEGER NOT NULL DEFAULT 0,
  sync_seq INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
) STRICT;
CREATE TABLE IF NOT EXISTS device_sessions (
  id TEXT PRIMARY KEY,
  token_digest BLOB NOT NULL UNIQUE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  UNIQUE(user_id, device_id)
) STRICT;
CREATE INDEX IF NOT EXISTS device_sessions_user ON device_sessions(user_id);
CREATE TABLE IF NOT EXISTS admin_sessions (
  id TEXT PRIMARY KEY,
  token_digest BLOB NOT NULL UNIQUE,
  csrf_token TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER
) STRICT;
CREATE INDEX IF NOT EXISTS admin_sessions_user ON admin_sessions(user_id);
CREATE TABLE IF NOT EXISTS records (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  record_key TEXT NOT NULL,
  value_json BLOB,
  deleted INTEGER NOT NULL,
  wall INTEGER NOT NULL,
  logical INTEGER NOT NULL,
  device TEXT NOT NULL,
  uncertain INTEGER NOT NULL,
  base_wall INTEGER,
  base_logical INTEGER,
  base_device TEXT,
  PRIMARY KEY(user_id, category, record_key)
) STRICT;
CREATE TABLE IF NOT EXISTS change_log (
  seq INTEGER NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  record_key TEXT NOT NULL,
  value_json BLOB,
  deleted INTEGER NOT NULL,
  wall INTEGER NOT NULL,
  logical INTEGER NOT NULL,
  device TEXT NOT NULL,
  uncertain INTEGER NOT NULL,
  base_wall INTEGER,
  base_logical INTEGER,
  base_device TEXT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(user_id, seq)
) STRICT;
CREATE INDEX IF NOT EXISTS change_log_user_seq ON change_log(user_id, seq);
CREATE INDEX IF NOT EXISTS change_log_user_category_seq ON change_log(user_id, category, seq);
CREATE TABLE IF NOT EXISTS version_history (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  record_key TEXT NOT NULL,
  wall INTEGER NOT NULL,
  logical INTEGER NOT NULL,
  device TEXT NOT NULL,
  content_hash BLOB NOT NULL,
  outcome TEXT NOT NULL,
  PRIMARY KEY(user_id, category, record_key, wall, logical, device)
) STRICT;
CREATE TABLE IF NOT EXISTS conflicts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  record_key TEXT NOT NULL,
  local_json BLOB NOT NULL,
  remote_json BLOB NOT NULL,
  local_wall INTEGER NOT NULL,
  local_logical INTEGER NOT NULL,
  local_device TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(user_id, category, record_key, local_wall, local_logical, local_device)
) STRICT;
CREATE INDEX IF NOT EXISTS conflicts_user ON conflicts(user_id, created_at);
CREATE TABLE IF NOT EXISTS conflict_resolutions (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  record_key TEXT NOT NULL,
  rejected_wall INTEGER NOT NULL,
  rejected_logical INTEGER NOT NULL,
  rejected_device TEXT NOT NULL,
  resolution_wall INTEGER NOT NULL,
  resolution_logical INTEGER NOT NULL,
  resolution_device TEXT NOT NULL,
  content_hash BLOB NOT NULL,
  canonical_json BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(user_id, category, record_key, rejected_wall, rejected_logical, rejected_device)
) STRICT;
`
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("migrate database: %w", err)
	}
	return nil
}

func randomToken(bytes int) (string, error) {
	buf := make([]byte, bytes)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

func randomID() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func tokenDigest(token string) []byte {
	digest := sha256.Sum256([]byte(token))
	return digest[:]
}

func unixMilli(t time.Time) int64 { return t.UTC().UnixMilli() }
