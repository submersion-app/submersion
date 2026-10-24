import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'helpers/color_encode_cases.dart';

/// Phase 2 of scripts/run_color_encode_it.sh (issue #3521): the real
/// AVFoundation colour encode on a macOS build. The sandboxed app may not
/// run ffmpeg, so the script synthesizes the inputs into the app's temp
/// folder first and checks the outputs afterwards; this test only encodes,
/// and skips when the inputs are absent. NOT part of plain `flutter test`.
/// iOS shares the Swift and is checked on a device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final root = p.join(Directory.systemTemp.path, colorItFolder);
  File input(String name) => File(p.join(root, 'in', name));
  File output(String name) => File(p.join(root, 'out', name));

  Future<void> writeReport(String name, Map<String, Object?> report) async {
    final file = File('${output(name).path}.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(report));
  }

  for (final c in colorCases) {
    testWidgets('AVFoundation colour encode of ${c.name}', (tester) async {
      if (!Platform.isMacOS) {
        markTestSkipped('darwin colour encode runs on macOS only');
        return;
      }
      final source = input(c.fileName);
      if (!await source.exists()) {
        markTestSkipped(
          'no ${source.path}; run scripts/run_color_encode_it.sh',
        );
        return;
      }
      final out = output(c.fileName);
      await out.parent.create(recursive: true);
      final fractions = <double>[];
      String? error;
      try {
        await colorEncoderForThisPlatform()!.encodeWithColor(
          source: source,
          output: out,
          timeline: testTimeline,
          onProgress: fractions.add,
        );
      } on Object catch (e) {
        error = '$e';
      }
      await writeReport(c.fileName, {
        'error': error,
        'lastFraction': fractions.isEmpty ? null : fractions.last,
        'tmpLeft': await File('${out.path}.tmp').exists(),
      });
      expect(error, isNull);
    });
  }

  testWidgets('AVFoundation colour encode cancels', (tester) async {
    if (!Platform.isMacOS) {
      markTestSkipped('darwin colour encode runs on macOS only');
      return;
    }
    final source = input(longCase.fileName);
    if (!await source.exists()) {
      markTestSkipped('no ${source.path}; run scripts/run_color_encode_it.sh');
      return;
    }
    final out = output(longCase.fileName);
    await out.parent.create(recursive: true);
    final cancel = ColorEncodeCancel();
    var cancelled = false;
    try {
      await colorEncoderForThisPlatform()!.encodeWithColor(
        source: source,
        output: out,
        timeline: testTimeline,
        cancel: cancel,
        onProgress: (f) {
          if (f > 0.05) cancel.cancel();
        },
      );
    } on TranscodeCancelledException {
      cancelled = true;
    }
    await writeReport(longCase.fileName, {
      'cancelled': cancelled,
      'outputExists': await out.exists(),
      'tmpLeft': await File('${out.path}.tmp').exists(),
    });
    expect(cancelled, isTrue);
  });
}
