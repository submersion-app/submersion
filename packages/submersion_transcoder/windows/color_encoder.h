#ifndef FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_COLOR_ENCODER_H_
#define FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_COLOR_ENCODER_H_

#include <array>
#include <atomic>
#include <functional>
#include <string>
#include <vector>

namespace submersion_transcoder {

// One key of the app's colour timeline: the 4x5 matrix (row-major; offsets on
// the 0-255 scale) in effect `time_ms` into the clip (issue #3521).
struct TimelineKey {
  double time_ms = 0;
  std::array<float, 20> matrix{};
};

enum class ColorEncodeOutcome { kOk, kCancelled, kUnsupported, kFailed };

struct ColorEncodeResult {
  ColorEncodeOutcome outcome = ColorEncodeOutcome::kOk;
  std::string message;
};

// Re-encodes `source` into `output` with the timeline applied to every frame,
// with the one formula color_math.dart pins. Keeps the codec family (H.264 or
// HEVC; anything else, or 10-bit H.264, becomes HEVC), dimensions, rotation,
// frame timing, bit depth, HDR colour tags and the audio. Writes
// "<output>.tmp" and renames it on success; never leaves the .tmp behind.
// Runs on the calling thread, which must be a worker thread.
ColorEncodeResult EncodeWithColor(const std::wstring& source,
                                  const std::wstring& output,
                                  const std::vector<TimelineKey>& keys,
                                  const std::function<void(double)>& progress,
                                  const std::atomic<bool>& cancelled);

}  // namespace submersion_transcoder

#endif  // FLUTTER_PLUGIN_SUBMERSION_TRANSCODER_COLOR_ENCODER_H_
