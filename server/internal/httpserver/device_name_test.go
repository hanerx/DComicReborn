package httpserver

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"
)

func TestSyncRefreshesDeviceNameWithinAuthenticatedAccount(t *testing.T) {
	ts, db := testServer(t)
	ctx := context.Background()
	alice, err := db.CreateUser(ctx, "alice", "correct horse battery staple", false)
	if err != nil {
		t.Fatal(err)
	}
	bob, err := db.CreateUser(ctx, "bob", "correct horse battery staple", false)
	if err != nil {
		t.Fatal(err)
	}
	token, _, err := db.LoginDevice(ctx, "alice", "correct horse battery staple", "shared-id", "localhost", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := db.LoginDevice(ctx, "bob", "correct horse battery staple", "shared-id", "Bob tablet", time.Hour); err != nil {
		t.Fatal(err)
	}
	response, err := http.DefaultClient.Do(jsonRequest(t, http.MethodPost, ts.URL+"/api/v1/sync", map[string]any{
		"cursor": 0, "categories": []string{"settings"}, "changes": []any{}, "deviceName": "我的 Pixel",
	}, token))
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("sync status=%d", response.StatusCode)
	}
	for _, expected := range []struct{ userID, name string }{{alice.ID, "我的 Pixel"}, {bob.ID, "Bob tablet"}} {
		devices, err := db.ListDevices(ctx, expected.userID)
		if err != nil || len(devices) != 1 || devices[0].Name != expected.name {
			t.Fatalf("user %s devices=%+v err=%v", expected.userID, devices, err)
		}
	}
	conflicts, err := http.DefaultClient.Do(jsonRequest(t, http.MethodGet, ts.URL+"/api/v1/conflicts", nil, token))
	if err != nil {
		t.Fatal(err)
	}
	defer conflicts.Body.Close()
	var body struct {
		Devices map[string]string `json:"devices"`
	}
	if err := json.NewDecoder(conflicts.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if len(body.Devices) != 1 || body.Devices["shared-id"] != "我的 Pixel" {
		t.Fatalf("conflict sources=%v", body.Devices)
	}
}
