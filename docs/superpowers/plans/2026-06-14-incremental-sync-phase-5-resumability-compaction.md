# Incremental Sync — Phase 5: Resumability + Compaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound the changeset log (compaction) and harden transfers (integrity verification). After this, an active device periodically rewrites a fresh base and prunes superseded files, and the reader rejects corrupt/incomplete data instead of applying it.

**Architecture:** Extends the Phase 3 `ChangesetWriter` and Phase 4 `ChangesetReader` — no new components. Compaction trigger is injectable (`compactionByteRatio` default 0.30, `compactionMaxChangesets` default 200) so tests fire it with tiny values. Superseded files are deleted **inline** after the new base is committed: this is correct because the reader is gap-tolerant + idempotent and a base supersedes the changesets it replaces (a mid-fetch peer simply cold-starts from the new base next sync). A time-based grace window remains a future optimization, not a correctness need. The reader verifies the base whole-checksum and each changeset's embedded checksum; a mismatch is treated as transient (stop, retry next sync). Cross-restart disk staging (resume a half-downloaded base after an app kill) is a documented future optimization — file-level resume already exists via cursor + gap-tolerance.

**Tech Stack:** Flutter, Drift, `flutter_test`, Phase 1 `FakeCloudStorageProvider`.

**Phase roadmap:** 1 ✅ 2 ✅ 3 ✅ 4 ✅ → **5 (resumability + compaction) ← this plan** → 6 (restore + coexistence) → wire writer+reader into `performSync`.

---

### Task 1: Compaction in `ChangesetWriter`

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart`
- Test: `test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    // Tiny threshold: compact after 2 changesets past the base.
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(db),
      compactionMaxChangesets: 2,
    );
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<ChangesetWriteResult> publish() async {
    final deviceId = await SyncRepository().getDeviceId();
    final deletions = await SyncRepository().getAllDeletions();
    return writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: deletions,
    );
  }

  test('compacts after the changeset threshold and prunes superseded files',
      () async {
    final deviceId = await SyncRepository().getDeviceId();
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
    await publish(); // base @1
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
    await publish(); // cs @2
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd3', diveNumber: 3));
    final result = await publish(); // cs @3 -> trips (headSeq-baseSeq == 2) -> compact

    expect(result.kind, ChangesetWriteKind.compacted);

    final manifest = SyncManifest.fromBytes(await provider.downloadFile(
      '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
    ));
    expect(manifest.headSeq, manifest.baseSeq, reason: 'fresh base: head == base');

    final files = await provider.listFiles(folderId: folder, namePattern: ChangesetLogLayout.prefix);
    // No changeset files below the new base remain.
    final staleCs = files.where((f) {
      final s = ChangesetLogLayout.changesetSeqOf(f.name);
      return s != null && s < manifest.baseSeq!;
    });
    expect(staleCs, isEmpty, reason: 'superseded changesets pruned');
    // Old base parts pruned (only the new baseSeq's parts remain).
    final staleBaseParts = files.where((f) {
      final b = ChangesetLogLayout.basePartOf(f.name);
      return b != null && b.baseSeq != manifest.baseSeq;
    });
    expect(staleBaseParts, isEmpty, reason: 'old base parts pruned');

    // The new base reflects all three dives.
    expect(manifest.publishedHlcHigh, isNotNull);
  });

  test('does not compact below the threshold', () async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
    await publish(); // base @1
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
    final result = await publish(); // cs @2 (only 1 changeset past base; threshold is 2)
    expect(result.kind, ChangesetWriteKind.changeset);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`compactionMaxChangesets` param and `ChangesetWriteKind.compacted` don't exist).

- [ ] **Step 3: Implement compaction in `ChangesetWriter`**

- Add `compacted` to `ChangesetWriteKind`.
- Add constructor params (after the positional deps):
  ```dart
  ChangesetWriter(
    this._serializer,
    this._codec,
    this._publishState, {
    this.compactionByteRatio = 0.30,
    this.compactionMaxChangesets = 200,
  });
  final double compactionByteRatio;
  final int compactionMaxChangesets;
  ```
- In the changeset branch, after `_publishState.upsert(...)` and before `return ChangesetWriteResult(ChangesetWriteKind.changeset, newSeq);`, evaluate the trigger and compact if tripped:
  ```dart
  final bytesSinceBase = (state?.changesetBytesSinceBase ?? 0) + bytes.length;
  final baseBytes = base.baseBytes ?? 0;
  final tripped =
      (newSeq - (base.baseSeq ?? newSeq)) >= compactionMaxChangesets ||
      (baseBytes > 0 && bytesSinceBase >= compactionByteRatio * baseBytes);
  if (tripped) {
    final compSeq = await _compact(
      provider: provider,
      deviceId: deviceId,
      folderId: folderId,
      providerId: providerId,
      afterSeq: newSeq,
      oldBaseSeq: base.baseSeq!,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );
    return ChangesetWriteResult(ChangesetWriteKind.compacted, compSeq);
  }
  return ChangesetWriteResult(ChangesetWriteKind.changeset, newSeq);
  ```
- Add `_compact` (writes a fresh full base at `afterSeq + 1`, rewrites the manifest, resets publish state, prunes superseded files):
  ```dart
  Future<int> _compact({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
    required String providerId,
    required int afterSeq,
    required int oldBaseSeq,
    String? epochId,
    String? uploadNonce,
  }) async {
    final full = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null, // full snapshot
      deletions: const [],
      epochId: epochId,
      uploadNonce: uploadNonce,
    );
    final fullBytes = _codec.encodeChangeset(full);
    final parts = _codec.encodeBaseParts(full);
    final compSeq = afterSeq + 1;
    for (var i = 0; i < parts.length; i++) {
      await provider.uploadFile(
        parts[i],
        ChangesetLogLayout.basePartName(deviceId, compSeq, i),
        folderId: folderId,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: compSeq,
      basePartCount: parts.length,
      baseBytes: fullBytes.length,
      baseChecksum: BaseChunker.checksum(fullBytes),
      basePartChecksums: parts.map(BaseChunker.checksum).toList(),
      headSeq: compSeq,
      publishedHlcHigh: full.toHlc,
      epochId: epochId,
      uploadNonce: uploadNonce,
      updatedAt: now,
    );
    await _writeManifest(provider, folderId, deviceId, manifest);
    await _publishState.upsert(
      LocalPublishStatesCompanion(
        provider: Value(providerId),
        baseSeq: Value(compSeq),
        basePartCount: Value(parts.length),
        baseBytes: Value(fullBytes.length),
        headSeq: Value(compSeq),
        publishedHlcHigh: Value(full.toHlc),
        changesetBytesSinceBase: const Value(0),
        updatedAt: Value(now),
      ),
    );
    // Prune superseded files (correct: the reader cold-starts from the new
    // base if it was mid-fetch). Delete after the manifest flip.
    await _pruneSupersededBelow(provider, folderId, deviceId, compSeq);
    return compSeq;
  }

  Future<void> _pruneSupersededBelow(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
    int keepBaseSeq,
  ) async {
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    for (final f in files) {
      if (ChangesetLogLayout.deviceIdOf(f.name) != deviceId) continue;
      final cs = ChangesetLogLayout.changesetSeqOf(f.name);
      final bp = ChangesetLogLayout.basePartOf(f.name);
      final supersededCs = cs != null && cs < keepBaseSeq;
      final supersededBase = bp != null && bp.baseSeq != keepBaseSeq;
      if (supersededCs || supersededBase) {
        await provider.deleteFile(f.id);
      }
    }
  }
  ```

- [ ] **Step 4: Run — expect PASS** (compaction test + no-compact-below-threshold). Also re-run the existing `changeset_writer_test.dart` (default threshold 200 → unaffected).
  Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart`

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart
git add -A && git commit -m "feat(sync): add changeset-log compaction (threshold + base rewrite + prune)"
```

---

### Task 2: Reader integrity verification

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Test: `test/core/services/sync/changeset_log/changeset_reader_verify_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/changeset_reader_verify_test.dart
// Publish a peer base+changeset, corrupt the changeset bytes in the fake
// provider, then pull: the reader must NOT apply the corrupt changeset and must
// leave the cursor below it (so a later, fixed sync retries).
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  test('a corrupt changeset is not applied and the cursor stays below it',
      () async {
    await setUpTestDatabase();
    addTearDown(() => DatabaseService.instance.resetForTesting());
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    final codec = ChangesetCodec(serializer);
    final writer = ChangesetWriter(serializer, codec, PublishStateStore(db));
    final reader = ChangesetReader(codec, PeerCursorStore(db));
    final provider = FakeCloudStorageProvider();
    final folder = await provider.getOrCreateSyncFolder();

    final peerId = await SyncRepository().getDeviceId();
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
    await writer.publish(provider: provider, deviceId: peerId, folderId: folder, deletions: const []);
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
    await writer.publish(provider: provider, deviceId: peerId, folderId: folder, deletions: const []);

    // Corrupt the changeset @ seq 2 (overwrite with garbage that still parses
    // as JSON but fails the embedded checksum).
    final csName = ChangesetLogLayout.changesetName(peerId, 2);
    final original = await provider.downloadFile('$folder/$csName');
    final tampered = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
    (tampered['data'] as Map<String, dynamic>)['dives'] = [
      {'id': 'INJECTED'},
    ];
    await provider.uploadFile(
      Uint8List.fromList(utf8.encode(jsonEncode(tampered))),
      csName,
      folderId: folder,
    );

    final applied = <SyncPayload>[];
    await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: (p) async => applied.add(p),
    );

    // The base (seq 1) applied; the corrupt cs (seq 2) did not.
    final ids = applied.expand((p) => p.data.dives.map((d) => d['id'])).toSet();
    expect(ids.contains('INJECTED'), isFalse,
        reason: 'corrupt changeset must be rejected');
    final cursor = await PeerCursorStore(db).get(peerId, provider.providerId);
    expect(cursor!.lastSeqApplied, lessThan(2),
        reason: 'cursor must stay below the corrupt seq so a fixed sync retries');
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (the reader currently applies without verifying the checksum, so `INJECTED` leaks through).

- [ ] **Step 3: Add verification in `ChangesetReader`**

In the changeset loop, after decoding, verify the embedded checksum and stop at a bad one:
```dart
final cs = _codec.decodeChangeset(await provider.downloadFile(csFile.id));
if (!_codec.serializer.validateChecksum(cs)) break; // corrupt -> stop, retry later
await apply(cs);
```
(`ChangesetCodec` already exposes `serializer`.) Do the same for the base after `decodeBaseParts`:
```dart
final base = await _fetchBase(...);
if (base == null || !_codec.serializer.validateChecksum(base)) continue;
```

- [ ] **Step 4: Run — expect PASS** (base applies; corrupt cs rejected; cursor < 2). Re-run `changeset_reader_test.dart` to confirm clean payloads still apply.

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/changeset_reader_verify_test.dart
git add -A && git commit -m "feat(sync): verify changeset/base checksums on read"
```

---

### Phase 5 wrap-up

- [ ] Run the writer (+compaction) and reader (+verify) test files together + `flutter analyze`; confirm green.

Deferred-but-documented optimizations (correctness already holds without them): the **time-based grace window** before pruning, and **cross-restart disk staging** for resuming a half-downloaded base. **Phase 6 (restore + coexistence)** is next, then the `performSync` wiring.
