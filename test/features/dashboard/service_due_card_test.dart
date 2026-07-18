import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/widgets/service_due_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 16);

  DueClock clock(
    String itemId,
    String itemName,
    String kindName,
    ServiceClockSeverity severity,
  ) {
    final kind = ServiceKind(
      id: kindName.toLowerCase(),
      name: kindName,
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    return (
      item: EquipmentItem(id: itemId, name: itemName, type: EquipmentType.tank),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-$itemId-${kind.id}',
          equipmentId: itemId,
          serviceKindId: kind.id,
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: kind,
        anchor: t0,
        dueDate: severity == ServiceClockSeverity.overdue
            ? DateTime(2026, 1, 1)
            : DateTime(2026, 8, 1),
        severity: severity,
        now: now,
      ),
    );
  }

  Widget buildCard(List<DueClock> due) {
    return ProviderScope(
      overrides: [dueClocksProvider.overrideWith((ref) async => due)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ServiceDueCard()),
      ),
    );
  }

  testWidgets('hidden when nothing is due', (tester) async {
    await tester.pumpWidget(buildCard(const []));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('lists overdue clocks with item and kind', (tester) async {
    await tester.pumpWidget(
      buildCard([
        clock('e1', 'AL80', 'Hydro', ServiceClockSeverity.overdue),
        clock('e2', 'Apeks XTX50', 'Reg service', ServiceClockSeverity.dueSoon),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service due'), findsOneWidget);
    expect(find.text('AL80'), findsOneWidget);
    expect(find.textContaining('Hydro'), findsOneWidget);
    expect(find.text('Apeks XTX50'), findsOneWidget);
  });

  testWidgets(
    'usage-triggered overdue with a future dueDate reads as Overdue, not Due',
    (tester) async {
      final kind = ServiceKind(
        id: 'reg',
        name: 'Reg service',
        defaultIntervalDives: 100,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      );
      // Overdue on dive count while the date trigger is still months out.
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
          kind: kind,
          anchor: t0,
          dueDate: DateTime(2026, 12, 1), // future
          divesRemaining: -3,
          severity: ServiceClockSeverity.overdue,
          now: now,
        ),
      );

      await tester.pumpWidget(buildCard([usageOverdue]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Overdue'), findsOneWidget);
      // The future date trigger must not be surfaced at all (it would only
      // appear via the "Due {date}"/"Overdue since {date}" phrasings, both
      // wrong for a usage-triggered overdue clock).
      expect(find.textContaining('2026'), findsNothing);
    },
  );

  testWidgets(
    'at the exact due instant reads generic Overdue, not "Overdue since"',
    (tester) async {
      // dueDate == now: the engine boundary is strict-overdue-after-dueDate, so
      // the card must show the generic "Overdue" label and not surface the date
      // via "Overdue since {date}".
      final boundary = (
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
            name: 'Hydro',
            defaultIntervalDays: 1825,
            isBuiltIn: true,
            createdAt: t0,
            updatedAt: t0,
          ),
          anchor: t0,
          dueDate: now, // exactly now
          severity: ServiceClockSeverity.overdue,
          now: now,
        ),
      );

      await tester.pumpWidget(buildCard([boundary]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Overdue'), findsOneWidget);
      expect(find.textContaining('since'), findsNothing);
    },
  );

  testWidgets('truncates past five rows with a +N more footer', (tester) async {
    await tester.pumpWidget(
      buildCard([
        for (var i = 0; i < 7; i++)
          clock('e$i', 'Item $i', 'Kind$i', ServiceClockSeverity.overdue),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('+2 more'), findsOneWidget);
  });
}
