import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// Service for rendering certification cards to PNG images for sharing.
///
/// Uses programmatic Canvas drawing to generate images without requiring
/// widgets to be in the widget tree.
class CertificationCardRenderer {
  CertificationCardRenderer._();

  /// Standard credit card aspect ratio (CR80: 85.6mm × 53.98mm).
  static const double _cardAspectRatio = 1.586;

  /// Generates a certification card image programmatically using Canvas.
  ///
  /// Creates a credit card-style image with:
  /// - Agency-branded gradient background
  /// - Decorative wave pattern
  /// - Certification name and level
  /// - Diver name
  /// - Issue date and card number
  ///
  /// Returns the PNG bytes, or null if generation fails.
  static Future<Uint8List?> generateCardImage({
    required Certification certification,
    required String diverName,
  }) async {
    try {
      const width = 800.0;
      const height = width / _cardAspectRatio;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      final primaryColor = ui.Color(
        certification.agency.primaryColor.toARGB32(),
      );
      final secondaryColor = ui.Color(
        certification.agency.secondaryColor.toARGB32(),
      );

      // Draw gradient background
      final gradientPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(width, height),
          [primaryColor, secondaryColor],
        );
      final cardRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(24),
      );
      canvas.drawRRect(cardRect, gradientPaint);

      // Draw decorative circles (wave pattern)
      _drawDecorativeCircles(canvas, width, height, primaryColor);

      // Draw agency name at top
      _drawText(
        canvas: canvas,
        text: certification.agency.displayName,
        x: 32,
        y: 32,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: const ui.Color(0xFFFFFFFF),
        maxWidth: width - 64,
      );

      // Draw certification name (large, centered vertically)
      _drawText(
        canvas: canvas,
        text: certification.name,
        x: 32,
        y: height * 0.35,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const ui.Color(0xFFFFFFFF),
        maxWidth: width - 64,
      );

      // Draw level if available
      if (certification.level != null) {
        _drawText(
          canvas: canvas,
          text: certification.level!.displayName,
          x: 32,
          y: height * 0.35 + 44,
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xCCFFFFFF),
          maxWidth: width - 64,
        );
      }

      // Draw diver name at bottom left
      _drawText(
        canvas: canvas,
        text: diverName.toUpperCase(),
        x: 32,
        y: height - 80,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const ui.Color(0xFFFFFFFF),
        maxWidth: width * 0.6,
      );

      // Draw card number if available (bottom left, below name)
      if (certification.cardNumber != null) {
        _drawText(
          canvas: canvas,
          text: certification.cardNumber!,
          x: 32,
          y: height - 48,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xAAFFFFFF),
          maxWidth: width * 0.6,
        );
      }

      // Draw issue date at bottom right
      if (certification.issueDate != null) {
        final dateFormat = DateFormat('MM/yy');
        final dateStr = dateFormat.format(certification.issueDate!);
        _drawTextRightAligned(
          canvas: canvas,
          text: dateStr,
          x: width - 32,
          y: height - 48,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: const ui.Color(0xFFFFFFFF),
        );
        _drawTextRightAligned(
          canvas: canvas,
          text: 'ISSUED',
          x: width - 32,
          y: height - 70,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xAAFFFFFF),
        );
      }

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

  /// Draws decorative circles for the wave pattern effect.
  static void _drawDecorativeCircles(
    Canvas canvas,
    double width,
    double height,
    ui.Color primaryColor,
  ) {
    final circlePaint = Paint()
      ..color = const ui.Color(0x1AFFFFFF)
      ..style = PaintingStyle.fill;

    // Large circle in top right
    canvas.drawCircle(
      Offset(width * 0.85, height * 0.1),
      height * 0.4,
      circlePaint,
    );

    // Medium circle
    canvas.drawCircle(
      Offset(width * 0.7, height * 0.3),
      height * 0.25,
      circlePaint,
    );

    // Small accent circle
    canvas.drawCircle(
      Offset(width * 0.9, height * 0.45),
      height * 0.15,
      circlePaint,
    );
  }

  /// Draws left-aligned text on the canvas.
  static void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
    required ui.Color color,
    double? maxWidth,
  }) {
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: fontSize,
              fontWeight: fontWeight,
              maxLines: 2,
              ellipsis: '...',
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth ?? 500));

    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  /// Draws right-aligned text on the canvas.
  static void _drawTextRightAligned({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
    required ui.Color color,
  }) {
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.right,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 200));

    // Position so that the right edge is at x
    canvas.drawParagraph(paragraph, Offset(x - 200, y));
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
