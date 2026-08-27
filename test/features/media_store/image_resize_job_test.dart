import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media_store/data/image_resize_job.dart';

/// The off-isolate decode/resize/encode the media store's upload pipeline
/// runs (#1175).
///
/// Both entry points are exercised through the real `compute` hop, not just
/// the isolate body: the hop is the whole point of the class, and it is the
/// part that can fail in ways the body cannot (an unsendable argument, a
/// closure capturing something isolate-local).
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('image_resize_job_test');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  String out(String name) => '${root.path}${Platform.pathSeparator}$name';

  /// A solid PNG of the given size, big enough to exceed the ceilings below.
  File writePng(String name, {required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(20, 80, 140));
    final file = File(out(name))..writeAsBytesSync(img.encodePng(image));
    return file;
  }

  test('resizes an oversized source down to the ceiling', () async {
    final source = writePng('big.png', width: 900, height: 600);
    final destination = out('thumb.jpg');

    final result = await resizeToJpegFile(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: destination,
        declaredName: 'big.png',
        maxDimension: 512,
        jpegQuality: 80,
      ),
    );

    expect(result.outcome, ImageResizeOutcome.written);
    expect(result.sizeBytes, greaterThan(0));

    final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
    expect(decoded.width, 512);
    // Aspect ratio preserved: only the width is constrained.
    expect(decoded.height, 341);
  });

  test('reports undecodable rather than throwing', () async {
    final source = File(out('nonsense.jpg'))
      ..writeAsBytesSync(List<int>.filled(64, 7));

    final result = await resizeToJpegFile(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: out('never.jpg'),
        declaredName: 'nonsense.jpg',
        maxDimension: 512,
        jpegQuality: 80,
      ),
    );

    expect(result.outcome, ImageResizeOutcome.undecodable);
    expect(
      File(out('never.jpg')).existsSync(),
      isFalse,
      reason: 'a failed job must not leave a truncated staging file behind',
    );
  });

  test('skipWhenUnderCeiling declines a source already small enough', () async {
    final source = writePng('small.png', width: 100, height: 80);

    final result = await resizeToJpegFile(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: out('never.jpg'),
        declaredName: 'small.png',
        maxDimension: 512,
        jpegQuality: 80,
        skipWhenUnderCeiling: true,
      ),
    );

    expect(result.outcome, ImageResizeOutcome.underCeiling);
    expect(File(out('never.jpg')).existsSync(), isFalse);
  });

  test('without skipWhenUnderCeiling a small source is still re-encoded', () {
    // Thumbnails take this branch: re-encoding is what strips EXIF/GPS, so a
    // small source must not short-circuit.
    final source = writePng('small.png', width: 100, height: 80);
    final destination = out('thumb.jpg');

    final result = runImageResizeRequest(
      ImageResizeRequest.fromFile(
        sourcePath: source.path,
        destinationPath: destination,
        declaredName: 'small.png',
        maxDimension: 512,
        jpegQuality: 80,
      ),
    );

    expect(result.outcome, ImageResizeOutcome.written);
    final decoded = img.decodeJpg(File(destination).readAsBytesSync())!;
    expect(decoded.width, 100, reason: 'never upscaled to the ceiling');
  });

  test('the bytes entry point survives the isolate hop', () async {
    final image = img.Image(width: 700, height: 700);
    img.fill(image, color: img.ColorRgb8(200, 30, 30));
    final destination = out('from_bytes.jpg');

    final result = await resizeToJpegFile(
      ImageResizeRequest.fromBytes(
        bytes: img.encodePng(image),
        destinationPath: destination,
        declaredName: 'rendition.png',
        maxDimension: 512,
        jpegQuality: 80,
      ),
    );

    expect(result.outcome, ImageResizeOutcome.written);
    expect(img.decodeJpg(File(destination).readAsBytesSync())!.width, 512);
  });
}
