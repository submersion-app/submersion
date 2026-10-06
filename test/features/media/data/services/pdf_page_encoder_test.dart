import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';

/// The page encode runs off the UI isolate (issue #1039: a 2048 px site card
/// render would otherwise stall the frame), so it takes raw BGRA pixels, the
/// one sendable form pdfium hands back.
void main() {
  test('encodes BGRA pixels to a JPEG of the same size and colour', () async {
    const width = 4;
    const height = 2;
    // Pure red in BGRA order: blue 0, green 0, red 255, alpha 255.
    final bgra = Uint8List(width * height * 4);
    for (var i = 0; i < bgra.length; i += 4) {
      bgra[i + 2] = 255;
      bgra[i + 3] = 255;
    }

    final jpeg = await PdfPageRenderer.encodeBgraJpeg(
      pixels: bgra,
      width: width,
      height: height,
      quality: 90,
    );

    final decoded = img.decodeJpg(jpeg)!;
    expect(decoded.width, width);
    expect(decoded.height, height);
    final pixel = decoded.getPixel(1, 1);
    expect(pixel.r, greaterThan(200));
    expect(pixel.g, lessThan(60));
    expect(pixel.b, lessThan(60));
  });

  test('a view into a larger buffer encodes only its own pixels', () async {
    // 8 leading bytes of opaque blue, then one red pixel in a 1x1 view.
    final backing = Uint8List.fromList([
      255, 0, 0, 255, 255, 0, 0, 255, //
      0, 0, 255, 255,
    ]);
    final view = Uint8List.sublistView(backing, 8);

    final jpeg = await PdfPageRenderer.encodeBgraJpeg(
      pixels: view,
      width: 1,
      height: 1,
      quality: 90,
    );

    final pixel = img.decodeJpg(jpeg)!.getPixel(0, 0);
    expect(pixel.r, greaterThan(200));
    expect(pixel.b, lessThan(60));
  });
}
