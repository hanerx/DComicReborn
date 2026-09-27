package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
)

var usernamePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$`)

const passwordCost = 12

func ValidateUsername(username string) (string, error) {
	username = strings.TrimSpace(username)
	if !usernamePattern.MatchString(username) {
		return "", errCode(CodeBadRequest, "username must be 3-64 characters using letters, numbers, '.', '_' or '-'")
	}
	return username, nil
}

func validateCredentials(username, password string) error {
	if _, err := ValidateUsername(username); err != nil {
		return err
	}
	if utf8.RuneCountInString(password) < 12 || len(password) > 72 {
		return errCode(CodeBadRequest, "password must be 12-72 bytes")
	}
	return nil
}

func hashPassword(password string) ([]byte, error) {
	if utf8.RuneCountInString(password) < 12 || len(password) > 72 {
		return nil, errCode(CodeBadRequest, "password must be 12-72 bytes")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), passwordCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}
	return hash, nil
}

func (s *Store) CreateUser(ctx context.Context, username, password string, admin bool) (User, error) {
	username = strings.TrimSpace(username)
	if err := validateCredentials(username, password); err != nil {
		return User{}, err
	}
	hash, err := hashPassword(password)
	if err != nil {
		return User{}, err
	}
	id, err := randomID()
	if err != nil {
		return User{}, err
	}
	now := time.Now().UTC()
	_, err = s.db.ExecContext(ctx, `INSERT INTO users(id, username, password_hash, is_admin, created_at, updated_at) VALUES(?,?,?,?,?,?)`,
		id, username, hash, admin, unixMilli(now), unixMilli(now))
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return User{}, errCode(CodeConflict, "username already exists")
		}
		return User{}, fmt.Errorf("create user: %w", err)
	}
	return User{ID: id, Username: username, Admin: admin, CreatedAt: now, UpdatedAt: now}, nil
}

func (s *Store) HasAdmin(ctx context.Context) (bool, error) {
	var exists bool
	if err := s.db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE is_admin = 1)`).Scan(&exists); err != nil {
		return false, fmt.Errorf("check administrators: %w", err)
	}
	return exists, nil
}

func (s *Store) BootstrapAdmin(ctx context.Context, username, password string) (User, error) {
	username = strings.TrimSpace(username)
	if err := validateCredentials(username, password); err != nil {
		return User{}, err
	}
	hash, err := hashPassword(password)
	if err != nil {
		return User{}, err
	}
	id, err := randomID()
	if err != nil {
		return User{}, err
	}
	now := time.Now().UTC()
	result, err := s.db.ExecContext(ctx, `INSERT INTO users(id, username, password_hash, is_admin, created_at, updated_at)
SELECT ?, ?, ?, 1, ?, ? WHERE NOT EXISTS(SELECT 1 FROM users WHERE is_admin = 1)`,
		id, username, hash, unixMilli(now), unixMilli(now))
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return User{}, errCode(CodeConflict, "username already exists")
		}
		return User{}, fmt.Errorf("bootstrap administrator: %w", err)
	}
	created, err := result.RowsAffected()
	if err != nil {
		return User{}, fmt.Errorf("read bootstrap result: %w", err)
	}
	if created != 1 {
		return User{}, errCode(CodeConflict, "an administrator already exists")
	}
	return User{ID: id, Username: username, Admin: true, CreatedAt: now, UpdatedAt: now}, nil
}

func (s *Store) authenticatePassword(ctx context.Context, username, password string, requireAdmin bool) (User, []byte, error) {
	var user User
	var hash []byte
	var admin, disabled bool
	var created, updated int64
	err := s.db.QueryRowContext(ctx, `SELECT id, username, password_hash, is_admin, disabled, created_at, updated_at FROM users WHERE username = ?`, strings.TrimSpace(username)).
		Scan(&user.ID, &user.Username, &hash, &admin, &disabled, &created, &updated)
	if errors.Is(err, sql.ErrNoRows) {
		// Keep missing-user attempts computationally comparable to bad passwords.
		_ = bcrypt.CompareHashAndPassword([]byte("$2a$12$2b2WgLK.mJAH6rMh0uoY5O1EQuWKOuK4cP6A7zXU8P6xEtFGrJxFe"), []byte(password))
		return User{}, nil, errCode(CodeUnauthorized, "invalid username or password")
	}
	if err != nil {
		return User{}, nil, fmt.Errorf("read user: %w", err)
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(password)) != nil {
		return User{}, nil, errCode(CodeUnauthorized, "invalid username or password")
	}
	if disabled {
		return User{}, nil, errCode(CodeUnauthorized, "account is disabled")
	}
	if requireAdmin && !admin {
		return User{}, nil, errCode(CodeForbidden, "administrator access required")
	}
	user.Admin = admin
	user.Disabled = disabled
	user.CreatedAt = time.UnixMilli(created).UTC()
	user.UpdatedAt = time.UnixMilli(updated).UTC()
	return user, hash, nil
}

func (s *Store) LoginDevice(ctx context.Context, username, password, deviceID, deviceName string, lifetime time.Duration) (string, User, error) {
	if len(deviceID) == 0 || len(deviceID) > 128 || len(deviceName) == 0 || len(deviceName) > 128 {
		return "", User{}, errCode(CodeBadRequest, "deviceId and deviceName must be 1-128 characters")
	}
	user, verifiedHash, err := s.authenticatePassword(ctx, username, password, false)
	if err != nil {
		return "", User{}, err
	}
	token, err := randomToken(32)
	if err != nil {
		return "", User{}, err
	}
	id, err := randomID()
	if err != nil {
		return "", User{}, err
	}
	now := time.Now().UTC()
	if lifetime <= 0 {
		lifetime = 90 * 24 * time.Hour
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", User{}, err
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(ctx, `UPDATE users SET updated_at=updated_at WHERE id=? AND password_hash=? AND disabled=0`, user.ID, verifiedHash)
	if err != nil {
		return "", User{}, fmt.Errorf("revalidate device login: %w", err)
	}
	if count, _ := result.RowsAffected(); count != 1 {
		return "", User{}, errCode(CodeUnauthorized, "credentials changed during login")
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO device_sessions(id, token_digest, user_id, device_id, device_name, created_at, last_seen_at, expires_at, revoked_at)
VALUES(?,?,?,?,?,?,?,?,NULL)
ON CONFLICT(user_id, device_id) DO UPDATE SET id=excluded.id, token_digest=excluded.token_digest, device_name=excluded.device_name,
 created_at=excluded.created_at, last_seen_at=excluded.last_seen_at, expires_at=excluded.expires_at, revoked_at=NULL`,
		id, tokenDigest(token), user.ID, deviceID, deviceName, unixMilli(now), unixMilli(now), unixMilli(now.Add(lifetime)))
	if err != nil {
		return "", User{}, fmt.Errorf("create device session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return "", User{}, fmt.Errorf("commit device session: %w", err)
	}
	return token, user, nil
}

func (s *Store) AuthenticateDevice(ctx context.Context, token string) (User, error) {
	if token == "" {
		return User{}, errCode(CodeUnauthorized, "bearer token required")
	}
	var user User
	var admin, disabled bool
	var created, updated, expires int64
	var sessionID string
	err := s.db.QueryRowContext(ctx, `SELECT u.id,u.username,u.is_admin,u.disabled,u.created_at,u.updated_at,d.expires_at,d.id
FROM device_sessions d JOIN users u ON u.id=d.user_id
WHERE d.token_digest=? AND d.revoked_at IS NULL`, tokenDigest(token)).
		Scan(&user.ID, &user.Username, &admin, &disabled, &created, &updated, &expires, &sessionID)
	if errors.Is(err, sql.ErrNoRows) || err == nil && (disabled || expires <= time.Now().UnixMilli()) {
		return User{}, errCode(CodeUnauthorized, "session is expired or revoked")
	}
	if err != nil {
		return User{}, fmt.Errorf("authenticate device: %w", err)
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE device_sessions SET last_seen_at=? WHERE id=?`, time.Now().UnixMilli(), sessionID)
	user.Admin = admin
	user.Disabled = disabled
	user.CreatedAt = time.UnixMilli(created).UTC()
	user.UpdatedAt = time.UnixMilli(updated).UTC()
	return user, nil
}

func (s *Store) RevokeDeviceToken(ctx context.Context, token string) error {
	result, err := s.db.ExecContext(ctx, `UPDATE device_sessions SET revoked_at=? WHERE token_digest=? AND revoked_at IS NULL`, time.Now().UnixMilli(), tokenDigest(token))
	if err != nil {
		return fmt.Errorf("revoke device session: %w", err)
	}
	if count, _ := result.RowsAffected(); count == 0 {
		return errCode(CodeUnauthorized, "session is expired or revoked")
	}
	return nil
}

func (s *Store) ChangePassword(ctx context.Context, userID, currentPassword, newPassword string) error {
	var hash []byte
	var disabled bool
	if err := s.db.QueryRowContext(ctx, `SELECT password_hash,disabled FROM users WHERE id=?`, userID).Scan(&hash, &disabled); err != nil {
		return errCode(CodeUnauthorized, "account is unavailable")
	}
	if disabled || bcrypt.CompareHashAndPassword(hash, []byte(currentPassword)) != nil {
		return errCode(CodeUnauthorized, "current password is incorrect")
	}
	newHash, err := hashPassword(newPassword)
	if err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	now := time.Now().UnixMilli()
	result, err := tx.ExecContext(ctx, `UPDATE users SET password_hash=?,updated_at=? WHERE id=? AND password_hash=? AND disabled=0`, newHash, now, userID, hash)
	if err != nil {
		return err
	}
	if count, _ := result.RowsAffected(); count != 1 {
		return errCode(CodeUnauthorized, "credentials changed during password update")
	}
	if _, err := tx.ExecContext(ctx, `UPDATE device_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE admin_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) LoginAdmin(ctx context.Context, username, password string, lifetime time.Duration) (token, csrf string, user User, err error) {
	user, verifiedHash, err := s.authenticatePassword(ctx, username, password, true)
	if err != nil {
		return "", "", User{}, err
	}
	token, err = randomToken(32)
	if err != nil {
		return "", "", User{}, err
	}
	csrf, err = randomToken(24)
	if err != nil {
		return "", "", User{}, err
	}
	id, err := randomID()
	if err != nil {
		return "", "", User{}, err
	}
	if lifetime <= 0 {
		lifetime = 12 * time.Hour
	}
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", "", User{}, err
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(ctx, `UPDATE users SET updated_at=updated_at WHERE id=? AND password_hash=? AND disabled=0 AND is_admin=1`, user.ID, verifiedHash)
	if err != nil {
		return "", "", User{}, fmt.Errorf("revalidate administrator login: %w", err)
	}
	if count, _ := result.RowsAffected(); count != 1 {
		return "", "", User{}, errCode(CodeUnauthorized, "credentials changed during login")
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO admin_sessions(id,token_digest,csrf_token,user_id,created_at,last_seen_at,expires_at) VALUES(?,?,?,?,?,?,?)`,
		id, tokenDigest(token), csrf, user.ID, unixMilli(now), unixMilli(now), unixMilli(now.Add(lifetime)))
	if err != nil {
		return "", "", User{}, fmt.Errorf("create admin session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return "", "", User{}, fmt.Errorf("commit admin session: %w", err)
	}
	return token, csrf, user, nil
}

func (s *Store) AuthenticateAdmin(ctx context.Context, token string) (User, string, error) {
	var user User
	var csrf, sessionID string
	var admin, disabled bool
	var created, updated, expires int64
	err := s.db.QueryRowContext(ctx, `SELECT u.id,u.username,u.is_admin,u.disabled,u.created_at,u.updated_at,a.csrf_token,a.expires_at,a.id
FROM admin_sessions a JOIN users u ON u.id=a.user_id WHERE a.token_digest=? AND a.revoked_at IS NULL`, tokenDigest(token)).
		Scan(&user.ID, &user.Username, &admin, &disabled, &created, &updated, &csrf, &expires, &sessionID)
	if errors.Is(err, sql.ErrNoRows) || err == nil && (disabled || !admin || expires <= time.Now().UnixMilli()) {
		return User{}, "", errCode(CodeUnauthorized, "administrator session is expired or revoked")
	}
	if err != nil {
		return User{}, "", fmt.Errorf("authenticate administrator: %w", err)
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE admin_sessions SET last_seen_at=? WHERE id=?`, time.Now().UnixMilli(), sessionID)
	user.Admin = admin
	user.CreatedAt = time.UnixMilli(created).UTC()
	user.UpdatedAt = time.UnixMilli(updated).UTC()
	return user, csrf, nil
}

func (s *Store) LogoutAdmin(ctx context.Context, token string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE admin_sessions SET revoked_at=? WHERE token_digest=?`, time.Now().UnixMilli(), tokenDigest(token))
	return err
}
