import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// In-memory settings repository so the real [SettingsNotifier] runs without
/// a database (mirrors settings_notifier_real_test.dart).
class _InMemorySettingsRepository extends DiverSettingsRepository {
  AppSettings? _stored;

  @override
  Future<AppSettings?> getSettingsForDiver(String diverId) async => _stored;

  @override
  Future<AppSettings> createSettingsForDiver(
    String diverId, {
    AppSettings? settings,
  }) async {
    _stored = settings ?? const AppSettings();
    return _stored!;
  }

  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    if (_stored != null) return _stored!;
    _stored = defaultSettings ?? const AppSettings();
    return _stored!;
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {
    _stored = settings;
  }
}

class _EmptyDiverRepository extends DiverRepository {
  @override
  Future<List<Diver>> getAllDivers() async => [];

  @override
  Future<Diver?> getDefaultDiver() async => null;

  @override
  Future<Diver?> getDiverById(String id) async => null;
}

class _NullDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _NullDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

void main() {
  group('Home card settings persistence', () {
    late ProviderContainer container;

    Future<void> makeContainer() async {
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diverSettingsRepositoryProvider.overrideWithValue(
            _InMemorySettingsRepository(),
          ),
          diverRepositoryProvider.overrideWithValue(_EmptyDiverRepository()),
          currentDiverIdProvider.overrideWith((ref) => _NullDiverIdNotifier()),
        ],
      );
      addTearDown(container.dispose);
      // Trigger notifier creation, then let async init settle.
      container.read(settingsProvider.notifier);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('defaults: empty order and no hidden cards', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homeCardOrder, isEmpty);
      expect(settings.hiddenHomeCards, isEmpty);
    });

    test('setHomeCardOrder persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      final notifier = container.read(settingsProvider.notifier);
      final order = [for (final c in HomeCardType.values.reversed) c.name];
      await notifier.setHomeCardOrder(order);
      expect(container.read(settingsProvider).homeCardOrder, order);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(SettingsKeys.homeCardOrder), order);
    });

    test('setHomeCardEnabled toggles hidden set and persists', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setHomeCardEnabled(HomeCardType.photoRibbon.name, false);
      expect(container.read(settingsProvider).hiddenHomeCards, {
        HomeCardType.photoRibbon.name,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(SettingsKeys.hiddenHomeCards), [
        HomeCardType.photoRibbon.name,
      ]);
      await notifier.setHomeCardEnabled(HomeCardType.photoRibbon.name, true);
      expect(container.read(settingsProvider).hiddenHomeCards, isEmpty);
    });

    test('stored values load on startup', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.homeCardOrder: [HomeCardType.recentDives.name],
        SettingsKeys.hiddenHomeCards: [HomeCardType.hero.name],
      });
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homeCardOrder, [HomeCardType.recentDives.name]);
      expect(settings.hiddenHomeCards, {HomeCardType.hero.name});
    });

    test('corrupt pref type falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.homeCardOrder: 'not-a-list',
        SettingsKeys.hiddenHomeCards: 42,
      });
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homeCardOrder, isEmpty);
      expect(settings.hiddenHomeCards, isEmpty);
    });

    test('resetHomeCards clears both prefs', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setHomeCardOrder([HomeCardType.hero.name]);
      await notifier.setHomeCardEnabled(HomeCardType.hero.name, false);
      await notifier.resetHomeCards();
      final settings = container.read(settingsProvider);
      expect(settings.homeCardOrder, isEmpty);
      expect(settings.hiddenHomeCards, isEmpty);
    });
  });
}
