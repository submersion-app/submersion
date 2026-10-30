import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_labels.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final l10n = AppLocalizationsEn();
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
  const iso = UnitFormatter(
    AppSettings(dateFormat: DateFormatPreference.yyyymmdd),
  );

  int at(int y, int m) => DateTime.utc(y, m, 10).millisecondsSinceEpoch;

  DiveScrubberEntry dive({
    int ts = 0,
    int? number,
    String? site,
    double? depth,
    int? minutes,
    int? rating,
  }) => DiveScrubberEntry(
    id: 'x',
    sortTimestamp: ts,
    diveNumber: number,
    siteName: site,
    maxDepth: depth,
    bottomTime: minutes == null ? null : Duration(minutes: minutes),
    rating: rating,
  );

  String value(DiveScrubberEntry e, DiveSortField f, [UnitFormatter? u]) =>
      diveScrubberValue(e, f, units: u ?? metric, l10n: l10n);

  List<DiveScrubberSlot> slotsOf(List<DiveScrubberEntry> entries) => [
    for (final (i, e) in entries.indexed)
      DiveScrubberSlot(entry: e, entryIndex: i),
  ];

  group('value', () {
    test('the sort value alone for every sort', () {
      final d = dive(
        ts: at(2024, 3),
        number: 412,
        site: 'Blue Hole',
        depth: 32,
        minutes: 48,
        rating: 4,
      );
      expect(value(d, DiveSortField.date), 'Mar 2024');
      expect(value(d, DiveSortField.diveNumber), '#412');
      expect(value(d, DiveSortField.site), 'Blue Hole');
      expect(value(d, DiveSortField.depth), '32m');
      expect(value(d, DiveSortField.bottomTime), '48 min');
      expect(value(d, DiveSortField.rating), '4★');
    });

    test('depth follows the diver unit', () {
      expect(value(dive(depth: 30), DiveSortField.depth, imperial), '98ft');
    });

    test('date follows the diver date preference', () {
      expect(value(dive(ts: at(2024, 3)), DiveSortField.date, iso), '2024-03');
    });

    test('missing values fall back', () {
      final d = dive();
      expect(value(d, DiveSortField.site), 'Unknown Site');
      expect(value(d, DiveSortField.diveNumber), '--');
      expect(value(d, DiveSortField.depth), '--');
      expect(value(d, DiveSortField.bottomTime), '--');
      expect(value(d, DiveSortField.rating), 'Unrated');
    });
  });

  group('markers', () {
    const asc = SortDirection.ascending;
    const desc = SortDirection.descending;

    List<ScrubberMarker> markers(
      List<DiveScrubberEntry> entries,
      DiveSortField field,
      SortDirection direction, [
      UnitFormatter? units,
    ]) => diveScrubberMarkers(
      slotsOf(entries),
      field,
      direction: direction,
      units: units ?? metric,
      l10n: l10n,
    );

    int slotOf(List<ScrubberMarker> ms, String label) =>
        ms.singleWhere((m) => m.label == label).slot;

    test('years newest-first, at the last slot of each', () {
      final entries = [
        dive(ts: at(2025, 6)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2023, 9)),
      ];
      expect(markers(entries, DiveSortField.date, desc), const [
        ScrubberMarker(slot: 1, label: '2025'),
        ScrubberMarker(slot: 2, label: '2023'),
      ]);
    });

    test('newest-first: an April 2022 dive sits between 2023 and 2022', () {
      final entries = [
        dive(ts: at(2023, 8)),
        dive(ts: at(2023, 2)),
        dive(ts: at(2022, 12)),
        dive(ts: at(2022, 4)),
        dive(ts: at(2022, 1)),
        dive(ts: at(2021, 7)),
      ];
      final ms = markers(entries, DiveSortField.date, desc);
      expect(ms, const [
        ScrubberMarker(slot: 1, label: '2023'),
        ScrubberMarker(slot: 4, label: '2022'),
        ScrubberMarker(slot: 5, label: '2021'),
      ]);
      const april = 3;
      expect(slotOf(ms, '2023'), lessThan(april));
      expect(slotOf(ms, '2022'), greaterThan(april));
    });

    test('oldest-first: an April 2022 dive sits between 2022 and 2023', () {
      final entries = [
        dive(ts: at(2021, 7)),
        dive(ts: at(2022, 1)),
        dive(ts: at(2022, 4)),
        dive(ts: at(2022, 12)),
        dive(ts: at(2023, 2)),
        dive(ts: at(2023, 8)),
      ];
      final ms = markers(entries, DiveSortField.date, asc);
      expect(ms, const [
        ScrubberMarker(slot: 0, label: '2021'),
        ScrubberMarker(slot: 1, label: '2022'),
        ScrubberMarker(slot: 4, label: '2023'),
      ]);
      const april = 2;
      expect(slotOf(ms, '2022'), lessThan(april));
      expect(slotOf(ms, '2023'), greaterThan(april));
    });

    test('months when the dives span two calendar years or fewer', () {
      final entries = [
        dive(ts: at(2025, 2)),
        dive(ts: at(2025, 2)),
        dive(ts: at(2024, 11)),
      ];
      expect(markers(entries, DiveSortField.date, desc), const [
        ScrubberMarker(slot: 1, label: 'Feb 2025'),
        ScrubberMarker(slot: 2, label: 'Nov 2024'),
      ]);
    });

    test('the earliest month of each year carries the year', () {
      final newestFirst = [
        dive(ts: at(2025, 2)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2024, 12)),
        dive(ts: at(2024, 11)),
        dive(ts: at(2024, 2)),
      ];
      expect(markers(newestFirst, DiveSortField.date, desc), const [
        ScrubberMarker(slot: 0, label: 'Feb'),
        ScrubberMarker(slot: 1, label: 'Jan 2025'),
        ScrubberMarker(slot: 2, label: 'Dec'),
        ScrubberMarker(slot: 3, label: 'Nov'),
        ScrubberMarker(slot: 4, label: 'Feb 2024'),
      ]);
      expect(
        markers(
          newestFirst.reversed.toList(),
          DiveSortField.date,
          asc,
        ).map((m) => m.label),
        ['Feb 2024', 'Nov', 'Dec', 'Jan 2025', 'Feb'],
      );
    });

    test('newest-first months: the year marker sits at the last slot of the '
        'earliest month of each year', () {
      final entries = [
        dive(ts: at(2025, 3)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2024, 12)),
        dive(ts: at(2024, 10)),
        dive(ts: at(2024, 10)),
      ];
      expect(markers(entries, DiveSortField.date, desc), const [
        ScrubberMarker(slot: 0, label: 'Mar'),
        ScrubberMarker(slot: 2, label: 'Jan 2025'),
        ScrubberMarker(slot: 3, label: 'Dec'),
        ScrubberMarker(slot: 5, label: 'Oct 2024'),
      ]);
    });

    test('a repeated month carries the year only on its first marker', () {
      final entries = [
        dive(ts: at(2025, 1)),
        dive(ts: at(2025, 2)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2025, 3)),
      ];
      expect(markers(entries, DiveSortField.date, asc), const [
        ScrubberMarker(slot: 0, label: 'Jan 2025'),
        ScrubberMarker(slot: 1, label: 'Feb'),
        ScrubberMarker(slot: 2, label: 'Jan'),
        ScrubberMarker(slot: 3, label: 'Mar'),
      ]);
    });

    test('year-carrying month markers follow the diver date preference', () {
      final entries = [
        dive(ts: at(2025, 2)),
        dive(ts: at(2025, 1)),
        dive(ts: at(2024, 12)),
      ];
      expect(
        markers(entries, DiveSortField.date, desc, iso).map((m) => m.label),
        ['02', '2025-01', '2024-12'],
      );
    });

    test('dive numbers in steps sized to the range', () {
      final entries = [for (var n = 300; n > 0; n -= 25) dive(number: n)];
      final labels = markers(
        entries,
        DiveSortField.diveNumber,
        desc,
      ).map((m) => m.label);
      expect(labels, ['300', '250', '200', '150', '100', '50', '0']);
    });

    test('first letters for sites, skipping unnamed ones', () {
      final entries = [
        dive(site: 'arch'),
        dive(site: 'Anemone'),
        dive(),
        dive(site: 'Blue Hole'),
      ];
      expect(markers(entries, DiveSortField.site, asc), const [
        ScrubberMarker(slot: 0, label: 'A'),
        ScrubberMarker(slot: 3, label: 'B'),
      ]);
    });

    test('a name with leading whitespace gets no letter', () {
      // NOCASE orders the stored name, so ' Blue Hole' sorts before 'A'.
      final entries = [
        dive(site: ' Blue Hole'),
        dive(site: 'Anemone'),
        dive(site: 'Blue Hole'),
      ];
      expect(markers(entries, DiveSortField.site, asc), const [
        ScrubberMarker(slot: 1, label: 'A'),
        ScrubberMarker(slot: 2, label: 'B'),
      ]);
    });

    test('accented initials follow the NOCASE order without repeats', () {
      final entries = [
        dive(site: 'Éden'),
        dive(site: 'Öresund'),
        dive(site: 'école'),
      ];
      final labels = markers(
        entries,
        DiveSortField.site,
        asc,
      ).map((m) => m.label).toList();
      expect(labels.toSet(), hasLength(labels.length));
      expect(labels, hasLength(3));
    });

    test('depth steps in feet', () {
      final entries = [dive(depth: 40), dive(depth: 33), dive(depth: 20)];
      expect(
        markers(
          entries,
          DiveSortField.depth,
          desc,
          imperial,
        ).map((m) => m.label),
        ['120ft', '100ft', '60ft'],
      );
    });

    test('deepest-first: a 25.2 m dive sits between 30m and 20m', () {
      final entries = [
        dive(depth: 45),
        dive(depth: 31),
        dive(depth: 28),
        dive(depth: 25.2),
        dive(depth: 21),
        dive(depth: 3),
      ];
      final ms = markers(entries, DiveSortField.depth, desc);
      expect(ms, const [
        ScrubberMarker(slot: 0, label: '40m'),
        ScrubberMarker(slot: 1, label: '30m'),
        ScrubberMarker(slot: 4, label: '20m'),
        ScrubberMarker(slot: 5, label: '0m'),
      ]);
      const dive25 = 3;
      expect(slotOf(ms, '30m'), lessThan(dive25));
      expect(slotOf(ms, '20m'), greaterThan(dive25));
    });

    test('descending: a null value inside a run does not end it early', () {
      final entries = [
        dive(depth: 48),
        dive(depth: 38),
        dive(depth: 28),
        dive(),
        dive(depth: 22),
        dive(),
        dive(depth: 4),
      ];
      expect(markers(entries, DiveSortField.depth, desc), const [
        ScrubberMarker(slot: 0, label: '40m'),
        ScrubberMarker(slot: 1, label: '30m'),
        ScrubberMarker(slot: 4, label: '20m'),
        ScrubberMarker(slot: 6, label: '0m'),
      ]);
    });

    test('bottom time steps', () {
      final entries = [dive(minutes: 55), dive(minutes: 41), dive(minutes: 12)];
      expect(
        markers(entries, DiveSortField.bottomTime, desc).map((m) => m.label),
        ['50 min', '40 min', '10 min'],
      );
    });

    test('ratings with unrated', () {
      final entries = [dive(rating: 5), dive(rating: 5), dive()];
      expect(markers(entries, DiveSortField.rating, desc), const [
        ScrubberMarker(slot: 1, label: '5★'),
        ScrubberMarker(slot: 2, label: 'Unrated'),
      ]);
    });

    test('ratings descending put each marker at the bottom of its block', () {
      final entries = [
        dive(rating: 5),
        dive(rating: 4),
        dive(rating: 4),
        dive(rating: 0),
        dive(),
      ];
      expect(markers(entries, DiveSortField.rating, desc), const [
        ScrubberMarker(slot: 0, label: '5★'),
        ScrubberMarker(slot: 2, label: '4★'),
        ScrubberMarker(slot: 4, label: 'Unrated'),
      ]);
    });

    test('no slots, no markers', () {
      expect(markers(const [], DiveSortField.date, desc), isEmpty);
    });
  });
}
