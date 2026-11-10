import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
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

  group('formatPinnedStripValues', () {
    final l10n = AppLocalizationsEn();
    const metric = UnitFormatter(AppSettings());
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    test('metric format', () {
      const v = PinnedStripValues(
        runtimeSeconds: 1394,
        depthMeters: 18.2,
        ppO2Bar: 1.12,
        deco: NdlSlot(840),
      );
      expect(formatPinnedStripValues(v, metric, l10n), [
        '23:14',
        '18.2m',
        'ppO2 1.12',
        'NDL 14 min',
      ]);
    });

    test('a stop shows its depth and rounded-up minutes', () {
      const v = PinnedStripValues(
        runtimeSeconds: 61,
        depthMeters: 6,
        ppO2Bar: 0.8,
        deco: StopSlot(depthMeters: 6, durationSeconds: 150),
      );
      expect(formatPinnedStripValues(v, metric, l10n).last, 'Stop 6m · 3 min');
    });

    test('imperial depth and stop in feet', () {
      const v = PinnedStripValues(
        runtimeSeconds: 61,
        depthMeters: 6,
        ppO2Bar: 0.8,
        deco: StopSlot(depthMeters: 6, durationSeconds: 180),
      );
      final out = formatPinnedStripValues(v, imperial, l10n);
      expect(out[1], '19.7ft');
      expect(out.last, 'Stop 20ft · 3 min');
    });

    test('missing values are dashes', () {
      const v = PinnedStripValues(
        runtimeSeconds: 0,
        depthMeters: null,
        ppO2Bar: null,
        deco: UnknownDecoSlot(),
      );
      expect(formatPinnedStripValues(v, metric, l10n), [
        '0:00',
        '--',
        'ppO2 --',
        '--',
      ]);
    });
  });
}
