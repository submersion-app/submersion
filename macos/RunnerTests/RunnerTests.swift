import Cocoa
import FlutterMacOS
import XCTest
import desktop_multi_window

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

  func testInfoPlistValueIsReadLikeFlutterReadsIt() {
    XCTAssertEqual(RendererPolicy.infoPlistValue(NSNumber(value: false)), false)
    XCTAssertEqual(RendererPolicy.infoPlistValue(NSNumber(value: true)), true)
    XCTAssertEqual(RendererPolicy.infoPlistValue("NO" as NSString), false)
    XCTAssertEqual(RendererPolicy.infoPlistValue("YES" as NSString), true)
    XCTAssertNil(RendererPolicy.infoPlistValue(nil))
    XCTAssertNil(RendererPolicy.infoPlistValue(NSArray()))
  }

  /// A native arm64 test process can only be running on Apple silicon.
  func testDetectsAppleSiliconHardware() throws {
    #if arch(arm64)
      XCTAssertTrue(RendererPolicy.isAppleSiliconHardware())
    #else
      throw XCTSkip("x86_64 process: Intel Mac or Rosetta, either answer is possible")
    #endif
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

  /// Flutter finds icudtl.dat in the bundle of the project's class. For this
  /// subclass that is the app, which has no copy, so without the override the
  /// engine starts without ICU and text ignores line breaks (issue #3639).
  func testFlutterStillDeclaresTheICUDataPathSelector() {
    XCTAssertTrue(
      FlutterDartProject.instancesRespond(to: NSSelectorFromString("ICUDataPath")))
  }

  func testProjectHandsTheEngineFluttersICUData() throws {
    let path = try XCTUnwrap(
      RendererDartProject(impellerEnabled: true).value(forKey: "ICUDataPath") as? String)
    XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    XCTAssertEqual(path, FlutterDartProject().value(forKey: "ICUDataPath") as? String)
  }

}

/// Pop-out windows (issue #5078) get their own engine; each must render
/// with the same choice as the main window, or Intel Macs flicker (#3531).
class PopOutWindowTests: XCTestCase {

  func testPopOutWindowsUseTheRendererProject() {
    MainFlutterWindow.configureMultiWindow(mainEngine: nil)
    let project = FlutterMultiWindowPlugin.projectFactory?()
    XCTAssertTrue(project is RendererDartProject)
  }

  /// Every engine claims the app's quit when it is made. A pop-out's engine
  /// must hand it back, or Cmd-Q skips the main window's exit guard and its
  /// database close.
  func testQuitGoesBackToTheMainEngine() throws {
    let delegate = try XCTUnwrap(NSApp.delegate as? NSObject)
    let main = FlutterEngine(name: "main", project: nil)
    let mainHandler = main.value(forKey: "terminationHandler") as AnyObject?
    XCTAssertNotNil(mainHandler)
    let popOut = FlutterEngine(name: "pop-out", project: nil)
    XCTAssertTrue(
      delegate.value(forKey: "terminationHandler") as AnyObject?
        === popOut.value(forKey: "terminationHandler") as AnyObject?)

    MainFlutterWindow.handQuitBack(to: main)

    XCTAssertTrue(delegate.value(forKey: "terminationHandler") as AnyObject? === mainHandler)
    withExtendedLifetime(popOut) {}
  }
}
