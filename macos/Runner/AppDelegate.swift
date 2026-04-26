import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  @IBOutlet var checkForUpdatesMenuItem: NSMenuItem?

  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?
  private var localMediaHandler: LocalMediaHandler?
  private var updateChannel: FlutterMethodChannel?

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
      localMediaHandler = LocalMediaHandler(messenger: messenger)
      updateChannel = FlutterMethodChannel(
        name: "app.submersion/updates",
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

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    bookmarkHandler?.cleanup()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
