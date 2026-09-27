package store

import (
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func openTestStore(t *testing.T) *Store {
	t.Helper()
	s, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

func createTestUser(t *testing.T, s *Store, username string) User {
	t.Helper()
	u, err := s.CreateUser(context.Background(), username, "correct horse battery staple", false)
	if err != nil {
		t.Fatal(err)
	}
	return u
}

func record(category, key, device string, wall int64, value string) SyncRecord {
	return SyncRecord{
		Category: category,
		Key:      key,
		Value:    json.RawMessage(fmt.Sprintf(`{"value":%q}`, value)),
		Version:  SyncVersion{Wall: wall, Logical: 0, Device: device},
	}
}

func TestBootstrapAdminIsAtomic(t *testing.T) {
	s := openTestStore(t)
	start := make(chan struct{})
	errors := make(chan error, 2)
	var wait sync.WaitGroup
	for _, password := range []string{"first strong password", "second strong password"} {
		wait.Add(1)
		go func(password string) {
			defer wait.Done()
			<-start
			_, err := s.BootstrapAdmin(context.Background(), "root", password)
			errors <- err
		}(password)
	}
	close(start)
	wait.Wait()
	close(errors)

	var created, conflicts int
	for err := range errors {
		switch {
		case err == nil:
			created++
		case IsCode(err, CodeConflict):
			conflicts++
		default:
			t.Fatalf("bootstrap error = %v", err)
		}
	}
	if created != 1 || conflicts != 1 {
		t.Fatalf("bootstrap results: created=%d conflicts=%d", created, conflicts)
	}
	users, err := s.ListUsers(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(users) != 1 || users[0].Username != "root" || !users[0].Admin {
		t.Fatalf("bootstrap users = %#v", users)
	}
}

func TestBootstrapAdminRejectsExistingNonRootAdministrator(t *testing.T) {
	s := openTestStore(t)
	if _, err := s.CreateUser(context.Background(), "existing-admin", "correct horse battery staple", true); err != nil {
		t.Fatal(err)
	}
	if _, err := s.BootstrapAdmin(context.Background(), "root", "another strong password"); !IsCode(err, CodeConflict) {
		t.Fatalf("bootstrap with existing administrator error = %v", err)
	}
	users, err := s.ListUsers(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(users) != 1 || users[0].Username != "existing-admin" {
		t.Fatalf("existing administrator changed: %#v", users)
	}
}

func TestSyncIsolatesUsersAndOrdersOfflineChanges(t *testing.T) {
	s := openTestStore(t)
	a := createTestUser(t, s, "alice")
	b := createTestUser(t, s, "bob")
	now := time.UnixMilli(2_000_000)

	newer := record("settings", "theme", "device-b", 1_500_000, "dark")
	if _, err := s.Sync(context.Background(), a.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{newer}}, now); err != nil {
		t.Fatal(err)
	}
	lateOld := record("settings", "theme", "device-a", 1_000_000, "light")
	res, err := s.Sync(context.Background(), a.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{lateOld}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if got := res.Results[0].Status; got != "superseded" {
		t.Fatalf("late offline edit status = %q", got)
	}
	if got := string(res.Results[0].Record.Value); got != string(newer.Value) {
		t.Fatalf("canonical value = %s", got)
	}

	bobChange := record("settings", "language", "bob-phone", 1_200_000, "en")
	bob, err := s.Sync(context.Background(), b.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{bobChange}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if len(bob.Records) != 1 || bob.Records[0].Key != "language" {
		t.Fatalf("Bob received another user's records: %#v", bob.Records)
	}
	if bob.Cursor != 1 {
		t.Fatalf("Bob's user-scoped cursor = %d, want 1", bob.Cursor)
	}
}

func TestSyncIsIdempotentAndRejectsVersionReuse(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	now := time.UnixMilli(2_000_000)
	r := record("history", `["history","source","comic"]`, "phone", 1_000_000, "one")

	first, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"history"}, Changes: []SyncRecord{r}}, now)
	if err != nil {
		t.Fatal(err)
	}
	second, err := s.Sync(context.Background(), u.ID, SyncRequest{Cursor: first.Cursor, Categories: []string{"history"}, Changes: []SyncRecord{r}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if second.Cursor != first.Cursor || len(second.Records) != 0 {
		t.Fatalf("replay created another change: first=%d second=%d records=%d", first.Cursor, second.Cursor, len(second.Records))
	}

	r.Value = json.RawMessage(`{"value":"different"}`)
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"history"}, Changes: []SyncRecord{r}}, now); !IsCode(err, CodeVersionReuse) {
		t.Fatalf("version reuse error = %v", err)
	}
}

func TestUncertainConcurrentChangesCreateDurableConflict(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	now := time.UnixMilli(2_000_000)
	remote := record("settings", "reader", "tablet", 1_000_000, "paged")
	remote.Uncertain = true
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{remote}}, now); err != nil {
		t.Fatal(err)
	}
	local := record("settings", "reader", "phone", 1_100_000, "scroll")
	res, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{local}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if res.Results[0].Status != "conflict" || string(res.Results[0].Record.Value) != string(remote.Value) {
		t.Fatalf("unexpected result: %#v", res.Results[0])
	}
	conflicts, err := s.ListConflicts(context.Background(), u.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(conflicts) != 1 || string(conflicts[0].Local.Value) != string(local.Value) {
		t.Fatalf("conflicts = %#v", conflicts)
	}

	advance := record("settings", "reader", "tablet", 1_150_000, "paged again")
	advance.BaseVersion = &remote.Version
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{advance}}, now); err != nil {
		t.Fatal(err)
	}
	refreshed, err := s.ListConflicts(context.Background(), u.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(refreshed) != 1 || !refreshed[0].Remote.Version.Equal(advance.Version) {
		t.Fatalf("conflict remote did not refresh to canonical: %#v", refreshed)
	}

	local.BaseVersion = &advance.Version
	local.Version = SyncVersion{Wall: 1_200_000, Device: "phone"}
	canonical, err := s.ResolveConflict(context.Background(), u.ID, local, conflicts[0].Local.Version, now)
	if err != nil {
		t.Fatal(err)
	}
	if string(canonical.Value) != string(local.Value) {
		t.Fatalf("resolved value = %s", canonical.Value)
	}
	if left, _ := s.ListConflicts(context.Background(), u.ID); len(left) != 0 {
		t.Fatalf("conflict was not removed: %#v", left)
	}

	replayedResolution, err := s.ResolveConflict(context.Background(), u.ID, local, conflicts[0].Local.Version, now)
	if err != nil {
		t.Fatal(err)
	}
	if !replayedResolution.Version.Equal(canonical.Version) || string(replayedResolution.Value) != string(canonical.Value) {
		t.Fatalf("resolution replay = %#v, want %#v", replayedResolution, canonical)
	}

	replay, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{conflicts[0].Local}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if replay.Results[0].Status != "superseded" {
		t.Fatalf("retired conflict replay status = %q", replay.Results[0].Status)
	}
}

func TestCausalChangeMustAdvanceVersion(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	now := time.UnixMilli(2_000_000)
	current := record("settings", "reader", "tablet", 1_000_000, "paged")
	current.Uncertain = true
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{current}}, now); err != nil {
		t.Fatal(err)
	}
	regression := record("settings", "reader", "phone", 900_000, "scroll")
	regression.BaseVersion = &current.Version
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{regression}}, now); !IsCode(err, CodeBadRequest) {
		t.Fatalf("causal version regression error = %v", err)
	}
}

func TestTombstonePreventsLateOfflineResurrection(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	now := time.UnixMilli(2_000_000)
	old := record("history", "comic", "offline", 900_000, "old")
	deleted := record("history", "comic", "online", 1_100_000, "")
	deleted.Value = nil
	deleted.Deleted = true
	if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"history"}, Changes: []SyncRecord{deleted}}, now); err != nil {
		t.Fatal(err)
	}
	res, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"history"}, Changes: []SyncRecord{old}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Results[0].Record.Deleted || res.Results[0].Status != "superseded" {
		t.Fatalf("tombstone lost: %#v", res.Results[0])
	}
}

func TestPaginationDoesNotLoseRows(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	now := time.UnixMilli(2_000_000)
	for i := range 505 {
		r := record("settings", fmt.Sprintf("key-%03d", i), "phone", int64(1_000_000+i), fmt.Sprint(i))
		if _, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{r}}, now); err != nil {
			t.Fatal(err)
		}
	}
	first, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if len(first.Records) != 500 || !first.HasMore {
		t.Fatalf("first page = %d, hasMore=%v", len(first.Records), first.HasMore)
	}
	second, err := s.Sync(context.Background(), u.ID, SyncRequest{Cursor: first.Cursor, Categories: []string{"settings"}}, now)
	if err != nil {
		t.Fatal(err)
	}
	if len(second.Records) != 5 || second.HasMore || second.Cursor <= first.Cursor {
		t.Fatalf("second page = %d, hasMore=%v, cursor=%d", len(second.Records), second.HasMore, second.Cursor)
	}
}

func TestDeviceSessionReplacementRevocationAndPasswordChange(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	ctx := context.Background()
	first, _, err := s.LoginDevice(ctx, "alice", "correct horse battery staple", "phone", "Alice phone", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	second, _, err := s.LoginDevice(ctx, "alice", "correct horse battery staple", "phone", "Alice phone", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.AuthenticateDevice(ctx, first); !IsCode(err, CodeUnauthorized) {
		t.Fatalf("replaced token auth error = %v", err)
	}
	if got, err := s.AuthenticateDevice(ctx, second); err != nil || got.ID != u.ID {
		t.Fatalf("new token auth user=%#v err=%v", got, err)
	}
	if err := s.ChangePassword(ctx, u.ID, "correct horse battery staple", "a different strong password"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.AuthenticateDevice(ctx, second); !IsCode(err, CodeUnauthorized) {
		t.Fatalf("password-change token auth error = %v", err)
	}
}
