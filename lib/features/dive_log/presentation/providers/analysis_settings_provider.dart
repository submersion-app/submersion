import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Every diver setting a profile analysis reads, captured once per analysis.
///
/// An analysis takes these as one explicit input instead of reading each
/// settings provider as it goes, so the whole run sees a single diver's
/// settings and its result can say which settings produced it ([fingerprint]).
/// Results that are persisted (the safety review, the deco classification
/// cache) store that fingerprint and are recomputed when it no longer matches
/// (issue #2592).
///
/// The per-metric sources change the curves a result is computed from, so
/// they are inputs like the rest. [analysisSettingsProvider] carries the
/// chart legend's (seeded from the diver's defaults, switchable per session);
/// [diverAnalysisSettingsProvider] carries the diver's defaults, and is what a
/// persisted result is keyed on.
class AnalysisSettings {
  const AnalysisSettings({
    required this.gfLow,
    required this.gfHigh,
    required this.ppO2MaxWorking,
    required this.ppO2MaxDeco,
    required this.cnsWarningThreshold,
    required this.ascentRateWarning,
    required this.ascentRateCritical,
    required this.lastStopDepth,
    required this.decoStopIncrement,
    required this.cnsCalculationMethod,
    required this.ascentGasSet,
    required this.gtrReservePressure,
    required this.ndlSource,
    required this.ttsSource,
    required this.cnsSource,
    required this.decoStopSource,
    required this.gtrSource,
  });

  /// Gradient factors as whole percentages. A dive that recorded both of its
  /// own overrides these, but they stay in the fingerprint for every dive:
  /// a needless recompute is the safe direction to err.
  final int gfLow;
  final int gfHigh;
  final double ppO2MaxWorking;
  final double ppO2MaxDeco;
  final int cnsWarningThreshold;
  final double ascentRateWarning;
  final double ascentRateCritical;
  final double lastStopDepth;
  final double decoStopIncrement;
  final CnsCalculationMethod cnsCalculationMethod;
  final AscentGasSet ascentGasSet;
  final double gtrReservePressure;
  final MetricDataSource ndlSource;
  final MetricDataSource ttsSource;
  final MetricDataSource cnsSource;
  final MetricDataSource decoStopSource;
  final MetricDataSource gtrSource;

  double get gfLowFraction => gfLow / 100.0;
  double get gfHighFraction => gfHigh / 100.0;

  /// A stable text identity of these settings, stored beside a persisted
  /// result. Equal settings give equal fingerprints on every device and run,
  /// so a synced result is not recomputed by a peer with the same settings.
  ///
  /// The leading version names the format: add a field and bump
  /// [fingerprintFormat], and every stored fingerprint stops matching once,
  /// which is what a new input needs.
  String get fingerprint => [
    'a$fingerprintFormat',
    'gf=$gfLow/$gfHigh',
    'ppo2=${_num(ppO2MaxWorking)}/${_num(ppO2MaxDeco)}',
    'cnsw=$cnsWarningThreshold',
    'asc=${_num(ascentRateWarning)}/${_num(ascentRateCritical)}',
    'stop=${_num(lastStopDepth)}/${_num(decoStopIncrement)}',
    'cnsm=${cnsCalculationMethod.name}',
    'gas=${ascentGasSet.name}',
    'gtr=${_num(gtrReservePressure)}',
    'src=${ndlSource.name}/${ttsSource.name}/${cnsSource.name}/'
        '${decoStopSource.name}/${gtrSource.name}',
  ].join(';');

  /// The [fingerprint] format this build writes.
  static const int fingerprintFormat = 1;

  /// Whether [fingerprint] was written in a format newer than this build's,
  /// by a newer peer. This build cannot tell whether such a fingerprint
  /// matches its own settings, so a result stored under it is kept rather
  /// than recomputed: recomputing would overwrite it, and the newer peer
  /// would recompute it back on every sync.
  static bool isNewerFormat(String fingerprint) {
    final match = RegExp(r'^a(\d+);').firstMatch(fingerprint);
    if (match == null) return false;
    return int.parse(match.group(1)!) > fingerprintFormat;
  }

  /// Whole values print without a fraction so `3` and `3.0` cannot differ.
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  AnalysisSettings copyWith({
    int? gfLow,
    int? gfHigh,
    double? ppO2MaxWorking,
    double? ppO2MaxDeco,
    int? cnsWarningThreshold,
    double? ascentRateWarning,
    double? ascentRateCritical,
    double? lastStopDepth,
    double? decoStopIncrement,
    CnsCalculationMethod? cnsCalculationMethod,
    AscentGasSet? ascentGasSet,
    double? gtrReservePressure,
    MetricDataSource? ndlSource,
    MetricDataSource? ttsSource,
    MetricDataSource? cnsSource,
    MetricDataSource? decoStopSource,
    MetricDataSource? gtrSource,
  }) => AnalysisSettings(
    gfLow: gfLow ?? this.gfLow,
    gfHigh: gfHigh ?? this.gfHigh,
    ppO2MaxWorking: ppO2MaxWorking ?? this.ppO2MaxWorking,
    ppO2MaxDeco: ppO2MaxDeco ?? this.ppO2MaxDeco,
    cnsWarningThreshold: cnsWarningThreshold ?? this.cnsWarningThreshold,
    ascentRateWarning: ascentRateWarning ?? this.ascentRateWarning,
    ascentRateCritical: ascentRateCritical ?? this.ascentRateCritical,
    lastStopDepth: lastStopDepth ?? this.lastStopDepth,
    decoStopIncrement: decoStopIncrement ?? this.decoStopIncrement,
    cnsCalculationMethod: cnsCalculationMethod ?? this.cnsCalculationMethod,
    ascentGasSet: ascentGasSet ?? this.ascentGasSet,
    gtrReservePressure: gtrReservePressure ?? this.gtrReservePressure,
    ndlSource: ndlSource ?? this.ndlSource,
    ttsSource: ttsSource ?? this.ttsSource,
    cnsSource: cnsSource ?? this.cnsSource,
    decoStopSource: decoStopSource ?? this.decoStopSource,
    gtrSource: gtrSource ?? this.gtrSource,
  );

  @override
  bool operator ==(Object other) =>
      other is AnalysisSettings && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;
}

/// The active diver's own [AnalysisSettings]: their stored settings, with
/// each per-metric source at the diver's default rather than the chart
/// legend's session toggle.
///
/// Persisted results (the safety review, the deco classification cache) key
/// on this and are saved only from an analysis that ran on exactly it.
/// Switching a source on the chart is a way of viewing one dive, not a change
/// to the diver's settings: keying on the legend would rewrite and re-sync a
/// review on every toggle, and a dismissed finding that stopped firing under
/// the toggled source would be tombstoned and come back undismissed.
///
/// Built from the individual settings providers (not [settingsProvider]
/// alone) so a test that overrides one of them still reaches the analysis.
/// Read it only after [awaitActiveDiverSettings]: until the active diver's
/// row loads, it reflects the defaults or, right after a diver switch, the
/// previous diver.
final diverAnalysisSettingsProvider = Provider<AnalysisSettings>((ref) {
  final sources = ref.watch(
    settingsProvider.select(
      (s) => (
        ndl: s.defaultNdlSource,
        tts: s.defaultTtsSource,
        cns: s.defaultCnsSource,
        decoStop: s.defaultDecoStopSource,
        gtr: s.defaultGtrSource,
        gtrReserve: s.gtrReservePressure,
      ),
    ),
  );
  return AnalysisSettings(
    gfLow: ref.watch(gfLowProvider),
    gfHigh: ref.watch(gfHighProvider),
    ppO2MaxWorking: ref.watch(ppO2MaxWorkingProvider),
    ppO2MaxDeco: ref.watch(ppO2MaxDecoProvider),
    cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
    ascentRateWarning: ref.watch(ascentRateWarningProvider),
    ascentRateCritical: ref.watch(ascentRateCriticalProvider),
    lastStopDepth: ref.watch(lastStopDepthProvider),
    decoStopIncrement: ref.watch(decoStopIncrementProvider),
    cnsCalculationMethod: ref.watch(cnsCalculationMethodProvider),
    ascentGasSet: ref.watch(ascentGasSetProvider),
    gtrReservePressure: sources.gtrReserve,
    ndlSource: sources.ndl,
    ttsSource: sources.tts,
    cnsSource: sources.cns,
    decoStopSource: sources.decoStop,
    gtrSource: sources.gtr,
  );
});

/// The [AnalysisSettings] the profile analysis runs on: the diver's own,
/// with the per-metric sources the chart legend currently shows. Equal to
/// [diverAnalysisSettingsProvider] until a source is switched on the chart.
///
/// Read it only after [awaitActiveDiverSettings], for the same reason.
final analysisSettingsProvider = Provider<AnalysisSettings>((ref) {
  return ref
      .watch(diverAnalysisSettingsProvider)
      .copyWith(
        ndlSource: ref.watch(profileLegendProvider.select((s) => s.ndlSource)),
        ttsSource: ref.watch(profileLegendProvider.select((s) => s.ttsSource)),
        cnsSource: ref.watch(profileLegendProvider.select((s) => s.cnsSource)),
        decoStopSource: ref.watch(
          profileLegendProvider.select((s) => s.decoStopSource),
        ),
        gtrSource: ref.watch(profileLegendProvider.select((s) => s.gtrSource)),
      );
});

/// Waits until the active diver's settings have loaded, including the reload
/// a diver switch starts ([SettingsNotifier.loaded]), so a following read of
/// [analysisSettingsProvider] or [diverAnalysisSettingsProvider] is that
/// diver's and not the placeholder or the previous diver's (issues #1859,
/// #2564).
///
/// Returns whether that load succeeded. A failed load is already logged by
/// the notifier and leaves [settingsProvider] holding whatever it held: the
/// placeholder defaults, or the previous diver's settings after a switch. An
/// analysis for display may still proceed on them, but nothing may be
/// persisted from it: a caller that saves a result checks this first.
Future<bool> awaitActiveDiverSettings(Ref ref) async {
  try {
    await ref.read(settingsProvider.notifier).loaded;
    return true;
  } catch (_) {
    // See the doc comment: already logged.
    return false;
  }
}
