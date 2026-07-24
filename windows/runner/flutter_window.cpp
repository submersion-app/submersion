#include "flutter_window.h"

#include <optional>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shlobj.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {
using Microsoft::WRL::ComPtr;

// Returns an empty string when the input is empty or cannot be converted:
// MultiByteToWideChar returns 0 on failure, and writing through &w[0] on a
// zero-length wstring would be undefined behaviour.
std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (len <= 0) return std::wstring();
  std::wstring w(len, L'\0');
  if (MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &w[0], len) <= 0) {
    return std::wstring();
  }
  if (!w.empty() && w.back() == L'\0') w.pop_back();
  return w;
}

// Encodes an HBITMAP to PNG bytes via WIC.
bool HBitmapToPng(HBITMAP hbmp, std::vector<uint8_t>* out) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IWICBitmap> bmp;
  if (FAILED(factory->CreateBitmapFromHBITMAP(
          hbmp, nullptr, WICBitmapUsePremultipliedAlpha, &bmp))) {
    return false;
  }
  ComPtr<IStream> stream;
  if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) return false;
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder))) {
    return false;
  }
  if (FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)))
    return false;
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IPropertyBag2> props;
  if (FAILED(encoder->CreateNewFrame(&frame, &props))) return false;
  if (FAILED(frame->Initialize(props.Get()))) return false;
  UINT w = 0, h = 0;
  bmp->GetSize(&w, &h);
  frame->SetSize(w, h);
  WICPixelFormatGUID fmt = GUID_WICPixelFormat32bppBGRA;
  frame->SetPixelFormat(&fmt);
  if (FAILED(frame->WriteSource(bmp.Get(), nullptr))) return false;
  if (FAILED(frame->Commit())) return false;
  if (FAILED(encoder->Commit())) return false;

  // Use the stream's LOGICAL size, not GlobalSize(). CreateStreamOnHGlobal
  // grows its HGLOBAL in chunks, so the allocation is normally larger than the
  // encoded PNG; copying GlobalSize bytes would append allocated-but-unwritten
  // padding to the payload. STATFLAG_NONAME skips the name field, so there is
  // nothing to CoTaskMemFree.
  STATSTG stat = {};
  if (FAILED(stream->Stat(&stat, STATFLAG_NONAME))) return false;
  const ULONGLONG written = stat.cbSize.QuadPart;
  if (written == 0) return false;

  HGLOBAL hg = nullptr;
  if (FAILED(GetHGlobalFromStream(stream.Get(), &hg))) return false;
  // Defensive: never read past the actual allocation.
  if (written > GlobalSize(hg)) return false;
  void* data = GlobalLock(hg);
  if (!data) return false;
  out->assign(static_cast<uint8_t*>(data),
              static_cast<uint8_t*>(data) + static_cast<size_t>(written));
  GlobalUnlock(hg);
  return !out->empty();
}

bool GenerateShellThumbnailPng(const std::string& path, int max_dim,
                               std::vector<uint8_t>* out) {
  ComPtr<IShellItemImageFactory> factory;
  if (FAILED(SHCreateItemFromParsingName(
          Widen(path).c_str(), nullptr, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  SIZE size{max_dim, max_dim};
  HBITMAP hbmp = nullptr;
  if (FAILED(factory->GetImage(size, SIIGBF_THUMBNAILONLY, &hbmp))) {
    // Retry allowing the shell to synthesize (icon-or-thumbnail).
    if (FAILED(factory->GetImage(size, SIIGBF_BIGGERSIZEOK, &hbmp))) {
      return false;
    }
  }
  bool ok = HBitmapToPng(hbmp, out);
  DeleteObject(hbmp);
  return ok;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

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

  thumb_bridge_ = std::make_shared<ThumbnailBridge>();
  thumb_bridge_->hwnd = GetHandle();

  local_media_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.submersion.app/local_media",
          &flutter::StandardMethodCodec::GetInstance());
  local_media_channel_->SetMethodCallHandler(
      [bridge = thumb_bridge_](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> res) {
        if (call.method_name() != "generateVideoThumbnail") {
          res->NotImplemented();
          return;
        }
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          res->Success();
          return;
        }
        std::string path;
        int max_dim = 512;
        auto pit = args->find(flutter::EncodableValue("path"));
        if (pit != args->end() &&
            std::holds_alternative<std::string>(pit->second)) {
          path = std::get<std::string>(pit->second);
        }
        auto mit = args->find(flutter::EncodableValue("maxDimension"));
        if (mit != args->end() &&
            std::holds_alternative<int32_t>(mit->second)) {
          max_dim = std::get<int32_t>(mit->second);
        }
        // Clamp at the channel boundary (mirrors the Dart caller's 1..4096):
        // a negative or absurd value would otherwise reach IShellItemImageFactory
        // as an invalid SIZE or provoke a large allocation.
        if (max_dim < 1) max_dim = 1;
        if (max_dim > 4096) max_dim = 4096;
        if (path.empty()) {
          res->Success();  // null
          return;
        }
        // Shell extraction + WIC encoding is synchronous and can take a while
        // for an uncached codec or a large file. This handler runs on the
        // platform/UI thread and the grid asks for a poster per visible tile,
        // so doing it inline would stall the message loop (input, painting).
        // Run it on a worker and complete the result back on the platform
        // thread, mirroring the Linux GTask handling.
        std::thread([bridge, path, max_dim,
                     r = std::move(res)]() mutable {
          // The shell and WIC APIs are COM; a fresh thread has no apartment,
          // so CoCreateInstance would fail with CO_E_NOTINITIALIZED without
          // this. Shell thumbnail handlers expect an STA.
          const HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
          std::vector<uint8_t> png;
          GenerateShellThumbnailPng(path, max_dim, &png);
          if (SUCCEEDED(hr)) CoUninitialize();

          {
            std::lock_guard<std::mutex> lock(bridge->mutex);
            bridge->completed.emplace_back(std::move(r), std::move(png));
          }
          // If the window is gone the result is simply never completed; the
          // process is shutting down. PostMessage to a stale HWND fails
          // harmlessly rather than crashing.
          if (bridge->alive.load()) {
            // Qualified: this runs inside a lambda, so spell out the enclosing
            // class rather than leaning on unqualified lookup reaching it.
            PostMessage(bridge->hwnd, FlutterWindow::kThumbnailReadyMsg, 0, 0);
          }
        }).detach();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // Add "Check for Updates..." to the window system menu
  HMENU sys_menu = GetSystemMenu(GetHandle(), FALSE);
  if (sys_menu) {
    AppendMenu(sys_menu, MF_SEPARATOR, 0, nullptr);
    AppendMenu(sys_menu, MF_STRING, kCheckForUpdatesCmd,
               L"Check for Updates...");
  }

  return true;
}

void FlutterWindow::OnDestroy() {
  // Stop in-flight thumbnail workers from posting to a window that is going
  // away. Any result still parked in the bridge is simply never completed,
  // which is correct at shutdown.
  if (thumb_bridge_) {
    thumb_bridge_->alive = false;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
    case kThumbnailReadyMsg: {
      // Runs on the platform thread, which is the only place a MethodResult
      // may be completed. Drain under the lock, then respond outside it.
      decltype(ThumbnailBridge::completed) ready;
      if (thumb_bridge_) {
        std::lock_guard<std::mutex> lock(thumb_bridge_->mutex);
        ready.swap(thumb_bridge_->completed);
      }
      for (auto& entry : ready) {
        if (entry.second.empty()) {
          entry.first->Success();  // null -> Dart falls back to placeholder
        } else {
          entry.first->Success(flutter::EncodableValue(entry.second));
        }
      }
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SYSCOMMAND:
      if ((wparam & 0xFFF0) == kCheckForUpdatesCmd) {
        if (flutter_controller_) {
          flutter_controller_->engine()->ProcessMessages();
          auto channel = flutter::MethodChannel<flutter::EncodableValue>(
              flutter_controller_->engine()->messenger(),
              "app.submersion/updates",
              &flutter::StandardMethodCodec::GetInstance());
          channel.InvokeMethod("checkForUpdateInteractively", nullptr);
        }
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
