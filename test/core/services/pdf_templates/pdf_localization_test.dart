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
    tearDown(() {
      PdfFonts.debugScriptFontLoader = null;
      PdfFonts.instance.reset();
    });

    test('a failed download is retried by the next export', () async {
      // An export made offline must not leave every later export in the
      // session without the script font.
      PdfFonts.debugScriptFontLoader = (_, {required bold}) async =>
          throw Exception('offline');
      await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('ar'));

      final arabic = pw.Font.courier();
      PdfFonts.debugScriptFontLoader = (_, {required bold}) async => arabic;
      final theme = await PdfFonts.instance.themeFor(
        PdfLocalization.forLanguageCode('ar'),
      );

      expect(theme.defaultTextStyle.fontNormal, same(arabic));
    });

    test('a loaded script font is fetched once per session', () async {
      var fetches = 0;
      PdfFonts.debugScriptFontLoader = (_, {required bold}) async {
        fetches++;
        return pw.Font.courier();
      };

      await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('zh'));
      await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('zh'));

      expect(fetches, 2, reason: 'regular and bold, once each');
    });

    test('asks for a script font only for non-Latin scripts', () async {
      final requested = <String>[];
      PdfFonts.debugScriptFontLoader = (code, {required bold}) async {
        requested.add(code);
        return null;
      };

      for (final code in ['en', 'fr', 'de', 'hu', 'zh', 'ar', 'he']) {
        await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode(code));
      }

      expect(requested, ['zh', 'ar', 'he']);
    });

    test(
      'a script font is the base font, the Latin font its fallback',
      () async {
        // Arabic letters only join and reorder when a whole word reaches one
        // font; a fallback font receives them one character at a time.
        final arabic = pw.Font.courier();
        final arabicBold = pw.Font.courierBold();
        PdfFonts.debugScriptFontLoader = (_, {required bold}) async =>
            bold ? arabicBold : arabic;

        final theme = await PdfFonts.instance.themeFor(
          PdfLocalization.forLanguageCode('ar'),
        );

        expect(theme.defaultTextStyle.fontNormal, same(arabic));
        expect(theme.defaultTextStyle.fontBold, same(arabicBold));
        final fallback = theme.defaultTextStyle.fontFallback;
        expect(fallback, hasLength(1));
        expect(fallback.single.fontName, PdfFonts.instance.regular.fontName);
      },
    );

    test('a partial Roboto load falls back to Helvetica throughout', () async {
      // Regular arrives, then bold fails: the theme must not mix a Roboto
      // body with Helvetica headings.
      PdfFonts.debugLatinFontLoader = (weight) async =>
          weight == 'regular' ? pw.Font.courier() : throw Exception('offline');
      addTearDown(() => PdfFonts.debugLatinFontLoader = null);

      await PdfFonts.instance.initialize();
      final theme = await PdfFonts.instance.themeFor(
        PdfLocalization.forLanguageCode('fr'),
      );

      expect(PdfFonts.instance.isInitialized, isFalse);
      expect(theme.defaultTextStyle.fontNormal?.fontName, 'Helvetica');
      expect(theme.defaultTextStyle.fontBold?.fontName, 'Helvetica-Bold');
    });

    test('a failing script font download still yields a theme', () async {
      PdfFonts.debugScriptFontLoader = (_, {required bold}) async =>
          throw Exception('offline');

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
      expect(
        french.hashCode,
        const PdfExportOptions(languageCode: 'fr').hashCode,
      );
      expect(french.toString(), contains('languageCode: fr'));
    });
  });
}
