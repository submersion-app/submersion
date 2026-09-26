import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/installed_in_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/part_of_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A part's page names the assembly it sits inside, and an assembly's page
/// names its parents. Both are gear the diver may need to service, so both
/// carry the signal.
///
/// Every assertion uses the RegExp form of bySemanticsLabel: ListTile and
/// the InkWell row merge their descendants into one node, so the accessible
/// name contains the status line rather than equalling it.
void main() {
  late SemanticsHandle semantics;
  setUp(() => semantics = TestWidgetsFlutterBinding.instance.ensureSemantics());
  tearDown(() => semantics.dispose());

  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  const host = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const part = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
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

  Widget wrap(Widget child, {Map<String, RollupClock> map = const {}}) =>
      ProviderScope(
        overrides: [
          equipmentRollupClockProvider.overrideWith((ref) async => map),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  final entry = (
    edge: EquipmentComponent(
      id: 'e1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'hose',
      parent: host,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    rootNames: const <String>[],
  );

  testWidgets('PartOfSection flags an overdue parent assembly', (tester) async {
    await tester.pumpWidget(
      wrap(PartOfSection(entries: [entry]), map: {'reg': clock()}),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsOneWidget,
    );
  });

  testWidgets('PartOfSection stays quiet for an ok parent', (tester) async {
    await tester.pumpWidget(
      wrap(
        PartOfSection(entries: [entry]),
        map: {'reg': clock(severity: ServiceClockSeverity.ok)},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsNothing,
    );
  });

  testWidgets('InstalledInRow flags an overdue host', (tester) async {
    await tester.pumpWidget(
      wrap(
        const InstalledInRow(
          part: part,
          host: host,
          units: UnitFormatter(AppSettings()),
        ),
        map: {'reg': clock()},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsOneWidget,
    );
  });

  testWidgets('InstalledInRow stays quiet for an ok host', (tester) async {
    await tester.pumpWidget(
      wrap(
        const InstalledInRow(
          part: part,
          host: host,
          units: UnitFormatter(AppSettings()),
        ),
        map: {'reg': clock(severity: ServiceClockSeverity.ok)},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('General service overdue')),
      findsNothing,
    );
  });
}
