import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/dive_import/data/services/restored_source_attribution.dart';

/// A tank a resync placed on no stored cylinder has no id (issue #4665): its
/// pressure series is dropped, never written onto another cylinder.
void main() {
  test('a series whose tank has no id is dropped', () {
    final diveData = <String, dynamic>{
      'tanks': [
        {'uddfTankId': 'tank-1'},
        {'uddfTankId': 'tank-2'},
      ],
      UddfSourceAttribution.seriesKey: [
        for (final ref in ['tank-1', 'tank-2'])
          {
            'tankRef': ref,
            'samples': <({int timestamp, double pressure})>[
              (timestamp: 0, pressure: 200.0),
            ],
          },
      ],
    };

    final series = restoredTankPressureSeries(diveData, ['kept', null]);

    expect([for (final s in series) s.tankId], ['kept']);
  });
}
