# Incremental Sync — Phase 3: Write Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone `ChangesetWriter` that publishes this device's local changes to its changeset log on any `CloudStorageProvider` — writing a base on first publish and immutable changesets thereafter, advancing `local_publish_states`, and rewriting the manifest as the commit point. No compaction or resume-after-interruption yet (Phase 5); no `performSync` wiring yet (after Phase 4).

**Architecture:** Composes the pieces from Phases 1–2: `exportChangeset` (base = null watermark, delta = `publishedHlcHigh` watermark), `ChangesetCodec` (encode), `BaseChunker` (checksums), `ChangesetLogLayout` (names), `SyncManifest` (commit point), `PublishStateStore` (own position). The device's **own cloud manifest is the authority**: the writer reads it first so `headSeq` is recovered (never reused) even after local-state loss, and a changeset reuses the manifest's existing base fields (so publish state needn't store base checksums).

**Tech Stack:** Flutter, Drift, `flutter_test`, the Phase 1 `FakeCloudStorageProvider`.

**Phase roadmap:** 1 (foundation) ✅ → 2 (serialization) ✅ → **3 (write path) ← this plan** → 4 (read path) → 5 (resumability + compaction) → 6 (restore + coexistence). After Phase 4, a small integration step swaps `performSync`'s full-file upload+download for writer+reader.

---

### Task 1: `ChangesetWriter` + first-base publish

**Files:**
- Create: `lib/core/services/sync/changeset_log/changeset_writer.dart`
- Test: `test/core/services/sync/changeset_log/changeset_writer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/changeset_writer_test.dart
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
    writer = ChangesetWriter(serializer, ChangesetCodec(serializer),
        PublishStateStore(db));
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

  test('first publish with data writes a base + manifest', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    final result = await publish();
    expect(result.kind, ChangesetWriteKind.base);

    final deviceId = await SyncRepository().getDeviceId();
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final names = files.map((f) => f.name).toList();
    expect(names, contains(ChangesetLogLayout.manifestName(deviceId)));
    expect(names.any((n) => ChangesetLogLayout.basePartOf(n) != null), isTrue);

    final manifestBytes = await provider.downloadFile(
      '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
    );
    final manifest = SyncManifest.fromBytes(manifestBytes);
    expect(manifest.baseSeq, isNotNull);
    expect(manifest.headSeq, manifest.baseSeq);
    expect(manifest.publishedHlcHigh, isNotNull);
    expect(manifest.basePartChecksums, isNotEmpty);
  });

  test('publish with no data is a no-op', () async {
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    expect(files, isEmpty);
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (file/types missing).
  Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart`

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/changeset_writer.dart
import 'package:submersion/core/database/database.dart' show DeletionLogData;
import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

enum ChangesetWriteKind { base, changeset, noop }

class ChangesetWriteResult {
  const ChangesetWriteResult(this.kind, [this.seq]);
  final ChangesetWriteKind kind;
  final int? seq;
}

/// Publishes this device's local changes to its per-device changeset log.
class ChangesetWriter {
  ChangesetWriter(this._serializer, this._codec, this._publishState);

  final SyncDataSerializer _serializer;
  final ChangesetCodec _codec;
  final PublishStateStore _publishState;

  Future<ChangesetWriteResult> publish({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
    required List<DeletionLogData> deletions,
    String? epochId,
    String? uploadNonce,
  }) async {
    final providerId = provider.providerId;
    final ownManifest = await _readOwnManifest(provider, folderId, deviceId);
    final state = await _publishState.get(providerId);

    final knownHeadSeq = _max(state?.headSeq ?? 0, ownManifest?.headSeq ?? 0);
    final hasBase = ownManifest?.baseSeq != null || state?.baseSeq != null;
    final watermark = ownManifest?.publishedHlcHigh ?? state?.publishedHlcHigh;

    final payload = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: hasBase ? watermark : null,
      deletions: deletions,
      seq: knownHeadSeq + 1,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );

    if (_isEmpty(payload)) {
      return const ChangesetWriteResult(ChangesetWriteKind.noop);
    }

    final newSeq = knownHeadSeq + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!hasBase) {
      final fullBytes = _codec.encodeChangeset(payload);
      final parts = _codec.encodeBaseParts(payload);
      for (var i = 0; i < parts.length; i++) {
        await provider.uploadFile(
          parts[i],
          ChangesetLogLayout.basePartName(deviceId, newSeq, i),
          folderId: folderId,
        );
      }
      final manifest = SyncManifest(
        deviceId: deviceId,
        provider: providerId,
        baseSeq: newSeq,
        basePartCount: parts.length,
        baseBytes: fullBytes.length,
        baseChecksum: BaseChunker.checksum(fullBytes),
        basePartChecksums: parts.map(BaseChunker.checksum).toList(),
        headSeq: newSeq,
        publishedHlcHigh: payload.toHlc,
        epochId: epochId,
        uploadNonce: uploadNonce,
        updatedAt: now,
      );
      await _writeManifest(provider, folderId, deviceId, manifest);
      await _publishState.upsert(
        LocalPublishStatesCompanion(
          provider: Value(providerId),
          baseSeq: Value(newSeq),
          basePartCount: Value(parts.length),
          baseBytes: Value(fullBytes.length),
          headSeq: Value(newSeq),
          publishedHlcHigh: Value(payload.toHlc),
          changesetBytesSinceBase: const Value(0),
          updatedAt: Value(now),
        ),
      );
      return ChangesetWriteResult(ChangesetWriteKind.base, newSeq);
    }

    // Changeset: reuse the existing base fields from the (authoritative) own
    // manifest; only headSeq / publishedHlcHigh advance.
    final bytes = _codec.encodeChangeset(payload);
    await provider.uploadFile(
      bytes,
      ChangesetLogLayout.changesetName(deviceId, newSeq),
      folderId: folderId,
    );
    final base = ownManifest!;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: base.baseSeq,
      basePartCount: base.basePartCount,
      baseBytes: base.baseBytes,
      baseChecksum: base.baseChecksum,
      basePartChecksums: base.basePartChecksums,
      headSeq: newSeq,
      publishedHlcHigh: payload.toHlc ?? base.publishedHlcHigh,
      epochId: epochId,
      uploadNonce: uploadNonce,
      updatedAt: now,
    );
    await _writeManifest(provider, folderId, deviceId, manifest);
    await _publishState.upsert(
      LocalPublishStatesCompanion(
        provider: Value(providerId),
        baseSeq: Value(base.baseSeq),
        basePartCount: Value(base.basePartCount),
        baseBytes: Value(base.baseBytes),
        headSeq: Value(newSeq),
        publishedHlcHigh: Value(payload.toHlc ?? base.publishedHlcHigh),
        changesetBytesSinceBase: Value(
          (state?.changesetBytesSinceBase ?? 0) + bytes.length,
        ),
        updatedAt: Value(now),
      ),
    );
    return ChangesetWriteResult(ChangesetWriteKind.changeset, newSeq);
  }

  Future<void> _writeManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
    SyncManifest manifest,
  ) async {
    // Manifest LAST: data files are uploaded above before it references them.
    await provider.uploadFile(
      manifest.toBytes(),
      ChangesetLogLayout.manifestName(deviceId),
      folderId: folderId,
    );
  }

  Future<SyncManifest?> _readOwnManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
  ) async {
    final name = ChangesetLogLayout.manifestName(deviceId);
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final own = files.where((f) => f.name == name).firstOrNull;
    if (own == null) return null;
    try {
      return SyncManifest.fromBytes(await provider.downloadFile(own.id));
    } catch (_) {
      return null;
    }
  }

  bool _isEmpty(SyncPayload payload) {
    final dataEmpty = payload.data.toJson().values.every(
      (v) => v is! List || v.isEmpty,
    );
    final deletionsEmpty = payload.deletions.values.every((l) => l.isEmpty);
    return dataEmpty && deletionsEmpty;
  }

  int _max(int a, int b) => a > b ? a : b;
}
```

> NOTE: confirm `SyncRepository.getAllDeletions()` returns `List<DeletionLogData>` (it is used that way at `sync_service.dart:518`). `firstOrNull` comes from `package:collection` or Dart 3 — if unavailable, use `.where(...).cast<CloudFileInfo?>().firstWhere((_) => true, orElse: () => null)` or a manual loop.

- [ ] **Step 4: Run it — expect PASS** (base written; no-op when empty).

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_writer_test.dart
git add -A && git commit -m "feat(sync): add ChangesetWriter base publish"
```

---

### Task 2: Changeset publish (subsequent deltas)

**Files:**
- Modify (test only): `test/core/services/sync/changeset_log/changeset_writer_test.dart`

The implementation from Task 1 already covers the changeset path; this task proves it.

- [ ] **Step 1: Add the failing test**

```dart
  test('second publish writes a changeset with only the new dive', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(); // base

    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final result = await publish(); // changeset
    expect(result.kind, ChangesetWriteKind.changeset);

    final deviceId = await SyncRepository().getDeviceId();
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final csNames =
        files.map((f) => f.name).where((n) => ChangesetLogLayout.changesetSeqOf(n) != null);
    expect(csNames, isNotEmpty);

    // The changeset contains only d2.
    final csName = csNames.first;
    final csFile = files.firstWhere((f) => f.name == csName);
    final payload = ChangesetCodec(SyncDataSerializer())
        .decodeChangeset(await provider.downloadFile(csFile.id));
    final diveIds = payload.data.dives.map((d) => d['id']).toSet();
    expect(diveIds.contains('d2'), isTrue);
    expect(diveIds.contains('d1'), isFalse);

    final manifest = SyncManifest.fromBytes(await provider.downloadFile(
      '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
    ));
    expect(manifest.headSeq, greaterThan(manifest.baseSeq!));
  });
```

- [ ] **Step 2: Run it — expect PASS** (the Task 1 implementation handles this).
- [ ] **Step 3: commit**

```bash
flutter analyze && dart format test/core/services/sync/changeset_log/changeset_writer_test.dart
git add -A && git commit -m "test(sync): cover ChangesetWriter changeset publish"
```

---

### Task 3: Empty no-op after base, and manifest-authority recovery

**Files:**
- Modify (test only): `test/core/services/sync/changeset_log/changeset_writer_test.dart`

- [ ] **Step 1: Add the failing tests**

```dart
  test('publish after base with no new changes is a no-op', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(); // base
    final before = (await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    )).length;

    final result = await publish(); // nothing changed
    expect(result.kind, ChangesetWriteKind.noop);
    final after = (await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    )).length;
    expect(after, before, reason: 'a no-op writes no new file');
  });

  test('lost local publish state recovers headSeq from the cloud manifest',
      () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(); // base @ seq 1
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    await publish(); // changeset @ seq 2

    // Simulate local-state loss (e.g. a restore wiped local_publish_states).
    await PublishStateStore(DatabaseService.instance.database)
        .resetForProvider(provider.providerId);

    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.changeset);
    expect(result.seq, 3, reason: 'seq must continue from the cloud manifest, not reset');
  });
```

- [ ] **Step 2: Run — expect PASS** (the writer reads the own manifest first, so headSeq is recovered).

> If the recovery test fails because the watermark also reset (re-sending d1/d2), that's acceptable for Phase 3 (idempotent on the reader side) — but `result.seq` must still be 3. The key invariant under test is **no seq reuse**.

- [ ] **Step 3: analyze, format, commit**

```bash
flutter analyze && dart format test/core/services/sync/changeset_log/changeset_writer_test.dart
git add -A && git commit -m "test(sync): ChangesetWriter no-op and manifest-authority seq recovery"
```

---

### Phase 3 wrap-up

- [ ] Run `test/core/services/sync/changeset_log/changeset_writer_test.dart` + `flutter analyze`; confirm green.

A device can now publish a base then incremental changesets to any backend, with crash-safe seq recovery from its own manifest. **Phase 4 (read path)** adds `ChangesetReader` (peer discovery, fetch decision, apply via the existing merge, cursor advance), after which a small step wires writer+reader into `performSync`.
