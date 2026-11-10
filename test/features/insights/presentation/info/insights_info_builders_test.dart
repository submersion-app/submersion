import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/info/insights_card_info.dart';
import 'package:submersion/features/insights/presentation/info/trend_chart_info.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String label(DiveTerm term) => diveTermEntry(l10n, units, term).term;
  List<String> labels(InfoContent content) =>
      content.terms.map((e) => e.term).toList();

  InfoContent trend(TrendChartSettings settings, TrendGapThreshold gaps) =>
      trendChartInfo(
        l10n,
        units,
        title: 'Maximum Depth Progression',
        summary: 'Depth over time.',
        settings: settings,
        gaps: gaps,
      );

  group('trend chart', () {
    test('rolling average off gives no rolling average term', () {
      final content = trend(
        const TrendChartSettings(showRollingMean: false),
        TrendGapThreshold.off,
      );
      expect(labels(content), isNot(contains(label(DiveTerm.rollingAverage))));
      expect(content.howToUse, isNotNull);
    });

    test('overall trend on brings the per-year rate', () {
      final content = trend(
        const TrendChartSettings(showLinearFit: true),
        TrendGapThreshold.off,
      );
      expect(labels(content), contains(label(DiveTerm.overallTrend)));
      expect(labels(content), contains(label(DiveTerm.perYearRate)));
    });

    test('weekly grouping adds the range band, per dive does not', () {
      final weekly = trend(
        const TrendChartSettings(aggregation: TrendAggregation.weekly),
        TrendGapThreshold.off,
      );
      final perDive = trend(
        const TrendChartSettings(aggregation: TrendAggregation.none),
        TrendGapThreshold.off,
      );
      expect(labels(weekly), contains(label(DiveTerm.rangeBand)));
      expect(labels(perDive), isNot(contains(label(DiveTerm.rangeBand))));
    });

    test('collapsed gaps are explained only when on', () {
      final on = trend(const TrendChartSettings(), TrendGapThreshold.year1);
      final off = trend(const TrendChartSettings(), TrendGapThreshold.off);
      expect(labels(on), contains(label(DiveTerm.collapseGaps)));
      expect(labels(off), isNot(contains(label(DiveTerm.collapseGaps))));
    });
  });

  group('focus', () {
    test('lists CNS only when CNS is the measure', () {
      final cns = focusInfo(l10n, units, metric: FocusMetric.cns);
      final depth = focusInfo(l10n, units, metric: FocusMetric.maxDepth);
      expect(labels(cns), contains(label(DiveTerm.cns)));
      expect(labels(depth), isNot(contains(label(DiveTerm.cns))));
      expect(labels(depth), isNot(contains(label(DiveTerm.otu))));
      expect(cns.howToUse, isNotNull);
    });
  });

  test('overview says Avg Depth averages each dive maximum depth', () {
    final content = overviewStatsInfo(l10n, units);
    final avg = content.terms.firstWhere(
      (e) => e.term == label(DiveTerm.avgMaxDepth),
    );
    expect(avg.body, contains("each dive's maximum depth"));
  });

  test('exposure explains only the chosen unit', () {
    final salt = exposureInfo(l10n, units, unit: ExposureUnit.saltHours);
    final dives = exposureInfo(l10n, units, unit: ExposureUnit.dives);
    expect(labels(salt), [label(DiveTerm.saltWaterHours)]);
    expect(dives.terms, isEmpty);
  });

  test('gas lane terms follow the lane', () {
    expect(gasLaneTerms(isRmv: true), [DiveTerm.rmv]);
    expect(gasLaneTerms(isRmv: false), [DiveTerm.sac]);
  });

  test('rebreather gas use explains the diluent only with its line', () {
    expect(ccrGasUseTerms(showsDiluent: true), contains(DiveTerm.diluent));
    expect(
      ccrGasUseTerms(showsDiluent: false),
      isNot(contains(DiveTerm.diluent)),
    );
    expect(ccrGasUseTerms(showsDiluent: false), contains(DiveTerm.rmv));
  });
}
