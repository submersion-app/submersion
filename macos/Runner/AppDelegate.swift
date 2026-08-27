import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  @IBOutlet var checkForUpdatesMenuItem: NSMenuItem?

  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?
  private var photoMetadataHandler: PhotoMetadataHandler?
  private var localMediaHandler: LocalMediaHandler?
  private var backupBookmarkHandler: BackupBookmarkHandler?
  private var updateChannel: FlutterMethodChannel?
  private var displayChannel: FlutterMethodChannel?

  /// Guards `terminateAnswered` across the watchdog queue and the main thread.
  private let terminateLock = NSLock()
  private var terminateAnswered = false

  /// Mac App Store and TestFlight builds contain a receipt file;
  /// direct-distribution (DMG / GitHub) builds do not.
  private var isAppStoreBuild: Bool {
    guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
    return FileManager.default.fileExists(atPath: receiptURL.path)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("[AppDelegate] applicationDidFinishLaunching called")

    if isAppStoreBuild, let item = checkForUpdatesMenuItem, let menu = item.menu {
      let index = menu.index(of: item)
      menu.removeItem(item)
      // Remove the trailing separator left behind
      if index < menu.numberOfItems && menu.item(at: index)?.isSeparatorItem == true {
        menu.removeItem(at: index)
      }
    }

    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[AppDelegate] Got FlutterViewController, setting up handlers...")
      let messenger = controller.engine.binaryMessenger
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: messenger)
      icloudHandler = ICloudContainerHandler(messenger: messenger)
      metadataHandler = MetadataWriteHandler(messenger: messenger)
      photoMetadataHandler = PhotoMetadataHandler(messenger: messenger)
      localMediaHandler = LocalMediaHandler(messenger: messenger)
      backupBookmarkHandler = BackupBookmarkHandler(messenger: messenger)
      updateChannel = FlutterMethodChannel(
        name: "app.submersion/updates",
        binaryMessenger: messenger
      )
      displayChannel = FlutterMethodChannel(
        name: "app.submersion/display",
        binaryMessenger: messenger
      )
      NSLog("[AppDelegate] All handlers initialized")
    } else {
      NSLog("[AppDelegate] ERROR: Could not get FlutterViewController!")
    }
  }

  @IBAction func checkForUpdates(_ sender: Any) {
    updateChannel?.invokeMethod("checkForUpdateInteractively", arguments: nil)
  }

  /// Invokes a display zoom method and logs anything the Dart side rejects.
  /// Without the result handler a miswired selector or renamed method is a
  /// menu item that silently does nothing.
  private func invokeDisplayMethod(_ method: String) {
    displayChannel?.invokeMethod(method, arguments: nil, result: { result in
      if let error = result as? FlutterError {
        NSLog(
          "[AppDelegate] display channel '\(method)' failed: \(error.code) \(error.message ?? "")"
        )
      } else if (result as? NSObject) == FlutterMethodNotImplemented {
        NSLog("[AppDelegate] display channel has no method '\(method)'")
      }
    })
  }

  @IBAction func zoomIn(_ sender: Any) {
    invokeDisplayMethod("zoomIn")
  }

  @IBAction func zoomOut(_ sender: Any) {
    invokeDisplayMethod("zoomOut")
  }

  @IBAction func actualSize(_ sender: Any) {
    invokeDisplayMethod("actualSize")
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  /// How long to wait for Dart's answer to the exit request before quitting
  /// anyway.
  ///
  /// Generous next to the 8s budget `closeDatabasesForExit` holds itself to, so
  /// a healthy quit never comes near it. It exists for the case that budget
  /// cannot cover: a blocked main isolate or a blocked main thread has no
  /// thread left to run a `Future.timeout` or a run-loop `Timer`.
  private static let terminateWatchdogInterval: TimeInterval = 20

  /// Extra grace after the watchdog asks AppKit nicely, before it stops asking.
  private static let terminateWatchdogGrace: TimeInterval = 2

  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    let reply = super.applicationShouldTerminate(sender)
    guard reply == .terminateLater else { return reply }
    armTerminateWatchdog()
    return reply
  }

  /// Force-quits if Dart never answers the exit request.
  ///
  /// FlutterAppDelegate returns `NSTerminateLater` and asks Dart over the
  /// `flutter/platform` channel. Nothing on the native side re-checks, so a
  /// Dart side that never replies leaves AppKit deferring forever. AppKit has
  /// already dismissed the window by then, so the user sees the app quit while
  /// the process lives on. That is the reported symptom, and the Media
  /// section's local-file reads are the likeliest thing to be in flight at
  /// quit.
  ///
  /// Runs on a background queue rather than a `Timer` on the main run loop,
  /// because a wedged main thread is precisely the case this guards. For the
  /// same reason it cannot rely on `reply(toApplicationShouldTerminate:)`
  /// landing: that must be called on the main thread, so it is attempted first
  /// and `exit(0)` follows only if the main queue never ran the block that
  /// delivers it. By then both databases have had their own budget and drift
  /// runs in WAL mode, so an abrupt exit is recoverable.
  ///
  /// `exit(0)` is deliberately gated on the *reply* having been delivered, not
  /// on termination having completed: once AppKit has the reply, finishing the
  /// quit is its business and however long it takes is not this watchdog's to
  /// cut short.
  private func armTerminateWatchdog() {
    let deadline: DispatchTime = .now() + AppDelegate.terminateWatchdogInterval
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) {
      [weak self] in
      guard let self, !self.hasAnsweredTerminate() else { return }
      NSLog(
        "[AppDelegate] No exit-request answer after "
          + "\(AppDelegate.terminateWatchdogInterval)s; forcing termination")
      DispatchQueue.main.async { [weak self] in
        // Marked answered HERE rather than left to applicationWillTerminate.
        // Delivering the reply is the single event this watchdog exists to
        // force; what follows it is AppKit's own teardown, whose duration is
        // nothing to do with the grace period. Deciding on willTerminate
        // instead would let the grace path call exit(0) in the middle of an
        // orderly termination that was already under way.
        self?.markTerminateAnswered()
        NSApplication.shared.reply(toApplicationShouldTerminate: true)
      }
      DispatchQueue.global(qos: .utility).asyncAfter(
        deadline: .now() + AppDelegate.terminateWatchdogGrace
      ) { [weak self] in
        // The flag is set by the block above, on the main queue. Reaching here
        // unset therefore means that block never ran: the main thread is not
        // turning, so no reply can ever be delivered and there is nothing left
        // to wait for.
        guard let self, !self.hasAnsweredTerminate() else { return }
        NSLog("[AppDelegate] Main thread never delivered the reply; calling exit(0)")
        exit(0)
      }
    }
  }

  private func hasAnsweredTerminate() -> Bool {
    terminateLock.lock()
    defer { terminateLock.unlock() }
    return terminateAnswered
  }

  /// Records that the exit request has been answered, so the watchdog stands
  /// down. Called on the main queue when the reply is delivered, and again
  /// from `applicationWillTerminate` as a backstop for a termination this
  /// watchdog never had to force.
  private func markTerminateAnswered() {
    terminateLock.lock()
    terminateAnswered = true
    terminateLock.unlock()
  }

  override func applicationWillTerminate(_ notification: Notification) {
    markTerminateAnswered()
    bookmarkHandler?.cleanup()
    backupBookmarkHandler?.releaseAll()
    // Released here as well as in its own deinit, which does not run on
    // terminate: these are security-scoped URLs the Media section opened.
    localMediaHandler?.releaseAllActiveBookmarks()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
