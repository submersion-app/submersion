import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// When and where a clip was recorded, as its MP4 or QuickTime file says.
class Mp4RecordingInfo {
  const Mp4RecordingInfo({this.created, this.location});

  final DateTime? created;

  /// ISO 6709, e.g. `+20.5000-087.0000/`.
  final String? location;
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
    return Mp4RecordingInfo(
      created: keyDate?.toUtc() ?? headerDate,
      location: keys['com.apple.quicktime.location.ISO6709'] ?? xyz ?? loci,
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

final _epoch = DateTime.utc(1904);

class _Box {
  const _Box(this.type, this.payloadStart, this.end);
  final String type;
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
    if (name == type) return _Box(name, pos + header, pos + size);
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
/// NUL-terminated name, a role byte, then longitude, latitude and altitude
/// as 16.16 fixed point.
String? _lociText(Uint8List bytes, _Box box) {
  var pos = box.payloadStart + 6;
  while (pos < box.end && bytes[pos] != 0) {
    pos++;
  }
  pos += 2; // the name's NUL, the role
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
