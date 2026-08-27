import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/urgent_banner.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _t0 = DateTime(2026, 1, 1);

DueClock _dueClock(String name, ServiceClockSeverity severity, {String? id}) =>
    (
      item: EquipmentItem(
        id: id ?? name,
        name: name,
        type: EquipmentType.regulator,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 'schedule',
          equipmentId: 'equipment',
          serviceKindId: 'kind',
          createdAt: _t0,
          updatedAt: _t0,
        ),
        kind: ServiceKind(
          id: 'kind',
          name: 'Annual service',
          createdAt: _t0,
          updatedAt: _t0,
        ),
        anchor: _t0,
        dueDate: DateTime(2026, 6, 1),
        severity: severity,
        now: DateTime(2026, 7, 24),
      ),
    );

/// Records the location the banner navigated to, if any.
class NavSpy {
  String? location;
}

Future<NavSpy> pumpBanner(WidgetTester tester, DashboardAlerts alerts) async {
  final overrides = await getBaseOverrides();
  final spy = NavSpy();
  Widget stub(String path) => Builder(
    builder: (context) {
      spy.location = path;
      return const Scaffold();
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: UrgentBanner()),
      ),
      GoRoute(
        path: '/equipment',
        builder: (_, _) => stub('/equipment'),
        routes: [
          GoRoute(
            path: ':equipmentId',
            builder: (_, state) =>
                stub('/equipment/${state.pathParameters['equipmentId']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/diver-profile/insurance',
        builder: (_, _) => stub('/settings/diver-profile/insurance'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        dashboardAlertsProvider.overrideWith((ref) async => alerts),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

/// Taps the banner line whose text is [label] and settles.
Future<void> tapLine(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hidden when nothing is urgent', (tester) async {
    await pumpBanner(
      tester,
      const DashboardAlerts(
        insuranceExpiringSoon: false,
        insuranceExpired: false,
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('hidden when a clock is only due soon, not overdue', (
    tester,
  ) async {
    await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [_dueClock('BCD', ServiceClockSeverity.dueSoon)],
        insuranceExpiringSoon: true,
        insuranceExpired: false,
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('lists overdue gear and opens the tapped item', (tester) async {
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          _dueClock('Regulator', ServiceClockSeverity.overdue, id: 'reg-1'),
          _dueClock('BCD', ServiceClockSeverity.dueSoon, id: 'bcd-1'),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: false,
      ),
    );

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Regulator overdue'), findsOneWidget);
    // Due-soon clocks stay in the strip, not the urgent banner.
    expect(find.text('BCD overdue'), findsNothing);

    // Issue #816: the line names one item, so open that item's detail page
    // rather than dropping the diver on the equipment list.
    await tapLine(tester, 'Regulator overdue');
    expect(spy.location, '/equipment/reg-1');
  });

  testWidgets('each overdue line opens its own item', (tester) async {
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          _dueClock('Regulator', ServiceClockSeverity.overdue, id: 'reg-1'),
          _dueClock('BCD', ServiceClockSeverity.overdue, id: 'bcd-1'),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: false,
      ),
    );

    await tapLine(tester, 'BCD overdue');
    expect(spy.location, '/equipment/bcd-1');
  });

  testWidgets('caps overdue lines and shows a "+N more" overflow', (
    tester,
  ) async {
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          for (var i = 0; i < 6; i++)
            _dueClock('Gear $i', ServiceClockSeverity.overdue),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: false,
      ),
    );

    // First three overdue items are listed; the remaining three collapse.
    expect(find.text('Gear 0 overdue'), findsOneWidget);
    expect(find.text('Gear 2 overdue'), findsOneWidget);
    expect(find.text('Gear 3 overdue'), findsNothing);
    expect(find.text('+3 more'), findsOneWidget);

    // The overflow line names no single item, so it keeps opening the list.
    await tapLine(tester, '+3 more');
    expect(spy.location, '/equipment');
  });

  testWidgets('expired insurance alone navigates to the insurance record', (
    tester,
  ) async {
    final spy = await pumpBanner(
      tester,
      const DashboardAlerts(
        insuranceExpiringSoon: false,
        insuranceExpired: true,
      ),
    );

    expect(find.text('Insurance expired'), findsOneWidget);

    await tapLine(tester, 'Insurance expired');
    expect(spy.location, '/settings/diver-profile/insurance');
  });

  testWidgets('insurance line keeps its own destination alongside gear', (
    tester,
  ) async {
    // Previously one card-wide tap meant overdue gear hijacked the insurance
    // line's destination; each line now routes independently.
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          _dueClock('Regulator', ServiceClockSeverity.overdue, id: 'reg-1'),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: true,
      ),
    );

    expect(find.text('Regulator overdue'), findsOneWidget);
    expect(find.text('Insurance expired'), findsOneWidget);

    await tapLine(tester, 'Insurance expired');
    expect(spy.location, '/settings/diver-profile/insurance');
  });

  testWidgets('every banner line is tappable', (tester) async {
    // Guard mirroring the gauge-strip contract: an InkWell with onTap: null
    // renders identically to a live row, so a dead line is invisible to both
    // the user and the compiler.
    await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          for (var i = 0; i < 5; i++)
            _dueClock('Gear $i', ServiceClockSeverity.overdue, id: 'gear-$i'),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: true,
      ),
    );

    // Scoped to the banner so the count asserts the banner's own contract
    // rather than the surrounding harness's widget structure.
    final inkWells = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(UrgentBanner),
            matching: find.byType(InkWell),
          ),
        )
        .toList();
    // Three capped gear lines, the "+2 more" overflow, and insurance.
    expect(inkWells, hasLength(5));
    for (final ink in inkWells) {
      expect(ink.onTap, isNotNull);
    }
  });
}
