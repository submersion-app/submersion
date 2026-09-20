import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
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

  test('setSiteDetailLayout applies and persists', () async {
    await notifier().setSiteDetailLayout(DiveDetailLayout.list);

    expect(
      container.read(settingsProvider).siteDetailLayout,
      DiveDetailLayout.list,
    );
    expect((await stored()).siteDetailLayout, DiveDetailLayout.list);
    expect((await stored()).diveDetailLayout, DiveDetailLayout.detailed);
  });

  test('setSiteDetailSections applies and persists the order', () async {
    final reversed = [
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(
          id: id,
          visible: id != SiteDetailSectionId.depth,
        ),
    ];
    await notifier().setSiteDetailSections(reversed);

    final saved = (await stored()).siteDetailSections;
    expect([for (final s in saved) s.id], SiteDetailSectionId.values.reversed);
    expect(
      saved.firstWhere((s) => s.id == SiteDetailSectionId.depth).visible,
      isFalse,
    );
  });

  test('resetSiteDetailSections restores the default order', () async {
    await notifier().setSiteDetailSections([
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(id: id, visible: false),
    ]);
    await notifier().resetSiteDetailSections();

    final saved = (await stored()).siteDetailSections;
    expect([for (final s in saved) s.id], SiteDetailSectionId.values);
    expect(saved.every((s) => s.visible), isTrue);
  });

  test('setSiteDetailSectionExpanded persists the fold state', () async {
    await notifier().setSiteDetailSectionExpanded(
      SiteDetailSectionId.depth,
      true,
    );

    final depth = (await stored()).siteDetailSections.firstWhere(
      (s) => s.id == SiteDetailSectionId.depth,
    );
    expect(depth.expanded, isTrue);
  });

  test('an unchanged fold state leaves the list instance alone', () async {
    final before = container.read(settingsProvider).siteDetailSections;
    await notifier().setSiteDetailSectionExpanded(
      SiteDetailSectionId.depth,
      false,
    );

    expect(
      identical(container.read(settingsProvider).siteDetailSections, before),
      isTrue,
    );
  });
}
