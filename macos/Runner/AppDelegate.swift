import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("[AppDelegate] applicationDidFinishLaunching called")
    // Get the Flutter engine's binary messenger
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[AppDelegate] Got FlutterViewController, setting up handlers...")
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: controller.engine.binaryMessenger)
      icloudHandler = ICloudContainerHandler(messenger: controller.engine.binaryMessenger)
      metadataHandler = MetadataWriteHandler(messenger: controller.engine.binaryMessenger)
      NSLog("[AppDelegate] All handlers initialized")
    } else {
      NSLog("[AppDelegate] ERROR: Could not get FlutterViewController!")
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    // Clean up security-scoped resource access
    bookmarkHandler?.cleanup()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
