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
      infoPlistValue: infoPlistValue(Bundle.main.object(forInfoDictionaryKey: infoPlistKey)),
      isAppleSilicon: isAppleSiliconHardware())
  }

  /// Reads the key as Flutter does, with `boolValue`, so a string value such
  /// as "NO" counts as well as a plist boolean. Anything else is unset.
  static func infoPlistValue(_ raw: Any?) -> Bool? {
    switch raw {
    case let number as NSNumber: return number.boolValue
    case let string as NSString: return string.boolValue
    default: return nil
    }
  }

  /// Asks the hardware, not the running slice: an x86_64 build translated by
  /// Rosetta still draws on an Apple GPU, so it keeps Impeller. Only a
  /// successful lookup that reads 1 counts; on an Intel Mac the key is
  /// missing or reads 0, and both mean Intel.
  static func isAppleSiliconHardware() -> Bool {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
  }
}

/// A project that hands the engine `RendererPolicy`'s choice, and the ICU
/// data a subclass would otherwise lose (see `icuDataPath`).
///
/// Flutter declares `enableImpeller` only in its private
/// FlutterDartProject_Internal.h, where it reads the Info.plist switch. Swift
/// cannot see that declaration, so this getter has no `override`, but the
/// engine reads the property through Objective-C dispatch and gets this one.
/// Flutter's wide-gamut choice asks it too. RunnerTests pins the selector and
/// CI runs them (macos-runner-tests.yml, also on a Flutter version bump), so
/// an engine upgrade that renames it fails a check rather than quietly turning
/// Impeller back on for Intel Macs.
final class RendererDartProject: FlutterDartProject {
  private let impellerEnabled: Bool

  init(impellerEnabled: Bool = RendererPolicy.impellerEnabled()) {
    self.impellerEnabled = impellerEnabled
    super.init(precompiledDartBundle: nil)
  }

  @objc var enableImpeller: Bool { impellerEnabled }

  /// Flutter finds icudtl.dat in `[NSBundle bundleForClass:[self class]]`,
  /// which for this subclass is the app, not FlutterMacOS.framework, so the
  /// engine would start without ICU and text would ignore line breaks
  /// (issue #3639). Point it back at the framework's copy. Private like
  /// `enableImpeller`, and pinned by RunnerTests the same way.
  @objc(ICUDataPath) var icuDataPath: String? {
    let path = Bundle(for: FlutterDartProject.self).path(forResource: "icudtl.dat", ofType: nil)
    if path == nil {
      // The engine's own getter logs this too; keep the clue it would give.
      NSLog("Failed to find path for \"icudtl.dat\"")
    }
    return path
  }
}
