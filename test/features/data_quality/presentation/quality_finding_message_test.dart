import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l10n;

  // Formatters tag their output so assertions can prove the raw numeric params
  // were routed through the unit formatter rather than hardcoded.
  final fmt = QualityUnitFormatters(
    depth: (m) => 'D${m.toStringAsFixed(1)}',
    depthRate: (mpm) => 'R${mpm.toStringAsFixed(1)}',
    limitDepth: (m) => 'L${m.toStringAsFixed(1)}',
    pressure: (bar) => 'P${bar.toStringAsFixed(1)}',
    temperature: (c) => 'T${c.toStringAsFixed(1)}',
    temperatureDelta: (c) => 'TD${c.toStringAsFixed(1)}',
    sac: (lpm) => 'S${lpm.toStringAsFixed(1)}',
    // Renders the UTC calendar date so assertions can prove the clock message
    // routes through the diver's date formatter rather than an ISO timestamp.
    date: (d) => 'DATE(${d.year}-${d.month}-${d.day})',
    dateTime: (d) =>
        'WHEN(${d.year}-${d.month}-${d.day} ${d.hour}:${d.minute})',
    time: (d) => 'TIME(${d.hour}:${d.minute})',
  );

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  QualityFinding finding(String detectorId, Map<String, Object?> params) =>
      QualityFinding(
        id: 'f-$detectorId',
        diveId: 'd1',
        detectorId: detectorId,
        detectorVersion: 1,
        category: QualityCategory.time,
        severity: QualitySeverity.warning,
        status: QualityStatus.open,
        params: params,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      );

  String detailFor(String detectorId, Map<String, Object?> params) =>
      buildFindingMessage(l10n, finding(detectorId, params), fmt).detail;

  group('detectorTitle', () {
    test('maps every known detector id to a non-id title', () {
      const ids = [
        'clock_offset',
        'duplicate',
        'split_pair',
        'sample_gap',
        'depth_spike',
        'impossible_rate',
        'temp_anomaly',
        'pressure_anomaly',
        'gas_mod',
        'tank_assignment',
        'missing_gas_switch',
        'source_conflict',
        'transmitter_role',
        'transmitter_gear_serial_mismatch',
      ];
      for (final id in ids) {
        final title = detectorTitle(l10n, id);
        expect(title, isNotEmpty);
        expect(title, isNot(equals(id)), reason: '$id should be localized');
      }
    });

    test('unknown detector id falls back to the id itself', () {
      expect(detectorTitle(l10n, 'nope'), 'nope');
    });
  });

  group('clock_offset', () {
    // The offset says which way the clock is off, and one hour is singular
    // (issue #4209).
    test('a positive offset is a clock running ahead', () {
      expect(
        detailFor('clock_offset', {'offsetHours': 3}),
        'A source clock runs 3 hours ahead',
      );
      expect(
        detailFor('clock_offset', {'offsetHours': 1}),
        'A source clock runs 1 hour ahead',
      );
    });

    test('a misplaced source reads how far it sits from its fit (#4296)', () {
      expect(
        detailFor('clock_offset', {
          'sourceId': 's2',
          'profileOffsetSeconds': -4020,
        }),
        "A source sits 67 min from where its profile matches the primary's",
      );
    });

    test('a negative offset is a clock running behind', () {
      expect(
        detailFor('clock_offset', {'offsetHours': -2}),
        'A source clock runs 2 hours behind',
      );
    });

    test('overlapMinutes branch', () {
      expect(detailFor('clock_offset', {'overlapMinutes': 12}), isNotEmpty);
    });

    test('ancient date branch uses UTC so year < 1950 classifies', () {
      final ancientDate = DateTime.utc(1900, 6);
      final ancient = detailFor('clock_offset', {
        'entryTimeMs': ancientDate.millisecondsSinceEpoch,
      });
      final future = detailFor('clock_offset', {
        'entryTimeMs': DateTime.utc(2100, 6).millisecondsSinceEpoch,
      });
      expect(ancient, isNotEmpty);
      expect(future, isNotEmpty);
      // Ancient vs future must produce different copy; if the UTC flag were
      // dropped the 1900 timestamp could drift and misclassify.
      expect(ancient, isNot(equals(future)));
      // The date renders through the diver's date formatter, not a raw ISO
      // timestamp: the formatter output appears and the ISO time/zone does not.
      expect(
        ancient,
        contains(
          'DATE(${ancientDate.year}-${ancientDate.month}-'
          '${ancientDate.day})',
        ),
      );
      expect(ancient, isNot(contains('Z')));
    });
  });

  // #3307: the drop goes through the diver's pressure formatter, so an
  // imperial diver reads psi.
  test('transmitter_role names the tank, its role and the OC drop', () {
    final detail = detailFor('transmitter_role', {
      'tankId': 'tx',
      'tankPosition': 1,
      'ocTankId': 'oc',
      'ocDropBar': 60.0,
      'role': 'oxygenSupply',
    });
    expect(detail, contains('Tank 2'));
    expect(detail, contains(l10n.enum_tankRole_oxygenSupply));
    expect(detail, contains('P60.0'));
  });

  test('duplicate renders score and time delta', () {
    expect(
      detailFor('duplicate', {'score': 0.92, 'timeDiffMinutes': 4}),
      isNotEmpty,
    );
  });

  test('split_pair renders gap in minutes', () {
    expect(detailFor('split_pair', {'gapSeconds': 180}), isNotEmpty);
  });

  test('sample_gap renders gap count and longest gap', () {
    expect(
      detailFor('sample_gap', {'gapCount': 3, 'longestGapSeconds': 45}),
      '3 gaps in samples, longest 45 s',
    );
  });

  group('qualityDurationLabel', () {
    test('keeps seconds below two minutes', () {
      expect(qualityDurationLabel(l10n, 0), '0 s');
      expect(qualityDurationLabel(l10n, 119), '119 s');
    });

    test('switches to whole minutes from two minutes on', () {
      expect(qualityDurationLabel(l10n, 120), '2 min');
      expect(qualityDurationLabel(l10n, 1620), '27 min');
      expect(qualityDurationLabel(l10n, 1650), '28 min');
    });
  });

  group('qualityGasLabel', () {
    test('air and oxygen use the localized gas names', () {
      expect(qualityGasLabel(l10n, 21, 0), l10n.gas_air_displayName);
      expect(qualityGasLabel(l10n, 100, 0), l10n.gas_oxygen_displayName);
    });

    test('nitrox and trimix keep their notation', () {
      expect(qualityGasLabel(l10n, 50, 0), 'EAN50');
      expect(qualityGasLabel(l10n, 18, 45), 'Tx 18/45');
    });

    test('a hypoxic helium-free mix reads as its oxygen share', () {
      expect(qualityGasLabel(l10n, 12, 0), '12% O2');
    });

    // A finding stored before helium was recorded could be a trimix; naming
    // its 21% "Air" would be a claim the finding cannot make.
    test('an unknown helium share names the oxygen share alone', () {
      expect(qualityGasLabel(l10n, 21, null), '21% O2');
      expect(qualityGasLabel(l10n, 32, null), '32% O2');
    });
  });

  group('depth_spike', () {
    test('max-depth mismatch routes both depths through the formatter', () {
      final d = detailFor('depth_spike', {
        'storedMaxDepth': 30.0,
        'profileMaxDepth': 42.0,
      });
      expect(d, contains('D30.0'));
      expect(d, contains('D42.0'));
    });

    test('negative depth branch', () {
      expect(
        detailFor('depth_spike', {'minDepth': -2.0, 'sampleCount': 5}),
        isNotEmpty,
      );
    });

    test('spike branch formats depth and mm:ss timestamp', () {
      final d = detailFor('depth_spike', {'depth': 55.0, 'atSeconds': 125});
      expect(d, contains('D55.0'));
      expect(d, contains('2:05'));
    });
  });

  test('impossible_rate routes the rate through the rate formatter', () {
    final d = detailFor('impossible_rate', {
      'maxRateMetersPerMinute': 30.0,
      'durationSeconds': 10,
    });
    expect(d, contains('R30.0'));
    expect(d, isNot(contains('/min')));
    expect(d, endsWith('for 10 s'));
  });

  test('impossible_rate renders a long run in minutes', () {
    final d = detailFor('impossible_rate', {
      'maxRateMetersPerMinute': 30.0,
      'durationSeconds': 1620,
    });
    expect(d, endsWith('for 27 min'));
  });

  group('temp_anomaly', () {
    // A jump is a difference; the absolute formatter would add the 32 degree
    // Fahrenheit offset to it (issue #4209).
    test('delta jump branch formats a difference', () {
      final d = detailFor('temp_anomaly', {'deltaC': 8.0});
      expect(d, contains('TD8.0'));
      expect(d, isNot(contains('T8.0')));
    });

    test('scalar branch', () {
      expect(
        detailFor('temp_anomaly', {'waterTempC': 45.0}),
        contains('T45.0'),
      );
    });

    test('range branch, plain', () {
      final d = detailFor('temp_anomaly', {'minTempC': 2.0, 'maxTempC': 40.0});
      expect(d, contains('T2.0'));
      expect(d, contains('T40.0'));
    });

    test('range branch appends unit-bug hint when suspected', () {
      final plain = detailFor('temp_anomaly', {
        'minTempC': 2.0,
        'maxTempC': 40.0,
      });
      final flagged = detailFor('temp_anomaly', {
        'minTempC': 2.0,
        'maxTempC': 40.0,
        'fahrenheitAsKelvinSuspected': true,
      });
      expect(flagged.length, greaterThan(plain.length));
    });
  });

  group('pressure_anomaly', () {
    test('swap branch reverses endpoints through the formatter', () {
      final d = detailFor('pressure_anomaly', {
        'startBar': 50.0,
        'endBar': 200.0,
      });
      expect(d, contains('P200.0'));
      expect(d, contains('P50.0'));
    });

    test('endpoint branch', () {
      final d = detailFor('pressure_anomaly', {
        'recordBar': 210.0,
        'seriesBar': 190.0,
      });
      expect(d, contains('P210.0'));
      expect(d, contains('P190.0'));
    });

    test('rise branch', () {
      expect(
        detailFor('pressure_anomaly', {'riseBar': 15.0}),
        contains('P15.0'),
      );
    });

    test('mixed branch names the two sources', () {
      expect(
        detailFor('pressure_anomaly', {'mixedSources': true, 'tankId': 't1'}),
        contains('two sources'),
      );
    });

    test('dropout branch counts the dropouts', () {
      expect(
        detailFor('pressure_anomaly', {'dropoutCount': 3, 'tankId': 't1'}),
        contains('3 times'),
      );
    });

    test(
      'SAC branch routes L/min through the sac formatter, not hardcoded',
      () {
        final d = detailFor('pressure_anomaly', {'surfaceLpm': 22.4});
        expect(d, contains('S22.4'));
        expect(d, isNot(contains('L/min')));
      },
    );
  });

  group('gas_mod', () {
    test('ppO2 branch', () {
      final d = detailFor('gas_mod', {
        'peakPpO2': 1.61,
        'o2Percent': 32.0,
        'hePercent': 0.0,
        'depthAtPeak': 40.0,
      });
      expect(d, contains('1.61'));
      expect(d, contains('EAN32'));
      expect(d, contains('D40.0'));
    });

    test('ppO2 branch keeps the helium of a trimix', () {
      final d = detailFor('gas_mod', {
        'peakPpO2': 1.7,
        'o2Percent': 18.0,
        'hePercent': 45.0,
        'depthAtPeak': 85.0,
      });
      expect(d, contains('Tx 18/45'));
    });

    test('ppO2 branch names oxygen as a gas, not EAN100', () {
      final d = detailFor('gas_mod', {
        'peakPpO2': 1.9,
        'o2Percent': 100.0,
        'hePercent': 0.0,
        'depthAtPeak': 9.0,
      });
      expect(d, contains(l10n.gas_oxygen_displayName));
      expect(d, isNot(contains('EAN100')));
    });

    test('switch/MOD branch', () {
      final d = detailFor('gas_mod', {'switchDepth': 25.0, 'modMeters': 22.0});
      expect(d, contains('D25.0'));
      // The MOD is a limit: it goes through the rounded-down formatter.
      expect(d, contains('L22.0'));
    });

    test('hypoxic-at-surface branch', () {
      expect(detailFor('gas_mod', {'o2Percent': 12.0}), contains('12% O2'));
      expect(
        detailFor('gas_mod', {'o2Percent': 10.0, 'hePercent': 70.0}),
        contains('Tx 10/70'),
      );
    });
  });

  group('missing_gas_switch (#165)', () {
    Map<String, Object?> start({
      required int number,
      required int t,
      required double depth,
      double o2 = 50,
      double? mod,
    }) => {
      'tankId': 't$number',
      // Stored 0-based; the text names cylinder [number].
      'tankPosition': number - 1,
      't': t,
      'depth': depth,
      'o2Percent': o2,
      'hePercent': 0.0,
      'modMeters': ?mod,
    };

    test('names the cylinder, gas, time and depth of each switch', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': [
          start(number: 2, t: 1800, depth: 21),
          start(number: 3, t: 2730, depth: 6, o2: 100),
        ],
        'deepStarts': const [],
      });
      expect(
        detail,
        'No gas switch was recorded, but the cylinder pressures show these '
        'switches: cylinder 2 (EAN50) at 30:00, D21.0; cylinder 3 (Oxygen) at '
        '45:30, D6.0.',
      );
    });

    test('a single switch reads in the singular', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': [start(number: 2, t: 1800, depth: 21)],
        'deepStarts': const [],
      });
      expect(
        detail,
        'No gas switch was recorded, but the cylinder pressures show this '
        'switch: cylinder 2 (EAN50) at 30:00, D21.0.',
      );
    });

    test('a start deeper than its MOD is named, never as a switch', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': const [],
        'deepStarts': [start(number: 2, t: 600, depth: 40, mod: 22)],
      });
      expect(
        detail,
        'No gas switch was recorded. The cylinder pressures show a change to '
        'cylinder 2 (EAN50) at D40.0, deeper than its MOD of L22.0, so no '
        'switch to it is suggested.',
      );
    });

    test('every too-deep start is named', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': const [],
        'deepStarts': [
          start(number: 2, t: 600, depth: 40, mod: 22),
          start(number: 3, t: 900, depth: 30, o2: 100, mod: 6),
        ],
      });
      expect(detail, contains('a change to cylinder 2 (EAN50) at D40.0'));
      expect(
        detail,
        endsWith(
          ' The cylinder pressures also show a change to cylinder 3 (Oxygen) '
          'at D30.0, deeper than its MOD of L6.0, so no switch to it is '
          'suggested.',
        ),
      );
    });

    test('a restart that cannot be placed says why no switch is offered', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': const [],
        'deepStarts': const [],
        'unplacedRestart': start(number: 2, t: 1800, depth: 6),
      });
      expect(
        detail,
        'No gas switch was recorded. Cylinder 2 (EAN50) was breathed again '
        'from 30:00 after a pause, so another cylinder was breathed in '
        'between, and with more than two cylinders the pressures cannot show '
        'which. Add the switches in the dive editor.',
      );
    });

    test('a too-deep start after an unplaced restart reads as also', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': const [],
        'deepStarts': [start(number: 3, t: 600, depth: 30, o2: 100, mod: 6)],
        'unplacedRestart': start(number: 2, t: 1800, depth: 6),
      });
      expect(detail, startsWith('No gas switch was recorded. Cylinder 2'));
      expect(
        detail,
        endsWith(
          ' The cylinder pressures also show a change to cylinder 3 (Oxygen) '
          'at D30.0, deeper than its MOD of L6.0, so no switch to it is '
          'suggested.',
        ),
      );
    });

    test('a wrongly typed stored value reads as a default, not a crash', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': [
          {...start(number: 2, t: 1800, depth: 21), 't': '30:00', 'depth': 'x'},
        ],
        'deepStarts': const [],
      });
      expect(detail, contains('cylinder 2 (EAN50) at 0:00, D0.0'));
    });

    test('switches and a too-deep start read as two sentences', () {
      final detail = detailFor('missing_gas_switch', {
        'missingSwitches': [start(number: 3, t: 2730, depth: 6, o2: 100)],
        'deepStarts': [start(number: 2, t: 600, depth: 40, mod: 22)],
      });
      expect(detail, startsWith('No gas switch was recorded, but'));
      expect(detail, contains('cylinder 3 (Oxygen) at 45:30, D6.0.'));
      expect(
        detail,
        endsWith(
          ' The cylinder pressures also show a change to cylinder 2 (EAN50) '
          'at D40.0, deeper than its MOD of L22.0, so no switch to it is '
          'suggested.',
        ),
      );
    });
  });

  group('tank_assignment', () {
    test('inactive-drop branch', () {
      expect(
        detailFor('tank_assignment', {'inactiveDropBar': 30.0}),
        contains('P30.0'),
      );
    });

    test('twin-tanks branch', () {
      expect(detailFor('tank_assignment', {}), isNotEmpty);
    });
  });

  group('source_conflict', () {
    test('depth branch, plain', () {
      final d = detailFor('source_conflict', {
        'primaryMaxDepth': 30.0,
        'sourceMaxDepth': 33.0,
      });
      expect(d, contains('D30.0'));
      expect(d, contains('D33.0'));
    });

    test('depth branch appends salinity hint when suspected', () {
      final plain = detailFor('source_conflict', {
        'primaryMaxDepth': 30.0,
        'sourceMaxDepth': 33.0,
      });
      final flagged = detailFor('source_conflict', {
        'primaryMaxDepth': 30.0,
        'sourceMaxDepth': 33.0,
        'salinitySettingSuspected': true,
      });
      expect(flagged.length, greaterThan(plain.length));
    });

    // Both values, like the depth branch, so the diver can see which source
    // is plausible (issue #4209).
    test('duration branch shows both durations', () {
      expect(
        detailFor('source_conflict', {
          'primarySeconds': 1390,
          'sourceSeconds': 4018,
        }),
        'Sources disagree on dive duration: 23 min vs. 67 min',
      );
    });

    test('temperature branch shows both temperatures', () {
      final d = detailFor('source_conflict', {
        'primaryTempC': 24.0,
        'sourceTempC': 27.5,
      });
      expect(d, contains('T24.0'));
      expect(d, contains('T27.5'));
    });
  });

  test('unknown detector yields an empty detail', () {
    expect(detailFor('nope', {}), isEmpty);
  });

  group('shared gear overlap (issue #2853)', () {
    QualityFinding overlap({
      List<String> parts = const [],
      String annaName = 'Anna',
    }) => QualityFinding(
      id: 'f1',
      diveId: 'a1',
      relatedDiveId: 'b1',
      detectorId: 'shared_gear_overlap',
      detectorVersion: 1,
      category: QualityCategory.time,
      severity: QualitySeverity.info,
      status: QualityStatus.open,
      params: {
        'equipmentId': 'light',
        'itemName': 'Primary light',
        'partIds': parts,
        'dives': {
          'a1': {
            'diverId': 'anna',
            'diverName': annaName,
            'entryMs': DateTime.utc(2026, 7, 1, 10, 2).millisecondsSinceEpoch,
            'linkKinds': ['gearList'],
          },
          'b1': {
            'diverId': 'bill',
            'diverName': 'Bill',
            'entryMs': DateTime.utc(2026, 7, 1, 10, 5).millisecondsSinceEpoch,
            'linkKinds': ['gearList'],
          },
        },
      },
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );

    test('names the item, both profiles and both times in UTC', () {
      final m = buildFindingMessage(l10n, overlap(), fmt);
      expect(m.title, 'Shared gear on overlapping dives');
      expect(
        m.detail,
        "Primary light is on Anna's dive at TIME(10:2) and Bill's dive at "
        'TIME(10:5).',
      );
    });

    test('adds the installed parts', () {
      final m = buildFindingMessage(
        l10n,
        overlap(parts: ['hose', 'octo']),
        fmt,
      );
      expect(m.detail, endsWith('Includes 2 installed parts.'));
    });

    test('a profile with no name reads another profile', () {
      final m = buildFindingMessage(l10n, overlap(annaName: ''), fmt);
      expect(
        m.detail,
        startsWith("Primary light is on another profile's dive"),
      );
    });
  });
}
