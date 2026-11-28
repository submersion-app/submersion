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
    MainFlutterWindow.configureMultiWindow(mainEngine: flutterViewController.engine)
    closeOtherWindowsWithThisOne()

    super.awakeFromNib()
  }

  /// Sets up the engines of pop-out windows (issue #5078).
  ///
  /// Each gets the main window's renderer choice (#3531) and only the
  /// plugins a pop-out uses. Registering every plugin again would let some
  /// take process-wide hooks (the notification-center delegate, URL
  /// handlers, the updater) away from the main window.
  static func configureMultiWindow(mainEngine: FlutterEngine?) {
    FlutterMultiWindowPlugin.setProjectFactory { RendererDartProject() }
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { [weak mainEngine] controller in
      WindowManagerPlugin.register(
        with: controller.registrar(forPlugin: "WindowManagerPlugin"))
      ScreenRetrieverMacosPlugin.register(
        with: controller.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
      if let mainEngine { handQuitBack(to: mainEngine) }
    }
  }

  /// Every Flutter engine claims the app's quit for itself when it is made
  /// (the app delegate's weak `terminationHandler`). A pop-out's engine is
  /// made after the main one, so without this Cmd-Q, the Dock's Quit and the
  /// last window's close would go to the pop-out, skipping the main window's
  /// exit guard (unsaved work) and its database close. Both names are
  /// private to Flutter, hence KVC behind a `responds(to:)` check; RunnerTests
  /// pins them.
  static func handQuitBack(to engine: FlutterEngine) {
    guard
      let delegate = NSApp.delegate as? NSObject,
      delegate.responds(to: NSSelectorFromString("setTerminationHandler:")),
      engine.responds(to: NSSelectorFromString("terminationHandler")),
      let handler = engine.value(forKey: "terminationHandler")
    else { return }
    delegate.setValue(handler, forKey: "terminationHandler")
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
