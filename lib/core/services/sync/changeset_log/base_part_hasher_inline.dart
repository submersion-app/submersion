import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher_types.dart';

/// Hashes on the calling thread. The native and browser openers hand it
/// out for small transfers, and fall back to it when their worker cannot
/// start.
class InlineBasePartHasher implements BasePartHasher {
  final _digest = _DigestSink();
  late final _whole = sha256.startChunkedConversion(_digest);

  @override
  Future<String> addPart(Uint8List part) async {
    _whole.add(part);
    return BaseChunker.checksum(part);
  }

  @override
  Future<String> finish() async {
    _whole.close();
    return 'sha256:${_digest.value}';
  }

  @override
  Future<void> dispose() async {}
}

/// Minimal `Sink<Digest>` that captures the single digest emitted at close.
/// Avoids depending on `package:convert`'s `AccumulatorSink` (not exported by
/// `crypto`).
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
