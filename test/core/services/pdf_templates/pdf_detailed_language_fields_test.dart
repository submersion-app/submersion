import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/pdf_text.dart';

/// #2252: every optional field of the Detailed dive page, and the shared
/// signature and certification blocks, print their labels and enum values in
/// the PDF's language, not English. A sparse dive never reaches most of these
/// branches, so this one fills them all.
void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final french = PdfLocalization.forLanguageCode('fr');
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());
  final epoch = DateTime(2026);

  // A valid 1x1 transparent PNG, so the PDF image decoder has real bytes.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
    'hKmMIQAAAABJRU5ErkJggg==',
  );

  final dive = Dive(
    id: 'd1',
    diveNumber: 7,
    dateTime: DateTime(2026, 8, 17, 9),
    runtime: const Duration(minutes: 50),
    surfaceInterval: const Duration(minutes: 35),
    maxDepth: 30,
    exitMethod: EntryMethod.ladder,
    weightAmount: 6,
    weightType: WeightType.integrated,
    diveMode: DiveMode.ccr,
    gradientFactorLow: 30,
    gradientFactorHigh: 70,
    setpointHigh: 1.3,
    windDirection: CurrentDirection.west,
    precipitation: Precipitation.drizzle,
    buddy: 'Marie',
    diveCenter: DiveCenter(
      id: 'c1',
      name: 'Blue Lagoon',
      createdAt: epoch,
      updatedAt: epoch,
    ),
  );

  final signatures = {
    'd1': [
      Signature(
        id: 's1',
        diveId: 'd1',
        signerName: 'Luc',
        signedAt: epoch,
        type: SignatureType.buddy,
      ),
    ],
  };

  final certifications = [
    Certification(
      id: 'k1',
      name: 'Advanced',
      agency: CertificationAgency.padi.name,
      photoFront: png,
      photoBack: png,
      createdAt: epoch,
      updatedAt: epoch,
    ),
  ];

  late String text;

  setUpAll(() async {
    text = pdfVisibleText(
      await PdfTemplateDetailed().buildPdf(
        dives: [dive],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
        diveSignatures: signatures,
        certifications: certifications,
        includeVerificationAreas: true,
        localization: french,
      ),
    );
  });

  // The pdf package lays words out on any whitespace, so a non-breaking space
  // in a translation reads back as a plain one.
  void expectPrinted(String value) =>
      expect(text, contains(value.replaceAll(' ', ' ')));

  test('conditions, equipment and weather enums print in French', () {
    expectPrinted(fr.enum_entryMethod_ladder);
    expectPrinted(fr.pdf_exit);
    expectPrinted(fr.pdf_weightType);
    expectPrinted(fr.enum_currentDirection_west);
    expectPrinted(fr.pdf_windDirection);
    expectPrinted(fr.enum_precipitation_drizzle);
  });

  test('technical fields print in French', () {
    expectPrinted(fr.pdf_diveMode);
    expectPrinted(fr.pdf_gradientFactors);
    expectPrinted(fr.pdf_setpoint);
  });

  test('team fields and a sub-hour surface interval print in French', () {
    expectPrinted(fr.pdf_buddy);
    expectPrinted(fr.pdf_diveCenter);
    expectPrinted(fr.pdf_minutesShort('35'));
  });

  test('signature, verification and card blocks print in French', () {
    expectPrinted(fr.pdf_signerBuddy);
    expectPrinted(fr.pdf_signaturePlaceholder);
    expectPrinted(fr.pdf_instructorSignature);
    expectPrinted(fr.pdf_officialStamp);
    expectPrinted(fr.pdf_cardFront);
    expectPrinted(fr.pdf_cardBack);
  });

  test('an empty logbook says so in French', () async {
    final empty = pdfVisibleText(
      await PdfTemplateSimple().buildPdf(
        dives: const [],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
        localization: french,
      ),
    );

    expect(empty, contains(fr.pdf_noDivesToDisplay));
  });
}
