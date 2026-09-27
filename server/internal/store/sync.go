package store

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"
)

const (
	maxChanges     = 200
	maxPullRecords = 500
	maxKeyBytes    = 4096
	maxValueBytes  = 1024 * 1024
)

var validCategories = map[string]struct{}{
	"history": {}, "bindings": {}, "chapterRules": {}, "settings": {}, "sourceSettings": {}, "credentials": {},
}

func ValidateCategories(categories []string) error {
	if len(categories) == 0 || len(categories) > len(validCategories) {
		return errCode(CodeBadRequest, "categories must contain 1-%d values", len(validCategories))
	}
	seen := make(map[string]struct{}, len(categories))
	for _, category := range categories {
		if _, ok := validCategories[category]; !ok {
			return errCode(CodeBadRequest, "unknown category %q", category)
		}
		if _, exists := seen[category]; exists {
			return errCode(CodeBadRequest, "duplicate category %q", category)
		}
		seen[category] = struct{}{}
	}
	return nil
}

func normalizeRecord(record SyncRecord, now time.Time) (SyncRecord, []byte, error) {
	if _, ok := validCategories[record.Category]; !ok {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "unknown category %q", record.Category)
	}
	if len(record.Key) == 0 || len(record.Key) > maxKeyBytes {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "record key must be 1-%d bytes", maxKeyBytes)
	}
	if record.Version.Logical < 0 || len(record.Version.Device) == 0 || len(record.Version.Device) > 128 {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "invalid record version")
	}
	if record.Version.Wall < 0 || record.Version.Wall == 0 && !record.Uncertain {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "wall=0 requires an uncertain record")
	}
	if record.Version.Wall > now.Add(5*time.Minute).UnixMilli() {
		return SyncRecord{}, nil, errCode(CodeFutureClock, "record version is more than five minutes in the future")
	}
	if record.BaseVersion != nil && (record.BaseVersion.Wall < 0 || record.BaseVersion.Logical < 0 || len(record.BaseVersion.Device) == 0 || len(record.BaseVersion.Device) > 128) {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "invalid baseVersion")
	}
	if record.BaseVersion != nil && record.Version.Compare(*record.BaseVersion) <= 0 {
		return SyncRecord{}, nil, errCode(CodeBadRequest, "record version must advance beyond baseVersion")
	}
	if record.Deleted {
		if len(record.Value) != 0 && !bytes.Equal(bytes.TrimSpace(record.Value), []byte("null")) {
			return SyncRecord{}, nil, errCode(CodeBadRequest, "deleted records must have a null value")
		}
		record.Value = nil
	} else {
		if len(record.Value) == 0 || len(record.Value) > maxValueBytes {
			return SyncRecord{}, nil, errCode(CodeBadRequest, "record value must be a JSON object no larger than %d bytes", maxValueBytes)
		}
		var value map[string]any
		decoder := json.NewDecoder(bytes.NewReader(record.Value))
		decoder.UseNumber()
		if err := decoder.Decode(&value); err != nil || value == nil {
			return SyncRecord{}, nil, errCode(CodeBadRequest, "record value must be a JSON object")
		}
		if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
			return SyncRecord{}, nil, errCode(CodeBadRequest, "record value must contain one JSON object")
		}
		normalized, err := json.Marshal(value)
		if err != nil {
			return SyncRecord{}, nil, errCode(CodeBadRequest, "invalid record value")
		}
		record.Value = normalized
	}
	content, err := json.Marshal(struct {
		Value       json.RawMessage `json:"value"`
		Deleted     bool            `json:"deleted"`
		Uncertain   bool            `json:"uncertain"`
		BaseVersion *SyncVersion    `json:"baseVersion"`
	}{record.Value, record.Deleted, record.Uncertain, record.BaseVersion})
	if err != nil {
		return SyncRecord{}, nil, err
	}
	hash := sha256.Sum256(content)
	return record, hash[:], nil
}

func (s *Store) Sync(ctx context.Context, userID string, request SyncRequest, now time.Time) (SyncResponse, error) {
	if request.Cursor < 0 {
		return SyncResponse{}, errCode(CodeBadRequest, "cursor cannot be negative")
	}
	if err := ValidateCategories(request.Categories); err != nil {
		return SyncResponse{}, err
	}
	if len(request.Changes) > maxChanges {
		return SyncResponse{}, errCode(CodeBadRequest, "changes cannot contain more than %d records", maxChanges)
	}
	allowed := make(map[string]struct{}, len(request.Categories))
	for _, category := range request.Categories {
		allowed[category] = struct{}{}
	}
	type normalizedChange struct {
		record SyncRecord
		hash   []byte
	}
	changes := make([]normalizedChange, 0, len(request.Changes))
	for _, record := range request.Changes {
		if _, ok := allowed[record.Category]; !ok {
			return SyncResponse{}, errCode(CodeBadRequest, "change category %q was not requested", record.Category)
		}
		normalized, hash, err := normalizeRecord(record, now)
		if err != nil {
			return SyncResponse{}, err
		}
		changes = append(changes, normalizedChange{normalized, hash})
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return SyncResponse{}, fmt.Errorf("begin sync: %w", err)
	}
	defer tx.Rollback()
	response := SyncResponse{Records: make([]SyncRecord, 0), Results: make([]SyncResult, 0, len(changes)), ServerTime: now.UnixMilli()}
	for _, change := range changes {
		result, err := applyIncoming(ctx, tx, userID, change.record, change.hash, now)
		if err != nil {
			return SyncResponse{}, err
		}
		response.Results = append(response.Results, result)
	}
	records, cursor, hasMore, err := pullChanges(ctx, tx, userID, request.Cursor, request.Categories)
	if err != nil {
		return SyncResponse{}, err
	}
	response.Records = records
	response.Cursor = cursor
	response.HasMore = hasMore
	if err := tx.Commit(); err != nil {
		return SyncResponse{}, fmt.Errorf("commit sync: %w", err)
	}
	return response, nil
}

func applyIncoming(ctx context.Context, tx *sql.Tx, userID string, incoming SyncRecord, hash []byte, now time.Time) (SyncResult, error) {
	result := SyncResult{Category: incoming.Category, Key: incoming.Key}
	var existingHash []byte
	var outcome string
	err := tx.QueryRowContext(ctx, `SELECT content_hash,outcome FROM version_history WHERE user_id=? AND category=? AND record_key=? AND wall=? AND logical=? AND device=?`,
		userID, incoming.Category, incoming.Key, incoming.Version.Wall, incoming.Version.Logical, incoming.Version.Device).Scan(&existingHash, &outcome)
	if err == nil {
		if !bytes.Equal(existingHash, hash) {
			return SyncResult{}, errCode(CodeVersionReuse, "record version was reused with different content")
		}
		canonical, loadErr := loadRecord(ctx, tx, userID, incoming.Category, incoming.Key)
		if loadErr != nil {
			return SyncResult{}, loadErr
		}
		result.Record = canonical
		if outcome == "conflict" {
			var exists int
			conflictErr := tx.QueryRowContext(ctx, `SELECT 1 FROM conflicts WHERE user_id=? AND category=? AND record_key=? AND local_wall=? AND local_logical=? AND local_device=?`,
				userID, incoming.Category, incoming.Key, incoming.Version.Wall, incoming.Version.Logical, incoming.Version.Device).Scan(&exists)
			if conflictErr == nil {
				result.Status = "conflict"
			} else if errors.Is(conflictErr, sql.ErrNoRows) {
				result.Status = "superseded"
			} else {
				return SyncResult{}, fmt.Errorf("check conflict candidate: %w", conflictErr)
			}
		} else if canonical.Version.Equal(incoming.Version) {
			result.Status = "accepted"
		} else {
			result.Status = "superseded"
		}
		return result, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return SyncResult{}, fmt.Errorf("check record version: %w", err)
	}

	current, err := loadRecord(ctx, tx, userID, incoming.Category, incoming.Key)
	if errors.Is(err, sql.ErrNoRows) {
		if err := saveCanonical(ctx, tx, userID, incoming, now); err != nil {
			return SyncResult{}, err
		}
		if err := saveVersion(ctx, tx, userID, incoming, hash, "accepted"); err != nil {
			return SyncResult{}, err
		}
		result.Status, result.Record = "accepted", incoming
		return result, nil
	}
	if err != nil {
		return SyncResult{}, err
	}

	causal := incoming.BaseVersion != nil && incoming.BaseVersion.Equal(current.Version)
	samePayload := incoming.Deleted == current.Deleted && bytes.Equal(incoming.Value, current.Value)
	if causal || samePayload && incoming.Version.Compare(current.Version) > 0 || !incoming.Uncertain && !current.Uncertain && incoming.Version.Compare(current.Version) > 0 {
		if err := saveCanonical(ctx, tx, userID, incoming, now); err != nil {
			return SyncResult{}, err
		}
		if err := saveVersion(ctx, tx, userID, incoming, hash, "accepted"); err != nil {
			return SyncResult{}, err
		}
		result.Status, result.Record = "accepted", incoming
		return result, nil
	}
	if !samePayload && (incoming.Uncertain || current.Uncertain) {
		localJSON, _ := json.Marshal(incoming)
		remoteJSON, _ := json.Marshal(current)
		id, idErr := randomID()
		if idErr != nil {
			return SyncResult{}, idErr
		}
		_, err := tx.ExecContext(ctx, `INSERT INTO conflicts(id,user_id,category,record_key,local_json,remote_json,local_wall,local_logical,local_device,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)`,
			id, userID, incoming.Category, incoming.Key, localJSON, remoteJSON, incoming.Version.Wall, incoming.Version.Logical, incoming.Version.Device, now.UnixMilli())
		if err != nil {
			return SyncResult{}, fmt.Errorf("save conflict: %w", err)
		}
		if err := saveVersion(ctx, tx, userID, incoming, hash, "conflict"); err != nil {
			return SyncResult{}, err
		}
		result.Status, result.Record = "conflict", current
		return result, nil
	}
	if err := saveVersion(ctx, tx, userID, incoming, hash, "superseded"); err != nil {
		return SyncResult{}, err
	}
	result.Status, result.Record = "superseded", current
	return result, nil
}

func saveVersion(ctx context.Context, tx *sql.Tx, userID string, record SyncRecord, hash []byte, outcome string) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO version_history(user_id,category,record_key,wall,logical,device,content_hash,outcome) VALUES(?,?,?,?,?,?,?,?)`,
		userID, record.Category, record.Key, record.Version.Wall, record.Version.Logical, record.Version.Device, hash, outcome)
	return err
}

func saveCanonical(ctx context.Context, tx *sql.Tx, userID string, record SyncRecord, now time.Time) error {
	var baseWall, baseLogical any
	var baseDevice any
	if record.BaseVersion != nil {
		baseWall, baseLogical, baseDevice = record.BaseVersion.Wall, record.BaseVersion.Logical, record.BaseVersion.Device
	}
	_, err := tx.ExecContext(ctx, `INSERT INTO records(user_id,category,record_key,value_json,deleted,wall,logical,device,uncertain,base_wall,base_logical,base_device)
VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id,category,record_key) DO UPDATE SET value_json=excluded.value_json,deleted=excluded.deleted,
wall=excluded.wall,logical=excluded.logical,device=excluded.device,uncertain=excluded.uncertain,base_wall=excluded.base_wall,base_logical=excluded.base_logical,base_device=excluded.base_device`,
		userID, record.Category, record.Key, nullValue(record.Value), record.Deleted, record.Version.Wall, record.Version.Logical, record.Version.Device, record.Uncertain, baseWall, baseLogical, baseDevice)
	if err != nil {
		return fmt.Errorf("save record: %w", err)
	}
	remoteJSON, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("encode canonical record: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `UPDATE conflicts SET remote_json=? WHERE user_id=? AND category=? AND record_key=?`,
		remoteJSON, userID, record.Category, record.Key); err != nil {
		return fmt.Errorf("refresh conflict canonical: %w", err)
	}
	var sequence int64
	if err := tx.QueryRowContext(ctx, `UPDATE users SET sync_seq=sync_seq+1 WHERE id=? RETURNING sync_seq`, userID).Scan(&sequence); err != nil {
		return fmt.Errorf("advance user cursor: %w", err)
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO change_log(seq,user_id,category,record_key,value_json,deleted,wall,logical,device,uncertain,base_wall,base_logical,base_device,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		sequence, userID, record.Category, record.Key, nullValue(record.Value), record.Deleted, record.Version.Wall, record.Version.Logical, record.Version.Device, record.Uncertain, baseWall, baseLogical, baseDevice, now.UnixMilli())
	if err != nil {
		return fmt.Errorf("append change log: %w", err)
	}
	return nil
}

func nullValue(value json.RawMessage) any {
	if len(value) == 0 {
		return nil
	}
	return []byte(value)
}

type scanner interface{ Scan(...any) error }

func scanRecord(row scanner) (SyncRecord, error) {
	var record SyncRecord
	var value []byte
	var deleted, uncertain bool
	var baseWall, baseLogical sql.NullInt64
	var baseDevice sql.NullString
	err := row.Scan(&record.Category, &record.Key, &value, &deleted, &record.Version.Wall, &record.Version.Logical, &record.Version.Device, &uncertain, &baseWall, &baseLogical, &baseDevice)
	if err != nil {
		return SyncRecord{}, err
	}
	record.Value = value
	record.Deleted = deleted
	record.Uncertain = uncertain
	if baseWall.Valid && baseLogical.Valid && baseDevice.Valid {
		record.BaseVersion = &SyncVersion{Wall: baseWall.Int64, Logical: baseLogical.Int64, Device: baseDevice.String}
	}
	return record, nil
}

func loadRecord(ctx context.Context, tx *sql.Tx, userID, category, key string) (SyncRecord, error) {
	return scanRecord(tx.QueryRowContext(ctx, `SELECT category,record_key,value_json,deleted,wall,logical,device,uncertain,base_wall,base_logical,base_device FROM records WHERE user_id=? AND category=? AND record_key=?`, userID, category, key))
}

func pullChanges(ctx context.Context, tx *sql.Tx, userID string, cursor int64, categories []string) ([]SyncRecord, int64, bool, error) {
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(categories)), ",")
	args := make([]any, 0, len(categories)+2)
	args = append(args, userID, cursor)
	for _, category := range categories {
		args = append(args, category)
	}
	args = append(args, maxPullRecords+1)
	query := `SELECT seq,category,record_key,value_json,deleted,wall,logical,device,uncertain,base_wall,base_logical,base_device FROM change_log WHERE user_id=? AND seq>? AND category IN (` + placeholders + `) ORDER BY seq LIMIT ?`
	rows, err := tx.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, cursor, false, fmt.Errorf("pull changes: %w", err)
	}
	defer rows.Close()
	records := make([]SyncRecord, 0, maxPullRecords)
	last := cursor
	hasMore := false
	for rows.Next() {
		var seq int64
		var record SyncRecord
		var value []byte
		var deleted, uncertain bool
		var baseWall, baseLogical sql.NullInt64
		var baseDevice sql.NullString
		if err := rows.Scan(&seq, &record.Category, &record.Key, &value, &deleted, &record.Version.Wall, &record.Version.Logical, &record.Version.Device, &uncertain, &baseWall, &baseLogical, &baseDevice); err != nil {
			return nil, cursor, false, err
		}
		if len(records) == maxPullRecords {
			hasMore = true
			break
		}
		record.Value, record.Deleted, record.Uncertain = value, deleted, uncertain
		if baseWall.Valid && baseLogical.Valid && baseDevice.Valid {
			record.BaseVersion = &SyncVersion{Wall: baseWall.Int64, Logical: baseLogical.Int64, Device: baseDevice.String}
		}
		records = append(records, record)
		last = seq
	}
	if err := rows.Err(); err != nil {
		return nil, cursor, false, err
	}
	if !hasMore {
		if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(seq),0) FROM change_log WHERE user_id=?`, userID).Scan(&last); err != nil {
			return nil, cursor, false, err
		}
		if last < cursor {
			last = cursor
		}
	}
	return records, last, hasMore, nil
}

func (s *Store) LatestCursor(ctx context.Context, userID string) (int64, error) {
	var cursor int64
	err := s.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(seq),0) FROM change_log WHERE user_id=?`, userID).Scan(&cursor)
	return cursor, err
}

func (s *Store) ListConflicts(ctx context.Context, userID string) ([]Conflict, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id,local_json,remote_json FROM conflicts WHERE user_id=? ORDER BY created_at,id`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	conflicts := make([]Conflict, 0)
	for rows.Next() {
		var conflict Conflict
		var local, remote []byte
		if err := rows.Scan(&conflict.ID, &local, &remote); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(local, &conflict.Local); err != nil {
			return nil, fmt.Errorf("decode local conflict: %w", err)
		}
		if err := json.Unmarshal(remote, &conflict.Remote); err != nil {
			return nil, fmt.Errorf("decode remote conflict: %w", err)
		}
		conflicts = append(conflicts, conflict)
	}
	return conflicts, rows.Err()
}

func (s *Store) ResolveConflict(ctx context.Context, userID string, record SyncRecord, rejected SyncVersion, now time.Time) (SyncRecord, error) {
	normalized, hash, err := normalizeRecord(record, now)
	if err != nil {
		return SyncRecord{}, err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return SyncRecord{}, err
	}
	defer tx.Rollback()
	var receiptWall, receiptLogical int64
	var receiptDevice string
	var receiptHash, receiptCanonical []byte
	receiptErr := tx.QueryRowContext(ctx, `SELECT resolution_wall,resolution_logical,resolution_device,content_hash,canonical_json
FROM conflict_resolutions WHERE user_id=? AND category=? AND record_key=? AND rejected_wall=? AND rejected_logical=? AND rejected_device=?`,
		userID, normalized.Category, normalized.Key, rejected.Wall, rejected.Logical, rejected.Device).
		Scan(&receiptWall, &receiptLogical, &receiptDevice, &receiptHash, &receiptCanonical)
	if receiptErr == nil {
		receiptVersion := SyncVersion{Wall: receiptWall, Logical: receiptLogical, Device: receiptDevice}
		if !receiptVersion.Equal(normalized.Version) || !bytes.Equal(receiptHash, hash) {
			return SyncRecord{}, errCode(CodeConflict, "conflict was already resolved with another record")
		}
		var canonical SyncRecord
		if err := json.Unmarshal(receiptCanonical, &canonical); err != nil {
			return SyncRecord{}, fmt.Errorf("decode resolution receipt: %w", err)
		}
		return canonical, nil
	}
	if !errors.Is(receiptErr, sql.ErrNoRows) {
		return SyncRecord{}, fmt.Errorf("check resolution receipt: %w", receiptErr)
	}
	var conflictID string
	err = tx.QueryRowContext(ctx, `SELECT id FROM conflicts WHERE user_id=? AND category=? AND record_key=? AND local_wall=? AND local_logical=? AND local_device=?`,
		userID, record.Category, record.Key, rejected.Wall, rejected.Logical, rejected.Device).Scan(&conflictID)
	if errors.Is(err, sql.ErrNoRows) {
		return SyncRecord{}, errCode(CodeNotFound, "conflict candidate not found")
	}
	if err != nil {
		return SyncRecord{}, err
	}
	current, err := loadRecord(ctx, tx, userID, record.Category, record.Key)
	if err != nil {
		return SyncRecord{}, err
	}
	if record.BaseVersion == nil || !record.BaseVersion.Equal(current.Version) {
		return SyncRecord{}, errCode(CodeConflict, "canonical record changed; refresh conflicts before resolving")
	}
	result, err := applyIncoming(ctx, tx, userID, normalized, hash, now)
	if err != nil {
		return SyncRecord{}, err
	}
	if result.Status != "accepted" {
		return SyncRecord{}, errCode(CodeConflict, "resolution did not supersede the canonical record")
	}
	canonicalJSON, err := json.Marshal(result.Record)
	if err != nil {
		return SyncRecord{}, fmt.Errorf("encode resolution receipt: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO conflict_resolutions(
user_id,category,record_key,rejected_wall,rejected_logical,rejected_device,resolution_wall,resolution_logical,resolution_device,content_hash,canonical_json,created_at)
VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`,
		userID, normalized.Category, normalized.Key, rejected.Wall, rejected.Logical, rejected.Device,
		normalized.Version.Wall, normalized.Version.Logical, normalized.Version.Device, hash, canonicalJSON, now.UnixMilli()); err != nil {
		return SyncRecord{}, fmt.Errorf("save resolution receipt: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM conflicts WHERE id=? AND user_id=?`, conflictID, userID); err != nil {
		return SyncRecord{}, err
	}
	if err := tx.Commit(); err != nil {
		return SyncRecord{}, err
	}
	return result.Record, nil
}
