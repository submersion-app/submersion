import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/gpx/gpx_track_builder.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

const String _kGpxMimeType = 'application/gpx+xml';

/// GPX export for recorded GPS surface tracks.
class GpxExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  String fileNameFor(GpsTrack track) {
    // Track times are wall-clock-as-UTC: format the UTC components.
    final date = DateTime.fromMillisecondsSinceEpoch(
      track.startTime,
      isUtc: true,
    );
    return 'submersion_track_${_dateFormat.format(date)}.gpx';
  }

  /// Writes the track and opens the system share sheet. Cannot be cancelled.
  Future<String> shareTrack(GpsTrack track) {
    return saveAndShareFile(
      buildGpxDocument(track, creator: 'Submersion'),
      fileNameFor(track),
      _kGpxMimeType,
    );
  }

  /// Prompts for a location and writes the track there.
  /// Returns null if the user cancelled.
  Future<String?> saveTrackToFile(GpsTrack track) {
    return saveTextToFile(
      buildGpxDocument(track, creator: 'Submersion'),
      fileNameFor(track),
      dialogTitle: 'Save GPX',
      mimeType: 'application/gpx+xml',
    );
  }
}
