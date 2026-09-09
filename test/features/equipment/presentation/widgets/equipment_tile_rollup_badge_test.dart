import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The list badge reads the rollup, so a due hose lights its regulator and
/// the badge says which part (issue #1487).
void main() {
  final t0 = DateTime(2025, 1, 1);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );

  RollupClock rollup(
    String ownerId,
    String ownerName,
    ServiceClockSeverity severity,
  ) => (
    ownerId: ownerId,
    ownerName: ownerName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: ownerId,
        serviceKindId: 'hose-swap',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hose-swap',
        name: 'Hose replacement',
        defaultIntervalDays: 1825,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  Widget wrap(Widget child, Map<String, RollupClock> map) => ProviderScope(
    overrides: [
      equipmentRollupClockProvider.overrideWith((ref) async => map),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.empty,
      ),
      activeEquipmentProvider.overrideWith((ref) async => const [reg]),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('standard tile names the part that owns the overdue clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const EquipmentListTile(item: reg), {
        'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.overdue),
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Necklace hose: Hose replacement overdue'),
      findsOneWidget,
    );
  });

  testWidgets(
    'standard tile keeps the plain label when the item owns the clock',
    (tester) async {
      await tester.pumpWidget(
        wrap(const EquipmentListTile(item: reg), {
          'reg': rollup('reg', 'Cold water reg', ServiceClockSeverity.dueSoon),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hose replacement'), findsOneWidget);
    },
  );

  testWidgets('an ok rollup shows no badge', (tester) async {
    await tester.pumpWidget(
      wrap(const EquipmentListTile(item: reg), {
        'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.ok),
      }),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Hose replacement'), findsNothing);
  });

  testWidgets('a plain item keeps the one-line tile (no empty subtitle)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EquipmentListTile(item: reg), const {}));
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.subtitle, isNull);
  });

  testWidgets('dense tile shows the part name for a descendant clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const DenseEquipmentListTile(item: reg), {
        'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.overdue),
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Necklace hose: Hose replacement'), findsOneWidget);
  });
}
