import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
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
}
