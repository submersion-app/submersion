import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The site list deletes as the owner and hides for everyone else
/// (issue #2594).
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedDivers(db, ['a', 'b']);
    await seedSite(db, 'theirs', owner: 'a', shared: true);
    await seedSite(db, 'mine', owner: 'b', shared: true);
  });

  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> containerFor(String diverId) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(siteListNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    while (container.read(siteListNotifierProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container;
  }

  List<String> listed(ProviderContainer c) => [
    for (final s in c.read(siteListNotifierProvider).value ?? const []) s.id,
  ];

  test('bulk delete removes only the profile\'s own sites', () async {
    final c = await containerFor('b');
    final result = await c
        .read(siteListNotifierProvider.notifier)
        .bulkDeleteSites(['theirs', 'mine']);
    expect(result.sites.map((s) => s.id), ['mine']);
    expect(await SiteRepository().getSiteById('theirs'), isNotNull);
  });

  test('Undo of the owner\'s bulk delete keeps another profile\'s hide '
      '(issue #2680)', () async {
    final hides = ProfileHidesRepository();
    await hides.hide(SharedItemKind.site, 'theirs', 'b');
    final c = await containerFor('a');
    final notifier = c.read(siteListNotifierProvider.notifier);
    final deleted = await notifier.bulkDeleteSites(['theirs']);
    expect(deleted.sites.map((s) => s.id), ['theirs']);

    await notifier.restoreSites(deleted.sites, links: deleted.links);
    expect(listed(c), contains('theirs'));
    expect((await hides.hiddenItems('b')).map((i) => i.id), ['theirs']);
  });

  test('a non-owner cannot delete it but hides and unhides it', () async {
    final c = await containerFor('b');
    final notifier = c.read(siteListNotifierProvider.notifier);
    expect(await notifier.deleteSite('theirs'), isFalse);
    expect(await notifier.hideSites(['theirs']), 1);
    expect(listed(c), ['mine']);
    await notifier.unhideSites(['theirs']);
    expect(listed(c).toSet(), {'mine', 'theirs'});
  });
}
