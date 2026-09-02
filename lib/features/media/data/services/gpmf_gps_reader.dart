import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

/// Reads the first GPS fix from a GoPro clip's GPMF telemetry.
///
/// GoPro writes telemetry as samples of a `gpmd` metadata track (one sample
/// per second). Each sample is a KLV stream; the GPS lives in a `STRM`
/// holding `GPS9` (HERO11 and later, per-sample fix) or `GPS5` (older, with a
/// sibling `GPSF` fix flag). The reader walks the sample tables and reads one
/// sample at a time, so the multi-GB `mdat` is never loaded. Cold-start clips
/// have no fix for the first seconds, so up to [maxSamples] samples are
/// tried before giving up.
GpsFix? readGpmfGps(File file, {int maxSamples = 30}) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final end = raf.lengthSync();
    final moov = findBox(raf, 0, end, 'moov');
    if (moov == null) return null;
    final stbl = _findGpmdSampleTable(raf, moov);
    if (stbl == null) return null;
    for (final s in _sampleLocations(raf, stbl, maxSamples)) {
      if (s.size <= 0 || s.size > _maxSampleBytes || s.offset + s.size > end) {
        return null;
      }
      final fix = gpsFromGpmfSample(readBytesAt(raf, s.offset, s.size));
      if (fix != null) return fix;
    }
    return null;
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

const _maxSampleBytes = 1024 * 1024;
const _maxTableBytes = 4 * 1024 * 1024;

/// The `stbl` of the track whose handler is `meta` and whose sample entry is
/// `gpmd`, or null when the file has no GoPro telemetry track.
BoxRange? _findGpmdSampleTable(RandomAccessFile raf, BoxRange moov) {
  for (final trak in findBoxes(raf, moov.start, moov.end, 'trak')) {
    final mdia = findBox(raf, trak.start, trak.end, 'mdia');
    if (mdia == null) continue;
    final hdlr = findBox(raf, mdia.start, mdia.end, 'hdlr');
    if (hdlr == null || hdlr.length < 12) continue;
    if (fourCC(readBytesAt(raf, hdlr.start + 8, 4), 0) != 'meta') continue;
    final minf = findBox(raf, mdia.start, mdia.end, 'minf');
    if (minf == null) continue;
    final stbl = findBox(raf, minf.start, minf.end, 'stbl');
    if (stbl == null) continue;
    final stsd = findBox(raf, stbl.start, stbl.end, 'stsd');
    if (stsd == null || stsd.length < 16) continue;
    if (fourCC(readBytesAt(raf, stsd.start + 12, 4), 0) == 'gpmd') return stbl;
  }
  return null;
}

typedef _SampleLocation = ({int offset, int size});

/// Absolute (offset, size) of the first [limit] samples, derived from
/// `stsz` (sizes), `stsc` (samples per chunk) and `stco`/`co64` (chunk
/// offsets). Samples within a chunk are contiguous.
Iterable<_SampleLocation> _sampleLocations(
  RandomAccessFile raf,
  BoxRange stbl,
  int limit,
) sync* {
  final stsz = _payload(raf, stbl, 'stsz');
  final stsc = _payload(raf, stbl, 'stsc');
  final stco = _payload(raf, stbl, 'stco');
  final co64 = stco == null ? _payload(raf, stbl, 'co64') : null;
  if (stsz == null || stsc == null) return;
  final offsets = stco ?? co64;
  if (offsets == null) return;
  if (stsz.length < 12 || stsc.length < 8 || offsets.length < 8) return;

  final constantSize = beU32(stsz, 4);
  final sampleCount = beU32(stsz, 8);
  int sizeOf(int i) {
    if (constantSize != 0) return constantSize;
    final p = 12 + i * 4;
    return p + 4 <= stsz.length ? beU32(stsz, p) : -1;
  }

  final chunkCount = beU32(offsets, 4);
  final entryLen = stco != null ? 4 : 8;
  int chunkOffset(int c) =>
      stco != null ? beU32(offsets, 8 + c * 4) : beU64(offsets, 8 + c * 8);

  final stscCount = beU32(stsc, 4);
  int samplesPerChunk(int chunkIndex1) {
    var result = 1;
    for (var e = 0; e < stscCount; e++) {
      final p = 8 + e * 12;
      if (p + 12 > stsc.length) break;
      if (beU32(stsc, p) <= chunkIndex1) result = beU32(stsc, p + 4);
    }
    return result;
  }

  var sample = 0;
  for (
    var c = 0;
    c < chunkCount && sample < sampleCount && sample < limit;
    c++
  ) {
    if (8 + (c + 1) * entryLen > offsets.length) return;
    var offset = chunkOffset(c);
    final perChunk = samplesPerChunk(c + 1);
    for (
      var k = 0;
      k < perChunk && sample < sampleCount && sample < limit;
      k++
    ) {
      final size = sizeOf(sample);
      if (size < 0) return;
      yield (offset: offset, size: size);
      offset += size;
      sample++;
    }
  }
}

/// Payload bytes of the first [type] box inside [parent], bounded.
Uint8List? _payload(RandomAccessFile raf, BoxRange parent, String type) {
  final r = findBox(raf, parent.start, parent.end, type);
  if (r == null || r.length < 8 || r.length > _maxTableBytes) return null;
  return readBytesAt(raf, r.start, r.length);
}

/// Parses one `gpmd` sample. Public for unit tests and the real-sample gate.
GpsFix? gpsFromGpmfSample(Uint8List sample) {
  try {
    return _searchStreams(sample, 0, sample.length);
  } on Object {
    return null;
  }
}

typedef _Item = ({
  String key,
  int type,
  int structSize,
  int repeat,
  int dataStart,
  int dataEnd,
});

/// Yields the items of one KLV stream; stops at the first malformed header.
Iterable<_Item> _items(Uint8List b, int start, int end) sync* {
  var p = start;
  while (p + 8 <= end) {
    final key = fourCC(b, p);
    final type = b[p + 4];
    final structSize = b[p + 5];
    final repeat = beU16(b, p + 6);
    final len = structSize * repeat;
    final padded = (len + 3) & ~3;
    if (p + 8 + padded > end) return;
    yield (
      key: key,
      type: type,
      structSize: structSize,
      repeat: repeat,
      dataStart: p + 8,
      dataEnd: p + 8 + len,
    );
    p += 8 + padded;
  }
}

/// Depth-first search for a `STRM` carrying GPS9 or GPS5.
GpsFix? _searchStreams(Uint8List b, int start, int end) {
  for (final item in _items(b, start, end)) {
    if (item.key == 'STRM') {
      final fix = _gpsFromStream(b, item.dataStart, item.dataEnd);
      if (fix != null) return fix;
    } else if (item.type == 0) {
      final fix = _searchStreams(b, item.dataStart, item.dataEnd);
      if (fix != null) return fix;
    }
  }
  return null;
}

GpsFix? _gpsFromStream(Uint8List b, int start, int end) {
  _Item? gps9, gps5, scal, gpsf, type;
  for (final item in _items(b, start, end)) {
    switch (item.key) {
      case 'GPS9':
        gps9 = item;
      case 'GPS5':
        gps5 = item;
      case 'SCAL':
        scal = item;
      case 'GPSF':
        gpsf = item;
      case 'TYPE':
        type = item;
    }
  }
  if (scal == null) return null;
  final scale = _numbers(b, scal);
  if (scale.length < 2 || scale[0] == 0 || scale[1] == 0) return null;

  if (gps9 != null && type != null) {
    final layout = String.fromCharCodes(b, type.dataStart, type.dataEnd);
    final fieldSizes = layout.split('').map(_sizeOfType).toList();
    if (fieldSizes.contains(0)) return null;
    final structSize = fieldSizes.fold(0, (a, s) => a + s);
    if (structSize != gps9.structSize || layout.length < 9) return null;
    final fixIndex = layout.length - 1;
    for (var i = 0; i < gps9.repeat; i++) {
      final base = gps9.dataStart + i * structSize;
      final lat = _readTyped(b, base, layout[0]) / scale[0];
      final lon = _readTyped(b, base + fieldSizes[0], layout[1]) / scale[1];
      var fixOffset = base;
      for (var f = 0; f < fixIndex; f++) {
        fixOffset += fieldSizes[f];
      }
      final fix = _readTyped(b, fixOffset, layout[fixIndex]);
      if (fix >= 2 && isPlausibleFix(lat, lon)) {
        return (latitude: lat, longitude: lon);
      }
    }
    return null;
  }

  if (gps5 != null) {
    if (gpsf == null) return null;
    final fixFlag = _numbers(b, gpsf);
    if (fixFlag.isEmpty || fixFlag.first < 2) return null;
    if (gps5.structSize < 8 || gps5.repeat < 1) return null;
    for (var i = 0; i < gps5.repeat; i++) {
      final base = gps5.dataStart + i * gps5.structSize;
      final lat = beS32(b, base) / scale[0];
      final lon = beS32(b, base + 4) / scale[1];
      if (isPlausibleFix(lat, lon)) return (latitude: lat, longitude: lon);
    }
  }
  return null;
}

/// Decodes a numeric item (SCAL, GPSF) of any integer type into doubles.
List<double> _numbers(Uint8List b, _Item item) {
  final c = String.fromCharCode(item.type);
  final size = _sizeOfType(c);
  if (size == 0) return const [];
  final out = <double>[];
  for (var p = item.dataStart; p + size <= item.dataEnd; p += size) {
    out.add(_readTyped(b, p, c));
  }
  return out;
}

int _sizeOfType(String c) => switch (c) {
  'b' || 'B' || 'c' => 1,
  's' || 'S' => 2,
  'l' || 'L' || 'f' => 4,
  'j' || 'J' || 'd' => 8,
  _ => 0,
};

double _readTyped(Uint8List b, int p, String c) => switch (c) {
  'b' => b[p].toSigned(8).toDouble(),
  'B' || 'c' => b[p].toDouble(),
  's' => beS16(b, p).toDouble(),
  'S' => beU16(b, p).toDouble(),
  'l' => beS32(b, p).toDouble(),
  'L' => beU32(b, p).toDouble(),
  'f' => ByteData.sublistView(b, p, p + 4).getFloat32(0),
  'd' => ByteData.sublistView(b, p, p + 8).getFloat64(0),
  'j' => ByteData.sublistView(b, p, p + 8).getInt64(0).toDouble(),
  'J' => ByteData.sublistView(b, p, p + 8).getUint64(0).toDouble(),
  _ => double.nan,
};
