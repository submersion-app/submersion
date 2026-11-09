import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/small_image_decoder.dart';

/// An image whose decode never finishes.
class _StuckImage extends ImageProvider<_StuckImage> {
  final frame = Completer<ImageInfo>();

  @override
  Future<_StuckImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _StuckImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(frame.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PaintingBinding.instance.imageCache.clear());

  test('fits the image in the box and reads it back as RGBA', () async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 200, height: 100)),
    );

    final small = await decodeSmallImage(MemoryImage(png), box: 32);

    expect(small, isNotNull);
    expect(small!.width, 32);
    expect(small.height, 16);
    expect(small.rgba, hasLength(32 * 16 * 4));
  });

  test('a decode past its timeout is given up and leaves the cache', () async {
    final stuck = _StuckImage();

    final small = await decodeSmallImage(
      stuck,
      box: 32,
      timeout: const Duration(milliseconds: 20),
    );

    expect(small, isNull);
    final key = await ResizeImage(
      stuck,
      width: 32,
      height: 32,
      policy: ResizeImagePolicy.fit,
    ).obtainKey(ImageConfiguration.empty);
    expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
  });

  test('a decode that fails is an error for the caller', () async {
    await expectLater(
      decodeSmallImage(MemoryImage(Uint8List.fromList([1, 2, 3]))),
      throwsA(anything),
    );
  });
}
