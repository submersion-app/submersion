// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    as divers;
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// No diver on file, so the settings fall to their defaults.
class _NoDiverRepository extends divers.DiverRepository {
  @override
  Future<domain.Diver?> getDiverById(String id) async => null;

  @override
  Future<domain.Diver?> getDefaultDiver() async => null;

  @override
  Future<String?> getActiveDiverIdFromSettings() async => null;

  @override
  Future<void> setActiveDiverIdInSettings(String? diverId) async {}
}

class _DefaultDiverSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    return const AppSettings(notificationsEnabled: false);
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {}
}

class _DefaultSettingsNotifier extends SettingsNotifier {
  _DefaultSettingsNotifier(Ref ref)
    : super(_DefaultDiverSettingsRepository(), ref);
}

/// Overrides that let the real profile analysis pipeline run in a test: the
/// settings it reads load (as the defaults) through the real
/// [SettingsNotifier], so the analysis records a settings fingerprint the
/// safety review accepts.
///
/// Repository lookups inside the pipeline (surface interval, events, gas
/// switches) still need a database: call `setUpTestDatabase()` as well.
List<riverpod.Override> analysisPipelineOverrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  diverRepositoryProvider.overrideWithValue(_NoDiverRepository()),
  settingsProvider.overrideWith((ref) => _DefaultSettingsNotifier(ref)),
];
