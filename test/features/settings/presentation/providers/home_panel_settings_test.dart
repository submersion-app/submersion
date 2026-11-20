import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
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
    AppSettings settings, {
    AppSettings? previous,
  }) async {
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
  group('Home panel settings persistence', () {
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

    test('nothing stored loads as null, meaning never set', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homePanelOrder, isNull);
      expect(settings.hiddenHomePanels, isNull);
      expect(settings.hiddenHomeKeyNumbers, isNull);
    });

    test('setHomePanelLayout persists both lists', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      await container
          .read(settingsProvider.notifier)
          .setHomePanelLayout(
            order: const ['recentDives', 'keyNumbers'],
            hidden: const {'sacTrend'},
          );
      final settings = container.read(settingsProvider);
      expect(settings.homePanelOrder, ['recentDives', 'keyNumbers']);
      expect(settings.hiddenHomePanels, {'sacTrend'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(SettingsKeys.homePanelOrder), [
        'recentDives',
        'keyNumbers',
      ]);
      expect(prefs.getStringList(SettingsKeys.hiddenHomePanels), ['sacTrend']);
    });

    test('a stored layout loads on startup', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.homePanelOrder: ['keyNumbers'],
        SettingsKeys.hiddenHomePanels: <String>[],
        SettingsKeys.hiddenHomeKeyNumbers: ['dives'],
      });
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homePanelOrder, ['keyNumbers']);
      expect(settings.hiddenHomePanels, isEmpty);
      expect(settings.hiddenHomeKeyNumbers, {'dives'});
    });

    test('the old card keys keep their values', () async {
      SharedPreferences.setMockInitialValues({
        'home_card_order': ['hero'],
        'hidden_home_cards': ['photoRibbon'],
      });
      await makeContainer();
      expect(container.read(settingsProvider).hiddenHomeCards, {'photoRibbon'});
      await container
          .read(settingsProvider.notifier)
          .setHomePanelLayout(order: const ['keyNumbers'], hidden: const {});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('home_card_order'), ['hero']);
      expect(prefs.getStringList('hidden_home_cards'), ['photoRibbon']);
    });

    test('a wrong-typed value in a new key loads as null', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.homePanelOrder: 42,
        SettingsKeys.hiddenHomeKeyNumbers: 'dives',
      });
      await makeContainer();
      final settings = container.read(settingsProvider);
      expect(settings.homePanelOrder, isNull);
      expect(settings.hiddenHomeKeyNumbers, isNull);
    });

    test('setHiddenHomeKeyNumbers persists the set', () async {
      SharedPreferences.setMockInitialValues({});
      await makeContainer();
      await container.read(settingsProvider.notifier).setHiddenHomeKeyNumbers(
        const {'species', 'avgSac'},
      );
      expect(container.read(settingsProvider).hiddenHomeKeyNumbers, {
        'species',
        'avgSac',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(SettingsKeys.hiddenHomeKeyNumbers), [
        'avgSac',
        'species',
      ]);
    });
  });
}
