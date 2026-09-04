import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
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
    UnitFormatter unitFormatter = units,
  }) => PdfTemplateDetailed().buildPdf(
    dives: [d, ...extra],
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: unitFormatter,
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

  group('review findings', () {
    test('falls back to Dive.profile when no series map is supplied', () async {
      // getDivesByIds hydrates Dive.profile, so the bulk and single-dive
      // export routes have samples even though they pass no profiles map.
      final withSamples = dive.copyWith(
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 600, depth: 9.8),
          const DiveProfilePoint(timestamp: 1560, depth: 0),
        ],
      );

      final text = pdfVisibleText(await render(withSamples));
      expect(
        text,
        contains('Depth Profile'),
        reason: 'the chart was omitted on every bulk Detailed export',
      );
    });

    test('renders gas consumption, which #1017 asks for by name', () async {
      // SAC and RMV are separate quantities since #1322, so the default
      // `both` display prints a row for each rather than one relabelled
      // value.
      final text = pdfVisibleText(await render(dive));
      expect(text, contains('SAC'));
      expect(text, contains('RMV'));
    });

    test('follows the gas-consumption display preference', () async {
      const sacOnly = UnitFormatter(
        AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.sac),
      );
      final text = pdfVisibleText(await render(dive, unitFormatter: sacOnly));
      expect(text, contains('SAC'));
      expect(
        text,
        isNot(contains('RMV')),
        reason: 'a SAC-only diver asked not to see the volume lane',
      );
    });

    test('prints SAC when an RMV-only diver has no cylinder volumes', () async {
      // Issue #386: dropping consumption from the page entirely is worse
      // than showing the lane the dive can supply. The page has no room for
      // the tappable volume hint the detail page shows in its place.
      const rmvOnly = UnitFormatter(
        AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
      );
      // Built rather than copyWith'd: `volume: null` reads as "unchanged".
      final noVolumes = dive.copyWith(
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'AL80',
            startPressure: 192,
            endPressure: 119,
          ),
        ],
      );

      final text = pdfVisibleText(
        await render(noVolumes, unitFormatter: rmvOnly),
      );
      expect(text, contains('SAC'));
    });

    test('renders the recorded weather fields', () async {
      final windy = dive.copyWith(
        windSpeed: 8.0,
        cloudCover: CloudCover.partlyCloudy,
        humidity: 74.0,
        swellHeight: 1.5,
        weatherDescription: 'Squalls offshore',
      );

      final text = pdfVisibleText(await render(windy));
      expect(text, contains('Squalls offshore'));
      expect(text, contains('Wind'));
      expect(text, contains('74%'));
      expect(text, contains('Swell'));
    });

    test('renders custom fields, which the legacy layout carried', () async {
      final tagged = dive.copyWith(
        customFields: const [
          DiveCustomField(id: 'f1', key: 'Boat', value: 'Devil Ray'),
        ],
      );

      final text = pdfVisibleText(await render(tagged));
      expect(text, contains('Boat'));
      expect(text, contains('Devil Ray'));
    });

    test('renders a cylinder with only one recorded pressure', () async {
      final partial = dive.copyWith(
        tanks: const [DiveTank(id: 't1', name: 'AL80', startPressure: 200)],
      );

      final text = pdfVisibleText(await render(partial));
      expect(
        text,
        contains('200'),
        reason: 'a half-filled pressure pair must not suppress the range',
      );
    });

    test(
      'prefers the multi-entry weight list over the legacy scalar',
      () async {
        final weighted = dive.copyWith(
          weightAmount: 4.0,
          weights: [
            const DiveWeight(
              id: 'w1',
              diveId: 'd1',
              weightType: WeightType.integrated,
              amountKg: 3.0,
            ),
            const DiveWeight(
              id: 'w2',
              diveId: 'd1',
              weightType: WeightType.integrated,
              amountKg: 2.5,
            ),
          ],
        );

        final text = pdfVisibleText(await render(weighted));
        expect(text, contains('5.5 kg'));
        expect(text, isNot(contains('4.0 kg')));
      },
    );

    test('omits the weather group when nothing was recorded', () async {
      final text = pdfVisibleText(await render(dive));
      expect(text, isNot(contains('Precipitation')));
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

  /// #1017 lists marine life among the groups a detailed logbook carries, and
  /// `Dive.sightings` is already hydrated by the export paths, but the rebuilt
  /// page went straight from the technical group to the notes.
  group('marine life', () {
    final spotted = dive.copyWith(
      sightings: const [
        MarineSighting(
          id: 's1',
          speciesId: 'sp1',
          speciesName: 'Green Sea Turtle',
          count: 2,
          notes: 'Resting under a ledge',
        ),
        MarineSighting(
          id: 's2',
          speciesId: 'sp2',
          speciesName: 'Spotted Eagle Ray',
        ),
      ],
    );

    test('renders the species that were recorded', () async {
      final text = pdfVisibleText(await render(spotted));

      expect(text, contains('MARINE LIFE'));
      expect(text, contains('Green Sea Turtle'));
      expect(text, contains('Spotted Eagle Ray'));
    });

    test('renders a count only when more than one was seen', () async {
      final text = pdfVisibleText(await render(spotted));

      expect(text, contains('x2'), reason: 'two turtles');
      expect(
        text,
        isNot(contains('x1')),
        reason: 'a single animal reads as noise with a count',
      );
    });

    test('renders the per-sighting notes', () async {
      expect(
        pdfVisibleText(await render(spotted)),
        contains('Resting under a ledge'),
      );
    });

    test('omits the group when nothing was recorded', () async {
      expect(pdfVisibleText(await render(dive)), isNot(contains('MARINE')));
    });
  });
}
