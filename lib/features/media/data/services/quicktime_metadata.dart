/// Read helpers for the two places QuickTime and MP4 files keep text
/// metadata: classic `moov > udta` atoms and the newer `moov > meta`
/// `keys`/`ilst` table.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

const _maxMetaBytes = 1024 * 1024;
const _maxTextBytes = 4096;

/// The text of a classic QuickTime user-data atom `moov > udta > [type]`,
/// such as `©xyz` or `©day`, or null. Those atoms hold a 16-bit text length
/// and a 16-bit language code before the text.
///
/// Type names beginning with the copyright sign match because the box
/// walker decodes the header byte 0xA9 to U+00A9.
String? readUdtaText(RandomAccessFile raf, BoxRange moov, String type) {
  final udta = findBox(raf, moov.start, moov.end, 'udta');
  if (udta == null) return null;
  final atom = findBox(raf, udta.start, udta.end, type);
  if (atom == null || atom.length < 4) return null;
  final header = readBytesAt(raf, atom.start, 4);
  final textLen = beU16(header, 0);
  if (textLen <= 0 || textLen > _maxTextBytes || 4 + textLen > atom.length) {
    return null;
  }
  final text = readBytesAt(raf, atom.start + 4, textLen);
  return latin1.decode(text, allowInvalid: true);
}

/// The text of an iTunes-style tag `moov > udta > meta > ilst > [type]`, the
/// layout ffmpeg and several cameras use for MP4 files, or null. Here `meta`
/// is a FullBox and each `ilst` child is named by the tag itself.
String? readUdtaIlstText(RandomAccessFile raf, BoxRange moov, String type) {
  final udta = findBox(raf, moov.start, moov.end, 'udta');
  if (udta == null) return null;
  final meta = findBox(raf, udta.start, udta.end, 'meta');
  if (meta == null || meta.length > _maxMetaBytes || meta.length < 8) {
    return null;
  }
  final b = readBytesAt(raf, meta.start, meta.length);
  final childStart = fourCC(b, 4) == 'hdlr' ? 0 : 4;
  final ilst = findBoxInBytes(b, childStart, b.length, 'ilst');
  if (ilst == null) return null;
  final entry = findBoxInBytes(b, ilst.start, ilst.end, type);
  return entry == null ? null : dataBoxText(b, entry);
}

/// The text value of [key] in a QuickTime `moov > meta > keys/ilst` table
/// (for example `com.apple.quicktime.creationdate`), or null when the movie
/// has no such table or no such key.
///
/// `keys` names each entry; `ilst` holds the values, each child box typed by
/// the 1-based index of its key and carrying a `data` box.
String? readQuickTimeKeyText(RandomAccessFile raf, BoxRange moov, String key) {
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

  final index = _keyIndex(b, keys, key);
  if (index == null) return null;

  for (final entry in _walkEntries(b, ilst)) {
    if (entry.index != index) continue;
    final text = dataBoxText(b, entry.range);
    if (text != null) return text;
  }
  return null;
}

/// The text payload of the `data` box inside [entry], or null. A `data` box
/// holds a 4-byte type indicator and a 4-byte locale before the value.
String? dataBoxText(Uint8List b, BoxRange entry) {
  final data = findBoxInBytes(b, entry.start, entry.end, 'data');
  if (data == null || data.length <= 8) return null;
  return utf8.decode(b.sublist(data.start + 8, data.end), allowMalformed: true);
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
