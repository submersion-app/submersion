import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(settingsProvider.notifier).initialLoad;
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  SettingsNotifier notifier() => container.read(settingsProvider.notifier);

  Future<AppSettings> stored() async =>
      (await DiverSettingsRepository().getSettingsForDiver(diverId))!;

  test('a new diver gets the order the page shipped with', () async {
    final saved = (await stored()).equipmentDetailSections;
    expect([for (final s in saved) s.id], EquipmentDetailSectionId.values);
    expect(saved.every((s) => s.visible), isTrue);
  });

  test('setEquipmentDetailSections applies and persists the order', () async {
    final reversed = [
      for (final id in EquipmentDetailSectionId.values.reversed)
        EquipmentDetailSectionConfig(
          id: id,
          visible: id != EquipmentDetailSectionId.exposure,
        ),
    ];
    await notifier().setEquipmentDetailSections(reversed);

    expect(
      container.read(settingsProvider).equipmentDetailSections.first.id,
      EquipmentDetailSectionId.documents,
    );
    final saved = (await stored()).equipmentDetailSections;
    expect([
      for (final s in saved) s.id,
    ], EquipmentDetailSectionId.values.reversed);
    expect(
      saved
          .firstWhere((s) => s.id == EquipmentDetailSectionId.exposure)
          .visible,
      isFalse,
    );
  });

  test('resetEquipmentDetailSections restores the default order', () async {
    await notifier().setEquipmentDetailSections([
      for (final id in EquipmentDetailSectionId.values.reversed)
        EquipmentDetailSectionConfig(id: id, visible: false),
    ]);
    await notifier().resetEquipmentDetailSections();

    final saved = (await stored()).equipmentDetailSections;
    expect([for (final s in saved) s.id], EquipmentDetailSectionId.values);
    expect(saved.every((s) => s.visible), isTrue);
  });

  test('the list the setter stores cannot be changed afterwards', () async {
    final sections = List.of(EquipmentDetailSectionConfig.defaultSections);
    await notifier().setEquipmentDetailSections(sections);
    sections.clear();

    expect(
      container.read(settingsProvider).equipmentDetailSections,
      hasLength(EquipmentDetailSectionId.values.length),
    );
    expect(
      () => container.read(settingsProvider).equipmentDetailSections.clear(),
      throwsUnsupportedError,
    );
  });
}
