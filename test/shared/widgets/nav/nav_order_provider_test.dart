import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

import '../../../support/fake_app_settings_repository.dart';

ProviderContainer _container(AppSettingsRepository repo) {
  return ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
  );
}

/// Reads a notifier and lets its async load settle.
Future<List<String>> _loaded(
  ProviderContainer container,
  StateNotifierProvider<NavOrderNotifier, List<String>> provider,
) async {
  container.read(provider);
  await Future<void>.delayed(Duration.zero);
  return container.read(provider);
}

void main() {
  group('NavOrderNotifier', () {
    test(
      'initial state is the canonical order before async load completes',
      () {
        final container = _container(FakeAppSettingsRepository());
        addTearDown(container.dispose);

        expect(container.read(navPhoneOrderNotifierProvider), movableNavIds);
      },
    );

    test('loads and normalizes stored ids on construction', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navPhoneOrderNotifierProvider);

      expect(order.take(3).toList(), ['equipment', 'buddies', 'statistics']);
      expect(order.toSet(), movableNavIds.toSet());
    });

    test('normalizes invalid stored ids during load', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['dashboard', 'more', 'unknown'];
      final container = _container(repo);
      addTearDown(container.dispose);

      expect(
        await _loaded(container, navPhoneOrderNotifierProvider),
        movableNavIds,
      );
    });

    test('a read failure leaves the canonical order in place', () async {
      final repo = FakeAppSettingsRepository()
        ..throwOnNavRead = StateError('database down');
      final container = _container(repo);
      addTearDown(container.dispose);

      expect(
        await _loaded(container, navPhoneOrderNotifierProvider),
        movableNavIds,
      );
    });

    test('setOrder writes the full order through and updates state', () async {
      final repo = FakeAppSettingsRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      final reordered = [
        'statistics',
        ...movableNavIds.where((id) => id != 'statistics'),
      ];
      await container
          .read(navPhoneOrderNotifierProvider.notifier)
          .setOrder(reordered);

      expect(repo.navPrimaryIds, reordered);
      expect(container.read(navPhoneOrderNotifierProvider), reordered);
    });

    test('setOrder normalizes a partial input before writing', () async {
      final repo = FakeAppSettingsRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(navPhoneOrderNotifierProvider.notifier).setOrder([
        'dashboard',
        'more',
        'equipment',
      ]);

      expect(repo.navPrimaryIds!.first, 'equipment');
      expect(repo.navPrimaryIds!.toSet(), movableNavIds.toSet());
    });

    test('resetToDefaults writes the canonical order', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics'];
      final container = _container(repo);
      addTearDown(container.dispose);

      await _loaded(container, navPhoneOrderNotifierProvider);
      await container
          .read(navPhoneOrderNotifierProvider.notifier)
          .resetToDefaults();

      expect(repo.navPrimaryIds, movableNavIds);
      expect(container.read(navPhoneOrderNotifierProvider), movableNavIds);
    });
  });

  group('phone and rail orders are independent', () {
    test('each notifier loads from its own storage key', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics']
        ..navRailIds = ['gps-log', 'planning'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final phone = await _loaded(container, navPhoneOrderNotifierProvider);
      final rail = await _loaded(container, navRailOrderNotifierProvider);

      expect(phone.take(3).toList(), ['equipment', 'buddies', 'statistics']);
      expect(rail.take(2).toList(), ['gps-log', 'planning']);
    });

    test('writing the rail order leaves the phone order untouched', () async {
      final repo = FakeAppSettingsRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      await _loaded(container, navPhoneOrderNotifierProvider);
      await container.read(navRailOrderNotifierProvider.notifier).setOrder([
        'settings',
        ...movableNavIds.where((id) => id != 'settings'),
      ]);

      expect(repo.navPrimaryIds, isNull);
      expect(repo.navRailIds!.first, 'settings');
      expect(container.read(navPhoneOrderNotifierProvider), movableNavIds);
    });
  });

  group('derived providers', () {
    test(
      'navPrimaryDestinationsProvider returns [home, ...3 middle, more]',
      () async {
        final repo = FakeAppSettingsRepository()
          ..navPrimaryIds = ['equipment', 'buddies', 'statistics'];
        final container = _container(repo);
        addTearDown(container.dispose);

        await _loaded(container, navPhoneOrderNotifierProvider);

        expect(
          container
              .read(navPrimaryDestinationsProvider)
              .map((d) => d.id)
              .toList(),
          ['dashboard', 'equipment', 'buddies', 'statistics', 'more'],
        );
      },
    );

    test(
      'navOverflowDestinationsProvider follows the stored phone order',
      () async {
        // 'settings' pulled to the front of the overflow tail, which canonical
        // order would have placed last.
        final tail = ['settings', 'dives', 'sites'];
        final repo = FakeAppSettingsRepository()
          ..navPrimaryIds = ['equipment', 'buddies', 'statistics', ...tail];
        final container = _container(repo);
        addTearDown(container.dispose);

        await _loaded(container, navPhoneOrderNotifierProvider);

        final overflow = container
            .read(navOverflowDestinationsProvider)
            .map((d) => d.id)
            .toList();

        expect(overflow.take(3).toList(), tail);
        expect(overflow, isNot(contains('equipment')));
        expect(overflow, isNot(contains('dashboard')));
        expect(overflow, isNot(contains('more')));
        expect(overflow.length, movableNavIds.length - 3);
      },
    );

    test(
      'navRailDestinationsProvider is pinned Home then the rail order',
      () async {
        final repo = FakeAppSettingsRepository()
          ..navRailIds = ['statistics', 'gps-log'];
        final container = _container(repo);
        addTearDown(container.dispose);

        await _loaded(container, navRailOrderNotifierProvider);

        final rail = container
            .read(navRailDestinationsProvider)
            .map((d) => d.id)
            .toList();

        expect(rail.take(3).toList(), ['dashboard', 'statistics', 'gps-log']);
        expect(rail.length, movableNavIds.length + 1);
        expect(rail, isNot(contains('more')));
      },
    );
  });
}
