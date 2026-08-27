import 'package:submersion/core/util/wall_clock_utc.dart';

DateTime? parseExifDateTimeOriginal(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(' ');
  if (parts.length != 2) return null;
  final dateParts = parts[0].split(':');
  if (dateParts.length != 3) return null;
  final iso = '${dateParts[0]}-${dateParts[1]}-${dateParts[2]}T${parts[1]}';
  return parseExternalDateAsWallClockUtc(iso);
}
