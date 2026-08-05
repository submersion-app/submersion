import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_custom_fields_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  group('EquipmentEditPage advanced fields', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
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

    testWidgets('populates existing buoyancy metadata and saves changes', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: '7mm Wetsuit',
          type: EquipmentType.wetsuit,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'buoyancy_kg',
              valueNum: 5.0,
            ),
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'dry_weight_kg',
              valueNum: 2.5,
            ),
          ],
        ),
      );
      await pumpEditor(tester, created.id);

      final buoyancyField = find.byKey(
        const ValueKey('attr-field-buoyancy_kg'),
      );
      final dryWeightField = find.byKey(
        const ValueKey('attr-field-dry_weight_kg'),
      );
      await tester.ensureVisible(buoyancyField);
      await tester.pumpAndSettle();
      // Whole numbers render without a trailing ".0" (matching the display
      // formatter); fractional values keep their decimal.
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);

      await tester.enterText(buoyancyField, '-2.5');
      await tester.ensureVisible(dryWeightField);
      await tester.enterText(dryWeightField, '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, -2.5);
      expect(saved.weightKg, 3.0);
    });

    testWidgets('de-dupes custom fields sharing a label on save', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Wetsuit',
          type: EquipmentType.wetsuit,
        ),
      );
      await pumpEditor(tester, created.id);

      Future<void> scrollTo(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      // Add two custom-field rows (the section lives at the bottom of the
      // lazy ListView, so scroll it into view before tapping).
      final addButton = find.text('Add custom field');
      await scrollTo(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await scrollTo(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Rows carry stable uuid-based keys, so locate the four inputs by their
      // position within the section: key0, value0, key1, value1.
      final inputs = find.descendant(
        of: find.byType(EquipmentCustomFieldsSection),
        matching: find.byType(TextFormField),
      );
      await scrollTo(inputs.first);
      // Give both the same key but distinct values; dedup keeps the first.
      await tester.enterText(inputs.at(0), 'warranty');
      await tester.enterText(inputs.at(1), 'first');
      await tester.enterText(inputs.at(2), 'warranty');
      await tester.enterText(inputs.at(3), 'second');

      final saveButton = find.text('Save');
      await scrollTo(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // The UNIQUE(equipment_id, attr_key, is_custom) constraint would have
      // failed the insert without dedup; exactly one custom row survives.
      final saved = await repository.getEquipmentById(created.id);
      final customFields = saved!.attributes
          .where((a) => a.isCustom && a.key == 'warranty')
          .toList();
      expect(customFields, hasLength(1));
      expect(customFields.single.valueText, 'first');
    });

    testWidgets('empty fields save as null', (tester) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Mask',
          type: EquipmentType.mask,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: '',
              key: 'buoyancy_kg',
              valueNum: 0.2,
            ),
          ],
        ),
      );
      await pumpEditor(tester, created.id);

      final buoyancyField = find.byKey(
        const ValueKey('attr-field-buoyancy_kg'),
      );
      await tester.ensureVisible(buoyancyField);
      await tester.pumpAndSettle();
      await tester.enterText(buoyancyField, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.buoyancyKg, isNull);
    });
  });
}
