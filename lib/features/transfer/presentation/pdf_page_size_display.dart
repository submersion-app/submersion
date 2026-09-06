import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label + dimensions for [PdfPageSize] in the PDF export dialog.
/// The enum's own `displayName` / `description` stay English (issue #1608).
extension PdfPageSizeDisplay on PdfPageSize {
  String localizedName(AppLocalizations l10n) => switch (this) {
    PdfPageSize.a4 => l10n.enum_pdfPageSize_a4,
    PdfPageSize.letter => l10n.enum_pdfPageSize_letter,
  };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
    PdfPageSize.a4 => l10n.enum_pdfPageSize_a4_description,
    PdfPageSize.letter => l10n.enum_pdfPageSize_letter_description,
  };
}
