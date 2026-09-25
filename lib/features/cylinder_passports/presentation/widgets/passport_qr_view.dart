import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// The tag string as an on-screen QR code (spec section 8, Tag card).
/// Error correction M matches the printed label so both scan alike.
class PassportQrView extends StatelessWidget {
  const PassportQrView({super.key, required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: data,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: QrModulesPainter(image: image, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class QrModulesPainter extends CustomPainter {
  QrModulesPainter({required this.image, required this.color});

  final QrImage image;
  final Color color;

  int get moduleCount => image.moduleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cell = size.shortestSide / image.moduleCount;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(QrModulesPainter old) =>
      old.image != image || old.color != color;
}
