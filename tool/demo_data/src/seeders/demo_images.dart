import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Simple generated images for the demo logbook: certification cards and
/// document pages. Drawn here, so no real person's card or paperwork is ever
/// part of the sample data.
class DemoImages {
  DemoImages._();

  /// A credit-card sized certification card.
  static Uint8List card({
    required String agency,
    required String title,
    required String holder,
    required String number,
    required String issued,
    required int color,
    bool back = false,
  }) {
    final image = img.Image(width: 856, height: 540);
    img.fill(image, color: _rgb(back ? 0xF2F2F2 : color));
    img.fillRect(image, x1: 0, y1: 0, x2: 856, y2: 96, color: _rgb(0x102A43));
    img.drawString(
      image,
      agency,
      font: img.arial48,
      x: 40,
      y: 22,
      color: _rgb(0xFFFFFF),
    );
    if (back) {
      _lines(
        image,
        [
          'This card certifies the holder completed the',
          'training and requirements for this rating.',
          '',
          'Card number $number',
          'Sample data: not a real certification.',
        ],
        y: 150,
        color: 0x102A43,
      );
    } else {
      _lines(
        image,
        [title, '', holder, 'No. $number', 'Issued $issued'],
        y: 150,
        color: 0xFFFFFF,
      );
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  /// A plain page with a heading and lines of text.
  static Uint8List page({
    required String heading,
    required List<String> lines,
  }) {
    final image = img.Image(width: 1240, height: 1754);
    img.fill(image, color: _rgb(0xFFFFFF));
    img.drawString(
      image,
      heading,
      font: img.arial48,
      x: 100,
      y: 120,
      color: _rgb(0x102A43),
    );
    _lines(
      image,
      [...lines, '', 'Sample data for Submersion demo mode.'],
      y: 260,
      color: 0x333333,
    );
    return Uint8List.fromList(img.encodePng(image));
  }

  static void _lines(
    img.Image image,
    List<String> lines, {
    required int y,
    required int color,
  }) {
    for (var i = 0; i < lines.length; i++) {
      img.drawString(
        image,
        lines[i],
        font: img.arial24,
        x: 40 + (image.width > 1000 ? 60 : 0),
        y: y + i * 44,
        color: _rgb(color),
      );
    }
  }

  static img.Color _rgb(int rgb) =>
      img.ColorRgb8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
}
