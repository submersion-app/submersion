import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  Future<void> pumpSection(
    WidgetTester tester, {
    required EquipmentType type,
    required Map<String, EquipmentAttribute> values,
    required void Function(EquipmentAttribute) onChanged,
    void Function(String)? onCleared,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentAttributeFormSection(
              type: type,
              values: values,
              units: const UnitFormatter(AppSettings()),
              onChanged: onChanged,
              onCleared: onCleared ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wetsuit renders thickness field and emits parsed value', (
    tester,
  ) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: const {},
      onChanged: (a) => emitted = a,
    );

    expect(find.text('Thickness (mm)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('attr-field-thickness_mm')),
      '5/4',
    );
    expect(emitted, isNotNull);
    expect(emitted!.key, 'thickness_mm');
    expect(emitted!.valueText, '5/4');
    expect(emitted!.valueNum, 5.0);
  });

  testWidgets('tank renders no thickness but has valve choices', (
    tester,
  ) async {
    await pumpSection(
      tester,
      type: EquipmentType.tank,
      values: const {},
      onChanged: (_) {},
    );
    expect(find.text('Thickness (mm)'), findsNothing);
    expect(find.byKey(const ValueKey('attr-field-valve_type')), findsOneWidget);
  });

  testWidgets('flag toggles emit 0/1', (tester) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      values: const {},
      onChanged: (a) => emitted = a,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('attr-field-cold_water_rated')),
    );
    await tester.tap(find.byKey(const ValueKey('attr-field-cold_water_rated')));
    await tester.pump();
    expect(emitted!.valueNum, 1.0);
  });

  testWidgets('number field keeps value on transient invalid input, clears '
      'only on empty', (tester) async {
    final cleared = <String>[];
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: const {},
      onChanged: (a) => emitted = a,
      onCleared: cleared.add,
    );
    final buoyancy = find.byKey(const ValueKey('attr-field-buoyancy_kg'));
    await tester.ensureVisible(buoyancy);

    // Transient invalid input (typing the sign of a negative number first)
    // must not drop the attribute from pending state.
    await tester.enterText(buoyancy, '-');
    expect(cleared, isEmpty);

    // Completing a valid number emits it.
    await tester.enterText(buoyancy, '-2.5');
    expect(emitted?.key, 'buoyancy_kg');
    expect(emitted?.valueNum, closeTo(-2.5, 0.001));

    // A comma decimal separator (non-dot locales) parses the same as a dot.
    await tester.enterText(buoyancy, '7,5');
    expect(emitted?.valueNum, closeTo(7.5, 0.001));

    // Emptying the field is the only thing that clears it.
    await tester.enterText(buoyancy, '');
    expect(cleared, contains('buoyancy_kg'));
  });

  testWidgets('text field emits trimmed value and clears when emptied', (
    tester,
  ) async {
    final cleared = <String>[];
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.tank,
      values: const {},
      onChanged: (a) => emitted = a,
      onCleared: cleared.add,
    );
    final field = find.byKey(const ValueKey('attr-field-tank_identifier'));
    await tester.ensureVisible(field);

    await tester.enterText(field, '  DIN-42  ');
    expect(emitted?.key, 'tank_identifier');
    expect(emitted?.valueText, 'DIN-42');

    await tester.enterText(field, '   ');
    expect(cleared, contains('tank_identifier'));
  });

  testWidgets('choice dropdown emits the selected option key', (tester) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: const {},
      onChanged: (a) => emitted = a,
    );
    final dropdown = find.byKey(const ValueKey('attr-field-suit_style'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(attributeChoiceLabel(l10n, 'suit_style', 'shorty')).last,
    );
    await tester.pumpAndSettle();

    expect(emitted?.key, 'suit_style');
    expect(emitted?.valueText, 'shorty');
  });

  testWidgets('choice dropdown clears when the -- option is chosen', (
    tester,
  ) async {
    final cleared = <String>[];
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: {
        'suit_style': EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: 'suit_style',
          valueText: 'full',
        ),
      },
      onChanged: (_) {},
      onCleared: cleared.add,
    );
    final dropdown = find.byKey(const ValueKey('attr-field-suit_style'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('--').last);
    await tester.pumpAndSettle();

    expect(cleared, contains('suit_style'));
  });

  testWidgets('number field renders the preset value in display units', (
    tester,
  ) async {
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: {
        'buoyancy_kg': EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: 'buoyancy_kg',
          valueNum: 3.5,
        ),
      },
      onChanged: (_) {},
    );
    // Metric formatter -> the stored kg value shows verbatim in the field.
    expect(find.text('3.5'), findsOneWidget);
  });

  testWidgets(
    'date field shows the formatted value and a working clear button',
    (tester) async {
      final cleared = <String>[];
      const formatter = UnitFormatter(AppSettings());
      final date = DateTime(2026, 3, 14);
      await pumpSection(
        tester,
        type: EquipmentType.tank,
        values: {
          'last_hydro_test': EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'last_hydro_test',
            valueNum: date.millisecondsSinceEpoch.toDouble(),
          ),
        },
        onChanged: (_) {},
        onCleared: cleared.add,
      );
      expect(find.text(formatter.formatDate(date)), findsOneWidget);

      final clearButton = find.descendant(
        of: find.byKey(const ValueKey('attr-field-last_hydro_test')),
        matching: find.byIcon(Icons.clear),
      );
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      expect(cleared, contains('last_hydro_test'));
    },
  );

  testWidgets('date field opens the picker and emits the chosen date', (
    tester,
  ) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.tank,
      values: const {},
      onChanged: (a) => emitted = a,
    );
    final field = find.byKey(
      const ValueKey('attr-field-last_visual_inspection'),
    );
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();

    // Confirm the default (today) selection in the opened date picker.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(emitted?.key, 'last_visual_inspection');
    expect(emitted?.valueNum, isNotNull);
  });

  testWidgets('date field clamps a stored future date so the picker opens', (
    tester,
  ) async {
    // A future value would trip showDatePicker's initialDate <= lastDate
    // assertion without the clamp.
    final future = DateTime.now().add(const Duration(days: 3650));
    await pumpSection(
      tester,
      type: EquipmentType.tank,
      values: {
        'last_hydro_test': EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: 'last_hydro_test',
          valueNum: future.millisecondsSinceEpoch.toDouble(),
        ),
      },
      onChanged: (_) {},
    );
    final field = find.byKey(const ValueKey('attr-field-last_hydro_test'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle(); // would throw if the assertion fired

    expect(find.text('OK'), findsOneWidget); // picker opened successfully
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('text and thickness fields render their preset values', (
    tester,
  ) async {
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: {
        'size': EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: 'size',
          valueText: 'L',
        ),
        'thickness_mm': EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: 'thickness_mm',
          valueText: '5/4/3',
          valueNum: 5,
        ),
      },
      onChanged: (_) {},
    );
    expect(find.text('L'), findsOneWidget);
    expect(find.text('5/4/3'), findsOneWidget);
  });

  testWidgets(
    'thickness field validates designations and clears when emptied',
    (tester) async {
      final cleared = <String>[];
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: EquipmentAttributeFormSection(
                  type: EquipmentType.wetsuit,
                  values: const {},
                  units: const UnitFormatter(AppSettings()),
                  onChanged: (_) {},
                  onCleared: cleared.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final thickness = find.byKey(const ValueKey('attr-field-thickness_mm'));

      // Non-numeric garbage fails validation and surfaces the error message.
      await tester.enterText(thickness, 'thin');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(l10n.equipment_edit_invalidThickness), findsOneWidget);

      // A valid multi-panel designation passes validation.
      await tester.enterText(thickness, '7/5/3');
      expect(formKey.currentState!.validate(), isTrue);

      // Emptying the field clears the attribute.
      await tester.enterText(thickness, '   ');
      expect(cleared, contains('thickness_mm'));
    },
  );
}
