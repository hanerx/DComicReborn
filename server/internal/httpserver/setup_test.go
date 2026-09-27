package httpserver

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
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

var csrfInputPattern = regexp.MustCompile(`name="csrf" value="([^"]+)"`)

func startSetupServer(t *testing.T, databasePath string, config Config) (*httptest.Server, *store.Store, *bytes.Buffer) {
	t.Helper()
	data, err := store.Open(databasePath)
	if err != nil {
		t.Fatal(err)
	}
	var logs bytes.Buffer
	config.Logger = slog.New(slog.NewJSONHandler(&logs, nil))
	handler, err := New(data, config)
	if err != nil {
		_ = data.Close()
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	t.Cleanup(func() {
		server.Close()
		_ = data.Close()
	})
	return server, data, &logs
}

func initializationCode(t *testing.T, logs *bytes.Buffer) string {
	t.Helper()
	for _, line := range strings.Split(strings.TrimSpace(logs.String()), "\n") {
		var record map[string]any
		if json.Unmarshal([]byte(line), &record) == nil {
			if code, ok := record["initialization_code"].(string); ok {
				return code
			}
		}
	}
	t.Fatal("startup log did not contain initialization code")
	return ""
}

func noRedirectClient(t *testing.T) *http.Client {
	t.Helper()
	jar, err := cookiejar.New(nil)
	if err != nil {
		t.Fatal(err)
	}
	return &http.Client{Jar: jar, CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
}

func getSetupForm(t *testing.T, client *http.Client, endpoint string) ([]byte, string) {
	t.Helper()
	response, err := client.Get(endpoint + "/dashboard/setup")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK {
		t.Fatalf("setup status=%d body=%s", response.StatusCode, body)
	}
	match := csrfInputPattern.FindSubmatch(body)
	if len(match) != 2 {
		t.Fatalf("missing setup csrf token: %s", body)
	}
	return body, string(match[1])
}

func postSetup(t *testing.T, client *http.Client, endpoint, origin, csrf, code, password string) *http.Response {
	t.Helper()
	form := url.Values{
		"csrf":               {csrf},
		"initializationCode": {code},
		"password":           {password},
		"confirmPassword":    {password},
	}
	request, err := http.NewRequest(http.MethodPost, endpoint+"/dashboard/setup", strings.NewReader(form.Encode()))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if origin != "" {
		request.Header.Set("Origin", origin)
	}
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	return response
}

func TestFirstRunRoutesToSetupWithoutExposingInitializationCode(t *testing.T) {
	server, _, logs := startSetupServer(t, filepath.Join(t.TempDir(), "first-run.db"), Config{})
	client := noRedirectClient(t)
	root, err := client.Get(server.URL + "/")
	if err != nil {
		t.Fatal(err)
	}
	root.Body.Close()
	if root.StatusCode != http.StatusSeeOther || root.Header.Get("Location") != "/dashboard" {
		t.Fatalf("GET / status=%d location=%q", root.StatusCode, root.Header.Get("Location"))
	}
	dashboard, err := client.Get(server.URL + "/dashboard")
	if err != nil {
		t.Fatal(err)
	}
	dashboard.Body.Close()
	if dashboard.StatusCode != http.StatusSeeOther || dashboard.Header.Get("Location") != "/dashboard/setup" {
		t.Fatalf("GET /dashboard status=%d location=%q", dashboard.StatusCode, dashboard.Header.Get("Location"))
	}
	obsolete, err := client.Get(server.URL + "/admin/")
	if err != nil {
		t.Fatal(err)
	}
	obsolete.Body.Close()
	if obsolete.StatusCode != http.StatusNotFound {
		t.Fatalf("obsolete /admin/ status=%d", obsolete.StatusCode)
	}

	body, _ := getSetupForm(t, client, server.URL)
	code := initializationCode(t, logs)
	if strings.Contains(string(body), code) {
		t.Fatal("setup page exposed the initialization code")
	}
}

func TestSetupRequiresSameOriginCSRFAndInitializationCode(t *testing.T) {
	server, data, logs := startSetupServer(t, filepath.Join(t.TempDir(), "protected.db"), Config{})
	client := noRedirectClient(t)
	_, csrf := getSetupForm(t, client, server.URL)
	code := initializationCode(t, logs)

	missingOrigin := postSetup(t, client, server.URL, "", csrf, code, "correct horse battery staple")
	missingOrigin.Body.Close()
	if missingOrigin.StatusCode != http.StatusForbidden {
		t.Fatalf("missing Origin status=%d", missingOrigin.StatusCode)
	}
	crossOrigin := postSetup(t, client, server.URL, "https://attacker.example", csrf, code, "correct horse battery staple")
	crossOrigin.Body.Close()
	if crossOrigin.StatusCode != http.StatusForbidden {
		t.Fatalf("cross-site Origin status=%d", crossOrigin.StatusCode)
	}
	badCSRF := postSetup(t, client, server.URL, server.URL, "wrong", code, "correct horse battery staple")
	badCSRF.Body.Close()
	if badCSRF.StatusCode != http.StatusForbidden {
		t.Fatalf("invalid CSRF status=%d", badCSRF.StatusCode)
	}
	badCode := postSetup(t, client, server.URL, server.URL, csrf, "wrong", "correct horse battery staple")
	badCode.Body.Close()
	if badCode.StatusCode != http.StatusUnauthorized {
		t.Fatalf("invalid initialization code status=%d", badCode.StatusCode)
	}
	weakPassword := postSetup(t, client, server.URL, server.URL, csrf, code, "too short")
	weakPassword.Body.Close()
	if weakPassword.StatusCode != http.StatusBadRequest {
		t.Fatalf("weak password status=%d", weakPassword.StatusCode)
	}
	initialized, err := data.HasAdmin(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if initialized {
		t.Fatal("rejected setup request created an administrator")
	}
}

func TestSuccessfulSetupCreatesOnlyRootAndDisablesInitialization(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "initialized.db")
	server, data, logs := startSetupServer(t, databasePath, Config{})

	client := noRedirectClient(t)
	_, csrf := getSetupForm(t, client, server.URL)
	response := postSetup(t, client, server.URL, server.URL, csrf, initializationCode(t, logs), "correct horse battery staple")
	response.Body.Close()
	if response.StatusCode != http.StatusSeeOther || response.Header.Get("Location") != "/dashboard/login" {
		t.Fatalf("setup status=%d location=%q", response.StatusCode, response.Header.Get("Location"))
	}
	if _, _, user, err := data.LoginAdmin(context.Background(), "root", "correct horse battery staple", 0); err != nil || user.Username != "root" {
		t.Fatalf("root login user=%#v err=%v", user, err)
	}
	root, err := client.Get(server.URL + "/")
	if err != nil {
		t.Fatal(err)
	}
	root.Body.Close()
	if root.StatusCode != http.StatusSeeOther || root.Header.Get("Location") != "/dashboard" {
		t.Fatalf("initialized root status=%d location=%q", root.StatusCode, root.Header.Get("Location"))
	}
	dashboard, err := client.Get(server.URL + "/dashboard")
	if err != nil {
		t.Fatal(err)
	}
	dashboard.Body.Close()
	if dashboard.StatusCode != http.StatusSeeOther || dashboard.Header.Get("Location") != "/dashboard/login" {
		t.Fatalf("initialized dashboard status=%d location=%q", dashboard.StatusCode, dashboard.Header.Get("Location"))
	}

	repeated := postSetup(t, client, server.URL, server.URL, csrf, initializationCode(t, logs), "another strong password")
	repeated.Body.Close()
	if repeated.StatusCode != http.StatusConflict {
		t.Fatalf("repeated setup status=%d", repeated.StatusCode)
	}
	users, err := data.ListUsers(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(users) != 1 || users[0].Username != "root" || !users[0].Admin {
		t.Fatalf("users after repeated setup = %#v", users)
	}
}

func TestInitializationCodeChangesOnRestartAndStopsAfterExistingAdmin(t *testing.T) {
	databasePath := filepath.Join(t.TempDir(), "restart.db")
	first, firstStore, firstLogs := startSetupServer(t, databasePath, Config{})
	firstCode := initializationCode(t, firstLogs)
	first.Close()
	if err := firstStore.Close(); err != nil {
		t.Fatal(err)
	}

	second, secondStore, secondLogs := startSetupServer(t, databasePath, Config{})
	secondCode := initializationCode(t, secondLogs)
	if firstCode == secondCode {
		t.Fatal("restart reused the initialization code")
	}
	if _, err := secondStore.BootstrapAdmin(context.Background(), "admin", "correct horse battery staple"); err != nil {
		t.Fatal(err)
	}
	second.Close()
	if err := secondStore.Close(); err != nil {
		t.Fatal(err)
	}

	third, _, thirdLogs := startSetupServer(t, databasePath, Config{})
	client := noRedirectClient(t)
	response, err := client.Get(third.URL + "/dashboard/setup")
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusSeeOther || response.Header.Get("Location") != "/dashboard/login" {
		t.Fatalf("existing-admin setup status=%d location=%q", response.StatusCode, response.Header.Get("Location"))
	}
	if strings.Contains(thirdLogs.String(), "initialization_code") {
		t.Fatalf("initialized restart logged a setup code: %s", thirdLogs)
	}
}

func TestDirectHTTPAndConfiguredOriginBoundaries(t *testing.T) {
	direct, _, _ := startSetupServer(t, filepath.Join(t.TempDir(), "direct.db"), Config{})
	response, err := direct.Client().Get(direct.URL + "/dashboard/setup")
	if err != nil {
		t.Fatal(err)
	}
	if cookie := response.Header.Get("Set-Cookie"); strings.Contains(cookie, "Secure") {
		t.Fatalf("direct HTTP setup cookie is Secure: %s", cookie)
	}
	response.Body.Close()

	data, err := store.Open(filepath.Join(t.TempDir(), "configured.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer data.Close()
	configured, err := New(data, Config{PublicURL: "https://sync.example.com"})
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "http://internal/dashboard/setup", nil)
	request.Host = "sync.example.com"
	recorder := httptest.NewRecorder()

	configured.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Header().Get("Set-Cookie"), "Secure") {
		t.Fatalf("configured HTTPS status=%d cookie=%q", recorder.Code, recorder.Header().Get("Set-Cookie"))
	}
	csrfMatch := csrfInputPattern.FindStringSubmatch(recorder.Body.String())
	if len(csrfMatch) != 2 {
		t.Fatalf("configured HTTPS setup form missing csrf: %s", recorder.Body.String())
	}
	setupCookie := recorder.Result().Cookies()[0]
	setupForm := url.Values{
		"csrf":               {csrfMatch[1]},
		"initializationCode": {configured.initializationCode},
		"password":           {"correct horse battery staple"},
		"confirmPassword":    {"correct horse battery staple"},
	}
	crossOrigin := httptest.NewRequest(http.MethodPost, "http://internal/dashboard/setup", strings.NewReader(setupForm.Encode()))
	crossOrigin.Host = "sync.example.com"
	crossOrigin.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	crossOrigin.Header.Set("Origin", "http://sync.example.com")
	crossOrigin.AddCookie(setupCookie)
	crossOriginRecorder := httptest.NewRecorder()
	configured.ServeHTTP(crossOriginRecorder, crossOrigin)
	if crossOriginRecorder.Code != http.StatusForbidden {
		t.Fatalf("configured HTTPS accepted HTTP Origin: status=%d", crossOriginRecorder.Code)
	}

	sameOrigin := httptest.NewRequest(http.MethodPost, "http://internal/dashboard/setup", strings.NewReader(setupForm.Encode()))
	sameOrigin.Host = "sync.example.com"
	sameOrigin.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	sameOrigin.Header.Set("Origin", "https://sync.example.com")
	sameOrigin.AddCookie(setupCookie)
	sameOriginRecorder := httptest.NewRecorder()
	configured.ServeHTTP(sameOriginRecorder, sameOrigin)
	if sameOriginRecorder.Code != http.StatusSeeOther || sameOriginRecorder.Header().Get("Location") != "/dashboard/login" {
		t.Fatalf("configured HTTPS setup status=%d location=%q", sameOriginRecorder.Code, sameOriginRecorder.Header().Get("Location"))
	}

	wrongHost := httptest.NewRequest(http.MethodGet, "http://internal/dashboard/setup", nil)
	wrongHost.Host = "internal:8080"
	wrongHostRecorder := httptest.NewRecorder()
	configured.ServeHTTP(wrongHostRecorder, wrongHost)
	if wrongHostRecorder.Code != http.StatusMisdirectedRequest {
		t.Fatalf("configured wrong Host status=%d", wrongHostRecorder.Code)
	}

	for _, publicURL := range []string{"ftp://sync.example.com", "https://sync.example.com/path", "https://user@sync.example.com", "https://sync.example.com?query=1", "//sync.example.com"} {
		if _, err := New(data, Config{PublicURL: publicURL}); err == nil {
			t.Errorf("New accepted invalid public URL %q", publicURL)
		}
	}
	if _, err := New(data, Config{PublicURL: "http://sync.example.com:8080"}); err != nil {
		t.Fatalf("configured HTTP origin rejected: %v", err)
	}
}
