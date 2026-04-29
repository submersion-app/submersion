import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_primary_provider.dart';

class _FakeRepo implements AppSettingsRepository {
  List<String>? stored;

  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async => stored;

  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {
    stored = List<String>.from(ids);
  }

  // Members we don't use in these tests — stub to satisfy the interface.
  @override
  Future<bool> getShareByDefault() async => false;

  @override
  Future<void> setShareByDefault(bool value) async {}
}

ProviderContainer _container(AppSettingsRepository repo) {
  return ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  group('NavPrimaryIdsNotifier', () {
    test('initial state is defaults before async load completes', () {
      final repo = _FakeRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      expect(container.read(navPrimaryIdsNotifierProvider), kDefaultPrimaryIds);
    });

    test('loads and normalizes stored ids on construction', () async {
      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      final container = _container(repo);
      addTearDown(container.dispose);

      // Trigger provider build and wait for the async _load().
      container.read(navPrimaryIdsNotifierProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(navPrimaryIdsNotifierProvider), [
        'equipment',
        'buddies',
        'statistics',
      ]);
    });

    test('normalizes invalid stored ids during load', () async {
      final repo = _FakeRepo()..stored = ['dashboard', 'more', 'unknown'];
      final container = _container(repo);
      addTearDown(container.dispose);

      container.read(navPrimaryIdsNotifierProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(navPrimaryIdsNotifierProvider), kDefaultPrimaryIds);
    });

    test('setPrimaryIds writes through and updates state', () async {
      final repo = _FakeRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      final notifier = container.read(navPrimaryIdsNotifierProvider.notifier);
      await notifier.setPrimaryIds(['equipment', 'buddies', 'statistics']);

      expect(repo.stored, ['equipment', 'buddies', 'statistics']);
      expect(container.read(navPrimaryIdsNotifierProvider), [
        'equipment',
        'buddies',
        'statistics',
      ]);
    });

    test('setPrimaryIds normalizes input before writing', () async {
      final repo = _FakeRepo();
      final container = _container(repo);
      addTearDown(container.dispose);

      final notifier = container.read(navPrimaryIdsNotifierProvider.notifier);
      await notifier.setPrimaryIds(['dashboard', 'more', 'equipment']);

      expect(repo.stored, ['equipment', 'dives', 'sites']);
    });

    test('resetToDefaults writes defaults', () async {
      final repo = _FakeRepo()..stored = ['equipment', 'buddies', 'statistics'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final notifier = container.read(navPrimaryIdsNotifierProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.resetToDefaults();

      expect(repo.stored, kDefaultPrimaryIds);
      expect(container.read(navPrimaryIdsNotifierProvider), kDefaultPrimaryIds);
    });
  });

  group('derived providers', () {
    test(
      'navPrimaryDestinationsProvider returns [home, ...3 middle, more]',
      () async {
        final repo = _FakeRepo()
          ..stored = ['equipment', 'buddies', 'statistics'];
        final container = _container(repo);
        addTearDown(container.dispose);

        container.read(navPrimaryIdsNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        final result = container.read(navPrimaryDestinationsProvider);
        expect(result.map((d) => d.id).toList(), [
          'dashboard',
          'equipment',
          'buddies',
          'statistics',
          'more',
        ]);
      },
    );

    test(
      'navOverflowDestinationsProvider excludes pinned and primary, keeps canonical order',
      () async {
        final repo = _FakeRepo()
          ..stored = ['equipment', 'buddies', 'statistics'];
        final container = _container(repo);
        addTearDown(container.dispose);

        container.read(navPrimaryIdsNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        final result = container.read(navOverflowDestinationsProvider);
        expect(result.map((d) => d.id).toList(), [
          'dives',
          'sites',
          'trips',
          'dive-centers',
          'certifications',
          'courses',
          'planning',
          'transfer',
          'settings',
        ]);
      },
    );
  });
}
