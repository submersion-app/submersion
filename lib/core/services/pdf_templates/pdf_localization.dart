import 'dart:ui' show Locale;

import 'package:intl/intl.dart' show Bidi;
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/l10n/arb/app_localizations.dart';

/// The language a generated PDF prints in (#2252).
///
/// A PDF is built with no [BuildContext], so the caller resolves the language
/// (the diver's pick in the export sheet, or the app language for exports
/// that offer no choice) and hands the builder one of these. It carries the
/// strings, and the text direction every page must use so Arabic and Hebrew
/// lay out right to left and get their letters shaped.
class PdfLocalization {
  PdfLocalization._(this.languageCode, this.l10n);

  /// Localization for [code], a language code with or without a region
  /// suffix (`fr`, `pt_BR`, `zh-Hans`).
  ///
  /// Anything the app does not ship, including null, falls back to English,
  /// the same resolution MaterialApp applies to the UI.
  factory PdfLocalization.forLanguageCode(String? code) {
    final language = (code ?? 'en').split(RegExp('[-_]')).first.toLowerCase();
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == language,
    );
    final resolved = supported ? language : 'en';
    return PdfLocalization._(
      resolved,
      lookupAppLocalizations(Locale(resolved)),
    );
  }

  factory PdfLocalization.english() => PdfLocalization.forLanguageCode('en');

  /// A language code the app ships, such as `fr`.
  final String languageCode;

  /// The strings for [languageCode].
  final AppLocalizations l10n;

  bool get isRtl => Bidi.isRtlLanguage(languageCode);

  /// Set on every page. The `pdf` package only shapes Arabic letters on a
  /// right-to-left page, so this is what makes Arabic readable at all.
  pw.TextDirection get textDirection =>
      isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
}
