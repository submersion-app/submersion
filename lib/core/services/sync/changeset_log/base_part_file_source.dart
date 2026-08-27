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

  /// Number of parts [path] will be sliced into, without reading it.
  ///
  /// Known from the length alone, so a caller can publish a denominator before
  /// the first byte moves. Mirrors the empty-file special case below.
  static int partCountFor(
    int byteLength, {
    int partSize = BaseChunker.defaultPartSize,
  }) => byteLength == 0 ? 1 : (byteLength + partSize - 1) ~/ partSize;

  /// Streams the file in [partSize] slices, invoking [upload] for each in order,
  /// and returns the part count plus the `sha256:` whole-file and per-part
  /// checksums (and the total byte length) for the manifest.
  ///
  /// [onPartUploaded] fires once per part, as `(uploaded, total)`, after that
  /// part has been dealt with -- uploaded, or skipped and re-hashed. A full
  /// base republish, which is what a wiped backend forces, can run to hundreds
  /// of megabytes, and without this tick the sync UI shows one motionless step
  /// for the entire transfer and reads as a hang (issue #1032).
  ///
  /// Counting skipped parts is deliberate rather than incidental: on a resumed
  /// publish the bar sweeps quickly through what already landed and then slows
  /// to the real upload rate, which is a truthful picture of the work left. A
  /// tick that fired only on genuine uploads would restart the bar at zero and
  /// hide the progress the previous attempt made.
  ///
  /// [skipPart] suppresses the network call for parts already present in the
  /// cloud, so an interrupted publish resumes instead of re-uploading hundreds
  /// of megabytes (issue #1032).
  ///
  /// Skipped parts are still read and hashed. That is the point: the checksums
  /// in the manifest then always describe the bytes actually on disk right now,
  /// so a file that was truncated between attempts fails verification instead of
  /// being certified by checksums recorded while it was still intact. Re-reading
  /// local disk is cheap next to re-uploading.
  Future<BasePartUploadResult> uploadAll(
    Future<void> Function(int index, Uint8List bytes) upload, {
    void Function(int uploaded, int total)? onPartUploaded,
    bool Function(int index)? skipPart,
  }) async {
    final raf = await File(path).open();
    final digestSink = _DigestSink();
    final whole = sha256.startChunkedConversion(digestSink);
    final partChecksums = <String>[];
    try {
      final length = await raf.length();
      final total = partCountFor(length, partSize: partSize);
      var index = 0;
      if (length == 0) {
        // Mirror BaseChunker.slice(empty) == [Uint8List(0)]: one empty part.
        final empty = Uint8List(0);
        whole.add(empty);
        partChecksums.add(BaseChunker.checksum(empty));
        if (skipPart?.call(0) != true) await upload(0, empty);
        index = 1;
        onPartUploaded?.call(index, total);
      } else {
        for (var off = 0; off < length; off += partSize) {
          final n = (off + partSize < length) ? partSize : length - off;
          final buf = await raf.read(n);
          whole.add(buf);
          partChecksums.add(BaseChunker.checksum(buf));
          if (skipPart?.call(index) != true) await upload(index, buf);
          index++;
          onPartUploaded?.call(index, total);
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
