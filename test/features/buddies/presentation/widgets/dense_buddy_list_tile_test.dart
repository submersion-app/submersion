import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/dense_buddy_list_tile.dart';

import '../../../../helpers/test_app.dart';

Buddy _makeBuddy({
  String id = 'test-id',
  String name = 'Alice Smith',
  CertificationLevel? certificationLevel = CertificationLevel.openWater,
  CertificationAgency? certificationAgency,
}) {
  final now = DateTime(2024, 1, 1);
  return Buddy(
    id: id,
    name: name,
    certificationLevel: certificationLevel,
    certificationAgency: certificationAgency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('DenseBuddyListTile', () {
    testWidgets('renders buddy name', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(name: 'Bob Jones')),
        ),
      );

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders cert level when present', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(
            buddy: _makeBuddy(
              certificationLevel: CertificationLevel.advancedOpenWater,
            ),
          ),
        ),
      );

      expect(find.text('Advanced Open Water'), findsOneWidget);
    });

    testWidgets('renders dive count when provided', (tester) async {
      await tester.pumpWidget(
        testApp(child: DenseBuddyListTile(buddy: _makeBuddy(), diveCount: 42)),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('handles null cert level gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(
            buddy: _makeBuddy(certificationLevel: null),
          ),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
      // Cert level placeholder is empty — no cert text present
      expect(find.text('Open Water'), findsNothing);
    });

    testWidgets('handles null dive count gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(), diveCount: null),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
    });

    testWidgets('applies selection highlight when isSelected is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DenseBuddyListTile(buddy: _makeBuddy(), isSelected: true),
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
          child: DenseBuddyListTile(buddy: _makeBuddy(), isSelected: false),
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
          child: DenseBuddyListTile(
            buddy: _makeBuddy(),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });
}
