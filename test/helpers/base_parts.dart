import 'dart:typed_data';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

/// [data] as the parts a device publishes, for a test holding it in memory.
List<Uint8List> sliceBaseParts(
  Uint8List data, {
  int partSize = BaseChunker.defaultPartSize,
}) {
  if (data.isEmpty) return [Uint8List(0)];
  return [
    for (var off = 0; off < data.length; off += partSize)
      Uint8List.sublistView(
        data,
        off,
        off + partSize < data.length ? off + partSize : data.length,
      ),
  ];
}

/// [parts] back as the bytes they were cut from.
Uint8List joinBaseParts(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  parts.forEach(out.add);
  return out.takeBytes();
}
