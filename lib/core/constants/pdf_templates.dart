/// PDF template types for dive logbook export.
///
/// Each template provides a different layout and style for the exported PDF:
/// - [simple]: High-density table format, 15-20 dives per page
/// - [detailed]: One dive per page with the full field set and a profile chart
/// - [padiStyle]: Layout mimicking PADI paper logbook format
/// - [nauiStyle]: Layout mimicking NAUI paper logbook format
enum PdfTemplate { simple, detailed, padiStyle, nauiStyle }

/// Extension methods for [PdfTemplate].
extension PdfTemplateExtension on PdfTemplate {
  /// Human-readable display name for the template.
  String get displayName {
    switch (this) {
      case PdfTemplate.simple:
        return 'Simple';
      case PdfTemplate.detailed:
        return 'Detailed';
      case PdfTemplate.padiStyle:
        return 'PADI Style';
      case PdfTemplate.nauiStyle:
        return 'NAUI Style';
    }
  }

  /// Short description of the template for UI display.
  String get description {
    switch (this) {
      case PdfTemplate.simple:
        return 'Compact table format, many dives per page';
      case PdfTemplate.detailed:
        return 'One dive per page with the profile chart and every field';
      case PdfTemplate.padiStyle:
        return 'Layout matching PADI logbook format';
      case PdfTemplate.nauiStyle:
        return 'Layout matching NAUI logbook format';
    }
  }

  /// Number of dives displayed per page for this template.
  int get divesPerPage {
    switch (this) {
      case PdfTemplate.simple:
        return 18;
      case PdfTemplate.detailed:
        return 1;
      case PdfTemplate.padiStyle:
        return 4;
      case PdfTemplate.nauiStyle:
        return 4;
    }
  }

  /// Whether this template supports certification cards.
  bool get supportsCertificationCards {
    switch (this) {
      case PdfTemplate.simple:
      case PdfTemplate.detailed:
      case PdfTemplate.padiStyle:
      case PdfTemplate.nauiStyle:
        return true;
    }
  }
}

/// PDF page size options for export.
enum PdfPageSize { a4, letter }

/// Extension methods for [PdfPageSize].
extension PdfPageSizeExtension on PdfPageSize {
  /// Human-readable display name for the page size.
  String get displayName {
    switch (this) {
      case PdfPageSize.a4:
        return 'A4';
      case PdfPageSize.letter:
        return 'Letter';
    }
  }

  /// Description with dimensions.
  String get description {
    switch (this) {
      case PdfPageSize.a4:
        return '210 x 297 mm';
      case PdfPageSize.letter:
        return '8.5 x 11 in';
    }
  }
}

/// Options for PDF export configuration.
///
/// Used to customize the PDF output when exporting dive logs.
class PdfExportOptions {
  /// The template style to use for the PDF.
  final PdfTemplate template;

  /// The page size for the PDF.
  final PdfPageSize pageSize;

  /// Whether to add an official stamp box and large signature blocks.
  ///
  /// For a logbook presented to a training agency for verification. Only the
  /// detailed template renders these.
  final bool includeVerificationAreas;

  /// Whether to include certification card images in the PDF.
  ///
  /// Only applicable for templates that support certification cards.
  /// When enabled, scanned certification card images (front/back) will be
  /// included on a dedicated page after the summary.
  final bool includeCertificationCards;

  /// Creates PDF export options with the specified settings.
  ///
  /// Defaults to [PdfTemplate.detailed], [PdfPageSize.a4], and no
  /// certification cards.
  const PdfExportOptions({
    this.template = PdfTemplate.detailed,
    this.pageSize = PdfPageSize.a4,
    this.includeCertificationCards = false,
    this.includeVerificationAreas = false,
  });

  /// Creates a copy of this options object with the given fields replaced.
  PdfExportOptions copyWith({
    PdfTemplate? template,
    PdfPageSize? pageSize,
    bool? includeCertificationCards,
    bool? includeVerificationAreas,
  }) {
    return PdfExportOptions(
      template: template ?? this.template,
      pageSize: pageSize ?? this.pageSize,
      includeCertificationCards:
          includeCertificationCards ?? this.includeCertificationCards,
      includeVerificationAreas:
          includeVerificationAreas ?? this.includeVerificationAreas,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfExportOptions &&
        other.template == template &&
        other.pageSize == pageSize &&
        other.includeCertificationCards == includeCertificationCards &&
        other.includeVerificationAreas == includeVerificationAreas;
  }

  @override
  int get hashCode {
    return Object.hash(
      template,
      pageSize,
      includeCertificationCards,
      includeVerificationAreas,
    );
  }

  @override
  String toString() {
    return 'PdfExportOptions('
        'template: $template, '
        'pageSize: $pageSize, '
        'includeCertificationCards: $includeCertificationCards, '
        'includeVerificationAreas: $includeVerificationAreas)';
  }
}
