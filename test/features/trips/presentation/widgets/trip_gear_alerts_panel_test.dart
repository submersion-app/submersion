import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_gear_alerts_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const ccr = EquipmentItem(
  id: 'r1',
  name: 'My CCR',
  type: EquipmentType.rebreather,
);

final _now = DateTime.now();
final _t0 = DateTime(2025, 1, 1);

Trip trip({bool past = false}) {
  final start = past
      ? DateTime(2025, 3, 1)
      : _now.add(const Duration(days: 10));
  return Trip(
    id: 't1',
    name: 'Trip',
    startDate: start,
    endDate: start.add(const Duration(days: 4)),
    createdAt: _t0,
    updatedAt: _t0,
  );
}

ScrubberMargin margin({double marginAfter = -140, bool caution = true}) =>
    ScrubberMargin(
      item: ccr,
      ratedMinutes: 300,
      consumedMinutes: 90,
      consumedSince: DateTime(2025, 2, 1),
      remainingBefore: 210,
      expectedDives: 10,
      expectedDivesN: 0,
      divesFromOverride: true,
      minutesFromOverride: false,
      minutesPerDive: 35,
      minutesPerDiveN: 2,
      expectedUse: 350,
      marginAfter: marginAfter,
      caution: caution,
    );

DueClock dueClock({bool overdue = false}) => (
  item: const EquipmentItem(id: 'e1', name: 'AL80', type: EquipmentType.tank),
  status: ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      createdAt: _t0,
      updatedAt: _t0,
    ),
    kind: ServiceKind(
      id: 'hydro',
      name: 'Hydrostatic test',
      defaultIntervalDays: 1825,
      isBuiltIn: true,
      createdAt: _t0,
      updatedAt: _t0,
    ),
    anchor: _t0,
    dueDate: overdue
        ? _now.subtract(const Duration(days: 30))
        : _now.add(const Duration(days: 5)),
    severity: overdue
        ? ServiceClockSeverity.overdue
        : ServiceClockSeverity.dueSoon,
    now: _now,
  ),
);

Widget host({
  List<ScrubberMargin> margins = const [],
  List<DueClock> alerts = const [],
  bool past = false,
  Widget Function(Widget panel)? wrap,
}) {
  final panel = TripGearAlertsPanel(trip: trip(past: past));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: wrap == null ? panel : wrap(panel)),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (_, _) => const Scaffold(body: Text('EQUIPMENT_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      tripScrubberMarginsProvider('t1').overrideWith((ref) async => margins),
      tripServiceAlertsProvider('t1').overrideWith((ref) async => alerts),
      equipmentRollupClockProvider.overrideWith((ref) async => const {}),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> toggle(WidgetTester tester) async {
  await tester.tap(find.byKey(TripGearAlertsPanel.headerKey));
  await tester.pumpAndSettle();
}

/// The fill behind the one-line header, null when it is untinted.
Color? headerFill(WidgetTester tester) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byKey(TripGearAlertsPanel.headerKey),
      matching: find.byType(Ink),
    ),
  );
  return (ink.decoration as BoxDecoration?)?.color;
}

void main() {
  // formatDate resolves against Intl.defaultLocale, a process global a
  // widget test never sets; pin it so the "as of" date reads the same on
  // every machine.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  testWidgets('nothing to say renders nothing', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  group('one line until tapped (#2221)', () {
    testWidgets('a scrubber margin alone shows its own summary', (
      tester,
    ) async {
      await tester.pumpWidget(host(margins: [margin()]));
      await tester.pumpAndSettle();
      expect(find.text('-140 min scrubber margin'), findsOneWidget);
      expect(find.text('My CCR'), findsNothing);
      await toggle(tester);
      expect(find.text('My CCR'), findsOneWidget);
      expect(find.text('-140 min margin after the trip'), findsOneWidget);
    });

    testWidgets('a service alert alone shows its count and lists the gear', (
      tester,
    ) async {
      await tester.pumpWidget(host(alerts: [dueClock()]));
      await tester.pumpAndSettle();
      expect(
        find.text('1 item needs service before this trip'),
        findsOneWidget,
      );
      expect(find.text('AL80'), findsNothing);
      await toggle(tester);
      expect(find.text('AL80'), findsOneWidget);
      // The lone section's heading would only repeat the header line.
      expect(
        find.text('1 item needs service before this trip'),
        findsOneWidget,
      );
    });

    testWidgets('several alerts fold under one counted line', (tester) async {
      await tester.pumpWidget(host(margins: [margin()], alerts: [dueClock()]));
      await tester.pumpAndSettle();
      expect(find.text('2 gear alerts for this trip'), findsOneWidget);
      expect(find.text('AL80'), findsNothing);
      expect(find.text('My CCR'), findsNothing);
      await toggle(tester);
      // Each section is headed once the header no longer names it.
      expect(
        find.text('1 item needs service before this trip'),
        findsOneWidget,
      );
      expect(find.text('Scrubber margin'), findsOneWidget);
      expect(find.text('AL80'), findsOneWidget);
      expect(find.text('My CCR'), findsOneWidget);
    });

    testWidgets('a second tap folds it away again', (tester) async {
      await tester.pumpWidget(host(margins: [margin()]));
      await tester.pumpAndSettle();
      await toggle(tester);
      expect(find.text('My CCR'), findsOneWidget);
      await toggle(tester);
      expect(find.text('My CCR'), findsNothing);
    });

    testWidgets('screen readers hear whether it is open', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(margins: [margin()]));
      await tester.pumpAndSettle();
      final header = find.byKey(TripGearAlertsPanel.headerKey);
      expect(
        tester.getSemantics(header),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
      );
      await toggle(tester);
      expect(
        tester.getSemantics(header),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
      );
      semantics.dispose();
    });
  });

  group('severity', () {
    testWidgets('an overdue item tints the header with the alert palette', (
      tester,
    ) async {
      await tester.pumpWidget(host(alerts: [dueClock(overdue: true)]));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(headerFill(tester), StatusColors.light.alert.container);
    });

    testWidgets('gear merely coming due uses the warn palette', (tester) async {
      await tester.pumpWidget(host(alerts: [dueClock()]));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(headerFill(tester), StatusColors.light.warn.container);
    });

    testWidgets('a scrubber caution outranks gear coming due', (tester) async {
      await tester.pumpWidget(host(margins: [margin()], alerts: [dueClock()]));
      await tester.pumpAndSettle();
      expect(headerFill(tester), StatusColors.light.alert.container);
    });

    testWidgets('a comfortable margin is information, not a warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(margins: [margin(marginAfter: 200, caution: false)]),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.air), findsOneWidget);
      expect(headerFill(tester), isNull);
    });
  });

  group('screen readers hear the severity', () {
    SemanticsNode headerNode(WidgetTester tester) =>
        tester.getSemantics(find.byKey(TripGearAlertsPanel.headerKey));

    testWidgets('an alert says so', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(margins: [margin()]));
      await tester.pumpAndSettle();
      expect(headerNode(tester).label, startsWith('Alert'));
      semantics.dispose();
    });

    testWidgets('gear coming due is a warning', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(alerts: [dueClock()]));
      await tester.pumpAndSettle();
      expect(headerNode(tester).label, startsWith('Warning'));
      semantics.dispose();
    });

    testWidgets('a comfortable margin claims neither', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(margins: [margin(marginAfter: 200, caution: false)]),
      );
      await tester.pumpAndSettle();
      expect(headerNode(tester).label, isNot(contains('Alert')));
      expect(headerNode(tester).label, isNot(contains('Warning')));
      semantics.dispose();
    });
  });

  testWidgets('selecting another trip starts it collapsed again', (
    tester,
  ) async {
    // The master-detail layouts rebuild the same detail page for the next
    // trip, so an open panel would otherwise carry over to a trip whose
    // alerts the diver never asked to see.
    Trip other() => trip().copyWith(id: 't2');
    final current = ValueNotifier<Trip>(trip());
    addTearDown(current.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          for (final id in ['t1', 't2']) ...[
            tripScrubberMarginsProvider(
              id,
            ).overrideWith((ref) async => [margin()]),
            tripServiceAlertsProvider(id).overrideWith((ref) async => const []),
          ],
          equipmentRollupClockProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<Trip>(
              valueListenable: current,
              builder: (_, t, _) => TripGearAlertsPanel(trip: t),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await toggle(tester);
    expect(find.text('My CCR'), findsOneWidget);

    current.value = other();
    await tester.pumpAndSettle();
    expect(find.text('My CCR'), findsNothing);
  });

  testWidgets('a past trip drops service alerts and reads as of its start', (
    tester,
  ) async {
    // Today's service state says nothing about a trip already dived.
    await tester.pumpWidget(
      host(margins: [margin()], alerts: [dueClock()], past: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('-140 min scrubber margin'), findsOneWidget);
    await toggle(tester);
    expect(find.text('AL80'), findsNothing);
    expect(find.textContaining('as of Mar 1, 2025'), findsOneWidget);
  });

  testWidgets('a past trip with only service alerts renders nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(alerts: [dueClock()], past: true));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('tapping a listed item opens it', (tester) async {
    await tester.pumpWidget(host(alerts: [dueClock(overdue: true)]));
    await tester.pumpAndSettle();
    await toggle(tester);
    await tester.tap(find.text('AL80'));
    await tester.pumpAndSettle();
    expect(find.text('EQUIPMENT_PAGE'), findsOneWidget);
  });

  testWidgets('on a phone the collapsed panel is a single short row', (
    tester,
  ) async {
    // The reported screen: the full breakdown took half an iPhone window
    // above the trip timeline and could not be dismissed.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(margins: [margin()], alerts: [dueClock()]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TripGearAlertsPanel)).height,
      lessThan(80),
    );
  });

  testWidgets('opened on a short window it leaves room for the page', (
    tester,
  ) async {
    // Once open the panel still sits above the page's scrolling content,
    // so several units scroll inside it instead of overflowing the page.
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        margins: [for (var i = 0; i < 6; i++) margin()],
        alerts: [dueClock()],
        wrap: (panel) => Column(
          children: [
            panel,
            const Expanded(child: SizedBox(key: ValueKey('page-body'))),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await toggle(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TripGearAlertsPanel)).height,
      lessThanOrEqualTo(600 * TripGearAlertsPanel.maxHeightFraction + 1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('page-body'))).height,
      greaterThan(0),
    );
  });
}
