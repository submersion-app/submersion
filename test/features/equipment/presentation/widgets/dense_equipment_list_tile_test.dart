import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
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

void main() {
  group('DenseEquipmentListTile', () {
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

    testWidgets('shows Service Due in error color when service is overdue', (
      tester,
    ) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 400));
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(
            item: _makeItem(
              name: 'Old Regulator',
              lastServiceDate: pastDate,
              serviceIntervalDays: 365,
            ),
          ),
        ),
      );

      expect(find.text('Service Due'), findsOneWidget);
    });

    testWidgets('shows days until service when service is upcoming', (
      tester,
    ) async {
      final recentDate = DateTime.now().subtract(const Duration(days: 10));
      await tester.pumpWidget(
        testApp(
          child: DenseEquipmentListTile(
            item: _makeItem(
              name: 'Recent Service',
              lastServiceDate: recentDate,
              serviceIntervalDays: 365,
            ),
          ),
        ),
      );

      // Should show "In X days" text
      final serviceFinder = find.textContaining('In ');
      expect(serviceFinder, findsOneWidget);
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
