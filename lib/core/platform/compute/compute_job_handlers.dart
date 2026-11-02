import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/opfs_files.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/byte_progress_stream.dart';

/// Runs every [ComputeJob], in the worker or inline.
///
/// Plain Dart: the browser worker is compiled apart from Flutter, and the
/// native path runs the same code on an isolate. Hash and parse sessions keep
/// state between calls, so one handler serves one worker (or one isolate run)
/// for its lifetime. Errors are thrown as the exception types the callers
/// catch; the worker maps them to wire kinds and the client maps them back.
class ComputeJobHandler {
  ComputeJobHandler({
    required this.files,
    this.parseBatchSize = 500,
    this.readChunkBytes = 1 << 20,
  });

  final OpfsFiles files;

  /// Rows per `baseParseNext` reply; the isolate worker's 500.
  final int parseBatchSize;

  /// Bytes read from a temp file per step while parsing.
  final int readChunkBytes;

  final Map<int, _HashSession> _hashes = {};
  final Map<int, _ParseSession> _parses = {};
  int _nextSession = 1;

  /// Runs [job] with [args]. [onProgress] hears byte progress while a parse
  /// pass runs.
  Future<Object?> handle(
    ComputeJob job,
    Map<String, Object?> args, {
    void Function(int bytes, int total)? onProgress,
  }) async {
    switch (job) {
      case ComputeJob.inflateBounded:
        return PlatformZlib.inflateBounded(
          _bytes(args, 'bytes'),
          maxBytes: _int(args, 'maxBytes'),
          framing: ZlibFraming.values.byName(
            args['framing'] as String? ?? ZlibFraming.zlib.name,
          ),
        );
      case ComputeJob.deflate:
        return PlatformZlib.deflate(
          _bytes(args, 'bytes'),
          level: _int(args, 'level', 6),
        );
      case ComputeJob.gzip:
        return PlatformZlib.gzip(
          _bytes(args, 'bytes'),
          level: _int(args, 'level', 6),
        );
      case ComputeJob.gunzip:
        return PlatformZlib.gunzip(_bytes(args, 'bytes'));
      case ComputeJob.aesGcmEncrypt:
        final box = await DartAesGcm.with256bits().encrypt(
          _bytes(args, 'plaintext'),
          secretKey: SecretKeyData(_bytes(args, 'key')),
          nonce: _bytes(args, 'nonce'),
          aad: _optionalBytes(args, 'aad') ?? const [],
        );
        return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
      case ComputeJob.aesGcmDecrypt:
        final sealed = _bytes(args, 'ciphertextWithMac');
        if (sealed.length < 16) {
          throw ArgumentError.value(
            sealed.length,
            'ciphertextWithMac',
            'shorter than the 16 byte tag',
          );
        }
        final split = sealed.length - 16;
        final clear = await DartAesGcm.with256bits().decrypt(
          SecretBox(
            Uint8List.sublistView(sealed, 0, split),
            nonce: _bytes(args, 'nonce'),
            mac: Mac(Uint8List.sublistView(sealed, split)),
          ),
          secretKey: SecretKeyData(_bytes(args, 'key')),
          aad: _optionalBytes(args, 'aad') ?? const [],
        );
        return clear is Uint8List ? clear : Uint8List.fromList(clear);
      case ComputeJob.argon2id:
        final key =
            await DartArgon2id(
              parallelism: _int(args, 'parallelism'),
              memory: _int(args, 'memoryKiB'),
              iterations: _int(args, 'iterations'),
              hashLength: _int(args, 'hashLength'),
            ).deriveKey(
              secretKey: SecretKeyData(_bytes(args, 'password')),
              nonce: _bytes(args, 'salt'),
            );
        return Uint8List.fromList(await key.extractBytes());
      case ComputeJob.sha256:
        return Uint8List.fromList(
          crypto.sha256.convert(_bytes(args, 'bytes')).bytes,
        );
      case ComputeJob.hashStart:
        final id = _nextSession++;
        _hashes[id] = _HashSession();
        return id;
      case ComputeJob.hashAddPart:
        return _hash(args).addPart(_bytes(args, 'bytes'));
      case ComputeJob.hashFinish:
        return _hash(args).finish();
      case ComputeJob.hashDispose:
        _hashes.remove(_int(args, 'session'));
        return null;
      case ComputeJob.opfsCreate:
        return files.create(_string(args, 'name'));
      case ComputeJob.opfsAppend:
        await files.append(_int(args, 'handle'), _bytes(args, 'bytes'));
        return null;
      case ComputeJob.opfsClose:
        return files.close(_int(args, 'handle'));
      case ComputeJob.opfsRead:
        return files.read(
          _string(args, 'path'),
          _int(args, 'offset'),
          _int(args, 'length'),
        );
      case ComputeJob.opfsLength:
        return files.length(_string(args, 'path'));
      case ComputeJob.opfsExists:
        return files.exists(_string(args, 'path'));
      case ComputeJob.opfsDelete:
        await files.delete(_string(args, 'path'));
        return null;
      case ComputeJob.baseParseScalars:
        return _scalarsAndDeletions(_string(args, 'path'), onProgress);
      case ComputeJob.baseParseStart:
        final id = _nextSession++;
        _parses[id] = _ParseSession(
          this,
          _string(args, 'path'),
          (args['tables'] as List).cast<String>().toSet(),
        );
        return id;
      case ComputeJob.baseParseNext:
        return _parse(args).next(onProgress);
      case ComputeJob.baseParseDispose:
        _parses.remove(_int(args, 'session'))?.dispose();
        return null;
    }
  }

  /// The file at [path] as a stream of [readChunkBytes] chunks, reporting
  /// consumed bytes to [onProgress] the way the isolate worker does.
  Stream<List<int>> _readWithProgress(
    String path,
    int total,
    void Function(int bytes, int total)? onProgress,
  ) {
    Stream<List<int>> chunks() async* {
      var offset = 0;
      while (offset < total) {
        final chunk = await files.read(
          path,
          offset,
          min(readChunkBytes, total - offset),
        );
        if (chunk.isEmpty) break;
        offset += chunk.length;
        yield chunk;
      }
    }

    return withByteProgress(
      chunks(),
      onProgress: (consumed) => onProgress?.call(consumed, total),
    );
  }

  /// Pass 1 of a base file: the `exportedAt` scalar and every row of the
  /// `deletions` section, in file order.
  Future<Map<String, Object?>> _scalarsAndDeletions(
    String path,
    void Function(int bytes, int total)? onProgress,
  ) async {
    final total = await files.length(path);
    var exportedAt = 0;
    final rows = <Map<String, Object?>>[];
    await BaseJsonStreamReader().parse(
      _readWithProgress(path, total, onProgress),
      onScalar: (key, raw) async {
        if (key == 'exportedAt') {
          exportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
        }
      },
      wantRows: (section, _) => section == 'deletions',
      onRow: (section, table, rowBytes) async {
        final decoded = jsonDecode(utf8.decode(rowBytes));
        // A legacy base can encode a deletion as a bare string id. Normalise
        // it to the {id, deletedAt: 0} map the inline path synthesises, as
        // the isolate worker does. Other non-map rows are dropped.
        final Object? row = decoded is String
            ? <String, Object?>{'id': decoded, 'deletedAt': 0}
            : decoded;
        if (row is! Map) return;
        rows.add(<String, Object?>{'table': table, 'row': row});
      },
    );
    return {'exportedAt': exportedAt, 'rows': rows};
  }

  _HashSession _hash(Map<String, Object?> args) {
    final id = _int(args, 'session');
    return _hashes[id] ?? (throw StateError('hash session $id is not open'));
  }

  _ParseSession _parse(Map<String, Object?> args) {
    final id = _int(args, 'session');
    return _parses[id] ?? (throw StateError('parse session $id is not open'));
  }

  static Uint8List _bytes(Map<String, Object?> args, String key) =>
      _optionalBytes(args, key) ??
      (throw ArgumentError.value(null, key, 'bytes are required'));

  static Uint8List? _optionalBytes(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    throw ArgumentError.value(value, key, 'not bytes');
  }

  static int _int(Map<String, Object?> args, String key, [int? fallback]) {
    final value = args[key];
    if (value is num) return value.toInt();
    if (value == null && fallback != null) return fallback;
    throw ArgumentError.value(value, key, 'not an integer');
  }

  static String _string(Map<String, Object?> args, String key) =>
      args[key] as String? ??
      (throw ArgumentError.value(null, key, 'a string is required'));
}

/// The rolling whole-file digest of one base transfer, part by part.
class _HashSession {
  final _DigestSink _digest = _DigestSink();
  late final ByteConversionSink _whole = crypto.sha256.startChunkedConversion(
    _digest,
  );

  String addPart(Uint8List part) {
    _whole.add(part);
    return BaseChunker.checksum(part);
  }

  String finish() {
    _whole.close();
    return 'sha256:${_digest.value}';
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}

/// Pass 2 of a base file: the `data` rows of the requested tables, handed
/// out one batch per [next] call with the parse paused in between, so the
/// caller's pulls are the back-pressure. Calls are sequential.
class _ParseSession {
  _ParseSession(this._handler, this._path, this._tables);

  final ComputeJobHandler _handler;
  final String _path;
  final Set<String> _tables;

  void Function(int bytes, int total)? _onProgress;
  Completer<Map<String, Object?>>? _waiting;
  Completer<void>? _resume;
  List<Map<String, Object?>> _batch = [];
  bool _started = false;
  bool _done = false;
  bool _disposed = false;
  int _bytes = 0;
  int _total = 0;

  Future<Map<String, Object?>> next(
    void Function(int bytes, int total)? onProgress,
  ) {
    if (_disposed) throw StateError('parse session is disposed');
    _onProgress = onProgress;
    if (_done) return Future.value(_reply(const [], done: true));
    final waiting = _waiting = Completer<Map<String, Object?>>();
    if (!_started) {
      _started = true;
      unawaited(_run());
    } else {
      _resume?.complete();
      _resume = null;
    }
    return waiting.future;
  }

  Future<void> _run() async {
    try {
      _total = await _handler.files.length(_path);
      await BaseJsonStreamReader().parse(
        _handler._readWithProgress(_path, _total, (bytes, total) {
          _bytes = bytes;
          _onProgress?.call(bytes, total);
        }),
        wantRows: (section, table) =>
            section == 'data' && _tables.contains(table),
        onRow: (section, table, rowBytes) async {
          _batch.add(<String, Object?>{
            'table': table,
            'row': jsonDecode(utf8.decode(rowBytes)),
          });
          if (_batch.length >= _handler.parseBatchSize) {
            _deliver(done: false);
            final resume = _resume = Completer<void>();
            await resume.future;
            if (_disposed) throw StateError('parse session is disposed');
          }
        },
      );
      _done = true;
      _deliver(done: true);
    } catch (e, st) {
      _done = true;
      final waiting = _waiting;
      _waiting = null;
      if (!_disposed) waiting?.completeError(e, st);
    }
  }

  void _deliver({required bool done}) {
    final rows = _batch;
    _batch = [];
    final waiting = _waiting;
    _waiting = null;
    waiting?.complete(_reply(rows, done: done));
  }

  Map<String, Object?> _reply(List<Object?> rows, {required bool done}) => {
    'rows': rows,
    'done': done,
    'bytes': _bytes,
    'total': _total,
  };

  void dispose() {
    _disposed = true;
    _resume?.complete();
    _resume = null;
    final waiting = _waiting;
    _waiting = null;
    waiting?.completeError(StateError('parse session is disposed'));
  }
}
