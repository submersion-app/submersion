import 'dart:typed_data';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';

/// Counts what a transfer does to its hasher, and fails on request.
class RecordingBasePartHasher implements BasePartHasher {
  RecordingBasePartHasher({this.failOnPart, this.failOnFinish = false});

  final int? failOnPart;
  final bool failOnFinish;
  int added = 0;
  int disposals = 0;

  @override
  Future<String> addPart(Uint8List part) async {
    if (added++ == failOnPart) throw BasePartHasherException('worker died');
    return BaseChunker.checksum(part);
  }

  @override
  Future<String> finish() async {
    if (failOnFinish) throw BasePartHasherException('worker died');
    return 'sha256:whole';
  }

  @override
  Future<void> dispose() async => disposals++;
}
