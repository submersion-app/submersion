import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

/// Bridges the serializer and the on-storage byte form: a changeset is one
/// JSON object; a base is the same JSON byte-sliced into resumable parts.
class ChangesetCodec {
  ChangesetCodec(this.serializer);

  final SyncDataSerializer serializer;

  Uint8List encodeChangeset(SyncPayload payload) =>
      Uint8List.fromList(utf8.encode(serializer.serializePayload(payload)));

  SyncPayload decodeChangeset(Uint8List bytes) =>
      serializer.deserializePayload(utf8.decode(bytes));

  List<Uint8List> encodeBaseParts(
    SyncPayload base, {
    int partSize = BaseChunker.defaultPartSize,
  }) => BaseChunker.slice(encodeChangeset(base), partSize: partSize);

  SyncPayload decodeBaseParts(List<Uint8List> parts) =>
      decodeChangeset(BaseChunker.reassemble(parts));
}
