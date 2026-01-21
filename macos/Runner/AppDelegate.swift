import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Get the Flutter engine's binary messenger
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: controller.engine.binaryMessenger)
      icloudHandler = ICloudContainerHandler(messenger: controller.engine.binaryMessenger)
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
