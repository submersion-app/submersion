import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';
import 'package:submersion/features/ocr_import/presentation/controllers/scan_flow_controller.dart';

import '../../fixtures/logbook_fixtures.dart';

class FakeEngine implements OcrEngine {
  final OcrResult result;

  FakeEngine(this.result);

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async => result;
}

class ThrowingEngine implements OcrEngine {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async =>
      throw StateError('engine exploded');
}

DiveSite site(String id, String name) => DiveSite(id: id, name: name);

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

void main() {
  test('happy path produces prefill with resolved site', () async {
    final controller = ScanFlowController(
      engine: FakeEngine(padiTrainingMetric()),
      parser: LogbookParser(),
      existingSites: [site('2', 'Pinnacle, Sodwana Bay')],
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
    expect(prefill.site?.id, '2');
    expect(prefill.maxDepthMeters, closeTo(11.1, 0.001));
    expect(prefill.durationMinutes, 45);
    expect(prefill.photoPath, '/tmp/p.jpg');
    expect(prefill.importSource, 'ocr');
    expect(prefill.notes, contains('First dive in the ocean!'));
  });

  test('unresolved site name lands in notes appendix', () async {
    final controller = ScanFlowController(
      engine: FakeEngine(padiHandwrittenImperial()),
      parser: LogbookParser(),
      existingSites: const [],
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
    expect(prefill.site, isNull);
    expect(prefill.notes, contains('Scanned from paper log'));
    expect(prefill.notes, contains("Site: O'ahu - pipe"));
    expect(prefill.notes, contains('Visibility: 60 ft'));
    expect(prefill.notes, contains('HUMPBACK WHALE'));
  });

  test('unresolved location text joins the appendix', () async {
    final controller = ScanFlowController(
      engine: FakeEngine(typewriterBoxed()),
      parser: LogbookParser(),
      existingSites: const [],
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
    expect(prefill.notes, contains('Site: Chac Mool Cenote'));
    expect(prefill.notes, contains('Location: Mexico'));
  });

  test('engine failure degrades to photo-only prefill', () async {
    final controller = ScanFlowController(
      engine: ThrowingEngine(),
      parser: LogbookParser(),
      existingSites: const [],
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
    expect(prefill.photoPath, '/tmp/p.jpg');
    expect(prefill.importSource, 'ocr');
    expect(prefill.maxDepthMeters, isNull);
    expect(prefill.notes, isNull);
  });

  test('empty page yields photo-only prefill without appendix', () async {
    final controller = ScanFlowController(
      engine: FakeEngine(
        const OcrResult(blocks: [], imageSize: Size(100, 100)),
      ),
      parser: LogbookParser(),
      existingSites: const [],
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
    expect(prefill.notes, isNull);
    expect(prefill.photoPath, '/tmp/p.jpg');
  });
}
