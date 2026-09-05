import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_favorites_provider.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

const _key = 'nav_favorite_ids';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<List<String>?> _stored() async =>
    (await SharedPreferences.getInstance()).getStringList(_key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeNavFavoriteIds', () {
    test('keeps order, drops unknown, pinned and duplicate ids', () {
      final result = normalizeNavFavoriteIds(
        stored: ['sites', 'ghost', 'dashboard', 'dives', 'sites', 'more'],
        validIds: movableNavIds,
      );
      expect(result, ['sites', 'dives']);
    });

    test('returns an unmodifiable list', () {
      final result = normalizeNavFavoriteIds(
        stored: ['dives'],
        validIds: movableNavIds,
      );
      expect(() => result.add('sites'), throwsUnsupportedError);
    });
  });

  group('NavFavoritesNotifier', () {
    test('starts empty when nothing is stored', () async {
      final container = await _container({});
      expect(container.read(navFavoritesNotifierProvider), isEmpty);
    });

    test('reads stored ids synchronously on first read', () async {
      final container = await _container({
        _key: ['trips', 'dives'],
      });
      expect(container.read(navFavoritesNotifierProvider), ['trips', 'dives']);
    });

    test('filters stale ids out of stored data', () async {
      final container = await _container({
        _key: ['trips', 'removed-feature', 'dashboard'],
      });
      expect(container.read(navFavoritesNotifierProvider), ['trips']);
    });

    test('add appends and persists', () async {
      final container = await _container({});
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.add('dives');
      await notifier.add('sites');

      expect(container.read(navFavoritesNotifierProvider), ['dives', 'sites']);
      expect(await _stored(), ['dives', 'sites']);
    });

    test('add ignores duplicates and non-favoritable ids', () async {
      final container = await _container({
        _key: ['dives'],
      });
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.add('dives');
      await notifier.add('dashboard');
      await notifier.add('more');
      await notifier.add('nope');

      expect(container.read(navFavoritesNotifierProvider), ['dives']);
    });

    test('remove drops the id and persists', () async {
      final container = await _container({
        _key: ['dives', 'sites', 'trips'],
      });
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.remove('sites');

      expect(container.read(navFavoritesNotifierProvider), ['dives', 'trips']);
      expect(await _stored(), ['dives', 'trips']);
    });

    test('toggle adds when absent and removes when present', () async {
      final container = await _container({});
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.toggle('equipment');
      expect(notifier.isFavorite('equipment'), isTrue);
      expect(container.read(navFavoritesNotifierProvider), ['equipment']);

      await notifier.toggle('equipment');
      expect(notifier.isFavorite('equipment'), isFalse);
      expect(container.read(navFavoritesNotifierProvider), isEmpty);
      expect(await _stored(), isEmpty);
    });

    test('reorder moves an item down to its final position', () async {
      final container = await _container({
        _key: ['dives', 'sites', 'trips'],
      });
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.reorder(0, 2);

      expect(container.read(navFavoritesNotifierProvider), [
        'sites',
        'trips',
        'dives',
      ]);
      expect(await _stored(), ['sites', 'trips', 'dives']);
    });

    test('reorder moves an item up', () async {
      final container = await _container({
        _key: ['dives', 'sites', 'trips'],
      });
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.reorder(2, 0);

      expect(container.read(navFavoritesNotifierProvider), [
        'trips',
        'dives',
        'sites',
      ]);
    });

    test('reorder ignores out-of-range indices', () async {
      final container = await _container({
        _key: ['dives', 'sites'],
      });
      final notifier = container.read(navFavoritesNotifierProvider.notifier);

      await notifier.reorder(5, 0);
      await notifier.reorder(0, -1);
      await notifier.reorder(0, 2);

      expect(container.read(navFavoritesNotifierProvider), ['dives', 'sites']);
    });

    test('persistence round-trips through a fresh container', () async {
      final first = await _container({});
      await first.read(navFavoritesNotifierProvider.notifier).add('planning');
      await first.read(navFavoritesNotifierProvider.notifier).add('media');

      final prefs = await SharedPreferences.getInstance();
      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);

      expect(second.read(navFavoritesNotifierProvider), ['planning', 'media']);
    });
  });

  group('navFavoriteDestinationsProvider', () {
    test('resolves ids to destinations in stored order', () async {
      final container = await _container({
        _key: ['settings', 'dives'],
      });
      final destinations = container.read(navFavoriteDestinationsProvider);
      expect(destinations.map((d) => d.id), ['settings', 'dives']);
      expect(destinations.map((d) => d.route), ['/settings', '/dives']);
    });
  });
}
