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
