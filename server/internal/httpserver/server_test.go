package httpserver

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"dcomic-sync-server/internal/store"
)

func testServer(t *testing.T) (*httptest.Server, *store.Store) {
	t.Helper()
	db, err := store.Open(filepath.Join(t.TempDir(), "server.db"))
	if err != nil {
		t.Fatal(err)
	}
	ts := httptest.NewUnstartedServer(nil)
	h, err := New(db, Config{})
	if err != nil {
		t.Fatal(err)
	}
	ts.Config.Handler = h
	ts.Start()
	t.Cleanup(func() { ts.Close(); _ = db.Close() })
	return ts, db
}

func jsonRequest(t *testing.T, method, endpoint string, body any, token string) *http.Request {
	t.Helper()
	encoded, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	req, err := http.NewRequest(method, endpoint, bytes.NewReader(encoded))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	return req
}

func TestAPIAuthenticationAndRevocation(t *testing.T) {
	ts, db := testServer(t)
	if _, err := db.CreateUser(context.Background(), "alice", "correct horse battery staple", false); err != nil {
		t.Fatal(err)
	}
	resp, err := http.DefaultClient.Do(jsonRequest(t, http.MethodPost, ts.URL+"/api/v1/login", map[string]any{
		"username": "alice", "password": "correct horse battery staple", "deviceId": "phone", "deviceName": "Phone",
	}, ""))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		t.Fatalf("login status=%d body=%s", resp.StatusCode, b)
	}
	var login struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&login); err != nil {
		t.Fatal(err)
	}

	logout, err := http.DefaultClient.Do(jsonRequest(t, http.MethodPost, ts.URL+"/api/v1/logout", map[string]any{}, login.Token))
	if err != nil {
		t.Fatal(err)
	}
	logout.Body.Close()
	if logout.StatusCode != http.StatusOK {
		t.Fatalf("logout status=%d", logout.StatusCode)
	}
	denied, err := http.DefaultClient.Do(jsonRequest(t, http.MethodPost, ts.URL+"/api/v1/sync", map[string]any{
		"cursor": 0, "categories": []string{"settings"}, "changes": []any{},
	}, login.Token))
	if err != nil {
		t.Fatal(err)
	}
	denied.Body.Close()
	if denied.StatusCode != http.StatusUnauthorized {
		t.Fatalf("revoked token status=%d", denied.StatusCode)
	}
}

func TestLoginRejectsOversizedUsernameBeforeAuthentication(t *testing.T) {
	ts, _ := testServer(t)
	resp, err := http.DefaultClient.Do(jsonRequest(t, http.MethodPost, ts.URL+"/api/v1/login", map[string]any{
		"username": strings.Repeat("a", 1_000), "password": "correct horse battery staple", "deviceId": "phone", "deviceName": "Phone",
	}, ""))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("oversized username status=%d, want 400", resp.StatusCode)
	}
}

func TestDashboardRequiresCSRFAndAdmin(t *testing.T) {
	ts, db := testServer(t)
	if _, err := db.CreateUser(context.Background(), "admin", "correct horse battery staple", true); err != nil {
		t.Fatal(err)
	}
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar}
	loginPage, err := client.Get(ts.URL + "/dashboard/login")
	if err != nil {
		t.Fatal(err)
	}
	page, _ := io.ReadAll(loginPage.Body)
	loginPage.Body.Close()
	re := regexp.MustCompile(`name="csrf" value="([^"]+)"`)
	match := re.FindSubmatch(page)
	if len(match) != 2 {
		t.Fatalf("missing login csrf token: %s", page)
	}
	form := url.Values{"username": {"admin"}, "password": {"correct horse battery staple"}, "csrf": {string(match[1])}}
	loggedIn, err := client.PostForm(ts.URL+"/dashboard/login", form)
	if err != nil {
		t.Fatal(err)
	}
	loggedIn.Body.Close()
	if loggedIn.StatusCode != http.StatusOK {
		t.Fatalf("dashboard status=%d", loggedIn.StatusCode)
	}

	withoutCSRF, err := client.PostForm(ts.URL+"/dashboard/users", url.Values{
		"username": {"bob"}, "password": {"another strong password"},
	})
	if err != nil {
		t.Fatal(err)
	}
	withoutCSRF.Body.Close()
	if withoutCSRF.StatusCode != http.StatusForbidden {
		t.Fatalf("missing csrf status=%d", withoutCSRF.StatusCode)
	}

	dashboard, err := client.Get(ts.URL + "/dashboard")
	if err != nil {
		t.Fatal(err)
	}
	html, _ := io.ReadAll(dashboard.Body)
	dashboard.Body.Close()
	match = re.FindSubmatch(html)
	if len(match) != 2 {
		t.Fatalf("missing session csrf token")
	}
	create := url.Values{"username": {"bob"}, "password": {"another strong password"}, "csrf": {string(match[1])}}
	created, err := client.PostForm(ts.URL+"/dashboard/users", create)
	if err != nil {
		t.Fatal(err)
	}
	created.Body.Close()
	if created.StatusCode != http.StatusOK || created.Request.URL.Path != "/dashboard" {
		t.Fatalf("create status=%d url=%s", created.StatusCode, created.Request.URL)
	}
}
