import 'package:pdf/pdf.dart';

import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Abstract base class for PDF template builders.
///
/// Each template implementation provides a specific layout and style
/// for the exported dive logbook PDF. Templates should implement
/// [buildPdf] to generate the PDF bytes.
abstract class PdfTemplateBuilder {
  /// The template type this builder implements.
  PdfTemplate get templateType;

  /// Human-readable name for the template.
  String get displayName => templateType.displayName;

  /// Short description for UI display.
  String get description => templateType.description;

  /// Build the complete PDF document.
  ///
  /// Parameters:
  /// - [dives]: List of dives to include in the logbook
  /// - [pageSize]: Page size for the PDF (A4 or Letter)
  /// - [title]: Title for the logbook cover page
  /// - [diveSignatures]: Map of dive ID to list of signatures for that dive
  /// - [certifications]: Optional list of certifications to include
  /// - [diver]: Optional diver profile for personalization
  ///
  /// Returns the PDF document as a byte array.
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    String title = 'Dive Logbook',
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
  });

  /// Convert [PdfPageSize] to the pdf package's [PdfPageFormat].
  PdfPageFormat getPageFormat(PdfPageSize pageSize) {
    switch (pageSize) {
      case PdfPageSize.a4:
        return PdfPageFormat.a4;
      case PdfPageSize.letter:
        return PdfPageFormat.letter;
    }
  }
}
