import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MOD Calculator State (issue #2342)
// ═══════════════════════════════════════════════════════════════════════════

/// Key of the calculator's preferences in the synced `settings` table.
const String modCalculatorPrefsKey = 'gas_mod_calculator_prefs';

const _log = LoggerService('ModCalculatorPreferences');

/// The MOD calculator's inputs, restored on first use and saved after every
/// change, like the blender's preferences.
///
/// Saves are debounced: dragging a slider is one database write once it
/// settles, not one per frame.
class ModCalculatorNotifier extends StateNotifier<ModCalculatorPreferences> {
  ModCalculatorNotifier(this._repository)
    : super(ModCalculatorPreferences.defaults) {
    unawaited(_load());
  }

  final AppSettingsRepository _repository;
  Timer? _saveTimer;

  /// Set once the diver changes anything, so a load that finishes late never
  /// overwrites an edit made meanwhile.
  bool _edited = false;

  static const Duration saveDelay = Duration(milliseconds: 500);

  Future<void> _load() async {
    final raw = await _repository.getRawSetting(modCalculatorPrefsKey);
    if (raw == null || _edited || !mounted) return;
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
    _edited = true;
    state = next;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(_save()));
  }

  /// A failed write is logged rather than propagated: the value the diver
  /// chose is live in the calculator either way.
  Future<void> _save() async {
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
    }
  }

  ModModeInputs get _current => state.inputsFor(state.mode);

  void _updateCurrent(ModModeInputs inputs) =>
      _update(state.withInputs(state.mode, inputs));

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

  /// Like the ppO2 limits: a value equal to the profile's high setpoint
  /// clears the override.
  void setSetpoint(double bar, {required double profileValue}) => _update(
    _sameAs(bar, profileValue)
        ? state.copyWith(clearSetpoint: true)
        : state.copyWith(setpointBar: bar),
  );

  void resetSetpoint() => _update(state.copyWith(clearSetpoint: true));

  void setTargetDepth(double meters) =>
      _updateCurrent(_current.copyWith(targetDepthMeters: meters));

  void setCheckTargetDepth(bool check) =>
      _updateCurrent(_current.copyWith(checkTargetDepth: check));

  void setWaterType(WaterType type) => _update(state.copyWith(waterType: type));

  void setMinPpO2(double ppO2) => _update(state.copyWith(minPpO2: ppO2));

  /// A value equal to the profile's clears the override, so the calculator
  /// follows later profile changes again.
  void setWorkingPpO2(double ppO2, {required double profileValue}) => _update(
    _sameAs(ppO2, profileValue)
        ? state.copyWith(clearWorkingPpO2: true)
        : state.copyWith(workingPpO2: ppO2),
  );

  void setDecoPpO2(double ppO2, {required double profileValue}) => _update(
    _sameAs(ppO2, profileValue)
        ? state.copyWith(clearDecoPpO2: true)
        : state.copyWith(decoPpO2: ppO2),
  );

  void setFlushPpO2(double ppO2, {required double profileValue}) => _update(
    _sameAs(ppO2, profileValue)
        ? state.copyWith(clearFlushPpO2: true)
        : state.copyWith(flushPpO2: ppO2),
  );

  void resetWorkingPpO2() => _update(state.copyWith(clearWorkingPpO2: true));
  void resetDecoPpO2() => _update(state.copyWith(clearDecoPpO2: true));
  void resetFlushPpO2() => _update(state.copyWith(clearFlushPpO2: true));

  void reset() => _update(ModCalculatorPreferences.defaults);

  static bool _sameAs(double a, double b) => (a - b).abs() < 1e-9;

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
    StateNotifierProvider<ModCalculatorNotifier, ModCalculatorPreferences>(
      (ref) => ModCalculatorNotifier(ref.read(appSettingsRepositoryProvider)),
    );

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

/// The profile's CCR diluent MOD ppO2, held to the calculator's ppO2 range
/// for the same reason.
double modProfileFlushPpO2(AppSettings settings) => settings.ccrDiluentModPpO2
    .clamp(modLimitPpO2Min, modLimitPpO2Max)
    .toDouble();

/// The calculator inputs with every override resolved against the active
/// diver's profile: the OC ppO2 limits for Rec and OC Tec, the CCR ppO2
/// limits for CCR Tec.
final modCalculatorInputsProvider = Provider<GasLimitsInputs>((ref) {
  final prefs = ref.watch(modCalculatorNotifierProvider);
  final settings = ref.watch(settingsProvider);
  final mode = prefs.inputsFor(prefs.mode);
  return GasLimitsInputs(
    mode: prefs.mode,
    o2Percent: mode.o2Percent,
    hePercent: mode.hePercent,
    workingPpO2: prefs.workingPpO2 ?? settings.ppO2MaxWorking,
    decoPpO2: prefs.decoPpO2 ?? settings.ppO2MaxDeco,
    flushPpO2: prefs.flushPpO2 ?? modProfileFlushPpO2(settings),
    setpointBar: prefs.setpointBar ?? modProfileSetpoint(settings),
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
