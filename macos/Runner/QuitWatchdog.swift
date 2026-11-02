import Foundation

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
/// That way out depends on `FLTEnableMergedPlatformUIThread` staying false in
/// Info.plist: with merged threads a blocked isolate also blocks the main
/// thread, and the second quit is never delivered. Dart cannot usefully cancel
/// with no window left, and after `applicationWillTerminate` it cannot cancel
/// at all, so both armed cases are always safe to finish.
///
/// When Dart stops answering, the deadline exits directly rather than asking
/// AppKit first. `closeDatabasesForExit` always answers, so silence means a
/// blocked isolate, and an orderly terminate would hang in engine shutdown.
/// With Drift's worker still open it could instead abort in FFI teardown.
///
/// An abrupt exit is recoverable: the databases run in WAL mode.
final class QuitWatchdog {
  /// How long Dart has to answer after the last window closes.
  ///
  /// Must stay above `kAppExitCloseBudget` in lib/core/app/app_exit.dart, so a
  /// healthy close is never cut short. A test there reads this line.
  static let defaultAnswerTimeout: TimeInterval = 20

  /// How long AppKit and the engine have to tear down once termination begins.
  static let defaultTeardownTimeout: TimeInterval = 5

  private let answerTimeout: TimeInterval
  private let teardownTimeout: TimeInterval
  private let forceExit: () -> Void

  /// A private queue rather than a global one, and never a `Timer` on the main
  /// run loop. Blocked work can fill the shared pool and a stopped main thread
  /// runs nothing, and a deadline has to fire in both cases.
  private let queue = DispatchQueue(label: "app.submersion.quit-watchdog", qos: .utility)

  /// [forceExit] defaults to `_exit`, not `exit`. A stuck process still has
  /// live threads, and `exit` would run atexit handlers and static destructors
  /// alongside them, which can crash or hang the one call that must not.
  init(
    answerTimeout: TimeInterval = QuitWatchdog.defaultAnswerTimeout,
    teardownTimeout: TimeInterval = QuitWatchdog.defaultTeardownTimeout,
    forceExit: @escaping () -> Void = { _exit(0) }
  ) {
    self.answerTimeout = answerTimeout
    self.teardownTimeout = teardownTimeout
    self.forceExit = forceExit
  }

  /// Call when AppKit reports the last window closed.
  func lastWindowClosed() {
    scheduleForceExit(after: answerTimeout)
  }

  /// Call when termination has begun and can no longer be cancelled.
  func willTerminate() {
    scheduleForceExit(after: teardownTimeout)
  }

  private func scheduleForceExit(after delay: TimeInterval) {
    queue.asyncAfter(deadline: .now() + delay) { [forceExit] in
      NSLog("[QuitWatchdog] Process still alive after \(delay)s; forcing exit")
      forceExit()
    }
  }
}
