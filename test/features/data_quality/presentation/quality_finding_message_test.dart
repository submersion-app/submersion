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
    pressure: (bar) => 'P${bar.toStringAsFixed(1)}',
    temperature: (c) => 'T${c.toStringAsFixed(1)}',
    sac: (lpm) => 'S${lpm.toStringAsFixed(1)}',
    // Renders the UTC calendar date so assertions can prove the clock message
    // routes through the diver's date formatter rather than an ISO timestamp.
    date: (d) => 'DATE(${d.year}-${d.month}-${d.day})',
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
        'source_conflict',
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
    test('offsetHours branch', () {
      expect(detailFor('clock_offset', {'offsetHours': 3}), isNotEmpty);
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
      isNotEmpty,
    );
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

  test('impossible_rate formats rate/min', () {
    final d = detailFor('impossible_rate', {
      'maxRateMetersPerMinute': 30.0,
      'durationSeconds': 10,
    });
    expect(d, contains('D30.0/min'));
  });

  group('temp_anomaly', () {
    test('delta jump branch', () {
      expect(detailFor('temp_anomaly', {'deltaC': 8.0}), contains('T8.0'));
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
        'depthAtPeak': 40.0,
      });
      expect(d, contains('1.61'));
      expect(d, contains('D40.0'));
    });

    test('switch/MOD branch', () {
      final d = detailFor('gas_mod', {'switchDepth': 25.0, 'modMeters': 22.0});
      expect(d, contains('D25.0'));
      expect(d, contains('D22.0'));
    });

    test('hypoxic-at-surface branch', () {
      expect(detailFor('gas_mod', {'o2Percent': 12.0}), isNotEmpty);
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

    test('duration branch', () {
      expect(
        detailFor('source_conflict', {'primarySeconds': 3000}),
        isNotEmpty,
      );
    });

    test('temperature branch', () {
      expect(detailFor('source_conflict', {}), isNotEmpty);
    });
  });

  test('unknown detector yields an empty detail', () {
    expect(detailFor('nope', {}), isEmpty);
  });
}
