import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// Provides fonts for PDF generation with proper Unicode support.
///
/// Uses Google Fonts (Roboto) via the printing package, which downloads
/// and caches fonts locally. This eliminates the Helvetica Unicode warnings
/// and enables proper rendering of special characters.
class PdfFonts {
  static PdfFonts? _instance;
  static PdfFonts get instance => _instance ??= PdfFonts._();

  PdfFonts._();

  pw.Font? _regular;
  pw.Font? _bold;
  pw.Font? _italic;
  pw.Font? _boldItalic;
  bool _initialized = false;

  /// Whether fonts have been loaded.
  bool get isInitialized => _initialized;

  /// Regular weight font.
  pw.Font get regular => _regular ?? pw.Font.helvetica();

  /// Bold weight font.
  pw.Font get bold => _bold ?? pw.Font.helveticaBold();

  /// Italic font.
  pw.Font get italic => _italic ?? pw.Font.helveticaOblique();

  /// Bold italic font.
  pw.Font get boldItalic => _boldItalic ?? pw.Font.helveticaBoldOblique();

  /// Load fonts asynchronously. Call this before generating PDFs.
  ///
  /// Uses PdfGoogleFonts which downloads and caches Roboto font variants.
  /// After first load, fonts are served from local cache.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load Roboto font variants using PdfGoogleFonts
      // These are downloaded and cached automatically
      _regular = await PdfGoogleFonts.robotoRegular();
      _bold = await PdfGoogleFonts.robotoBold();
      _italic = await PdfGoogleFonts.robotoItalic();
      _boldItalic = await PdfGoogleFonts.robotoBoldItalic();

      _initialized = true;
    } catch (e) {
      // Fall back to Helvetica if font loading fails (e.g., no network)
      _initialized = false;
    }
  }

  /// Create a PDF theme with the loaded fonts.
  ///
  /// Use this when creating a pw.Document to ensure consistent font usage
  /// across all templates.
  pw.ThemeData get theme {
    if (!_initialized) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      );
    }

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
  }

  /// Replaces the fallback font download in tests, which must not reach the
  /// network. Returning null means "no fallback font available".
  @visibleForTesting
  static Future<pw.Font?> Function(String languageCode)? debugFallbackLoader;

  /// Fallback fonts by language code, loaded once per run. A failed load is
  /// cached as null so an offline export does not retry on every page.
  final Map<String, pw.Font?> _fallbacks = {};

  /// The theme for a PDF printed in [localization]'s language (#2252).
  ///
  /// Roboto (or Helvetica, when [initialize] has not run or failed) covers
  /// Latin, Greek and Cyrillic but has no Arabic, Hebrew or Chinese glyphs,
  /// so those languages get a Noto font as a fallback for every glyph the
  /// base font lacks. Only those three trigger a download. Deliberately does
  /// not call [initialize]: whether the base font is embedded stays the
  /// caller's decision, as it was before.
  ///
  /// Never throws. A fallback that cannot be loaded (no network) leaves the
  /// theme without one, which prints the base font exactly as before.
  Future<pw.ThemeData> themeFor(PdfLocalization localization) async {
    final fallback = await _fallbackFor(localization.languageCode);
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: [?fallback],
    );
  }

  Future<pw.Font?> _fallbackFor(String languageCode) async {
    final load = switch (languageCode) {
      'ar' => PdfGoogleFonts.notoSansArabicRegular,
      'he' => PdfGoogleFonts.notoSansHebrewRegular,
      'zh' => PdfGoogleFonts.notoSansSCRegular,
      _ => null,
    };
    if (load == null) return null;
    if (_fallbacks.containsKey(languageCode)) return _fallbacks[languageCode];

    pw.Font? font;
    try {
      final override = debugFallbackLoader;
      font = override != null ? await override(languageCode) : await load();
    } catch (_) {
      font = null;
    }
    // A test override is not cached, so each test sees its own loader.
    if (debugFallbackLoader == null) _fallbacks[languageCode] = font;
    return font;
  }

  /// Reset the font cache (useful for testing).
  void reset() {
    _regular = null;
    _bold = null;
    _italic = null;
    _boldItalic = null;
    _initialized = false;
    _fallbacks.clear();
  }
}
