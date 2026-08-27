# Incremental Sync — Phase 4: Read Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone `ChangesetReader` that consumes peers' changeset logs — discover peers, decide per-peer what to fetch against `sync_peer_cursors`, download base/changesets, apply them in seq order through an **injected** merge callback, and advance the cursor. No resumable staging/checksum verification yet (Phase 5); no `performSync` wiring yet (next, once both writer and reader exist).

**Architecture:** Mirror of Phase 3. The reader composes `ChangesetLogLayout` (peer discovery + names), `SyncManifest` (peer head/base), `ChangesetCodec` (decode), and `PeerCursorStore` (progress). The merge is injected as `ApplyPayload = Future<void> Function(SyncPayload)` so the existing `_applyRemotePayload` stays the only merge implementation. Fetch decision per peer:
- `lastApplied >= headSeq` → nothing (up to date).
- `baseSeq != null && lastApplied < baseSeq` → cold-start/lapped: fetch base, then `cs (baseSeq+1 … headSeq]`.
- else → steady-state: `cs (lastApplied+1 … headSeq]`.
Stop at the first missing changeset/part (transient gap or eventual-consistency lag); apply what's contiguous; advance the cursor only to what was applied; retry next sync (idempotent).

**Tech Stack:** Flutter, Drift, `flutter_test`, Phase 1 `FakeCloudStorageProvider`, Phase 3 `ChangesetWriter` (to author peer data in tests).

**Phase roadmap:** 1 ✅ 2 ✅ 3 ✅ → **4 (read path) ← this plan** → 5 (resumability + compaction) → 6 (restore + coexistence) → wire writer+reader into `performSync`.

---

### Task 1: `ChangesetReader`

**Files:**
- Create: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Test: `test/core/services/sync/changeset_log/changeset_reader_test.dart`

- [ ] **Step 1: Write the failing tests** (see the full test file in Step 3 of execution — covers cold-start order+cursor, up-to-date no-op, steady-state only-new, and own-file skipping).

- [ ] **Step 2: Run — expect FAIL** (file missing).
  Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_test.dart`

- [ ] **Step 3: Implement `ChangesetReader`** (see `lib/.../changeset_reader.dart` below): list folder once, build a name→file map, derive peer ids excluding self, and for each peer read its manifest, compute the fetch range vs. the cursor, download+decode base/changesets, `apply` each in order, and `PeerCursorStore.upsert` to the applied seq. Wrap each peer body in try/catch so one bad peer never blocks others.

- [ ] **Step 4: Run — expect PASS** (4 tests).

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/changeset_reader_test.dart
git add -A && git commit -m "feat(sync): add ChangesetReader (peer discovery, fetch decision, cursor advance)"
```

---

### Phase 4 wrap-up

- [ ] Run the reader test + `flutter analyze`; confirm green.

After this, both halves of the transport exist as tested units. The **next step** (its own small plan) wires `ChangesetWriter` + `ChangesetReader` into `SyncService.performSync`, passing `_applyRemotePayload` as the reader's `apply` and replacing the legacy full-file upload/download — at which point two real devices converge end-to-end. Phases 5 (resumability + compaction) and 6 (restore + coexistence) harden it.
