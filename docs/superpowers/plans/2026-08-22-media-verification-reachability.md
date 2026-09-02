# Media Verification Reachability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `MediaItem.isOrphaned` true for every source type, not just local files, so the media status badge and every other consumer of that column stop understating library damage.

**Architecture:** Three parts, in order. (1) Add a third `ResolutionStatus` and a matching `VerifyResult` so "I could not check the gallery" stops arriving as "the asset is gone", which today already orphans rows when photo permission is revoked. (2) A pure reconciler turns a completed resolution into an orphan-flag decision, and `MediaItemView` persists it through a new narrow write, writing only when the flag actually changes so a scroll costs zero writes. (3) Extract the local-file sweep into a registry-dispatched `MediaVerificationSweep` that covers every source type, with a new Settings action.

**Tech Stack:** Flutter 3.47 / Dart, Riverpod 3, Drift, `flutter gen-l10n` across 11 locales.

**Spec:** `docs/superpowers/specs/2026-08-22-media-verification-reachability-design.md`

## Global Constraints

- No em-dashes (U+2014) anywhere: code, comments, docs, ARB strings, commit messages. En-dashes (U+2013) and " - " used as prose punctuation are equally forbidden. Rewrite with commas, parentheses, colons, or semicolons.
- No emojis in code, comments, or documentation.
- `dart format .` must leave the tree unchanged before every commit.
- `flutter analyze` must report "No issues found!" over the whole project. Infos are fatal in CI.
- Every user-visible string goes in all 11 ARB files: `ar de en es fr he hu it nl pt zh`. Translate them; do not leave English placeholders in non-English files.
- Immutability: never mutate an existing object or list in place.
- TDD: the failing test comes first, and you must watch it fail before writing the implementation.
- Commit after each task.
- **Only a positive finding may orphan a row.** Every "could not check" outcome leaves `isOrphaned` alone. A false orphan tells a diver a photo they still have is gone, and it replicates through sync.
- Do not run `flutter test` while another session is running it. Overlapping runs produce phantom lone failures.

---

## File Structure

**Create:**
- `lib/features/media/domain/services/media_orphan_reconciler.dart` - the pure decision function. Domain layer, no Flutter or Drift imports, so it is table-testable.
- `lib/features/media/data/services/media_verification_sweep.dart` - the registry-dispatched sweep across all source types.
- `test/features/media/domain/services/media_orphan_reconciler_test.dart`
- `test/features/media/data/services/media_verification_sweep_test.dart`

**Modify:**
- `lib/features/media/data/services/asset_resolution_service.dart` - third `ResolutionStatus`, returned at the two permission sites.
- `lib/features/media/domain/value_objects/verify_result.dart` - `accessDenied`.
- `lib/features/media/domain/value_objects/media_source_data.dart` - `UnavailableKind.accessDenied`, for the serving path (F6b).
- `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart:47-78` - an arm in each of the two exhaustive switches.
- `lib/features/media/data/resolvers/platform_gallery_resolver.dart:46-95,149-167` - propagate the status in `verify`, `resolve`, and `resolveThumbnail` instead of collapsing every failure to `notFound`.
- `lib/features/media/data/services/media_item_verifier.dart:60-64` - `accessDenied` joins the transient branch.
- `lib/features/media/data/services/local_files_diagnostics_service.dart:89-122` - `reverifyAll` delegates to the sweep.
- `lib/features/media/data/repositories/media_repository.dart` - `markVerified`, `getAllBySourceTypes`.
- `lib/features/media/presentation/widgets/media_item_view.dart:137-160` - call the reconciler after recording.
- `lib/features/media/presentation/providers/media_resolver_providers.dart` - provider for the sweep.
- `lib/features/media/presentation/pages/media_sources_page.dart` - "Check all media" action.
- `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` - 3 new keys.
- `lib/features/media_store/presentation/providers/media_store_providers.dart:219-233` - delete the orphaned doc comment left by PR #1125.
- `lib/features/media/domain/entities/media_status.dart:47-52` - correct the reachability comment.

---

### Task 1: `ResolutionStatus.accessDenied`

**Files:**
- Modify: `lib/features/media/data/services/asset_resolution_service.dart:10-16`, `:160-176`
- Test: `test/features/media/data/services/asset_resolution_service_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ResolutionStatus.accessDenied`, returned by `AssetResolutionService.resolveAssetId` whenever the photo permission check throws or reports a status other than `authorized` / `limited`.

- [ ] **Step 1: Write the failing test**

Add to the existing test file. Match its existing mock setup for `PhotoPickerService`.

```dart
test('denied photo permission reports accessDenied, not unavailable', () async {
  // The distinction is load-bearing: unavailable is a positive finding that
  // no matching asset exists, and callers are entitled to orphan a row on
  // it. A permission problem teaches nothing about the asset.
  when(() => picker.checkPermission())
      .thenAnswer((_) async => PhotoPermissionStatus.denied);

  final result = await service.resolveAssetId(itemWithUnresolvableId);

  expect(result.status, ResolutionStatus.accessDenied);
});

test('a thrown permission check reports accessDenied', () async {
  when(() => picker.checkPermission()).thenThrow(Exception('channel down'));

  final result = await service.resolveAssetId(itemWithUnresolvableId);

  expect(result.status, ResolutionStatus.accessDenied);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/asset_resolution_service_test.dart`
Expected: FAIL, "The getter 'accessDenied' isn't defined for the type 'ResolutionStatus'".

- [ ] **Step 3: Add the enum value**

In `asset_resolution_service.dart`, replace the enum:

```dart
enum ResolutionStatus {
  /// Asset ID was resolved successfully (from cache, original ID, or matching).
  resolved,

  /// No matching asset found on this device. A positive finding: the gallery
  /// was consulted and does not have it.
  unavailable,

  /// The gallery could not be consulted, so nothing was learned about the
  /// asset. Never a reason to orphan a row: the asset is probably fine and
  /// the user can restore access.
  accessDenied,
}
```

- [ ] **Step 4: Return it at both permission sites**

At `:167` (thrown check) and `:175` (non-authorized status), change
`ResolutionStatus.unavailable` to `ResolutionStatus.accessDenied`. Leave the
existing comments; extend the one at `:152-159` with:

```dart
    // Returning accessDenied rather than unavailable is what lets a caller
    // tell those two apart. A caller that orphans on unavailable would
    // otherwise mark the entire library missing the moment permission is
    // revoked.
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/media/data/services/asset_resolution_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Check for callers that switch on the enum**

Run: `grep -rn "ResolutionStatus\." lib/ test/`
Any exhaustive `switch` must gain an `accessDenied` arm. A caller that treats
`unavailable` as "no asset" must NOT treat `accessDenied` the same way.

- [ ] **Step 7: Commit**

```bash
git add lib/features/media/data/services/asset_resolution_service.dart test/features/media/data/services/asset_resolution_service_test.dart
git commit -m "fix(media): distinguish denied gallery access from a missing asset"
```

---

### Task 2: `VerifyResult.accessDenied` and the transient branches

**Files:**
- Modify: `lib/features/media/domain/value_objects/verify_result.dart`
- Modify: `lib/features/media/data/resolvers/platform_gallery_resolver.dart:149-167`
- Modify: `lib/features/media/data/services/media_item_verifier.dart:60-64`
- Modify: `lib/features/media/data/services/local_files_diagnostics_service.dart:100-106`
- Test: `test/features/media/data/services/media_item_verifier_test.dart`

**Interfaces:**
- Consumes: `ResolutionStatus.accessDenied` from Task 1.
- Produces: `VerifyResult.accessDenied`. `MediaItemVerifier.verify` returns it without writing `isOrphaned`, and stamps `lastVerifiedAt` only.

- [ ] **Step 1: Write the failing test**

```dart
test('a gallery row whose library cannot be read is not orphaned', () async {
  // The bug this pins: denied permission used to arrive as notFound, and
  // the verifier wrote isOrphaned = true for every row it touched. That
  // damage then replicates through sync.
  when(() => registry.resolverFor(MediaSourceType.platformGallery))
      .thenReturn(resolver);
  when(() => resolver.verify(item))
      .thenAnswer((_) async => VerifyResult.accessDenied);

  final result = await verifier.verify(item);

  expect(result, VerifyResult.accessDenied);
  final written = verify(() => repository.updateMedia(captureAny()))
      .captured.single as MediaItem;
  expect(written.isOrphaned, isFalse, reason: 'nothing was learned');
  expect(written.lastVerifiedAt, isNotNull, reason: 'the attempt is dated');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/media_item_verifier_test.dart`
Expected: FAIL, "The getter 'accessDenied' isn't defined for the type 'VerifyResult'".

- [ ] **Step 3: Add the enum value**

In `verify_result.dart`, after `volumeOffline`:

```dart
  /// The source could not be consulted at all, so nothing was learned. The
  /// gallery case is a revoked or not-yet-granted photo permission. Treated
  /// as transient by every sweep: never orphans.
  accessDenied,
```

Update the doc comment at the top of the enum so its list of persistent
failure states still reads correctly.

- [ ] **Step 4: Propagate the status out of the gallery resolver**

Replace `_resolveId` and the gallery `verify`:

```dart
  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return VerifyResult.notFound;
    final resolution = await _resolutionService.resolveAssetId(item);
    // Checked before the id, because accessDenied always carries a null id
    // and collapsing the two would reintroduce the mass-orphan bug.
    if (resolution.status == ResolutionStatus.accessDenied) {
      return VerifyResult.accessDenied;
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId == null) return VerifyResult.notFound;
    // coverage:ignore-start
    final asset = await AssetEntity.fromId(resolvedId);
    return asset == null ? VerifyResult.notFound : VerifyResult.available;
    // coverage:ignore-end
  }
```

Keep `_resolveId` only if other callers remain; otherwise delete it.

- [ ] **Step 4b: Add `UnavailableKind.accessDenied` and produce it while serving**

REQUIRED. `ResolutionStatus.accessDenied` alone is not enough. Grid tiles call
`resolveThumbnail`, whose helper `_fetchThumbnail` returns `Uint8List?` and has
already discarded the reason, so every permission failure currently reaches the
serving path as `notFound`. Task 5 would then orphan the entire library on a
permission-revoked device.

In `media_source_data.dart`, after `stillFetching`:

```dart
  /// The source refused to answer, so nothing is known about the item. The
  /// gallery case is a revoked or not-yet-granted photo permission.
  ///
  /// Never evidence of absence. `reconciledOrphanFlag` must leave the orphan
  /// flag alone for this kind: it is the difference between "your photo is
  /// gone" and "let me look at your photos".
  accessDenied,
```

In `PlatformGalleryResolver.resolve`, replace the `_resolveId` null branch:

```dart
    final resolution = await _resolutionService.resolveAssetId(item);
    if (resolution.status == ResolutionStatus.accessDenied) {
      return const UnavailableData(kind: UnavailableKind.accessDenied);
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
```

In `resolveThumbnail`, replace the `bytes == null` branch:

```dart
    if (bytes == null) {
      // Failure path only, and getOrFetch never caches a null
      // (gallery_thumbnail_cache.dart:99-103), so this costs nothing in the
      // common case. resolveAssetId short-circuits at the permission check
      // before it queries the gallery.
      final status = (await _resolutionService.resolveAssetId(item)).status;
      return UnavailableData(
        kind: status == ResolutionStatus.accessDenied
            ? UnavailableKind.accessDenied
            : UnavailableKind.notFound,
      );
    }
```

- [ ] **Step 4c: Give the placeholder an arm and a string**

`unavailable_media_placeholder.dart` has two exhaustive switches. Add to
`_iconFor`: `UnavailableKind.accessDenied => Icons.no_photography_outlined,`
and to `_messageFor`:
`UnavailableKind.accessDenied => l10n.media_unavailablePlaceholder_accessDenied,`.

New ARB key in all 11 catalogs, English:

```json
"media_unavailablePlaceholder_accessDenied": "No photo library access"
```

with `"@media_unavailablePlaceholder_accessDenied": {"description": "Media placeholder: the photo library could not be read"}`.

Run `flutter gen-l10n` afterwards.

- [ ] **Step 5: Add `accessDenied` to both transient branches**

`media_item_verifier.dart:60-64`:

```dart
      if (result == VerifyResult.volumeOffline ||
          result == VerifyResult.accessDenied ||
          result == VerifyResult.transientError) {
```

`local_files_diagnostics_service.dart:100-106`: same three-way condition.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/media/data/services/media_item_verifier_test.dart test/features/media/data/services/local_files_diagnostics_service_test.dart test/features/media/data/resolvers/platform_gallery_resolver_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/media test/features/media
git commit -m "fix(media): never orphan a row the gallery could not be read for"
```

---

### Task 3: the pure reconciler

**Files:**
- Create: `lib/features/media/domain/services/media_orphan_reconciler.dart`
- Test: `test/features/media/domain/services/media_orphan_reconciler_test.dart`

**Interfaces:**
- Consumes: `UnavailableKind` from `media_source_data.dart`.
- Produces: `bool? reconciledOrphanFlag({required bool currentlyOrphaned, required UnavailableKind? failure})`. Returns the flag to write, or null when nothing should be written.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  group('positive findings write', () {
    test('bytes served un-orphans a row currently marked missing', () {
      expect(
        reconciledOrphanFlag(currentlyOrphaned: true, failure: null),
        isFalse,
      );
    });

    test('notFound orphans a row currently marked present', () {
      expect(
        reconciledOrphanFlag(
          currentlyOrphaned: false,
          failure: UnavailableKind.notFound,
        ),
        isTrue,
      );
    });

    test('unauthenticated orphans a row currently marked present', () {
      expect(
        reconciledOrphanFlag(
          currentlyOrphaned: false,
          failure: UnavailableKind.unauthenticated,
        ),
        isTrue,
      );
    });
  });

  group('no-op when the flag already agrees', () {
    // This is the property that makes the whole passive path affordable: a
    // steady-state library costs zero writes no matter how far it scrolls.
    test('bytes served on a healthy row writes nothing', () {
      expect(
        reconciledOrphanFlag(currentlyOrphaned: false, failure: null),
        isNull,
      );
    });

    test('notFound on an already-orphaned row writes nothing', () {
      expect(
        reconciledOrphanFlag(
          currentlyOrphaned: true,
          failure: UnavailableKind.notFound,
        ),
        isNull,
      );
    });
  });

  group('inconclusive kinds never write', () {
    // Each of these means the resolution learned nothing about whether the
    // asset exists. Orphaning on any of them would report a recoverable
    // condition as permanent data loss, and sync would replicate it.
    for (final kind in const [
      UnavailableKind.accessDenied,
      UnavailableKind.stillFetching,
      UnavailableKind.networkError,
      UnavailableKind.volumeOffline,
      UnavailableKind.fromOtherDevice,
      UnavailableKind.signInRequired,
    ]) {
      test('$kind leaves a healthy row alone', () {
        expect(
          reconciledOrphanFlag(currentlyOrphaned: false, failure: kind),
          isNull,
        );
      });

      test('$kind leaves an orphaned row alone', () {
        expect(
          reconciledOrphanFlag(currentlyOrphaned: true, failure: kind),
          isNull,
        );
      });
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/services/media_orphan_reconciler_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Decides whether a completed resolution should change a row's orphan flag.
///
/// Pure, and deliberately conservative: only a POSITIVE finding may write.
/// A resolution either consulted the source and learned something, or it did
/// not. Everything in the second category leaves the flag alone, because a
/// false orphan tells a diver a photo they still have is gone, and
/// `MediaRepository.markVerified` replicates that claim to every other
/// device through sync.
///
/// Returns null when nothing should be written, which is the common case:
/// the flag already agrees, or the resolution was inconclusive. That is what
/// makes calling this on every tile resolution affordable. A library at rest
/// performs no writes no matter how far it is scrolled.
bool? reconciledOrphanFlag({
  required bool currentlyOrphaned,
  required UnavailableKind? failure,
}) {
  final desired = _desiredFlag(failure);
  if (desired == null || desired == currentlyOrphaned) return null;
  return desired;
}

/// Exhaustive with no default arm, so a new [UnavailableKind] cannot ship
/// without someone deciding whether it is evidence of absence. The default
/// answer for a new kind should almost always be null.
bool? _desiredFlag(UnavailableKind? failure) {
  if (failure == null) return false; // Bytes arrived: the source has it.
  return switch (failure) {
    // The source was consulted and does not have this item.
    UnavailableKind.notFound => true,
    UnavailableKind.unauthenticated => true,

    // The source refused to answer. The single most important null in this
    // function: without it, one revoked photo permission orphans every
    // gallery row in the library and syncs that claim everywhere.
    UnavailableKind.accessDenied => null,

    // Recoverable by a user action; the item is probably still there.
    UnavailableKind.signInRequired => null,

    // Not a claim about this device's copy at all.
    UnavailableKind.fromOtherDevice => null,

    // Transient by construction. volumeOffline is documented as never
    // orphaning, and stillFetching explicitly means nothing is wrong.
    UnavailableKind.networkError => null,
    UnavailableKind.volumeOffline => null,
    UnavailableKind.stillFetching => null,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/domain/services/media_orphan_reconciler_test.dart`
Expected: PASS, 15 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/domain/services/media_orphan_reconciler.dart test/features/media/domain/services/media_orphan_reconciler_test.dart
git commit -m "feat(media): add the orphan reconciliation decision function"
```

---

### Task 4: `MediaRepository.markVerified`

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (add after `markOrphaned`, around `:572`)
- Test: `test/features/media/data/repositories/media_repository_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Future<void> markVerified(String id, {required bool isOrphaned, required DateTime verifiedAt})`.

- [ ] **Step 1: Write the failing test**

```dart
test('markVerified writes only the flag and the stamp', () async {
  // updateMedia writes all 30 columns from the caller's snapshot, and a grid
  // tile's snapshot is routinely stale, so the passive path must not use it.
  final before = await repository.getMediaById(id);
  await repository.markVerified(
    id,
    isOrphaned: true,
    verifiedAt: DateTime.utc(2026, 8, 22),
  );

  final after = await repository.getMediaById(id);
  expect(after!.isOrphaned, isTrue);
  expect(after.lastVerifiedAt, DateTime.utc(2026, 8, 22));
  expect(after.caption, before!.caption);
  expect(after.remoteUploadedAt, before.remoteUploadedAt);
  expect(after.diveId, before.diveId);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart --plain-name "markVerified"`
Expected: FAIL, "The method 'markVerified' isn't defined".

- [ ] **Step 3: Write the implementation**

```dart
  /// Writes the orphan flag and the verification stamp together, and nothing
  /// else.
  ///
  /// Deliberately NOT [updateMedia], which writes all 30 columns from the
  /// caller's snapshot. The passive reconciliation path is driven by grid
  /// tiles, whose snapshot comes from a FutureProvider that an upload's stamp
  /// write does not invalidate, so it goes stale the moment an upload
  /// completes. A full-row write from there would silently roll back
  /// `remoteUploadedAt` and anything else that changed since the tile built.
  ///
  /// Sync-visible like every other write here: callers must therefore only
  /// call it when something actually changed.
  Future<void> markVerified(
    String id, {
    required bool isOrphaned,
    required DateTime verifiedAt,
  }) async {
    try {
      _log.info('Marking media verified: $id (isOrphaned=$isOrphaned)');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
        MediaCompanion(
          isOrphaned: Value(isOrphaned),
          lastVerifiedAt: Value(verifiedAt.millisecondsSinceEpoch),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark media verified: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/repositories/media_repository_test.dart
git commit -m "feat(media): add a narrow verified-state write"
```

---

### Task 5: wire reconciliation into the serving path

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart:137-160`
- Test: `test/features/media/presentation/widgets/media_item_view_reconcile_test.dart` (create)

**Interfaces:**
- Consumes: `reconciledOrphanFlag` (Task 3), `MediaRepository.markVerified` (Task 4).
- Produces: nothing. This is the wiring task.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('a notFound resolution orphans the row once', (tester) async {
  final repository = MockMediaRepository();
  await pumpItemView(tester, repository: repository, item: healthyItem,
      resolution: const UnavailableData(kind: UnavailableKind.notFound));

  verify(() => repository.markVerified(healthyItem.id,
      isOrphaned: true, verifiedAt: any(named: 'verifiedAt'))).called(1);
});

testWidgets('a successful resolution on a healthy row writes nothing', (tester) async {
  final repository = MockMediaRepository();
  await pumpItemView(tester, repository: repository, item: healthyItem,
      resolution: BytesData(Uint8List(1)));

  verifyNever(() => repository.markVerified(any(),
      isOrphaned: any(named: 'isOrphaned'), verifiedAt: any(named: 'verifiedAt')));
});

testWidgets('a stillFetching resolution never orphans', (tester) async {
  // The availability work's own constraint: a timeout under load must not
  // permanently mark a diver's photo dead.
  final repository = MockMediaRepository();
  await pumpItemView(tester, repository: repository, item: healthyItem,
      resolution: const UnavailableData(kind: UnavailableKind.stillFetching));

  verifyNever(() => repository.markVerified(any(),
      isOrphaned: any(named: 'isOrphaned'), verifiedAt: any(named: 'verifiedAt')));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/media_item_view_reconcile_test.dart`
Expected: FAIL, `markVerified` never called.

- [ ] **Step 3: Write the implementation**

In `_resolve()`, immediately after the existing `recorder.record(...)` call and
before `return resolution;`:

```dart
    // Persist what this resolution just proved, if anything. The recorder
    // above is session-scoped and 200 entries deep, so without this the app
    // rediscovers a deleted asset on every scroll and never writes it down.
    //
    // Unawaited on purpose: this runs on the resolve path of a grid tile and
    // must not delay the frame. Errors are swallowed by markVerified's own
    // logging; a failed reconciliation is not worth failing a thumbnail over.
    final data = resolution.data;
    final desired = reconciledOrphanFlag(
      currentlyOrphaned: widget.item.isOrphaned,
      failure: data is UnavailableData ? data.kind : null,
    );
    if (desired != null) {
      unawaited(
        ref
            .read(mediaRepositoryProvider)
            .markVerified(
              widget.item.id,
              isOrphaned: desired,
              verifiedAt: DateTime.now(),
            )
            .catchError((Object _) {}),
      );
    }
```

Add `import 'dart:async';` for `unawaited` if not already present.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/media_item_view_reconcile_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Run the surrounding suites for fanout**

Run: `flutter test test/features/media/presentation/widgets/`
Expected: PASS. `MediaItemView` now reads `mediaRepositoryProvider`, so any
consumer test that pumps it without that override will fail; give those the
same mock rather than weakening the assertion.

- [ ] **Step 6: Commit**

```bash
git add lib/features/media/presentation/widgets/media_item_view.dart test/features/media/presentation/widgets/media_item_view_reconcile_test.dart
git commit -m "feat(media): persist orphan state discovered while serving a tile"
```

---

### Task 6: the all-source-types sweep

**Files:**
- Create: `lib/features/media/data/services/media_verification_sweep.dart`
- Create: `test/features/media/data/services/media_verification_sweep_test.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart:484-509`
- Modify: `lib/features/media/data/services/local_files_diagnostics_service.dart:89-122`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart`

**Interfaces:**
- Consumes: `MediaItemVerifier` (unchanged), `VerifyResult.accessDenied` (Task 2).
- Produces:
  - `Future<List<domain.MediaItem>> getAllBySourceTypes(Set<MediaSourceType>? sourceTypes)` on `MediaRepository`, returning every row when null.
  - `class SweepOutcome { final int processed; final int flipped; final int inconclusive; final int failed; }`
  - `Future<SweepOutcome> MediaVerificationSweep.run({Set<MediaSourceType>? sourceTypes})`
  - `final mediaVerificationSweepProvider = Provider<MediaVerificationSweep>(...)`

- [ ] **Step 1: Write the failing test**

```dart
test('sweeps every source type when unfiltered', () async {
  when(() => repository.getAllBySourceTypes(null))
      .thenAnswer((_) async => [galleryItem, urlItem]);
  when(() => verifier.verify(any()))
      .thenAnswer((_) async => VerifyResult.available);

  final outcome = await sweep.run();

  expect(outcome.processed, 2);
  verify(() => verifier.verify(galleryItem)).called(1);
  verify(() => verifier.verify(urlItem)).called(1);
});

test('counts accessDenied as inconclusive, not as a clean result', () async {
  // A sweep that could not read the photo library must not look like a clean
  // bill of health, or the user will trust a report that checked nothing.
  when(() => repository.getAllBySourceTypes(null))
      .thenAnswer((_) async => [galleryItem]);
  when(() => verifier.verify(galleryItem))
      .thenAnswer((_) async => VerifyResult.accessDenied);

  final outcome = await sweep.run();

  expect(outcome.inconclusive, 1);
  expect(outcome.flipped, 0);
});

test('one throwing row does not abort the sweep', () async {
  when(() => repository.getAllBySourceTypes(null))
      .thenAnswer((_) async => [galleryItem, urlItem]);
  when(() => verifier.verify(galleryItem)).thenThrow(Exception('bad row'));
  when(() => verifier.verify(urlItem))
      .thenAnswer((_) async => VerifyResult.available);

  final outcome = await sweep.run();

  expect(outcome.failed, 1);
  expect(outcome.processed, 2);
});

test('a filtered sweep asks only for those source types', () async {
  when(() => repository.getAllBySourceTypes({MediaSourceType.localFile}))
      .thenAnswer((_) async => []);

  await sweep.run(sourceTypes: {MediaSourceType.localFile});

  verify(() => repository.getAllBySourceTypes({MediaSourceType.localFile}))
      .called(1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/media_verification_sweep_test.dart`
Expected: FAIL, "Target of URI doesn't exist".

- [ ] **Step 3: Generalize the repository query**

Replace `getAllBySourceType` with a set-taking version, keeping the old name as
a delegate so existing callers and tests are untouched:

```dart
  /// Every row of the given source types, or every row when [sourceTypes] is
  /// null. Null rather than "all types" as a default so a caller cannot
  /// accidentally sweep the whole library by omitting an argument.
  Future<List<domain.MediaItem>> getAllBySourceTypes(
    Set<MediaSourceType>? sourceTypes,
  ) async {
    try {
      final query = _db.select(_db.media).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
        ),
      ]);
      if (sourceTypes != null) {
        query.where(
          _db.media.sourceType.isIn(sourceTypes.map((t) => t.name).toList()),
        );
      }
      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get media by source types', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<domain.MediaItem>> getAllBySourceType(
    MediaSourceType sourceType,
  ) => getAllBySourceTypes({sourceType});
```

- [ ] **Step 4: Write the sweep**

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// What one sweep pass found.
///
/// [inconclusive] is reported separately from [processed] on purpose: a pass
/// that could not read the photo library checked nothing, and folding those
/// rows into a success count would hand the user a clean bill of health for
/// a library nobody looked at.
class SweepOutcome {
  const SweepOutcome({
    required this.processed,
    required this.flipped,
    required this.inconclusive,
    required this.failed,
  });

  final int processed;
  final int flipped;
  final int inconclusive;
  final int failed;
}

/// Verifies media rows of any source type, dispatching through the resolver
/// registry that [MediaItemVerifier] already owns.
///
/// Reuses [MediaItemVerifier] per item rather than reimplementing the
/// persistence contract. Two implementations of "what does this result mean
/// for isOrphaned" would eventually disagree about the same row, which is
/// exactly the divergence MediaItemVerifier's own doc comment warns about.
class MediaVerificationSweep {
  MediaVerificationSweep({
    required MediaRepository repository,
    required MediaItemVerifier verifier,
  }) : _repository = repository,
       _verifier = verifier;

  final MediaRepository _repository;
  final MediaItemVerifier _verifier;
  final _log = LoggerService.forClass(MediaVerificationSweep);

  Future<SweepOutcome> run({
    Set<MediaSourceType>? sourceTypes,
    void Function(int done, int total)? onProgress,
  }) async {
    final items = await _repository.getAllBySourceTypes(sourceTypes);
    _log.info('Verification sweep starting over ${items.length} rows');
    var flipped = 0;
    var inconclusive = 0;
    var failed = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        final result = await _verifier.verify(item);
        if (result == VerifyResult.accessDenied ||
            result == VerifyResult.transientError ||
            result == VerifyResult.volumeOffline) {
          inconclusive++;
        } else if ((result != VerifyResult.available) != item.isOrphaned) {
          flipped++;
        }
      } catch (e, st) {
        failed++;
        _log.error('Verification failed for ${item.id}', error: e, stackTrace: st);
      }
      onProgress?.call(i + 1, items.length);
    }
    _log.info(
      'Verification sweep complete: ${items.length} processed, '
      '$flipped flipped, $inconclusive inconclusive, $failed failed',
    );
    return SweepOutcome(
      processed: items.length,
      flipped: flipped,
      inconclusive: inconclusive,
      failed: failed,
    );
  }
}
```

- [ ] **Step 5: Delegate `reverifyAll` to the sweep**

`LocalFilesDiagnosticsService` gains a `MediaVerificationSweep _sweep`
constructor field, and `_resolver` stays only if `androidUriUsage` still needs
it. Replace the whole `reverifyAll` body:

```dart
  /// Re-verifies every local-file row.
  ///
  /// The loop now lives in [MediaVerificationSweep], which does the same work
  /// for any source type. This stays as the Local files subsection's own
  /// entry point, and keeps returning the flipped count its snackbar shows.
  Future<int> reverifyAll() async {
    final outcome = await _sweep.run(
      sourceTypes: {MediaSourceType.localFile},
    );
    return outcome.flipped;
  }
```

Update `localFilesDiagnosticsServiceProvider` in `media_resolver_providers.dart`
to pass `sweep: ref.watch(mediaVerificationSweepProvider)`.

- [ ] **Step 6: Add the provider**

In `media_resolver_providers.dart`, beside `localFilesDiagnosticsServiceProvider`:

```dart
/// no-tick: a service rather than a cached query result.
final mediaVerificationSweepProvider = Provider<MediaVerificationSweep>(
  (ref) => MediaVerificationSweep(
    repository: ref.watch(mediaRepositoryProvider),
    verifier: ref.watch(mediaItemVerifierProvider),
  ),
);
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/media/data/`
Expected: PASS, including the untouched `local_files_diagnostics_service_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add lib/features/media test/features/media
git commit -m "feat(media): sweep every source type, not just local files"
```

---

### Task 7: the Settings action

**Files:**
- Modify: `lib/features/media/presentation/pages/media_sources_page.dart:63-100`
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Test: `test/features/media/presentation/pages/media_sources_page_test.dart`

**Interfaces:**
- Consumes: `mediaVerificationSweepProvider`, `SweepOutcome` (Task 6).
- Produces: nothing.

New keys (English; translate all 11):

```json
"settings_mediaSources_checkAll": "Check all media",
"settings_mediaSources_checkAllResult": "{count, plural, one{{count} item updated} other{{count} items updated}}",
"settings_mediaSources_checkAllBlocked": "{count, plural, one{{count} item could not be checked. Submersion cannot access your photo library.} other{{count} items could not be checked. Submersion cannot access your photo library.}}"
```

With `@` metadata entries matching the existing `settings_mediaSources_reverifyResult` shape (`"count": {"type": "int"}`).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('a blocked sweep says so instead of reporting success', (tester) async {
  when(() => sweep.run()).thenAnswer((_) async => const SweepOutcome(
      processed: 453, flipped: 0, inconclusive: 453, failed: 0));

  await pumpMediaSourcesPage(tester, sweep: sweep);
  await tester.tap(find.text('Check all media'));
  await tester.pumpAndSettle();

  expect(find.textContaining('could not be checked'), findsOneWidget);
});

testWidgets('a clean sweep reports the updated count', (tester) async {
  when(() => sweep.run()).thenAnswer((_) async => const SweepOutcome(
      processed: 453, flipped: 2, inconclusive: 0, failed: 0));

  await pumpMediaSourcesPage(tester, sweep: sweep);
  await tester.tap(find.text('Check all media'));
  await tester.pumpAndSettle();

  expect(find.text('2 items updated'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/pages/media_sources_page_test.dart`
Expected: FAIL, "Check all media" not found.

- [ ] **Step 3: Add the ARB keys**

Add all three keys plus `@` metadata to `app_en.arb`, then the translated
values to the other ten catalogs. Do not leave English in a non-English file.

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`
Then confirm all 11 catalogs carry the same key count.

- [ ] **Step 5: Add the ListTile**

After the existing re-verify `ListTile` and its `Divider`, inside the same
`Consumer`:

```dart
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(context.l10n.settings_mediaSources_checkAll),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final l10n = context.l10n;
                    final sweep = ref.read(mediaVerificationSweepProvider);
                    try {
                      final outcome = await sweep.run();
                      if (!context.mounted) return;
                      // Inconclusive wins the message. A pass that could not
                      // read the photo library checked nothing, and showing
                      // "0 items updated" would read as a clean result.
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            outcome.inconclusive > 0
                                ? l10n.settings_mediaSources_checkAllBlocked(
                                    outcome.inconclusive,
                                  )
                                : l10n.settings_mediaSources_checkAllResult(
                                    outcome.flipped,
                                  ),
                          ),
                        ),
                      );
                      ref.invalidate(localFilesDiagnosticsProvider);
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.settings_mediaSources_reverifyFailed('$e'),
                          ),
                        ),
                      );
                    }
                  },
                ),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/pages/media_sources_page_test.dart test/l10n/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/media lib/l10n test/features/media test/l10n
git commit -m "feat(settings): add a check-all-media action to Media Sources"
```

---

### Task 8: documentation corrections left by PR #1125

**Files:**
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart:219-233`
- Modify: `lib/features/media/domain/entities/media_status.dart:47-52`

No test changes. Both are comment-only corrections of statements that are now
false.

- [ ] **Step 1: Delete the orphaned doc block**

PR #1125 deleted `mediaBadgeStateProvider` but left its 15-line doc comment,
which now reads as documentation for `mediaStoresRepositoryProvider` and
describes a badge ladder that no longer exists. Delete lines 219 through 233
inclusive (through the trailing `///`), leaving
`final mediaStoresRepositoryProvider` with no doc comment or a one-line one.

- [ ] **Step 2: Correct the reachability claim**

`media_status.dart:47-52` says "The store must be REACHABLE", but
`coveredByStore` uses `backup.storeAttached`, which resolves to a single
SharedPreferences read (`media_store_providers.dart:199`). That is
"configured", not "reachable". Replace with:

```dart
  // Two conditions, both load-bearing. The store must be ATTACHED, and
  // "backed up" must be the upload pipeline's own predicate rather than
  // tier != none: a thumb-only stamp yields BackupTier.thumbOnly while
  // isBackedUp stays false, and treating that as covered would report a
  // photo as cloud-only when only its thumbnail was ever uploaded.
  //
  // Attached is deliberately weaker than REACHABLE. A real reachability
  // probe would have to build the store runtime, which this function is
  // contractually forbidden from reaching for (see mediaProvenanceProvider).
  // The residual risk is that an offline device with a configured store
  // reports a missing local file as cloudOnly rather than broken.
```

- [ ] **Step 3: Verify nothing else referenced the deleted text**

Run: `grep -rn "mediaBadgeStateProvider" lib/ test/ docs/`
Expected: no hits in `lib/` or `test/`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/media_store/presentation/providers/media_store_providers.dart lib/features/media/domain/entities/media_status.dart
git commit -m "docs(media): correct two comments left stale by the badge PR"
```

---

## Final verification

- [ ] `dart format .` leaves the tree unchanged
- [ ] `flutter analyze` reports no issues over the whole project
- [ ] `flutter test` passes with no new failures. Run the full suite TWICE: several known flakes fail alone and pass on a second run, and one green run proves nothing.
- [ ] All 11 ARB catalogs carry the same key count
- [ ] Schema unchanged: no Drift migration, no schema version bump. This plan adds no columns.
- [ ] Manual check on the reporting device: attach nothing, open the media library, confirm no badges appear while every asset resolves, then delete one gallery asset outside the app, scroll past its tile twice, and confirm it gains the broken badge and shows `is_orphaned = 1`.
