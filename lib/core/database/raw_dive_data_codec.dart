import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';

/// The at-rest encoding for `dive_data_sources.raw_data` (issue #227).
///
/// The raw bytes libdivecomputer handed back at download time are the only
/// thing that makes a later re-parse possible, so they are kept forever and
/// there is no second copy to fall back on. Every rule here exists to make
/// losing one impossible.
///
/// A stored blob is either the compressed form:
///
/// ```text
/// offset  size  meaning
/// 0       4     magic, ASCII "SRD1"
/// 4       4     uint32 little-endian, length of the original bytes
/// 8       n     zlib stream (level 6) of the original bytes
/// ```
///
/// or the original bytes verbatim. Nothing else records which, so the header
/// is the only discriminator and a blob carries its own answer. That is what
/// lets a partially migrated table, a row inbound from a peer that has not
/// updated, and a blob that simply does not compress all sit in one column
/// with no state to consult, and it is what lets `DiveMergeService` keep
/// copying provenance rows wholesale without knowing this format exists.
///
/// The digit in the magic is the extension point: a future codec mints
/// "SRD2" and this decoder keeps reading "SRD1" for as long as any diver's
/// database still holds one, which is forever.
const List<int> kRawDiveDataMagic = [0x53, 0x52, 0x44, 0x31];

/// Magic (4 bytes) plus the uint32 original length (4 bytes).
const int kRawDiveDataHeaderBytes = 8;

/// The largest blob this codec will compress, and the largest it will inflate.
///
/// One constant for both directions on purpose. A decode bound without a
/// matching encode refusal would let the encoder mint a blob its own decoder
/// rejects, which would read back as compressed garbage: the exact data loss
/// this file exists to prevent. 8 MiB is far above any dive a computer
/// records and far below anything that threatens memory.
const int kMaxRawDiveBlobBytes = 8 * 1024 * 1024;

/// Level 6. Level 9 was measured on all three committed fixtures and gained
/// under 1.2%, which does not pay for its time. Not `const`: `ZLibCodec` has
/// no const constructor.
final ZLibCodec _zlib = ZLibCodec(level: 6);

/// True when [stored] carries the compressed header.
///
/// A cheap prefix test for callers that want to skip work, such as the v190
/// migration deciding whether a row is already packed. It is NOT proof the
/// body is intact; only [decodeRawDiveData] establishes that.
bool isCompressedRawDiveData(Uint8List stored) {
  if (stored.length < kRawDiveDataHeaderBytes) return false;
  for (var i = 0; i < kRawDiveDataMagic.length; i++) {
    if (stored[i] != kRawDiveDataMagic[i]) return false;
  }
  return true;
}

/// Returns the at-rest form of [raw].
///
/// Compressed only when that is strictly smaller AND within
/// [kMaxRawDiveBlobBytes]; otherwise [raw] itself, unchanged and uncopied.
/// Never mutates [raw].
Uint8List encodeRawDiveData(Uint8List raw) {
  if (raw.length > kMaxRawDiveBlobBytes) return raw;

  final body = _zlib.encode(raw);
  final total = kRawDiveDataHeaderBytes + body.length;
  if (total >= raw.length) return raw;

  final out = Uint8List(total);
  out.setRange(0, kRawDiveDataMagic.length, kRawDiveDataMagic);
  ByteData.sublistView(out).setUint32(4, raw.length, Endian.little);
  out.setRange(kRawDiveDataHeaderBytes, total, body);
  return out;
}

/// Returns the original bytes behind [stored].
///
/// Falls back to [stored] itself on anything that is not a well-formed
/// compressed blob, and never throws. A converter that threw would break
/// ordinary row mapping for the whole table, taking down pages that never
/// wanted the raw bytes; a damaged blob instead degrades into a re-parse
/// failure, which `ReparseService` already counts and surfaces.
///
/// The declared length is load-bearing twice. It bounds the inflate, and it
/// is checked afterwards: zlib accepts a truncated stream and returns what it
/// managed to inflate with no error at all, so length equality is the only
/// completeness check available.
Uint8List decodeRawDiveData(Uint8List stored) {
  if (!isCompressedRawDiveData(stored)) return stored;

  final declared = ByteData.sublistView(
    stored,
    4,
    kRawDiveDataHeaderBytes,
  ).getUint32(0, Endian.little);
  // The declared length reaches 4 GiB and is not trustworthy on its own, so
  // it bounds the inflate only while it is the smaller of the two.
  final cap = declared < kMaxRawDiveBlobBytes ? declared : kMaxRawDiveBlobBytes;

  try {
    final inflated = inflateBounded(
      Uint8List.sublistView(stored, kRawDiveDataHeaderBytes),
      decoder: _zlib.decoder,
      maxBytes: cap,
      maxBlobBytes: kMaxRawDiveBlobBytes,
    );
    if (inflated.length != declared) return stored;
    return inflated;
  } on BoundedInflateException {
    return stored;
  }
}

/// Applies [encodeRawDiveData] and [decodeRawDiveData] to every read and
/// write of the column.
///
/// A converter rather than encoding at the call sites, because the two
/// mistakes are not symmetrical: a write site that forgets to encode stores a
/// raw blob that still reads back correctly, so the bug is invisible, while a
/// read site that forgets to decode hands compressed bytes to
/// libdivecomputer. It is also what keeps sync transparent. Every sync path
/// for this table goes through the row's `toJson`/`fromJson`, which operate
/// on the converted Dart value, so peers keep exchanging uncompressed bytes
/// and no schema floor has to be raised.
class RawDiveDataConverter extends TypeConverter<Uint8List, Uint8List> {
  const RawDiveDataConverter();

  @override
  Uint8List fromSql(Uint8List fromDb) => decodeRawDiveData(fromDb);

  @override
  Uint8List toSql(Uint8List value) => encodeRawDiveData(value);
}
