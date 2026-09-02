import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Reads the recording location iPhones and most cameras write into a
/// QuickTime/MP4 container: the classic `moov > udta > ©xyz` atom, then the
/// newer `moov > meta > keys/ilst` entry
/// `com.apple.quicktime.location.ISO6709`. Both hold an ISO 6709 string.
GpsFix? readQuickTimeLocation(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final moov = findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    return _fromUdta(raf, moov) ?? _fromMeta(raf, moov);
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

const _maxTextBytes = 4096;
const _maxMetaBytes = 1024 * 1024;
const _locationKey = 'com.apple.quicktime.location.ISO6709';

/// The `©xyz` type: the copyright sign is byte 0xA9 in the box header, which
/// `String.fromCharCodes` decodes to U+00A9.
const _xyzType = '©xyz';

GpsFix? _fromUdta(RandomAccessFile raf, BoxRange moov) {
  final udta = findBox(raf, moov.start, moov.end, 'udta');
  if (udta == null) return null;
  final xyz = findBox(raf, udta.start, udta.end, _xyzType);
  if (xyz == null || xyz.length < 4) return null;
  final header = readBytesAt(raf, xyz.start, 4);
  final textLen = beU16(header, 0);
  if (textLen <= 0 || textLen > _maxTextBytes || 4 + textLen > xyz.length) {
    return null;
  }
  final text = readBytesAt(raf, xyz.start + 4, textLen);
  return parseIso6709(latin1.decode(text, allowInvalid: true));
}

GpsFix? _fromMeta(RandomAccessFile raf, BoxRange moov) {
  final meta = findBox(raf, moov.start, moov.end, 'meta');
  if (meta == null || meta.length > _maxMetaBytes || meta.length < 8) {
    return null;
  }
  final b = readBytesAt(raf, meta.start, meta.length);
  // Apple writes meta as a plain box (hdlr at offset 0); ISO files make it a
  // FullBox (4 bytes of version/flags first). Detect rather than assume.
  final childStart = fourCC(b, 4) == 'hdlr' ? 0 : 4;
  final keys = findBoxInBytes(b, childStart, b.length, 'keys');
  final ilst = findBoxInBytes(b, childStart, b.length, 'ilst');
  if (keys == null || ilst == null) return null;

  final index = _keyIndex(b, keys, _locationKey);
  if (index == null) return null;

  for (final entry in _walkEntries(b, ilst)) {
    if (entry.index != index) continue;
    final data = findBoxInBytes(b, entry.range.start, entry.range.end, 'data');
    if (data == null || data.length <= 8) continue;
    final text = b.sublist(data.start + 8, data.end);
    return parseIso6709(utf8.decode(text, allowMalformed: true));
  }
  return null;
}

/// 1-based index of [name] in a `keys` FullBox, or null.
int? _keyIndex(Uint8List b, BoxRange keys, String name) {
  var p = keys.start + 4; // version + flags
  if (p + 4 > keys.end) return null;
  final count = beU32(b, p);
  p += 4;
  for (var i = 1; i <= count && p + 8 <= keys.end; i++) {
    final size = beU32(b, p);
    if (size < 8 || p + size > keys.end) return null;
    final key = utf8.decode(b.sublist(p + 8, p + size), allowMalformed: true);
    if (key == name) return i;
    p += size;
  }
  return null;
}

typedef _IlstEntry = ({int index, BoxRange range});

/// `ilst` children are boxes whose type field is the key index.
Iterable<_IlstEntry> _walkEntries(Uint8List b, BoxRange ilst) sync* {
  var pos = ilst.start;
  while (pos + 8 <= ilst.end) {
    final size = beU32(b, pos);
    if (size < 8 || pos + size > ilst.end) return;
    yield (index: beU32(b, pos + 4), range: BoxRange(pos + 8, pos + size));
    pos += size;
  }
}

final _iso6709 = RegExp(r'^([+-]\d{1,2}(?:\.\d+)?)([+-]\d{1,3}(?:\.\d+)?)');

/// Parses the decimal-degree ISO 6709 form (`+DD.DDDD+DDD.DDDD[+ALT]/`)
/// that Apple and camera firmware write. Returns null for anything else.
GpsFix? parseIso6709(String value) {
  final m = _iso6709.firstMatch(value.trim());
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null || !isPlausibleFix(lat, lon)) return null;
  return (latitude: lat, longitude: lon);
}
