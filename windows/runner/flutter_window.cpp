#include "flutter_window.h"

#include <algorithm>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr wchar_t kWindowStateKey[] = L"Software\\DComicReborn";
constexpr wchar_t kWindowStateValue[] = L"WindowState";

struct WindowState {
  DWORD width;
  DWORD height;
  DWORD maximized;
};

// Store normal window dimensions in logical pixels, not the maximized bounds.
void SaveWindowState(HWND window) {
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }
  const UINT dpi = GetDpiForWindow(window);
  if (dpi == 0) {
    return;
  }
  const RECT& bounds = placement.rcNormalPosition;
  const int width = MulDiv(bounds.right - bounds.left, 96, dpi);
  const int height = MulDiv(bounds.bottom - bounds.top, 96, dpi);
  if (width <= 0 || height <= 0) {
    return;
  }
  const WindowState state = {
      static_cast<DWORD>(width), static_cast<DWORD>(height),
      placement.showCmd == SW_SHOWMAXIMIZED ||
              (placement.showCmd == SW_SHOWMINIMIZED &&
               (placement.flags & WPF_RESTORETOMAXIMIZED) != 0)
          ? 1u
          : 0u};
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kWindowStateKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) == ERROR_SUCCESS) {
    RegSetValueExW(key, kWindowStateValue, 0, REG_BINARY,
                   reinterpret_cast<const BYTE*>(&state), sizeof(state));
    RegCloseKey(key);
  }
}

bool RestoreWindowSize(HWND window) {
  WindowState state = {};
  DWORD bytes = sizeof(state);
  if (RegGetValueW(HKEY_CURRENT_USER, kWindowStateKey, kWindowStateValue,
                  RRF_RT_REG_BINARY, nullptr, &state, &bytes) != ERROR_SUCCESS ||
      bytes != sizeof(state) || state.width == 0 || state.height == 0 ||
      state.width > 32767 || state.height > 32767 || state.maximized > 1) {
    return false;
  }
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(monitor);
  const UINT dpi = GetDpiForWindow(window);
  if (dpi == 0 ||
      !GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                       &monitor)) {
    return false;
  }
  const RECT& work = monitor.rcWork;
  const int width = std::min(MulDiv(static_cast<int>(state.width), dpi, 96),
                             static_cast<int>(work.right - work.left));
  const int height = std::min(MulDiv(static_cast<int>(state.height), dpi, 96),
                              static_cast<int>(work.bottom - work.top));
  RECT bounds = {};
  GetWindowRect(window, &bounds);
  const int x = std::clamp(bounds.left, work.left, work.right - width);
  const int y = std::clamp(bounds.top, work.top, work.bottom - height);
  SetWindowPos(window, nullptr, x, y, width, height,
               SWP_NOZORDER | SWP_NOACTIVATE);
  return state.maximized != 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  start_maximized_ = RestoreWindowSize(GetHandle());

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    ::ShowWindow(GetHandle(), start_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE) {
    SaveWindowState(hwnd);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
