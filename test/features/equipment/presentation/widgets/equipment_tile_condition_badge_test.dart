import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_badge_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Condition findings on both list tiles (phase 4b): the badge is the worst
/// of the clock and the finding; info never badges.
void main() {
  final t0 = DateTime(2025, 1, 1);
  const item = EquipmentItem(
    id: 'e1',
    name: 'CCR',
    type: EquipmentType.rebreather,
  );

  RollupClock clock(ServiceClockSeverity severity) => (
    ownerId: item.id,
    ownerName: item.name,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: item.id,
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
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  ConditionBadge badge(ConditionSeverity severity) => (
    severity: severity,
    rule: severity == ConditionSeverity.significant
        ? ConditionRuleId.cellOutputLow
        : ConditionRuleId.cellOutputDeclining,
  );

  Widget wrap(
    Widget child, {
    Map<String, RollupClock> worst = const {},
    Map<String, ConditionBadge> badges = const {},
  }) => ProviderScope(
    overrides: [
      equipmentRollupClockProvider.overrideWith((ref) async => worst),
      conditionBadgeProvider.overrideWith((ref) async => badges),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.empty,
      ),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  for (final (name, build) in [
    ('DenseEquipmentListTile', () => const DenseEquipmentListTile(item: item)),
    ('EquipmentListTile', () => const EquipmentListTile(item: item)),
  ]) {
    group(name, () {
      testWidgets('a significant finding badges in the error colour', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(build(), badges: {'e1': badge(ConditionSeverity.significant)}),
        );
        await tester.pumpAndSettle();
        final scheme = Theme.of(
          tester.element(find.byType(Scaffold)),
        ).colorScheme;
        expect(find.text('Cell output low'), findsOneWidget);
        expect(colorOf(tester, 'Cell output low'), scheme.error);
      });

      testWidgets('a caution finding badges in the tertiary colour', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(build(), badges: {'e1': badge(ConditionSeverity.caution)}),
        );
        await tester.pumpAndSettle();
        final scheme = Theme.of(
          tester.element(find.byType(Scaffold)),
        ).colorScheme;
        expect(colorOf(tester, 'Cell output declining'), scheme.tertiary);
      });

      testWidgets('a significant finding beats a due-soon clock', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            build(),
            worst: {'e1': clock(ServiceClockSeverity.dueSoon)},
            badges: {'e1': badge(ConditionSeverity.significant)},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cell output low'), findsOneWidget);
        expect(find.textContaining('Hydrostatic'), findsNothing);
      });

      testWidgets('an overdue clock beats a caution finding', (tester) async {
        await tester.pumpWidget(
          wrap(
            build(),
            worst: {'e1': clock(ServiceClockSeverity.overdue)},
            badges: {'e1': badge(ConditionSeverity.caution)},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Hydrostatic test'), findsOneWidget);
        expect(find.text('Cell output declining'), findsNothing);
      });
    });
  }
}
