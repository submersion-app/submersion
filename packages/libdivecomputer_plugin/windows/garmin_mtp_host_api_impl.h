#ifndef GARMIN_MTP_HOST_API_IMPL_H_
#define GARMIN_MTP_HOST_API_IMPL_H_

#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>

#include "garmin_mtp_api.g.h"

namespace garmin_mtp {

class WpdReader;

// GarminMtpHostApi over WPD (issue #4223). Every call runs on one worker
// thread, in order, so the watch is only ever spoken to from one place and
// the platform thread never waits on it. Replies are handed back through
// |post_to_platform_thread|, since Pigeon replies must run there.
class GarminMtpHostApiImpl : public GarminMtpHostApi {
 public:
  using PostTask = std::function<void(std::function<void()>)>;

  explicit GarminMtpHostApiImpl(PostTask post_to_platform_thread);
  // Joins the worker. A call still queued is dropped unanswered, which only
  // happens as the engine shuts down.
  ~GarminMtpHostApiImpl() override;

  void ListDevices(
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;
  void ListActivityFiles(
      const std::string& device_id,
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;
  void ReadFile(
      const std::string& device_id,
      const std::string& object_id,
      std::function<void(ErrorOr<std::vector<uint8_t>> reply)> result)
      override;

 private:
  using Job = std::function<void(WpdReader&)>;

  void Enqueue(Job job);
  void WorkerLoop();

  PostTask post_;
  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<Job> jobs_;
  bool stopping_ = false;
  std::thread worker_;
};

}  // namespace garmin_mtp

#endif  // GARMIN_MTP_HOST_API_IMPL_H_
