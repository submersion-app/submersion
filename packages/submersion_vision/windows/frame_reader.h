#ifndef FLUTTER_PLUGIN_SUBMERSION_VISION_FRAME_READER_H_
#define FLUTTER_PLUGIN_SUBMERSION_VISION_FRAME_READER_H_

#define NOMINMAX
#include <windows.h>

#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace submersion_vision {

// RGBA pixels of one frame, rows top to bottom.
struct Frame {
  int64_t ms = 0;
  int width = 0;
  int height = 0;
  std::vector<uint8_t> rgba;
};

// A failure with the engine's error code.
struct FrameError {
  std::string code;
  std::string message;
};

// One opened video, read with Media Foundation's source reader as the
// transcoder's colour encode reads it: decoded to 32-bit RGB, turned as the
// player shows it (MF_MT_VIDEO_ROTATION) and fitted so its longer side is at
// most the size asked. Used from one thread, on which Media Foundation has
// been started.
class VideoFrames {
 public:
  // Opens [path] (UTF-8), or returns why it cannot.
  static std::optional<VideoFrames> Open(const std::string& path,
                                         FrameError* error);

  // The video's size as the player shows it, and its length.
  int shown_width() const;
  int shown_height() const;
  int64_t duration_ms() const { return duration_ms_; }

  // Pass 1: decodes on in order to the first frame shown at or after
  // [at_or_after_ms]; nothing at the end. Seeks first when that time is
  // behind the reader or well ahead of it.
  std::optional<Frame> Next(int64_t at_or_after_ms, int max_side,
                            FrameError* error);

  // Pass 2: the frame shown at [ms]; nothing when it cannot be read.
  std::optional<Frame> FrameAt(int64_t ms, int max_side, FrameError* error);

 private:
  VideoFrames() = default;

  bool Seek(int64_t ms);
  // The decoder's buffer layout (coded size and stride), read from its
  // current output type; again whenever the decoder changes that type.
  bool ReadLayout();
  // Reads frames until one is shown at or after [ms].
  std::optional<Frame> ReadTo(int64_t ms, int max_side, FrameError* error);
  // The frame turned and scaled as the player shows it; an error, never a
  // blank frame, when its buffer cannot be read or is not the layout
  // expected.
  std::optional<Frame> Convert(IMFSample* sample, int64_t ms, int max_side,
                               FrameError* error) const;

  Microsoft::WRL::ComPtr<IMFSourceReader> reader_;
  DWORD stream_ = 0;
  int width_ = 0;   // Stored picture size, before rotation (the container's).
  int height_ = 0;
  // The decoder's buffer: its coded size, which can be padded past the
  // picture (1080 rows decode into 1088), and the bytes a row; a negative
  // stride is bottom-up.
  int coded_width_ = 0;
  int coded_height_ = 0;
  int stride_ = 0;
  int rotation_ = 0;
  int64_t duration_ms_ = 0;
  int64_t position_ms_ = -1;  // The last frame read, or -1 before any.
};

}  // namespace submersion_vision

#endif  // FLUTTER_PLUGIN_SUBMERSION_VISION_FRAME_READER_H_
