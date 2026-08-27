import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_custom_fields_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<EquipmentAttribute> fields,
    required void Function(List<EquipmentAttribute>) onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentCustomFieldsSection(
              fields: fields,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  EquipmentAttribute custom(String key, {String? value}) => EquipmentAttribute(
    id: 'c-$key',
    equipmentId: 'e1',
    key: key,
    isCustom: true,
    valueText: value,
  );

  testWidgets('add button appends a blank custom field', (tester) async {
    List<EquipmentAttribute>? result;
    await pumpSection(tester, fields: const [], onChanged: (f) => result = f);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!, hasLength(1));
    expect(result!.single.isCustom, isTrue);
    expect(result!.single.key, isEmpty);
    expect(result!.single.sortOrder, 0);
  });

  testWidgets('editing the key emits an updated field at the same index', (
    tester,
  ) async {
    List<EquipmentAttribute>? result;
    await pumpSection(
      tester,
      fields: [custom('serial', value: '123')],
      onChanged: (f) => result = f,
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-key-c-serial')),
      'asset_tag',
    );
    expect(result, hasLength(1));
    expect(result!.single.key, 'asset_tag');
    // The value is preserved through a key edit.
    expect(result!.single.valueText, '123');
  });

  testWidgets('editing the value emits an updated field', (tester) async {
    List<EquipmentAttribute>? result;
    await pumpSection(
      tester,
      fields: [custom('serial')],
      onChanged: (f) => result = f,
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-value-c-serial')),
      'ABC-999',
    );
    expect(result!.single.key, 'serial');
    expect(result!.single.valueText, 'ABC-999');
  });

  testWidgets('delete removes only the tapped row', (tester) async {
    List<EquipmentAttribute>? result;
    await pumpSection(
      tester,
      fields: [
        custom('a', value: '1'),
        custom('b', value: '2'),
      ],
      onChanged: (f) => result = f,
    );
    // Two rows -> two delete buttons; tap the first.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();

    expect(result, hasLength(1));
    expect(result!.single.key, 'b');
  });

  testWidgets('deleting a row does not leak values into remaining rows', (
    tester,
  ) async {
    // Stateful wrapper so the section rebuilds in place after a delete
    // (index-based field keys would reuse the wrong FormFieldState here).
    var fields = <EquipmentAttribute>[
      custom('a', value: '1'),
      custom('b', value: '2'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: EquipmentCustomFieldsSection(
                fields: fields,
                onChanged: (f) => setState(() => fields = f),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Delete the first row ('a'); 'b' must keep its own value '2'.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(fields, hasLength(1));
    expect(fields.single.key, 'b');
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}
