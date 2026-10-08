import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_parsing/path_parsing.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';

/// The generated artwork is a build artefact checked in like the icon font.
/// CI does not run the Python generator, so these tests are what keep the
/// file honest: its digest must match the sources it was built from, and
/// every path must parse and stay inside the figure box.
void main() {
  test('the generated artwork matches tool/figure', () {
    final dir = Directory(p.join('tool', 'figure'));
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
      bytes.addAll(file.readAsBytesSync());
    }
    expect(
      figureArtworkDigest,
      sha256.convert(bytes).toString(),
      reason: 'run: python3 tool/build_figure_artwork.py',
    );
  });

  test('the mannequin exists for both views', () {
    expect(figureArtwork['body_front']?.layer, 0);
    expect(figureArtwork['body_back']?.layer, 0);
  });

  test('every path parses and stays inside the figure box', () {
    for (final piece in figureArtwork.values) {
      expect(piece.paths, isNotEmpty, reason: piece.id);
      for (final path in piece.paths) {
        final proxy = _BoundsProxy();
        writeSvgPathDataToPath(path.d, proxy);
        expect(proxy.points, isNotEmpty, reason: '${piece.id}: ${path.d}');
        for (final point in proxy.points) {
          expect(
            point.$1,
            inInclusiveRange(-0.5, kFigureWidth + 0.5),
            reason: piece.id,
          );
          expect(
            point.$2,
            inInclusiveRange(-0.5, kFigureHeight + 0.5),
            reason: piece.id,
          );
        }
      }
    }
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
