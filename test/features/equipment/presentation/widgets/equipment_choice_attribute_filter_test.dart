import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Finder chip(String key, String option) =>
      find.byKey(ValueKey('equipment_filter_attr_${key}_$option'));

  testWidgets('hose offers its type options and builds one condition', (
    tester,
  ) async {
    var conditions = <EquipmentAttrCondition>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => EquipmentChoiceAttributeFilter(
              type: EquipmentType.hose,
              conditions: conditions,
              onChanged: (next) => setState(() => conditions = next),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hose type'), findsOneWidget);
    expect(find.text('LP (low pressure)'), findsOneWidget);

    await tester.tap(chip('hose_type', 'hp'));
    await tester.pumpAndSettle();
    await tester.tap(chip('hose_type', 'lpi'));
    await tester.pumpAndSettle();
    expect(conditions, [
      const EquipmentAttrCondition(
        key: 'hose_type',
        choices: {'hp', 'lpi'},
        types: {EquipmentType.hose},
      ),
    ]);
    expect(tester.widget<FilterChip>(chip('hose_type', 'hp')).selected, isTrue);

    await tester.tap(chip('hose_type', 'hp'));
    await tester.pumpAndSettle();
    await tester.tap(chip('hose_type', 'lpi'));
    await tester.pumpAndSettle();
    expect(conditions, isEmpty);
  });

  testWidgets('toggling one field keeps the other fields\' conditions', (
    tester,
  ) async {
    // Fins carry two choice fields: heel type and blade style.
    final defs = EquipmentChoiceAttributeFilter.choiceDefsFor(
      EquipmentType.fins,
    );
    expect(defs.length, greaterThanOrEqualTo(2));
    final first = defs[0];
    final second = defs[1];

    var conditions = <EquipmentAttrCondition>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => EquipmentChoiceAttributeFilter(
                type: EquipmentType.fins,
                conditions: conditions,
                onChanged: (next) => setState(() => conditions = next),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(chip(second.key, second.choiceKeys.first));
    await tester.pumpAndSettle();
    await tester.tap(chip(first.key, first.choiceKeys.first));
    await tester.pumpAndSettle();

    // Both survive, in catalog order rather than tap order.
    expect(conditions.map((c) => c.key), [first.key, second.key]);
    expect(conditions.last.choices, {second.choiceKeys.first});
  });

  testWidgets('a type with no choice fields renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EquipmentChoiceAttributeFilter(
            type: EquipmentType.other,
            conditions: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  test('choiceDefsFor lists spec choice fields only', () {
    final keys = EquipmentChoiceAttributeFilter.choiceDefsFor(
      EquipmentType.hose,
    ).map((d) => d.key);
    expect(keys, ['hose_type']);
  });
}
