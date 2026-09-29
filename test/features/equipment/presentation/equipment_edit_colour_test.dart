import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
    // Tall enough that the lazily built form lays out the colour row.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fins show their stored colour in the form', (tester) async {
    final created = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Jet Fins',
        type: EquipmentType.fins,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'color',
          ).copyWith(valueText: '#EF4444'),
        ],
      ),
    );
    await pumpEditor(tester, created.id);
    final field = find.byKey(const ValueKey('attr-field-color'));
    expect(field, findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets('a battery has no colour field', (tester) async {
    final created = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Cell pack',
        type: EquipmentType.battery,
      ),
    );
    await pumpEditor(tester, created.id);
    expect(find.byKey(const ValueKey('attr-field-color')), findsNothing);
  });

  // Issue #2520: CSV import could give a battery a colour. The form has no
  // colour field for it, so it keeps the value as a custom field on save.
  testWidgets('a colour on a battery survives a save as a custom field', (
    tester,
  ) async {
    final created = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell pack',
        type: EquipmentType.battery,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'color',
          ).copyWith(valueText: '#EF4444'),
        ],
      ),
    );
    await pumpEditor(tester, created.id);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getEquipmentById(created.id);
    expect(saved!.attributes.map((a) => (a.key, a.isCustom, a.valueText)), [
      ('color', true, '#EF4444'),
    ]);
  });

  testWidgets('picking and then clearing a colour updates the form', (
    tester,
  ) async {
    final created = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Jet Fins', type: EquipmentType.fins),
    );
    await pumpEditor(tester, created.id);
    final field = find.byKey(const ValueKey('attr-field-color'));
    expect(
      find.descendant(of: field, matching: find.text('--')),
      findsOneWidget,
    );

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#14B8A6')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: field, matching: find.text('Teal')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: field, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: field, matching: find.text('--')),
      findsOneWidget,
    );
  });
}
