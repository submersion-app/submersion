import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// The tag string as an on-screen QR code (spec section 8, Tag card).
///
/// Always dark modules on a light ground with a four-module quiet zone,
/// whatever the theme: many decoders refuse an inverted code, and the QR
/// standard needs the margin to find the finder patterns. Error correction M
/// matches the printed label so both scan alike.
class PassportQrView extends StatelessWidget {
  const PassportQrView({
    super.key,
    required this.data,
    required this.size,
    required this.semanticLabel,
  });

  final String data;
  final double size;

  /// What a screen reader announces. The URL itself is never read out: it
  /// is a long run of characters that means nothing spoken.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: QrModulesPainter(
            image: QrImage(code),
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
    );
  }
}

class QrModulesPainter extends CustomPainter {
  QrModulesPainter({required this.image, required this.devicePixelRatio});

  final QrImage image;
  final double devicePixelRatio;

  /// Fixed, not themed: see [PassportQrView].
  final Color color = const Color(0xFF000000);
  final Color background = const Color(0xFFFFFFFF);

  /// Light margin on every side, in modules.
  final int quietModules = 4;

  int get moduleCount => image.moduleCount;

  /// The side of one module in logical pixels, snapped down to whole device
  /// pixels so adjacent modules share an edge instead of leaving
  /// anti-aliased seams. Never smaller than one device pixel.
  static double cellSize(double side, int cells, double devicePixelRatio) {
    final devicePixels = (side * devicePixelRatio / cells).floor();
    return (devicePixels < 1 ? 1 : devicePixels) / devicePixelRatio;
  }

  /// Where the first module row and column start, in logical pixels: the
  /// grid centred with its quiet zone, then snapped down to a whole device
  /// pixel, since a whole-pixel cell on a half-pixel origin still blurs
  /// every edge.
  static double moduleOrigin(
    double side,
    int cells,
    double cell,
    int quietModules,
    double devicePixelRatio,
  ) {
    final raw = (side - cell * cells) / 2 + cell * quietModules;
    return (raw * devicePixelRatio).floorToDouble() / devicePixelRatio;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final cells = image.moduleCount + 2 * quietModules;
    final cell = cellSize(side, cells, devicePixelRatio);
    final origin = moduleOrigin(
      side,
      cells,
      cell,
      quietModules,
      devicePixelRatio,
    );
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(origin + c * cell, origin + r * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(QrModulesPainter old) =>
      old.image != image || old.devicePixelRatio != devicePixelRatio;
}
