#include "color_encoder.h"

#define NOMINMAX
#include <windows.h>

#include <codecapi.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <thread>

namespace submersion_transcoder {

namespace {

using Microsoft::WRL::ComPtr;

// How the frames encode light, as in color_math.dart.
enum class Transfer { kSdr, kPq, kHlg };

// The timeline, interpolated the way the Dart ColorTimeline.matrixAt does.
std::array<float, 20> MatrixAt(const std::vector<TimelineKey>& keys,
                               double t) {
  std::array<float, 20> identity{1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
                                 0, 0, 1, 0, 0, 0, 0, 0, 1, 0};
  if (keys.empty()) return identity;
  if (t <= keys.front().time_ms) return keys.front().matrix;
  if (t >= keys.back().time_ms) return keys.back().matrix;
  // The first key at or after t, by binary search: asked per frame.
  const auto found = std::lower_bound(
      keys.begin() + 1, keys.end(), t,
      [](const TimelineKey& key, double time) { return key.time_ms < time; });
  const auto& lo = *(found - 1);
  const auto& hi = *found;
  const float f =
      static_cast<float>((t - lo.time_ms) / (hi.time_ms - lo.time_ms));
  std::array<float, 20> out{};
  for (int k = 0; k < 20; ++k) {
    out[k] = lo.matrix[k] + (hi.matrix[k] - lo.matrix[k]) * f;
  }
  return out;
}

// --- The colour formula (color_math.dart) ---------------------------------

constexpr double kPqWhite = 203.0;
constexpr double kHlgA = 0.17883277;
constexpr double kHlgB = 0.28466892;
constexpr double kHlgC = 0.559910729529562;
constexpr double kHlgWhite = 0.26496256042100724;

double PqEotf(double e) {
  const double p = std::pow(std::clamp(e, 0.0, 1.0), 1.0 / 78.84375);
  return 10000.0 *
         std::pow(std::max(p - 0.8359375, 0.0) / (18.8515625 - 18.6875 * p),
                  1.0 / 0.1593017578125);
}

double PqInverse(double nits) {
  const double y =
      std::pow(std::clamp(nits / 10000.0, 0.0, 1.0), 0.1593017578125);
  return std::pow((0.8359375 + 18.8515625 * y) / (1.0 + 18.6875 * y),
                  78.84375);
}

double HlgInverseOetf(double e) {
  return e <= 0.5 ? e * e / 3.0 : (std::exp((e - kHlgC) / kHlgA) + kHlgB) / 12.0;
}

double HlgOetf(double l) {
  return l <= 1.0 / 12.0 ? std::sqrt(3.0 * std::max(l, 0.0))
                         : kHlgA * std::log(12.0 * l - kHlgB) + kHlgC;
}

double SrgbEncode(double l) {
  const double x = std::abs(l);
  const double v =
      x <= 0.0031308 ? 12.92 * x : 1.055 * std::pow(x, 1.0 / 2.4) - 0.055;
  return l < 0 ? -v : v;
}

double SrgbDecode(double v) {
  const double x = std::abs(v);
  const double l = x <= 0.04045 ? x / 12.92 : std::pow((x + 0.055) / 1.055, 2.4);
  return v < 0 ? -l : l;
}

// Linear BT.709 to BT.2020 (ITU-R BT.2087) and its exact inverse.
struct Mat3 {
  double m[9];
  void Apply(const double in[3], double out[3]) const {
    for (int r = 0; r < 3; ++r) {
      out[r] = m[r * 3] * in[0] + m[r * 3 + 1] * in[1] + m[r * 3 + 2] * in[2];
    }
  }
};

constexpr Mat3 kTo2020{{0.627403895934699, 0.329283038377884, 0.043313065687417,
                        0.069097289358232, 0.919540395075459, 0.011362315566309,
                        0.016391438875150, 0.088013307877226,
                        0.895595253247624}};

Mat3 Invert(const Mat3& a) {
  const double* m = a.m;
  const double det = m[0] * (m[4] * m[8] - m[5] * m[7]) -
                     m[1] * (m[3] * m[8] - m[5] * m[6]) +
                     m[2] * (m[3] * m[7] - m[4] * m[6]);
  return {{(m[4] * m[8] - m[5] * m[7]) / det, (m[2] * m[7] - m[1] * m[8]) / det,
           (m[1] * m[5] - m[2] * m[4]) / det, (m[5] * m[6] - m[3] * m[8]) / det,
           (m[0] * m[8] - m[2] * m[6]) / det, (m[2] * m[3] - m[0] * m[5]) / det,
           (m[3] * m[7] - m[4] * m[6]) / det, (m[1] * m[6] - m[0] * m[7]) / det,
           (m[0] * m[4] - m[1] * m[3]) / det}};
}

const Mat3 kTo709 = Invert(kTo2020);

// Applies the 4x5 matrix to encoded R'G'B' (0..1) in place.
void Correct(double rgb[3], const std::array<float, 20>& m, Transfer t) {
  auto apply = [&m](const double in[3], double out[3]) {
    for (int r = 0; r < 3; ++r) {
      out[r] = m[r * 5] * in[0] + m[r * 5 + 1] * in[1] + m[r * 5 + 2] * in[2] +
               m[r * 5 + 3] + m[r * 5 + 4] / 255.0;
    }
  };
  if (t == Transfer::kSdr) {
    double out[3];
    apply(rgb, out);
    for (int c = 0; c < 3; ++c) rgb[c] = std::clamp(out[c], 0.0, 1.0);
    return;
  }
  double lin[3], l709[3], enc[3], k[3], dec[3], l2020[3];
  for (int c = 0; c < 3; ++c) {
    lin[c] = t == Transfer::kPq ? PqEotf(rgb[c]) / kPqWhite
                                : HlgInverseOetf(rgb[c]) / kHlgWhite;
  }
  kTo709.Apply(lin, l709);
  for (int c = 0; c < 3; ++c) enc[c] = SrgbEncode(l709[c]);
  apply(enc, k);
  for (int c = 0; c < 3; ++c) dec[c] = SrgbDecode(k[c]);
  kTo2020.Apply(dec, l2020);
  for (int c = 0; c < 3; ++c) {
    const double l = std::max(l2020[c], 0.0);
    rgb[c] = std::clamp(
        t == Transfer::kPq ? PqInverse(l * kPqWhite) : HlgOetf(l * kHlgWhite),
        0.0, 1.0);
  }
}

// --- YCbCr (limited range, 4:2:0) ------------------------------------------

struct Ycc {
  double kr, kb;
  bool ten_bit;
  // Full range (0..255) rather than video range (16..235, chroma 16..240),
  // as the source's MF_MT_VIDEO_NOMINAL_RANGE says.
  bool full_range = false;
  double Max() const { return ten_bit ? 1023.0 : 255.0; }
  double Scale() const { return ten_bit ? 4.0 : 1.0; }
  double YOffset() const { return full_range ? 0 : 16 * Scale(); }
  double YSpan() const { return full_range ? Max() : 219 * Scale(); }
  double CSpan() const { return full_range ? Max() : 224 * Scale(); }
  double CMid() const { return 128 * Scale(); }
  double ToY(int code) const { return (code - YOffset()) / YSpan(); }
  double ToC(int code) const { return (code - CMid()) / CSpan(); }
  int FromY(double y) const {
    return static_cast<int>(
        std::lround(std::clamp(YOffset() + y * YSpan(), 0.0, Max())));
  }
  int FromC(double c) const {
    return static_cast<int>(
        std::lround(std::clamp(CMid() + c * CSpan(), 0.0, Max())));
  }
  void ToRgb(double y, double cb, double cr, double rgb[3]) const {
    const double kg = 1 - kr - kb;
    rgb[0] = y + 2 * (1 - kr) * cr;
    rgb[2] = y + 2 * (1 - kb) * cb;
    rgb[1] = (y - kr * rgb[0] - kb * rgb[2]) / kg;
  }
  void FromRgb(const double rgb[3], double* y, double* cb, double* cr) const {
    const double kg = 1 - kr - kb;
    *y = kr * rgb[0] + kg * rgb[1] + kb * rgb[2];
    *cb = (rgb[2] - *y) / (2 * (1 - kb));
    *cr = (rgb[0] - *y) / (2 * (1 - kr));
  }
};

// One 4:2:0 frame in place: NV12 (8-bit) or P010 (10-bit, MSB-aligned 16-bit).
struct Planes {
  uint8_t* y;
  uint8_t* uv;
  LONG pitch;
  UINT32 width;
  UINT32 height;
};

int Sample(const uint8_t* row, UINT32 i, bool ten_bit) {
  if (!ten_bit) return row[i];
  uint16_t v;
  std::memcpy(&v, row + i * 2, 2);
  return v >> 6;
}

void Store(uint8_t* row, UINT32 i, int code, bool ten_bit) {
  if (!ten_bit) {
    row[i] = static_cast<uint8_t>(code);
    return;
  }
  const uint16_t v = static_cast<uint16_t>(code << 6);
  std::memcpy(row + i * 2, &v, 2);
}

void CorrectRows(const Planes& f, UINT32 from, UINT32 to,
                 const std::array<float, 20>& m, Transfer t, const Ycc& ycc) {
  for (UINT32 by = from; by < to; ++by) {
    uint8_t* uv = f.uv + by * f.pitch;
    for (UINT32 bx = 0; bx < f.width / 2; ++bx) {
      const double cb0 = ycc.ToC(Sample(uv, bx * 2, ycc.ten_bit));
      const double cr0 = ycc.ToC(Sample(uv, bx * 2 + 1, ycc.ten_bit));
      double cb_sum = 0, cr_sum = 0;
      for (int dy = 0; dy < 2; ++dy) {
        uint8_t* yrow = f.y + (by * 2 + dy) * f.pitch;
        for (int dx = 0; dx < 2; ++dx) {
          const UINT32 x = bx * 2 + dx;
          double rgb[3];
          ycc.ToRgb(ycc.ToY(Sample(yrow, x, ycc.ten_bit)), cb0, cr0, rgb);
          Correct(rgb, m, t);
          double y, cb, cr;
          ycc.FromRgb(rgb, &y, &cb, &cr);
          Store(yrow, x, ycc.FromY(y), ycc.ten_bit);
          cb_sum += cb;
          cr_sum += cr;
        }
      }
      Store(uv, bx * 2, ycc.FromC(cb_sum / 4), ycc.ten_bit);
      Store(uv, bx * 2 + 1, ycc.FromC(cr_sum / 4), ycc.ten_bit);
    }
  }
}

void CorrectFrame(const Planes& f, const std::array<float, 20>& m, Transfer t,
                  const Ycc& ycc) {
  const UINT32 block_rows = f.height / 2;
  const unsigned workers =
      std::max(1u, std::min(std::thread::hardware_concurrency(), 16u));
  std::vector<std::thread> threads;
  const UINT32 per = (block_rows + workers - 1) / workers;
  for (unsigned w = 0; w < workers; ++w) {
    const UINT32 from = w * per;
    const UINT32 to = std::min(block_rows, from + per);
    if (from >= to) break;
    threads.emplace_back(CorrectRows, std::cref(f), from, to, std::cref(m), t,
                         std::cref(ycc));
  }
  for (auto& th : threads) th.join();
}

// --- Media Foundation plumbing ----------------------------------------------

std::string Hr(const char* what, HRESULT hr) {
  char buf[96];
  std::snprintf(buf, sizeof(buf), "%s failed (0x%08lx)", what,
                static_cast<unsigned long>(hr));
  return buf;
}

bool IsUnsupported(HRESULT hr) {
  return hr == MF_E_TOPO_CODEC_NOT_FOUND || hr == MF_E_INVALIDMEDIATYPE ||
         hr == MF_E_UNSUPPORTED_D3D_TYPE || hr == MF_E_TRANSFORM_TYPE_NOT_SET ||
         hr == MF_E_UNSUPPORTED_FORMAT || hr == MF_E_INVALIDTYPE;
}

// Copies `key` from `from` to `to` when `from` has it.
void CopyAttr(IMFAttributes* from, IMFAttributes* to, REFGUID key) {
  PROPVARIANT v;
  PropVariantInit(&v);
  if (SUCCEEDED(from->GetItem(key, &v))) to->SetItem(key, v);
  PropVariantClear(&v);
}

struct Session {
  ~Session() {
    Release();
    if (mf_started) MFShutdown();
    if (com_started) CoUninitialize();
  }
  // Closes the output file, so it can be deleted or renamed.
  void Release() {
    writer.Reset();
    reader.Reset();
  }
  bool com_started = false;
  bool mf_started = false;
  ComPtr<IMFSourceReader> reader;
  ComPtr<IMFSinkWriter> writer;
};

}  // namespace

ColorEncodeResult EncodeWithColor(const std::wstring& source,
                                  const std::wstring& output,
                                  const std::vector<TimelineKey>& unsorted_keys,
                                  const std::function<void(double)>& progress,
                                  const std::atomic<bool>& cancelled) {
  std::vector<TimelineKey> keys = unsorted_keys;
  std::sort(keys.begin(), keys.end(),
            [](const TimelineKey& a, const TimelineKey& b) {
              return a.time_ms < b.time_ms;
            });
  const std::wstring tmp = output + L".tmp";
  DeleteFileW(tmp.c_str());
  // Media Foundation is shut down after the writer and reader are released,
  // whatever path returns.
  Session s;
  auto fail = [&tmp, &s](ColorEncodeOutcome outcome, std::string message) {
    s.Release();
    DeleteFileW(tmp.c_str());
    return ColorEncodeResult{outcome, std::move(message)};
  };
  auto hr_fail = [&fail](const char* what, HRESULT hr) {
    return fail(IsUnsupported(hr) ? ColorEncodeOutcome::kUnsupported
                                  : ColorEncodeOutcome::kFailed,
                Hr(what, hr));
  };

  {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    s.com_started = SUCCEEDED(hr);
    hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) return hr_fail("MFStartup", hr);
    s.mf_started = true;

    ComPtr<IMFAttributes> reader_attrs;
    MFCreateAttributes(&reader_attrs, 2);
    reader_attrs->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
    hr = MFCreateSourceReaderFromURL(source.c_str(), reader_attrs.Get(),
                                     &s.reader);
    if (FAILED(hr)) return hr_fail("opening the source", hr);

    // Samples report their real stream index, so find the video's.
    DWORD video_stream = 0;
    ComPtr<IMFMediaType> native;
    for (DWORD i = 0;; ++i) {
      ComPtr<IMFMediaType> type;
      hr = s.reader->GetNativeMediaType(i, 0, &type);
      if (FAILED(hr)) break;
      GUID major = GUID_NULL;
      type->GetGUID(MF_MT_MAJOR_TYPE, &major);
      if (major == MFMediaType_Video) {
        video_stream = i;
        native = type;
        break;
      }
    }
    if (!native) {
      return fail(ColorEncodeOutcome::kFailed, "no video track in the source");
    }
    s.reader->SetStreamSelection(
        static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
    s.reader->SetStreamSelection(video_stream, TRUE);

    GUID codec = GUID_NULL;
    native->GetGUID(MF_MT_SUBTYPE, &codec);
    UINT32 width = 0, height = 0;
    MFGetAttributeSize(native.Get(), MF_MT_FRAME_SIZE, &width, &height);
    if (width == 0 || height == 0) {
      return fail(ColorEncodeOutcome::kFailed, "the video has no frame size");
    }
    // 4:2:0 frames have even sides; an odd-sized source would have to be
    // cropped, which the copy must never do silently.
    if ((width & 1u) != 0 || (height & 1u) != 0) {
      return fail(ColorEncodeOutcome::kUnsupported,
                  "an odd frame size cannot be encoded as 4:2:0");
    }
    const UINT32 transfer_fn =
        MFGetAttributeUINT32(native.Get(), MF_MT_TRANSFER_FUNCTION,
                             MFVideoTransFunc_Unknown);
    const Transfer transfer = transfer_fn == MFVideoTransFunc_2084
                                  ? Transfer::kPq
                                  : (transfer_fn == MFVideoTransFunc_HLG
                                         ? Transfer::kHlg
                                         : Transfer::kSdr);
    const UINT32 profile =
        MFGetAttributeUINT32(native.Get(), MF_MT_MPEG2_PROFILE, 0);
    const bool is_h264 = codec == MFVideoFormat_H264;
    const bool ten_bit =
        transfer != Transfer::kSdr ||
        (codec == MFVideoFormat_HEVC &&
         profile == eAVEncH265VProfile_Main_420_10) ||
        (is_h264 && profile == eAVEncH264VProfile_High10);
    // There is no 10-bit H.264 encoder; such a clip becomes HEVC.
    const GUID out_codec =
        is_h264 && !ten_bit ? MFVideoFormat_H264 : MFVideoFormat_HEVC;
    const GUID frame_format = ten_bit ? MFVideoFormat_P010 : MFVideoFormat_NV12;
    // An untagged clip is read the way AVFoundation and Media3 read it:
    // BT.2020 for HDR, BT.601 below HD, BT.709 otherwise.
    const UINT32 matrix = MFGetAttributeUINT32(
        native.Get(), MF_MT_YUV_MATRIX,
        transfer != Transfer::kSdr ? MFVideoTransferMatrix_BT2020_10
        : height < 720             ? MFVideoTransferMatrix_BT601
                                   : MFVideoTransferMatrix_BT709);
    Ycc ycc{0.2126, 0.0722, ten_bit};
    ycc.full_range = MFGetAttributeUINT32(native.Get(), MF_MT_VIDEO_NOMINAL_RANGE,
                                          MFNominalRange_16_235) ==
                     MFNominalRange_0_255;
    if (matrix == MFVideoTransferMatrix_BT2020_10 ||
        matrix == MFVideoTransferMatrix_BT2020_12) {
      ycc.kr = 0.2627;
      ycc.kb = 0.0593;
    } else if (matrix == MFVideoTransferMatrix_BT601) {
      ycc.kr = 0.299;
      ycc.kb = 0.114;
    }

    // Decode to the matching 4:2:0 format, so no colour conversion of Media
    // Foundation's own sits between the decoder, the formula and the encoder.
    ComPtr<IMFMediaType> decoded;
    MFCreateMediaType(&decoded);
    decoded->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    decoded->SetGUID(MF_MT_SUBTYPE, frame_format);
    hr = s.reader->SetCurrentMediaType(video_stream, nullptr, decoded.Get());
    if (FAILED(hr)) return hr_fail("decoding the video", hr);
    // The decoder's buffer layout: its coded (possibly padded) size and row
    // stride. Read again whenever the decoder changes its output type.
    UINT32 coded_w = width, coded_h = height;
    LONG default_stride = 0;
    auto read_layout = [&] {
      ComPtr<IMFMediaType> current;
      if (FAILED(s.reader->GetCurrentMediaType(video_stream, &current))) return;
      MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &coded_w, &coded_h);
      UINT32 stride = 0;
      default_stride = SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE,
                                                    &stride))
                           ? static_cast<LONG>(stride)
                           : static_cast<LONG>(coded_w * (ten_bit ? 2 : 1));
    };
    read_layout();

    // Bitrate from the source, between 4 and 100 Mbit/s.
    UINT32 bitrate = MFGetAttributeUINT32(native.Get(), MF_MT_AVG_BITRATE, 0);
    bitrate = std::clamp<UINT32>(bitrate, 4'000'000u, 100'000'000u);

    PROPVARIANT duration_var;
    PropVariantInit(&duration_var);
    LONGLONG duration = 0;
    if (SUCCEEDED(s.reader->GetPresentationAttribute(
            static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE), MF_PD_DURATION,
            &duration_var))) {
      duration = static_cast<LONGLONG>(duration_var.uhVal.QuadPart);
    }
    PropVariantClear(&duration_var);

    ComPtr<IMFAttributes> writer_attrs;
    MFCreateAttributes(&writer_attrs, 2);
    // The .tmp extension says nothing about the container; ask for MP4.
    writer_attrs->SetGUID(MF_TRANSCODE_CONTAINERTYPE,
                          MFTranscodeContainerType_MPEG4);
    writer_attrs->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);
    hr = MFCreateSinkWriterFromURL(tmp.c_str(), nullptr, writer_attrs.Get(),
                                   &s.writer);
    if (FAILED(hr)) return hr_fail("creating the output", hr);

    // No MF_MT_VIDEO_ROTATION here: given one, the sink writer turns the
    // frames upright and letterboxes them. The Dart side copies the source's
    // rotation matrix into the finished copy instead.
    auto describe = [&](IMFMediaType* type) {
      type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
      MFSetAttributeSize(type, MF_MT_FRAME_SIZE, width, height);
      type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
      for (const GUID& key :
           {MF_MT_FRAME_RATE, MF_MT_PIXEL_ASPECT_RATIO, MF_MT_YUV_MATRIX,
            MF_MT_VIDEO_PRIMARIES, MF_MT_TRANSFER_FUNCTION,
            MF_MT_VIDEO_NOMINAL_RANGE,
            MF_MT_MAX_MASTERING_LUMINANCE, MF_MT_MIN_MASTERING_LUMINANCE,
            MF_MT_MAX_LUMINANCE_LEVEL, MF_MT_MAX_FRAME_AVERAGE_LUMINANCE_LEVEL,
            MF_MT_CUSTOM_VIDEO_PRIMARIES}) {
        CopyAttr(native.Get(), type, key);
      }
    };
    ComPtr<IMFMediaType> encoded;
    MFCreateMediaType(&encoded);
    describe(encoded.Get());
    encoded->SetGUID(MF_MT_SUBTYPE, out_codec);
    encoded->SetUINT32(MF_MT_AVG_BITRATE, bitrate);
    if (out_codec == MFVideoFormat_HEVC) {
      encoded->SetUINT32(MF_MT_MPEG2_PROFILE,
                         ten_bit ? eAVEncH265VProfile_Main_420_10
                                 : eAVEncH265VProfile_Main_420_8);
    } else {
      encoded->SetUINT32(MF_MT_MPEG2_PROFILE, eAVEncH264VProfile_High);
    }
    DWORD out_video = 0;
    hr = s.writer->AddStream(encoded.Get(), &out_video);
    if (FAILED(hr)) return hr_fail("adding the video stream", hr);
    ComPtr<IMFMediaType> frames_in;
    MFCreateMediaType(&frames_in);
    describe(frames_in.Get());
    frames_in->SetGUID(MF_MT_SUBTYPE, frame_format);
    frames_in->SetUINT32(MF_MT_DEFAULT_STRIDE, width * (ten_bit ? 2 : 1));
    hr = s.writer->SetInputMediaType(out_video, frames_in.Get(), nullptr);
    if (FAILED(hr)) return hr_fail("setting up the encoder", hr);

    // Audio: copied as it is when MP4 takes it, otherwise re-encoded as AAC.
    std::vector<std::pair<DWORD, DWORD>> audio;  // reader stream, writer stream
    for (DWORD i = 0;; ++i) {
      ComPtr<IMFMediaType> type;
      if (FAILED(s.reader->GetNativeMediaType(i, 0, &type))) break;
      GUID major = GUID_NULL;
      type->GetGUID(MF_MT_MAJOR_TYPE, &major);
      if (major != MFMediaType_Audio) continue;
      s.reader->SetStreamSelection(i, TRUE);
      GUID sub = GUID_NULL;
      type->GetGUID(MF_MT_SUBTYPE, &sub);
      DWORD out_stream = 0;
      if (sub == MFAudioFormat_AAC &&
          SUCCEEDED(s.reader->SetCurrentMediaType(i, nullptr, type.Get())) &&
          SUCCEEDED(s.writer->AddStream(type.Get(), &out_stream))) {
        audio.emplace_back(i, out_stream);
        continue;
      }
      // The AAC encoder takes 44.1 or 48 kHz and 1, 2 or 6 channels; any
      // other source is not re-encoded into something it was not.
      const UINT32 aac_rate = MFGetAttributeUINT32(
          type.Get(), MF_MT_AUDIO_SAMPLES_PER_SECOND, 0);
      const UINT32 channels =
          MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_NUM_CHANNELS, 0);
      if ((aac_rate != 44100 && aac_rate != 48000) ||
          (channels != 1 && channels != 2 && channels != 6)) {
        return fail(ColorEncodeOutcome::kUnsupported,
                    "the audio's rate or channel count cannot be kept in AAC");
      }
      ComPtr<IMFMediaType> pcm, aac;
      MFCreateMediaType(&pcm);
      pcm->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
      pcm->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
      pcm->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
      pcm->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, aac_rate);
      pcm->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, channels);
      MFCreateMediaType(&aac);
      aac->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
      aac->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
      aac->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
      aac->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, aac_rate);
      aac->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, channels);
      aac->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 24000);
      if (FAILED(s.reader->SetCurrentMediaType(i, nullptr, pcm.Get())) ||
          FAILED(s.writer->AddStream(aac.Get(), &out_stream))) {
        return fail(ColorEncodeOutcome::kUnsupported,
                    "the audio cannot be written to MP4");
      }
      ComPtr<IMFMediaType> pcm_current;
      s.reader->GetCurrentMediaType(i, &pcm_current);
      hr = s.writer->SetInputMediaType(out_stream, pcm_current.Get(), nullptr);
      if (FAILED(hr)) return hr_fail("setting up the audio encoder", hr);
      audio.emplace_back(i, out_stream);
    }

    hr = s.writer->BeginWriting();
    if (FAILED(hr)) return hr_fail("starting the output", hr);

    const size_t plane = static_cast<size_t>(width) * (ten_bit ? 2 : 1);
    const DWORD frame_size = static_cast<DWORD>(plane * height * 3 / 2);
    while (true) {
      if (cancelled.load()) {
        return fail(ColorEncodeOutcome::kCancelled, "cancelled");
      }
      DWORD stream = 0, flags = 0;
      LONGLONG time = 0;
      ComPtr<IMFSample> sample;
      hr = s.reader->ReadSample(
          static_cast<DWORD>(MF_SOURCE_READER_ANY_STREAM), 0, &stream, &flags,
          &time, &sample);
      if (FAILED(hr)) return hr_fail("reading the source", hr);
      if (flags & MF_SOURCE_READERF_ERROR) {
        return fail(ColorEncodeOutcome::kFailed, "the source could not be read");
      }
      if (flags & MF_SOURCE_READERF_ENDOFSTREAM) {
        s.reader->SetStreamSelection(stream, FALSE);
        bool any_left = false;
        for (DWORD i = 0;; ++i) {
          BOOL selected = FALSE;
          if (FAILED(s.reader->GetStreamSelection(i, &selected))) break;
          any_left = any_left || selected;
        }
        if (!any_left) break;
        continue;
      }
      if (stream == video_stream &&
          (flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)) {
        read_layout();
      }
      if (!sample) continue;

      if (stream != video_stream) {
        // Audio: pass the sample on to its writer stream.
        for (const auto& [in_stream, out_stream] : audio) {
          if (in_stream == stream) {
            hr = s.writer->WriteSample(out_stream, sample.Get());
            if (FAILED(hr)) return hr_fail("writing audio", hr);
          }
        }
        continue;
      }

      // Video: copied straight into the encoder's buffer as tight NV12/P010,
      // corrected there, encoded.
      ComPtr<IMFMediaBuffer> out_buffer;
      hr = MFCreateMemoryBuffer(frame_size, &out_buffer);
      if (FAILED(hr)) return hr_fail("allocating a frame", hr);
      BYTE* dst = nullptr;
      hr = out_buffer->Lock(&dst, nullptr, nullptr);
      if (FAILED(hr)) return hr_fail("locking a frame", hr);
      ComPtr<IMFMediaBuffer> in_buffer;
      hr = sample->ConvertToContiguousBuffer(&in_buffer);
      if (FAILED(hr)) {
        out_buffer->Unlock();
        return hr_fail("reading a frame", hr);
      }
      BYTE* src = nullptr;
      LONG src_pitch = default_stride;
      DWORD src_len = 0;
      ComPtr<IMF2DBuffer> two_d;
      bool locked_2d = false;
      if (SUCCEEDED(in_buffer.As(&two_d)) &&
          SUCCEEDED(two_d->Lock2D(&src, &src_pitch))) {
        locked_2d = true;
        in_buffer->GetCurrentLength(&src_len);
      } else {
        DWORD max_len = 0;
        hr = in_buffer->Lock(&src, &max_len, &src_len);
        if (FAILED(hr)) {
          out_buffer->Unlock();
          return hr_fail("locking a frame", hr);
        }
      }
      auto unlock = [&] {
        if (locked_2d) {
          two_d->Unlock2D();
        } else {
          in_buffer->Unlock();
        }
      };
      // Never read past the decoder's buffer: a layout this code does not
      // expect (a bottom-up or short buffer) fails the encode instead.
      const size_t needed =
          static_cast<size_t>(src_pitch) * (coded_h + coded_h / 2);
      if (src_pitch < static_cast<LONG>(plane) || coded_h < height ||
          src_len < needed) {
        unlock();
        out_buffer->Unlock();
        return fail(ColorEncodeOutcome::kFailed,
                    "unexpected decoded frame layout");
      }
      const uint8_t* src_uv = src + static_cast<size_t>(src_pitch) * coded_h;
      for (UINT32 row = 0; row < height; ++row) {
        std::memcpy(dst + row * plane, src + row * src_pitch, plane);
      }
      for (UINT32 row = 0; row < height / 2; ++row) {
        std::memcpy(dst + plane * height + row * plane,
                    src_uv + row * src_pitch, plane);
      }
      unlock();
      // Presentation time, as the player's position reads it, which is what
      // the app's timeline is sampled against.
      const Planes planes{dst, dst + plane * height, static_cast<LONG>(plane),
                          width, height};
      CorrectFrame(planes, MatrixAt(keys, time / 10000.0), transfer, ycc);
      out_buffer->Unlock();
      out_buffer->SetCurrentLength(frame_size);
      ComPtr<IMFSample> out_sample;
      MFCreateSample(&out_sample);
      out_sample->AddBuffer(out_buffer.Get());
      out_sample->SetSampleTime(time);
      LONGLONG frame_duration = 0;
      if (SUCCEEDED(sample->GetSampleDuration(&frame_duration))) {
        out_sample->SetSampleDuration(frame_duration);
      }
      hr = s.writer->WriteSample(out_video, out_sample.Get());
      if (FAILED(hr)) return hr_fail("encoding a frame", hr);
      if (duration > 0) {
        progress(std::min(1.0, static_cast<double>(time) / duration));
      }
    }

    hr = s.writer->Finalize();
    if (FAILED(hr)) return hr_fail("finishing the output", hr);
    s.Release();
  }

  progress(1.0);
  if (!MoveFileExW(tmp.c_str(), output.c_str(), MOVEFILE_REPLACE_EXISTING)) {
    return fail(ColorEncodeOutcome::kFailed, "rename failed");
  }
  return {};
}

}  // namespace submersion_transcoder
