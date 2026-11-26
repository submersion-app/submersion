import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_parsing/path_parsing.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_artwork.gen.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_space.dart';

/// The trim figure's side-view artwork (issue #5028) is a build artefact
/// checked in like the gear figure's. CI does not run the generator, so these
/// tests keep the file honest: its digest must match its sources, and every
/// path must parse and stay inside the side box.
void main() {
  test('the generated artwork matches tool/figure_side', () {
    final dir = Directory(p.join('tool', 'figure_side'));
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.svg') ||
                  p.basename(f.path) == 'manifest.json',
            )
            .toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final bytes = <int>[];
    for (final file in files) {
      bytes.addAll(utf8.encode('${p.basename(file.path)}\n'));
      final text = file.readAsStringSync();
      bytes.addAll(
        utf8.encode(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n')),
      );
    }
    expect(
      trimArtworkDigest,
      sha256.convert(bytes).toString(),
      reason: 'run: python3.14 tool/build_trim_artwork.py',
    );
  });

  test('the body exists for every moving part', () {
    expect(trimArtwork['body_side_torso']?.segment, TrimSegment.torso);
    expect(trimArtwork['body_side_arm']?.segment, TrimSegment.arm);
    expect(trimArtwork['body_side_shin']?.segment, TrimSegment.shin);
    expect(trimArtwork['body_side_foot']?.segment, TrimSegment.foot);
  });

  test('every path parses and stays inside the side box', () {
    for (final piece in trimArtwork.values) {
      expect(piece.paths, isNotEmpty, reason: piece.id);
      for (final path in piece.paths) {
        final proxy = _BoundsProxy();
        writeSvgPathDataToPath(path.d, proxy);
        expect(proxy.points, isNotEmpty, reason: '${piece.id}: ${path.d}');
        for (final point in proxy.points) {
          expect(
            point.$1,
            inInclusiveRange(-0.5, kTrimWidth + 0.5),
            reason: piece.id,
          );
          expect(
            point.$2,
            inInclusiveRange(-0.5, kTrimHeight + 0.5),
            reason: piece.id,
          );
        }
      }
    }
  });

  test('the side space maps the body model', () {
    final body = TrimBody(heightCm: 175);
    final shoulder = trimSpaceOf(body.shoulder, body);
    expect(shoulder.dx, closeTo(kTrimShoulder.dx, 0.5));
    expect(shoulder.dy, closeTo(kTrimShoulder.dy, 0.5));
    expect(trimSpaceOf(body.knee, body).dx, closeTo(kTrimKnee.dx, 0.5));
    final ankle = trimSpaceOf(
      body.ankle(TrimPose(armReach: 0, kneeBendDeg: 0)),
      body,
    );
    expect(ankle.dx, closeTo(kTrimAnkle.dx, 0.5));
  });
}

class _BoundsProxy extends PathProxy {
  final points = <(double, double)>[];

  @override
  void moveTo(double x, double y) => points.add((x, y));

  @override
  void lineTo(double x, double y) => points.add((x, y));

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    points.add((x1, y1));
    points.add((x2, y2));
    points.add((x3, y3));
  }

  @override
  void close() {}
}
