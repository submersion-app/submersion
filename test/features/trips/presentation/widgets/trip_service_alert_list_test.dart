import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final now = DateTime.now();
  final t0 = DateTime(2025, 1, 1);

  DueClock hydroAlert() {
    final kind = ServiceKind(
      id: 'hydro',
      name: 'Hydrostatic test',
      defaultIntervalDays: 1825,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    return (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: 'e1',
          serviceKindId: 'hydro',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: kind,
        anchor: t0,
        dueDate: now.add(const Duration(days: 5)),
        severity: ServiceClockSeverity.dueSoon,
        now: now,
      ),
    );
  }

  Widget buildList(List<DueClock> alerts, {bool showItemName = true}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: TripServiceAlertList(
              alerts: alerts,
              showItemName: showItemName,
            ),
          ),
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
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('lists each blocking item with when it falls due', (
    tester,
  ) async {
    await tester.pumpWidget(buildList([hydroAlert()]));
    await tester.pumpAndSettle();

    expect(find.text('AL80'), findsOneWidget);
    expect(find.textContaining('Hydrostatic test due'), findsOneWidget);
  });

  testWidgets('inside one item\'s sheet a row reads only its clock (#2882)', (
    tester,
  ) async {
    await tester.pumpWidget(buildList([hydroAlert()], showItemName: false));
    await tester.pumpAndSettle();

    expect(find.text('AL80'), findsNothing);
    final row = tester.widget<ListTile>(find.byType(ListTile));
    expect((row.title! as Text).data, startsWith('Hydrostatic test due'));
    expect(row.subtitle, isNull);
    // A screen reader hears the clock once, not the item name: one button
    // node carries it, and that node is the one that taps.
    expect(
      find.bySemanticsLabel(RegExp('^Hydrostatic test due')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byType(ListTile))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    // The row still opens its item.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('EQUIPMENT_PAGE'), findsOneWidget);
  });

  test('two blocking clocks on one item still count as 1 item', () {
    final vipKind = ServiceKind(
      id: 'vip',
      name: 'Visual inspection (VIP)',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    final vipAlert = (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's2',
          equipmentId: 'e1',
          serviceKindId: 'vip',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: vipKind,
        anchor: t0,
        dueDate: now.add(const Duration(days: 3)),
        severity: ServiceClockSeverity.dueSoon,
        now: now,
      ),
    );
    // Per-clock alerts collapse to distinct equipment items in the count.
    expect(tripServiceAlertItemCount([hydroAlert(), vipAlert]), 1);
    expect(tripServiceAlertsAnyOverdue([hydroAlert(), vipAlert]), isFalse);
  });

  testWidgets('a due-soon alert marks its row with the warn palette', (
    tester,
  ) async {
    await tester.pumpWidget(buildList([hydroAlert()]));
    await tester.pumpAndSettle();

    final dot = tester.widget<Icon>(find.byIcon(Icons.circle));
    expect(dot.color, StatusColors.light.warn.accent);
  });

  testWidgets('an overdue alert reads overdue and taps through to the item', (
    tester,
  ) async {
    final overdue = (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: 'e1',
          serviceKindId: 'hydro',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'hydro',
          name: 'Hydrostatic test',
          defaultIntervalDays: 1825,
          isBuiltIn: true,
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: now.subtract(const Duration(days: 30)),
        severity: ServiceClockSeverity.overdue,
        now: now,
      ),
    );
    await tester.pumpWidget(buildList([overdue]));
    await tester.pumpAndSettle();

    expect(tripServiceAlertsAnyOverdue([overdue]), isTrue);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.circle)).color,
      StatusColors.light.alert.accent,
    );

    // Overdue clocks phrase without a due date.
    expect(find.text('Hydrostatic test overdue'), findsOneWidget);

    // Tapping the row navigates to the item.
    await tester.tap(find.text('AL80'));
    await tester.pumpAndSettle();
    expect(find.text('EQUIPMENT_PAGE'), findsOneWidget);
  });

  testWidgets(
    'usage-overdue clock with a future dueDate still reads as overdue',
    (tester) async {
      // Overdue on dive count while the date trigger is still in the future.
      final usageOverdue = (
        item: const EquipmentItem(
          id: 'e1',
          name: 'Apeks XTX50',
          type: EquipmentType.regulator,
        ),
        status: ServiceClockStatus(
          schedule: ServiceSchedule(
            id: 's1',
            equipmentId: 'e1',
            serviceKindId: 'reg',
            createdAt: t0,
            updatedAt: t0,
          ),
          kind: ServiceKind(
            id: 'reg',
            name: 'Reg service',
            defaultIntervalDives: 100,
            isBuiltIn: true,
            createdAt: t0,
            updatedAt: t0,
          ),
          anchor: t0,
          dueDate: now.add(const Duration(days: 200)), // future
          divesRemaining: -4,
          severity: ServiceClockSeverity.overdue,
          now: now,
        ),
      );
      await tester.pumpWidget(buildList([usageOverdue]));
      await tester.pumpAndSettle();

      expect(find.text('Reg service overdue'), findsOneWidget);
      // Must not present the future date via the "{kind} due {date}" phrasing.
      expect(find.textContaining('Reg service due'), findsNothing);
    },
  );
}
