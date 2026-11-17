import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive form's Weights section names the lead its weights gear already
/// carries and counts it in the total, as the dive page does (issue #4442).
void main() {
  late DiveRepository repository;
  late EquipmentRepository equipment;
  String? previousLocale;

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    await setUpTestDatabase();
    repository = DiveRepository();
    equipment = EquipmentRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(WidgetTester tester, String diveId) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Gas & Gear section is collapsed when editing; open it.
    final summary = find.textContaining('1 tank').first;
    await tester.ensureVisible(summary);
    await tester.tap(summary);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('How was your weighting?'));
    await tester.pumpAndSettle();
  }

  Future<EquipmentItem> weightsGear(String id, String name, double? kg) =>
      equipment.createEquipment(
        EquipmentItem(
          id: id,
          name: name,
          type: EquipmentType.weights,
          attributes: [
            if (kg != null)
              EquipmentAttribute(
                id: '$id-dry',
                equipmentId: id,
                key: EquipmentAttrKeys.dryWeightKg,
                valueNum: kg,
              ),
          ],
        ),
      );

  Future<String> diveWith(List<EquipmentItem> gear) async {
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 1, 1),
        weights: const [
          DiveWeight(
            id: 'belt',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 4.5,
          ),
        ],
        gear: looseGear(gear),
      ),
    );
    return created.id;
  }

  testWidgets('names the gear lead and counts it in the total', (tester) async {
    final plate = await weightsGear('plate', 'Weighted backplate', 2.5);
    await pumpEditor(tester, await diveWith([plate]));

    expect(
      find.text(
        'Also counted: 2.5 kg carried as equipment (Weighted backplate). '
        'Add a weight here only for separate lead.',
      ),
      findsOneWidget,
    );
    expect(find.text('Total: 7.0 kg'), findsOneWidget);
  });

  testWidgets('says nothing when the gear declares no lead', (tester) async {
    final block = await weightsGear('block', 'Trim block', null);
    await pumpEditor(tester, await diveWith([block]));

    expect(find.textContaining('Also counted'), findsNothing);
    expect(find.text('Total: 4.5 kg'), findsOneWidget);
  });
}
