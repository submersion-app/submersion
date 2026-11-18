import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// Unpacks a zip as its bytes arrive, so a model is written to disk once,
/// unpacked, rather than once as a zip and again unpacked (issue #4708).
///
/// Reads each entry's local header in order and stops at the central
/// directory, which only repeats them. Entries are stored or deflated, with
/// their sizes in the local header or its ZIP64 extra field. A zip written
/// to a stream, whose sizes follow the data instead, is refused: the pack
/// builder (`tool/species_pack/models.py`) writes its zips to a file, so
/// their headers carry the sizes.
///
/// Throws [PackManifestException] for a zip it cannot unpack, an entry that
/// would land outside the folder or a file that does not unpack to its
/// recorded size, and lets a [FileSystemException] (a full disk) through.
/// After a failure, [abort] closes the open file; the caller removes the
/// folder.
class ZipStreamUnpacker {
  ZipStreamUnpacker(String outPath) : _root = p.normalize(p.absolute(outPath));

  final String _root;

  /// Header bytes received but not yet parsed.
  final _header = BytesBuilder();
  _Entry? _entry;

  /// The central directory has begun: the rest is not unpacked.
  var _ended = false;

  static const _localHeader = 0x04034b50;
  static const _localHeaderLength = 30;
  static const _centralHeader = 0x02014b50;
  static const _endOfCentralDirectory = 0x06054b50;
  static const _zip64EndOfCentralDirectory = 0x06064b50;

  /// Compressed bytes inflated in one step. Deflate can expand a run of
  /// zeros about a thousandfold, so this bounds what one step holds in
  /// memory before it is written.
  static const _inflateStep = 16 * 1024;

  Future<void> add(List<int> chunk) async {
    var offset = 0;
    while (offset < chunk.length && !_ended) {
      final entry = _entry;
      if (entry == null) {
        offset = await _readHeader(chunk, offset);
      } else {
        offset = await _readData(entry, chunk, offset);
      }
    }
  }

  /// The zip ended: anything left mid-entry means it was cut short.
  Future<void> close() async {
    if (_entry != null || _header.isNotEmpty) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'a model zip ended inside a file',
      );
    }
  }

  /// Closes the file being written, after a failure.
  Future<void> abort() async {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    try {
      await entry.out?.close();
    } on FileSystemException {
      // The caller removes the folder either way.
    }
  }

  /// Takes header bytes from [chunk] at [offset]; once a whole header is
  /// in, opens its entry. Returns where the header ended.
  Future<int> _readHeader(List<int> chunk, int offset) async {
    if (_header.length < 4) {
      offset = _takeHeader(chunk, offset, 4);
      if (_header.length < 4) return offset;
      final signature = _u32(_header.toBytes(), 0);
      if (signature != _localHeader) {
        if (signature == _centralHeader ||
            signature == _endOfCentralDirectory ||
            signature == _zip64EndOfCentralDirectory) {
          _header.clear();
          _ended = true;
          return chunk.length;
        }
        throw const PackManifestException(
          PackManifestFailure.malformed,
          'a model file is not a zip',
        );
      }
    }
    if (_header.length < _localHeaderLength) {
      offset = _takeHeader(chunk, offset, _localHeaderLength);
      if (_header.length < _localHeaderLength) return offset;
    }
    // The fixed part gives the name and extra field lengths.
    final fixed = _header.toBytes();
    final needed = _localHeaderLength + _u16(fixed, 26) + _u16(fixed, 28);
    offset = _takeHeader(chunk, offset, needed);
    if (_header.length < needed) return offset;
    final entry = await _open(_header.takeBytes());
    _entry = entry;
    if (entry.remaining == 0) await _finish(entry);
    return offset;
  }

  /// Moves bytes from [chunk] at [offset] into the header until it holds
  /// [upTo]. Returns where the taken bytes ended.
  int _takeHeader(List<int> chunk, int offset, int upTo) {
    final take = _min(upTo - _header.length, chunk.length - offset);
    if (take > 0) _header.add(chunk.sublist(offset, offset + take));
    return offset + take;
  }

  Future<_Entry> _open(Uint8List header) async {
    final flags = _u16(header, 6);
    final method = _u16(header, 8);
    if (flags & 0x1 != 0) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'a model zip is encrypted',
      );
    }
    if (flags & 0x8 != 0) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'a model zip has no sizes in its headers',
      );
    }
    if (method != 0 && method != 8) {
      throw PackManifestException(
        PackManifestFailure.malformed,
        'a model zip uses compression method $method',
      );
    }
    final nameLength = _u16(header, 26);
    final name = utf8.decode(
      header.sublist(_localHeaderLength, _localHeaderLength + nameLength),
      allowMalformed: true,
    );
    var compressed = _u32(header, 18);
    var size = _u32(header, 22);
    if (compressed == 0xFFFFFFFF || size == 0xFFFFFFFF) {
      (size, compressed) = _zip64Sizes(
        header,
        _localHeaderLength + nameLength,
        size: size,
        compressed: compressed,
      );
    }
    final target = p.normalize(p.join(_root, name));
    if (!p.isWithin(_root, target)) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'a model file would land outside its folder',
      );
    }
    final entry = _Entry(
      name: name,
      remaining: compressed,
      size: size,
      inflate: method == 8,
    );
    if (name.endsWith('/')) {
      await Directory(target).create(recursive: true);
    } else {
      await File(target).parent.create(recursive: true);
      entry.out = await File(target).open(mode: FileMode.write);
    }
    return entry;
  }

  /// The real sizes from a ZIP64 extra field, which holds the uncompressed
  /// then the compressed size, each only where the header says 0xFFFFFFFF.
  static (int, int) _zip64Sizes(
    Uint8List header,
    int extraStart, {
    required int size,
    required int compressed,
  }) {
    var at = extraStart;
    while (at + 4 <= header.length) {
      final id = _u16(header, at);
      final length = _u16(header, at + 2);
      if (id == 0x0001) {
        var field = at + 4;
        if (size == 0xFFFFFFFF && field + 8 <= header.length) {
          size = _u64(header, field);
          field += 8;
        }
        if (compressed == 0xFFFFFFFF && field + 8 <= header.length) {
          compressed = _u64(header, field);
        }
        return (size, compressed);
      }
      at += 4 + length;
    }
    throw const PackManifestException(
      PackManifestFailure.malformed,
      'a model zip has no ZIP64 sizes',
    );
  }

  /// Writes [entry]'s data from [chunk] at [offset]. Returns where its
  /// data ended in [chunk].
  Future<int> _readData(_Entry entry, List<int> chunk, int offset) async {
    final end = offset + _min(entry.remaining, chunk.length - offset);
    final out = entry.out;
    if (entry.inflate) {
      for (var at = offset; at < end; at += _inflateStep) {
        final stop = _min(at + _inflateStep, end);
        try {
          entry.inflater.addSlice(chunk, at, stop, false);
        } on FormatException {
          throw _doesNotInflate(entry);
        }
        await _drain(entry);
      }
    } else if (out != null) {
      await out.writeFrom(chunk, offset, end);
      entry.written += end - offset;
    }
    entry.remaining -= end - offset;
    if (entry.remaining == 0) await _finish(entry);
    return end;
  }

  Future<void> _finish(_Entry entry) async {
    if (entry.inflate) {
      try {
        entry.inflater.close();
      } on FormatException {
        throw _doesNotInflate(entry);
      }
      await _drain(entry);
    }
    await entry.out?.close();
    entry.out = null;
    _entry = null;
    if (!entry.name.endsWith('/') && entry.written != entry.size) {
      throw PackManifestException(
        PackManifestFailure.malformed,
        '${entry.name} did not unpack in full',
      );
    }
  }

  /// Writes what the inflater has produced so far.
  static Future<void> _drain(_Entry entry) async {
    final out = entry.out;
    for (final piece in entry.inflated.pieces) {
      if (out != null) await out.writeFrom(piece);
      entry.written += piece.length;
    }
    entry.inflated.pieces.clear();
  }

  static PackManifestException _doesNotInflate(_Entry entry) =>
      PackManifestException(
        PackManifestFailure.malformed,
        '${entry.name} does not inflate',
      );

  static int _u16(List<int> b, int at) => b[at] | (b[at + 1] << 8);

  static int _u32(List<int> b, int at) =>
      b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);

  /// A little-endian uint64 as two 32-bit halves: the web build has no
  /// 64-bit ByteData (#4194), and this is exact there up to 2^53.
  static int _u64(List<int> b, int at) =>
      _u32(b, at + 4) * 0x100000000 + _u32(b, at);

  static int _min(int a, int b) => a < b ? a : b;
}

class _Entry {
  _Entry({
    required this.name,
    required this.remaining,
    required this.size,
    required this.inflate,
  });

  final String name;

  /// Compressed bytes still to come.
  int remaining;

  /// The unpacked size the zip records.
  final int size;

  /// Deflated, else stored.
  final bool inflate;
  int written = 0;
  RandomAccessFile? out;

  final inflated = _Pieces();

  /// Made only for a deflated entry, at its first data.
  late final ByteConversionSink inflater = ZLibDecoder(
    raw: true,
  ).startChunkedConversion(inflated);
}

/// Collects the inflater's output until it is written.
class _Pieces implements Sink<List<int>> {
  final pieces = <List<int>>[];

  @override
  void add(List<int> data) => pieces.add(data);

  @override
  void close() {}
}
