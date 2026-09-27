package httpserver

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"dcomic-sync-server/internal/store"
)

const (
	adminCookie     = "dcomic_admin"
	loginCSRFCookie = "dcomic_login_csrf"
	setupCSRFCookie = "dcomic_setup_csrf"
	apiBodyLimit    = 4 << 20
	formBodyLimit   = 64 << 10
)

type Config struct {
	PublicURL        string
	Logger           *slog.Logger
	DeviceSessionTTL time.Duration
	AdminSessionTTL  time.Duration
}

type Server struct {
	store              *store.Store
	publicURL          *url.URL
	secure             bool
	logger             *slog.Logger
	deviceTTL          time.Duration
	adminTTL           time.Duration
	peerLoginLimits    *rateLimiter
	accountLoginLimits *rateLimiter
	hub                *eventHub
	initializationCode string
	initialized        atomic.Bool
	handler            http.Handler
}

func New(data *store.Store, config Config) (*Server, error) {
	if data == nil {
		return nil, fmt.Errorf("store is required")
	}
	var publicURL *url.URL
	if config.PublicURL != "" {
		parsed, err := url.Parse(config.PublicURL)
		if err != nil || parsed.Host == "" || parsed.User != nil || parsed.RawQuery != "" || parsed.ForceQuery || strings.Contains(config.PublicURL, "#") || parsed.Fragment != "" || parsed.Path != "" && parsed.Path != "/" || parsed.Scheme != "http" && parsed.Scheme != "https" {
			return nil, fmt.Errorf("public URL must be an HTTP or HTTPS absolute origin without path, query, user info, or fragment")
		}
		parsed.Path = ""
		publicURL = parsed
	}
	if config.Logger == nil {
		config.Logger = slog.Default()
	}
	if config.DeviceSessionTTL <= 0 {
		config.DeviceSessionTTL = 90 * 24 * time.Hour
	}
	if config.AdminSessionTTL <= 0 {
		config.AdminSessionTTL = 12 * time.Hour
	}
	hasAdmin, err := data.HasAdmin(context.Background())
	if err != nil {
		return nil, err
	}
	s := &Server{
		store: data, publicURL: publicURL, secure: publicURL != nil && publicURL.Scheme == "https", logger: config.Logger,
		deviceTTL: config.DeviceSessionTTL, adminTTL: config.AdminSessionTTL,
		peerLoginLimits: newRateLimiter(100, 10*time.Minute), accountLoginLimits: newRateLimiter(8, 10*time.Minute),
		hub: newEventHub(),
	}
	s.initialized.Store(hasAdmin)
	if !hasAdmin {
		s.initializationCode, err = browserToken(24)
		if err != nil {
			return nil, fmt.Errorf("generate initialization code: %w", err)
		}
		s.logger.Warn("administrator setup required", "setup_url", "/dashboard/setup", "initialization_code", s.initializationCode)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.handleRoot)
	mux.HandleFunc("GET /api/v1/time", s.handleTime)
	mux.HandleFunc("POST /api/v1/login", s.handleLogin)
	mux.HandleFunc("POST /api/v1/logout", s.withDevice(s.handleLogout))
	mux.HandleFunc("POST /api/v1/password", s.withDevice(s.handlePassword))
	mux.HandleFunc("POST /api/v1/sync", s.withDevice(s.handleSync))
	mux.HandleFunc("GET /api/v1/events", s.withDevice(s.handleEvents))
	mux.HandleFunc("GET /api/v1/conflicts", s.withDevice(s.handleConflicts))
	mux.HandleFunc("POST /api/v1/conflicts/resolve", s.withDevice(s.handleResolveConflict))
	mux.HandleFunc("GET /dashboard/assets/styles.css", s.handleStyles)
	mux.HandleFunc("GET /dashboard/setup", s.handleSetupPage)
	mux.HandleFunc("POST /dashboard/setup", s.handleSetup)
	mux.HandleFunc("GET /dashboard/login", s.handleAdminLoginPage)
	mux.HandleFunc("POST /dashboard/login", s.handleAdminLogin)
	mux.HandleFunc("POST /dashboard/logout", s.withAdmin(s.handleAdminLogout))
	mux.HandleFunc("GET /dashboard", s.withAdmin(s.handleDashboard))
	mux.HandleFunc("POST /dashboard/users", s.withAdmin(s.handleCreateUser))
	mux.HandleFunc("GET /dashboard/users/{userID}", s.withAdmin(s.handleUser))
	mux.HandleFunc("POST /dashboard/users/{userID}/disable", s.withAdmin(s.handleDisableUser))
	mux.HandleFunc("POST /dashboard/users/{userID}/enable", s.withAdmin(s.handleEnableUser))
	mux.HandleFunc("POST /dashboard/users/{userID}/password", s.withAdmin(s.handleResetPassword))
	mux.HandleFunc("POST /dashboard/users/{userID}/devices/{deviceID}/revoke", s.withAdmin(s.handleRevokeDevice))
	s.handler = s.securityHeaders(mux)
	return s, nil
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) { s.handler.ServeHTTP(w, r) }

func (s *Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.publicURL != nil && !strings.EqualFold(r.Host, s.publicURL.Host) {
			http.Error(w, "misdirected request", http.StatusMisdirectedRequest)
			return
		}
		w.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'")
		w.Header().Set("Referrer-Policy", "same-origin")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		if s.secure {
			w.Header().Set("Strict-Transport-Security", "max-age=31536000")
		}
		next.ServeHTTP(w, r)
	})
}

type contextKey int

const (
	deviceUserKey contextKey = iota
	deviceTokenKey
	adminUserKey
	adminCSRFKey
	adminTokenKey
)

func bearerToken(r *http.Request) string {
	header := r.Header.Get("Authorization")
	if len(header) < 8 || !strings.EqualFold(header[:7], "Bearer ") || strings.ContainsAny(header[7:], " \t\r\n") {
		return ""
	}
	return header[7:]
}

func (s *Server) hasAdministrator(ctx context.Context) (bool, error) {
	if s.initialized.Load() {
		return true, nil
	}
	exists, err := s.store.HasAdmin(ctx)
	if err != nil {
		return false, err
	}
	if exists {
		s.initialized.Store(true)
	}
	return exists, nil
}

func (s *Server) withDevice(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := bearerToken(r)
		user, err := s.store.AuthenticateDevice(r.Context(), token)
		if err != nil {
			s.writeError(w, err)
			return
		}
		ctx := context.WithValue(r.Context(), deviceUserKey, user)
		ctx = context.WithValue(ctx, deviceTokenKey, token)
		next(w, r.WithContext(ctx))
	}
}

func (s *Server) withAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		initialized, err := s.hasAdministrator(r.Context())
		if err != nil {
			http.Error(w, "internal server error", http.StatusInternalServerError)
			return
		}
		if !initialized {
			http.Redirect(w, r, "/dashboard/setup", http.StatusSeeOther)
			return
		}
		cookie, err := r.Cookie(adminCookie)
		if err != nil {
			s.redirectLogin(w, r)
			return
		}
		user, csrf, err := s.store.AuthenticateAdmin(r.Context(), cookie.Value)
		if err != nil {
			s.clearCookie(w, adminCookie)
			s.redirectLogin(w, r)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			if !s.validOrigin(r) {
				http.Error(w, "cross-site request rejected", http.StatusForbidden)
				return
			}
			r.Body = http.MaxBytesReader(w, r.Body, formBodyLimit)
			if err := r.ParseForm(); err != nil || subtle.ConstantTimeCompare([]byte(r.Form.Get("csrf")), []byte(csrf)) != 1 {
				http.Error(w, "invalid CSRF token", http.StatusForbidden)
				return
			}
		}
		ctx := context.WithValue(r.Context(), adminUserKey, user)
		ctx = context.WithValue(ctx, adminCSRFKey, csrf)
		ctx = context.WithValue(ctx, adminTokenKey, cookie.Value)
		next(w, r.WithContext(ctx))
	}
}

func (s *Server) validOrigin(r *http.Request) bool {
	if strings.EqualFold(r.Header.Get("Sec-Fetch-Site"), "cross-site") {
		return false
	}
	origin := r.Header.Get("Origin")
	if origin == "" {
		return true
	}
	expected := ""
	if s.publicURL != nil {
		expected = s.publicURL.Scheme + "://" + s.publicURL.Host
	} else {
		scheme := "http"
		if r.TLS != nil {
			scheme = "https"
		}
		expected = scheme + "://" + r.Host
	}
	return subtle.ConstantTimeCompare([]byte(origin), []byte(expected)) == 1
}

func (s *Server) validRequiredOrigin(r *http.Request) bool {
	return r.Header.Get("Origin") != "" && s.validOrigin(r)
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, apiBodyLimit)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return storeError(store.CodeBadRequest, "invalid JSON request")
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return storeError(store.CodeBadRequest, "request must contain one JSON object")
	}
	return nil
}

func storeError(code, message string) error {
	return &store.Error{Code: code, Message: message}
}

func (s *Server) writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		s.logger.Error("write JSON response", "error", err)
	}
}

func (s *Server) writeError(w http.ResponseWriter, err error) {
	status, code, message := http.StatusInternalServerError, "internal", "internal server error"
	var appErr *store.Error
	if errors.As(err, &appErr) {
		code, message = appErr.Code, appErr.Message
		switch appErr.Code {
		case store.CodeBadRequest:
			status = http.StatusBadRequest
		case store.CodeUnauthorized:
			status = http.StatusUnauthorized
		case store.CodeForbidden:
			status = http.StatusForbidden
		case store.CodeNotFound:
			status = http.StatusNotFound
		case store.CodeConflict, store.CodeVersionReuse:
			status = http.StatusConflict
		case store.CodeFutureClock:
			status = http.StatusUnprocessableEntity
		}
	} else {
		s.logger.Error("request failed", "error", err)
	}
	s.writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": message}})
}

func (s *Server) handleTime(w http.ResponseWriter, _ *http.Request) {
	s.writeJSON(w, http.StatusOK, map[string]int64{"serverTime": time.Now().UnixMilli()})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Username   string `json:"username"`
		Password   string `json:"password"`
		DeviceID   string `json:"deviceId"`
		DeviceName string `json:"deviceName"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		s.writeError(w, err)
		return
	}
	username, err := store.ValidateUsername(request.Username)
	if err != nil {
		s.writeError(w, err)
		return
	}
	request.Username = username
	ipKey := "ip:" + remoteIP(r)
	userKey := "api-user:" + strings.ToLower(request.Username)
	if !s.peerLoginLimits.Allow(ipKey) || !s.accountLoginLimits.Allow(userKey) {
		w.Header().Set("Retry-After", "600")
		s.writeJSON(w, http.StatusTooManyRequests, map[string]any{"error": map[string]string{"code": "rate_limited", "message": "too many login attempts"}})
		return
	}
	token, user, err := s.store.LoginDevice(r.Context(), request.Username, request.Password, request.DeviceID, request.DeviceName, s.deviceTTL)
	if err != nil {
		s.writeError(w, err)
		return
	}
	s.accountLoginLimits.Reset(userKey)
	s.hub.Notify(user.ID)
	s.writeJSON(w, http.StatusOK, map[string]any{"token": token, "userId": user.ID, "username": user.Username, "serverTime": time.Now().UnixMilli()})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	if err := decodeJSON(w, r, &struct{}{}); err != nil {
		s.writeError(w, err)
		return
	}
	token := r.Context().Value(deviceTokenKey).(string)
	if err := s.store.RevokeDeviceToken(r.Context(), token); err != nil {
		s.writeError(w, err)
		return
	}
	user := r.Context().Value(deviceUserKey).(store.User)
	s.hub.Notify(user.ID)
	s.writeJSON(w, http.StatusOK, struct{}{})
}

func (s *Server) handlePassword(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Current string `json:"currentPassword"`
		New     string `json:"newPassword"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		s.writeError(w, err)
		return
	}
	user := r.Context().Value(deviceUserKey).(store.User)
	if err := s.store.ChangePassword(r.Context(), user.ID, request.Current, request.New); err != nil {
		s.writeError(w, err)
		return
	}
	s.hub.Notify(user.ID)
	s.writeJSON(w, http.StatusOK, struct{}{})
}

func (s *Server) handleSync(w http.ResponseWriter, r *http.Request) {
	var request store.SyncRequest
	if err := decodeJSON(w, r, &request); err != nil {
		s.writeError(w, err)
		return
	}
	user := r.Context().Value(deviceUserKey).(store.User)
	response, err := s.store.Sync(r.Context(), user.ID, request, time.Now())
	if err != nil {
		s.writeError(w, err)
		return
	}
	for _, result := range response.Results {
		if result.Status == "accepted" {
			s.hub.Notify(user.ID)
			break
		}
	}
	s.writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleConflicts(w http.ResponseWriter, r *http.Request) {
	user := r.Context().Value(deviceUserKey).(store.User)
	conflicts, err := s.store.ListConflicts(r.Context(), user.ID)
	if err != nil {
		s.writeError(w, err)
		return
	}
	s.writeJSON(w, http.StatusOK, map[string]any{"conflicts": conflicts})
}

func (s *Server) handleResolveConflict(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Record   store.SyncRecord  `json:"record"`
		Rejected store.SyncVersion `json:"rejectedVersion"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		s.writeError(w, err)
		return
	}
	user := r.Context().Value(deviceUserKey).(store.User)
	canonical, err := s.store.ResolveConflict(r.Context(), user.ID, request.Record, request.Rejected, time.Now())
	if err != nil {
		s.writeError(w, err)
		return
	}
	s.hub.Notify(user.ID)
	s.writeJSON(w, http.StatusOK, canonical)
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		s.writeError(w, storeError(store.CodeBadRequest, "streaming unsupported"))
		return
	}
	user := r.Context().Value(deviceUserKey).(store.User)
	token := r.Context().Value(deviceTokenKey).(string)
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache, no-transform")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	updates, unsubscribe := s.hub.Subscribe(user.ID)
	defer unsubscribe()
	writeCursor := func() bool {
		cursor, err := s.store.LatestCursor(r.Context(), user.ID)
		if err != nil {
			return false
		}
		_, err = fmt.Fprintf(w, "event: change\ndata: %d\n\n", cursor)
		flusher.Flush()
		return err == nil
	}
	if !writeCursor() {
		return
	}
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case <-updates:
			if _, err := s.store.AuthenticateDevice(r.Context(), token); err != nil || !writeCursor() {
				return
			}
		case <-ticker.C:
			if _, err := s.store.AuthenticateDevice(r.Context(), token); err != nil {
				return
			}
			if _, err := io.WriteString(w, ": heartbeat\n\n"); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}

func remoteIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}

type rateEntry struct {
	count int
	reset time.Time
}
type rateLimiter struct {
	mu      sync.Mutex
	max     int
	window  time.Duration
	entries map[string]rateEntry
}

func newRateLimiter(max int, window time.Duration) *rateLimiter {
	return &rateLimiter{max: max, window: window, entries: make(map[string]rateEntry)}
}
func (l *rateLimiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	if len(l.entries) > 10_000 {
		for candidate, value := range l.entries {
			if now.After(value.reset) {
				delete(l.entries, candidate)
			}
		}
	}
	entry := l.entries[key]
	if now.After(entry.reset) {
		entry = rateEntry{reset: now.Add(l.window)}
	}
	if entry.count >= l.max {
		l.entries[key] = entry
		return false
	}
	entry.count++
	l.entries[key] = entry
	return true
}
func (l *rateLimiter) Reset(key string) { l.mu.Lock(); delete(l.entries, key); l.mu.Unlock() }

type eventHub struct {
	mu          sync.Mutex
	subscribers map[string]map[chan struct{}]struct{}
}

func newEventHub() *eventHub {
	return &eventHub{subscribers: make(map[string]map[chan struct{}]struct{})}
}
func (h *eventHub) Subscribe(userID string) (<-chan struct{}, func()) {
	h.mu.Lock()
	defer h.mu.Unlock()
	ch := make(chan struct{}, 1)
	if h.subscribers[userID] == nil {
		h.subscribers[userID] = make(map[chan struct{}]struct{})
	}
	h.subscribers[userID][ch] = struct{}{}
	return ch, func() {
		h.mu.Lock()
		delete(h.subscribers[userID], ch)
		if len(h.subscribers[userID]) == 0 {
			delete(h.subscribers, userID)
		}
		h.mu.Unlock()
	}
}
func (h *eventHub) Notify(userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for ch := range h.subscribers[userID] {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}
