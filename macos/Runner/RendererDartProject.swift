import Darwin
import FlutterMacOS

/// Chooses the renderer for this Mac (issue #3531).
///
/// Flutter 3.47 made Impeller the default macOS renderer, and on Intel Macs
/// it flickers the whole window until the app is unusable
/// (flutter/flutter#191538, fixed upstream after 3.47). Intel Macs render
/// with Skia instead, as every Mac did before 3.47; Apple silicon keeps
/// Impeller.
enum RendererPolicy {
  /// Flutter's own Info.plist switch. When it is set, it decides on every
  /// Mac, so a build can still force either renderer.
  static let infoPlistKey = "FLTEnableImpeller"

  static func impellerEnabled(infoPlistValue: Bool?, isAppleSilicon: Bool) -> Bool {
    infoPlistValue ?? isAppleSilicon
  }

  /// The choice for the running app and the Mac it runs on.
  static func impellerEnabled() -> Bool {
    impellerEnabled(
      infoPlistValue: Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool,
      isAppleSilicon: isAppleSiliconHardware())
  }

  /// Asks the hardware, not the running slice: an x86_64 build translated by
  /// Rosetta still draws on an Apple GPU, so it keeps Impeller. The key does
  /// not exist on Intel Macs, so the lookup fails there.
  static func isAppleSiliconHardware() -> Bool {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
  }
}

/// A project that hands the engine `RendererPolicy`'s choice.
///
/// Flutter declares `enableImpeller` only in its private
/// FlutterDartProject_Internal.h, where it reads the Info.plist switch. Swift
/// cannot see that declaration, so this getter has no `override`, but the
/// engine reads the property through Objective-C dispatch and gets this one.
/// Flutter's wide-gamut choice asks it too. RunnerTests pins the selector, so
/// an engine upgrade that renames it fails a test rather than quietly turning
/// Impeller back on for Intel Macs.
final class RendererDartProject: FlutterDartProject {
  private let impellerEnabled: Bool

  init(impellerEnabled: Bool = RendererPolicy.impellerEnabled()) {
    self.impellerEnabled = impellerEnabled
    super.init(precompiledDartBundle: nil)
  }

  @objc var enableImpeller: Bool { impellerEnabled }
}
