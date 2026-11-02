import XCTest

@testable import Submersion

/// What ends the process when a quit cannot finish by itself.
final class QuitWatchdogTests: XCTestCase {

  func testAsksAppKitToQuitOnTheMainThreadWhenDartNeverAnswers() {
    let asked = expectation(description: "terminate")
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 60,
      terminate: {
        XCTAssertTrue(Thread.isMainThread)
        asked.fulfill()
      },
      forceExit: {}
    )

    watchdog.lastWindowClosed()

    wait(for: [asked], timeout: 5)
  }

  /// `terminate` can return having changed nothing: Dart cancelled, so the
  /// engine refused it. With no window left there is nothing to go back to.
  func testForcesExitWhenAskingAppKitDidNotEndTheProcess() {
    let asked = expectation(description: "terminate")
    let exited = expectation(description: "forceExit")
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 0.01,
      terminate: { asked.fulfill() },
      forceExit: { exited.fulfill() }
    )

    watchdog.lastWindowClosed()

    wait(for: [asked, exited], timeout: 5, enforceOrder: true)
  }

  /// The test thread is the main thread, so holding it here stands in for a
  /// main thread that has stopped turning. Nothing on the main queue can run.
  func testForcesExitWhileTheMainThreadIsBlocked() {
    let exited = DispatchSemaphore(value: 0)
    var asked = false
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 0.01,
      terminate: { asked = true },
      forceExit: { exited.signal() }
    )

    watchdog.lastWindowClosed()

    XCTAssertEqual(exited.wait(timeout: .now() + 5), .success)
    XCTAssertFalse(asked)
  }

  /// Engine shutdown waits for the isolate, so a blocked isolate strands the
  /// process inside `applicationWillTerminate` with the main thread held.
  func testTeardownDeadlineEndsAProcessStuckInShutdownWhileMainIsBlocked() {
    let exited = DispatchSemaphore(value: 0)
    let watchdog = QuitWatchdog(
      answerTimeout: 60,
      teardownTimeout: 0.01,
      terminate: {},
      forceExit: { exited.signal() }
    )

    watchdog.willTerminate()

    XCTAssertEqual(exited.wait(timeout: .now() + 5), .success)
  }

  func testATerminationAlreadyUnderWayIsNotAskedToStartAgain() {
    let exited = expectation(description: "forceExit")
    let asked = expectation(description: "terminate")
    asked.isInverted = true
    let watchdog = QuitWatchdog(
      answerTimeout: 0.01,
      teardownTimeout: 0.01,
      terminate: { asked.fulfill() },
      forceExit: { exited.fulfill() }
    )

    watchdog.willTerminate()

    wait(for: [exited, asked], timeout: 0.2)
  }

  /// A blocked isolate trips both deadlines at nearly the same moment, and
  /// calling `exit` from two threads at once is undefined behaviour.
  func testTwoDeadlinesNeverForceExitAtTheSameTime() {
    let lock = NSLock()
    var running = 0
    var overlapped = false
    let finished = DispatchSemaphore(value: 0)
    let watchdog = QuitWatchdog(
      answerTimeout: 0,
      teardownTimeout: 0.01,
      terminate: {},
      forceExit: {
        lock.lock()
        running += 1
        overlapped = overlapped || running > 1
        lock.unlock()
        Thread.sleep(forTimeInterval: 0.1)
        lock.lock()
        running -= 1
        lock.unlock()
        finished.signal()
      }
    )

    watchdog.lastWindowClosed()
    watchdog.willTerminate()

    XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
    XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
    XCTAssertFalse(overlapped)
  }

  /// Dart spends up to `kAppExitCloseBudget` (8s, lib/core/app/app_exit.dart)
  /// closing the databases. The watchdog must never cut that short.
  func testDefaultsLeaveDartItsWholeCloseBudget() {
    XCTAssertGreaterThan(QuitWatchdog.defaultAnswerTimeout, 8)
  }
}
