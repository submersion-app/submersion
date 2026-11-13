import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

DecoStatus _status({int ndl = 840, List<DecoStop> stops = const []}) =>
    DecoStatus(
      compartments: const [],
      ndlSeconds: ndl,
      ceilingMeters: ndl < 0 ? 4 : 0,
      ttsSeconds: 0,
      gfLow: 0.3,
      gfHigh: 0.7,
      decoStops: stops,
      currentDepthMeters: 20,
      ambientPressureBar: 3,
    );

void main() {
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 60, depth: 10),
    DiveProfilePoint(timestamp: 120, depth: 20),
    DiveProfilePoint(timestamp: 1394, depth: 18.2),
    DiveProfilePoint(timestamp: 1500, depth: 0),
  ];
  final analysis = ProfileAnalysis.empty().copyWith(
    ppO2Curve: [0.21, 0.42, 0.63, 1.12, 0.21],
    decoStatuses: [
      _status(),
      _status(),
      _status(),
      _status(ndl: 840),
      _status(),
    ],
  );

  group('pinnedStripValuesAt', () {
    test('null cursor gives null', () {
      expect(
        pinnedStripValuesAt(
          chartProfile: profile,
          analysis: analysis,
          cursorIndex: null,
        ),
        isNull,
      );
    });

    test('an index past the profile gives null', () {
      expect(
        pinnedStripValuesAt(
          chartProfile: profile,
          analysis: analysis,
          cursorIndex: 5,
        ),
        isNull,
      );
    });

    test('reads time, depth and ppO2 at the index from the chart profile', () {
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: analysis,
        cursorIndex: 3,
      )!;
      expect(v.runtimeSeconds, 1394);
      expect(v.depthMeters, 18.2);
      expect(v.ppO2Bar, 1.12);
    });

    test('NDL slot when the status at the index is not in deco', () {
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: analysis,
        cursorIndex: 3,
      )!;
      expect(v.deco, isA<NdlSlot>());
      expect((v.deco as NdlSlot).ndlSeconds, 840);
    });

    test('stop slot from the first deco stop when in deco', () {
      final inDeco = analysis.copyWith(
        decoStatuses: [
          for (var i = 0; i < 5; i++)
            _status(
              ndl: -1,
              stops: const [
                DecoStop(depthMeters: 6, durationSeconds: 180),
                DecoStop(depthMeters: 3, durationSeconds: 420),
              ],
            ),
        ],
      );
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: inDeco,
        cursorIndex: 2,
      )!;
      expect(v.deco, isA<StopSlot>());
      final stop = v.deco as StopSlot;
      expect(stop.depthMeters, 6);
      expect(stop.durationSeconds, 180);
    });

    test('in deco with no stops listed gives unknown', () {
      final inDeco = analysis.copyWith(
        decoStatuses: [for (var i = 0; i < 5; i++) _status(ndl: -1)],
      );
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: inDeco,
        cursorIndex: 2,
      )!;
      expect(v.deco, isA<UnknownDecoSlot>());
    });

    test('no analysis: time and depth only, ppO2 null, deco unknown', () {
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: null,
        cursorIndex: 1,
      )!;
      expect(v.runtimeSeconds, 60);
      expect(v.depthMeters, 10);
      expect(v.ppO2Bar, isNull);
      expect(v.deco, isA<UnknownDecoSlot>());
    });

    test('index past decoStatuses length gives unknown deco', () {
      final short = analysis.copyWith(decoStatuses: [_status()]);
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: short,
        cursorIndex: 3,
      )!;
      expect(v.deco, isA<UnknownDecoSlot>());
    });

    test('resolves against the chart profile, not a merged one', () {
      // The active source's own series: index 1 is 25 m at 90 s, where the
      // merged dive.profile has 10 m at 60 s (#543).
      const chartProfile = [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 90, depth: 25),
      ];
      final v = pinnedStripValuesAt(
        chartProfile: chartProfile,
        analysis: null,
        cursorIndex: 1,
      )!;
      expect(v.runtimeSeconds, 90);
      expect(v.depthMeters, 25);
    });
  });

  group('ceiling', () {
    final withCeiling = analysis.copyWith(
      ceilingCurve: [0.0, 0.0, 4.2, 5.1, 0.0],
    );

    test('reads the ceiling at the index', () {
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: withCeiling,
        cursorIndex: 3,
      )!;
      expect(v.ceilingMeters, 5.1);
    });

    test('a ceiling curve shorter than the index gives null', () {
      final v = pinnedStripValuesAt(
        chartProfile: profile,
        analysis: analysis.copyWith(ceilingCurve: [0.0]),
        cursorIndex: 3,
      )!;
      expect(v.ceilingMeters, isNull);
    });
  });

  group('pinnedStripTooltipRows', () {
    final l10n = AppLocalizationsEn();
    const metric = UnitFormatter(AppSettings());
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    List<String> labels(List<TooltipRow> rows) => [
      for (final r in rows) r.label,
    ];
    List<String> values(List<TooltipRow> rows) => [
      for (final r in rows) r.value,
    ];

    test('metric format', () {
      const v = PinnedStripValues(
        runtimeSeconds: 1394,
        depthMeters: 18.2,
        ppO2Bar: 1.12,
        deco: NdlSlot(840),
      );
      final rows = pinnedStripTooltipRows(v, metric, l10n);
      expect(labels(rows), ['Time', 'Depth', 'ppO2', 'NDL']);
      expect(values(rows), ['23:14', '18.2m', '1.12', '14 min']);
    });

    test('rows take the diver\'s chart colours', () {
      final palette = ProfileMetricPalette(
        overrides: const ProfileMetricColorOverrides().withColor(
          ProfileMetric.ndl,
          const Color(0xFF00FF00),
        ),
        temperatureAuto: const Color(0xFF000000),
      );
      const v = PinnedStripValues(
        runtimeSeconds: 1394,
        depthMeters: 18.2,
        ppO2Bar: 1.12,
        deco: NdlSlot(840),
      );
      final rows = pinnedStripTooltipRows(v, metric, l10n, palette: palette);
      expect(rows[3].bulletColor, const Color(0xFF00FF00));
    });

    test('rows carry the colours of the strip\'s lines', () {
      const v = PinnedStripValues(
        runtimeSeconds: 1394,
        depthMeters: 18.2,
        ppO2Bar: 1.12,
        deco: NdlSlot(840),
      );
      final rows = pinnedStripTooltipRows(v, metric, l10n);
      expect(rows[1].bulletColor, ProfileMetricColors.depth);
      expect(rows[2].bulletColor, ProfileMetricColors.ppO2);
      expect(rows[3].bulletColor, ProfileMetricColors.ndl);
    });

    // A second computer placed on the primary's timeline can start before
    // it (#4296), so the cursor's time can be negative.
    test('a time before the dive start keeps its sign', () {
      const v = PinnedStripValues(
        runtimeSeconds: -65,
        depthMeters: 0,
        ppO2Bar: null,
        deco: UnknownDecoSlot(),
      );
      expect(values(pinnedStripTooltipRows(v, metric, l10n)).first, '-1:05');
    });

    // At and near the surface the NDL is a 999-minute "unlimited" sentinel,
    // which read as broken spelled out (review M4).
    test('an NDL past 99 minutes reads as more than 99', () {
      const v = PinnedStripValues(
        runtimeSeconds: 30,
        depthMeters: 2,
        ppO2Bar: 0.25,
        deco: NdlSlot(999 * 60),
      );
      expect(values(pinnedStripTooltipRows(v, metric, l10n)).last, '>99 min');
    });

    test('an NDL of exactly 99 minutes is shown as it is', () {
      const v = PinnedStripValues(
        runtimeSeconds: 30,
        depthMeters: 2,
        ppO2Bar: 0.25,
        deco: NdlSlot(99 * 60),
      );
      expect(values(pinnedStripTooltipRows(v, metric, l10n)).last, '99 min');
    });

    test('in deco: Deco stop and Ceiling rows, no NDL row', () {
      const v = PinnedStripValues(
        runtimeSeconds: 1860,
        depthMeters: 6,
        ppO2Bar: 0.34,
        deco: StopSlot(depthMeters: 6, durationSeconds: 210),
        ceilingMeters: 5.1,
      );
      final rows = pinnedStripTooltipRows(v, metric, l10n);
      expect(labels(rows), ['Time', 'Depth', 'ppO2', 'Deco stop', 'Ceiling']);
      expect(rows[3].value, '6m · 4 min');
      expect(rows[4].value, '5.1m');
      expect(rows[3].bulletColor, decoStopBandColor);
      expect(rows[4].bulletColor, ProfileMetricColors.ceiling);
    });

    test('a stop shows its depth and rounded-up minutes', () {
      const v = PinnedStripValues(
        runtimeSeconds: 61,
        depthMeters: 6,
        ppO2Bar: 0.8,
        deco: StopSlot(depthMeters: 6, durationSeconds: 150),
      );
      expect(values(pinnedStripTooltipRows(v, metric, l10n))[3], '6m · 3 min');
    });

    test('imperial depth and stop in feet', () {
      const v = PinnedStripValues(
        runtimeSeconds: 61,
        depthMeters: 6,
        ppO2Bar: 0.8,
        deco: StopSlot(depthMeters: 6, durationSeconds: 180),
        ceilingMeters: 5,
      );
      final out = values(pinnedStripTooltipRows(v, imperial, l10n));
      expect(out[1], '19.7ft');
      expect(out[3], '20ft · 3 min');
      expect(out[4], '16.4ft');
    });

    test('missing values are dashes', () {
      const v = PinnedStripValues(
        runtimeSeconds: 0,
        depthMeters: null,
        ppO2Bar: null,
        deco: UnknownDecoSlot(),
      );
      final rows = pinnedStripTooltipRows(v, metric, l10n);
      expect(labels(rows), ['Time', 'Depth', 'ppO2', 'NDL']);
      expect(values(rows), ['0:00', '--', '--', '--']);
    });

    test('in deco with no ceiling known, the ceiling reads as a dash', () {
      const v = PinnedStripValues(
        runtimeSeconds: 61,
        depthMeters: 6,
        ppO2Bar: 0.8,
        deco: StopSlot(depthMeters: 6, durationSeconds: 180),
      );
      expect(values(pinnedStripTooltipRows(v, metric, l10n)).last, '--');
    });
  });
}
