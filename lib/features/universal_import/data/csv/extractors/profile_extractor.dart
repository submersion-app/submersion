/// Extracts sample-by-sample dive profile data from transformed CSV rows.
///
/// Profile rows are rows that contain a 'sampleTime' field indicating they
/// represent a point-in-time measurement during a dive. Rows without
/// 'sampleTime' are treated as dive header rows and skipped.
///
/// The returned map groups samples by a composite dive key:
/// "diveNumber|date|time"
class ProfileExtractor {
  const ProfileExtractor();

  /// Group profile samples from [rows] by dive key.
  ///
  /// The dive key is constructed as "diveNumber|date|time".
  /// Each sample map contains: timestamp, depth, temperature, pressure,
  /// heartRate.
  Map<String, List<Map<String, dynamic>>> extractProfiles(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final rawTime = row['sampleTime'];
      if (rawTime == null) continue;

      final timeSeconds = _parseSampleTime(rawTime.toString());
      if (timeSeconds == null) continue;

      final key = _diveKey(row);
      result.putIfAbsent(key, () => []);
      result[key]!.add({
        'timestamp': timeSeconds,
        'depth': row['sampleDepth'],
        'temperature': row['sampleTemperature'],
        'pressure': row['samplePressure'],
        'heartRate': row['sampleHeartRate'],
      });
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _diveKey(Map<String, dynamic> row) {
    final number = row['diveNumber']?.toString() ?? '';
    final dateTime = row['dateTime'];
    String date = '';
    String time = '';
    if (dateTime is DateTime) {
      date =
          '${dateTime.year}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')}';
      time =
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}:'
          '${dateTime.second.toString().padLeft(2, '0')}';
    } else {
      date = row['date']?.toString() ?? '';
      final rawTime = row['time']?.toString() ?? '';
      // Normalize to HH:MM:SS so string times match DateTime-derived keys.
      time = rawTime.split(':').length == 2 ? '$rawTime:00' : rawTime;
    }
    return '$number|$date|$time';
  }

  /// Parse a M:SS formatted time string to total seconds.
  ///
  /// "1:30" -> 90, "0:00" -> 0, "25:45" -> 1545.
  /// Returns null for unparseable input.
  int? _parseSampleTime(String raw) {
    final trimmed = raw.trim();
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;

    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;

    return minutes * 60 + seconds;
  }
}
