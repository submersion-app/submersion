#include "flutter_window.h"

#include <optional>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shlobj.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {
using Microsoft::WRL::ComPtr;

std::wstring Widen(const std::string& utf8) {
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring w(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &w[0], len);
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

  HGLOBAL hg = nullptr;
  if (FAILED(GetHGlobalFromStream(stream.Get(), &hg))) return false;
  SIZE_T size = GlobalSize(hg);
  void* data = GlobalLock(hg);
  if (!data) return false;
  out->assign(static_cast<uint8_t*>(data),
              static_cast<uint8_t*>(data) + size);
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

  local_media_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.submersion.app/local_media",
          &flutter::StandardMethodCodec::GetInstance());
  local_media_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
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
        std::vector<uint8_t> png;
        if (path.empty() || !GenerateShellThumbnailPng(path, max_dim, &png)) {
          res->Success();  // null
          return;
        }
        res->Success(flutter::EncodableValue(png));
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
