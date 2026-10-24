import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// When and where a clip was recorded, as its MP4 or QuickTime file says.
class Mp4RecordingInfo {
  const Mp4RecordingInfo({this.created, this.location, this.videoMatrix});

  final DateTime? created;

  /// ISO 6709, e.g. `+20.5000-087.0000/`.
  final String? location;

  /// The video track's display matrix (see [readMp4VideoMatrix]).
  final List<int>? videoMatrix;
}

/// Reads [file]'s recording date and location (issue #3521): QuickTime
/// metadata keys first (`com.apple.quicktime.creationdate` and
/// `.location.ISO6709`, as iPhones write them), else the movie header's
/// creation time and the `©xyz` location (as Android cameras write them) or
/// the 3GPP `loci` one (as ffmpeg and AVFoundation write MP4).
/// Only box headers and the `moov` box are read. Never throws: an
/// unreadable or unexpected file gives nothing.
Future<Mp4RecordingInfo> readMp4RecordingInfo(File file) async {
  RandomAccessFile? raf;
  try {
    raf = await file.open();
    final moov = await _findTopLevel(raf, 'moov');
    if (moov == null) return const Mp4RecordingInfo();
    await raf.setPosition(moov.payloadStart);
    final bytes = await raf.read(moov.payloadLength);
    final keys = <String, String>{};
    DateTime? headerDate;
    String? xyz;
    String? loci;
    for (final child in _children(bytes, 0, bytes.length)) {
      switch (child.type) {
        case 'mvhd':
          headerDate = _mvhdDate(bytes, child);
        case 'meta':
          keys.addAll(_metaKeys(bytes, child));
        case 'udta':
          for (final u in _children(bytes, child.payloadStart, child.end)) {
            if (u.type == '©xyz') xyz = _xyzText(bytes, u);
            if (u.type == 'loci') loci = _lociText(bytes, u);
            if (u.type == 'meta') keys.addAll(_metaKeys(bytes, u));
          }
      }
    }
    final keyDate = DateTime.tryParse(
      keys['com.apple.quicktime.creationdate'] ?? '',
    );
    final matrixAt = _videoMatrixOffset(bytes);
    final data = ByteData.sublistView(bytes);
    return Mp4RecordingInfo(
      created: keyDate?.toUtc() ?? headerDate,
      location: keys['com.apple.quicktime.location.ISO6709'] ?? xyz ?? loci,
      videoMatrix: matrixAt == null
          ? null
          : [for (var i = 0; i < 9; i++) data.getInt32(matrixAt + i * 4)],
    );
  } on Object {
    return const Mp4RecordingInfo();
  } finally {
    await raf?.close();
  }
}

/// Writes [created] as [file]'s creation and modification time in the movie
/// header and every track and media header, in place (issue #3521):
/// encoders stamp a copy with the moment it was made, and the movie header
/// date is what photo libraries sort by. A file with no `moov` is left as
/// it is.
Future<void> stampMp4CreationTime(File file, DateTime created) async {
  final raf = await file.open(mode: FileMode.append);
  try {
    final moov = await _findTopLevel(raf, 'moov');
    if (moov == null) return;
    await raf.setPosition(moov.payloadStart);
    final bytes = await raf.read(moov.payloadLength);
    final seconds = created.toUtc().difference(_epoch).inSeconds;
    for (final header in _dateHeaders(bytes, 0, bytes.length)) {
      final version = bytes[header.payloadStart];
      final field = ByteData(version == 1 ? 16 : 8);
      if (version == 1) {
        field
          ..setUint64(0, seconds)
          ..setUint64(8, seconds);
      } else {
        field
          ..setUint32(0, seconds)
          ..setUint32(4, seconds);
      }
      await raf.setPosition(moov.payloadStart + header.payloadStart + 4);
      await raf.writeFrom(field.buffer.asUint8List());
    }
  } finally {
    await raf.close();
  }
}

/// Adds [iso6709] (e.g. `+20.5000-087.0000/`) to [file] as a 3GPP `loci`
/// box in `moov/udta` (issue #3521), for an encoder that writes no location.
/// Done only when `moov` is the file's last box, so growing it moves no
/// sample data and no chunk offset. Returns whether it was added.
Future<bool> addMp4Location(File file, String iso6709) async {
  final place = _parseIso6709(iso6709);
  if (place == null) return false;
  final raf = await file.open(mode: FileMode.append);
  try {
    final moov = await _findTopLevel(raf, 'moov');
    final length = await raf.length();
    // A 64-bit moov header is left alone: it never needs the space here.
    if (moov == null ||
        moov.end != length ||
        moov.payloadStart - moov.start != 8) {
      return false;
    }
    await raf.setPosition(moov.payloadStart);
    final payload = await raf.read(moov.payloadLength);
    final loci = _lociBox(place.$1, place.$2, place.$3);
    final children = BytesBuilder();
    var placed = false;
    for (final child in _children(payload, 0, payload.length)) {
      if (child.type == 'udta' && !placed) {
        final udta = BytesBuilder()
          ..add(payload.sublist(child.payloadStart, child.end))
          ..add(loci);
        children.add(_box('udta', udta.toBytes()));
        placed = true;
      } else {
        children.add(payload.sublist(child.start, child.end));
      }
    }
    if (!placed) children.add(_box('udta', loci));
    final newMoov = _box('moov', children.toBytes());
    await raf.setPosition(moov.start);
    await raf.writeFrom(newMoov);
    return true;
  } on Object {
    return false;
  } finally {
    await raf.close();
  }
}

(double, double, double)? _parseIso6709(String text) {
  final match = RegExp(
    r'^([+-]\d{1,2}(?:\.\d+)?)([+-]\d{1,3}(?:\.\d+)?)([+-]\d+(?:\.\d+)?)?',
  ).firstMatch(text);
  if (match == null) return null;
  final lat = double.tryParse(match.group(1)!);
  final lon = double.tryParse(match.group(2)!);
  final alt = double.tryParse(match.group(3) ?? '+0') ?? 0;
  if (lat == null || lon == null) return null;
  return (lat, lon, alt);
}

Uint8List _box(String type, List<int> payload) {
  final header = ByteData(8)..setUint32(0, 8 + payload.length);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List(0, 4))
        ..add(latin1.encode(type))
        ..add(payload))
      .toBytes();
}

Uint8List _lociBox(double lat, double lon, double alt) {
  final fixed = ByteData(12)
    ..setInt32(0, (lon * 65536).round())
    ..setInt32(4, (lat * 65536).round())
    ..setInt32(8, (alt * 65536).round());
  return _box('loci', [
    0, 0, 0, 0, // version, flags
    0x15, 0xc7, // language: und
    0, // empty name
    0, // role: shooting location
    ...fixed.buffer.asUint8List(),
    0, // astronomical body
    0, // notes
  ]);
}

/// The display matrix of [file]'s video track (its `tkhd`, nine 32-bit
/// fixed-point values), which carries the clip's rotation. Null when there
/// is no video track or the file cannot be read.
Future<List<int>?> readMp4VideoMatrix(File file) async {
  RandomAccessFile? raf;
  try {
    raf = await file.open();
    final moov = await _findTopLevel(raf, 'moov');
    if (moov == null) return null;
    await raf.setPosition(moov.payloadStart);
    final bytes = await raf.read(moov.payloadLength);
    final at = _videoMatrixOffset(bytes);
    if (at == null) return null;
    final data = ByteData.sublistView(bytes);
    return [for (var i = 0; i < 9; i++) data.getInt32(at + i * 4)];
  } on Object {
    return null;
  } finally {
    await raf?.close();
  }
}

/// Writes [matrix] (nine values) into [file]'s video track header, in place
/// (issue #3521), for an encoder that turned a rotated clip's frames
/// instead of keeping its rotation. Returns whether it was written.
Future<bool> setMp4VideoMatrix(File file, List<int> matrix) async {
  if (matrix.length != 9) return false;
  final raf = await file.open(mode: FileMode.append);
  try {
    final moov = await _findTopLevel(raf, 'moov');
    if (moov == null) return false;
    await raf.setPosition(moov.payloadStart);
    final bytes = await raf.read(moov.payloadLength);
    final at = _videoMatrixOffset(bytes);
    if (at == null) return false;
    final field = ByteData(36);
    for (var i = 0; i < 9; i++) {
      field.setInt32(i * 4, matrix[i]);
    }
    await raf.setPosition(moov.payloadStart + at);
    await raf.writeFrom(field.buffer.asUint8List());
    return true;
  } on Object {
    return false;
  } finally {
    await raf.close();
  }
}

/// Where, in a moov payload, the video track's tkhd matrix starts.
int? _videoMatrixOffset(Uint8List moov) {
  for (final trak in _children(moov, 0, moov.length)) {
    if (trak.type != 'trak') continue;
    _Box? tkhd;
    var video = false;
    for (final child in _children(moov, trak.payloadStart, trak.end)) {
      if (child.type == 'tkhd') tkhd = child;
      if (child.type != 'mdia') continue;
      for (final m in _children(moov, child.payloadStart, child.end)) {
        if (m.type == 'hdlr' && m.payloadLength >= 12) {
          video =
              latin1.decode(
                moov.sublist(m.payloadStart + 8, m.payloadStart + 12),
              ) ==
              'vide';
        }
      }
    }
    if (!video || tkhd == null) continue;
    // version 1 has 64-bit times and duration: 12 more bytes before it.
    final at = tkhd.payloadStart + (moov[tkhd.payloadStart] == 1 ? 52 : 40);
    return at + 36 <= tkhd.end ? at : null;
  }
  return null;
}

final _epoch = DateTime.utc(1904);

class _Box {
  const _Box(this.type, this.start, this.payloadStart, this.end);
  final String type;
  final int start;
  final int payloadStart;
  final int end;
  int get payloadLength => end - payloadStart;
}

Future<_Box?> _findTopLevel(RandomAccessFile raf, String type) async {
  final length = await raf.length();
  var pos = 0;
  while (pos + 8 <= length) {
    await raf.setPosition(pos);
    final head = await raf.read(16);
    if (head.length < 8) return null;
    final data = ByteData.sublistView(head);
    var size = data.getUint32(0);
    var header = 8;
    if (size == 1) {
      if (head.length < 16) return null;
      size = data.getUint64(8);
      header = 16;
    } else if (size == 0) {
      size = length - pos;
    }
    if (size < header) return null;
    final name = latin1.decode(head.sublist(4, 8));
    if (name == type) return _Box(name, pos, pos + header, pos + size);
    pos += size;
  }
  return null;
}

Iterable<_Box> _children(Uint8List bytes, int start, int end) sync* {
  final data = ByteData.sublistView(bytes);
  var pos = start;
  while (pos + 8 <= end) {
    var size = data.getUint32(pos);
    var header = 8;
    if (size == 1 && pos + 16 <= end) {
      size = data.getUint64(pos + 8);
      header = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < header || pos + size > end) return;
    yield _Box(
      latin1.decode(bytes.sublist(pos + 4, pos + 8)),
      pos,
      pos + header,
      pos + size,
    );
    pos += size;
  }
}

DateTime? _mvhdDate(Uint8List bytes, _Box box) {
  final data = ByteData.sublistView(bytes);
  final version = bytes[box.payloadStart];
  final seconds = version == 1
      ? data.getUint64(box.payloadStart + 4)
      : data.getUint32(box.payloadStart + 4);
  if (seconds == 0) return null;
  return _epoch.add(Duration(seconds: seconds));
}

String? _xyzText(Uint8List bytes, _Box box) {
  if (box.payloadLength < 4) return null;
  final length = ByteData.sublistView(bytes).getUint16(box.payloadStart);
  final start = box.payloadStart + 4;
  if (start + length > box.end) return null;
  return utf8.decode(
    bytes.sublist(start, start + length),
    allowMalformed: true,
  );
}

/// The string values of a QuickTime `meta` box's `keys`/`ilst` pairs. The
/// box is a full box (version and flags first) in ISO files and a plain box
/// in QuickTime ones; a plain one starts with a child's non-zero size.
Map<String, String> _metaKeys(Uint8List bytes, _Box meta) {
  final data = ByteData.sublistView(bytes);
  var start = meta.payloadStart;
  if (start + 4 <= meta.end && data.getUint32(start) == 0) start += 4;
  final names = <int, String>{};
  final values = <int, String>{};
  for (final child in _children(bytes, start, meta.end)) {
    if (child.type == 'keys') {
      var pos = child.payloadStart + 8;
      var index = 1;
      while (pos + 8 <= child.end) {
        final size = data.getUint32(pos);
        if (size < 8 || pos + size > child.end) break;
        names[index++] = utf8.decode(
          bytes.sublist(pos + 8, pos + size),
          allowMalformed: true,
        );
        pos += size;
      }
    } else if (child.type == 'ilst') {
      var pos = child.payloadStart;
      while (pos + 8 <= child.end) {
        final size = data.getUint32(pos);
        if (size < 8 || pos + size > child.end) break;
        final index = data.getUint32(pos + 4);
        for (final d in _children(bytes, pos + 8, pos + size)) {
          if (d.type == 'data' && d.payloadLength >= 8) {
            values[index] = utf8.decode(
              bytes.sublist(d.payloadStart + 8, d.end),
              allowMalformed: true,
            );
          }
        }
        pos += size;
      }
    }
  }
  return {for (final e in values.entries) ?names[e.key]: e.value};
}

/// The headers holding a creation time: mvhd, and each track's tkhd and
/// mdhd.
Iterable<_Box> _dateHeaders(Uint8List bytes, int start, int end) sync* {
  for (final box in _children(bytes, start, end)) {
    if (box.type == 'mvhd' || box.type == 'tkhd' || box.type == 'mdhd') {
      yield box;
    } else if (box.type == 'trak' || box.type == 'mdia') {
      yield* _dateHeaders(bytes, box.payloadStart, box.end);
    }
  }
}

/// A 3GPP `loci` box as ISO 6709: version and flags, language, a
/// NUL-terminated name (UTF-8, or UTF-16 after a FE FF byte order mark), a
/// role byte, then longitude, latitude and altitude as 16.16 fixed point.
String? _lociText(Uint8List bytes, _Box box) {
  var pos = box.payloadStart + 6;
  final utf16 =
      pos + 1 < box.end && bytes[pos] == 0xfe && bytes[pos + 1] == 0xff;
  if (utf16) {
    pos += 2;
    while (pos + 1 < box.end && (bytes[pos] != 0 || bytes[pos + 1] != 0)) {
      pos += 2;
    }
    pos += 3; // the name's two-byte NUL, the role
  } else {
    while (pos < box.end && bytes[pos] != 0) {
      pos++;
    }
    pos += 2; // the name's NUL, the role
  }
  if (pos + 12 > box.end) return null;
  final data = ByteData.sublistView(bytes);
  double fixed(int at) => data.getInt32(at) / 65536;
  final lon = fixed(pos), lat = fixed(pos + 4), alt = fixed(pos + 8);
  String signed(double v, int intDigits, int decimals) {
    final text = v.abs().toStringAsFixed(decimals);
    final width = intDigits + 1 + decimals;
    return '${v < 0 ? '-' : '+'}${text.padLeft(width, '0')}';
  }

  return '${signed(lat, 2, 4)}${signed(lon, 3, 4)}${signed(alt, 3, 3)}/';
}
