import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/pdf_text.dart';

/// #2252: every logbook template printed English whatever the app language.
/// Each template now prints the language its [PdfLocalization] names.
///
/// Expected strings are read from the generated French localizations rather
/// than spelled out, so a reworded translation does not break this test; the
/// `isNot(english)` guards make sure the assertion is not satisfied by an
/// untranslated key falling back to English.
void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));
  final french = PdfLocalization.forLanguageCode('fr');

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  final dives = [
    Dive(
      id: 'd1',
      diveNumber: 12,
      dateTime: DateTime(2026, 8, 17, 11, 7),
      runtime: const Duration(minutes: 45),
      maxDepth: 24.0,
      avgDepth: 14.0,
      waterTemp: 26.0,
      visibility: Visibility.good,
      currentStrength: CurrentStrength.strong,
      waterType: WaterType.salt,
      tanks: const [
        DiveTank(
          id: 't1',
          startPressure: 200,
          endPressure: 60,
          material: TankMaterial.aluminum,
        ),
      ],
    ),
  ];

  final diver = Diver(
    id: 'v1',
    name: 'Ana',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
  final certifications = [
    Certification(
      id: 'c1',
      name: 'Open Water Diver',
      agency: CertificationAgency.padi,
      cardNumber: 'CARD-1',
      issueDate: DateTime(2018, 6, 12),
      createdAt: DateTime(2018, 6, 12),
      updatedAt: DateTime(2018, 6, 12),
    ),
  ];

  Future<String> render(
    PdfTemplateBuilder builder, {
    PdfLocalization? localization,
  }) async => pdfVisibleText(
    await builder.buildPdf(
      dives: dives,
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
      diver: diver,
      certifications: certifications,
      localization: localization,
    ),
  );

  /// Asserts [text] carries the French [frValue] and not the English one.
  void expectFrench(String text, String frValue, String enValue) {
    expect(frValue, isNot(enValue), reason: 'untranslated key');
    expect(text, contains(frValue));
    expect(text, isNot(contains(enValue)));
  }

  test('Simple prints its summary and table headers in French', () async {
    final text = await render(PdfTemplateSimple(), localization: french);

    expectFrench(text, fr.pdf_totalDives, en.pdf_totalDives);
    expectFrench(text, fr.pdf_deepestDive, en.pdf_deepestDive);
    expectFrench(text, fr.pdf_firstDive, en.pdf_firstDive);
    // Spelled the same in both languages, so only presence is checked.
    expect(text, contains(fr.pdf_certifications));
    expect(text, contains(fr.pdf_columnDepth));
  });

  test('Detailed prints labels and enum values in French', () async {
    final text = await render(PdfTemplateDetailed(), localization: french);

    expectFrench(text, fr.pdf_maxDepth, en.pdf_maxDepth);
    expectFrench(text, fr.pdf_diverProfile, en.pdf_diverProfile);
    expectFrench(
      text,
      fr.enum_currentStrength_strong,
      CurrentStrength.strong.displayName,
    );
    expect(text, contains(fr.pdf_sectionConditions.toUpperCase()));
  });

  test('PADI prints its cover and dive entries in French', () async {
    final text = await render(PdfTemplatePadi(), localization: french);

    expectFrench(text, fr.pdf_loggedDives, en.pdf_loggedDives);
    expect(text, contains(fr.pdf_diveNumber('12')));
  });

  test('NAUI prints its cover and dive entries in French', () async {
    final text = await render(PdfTemplateNaui(), localization: french);

    expectFrench(text, fr.pdf_statHours, en.pdf_statHours);
    expect(text, contains(fr.pdf_diveDataHeading));
  });

  test('no localization still prints English', () async {
    final text = await render(PdfTemplateSimple());

    expect(text, contains('Total Dives'));
  });

  group('right-to-left and CJK languages', () {
    setUp(
      () => PdfFonts.debugScriptFontLoader = (_, {required bold}) async => null,
    );
    tearDown(() => PdfFonts.debugScriptFontLoader = null);

    for (final code in ['ar', 'he', 'zh']) {
      for (final builder in <PdfTemplateBuilder>[
        PdfTemplateSimple(),
        PdfTemplateDetailed(),
        PdfTemplatePadi(),
        PdfTemplateNaui(),
      ]) {
        test('${builder.templateType.name} renders in $code', () async {
          // Helvetica has none of these glyphs, so the pdf package prints a
          // warning per character; keep the test log readable.
          final bytes = await runZoned<Future<List<int>>>(
            () => builder.buildPdf(
              dives: dives,
              pageSize: PdfPageSize.a4,
              dates: dates,
              units: units,
              diver: diver,
              certifications: certifications,
              localization: PdfLocalization.forLanguageCode(code),
            ),
            zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
          );

          expect(pdfPageCount(bytes), greaterThan(0));
        });
      }
    }
  });

  test('built-in dive types print their localized name', () async {
    final bytes = await PdfTemplateDetailed().buildPdf(
      dives: [
        Dive(
          id: 't1',
          diveNumber: 1,
          dateTime: DateTime(2026, 8, 17),
          diveTypeIds: const ['recreational'],
        ),
      ],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
      localization: french,
    );

    expect(fr.diveType_builtin_recreational, isNot('Recreational'));
    expect(pdfVisibleText(bytes), contains(fr.diveType_builtin_recreational));
  });

  test('letter-spacing is dropped for a joining script', () {
    // Spaced-out Arabic letters no longer join into words.
    expect(pdfTracking('PROFIL', 1), 1);
    expect(pdfTracking('ملف الغوصة', 1), 0);
    expect(pdfTracking('Ras Mohammed غرب', 2), 0);
  });
}
