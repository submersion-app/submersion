import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'harness.dart';

/// Phase 3 of scripts/run_color_encode_it.sh (issue #3521): checks what the
/// in-app encode wrote against its input and [correctPixel].
void main() {
  late String ffmpeg;
  late String ffprobe;
  final root = colorItOutputRoot();
  File input(String name) => File(p.join(root.path, 'in', name));
  File output(String name) => File(p.join(root.path, 'out', name));
  Map<String, dynamic> report(String name) =>
      jsonDecode(File('${output(name).path}.json').readAsStringSync())
          as Map<String, dynamic>;

  setUpAll(() async {
    ffmpeg = (await which('ffmpeg'))!;
    ffprobe = (await which('ffprobe'))!;
  });

  for (final c in colorCases) {
    test('colour encode keeps ${c.name}', () async {
      final r = report(c.fileName);
      if (r['unsupported'] != null) {
        markTestSkipped(
          'this device cannot encode ${c.name}: ${r['unsupported']}',
        );
        return;
      }
      expect(r['error'], isNull, reason: 'encode error: ${r['error']}');
      expect(r['tmpLeft'], isFalse);
      expect(r['lastFraction'], closeTo(1.0, 0.05));
      final source = input(c.fileName);
      final copy = output(c.fileName);

      final json = await probeJson(ffprobe, copy);
      final video = (json['streams'] as List).first as Map;
      expect(video['codec_name'], c.codec);
      if (c.codec == 'hevc') expect(video['codec_tag_string'], 'hvc1');
      expect(video['width'], 320);
      expect(video['height'], 240);
      expect(
        '${video['pix_fmt']}'.contains('10'),
        c.tenBit,
        reason: 'bit depth: ${video['pix_fmt']}',
      );
      if (c.transfer == SignalTransfer.hlg) {
        expect(video['color_transfer'], 'arib-std-b67');
        expect(video['color_primaries'], 'bt2020');
      }
      if (c.transfer == SignalTransfer.pq) {
        expect(video['color_transfer'], 'smpte2084');
        expect(video['color_primaries'], 'bt2020');
        final frame = (json['frames'] as List).first as Map;
        expect(
          '${frame['side_data_list']}',
          contains('Mastering display metadata'),
        );
      }
      if (c.rotation != 0) {
        expect('${video['side_data_list']}', contains('rotation'));
      }
      expect(await hasAudio(ffprobe, copy), isTrue);
      final formatTags = ((json['format'] as Map)['tags'] as Map?) ?? {};
      expect(
        '${formatTags['creation_time']}',
        startsWith('2026-05-01'),
        reason: 'recording date in $formatTags',
      );
      final tags = await allTags(ffprobe, copy);
      expect(
        tags.keys.any((k) => k.contains('location')),
        isTrue,
        reason: 'location in $tags',
      );

      final hdr = c.transfer != SignalTransfer.sdr;
      final tolerance = c.tenBit ? 0.02 : 0.03;
      // The timeline follows presentation time, the player's position: a
      // clip whose first frame is shown at 1.5 s gets the colour for 1.5 s.
      final first = await firstFrameSeconds(ffprobe, source);
      // An engine may move a late-starting clip to start at 0 (Media
      // Foundation drops the leading empty edit) or stretch its first frame
      // back to 0 (AVFoundation): read each file at the same point of its
      // content, lined up by the last frame.
      final offset =
          await lastFrameSeconds(ffprobe, copy) -
          await lastFrameSeconds(ffprobe, source);
      double inCopy(double t) => t + offset;
      List<double> expected(List<double> source, double t) => correctPixel(
        source,
        testTimeline.matrixAt((t * 1000).round()),
        c.transfer,
      );
      // An engine's YUV and RGB conversions can shift every frame by the
      // same amount (an Android emulator's do): measured once, held to a
      // loose bound, and taken out of the check of the correction itself.
      // Measured where the timeline no longer changes (from 2 s), so a
      // timing difference cannot pass for a conversion shift.
      final steady = first + 2.2;
      final steadyBefore = await bandColors(ffmpeg, source, steady, hdr: hdr);
      final steadyAfter = await bandColors(
        ffmpeg,
        copy,
        inCopy(steady),
        hdr: hdr,
      );
      final shift = [
        for (var band = 0; band < steadyBefore.length; band++)
          [
            for (var ch = 0; ch < 3; ch++)
              steadyAfter[band][ch] - expected(steadyBefore[band], steady)[ch],
          ],
      ];
      for (final s in shift.expand((band) => band)) {
        expect(s.abs(), lessThan(0.05), reason: 'conversion shift $shift');
      }
      for (final t in [first + 0.5, first + 1.5]) {
        final before = await bandColors(ffmpeg, source, t, hdr: hdr);
        final after = await bandColors(ffmpeg, copy, inCopy(t), hdr: hdr);
        for (var band = 0; band < before.length; band++) {
          final want = [
            for (var ch = 0; ch < 3; ch++)
              expected(before[band], t)[ch] + shift[band][ch],
          ];
          for (var ch = 0; ch < 3; ch++) {
            expect(
              after[band][ch],
              closeTo(want[ch], tolerance),
              reason:
                  '${c.name} at $t s, band $band channel $ch: '
                  'source ${before[band]}, want $want, got ${after[band]}',
            );
          }
        }
      }
    });
  }

  test('colour encode cancels cleanly', () {
    final r = report(longCase.fileName);
    expect(r['cancelled'], isTrue, reason: 'outcome: $r');
    expect(r['progressEvents'], greaterThan(0), reason: 'no progress: $r');
    expect(r['outputExists'], isFalse);
    expect(r['tmpLeft'], isFalse);
  });
}
