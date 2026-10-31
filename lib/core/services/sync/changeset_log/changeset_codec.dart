import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_json_weight.dart';
import 'package:submersion/core/utils/off_isolate.dart';

/// A received payload, and whether its checksum matched. They come back
/// together because hashing a large data section stalls the calling isolate as
/// badly as parsing it does.
typedef VerifiedChangeset = ({SyncPayload payload, bool checksumValid});

/// Bridges payloads and the on-storage byte form: a changeset is one JSON
/// object. A base has the same shape but is streamed to and from a temp file
/// (see [SyncDataSerializer.exportBaseToTempFile]), never held here.
///
/// A substantial payload is encoded and decoded on a worker, because a sync
/// usually runs on the UI isolate. The closures handed to [runOffIsolate] reach
/// their arguments alone: one that held anything unsendable would still give
/// the right answer, inline, and the stall would quietly come back.
class ChangesetCodec {
  const ChangesetCodec({
    @visibleForTesting this.offIsolateMinBytes = kOffIsolateMinBytes,
    @visibleForTesting this.offIsolateRunner = isolateRun,
  });

  final int offIsolateMinBytes;
  final OffIsolateRunner offIsolateRunner;

  Future<Uint8List> encodeChangeset(SyncPayload payload) => runOffIsolate(
    () => utf8.encode(jsonEncode(payload.toJson())),
    bytes: syncJsonWeight([
      payload.data.toJson(),
      // Lazy, so a long tombstone list is not built just to be measured.
      for (final list in payload.deletions.values)
        list.map((deletion) => deletion.toJson()),
    ], limit: offIsolateMinBytes),
    minBytes: offIsolateMinBytes,
    runner: offIsolateRunner,
  );

  /// [bytes] parsed, with the checksum checked on the same worker. Bytes that
  /// hold no payload at all throw, which a caller reports as a failed read.
  Future<VerifiedChangeset> decodeVerifiedChangeset(Uint8List bytes) =>
      runOffIsolate(
        () {
          final payload = SyncPayload.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          );
          return (
            payload: payload,
            checksumValid: SyncDataSerializer.checksumIsValid(payload),
          );
        },
        bytes: bytes.length,
        minBytes: offIsolateMinBytes,
        isExpected: _isMalformed,
        runner: offIsolateRunner,
      );

  /// Bytes that do not hold a payload are an answer about the bytes, and
  /// parsing them again on this isolate would only repeat it.
  static bool _isMalformed(Object error) =>
      error is FormatException || error is TypeError;
}
