import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

/// Issue #3012: the real SettingsNotifier's profile metric colour setters.
void main() {
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
  });

  tearDown(() => container.dispose());

  ProfileMetricColorOverrides colors() =>
      container.read(settingsProvider).profileMetricColors;

  test('setProfileMetricColor swaps a taken colour', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setProfileMetricColor(
      ProfileMetric.ppO2,
      ProfileMetricColors.tts,
    );
    expect(
      colors().effectiveArgb(ProfileMetric.ppO2),
      ProfileMetricColors.tts.toARGB32(),
    );
    expect(
      colors().effectiveArgb(ProfileMetric.tts),
      ProfileMetricColors.ppO2.toARGB32(),
    );
  });

  test('resetProfileMetricColors clears every colour', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setProfileMetricColor(
      ProfileMetric.ppO2,
      const Color(0xFFE040FB),
    );
    expect(colors().count, 1);
    await notifier.resetProfileMetricColors();
    expect(colors(), ProfileMetricColorOverrides.none);
  });

  test(
    'a pick made while settings load is not overwritten by the load',
    () async {
      // No settle before the call: the setter must wait for the load itself.
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setProfileMetricColor(
        ProfileMetric.gf,
        const Color(0xFF00E676),
      );
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(colors().argbOf(ProfileMetric.gf), 0xFF00E676);
    },
  );
}
