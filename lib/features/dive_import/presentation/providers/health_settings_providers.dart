import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Which diver each Apple Health switch belongs to (issue #637), on this
/// device. Null means off. A switch is bound to the diver who turned it on,
/// so nothing from Health is written to another diver's dives when the app
/// switches divers.
class HealthSettings {
  const HealthSettings({this.autoImportDiverId, this.metricsDiverId});

  /// "Import Apple Watch dives automatically".
  final String? autoImportDiverId;

  /// "Heart rate, recovery and sleep" from Apple Health on dives.
  final String? metricsDiverId;
}

/// The Apple Health switches, kept in SharedPreferences: they describe this
/// device's Health store, which another device's diver may not share.
class HealthSettingsNotifier extends StateNotifier<HealthSettings> {
  HealthSettingsNotifier(
    this._prefs, {
    required Future<bool> Function(String diverId) diverExists,
  }) : _diverExists = diverExists,
       super(
         HealthSettings(
           autoImportDiverId: _prefs.getString(
             SettingsKeys.healthAutoImportDiver,
           ),
           metricsDiverId: _prefs.getString(SettingsKeys.healthMetricsDiver),
         ),
       );

  final SharedPreferences _prefs;
  final Future<bool> Function(String diverId) _diverExists;

  Future<void> enableAutoImport(String diverId) =>
      _set(autoImport: diverId, metrics: state.metricsDiverId);

  Future<void> disableAutoImport() =>
      _set(autoImport: null, metrics: state.metricsDiverId);

  Future<void> enableMetrics(String diverId) =>
      _set(autoImport: state.autoImportDiverId, metrics: diverId);

  Future<void> disableMetrics() =>
      _set(autoImport: state.autoImportDiverId, metrics: null);

  /// Turns off a switch whose diver no longer exists (deleted, or merged
  /// into another profile), so nothing is written for them. The lookups
  /// await the database, so the switches are read again after them: one
  /// turned on or off meanwhile keeps that change, and only a switch still
  /// bound to the missing diver is cleared.
  Future<void> verifyBoundDivers() async {
    final autoImport = state.autoImportDiverId;
    final metrics = state.metricsDiverId;
    final autoImportGone =
        autoImport != null && !await _diverExists(autoImport);
    final metricsGone = metrics != null && !await _diverExists(metrics);
    if (!autoImportGone && !metricsGone) return;
    final now = state;
    await _set(
      autoImport: autoImportGone && now.autoImportDiverId == autoImport
          ? null
          : now.autoImportDiverId,
      metrics: metricsGone && now.metricsDiverId == metrics
          ? null
          : now.metricsDiverId,
    );
  }

  Future<void> _set({String? autoImport, String? metrics}) async {
    state = HealthSettings(
      autoImportDiverId: autoImport,
      metricsDiverId: metrics,
    );
    await _write(SettingsKeys.healthAutoImportDiver, autoImport);
    await _write(SettingsKeys.healthMetricsDiver, metrics);
  }

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}

// no-tick: the value is device preferences, not a query result. The diver
// lookup only checks that a bound diver still exists, on demand.
final healthSettingsProvider =
    StateNotifierProvider<HealthSettingsNotifier, HealthSettings>((ref) {
      final notifier = HealthSettingsNotifier(
        ref.watch(sharedPreferencesProvider),
        diverExists: (id) async =>
            await ref.read(diverRepositoryProvider).getDiverById(id) != null,
      );
      notifier.verifyBoundDivers();
      return notifier;
    });
