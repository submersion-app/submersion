import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_sync_engine.dart';
import 'package:submersion/core/services/nearby/nearby_watermarks.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// A scripted library for nearby protocol tests: canned exports, recorded
/// applies, and watermarks that move to [marksAfterApply] once something
/// is applied.
class FakeNearbySyncEngine implements NearbySyncEngine {
  FakeNearbySyncEngine({
    required this.self,
    required this.marks,
    this.marksAfterApply,
    this.delta,
    this.fullContent,
    this.blobBytes = 0,
    this.maxDeltaBlobBytes = 16 * 1024 * 1024,
    required this.tempDir,
  });

  NearbyIdentity self;
  Map<String, String> marks;
  Map<String, String>? marksAfterApply;
  SyncPayload? delta;

  /// What [exportFull] writes; null throws.
  String? fullContent;
  int blobBytes;
  final Directory tempDir;

  @override
  final int maxDeltaBlobBytes;

  final exportDeltaCalls = <String>[];
  int exportFullCalls = 0;
  final appliedPayloads = <SyncPayload>[];
  final appliedFiles = <String>[];
  final recordedApplied = <({String peer, String? high, String? low})>[];
  final recordedAcks = <({String peer, String? ack})>[];
  final adoptedEpochs = <String>[];

  @override
  Future<NearbyIdentity> identity() async {
    // A real identity reads the database; a delay lets tests open the race
    // window between two sessions with the same peer.
    if (identityDelay > Duration.zero) {
      await Future<void>.delayed(identityDelay);
    }
    return self;
  }

  Duration identityDelay = Duration.zero;

  @override
  Future<NearbyWatermarks> watermarks() async => NearbyWatermarks(marks);

  @override
  Future<int> deltaBlobBytes(String watermark) async => blobBytes;

  @override
  Future<SyncPayload> exportDelta(String watermark) async {
    exportDeltaCalls.add(watermark);
    return delta!;
  }

  /// How long [exportFull] takes, for tests of a slow first copy.
  Duration exportDelay = Duration.zero;

  @override
  Future<StreamedBase> exportFull() async {
    exportFullCalls++;
    if (exportDelay > Duration.zero) await Future<void>.delayed(exportDelay);
    final file = File(
      p.join(
        tempDir.path,
        'fake-full-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await file.writeAsString(fullContent!);
    return (
      path: file.path,
      byteLength: await file.length(),
      exportedAt: 0,
      toHlc: null,
      rowCount: 1,
    );
  }

  void _moveMarks() {
    final after = marksAfterApply;
    if (after != null) marks = after;
  }

  /// Thrown by every apply while set, as a locked or failing database
  /// would.
  Object? applyError;

  /// Rows every apply reports it could not merge, as a constraint error
  /// on some of them would.
  int recordsFailed = 0;

  @override
  Future<NearbyApplyResult> applyPayload(
    SyncPayload payload, {
    required String peerDeviceId,
  }) async {
    final error = applyError;
    if (error != null) throw error;
    appliedPayloads.add(payload);
    _moveMarks();
    return (recordsApplied: 1, conflictsFound: 0, recordsFailed: recordsFailed);
  }

  @override
  Future<NearbyApplyResult> applyBaseFile(
    String path, {
    required String peerDeviceId,
    void Function(double fraction)? onProgress,
  }) async {
    final error = applyError;
    if (error != null) throw error;
    appliedFiles.add(await File(path).readAsString());
    _moveMarks();
    return (recordsApplied: 1, conflictsFound: 0, recordsFailed: recordsFailed);
  }

  @override
  Future<void> recordApplied({
    required String peerDeviceId,
    required String? appliedHlcHigh,
    required String? lowestAppliedHlc,
  }) async => recordedApplied.add((
    peer: peerDeviceId,
    high: appliedHlcHigh,
    low: lowestAppliedHlc,
  ));

  @override
  Future<void> recordPeerAck({
    required String peerDeviceId,
    required String? peerAppliedHlcHigh,
  }) async => recordedAcks.add((peer: peerDeviceId, ack: peerAppliedHlcHigh));

  /// What [lowestClockOf] answers, per writer.
  Map<String, String> lowestByWriter = {};

  @override
  Future<String?> lowestClockOf(String writer) async => lowestByWriter[writer];

  @override
  Future<void> adoptEpoch(String epochId) async {
    adoptedEpochs.add(epochId);
    self = self.copyWith(epochId: epochId);
  }
}

/// A delta payload whose rows are tags with the given clocks.
SyncPayload fakeTagsPayload(List<(String id, String hlc)> tags) {
  final data = SyncData.fromJson({
    'tags': [
      for (final (id, clock) in tags) {'id': id, 'hlc': clock},
    ],
  });
  return SyncPayload(
    version: syncFormatVersion,
    exportedAt: 0,
    deviceId: 'fake',
    checksum: SyncDataSerializer.checksumOf(data),
    data: data,
    deletions: const {},
  );
}

String fakeHlc(int ms, String node) =>
    '${ms.toString().padLeft(15, '0')}:000000:$node';

/// JSON-safe content that gzip cannot shrink much, so a test controls how
/// many parts a full copy needs.
String incompressibleJson(int approxBytes) {
  final random = Random(approxBytes);
  final bytes = List<int>.generate(
    (approxBytes * 3) ~/ 4,
    (_) => random.nextInt(256),
  );
  return jsonEncode({'blob': base64Encode(bytes)});
}
