import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name the chart's legend gives [metric].
String profileMetricLabel(AppLocalizations l10n, ProfileMetric metric) =>
    switch (metric) {
      ProfileMetric.depth => l10n.diveLog_legend_label_depth,
      ProfileMetric.temperature => l10n.diveLog_legend_label_temp,
      ProfileMetric.pressure => l10n.diveLog_legend_label_pressure,
      ProfileMetric.heartRate => l10n.diveLog_legend_label_heartRate,
      ProfileMetric.sac => l10n.diveLog_legend_label_sacRate,
      ProfileMetric.maxDepth => l10n.diveLog_legend_label_maxDepth,
      ProfileMetric.ceiling => l10n.diveLog_legend_label_ceiling,
      ProfileMetric.ndl => l10n.diveLog_legend_label_ndl,
      ProfileMetric.tts => l10n.diveLog_legend_label_tts,
      ProfileMetric.gtr => l10n.diveLog_legend_label_gtr,
      ProfileMetric.cns => l10n.diveLog_legend_label_cns,
      ProfileMetric.otu => l10n.diveLog_legend_label_otu,
      ProfileMetric.ppO2 => l10n.diveLog_legend_label_ppO2,
      ProfileMetric.ppN2 => l10n.diveLog_legend_label_ppN2,
      ProfileMetric.ppHe => l10n.diveLog_legend_label_ppHe,
      ProfileMetric.mod => l10n.diveLog_legend_label_mod,
      ProfileMetric.density => l10n.diveLog_legend_label_gasDensity,
      ProfileMetric.gf => l10n.diveLog_legend_label_gfPercent,
      ProfileMetric.surfaceGf => l10n.diveLog_legend_label_surfaceGf,
      ProfileMetric.meanDepth => l10n.diveLog_legend_label_meanDepth,
    };
