import Cocoa

/// Ends the process when a quit cannot finish by itself.
///
/// A quit on macOS is a round trip through Dart. `FlutterAppDelegate` answers
/// `NSTerminateCancel`, asks Dart over `flutter/platform`, and calls
/// `NSApp.terminate` again once Dart replies `exit`. AppKit is not left waiting
/// on anything, so nothing notices when that round trip stalls, and two things
/// can strand the process:
///
/// - The last window closed and Dart never answers. AppKit has already removed
///   the window, so the diver sees the app quit while the process lives on.
/// - Termination began and the engine cannot shut down. Shutdown waits for the
///   isolate, so a blocked isolate holds the main thread inside
///   `applicationWillTerminate` forever. A delivered terminate is therefore no
///   proof the process will end, which is why neither deadline stands down.
///
/// Both are armed from AppKit events, never from the value Flutter returns. An
/// earlier watchdog armed on `NSTerminateLater`, which the engine stopped
/// returning, and so it silently never ran.
///
/// A quit with a window still up arms nothing. Dart can cancel that quit on
/// purpose, and the diver can still see the app and quit again, which goes
/// straight to termination because the engine remembers the unanswered request.
/// Dart cannot usefully cancel with no window left, and after
/// `applicationWillTerminate` it cannot cancel at all, so both armed cases are
/// always safe to finish.
///
/// Deadlines run on a background queue rather than a `Timer` on the main run
/// loop, because a stopped main thread is one of the cases they guard. By the
/// time either fires, Dart has had its own close budget and drift runs in WAL
/// mode, so an abrupt exit is recoverable.
final class QuitWatchdog {
  /// How long Dart has to answer after the last window closes.
  ///
  /// Generous next to the 8s `closeDatabasesForExit` holds itself to, so a
  /// healthy quit never comes near it.
  static let defaultAnswerTimeout: TimeInterval = 20

  /// How long AppKit and the engine have to tear down before the process ends
  /// regardless. Dart has closed the databases before any orderly teardown.
  static let defaultTeardownTimeout: TimeInterval = 5

  private let answerTimeout: TimeInterval
  private let teardownTimeout: TimeInterval
  private let terminate: () -> Void
  private let forceExit: () -> Void
  /// Serial, so two deadlines landing together cannot both reach `exit`, which
  /// is undefined when called twice. The first one never returns.
  private let queue = DispatchQueue(label: "app.submersion.quit-watchdog", qos: .utility)

  init(
    answerTimeout: TimeInterval = QuitWatchdog.defaultAnswerTimeout,
    teardownTimeout: TimeInterval = QuitWatchdog.defaultTeardownTimeout,
    terminate: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
    forceExit: @escaping () -> Void = { exit(0) }
  ) {
    self.answerTimeout = answerTimeout
    self.teardownTimeout = teardownTimeout
    self.terminate = terminate
    self.forceExit = forceExit
  }

  /// Call when AppKit reports the last window closed.
  ///
  /// Asks AppKit first, for the orderly teardown, then forces the exit. The
  /// force is unconditional: `terminate` is a no-op if the main thread has
  /// stopped, and it returns having changed nothing if Dart cancelled.
  func lastWindowClosed() {
    let timeout = answerTimeout
    queue.asyncAfter(deadline: .now() + timeout) { [terminate] in
      NSLog("[QuitWatchdog] No exit answer after \(timeout)s; terminating")
      DispatchQueue.main.async(execute: terminate)
    }
    forceExit(after: answerTimeout + teardownTimeout)
  }

  /// Call when termination has begun and can no longer be cancelled.
  func willTerminate() {
    forceExit(after: teardownTimeout)
  }

  private func forceExit(after delay: TimeInterval) {
    queue.asyncAfter(deadline: .now() + delay) { [forceExit] in
      NSLog("[QuitWatchdog] Process still alive; forcing exit")
      forceExit()
    }
  }
}
