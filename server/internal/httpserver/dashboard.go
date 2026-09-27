package httpserver

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"dcomic-sync-server/internal/store"
)

type setupView struct {
	CSRF  string
	Error string
}

type loginView struct {
	CSRF  string
	Error string
}

type overviewView struct {
	Admin  store.User
	CSRF   string
	Stats  store.AdminStats
	Users  []store.UserSummary
	Notice string
	Error  string
}

type userView struct {
	Admin   store.User
	CSRF    string
	User    store.UserSummary
	Devices []store.Device
	Notice  string
	Error   string
}

func browserToken(bytes int) (string, error) {
	data := make([]byte, bytes)
	if _, err := rand.Read(data); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(data), nil
}

func (s *Server) setCookie(w http.ResponseWriter, name, value string, expires time.Time, httpOnly bool) {
	http.SetCookie(w, &http.Cookie{Name: name, Value: value, Path: "/dashboard", Secure: s.secure, HttpOnly: httpOnly, SameSite: http.SameSiteStrictMode, Expires: expires, MaxAge: int(time.Until(expires).Seconds())})
}

func (s *Server) clearCookie(w http.ResponseWriter, name string) {
	http.SetCookie(w, &http.Cookie{Name: name, Value: "", Path: "/dashboard", Secure: s.secure, HttpOnly: true, SameSite: http.SameSiteStrictMode, Expires: time.Unix(1, 0), MaxAge: -1})
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}

func (s *Server) handleSetupPage(w http.ResponseWriter, r *http.Request) {
	initialized, err := s.hasAdministrator(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	if initialized {
		http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
		return
	}
	csrf, err := browserToken(24)
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	s.setCookie(w, setupCSRFCookie, csrf, time.Now().Add(20*time.Minute), true)
	s.renderSetup(w, http.StatusOK, setupView{CSRF: csrf})
}

func (s *Server) handleSetup(w http.ResponseWriter, r *http.Request) {
	initialized, err := s.hasAdministrator(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	if initialized {
		http.Error(w, "administrator setup is no longer available", http.StatusConflict)
		return
	}
	if !s.validRequiredOrigin(r) {
		http.Error(w, "cross-site request rejected", http.StatusForbidden)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, formBodyLimit)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	csrfCookie, err := r.Cookie(setupCSRFCookie)
	csrf := r.Form.Get("csrf")
	if err != nil || csrfCookie.Value == "" || subtle.ConstantTimeCompare([]byte(csrfCookie.Value), []byte(csrf)) != 1 {
		http.Error(w, "invalid CSRF token", http.StatusForbidden)
		return
	}
	if subtle.ConstantTimeCompare([]byte(r.Form.Get("initializationCode")), []byte(s.initializationCode)) != 1 {
		s.renderSetup(w, http.StatusUnauthorized, setupView{CSRF: csrf, Error: "Invalid initialization code"})
		return
	}
	password := r.Form.Get("password")
	if password != r.Form.Get("confirmPassword") {
		s.renderSetup(w, http.StatusBadRequest, setupView{CSRF: csrf, Error: "Passwords do not match"})
		return
	}
	if _, err := s.store.BootstrapAdmin(r.Context(), "root", password); err != nil {
		if store.IsCode(err, store.CodeConflict) {
			hasAdmin, checkErr := s.store.HasAdmin(r.Context())
			if checkErr != nil {
				s.logger.Error("check administrator after setup conflict", "error", checkErr)
				http.Error(w, "internal server error", http.StatusInternalServerError)
				return
			}
			if hasAdmin {
				s.initialized.Store(true)
				http.Error(w, "administrator setup is no longer available", http.StatusConflict)
				return
			}
			s.renderSetup(w, http.StatusConflict, setupView{CSRF: csrf, Error: err.Error()})
			return
		}
		if store.IsCode(err, store.CodeBadRequest) {
			s.renderSetup(w, http.StatusBadRequest, setupView{CSRF: csrf, Error: err.Error()})
			return
		}
		s.logger.Error("create root administrator", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	s.initialized.Store(true)
	s.clearCookie(w, setupCSRFCookie)
	http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
}

func (s *Server) renderSetup(w http.ResponseWriter, status int, view setupView) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := dashboardTemplates.ExecuteTemplate(w, "setup", view); err != nil {
		s.logger.Error("render setup", "error", err)
	}
}

func (s *Server) redirectLogin(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/dashboard/login") {
		http.Error(w, "administrator authentication required", http.StatusUnauthorized)
		return
	}
	http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
}

func (s *Server) handleStyles(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/css; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	_, _ = w.Write([]byte(dashboardCSS))
}

func (s *Server) handleAdminLoginPage(w http.ResponseWriter, r *http.Request) {
	initialized, err := s.hasAdministrator(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	if !initialized {
		http.Redirect(w, r, "/dashboard/setup", http.StatusSeeOther)
		return
	}
	if cookie, err := r.Cookie(adminCookie); err == nil {
		if _, _, authErr := s.store.AuthenticateAdmin(r.Context(), cookie.Value); authErr == nil {
			http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
			return
		}
	}
	csrf, err := browserToken(24)
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	s.setCookie(w, loginCSRFCookie, csrf, time.Now().Add(20*time.Minute), true)
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := dashboardTemplates.ExecuteTemplate(w, "login", loginView{CSRF: csrf, Error: r.URL.Query().Get("error")}); err != nil {
		s.logger.Error("render login", "error", err)
	}
}

func (s *Server) handleAdminLogin(w http.ResponseWriter, r *http.Request) {
	initialized, err := s.hasAdministrator(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	if !initialized {
		http.Error(w, "administrator setup is required", http.StatusConflict)
		return
	}
	if !s.validOrigin(r) {
		http.Error(w, "cross-site request rejected", http.StatusForbidden)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, formBodyLimit)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	csrfCookie, err := r.Cookie(loginCSRFCookie)
	if err != nil || csrfCookie.Value == "" || subtle.ConstantTimeCompare([]byte(csrfCookie.Value), []byte(r.Form.Get("csrf"))) != 1 {
		http.Error(w, "invalid CSRF token", http.StatusForbidden)
		return
	}
	username, validationErr := store.ValidateUsername(r.Form.Get("username"))
	if validationErr != nil {
		http.Redirect(w, r, "/dashboard/login?error="+url.QueryEscape("Invalid username or password"), http.StatusSeeOther)
		return
	}
	ipKey := "ip:" + remoteIP(r)
	userKey := "admin-user:" + strings.ToLower(username)
	if !s.peerLoginLimits.Allow(ipKey) || !s.accountLoginLimits.Allow(userKey) {
		w.Header().Set("Retry-After", "600")
		http.Error(w, "too many login attempts", http.StatusTooManyRequests)
		return
	}
	token, _, _, err := s.store.LoginAdmin(r.Context(), username, r.Form.Get("password"), s.adminTTL)
	if err != nil {
		http.Redirect(w, r, "/dashboard/login?error="+url.QueryEscape("Invalid username or password"), http.StatusSeeOther)
		return
	}
	s.accountLoginLimits.Reset(userKey)
	s.setCookie(w, adminCookie, token, time.Now().Add(s.adminTTL), true)
	s.clearCookie(w, loginCSRFCookie)
	http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}

func (s *Server) handleAdminLogout(w http.ResponseWriter, r *http.Request) {
	_ = s.store.LogoutAdmin(r.Context(), r.Context().Value(adminTokenKey).(string))
	s.clearCookie(w, adminCookie)
	http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
}

func (s *Server) handleDashboard(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/dashboard" {
		http.NotFound(w, r)
		return
	}
	stats, err := s.store.Stats(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	users, err := s.store.ListUsers(r.Context())
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	view := overviewView{Admin: r.Context().Value(adminUserKey).(store.User), CSRF: r.Context().Value(adminCSRFKey).(string), Stats: stats, Users: users, Notice: r.URL.Query().Get("notice"), Error: r.URL.Query().Get("error")}
	s.render(w, "overview", view)
}

func (s *Server) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	_, err := s.store.CreateUser(r.Context(), r.Form.Get("username"), r.Form.Get("password"), false)
	if err != nil {
		http.Redirect(w, r, "/dashboard?error="+url.QueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, "/dashboard?notice="+url.QueryEscape("User created"), http.StatusSeeOther)
}

func (s *Server) handleUser(w http.ResponseWriter, r *http.Request) {
	s.renderUser(w, r, "", "")
}

func (s *Server) renderUser(w http.ResponseWriter, r *http.Request, notice, message string) {
	user, err := s.store.GetUser(r.Context(), r.PathValue("userID"))
	if err != nil {
		if store.IsCode(err, store.CodeNotFound) {
			http.NotFound(w, r)
		} else {
			http.Error(w, "internal server error", http.StatusInternalServerError)
		}
		return
	}
	devices, err := s.store.ListDevices(r.Context(), user.ID)
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	if notice == "" {
		notice = r.URL.Query().Get("notice")
	}
	if message == "" {
		message = r.URL.Query().Get("error")
	}
	view := userView{Admin: r.Context().Value(adminUserKey).(store.User), CSRF: r.Context().Value(adminCSRFKey).(string), User: user, Devices: devices, Notice: notice, Error: message}
	s.render(w, "user", view)
}

func (s *Server) handleDisableUser(w http.ResponseWriter, r *http.Request) {
	admin := r.Context().Value(adminUserKey).(store.User)
	if admin.ID == r.PathValue("userID") {
		s.redirectUser(w, r, "", "You cannot disable your current administrator account")
		return
	}
	if err := s.store.SetUserDisabled(r.Context(), r.PathValue("userID"), true); err != nil {
		s.redirectUser(w, r, "", err.Error())
		return
	}
	s.hub.Notify(r.PathValue("userID"))
	s.redirectUser(w, r, "Account disabled; active sessions were revoked", "")
}

func (s *Server) handleEnableUser(w http.ResponseWriter, r *http.Request) {
	if err := s.store.SetUserDisabled(r.Context(), r.PathValue("userID"), false); err != nil {
		s.redirectUser(w, r, "", err.Error())
		return
	}
	s.redirectUser(w, r, "Account enabled", "")
}

func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("userID")
	if err := s.store.AdminResetPassword(r.Context(), userID, r.Form.Get("password")); err != nil {
		s.redirectUser(w, r, "", err.Error())
		return
	}
	s.hub.Notify(userID)
	admin := r.Context().Value(adminUserKey).(store.User)
	if admin.ID == userID {
		s.clearCookie(w, adminCookie)
		http.Redirect(w, r, "/dashboard/login?error="+url.QueryEscape("Password reset; sign in again"), http.StatusSeeOther)
		return
	}
	s.redirectUser(w, r, "Password reset; all sessions were revoked", "")
}

func (s *Server) handleRevokeDevice(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("userID")
	if err := s.store.RevokeDevice(r.Context(), userID, r.PathValue("deviceID")); err != nil {
		s.redirectUser(w, r, "", err.Error())
		return
	}
	s.hub.Notify(userID)
	s.redirectUser(w, r, "Device session revoked", "")
}

func (s *Server) redirectUser(w http.ResponseWriter, r *http.Request, notice, message string) {
	values := url.Values{}
	if notice != "" {
		values.Set("notice", notice)
	}
	if message != "" {
		values.Set("error", message)
	}
	location := fmt.Sprintf("/dashboard/users/%s", url.PathEscape(r.PathValue("userID")))
	if encoded := values.Encode(); encoded != "" {
		location += "?" + encoded
	}
	http.Redirect(w, r, location, http.StatusSeeOther)
}

func (s *Server) render(w http.ResponseWriter, name string, value any) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := dashboardTemplates.ExecuteTemplate(w, name, value); err != nil {
		s.logger.Error("render dashboard", "template", name, "error", err)
	}
}
