#include "kiosk_mode.h"

#include <flutter/standard_method_codec.h>

#include <string>

KioskMode* KioskMode::instance_ = nullptr;

KioskMode::KioskMode(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window) {
  placement_ = {};
  placement_.length = sizeof(WINDOWPLACEMENT);
  instance_ = this;

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "skolpunkten/kiosk",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& name = call.method_name();
        if (name == "enter") {
          Enter();
          result->Success(flutter::EncodableValue(true));
        } else if (name == "exit") {
          Exit();
          result->Success(flutter::EncodableValue(true));
        } else if (name == "isActive") {
          result->Success(flutter::EncodableValue(active_));
        } else if (name == "quit") {
          Exit();
          result->Success(flutter::EncodableValue(true));
          PostMessage(window_, WM_CLOSE, 0, 0);
        } else {
          result->NotImplemented();
        }
      });
}

KioskMode::~KioskMode() {
  if (hook_) {
    UnhookWindowsHookEx(hook_);
    hook_ = nullptr;
  }
  if (channel_) channel_->SetMethodCallHandler(nullptr);
  if (instance_ == this) instance_ = nullptr;
}

void KioskMode::Enter() {
  if (active_) return;

  style_ = GetWindowLongPtr(window_, GWL_STYLE);
  ex_style_ = GetWindowLongPtr(window_, GWL_EXSTYLE);
  placement_.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(window_, &placement_);

  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST),
                 &monitor);

  SetWindowLongPtr(window_, GWL_STYLE,
                   style_ & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                              WS_MAXIMIZEBOX | WS_SYSMENU));
  SetWindowLongPtr(window_, GWL_EXSTYLE,
                   ex_style_ & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE |
                                 WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

  const RECT& r = monitor.rcMonitor;
  SetWindowPos(window_, HWND_TOPMOST, r.left, r.top, r.right - r.left,
               r.bottom - r.top, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  SetForegroundWindow(window_);

  hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc,
                           GetModuleHandle(nullptr), 0);
  active_ = true;
}

void KioskMode::Exit() {
  if (!active_) return;
  active_ = false;

  if (hook_) {
    UnhookWindowsHookEx(hook_);
    hook_ = nullptr;
  }

  SetWindowLongPtr(window_, GWL_STYLE, style_);
  SetWindowLongPtr(window_, GWL_EXSTYLE, ex_style_);
  SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
  SetWindowPlacement(window_, &placement_);
}

bool KioskMode::HandleMessage(UINT message, WPARAM wparam, LPARAM /*lparam*/,
                              LRESULT* result) {
  if (!active_) return false;

  switch (message) {
    case WM_CLOSE:
      // Fråga appen — den visar PIN-dialogen och anropar "quit" om koden
      // stämmer.
      channel_->InvokeMethod("closeRequested", nullptr);
      *result = 0;
      return true;

    case WM_SYSCOMMAND: {
      const WPARAM command = wparam & 0xFFF0;
      if (command == SC_CLOSE || command == SC_MINIMIZE ||
          command == SC_MAXIMIZE || command == SC_RESTORE ||
          command == SC_MOVE || command == SC_SIZE ||
          command == SC_KEYMENU) {
        *result = 0;
        return true;
      }
      break;
    }

    case WM_ACTIVATEAPP:
      // Något annat fönster tog fokus (t.ex. en avisering) — lägg appen
      // överst igen.
      if (!wparam) {
        SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
      }
      break;
  }
  return false;
}

LRESULT CALLBACK KioskMode::KeyboardProc(int code, WPARAM wparam,
                                         LPARAM lparam) {
  if (code == HC_ACTION && instance_ && instance_->active_) {
    const auto* key = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    const bool alt = (key->flags & LLKHF_ALTDOWN) != 0;
    const bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;

    switch (key->vkCode) {
      case VK_LWIN:
      case VK_RWIN:
      case VK_APPS:
        return 1;
      case VK_TAB:
      case VK_F4:
      case VK_SPACE:
        if (alt) return 1;
        break;
      case VK_ESCAPE:
        // Alt+Esc, Ctrl+Esc (Start) och Ctrl+Shift+Esc (Aktivitetshanteraren).
        // Esc ensamt släpps igenom — det stänger dialoger i appen.
        if (alt || ctrl) return 1;
        break;
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
