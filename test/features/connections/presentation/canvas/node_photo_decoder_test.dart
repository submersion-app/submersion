import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/canvas/node_photo_decoder.dart';

void main() {
  testWidgets('node photos decode at the thumbnail width', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 512, 512),
        Paint()..color = Colors.teal,
      );
      final big = await recorder.endRecording().toImage(512, 512);
      final png = (await big.toByteData(format: ui.ImageByteFormat.png))!;
      big.dispose();
      final img = await decodeNodePhoto(png.buffer.asUint8List());
      expect(img.width, kNodePhotoDecodeWidth);
      expect(img.height, kNodePhotoDecodeWidth);
      img.dispose();
    });
  });
}
