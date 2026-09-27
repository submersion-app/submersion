import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// #2252: a PDF export printed English whatever the app language was. The
/// language a PDF prints in is now carried by a [PdfLocalization], and the
/// fonts a non-Latin script needs are added as a fallback.
void main() {
  group('PdfLocalization.forLanguageCode', () {
    test('unsupported and null codes fall back to English', () {
      expect(PdfLocalization.forLanguageCode(null).languageCode, 'en');
      expect(PdfLocalization.forLanguageCode('xx').languageCode, 'en');
    });

    test('a region suffix resolves to its language', () {
      expect(PdfLocalization.forLanguageCode('pt_BR').languageCode, 'pt');
      expect(PdfLocalization.forLanguageCode('zh-Hans').languageCode, 'zh');
    });

    test('reads the strings of the requested language', () {
      expect(PdfLocalization.forLanguageCode('fr').l10n.localeName, 'fr');
      expect(PdfLocalization.english().l10n.localeName, 'en');
    });

    test('Arabic and Hebrew lay out right to left', () {
      expect(
        PdfLocalization.forLanguageCode('ar').textDirection,
        pw.TextDirection.rtl,
      );
      expect(PdfLocalization.forLanguageCode('he').isRtl, isTrue);
      expect(
        PdfLocalization.forLanguageCode('fr').textDirection,
        pw.TextDirection.ltr,
      );
    });
  });

  group('PdfFonts.themeFor', () {
    tearDown(() => PdfFonts.debugFallbackLoader = null);

    test('asks for a fallback font only for non-Latin scripts', () async {
      final requested = <String>[];
      PdfFonts.debugFallbackLoader = (code) async {
        requested.add(code);
        return null;
      };

      for (final code in ['en', 'fr', 'de', 'hu', 'zh', 'ar', 'he']) {
        await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode(code));
      }

      expect(requested, ['zh', 'ar', 'he']);
    });

    test('a failing fallback download still yields a theme', () async {
      PdfFonts.debugFallbackLoader = (_) async => throw Exception('offline');

      final theme = await PdfFonts.instance.themeFor(
        PdfLocalization.forLanguageCode('ar'),
      );

      expect(theme.defaultTextStyle.fontFallback, isEmpty);
    });
  });

  group('PdfExportOptions.languageCode', () {
    test('survives copyWith and takes part in equality', () {
      const french = PdfExportOptions(languageCode: 'fr');

      expect(french.copyWith().languageCode, 'fr');
      expect(french.copyWith(languageCode: 'de').languageCode, 'de');
      expect(french, isNot(const PdfExportOptions(languageCode: 'de')));
      expect(french, const PdfExportOptions(languageCode: 'fr'));
      expect(const PdfExportOptions().languageCode, isNull);
    });
  });
}
