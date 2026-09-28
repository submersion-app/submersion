import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';

import 'global_state_snapshot.dart';
import 'global_test_defaults.dart';

class _FakePathProvider extends PathProviderPlatform {}

class _Overrides extends HttpOverrides {}

final class _IoOverrides extends IOOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing changed reports nothing', () {
    final before = GlobalStateSnapshot.take();

    expect(GlobalStateSnapshot.take().changedSince(before), isEmpty);
  });

  test('a replaced platform singleton is reported by name', () {
    final before = GlobalStateSnapshot.take();
    final original = PathProviderPlatform.instance;
    addTearDown(() => PathProviderPlatform.instance = original);

    PathProviderPlatform.instance = _FakePathProvider();

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'PathProviderPlatform.instance',
    ]);
  });

  test('a changed harness default is reported', () {
    final before = GlobalStateSnapshot.take();
    addTearDown(applyGlobalTestDefaults);

    QualityScanScheduler.enabled = true;
    debugCanShareFiles = false;

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'QualityScanScheduler.enabled',
      'canShareFiles',
    ]);
  });

  test('turning font fetching back on is reported', () {
    final before = GlobalStateSnapshot.take();
    addTearDown(applyGlobalTestDefaults);

    GoogleFonts.config.allowRuntimeFetching = true;

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'GoogleFonts.config.allowRuntimeFetching',
    ]);
  });

  test('HTTP overrides and foundation hooks are reported', () {
    final before = GlobalStateSnapshot.take();
    final previousOverrides = HttpOverrides.current;
    final previousPrint = debugPrint;
    final previousOnError = FlutterError.onError;
    addTearDown(() {
      HttpOverrides.global = previousOverrides;
      debugPrint = previousPrint;
      FlutterError.onError = previousOnError;
      debugDefaultTargetPlatformOverride = null;
    });

    HttpOverrides.global = _Overrides();
    debugPrint = (String? message, {int? wrapWidth}) {};
    FlutterError.onError = (details) {};
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'HttpOverrides.current',
      'debugPrint',
      'FlutterError.onError',
      'debugDefaultTargetPlatformOverride',
    ]);
  });

  test('IO overrides are reported', () {
    final before = GlobalStateSnapshot.take();
    final previous = IOOverrides.current;
    addTearDown(() => IOOverrides.global = previous);

    IOOverrides.global = _IoOverrides();

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'IOOverrides.current',
    ]);
  });

  test('restoring the harness overrides reports nothing', () {
    final before = GlobalStateSnapshot.take();
    final previousHttp = HttpOverrides.current;
    final previousIo = IOOverrides.current;
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      IOOverrides.global = previousIo;
    });
    HttpOverrides.global = _Overrides();
    IOOverrides.global = _IoOverrides();

    HttpOverrides.global = previousHttp;
    IOOverrides.global = previousIo;

    expect(GlobalStateSnapshot.take().changedSince(before), isEmpty);
  });

  test('a PDF font loader override is reported', () {
    final before = GlobalStateSnapshot.take();
    addTearDown(() {
      PdfFonts.debugLatinFontLoader = null;
      PdfFonts.debugScriptFontLoader = null;
    });

    PdfFonts.debugLatinFontLoader = (weight) async => pw.Font.helvetica();
    PdfFonts.debugScriptFontLoader = (code, {required bold}) async => null;

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'PdfFonts.debugLatinFontLoader',
      'PdfFonts.debugScriptFontLoader',
    ]);
  });

  test('a mock handler left on a watched channel is reported', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final before = GlobalStateSnapshot.take();
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    messenger.setMockMethodCallHandler(channel, (call) async => '/tmp');

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'mock handler on plugins.flutter.io/path_provider',
    ]);
  });

  test('putting everything back reports nothing', () {
    final before = GlobalStateSnapshot.take();
    final original = PathProviderPlatform.instance;
    addTearDown(() => PathProviderPlatform.instance = original);
    addTearDown(applyGlobalTestDefaults);

    PathProviderPlatform.instance = _FakePathProvider();
    QualityScanScheduler.enabled = true;
    PathProviderPlatform.instance = original;
    applyGlobalTestDefaults();

    expect(GlobalStateSnapshot.take().changedSince(before), isEmpty);
  });

  test('expectRestored fails and names what was left changed', () {
    final before = GlobalStateSnapshot.take();
    addTearDown(applyGlobalTestDefaults);

    QualityScanScheduler.enabled = true;

    expect(
      before.expectRestored,
      throwsA(
        isA<TestFailure>().having(
          (failure) => failure.message,
          'message',
          contains('QualityScanScheduler.enabled'),
        ),
      ),
    );
  });

  group('the test binding appearing during a file', () {
    void printA(String? message, {int? wrapWidth}) {}
    void printB(String? message, {int? wrapWidth}) {}
    final overrides = _Overrides();

    Map<String, Object?> state({
      required bool binding,
      Object? http,
      Object? print,
      bool scan = false,
    }) => {
      GlobalStateSnapshot.bindingKey: binding,
      'HttpOverrides.current': http,
      'debugPrint': print,
      'QualityScanScheduler.enabled': scan,
    };

    test('the values the binding installs are not reported', () {
      final before = GlobalStateSnapshot.fromValues(
        state(binding: false, print: printA),
      );
      final after = GlobalStateSnapshot.fromValues(
        state(binding: true, http: overrides, print: printB),
      );

      expect(after.changedSince(before), isEmpty);
    });

    test('they are reported when the binding was already there', () {
      final before = GlobalStateSnapshot.fromValues(
        state(binding: true, print: printA),
      );
      final after = GlobalStateSnapshot.fromValues(
        state(binding: true, http: overrides, print: printB),
      );

      expect(after.changedSince(before), [
        'HttpOverrides.current',
        'debugPrint',
      ]);
    });

    test('anything else the file changed is still reported', () {
      final before = GlobalStateSnapshot.fromValues(
        state(binding: false, print: printA),
      );
      final after = GlobalStateSnapshot.fromValues(
        state(binding: true, http: overrides, print: printB, scan: true),
      );

      expect(after.changedSince(before), ['QualityScanScheduler.enabled']);
    });
  });

  group('declareAndCheck', () {
    test('a clean declaration reports no error and no change', () {
      var ran = false;

      final result = declareAndCheck(() => ran = true);

      expect(ran, isTrue);
      expect(result.error, isNull);
      expect(result.changed, isEmpty);
    });

    test('a declaration that throws hands back the error and its stack', () {
      final result = declareAndCheck(() => throw StateError('boom'));

      expect(result.error, isA<StateError>());
      expect(result.stack, isNotNull);
    });

    test('a declaration that replaces a global reports it', () {
      final original = PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = original);

      final result = declareAndCheck(
        () => PathProviderPlatform.instance = _FakePathProvider(),
      );

      expect(result.changed, ['PathProviderPlatform.instance']);
    });

    test('the harness defaults are applied before declaring', () {
      addTearDown(applyGlobalTestDefaults);
      QualityScanScheduler.enabled = true;
      bool? seen;

      declareAndCheck(() => seen = QualityScanScheduler.enabled);

      expect(seen, isFalse);
    });
  });

  test('expectRestored passes when nothing changed', () {
    GlobalStateSnapshot.take().expectRestored();
  });
}
