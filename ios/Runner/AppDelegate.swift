import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    clearStaleLaunchScreenCache()
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Use FlutterPluginRegistry API to get the binary messenger
    // This avoids the deprecation warning about accessing rootViewController
    // in didFinishLaunchingWithOptions after UISceneDelegate migration
    if let bookmarkRegistrar = self.registrar(forPlugin: "SecurityScopedBookmarkHandler") {
      bookmarkHandler = SecurityScopedBookmarkHandler(messenger: bookmarkRegistrar.messenger())
    }
    if let icloudRegistrar = self.registrar(forPlugin: "ICloudContainerHandler") {
      icloudHandler = ICloudContainerHandler(messenger: icloudRegistrar.messenger())
    }
    if let metadataRegistrar = self.registrar(forPlugin: "MetadataWriteHandler") {
      metadataHandler = MetadataWriteHandler(messenger: metadataRegistrar.messenger())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    // Clean up security-scoped resource access
    bookmarkHandler?.cleanup()
  }

  /// iOS caches launch screen snapshots in Library/SplashBoard.
  /// The cache can survive app updates, causing stale launch screens
  /// to flash briefly on startup. Clear it once per new app version.
  private func clearStaleLaunchScreenCache() {
    let defaults = UserDefaults.standard
    let key = "lastLaunchScreenVersion"
    let current = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

    guard defaults.string(forKey: key) != current else { return }
    defaults.set(current, forKey: key)

    if let libraryDir = FileManager.default.urls(
      for: .libraryDirectory, in: .userDomainMask
    ).first {
      let splashBoard = libraryDir.appendingPathComponent("SplashBoard")
      try? FileManager.default.removeItem(at: splashBoard)
    }
  }
}
