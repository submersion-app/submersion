import 'dart:io';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';
import 'package:submersion/features/media/data/services/quicktime_metadata.dart';

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

const _locationKey = 'com.apple.quicktime.location.ISO6709';

/// The `©xyz` type: the copyright sign is byte 0xA9 in the box header, which
/// `String.fromCharCodes` decodes to U+00A9.
const _xyzType = '©xyz';

GpsFix? _fromUdta(RandomAccessFile raf, BoxRange moov) {
  final text = readUdtaText(raf, moov, _xyzType);
  return text == null ? null : parseIso6709(text);
}

GpsFix? _fromMeta(RandomAccessFile raf, BoxRange moov) {
  final text = readQuickTimeKeyText(raf, moov, _locationKey);
  return text == null ? null : parseIso6709(text);
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
