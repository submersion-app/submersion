import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

// ---------------------------------------------------------------------------
// Mock dependencies that avoid touching the real database.
// ---------------------------------------------------------------------------

/// A [DiverSettingsRepository] subclass that stores settings in memory instead
/// of hitting a real SQLite database. This allows testing the real
/// [SettingsNotifier] class (and covering its code) without database access.
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

/// A [DiverRepository] subclass that always returns null/empty.
class _EmptyDiverRepository extends DiverRepository {
  @override
  Future<List<Diver>> getAllDivers() async => [];

  @override
  Future<Diver?> getDefaultDiver() async => null;

  @override
  Future<Diver?> getDiverById(String id) async => null;
}

void main() {
  group('Real SettingsNotifier.setShowDetailsPaneForSection', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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

      // Let the async _initializeAndLoad settle completely. It runs through
      // several awaits: currentDiverIdProvider read, getDiverById (null),
      // getDefaultDiver (null), then _loadSettings (returns defaults).
      // Multiple event-loop ticks are needed for all microtasks to complete.
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      container.dispose();
    });

    // Helper to wait for initialization to fully settle. The real
    // SettingsNotifier runs async _initializeAndLoad in the constructor,
    // which goes through several awaits. We must wait for it to complete
    // before calling any setter, otherwise _loadSettings may reset state.
    Future<void> waitForInit() async {
      // Pump multiple event loop ticks to let all microtasks/futures settle
      for (var i = 0; i < 10; i++) {
        await Future.delayed(Duration.zero);
      }
    }

    test('sets showDetailsPaneDives to true', () async {
      // Access the notifier to trigger creation
      container.read(settingsProvider.notifier);
      await waitForInit();

      expect(container.read(settingsProvider).showDetailsPaneDives, isFalse);
      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('dives', true);
      expect(container.read(settingsProvider).showDetailsPaneDives, isTrue);
    });

    test('sets siteMatchSensitivity', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      expect(
        container.read(settingsProvider).siteMatchSensitivity,
        SiteMatchSensitivity.balanced,
      );
      await container
          .read(settingsProvider.notifier)
          .setSiteMatchSensitivity(SiteMatchSensitivity.strict);
      expect(
        container.read(settingsProvider).siteMatchSensitivity,
        SiteMatchSensitivity.strict,
      );
    });

    test('sets showDetailsPaneSites to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('sites', true);
      expect(container.read(settingsProvider).showDetailsPaneSites, isTrue);
    });

    test('sets showDetailsPaneBuddies to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('buddies', true);
      expect(container.read(settingsProvider).showDetailsPaneBuddies, isTrue);
    });

    test('sets showDetailsPaneTrips to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('trips', true);
      expect(container.read(settingsProvider).showDetailsPaneTrips, isTrue);
    });

    test('sets showDetailsPaneEquipment to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('equipment', true);
      expect(container.read(settingsProvider).showDetailsPaneEquipment, isTrue);
    });

    test('sets showDetailsPaneDiveCenters to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('diveCenters', true);
      expect(
        container.read(settingsProvider).showDetailsPaneDiveCenters,
        isTrue,
      );
    });

    test('sets showDetailsPaneCertifications to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('certifications', true);
      expect(
        container.read(settingsProvider).showDetailsPaneCertifications,
        isTrue,
      );
    });

    test('sets showDetailsPaneCourses to true', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('courses', true);
      expect(container.read(settingsProvider).showDetailsPaneCourses, isTrue);
    });

    test('unknown key leaves state unchanged', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      final before = container.read(settingsProvider);
      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('nonexistent', true);
      expect(container.read(settingsProvider), before);
    });

    test('can toggle from true back to false', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('dives', true);
      expect(container.read(settingsProvider).showDetailsPaneDives, isTrue);

      await container
          .read(settingsProvider.notifier)
          .setShowDetailsPaneForSection('dives', false);
      expect(container.read(settingsProvider).showDetailsPaneDives, isFalse);
    });
  });

  group('Real SettingsNotifier other setters', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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

      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> waitForInit() async {
      for (var i = 0; i < 10; i++) {
        await Future.delayed(Duration.zero);
      }
    }

    test('setShowProfilePanelInTableView toggles value', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      expect(
        container.read(settingsProvider).showProfilePanelInTableView,
        isTrue,
      );
      await container
          .read(settingsProvider.notifier)
          .setShowProfilePanelInTableView(false);
      expect(
        container.read(settingsProvider).showProfilePanelInTableView,
        isFalse,
      );
    });

    test('setShowDataSourceBadges toggles value', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      expect(container.read(settingsProvider).showDataSourceBadges, isTrue);
      await container
          .read(settingsProvider.notifier)
          .setShowDataSourceBadges(false);
      expect(container.read(settingsProvider).showDataSourceBadges, isFalse);
    });

    test('setDefaultShowAscentRateLine persists the new default', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      // Promoted from session-only to a persisted default in v91; starts off.
      expect(
        container.read(settingsProvider).defaultShowAscentRateLine,
        isFalse,
      );
      await container
          .read(settingsProvider.notifier)
          .setDefaultShowAscentRateLine(true);
      expect(
        container.read(settingsProvider).defaultShowAscentRateLine,
        isTrue,
      );
    });

    test('setDefaultShowPhotoMarkers persists the new default', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      // Added as a persisted default in v96; photo markers start visible.
      expect(container.read(settingsProvider).defaultShowPhotoMarkers, isTrue);
      await container
          .read(settingsProvider.notifier)
          .setDefaultShowPhotoMarkers(false);
      expect(container.read(settingsProvider).defaultShowPhotoMarkers, isFalse);
    });

    test(
      'setShowAscentRateColors toggles the velocity-coloring default',
      () async {
        container.read(settingsProvider.notifier);
        await waitForInit();

        // Coloring now defaults off as of this change.
        expect(container.read(settingsProvider).showAscentRateColors, isFalse);
        await container
            .read(settingsProvider.notifier)
            .setShowAscentRateColors(true);
        expect(container.read(settingsProvider).showAscentRateColors, isTrue);
      },
    );

    test('fullscreen tile preferences persist and reload', () async {
      final notifier = container.read(settingsProvider.notifier);
      await waitForInit();

      await notifier.setFullscreenTilePreferences(
        order: ['depth', 'runtime', 'ppO2'],
        hidden: ['heartRate'],
      );

      expect(notifier.state.fullscreenTileOrder, ['depth', 'runtime', 'ppO2']);
      expect(notifier.state.fullscreenHiddenTiles, ['heartRate']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('fullscreen_tile_order'), [
        'depth',
        'runtime',
        'ppO2',
      ]);
      expect(prefs.getStringList('fullscreen_hidden_tiles'), ['heartRate']);
    });

    test('readout card position defaults to null and persists', () async {
      final notifier = container.read(settingsProvider.notifier);
      await waitForInit();

      expect(container.read(settingsProvider).fullscreenReadoutCardX, isNull);
      expect(container.read(settingsProvider).fullscreenReadoutCardY, isNull);

      await notifier.setFullscreenReadoutCardPosition(0.25, 0.75);

      expect(container.read(settingsProvider).fullscreenReadoutCardX, 0.25);
      expect(container.read(settingsProvider).fullscreenReadoutCardY, 0.75);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('fullscreen_readout_card_x'), 0.25);
      expect(prefs.getDouble('fullscreen_readout_card_y'), 0.75);
    });
  });
}

/// A [CurrentDiverIdNotifier] mock that always returns null.
class _NullDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _NullDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}
