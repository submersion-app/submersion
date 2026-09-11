import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  _extentTests();

  // The date range in the header is formatted by intl, which resolves against
  // Intl.defaultLocale: a PROCESS GLOBAL that app.dart sets from the app
  // locale. MaterialApp.locale does not touch it, so pinning the widget's
  // locale is not enough on its own and the 'Jun' assertion below would ride
  // on intl's implicit en_US fallback, or on whatever another test left
  // behind. Pin it, and restore it so the global stays contained.
  //
  // No initializeDateFormatting needed here, unlike a pure unit test:
  // GlobalMaterialLocalizations.delegate does that for widget tests.
  String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  TripSection section({
    int loaded = 2,
    int total = 2,
    bool collapsed = false,
    String name = 'Tassie',
  }) {
    return TripSection(
      tripId: 't1',
      tripName: name,
      startDate: DateTime(2026, 6, 8),
      endDate: DateTime(2026, 6, 9),
      entries: [
        for (var i = 0; i < loaded; i++)
          DiveListEntry(
            dive: DiveSummary(
              id: 'd$i',
              dateTime: DateTime(2026, 6, 8),
              sortTimestamp: 0,
              tripId: 't1',
              tripName: name,
            ),
            flatIndex: i,
          ),
      ],
      collapsed: collapsed,
      totalCount: total,
    );
  }

  Future<void> pumpHeader(
    WidgetTester tester, {
    required TripSection value,
    VoidCallback? onToggle,
    VoidCallback? onOpenTrip,
    bool isSelectionMode = false,
    bool? groupChecked,
    ValueChanged<bool?>? onGroupCheckedChanged,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: TripGroupHeader(
          section: value,
          onToggle: onToggle ?? () {},
          onOpenTrip: onOpenTrip ?? () {},
          isSelectionMode: isSelectionMode,
          groupChecked: groupChecked,
          onGroupCheckedChanged: onGroupCheckedChanged,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TripGroupHeader', () {
    testWidgets('shows the trip name', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.text('Tassie'), findsOneWidget);
    });

    testWidgets('shows a plain count when the whole trip is loaded', (
      tester,
    ) async {
      await pumpHeader(tester, value: section(loaded: 4, total: 4));

      expect(find.textContaining('4 dives'), findsOneWidget);
      expect(find.textContaining(' of '), findsNothing);
    });

    testWidgets('shows "6 of 14 dives" when only part of the trip is loaded', (
      tester,
    ) async {
      await pumpHeader(tester, value: section(loaded: 6, total: 14));

      expect(find.textContaining('6 of 14 dives'), findsOneWidget);
    });

    testWidgets('shows the trip date range', (tester) async {
      await pumpHeader(tester, value: section());

      expect(find.textContaining('Jun'), findsOneWidget);
    });

    testWidgets('tapping anywhere on the header toggles', (tester) async {
      var toggled = 0;
      await pumpHeader(tester, value: section(), onToggle: () => toggled++);

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });

    testWidgets('the chevron points down when expanded', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('the chevron points right when collapsed', (tester) async {
      await pumpHeader(tester, value: section(collapsed: true));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('the open-trip button fires its own callback', (tester) async {
      var opened = 0;
      var toggled = 0;
      await pumpHeader(
        tester,
        value: section(),
        onToggle: () => toggled++,
        onOpenTrip: () => opened++,
      );

      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(toggled, 0, reason: 'opening a trip must not also fold it');
    });

    testWidgets('selection mode swaps the open button for a checkbox', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        value: section(),
        isSelectionMode: true,
        groupChecked: false,
        onGroupCheckedChanged: (_) {},
      );

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('a partly selected group reads as mixed', (tester) async {
      await pumpHeader(
        tester,
        value: section(),
        isSelectionMode: true,
        groupChecked: null,
        onGroupCheckedChanged: (_) {},
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
    });
  });
}

void _extentTests() {
  group('tripGroupHeaderExtent', () {
    testWidgets('grows past 200% instead of capping', (tester) async {
      // The cap this replaced reintroduced the very clipping the fixed extent
      // exists to prevent: both iOS and Android offer accessibility text sizes
      // well beyond 200%.
      late double at2x;
      late double at3x;

      Widget probe(double factor, void Function(double) sink) => MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(factor)),
        child: Builder(
          builder: (context) {
            sink(tripGroupHeaderExtent(context));
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(probe(2.0, (v) => at2x = v));
      await tester.pumpWidget(probe(3.0, (v) => at3x = v));

      expect(
        at3x,
        greaterThan(at2x),
        reason: 'a 300% reader must get a taller header, not a clipped one',
      );
    });

    testWidgets('never shrinks below the designed height', (tester) async {
      late double small;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: Builder(
            builder: (context) {
              small = tripGroupHeaderExtent(context);
              return const SizedBox();
            },
          ),
        ),
      );

      late double normal;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
          child: Builder(
            builder: (context) {
              normal = tripGroupHeaderExtent(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(small, normal);
    });
  });
}
