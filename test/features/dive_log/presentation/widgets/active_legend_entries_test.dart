import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_legend_entries.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _tanks = [
  DiveTank(id: 'tank-1', name: 'D80', gasMix: GasMix(o2: 21), order: 0),
  DiveTank(id: 'tank-2', name: 'AL80', gasMix: GasMix(o2: 50), order: 1),
];

const _tankPressures = {
  'tank-1': [TankPressurePoint(tankId: 'tank-1', timestamp: 0, pressure: 200)],
  'tank-2': [TankPressurePoint(tankId: 'tank-2', timestamp: 0, pressure: 200)],
};

/// Builds the entries under a real localized context and hands them back.
Future<List<ActiveLegendEntry>> _entries(
  WidgetTester tester, {
  required ProfileLegendConfig config,
  required ProfileLegendState state,
}) async {
  late List<ActiveLegendEntry> result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          result = activeLegendEntries(context, config: config, state: state);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('activeLegendEntries', () {
    testWidgets('lists only metrics that are both available and switched on', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasHeartRateData: true,
          hasCeilingCurve: true,
          hasTtsData: true,
        ),
        state: const ProfileLegendState(
          showTemperature: true,
          showHeartRate: false,
          showCeiling: true,
          showTts: true,
        ),
      );

      expect(entries.map((e) => e.label), ['Temp', 'Ceiling', 'TTS']);
    });

    testWidgets('ignores switched-on metrics the dive has no data for', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(),
        state: const ProfileLegendState(showTts: true, showGtr: true),
      );

      expect(entries, isEmpty);
    });

    testWidgets('colours each entry like its line on the chart', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          hasCeilingCurve: true,
          hasTtsData: true,
          hasGasSwitches: true,
          hasMaxDepthMarker: true,
        ),
        state: const ProfileLegendState(
          showCeiling: true,
          showTts: true,
          showGasSwitchMarkers: true,
          showMaxDepthMarker: true,
        ),
      );

      final byLabel = {for (final e in entries) e.label: e.color};
      expect(byLabel['Ceiling'], ProfileMetricColors.ceiling);
      expect(byLabel['TTS'], ProfileMetricColors.tts);
      expect(byLabel['Gas Switches'], GasColors.nitrox);
      expect(byLabel['Max Depth'], ProfileMetricColors.maxDepth);
    });

    testWidgets('uses one entry per visible tank on multi-tank dives, '
        'not the single Pressure entry', (tester) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          hasPressureData: true,
          hasMultiTankPressure: true,
          tanks: _tanks,
          tankPressures: _tankPressures,
          estimatedTankIds: {'tank-2'},
        ),
        state: const ProfileLegendState(
          showPressure: true,
          showTankPressure: {'tank-1': true, 'tank-2': true},
        ),
      );

      final labels = entries.map((e) => e.label).toList();
      expect(labels, isNot(contains('Pressure')));
      expect(labels, contains('D80 (Air)'));
      expect(labels, contains('AL80 (EAN50) (est.)'));
      expect(
        entries.firstWhere((e) => e.label == 'D80 (Air)').color,
        GasColors.forGasMix(const GasMix(o2: 21)),
      );
    });

    testWidgets('drops a tank the user has hidden', (tester) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          hasMultiTankPressure: true,
          tanks: _tanks,
          tankPressures: _tankPressures,
        ),
        state: const ProfileLegendState(
          showTankPressure: {'tank-1': true, 'tank-2': false},
        ),
      );

      expect(entries.map((e) => e.label), ['D80 (Air)']);
    });

    testWidgets('treats a tank with no recorded preference as visible', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          hasMultiTankPressure: true,
          tanks: _tanks,
          tankPressures: _tankPressures,
        ),
        state: const ProfileLegendState(),
      );

      expect(entries, hasLength(2));
    });

    testWidgets('leaves out depth, the gas strip and display behaviour', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(hasGasData: true),
        state: const ProfileLegendState(
          showGas: true,
          metricsFollowViewport: true,
        ),
      );

      expect(entries, isEmpty);
    });
  });

  group('activeLegendEntries on multi-source dives', () {
    const overlay = LegendOverlaySource(
      name: 'Suunto',
      metrics: {LegendMetric.depth, LegendMetric.ceiling, LegendMetric.tts},
    );

    testWidgets('lists depth once per source, active source first', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          activeSourceName: 'Perdix',
          overlays: [overlay],
        ),
        // Ceiling is on by default and the overlay has one; turn it off so
        // only the depth entries remain.
        state: const ProfileLegendState(showCeiling: false),
      );

      expect(entries.map((e) => e.label), ['Depth · Perdix', 'Depth · Suunto']);
      expect(entries[0].color, ProfileMetricColors.depth);
      expect(entries[1].color, overlayTint(ProfileMetricColors.depth, 0));
    });

    testWidgets('follows each active metric with the overlays that draw it', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          activeSourceName: 'Perdix',
          overlays: [overlay],
          hasCeilingCurve: true,
          hasTtsData: true,
          hasNdlData: true,
        ),
        state: const ProfileLegendState(
          showCeiling: true,
          showTts: true,
          showNdl: true,
        ),
      );

      expect(entries.map((e) => e.label), [
        'Depth · Perdix',
        'Depth · Suunto',
        'Ceiling · Perdix',
        'Ceiling · Suunto',
        // The overlay has no NDL data, so only the active source is listed.
        'NDL · Perdix',
        'TTS · Perdix',
        'TTS · Suunto',
      ]);
      expect(
        entries.firstWhere((e) => e.label == 'TTS · Suunto').color,
        overlayTint(ProfileMetricColors.tts, 0),
      );
    });

    testWidgets('a switched-off metric hides every source\'s entry', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          activeSourceName: 'Perdix',
          overlays: [overlay],
          hasCeilingCurve: true,
        ),
        state: const ProfileLegendState(showCeiling: false),
      );

      expect(entries.map((e) => e.label), ['Depth · Perdix', 'Depth · Suunto']);
    });

    testWidgets('lists an overlay trace even when the active source lacks '
        'that metric', (tester) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          activeSourceName: 'Perdix',
          overlays: [overlay],
          hasTtsData: false,
        ),
        state: const ProfileLegendState(showTts: true),
      );

      final labels = entries.map((e) => e.label).toList();
      expect(labels, contains('TTS · Suunto'));
      expect(labels, isNot(contains('TTS · Perdix')));
    });

    testWidgets('leaves active-source-only metrics unsuffixed', (tester) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          activeSourceName: 'Perdix',
          overlays: [overlay],
          hasHeartRateData: true,
        ),
        state: const ProfileLegendState(showHeartRate: true),
      );

      expect(entries.map((e) => e.label), contains('Heart Rate'));
    });

    testWidgets(
      'leaves the active source unsuffixed when its name is unknown',
      (tester) async {
        final entries = await _entries(
          tester,
          config: const ProfileLegendConfig(overlays: [overlay]),
          state: const ProfileLegendState(showCeiling: false),
        );

        expect(entries.map((e) => e.label), ['Depth', 'Depth · Suunto']);
      },
    );

    testWidgets('tints a second overlay one step lighter than the first', (
      tester,
    ) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          overlays: [
            overlay,
            LegendOverlaySource(name: 'Teric', metrics: {LegendMetric.depth}),
          ],
        ),
        state: const ProfileLegendState(showCeiling: false),
      );

      expect(entries.map((e) => e.label), [
        'Depth',
        'Depth · Suunto',
        'Depth · Teric',
      ]);
      expect(entries[2].color, overlayTint(ProfileMetricColors.depth, 1));
    });

    testWidgets('uses the overlay\'s own colour when it is not tinted by '
        'metric', (tester) async {
      final entries = await _entries(
        tester,
        config: const ProfileLegendConfig(
          overlays: [
            LegendOverlaySource(
              name: 'Plan',
              metrics: {LegendMetric.depth},
              tintByMetric: false,
              color: Colors.purple,
            ),
          ],
        ),
        state: const ProfileLegendState(),
      );

      expect(entries.last.label, 'Depth · Plan');
      expect(entries.last.color, Colors.purple);
    });
  });
}
