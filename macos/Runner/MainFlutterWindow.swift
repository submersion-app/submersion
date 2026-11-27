import Cocoa
import FlutterMacOS
import desktop_multi_window
import screen_retriever_macos
import window_manager

class MainFlutterWindow: NSWindow {
  private var closeObserver: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController(project: RendererDartProject())
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MainFlutterWindow.configureMultiWindow()
    closeOtherWindowsWithThisOne()

    super.awakeFromNib()
  }

  /// Sets up the engines of pop-out windows (issue #5078).
  ///
  /// Each gets the main window's renderer choice (#3531) and only the
  /// plugins a pop-out uses. Registering every plugin again would let some
  /// take process-wide hooks (the notification-center delegate, URL
  /// handlers, the updater) away from the main window.
  static func configureMultiWindow() {
    FlutterMultiWindowPlugin.setProjectFactory { RendererDartProject() }
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      WindowManagerPlugin.register(
        with: controller.registrar(forPlugin: "WindowManagerPlugin"))
      ScreenRetrieverMacosPlugin.register(
        with: controller.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
    }
  }

  /// Closing the main window quits, but only once it is the last window.
  /// A pop-out left open would keep the app running with its data source
  /// gone, so pop-outs close with the main window.
  private func closeOtherWindowsWithThisOne() {
    closeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: self, queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      for window in NSApp.windows where window !== self && window.isVisible {
        window.close()
      }
    }
  }
}
