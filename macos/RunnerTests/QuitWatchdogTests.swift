import Cocoa
import XCTest

@testable import Submersion

/// What ends the process when a quit cannot finish by itself.
final class QuitWatchdogTests: XCTestCase {

  func testForcesExitWhenDartNeverAnswersAfterTheLastWindowCloses() {
    let exited = expectation(description: "forceExit")
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 60,
      forceExit: { exited.fulfill() }
    )

    watchdog.lastWindowClosed()

    wait(for: [exited], timeout: 5)
  }

  /// The test thread is the main thread, so holding it here stands in for a
  /// main thread that has stopped turning.
  func testAnswerDeadlineFiresWhileTheMainThreadIsBlocked() {
    let exited = DispatchSemaphore(value: 0)
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 60,
      forceExit: { exited.signal() }
    )

    watchdog.lastWindowClosed()

    XCTAssertEqual(exited.wait(timeout: .now() + 5), .success)
  }

  /// Engine shutdown waits for the isolate, so a blocked isolate strands the
  /// process inside `applicationWillTerminate` with the main thread held.
  func testTeardownDeadlineEndsAProcessStuckInShutdownWhileMainIsBlocked() {
    let exited = DispatchSemaphore(value: 0)
    let watchdog = QuitWatchdog(
      answerTimeout: 60,
      teardownTimeout: 0.01,
      forceExit: { exited.signal() }
    )

    watchdog.willTerminate()

    XCTAssertEqual(exited.wait(timeout: .now() + 5), .success)
  }

  /// Native handlers run blocking file work on the shared queues, and a stalled
  /// read is the likeliest thing in flight at quit. A deadline must not need a
  /// free worker from that pool.
  func testDeadlinesStillFireWhenTheSharedQueuesAreFull() {
    let release = DispatchSemaphore(value: 0)
    let blockers = 512
    addTeardownBlock {
      for _ in 0..<blockers * 2 { release.signal() }
    }
    for _ in 0..<blockers {
      DispatchQueue.global(qos: .utility).async { release.wait() }
      DispatchQueue.global(qos: .userInitiated).async { release.wait() }
    }
    let exited = DispatchSemaphore(value: 0)
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 60,
      forceExit: { exited.signal() }
    )

    watchdog.lastWindowClosed()

    XCTAssertEqual(exited.wait(timeout: .now() + 5), .success)
  }

  // The watchdog once armed on a reply the engine had stopped returning, so it
  // never ran and nothing noticed. These pin what arms it.

  func testClosingTheLastWindowArmsTheWatchdogAndStillQuits() {
    let exited = expectation(description: "forceExit")
    let delegate = AppDelegate(
      quitWatchdog: QuitWatchdog(
        answerTimeout: 0.01,
        teardownTimeout: 60,
        forceExit: { exited.fulfill() }
      ))

    XCTAssertTrue(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))

    wait(for: [exited], timeout: 5)
  }

  func testTerminationArmsTheTeardownDeadline() {
    let exited = expectation(description: "forceExit")
    let delegate = AppDelegate(
      quitWatchdog: QuitWatchdog(
        answerTimeout: 60,
        teardownTimeout: 0.01,
        forceExit: { exited.fulfill() }
      ))

    delegate.applicationWillTerminate(
      Notification(name: NSApplication.willTerminateNotification))

    wait(for: [exited], timeout: 5)
  }

  /// A quit with the window up can be cancelled by Dart on purpose. Nothing may
  /// be counting down against it.
  func testAQuitRequestAloneArmsNothing() {
    let exited = expectation(description: "forceExit")
    exited.isInverted = true
    let delegate = AppDelegate(
      quitWatchdog: QuitWatchdog(
        answerTimeout: 0.01,
        teardownTimeout: 0.01,
        forceExit: { exited.fulfill() }
      ))

    _ = delegate.applicationShouldTerminate(NSApplication.shared)

    wait(for: [exited], timeout: 0.2)
  }
}
