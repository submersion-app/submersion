import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// The reported bug: selecting "Detailed" produced a summary-sized card.
/// `_buildDiveEntry` rendered six fields and capped the notes at two lines, so
/// a dive's story was cut off mid-sentence. #1017 lists the fields a detailed
/// logbook is expected to carry.
void main() {
  const longNote =
      'Dropped in from Devil Ray at Casique. Stayed on surface while Jack '
      'tied DSMB to a rock on the bottom as a marker. Backed off 100 yards, '
      'performed tired diver tow via push technique. Snorkel was flooding so '
      'switched to regulator and finished the tow on the surface.';

  final dive = Dive(
    id: 'd1',
    diveNumber: 197,
    dateTime: DateTime(2026, 8, 17, 11, 7),
    entryTime: DateTime(2026, 8, 17, 11, 7),
    exitTime: DateTime(2026, 8, 17, 11, 33),
    runtime: const Duration(minutes: 26),
    surfaceInterval: const Duration(minutes: 72),
    maxDepth: 9.8,
    avgDepth: 6.1,
    waterTemp: 28.0,
    airTemp: 31.0,
    visibilityMeters: 15.0,
    waterType: WaterType.salt,
    entryMethod: EntryMethod.boat,
    rating: 4,
    weightAmount: 4.0,
    diveComputerModel: 'Perdix 2',
    notes: longNote,
    tanks: const [
      DiveTank(
        id: 't1',
        name: 'AL80',
        volume: 11.1,
        startPressure: 192,
        endPressure: 119,
        material: TankMaterial.aluminum,
      ),
      DiveTank(
        id: 't2',
        name: 'Deco 50',
        volume: 11.1,
        startPressure: 200,
        endPressure: 180,
        gasMix: GasMix(o2: 50),
      ),
    ],
  );

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  final secondDive = dive.copyWith(id: 'd2', diveNumber: 198);
  final thirdDive = dive.copyWith(id: 'd3', diveNumber: 199);

  Future<List<int>> render(
    Dive d, {
    List<Dive> extra = const [],
    Map<String, PdfProfileSeries>? profiles,
    bool verification = false,
  }) => PdfTemplateDetailed().buildPdf(
    dives: [d, ...extra],
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: units,
    profiles: profiles,
    includeVerificationAreas: verification,
  );

  group('the reported bug', () {
    test('renders the notes in full, without truncation', () async {
      final text = pdfVisibleText(await render(dive));
      expect(
        text,
        contains('finished the tow on the surface'),
        reason: 'notes were capped at maxLines 2, cutting the story off',
      );
    });

    test('renders every cylinder, not only the first', () async {
      final text = pdfVisibleText(await render(dive));
      expect(text, contains('AL80'));
      expect(
        text,
        contains('Deco 50'),
        reason: 'only dive.tanks.first was rendered',
      );
      expect(text, contains('EAN50'), reason: 'the deco gas mix');
    });
  });

  group('field coverage from #1017', () {
    late String text;

    setUpAll(() async {
      text = pdfVisibleText(await render(dive));
    });

    test('renders average depth alongside max depth', () {
      expect(text, contains('9.8m'));
      expect(text, contains('6.1m'));
    });

    test('renders air temperature as well as water temperature', () {
      expect(text, contains('28°C'));
      expect(text, contains('31°C'));
    });

    test('renders the surface interval', () {
      expect(text, contains('Surface Interval'));
    });

    test('renders entry and exit times', () {
      expect(text, contains('11:07'));
      expect(text, contains('11:33'));
    });

    test('renders visibility, water type and entry method', () {
      expect(text, contains('15m'));
      expect(text, contains(WaterType.salt.displayName));
      expect(text, contains(EntryMethod.boat.displayName));
    });

    test('renders weight and the dive computer', () {
      // UnitFormatter.formatWeight spaces the unit, unlike formatDepth.
      expect(text, contains('4.0 kg'));
      expect(text, contains('Perdix 2'));
    });

    test('renders the rating', () {
      expect(text, contains('****'));
    });
  });

  group('layout', () {
    test('puts one dive on each page', () async {
      final onePage = pdfPageCount(await render(dive));
      final threePages = pdfPageCount(
        await render(dive, extra: [secondDive, thirdDive]),
      );
      expect(
        threePages - onePage,
        2,
        reason: 'two extra dives must add exactly two pages',
      );
    });

    test('omits the profile section when the dive has no samples', () async {
      final text = pdfVisibleText(await render(dive));
      expect(
        text,
        isNot(contains('Depth Profile')),
        reason: 'a manually logged dive should not print an empty chart frame',
      );
    });

    test('renders the profile chart when samples are supplied', () async {
      final text = pdfVisibleText(
        await render(
          dive,
          profiles: {
            'd1': PdfProfileSeries.downsampled([
              const DiveProfilePoint(timestamp: 0, depth: 0),
              const DiveProfilePoint(timestamp: 600, depth: 9.8),
              const DiveProfilePoint(timestamp: 1560, depth: 0),
            ]),
          },
        ),
      );
      expect(text, contains('Depth Profile'));
    });

    test('omits verification areas unless requested', () async {
      expect(
        pdfVisibleText(await render(dive)),
        isNot(contains('Official Stamp')),
      );
      expect(
        pdfVisibleText(await render(dive, verification: true)),
        contains('Official Stamp'),
      );
    });

    test('omits groups a sparse dive has no data for', () async {
      final sparse = Dive(
        id: 'bare',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1, 9),
        maxDepth: 12.0,
      );
      final text = pdfVisibleText(await render(sparse));

      expect(text, contains('12.0m'));
      expect(text, isNot(contains('Surface Interval')));
      expect(text, isNot(contains('Cylinders')));
      expect(text, isNot(contains('Notes')));
    });
  });
}
