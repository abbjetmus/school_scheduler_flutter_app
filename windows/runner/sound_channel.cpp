#include "sound_channel.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <mmsystem.h>

#include <string>

namespace {

// Mappen där exe-filen ligger, med avslutande \.
std::wstring ExeDirectory() {
  wchar_t path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring full(path, length);
  const size_t slash = full.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"" : full.substr(0, slash + 1);
}

// Bara korta namn med bokstäver — inga sökvägar.
bool IsSafeName(const std::string& name) {
  if (name.empty() || name.size() > 32) return false;
  for (const char c : name) {
    if (!((c >= 'a' && c <= 'z') || c == '_')) return false;
  }
  return true;
}

}  // namespace

SoundChannel::SoundChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "skolpunkten/sound",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "play") {
          result->NotImplemented();
          return;
        }
        const auto* name = std::get_if<std::string>(call.arguments());
        if (!name || !IsSafeName(*name)) {
          result->Error("bad_name", "Unknown sound");
          return;
        }
        const std::wstring file =
            ExeDirectory() + L"data\\flutter_assets\\assets\\sounds\\" +
            std::wstring(name->begin(), name->end()) + L".wav";
        // Asynkront: utlåningen väntar inte på ljudet, och ett nytt ljud
        // avbryter det som spelas.
        const BOOL ok =
            PlaySoundW(file.c_str(), nullptr, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
        result->Success(flutter::EncodableValue(ok != FALSE));
      });
}

SoundChannel::~SoundChannel() {
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}
