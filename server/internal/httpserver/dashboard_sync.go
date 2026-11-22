package httpserver

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"dcomic-sync-server/internal/store"
)

type syncDetailsView struct {
	Admin      store.User
	CSRF       string
	User       store.UserSummary
	Category   string
	Stats      store.CategoryStats
	Categories []store.CategoryStats
	Changes    []syncChangeView
	Conflicts  []syncConflictView
	NextURL    string
}

type syncChangeView struct {
	Sequence   int64
	Category   string
	Key        string
	Deleted    bool
	Value      string
	Redacted   bool
	DeviceName string
	DeviceID   string
	ReceivedAt time.Time
	Version    store.SyncVersion
}

type syncRecordView struct {
	Category   string
	Key        string
	Deleted    bool
	Value      string
	Redacted   bool
	DeviceName string
	DeviceID   string
	Version    store.SyncVersion
}

type syncConflictView struct {
	ID              string
	Candidate       syncRecordView
	Current         syncRecordView
	ExpectedWall    int64
	ExpectedLogical int64
	ExpectedDevice  string
}

func (s *Server) handleSyncDetails(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("userID")
	user, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		s.renderSyncError(w, r, err)
		return
	}
	category := r.URL.Query().Get("category")
	before := int64(0)
	if raw := r.URL.Query().Get("before"); raw != "" {
		before, err = strconv.ParseInt(raw, 10, 64)
		if err != nil || before < 0 {
			http.Error(w, "分页游标无效，请重新打开同步详情。", http.StatusBadRequest)
			return
		}
	}
	details, err := s.store.GetSyncDetails(r.Context(), userID, category, before)
	if err != nil {
		s.renderSyncError(w, r, err)
		return
	}
	devices, err := s.store.ListDevices(r.Context(), userID)
	if err != nil {
		http.Error(w, "服务器内部错误，请稍后重试。", http.StatusInternalServerError)
		return
	}
	conflicts, err := s.store.ListConflicts(r.Context(), userID)
	if err != nil {
		http.Error(w, "服务器内部错误，请稍后重试。", http.StatusInternalServerError)
		return
	}
	view := syncDetailsView{
		Admin: r.Context().Value(adminUserKey).(store.User), CSRF: r.Context().Value(adminCSRFKey).(string),
		User: user, Category: category, Stats: dashboardSelectedStats(details.Categories, category), Categories: details.Categories,
		Changes: dashboardChangeViews(details.Changes), Conflicts: dashboardConflictViews(conflicts, devices),
	}
	if details.NextBefore != 0 {
		values := url.Values{"before": {strconv.FormatInt(details.NextBefore, 10)}}
		if category != "" {
			values.Set("category", category)
		}
		view.NextURL = "/dashboard/users/" + url.PathEscape(userID) + "/sync?" + values.Encode()
	}
	s.render(w, "sync-details", view)
}

func (s *Server) handleDashboardResolveConflict(w http.ResponseWriter, r *http.Request) {
	expectedWall, wallErr := strconv.ParseInt(r.Form.Get("expectedWall"), 10, 64)
	expectedLogical, logicalErr := strconv.ParseInt(r.Form.Get("expectedLogical"), 10, 64)
	expectedDevice := r.Form.Get("expectedDevice")
	if wallErr != nil || logicalErr != nil || expectedWall < 0 || expectedLogical < 0 || expectedDevice == "" {
		s.redirectUser(w, r, "", "冲突版本无效，请刷新页面后重试。")
		return
	}
	userID := r.PathValue("userID")
	_, err := s.store.ResolveDashboardConflict(r.Context(), userID, r.PathValue("conflictID"), r.Form.Get("choice"), store.SyncVersion{
		Wall: expectedWall, Logical: expectedLogical, Device: expectedDevice,
	}, time.Now())
	if err != nil {
		s.redirectUser(w, r, "", s.dashboardError(err))
		return
	}
	s.hub.Notify(userID)
	s.redirectUser(w, r, "冲突已处理。", "")
}

func dashboardSelectedStats(categories []store.CategoryStats, selected string) store.CategoryStats {
	var total store.CategoryStats
	for _, stats := range categories {
		if selected == stats.Category {
			return stats
		}
		total.Records += stats.Records
		total.Deleted += stats.Deleted
		total.Conflicts += stats.Conflicts
	}
	return total
}

func dashboardChangeViews(changes []store.RecordDetail) []syncChangeView {
	views := make([]syncChangeView, 0, len(changes))
	for _, change := range changes {
		value, redacted := dashboardPayload(change.Category, change.Value, change.Deleted)
		views = append(views, syncChangeView{
			Sequence: change.Sequence, Category: change.Category, Key: change.Key, Deleted: change.Deleted,
			Value: value, Redacted: redacted, DeviceName: dashboardDeviceName(change.DeviceName, change.Version.Device),
			DeviceID: change.Version.Device, ReceivedAt: change.ReceivedAt, Version: change.Version,
		})
	}
	return views
}

func dashboardConflictViews(conflicts []store.Conflict, devices []store.Device) []syncConflictView {
	names := make(map[string]string, len(devices))
	for _, device := range devices {
		names[device.DeviceID] = device.Name
	}
	views := make([]syncConflictView, 0, len(conflicts))
	for _, conflict := range conflicts {
		views = append(views, syncConflictView{
			ID:           conflict.ID,
			Candidate:    dashboardRecordView(conflict.Local, names[conflict.Local.Version.Device]),
			Current:      dashboardRecordView(conflict.Remote, names[conflict.Remote.Version.Device]),
			ExpectedWall: conflict.Remote.Version.Wall, ExpectedLogical: conflict.Remote.Version.Logical,
			ExpectedDevice: conflict.Remote.Version.Device,
		})
	}
	return views
}

func dashboardRecordView(record store.SyncRecord, name string) syncRecordView {
	value, redacted := dashboardPayload(record.Category, record.Value, record.Deleted)
	return syncRecordView{
		Category: record.Category, Key: record.Key, Deleted: record.Deleted, Value: value, Redacted: redacted,
		DeviceName: dashboardDeviceName(name, record.Version.Device), DeviceID: record.Version.Device, Version: record.Version,
	}
}

func dashboardPayload(category string, value json.RawMessage, deleted bool) (string, bool) {
	if category == "credentials" {
		return "为保护账户安全，不显示令牌与 Cookie 的内容。", true
	}
	if deleted {
		return "此记录已删除（保留同步删除标记）。", false
	}
	var formatted bytes.Buffer
	if err := json.Indent(&formatted, value, "", "  "); err == nil {
		return formatted.String(), false
	}
	return string(value), false
}

func (s *Server) renderSyncError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case store.IsCode(err, store.CodeNotFound):
		http.Error(w, "用户或记录不存在。", http.StatusNotFound)
	case store.IsCode(err, store.CodeBadRequest):
		http.Error(w, s.dashboardError(err), http.StatusBadRequest)
	default:
		s.logger.Error("load dashboard sync details", "error", err)
		http.Error(w, "服务器内部错误，请稍后重试。", http.StatusInternalServerError)
	}
}
