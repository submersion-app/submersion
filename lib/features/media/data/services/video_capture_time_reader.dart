import 'dart:io';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';
import 'package:submersion/features/media/data/services/quicktime_metadata.dart';

/// Reads when an MP4/MOV/M4V video was recorded, as wall-clock UTC (the
/// digits of the clock where it was filmed, the frame dive times use), or
/// null when the file carries no usable date and the caller has to fall back
/// to the file's modified time.
///
/// Videos can hold several dates. They are tried in this order, and the
/// first usable one wins:
///
/// 1. `com.apple.quicktime.creationdate` in the `moov > meta` keys table.
///    iPhones and recent Apple software write it as the local time plus its
///    UTC offset, so the local digits are known exactly.
/// 2. `©day` in `moov > udta`, either as a classic QuickTime text atom or as
///    an iTunes-style `meta > ilst` tag. Same format, when a camera writes it.
/// 3. `creation_time` in the `moov > mvhd` movie header, which every MP4 has.
///    The format defines it as UTC, but GoPro and other cameras write their
///    local clock there instead; [resolveMvhdCreationTime] decides which.
///
/// A creationdate or `©day` value in UTC (`Z`) says nothing about the local
/// clock, so it is skipped in favour of the next field.
///
/// [toLocal] converts a UTC `mvhd` value to local time; it defaults to this
/// computer's timezone. Tests pass a fixed zone so the conversion shows even
/// on a UTC host.
DateTime? readVideoCaptureTime(
  File file, {
  DateTime Function(DateTime utc) toLocal = _systemLocal,
}) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final moov = findBox(raf, 0, raf.lengthSync(), 'moov');
    if (moov == null) return null;

    final r = raf;
    final tagged =
        _parsed(() => readQuickTimeKeyText(r, moov, _creationDateKey)) ??
        _parsed(() => readUdtaText(r, moov, _dayType)) ??
        _parsed(() => readUdtaIlstText(r, moov, _dayType));
    if (tagged != null) return tagged;

    final header = _readMvhd(raf, moov);
    if (header == null) return null;
    return resolveMvhdCreationTime(
      raw: header.creation,
      duration: header.duration,
      modified: file.lastModifiedSync(),
      toLocal: toLocal,
    );
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

const _creationDateKey = 'com.apple.quicktime.creationdate';

/// The copyright sign is byte 0xA9 in the box header.
const _dayType = '©day';

/// Parses one tag, treating a corrupt tag as absent so it cannot hide the
/// fields after it.
DateTime? _parsed(String? Function() read) {
  try {
    final text = read();
    return text == null ? null : parseQuickTimeDateText(text);
  } on Object {
    return null;
  }
}

final _dateText = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?'
  r'(Z|([+-])(\d{2}):?(\d{2}))?$',
);

/// Parses an ISO 8601 date-time from a QuickTime text tag and returns its
/// local digits as wall-clock UTC. An offset (`-0500`, `+05:30`) is dropped,
/// not applied: the digits before it are already the local clock. A value
/// without a zone is read as wall clock too. Returns null for a UTC (`Z`)
/// value, which has no local clock, and for anything that is not a complete,
/// valid date and time (a bare year, a 13th month, a `+99:99` offset), so a
/// corrupt tag falls through to the next field.
DateTime? parseQuickTimeDateText(String text) {
  final m = _dateText.firstMatch(text.trim());
  if (m == null || m.group(8) == 'Z') return null;
  if (m.group(8) != null &&
      !_isRealOffset(m.group(9)!, m.group(10)!, m.group(11)!)) {
    return null;
  }
  final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  final fraction = m.group(7);
  final millis = fraction == null
      ? 0
      : int.parse(fraction.padRight(3, '0').substring(0, 3));
  final value = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
    millis,
  );
  // DateTime rolls an out-of-range field into the next one; a round trip
  // that changes any field means the text was not a real date.
  final valid =
      value.year == parts[0] &&
      value.month == parts[1] &&
      value.day == parts[2] &&
      value.hour == parts[3] &&
      value.minute == parts[4] &&
      value.second == parts[5];
  return valid ? value : null;
}

/// Whether an offset is one a clock can be set to: real zones run from
/// -12:00 to +14:00, in whole minutes below 60.
bool _isRealOffset(String sign, String hours, String minutes) {
  final total = int.parse(hours) * 60 + int.parse(minutes);
  if (int.parse(minutes) >= 60) return false;
  return sign == '+' ? total <= 14 * 60 : total <= 12 * 60;
}

/// How far a file's modified time may sit from the start or end of the
/// recording and still count as the camera's own stamp. Cameras close the
/// file within seconds of stopping; FAT stores mtime to 2 s.
const _mtimeTolerance = Duration(seconds: 60);

/// Decides whether an `mvhd` creation time holds UTC (as the format says) or
/// a camera's local clock (as GoPro writes it), using the file's modified
/// time as the witness.
///
/// [raw] is the header value with its digits in a UTC [DateTime]. A camera
/// stamps the file when it closes it, and copies normally keep that stamp, so
/// [modified] is an instant at the end (or, for some firmware, the start) of
/// the recording. When [raw] read as a UTC instant lands there, the header
/// is UTC, and it is converted to wall clock through [toLocal], which by
/// default uses this computer's timezone, as Windows does for its "Media
/// created" column. Otherwise the header keeps today's reading as local
/// digits: a GoPro value, or one whose mtime is a later copy time that
/// proves nothing.
///
/// The comparison is made between instants, never between local digits: a
/// clip copied on a trip and imported at home in another timezone keeps its
/// instant, so a local-time header is never mistaken for UTC by the
/// difference between the two zones.
DateTime resolveMvhdCreationTime({
  required DateTime raw,
  required Duration duration,
  required DateTime? modified,
  DateTime Function(DateTime utc) toLocal = _systemLocal,
}) {
  if (modified == null) return raw;
  final stamp = modified.millisecondsSinceEpoch;
  bool near(DateTime t) =>
      (stamp - t.millisecondsSinceEpoch).abs() <=
      _mtimeTolerance.inMilliseconds;
  if (near(raw) || near(raw.add(duration))) {
    return asWallClockUtc(toLocal(raw));
  }
  return raw;
}

DateTime _systemLocal(DateTime utc) => utc.toLocal();

// Seconds between the QuickTime/ISO-BMFF epoch (1904-01-01) and the Unix epoch.
// This is a whole number of days, so the epoch shift preserves the time-of-day
// digits exactly (only the date rolls) when reconstructing the DateTime.
const _secondsBetween1904And1970 = 2082844800;

/// The longest clip duration trusted from a header. Anything longer is a
/// corrupt value, and using it would widen the agreement window.
const _maxDuration = Duration(hours: 12);

typedef _MovieHeader = ({DateTime creation, Duration duration});

_MovieHeader? _readMvhd(RandomAccessFile raf, BoxRange moov) {
  final mvhd = findBox(raf, moov.start, moov.end, 'mvhd');
  if (mvhd == null) return null;
  final version = readByteAt(raf, mvhd.start);
  // Only v0/v1 mvhd headers exist. Bail on anything else rather than
  // mis-reading a corrupt byte as v0 and emitting a bogus timestamp.
  if (version != 0 && version != 1) return null;
  // After the 1-byte version and 3 flag bytes: creation_time and
  // modification_time (uint32 in v0, uint64 in v1), timescale (uint32), then
  // duration (uint32 in v0, uint64 in v1).
  final v1 = version == 1;
  final creation = v1
      ? readU64At(raf, mvhd.start + 4)
      : readU32At(raf, mvhd.start + 4);
  if (creation == 0) return null; // 0 == "unknown"; caller uses mtime.
  final timescale = readU32At(raf, mvhd.start + (v1 ? 20 : 12));
  final units = v1
      ? readU64At(raf, mvhd.start + 24)
      : readU32At(raf, mvhd.start + 16);
  // A uint64 with its top bit set reads back negative; either way a value
  // outside 0 to 12 h is corrupt and only an instant comparison remains.
  final seconds = timescale == 0 ? 0.0 : units / timescale;
  final duration = seconds < 0 || seconds > _maxDuration.inSeconds
      ? Duration.zero
      : Duration(milliseconds: (seconds * 1000).round());
  return (
    creation: DateTime.fromMillisecondsSinceEpoch(
      (creation - _secondsBetween1904And1970) * 1000,
      isUtc: true,
    ),
    duration: duration,
  );
}
