import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Components card read the own-clocks map while the equipment list read
/// the rollup, so a part whose own sub-part was overdue got a dot in the
/// list and none here. Both now read the rollup (#2260).
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  final part = EquipmentComponent(
    id: 'edge1',
    parentEquipmentId: 'reg',
    componentEquipmentId: 'hose',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// A clock owned by something *below* the hose, which is exactly the case
  /// the own-clocks map cannot see.
  final subPartClock = (
    ownerId: 'oring',
    ownerName: 'O-ring',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'oring',
        serviceKindId: 'k1',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k1',
        name: 'General service',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2025, 6, 1),
      severity: ServiceClockSeverity.overdue,
      now: now,
    ),
  );

  Widget wrap() => ProviderScope(
    overrides: [
      equipmentComponentsProvider('reg').overrideWith((ref) async => [part]),
      equipmentPartOfProvider(
        'reg',
      ).overrideWith((ref) async => const <PartOfEntry>[]),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      // The own-clocks map is deliberately empty: the hose itself is fine,
      // only something inside it is overdue.
      equipmentWorstClockProvider.overrideWith((ref) async => const {}),
      equipmentRollupClockProvider.overrideWith(
        (ref) async => {'hose': subPartClock},
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ComponentsCard(equipmentId: 'reg')),
    ),
  );

  testWidgets('a part whose own sub-part is overdue gets the alert dot', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final dots = tester
        .widgetList<Icon>(find.byIcon(Icons.circle))
        .map((i) => i.color)
        .toList();
    expect(
      dots,
      contains(StatusColors.light.alert.accent),
      reason:
          'the rollup must reach the Components card, or the list and the '
          'card disagree about the same part',
    );
  });
}
