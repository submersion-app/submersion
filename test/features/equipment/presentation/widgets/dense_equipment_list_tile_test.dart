import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_badge_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';

import '../../../../helpers/test_app.dart';

EquipmentItem _makeItem({
  String id = 'test-id',
  String name = 'Test Regulator',
  EquipmentType type = EquipmentType.regulator,
  EquipmentStatus status = EquipmentStatus.active,
  DateTime? lastServiceDate,
  int? serviceIntervalDays,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    type: type,
    status: status,
    lastServiceDate: lastServiceDate,
    serviceIntervalDays: serviceIntervalDays,
  );
}

RollupClock _clock(EquipmentItem item, ServiceClockSeverity severity) {
  final t0 = DateTime(2026, 1, 1);
  return (
    ownerId: item.id,
    ownerName: item.name,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's-${item.id}',
        equipmentId: item.id,
        serviceKindId: 'annual',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'annual',
        name: 'Annual service',
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime.now().add(const Duration(days: 5)),
      severity: severity,
      now: DateTime.now(),
    ),
  );
}

void main() {
  group('DenseEquipmentListTile service label', () {
    for (final (severity, expected) in [
      (ServiceClockSeverity.overdue, StatusColors.light.alert.accent),
      (ServiceClockSeverity.dueSoon, StatusColors.light.warn.accent),
    ]) {
      testWidgets('a ${severity.name} clock uses the status accent', (
        tester,
      ) async {
        final item = _makeItem();
        await tester.pumpWidget(
          testApp(
            overrides: [
              equipmentRollupClockProvider.overrideWith(
                (ref) async => {item.id: _clock(item, severity)},
              ),
            ],
            child: DenseEquipmentListTile(item: item, onTap: () {}),
          ),
        );
        await tester.pumpAndSettle();

        final label = tester.widget<Text>(find.text('Annual service'));
        expect(label.style?.color, expected);
      });
    }
  });

  group('DenseEquipmentListTile', () {
    testWidgets('a screen reader hears the condition badge', (tester) async {
      // The badge is text and colour on screen. The row's Semantics label
      // folds its children's text in, so a screen reader hears the badge
      // after the name; this pins that, since hiding the status from
      // semantics would leave the reader with the name alone.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          overrides: [
            conditionBadgeProvider.overrideWith(
              (ref) async => {
                'test-id': (
                  severity: ConditionSeverity.significant,
                  rule: ConditionRuleId.cellCurrentLimited,
                ),
              },
            ),
          ],
          child: DenseEquipmentListTile(item: _makeItem(), onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final row = tester.getSemantics(find.byType(DenseEquipmentListTile));
      final heard = <String>[];
      void collect(SemanticsNode n) {
        final d = n.getSemanticsData();
        heard
          ..add(d.label)
          ..add(d.value);
        n.visitChildren((c) {
          collect(c);
          return true;
        });
      }

      collect(row);
      final said = heard.where((s) => s.isNotEmpty).join(' | ');
      expect(said, contains('Test Regulator'));
      expect(said, contains('Cell current-limited at high ppO2'));
      semantics.dispose();
    });

    testWidgets('renders name and type label', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(
            item: _makeItem(name: 'My BCD', type: EquipmentType.bcd),
          ),
        ),
      );

      expect(find.text('My BCD'), findsOneWidget);
      expect(find.text('BCD'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('ignores the legacy interval: no badge without a clock', (
      tester,
    ) async {
      // Under the unified model the service badge comes only from the ledger.
      // A legacy-overdue item with no ledger clock shows no badge at all.
      final pastDate = DateTime.now().subtract(const Duration(days: 400));
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: DenseEquipmentListTile(
            item: _makeItem(
              name: 'Old Regulator',
              lastServiceDate: pastDate,
              serviceIntervalDays: 365,
            ),
          ),
        ),
      );

      expect(find.text('Service Due'), findsNothing);
      expect(find.textContaining('Service in'), findsNothing);
    });

    testWidgets('shows non-active status when no service info', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(
            item: _makeItem(
              name: 'Retired Gear',
              status: EquipmentStatus.retired,
            ),
          ),
        ),
      );

      expect(find.text('Retired Gear'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets(
      'shows no service status for active item with no service info',
      (tester) async {
        await tester.pumpWidget(
          testApp(child: DenseEquipmentListTile(item: _makeItem())),
        );

        expect(find.text('Test Regulator'), findsOneWidget);
        // No service status text should appear
        expect(find.text('Service Due'), findsNothing);
      },
    );

    testWidgets('applies selection highlight when isSelected is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(item: _makeItem(), isSelected: true),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });

    testWidgets('no selection highlight when isSelected is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(item: _makeItem(), isSelected: false),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(
            item: _makeItem(),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });
}
