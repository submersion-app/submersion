import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/constants/enums.dart' show WaterType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart'
    show GasDensityTemperature;
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart'
    show modProfileLimits;
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Best Mix Calculator State (issue #3112)
// ═══════════════════════════════════════════════════════════════════════════

/// Key of the calculator's preferences in the synced `settings` table.
const String bestMixCalculatorPrefsKey = 'gas_best_mix_calculator_prefs';

const _log = LoggerService('BestMixCalculatorPreferences');

/// The Best Mix calculator's inputs, restored on first use, re-read when
/// sync changes them, and saved after every change. Mirrors
/// `ModCalculatorNotifier` exactly, including its debounced save and the
/// per-diver ppO2 overrides.
class BestMixCalculatorNotifier
    extends StateNotifier<BestMixCalculatorPreferences> {
  BestMixCalculatorNotifier(
    this._repository, {
    required String? Function() diverId,
    required ModProfileLimits Function() profile,
  }) : _diverId = diverId,
       _profile = profile,
       super(BestMixCalculatorPreferences.defaults) {
    unawaited(reload());
  }

  final AppSettingsRepository _repository;
  final String? Function() _diverId;
  final ModProfileLimits Function() _profile;
  Timer? _saveTimer;
  bool _saving = false;

  /// Numbers each read in the order it started. An edit bumps it too, so a
  /// read that began before an edit, or before a newer read, never publishes.
  int _loadSeq = 0;

  static const Duration saveDelay = Duration(milliseconds: 500);

  bool get _hasUnsavedEdit => (_saveTimer?.isActive ?? false) || _saving;

  /// Adopts the stored preferences.
  ///
  /// Runs on creation and on every settings tick, so a change synced from
  /// another device reaches an open calculator. While an edit here is not yet
  /// saved the stored value is older than the state and is ignored; the save
  /// itself ticks again, and that read finds what was saved.
  Future<void> reload() async {
    final seq = ++_loadSeq;
    final raw = await _repository.getRawSetting(bestMixCalculatorPrefsKey);
    if (raw == null || !mounted || seq != _loadSeq || _hasUnsavedEdit) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = BestMixCalculatorPreferences.fromJson(decoded);
      }
    } on FormatException catch (e, stackTrace) {
      _log.error(
        'Stored Best Mix calculator preferences are not JSON',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _update(BestMixCalculatorPreferences next) {
    if (next == state) return;
    _loadSeq++;
    state = next;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(_save()));
  }

  /// A failed write is logged rather than propagated: the value the diver
  /// chose is live in the calculator either way.
  Future<void> _save() async {
    _saving = true;
    try {
      await _repository.setRawSetting(
        bestMixCalculatorPrefsKey,
        jsonEncode(state.toJson()),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save Best Mix calculator preferences',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _saving = false;
    }
  }

  BestMixModeInputs get _current => state.inputsFor(state.mode);

  void _updateCurrent(BestMixModeInputs inputs) =>
      _update(state.withInputs(state.mode, inputs));

  ModLimitOverrides get _overrides => state.overridesFor(_diverId());

  void _updateOverrides(ModLimitOverrides overrides) =>
      _update(state.withOverrides(_diverId(), overrides));

  void setMode(BestMixMode mode) => _update(state.copyWith(mode: mode));

  void setCcrSource(CcrGasSource source) =>
      _update(state.copyWith(ccrSource: source));

  void setDepth(double meters) =>
      _updateCurrent(_current.copyWith(depthMeters: meters));

  void setDensityAware(bool value) =>
      _updateCurrent(_current.copyWith(densityAware: value));

  /// Rec only: one of the three ppO2 chips.
  void setRecPpO2(double ppO2) =>
      _updateCurrent(_current.copyWith(recPpO2: ppO2));

  void setWaterType(WaterType type) => _update(state.copyWith(waterType: type));

  void setTemperature(GasDensityTemperature temperature) =>
      _update(state.copyWith(temperature: temperature));

  /// Working and flush are each stored as "follow the profile" when they
  /// equal the profile value, mirroring `ModCalculatorNotifier`.
  void setWorkingPpO2(double ppO2) => _updateOverrides(
    _overrides.withLimits(
      workingPpO2: ppO2,
      decoPpO2: _profile().decoPpO2,
      profile: _profile(),
    ),
  );

  void resetWorkingPpO2() => _updateOverrides(
    _overrides.withLimits(
      workingPpO2: _profile().workingPpO2,
      decoPpO2: _profile().decoPpO2,
      profile: _profile(),
    ),
  );

  void setFlushPpO2(double ppO2) =>
      _updateOverrides(_overrides.withFlushPpO2(ppO2, _profile()));

  void resetFlushPpO2() =>
      _updateOverrides(_overrides.withFlushPpO2(null, _profile()));

  void reset() => _update(BestMixCalculatorPreferences.defaults);

  /// A pending save still goes out when the notifier goes away.
  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_save());
    }
    super.dispose();
  }
}

final bestMixCalculatorNotifierProvider =
    StateNotifierProvider<
      BestMixCalculatorNotifier,
      BestMixCalculatorPreferences
    >((ref) {
      final repository = ref.read(appSettingsRepositoryProvider);
      final notifier = BestMixCalculatorNotifier(
        repository,
        diverId: () => ref.read(currentDiverIdProvider),
        profile: () => modProfileLimits(ref.read(settingsProvider)),
      );
      // A change arriving from sync ticks the settings table. The tick fires
      // for every key; a re-read that finds the same value changes nothing.
      final subscription = repository.watchSettingsChanges().listen(
        (_) => unawaited(notifier.reload()),
      );
      ref.onDispose(subscription.cancel);
      return notifier;
    });

/// The water type the Tec modes use, following the same fallback rule the
/// MOD calculator uses.
WaterType bestMixCalculatorWaterType(
  BestMixCalculatorPreferences prefs,
  AppSettings settings,
) => resolveWaterType(prefs.waterType, settings.defaultPlannerWaterType);

/// The ppO2 limits in effect for the active diver, and which of them differ
/// from their profile. Only `workingPpO2` and `flushPpO2` are read by Best
/// Mix; `decoPpO2`/`setpointBar` are carried along unused, same as the MOD
/// calculator leaves fields unused outside the mode that needs them.
final bestMixCalculatorLimitsProvider = Provider<ModResolvedLimits>((ref) {
  final prefs = ref.watch(bestMixCalculatorNotifierProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final settings = ref.watch(settingsProvider);
  return resolveModLimits(
    prefs.overridesFor(diverId),
    modProfileLimits(settings),
  );
});

/// The calculator inputs with every override resolved against the active
/// diver's profile.
final bestMixCalculatorInputsProvider = Provider<BestMixInputs>((ref) {
  final prefs = ref.watch(bestMixCalculatorNotifierProvider);
  final settings = ref.watch(settingsProvider);
  final limits = ref.watch(bestMixCalculatorLimitsProvider);
  final mode = prefs.inputsFor(prefs.mode);
  return BestMixInputs(
    depthMeters: mode.depthMeters,
    ppO2Limit: prefs.mode == BestMixMode.rec
        ? mode.recPpO2
        : limits.workingPpO2,
    endLimitMeters: settings.endLimit,
    o2Narcotic: settings.o2Narcotic,
    mode: prefs.mode,
    ccrSource: prefs.ccrSource,
    flushPpO2: limits.flushPpO2,
    waterType: bestMixCalculatorWaterType(prefs, settings),
    densityAware: mode.densityAware,
    temperature: prefs.temperature,
  );
});

final bestMixCalculatorResultProvider = Provider<BestMixResult>(
  (ref) => computeBestMix(ref.watch(bestMixCalculatorInputsProvider)),
);
