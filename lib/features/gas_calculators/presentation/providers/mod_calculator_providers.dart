import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MOD Calculator State (issue #2342)
// ═══════════════════════════════════════════════════════════════════════════

/// Key of the calculator's preferences in the synced `settings` table.
const String modCalculatorPrefsKey = 'gas_mod_calculator_prefs';

const _log = LoggerService('ModCalculatorPreferences');

/// The MOD calculator's inputs, restored on first use, re-read when sync
/// changes them, and saved after every change.
///
/// Saves are debounced: dragging a slider is one database write once it
/// settles, not one per frame. The ppO2 limit overrides belong to the active
/// diver, read through [_diverId] and resolved against [_profile].
class ModCalculatorNotifier extends StateNotifier<ModCalculatorPreferences> {
  ModCalculatorNotifier(
    this._repository, {
    required String? Function() diverId,
    required ModProfileLimits Function() profile,
  }) : _diverId = diverId,
       _profile = profile,
       super(ModCalculatorPreferences.defaults) {
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
    final raw = await _repository.getRawSetting(modCalculatorPrefsKey);
    if (raw == null || !mounted || seq != _loadSeq || _hasUnsavedEdit) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = ModCalculatorPreferences.fromJson(decoded);
      }
    } on FormatException catch (e, stackTrace) {
      _log.error(
        'Stored MOD calculator preferences are not JSON',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _update(ModCalculatorPreferences next) {
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
        modCalculatorPrefsKey,
        jsonEncode(state.toJson()),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save MOD calculator preferences',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _saving = false;
    }
  }

  ModModeInputs get _current => state.inputsFor(state.mode);

  void _updateCurrent(ModModeInputs inputs) =>
      _update(state.withInputs(state.mode, inputs));

  ModLimitOverrides get _overrides => state.overridesFor(_diverId());

  void _updateOverrides(ModLimitOverrides overrides) =>
      _update(state.withOverrides(_diverId(), overrides));

  ModResolvedLimits get _resolved => resolveModLimits(_overrides, _profile());

  void setMode(ModCalculatorMode mode) => _update(state.copyWith(mode: mode));

  /// Also pulls helium back into the room the new oxygen leaves.
  void setO2Percent(double o2) {
    final he = _current.hePercent.clamp(0.0, 100.0 - o2).toDouble();
    _updateCurrent(_current.copyWith(o2Percent: o2, hePercent: he));
  }

  void setHePercent(double he) => _updateCurrent(
    _current.copyWith(
      hePercent: he.clamp(0.0, 100.0 - _current.o2Percent).toDouble(),
    ),
  );

  void setTargetDepth(double meters) =>
      _updateCurrent(_current.copyWith(targetDepthMeters: meters));

  void setCheckTargetDepth(bool check) =>
      _updateCurrent(_current.copyWith(checkTargetDepth: check));

  void setWaterType(WaterType type) => _update(state.copyWith(waterType: type));

  void setMinPpO2(double ppO2) => _update(state.copyWith(minPpO2: ppO2));

  /// Working and deco are never inverted, the rule the profile keeps:
  /// raising working pulls deco up with it, lowering deco pulls working
  /// down. A value equal to the profile's is stored as "follow the profile".
  void setWorkingPpO2(double ppO2) =>
      _setWorkingDeco(ppO2, math.max(_resolved.decoPpO2, ppO2));

  void setDecoPpO2(double ppO2) =>
      _setWorkingDeco(math.min(_resolved.workingPpO2, ppO2), ppO2);

  void resetWorkingPpO2() {
    final working = _profile().workingPpO2;
    _setWorkingDeco(working, math.max(_resolved.decoPpO2, working));
  }

  void resetDecoPpO2() {
    final deco = _profile().decoPpO2;
    _setWorkingDeco(math.min(_resolved.workingPpO2, deco), deco);
  }

  void _setWorkingDeco(double working, double deco) => _updateOverrides(
    _overrides.withLimits(
      workingPpO2: working,
      decoPpO2: deco,
      profile: _profile(),
    ),
  );

  void setFlushPpO2(double ppO2) =>
      _updateOverrides(_overrides.withFlushPpO2(ppO2, _profile()));

  void resetFlushPpO2() =>
      _updateOverrides(_overrides.withFlushPpO2(null, _profile()));

  void setSetpoint(double bar) =>
      _updateOverrides(_overrides.withSetpoint(bar, _profile()));

  void resetSetpoint() =>
      _updateOverrides(_overrides.withSetpoint(null, _profile()));

  void reset() => _update(ModCalculatorPreferences.defaults);

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

final modCalculatorNotifierProvider =
    StateNotifierProvider<ModCalculatorNotifier, ModCalculatorPreferences>((
      ref,
    ) {
      final repository = ref.read(appSettingsRepositoryProvider);
      final notifier = ModCalculatorNotifier(
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

/// The water type the Tec modes use: the diver's choice, else the planner's
/// default. A custom salinity maps to salt, the sea water it defaults to.
WaterType modCalculatorWaterType(
  ModCalculatorPreferences prefs,
  AppSettings settings,
) =>
    prefs.waterType ??
    switch (settings.defaultPlannerWaterType) {
      PlannerWaterType.fresh => WaterType.fresh,
      PlannerWaterType.salt || PlannerWaterType.custom => WaterType.salt,
    };

/// The profile's CCR high setpoint, held to the calculator's setpoint range.
///
/// The profile allows 0.5-1.6 bar; the calculator's slider 0.4-1.6. A
/// profile value outside it is computed at the nearest edge, so what the
/// slider shows is what the numbers are computed for.
double modProfileSetpoint(AppSettings settings) => settings.ccrSetpointHigh
    .clamp(modSetpointMinBar, modSetpointMaxBar)
    .toDouble();

/// The profile's CCR diluent MOD ppO2. The calculator offers the profile's
/// own 0.5-1.6 bar range, so a stored value is never raised to a deeper
/// MOD; the clamp only guards a value from outside that range.
double modProfileFlushPpO2(AppSettings settings) => settings.ccrDiluentModPpO2
    .clamp(modFlushPpO2Min, modFlushPpO2Max)
    .toDouble();

/// The active diver's profile limits: the OC ppO2 limits for Rec and OC
/// Tec, the CCR ppO2 limits for CCR Tec.
ModProfileLimits modProfileLimits(AppSettings settings) => ModProfileLimits(
  workingPpO2: settings.ppO2MaxWorking,
  decoPpO2: settings.ppO2MaxDeco,
  flushPpO2: modProfileFlushPpO2(settings),
  setpointBar: modProfileSetpoint(settings),
);

/// The ppO2 limits in effect for the active diver, and which of them differ
/// from their profile.
final modCalculatorLimitsProvider = Provider<ModResolvedLimits>((ref) {
  final prefs = ref.watch(modCalculatorNotifierProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final settings = ref.watch(settingsProvider);
  return resolveModLimits(
    prefs.overridesFor(diverId),
    modProfileLimits(settings),
  );
});

/// The calculator inputs with every override resolved against the active
/// diver's profile.
final modCalculatorInputsProvider = Provider<GasLimitsInputs>((ref) {
  final prefs = ref.watch(modCalculatorNotifierProvider);
  final settings = ref.watch(settingsProvider);
  final limits = ref.watch(modCalculatorLimitsProvider);
  final mode = prefs.inputsFor(prefs.mode);
  return GasLimitsInputs(
    mode: prefs.mode,
    o2Percent: mode.o2Percent,
    hePercent: mode.hePercent,
    workingPpO2: limits.workingPpO2,
    decoPpO2: limits.decoPpO2,
    flushPpO2: limits.flushPpO2,
    setpointBar: limits.setpointBar,
    minPpO2: prefs.minPpO2,
    endLimitMeters: settings.endLimit,
    o2Narcotic: settings.o2Narcotic,
    targetDepthMeters: mode.checkTargetDepth ? mode.targetDepthMeters : null,
    waterType: modCalculatorWaterType(prefs, settings),
  );
});

final modCalculatorResultProvider = Provider<GasLimitsResult>(
  (ref) => computeGasLimits(ref.watch(modCalculatorInputsProvider)),
);
