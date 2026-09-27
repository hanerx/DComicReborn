package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

const (
	CodeBadRequest   = "bad_request"
	CodeUnauthorized = "unauthorized"
	CodeForbidden    = "forbidden"
	CodeConflict     = "conflict"
	CodeVersionReuse = "version_reuse"
	CodeFutureClock  = "future_clock"
	CodeNotFound     = "not_found"
)

type Error struct {
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Message }

func IsCode(err error, code string) bool {
	var target *Error
	return errors.As(err, &target) && target.Code == code
}

func errCode(code, format string, args ...any) error {
	return &Error{Code: code, Message: fmt.Sprintf(format, args...)}
}

type User struct {
	ID        string
	Username  string
	Admin     bool
	Disabled  bool
	CreatedAt time.Time
	UpdatedAt time.Time
}

type SyncVersion struct {
	Wall    int64  `json:"wall"`
	Logical int64  `json:"logical"`
	Device  string `json:"device"`
}

func (v SyncVersion) Compare(other SyncVersion) int {
	if v.Wall < other.Wall {
		return -1
	}
	if v.Wall > other.Wall {
		return 1
	}
	if v.Logical < other.Logical {
		return -1
	}
	if v.Logical > other.Logical {
		return 1
	}
	if v.Device < other.Device {
		return -1
	}
	if v.Device > other.Device {
		return 1
	}
	return 0
}

func (v SyncVersion) Equal(other SyncVersion) bool { return v.Compare(other) == 0 }

type SyncRecord struct {
	Category    string          `json:"category"`
	Key         string          `json:"key"`
	Value       json.RawMessage `json:"value"`
	Deleted     bool            `json:"deleted"`
	Version     SyncVersion     `json:"version"`
	Uncertain   bool            `json:"uncertain"`
	BaseVersion *SyncVersion    `json:"baseVersion"`
}

type SyncRequest struct {
	Cursor     int64        `json:"cursor"`
	Categories []string     `json:"categories"`
	Changes    []SyncRecord `json:"changes"`
}

type SyncResult struct {
	Category string     `json:"category"`
	Key      string     `json:"key"`
	Status   string     `json:"status"`
	Record   SyncRecord `json:"record"`
}

type SyncResponse struct {
	Cursor     int64        `json:"cursor"`
	HasMore    bool         `json:"hasMore"`
	Records    []SyncRecord `json:"records"`
	Results    []SyncResult `json:"results"`
	ServerTime int64        `json:"serverTime"`
}

type Conflict struct {
	ID     string     `json:"id"`
	Local  SyncRecord `json:"local"`
	Remote SyncRecord `json:"remote"`
}

type Device struct {
	ID        string
	DeviceID  string
	Name      string
	CreatedAt time.Time
	LastSeen  time.Time
	ExpiresAt time.Time
	Revoked   bool
}

type AdminStats struct {
	Users     int
	Enabled   int
	Devices   int
	Records   int
	Conflicts int
}

type UserSummary struct {
	User
	DeviceCount   int
	RecordCount   int
	ConflictCount int
	LatestCursor  int64
}
