#include "frame_reader.h"

#include <mfapi.h>
#include <propidl.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <utility>

namespace submersion_vision {

using Microsoft::WRL::ComPtr;

namespace {

std::wstring Wide(const std::string& s) {
  if (s.empty()) return std::wstring();
  const int len = MultiByteToWideChar(CP_UTF8, 0, s.data(),
                                      static_cast<int>(s.size()), nullptr, 0);
  std::wstring w(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()),
                      w.data(), len);
  return w;
}

std::string Hr(const char* what, HRESULT hr) {
  char buf[64];
  snprintf(buf, sizeof(buf), " (0x%08lX)", static_cast<unsigned long>(hr));
  return std::string(what) + buf;
}

// 100-nanosecond units to milliseconds, rounded.
int64_t Ms(LONGLONG hns) { return (hns + 5000) / 10000; }

}  // namespace

std::optional<VideoFrames> VideoFrames::Open(const std::string& path,
                                             FrameError* error) {
  VideoFrames video;
  ComPtr<IMFAttributes> attrs;
  HRESULT hr = MFCreateAttributes(&attrs, 1);
  if (FAILED(hr)) {
    *error = {"decode_failed", Hr("the reader could not be set up", hr)};
    return std::nullopt;
  }
  attrs->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
  hr = MFCreateSourceReaderFromURL(Wide(path).c_str(), attrs.Get(),
                                   &video.reader_);
  if (FAILED(hr)) {
    *error = {"decode_failed", Hr("the video could not be opened", hr)};
    return std::nullopt;
  }

  ComPtr<IMFMediaType> native;
  for (DWORD i = 0;; ++i) {
    ComPtr<IMFMediaType> type;
    if (FAILED(video.reader_->GetNativeMediaType(i, 0, &type))) break;
    GUID major = GUID_NULL;
    type->GetGUID(MF_MT_MAJOR_TYPE, &major);
    if (major == MFMediaType_Video) {
      video.stream_ = i;
      native = type;
      break;
    }
  }
  if (!native) {
    *error = {"decode_failed", "no video track"};
    return std::nullopt;
  }
  video.reader_->SetStreamSelection(
      static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
  video.reader_->SetStreamSelection(video.stream_, TRUE);
  video.rotation_ =
      static_cast<int>(MFGetAttributeUINT32(native.Get(), MF_MT_VIDEO_ROTATION,
                                            MFVideoRotationFormat_0)) % 360;

  ComPtr<IMFMediaType> rgb;
  hr = MFCreateMediaType(&rgb);
  if (FAILED(hr)) {
    *error = {"decode_failed", Hr("the reader could not be set up", hr)};
    return std::nullopt;
  }
  rgb->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  rgb->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
  hr = video.reader_->SetCurrentMediaType(video.stream_, nullptr, rgb.Get());
  if (FAILED(hr)) {
    *error = {"decode_failed", Hr("the video cannot be decoded to RGB", hr)};
    return std::nullopt;
  }
  if (!video.ReadLayout()) {
    *error = {"decode_failed", "the video has no frame size"};
    return std::nullopt;
  }
  // The picture's size is the container's, as the player shows it; the
  // decoder's own can be padded past it.
  UINT32 width = 0, height = 0;
  MFGetAttributeSize(native.Get(), MF_MT_FRAME_SIZE, &width, &height);
  video.width_ = width > 0 ? static_cast<int>(width) : video.coded_width_;
  video.height_ = height > 0 ? static_cast<int>(height) : video.coded_height_;

  PROPVARIANT duration;
  PropVariantInit(&duration);
  if (SUCCEEDED(video.reader_->GetPresentationAttribute(
          static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE), MF_PD_DURATION,
          &duration)) &&
      duration.vt == VT_UI8) {
    video.duration_ms_ = Ms(static_cast<LONGLONG>(duration.uhVal.QuadPart));
  }
  PropVariantClear(&duration);
  if (video.duration_ms_ <= 0) {
    *error = {"decode_failed", "no readable length"};
    return std::nullopt;
  }
  return video;
}

int VideoFrames::shown_width() const {
  return rotation_ == 90 || rotation_ == 270 ? height_ : width_;
}

int VideoFrames::shown_height() const {
  return rotation_ == 90 || rotation_ == 270 ? width_ : height_;
}

std::optional<Frame> VideoFrames::Next(int64_t at_or_after_ms, int max_side,
                                       FrameError* error) {
  if (at_or_after_ms >= duration_ms_) return std::nullopt;
  // Reading on is cheaper than seeking for a gap of a couple of seconds;
  // a chunk that starts later, or a time behind the reader, seeks.
  if (position_ms_ < 0 || at_or_after_ms < position_ms_ ||
      at_or_after_ms - position_ms_ > 2000) {
    if (!Seek(at_or_after_ms)) {
      *error = {"decode_failed", "the video cannot be seeked"};
      return std::nullopt;
    }
  }
  return ReadTo(at_or_after_ms, max_side, error);
}

std::optional<Frame> VideoFrames::FrameAt(int64_t ms, int max_side,
                                          FrameError* error) {
  // A moment that cannot be reached is answered with no frame, not an
  // error: the engine skips that moment and fails only when none is read.
  if (!Seek(ms)) return std::nullopt;
  return ReadTo(ms, max_side, error);
}

bool VideoFrames::ReadLayout() {
  ComPtr<IMFMediaType> current;
  if (FAILED(reader_->GetCurrentMediaType(stream_, &current))) return false;
  UINT32 width = 0, height = 0;
  MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &width, &height);
  if (width == 0 || height == 0) return false;
  coded_width_ = static_cast<int>(width);
  coded_height_ = static_cast<int>(height);
  UINT32 stride = 0;
  if (SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE, &stride))) {
    stride_ = static_cast<int>(static_cast<INT32>(stride));
  } else {
    LONG computed = 0;
    MFGetStrideForBitmapInfoHeader(MFVideoFormat_RGB32.Data1, width, &computed);
    stride_ = static_cast<int>(computed);
  }
  return true;
}

bool VideoFrames::Seek(int64_t ms) {
  PROPVARIANT position;
  PropVariantInit(&position);
  position.vt = VT_I8;
  position.hVal.QuadPart = static_cast<LONGLONG>(ms) * 10000;
  const HRESULT hr = reader_->SetCurrentPosition(GUID_NULL, position);
  PropVariantClear(&position);
  if (FAILED(hr)) return false;
  position_ms_ = -1;
  return true;
}

std::optional<Frame> VideoFrames::ReadTo(int64_t ms, int max_side,
                                         FrameError* error) {
  while (true) {
    DWORD actual = 0, flags = 0;
    LONGLONG time = 0;
    ComPtr<IMFSample> sample;
    const HRESULT hr =
        reader_->ReadSample(stream_, 0, &actual, &flags, &time, &sample);
    if (FAILED(hr)) {
      *error = {"decode_failed", Hr("reading a frame failed", hr)};
      return std::nullopt;
    }
    // A decoder error comes back as S_OK with this flag and no sample; left
    // unchecked, the loop below would ask for the next sample for ever.
    if (flags & MF_SOURCE_READERF_ERROR) {
      *error = {"decode_failed", "the decoder reported an error"};
      return std::nullopt;
    }
    if (flags & MF_SOURCE_READERF_ENDOFSTREAM) return std::nullopt;
    if ((flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) && !ReadLayout()) {
      *error = {"decode_failed", "the decoder's new frame layout is unreadable"};
      return std::nullopt;
    }
    if (!sample) continue;
    const int64_t at = Ms(time);
    position_ms_ = at;
    // Frames before the time asked are decoded but not looked at.
    if (at < ms) continue;
    return Convert(sample.Get(), at, max_side, error);
  }
}

std::optional<Frame> VideoFrames::Convert(IMFSample* sample, int64_t ms,
                                          int max_side,
                                          FrameError* error) const {
  Frame frame;
  frame.ms = ms;
  const int shown_w = shown_width(), shown_h = shown_height();
  const double scale = std::min(
      1.0, static_cast<double>(max_side) / std::max(shown_w, shown_h));
  frame.width = std::max(1, static_cast<int>(std::lround(shown_w * scale)));
  frame.height = std::max(1, static_cast<int>(std::lround(shown_h * scale)));
  frame.rgba.assign(static_cast<size_t>(frame.width) * frame.height * 4, 0);

  ComPtr<IMFMediaBuffer> buffer;
  if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) {
    *error = {"decode_failed", "a frame's buffer could not be read"};
    return std::nullopt;
  }
  DWORD length = 0;
  buffer->GetCurrentLength(&length);
  BYTE* row0 = nullptr;
  LONG pitch = 0;
  ComPtr<IMF2DBuffer> buffer2d;
  bool locked2d = false;
  BYTE* data = nullptr;
  if (SUCCEEDED(buffer.As(&buffer2d)) &&
      SUCCEEDED(buffer2d->Lock2D(&row0, &pitch))) {
    locked2d = true;
  } else {
    if (FAILED(buffer->Lock(&data, nullptr, &length))) {
      *error = {"decode_failed", "a frame's buffer could not be locked"};
      return std::nullopt;
    }
    pitch = stride_;
    row0 = pitch < 0
               ? data + static_cast<size_t>(coded_height_ - 1) * -pitch
               : data;
  }
  auto unlock = [&] {
    if (locked2d) {
      buffer2d->Unlock2D();
    } else {
      buffer->Unlock();
    }
  };
  // Never read past the decoder's buffer: a row shorter than the picture,
  // a picture larger than the coded frame or a buffer shorter than its
  // rows fails the frame instead.
  const size_t row_bytes = static_cast<size_t>(pitch < 0 ? -pitch : pitch);
  if (row_bytes < static_cast<size_t>(width_) * 4 ||
      coded_width_ < width_ || coded_height_ < height_ ||
      static_cast<size_t>(length) < row_bytes * static_cast<size_t>(coded_height_)) {
    unlock();
    *error = {"decode_failed", "unexpected decoded frame layout"};
    return std::nullopt;
  }

  // Each output pixel averages the stored pixels under it, taken out of the
  // stored frame turned clockwise by its rotation, as the player shows it.
  const int w = width_, h = height_;
  for (int oy = 0; oy < frame.height; ++oy) {
    const int y0 = std::min(shown_h - 1, static_cast<int>(oy / scale));
    const int y1 = std::max(y0 + 1, std::min(shown_h, static_cast<int>((oy + 1) / scale)));
    for (int ox = 0; ox < frame.width; ++ox) {
      const int x0 = std::min(shown_w - 1, static_cast<int>(ox / scale));
      const int x1 = std::max(x0 + 1, std::min(shown_w, static_cast<int>((ox + 1) / scale)));
      uint32_t r = 0, g = 0, b = 0, n = 0;
      for (int sy = y0; sy < y1; ++sy) {
        for (int sx = x0; sx < x1; ++sx) {
          int x = sx, y = sy;
          switch (rotation_) {
            case 90:
              x = sy;
              y = h - 1 - sx;
              break;
            case 180:
              x = w - 1 - sx;
              y = h - 1 - sy;
              break;
            case 270:
              x = w - 1 - sy;
              y = sx;
              break;
            default:
              break;
          }
          const BYTE* p = row0 + static_cast<ptrdiff_t>(y) * pitch + x * 4;
          b += p[0];
          g += p[1];
          r += p[2];
          ++n;
        }
      }
      uint8_t* out = &frame.rgba[(static_cast<size_t>(oy) * frame.width + ox) * 4];
      out[0] = static_cast<uint8_t>(r / n);
      out[1] = static_cast<uint8_t>(g / n);
      out[2] = static_cast<uint8_t>(b / n);
      out[3] = 255;
    }
  }

  unlock();
  return frame;
}

}  // namespace submersion_vision
