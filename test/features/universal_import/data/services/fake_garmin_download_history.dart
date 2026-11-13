import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_download_history.dart';

/// One watch's marker in memory, recording what was asked of it.
class FakeGarminDownloadHistory implements GarminDownloadHistory {
  FakeGarminDownloadHistory([this.marker]);

  GarminActivityMarker? marker;

  final lookups = <({String? computerId, String? serialNumber})>[];
  final saves = <({GarminActivityMarker marker, String? computerId})>[];

  @override
  Future<GarminActivityMarker?> markerFor({
    String? computerId,
    String? serialNumber,
  }) async {
    lookups.add((computerId: computerId, serialNumber: serialNumber));
    return marker;
  }

  @override
  Future<bool> save(
    GarminActivityMarker marker, {
    String? computerId,
    String? watchSerial,
    Iterable<String> fitSerials = const [],
  }) async {
    saves.add((marker: marker, computerId: computerId));
    this.marker = marker.laterOf(this.marker);
    return true;
  }
}
