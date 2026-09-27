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

  /// Replaces the script font download in tests, which must not reach the
  /// network. Returning null means "this weight is not available".
  @visibleForTesting
  static Future<pw.Font?> Function(String languageCode, {required bool bold})?
  debugScriptFontLoader;

  /// Script fonts by language code. Only a complete load is kept: a
  /// download that failed (offline) is tried again by the next export, so
  /// one offline export does not cost the rest of the session its script.
  final Map<String, ({pw.Font regular, pw.Font? bold})> _scriptFonts = {};

  /// The theme for a PDF printed in [localization]'s language (#2252).
  ///
  /// Roboto (or Helvetica, when [initialize] has not run or failed) covers
  /// Latin, Greek and Cyrillic, so those languages keep today's theme exactly.
  /// Arabic, Hebrew and Chinese get a font covering both that script and
  /// Latin as the BASE font, with the Latin font as a last-resort fallback.
  /// Base rather than fallback matters: the pdf package hands every glyph
  /// its base font lacks to the fallback one character at a time, and
  /// characters laid out one at a time neither join (Arabic) nor keep their
  /// order inside a mixed right-to-left line (Latin site names, units). Only those three languages trigger a download. Deliberately does
  /// not call [initialize]: whether the Latin font is embedded stays the
  /// caller's decision, as it was before.
  ///
  /// Never throws. A script font that cannot be loaded (no network) leaves
  /// the Latin theme, which prints the characters it can, as before.
  Future<pw.ThemeData> themeFor(PdfLocalization localization) async {
    final script = await _scriptFontsFor(localization.languageCode);
    if (script == null) {
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
      );
    }
    final scriptBold = script.bold ?? script.regular;
    return pw.ThemeData.withFont(
      base: script.regular,
      bold: scriptBold,
      italic: script.regular,
      boldItalic: scriptBold,
      fontFallback: [regular],
    );
  }

  Future<({pw.Font regular, pw.Font? bold})?> _scriptFontsFor(
    String languageCode,
  ) async {
    final load = switch (languageCode) {
      // Cairo and Heebo carry Latin glyphs beside their script (Heebo's
      // Latin is Roboto's), so site names and units never reach the
      // per-character fallback, which lays Latin out backwards on a
      // right-to-left page. Noto Sans SC covers Latin itself.
      'ar' => (
        regular: PdfGoogleFonts.cairoRegular,
        bold: PdfGoogleFonts.cairoBold,
      ),
      'he' => (
        regular: PdfGoogleFonts.heeboRegular,
        bold: PdfGoogleFonts.heeboBold,
      ),
      'zh' => (
        regular: PdfGoogleFonts.notoSansSCRegular,
        bold: PdfGoogleFonts.notoSansSCBold,
      ),
      _ => null,
    };
    if (load == null) return null;
    final cached = _scriptFonts[languageCode];
    if (cached != null) return cached;

    Future<pw.Font?> fetch({required bool bold}) async {
      try {
        final override = debugScriptFontLoader;
        if (override != null) return await override(languageCode, bold: bold);
        return await (bold ? load.bold : load.regular)();
      } catch (_) {
        return null;
      }
    }

    final regularFont = await fetch(bold: false);
    if (regularFont == null) return null;
    final boldFont = await fetch(bold: true);
    final fonts = (regular: regularFont, bold: boldFont);
    // Without the bold weight the document still prints, in the regular one;
    // leaving it uncached lets the next export try for the bold again.
    if (boldFont != null) _scriptFonts[languageCode] = fonts;
    return fonts;
  }

  /// Reset the font cache (useful for testing).
  void reset() {
    _regular = null;
    _bold = null;
    _italic = null;
    _boldItalic = null;
    _initialized = false;
    _scriptFonts.clear();
  }
}
