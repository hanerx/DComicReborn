package httpserver

import (
	"context"
	"html"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"dcomic-sync-server/internal/store"
)

const dashboardTestPassword = "correct horse battery staple"

func dashboardAdminClient(t *testing.T, endpoint string, db *store.Store) (*http.Client, string) {
	t.Helper()
	if _, err := db.CreateUser(context.Background(), "dashboard-admin", dashboardTestPassword, true); err != nil {
		t.Fatal(err)
	}
	jar, err := cookiejar.New(nil)
	if err != nil {
		t.Fatal(err)
	}
	client := &http.Client{Jar: jar}
	response, err := client.Get(endpoint + "/dashboard/login")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(response.Body)
	response.Body.Close()
	csrf := dashboardFormValue(t, string(body), "csrf")
	response, err = client.PostForm(endpoint+"/dashboard/login", url.Values{
		"username": {"dashboard-admin"}, "password": {dashboardTestPassword}, "csrf": {csrf},
	})
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	response, err = client.Get(endpoint + "/dashboard")
	if err != nil {
		t.Fatal(err)
	}
	body, _ = io.ReadAll(response.Body)
	response.Body.Close()
	return client, dashboardFormValue(t, string(body), "csrf")
}

func dashboardFormValue(t *testing.T, page, name string) string {
	t.Helper()
	pattern := regexp.MustCompile(`name="` + regexp.QuoteMeta(name) + `" value="([^"]*)"`)
	match := pattern.FindStringSubmatch(page)
	if len(match) != 2 {
		t.Fatalf("form field %q not found in dashboard response", name)
	}
	return html.UnescapeString(match[1])
}

func dashboardSyncRecord(category, key, value, device string, wall int64, uncertain bool, base *store.SyncVersion) store.SyncRecord {
	return store.SyncRecord{
		Category: category, Key: key, Value: []byte(value), Version: store.SyncVersion{Wall: wall, Device: device},
		Uncertain: uncertain, BaseVersion: base,
	}
}

func syncDashboardRecords(t *testing.T, db *store.Store, userID string, records ...store.SyncRecord) {
	t.Helper()
	categories := make([]string, 0, len(records))
	seen := map[string]bool{}
	for _, record := range records {
		if !seen[record.Category] {
			seen[record.Category] = true
			categories = append(categories, record.Category)
		}
	}
	if _, err := db.Sync(context.Background(), userID, store.SyncRequest{Categories: categories, Changes: records}, time.Now()); err != nil {
		t.Fatal(err)
	}
}

func TestDashboardSyncDetailsEscapePayloadsAndRedactCredentials(t *testing.T) {
	ts, db := testServer(t)
	client, _ := dashboardAdminClient(t, ts.URL, db)
	user, err := db.CreateUser(context.Background(), "sync-reader", dashboardTestPassword, false)
	if err != nil {
		t.Fatal(err)
	}
	syncDashboardRecords(t, db, user.ID,
		dashboardSyncRecord("settings", `<unsafe-key>`, `{"label":"<script>alert(1)</script>"}`, "phone-1", 1000, false, nil),
		dashboardSyncRecord("credentials", "private-login", `{"token":"dashboard-secret-token","password":"hidden"}`, "phone-1", 1001, false, nil),
	)
	syncDashboardRecords(t, db, user.ID,
		dashboardSyncRecord("credentials", "private-login", `{"token":"candidate-secret-token"}`, "tablet-2", 1002, true, nil),
	)

	response, err := client.Get(ts.URL + "/dashboard/users/" + url.PathEscape(user.ID) + "/sync?category=settings")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(response.Body)
	response.Body.Close()
	page := string(body)
	if response.StatusCode != http.StatusOK {
		t.Fatalf("sync details status=%d", response.StatusCode)
	}
	if strings.Contains(page, "<script>alert(1)</script>") || !strings.Contains(page, `\u003cscript\u003ealert(1)\u003c/script\u003e`) {
		t.Fatalf("payload was not safely escaped")
	}
	if !strings.Contains(page, "phone-1") || !strings.Contains(page, "<unsafe-key>") && !strings.Contains(page, "&lt;unsafe-key&gt;") {
		t.Fatalf("details omitted origin or record key")
	}

	response, err = client.Get(ts.URL + "/dashboard/users/" + url.PathEscape(user.ID) + "/sync?category=credentials")
	if err != nil {
		t.Fatal(err)
	}
	body, _ = io.ReadAll(response.Body)
	response.Body.Close()
	page = string(body)
	if strings.Contains(page, "dashboard-secret-token") || strings.Contains(page, "candidate-secret-token") || strings.Contains(page, `"password":"hidden"`) {
		t.Fatalf("credential content leaked in HTML source")
	}
	if !strings.Contains(page, "private-login") || !strings.Contains(page, "phone-1") {
		t.Fatalf("credential record metadata was omitted")
	}
	response, err = client.Get(ts.URL + "/dashboard/users/" + url.PathEscape(user.ID))
	if err != nil {
		t.Fatal(err)
	}
	body, _ = io.ReadAll(response.Body)
	response.Body.Close()
	page = string(body)
	if strings.Contains(page, "dashboard-secret-token") || strings.Contains(page, "candidate-secret-token") {
		t.Fatalf("credential conflict was not safely redacted")
	}
}

func TestDashboardSyncDetailsPaginateNewestFirst(t *testing.T) {
	ts, db := testServer(t)
	client, _ := dashboardAdminClient(t, ts.URL, db)
	user, err := db.CreateUser(context.Background(), "paged-reader", dashboardTestPassword, false)
	if err != nil {
		t.Fatal(err)
	}
	records := make([]store.SyncRecord, 0, 51)
	for index := range 51 {
		key := "entry-" + strconv.Itoa(index)
		records = append(records, dashboardSyncRecord("history", key, `{"chapter":`+strconv.Itoa(index)+`}`, "reader-phone", int64(4000+index), false, nil))
	}
	syncDashboardRecords(t, db, user.ID, records...)

	response, err := client.Get(ts.URL + "/dashboard/users/" + url.PathEscape(user.ID) + "/sync?category=history")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(response.Body)
	response.Body.Close()
	page := string(body)
	newest := strings.Index(page, "entry-50")
	nextNewest := strings.Index(page, "entry-49")
	if newest < 0 || nextNewest < 0 || newest >= nextNewest || strings.Contains(page, "entry-0") {
		t.Fatalf("first page is not newest-first or exceeded its page boundary")
	}
	olderPattern := regexp.MustCompile(`href="([^"]*before=[^"]+)"`)
	olderMatch := olderPattern.FindStringSubmatch(page)
	if len(olderMatch) != 2 {
		t.Fatalf("first page has no older-page link")
	}
	olderURL := html.UnescapeString(olderMatch[1])
	response, err = client.Get(ts.URL + olderURL)
	if err != nil {
		t.Fatal(err)
	}
	body, _ = io.ReadAll(response.Body)
	response.Body.Close()
	if !strings.Contains(string(body), "entry-0") {
		t.Fatalf("older page omitted the remaining accepted change")
	}
}

func TestDashboardSyncRoutesRequireAdminCSRFAndTenantMatch(t *testing.T) {
	ts, db := testServer(t)
	client, csrf := dashboardAdminClient(t, ts.URL, db)
	owner, err := db.CreateUser(context.Background(), "conflict-owner", dashboardTestPassword, false)
	if err != nil {
		t.Fatal(err)
	}
	other, err := db.CreateUser(context.Background(), "other-user", dashboardTestPassword, false)
	if err != nil {
		t.Fatal(err)
	}
	current := dashboardSyncRecord("settings", "theme", `{"mode":"light"}`, "desktop", 2000, true, nil)
	candidate := dashboardSyncRecord("settings", "theme", `{"mode":"dark"}`, "phone", 2001, true, nil)
	syncDashboardRecords(t, db, owner.ID, current)
	syncDashboardRecords(t, db, owner.ID, candidate)
	conflicts, err := db.ListConflicts(context.Background(), owner.ID)
	if err != nil || len(conflicts) != 1 {
		t.Fatalf("create conflict: count=%d err=%v", len(conflicts), err)
	}

	anonymous, err := http.Get(ts.URL + "/dashboard/users/" + url.PathEscape(owner.ID) + "/sync")
	if err != nil {
		t.Fatal(err)
	}
	anonymous.Body.Close()
	if anonymous.Request.URL.Path != "/dashboard/login" {
		t.Fatalf("anonymous details request was not redirected to login")
	}

	resolveURL := ts.URL + "/dashboard/users/" + url.PathEscape(other.ID) + "/conflicts/" + url.PathEscape(conflicts[0].ID) + "/resolve"
	withoutCSRF, err := client.PostForm(resolveURL, url.Values{
		"choice": {"candidate"}, "expectedWall": {"2000"}, "expectedLogical": {"0"}, "expectedDevice": {"desktop"},
	})
	if err != nil {
		t.Fatal(err)
	}
	withoutCSRF.Body.Close()
	if withoutCSRF.StatusCode != http.StatusForbidden {
		t.Fatalf("resolution without CSRF status=%d", withoutCSRF.StatusCode)
	}

	response, err := client.PostForm(resolveURL, url.Values{
		"csrf": {csrf}, "choice": {"candidate"}, "expectedWall": {"2000"}, "expectedLogical": {"0"}, "expectedDevice": {"desktop"},
	})
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	remaining, err := db.ListConflicts(context.Background(), owner.ID)
	if err != nil || len(remaining) != 1 {
		t.Fatalf("cross-tenant resolution changed owner's conflict: count=%d err=%v", len(remaining), err)
	}
}

func TestDashboardRejectsStaleResolutionAndPersistsFreshChoice(t *testing.T) {
	ts, db := testServer(t)
	client, csrf := dashboardAdminClient(t, ts.URL, db)
	user, err := db.CreateUser(context.Background(), "stale-resolution", dashboardTestPassword, false)
	if err != nil {
		t.Fatal(err)
	}
	current := dashboardSyncRecord("settings", "reader", `{"layout":"grid"}`, "desktop", 3000, true, nil)
	candidate := dashboardSyncRecord("settings", "reader", `{"layout":"list"}`, "phone", 3001, true, nil)
	syncDashboardRecords(t, db, user.ID, current)
	syncDashboardRecords(t, db, user.ID, candidate)
	conflicts, err := db.ListConflicts(context.Background(), user.ID)
	if err != nil || len(conflicts) != 1 {
		t.Fatalf("create conflict: count=%d err=%v", len(conflicts), err)
	}
	conflict := conflicts[0]

	phoneVersion := store.SyncVersion{Wall: 3002, Device: "desktop"}
	phone := dashboardSyncRecord("settings", "reader", `{"layout":"pages"}`, "desktop", phoneVersion.Wall, true, &current.Version)
	syncDashboardRecords(t, db, user.ID, phone)

	resolveURL := ts.URL + "/dashboard/users/" + url.PathEscape(user.ID) + "/conflicts/" + url.PathEscape(conflict.ID) + "/resolve"
	response, err := client.PostForm(resolveURL, url.Values{
		"csrf": {csrf}, "choice": {"candidate"}, "expectedWall": {"3000"}, "expectedLogical": {"0"}, "expectedDevice": {"desktop"},
	})
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	remaining, err := db.ListConflicts(context.Background(), user.ID)
	if err != nil || len(remaining) != 1 {
		t.Fatalf("stale resolution removed conflict: count=%d err=%v", len(remaining), err)
	}
	if string(remaining[0].Remote.Value) != `{"layout":"pages"}` {
		t.Fatalf("stale dashboard form overwrote phone outcome: %s", remaining[0].Remote.Value)
	}

	response, err = client.PostForm(resolveURL, url.Values{
		"csrf": {csrf}, "choice": {"server"}, "expectedWall": {"3002"}, "expectedLogical": {"0"}, "expectedDevice": {"desktop"},
	})
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	remaining, err = db.ListConflicts(context.Background(), user.ID)
	if err != nil || len(remaining) != 0 {
		t.Fatalf("fresh server choice did not resolve conflict: count=%d err=%v", len(remaining), err)
	}
	details, err := db.GetSyncDetails(context.Background(), user.ID, "settings", 0)
	if err != nil || len(details.Changes) == 0 {
		t.Fatalf("load resolved state: changes=%d err=%v", len(details.Changes), err)
	}
	resolved := details.Changes[0]
	if string(resolved.Value) != `{"layout":"pages"}` || resolved.Version.Device != "server-dashboard" {
		t.Fatalf("unexpected persisted resolution: value=%s device=%s", resolved.Value, resolved.Version.Device)
	}
}
