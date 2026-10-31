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
/// usually runs on the UI isolate. The work lives in static functions so that
/// the closures handed to [runOffIsolate] close over their arguments alone: one
/// that held anything unsendable would still give the right answer, inline,
/// and the stall would quietly come back.
class ChangesetCodec {
  const ChangesetCodec({
    @visibleForTesting this.offIsolateMinBytes = kOffIsolateMinBytes,
    @visibleForTesting this.offIsolateRunner = isolateRun,
  });

  final int offIsolateMinBytes;
  final OffIsolateRunner offIsolateRunner;

  Future<Uint8List> encodeChangeset(SyncPayload payload) =>
      _encodeOffIsolate(payload, offIsolateMinBytes, offIsolateRunner);

  /// [bytes] parsed but not judged. A caller that applies the payload wants
  /// [decodeVerifiedChangeset].
  Future<SyncPayload> decodeChangeset(Uint8List bytes) =>
      _decodeOffIsolate(bytes, offIsolateMinBytes, offIsolateRunner);

  /// [bytes] parsed, with the checksum checked on the same worker.
  Future<VerifiedChangeset> decodeVerifiedChangeset(Uint8List bytes) =>
      _decodeVerifiedOffIsolate(bytes, offIsolateMinBytes, offIsolateRunner);

  static Future<Uint8List> _encodeOffIsolate(
    SyncPayload payload,
    int minBytes,
    OffIsolateRunner runner,
  ) => runOffIsolate(
    () => utf8.encode(jsonEncode(payload.toJson())),
    bytes: syncJsonWeight([
      payload.data.toJson(),
      // Lazy, so a long tombstone list is not built just to be measured.
      for (final list in payload.deletions.values)
        list.map((deletion) => deletion.toJson()),
    ], limit: minBytes),
    minBytes: minBytes,
    runner: runner,
  );

  static Future<SyncPayload> _decodeOffIsolate(
    Uint8List bytes,
    int minBytes,
    OffIsolateRunner runner,
  ) => runOffIsolate(
    () => _parse(bytes),
    bytes: bytes.length,
    minBytes: minBytes,
    isExpected: _isMalformed,
    runner: runner,
  );

  static Future<VerifiedChangeset> _decodeVerifiedOffIsolate(
    Uint8List bytes,
    int minBytes,
    OffIsolateRunner runner,
  ) => runOffIsolate(
    () {
      final payload = _parse(bytes);
      return (
        payload: payload,
        checksumValid: SyncDataSerializer.checksumIsValid(payload),
      );
    },
    bytes: bytes.length,
    minBytes: minBytes,
    isExpected: _isMalformed,
    runner: runner,
  );

  static SyncPayload _parse(Uint8List bytes) => SyncPayload.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
  );

  /// Bytes that do not hold a payload are an answer about the bytes, and
  /// parsing them again on this isolate would only repeat it.
  static bool _isMalformed(Object error) =>
      error is FormatException || error is TypeError;
}
