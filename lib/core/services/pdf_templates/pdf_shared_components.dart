import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Shared PDF components used across multiple templates.
///
/// These helper methods provide consistent styling and layout for
/// common elements like headers, info chips, signatures, and
/// certification cards.
class PdfSharedComponents {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Format a date for display.
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Format a time for display.
  static String formatTime(DateTime time) => _timeFormat.format(time);

  /// Format a date and time for display.
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);

  /// Build a small info chip with label and value.
  static pw.Widget buildInfoChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// Build a stat row for summary pages.
  static pw.Widget buildStatRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build a signature block for display in PDF.
  static pw.Widget buildSignatureBlock(Signature signature) {
    pw.ImageProvider? signatureImage;
    if (signature.hasImage) {
      try {
        signatureImage = pw.MemoryImage(signature.imageData!);
      } catch (_) {
        // Ignore image load errors
      }
    }

    return pw.Container(
      width: 80,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (signatureImage != null)
            pw.SizedBox(
              height: 30,
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            )
          else
            pw.SizedBox(
              height: 30,
              child: pw.Center(
                child: pw.Text(
                  '[Signature]',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            signature.signerName,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            signature.isBuddySignature ? 'Buddy' : 'Instructor',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            formatDate(signature.signedAt),
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build a larger signature block for professional template.
  static pw.Widget buildLargeSignatureBlock({
    String label = 'Signature',
    Signature? signature,
    double width = 150,
    double height = 60,
  }) {
    pw.ImageProvider? signatureImage;
    if (signature?.hasImage == true) {
      try {
        signatureImage = pw.MemoryImage(signature!.imageData!);
      } catch (_) {
        // Ignore image load errors
      }
    }

    return pw.Container(
      width: width,
      height: height + 20,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            width: width,
            height: height,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: signatureImage != null
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  )
                : pw.Center(
                    child: pw.Text(
                      '',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build an empty stamp area box for professional template.
  static pw.Widget buildStampArea({
    double size = 100,
    String label = 'Official Stamp',
  }) {
    return pw.Container(
      width: size,
      height: size + 16,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            width: size,
            height: size,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Center(
              child: pw.Text(
                '',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the certification cards page.
  ///
  /// Displays certifications with their scanned card images (if available).
  /// For agency-specific templates, certifications from that agency are
  /// highlighted.
  static pw.Widget buildCertificationCardsPage({
    required List<Certification> certifications,
    Diver? diver,
    String? highlightAgency,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Certifications',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        if (diver != null) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            diver.name,
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 16),
        ...certifications.map(
          (cert) => _buildCertificationCard(
            cert,
            isHighlighted:
                highlightAgency != null &&
                cert.agency.name.toLowerCase().contains(
                  highlightAgency.toLowerCase(),
                ),
            accentColor: accentColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCertificationCard(
    Certification cert, {
    bool isHighlighted = false,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    // Try to load card images
    pw.ImageProvider? frontImage;
    pw.ImageProvider? backImage;

    if (cert.photoFront != null) {
      try {
        frontImage = pw.MemoryImage(cert.photoFront!);
      } catch (_) {
        // Ignore load errors
      }
    }
    if (cert.photoBack != null) {
      try {
        backImage = pw.MemoryImage(cert.photoBack!);
      } catch (_) {
        // Ignore load errors
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isHighlighted ? accentColor : PdfColors.grey300,
          width: isHighlighted ? 2 : 1,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      cert.name,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: isHighlighted ? accentColor : PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      cert.agency.displayName,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              if (cert.level != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: isHighlighted ? accentColor : PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    cert.level!.displayName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: isHighlighted
                          ? PdfColors.white
                          : PdfColors.grey700,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Details row
          pw.Row(
            children: [
              if (cert.cardNumber != null) ...[
                pw.Text(
                  'Card #: ${cert.cardNumber}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(width: 16),
              ],
              if (cert.issueDate != null)
                pw.Text(
                  'Issued: ${formatDate(cert.issueDate!)}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
          // Card images
          if (frontImage != null || backImage != null) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                if (frontImage != null)
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Front',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          height: 100,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(frontImage, fit: pw.BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (frontImage != null && backImage != null)
                  pw.SizedBox(width: 12),
                if (backImage != null)
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Back',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          height: 100,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(backImage, fit: pw.BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build a cover page for the logbook.
  static pw.Widget buildCoverPage({
    required String title,
    required int diveCount,
    required PdfPageFormat pageFormat,
    DateTime? firstDiveDate,
    DateTime? lastDiveDate,
    Diver? diver,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          if (diver != null) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              diver.name,
              style: const pw.TextStyle(fontSize: 20, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 24),
          pw.Text('$diveCount Dives', style: const pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 10),
          if (firstDiveDate != null && lastDiveDate != null)
            pw.Text(
              '${formatDate(firstDiveDate)} - ${formatDate(lastDiveDate)}',
              style: const pw.TextStyle(fontSize: 16),
            ),
          pw.SizedBox(height: 40),
          pw.Text(
            'Generated on ${formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Build a summary page with dive statistics.
  static pw.Widget buildSummaryPage({
    required List<Dive> dives,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    if (dives.isEmpty) {
      return pw.Center(child: pw.Text('No dives to summarize'));
    }

    final totalDiveTime = dives
        .where((d) => d.duration != null)
        .fold<Duration>(Duration.zero, (sum, d) => sum + d.duration!);
    final maxDepth = dives
        .where((d) => d.maxDepth != null)
        .map((d) => d.maxDepth!)
        .fold<double>(0, (max, depth) => depth > max ? depth : max);
    final avgDepth = dives.where((d) => d.avgDepth != null).isEmpty
        ? 0.0
        : dives
                  .where((d) => d.avgDepth != null)
                  .map((d) => d.avgDepth!)
                  .reduce((a, b) => a + b) /
              dives.where((d) => d.avgDepth != null).length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 20),
        buildStatRow('Total Dives', '${dives.length}'),
        buildStatRow(
          'Total Dive Time',
          '${totalDiveTime.inHours}h ${totalDiveTime.inMinutes % 60}m',
        ),
        buildStatRow('Deepest Dive', '${maxDepth.toStringAsFixed(1)}m'),
        buildStatRow('Average Depth', '${avgDepth.toStringAsFixed(1)}m'),
        buildStatRow(
          'Unique Sites',
          '${dives.map((d) => d.site?.id).where((id) => id != null).toSet().length}',
        ),
      ],
    );
  }

  /// Build star rating display.
  ///
  /// Uses asterisks instead of Unicode stars for better font compatibility.
  static pw.Widget buildRating(int? rating) {
    if (rating == null || rating <= 0) {
      return pw.SizedBox.shrink();
    }
    // Use asterisks for compatibility - Unicode stars may not render with default fonts
    return pw.Text(
      '${'*' * rating}${'.' * (5 - rating)}',
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.amber,
      ),
    );
  }
}
