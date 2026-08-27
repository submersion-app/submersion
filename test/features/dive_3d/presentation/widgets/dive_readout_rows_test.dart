import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const data = Dive3dSceneData(
    diveId: 'd1',
    times: [0, 100],
    depths: [0, 20],
    temperatures: [20, 10],
    ascentRates: [null, null],
    ppO2s: [0.21, 0.63],
    cnss: [0, 10],
    heartRates: [null, null],
    ceilings: [null, 6.0],
    ttss: [null, 600],
    tankPressures: {
      't1': [
        TankPressurePoint(id: 'p1', tankId: 't1', timestamp: 0, pressure: 200),
        TankPressurePoint(
          id: 'p2',
          tankId: 't1',
          timestamp: 100,
          pressure: 100,
        ),
      ],
    },
    gasSwitches: [],
    bookmarkEvents: [],
    photos: [],
    durationSeconds: 100,
    maxDepthMeters: 20,
  );

  test('rows at mid-dive, tank row and emphasis', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final rows = diveReadoutRows(
      lookups: DiveReadoutLookups(data),
      timestampSeconds: 50,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
      emphasize: SceneMetric.temperature,
    );
    final byLabel = {for (final r in rows) r.label: r};
    expect(rows.first.label, 'Run time');
    expect(rows.first.value, '0:50');
    expect(byLabel['Depth']!.value, startsWith('10.0'));
    expect(byLabel['Temp']!.value, startsWith('15'));
    expect(byLabel['Temp']!.emphasized, isTrue);
    expect(byLabel['Depth']!.emphasized, isFalse);
    expect(byLabel['ppO2']!.value, '0.42');
    expect(byLabel['CNS']!.value, '5%');
    expect(byLabel['Tank 1']!.value, startsWith('150'));
    // Ceiling and TTS are null at t=0 so interpolation yields nothing.
    expect(byLabel.containsKey('Ceiling'), isFalse);
    expect(byLabel.containsKey('Ascent'), isFalse);
  });

  test('ceiling and tts appear once both neighbors carry values', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final rows = diveReadoutRows(
      lookups: DiveReadoutLookups(data),
      timestampSeconds: 100,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
    );
    final byLabel = {for (final r in rows) r.label: r};
    expect(byLabel['Ceiling']!.value, startsWith('6.0'));
    expect(byLabel['TTS']!.value, '10 min');
  });

  test('lookups hold one entry per tank, null for an empty series', () {
    const twoTanks = Dive3dSceneData(
      diveId: 'd1',
      times: [0, 100],
      depths: [0, 20],
      temperatures: [20, 10],
      ascentRates: [null, null],
      ppO2s: [null, null],
      cnss: [null, null],
      heartRates: [null, null],
      ceilings: [null, null],
      ttss: [null, null],
      tankPressures: {
        'empty': [],
        't2': [
          TankPressurePoint(
            id: 'p1',
            tankId: 't2',
            timestamp: 0,
            pressure: 200,
          ),
          TankPressurePoint(
            id: 'p2',
            tankId: 't2',
            timestamp: 100,
            pressure: 100,
          ),
        ],
      },
      gasSwitches: [],
      bookmarkEvents: [],
      photos: [],
      durationSeconds: 100,
      maxDepthMeters: 20,
    );
    final lookups = DiveReadoutLookups(twoTanks);
    expect(identical(lookups.data, twoTanks), isTrue);
    expect(lookups.tankPressure, hasLength(2));
    expect(lookups.tankPressure[0], isNull);
    expect(lookups.tankPressure[1], isNotNull);
  });

  test(
    'an empty tank still consumes its number so labels stay stable',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      const twoTanks = Dive3dSceneData(
        diveId: 'd1',
        times: [0, 100],
        depths: [0, 20],
        temperatures: [null, null],
        ascentRates: [null, null],
        ppO2s: [null, null],
        cnss: [null, null],
        heartRates: [null, null],
        ceilings: [null, null],
        ttss: [null, null],
        tankPressures: {
          'empty': [],
          't2': [
            TankPressurePoint(
              id: 'p1',
              tankId: 't2',
              timestamp: 0,
              pressure: 200,
            ),
            TankPressurePoint(
              id: 'p2',
              tankId: 't2',
              timestamp: 100,
              pressure: 100,
            ),
          ],
        },
        gasSwitches: [],
        bookmarkEvents: [],
        photos: [],
        durationSeconds: 100,
        maxDepthMeters: 20,
      );
      final rows = diveReadoutRows(
        lookups: DiveReadoutLookups(twoTanks),
        timestampSeconds: 50,
        units: const UnitFormatter(AppSettings()),
        l10n: l10n,
      );
      final labels = rows.map((r) => r.label).toList();
      expect(labels, contains('Tank 2'));
      expect(labels, isNot(contains('Tank 1')));
    },
  );

  test('the per-tick series are derived once, not per call', () {
    final lookups = DiveReadoutLookups(data);
    // Same instances on every read: the row builder must only interpolate.
    expect(identical(lookups.depths, lookups.depths), isTrue);
    expect(identical(lookups.ttsSeconds, lookups.ttsSeconds), isTrue);
    // And they are NOT the getter, which rebuilds the series each time.
    expect(identical(data.ttsSeconds, data.ttsSeconds), isFalse);
    expect(lookups.ttsSeconds, data.ttsSeconds);
    expect(lookups.depths, data.depths);
  });
}
