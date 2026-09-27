package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

func (s *Store) Stats(ctx context.Context) (AdminStats, error) {
	var stats AdminStats
	err := s.db.QueryRowContext(ctx, `SELECT
 (SELECT COUNT(*) FROM users),
 (SELECT COUNT(*) FROM users WHERE disabled=0),
 (SELECT COUNT(*) FROM device_sessions WHERE revoked_at IS NULL AND expires_at>?),
 (SELECT COUNT(*) FROM records),
 (SELECT COUNT(*) FROM conflicts)`, time.Now().UnixMilli()).Scan(&stats.Users, &stats.Enabled, &stats.Devices, &stats.Records, &stats.Conflicts)
	return stats, err
}

func (s *Store) ListUsers(ctx context.Context) ([]UserSummary, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT u.id,u.username,u.is_admin,u.disabled,u.created_at,u.updated_at,
 (SELECT COUNT(*) FROM device_sessions d WHERE d.user_id=u.id AND d.revoked_at IS NULL AND d.expires_at>?),
 (SELECT COUNT(*) FROM records r WHERE r.user_id=u.id),
 (SELECT COUNT(*) FROM conflicts c WHERE c.user_id=u.id),
 (SELECT COALESCE(MAX(seq),0) FROM change_log l WHERE l.user_id=u.id)
 FROM users u ORDER BY u.username COLLATE NOCASE`, time.Now().UnixMilli())
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	users := make([]UserSummary, 0)
	for rows.Next() {
		var user UserSummary
		var created, updated int64
		if err := rows.Scan(&user.ID, &user.Username, &user.Admin, &user.Disabled, &created, &updated, &user.DeviceCount, &user.RecordCount, &user.ConflictCount, &user.LatestCursor); err != nil {
			return nil, err
		}
		user.CreatedAt, user.UpdatedAt = time.UnixMilli(created).UTC(), time.UnixMilli(updated).UTC()
		users = append(users, user)
	}
	return users, rows.Err()
}

func (s *Store) GetUser(ctx context.Context, userID string) (UserSummary, error) {
	var user UserSummary
	var created, updated int64
	err := s.db.QueryRowContext(ctx, `SELECT u.id,u.username,u.is_admin,u.disabled,u.created_at,u.updated_at,
 (SELECT COUNT(*) FROM device_sessions d WHERE d.user_id=u.id AND d.revoked_at IS NULL AND d.expires_at>?),
 (SELECT COUNT(*) FROM records r WHERE r.user_id=u.id),
 (SELECT COUNT(*) FROM conflicts c WHERE c.user_id=u.id),
 (SELECT COALESCE(MAX(seq),0) FROM change_log l WHERE l.user_id=u.id)
 FROM users u WHERE u.id=?`, time.Now().UnixMilli(), userID).
		Scan(&user.ID, &user.Username, &user.Admin, &user.Disabled, &created, &updated, &user.DeviceCount, &user.RecordCount, &user.ConflictCount, &user.LatestCursor)
	if errors.Is(err, sql.ErrNoRows) {
		return UserSummary{}, errCode(CodeNotFound, "user not found")
	}
	if err != nil {
		return UserSummary{}, err
	}
	user.CreatedAt, user.UpdatedAt = time.UnixMilli(created).UTC(), time.UnixMilli(updated).UTC()
	return user, nil
}

func (s *Store) SetUserDisabled(ctx context.Context, userID string, disabled bool) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(ctx, `UPDATE users SET disabled=?,updated_at=? WHERE id=?`, disabled, time.Now().UnixMilli(), userID)
	if err != nil {
		return err
	}
	if count, _ := result.RowsAffected(); count == 0 {
		return errCode(CodeNotFound, "user not found")
	}
	if disabled {
		now := time.Now().UnixMilli()
		if _, err := tx.ExecContext(ctx, `UPDATE device_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE admin_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) AdminResetPassword(ctx context.Context, userID, password string) error {
	hash, err := hashPassword(password)
	if err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	now := time.Now().UnixMilli()
	result, err := tx.ExecContext(ctx, `UPDATE users SET password_hash=?,updated_at=? WHERE id=?`, hash, now, userID)
	if err != nil {
		return err
	}
	if count, _ := result.RowsAffected(); count == 0 {
		return errCode(CodeNotFound, "user not found")
	}
	if _, err := tx.ExecContext(ctx, `UPDATE device_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE admin_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL`, now, userID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) ListDevices(ctx context.Context, userID string) ([]Device, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id,device_id,device_name,created_at,last_seen_at,expires_at,revoked_at IS NOT NULL FROM device_sessions WHERE user_id=? ORDER BY last_seen_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	devices := make([]Device, 0)
	for rows.Next() {
		var device Device
		var created, seen, expires int64
		if err := rows.Scan(&device.ID, &device.DeviceID, &device.Name, &created, &seen, &expires, &device.Revoked); err != nil {
			return nil, err
		}
		device.CreatedAt, device.LastSeen, device.ExpiresAt = time.UnixMilli(created).UTC(), time.UnixMilli(seen).UTC(), time.UnixMilli(expires).UTC()
		devices = append(devices, device)
	}
	return devices, rows.Err()
}

func (s *Store) RevokeDevice(ctx context.Context, userID, sessionID string) error {
	result, err := s.db.ExecContext(ctx, `UPDATE device_sessions SET revoked_at=? WHERE id=? AND user_id=? AND revoked_at IS NULL`, time.Now().UnixMilli(), sessionID, userID)
	if err != nil {
		return fmt.Errorf("revoke device: %w", err)
	}
	if count, _ := result.RowsAffected(); count == 0 {
		return errCode(CodeNotFound, "active device not found")
	}
	return nil
}
