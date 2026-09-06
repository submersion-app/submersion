import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
import 'package:submersion/features/bathymetry/data/sources/noaa_dem_source.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';

void main() {
  test('every shipped source id has a human display name', () {
    // The switch falls through to the raw id, so a missing case is not a
    // crash: it is a provenance caption reading "noaa_dem" at the diver.
    const shipped = [
      GmrtSource.sourceId,
      EmodnetSource.sourceId,
      EtopoErddapSource.sourceId,
      NoaaDemSource.sourceId,
    ];
    for (final id in shipped) {
      expect(bathymetrySourceDisplayName(id), isNot(id), reason: id);
    }
  });

  test('an unknown id falls back to itself rather than throwing', () {
    expect(bathymetrySourceDisplayName('future_source'), 'future_source');
  });
}
