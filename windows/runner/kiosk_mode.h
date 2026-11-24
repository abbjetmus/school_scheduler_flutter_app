#ifndef RUNNER_KIOSK_MODE_H_
#define RUNNER_KIOSK_MODE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Kioskläge för bibliotekets dator: fönstret täcker hela skärmen och ligger
// överst, går inte att stänga, flytta eller minimera, och Windows-tangenten,
// Alt+Tab, Alt+F4, Alt+Esc, Ctrl+Esc och Ctrl+Shift+Esc stängs av med en
// tangentbordshook. Ctrl+Alt+Del går inte att stänga av för ett program — se
// README för hur datorn låses med ett eget kioskkonto.
//
// Styrs från Dart över kanalen "skolpunkten/kiosk":
//   enter / exit / isActive / quit
// och meddelar Dart med "closeRequested" när någon försöker stänga fönstret,
// så att appen kan fråga efter PIN-koden.
class KioskMode {
 public:
  KioskMode(HWND window, flutter::BinaryMessenger* messenger);
  ~KioskMode();

  KioskMode(const KioskMode&) = delete;
  KioskMode& operator=(const KioskMode&) = delete;

  // Anropas från fönstrets meddelandehantering. Returnerar true om
  // meddelandet stoppades; då står svaret i |result|.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                     LRESULT* result);

 private:
  void Enter();
  void Exit();
  static LRESULT CALLBACK KeyboardProc(int code, WPARAM wparam, LPARAM lparam);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool active_ = false;
  WINDOWPLACEMENT placement_;
  LONG_PTR style_ = 0;
  LONG_PTR ex_style_ = 0;
  HHOOK hook_ = nullptr;

  static KioskMode* instance_;
};

#endif  // RUNNER_KIOSK_MODE_H_
