import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

typedef BasePartUploadResult = ({
  int partCount,
  String wholeChecksum,
  List<String> partChecksums,
  int byteLength,
});

/// Reads an assembled base temp file back out in fixed-size parts, checksumming
/// each part and the whole file incrementally so the full base is never held in
/// memory. Write-side mirror of [BasePartFileSink] (which does the reverse on
/// download). Each part is handed to [uploadAll]'s callback in order; the
/// returned checksums use the same `sha256:<hex>` convention as the manifest
/// fields, so a reader's verification against the manifest can only fail on real
/// transport corruption.
class BasePartFileSource {
  BasePartFileSource(this.path, {this.partSize = BaseChunker.defaultPartSize});

  final String path;
  final int partSize;

  /// Streams the file in [partSize] slices, invoking [upload] for each in order,
  /// and returns the part count plus the `sha256:` whole-file and per-part
  /// checksums (and the total byte length) for the manifest.
  Future<BasePartUploadResult> uploadAll(
    Future<void> Function(int index, Uint8List bytes) upload,
  ) async {
    final raf = await File(path).open();
    final digestSink = _DigestSink();
    final whole = sha256.startChunkedConversion(digestSink);
    final partChecksums = <String>[];
    try {
      final length = await raf.length();
      var index = 0;
      if (length == 0) {
        // Mirror BaseChunker.slice(empty) == [Uint8List(0)]: one empty part.
        final empty = Uint8List(0);
        whole.add(empty);
        partChecksums.add(BaseChunker.checksum(empty));
        await upload(0, empty);
        index = 1;
      } else {
        for (var off = 0; off < length; off += partSize) {
          final n = (off + partSize < length) ? partSize : length - off;
          final buf = await raf.read(n);
          whole.add(buf);
          partChecksums.add(BaseChunker.checksum(buf));
          await upload(index, buf);
          index++;
        }
      }
      whole.close();
      return (
        partCount: index,
        wholeChecksum: 'sha256:${digestSink.value}',
        partChecksums: partChecksums,
        byteLength: length,
      );
    } finally {
      await raf.close();
    }
  }
}

/// Minimal `Sink<Digest>` capturing the digest emitted at close (mirrors the one
/// in base_part_file_sink.dart; crypto does not export AccumulatorSink).
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
