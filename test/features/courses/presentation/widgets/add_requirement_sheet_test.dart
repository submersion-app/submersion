import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/widgets/add_requirement_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  const unitA = EquipmentItem(
    id: 'rb-1',
    name: 'Unit A',
    type: EquipmentType.rebreather,
  );
  const fins = EquipmentItem(
    id: 'fins-1',
    name: 'Fins',
    type: EquipmentType.fins,
  );

  /// Opens the sheet from a button and returns a getter for what it popped.
  Future<RequirementDraft? Function()> openSheet(
    WidgetTester tester, {
    CourseRequirement? existing,
  }) async {
    RequirementDraft? popped;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          allEquipmentProvider.overrideWith((ref) async => [unitA, fins]),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped = await showAddRequirementSheet(
              context,
              existing: existing,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

  Finder targetField() => find.byType(TextField).at(1);

  CourseRequirement ccrRequirement(String name, String equipmentId) {
    final now = DateTime(2026);
    return CourseRequirement(
      id: 'req-1',
      courseId: 'course-1',
      name: name,
      kind: RequirementKind.ccrHours,
      targetCount: 20,
      equipmentId: equipmentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('a CCR hours requirement asks for hours and a rebreather', (
    tester,
  ) async {
    final result = await openSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'CCR time');
    await tester.tap(find.text('CCR hours'));
    await tester.pumpAndSettle();
    expect(find.text('Required hours'), findsOneWidget);

    await tester.enterText(targetField(), '40');
    await tester.tap(find.text('Any rebreather'));
    await tester.pumpAndSettle();
    // Only rebreathers are offered.
    expect(find.text('Fins'), findsNothing);
    await tester.tap(find.text('Unit A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final draft = result()!;
    expect(draft.kind, RequirementKind.ccrHours);
    expect(draft.targetCount, 40);
    expect(draft.equipmentId, 'rb-1');
    expect(draft.queryJson, isNull);
  });

  testWidgets('a blank, zero or fractional target keeps Save disabled', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).first, 'Training dives');
    await tester.pumpAndSettle();

    for (final text in ['', '0', '2.5']) {
      await tester.enterText(targetField(), text);
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNull, reason: '"$text"');
    }

    await tester.enterText(targetField(), '3');
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a removed rebreather stays selected rather than widening', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      existing: ccrRequirement('CCR time on the old unit', 'rb-gone'),
    );

    expect(find.text('Removed rebreather'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result()!.equipmentId, 'rb-gone');
  });

  testWidgets('a check-off item drops the rebreather and counts once', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      existing: ccrRequirement('Swim test', 'rb-1'),
    );

    await tester.tap(find.text('Check-off item'));
    await tester.pumpAndSettle();
    expect(find.text('Required hours'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final draft = result()!;
    expect(draft.kind, RequirementKind.checklist);
    expect(draft.targetCount, 1);
    expect(draft.equipmentId, isNull);
  });

  testWidgets('a dive search cannot be saved without a search', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).first, 'Deep dives');
    await tester.tap(find.text('Dives matching a search'));
    await tester.pumpAndSettle();

    expect(find.text('Dive search'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });
}
