import 'dart:convert';
import 'dart:typed_data';

/// Compresses [mebibytes] MiB of zeros through [encoder], streaming so the
/// fixture itself never costs [mebibytes] MiB.
///
/// The point of a bomb fixture is that the compressed form is tiny and the
/// body is not, so building it the obvious way (allocate the body, encode
/// it) would need exactly the memory the guard under test exists to avoid.
Uint8List compressZeros(
  Converter<List<int>, List<int>> encoder, {
  required int mebibytes,
}) {
  final chunks = <List<int>>[];
  final sink = encoder.startChunkedConversion(_Collect(chunks));
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < mebibytes; i++) {
    sink.add(block);
  }
  sink.close();
  final out = BytesBuilder(copy: false);
  for (final c in chunks) {
    out.add(c);
  }
  return out.takeBytes();
}

class _Collect implements Sink<List<int>> {
  _Collect(this.chunks);

  final List<List<int>> chunks;

  @override
  void add(List<int> data) => chunks.add(data);

  @override
  void close() {}
}
