import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32, getCrc32Byte;

/// Writes a ZIP whose entries are encrypted with ZipCrypto, the traditional
/// PKWARE scheme (APPNOTE 6.3.x section 6.1).
///
/// ZipCrypto is weak: a known-plaintext attack recovers the keys. It is
/// used because macOS Archive Utility, Windows Explorer and `unzip` open it
/// natively, which AES ZIPs (the only kind `archive`'s encoder writes) do
/// not. Callers must not present it as strong encryption.
///
/// Entries are written one at a time to [RandomAccessFile], so the archive
/// never has to fit in memory. Every entry has its CRC and sizes in the
/// local header (no data descriptor), UTF-8 names, and no ZIP64, which keeps
/// it inside what the OS tools accept.
class ZipCryptoWriter {
  ZipCryptoWriter(this._out, {required String password, Random? random})
    : _password = _checkedPassword(password),
      _random = random ?? Random.secure();

  /// Opens [path] for a new archive, checking [password] first so a refused
  /// one leaves no file behind.
  static Future<ZipCryptoWriter> open(
    String path, {
    required String password,
    Random? random,
  }) async {
    _checkedPassword(password);
    return ZipCryptoWriter(
      await File(path).open(mode: FileMode.write),
      password: password,
      random: random,
    );
  }

  final RandomAccessFile _out;
  final Uint8List _password;
  final Random _random;
  final List<_CentralEntry> _entries = [];
  int _offset = 0;

  /// Minimum password length the export accepts.
  static const minPasswordLength = 8;

  /// Whether [password] is long enough and printable ASCII (0x20 to 0x7E).
  /// ZipCrypto has no defined password encoding: macOS uses UTF-8 and
  /// Windows the system code page, so anything else could open on one and
  /// fail on the other.
  static bool isValidPassword(String password) =>
      password.length >= minPasswordLength && isAsciiPassword(password);

  /// Whether every character of [password] is printable ASCII.
  static bool isAsciiPassword(String password) =>
      password.codeUnits.every((c) => c >= 0x20 && c <= 0x7e);

  static Uint8List _checkedPassword(String password) {
    if (!isValidPassword(password)) {
      throw ArgumentError.value('<hidden>', 'password', 'not a valid password');
    }
    return Uint8List.fromList(password.codeUnits);
  }

  /// Random bytes for one entry's encryption header.
  Uint8List nextHeaderSeed() => Uint8List.fromList(
    List.generate(_seedLength, (_) => _random.nextInt(256)),
  );

  /// The password as the bytes [encodeZipCryptoEntry] takes.
  Uint8List get passwordBytes => _password;

  /// Compresses, encrypts and writes [data] as [name].
  Future<void> addFile(
    String name,
    Uint8List data, {
    required DateTime modified,
  }) => addEncoded(
    name,
    encodeZipCryptoEntry(_password, data, nextHeaderSeed()),
    modified: modified,
  );

  /// Writes an entry already produced by [encodeZipCryptoEntry], for callers
  /// that encode on another isolate.
  Future<void> addEncoded(
    String name,
    EncodedZipEntry entry, {
    required DateTime modified,
  }) async {
    final nameBytes = Uint8List.fromList(utf8.encode(name));
    final (time, date) = _dosDateTime(modified);
    final header = _localHeader(nameBytes, entry, time, date);
    // Only the sizes are kept for the central directory, so each payload
    // can be released as soon as it is written.
    final central = _CentralEntry(
      name: nameBytes,
      crc: entry.crc,
      method: entry.method,
      compressedSize: entry.payload.length,
      size: entry.size,
      time: time,
      date: date,
      offset: _offset,
    );
    await _out.writeFrom(header);
    await _out.writeFrom(entry.payload);
    _offset += header.length + entry.payload.length;
    _checkLimit(_offset);
    _entries.add(central);
  }

  /// Writes the central directory and end record, then closes the file.
  Future<void> close() async {
    final start = _offset;
    for (final e in _entries) {
      final bytes = e.toBytes();
      await _out.writeFrom(bytes);
      _offset += bytes.length;
    }
    _checkLimit(_offset);
    if (_entries.length > 0xffff) {
      throw StateError('Too many entries for a ZIP without ZIP64');
    }
    final end = _Bytes(22)
      ..u32(0x06054b50)
      ..u16(0)
      ..u16(0)
      ..u16(_entries.length)
      ..u16(_entries.length)
      ..u32(_offset - start)
      ..u32(start)
      ..u16(0);
    await _out.writeFrom(end.bytes);
    await _out.close();
  }

  /// Closes the file without finishing the archive, for a caller that is
  /// about to delete it after a cancel or a failure.
  Future<void> abort() => _out.close();

  static void _checkLimit(int offset) {
    if (offset > 0xffffffff) {
      throw StateError('Archive larger than 4 GB needs ZIP64');
    }
  }

  static Uint8List _localHeader(
    Uint8List name,
    EncodedZipEntry entry,
    int time,
    int date,
  ) {
    final b = _Bytes(30 + name.length)
      ..u32(0x04034b50)
      ..u16(_versionNeeded)
      ..u16(_flags)
      ..u16(entry.method)
      ..u16(time)
      ..u16(date)
      ..u32(entry.crc)
      ..u32(entry.payload.length)
      ..u32(entry.size)
      ..u16(name.length)
      ..u16(0)
      ..raw(name);
    return b.bytes;
  }

  static (int, int) _dosDateTime(DateTime t) {
    final year = t.year.clamp(1980, 2107);
    return (
      (t.hour << 11) | (t.minute << 5) | (t.second ~/ 2),
      ((year - 1980) << 9) | (t.month << 5) | t.day,
    );
  }
}

/// Version 2.0: Deflate and traditional encryption.
const _versionNeeded = 20;

/// Bit 0: encrypted. Bit 11: names are UTF-8.
const _flags = 0x0801;

const _seedLength = 11;
const _methodStored = 0;
const _methodDeflate = 8;

/// One entry, compressed and encrypted, ready to write.
class EncodedZipEntry {
  /// CRC-32 of the uncompressed data.
  final int crc;
  final int method;

  /// Uncompressed size.
  final int size;

  /// The 12-byte encryption header followed by the encrypted data.
  final Uint8List payload;

  const EncodedZipEntry({
    required this.crc,
    required this.method,
    required this.size,
    required this.payload,
  });
}

/// Compresses [data] (Deflate, or Stored when that is no smaller) and
/// encrypts it with ZipCrypto under [password], using [seed] (11 random
/// bytes) for the encryption header. Pure, so it can run on another isolate.
EncodedZipEntry encodeZipCryptoEntry(
  Uint8List password,
  Uint8List data,
  Uint8List seed,
) {
  assert(seed.length == _seedLength);
  final crc = getCrc32(data);
  final deflated = ZLibCodec(raw: true, level: 6).encode(data);
  final stored = deflated.length >= data.length;
  final body = stored ? data : deflated;

  final payload = Uint8List(12 + body.length);
  payload.setRange(0, _seedLength, seed);
  // The last header byte lets an unzipper check the password: the CRC's
  // high byte when there is no data descriptor.
  payload[_seedLength] = (crc >> 24) & 0xff;
  payload.setRange(12, payload.length, body);

  final keys = _ZipCryptoKeys(password);
  for (var i = 0; i < payload.length; i++) {
    final plain = payload[i];
    payload[i] = plain ^ keys.streamByte();
    keys.update(plain);
  }
  return EncodedZipEntry(
    crc: crc,
    method: stored ? _methodStored : _methodDeflate,
    size: data.length,
    payload: payload,
  );
}

class _ZipCryptoKeys {
  int _k0 = 0x12345678;
  int _k1 = 0x23456789;
  int _k2 = 0x34567890;

  _ZipCryptoKeys(Uint8List password) {
    for (final c in password) {
      update(c);
    }
  }

  void update(int c) {
    _k0 = getCrc32Byte(_k0, c);
    _k1 = ((_k1 + (_k0 & 0xff)) * 134775813 + 1) & 0xffffffff;
    _k2 = getCrc32Byte(_k2, _k1 >> 24);
  }

  int streamByte() {
    final t = (_k2 | 2) & 0xffff;
    return ((t * (t ^ 1)) >> 8) & 0xff;
  }
}

class _CentralEntry {
  final Uint8List name;
  final int crc;
  final int method;
  final int compressedSize;
  final int size;
  final int time;
  final int date;
  final int offset;

  _CentralEntry({
    required this.name,
    required this.crc,
    required this.method,
    required this.compressedSize,
    required this.size,
    required this.time,
    required this.date,
    required this.offset,
  });

  Uint8List toBytes() {
    final b = _Bytes(46 + name.length)
      ..u32(0x02014b50)
      ..u16(_versionNeeded)
      ..u16(_versionNeeded)
      ..u16(_flags)
      ..u16(method)
      ..u16(time)
      ..u16(date)
      ..u32(crc)
      ..u32(compressedSize)
      ..u32(size)
      ..u16(name.length)
      ..u16(0)
      ..u16(0)
      ..u16(0)
      ..u16(0)
      ..u32(0)
      ..u32(offset)
      ..raw(name);
    return b.bytes;
  }
}

/// A little-endian byte builder of a known size.
class _Bytes {
  _Bytes(int length) : bytes = Uint8List(length);

  final Uint8List bytes;
  late final ByteData _view = ByteData.sublistView(bytes);
  int _at = 0;

  void u16(int v) {
    _view.setUint16(_at, v, Endian.little);
    _at += 2;
  }

  void u32(int v) {
    _view.setUint32(_at, v, Endian.little);
    _at += 4;
  }

  void raw(Uint8List v) {
    bytes.setRange(_at, _at + v.length, v);
    _at += v.length;
  }
}
