package store

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

func TestSyncPreservesLargePayloadIntegers(t *testing.T) {
	s := openTestStore(t)
	u := createTestUser(t, s, "alice")
	record := SyncRecord{
		Category: "settings",
		Key:      "large-number",
		Value:    json.RawMessage(`{"identifier":9223372036854775807}`),
		Version:  SyncVersion{Wall: 1_000_000, Device: "phone"},
	}
	response, err := s.Sync(context.Background(), u.ID, SyncRequest{Categories: []string{"settings"}, Changes: []SyncRecord{record}}, time.UnixMilli(2_000_000))
	if err != nil {
		t.Fatal(err)
	}
	if got, want := string(response.Results[0].Record.Value), `{"identifier":9223372036854775807}`; got != want {
		t.Fatalf("payload = %s, want %s", got, want)
	}
}
