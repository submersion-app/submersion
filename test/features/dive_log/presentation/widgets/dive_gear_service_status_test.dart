import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Overdue gear is a statement about today, so the gear tree carries it
/// only where the diver can still act: dive edit, and a planned or future
/// dive. A logged past dive stays a faithful record of that dive rather
/// than gaining a red mark about today's service state.
void main() {
  // find.bySemanticsLabel only sees nodes while semantics is enabled, so
  // the handle has to outlive every assertion in this file.
  //
  // Every assertion below uses the RegExp form deliberately. ListTile
  // merges its descendants into one node, so a row's accessible name is
  // "Cold water reg\nGeneral service overdue\nRegulator", never the
  // status line alone. The exact-string overload can never match here.
  late SemanticsHandle semantics;
  setUp(() => semantics = TestWidgetsFlutterBinding.instance.ensureSemantics());
  tearDown(() => semantics.dispose());

  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const links = [GearLink(item: reg)];

  RollupClock clock({
    String ownerId = 'reg',
    String ownerName = 'Cold water reg',
    ServiceClockSeverity severity = ServiceClockSeverity.overdue,
  }) => (
    ownerId: ownerId,
    ownerName: ownerName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: ownerId,
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

  Widget build({
    required bool showServiceStatus,
    Map<String, RollupClock> map = const {},
  }) => ProviderScope(
    overrides: [
      equipmentArrangementProvider.overrideWithValue(
        EquipmentArrangement.defaults.copyWith(groupByType: false),
      ),
      equipmentSetsProvider.overrideWith((ref) async => const []),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.empty,
      ),
      activeComponentIdsProvider.overrideWith((ref) async => const <String>{}),
      equipmentRollupClockProvider.overrideWith((ref) async => map),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiveGearTreeView(
            links: links,
            showServiceStatus: showServiceStatus,
          ),
        ),
      ),
    ),
  );

  testWidgets('a dive being edited shows overdue gear', (tester) async {
    await tester.pumpWidget(
      build(showServiceStatus: true, map: {'reg': clock()}),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsOneWidget,
    );
  });

  testWidgets('a logged past dive stays clean', (tester) async {
    await tester.pumpWidget(
      build(showServiceStatus: false, map: {'reg': clock()}),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsNothing,
    );
  });

  testWidgets('gear with an ok clock carries no mark even when shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        showServiceStatus: true,
        map: {'reg': clock(severity: ServiceClockSeverity.ok)},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsNothing,
    );
  });

  testWidgets('an overdue part names itself on the assembly row', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        showServiceStatus: true,
        map: {'reg': clock(ownerId: 'hose', ownerName: 'Long hose')},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Long hose')),
      findsOneWidget,
      reason: 'a rolled-up clock must say which part is overdue',
    );
  });
}
