import Cocoa
import FlutterMacOS
import XCTest

@testable import Submersion

/// Renderer choice for Intel and Apple silicon Macs (issue #3531).
class RendererDartProjectTests: XCTestCase {

  func testIntelRendersWithSkiaWhenInfoPlistIsSilent() {
    XCTAssertFalse(RendererPolicy.impellerEnabled(infoPlistValue: nil, isAppleSilicon: false))
  }

  func testAppleSiliconKeepsImpellerWhenInfoPlistIsSilent() {
    XCTAssertTrue(RendererPolicy.impellerEnabled(infoPlistValue: nil, isAppleSilicon: true))
  }

  func testInfoPlistValueWinsOnEitherHardware() {
    XCTAssertTrue(RendererPolicy.impellerEnabled(infoPlistValue: true, isAppleSilicon: false))
    XCTAssertFalse(RendererPolicy.impellerEnabled(infoPlistValue: false, isAppleSilicon: true))
  }

  /// The override only works while Flutter still reads this selector. If an
  /// engine upgrade renames it, Intel Macs silently go back to Impeller.
  func testFlutterStillDeclaresTheOverriddenSelector() {
    XCTAssertTrue(
      FlutterDartProject.instancesRespond(to: NSSelectorFromString("enableImpeller")))
  }

  /// Read through Objective-C dispatch, as the engine does. Wide gamut is
  /// Flutter's own method, which asks `enableImpeller`, so it must follow too.
  func testProjectAnswersTheEngineWithItsChoice() {
    let skia = RendererDartProject(impellerEnabled: false)
    XCTAssertEqual(skia.value(forKey: "enableImpeller") as? Bool, false)
    XCTAssertEqual(skia.value(forKey: "enableWideGamut") as? Bool, false)

    let impeller = RendererDartProject(impellerEnabled: true)
    XCTAssertEqual(impeller.value(forKey: "enableImpeller") as? Bool, true)
  }

}
