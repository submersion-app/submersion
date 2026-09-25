import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';
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
  group('renamed nav ids', () {
    // A build that already ships the new id; kRenamedNavIds records
    // statistics -> insights.
    const movable = ['dives', 'insights', 'sites', 'gear'];

    test('a renamed id keeps its stored slot under the new id', () {
      expect(
        normalizeNavOrder(
          stored: const ['sites', 'statistics', 'dives'],
          movableIds: movable,
        ),
        ['sites', 'insights', 'dives', 'gear'],
      );
    });

    test('the old and new id together collapse to one entry', () {
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'sites', 'insights'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
      expect(
        normalizeNavOrder(
          stored: const ['insights', 'sites', 'statistics'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
    });

    test('an alias never replaces an id the build still knows', () {
      // An older build that still ships the old id reads it as itself.
      const olderBuild = ['dives', 'statistics', 'sites'];
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'dives'],
          movableIds: olderBuild,
        ),
        ['statistics', 'dives', 'sites'],
      );
    });

    test('an unknown id with no alias is still dropped', () {
      expect(
        normalizeNavOrder(
          stored: const ['not-a-real-id', 'sites'],
          movableIds: movable,
        ),
        ['sites', 'dives', 'insights', 'gear'],
      );
    });
  });

  group('renamed nav ids against the real destinations', () {
    test('every alias points at a current destination and retires its '
        'source', () {
      for (final entry in kRenamedNavIds.entries) {
        expect(movableNavIds, contains(entry.value), reason: entry.key);
        expect(movableNavIds, isNot(contains(entry.key)), reason: entry.key);
      }
    });

    test('a phone order saved before the rename keeps Insights in its '
        'slot', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'statistics', 'buddies'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navPhoneOrderNotifierProvider);

      expect(order.take(3).toList(), ['equipment', 'insights', 'buddies']);
      expect(order.toSet(), movableNavIds.toSet());
    });

    test('a rail order saved before the rename keeps Insights in its '
        'slot', () async {
      final repo = FakeAppSettingsRepository()
        ..navRailIds = ['statistics', 'gps-log'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navRailOrderNotifierProvider);

      expect(order.take(2).toList(), ['insights', 'gps-log']);
    });

    test('the next save writes the new id', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'statistics', 'buddies'];
      final container = _container(repo);
      addTearDown(container.dispose);

      final order = await _loaded(container, navPhoneOrderNotifierProvider);
      await container
          .read(navPhoneOrderNotifierProvider.notifier)
          .setOrder(order);

      expect(repo.navPrimaryIds, contains('insights'));
      expect(repo.navPrimaryIds, isNot(contains('statistics')));
    });
  });
}
