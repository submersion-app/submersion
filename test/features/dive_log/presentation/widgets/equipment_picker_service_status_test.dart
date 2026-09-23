import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Choosing gear for a dive is the moment a service warning is most
/// actionable, so the picker rows carry it.
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );

  RollupClock clock({
    ServiceClockSeverity severity = ServiceClockSeverity.overdue,
  }) => (
    ownerId: 'reg',
    ownerName: 'Cold water reg',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'reg',
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
      severity: severity,
      now: now,
    ),
  );

  Widget build({Map<String, RollupClock> map = const {}}) => ProviderScope(
    overrides: [
      activeEquipmentProvider.overrideWith((ref) async => const [reg, fins]),
      equipmentArrangementProvider.overrideWithValue(
        EquipmentArrangement.defaults.copyWith(groupByType: false),
      ),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      equipmentRollupClockProvider.overrideWith((ref) async => map),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EquipmentPickerSheet(
          scrollController: ScrollController(),
          selectedEquipmentIds: const {},
          onEquipmentSelected: (_) {},
        ),
      ),
    ),
  );

  testWidgets('an overdue item says so in the picker row', (tester) async {
    await tester.pumpWidget(build(map: {'reg': clock()}));
    await tester.pumpAndSettle();
    expect(find.text('General service overdue'), findsOneWidget);
  });

  testWidgets('an item with no clock carries no status', (tester) async {
    await tester.pumpWidget(build(map: {'reg': clock()}));
    await tester.pumpAndSettle();
    // Only the regulator is flagged; the fins row stays quiet.
    expect(find.text('Jets'), findsOneWidget);
    expect(find.textContaining('overdue'), findsOneWidget);
  });

  testWidgets('an ok clock carries no status', (tester) async {
    await tester.pumpWidget(
      build(map: {'reg': clock(severity: ServiceClockSeverity.ok)}),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('overdue'), findsNothing);
  });
}
