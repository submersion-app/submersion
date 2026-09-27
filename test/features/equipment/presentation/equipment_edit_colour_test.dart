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
}
