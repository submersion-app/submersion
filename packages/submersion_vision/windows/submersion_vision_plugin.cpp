#include "submersion_vision_plugin.h"

#include <mfapi.h>
#include <objbase.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <exception>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace submersion_vision {

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

using Result = flutter::MethodResult<EncodableValue>;

std::optional<int64_t> IntArg(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(&it->second)) return *v;
  if (const auto* v = std::get_if<int64_t>(&it->second)) return *v;
  return std::nullopt;
}

EncodableValue FrameReply(const Frame& frame, bool with_time) {
  EncodableMap reply{
      {EncodableValue("width"), EncodableValue(frame.width)},
      {EncodableValue("height"), EncodableValue(frame.height)},
      {EncodableValue("rgba"), EncodableValue(frame.rgba)},
  };
  if (with_time) {
    reply[EncodableValue("ms")] = EncodableValue(static_cast<int64_t>(frame.ms));
  }
  return EncodableValue(reply);
}

}  // namespace

// static
void SubmersionVisionPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "submersion_vision/frames",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<SubmersionVisionPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

SubmersionVisionPlugin::SubmersionVisionPlugin()
    : worker_([this] { Run(); }) {}

SubmersionVisionPlugin::~SubmersionVisionPlugin() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stopping_ = true;
  }
  wake_.notify_one();
  if (worker_.joinable()) worker_.join();
}

void SubmersionVisionPlugin::Post(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks_.push_back(std::move(task));
  }
  wake_.notify_one();
}

void SubmersionVisionPlugin::Run() {
  const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool mf = SUCCEEDED(MFStartup(MF_VERSION));
  while (true) {
    std::function<void()> task;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      wake_.wait(lock, [this] { return stopping_ || !tasks_.empty(); });
      if (stopping_ && tasks_.empty()) break;
      task = std::move(tasks_.front());
      tasks_.pop_front();
    }
    task();
  }
  videos_.clear();
  if (mf) MFShutdown();
  if (SUCCEEDED(com)) CoUninitialize();
}

void SubmersionVisionPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<Result> unique_result) {
  const std::string method = method_call.method_name();
  const auto* map = std::get_if<EncodableMap>(method_call.arguments());
  const EncodableMap args = map ? *map : EncodableMap();
  std::shared_ptr<Result> result = std::move(unique_result);

  if (method == "deviceState") {
    MEMORYSTATUSEX status{};
    status.dwLength = sizeof(status);
    const int64_t available =
        GlobalMemoryStatusEx(&status) ? static_cast<int64_t>(status.ullAvailPhys)
                                      : 0;
    // A PC is not stopped for heat, as a Mac is not.
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("thermalSevere"), EncodableValue(false)},
        {EncodableValue("lowMemory"), EncodableValue(false)},
        {EncodableValue("availableBytes"), EncodableValue(available)},
    }));
    return;
  }
  if (method != "open" && method != "next" && method != "frameAt" &&
      method != "close") {
    result->NotImplemented();
    return;
  }

  Post([this, method, args, result] {
    // Media Foundation and allocations can throw; an exception that left
    // this worker thread would end the app, so each call answers instead.
    try {
      FrameError error;
      if (method == "open") {
        const auto it = args.find(EncodableValue("path"));
        const auto* path =
            it == args.end() ? nullptr : std::get_if<std::string>(&it->second);
        if (path == nullptr) {
          result->Error("bad_arguments", "path");
          return;
        }
        auto video = VideoFrames::Open(*path, &error);
        if (!video) {
          result->Error(error.code, error.message);
          return;
        }
        const int64_t handle = next_handle_++;
        const EncodableMap reply{
            {EncodableValue("handle"), EncodableValue(handle)},
            {EncodableValue("width"), EncodableValue(video->shown_width())},
            {EncodableValue("height"), EncodableValue(video->shown_height())},
            {EncodableValue("durationMs"),
             EncodableValue(static_cast<int64_t>(video->duration_ms()))},
        };
        videos_.emplace(handle, std::move(*video));
        result->Success(EncodableValue(reply));
        return;
      }

      const auto handle = IntArg(args, "handle");
      const auto found = handle ? videos_.find(*handle) : videos_.end();
      if (method == "close") {
        if (found != videos_.end()) videos_.erase(found);
        result->Success();
        return;
      }
      if (found == videos_.end()) {
        result->Error("decode_failed", "the video is not open");
        return;
      }
      const auto max_side = IntArg(args, "maxSide");
      if (!max_side) {
        result->Error("bad_arguments", "maxSide");
        return;
      }
      std::optional<Frame> frame;
      if (method == "next") {
        const auto at = IntArg(args, "atOrAfterMs");
        if (!at) {
          result->Error("bad_arguments", "atOrAfterMs");
          return;
        }
        frame = found->second.Next(*at, static_cast<int>(*max_side), &error);
      } else {
        const auto ms = IntArg(args, "ms");
        if (!ms) {
          result->Error("bad_arguments", "ms");
          return;
        }
        frame = found->second.FrameAt(*ms, static_cast<int>(*max_side), &error);
      }
      if (!frame && !error.code.empty()) {
        result->Error(error.code, error.message);
        return;
      }
      result->Success(frame ? FrameReply(*frame, method == "next")
                            : EncodableValue());
    } catch (const std::exception& e) {
      result->Error("decode_failed", e.what());
    } catch (...) {
      result->Error("decode_failed", "the frame call failed");
    }
  });
}

}  // namespace submersion_vision
