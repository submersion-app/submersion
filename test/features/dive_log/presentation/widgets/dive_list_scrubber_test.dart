import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_density_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show makeDive;
import 'dive_scrubber_index_override.dart';

import '../../../../shared/widgets/list_scrubber/scrubber_hover.dart';

class _ScrubNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _ScrubNotifier(this.all, int loaded)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: all.take(loaded).toList(),
            hasMore: true,
            totalCount: all.length,
            revision: 1,
          ),
        ),
      );

  final List<DiveSummary> all;
  final calls = <(String, int)>[];
  bool vanish = false;

  @override
  Future<bool> loadThrough(String diveId, {required int targetIndex}) async {
    calls.add((diveId, targetIndex));
    if (vanish) return false;
    final through = (targetIndex + 51).clamp(0, all.length);
    state = AsyncValue.data(
      state.value!.copyWith(
        dives: all.take(through).toList(),
        hasMore: through < all.length,
      ),
    );
    return true;
  }

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const tripFirst = 200;
  const tripLast = 220;

  List<DiveSummary> fixture({bool trip = false, String? country}) => [
    for (var i = 0; i < 300; i++)
      (trip && i >= tripFirst && i <= tripLast
              ? makeDive('d$i', tripId: 't1', tripName: 'Red Sea')
              : makeDive('d$i'))
          .copyWith(siteCountry: country),
  ];

  List<DiveScrubberEntry> indexOf(
    List<DiveSummary> dives, {
    Set<String> favorites = const {},
  }) => [
    for (final d in dives)
      DiveScrubberEntry(
        id: d.id,
        sortTimestamp: d.sortTimestamp,
        diveNumber: d.diveNumber,
        siteName: d.siteName,
        tripId: d.tripId,
        tripName: d.tripName,
        isFavorite: favorites.contains(d.id),
      ),
  ];

  // The trailing loader row spins while more pages remain, so
  // pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_ScrubNotifier> pumpList(
    WidgetTester tester, {
    bool trip = false,
    String? country,
    Future<List<DiveScrubberEntry>>? index,
    List<DiveScrubberEntry> Function()? entries,
    ValueListenable<bool>? shown,
    String? selectedId,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dives = fixture(trip: trip, country: country);
    final notifier = _ScrubNotifier(dives, 50);
    final base = await getBaseOverrides();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      kCollapsedTripIdsPrefsKey,
      trip ? const ['t1'] : const [],
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          diveListGroupTripsProvider.overrideWith((ref) => trip),
          tripDiveCountsProvider.overrideWith(
            (ref) async => trip ? const {'t1': 21} : const <String, int>{},
          ),
          collapsedTripIdsProvider.overrideWith(
            (ref) => CollapsedTripsNotifier(prefs, null),
          ),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
          diveScrubberIndexOverride(
            () => index ?? entries?.call() ?? indexOf(dives),
          ),
        ],
        child: shown == null
            ? DiveListContent(showAppBar: false, selectedId: selectedId)
            : ValueListenableBuilder<bool>(
                valueListenable: shown,
                builder: (_, show, _) => show
                    ? const DiveListContent(showAppBar: false)
                    : const SizedBox(),
              ),
      ),
    );
    await settle(tester);
    return notifier;
  }

  Finder row(String id) => find.byWidgetPredicate(
    (w) => w is KeyboardListItem && w.navigationKey == id,
  );

  Future<void> showThumb(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
    await tester.pump();
  }

  Future<void> dragThumb(WidgetTester tester, double dy) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(Offset(0, dy));
    await tester.pump();
    await gesture.up();
    await settle(tester);
  }

  testWidgets('dropping past the loaded rows loads through and lands', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    await showThumb(tester);
    await dragThumb(tester, 2000);

    expect(notifier.calls, [('d299', 299)]);
    expect(row('d299'), findsOneWidget);
    // The last row cannot reach the top, so it lands fully in view.
    final list = tester.getRect(find.byType(CustomScrollView));
    final target = tester.getRect(row('d299'));
    expect(target.top, greaterThanOrEqualTo(list.top));
    expect(target.bottom, lessThanOrEqualTo(list.bottom));
  });

  testWidgets('a mid-list drop past the loaded rows lands at the top', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    await showThumb(tester);
    final list = tester.getRect(find.byType(CustomScrollView));
    final thumbY = tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy;
    final target = trackForSlot(
      slot: 150,
      trackExtent: list.height - 48,
      slotCount: 300,
    );
    await dragThumb(tester, list.top + target - thumbY);

    expect(notifier.calls, [('d150', 150)]);
    expect(tester.getRect(row('d150')).top, closeTo(list.top, 4));
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    final settled = trackForSlot(
      slot: slotPositionForScroll(
        pixels: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
        loadedSlotCount: 201,
      ),
      trackExtent: list.height - 48,
      slotCount: 300,
    );
    expect(
      tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy,
      closeTo(list.top + settled, 0.01),
    );
  });

  testWidgets('slots and markers are reused while their inputs hold', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    ListScrubber scrubber() => tester.widget(find.byType(ListScrubber));
    final before = scrubber();
    expect(before.markers, isNotEmpty);
    expect(before.loadedSlotCount, 50);

    await notifier.loadThrough('d120', targetIndex: 120);
    await tester.pump();

    final after = scrubber();
    expect(after.loadedSlotCount, 171);
    expect(identical(after.markers, before.markers), isTrue);
    expect(identical(after.highlightTicks, before.highlightTicks), isTrue);
    expect(identical(after.segments, before.segments), isTrue);
    expect(identical(after.contextTicks, before.contextTicks), isTrue);
    expect(identical(after.density, before.density), isTrue);
  });

  group('per-sort details', () {
    ListScrubber scrubber(WidgetTester tester) =>
        tester.widget<ListScrubber>(find.byType(ListScrubber));

    BuildContext ctx(WidgetTester tester) =>
        tester.element(find.byType(ListScrubber));

    Future<void> sortBy(
      WidgetTester tester,
      DiveSortField field, [
      SortDirection direction = SortDirection.descending,
    ]) async {
      ProviderScope.containerOf(ctx(tester))
          .read(settingsProvider.notifier)
          .setDiveSort(SortState(field: field, direction: direction));
      await tester.pump();
    }

    List<DiveScrubberEntry> gassy({Map<int, DiveScrubberGas>? gases}) => [
      for (final (i, e) in indexOf(fixture()).indexed)
        DiveScrubberEntry(
          id: e.id,
          sortTimestamp: e.sortTimestamp,
          diveNumber: e.diveNumber,
          gas:
              (gases ??
              const {
                5: DiveScrubberGas.air,
                10: DiveScrubberGas.nitrox,
                20: DiveScrubberGas.trimix,
                25: DiveScrubberGas.air,
                30: DiveScrubberGas.nitrox,
              })[i],
        ),
    ];

    testWidgets('date sort stripes each trip run in a calm tone', (
      tester,
    ) async {
      await pumpList(tester, entries: () => indexOf(fixture(trip: true)));
      final tone = Theme.of(
        ctx(tester),
      ).colorScheme.tertiary.withValues(alpha: 0.7);
      expect(scrubber(tester).segments, [
        ScrubberSegment(firstSlot: tripFirst, lastSlot: tripLast, color: tone),
      ]);
      expect(scrubber(tester).contextTicks, isEmpty);
    });

    testWidgets('a collapsed trip stripes its single slot', (tester) async {
      await pumpList(tester, trip: true);
      expect(scrubber(tester).segments.single.firstSlot, tripFirst);
      expect(scrubber(tester).segments.single.lastSlot, tripFirst);
    });

    testWidgets('the detail names the trip under the thumb in date sort', (
      tester,
    ) async {
      await pumpList(tester, entries: () => indexOf(fixture(trip: true)));
      expect(scrubber(tester).labelFor(tripFirst - 1), 'Jan 1970');
      expect(scrubber(tester).detailFor!(tripFirst - 1), isNull);
      expect(scrubber(tester).labelFor(tripFirst + 3), 'Jan 1970');
      expect(scrubber(tester).detailFor!(tripFirst + 3), 'Red Sea');

      await sortBy(tester, DiveSortField.diveNumber);
      expect(scrubber(tester).detailFor!(tripFirst + 3), isNull);
    });

    testWidgets(
      'depth sort ticks air, nitrox and trimix in the chart colours',
      (tester) async {
        await pumpList(tester, entries: gassy);
        expect(scrubber(tester).contextTicks, isEmpty);
        await sortBy(tester, DiveSortField.depth);
        expect(scrubber(tester).contextTicks, const [
          ScrubberTick(slot: 5, color: GasColors.air),
          ScrubberTick(slot: 25, color: GasColors.air),
          ScrubberTick(slot: 10, color: GasColors.nitrox),
          ScrubberTick(slot: 30, color: GasColors.nitrox),
          ScrubberTick(slot: 20, color: GasColors.trimix),
        ]);
        expect(scrubber(tester).segments, isEmpty);
        await sortBy(tester, DiveSortField.date);
        expect(scrubber(tester).contextTicks, isEmpty);
      },
    );

    testWidgets('gas ticks follow a change in the index', (tester) async {
      var gases = const {5: DiveScrubberGas.nitrox};
      await pumpList(tester, entries: () => gassy(gases: gases));
      await sortBy(tester, DiveSortField.depth);
      final before = scrubber(tester).contextTicks;
      expect(before, const [ScrubberTick(slot: 5, color: GasColors.nitrox)]);

      gases = const {5: DiveScrubberGas.trimix, 42: DiveScrubberGas.nitrox};
      ProviderScope.containerOf(
        ctx(tester),
      ).invalidate(diveScrubberIndexProvider);
      await tester.pump();
      await tester.pump();
      expect(scrubber(tester).contextTicks, const [
        ScrubberTick(slot: 42, color: GasColors.nitrox),
        ScrubberTick(slot: 5, color: GasColors.trimix),
      ]);
    });

    testWidgets('dive number sort ticks breaks in the numbering', (
      tester,
    ) async {
      List<DiveScrubberEntry> numbered() => [
        for (final (i, e) in indexOf(fixture()).indexed)
          DiveScrubberEntry(
            id: e.id,
            sortTimestamp: e.sortTimestamp,
            diveNumber: i == 40
                ? 38
                : i > 120
                ? 400 - i
                : 300 - i,
          ),
      ];
      await pumpList(tester, entries: numbered);
      expect(scrubber(tester).contextTicks, isEmpty);
      await sortBy(tester, DiveSortField.diveNumber);
      const warn = AppColors.warning;
      expect(scrubber(tester).contextTicks, [
        const ScrubberTick(slot: 40, color: warn),
        const ScrubberTick(slot: 41, color: warn),
        const ScrubberTick(slot: 121, color: warn),
      ]);
      expect(scrubber(tester).segments, isEmpty);
    });

    testWidgets('other sorts show no details', (tester) async {
      await pumpList(tester, entries: gassy);
      for (final field in [
        DiveSortField.site,
        DiveSortField.bottomTime,
        DiveSortField.rating,
      ]) {
        await sortBy(tester, field);
        expect(scrubber(tester).segments, isEmpty, reason: '$field');
        expect(scrubber(tester).contextTicks, isEmpty, reason: '$field');
      }
    });

    testWidgets('details are recomputed when the sort changes', (tester) async {
      await pumpList(tester, entries: gassy);
      final dated = scrubber(tester).contextTicks;
      final density = scrubber(tester).density;
      expect(density, const [
        ScrubberDensityBin(firstSlot: 0, lastSlot: 299, count: 300),
      ]);
      await tester.pump();
      expect(identical(scrubber(tester).contextTicks, dated), isTrue);
      expect(identical(scrubber(tester).density, density), isTrue);
      await sortBy(tester, DiveSortField.depth);
      expect(scrubber(tester).contextTicks, hasLength(5));
      expect(scrubber(tester).density, isEmpty);
      await sortBy(tester, DiveSortField.date);
      expect(scrubber(tester).contextTicks, isEmpty);
      expect(scrubber(tester).density, density);
    });

    testWidgets('date sort bars each month while active, other sorts none', (
      tester,
    ) async {
      List<DiveScrubberEntry> dated() => [
        for (final (i, e) in indexOf(fixture()).indexed)
          DiveScrubberEntry(
            id: e.id,
            sortTimestamp: DateTime.utc(
              2024,
              i < 100 ? 3 : (i == 100 ? 2 : 1),
              10,
            ).millisecondsSinceEpoch,
          ),
      ];
      const months = [
        ScrubberDensityBin(firstSlot: 0, lastSlot: 99, count: 100),
        ScrubberDensityBin(firstSlot: 100, lastSlot: 100, count: 1),
        ScrubberDensityBin(firstSlot: 101, lastSlot: 299, count: 199),
      ];
      final bars = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ListScrubberDensityPainter,
      );
      await pumpList(tester, entries: dated);
      await showThumb(tester);
      expect(bars, findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: scrubberThumbHoverPoint(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final painter =
          tester.widget<CustomPaint>(bars).painter!
              as ListScrubberDensityPainter;
      expect(painter.bins, months);

      for (final field in [
        DiveSortField.diveNumber,
        DiveSortField.site,
        DiveSortField.depth,
        DiveSortField.bottomTime,
        DiveSortField.rating,
      ]) {
        await sortBy(tester, field);
        await tester.pump(const Duration(milliseconds: 200));
        expect(scrubber(tester).density, isEmpty, reason: '$field');
        expect(bars, findsNothing, reason: '$field');
      }
      await mouse.removePointer();
      await settle(tester);
    });
  });

  group('favourite ticks', () {
    ListScrubber scrubber(WidgetTester tester) =>
        tester.widget<ListScrubber>(find.byType(ListScrubber));

    testWidgets('favourite slots become ticks in the favourite colour', (
      tester,
    ) async {
      await pumpList(
        tester,
        entries: () => indexOf(fixture(), favorites: {'d120', 'd5'}),
      );
      expect(scrubber(tester).highlightTicks, [5, 120]);
      expect(scrubber(tester).highlightTickColor, AppColors.favorite);
    });

    testWidgets('a favourite in a collapsed trip ticks the trip slot', (
      tester,
    ) async {
      await pumpList(
        tester,
        trip: true,
        entries: () => indexOf(
          fixture(trip: true),
          favorites: {'d${tripFirst + 7}', 'd250'},
        ),
      );
      final slots = buildDiveScrubberSlots(
        entries: indexOf(fixture(trip: true)),
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
      );
      expect(scrubber(tester).highlightTicks, [
        slots.indexWhere((s) => s.collapsedTripId == 't1'),
        250 - (tripLast - tripFirst),
      ]);
    });

    testWidgets('ticks follow a dive being favourited', (tester) async {
      var favorites = {'d5'};
      await pumpList(
        tester,
        entries: () => indexOf(fixture(), favorites: favorites),
      );
      expect(scrubber(tester).highlightTicks, [5]);

      favorites = {'d5', 'd42'};
      ProviderScope.containerOf(
        tester.element(find.byType(ListScrubber)),
      ).invalidate(diveScrubberIndexProvider);
      await tester.pump();
      await tester.pump();
      expect(scrubber(tester).highlightTicks, [5, 42]);
    });
  });

  group('selected-dive dot', () {
    int? highlight(WidgetTester tester) =>
        tester.widget<ListScrubber>(find.byType(ListScrubber)).highlightSlot;

    testWidgets('marks the selected dive at its track position', (
      tester,
    ) async {
      await pumpList(tester, selectedId: 'd120');
      expect(highlight(tester), 120);
      await showThumb(tester);
      final list = tester.getRect(find.byType(CustomScrollView));
      final y = trackForSlot(
        slot: 120,
        trackExtent: list.height - 48,
        slotCount: 300,
      );
      expect(
        tester.getCenter(find.byKey(ListScrubber.highlightKey)).dy,
        closeTo(list.top + y + 24, 0.01),
      );
      await tester.pump(ListScrubber.idleHide);
    });

    testWidgets('follows the highlighted dive without a selection', (
      tester,
    ) async {
      await pumpList(tester);
      expect(highlight(tester), isNull);
      ProviderScope.containerOf(
        tester.element(find.byType(ListScrubber)),
      ).read(highlightedDiveIdProvider.notifier).state = 'd42';
      await tester.pump();
      expect(highlight(tester), 42);
    });

    testWidgets('no dot without a selection or for an unknown dive', (
      tester,
    ) async {
      await pumpList(tester);
      await showThumb(tester);
      expect(highlight(tester), isNull);
      expect(find.byKey(ListScrubber.highlightKey), findsNothing);
      await tester.pump(ListScrubber.idleHide);
    });

    testWidgets('an unknown dive puts no dot', (tester) async {
      await pumpList(tester, selectedId: 'gone');
      expect(highlight(tester), isNull);
    });

    testWidgets('a dive in a collapsed trip marks the trip slot', (
      tester,
    ) async {
      await pumpList(tester, trip: true, selectedId: 'd${tripFirst + 7}');
      final slots = buildDiveScrubberSlots(
        entries: indexOf(fixture(trip: true)),
        groupingEnabled: true,
        collapsedTripIds: const {'t1'},
      );
      expect(
        highlight(tester),
        slots.indexWhere((s) => s.collapsedTripId == 't1'),
      );
    });

    testWidgets('a dive after a collapsed trip marks its own slot', (
      tester,
    ) async {
      await pumpList(tester, trip: true, selectedId: 'd250');
      expect(highlight(tester), 250 - (tripLast - tripFirst));
    });
  });

  testWidgets('year markers bound each dive in the sort direction', (
    tester,
  ) async {
    int yearOf(int i) => 2023 - i ~/ 100;
    final index = [
      for (final e in indexOf(fixture()))
        DiveScrubberEntry(
          id: e.id,
          sortTimestamp: DateTime.utc(
            yearOf(int.parse(e.id.substring(1))),
            4,
          ).millisecondsSinceEpoch,
        ),
    ];
    await pumpList(tester, index: Future.value(index));
    List<ScrubberMarker> markers() =>
        tester.widget<ListScrubber>(find.byType(ListScrubber)).markers;
    int slotOf(String label) =>
        markers().singleWhere((m) => m.label == label).slot;

    // d150 is from 2022 in a newest-first list.
    expect(slotOf('2023'), lessThan(150));
    expect(slotOf('2022'), greaterThan(150));

    ProviderScope.containerOf(tester.element(find.byType(ListScrubber)))
        .read(settingsProvider.notifier)
        .setDiveSort(
          const SortState(
            field: DiveSortField.date,
            direction: SortDirection.ascending,
          ),
        );
    await settle(tester);
    expect(markers().map((m) => m.slot), [0, 100, 200]);
  });

  testWidgets('the value shows the sort value alone, without the country', (
    tester,
  ) async {
    final index = [
      for (final e in indexOf(fixture()))
        DiveScrubberEntry(
          id: e.id,
          sortTimestamp: DateTime.utc(2024, 3, 10).millisecondsSinceEpoch,
          siteName: 'Blue Hole',
        ),
    ];
    await pumpList(tester, index: Future.value(index), country: 'Egypt');
    final scrubber = tester.widget<ListScrubber>(find.byType(ListScrubber));
    expect(scrubber.labelFor(0), 'Mar 2024');
  });

  testWidgets('month markers follow a date preference change', (tester) async {
    final index = [
      for (final e in indexOf(fixture()))
        DiveScrubberEntry(
          id: e.id,
          sortTimestamp: DateTime.utc(
            2025,
            12 - int.parse(e.id.substring(1)) ~/ 30,
          ).millisecondsSinceEpoch,
        ),
    ];
    await pumpList(tester, index: Future.value(index));
    List<String> labels() => [
      for (final m
          in tester.widget<ListScrubber>(find.byType(ListScrubber)).markers)
        m.label,
    ];
    expect(labels(), contains('Mar 2025'));

    await ProviderScope.containerOf(tester.element(find.byType(ListScrubber)))
        .read(settingsProvider.notifier)
        .setDateFormat(DateFormatPreference.yyyymmdd);
    await tester.pump();
    expect(labels(), contains('2025-03'));
    expect(labels(), isNot(contains('Mar 2025')));
  });

  testWidgets('landing leaves the selection alone', (tester) async {
    final notifier = await pumpList(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CustomScrollView)),
    );
    await showThumb(tester);
    await dragThumb(tester, 2000);
    expect(notifier.calls, isNotEmpty);
    expect(container.read(highlightedDiveIdProvider), isNull);
  });

  testWidgets('a vanished target leaves the list where it is', (tester) async {
    final notifier = await pumpList(tester);
    notifier.vanish = true;
    await showThumb(tester);
    await dragThumb(tester, 2000);
    expect(notifier.calls, hasLength(1));
    expect(row('d299'), findsNothing);
  });

  testWidgets('a target in a collapsed trip lands on its header', (
    tester,
  ) async {
    final notifier = await pumpList(tester, trip: true);
    final slots = buildDiveScrubberSlots(
      entries: indexOf(fixture(trip: true)),
      groupingEnabled: true,
      collapsedTripIds: const {'t1'},
    );
    final tripSlot = slots.indexWhere((s) => s.collapsedTripId == 't1');

    await showThumb(tester);
    final listTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    final trackExtent =
        tester.getSize(find.byType(CustomScrollView)).height - 48;
    final thumbY =
        tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy - listTop;
    final target = trackForSlot(
      slot: tripSlot,
      trackExtent: trackExtent,
      slotCount: slots.length,
    );
    await dragThumb(tester, target - thumbY);

    expect(notifier.calls.single.$1, 'd$tripFirst');
    expect(find.text('Red Sea'), findsOneWidget);
    expect(row('d${tripFirst + 1}'), findsNothing);
  });

  testWidgets('the list keeps its place when the index arrives', (
    tester,
  ) async {
    final index = Completer<List<DiveScrubberEntry>>();
    await pumpList(tester, index: index.future);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await settle(tester);
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    index.complete(indexOf(fixture()));
    await settle(tester);

    expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
  });

  bool scrubbing(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(diveListScrubbingProvider);

  testWidgets('dragging the thumb marks the list as scrubbing until release', (
    tester,
  ) async {
    await pumpList(tester);
    await showThumb(tester);
    expect(scrubbing(tester), isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await tester.pump();
    expect(scrubbing(tester), isTrue);

    await gesture.up();
    await settle(tester);
    expect(scrubbing(tester), isFalse);
  });

  testWidgets('leaving the list mid-drag clears the scrubbing flag', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await pumpList(tester, shown: shown);
    await showThumb(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await tester.pump();
    expect(scrubbing(tester), isTrue);

    shown.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.byType(ListScrubber), findsNothing);
    expect(scrubbing(tester), isFalse);
    await gesture.up();
    await settle(tester);
  });
}
