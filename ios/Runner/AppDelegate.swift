import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Get the Flutter engine's binary messenger
    if let controller = window?.rootViewController as? FlutterViewController {
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: controller.binaryMessenger)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    // Clean up security-scoped resource access
    bookmarkHandler?.cleanup()
  }
}
