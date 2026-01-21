import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Use FlutterPluginRegistry API to get the binary messenger
    // This avoids the deprecation warning about accessing rootViewController
    // in didFinishLaunchingWithOptions after UISceneDelegate migration
    if let bookmarkRegistrar = self.registrar(forPlugin: "SecurityScopedBookmarkHandler") {
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: bookmarkRegistrar.messenger())
    }
    if let icloudRegistrar = self.registrar(forPlugin: "ICloudContainerHandler") {
      icloudHandler = ICloudContainerHandler(messenger: icloudRegistrar.messenger())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    // Clean up security-scoped resource access
    bookmarkHandler?.cleanup()
  }
}
