import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'color_encode_cases.dart';

/// Phase 2 of scripts/run_color_encode_it.sh (issue #3521), shared by the
/// platform tests: encodes each input found under `<root>/in` with the real
/// engine into `<root>/out`, with a JSON report beside each output for the
/// host-side check. Skips cases whose input is absent.
///
/// With [waitForInputs], it first writes `<root>/waiting` and waits for the
/// host to copy the inputs in and write `<root>/in/.ready`: on Android the
/// app is reinstalled at launch, which clears any folder of its own the
/// host could have filled beforehand.
void colorEncodeInAppTests({
  required String engine,
  required bool onThisPlatform,
  required Future<Directory> Function() root,
  bool waitForInputs = false,
}) {
  if (waitForInputs && onThisPlatform) {
    setUpAll(() async {
      final dir = await root();
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'waiting')).writeAsString('');
      final ready = File(p.join(dir.path, 'in', '.ready'));
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (!await ready.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
  }

  Future<File?> input(String name) async {
    final file = File(p.join((await root()).path, 'in', name));
    return await file.exists() ? file : null;
  }

  Future<File> output(String name) async {
    final file = File(p.join((await root()).path, 'out', name));
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> writeReport(File out, Map<String, Object?> report) =>
      File('${out.path}.json').writeAsString(jsonEncode(report));

  for (final c in colorCases) {
    testWidgets('$engine colour encode of ${c.name}', (tester) async {
      if (!onThisPlatform) {
        markTestSkipped('$engine colour encode runs on its own platform only');
        return;
      }
      final source = await input(c.fileName);
      if (source == null) {
        markTestSkipped('no ${c.fileName}; run scripts/run_color_encode_it.sh');
        return;
      }
      final out = await output(c.fileName);
      final fractions = <double>[];
      String? error;
      var unsupported = false;
      try {
        await colorEncoderForThisPlatform()!.encodeWithColor(
          source: source,
          output: out,
          timeline: testTimeline,
          onProgress: fractions.add,
        );
      } on TranscodeUnsupportedException catch (e) {
        // A device that cannot do this source says so; the host check
        // records it rather than failing (an emulator cannot edit HDR).
        unsupported = true;
        error = '$e';
      } on Object catch (e) {
        error = '$e';
      }
      await writeReport(out, {
        'error': unsupported ? null : error,
        'unsupported': unsupported ? error : null,
        'lastFraction': fractions.isEmpty ? null : fractions.last,
        'tmpLeft': await File('${out.path}.tmp').exists(),
      });
      if (!unsupported) expect(error, isNull);
    });
  }

  testWidgets('$engine colour encode cancels', (tester) async {
    if (!onThisPlatform) {
      markTestSkipped('$engine colour encode runs on its own platform only');
      return;
    }
    final source = await input(longCase.fileName);
    if (source == null) {
      markTestSkipped(
        'no ${longCase.fileName}; run scripts/run_color_encode_it.sh',
      );
      return;
    }
    final out = await output(longCase.fileName);
    final cancel = ColorEncodeCancel();
    var cancelled = false;
    var progressEvents = 0;
    String? error;
    // Cancelled on the first progress past 5%, or after a second whether or
    // not progress arrives, so the cancel itself is always exercised.
    final timer = Timer(const Duration(seconds: 1), cancel.cancel);
    try {
      await colorEncoderForThisPlatform()!.encodeWithColor(
        source: source,
        output: out,
        timeline: testTimeline,
        cancel: cancel,
        onProgress: (f) {
          progressEvents++;
          if (f > 0.05) cancel.cancel();
        },
      );
    } on TranscodeCancelledException {
      cancelled = true;
    } on Object catch (e) {
      error = '$e';
    } finally {
      timer.cancel();
    }
    await writeReport(out, {
      'cancelled': cancelled,
      'error': error,
      'progressEvents': progressEvents,
      'outputExists': await out.exists(),
      'tmpLeft': await File('${out.path}.tmp').exists(),
    });
    expect(cancelled, isTrue);
  });
}
