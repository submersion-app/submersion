import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// Service for rendering certification cards to PNG images for sharing.
///
/// Uses Flutter's rendering pipeline to capture widgets as images.
class CertificationCardRenderer {
  CertificationCardRenderer._();

  /// Renders a widget wrapped in a RepaintBoundary to a PNG image.
  ///
  /// The [key] must be attached to a RepaintBoundary that is currently
  /// in the widget tree.
  ///
  /// Returns the PNG bytes, or null if rendering fails.
  static Future<Uint8List?> renderCardToImage(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject();
      if (boundary == null || boundary is! RenderRepaintBoundary) {
        return null;
      }

      // Use 2.0 pixel ratio for retina quality
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Generates a formal certificate image programmatically using Canvas.
  ///
  /// Creates a 1200x800 certificate layout with:
  /// - White background with agency-colored border
  /// - Agency name at top
  /// - Diver name prominently displayed
  /// - Certification name and details
  /// - Issue date and card number at bottom
  ///
  /// Returns the PNG bytes, or null if generation fails.
  static Future<Uint8List?> generateCertificateImage({
    required Certification certification,
    required String diverName,
  }) async {
    try {
      const width = 1200.0;
      const height = 800.0;
      const borderWidth = 8.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      final agencyColor = ui.Color(
        certification.agency.primaryColor.toARGB32(),
      );

      // Draw white background
      final backgroundPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height),
        backgroundPaint,
      );

      // Draw agency color border
      final borderPaint = Paint()
        ..color = agencyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawRect(
        const Rect.fromLTWH(
          borderWidth / 2,
          borderWidth / 2,
          width - borderWidth,
          height - borderWidth,
        ),
        borderPaint,
      );

      // Draw inner decorative border
      final innerBorderPaint = Paint()
        ..color = agencyColor.withAlpha((0.3 * 255).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(
        const Rect.fromLTWH(20, 20, width - 40, height - 40),
        innerBorderPaint,
      );

      // Draw agency name at top
      _drawCenteredText(
        canvas: canvas,
        text: certification.agency.displayName,
        y: 60,
        width: width,
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: agencyColor,
      );

      // Draw decorative line under agency name
      final linePaint = Paint()
        ..color = agencyColor
        ..strokeWidth = 2.0;
      canvas.drawLine(
        const Offset(width * 0.3, 120),
        const Offset(width * 0.7, 120),
        linePaint,
      );

      // Draw "This certifies that"
      _drawCenteredText(
        canvas: canvas,
        text: 'This certifies that',
        y: 180,
        width: width,
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: const ui.Color(0xFF666666),
      );

      // Draw diver name (large, prominent)
      _drawCenteredText(
        canvas: canvas,
        text: diverName,
        y: 240,
        width: width,
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: const ui.Color(0xFF333333),
      );

      // Draw "has completed training as"
      _drawCenteredText(
        canvas: canvas,
        text: 'has completed training as',
        y: 330,
        width: width,
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: const ui.Color(0xFF666666),
      );

      // Draw certification name
      _drawCenteredText(
        canvas: canvas,
        text: certification.name,
        y: 390,
        width: width,
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: agencyColor,
      );

      // Draw level if available
      if (certification.level != null) {
        _drawCenteredText(
          canvas: canvas,
          text: certification.level!.displayName,
          y: 450,
          width: width,
          fontSize: 28,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xFF555555),
        );
      }

      // Draw issue date and card number at bottom
      final dateFormat = DateFormat('MMMM d, yyyy');
      final issueDateStr = certification.issueDate != null
          ? 'Issued: ${dateFormat.format(certification.issueDate!)}'
          : '';
      final cardNumberStr = certification.cardNumber != null
          ? 'Card #: ${certification.cardNumber}'
          : '';

      if (issueDateStr.isNotEmpty) {
        _drawCenteredText(
          canvas: canvas,
          text: issueDateStr,
          y: 560,
          width: width,
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xFF777777),
        );
      }

      if (cardNumberStr.isNotEmpty) {
        _drawCenteredText(
          canvas: canvas,
          text: cardNumberStr,
          y: 600,
          width: width,
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xFF777777),
        );
      }

      // Draw instructor info if available
      if (certification.instructorName != null) {
        final instructorText = certification.instructorNumber != null
            ? 'Instructor: ${certification.instructorName} (${certification.instructorNumber})'
            : 'Instructor: ${certification.instructorName}';
        _drawCenteredText(
          canvas: canvas,
          text: instructorText,
          y: 640,
          width: width,
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xFF888888),
        );
      }

      // Draw decorative line above footer
      canvas.drawLine(
        const Offset(width * 0.2, 700),
        const Offset(width * 0.8, 700),
        linePaint,
      );

      // Draw "Submersion Dive Log" footer
      _drawCenteredText(
        canvas: canvas,
        text: 'Submersion Dive Log',
        y: 730,
        width: width,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: const ui.Color(0xFF999999),
      );

      // End recording and convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Draws centered text on the canvas at the specified y position.
  static void _drawCenteredText({
    required Canvas canvas,
    required String text,
    required double y,
    required double width,
    required double fontSize,
    required FontWeight fontWeight,
    required ui.Color color,
  }) {
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: width));

    canvas.drawParagraph(paragraph, Offset(0, y));
  }
}
