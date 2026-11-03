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
  private var systemProxyHandler: SystemProxyHandler?
  private var multipeerHandler: MultipeerHandler?
  private var updateChannel: FlutterMethodChannel?
  private var displayChannel: FlutterMethodChannel?

  private let quitWatchdog: QuitWatchdog

  /// Mac App Store and TestFlight builds contain a receipt file;
  /// direct-distribution (DMG / GitHub) builds do not.
  private var isAppStoreBuild: Bool {
    guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
    return FileManager.default.fileExists(atPath: receiptURL.path)
  }

  /// Designated, not a convenience init calling the one below. The nib creates
  /// this class and aborts the launch if `init` hands back a different object,
  /// which a convenience init delegating to a Swift-only init does.
  override init() {
    quitWatchdog = QuitWatchdog()
    super.init()
  }

  /// Tests supply their own deadlines and exit action.
  init(quitWatchdog: QuitWatchdog) {
    self.quitWatchdog = quitWatchdog
    super.init()
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
      systemProxyHandler = SystemProxyHandler(messenger: messenger)
      multipeerHandler = MultipeerHandler(messenger: messenger)
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
    quitWatchdog.lastWindowClosed()
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    // Stays first. The delegate hears this before the engine's own observer,
    // whose shutdown never returns on a blocked isolate, so anything armed
    // after that point would never be armed at all.
    quitWatchdog.willTerminate()
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
