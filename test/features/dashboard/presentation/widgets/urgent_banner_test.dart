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

DueClock _dueClock(String name, ServiceClockSeverity severity) => (
  item: EquipmentItem(id: name, name: name, type: EquipmentType.regulator),
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
      GoRoute(path: '/equipment', builder: (_, _) => stub('/equipment')),
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

  testWidgets('lists overdue gear and navigates to gear', (tester) async {
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          _dueClock('Regulator', ServiceClockSeverity.overdue),
          _dueClock('BCD', ServiceClockSeverity.dueSoon),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: false,
      ),
    );

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Regulator overdue'), findsOneWidget);
    // Due-soon clocks stay in the strip, not the urgent banner.
    expect(find.text('BCD overdue'), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(spy.location, '/equipment');
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

    // Tap still opens the gear list.
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(spy.location, '/settings/diver-profile/insurance');
  });

  testWidgets('overdue gear wins the destination over expired insurance', (
    tester,
  ) async {
    final spy = await pumpBanner(
      tester,
      DashboardAlerts(
        serviceClocksDue: [
          _dueClock('Regulator', ServiceClockSeverity.overdue),
        ],
        insuranceExpiringSoon: false,
        insuranceExpired: true,
      ),
    );

    expect(find.text('Regulator overdue'), findsOneWidget);
    expect(find.text('Insurance expired'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(spy.location, '/equipment');
  });
}
