#ifndef RUNNER_SOUND_CHANNEL_H_
#define RUNNER_SOUND_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Pipljuden vid utlåning ("success", "card", "error") — spelas med Windows
// PlaySound från appens assets (data\flutter_assets\assets\sounds\<namn>.wav).
// Ersätter audioplayers, vars Windows-del inte går att bygga med nyare
// Visual Studio.
//
// Kanal "skolpunkten/sound", metod "play" med ljudets namn som argument.
class SoundChannel {
 public:
  explicit SoundChannel(flutter::BinaryMessenger* messenger);
  ~SoundChannel();

  SoundChannel(const SoundChannel&) = delete;
  SoundChannel& operator=(const SoundChannel&) = delete;

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SOUND_CHANNEL_H_
