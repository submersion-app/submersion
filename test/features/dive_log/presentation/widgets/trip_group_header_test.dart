import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: Directionality(
          textDirection: textDirection,
          child: TripGroupHeader(
            section: value,
            onToggle: onToggle ?? () {},
            onOpenTrip: onOpenTrip ?? () {},
            isSelectionMode: isSelectionMode,
            groupChecked: groupChecked,
            onGroupCheckedChanged: onGroupCheckedChanged,
          ),
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

    testWidgets('carries no kicker, no trip icon and no card fill', (
      tester,
    ) async {
      // The quiet treatment: the trip reads as a heading over the list, not
      // as a filled card with a label in front of the name. The Material that
      // hosts the splash stays transparent; the opaque backing below is the
      // list's own colour, not a card.
      await pumpHeader(tester, value: section());

      expect(find.text('TRIP'), findsNothing);
      expect(find.byIcon(Icons.card_travel), findsNothing);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TripGroupHeader),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.transparent);
    });

    testWidgets('is backed by the list colour, clear of the gutter (LTR)', (
      tester,
    ) async {
      // Pinned, the header sits over cards scrolling beneath it, so it must
      // be opaque. The leading 16px stays clear: that is where the rail runs,
      // and no card ever reaches into it.
      await pumpHeader(tester, value: section());

      final header = tester.getRect(find.byType(TripGroupHeader));
      final backing = find.byKey(const ValueKey('trip_group_header_backing'));
      final rect = tester.getRect(backing);
      expect(rect.left - header.left, 16);
      expect(rect.right, header.right);
      expect(rect.height, header.height);

      final color = tester.widget<ColoredBox>(backing).color;
      final context = tester.element(find.byType(TripGroupHeader));
      expect(color, Theme.of(context).scaffoldBackgroundColor);
      expect(color.a, 1.0);
    });

    testWidgets('in a fixed extent the whole height is the tap target', (
      tester,
    ) async {
      // The pinned delegate gives the header a tight extent that grows with
      // the text scale. The tappable row must fill it, and its content must
      // centre in it, rather than shrinking to its natural height and riding
      // to the top. At 100% the open-trip button's 48px minimum hides the
      // problem, so this runs at 200%, where the extent is 96.
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 96,
                child: TripGroupHeader(
                  section: section(),
                  onToggle: () {},
                  onOpenTrip: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byType(TripGroupHeader));
      // The outermost InkWell is the row's; the open-trip button has its own.
      final ink = tester.getRect(
        find
            .descendant(
              of: find.byType(TripGroupHeader),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(header.height, 96);
      expect(ink.height, 96);
    });

    testWidgets('the backing leaves the gutter clear under RTL too', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        value: section(),
        textDirection: TextDirection.rtl,
      );

      final header = tester.getRect(find.byType(TripGroupHeader));
      final rect = tester.getRect(
        find.byKey(const ValueKey('trip_group_header_backing')),
      );
      expect(header.right - rect.right, 16);
      expect(rect.left, header.left);
    });

    testWidgets('the name keeps a 16px inset on the leading side (LTR)', (
      tester,
    ) async {
      await pumpHeader(tester, value: section());

      final header = tester.getRect(find.byType(TripGroupHeader));
      final name = tester.getRect(find.text('Tassie'));
      expect(name.left - header.left, 16);
    });

    testWidgets('the name keeps a 16px inset on the leading side (RTL)', (
      tester,
    ) async {
      // The rail mirrors to the right under RTL, so the header's wide inset
      // has to follow it. A physical left inset would leave 4px there and
      // push the text onto the rail.
      await pumpHeader(
        tester,
        value: section(),
        textDirection: TextDirection.rtl,
      );

      final header = tester.getRect(find.byType(TripGroupHeader));
      final name = tester.getRect(find.text('Tassie'));
      expect(header.right - name.right, 16);
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
    testWidgets('is 48 at the default text scale', (tester) async {
      // Down from 62: the header lost its card padding, its kicker line and
      // its icon, and 48 still clears the minimum tap target for the
      // open-trip button that sits inside it.
      late double extent;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              extent = tripGroupHeaderExtent(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(extent, 48);
    });

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
