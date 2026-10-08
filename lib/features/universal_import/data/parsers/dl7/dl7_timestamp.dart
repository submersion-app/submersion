/// Parses a DL7 timestamp, `YYYYMMDDHHMMSS` with the seconds optional, as
/// wall-clock UTC, ignoring any timezone suffix per the house dive-time
/// convention. Non-digit separators are tolerated.
///
/// Shared by the `ZDH`/`ZDT` segments and the Aqualung `ZAR` block's
/// `DIVE_DT`, which must read alike for a block to be matched to its dive.
DateTime? parseDl7Timestamp(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 12) return null;
  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  final hour = int.tryParse(digits.substring(8, 10));
  final minute = int.tryParse(digits.substring(10, 12));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  final second = digits.length >= 14
      ? int.tryParse(digits.substring(12, 14)) ?? 0
      : 0;
  return DateTime.utc(year, month, day, hour, minute, second);
}
