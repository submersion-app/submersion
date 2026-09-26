# Scoped Event Tombstones and Safety Findings Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop minting one tombstone per child row: diff safety findings instead of replacing them, and replace per-event tombstones with one scoped tombstone per dive (or per dive and computer).

**Architecture:** The findings diff matches stored rows by natural key and gives new findings deterministic uuid-v5 ids. The scoped tombstone is a synthetic entity type, `diveProfileEventsScope`, in the existing `deletion_log`; a dedicated applier expands it on receipt, a merge guard stops stale events reviving, and the compat floor rises to the new schema rung so older readers never receive one.

**Tech Stack:** Flutter, Dart, Drift (SQLite), the in-repo changeset sync (`lib/core/services/sync/`), `uuid` ^4.5.

**Spec:** `docs/superpowers/specs/2026-09-26-scoped-tombstones-and-findings-diff-design.md`

## Global Constraints

- Schema rung: **v233** (main is at 231; open PRs #2411, #2407 and #2331 all claim 232). Re-scan open PRs for `currentSchemaVersion` right before pushing and renumber upward if 233 is taken.
- `minimumCompatibleSchemaVersion`: **224 -> 233**.
- Scope entity type string: `diveProfileEventsScope`. recordId `<diveId>` or `<diveId>|<computerId>`.
- Safety finding id namespace (never change once shipped): `kSafetyFindingNamespace = '4d0c8a52-6b1e-4f3a-9a27-c5e1d7b3f906'`.
- No em-dashes anywhere (code, comments, commits, PR). No mention of Claude or Anthropic in any commit or PR text.
- Paths built with `p.join`, never string concatenation.
- Run `dart format .` before each commit; `flutter analyze` must report zero issues (infos are fatal in CI).
- A fresh worktree needs `bash scripts/setup.sh` (codegen) before any test compiles.

## Review Focus

1. **A finding whose `rule_id` this build does not know** (written by a newer peer) must survive a recompute here. The diff must never delete or tombstone it. Pinned in Task 2.
2. **Replacement events written by an emitter must be stamped** (`markRecordPending`) after the scope tombstone, so their `hlc` is newer; otherwise a peer's `createdAt` fallback could delete them. Pinned per emitter in Task 7.
3. **A scope naming a computer must not touch other computers' events** on the same dive, nor events with a null `computer_id`. Pinned in Task 5.
4. **A locally pending event** (edited here, not yet published) must survive a peer's scope tombstone. Pinned in Task 5.
5. **A dive whose review marker was dropped** must show no finding badge in the dive list, even though its findings rows still exist. Pinned in Task 3.

---

### Task 1: Deterministic safety finding identity

**Files:**
- Create: `lib/features/dive_log/domain/services/safety_finding_identity.dart`
- Modify: `lib/features/dive_log/domain/services/safety_review_service.dart` (the `review` method, lines ~25-42)
- Test: `test/features/dive_log/domain/services/safety_finding_identity_test.dart`

**Interfaces:**
- Produces:
  - `typedef SafetyFindingKey = (String ruleId, int? start, int? end, int ordinal);`
  - `List<SafetyFindingKey> safetyFindingKeys(Iterable<({String ruleId, int? start, int? end})> spans)`
  - `String safetyFindingId(String diveId, SafetyFindingKey key)`
  - `List<SafetyFinding> withDeterministicIds(String diveId, List<SafetyFinding> findings)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_finding_identity.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26);
  SafetyFinding f(String id, {int? start = 100, int? end = 140}) =>
      SafetyFinding(
        id: id,
        diveId: 'dive-1',
        ruleId: SafetyRuleId.rapidAscent,
        severity: SafetySeverity.caution,
        startTimestamp: start,
        endTimestamp: end,
        value: 12,
        engineVersion: 2,
        createdAt: now,
      );

  test('keys number repeats of the same span in order', () {
    final keys = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2),
      (ruleId: 'a', start: 1, end: 2),
      (ruleId: 'a', start: 3, end: 4),
    ]);
    expect(keys, [('a', 1, 2, 0), ('a', 1, 2, 1), ('a', 3, 4, 0)]);
  });

  test('the same finding gets the same id on every device', () {
    final a = withDeterministicIds('dive-1', [f('x')]);
    final b = withDeterministicIds('dive-1', [f('y')]);
    expect(a.single.id, b.single.id);
    expect(a.single.id, isNot('x'));
  });

  test('different dives, spans and repeats get different ids', () {
    final ids = {
      safetyFindingId('dive-1', ('rapidAscent', 100, 140, 0)),
      safetyFindingId('dive-2', ('rapidAscent', 100, 140, 0)),
      safetyFindingId('dive-1', ('rapidAscent', 100, 141, 0)),
      safetyFindingId('dive-1', ('rapidAscent', 100, 140, 1)),
      safetyFindingId('dive-1', ('rapidAscent', null, null, 0)),
    };
    expect(ids, hasLength(5));
  });
}
```

Also add to the existing `test/features/dive_log/domain/services/safety_review_service_test.dart` (find the file with `ls test/features/dive_log/domain/services | grep safety`): a test that calls `const SafetyReviewService().review(...)` twice on the same analysis with no `idGenerator` and asserts the two id lists are equal.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/safety_finding_identity_test.dart`
Expected: FAIL, `safety_finding_identity.dart` not found.

- [ ] **Step 3: Implement**

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Fixed namespace for deterministic safety finding ids (UUIDv5). Never
/// change: a stored id minted under it must keep matching.
const String kSafetyFindingNamespace = '4d0c8a52-6b1e-4f3a-9a27-c5e1d7b3f906';

/// What makes two findings of one dive the same finding: the rule, the span
/// and the finding's position among findings sharing that rule and span.
typedef SafetyFindingKey = (String ruleId, int? start, int? end, int ordinal);

/// Keys for [spans] in order. The ordinal counts earlier entries with the
/// same rule and span, so repeats never collapse into one key.
List<SafetyFindingKey> safetyFindingKeys(
  Iterable<({String ruleId, int? start, int? end})> spans,
) {
  final seen = <(String, int?, int?), int>{};
  return [
    for (final s in spans)
      (
        s.ruleId,
        s.start,
        s.end,
        seen.update(
          (s.ruleId, s.start, s.end),
          (n) => n + 1,
          ifAbsent: () => 0,
        ),
      ),
  ];
}

/// Deterministic id: two devices reviewing the same dive mint the same id
/// for the same finding and converge under sync instead of duplicating.
String safetyFindingId(String diveId, SafetyFindingKey key) => const Uuid().v5(
  kSafetyFindingNamespace,
  '$diveId|${key.$1}|${key.$2 ?? ''}|${key.$3 ?? ''}|${key.$4}',
);

/// [findings] with their ids replaced by [safetyFindingId].
List<SafetyFinding> withDeterministicIds(
  String diveId,
  List<SafetyFinding> findings,
) {
  final keys = safetyFindingKeys([
    for (final f in findings)
      (ruleId: f.ruleId.dbValue, start: f.startTimestamp, end: f.endTimestamp),
  ]);
  return [
    for (var i = 0; i < findings.length; i++)
      findings[i].copyWith(id: safetyFindingId(diveId, keys[i])),
  ];
}
```

In `SafetyReviewService.review`, change the default id source and post-process:

```dart
    // Deterministic by default (see withDeterministicIds); a caller-supplied
    // generator is kept verbatim for tests that pin ids.
    final nextId = idGenerator ?? () => '';
    final findings = <SafetyFinding>[];
    // ... the five addAll calls, unchanged ...
    return idGenerator == null
        ? withDeterministicIds(diveId, findings)
        : findings;
```

Remove the now-unused `uuid` import from the service if analyze reports it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/services/safety_finding_identity.dart lib/features/dive_log/domain/services/safety_review_service.dart test/features/dive_log/domain/services/
git commit -m "feat(safety): give safety findings deterministic ids"
```

---

### Task 2: Diff findings in `saveReview`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/safety_findings_repository.dart` (`saveReview`, lines 49-113; class doc lines 9-14)
- Modify: `lib/features/dive_log/presentation/providers/safety_review_providers.dart` (lines ~48-60)
- Test: `test/features/dive_log/data/repositories/safety_findings_repository_test.dart`

**Interfaces:**
- Consumes: `safetyFindingKeys`, from Task 1.
- Produces: `Future<SafetyReview> saveReview(SafetyReview review)`. It now returns the persisted review: stored ids, dismissals and creation times.

- [ ] **Step 1: Write the failing tests** (add to the repository test file; replace the two tests named below)

Replace `'saveReview replaces prior findings'` with:

```dart
  test('a recompute that reaches the same findings mints nothing', () async {
    await repo.saveReview(
      SafetyReview(diveId: 'dive-1', engineVersion: 1, reviewedAt: now,
          findings: [finding('f1')]),
    );
    await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);

    final saved = await repo.saveReview(
      SafetyReview(diveId: 'dive-1', engineVersion: 2, reviewedAt: now,
          findings: [finding('f-new-random-id')]),
    );

    expect(saved.findings.single.id, 'f1', reason: 'the stored id is kept');
    expect(saved.findings.single.isDismissed, isTrue);
    final review = await repo.getReview('dive-1');
    expect(review!.findings.single.id, 'f1');
    expect(review.findings.single.isDismissed, isTrue);
    expect(review.findings.single.engineVersion, 1,
        reason: 'finding() builds engineVersion 1 both times: nothing changed');
    expect(
      (await db.select(db.deletionLog).get())
          .where((t) => t.entityType == 'diveSafetyFindings'),
      isEmpty,
    );
  });

  test('a changed severity updates in place and keeps the dismissal',
      () async {
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));
    await repo.setDismissed(findingId: 'f1', dismissed: true, now: now);
    await syncRepository.clearAllSyncRecords();

    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 2,
        reviewedAt: now, findings: [
          finding('other').copyWith(severity: SafetySeverity.significant),
        ]));

    final f = (await repo.getReview('dive-1'))!.findings.single;
    expect(f.id, 'f1');
    expect(f.severity, SafetySeverity.significant);
    expect(f.isDismissed, isTrue);
    final pending = await syncRepository.getPendingRecords();
    expect(pending.where((r) => r.entityType == 'diveSafetyFindings')
        .map((r) => r.recordId), ['f1']);
  });

  test('a finding that stops firing is deleted with one tombstone', () async {
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [
          finding('f1'),
          finding('f2', rule: SafetyRuleId.sawtoothProfile),
        ]));
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 2,
        reviewedAt: now, findings: [finding('x')]));

    expect((await repo.getReview('dive-1'))!.findings.map((f) => f.id), ['f1']);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => (t.entityType, t.recordId)),
        [('diveSafetyFindings', 'f2')]);
  });

  test('a finding that fires again clears its old tombstone', () async {
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: const []));
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));

    expect((await repo.getReview('dive-1'))!.findings.single.id, 'f1');
    expect(
      (await db.select(db.deletionLog).get())
          .where((t) => t.recordId == 'f1'),
      isEmpty,
    );
  });

  test('a finding from a rule this build does not know survives', () async {
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));
    await db.into(db.diveSafetyFindings).insert(
      DiveSafetyFindingsCompanion.insert(
        id: 'f-future', diveId: 'dive-1', ruleId: 'someFutureRule',
        severity: 'caution', engineVersion: 9,
        createdAt: now.millisecondsSinceEpoch,
      ),
    );

    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 2,
        reviewedAt: now, findings: const []));

    final ids = (await db.select(db.diveSafetyFindings).get()).map((r) => r.id);
    expect(ids, ['f-future']);
    expect(
      (await db.select(db.deletionLog).get())
          .where((t) => t.recordId == 'f-future'),
      isEmpty,
    );
  });
```

Replace `'saveReview advances the parent dive HLC so the review syncs'` with:

```dart
  test('a saved review exports without re-stamping the dive', () async {
    // Both safety tables export their pending rows on their own (#1769);
    // re-stamping the dive would let this device's stale dive row beat a
    // peer's newer edit.
    await syncRepository.markRecordPending(entityType: 'dives',
        recordId: 'dive-1', localUpdatedAt: now.millisecondsSinceEpoch);
    Future<String?> diveHlc() async => (await db
            .customSelect("SELECT hlc FROM dives WHERE id = 'dive-1'")
            .getSingle())
        .read<String?>('hlc');
    final watermark = await diveHlc();

    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));

    expect(await diveHlc(), watermark);
    final after = await SyncDataSerializer().exportChangeset(
      deviceId: await syncRepository.getDeviceId(),
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(after.data.diveSafetyReviews, isNotEmpty);
    expect(after.data.diveSafetyFindings.map((f) => f['id']), contains('f1'));
  });
```

If `getPendingRecords` is not the pending-read method's name, find it with `grep -n "Future<List<SyncRecord>>" lib/core/data/repositories/sync_repository.dart` and use that.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart`
Expected: the new tests FAIL (ids replaced, tombstones minted, dive hlc advanced).

- [ ] **Step 3: Implement `saveReview`**

```dart
  /// Saves [review] by diffing it against the stored findings, and returns
  /// what is now stored.
  ///
  /// A computed finding with the same key as a stored one (rule, span,
  /// ordinal; see [safetyFindingKeys]) is the same finding: it keeps its id,
  /// dismissal and creation time, and is written only when its severity,
  /// value or engine version changed. So a recompute that reaches the same
  /// findings writes no finding row and mints no tombstone (#1926). Stored
  /// rows that no longer fire are deleted and tombstoned; rows whose rule
  /// this build does not know came from a newer peer and are never touched.
  Future<SafetyReview> saveReview(SafetyReview review) async {
    final reviewedAtMs = review.reviewedAt.millisecondsSinceEpoch;
    final persisted = <SafetyFinding>[];
    await _db.transaction(() async {
      final stored = await (_db.select(_db.diveSafetyFindings)
            ..where((t) => t.diveId.equals(review.diveId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.startTimestamp),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();
      final known = [
        for (final row in stored)
          if (SafetyRuleId.fromDbValue(row.ruleId) != null) row,
      ];
      final storedKeys = safetyFindingKeys([
        for (final r in known)
          (ruleId: r.ruleId, start: r.startTimestamp, end: r.endTimestamp),
      ]);
      final storedByKey = {
        for (var i = 0; i < known.length; i++) storedKeys[i]: known[i],
      };
      final computedKeys = safetyFindingKeys([
        for (final f in review.findings)
          (ruleId: f.ruleId.dbValue, start: f.startTimestamp,
              end: f.endTimestamp),
      ]);

      final matched = <String>{};
      final updates = <(DiveSafetyFinding, SafetyFinding)>[];
      final inserts = <SafetyFinding>[];
      for (var i = 0; i < review.findings.length; i++) {
        final computed = review.findings[i];
        final old = storedByKey[computedKeys[i]];
        if (old == null) {
          inserts.add(computed);
          persisted.add(computed);
          continue;
        }
        matched.add(old.id);
        persisted.add(SafetyFinding(
          id: old.id,
          diveId: review.diveId,
          ruleId: computed.ruleId,
          severity: computed.severity,
          startTimestamp: computed.startTimestamp,
          endTimestamp: computed.endTimestamp,
          value: computed.value,
          engineVersion: computed.engineVersion,
          dismissedAt: old.dismissedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(old.dismissedAt!),
          createdAt: DateTime.fromMillisecondsSinceEpoch(old.createdAt),
        ));
        if (old.severity != computed.severity.dbValue ||
            old.value != computed.value ||
            old.engineVersion != computed.engineVersion) {
          updates.add((old, computed));
        }
      }

      // Deletes first, so an insert can never meet a row about to go.
      final gone = [
        for (final r in known)
          if (!matched.contains(r.id)) r.id,
      ];
      if (gone.isNotEmpty) {
        await (_db.delete(_db.diveSafetyFindings)
              ..where((t) => t.id.isIn(gone)))
            .go();
        await _syncRepository.logDeletions(
          entityType: 'diveSafetyFindings',
          recordIds: gone,
        );
      }

      for (final (old, computed) in updates) {
        await (_db.update(_db.diveSafetyFindings)
              ..where((t) => t.id.equals(old.id)))
            .write(DiveSafetyFindingsCompanion(
          severity: Value(computed.severity.dbValue),
          value: Value(computed.value),
          engineVersion: Value(computed.engineVersion),
        ));
        await _syncRepository.markRecordPending(
          entityType: 'diveSafetyFindings',
          recordId: old.id,
          localUpdatedAt: reviewedAtMs,
        );
      }

      for (final finding in inserts) {
        await _db.into(_db.diveSafetyFindings).insert(
          DiveSafetyFindingsCompanion.insert(
            id: finding.id,
            diveId: review.diveId,
            ruleId: finding.ruleId.dbValue,
            severity: finding.severity.dbValue,
            startTimestamp: Value(finding.startTimestamp),
            endTimestamp: Value(finding.endTimestamp),
            value: Value(finding.value),
            engineVersion: finding.engineVersion,
            dismissedAt: Value(finding.dismissedAt?.millisecondsSinceEpoch),
            createdAt: finding.createdAt.millisecondsSinceEpoch,
          ),
        );
        // Ids are deterministic, so a finding that stopped firing (and was
        // tombstoned) returns under the same id. Left in place, that
        // tombstone would ride the next changeset beside the row and delete
        // it on every peer.
        await _syncRepository.removeDeletion(
          entityType: 'diveSafetyFindings',
          recordId: finding.id,
        );
        await _syncRepository.markRecordPending(
          entityType: 'diveSafetyFindings',
          recordId: finding.id,
          localUpdatedAt: finding.createdAt.millisecondsSinceEpoch,
        );
      }

      await _db.into(_db.diveSafetyReviews).insertOnConflictUpdate(
        DiveSafetyReviewsCompanion.insert(
          diveId: review.diveId,
          engineVersion: review.engineVersion,
          reviewedAt: reviewedAtMs,
        ),
      );
      // A profile edit tombstones the marker (clearReviewForDive); the
      // recompute brings it back under the same key.
      await _syncRepository.removeDeletion(
        entityType: 'diveSafetyReviews',
        recordId: review.diveId,
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveSafetyReviews',
        recordId: review.diveId,
        localUpdatedAt: reviewedAtMs,
      );
      // No parent-dive bump: both safety tables export their pending rows
      // on their own (SyncDataSerializer.parentGatedChildEntities), and
      // re-stamping the dive for a child-only change lets this device's
      // stale dive row beat a peer's newer edit (#1769).
    });
    SyncEventBus.notifyLocalChange();
    return SafetyReview(
      diveId: review.diveId,
      engineVersion: review.engineVersion,
      reviewedAt: review.reviewedAt,
      findings: persisted,
    );
  }
```

Add `import 'package:submersion/features/dive_log/domain/services/safety_finding_identity.dart';`. Update the class doc comment (lines 9-14): findings are diffed, and writes mark the row itself pending rather than the dive.

In `safetyReviewProvider`, replace the tail:

```dart
  final now = DateTime.now();
  // Return what was stored, not the engine's raw output: a kept finding
  // keeps its stored id and dismissal, and a dismiss must address that id.
  return repo.saveReview(
    SafetyReview(
      diveId: diveId,
      engineVersion: SafetyReviewService.engineVersion,
      reviewedAt: now,
      findings: const SafetyReviewService().review(
        diveId: diveId,
        analysis: analysis,
        now: now,
      ),
    ),
  );
```

Check other `saveReview` callers compile: `grep -rn "saveReview(" lib test | grep -v equipment`. The safety review sweep may call it and ignore the result, which is fine.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart test/features/dive_log/presentation/providers/`
Expected: PASS. If a provider test asserted the engine's ids, update it to read ids back through `getReview`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/safety_findings_repository.dart lib/features/dive_log/presentation/providers/safety_review_providers.dart test/features/dive_log/
git commit -m "fix(safety): diff findings on recompute instead of replacing them"
```

---

### Task 3: Keep findings on profile change; gate the badge on the marker

**Files:**
- Modify: `lib/features/dive_log/data/repositories/safety_findings_repository.dart` (`clearReviewForDive`, lines ~238-264)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (the two `safety_finding_count` subqueries, near lines 2214 and 2863, and their `readsFrom` sets)
- Test: `test/features/dive_log/data/repositories/safety_findings_repository_test.dart`, `test/features/dive_log/data/repositories/dive_summary_safety_badge_test.dart`

**Interfaces:**
- Consumes: `saveReview` from Task 2.
- Produces: `clearReviewForDive` keeps its signature; it now tombstones only the marker.

- [ ] **Step 1: Write the failing tests**

Replace `'clearReviewForDive removes marker and findings with tombstones'` with:

```dart
  test('clearReviewForDive drops only the marker', () async {
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('f1')]));
    await SafetyFindingsRepository.clearReviewForDive(
        db, syncRepository, 'dive-1');

    expect(await repo.getReview('dive-1'), isNull);
    expect((await db.select(db.diveSafetyFindings).get()).map((r) => r.id),
        ['f1'], reason: 'kept so the recompute can diff against it');
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => (t.entityType, t.recordId)),
        [('diveSafetyReviews', 'dive-1')]);

    // The recompute reaches the same finding: nothing new is tombstoned,
    // and the marker's tombstone is cleared.
    await repo.saveReview(SafetyReview(diveId: 'dive-1', engineVersion: 1,
        reviewedAt: now, findings: [finding('x')]));
    expect(await db.select(db.deletionLog).get(), isEmpty);
    expect((await repo.getReview('dive-1'))!.findings.single.id, 'f1');
  });
```

In `dive_summary_safety_badge_test.dart`, add a test modelled on the file's existing badge test: save a review with one finding, call `SafetyFindingsRepository.clearReviewForDive`, then read the dive summary the same way the existing tests do and expect `safetyFindingCount` to be 0.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/safety_findings_repository_test.dart test/features/dive_log/data/repositories/dive_summary_safety_badge_test.dart`
Expected: FAIL (findings deleted and tombstoned; the badge still counts them once kept).

- [ ] **Step 3: Implement**

```dart
  /// Invalidation hook for profile writes: drops the review marker so the
  /// next view recomputes against the new profile. The findings rows stay,
  /// so that recompute diffs against them and a re-import reaching the same
  /// findings mints no tombstones (#1926). Readers gate on the marker:
  /// [getReview] returns null without one, and the dive list's badge counts
  /// only dives that have one. Static so both dive repositories can call it
  /// without holding a SafetyFindingsRepository.
  static Future<void> clearReviewForDive(
    AppDatabase db,
    SyncRepository sync,
    String diveId,
  ) async {
    final deletedMarker = await (db.delete(
      db.diveSafetyReviews,
    )..where((t) => t.diveId.equals(diveId))).go();
    if (deletedMarker > 0) {
      await sync.logDeletion(entityType: 'diveSafetyReviews', recordId: diveId);
    }
  }
```

In both badge subqueries of `dive_repository_impl.dart`, change

```dart
            'WHERE sf.dive_id = d.id AND sf.dismissed_at IS NULL'
```

to

```dart
            'WHERE sf.dive_id = d.id AND sf.dismissed_at IS NULL '
            // A dive whose review was invalidated (clearReviewForDive keeps
            // its findings for the next diff) shows no badge until it is
            // recomputed.
            'AND EXISTS (SELECT 1 FROM dive_safety_reviews sr '
            'WHERE sr.dive_id = d.id)'
```

and add `_db.diveSafetyReviews,` beside `_db.diveSafetyFindings,` in each `readsFrom` set.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/ test/features/dive_log/data/repositories/
git commit -m "fix(safety): keep findings when a profile change invalidates the review"
```

---

### Task 4: The scope tombstone type and its repository calls

**Files:**
- Create: `lib/core/services/sync/event_scope_tombstone.dart`
- Modify: `lib/core/data/repositories/sync_repository.dart` (after `logDeletions`, ~line 1368)
- Test: `test/core/services/sync/event_scope_tombstone_test.dart`, `test/core/data/repositories/sync_repository_scoped_deletion_test.dart`

**Interfaces:**
- Produces:
  - `class EventScopeTombstone { static const entityType = 'diveProfileEventsScope'; final String diveId; final String? computerId; String encode(); static EventScopeTombstone? tryDecode(String recordId); }`
  - `bool eventPredatesScopeDelete({Hlc? rowHlc, required int rowCreatedAt, Hlc? deleteHlc, required int deletedAt})`
  - `Hlc? tryParseHlc(Object? raw)`
  - `class EventScopeCoverage { factory EventScopeCoverage.from({required Map<String, int> deletedAt, required Map<String, Hlc> clocks}); bool get isEmpty; bool covers(Map<String, dynamic> eventRecord); }`
  - `SyncRepository.logScopedDeletion(EventScopeTombstone scope)`
  - `SyncRepository.relayScopedDeletion({required String recordId, required int deletedAt, String? originHlc})`

- [ ] **Step 1: Write the failing tests**

`event_scope_tombstone_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('encodes and decodes both scopes', () {
    const dive = EventScopeTombstone(diveId: 'd1');
    const computer = EventScopeTombstone(diveId: 'd1', computerId: 'c1');
    expect(dive.encode(), 'd1');
    expect(computer.encode(), 'd1|c1');
    expect(EventScopeTombstone.tryDecode('d1')!.computerId, isNull);
    expect(EventScopeTombstone.tryDecode('d1|c1')!.computerId, 'c1');
  });

  test('rejects malformed ids', () {
    for (final bad in ['', '|c1', 'd1|', 'a|b|c']) {
      expect(EventScopeTombstone.tryDecode(bad), isNull, reason: bad);
    }
  });

  group('eventPredatesScopeDelete', () {
    final h = Hlc(1000, 0, 'a');
    test('compares clocks when both exist', () {
      expect(eventPredatesScopeDelete(rowHlc: Hlc(999, 0, 'b'),
          rowCreatedAt: 5000, deleteHlc: h, deletedAt: 1), isTrue);
      expect(eventPredatesScopeDelete(rowHlc: h, rowCreatedAt: 0,
          deleteHlc: h, deletedAt: 0), isTrue, reason: 'a tie is covered');
      expect(eventPredatesScopeDelete(rowHlc: Hlc(1001, 0, 'b'),
          rowCreatedAt: 0, deleteHlc: h, deletedAt: 9999), isFalse);
    });
    test('falls back to createdAt when a clock is missing', () {
      expect(eventPredatesScopeDelete(rowHlc: null, rowCreatedAt: 10,
          deleteHlc: h, deletedAt: 10), isTrue);
      expect(eventPredatesScopeDelete(rowHlc: null, rowCreatedAt: 11,
          deleteHlc: h, deletedAt: 10), isFalse);
    });
  });

  group('EventScopeCoverage', () {
    final clock = Hlc(1000, 0, 'a');
    final coverage = EventScopeCoverage.from(
      deletedAt: {'d1|c1': 1000, 'd2': 1000},
      clocks: {'d1|c1': clock},
    );
    Map<String, dynamic> event(String dive, String? computer, {Hlc? hlc,
            int createdAt = 0}) =>
        {'id': 'e', 'diveId': dive, 'computerId': computer,
          'hlc': hlc?.toString(), 'createdAt': createdAt};

    test('a computer scope covers only that computer', () {
      expect(coverage.covers(event('d1', 'c1', hlc: Hlc(999, 0, 'b'))), isTrue);
      expect(coverage.covers(event('d1', 'c2', hlc: Hlc(999, 0, 'b'))), isFalse);
      expect(coverage.covers(event('d1', null, hlc: Hlc(999, 0, 'b'))), isFalse);
    });
    test('a newer row is not covered', () {
      expect(coverage.covers(event('d1', 'c1', hlc: Hlc(1001, 0, 'b'))), isFalse);
    });
    test('a dive scope covers every computer by createdAt', () {
      expect(coverage.covers(event('d2', 'c9', createdAt: 999)), isTrue);
      expect(coverage.covers(event('d2', null, createdAt: 1001)), isFalse);
    });
    test('other dives are not covered', () {
      expect(coverage.covers(event('d3', 'c1', createdAt: 0)), isFalse);
    });
  });
}
```

`sync_repository_scoped_deletion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('logScopedDeletion writes one stamped tombstone', () async {
    await SyncRepository().logScopedDeletion(
      const EventScopeTombstone(diveId: 'd1', computerId: 'c1'),
    );
    final row = (await db.select(db.deletionLog).get()).single;
    expect(row.entityType, 'diveProfileEventsScope');
    expect(row.recordId, 'd1|c1');
    expect(row.originHlc, isNotNull);
    expect(row.originHlc, row.hlc);
  });

  test('relayScopedDeletion keeps the newest clock', () async {
    final repo = SyncRepository();
    final older = Hlc(1000, 0, 'p').toString();
    final newer = Hlc(2000, 0, 'p').toString();
    await repo.relayScopedDeletion(recordId: 'd1', deletedAt: 1000,
        originHlc: newer);
    await repo.relayScopedDeletion(recordId: 'd1', deletedAt: 900,
        originHlc: older);
    expect((await db.select(db.deletionLog).get()).single.originHlc, newer);
    await repo.relayScopedDeletion(recordId: 'd1', deletedAt: 3000,
        originHlc: Hlc(3000, 0, 'p').toString());
    final row = (await db.select(db.deletionLog).get()).single;
    expect(row.originHlc, Hlc(3000, 0, 'p').toString());
    expect(row.deletedAt, 3000);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/event_scope_tombstone_test.dart test/core/data/repositories/sync_repository_scoped_deletion_test.dart`
Expected: FAIL, the files and methods do not exist.

- [ ] **Step 3: Implement**

`event_scope_tombstone.dart`:

```dart
import 'package:submersion/core/services/sync/hlc.dart';

/// One tombstone for a set of `dive_profile_events` rows (#1926): every
/// event on a dive, or every event a given computer recorded on it.
///
/// Rides the ordinary `deletion_log` under its own entity type, so export,
/// relay and GC treat it like any tombstone, and a reader too old to know
/// the type stores it as an inert unknown type and deletes nothing (the
/// compatibility floor keeps such readers from receiving it at all). The
/// scope is never sent as extra fields on a `diveProfileEvents` entry: an
/// older reader would ignore them and delete the one row named by `id`.
class EventScopeTombstone {
  static const String entityType = 'diveProfileEventsScope';

  final String diveId;
  final String? computerId;

  const EventScopeTombstone({required this.diveId, this.computerId});

  /// `<diveId>` or `<diveId>|<computerId>`. Both ids are uuids, which never
  /// contain the separator.
  String encode() => computerId == null ? diveId : '$diveId|$computerId';

  static EventScopeTombstone? tryDecode(String recordId) {
    final parts = recordId.split('|');
    if (parts.length > 2 || parts.any((p) => p.isEmpty)) return null;
    return EventScopeTombstone(
      diveId: parts[0],
      computerId: parts.length == 2 ? parts[1] : null,
    );
  }

  bool includes({required String diveId, required String? computerId}) =>
      diveId == this.diveId &&
      (this.computerId == null || computerId == this.computerId);
}

/// Whether an event row existed when a scope delete happened, so the delete
/// covers it. The per-row rule from #1769 applied to a set: with both clocks
/// the clocks decide (a tie is covered, as a per-row tombstone deletes a
/// row whose clock equals its own); otherwise creation time against the
/// delete time, so a pre-v210 row with no clock is still removed.
bool eventPredatesScopeDelete({
  required Hlc? rowHlc,
  required int rowCreatedAt,
  required Hlc? deleteHlc,
  required int deletedAt,
}) {
  if (rowHlc != null && deleteHlc != null) {
    return rowHlc.compareTo(deleteHlc) <= 0;
  }
  return rowCreatedAt <= deletedAt;
}

Hlc? tryParseHlc(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    return Hlc.parse(raw);
  } catch (_) {
    return null;
  }
}

/// The stored scope tombstones, indexed for the merge: whether an incoming
/// event row is one a scope delete already removed.
class EventScopeCoverage {
  final Map<String, List<({EventScopeTombstone scope, int deletedAt, Hlc? clock})>>
  _byDive;

  const EventScopeCoverage._(this._byDive);

  factory EventScopeCoverage.from({
    required Map<String, int> deletedAt,
    required Map<String, Hlc> clocks,
  }) {
    final byDive =
        <String, List<({EventScopeTombstone scope, int deletedAt, Hlc? clock})>>{};
    deletedAt.forEach((recordId, at) {
      final scope = EventScopeTombstone.tryDecode(recordId);
      if (scope == null) return;
      byDive.putIfAbsent(scope.diveId, () => []).add(
        (scope: scope, deletedAt: at, clock: clocks[recordId]),
      );
    });
    return EventScopeCoverage._(byDive);
  }

  bool get isEmpty => _byDive.isEmpty;

  bool covers(Map<String, dynamic> event) {
    final diveId = event['diveId'];
    if (diveId is! String) return false;
    final scopes = _byDive[diveId];
    if (scopes == null) return false;
    final computerId = event['computerId'] as String?;
    final createdAt = event['createdAt'];
    final rowHlc = tryParseHlc(event['hlc']);
    for (final s in scopes) {
      if (!s.scope.includes(diveId: diveId, computerId: computerId)) continue;
      if (eventPredatesScopeDelete(
        rowHlc: rowHlc,
        rowCreatedAt: createdAt is int ? createdAt : 0,
        deleteHlc: s.clock,
        deletedAt: s.deletedAt,
      )) {
        return true;
      }
    }
    return false;
  }
}
```

In `sync_repository.dart` after `logDeletions` (import `event_scope_tombstone.dart`):

```dart
  /// One tombstone for a whole set of events (see [EventScopeTombstone]),
  /// in place of one per row.
  Future<void> logScopedDeletion(EventScopeTombstone scope) => logDeletion(
    entityType: EventScopeTombstone.entityType,
    recordId: scope.encode(),
  );

  /// Stores a peer's scope tombstone for relay. Unlike
  /// [logDeletionIfMissing], a stored copy is replaced when the incoming
  /// delete is newer: a later delete of the same scope covers every row the
  /// earlier one did and more, so keeping the first copy would relay the
  /// narrower one.
  Future<void> relayScopedDeletion({
    required String recordId,
    required int deletedAt,
    String? originHlc,
  }) async {
    final existing = await (_db.select(_db.deletionLog)
          ..where((t) =>
              t.entityType.equals(EventScopeTombstone.entityType) &
              t.recordId.equals(recordId)))
        .get();
    if (existing.isNotEmpty) {
      final incoming = tryParseHlc(originHlc);
      final stored = tryParseHlc(existing.first.originHlc);
      if (incoming == null) return;
      if (stored != null && incoming.compareTo(stored) <= 0) return;
    }
    await logDeletion(
      entityType: EventScopeTombstone.entityType,
      recordId: recordId,
      deletedAt: deletedAt,
      relayed: true,
      originHlc: originHlc,
    );
  }
```

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/core/services/sync/event_scope_tombstone_test.dart test/core/data/repositories/sync_repository_scoped_deletion_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/event_scope_tombstone.dart lib/core/data/repositories/sync_repository.dart test/core/services/sync/event_scope_tombstone_test.dart test/core/data/repositories/sync_repository_scoped_deletion_test.dart
git commit -m "feat(sync): add a scoped tombstone for a dive's events"
```

---

### Task 5: Apply a peer's scope tombstone, and guard the merge

**Files:**
- Create: `lib/core/services/sync/event_scope_tombstone_applier.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (`_applyRemoteDeletions` ~line 2196; `_mergeEntity` ~line 2760 and its local-deletion guard ~line 2898; constructor to hold an applier)
- Test: `test/core/services/sync/event_scope_tombstone_apply_test.dart`

**Interfaces:**
- Consumes: everything Task 4 produces.
- Produces: `class EventScopeTombstoneApplier { EventScopeTombstoneApplier({AppDatabase? db, SyncRepository? syncRepository}); Future<int> apply({required SyncDeletion deletion, required int deletedAt, required Set<String> pendingEventIds, required Set<String> contradictedEventIds}); }`

- [ ] **Step 1: Write the failing tests**

Model the harness on `test/core/services/sync/child_tombstone_hlc_test.dart` (its `pull` helper, `seedPeerBaseFromPayload`, `performSync`). Seed dive `d1` with `createTestDiveWithBottomTime`, insert computers `c1` and `c2` (as `dive_split_service_test.dart`'s `insertComputer` does), and insert events with raw SQL: `INSERT INTO dive_profile_events (id, dive_id, timestamp, event_type, computer_id, created_at) VALUES (...)`, then stamp the ones that need a clock with `SyncRepository().markRecordPending(entityType: 'diveProfileEvents', ...)` and read their `hlc` back. Clear sync records afterwards, as that file does, so they are not pending. Tests:

```dart
  test('a dive scope deletes every older event and keeps newer ones', ...);
  // e-old (hlc below the scope clock) gone; e-new (hlc above) kept.

  test('a computer scope leaves other computers and null-computer events',
      ...);
  // scope 'd1|c1': c1 event gone; c2 and null-computer events kept.

  test('a pre-v210 event with no clock is deleted by createdAt', ...);
  // event with hlc NULL and created_at below deletedAt: gone;
  // created_at above deletedAt: kept.

  test('a locally pending event survives', ...);
  // mark e1 pending (do not clear sync records) with an hlc BELOW the
  // scope clock: it is kept.

  test('the scope tombstone is stored for relay with the peer clock', ...);
  // deletion_log has ('diveProfileEventsScope', 'd1') whose originHlc is
  // the pulled clock.

  test('a stale event from a lagging peer does not come back', ...);
  // First pull: scope 'd1' at clock H (events deleted). Second pull from a
  // different peer id: data carries e-old with hlc below H. It stays gone.
  // Third pull: an event with hlc above H applies.

  test('a malformed scope id deletes nothing and does not fail the sync',
      ...);
  // deletions {'diveProfileEventsScope': [SyncDeletion(id: 'a|b|c', ...)]}
  // every event kept; result status not error.
```

Write each body fully in the test file (the `pull` helper takes `events:` as well as `deletions:`; build `SyncData(diveProfileEvents: events)`).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/event_scope_tombstone_apply_test.dart`
Expected: FAIL, events not deleted (an unknown type is inert today).

- [ ] **Step 3: Implement the applier**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

/// Applies a peer's [EventScopeTombstone]: deletes the events it covers and
/// stores it for relay.
class EventScopeTombstoneApplier {
  static final _log = LoggerService.forClass(EventScopeTombstoneApplier);

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;

  EventScopeTombstoneApplier({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Returns how many events were deleted. Rows pending here (an unpublished
  /// local edit) and rows the same payload presents live are kept, as the
  /// per-row path keeps them.
  Future<int> apply({
    required SyncDeletion deletion,
    required int deletedAt,
    required Set<String> pendingEventIds,
    required Set<String> contradictedEventIds,
  }) async {
    final scope = EventScopeTombstone.tryDecode(deletion.id);
    if (scope == null) {
      _log.warning('Ignoring malformed event scope tombstone ${deletion.id}');
      return 0;
    }
    final deleteHlc = tryParseHlc(deletion.hlc);
    final query = _db.select(_db.diveProfileEvents)
      ..where((t) => t.diveId.equals(scope.diveId));
    if (scope.computerId != null) {
      query.where((t) => t.computerId.equals(scope.computerId!));
    }
    final doomed = [
      for (final row in await query.get())
        if (!pendingEventIds.contains(row.id) &&
            !contradictedEventIds.contains(row.id) &&
            eventPredatesScopeDelete(
              rowHlc: tryParseHlc(row.hlc),
              rowCreatedAt: row.createdAt,
              deleteHlc: deleteHlc,
              deletedAt: deletedAt,
            ))
          row.id,
    ];
    for (var i = 0; i < doomed.length; i += 500) {
      final chunk = doomed.sublist(i, (i + 500).clamp(0, doomed.length));
      await (_db.delete(_db.diveProfileEvents)
            ..where((t) => t.id.isIn(chunk)))
          .go();
    }
    await _syncRepository.relayScopedDeletion(
      recordId: deletion.id,
      deletedAt: deletedAt,
      originHlc: deletion.hlc,
    );
    return doomed.length;
  }
}
```

Check the logger import and API with `grep -rn "LoggerService.forClass" lib/core/services/sync | head -2` and match it.

- [ ] **Step 4: Wire it into `SyncService`**

Add a field `final EventScopeTombstoneApplier _eventScopeApplier;` initialised in the constructor as `_eventScopeApplier = EventScopeTombstoneApplier(syncRepository: syncRepository)` (use whatever the constructor already names the injected `SyncRepository`; read the constructor first).

In `_applyRemoteDeletions`, first statement inside `try {`:

```dart
          if (entityType == EventScopeTombstone.entityType) {
            final deletionHlc = _parseHlc(deletion.hlc);
            if (deletionHlc != null) SyncClock.instance.receive(deletionHlc);
            await _eventScopeApplier.apply(
              deletion: deletion,
              deletedAt: deletion.deletedAt > 0
                  ? deletion.deletedAt
                  : remoteExportedAt,
              pendingEventIds:
                  pendingByEntity['diveProfileEvents'] ?? const <String>{},
              contradictedEventIds:
                  contradictedByEntity['diveProfileEvents'] ??
                  const <String>{},
            );
            applied += 1;
            continue;
          }
```

In `_mergeEntity`, after `final ownClocked = ...`:

```dart
    // Deletions apply before the merge, but the local-deletion guard below
    // matches by exact id. A lagging peer can still hold events a scope
    // delete removed, so those are checked against the scopes as well.
    final eventScopes = entityType == 'diveProfileEvents'
        ? EventScopeCoverage.from(
            deletedAt:
                allTombstones[EventScopeTombstone.entityType] ??
                const <String, int>{},
            clocks:
                tombstoneClocks[EventScopeTombstone.entityType] ??
                const <String, Hlc>{},
          )
        : null;
```

and immediately after the local-deletion guard block (the `if (deletedAt != null) { ... }` that ends before `if (!hasUpdatedAt) {`):

```dart
        if (eventScopes != null &&
            !eventScopes.isEmpty &&
            eventScopes.covers(record)) {
          continue;
        }
```

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/core/services/sync/event_scope_tombstone_apply_test.dart test/core/services/sync/child_tombstone_hlc_test.dart test/core/services/sync/unknown_entity_type_forward_compat_test.dart test/core/services/sync/sync_deletion_propagation_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/sync/ test/core/services/sync/event_scope_tombstone_apply_test.dart
git commit -m "feat(sync): apply scoped event tombstones and block stale events reviving"
```

---

### Task 6: Schema v233 and the compat floor

**Files:**
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `minimumCompatibleSchemaVersion` and its history comment, `migrationVersions`, `onUpgrade` tail, `beforeOpen` backstops, a new `_assertProfileEventsDiveIdIndex` beside `_assertNavTracksSchema`)
- Modify: `test/core/services/sync/cross_version_roundtrip_test.dart`
- Test: a migration test modelled on the nearest rung test (`ls test/core/database | grep -i -E "v2[23][0-9]|nav_track|migration"`)

**Interfaces:**
- Produces: `AppDatabase.currentSchemaVersion == 233`, `AppDatabase.minimumCompatibleSchemaVersion == 233`, index `idx_dive_profile_events_dive_id`.

- [ ] **Step 1: Write the failing tests**

Migration test (in the style of the nearest rung test found above): open a fresh database and assert
`SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_dive_profile_events_dive_id'` returns one row; and for an upgrade from 231, drop the index, run the rung's `_assert` path by reopening (the backstop), and assert it is back.

In `cross_version_roundtrip_test.dart`, add a header paragraph:

```dart
// The floor moved 224 -> 233 with scoped event tombstones (#1926): this
// build replaces a dive's event tombstones with one tombstone for the whole
// set, which an older reader stores as an inert unknown type, leaving the
// events on that device for good. The direction the floor cannot reach, an
// older peer's live events arriving here after we scope-deleted them, is
// the merge guard's job; the group below covers it.
```

and a group:

```dart
  group('pre-v233 peer and scoped event tombstones', () {
    test('the floor is at least 233', () {
      expect(AppDatabase.minimumCompatibleSchemaVersion,
          greaterThanOrEqualTo(233));
    });
    // An older peer republishes a dive's events we scope-deleted: they
    // stay deleted; an event it creates after the delete applies.
    test('an older peer cannot bring back scope-deleted events', () async {
      // Build with this file's existing old-peer payload helper, the event
      // rows omitting the post-v210 hlc key (an old writer's shape) and
      // carrying created_at before and after the local scope delete.
    });
  });
```

Write the second test body fully using the file's existing helpers.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/cross_version_roundtrip_test.dart <migration test path>`
Expected: FAIL (floor 224, index missing).

- [ ] **Step 3: Implement**

```dart
  Future<void> _assertProfileEventsDiveIdIndex() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_profile_events_dive_id '
      'ON dive_profile_events (dive_id)',
    );
  }
```

`onUpgrade` tail:

```dart
        // v233: index dive_profile_events by dive (#1926). Scoped event
        // tombstones delete and match events by dive, and the table had no
        // index on it. Index-only rung; the floor rise it ships with is for
        // the tombstones, not for this.
        if (from < 233) {
          await _assertProfileEventsDiveIdIndex();
        }
        if (from < 233) await reportProgress();
```

`beforeOpen`, first line: `// v233 backstop: the events-by-dive index.` then `await _assertProfileEventsDiveIdIndex();`.

`migrationVersions`: append

```dart
    // v233: idx_dive_profile_events_dive_id for scoped event tombstones
    // (#1926); raises the floor to 233. 232 is claimed by open PRs #2411,
    // #2407 and #2331.
    233,
```

Set `currentSchemaVersion = 233` and `minimumCompatibleSchemaVersion = 233`, adding to the floor's doc comment:

```dart
  /// Raised 224 -> 233 by scoped event tombstones (#1926): this build
  /// replaces the per-row tombstones a split, re-import or re-parse wrote
  /// for a dive's events with one tombstone for the whole set. An older
  /// reader knows nothing of the scope type and stores it as an inert
  /// unknown entity, so the events it names stay on that device for good.
  /// That is an old reader misapplying our payload, which is what this floor
  /// exists to prevent. Peers below 233 are held until they update; their
  /// own payloads still arrive here, and the merge's scope guard keeps their
  /// copies of deleted events from coming back.
```

Then find tests that pin the old literals: `grep -rn "231\b\|224\b" test/core/database test/core/services/sync | grep -i -E "schema|version|floor"` and update each to the new values (see memory cue ladder-literals).

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/core/database test/core/services/sync/cross_version_roundtrip_test.dart test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/database.dart test/core/
git commit -m "feat(db): v233 events-by-dive index; raise the sync floor to 233"
```

---

### Task 7: Emit scope tombstones

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_split_service.dart` (step 8, ~lines 352-376)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`clearEventsForDive`, ~line 2240)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`deleteProfileEventsForDive`, ~line 4840)
- Modify: `lib/features/dive_import/data/services/dive_reimport_service.dart` (`_replaceProfileEvents`, ~line 606)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`_deleteAndTombstone` and its two call sites, ~lines 203-216 and 310-329)
- Test: `test/features/dive_log/data/services/dive_split_service_test.dart`, plus the existing test file of each other emitter (`grep -rln "clearEventsForDive\|deleteProfileEventsForDive\|_replaceProfileEvents\|ReparseService" test | head`)

**Interfaces:**
- Consumes: `SyncRepository.logScopedDeletion`, `SyncRepository.logDeletions`, `EventScopeTombstone` (Task 4).

- [ ] **Step 1: Write the failing tests**

Split: update `'split tombstones every moved row'` so it expects `byRecord['dive-1|dc-b'] == 'diveProfileEventsScope'`, no `'diveProfileEvents'` tombstone at all, and `byRecord[movedTank] == 'diveTanks'`. Add:

```dart
  test('split writes one events tombstone however many events move',
      () async {
    await insertDive('dive-1', computerId: 'dc-a');
    await insertSource('src-a', 'dive-1', 'dc-a', isPrimary: true);
    await insertSource('src-b', 'dive-1', 'dc-b', isPrimary: false);
    await insertProfileSeriesRow('dive-1', 'dc-a', isPrimary: true);
    await insertProfileSeriesRow('dive-1', 'dc-b', isPrimary: false);
    for (var i = 0; i < 50; i++) {
      await insertEvent('dive-1', 'dc-b');
    }
    final keptEvent = await insertEvent('dive-1', 'dc-a');

    await service.split(diveId: 'dive-1', sourceId: 'src-b');

    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((t) => t.entityType.startsWith('diveProfileEvents')),
      hasLength(1),
    );
    final events = await db.select(db.diveProfileEvents).get();
    expect(events.where((e) => e.diveId == 'dive-1').map((e) => e.id),
        [keptEvent]);
  });
```

For each of the other four emitters, in its existing test file, add a test: seed a dive with 3 events, run the path, and assert that `deletion_log` holds exactly one row `('diveProfileEventsScope', '<diveId>')` and no `diveProfileEvents` rows. Where the path inserts replacement events (reimport, reparse), also assert that every replacement event's `hlc` compares greater than the scope row's `originHlc` (parse both with `Hlc.parse`). That pins Review Focus 2.

- [ ] **Step 2: Run to verify they fail**

Run each touched test file with `flutter test <path>`.
Expected: FAIL (per-event tombstones).

- [ ] **Step 3: Implement**

Split, step 8, replace the event loop and the tank loop:

```dart
      if (eventRows.isNotEmpty) {
        await (_db.delete(
          _db.diveProfileEvents,
        )..where((t) => t.id.isIn([for (final r in eventRows) r.id]))).go();
        // One tombstone for every event this source's computer recorded on
        // the dive, instead of one per event (#1926). eventRows is exactly
        // that set (ownedByComputer), so the scope removes on a peer what
        // was removed here.
        await _sync.logScopedDeletion(
          EventScopeTombstone(diveId: diveId, computerId: source.computerId),
        );
      }
      if (movedTankIds.isNotEmpty) {
        await _sync.logDeletions(
          entityType: 'diveTanks',
          recordIds: movedTankIds,
        );
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.isIn(movedTankIds))).go();
      }
```

Update the step-8 comment to say events go by one scope tombstone and tanks in one batch.

`clearEventsForDive` and `deleteProfileEventsForDive` (same shape in both):

```dart
      final deleted = await (_db.delete(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).go();
      // One tombstone for the dive's events, not one per event (#1926).
      if (deleted > 0) {
        await _syncRepository.logScopedDeletion(
          EventScopeTombstone(diveId: diveId),
        );
      }
```

(drop the now-unused `existing` select).

`_replaceProfileEvents`: the same replacement for its select, delete and loop, before the insert loop that follows.

`ReparseService`: give `_deleteAndTombstone` a `required String diveId` parameter and replace its final loop with:

```dart
    if (entityType == 'diveProfileEvents') {
      // One tombstone for the dive's events, not one per event (#1926).
      await _sync.logScopedDeletion(EventScopeTombstone(diveId: diveId));
    } else {
      await _sync.logDeletions(entityType: entityType, recordIds: ids);
    }
```

and pass `diveId: diveId` at both call sites. Add the `event_scope_tombstone.dart` import to each file.

- [ ] **Step 4: Run to verify they pass**

Run the same test files.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ test/features/
git commit -m "feat(sync): tombstone replaced and split events by scope"
```

---

### Task 8: Measurement

**Files:**
- Test: `test/core/services/sync/tombstone_amplification_measurement_test.dart`

- [ ] **Step 1: Write the measurement test**

Use only APIs that exist on the parent commit (`SafetyFindingsRepository.saveReview`, `clearReviewForDive`, `DiveComputerRepositoryImpl.clearEventsForDive`, `DiveSplitService.split`), so the same file runs unchanged on the parent commit to produce the before numbers. Each scenario counts `deletion_log` rows written by the operation (count after minus count before), prints `MEASURE <scenario> <count>` BEFORE asserting, and asserts the after value:

1. `engine-bump`: 200 dives, dive `i` gets `i % 7` findings with distinct rules or spans and random uuid ids; `saveReview` at engine 2; then `saveReview` again at engine 3 with the same findings under new random ids (the engine's output shape before this change). Expect 0.
2. `profile-edit`: for those 200 dives, `clearReviewForDive` then `saveReview` with the same findings. Expect 0 net rows: the marker's tombstone is written, then cleared when the recompute restores the marker (on the parent commit the findings are tombstoned too and the marker tombstone stays).
3. `reimport`: one dive with 300 events, `clearEventsForDive`. Expect 1.
4. `split`: one dive, two sources (`dc-a` primary, `dc-b`), 300 events and 2 unreferenced tanks on `dc-b`, one profile series per source. Expect the count the new code writes: 1 scope + 2 tanks + 1 profile series + 1 source = 5.

Guard the prints with `// ignore: avoid_print`.

- [ ] **Step 2: Run on this branch**

Run: `flutter test test/core/services/sync/tombstone_amplification_measurement_test.dart`
Expected: PASS; note the four MEASURE lines.

- [ ] **Step 3: Run on the parent commit for the before numbers**

```bash
git worktree add "$TMPDIR/wt-1926-before" 086c1af309
cp test/core/services/sync/tombstone_amplification_measurement_test.dart "$TMPDIR/wt-1926-before/test/core/services/sync/"
```

Then in that worktree: `git submodule update --init --recursive`, `bash scripts/setup.sh`, and `flutter test test/core/services/sync/tombstone_amplification_measurement_test.dart`. The assertions fail there by design; record the MEASURE lines. Remove the worktree afterwards with `rm -rf` plus `git worktree prune` (`git worktree remove` refuses on this repo because of its submodules).

- [ ] **Step 4: Commit**

```bash
git add test/core/services/sync/tombstone_amplification_measurement_test.dart
git commit -m "test(sync): measure tombstones minted by review recompute, re-import and split"
```

---

### Task 9: Verify and open the PR

- [ ] **Step 1:** `dart format .` and `flutter analyze` (expect "No issues found!", and do not pipe it; see memory cue pipe-mask).
- [ ] **Step 2:** `flutter test test/architecture test/core/services/sync test/core/data test/core/database test/features/dive_log test/features/dive_import test/features/dive_computer`. Expect all green.
- [ ] **Step 3:** Re-scan open PRs for `currentSchemaVersion` claims (Global Constraints) and renumber if needed.
- [ ] **Step 4:** Push the branch and open the PR against `main` with `Closes #1926`, the before/after table from Task 8, and the Screenshots section: tick "No visible UI change". The badge query lives in `data/`, not `presentation/`, and its visible behaviour matches today's (no badge while a review is invalidated). No attribution lines.
- [ ] **Step 5:** Bind the PR with the ccd_pr tools and turn on auto-fix monitoring.
