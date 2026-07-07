import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart' hide Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';
import 'package:submersion/features/ocr_import/presentation/pages/ocr_scan_page.dart';
import 'package:submersion/features/ocr_import/presentation/providers/ocr_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../fixtures/logbook_fixtures.dart';

class FakeEngine implements OcrEngine {
  final OcrResult result;
  final bool available;

  FakeEngine(this.result, {this.available = true});

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async => result;
}

void main() {
  late Directory tmpDir;
  late String photoPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('ocr_scan_test');
    final file = File('${tmpDir.path}/page.jpg');
    await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
    photoPath = file.path;
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  // Taps a button whose handler does real file IO (readAsBytes), which
  // only progresses inside runAsync in the FakeAsync test zone. Bounded
  // pumps instead of pumpAndSettle: the processing spinner animates
  // until navigation replaces the page.
  Future<void> tapAndProcess(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<({List<Object?> pushedExtras})> pumpScanPage(
    WidgetTester tester, {
    required OcrEngine engine,
    Future<String?> Function(ImageSource)? pickImage,
    bool mobileLayout = false,
  }) async {
    final pushedExtras = <Object?>[];
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) => OcrScanPage(
            pickImageOverride: pickImage,
            forceMobileLayout: mobileLayout,
          ),
        ),
        GoRoute(
          path: '/dives/new',
          builder: (context, state) {
            pushedExtras.add(state.extra);
            return const Scaffold(body: Text('edit page'));
          },
        ),
      ],
    );
    final baseOverrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides,
          ocrEngineProvider.overrideWithValue(engine),
          sitesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (pushedExtras: pushedExtras);
  }

  testWidgets('engine unavailable shows install guidance', (tester) async {
    await pumpScanPage(
      tester,
      engine: FakeEngine(
        const OcrResult(blocks: [], imageSize: Size.zero),
        available: false,
      ),
    );
    expect(find.textContaining('Tesseract'), findsOneWidget);
    expect(find.text('Choose Photo'), findsNothing);
  });

  testWidgets('desktop layout shows a single choose button', (tester) async {
    await pumpScanPage(tester, engine: FakeEngine(padiTrainingMetric()));
    expect(find.text('Choose Photo'), findsOneWidget);
    expect(find.text('Take Photo'), findsNothing);
  });

  testWidgets('mobile layout shows camera and gallery buttons', (tester) async {
    await pumpScanPage(
      tester,
      engine: FakeEngine(padiTrainingMetric()),
      mobileLayout: true,
    );
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose Photo'), findsOneWidget);
  });

  testWidgets('successful scan navigates with a populated prefill', (
    tester,
  ) async {
    final harness = await pumpScanPage(
      tester,
      engine: FakeEngine(padiTrainingMetric()),
      pickImage: (source) async => photoPath,
    );
    await tapAndProcess(tester, 'Choose Photo');

    expect(harness.pushedExtras, hasLength(1));
    final prefill = harness.pushedExtras.single! as DivePrefill;
    expect(prefill.maxDepthMeters, closeTo(11.1, 0.001));
    expect(prefill.photoPath, photoPath);
    expect(prefill.importSource, 'ocr');
    expect(find.text('edit page'), findsOneWidget);
  });

  testWidgets('camera path also processes', (tester) async {
    final sources = <ImageSource>[];
    final harness = await pumpScanPage(
      tester,
      engine: FakeEngine(padiTrainingMetric()),
      mobileLayout: true,
      pickImage: (source) async {
        sources.add(source);
        return photoPath;
      },
    );
    await tapAndProcess(tester, 'Take Photo');
    expect(sources, [ImageSource.camera]);
    expect(harness.pushedExtras, hasLength(1));
  });

  testWidgets('empty scan shows notice and still navigates', (tester) async {
    final harness = await pumpScanPage(
      tester,
      engine: FakeEngine(const OcrResult(blocks: [], imageSize: Size.zero)),
      pickImage: (source) async => photoPath,
    );
    await tapAndProcess(tester, 'Choose Photo');
    expect(find.textContaining("Couldn't read much"), findsOneWidget);
    expect(harness.pushedExtras, hasLength(1));
    final prefill = harness.pushedExtras.single! as DivePrefill;
    expect(prefill.maxDepthMeters, isNull);
    expect(prefill.photoPath, photoPath);
  });

  testWidgets('cancelled pick stays on the page', (tester) async {
    final harness = await pumpScanPage(
      tester,
      engine: FakeEngine(padiTrainingMetric()),
      pickImage: (source) async => null,
    );
    await tapAndProcess(tester, 'Choose Photo');
    expect(harness.pushedExtras, isEmpty);
    expect(find.text('Choose Photo'), findsOneWidget);
  });
}
