import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bookmarkHandler: SecurityScopedBookmarkHandler?
  private var icloudHandler: ICloudContainerHandler?
  private var metadataHandler: MetadataWriteHandler?
  private var photoMetadataHandler: PhotoMetadataHandler?
  private var localMediaHandler: LocalMediaHandler?
  private var backupBookmarkHandler: BackupBookmarkHandler?
  private var deviceNameHandler: DeviceNameHandler?
  private var systemProxyHandler: SystemProxyHandler?
  private var multipeerHandler: MultipeerHandler?

  // The app uses the UIScene lifecycle (UIApplicationSceneManifest in
  // Info.plist): iOS 27 refuses to launch an app built with its SDK that does
  // not. The Flutter engine is created when the scene connects, after this
  // method returns, so only app-level work belongs here. Plugins and method
  // channels register in didInitializeImplicitFlutterEngine below.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    clearStaleLaunchScreenCache()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // BGTaskScheduler only delivers a task to a relaunched app whose launch
    // handler was registered before launch finished. With scenes the plugin
    // registers too late to do this itself.
    WorkmanagerPlugin.registerLaunchHandlers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called when the storyboard's FlutterViewController creates its engine as
  // the scene connects: once per launch, and again with a fresh engine if iOS
  // disconnects the scene and later reconnects it.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Handlers left from an earlier engine still hold security-scoped access.
    releaseSecurityScopedAccess()

    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    if let bookmarkRegistrar = registry.registrar(forPlugin: "SecurityScopedBookmarkHandler") {
      bookmarkHandler = SecurityScopedBookmarkHandler(registrar: bookmarkRegistrar)
    }
    if let icloudRegistrar = registry.registrar(forPlugin: "ICloudContainerHandler") {
      icloudHandler = ICloudContainerHandler(messenger: icloudRegistrar.messenger())
    }
    if let metadataRegistrar = registry.registrar(forPlugin: "MetadataWriteHandler") {
      metadataHandler = MetadataWriteHandler(messenger: metadataRegistrar.messenger())
    }
    if let photoMetadataRegistrar = registry.registrar(forPlugin: "PhotoMetadataHandler") {
      photoMetadataHandler = PhotoMetadataHandler(messenger: photoMetadataRegistrar.messenger())
    }
    if let localMediaRegistrar = registry.registrar(forPlugin: "LocalMediaHandler") {
      localMediaHandler = LocalMediaHandler(messenger: localMediaRegistrar.messenger())
    }
    if let backupRegistrar = registry.registrar(forPlugin: "BackupBookmarkHandler") {
      backupBookmarkHandler = BackupBookmarkHandler(registrar: backupRegistrar)
    }
    if let deviceNameRegistrar = registry.registrar(forPlugin: "DeviceNameHandler") {
      deviceNameHandler = DeviceNameHandler(messenger: deviceNameRegistrar.messenger())
    }
    if let systemProxyRegistrar = registry.registrar(forPlugin: "SystemProxyHandler") {
      systemProxyHandler = SystemProxyHandler(messenger: systemProxyRegistrar.messenger())
    }
    if let multipeerRegistrar = registry.registrar(forPlugin: "MultipeerHandler") {
      multipeerHandler = MultipeerHandler(messenger: multipeerRegistrar.messenger())
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    releaseSecurityScopedAccess()
  }

  /// Stops the security-scoped access the folder and media handlers hold.
  private func releaseSecurityScopedAccess() {
    bookmarkHandler?.cleanup()
    backupBookmarkHandler?.releaseAll()
    localMediaHandler?.releaseAll()
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
