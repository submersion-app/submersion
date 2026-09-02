# Media: Attached or Absent. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every `media` row carries a dive or site link from the moment it is inserted; the Unlinked console section disappears, Missing becomes a Library filter chip with a contextual repair banner, and the network-source exemption is removed by resolving links before inserting.

**Architecture:** Creators are made to comply first (library import and network sources resolve the link before any row exists, through one shared `MediaImportReviewPage` and one shared `DiveLinkMatcher`), then the data layer drops its exemptions (`libraryLevelSourceTypes`, `retainInLibrary` writes), then the console UI loses its two sections, then the orphan sweep becomes a per-launch safety net. `NetworkFetchPipeline` gains `resolve` / `insertResolved` alongside the old `ingest` API, callers migrate one at a time, and the old API is deleted last so the tree compiles at every commit.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier / FutureProvider.family), Drift, flutter_test with in-memory `AppDatabase` (`setUpTestDatabase()`), mockito for the URL-tab mocks, `flutter gen-l10n` for the eleven ARB catalogs.

**Spec:** `docs/superpowers/specs/2026-08-23-media-attached-or-absent-design.md`

## Global Constraints

- Work only in the worktree `.claude/worktrees/media-attached-or-absent` on branch `worktree-media-attached-or-absent`. Every shell command below assumes that directory is the current one; prefix with `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-attached-or-absent &&` if the shell has reset to the main checkout (it does between calls in this environment).
- Invariant (spec section 3): after this plan, every row in `media` has `dive_id` or `site_id` non-null. No creator may insert a row without one.
- No schema version bump. `retain_in_library` stays a column; nothing writes `true` to it after Task 1.
- Never use the em-dash character (U+2014) or an en-dash as prose punctuation anywhere: code, comments, tests, ARB strings, commit messages.
- No emojis in code, comments, or docs.
- Every new or changed user-facing string goes into ALL eleven ARB catalogs: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`, then `flutter gen-l10n` is run and the generated `lib/l10n/arb/app_localizations*.dart` files are committed (CI regenerates but never verifies them).
- Each new key with placeholders gets an `"@key"` metadata block in `app_en.arb` mirroring its neighbors (see the `media_inbox_linkChip` block near line 7807 of `app_en.arb` for the shape).
- `dart format lib/ test/` must produce no changes before every commit.
- Commit after every task with the message given in that task. Do not add a Co-Authored-By line or a session URL.
- Mockito mocks (`test/**/*.mocks.dart`) are generated. After any change to `MediaRepository`'s or `NetworkFetchPipeline`'s public surface, run `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated mocks with the task.
- One full-suite run is sufficient before the PR. A lone failure in a file this branch never touched is checked against the project's known-flake list and rerun alone before being treated as a regression.

---

## File Structure

**Created**
- `lib/features/media/data/services/dive_link_matcher.dart`: loads candidate dives around a timestamp and returns a `TimestampMatch`; shared by the import review provider, the URL tab, the manifest panel, and the subscription poller.
- `lib/features/media/presentation/providers/media_import_suggestion_providers.dart`: `ImportSuggestion` + `importSuggestionProvider(DateTime)`; replaces `media_inbox_providers.dart`.
- `lib/features/media/domain/entities/import_candidate.dart`: `ImportCandidate` and `ImportReviewResult`, the review's input and output types, kept in the domain so the data-layer poller helper can use them without importing a page.
- `lib/features/media/presentation/pages/media_import_review_page.dart`: the shared pre-import review (`MediaImportReviewPage`); replaces `media_import_link_page.dart`.
- `lib/features/media/presentation/widgets/site_picker_sheet.dart`: `showSitePickerSheet`, extracted from the inbox view.
- `lib/features/media/presentation/widgets/ambiguous_dive_sheet.dart`: `showAmbiguousDiveSheet`, extracted from the inbox view.
- `lib/features/media/presentation/widgets/media_missing_banner.dart`: offline count + Repair + history, shown in the Library when the Missing chip is active.
- `lib/features/media/data/services/network_import_targets.dart`: turns resolved network media plus a target/match into `NetworkInsertRequest`s (shared by URL tab, manifest panel, poller).

**Modified**
- `lib/features/media/data/repositories/media_repository.dart`: exemption removed, `partitionForSiteUnlink`, no `retainInLibrary` writes, sweep predicate.
- `lib/features/media/data/repositories/media_library_repository.dart`: `kLibraryLevelSourceTypes` removed, `countUnlinked` removed (Task 9), health switch.
- `lib/features/media/domain/entities/media_library_filter.dart`: `MediaHealthFilter.unlinked` removed (Task 9).
- `lib/features/media/data/services/media_unlink_service.dart`: `unlinkFromSite`, `SiteUnlinkOutcome`.
- `lib/features/media/presentation/providers/site_media_providers.dart`: `unlinkMultipleMedia`.
- `lib/features/media/presentation/widgets/site_media_section.dart`, `media_selection_bar.dart`: route site unlink through the service.
- `lib/features/media/data/services/media_import_service.dart`: `importPhotosToLibrary` and the `retainInLibrary` parameter removed.
- `lib/features/media/presentation/pages/media_import_view.dart`: opens the review with assets, imports on confirm.
- `lib/features/media/data/services/network_fetch_pipeline.dart`: `resolve`, `resolveManifestEntries`, `insertResolved`; `ingest`, `ingestManifestEntries`, `_tryAutoMatch` deleted in Task 8.
- `lib/features/media/presentation/providers/url_tab_providers.dart`, `widgets/url_tab.dart`, `widgets/manifest_mode_panel.dart`, `data/services/subscription_poller.dart`: resolve-then-insert.
- `lib/features/media/presentation/widgets/media_console_scaffold.dart`, `pages/media_section_page.dart`, `widgets/media_library_filter_bar.dart`, `pages/media_library_view.dart`, `providers/media_library_providers.dart`: console changes.
- `lib/features/media_store/data/media_orphan_backlog_sweep.dart`, `lib/core/presentation/pages/startup_page.dart`: per-launch sweep.

**Deleted**
- `lib/features/media/presentation/pages/media_unlinked_inbox_view.dart`, `pages/media_missing_view.dart`, `pages/media_import_link_page.dart`, `providers/media_inbox_providers.dart`.
- `test/features/media/data/media_import_library_test.dart`, `test/features/media/presentation/media_inbox_test.dart`, `media_missing_view_test.dart`, `media_import_link_test.dart`.

---

### Task 1: Data layer drops the exemption and the retain latch

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart:1253-1262` (delete `libraryLevelSourceTypes`), `:1269-1290` (dive-deletion partition), `:1323-1345` (site-deletion partition), `:1499-1516` (`partitionForDiveUnlink`), `:1570-1595` (`unlinkFromDive`, `unlinkFromSite`, `markRetainedInLibrary`), `:1627-1645` (`getSweepableOrphanIds`)
- Modify: `lib/features/media/data/repositories/media_library_repository.dart:13-15` (delete `kLibraryLevelSourceTypes`), `:87-97` (health switch), `:177-190` (`countUnlinked`)
- Test: `test/features/media/data/media_unlink_ops_test.dart`, `test/features/media/data/media_repository_cascade_test.dart`, `test/features/media/data/media_library_repository_test.dart`, `test/features/media_store/media_orphan_backlog_sweep_test.dart`

**Interfaces:**
- Produces: `Future<({List<String> deletable, List<String> diveLinked})> MediaRepository.partitionForSiteUnlink(List<String> mediaIds)`; `MediaRepository.getSweepableOrphanIds({required DateTime olderThan})` now returns every unlinked non-signature row older than the cutoff regardless of source type or `retain_in_library`.
- Removes: `MediaRepository.libraryLevelSourceTypes`, `MediaRepository.markRetainedInLibrary`, `kLibraryLevelSourceTypes`.

- [ ] **Step 1: Rewrite the unlink-ops tests to the new contract**

Replace the body of `test/features/media/data/media_unlink_ops_test.dart` from the first `test(` to the end of `main` with:

```dart
  test('unlinkFromDive clears the FK and keeps the row', () async {
    await insertDive('d1');
    await repo.createMedia(item('m1', diveId: 'd1'));

    await repo.unlinkFromDive(['m1']);

    final m = await repo.getMediaById('m1');
    expect(m, isNotNull);
    expect(m!.diveId, isNull);
    expect(m.retainInLibrary, isFalse, reason: 'nothing latches the flag');
  });

  test('unlinkFromSite clears only the site link', () async {
    await insertDive('d1');
    await insertSite('s1');
    await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));

    await repo.unlinkFromSite(['m1']);

    final m = await repo.getMediaById('m1');
    expect(m!.siteId, isNull);
    expect(m.diveId, 'd1');
    expect(m.retainInLibrary, isFalse);
  });

  test('partitionForSiteUnlink keeps dive-linked rows, deletes the rest', () async {
    await insertDive('d1');
    await insertSite('s1');
    await repo.createMedia(item('both', diveId: 'd1', siteId: 's1'));
    await repo.createMedia(item('site-only', siteId: 's1'));

    final split = await repo.partitionForSiteUnlink(['both', 'site-only']);

    expect(split.diveLinked, ['both']);
    expect(split.deletable, ['site-only']);
  });

  test('partitionForSiteUnlink short-circuits an empty list', () async {
    final split = await repo.partitionForSiteUnlink(const []);
    expect(split.diveLinked, isEmpty);
    expect(split.deletable, isEmpty);
  });

  test('empty id lists are no-ops', () async {
    await repo.unlinkFromDive(const []);
    await repo.unlinkFromSite(const []);
  });

  test('getSweepableOrphanIds ignores a legacy retain_in_library flag', () async {
    await repo.createMedia(item('sweep-me'));
    await repo.createMedia(item('legacy-kept'));
    // A row a pre-upgrade build latched: the flag no longer protects it.
    await db.customStatement(
      'UPDATE media SET retain_in_library = 1, created_at = 0 WHERE id = ?',
      ['legacy-kept'],
    );
    await db.customStatement('UPDATE media SET created_at = 0 WHERE id = ?', [
      'sweep-me',
    ]);

    final ids = await repo.getSweepableOrphanIds(
      olderThan: DateTime(2026, 1, 1),
    );
    expect(ids.toSet(), {'sweep-me', 'legacy-kept'});
  });
}
```

- [ ] **Step 2: Update the cascade tests**

In `test/features/media/data/media_repository_cascade_test.dart`:

Replace the first test (`'partitionMediaForDiveDeletion splits doomed from unlink'`) with:

```dart
  test('partitionMediaForDiveDeletion splits doomed from unlink', () async {
    await insertDive('d1');
    await insertSite('s1');
    final doomed = await repo.createMedia(
      item('a.jpg', diveId: 'd1', hash: 'h1'), // dive-only gallery photo
    );
    final siteLinked = await repo.createMedia(
      item('b.jpg', diveId: 'd1', siteId: 's1'),
    );
    // A URL row is dive-only too now: no source type is exempt from the
    // cascade, so it dies with its dive like any other photo.
    final url = await repo.createMedia(
      item('c.jpg', diveId: 'd1', sourceType: MediaSourceType.networkUrl),
    );
    await repo.createMedia(item('other.jpg', siteId: 's1')); // unrelated row

    final split = await repo.partitionMediaForDiveDeletion(['d1']);
    expect(split.doomed.map((m) => m.id).toSet(), {doomed.id, url.id});
    expect(
      split.doomed.firstWhere((m) => m.id == doomed.id).contentHash,
      'h1',
    );
    expect(split.unlinkIds, [siteLinked.id]);
  });
```

Replace the test `'getSweepableOrphanIds honours linkage, source type, and age'` with:

```dart
  test('getSweepableOrphanIds honours linkage and age only', () async {
    await insertDive('d1');
    final orphan = await repo.createMedia(item('old.jpg'));
    // Network rows used to be exempt as "library-level" media. Every row
    // now needs a dive or site, so an unlinked network row is a sweepable
    // orphan like any other.
    final manifestOrphan = await repo.createMedia(
      item('manifest.jpg', sourceType: MediaSourceType.manifestEntry),
    );
    final urlOrphan = await repo.createMedia(
      item('url.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));

    final sweepable = await repo.getSweepableOrphanIds(olderThan: future);
    expect(sweepable.toSet(), {orphan.id, manifestOrphan.id, urlOrphan.id});
    expect(sweepable, isNot(contains(linked.id)));

    expect(await repo.getSweepableOrphanIds(olderThan: past), isEmpty);
  });
```

In the test `'partitionMediaForDiveDeletion short-circuits an empty dive list'`, change `await repo.createMedia(item('unlinked.jpg'));` to `await repo.createMedia(item('site-only.jpg', siteId: 's1'));` and add `await insertSite('s1');` before it (the fixture must not rely on an unlinked row).

- [ ] **Step 3: Update the library-repository and sweep tests**

In `test/features/media/data/media_library_repository_test.dart`:
- In the test `'mediaType, health, and dive filters compile correctly'` (around line 219), the assertion on the unlinked page currently reads `expect(unlinked.entries.map((e) => e.item.id), ['unlinked-1']);`. Change it to `expect(unlinked.entries.map((e) => e.item.id).toSet(), {'unlinked-1', 'unlinked-url-1'});` (the URL row is no longer excluded from the health facet).
- In the test `'countUnlinked excludes library-level sources and signatures'` (around line 350), rename it to `'countUnlinked excludes signatures only'` and change `expect(await repo.countUnlinked(), 1);` to `expect(await repo.countUnlinked(), 2);` (fixtures `unlinked-1` and `unlinked-url-1` both count now).
- In the test `'counts exclude legacy camelCase signatures'` (around line 383), the fixture set is the shared one plus the legacy signature, so the same two rows count: change `expect(await repo.countUnlinked(), 1);` at line 397 to `expect(await repo.countUnlinked(), 2);`.

In `test/features/media_store/media_orphan_backlog_sweep_test.dart`, in the test `'sweeps old unlinked non-library rows exactly once'`: rename it to `'sweeps every old unlinked row exactly once'`, change `expect(swept, 1);` to `expect(swept, 2);` and `expect(await repo.getMediaById(library.id), isNotNull);` to `expect(await repo.getMediaById(library.id), isNull);`. Rename the local `library` to `url` for honesty. Leave the flag assertions alone (Task 10 changes them).

- [ ] **Step 4: Run the four test files to verify they fail**

Run: `flutter test test/features/media/data/media_unlink_ops_test.dart test/features/media/data/media_repository_cascade_test.dart test/features/media/data/media_library_repository_test.dart test/features/media_store/media_orphan_backlog_sweep_test.dart`
Expected: compile error on `partitionForSiteUnlink` (undefined) and, once that is stubbed, failures on `retainInLibrary`/sweep expectations.

- [ ] **Step 5: Edit `media_repository.dart`**

Delete the `libraryLevelSourceTypes` declaration and its doc comment (lines 1253-1262).

In `partitionMediaForDiveDeletion`, replace

```dart
      final keep =
          row.siteId != null ||
          libraryLevelSourceTypes.contains(row.sourceType);
```

with `final keep = row.siteId != null;`, and update its doc comment's `unlinkIds` sentence to "`unlinkIds` survive as site-linked rows with diveId nulled".

In `partitionMediaForSiteDeletion`, replace

```dart
      final keep =
          row.diveId != null ||
          libraryLevelSourceTypes.contains(row.sourceType);
```

with `final keep = row.diveId != null;`.

In `partitionForDiveUnlink`, replace

```dart
      if (row.siteId != null ||
          libraryLevelSourceTypes.contains(row.sourceType)) {
```

with `if (row.siteId != null) {`.

Directly after `partitionForDiveUnlink`, add:

```dart
  /// Mirror of [partitionForDiveUnlink] for the site-unlink path: rows a
  /// dive still references survive with only the site link cleared, the
  /// rest leave the library.
  Future<({List<String> deletable, List<String> diveLinked})>
  partitionForSiteUnlink(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return (deletable: const <String>[], diveLinked: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.id.isIn(mediaIds))).get();
    final deletable = <String>[];
    final diveLinked = <String>[];
    for (final row in rows) {
      if (row.diveId != null) {
        diveLinked.add(row.id);
      } else {
        deletable.add(row.id);
      }
    }
    return (deletable: deletable, diveLinked: diveLinked);
  }
```

Replace the `unlinkFromDive`, `unlinkFromSite`, and `markRetainedInLibrary` members (and their doc comments) with:

```dart
  /// Clears the dive link and keeps the row. Reached from
  /// [MediaUnlinkService] for media a dive site still needs; media with no
  /// other attachment is deleted outright instead.
  ///
  /// Drops the enrichment as part of the same transaction: it was computed
  /// against the dive being left, so keeping it would leave the photo
  /// reporting that dive's depth and elapsed time from the site gallery.
  Future<void> unlinkFromDive(List<String> mediaIds) => _unlinkColumns(
    mediaIds,
    const MediaCompanion(diveId: Value(null)),
    dropEnrichment: true,
  );

  /// Same mechanic for the site link, for media a dive still needs.
  Future<void> unlinkFromSite(List<String> mediaIds) =>
      _unlinkColumns(mediaIds, const MediaCompanion(siteId: Value(null)));
```

Keep `linkMediaToSite` and `_unlinkColumns` as they are.

In `getSweepableOrphanIds`, replace the `where(...)` expression with:

```dart
        isLinkedToDiveOrSite(_db.media).not() &
            _db.media.createdAt.isSmallerThanValue(
              olderThan.millisecondsSinceEpoch,
            ),
```

and rewrite its doc comment to: "Unlinked rows older than [olderThan]. Every source type qualifies: a row with no dive and no site has no business in the library, and the age guard only exists so an insert racing this query is never caught mid-flight."

Update the `isLinkedToDiveOrSite` doc comment's last sentence to read "shared by the deletion cascades, the unlink partitions, and the orphan backlog sweep so the predicates cannot drift apart."

- [ ] **Step 6: Edit `media_library_repository.dart`**

Delete lines 13-15 (`kLibraryLevelSourceTypes` and its comment). In `_baseWhere`, replace the `unlinked` case with:

```dart
      case MediaHealthFilter.unlinked:
        where = where & m.diveId.isNull() & m.siteId.isNull();
```

In `countUnlinked`, remove the `& m.sourceType.isNotIn(kLibraryLevelSourceTypes)` clause and change its doc to "Rows attached to neither a dive nor a site, excluding signatures."

- [ ] **Step 7: Regenerate mocks, run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/features/media/data/media_unlink_ops_test.dart test/features/media/data/media_repository_cascade_test.dart test/features/media/data/media_library_repository_test.dart test/features/media_store/media_orphan_backlog_sweep_test.dart test/features/media/data/media_unlink_delete_test.dart`
Expected: all PASS.

- [ ] **Step 8: Analyze, format, commit**

Run: `flutter analyze && dart format lib/ test/`
Expected: no issues, no reformatted files.

```bash
git add lib/features/media/data/repositories test/features/media/data test/features/media_store test/**/*.mocks.dart
git commit -m "refactor(media): drop the library-level source exemption and retain latch

Every media row now needs a dive or site link, so the cascades, the
unlink partitions and the orphan sweep collapse onto one predicate."
```

---

### Task 2: Site unlink goes through MediaUnlinkService

**Files:**
- Modify: `lib/features/media/data/services/media_unlink_service.dart`
- Modify: `lib/features/media/presentation/providers/site_media_providers.dart:126-133`
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart:71-130`
- Modify: `lib/features/media/presentation/widgets/media_selection_bar.dart:53-140`
- Modify: `lib/l10n/arb/app_*.arb` (`media_siteMediaSection_unlinkSelectedContent`)
- Test: `test/features/media/data/media_unlink_delete_test.dart`, `test/features/media/presentation/widgets/site_media_section_test.dart`, `test/features/media/presentation/media_selection_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.partitionForSiteUnlink` (Task 1).
- Produces: `class SiteUnlinkOutcome { final int deleted; final int keptAsDiveMedia; }`, `Future<SiteUnlinkOutcome> MediaUnlinkService.unlinkFromSite(List<String> mediaIds)`, `Future<Set<String>> MediaUnlinkService.idsWithUserMetadataAtRiskForSite(List<String> mediaIds)`, `Future<SiteUnlinkOutcome> SiteMediaListNotifier.unlinkMultipleMedia(List<String> ids)`.

- [ ] **Step 1: Add the service tests**

Append to `main` in `test/features/media/data/media_unlink_delete_test.dart` (before the closing `}` of `main`):

```dart
  group('unlinkFromSite', () {
    test('a site-only photo is deleted from the library', () async {
      await insertSite('s1');
      final m = await repo.createMedia(item('m1', siteId: 's1'));
      final built = buildService();

      final outcome = await built.service.unlinkFromSite([m.id]);

      expect(built.deleted, [m.id]);
      expect(await repo.getMediaById(m.id), isNull);
      expect(outcome.deleted, 1);
      expect(outcome.keptAsDiveMedia, 0);
    });

    test('a dive-linked photo survives with only the site link cleared', () async {
      await insertDive('d1');
      await insertSite('s1');
      final m = await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));
      final built = buildService();

      final outcome = await built.service.unlinkFromSite([m.id]);

      expect(built.deleted, isEmpty, reason: 'a dive still needs this photo');
      final kept = await repo.getMediaById(m.id);
      expect(kept!.siteId, isNull);
      expect(kept.diveId, 'd1');
      expect(outcome.deleted, 0);
      expect(outcome.keptAsDiveMedia, 1);
    });

    test('metadata at risk is scoped to the rows the site unlink deletes', () async {
      await insertDive('d1');
      await insertSite('s1');
      final kept = await repo.createMedia(
        item('kept', diveId: 'd1', siteId: 's1', caption: 'stays'),
      );
      final gone = await repo.createMedia(
        item('gone', siteId: 's1', isFavorite: true),
      );
      final built = buildService();

      final atRisk = await built.service.idsWithUserMetadataAtRiskForSite([
        kept.id,
        gone.id,
      ]);

      expect(atRisk, {gone.id});
    });

    test('an empty list is a no-op', () async {
      final built = buildService();
      final outcome = await built.service.unlinkFromSite(const []);
      expect(outcome.deleted, 0);
      expect(outcome.keptAsDiveMedia, 0);
      expect(built.deleted, isEmpty);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_unlink_delete_test.dart`
Expected: compile error, `unlinkFromSite` undefined on `MediaUnlinkService`.

- [ ] **Step 3: Implement the service half**

In `lib/features/media/data/services/media_unlink_service.dart`, add after `UnlinkOutcome`:

```dart
/// What a site unlink did. Kept separate from [UnlinkOutcome] because the
/// carve-out runs the other way: here it is the DIVE that can still need
/// the row.
class SiteUnlinkOutcome {
  const SiteUnlinkOutcome({
    required this.deleted,
    required this.keptAsDiveMedia,
  });

  final int deleted;
  final int keptAsDiveMedia;

  int get total => deleted + keptAsDiveMedia;
}
```

Add to `MediaUnlinkService` after `idsWithUserMetadataAtRisk`:

```dart
  /// The site-scoped twin of [unlinkFromDive]: rows a dive still references
  /// keep their row with the site link cleared, everything else leaves the
  /// library through the same destructive path.
  Future<SiteUnlinkOutcome> unlinkFromSite(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const SiteUnlinkOutcome(deleted: 0, keptAsDiveMedia: 0);
    }
    final split = await repository.partitionForSiteUnlink(mediaIds);
    if (split.diveLinked.isNotEmpty) {
      await repository.unlinkFromSite(split.diveLinked);
    }
    if (split.deletable.isNotEmpty) {
      await deleteMedia(split.deletable);
    }
    return SiteUnlinkOutcome(
      deleted: split.deletable.length,
      keptAsDiveMedia: split.diveLinked.length,
    );
  }

  /// [idsWithUserMetadataAtRisk] for the site path: only rows the site
  /// unlink would delete can lose a caption or favorite.
  Future<Set<String>> idsWithUserMetadataAtRiskForSite(
    List<String> mediaIds,
  ) async {
    if (mediaIds.isEmpty) return {};
    final split = await repository.partitionForSiteUnlink(mediaIds);
    if (split.deletable.isEmpty) return {};
    return repository.idsWithUserMetadata(split.deletable);
  }
```

Update the class doc's first paragraph to say "unlink media from a dive or a site".

- [ ] **Step 4: Run the service tests**

Run: `flutter test test/features/media/data/media_unlink_delete_test.dart`
Expected: PASS.

- [ ] **Step 5: Update the site section test fake and expectations**

In `test/features/media/presentation/widgets/site_media_section_test.dart`, replace the `_RecordingSiteMediaNotifier.deleteMultipleMedia` override with:

```dart
  @override
  Future<SiteUnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    deleteCalls.add(List<String>.of(ids));
    if (failWith != null) throw failWith!;
    return SiteUnlinkOutcome(deleted: ids.length, keptAsDiveMedia: 0);
  }
```

and add `import 'package:submersion/features/media/data/services/media_unlink_service.dart';`. Rename `deleteCalls` to `unlinkCalls` throughout the file (declaration, constructor, the `unlink` group). The existing assertions on the recorded ids and the success/error snackbars stay valid.

In `test/features/media/presentation/media_selection_test.dart`, add to `_RecordingMediaRepo`:

```dart
  /// Ids the site partition should report as still needed by a dive.
  final Set<String> diveLinkedIds = {};

  @override
  Future<({List<String> deletable, List<String> diveLinked})>
  partitionForSiteUnlink(List<String> mediaIds) async => (
    deletable: [
      for (final id in mediaIds)
        if (!diveLinkedIds.contains(id)) id,
    ],
    diveLinked: [
      for (final id in mediaIds)
        if (diveLinkedIds.contains(id)) id,
    ],
  );
```

In the test `'Unlink from site appears only when a selected item has a site'`, replace the trailing comment and assertion:

```dart
      // Only the site-linked id reaches the service, and with no dive
      // holding it the row leaves the library rather than lingering
      // unlinked.
      await tester.tap(find.text('Unlink from site'));
      await tester.pumpAndSettle();
      expect(coordinator.deleted, ['b']);
      expect(mediaRepo.unlinkedFromSite, isEmpty);
```

(`coordinator` is the `_RecordingDeletionCoordinator` the host already injects via `mediaDeletionCoordinatorProvider`; if it is a local inside `host`, hoist it to a `late` at `main` scope the way `mediaRepo` is.)

- [ ] **Step 6: Run the two widget tests to verify failure**

Run: `flutter test test/features/media/presentation/widgets/site_media_section_test.dart test/features/media/presentation/media_selection_test.dart`
Expected: compile error (`unlinkMultipleMedia` undefined on `SiteMediaListNotifier`) and, for the selection test, the coordinator assertion failing.

- [ ] **Step 7: Wire the notifier and the two widgets**

In `lib/features/media/presentation/providers/site_media_providers.dart`, add to `SiteMediaListNotifier` after `deleteMultipleMedia` (add the import `package:submersion/features/media/data/services/media_unlink_service.dart` and make sure `mediaUnlinkServiceProvider` from `media_providers.dart` is imported):

```dart
  /// Unlinks from the site: rows leave the library unless a dive still
  /// needs them. Original source files are never touched. See
  /// [MediaUnlinkService].
  Future<SiteUnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    final outcome = await _ref
        .read(mediaUnlinkServiceProvider)
        .unlinkFromSite(ids);
    await refresh();
    return outcome;
  }
```

In `site_media_section.dart` `_unlinkSelected`, change `.deleteMultipleMedia(selectedIds);` to `.unlinkMultipleMedia(selectedIds);` and update the comment above `onDelete: null` to: "Unlinking removes the rows from the library unless a dive still uses them; files on disk are never touched. There is no separate delete here."

In `media_selection_bar.dart`, replace the `_diveLinkedIds` doc comment with "Ids of the selection that actually carry a dive link: the service must only see rows the action applies to.", then add after `_unlinkFromDive`:

```dart
  Future<void> _unlinkFromSite(BuildContext context, WidgetRef ref) async {
    final ids = _siteLinkedIds;
    if (ids.isEmpty) return;
    final service = ref.read(mediaUnlinkServiceProvider);

    final wouldLose = await service.idsWithUserMetadataAtRiskForSite(ids);
    if (wouldLose.isNotEmpty) {
      if (!context.mounted) return;
      final go = await confirmUnlinkDiscardsMetadata(
        context,
        count: wouldLose.length,
      );
      if (!go) return;
    }

    await service.unlinkFromSite(ids);
    ref.read(mediaSelectionProvider.notifier).clear();
  }
```

and replace the "Unlink from site" button's `onPressed` closure with `onPressed: () => _unlinkFromSite(context, ref),`.

- [ ] **Step 8: Update the site-section dialog copy in all eleven ARBs**

Change `media_siteMediaSection_unlinkSelectedContent` to:

| Locale | Value |
| --- | --- |
| en | Removes {count} items from your library, along with their cloud copies and thumbnails. Media a dive still uses is kept. Your original files are not affected. |
| de | Entfernt {count} Elemente aus Ihrer Bibliothek, einschließlich Cloud-Kopien und Vorschaubildern. Medien, die ein Tauchgang noch verwendet, bleiben erhalten. Ihre Originaldateien sind nicht betroffen. |
| es | Elimina {count} elementos de tu biblioteca, junto con sus copias en la nube y miniaturas. Los medios que un buceo todavía usa se conservan. Tus archivos originales no se ven afectados. |
| fr | Supprime {count} éléments de votre bibliothèque, ainsi que leurs copies cloud et vignettes. Les médias encore utilisés par une plongée sont conservés. Vos fichiers d'origine ne sont pas affectés. |
| it | Rimuove {count} elementi dalla libreria, insieme alle copie cloud e alle miniature. I media ancora usati da un'immersione vengono conservati. I file originali non vengono toccati. |
| nl | Verwijdert {count} items uit je bibliotheek, inclusief cloudkopieën en miniaturen. Media die een duik nog gebruikt, blijven bewaard. Je originele bestanden blijven onaangetast. |
| pt | Remove {count} itens da sua biblioteca, junto com as cópias na nuvem e miniaturas. Mídias que um mergulho ainda usa são mantidas. Seus arquivos originais não são afetados. |
| ar | يزيل {count} عنصرًا من مكتبتك مع نسخها السحابية وصورها المصغرة. تُحفظ الوسائط التي لا تزال غطسة تستخدمها. ملفاتك الأصلية لا تتأثر. |
| he | מסיר {count} פריטים מהספרייה שלך, יחד עם עותקי הענן והתמונות הממוזערות. מדיה שצלילה עדיין משתמשת בה נשמרת. הקבצים המקוריים שלך אינם מושפעים. |
| hu | Eltávolít {count} elemet a könyvtárból, a felhőmásolatokkal és bélyegképekkel együtt. A merülés által még használt médiák megmaradnak. Az eredeti fájlok nem változnak. |
| zh | 从媒体库中移除 {count} 个项目及其云端副本和缩略图。仍被潜水使用的媒体会保留。您的原始文件不受影响。 |

If the existing value for a locale has no `{count}` placeholder, add the placeholder metadata block in `app_en.arb` mirroring `media_diveMediaSection_unlinkSelectedContent`'s block.

Run: `flutter gen-l10n`

- [ ] **Step 9: Run the affected tests**

Run: `flutter test test/features/media/presentation/widgets/site_media_section_test.dart test/features/media/presentation/media_selection_test.dart test/features/media/data/media_unlink_delete_test.dart`
Expected: PASS.

- [ ] **Step 10: Analyze, format, commit**

Run: `flutter analyze && dart format lib/ test/`

```bash
git add lib/features/media lib/l10n test/features/media
git commit -m "fix(media): route site unlink through MediaUnlinkService

The site page's Unlink was a hard delete even for photos a dive still
referenced; the Library bar's left an unlinked row behind. Both now use
the same keep-or-delete partition the dive side already has."
```

---

### Task 3: Shared pre-import review page and the library import

**Files:**
- Create: `lib/features/media/data/services/dive_link_matcher.dart`
- Create: `lib/features/media/presentation/providers/media_import_suggestion_providers.dart`
- Create: `lib/features/media/presentation/widgets/site_picker_sheet.dart`
- Create: `lib/features/media/presentation/widgets/ambiguous_dive_sheet.dart`
- Create: `lib/features/media/domain/entities/import_candidate.dart`
- Create: `lib/features/media/presentation/pages/media_import_review_page.dart`
- Modify: `lib/features/media/presentation/pages/media_import_view.dart`
- Modify: `lib/features/media/data/services/media_import_service.dart:262-300` (delete `importPhotosToLibrary`), `:306` and `:356` (`retainInLibrary` parameter)
- Modify: `lib/features/media/presentation/pages/media_import_link_page.dart` (delete), `lib/features/media/presentation/pages/media_unlinked_inbox_view.dart` (switch to the extracted sheets; the view itself dies in Task 9)
- Modify: `lib/l10n/arb/app_*.arb`
- Test: create `test/features/media/data/services/dive_link_matcher_test.dart`, `test/features/media/presentation/media_import_review_test.dart`; modify `test/features/media/presentation/media_import_view_test.dart`; delete `test/features/media/data/media_import_library_test.dart`, `test/features/media/presentation/media_import_link_test.dart`

**Interfaces:**
- Produces:
  - `class DiveLinkMatcher { DiveLinkMatcher({required DiveRepository diveRepository}); static List<DiveBounds> boundsFor(List<Dive> dives); static TimestampMatch matchAgainst({required DateTime takenAt, required List<Dive> candidateDives}); Future<TimestampMatch> match(DateTime takenAt, {String? diverId}); }` (window: two days either side).
  - `class ImportSuggestion { final TimestampMatch match; final int? diveNumber; }` and `final importSuggestionProvider = FutureProvider.family<ImportSuggestion, DateTime>`.
  - `class ImportCandidate { final String key; final String title; final DateTime? takenAt; final String? error; }` and `class ImportReviewResult { final int linked; final int skipped; final Map<String, String> failures; }`, both in `lib/features/media/domain/entities/import_candidate.dart`.
  - `typedef ImportReviewConfirm = Future<ImportReviewResult> Function(Map<String, MediaAttachTarget> targets);`
  - `class MediaImportReviewPage extends ConsumerStatefulWidget { MediaImportReviewPage({required List<ImportCandidate> candidates, required ImportReviewConfirm onConfirm}); }`
  - `Future<String?> showSitePickerSheet(BuildContext context)`, `Future<String?> showAmbiguousDiveSheet(BuildContext context, List<String> candidateDiveIds)`.
  - `MediaImportView.launchOverride` is now `Future<List<AssetInfo>> Function(BuildContext)?`.
- Removes: `MediaImportService.importPhotosToLibrary`, `MediaImportLinkPage`.

- [ ] **Step 1: Write the matcher test**

Create `test/features/media/data/services/dive_link_matcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

Dive dive(String id, DateTime start, {Duration runtime = const Duration(minutes: 50), int? number}) =>
    Dive(
      id: id,
      diveNumber: number,
      dateTime: start,
      entryTime: start,
      exitTime: start.add(runtime),
    );

void main() {
  test('a timestamp inside exactly one window is confident', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9), number: 7);
    final d2 = dive('d2', DateTime(2026, 6, 12, 14));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 20),
      candidateDives: [d1, d2],
    );

    expect(match.kind, TimestampMatchKind.confident);
    expect(match.diveId, 'd1');
  });

  test('a timestamp with no window is none', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 13, 9),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.none);
  });

  test('overlapping windows are ambiguous', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));
    final d2 = dive('d2', DateTime(2026, 6, 12, 9, 30));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 40),
      candidateDives: [d1, d2],
    );

    expect(match.kind, TimestampMatchKind.ambiguous);
    expect(match.candidateDiveIds.toSet(), {'d1', 'd2'});
  });

  test('a local timestamp and a local dive compare on wall clock', () {
    // Photo timestamps arrive wall-clock-as-UTC; dive times are local.
    // Both sides are normalized the same way, so a 09:20 photo matches a
    // 09:00 dive regardless of the host's UTC offset.
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime.utc(2026, 6, 12, 9, 20),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.confident);
  });
}
```

`Dive` requires only `id` and `dateTime` (`lib/features/dive_log/domain/entities/dive.dart:179-183`); `diveNumber`, `entryTime`, and `exitTime` are optional named parameters.

- [ ] **Step 2: Run it to verify failure**

Run: `flutter test test/features/media/data/services/dive_link_matcher_test.dart`
Expected: compile error, `dive_link_matcher.dart` does not exist.

- [ ] **Step 3: Create `DiveLinkMatcher`**

Create `lib/features/media/data/services/dive_link_matcher.dart`:

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Answers "which dive was this taken on?" for one timestamp, the way every
/// creator has to before it may insert a media row.
///
/// One implementation shared by the import review, the URL tab, the
/// manifest panel and the subscription poller, so a photo gets the same
/// answer whichever door it came in through.
class DiveLinkMatcher {
  DiveLinkMatcher({
    required DiveRepository diveRepository,
    DivePhotoMatcher matcher = const DivePhotoMatcher(),
  }) : _diveRepository = diveRepository,
       _matcher = matcher;

  final DiveRepository _diveRepository;
  final DivePhotoMatcher _matcher;

  /// Candidate window either side of the timestamp. Two days covers a
  /// camera clock a day off in either direction.
  static const Duration window = Duration(days: 2);

  /// Matcher bounds for [dives]: entryTime falling back to dateTime,
  /// exitTime falling back to dateTime + effectiveRuntime, else 60 minutes.
  /// Everything is normalized to wall-clock UTC so photo timestamps (stored
  /// wall-clock-as-UTC) compare against dive times (local wall clock) on
  /// one basis.
  static List<DiveBounds> boundsFor(List<Dive> dives) {
    return [
      for (final dive in dives)
        () {
          final entry = dive.entryTime ?? dive.dateTime;
          final exit =
              dive.exitTime ??
              (dive.effectiveRuntime != null
                  ? dive.dateTime.add(dive.effectiveRuntime!)
                  : dive.dateTime.add(const Duration(minutes: 60)));
          return DiveBounds(
            diveId: dive.id,
            entryTime: TripMediaScanner.toWallClockUtc(entry),
            exitTime: TripMediaScanner.toWallClockUtc(exit),
          );
        }(),
    ];
  }

  /// Pure match of [takenAt] against [candidateDives].
  static TimestampMatch matchAgainst({
    required DateTime takenAt,
    required List<Dive> candidateDives,
    DivePhotoMatcher matcher = const DivePhotoMatcher(),
  }) {
    return matcher.matchTimestamp(
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      dives: boundsFor(candidateDives),
    );
  }

  /// Loads the dives within [window] of [takenAt] and matches against them.
  Future<TimestampMatch> match(DateTime takenAt, {String? diverId}) async {
    final dives = await _diveRepository.getDivesInRange(
      takenAt.subtract(window),
      takenAt.add(window),
      diverId: diverId,
    );
    return matchAgainst(
      takenAt: takenAt,
      candidateDives: dives,
      matcher: _matcher,
    );
  }
}
```

- [ ] **Step 4: Run the matcher test, then commit it on its own**

Run: `flutter test test/features/media/data/services/dive_link_matcher_test.dart && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib/features/media/data/services/dive_link_matcher.dart test/features/media/data/services/dive_link_matcher_test.dart
git commit -m "feat(media): add DiveLinkMatcher, the one timestamp-to-dive answer"
```

- [ ] **Step 5: Add the ARB keys the review page needs**

In every ARB catalog, add these keys (copy the translated value of the old inbox key where noted; the inbox keys themselves are deleted in Task 9):

| Key | en | Note |
| --- | --- | --- |
| `media_import_review_title` | Review import | new |
| `media_import_review_confirm` | Import {count} items | new, `count` int placeholder |
| `media_import_review_result` | {linked} linked, {skipped} skipped, {failed} failed | new, three int placeholders |
| `media_import_review_linkChip` | Link to #{number} | copy of `media_inbox_linkChip` |
| `media_import_review_linkToDive` | Link to dive | copy of `media_inbox_linkToDive` |
| `media_import_review_linkToSite` | Link to site | copy of `media_inbox_linkToSite` |
| `media_import_review_chooseDive` | Choose dive | copy of `media_inbox_chooseDive` |
| `media_import_review_chooseSite` | Choose site | new |
| `media_import_review_ambiguous` | Several dives match | new |
| `media_import_review_noMatch` | No matching dive | new |
| `media_import_review_skipped` | Not imported | new |

Translations for the new strings:

| Key | de | es | fr | it | nl |
| --- | --- | --- | --- | --- | --- |
| review_title | Import prüfen | Revisar importación | Vérifier l'import | Rivedi importazione | Import controleren |
| review_confirm | {count} Elemente importieren | Importar {count} elementos | Importer {count} éléments | Importa {count} elementi | {count} items importeren |
| review_result | {linked} verknüpft, {skipped} übersprungen, {failed} fehlgeschlagen | {linked} vinculados, {skipped} omitidos, {failed} fallidos | {linked} liés, {skipped} ignorés, {failed} en échec | {linked} collegati, {skipped} saltati, {failed} falliti | {linked} gekoppeld, {skipped} overgeslagen, {failed} mislukt |
| review_chooseSite | Tauchplatz wählen | Elegir sitio | Choisir un site | Scegli sito | Site kiezen |
| review_ambiguous | Mehrere Tauchgänge passen | Varios buceos coinciden | Plusieurs plongées correspondent | Più immersioni corrispondono | Meerdere duiken komen overeen |
| review_noMatch | Kein passender Tauchgang | Ningún buceo coincide | Aucune plongée correspondante | Nessuna immersione corrispondente | Geen overeenkomende duik |
| review_skipped | Nicht importiert | No importado | Non importé | Non importato | Niet geïmporteerd |

| Key | pt | ar | he | hu | zh |
| --- | --- | --- | --- | --- | --- |
| review_title | Revisar importação | مراجعة الاستيراد | סקירת ייבוא | Importálás ellenőrzése | 检查导入 |
| review_confirm | Importar {count} itens | استيراد {count} عنصرًا | ייבוא {count} פריטים | {count} elem importálása | 导入 {count} 个项目 |
| review_result | {linked} vinculados, {skipped} ignorados, {failed} com falha | {linked} مرتبطة، {skipped} متخطاة، {failed} فاشلة | {linked} מקושרים, {skipped} דולגו, {failed} נכשלו | {linked} összekapcsolva, {skipped} kihagyva, {failed} sikertelen | 已关联 {linked} 个，跳过 {skipped} 个，失败 {failed} 个 |
| review_chooseSite | Escolher local | اختر الموقع | בחירת אתר | Merülőhely kiválasztása | 选择潜点 |
| review_ambiguous | Vários mergulhos correspondem | تتطابق عدة غطسات | כמה צלילות תואמות | Több merülés is egyezik | 多次潜水匹配 |
| review_noMatch | Nenhum mergulho correspondente | لا توجد غطسة مطابقة | אין צלילה תואמת | Nincs egyező merülés | 没有匹配的潜水 |
| review_skipped | Não importado | لم يتم الاستيراد | לא יובא | Nincs importálva | 未导入 |

Also change `media_import_intro` in every catalog:

| Locale | Value |
| --- | --- |
| en | Photos are linked to a dive or a dive site as you import them. |
| de | Fotos werden beim Import mit einem Tauchgang oder Tauchplatz verknüpft. |
| es | Las fotos se vinculan a un buceo o a un sitio de buceo al importarlas. |
| fr | Les photos sont liées à une plongée ou à un site au moment de l'import. |
| it | Le foto vengono collegate a un'immersione o a un sito durante l'importazione. |
| nl | Foto's worden tijdens het importeren aan een duik of duiksite gekoppeld. |
| pt | As fotos são vinculadas a um mergulho ou ponto de mergulho ao importar. |
| ar | تُربط الصور بغطسة أو موقع غطس أثناء استيرادها. |
| he | תמונות מקושרות לצלילה או לאתר צלילה בעת הייבוא. |
| hu | A fotók importáláskor egy merüléshez vagy merülőhelyhez kapcsolódnak. |
| zh | 照片在导入时会关联到潜水或潜点。 |

Run: `flutter gen-l10n`

- [ ] **Step 6: Write the review page widget test**

Create `test/features/media/presentation/media_import_review_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final t1 = DateTime.utc(2026, 6, 12, 10);
final t2 = DateTime.utc(2026, 6, 12, 11);
final t3 = DateTime.utc(2026, 6, 13, 10);

ImportSuggestion confident(String diveId, int number) => ImportSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.confident, diveId: diveId),
  diveNumber: number,
);

const none = ImportSuggestion(
  match: TimestampMatch(kind: TimestampMatchKind.none),
);

const ambiguous = ImportSuggestion(
  match: TimestampMatch(
    kind: TimestampMatchKind.ambiguous,
    candidateDiveIds: ['d1', 'd2'],
  ),
);

void main() {
  Map<String, MediaAttachTarget>? confirmed;

  Widget host(
    List<ImportCandidate> candidates,
    Map<DateTime, ImportSuggestion> suggestions,
  ) {
    confirmed = null;
    return ProviderScope(
      overrides: [
        for (final MapEntry(:key, :value) in suggestions.entries)
          importSuggestionProvider(key).overrideWith((ref) async => value),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) async {
            confirmed = targets;
            return ImportReviewResult(
              linked: targets.length,
              skipped: candidates.length - targets.length,
            );
          },
        ),
      ),
    );
  }

  ImportCandidate candidate(String key, DateTime? takenAt, {String? error}) =>
      ImportCandidate(key: key, title: '$key.jpg', takenAt: takenAt, error: error);

  testWidgets('confident matches are pre-checked; the rest are not', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1), candidate('b', t2), candidate('c', t3)],
        {t1: confident('d7', 7), t2: ambiguous, t3: none},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Link to #7'), findsOneWidget);
    expect(find.text('Several dives match'), findsOneWidget);
    expect(find.text('No matching dive'), findsOneWidget);
    expect(find.text('Import 1 items'), findsOneWidget);
  });

  testWidgets('confirm hands only resolved candidates to onConfirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [candidate('a', t1), candidate('b', t3)],
        {t1: confident('d7', 7), t3: none},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 items'));
    await tester.pumpAndSettle();

    expect(confirmed, {'a': const DiveAttachTarget('d7')});
    expect(find.text('1 linked, 1 skipped, 0 failed'), findsOneWidget);
  });

  testWidgets('unchecking a confident row skips it', (tester) async {
    await tester.pumpWidget(
      host([candidate('a', t1), candidate('b', t2)], {
        t1: confident('d7', 7),
        t2: confident('d8', 8),
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Not imported'), findsOneWidget);
    expect(find.text('Import 1 items'), findsOneWidget);

    await tester.tap(find.text('Import 1 items'));
    await tester.pumpAndSettle();
    expect(confirmed, {'b': const DiveAttachTarget('d8')});
  });

  testWidgets('a failed candidate shows its error and is not imported', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([candidate('a', null, error: 'HTTP 404')], const {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('HTTP 404'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('nothing resolved disables confirm', (tester) async {
    await tester.pumpWidget(host([candidate('a', t3)], {t3: none}));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(confirmed, isNull);
  });
}
```

`DiveAttachTarget` and `SiteAttachTarget` are `Equatable` with a single positional id (`lib/features/media/domain/value_objects/media_attach_target.dart:28-55`), so map equality holds.

- [ ] **Step 7: Run to verify failure**

Run: `flutter test test/features/media/presentation/media_import_review_test.dart`
Expected: compile error, the page and provider files do not exist.

- [ ] **Step 8: Create the suggestion provider**

Create `lib/features/media/presentation/providers/media_import_suggestion_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Match verdict for one capture timestamp, plus the dive number the review
/// row shows for a confident match.
class ImportSuggestion {
  const ImportSuggestion({required this.match, this.diveNumber});

  final TimestampMatch match;
  final int? diveNumber;
}

/// Suggestion for a capture timestamp (wall-clock UTC). Keyed by the
/// timestamp rather than a media id because nothing has been inserted yet:
/// the review runs BEFORE any row exists.
///
/// Subscribes to the DIVES tick: the verdict is a join of this timestamp
/// against the dives in its window, so it goes stale when the candidate set
/// moves underneath it (a consolidation, a bulk delete, a sync pull).
final importSuggestionProvider =
    FutureProvider.family<ImportSuggestion, DateTime>((ref, takenAt) async {
      final diveRepository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final dives = await diveRepository.getDivesInRange(
        takenAt.subtract(DiveLinkMatcher.window),
        takenAt.add(DiveLinkMatcher.window),
        diverId: ref.read(currentDiverIdProvider),
      );
      final match = DiveLinkMatcher.matchAgainst(
        takenAt: takenAt,
        candidateDives: dives,
      );
      final number = match.diveId == null
          ? null
          : dives.where((d) => d.id == match.diveId).firstOrNull?.diveNumber;
      return ImportSuggestion(match: match, diveNumber: number);
    });
```

- [ ] **Step 9: Extract the two picker sheets from the inbox view**

Create `lib/features/media/presentation/widgets/site_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Lets the user pick one dive site by name. Resolves to the site id, or
/// null when dismissed.
Future<String?> showSitePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final sites = ref.watch(sitesProvider).value ?? const [];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final site in sites)
                ListTile(
                  title: Text(site.name),
                  onTap: () => Navigator.of(sheetContext).pop(site.id),
                ),
            ],
          ),
        );
      },
    ),
  );
}
```

Create `lib/features/media/presentation/widgets/ambiguous_dive_sheet.dart` by moving `_AmbiguousDiveTile` out of `media_unlinked_inbox_view.dart` (rename it `AmbiguousDiveTile`, keep its body verbatim) and adding above it:

```dart
/// Lets the user pick between the dives an ambiguous timestamp match
/// offered, closest entry first. Resolves to the dive id, or null.
Future<String?> showAmbiguousDiveSheet(
  BuildContext context,
  List<String> candidateDiveIds,
) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final id in candidateDiveIds)
            AmbiguousDiveTile(
              diveId: id,
              onTap: () => Navigator.of(sheetContext).pop(id),
            ),
        ],
      ),
    ),
  );
}
```

Then in `media_unlinked_inbox_view.dart`, replace the bodies of `_pickAndLinkSite` and `_chooseAmbiguous` to call `showSitePickerSheet(context)` and `showAmbiguousDiveSheet(context, candidateDiveIds)` respectively, delete the private `_AmbiguousDiveTile` and the now-unused imports. Run `flutter test test/features/media/presentation/media_inbox_test.dart` and confirm it still passes (it is deleted in Task 9, but must stay green until then).

- [ ] **Step 10: Create the review types and the review page**

Create `lib/features/media/domain/entities/import_candidate.dart`:

```dart
/// One thing the user is about to import, before any row exists for it.
class ImportCandidate {
  const ImportCandidate({
    required this.key,
    required this.title,
    this.takenAt,
    this.error,
  });

  /// Caller-defined identity (asset id, URL, manifest entry key).
  final String key;
  final String title;

  /// Capture timestamp as wall-clock UTC; null when unknown.
  final DateTime? takenAt;

  /// Why the candidate could not be examined (a failed fetch). Such a
  /// candidate can still be imported against an explicit target.
  final String? error;
}

/// What confirming did, for the result snackbar.
class ImportReviewResult {
  const ImportReviewResult({
    required this.linked,
    required this.skipped,
    this.failures = const {},
  });

  final int linked;
  final int skipped;
  final Map<String, String> failures;
}
```

Create `lib/features/media/presentation/pages/media_import_review_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/widgets/ambiguous_dive_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/site_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

typedef ImportReviewConfirm =
    Future<ImportReviewResult> Function(Map<String, MediaAttachTarget> targets);

/// The pre-import review: every candidate resolves to a dive, a site, or
/// "not imported" before the caller writes anything. Confident timestamp
/// matches start checked; ambiguous and unmatched candidates need a pick.
class MediaImportReviewPage extends ConsumerStatefulWidget {
  const MediaImportReviewPage({
    super.key,
    required this.candidates,
    required this.onConfirm,
  });

  final List<ImportCandidate> candidates;
  final ImportReviewConfirm onConfirm;

  @override
  ConsumerState<MediaImportReviewPage> createState() =>
      _MediaImportReviewPageState();
}

class _MediaImportReviewPageState extends ConsumerState<MediaImportReviewPage> {
  /// Explicit user decisions, keyed by candidate. A null value means "skip
  /// this one" (a confident match the user unchecked). Absent means "use
  /// the suggestion".
  final Map<String, MediaAttachTarget?> _overrides = {};
  bool _busy = false;

  ImportSuggestion? _suggestionFor(ImportCandidate c) {
    final takenAt = c.takenAt;
    if (takenAt == null) return null;
    return ref.watch(importSuggestionProvider(takenAt)).value;
  }

  MediaAttachTarget? _targetFor(ImportCandidate c, ImportSuggestion? s) {
    if (_overrides.containsKey(c.key)) return _overrides[c.key];
    final match = s?.match;
    if (match != null && match.kind == TimestampMatchKind.confident) {
      return DiveAttachTarget(match.diveId!);
    }
    return null;
  }

  Future<void> _chooseDive(ImportCandidate c, ImportSuggestion? s) async {
    final match = s?.match;
    final diveId = match != null && match.kind == TimestampMatchKind.ambiguous
        ? await showAmbiguousDiveSheet(context, match.candidateDiveIds)
        : await showDivePickerSheet(context);
    if (diveId == null || !mounted) return;
    setState(() => _overrides[c.key] = DiveAttachTarget(diveId));
  }

  Future<void> _chooseSite(ImportCandidate c) async {
    final siteId = await showSitePickerSheet(context);
    if (siteId == null || !mounted) return;
    setState(() => _overrides[c.key] = SiteAttachTarget(siteId));
  }

  void _toggle(ImportCandidate c, ImportSuggestion? s) {
    final current = _targetFor(c, s);
    setState(() {
      if (current != null) {
        _overrides[c.key] = null;
      } else if (s?.match.kind == TimestampMatchKind.confident) {
        _overrides.remove(c.key);
      }
    });
    if (current == null && s?.match.kind != TimestampMatchKind.confident) {
      _chooseDive(c, s);
    }
  }

  Future<void> _confirm(Map<String, MediaAttachTarget> targets) async {
    setState(() => _busy = true);
    final ImportReviewResult result;
    try {
      result = await widget.onConfirm(targets);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.media_import_review_result(
            result.linked,
            result.skipped,
            result.failures.length,
          ),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  String _subtitle(
    BuildContext context,
    ImportCandidate c,
    ImportSuggestion? s,
    MediaAttachTarget? target,
  ) {
    final l10n = context.l10n;
    switch (target) {
      case DiveAttachTarget():
        final number = s?.match.diveId == target.diveId ? s?.diveNumber : null;
        return number == null
            ? l10n.media_import_review_linkToDive
            : l10n.media_import_review_linkChip(number);
      case SiteAttachTarget():
        return l10n.media_import_review_linkToSite;
      case null:
        break;
    }
    if (c.error != null) return c.error!;
    if (_overrides.containsKey(c.key)) return l10n.media_import_review_skipped;
    return switch (s?.match.kind) {
      TimestampMatchKind.ambiguous => l10n.media_import_review_ambiguous,
      _ => l10n.media_import_review_noMatch,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targets = <String, MediaAttachTarget>{};
    final rows = <(ImportCandidate, ImportSuggestion?, MediaAttachTarget?)>[];
    for (final c in widget.candidates) {
      final s = _suggestionFor(c);
      final target = _targetFor(c, s);
      if (target != null) targets[c.key] = target;
      rows.add((c, s, target));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.media_import_review_title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final (c, s, target) = rows[index];
                final subtitle = _subtitle(context, c, s, target);
                return CheckboxListTile(
                  value: target != null,
                  onChanged: _busy ? null : (_) => _toggle(c, s),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    subtitle,
                    style: c.error != null && target == null
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                  secondary: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'dive') {
                        _chooseDive(c, s);
                      } else {
                        _chooseSite(c);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'dive',
                        child: Text(l10n.media_import_review_chooseDive),
                      ),
                      PopupMenuItem(
                        value: 'site',
                        child: Text(l10n.media_import_review_chooseSite),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: targets.isEmpty || _busy
                    ? null
                    : () => _confirm(targets),
                child: Text(l10n.media_import_review_confirm(targets.length)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 11: Run the review test, then commit the review page on its own**

Run: `flutter test test/features/media/presentation/media_import_review_test.dart test/features/media/presentation/media_inbox_test.dart && flutter analyze && dart format lib/ test/`
Expected: PASS, clean. (If the pattern `case DiveAttachTarget():` with field access needs `case DiveAttachTarget(:final diveId):`, adjust to that form.)

```bash
git add lib test
git commit -m "feat(media): add the shared pre-import review page

Candidates resolve to a dive, a site, or nothing before the caller
writes a row. The site and ambiguous-dive pickers move out of the inbox
so the review can reuse them."
```

- [ ] **Step 12: Rewrite the import view and its test**

Replace `test/features/media/presentation/media_import_view_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

AssetInfo asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 6, 12, 10),
  width: 100,
  height: 100,
  filename: '$id.jpg',
);

void main() {
  Widget host({
    Future<List<AssetInfo>> Function(BuildContext)? launchOverride,
  }) {
    return ProviderScope(
      overrides: [
        importSuggestionProvider(DateTime.utc(2026, 6, 12, 10)).overrideWith(
          (ref) async => const ImportSuggestion(
            match: TimestampMatch(kind: TimestampMatchKind.none),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaImportView(launchOverride: launchOverride)),
      ),
    );
  }

  testWidgets('renders intro and launch button', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      find.text('Photos are linked to a dive or a dive site as you import them.'),
      findsOneWidget,
    );
    expect(find.text('Import media...'), findsOneWideget);
  });

  testWidgets('a non-empty pick opens the review with one candidate per asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(launchOverride: (context) async => [asset('a1'), asset('a2')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();

    final page = tester.widget<MediaImportReviewPage>(
      find.byType(MediaImportReviewPage),
    );
    expect(page.candidates.map((c) => c.key), ['a1', 'a2']);
    expect(page.candidates.first.title, 'a1.jpg');
    expect(page.candidates.first.takenAt, DateTime.utc(2026, 6, 12, 10));
  });

  test('the library import window has no effective lower bound', () {
    expect(
      MediaImportView.libraryWindowStart.millisecondsSinceEpoch,
      lessThanOrEqualTo(0),
    );
  });

  testWidgets('an empty pick stays on the view', (tester) async {
    await tester.pumpWidget(host(launchOverride: (context) async => []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaImportReviewPage), findsNothing);
  });
}
```

(Fix the typo `findsOneWideget` to `findsOneWidget` when writing the file.)

Then rewrite `lib/features/media/presentation/pages/media_import_view.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Import console section: launches the three-tab picker with no dive
/// context, then hands the picked assets to [MediaImportReviewPage]. Nothing
/// is written until the user confirms, and only assets resolved to a dive or
/// a site are imported.
class MediaImportView extends ConsumerWidget {
  const MediaImportView({super.key, this.launchOverride});

  /// Test seam: returns the picked assets instead of driving the platform
  /// picker (which flutter_test cannot).
  @visibleForTesting
  final Future<List<AssetInfo>> Function(BuildContext context)? launchOverride;

  /// Lower bound of the gallery tab's date window for a dive-less import.
  ///
  /// The mobile picker turns this into a hard photo_manager
  /// `DateTimeCond(min:)`, so a "recent enough" sentinel would quietly hide
  /// everything older -- scanned film and slide libraries being exactly the
  /// media a diver back-fills. Epoch is photo_manager's own no-lower-bound
  /// value (`DateTimeCond.def()`), so it reads as unbounded to the native
  /// query rather than as an arbitrary cutoff.
  static final DateTime libraryWindowStart =
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<AssetInfo>> _pick(BuildContext context) async {
    final selected = await showPhotoPicker(
      context: context,
      diveStartTime: libraryWindowStart,
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
    );
    return selected ?? const [];
  }

  /// Imports the resolved assets, one service call per dive and per site.
  /// A failing group never blocks another; its failures ride the result.
  static Future<ImportReviewResult> importResolved(
    WidgetRef ref,
    List<AssetInfo> assets,
    Map<String, MediaAttachTarget> targets,
  ) async {
    final byId = {for (final a in assets) a.id: a};
    final byDive = <String, List<AssetInfo>>{};
    final bySite = <String, List<AssetInfo>>{};
    for (final MapEntry(:key, :value) in targets.entries) {
      final asset = byId[key];
      if (asset == null) continue;
      switch (value) {
        case DiveAttachTarget(:final diveId):
          byDive.putIfAbsent(diveId, () => []).add(asset);
        case SiteAttachTarget(:final siteId):
          bySite.putIfAbsent(siteId, () => []).add(asset);
      }
    }

    final service = ref.read(mediaImportServiceProvider);
    final diveRepository = ref.read(diveRepositoryProvider);
    var linked = 0;
    final failures = <String, String>{};
    for (final MapEntry(:key, :value) in byDive.entries) {
      final dive = await diveRepository.getDiveById(key);
      if (dive == null) {
        for (final a in value) {
          failures[a.id] = 'dive $key no longer exists';
        }
        continue;
      }
      final result = await service.importPhotosForDive(
        selectedAssets: value,
        dive: dive,
      );
      linked += result.imported.length;
      failures.addAll(result.failures);
    }
    for (final MapEntry(:key, :value) in bySite.entries) {
      final result = await service.importPhotosForSite(
        selectedAssets: value,
        siteId: key,
      );
      linked += result.imported.length;
      failures.addAll(result.failures);
    }
    return ImportReviewResult(
      linked: linked,
      skipped: assets.length - targets.length,
      failures: failures,
    );
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    final assets = await (launchOverride?.call(context) ?? _pick(context));
    if (assets.isEmpty || !context.mounted) return;
    final candidates = [
      for (final a in assets)
        ImportCandidate(
          key: a.id,
          title: a.filename ?? a.id,
          // The same value the import persists as takenAt, so the match
          // shown here is the match the row would get.
          takenAt: TripMediaScanner.toWallClockUtc(a.createDateTime),
        ),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) => importResolved(ref, assets, targets),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.media_import_intro, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(context.l10n.media_import_launch),
              onPressed: () => _launch(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
```

Keep whatever the current file has below `build` if anything beyond the column exists; the shown `build` matches the current one.

- [ ] **Step 13: Delete the old page, service method, and tests**

- Delete `lib/features/media/presentation/pages/media_import_link_page.dart`, `test/features/media/presentation/media_import_link_test.dart`, `test/features/media/data/media_import_library_test.dart`.
- In `media_import_service.dart`: delete `importPhotosToLibrary` (lines 262-300 and its doc comment); remove the `bool retainInLibrary = false,` parameter and the `retainInLibrary: retainInLibrary,` argument from `_createMediaItemFromAsset`; delete the `getAllPlatformAssetIds` / `getAllLocalPaths` repository calls only if nothing else uses them (run `grep -rn "getAllPlatformAssetIds\|getAllLocalPaths" lib` first; if only the deleted method used them, delete those repository methods and their tests too).
- Regenerate mocks: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 14: Run the import tests and analyze**

Run: `flutter test test/features/media/presentation/media_import_view_test.dart test/features/media/presentation/media_import_review_test.dart test/features/media/data/services/dive_link_matcher_test.dart test/features/media/presentation/media_inbox_test.dart test/features/media/data/services/media_import_service_test.dart && flutter analyze && dart format lib/ test/`
Expected: all PASS, analyzer clean, no reformat.

- [ ] **Step 15: Commit**

```bash
git add lib test
git commit -m "feat(media): review library imports before any row is written

The import match page now runs on the picked assets' capture dates and
imports only what resolved to a dive or a site, through the existing
per-dive and per-site import paths. importPhotosToLibrary is gone."
```

---

### Task 4: Pipeline gains resolve / insertResolved

**Files:**
- Modify: `lib/features/media/data/services/network_fetch_pipeline.dart`
- Test: `test/features/media/data/services/network_fetch_pipeline_test.dart` (append a group; the old tests keep passing until Task 8)

**Interfaces:**
- Produces:
  ```dart
  class ResolvedNetworkMedia {
    const ResolvedNetworkMedia({required this.uri, this.entry, this.result, this.failure});
    final Uri uri; final ManifestEntry? entry; final UrlExtractionResult? result; final String? failure;
    DateTime? get takenAt; bool get failed;
  }
  class NetworkInsertRequest {
    NetworkInsertRequest({required this.media, this.diveId, this.siteId}); // exactly one target, asserted
  }
  Future<List<ResolvedNetworkMedia>> NetworkFetchPipeline.resolve(List<Uri> uris);
  Future<List<ResolvedNetworkMedia>> NetworkFetchPipeline.resolveManifestEntries(List<ManifestEntry> entries);
  Future<List<String>> NetworkFetchPipeline.insertResolved(List<NetworkInsertRequest> requests, {String? subscriptionId});
  ```
- Keeps (until Task 8): `ingest`, `ingestManifestEntries`, `idle`.

- [ ] **Step 1: Append the new-API tests**

Append inside `main` of `test/features/media/data/services/network_fetch_pipeline_test.dart`:

```dart
  group('resolve / insertResolved', () {
    Future<void> insertDive(String id) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(1700000000000),
            createdAt: const Value(1700000000000),
            updatedAt: const Value(1700000000000),
          ),
        );

    test('resolve returns metadata in input order without inserting', () async {
      const a = 'https://example.com/a.jpg';
      const b = 'https://example.com/b.jpg';
      final extractor = _StubExtractor(
        results: {a: _ok(a), b: _err(b, 'HTTP 404')},
      );
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final resolved = await pipeline.resolve([Uri.parse(a), Uri.parse(b)]);

      expect(resolved.map((r) => r.uri.toString()), [a, b]);
      expect(resolved[0].takenAt, DateTime.utc(2024, 6, 1, 12));
      expect(resolved[0].failed, isFalse);
      expect(resolved[1].failed, isTrue);
      expect(resolved[1].failure, 'HTTP 404');
      expect(await db.select(db.media).get(), isEmpty);
    });

    test('a prefilled manifest entry resolves without touching the network', () async {
      final entry = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/m.jpg',
        takenAt: DateTime.utc(2024, 6, 1, 12),
        latitude: 1,
        longitude: 2,
        width: 800,
        height: 600,
      );
      final extractor = _StubExtractor(results: const {});
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final resolved = await pipeline.resolveManifestEntries([entry]);

      expect(extractor.calls, isEmpty);
      expect(resolved.single.entry, entry);
      expect(resolved.single.takenAt, entry.takenAt);
    });

    test('insertResolved writes a linked, verified row', () async {
      const url = 'https://example.com/a.jpg';
      await insertDive('d1');
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _ok(url)}),
      );
      final resolved = await pipeline.resolve([Uri.parse(url)]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ]);

      final row = await (db.select(
        db.media,
      )..where((t) => t.id.equals(ids.single))).getSingle();
      expect(row.sourceType, 'networkUrl');
      expect(row.diveId, 'd1');
      expect(row.siteId, isNull);
      expect(row.url, url);
      expect(row.width, 1024);
      expect(row.lastVerifiedAt, isNotNull);
      expect(row.isOrphaned, isFalse);
    });

    test('insertResolved on a failed fetch writes an orphaned row with diagnostics', () async {
      const url = 'https://example.com/gone.jpg';
      await insertDive('d1');
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _err(url, 'HTTP 404')}),
      );
      final resolved = await pipeline.resolve([Uri.parse(url)]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ]);

      final row = await (db.select(
        db.media,
      )..where((t) => t.id.equals(ids.single))).getSingle();
      expect(row.isOrphaned, isTrue);
      expect(row.lastVerifiedAt, isNull);
      final diag = await (db.select(
        db.mediaFetchDiagnostics,
      )..where((t) => t.mediaItemId.equals(ids.single))).getSingle();
      expect(diag.lastErrorMessage, 'HTTP 404');
    });

    test('insertResolved stamps manifest rows with subscription and entry key', () async {
      await insertDive('d1');
      final entry = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/m.jpg',
        takenAt: DateTime.utc(2024, 6, 1, 12),
        latitude: 1,
        longitude: 2,
        width: 800,
        height: 600,
        caption: 'cap',
      );
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: const {}),
      );
      final resolved = await pipeline.resolveManifestEntries([entry]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ], subscriptionId: 'sub-1');

      final row = await (db.select(
        db.media,
      )..where((t) => t.id.equals(ids.single))).getSingle();
      expect(row.sourceType, 'manifestEntry');
      expect(row.subscriptionId, 'sub-1');
      expect(row.entryKey, 'k1');
      expect(row.caption, 'cap');
      expect(row.diveId, 'd1');
    });

    test('a request needs exactly one target', () {
      final media = ResolvedNetworkMedia(uri: Uri.parse('https://e.com/a.jpg'));
      expect(() => NetworkInsertRequest(media: media), throwsAssertionError);
      expect(
        () => NetworkInsertRequest(media: media, diveId: 'd', siteId: 's'),
        throwsAssertionError,
      );
    });
  });
```

`_StubExtractor.calls` already exists in the test's stub (line 33). Add `import 'package:drift/drift.dart' show Value;` at the top of the test file for the `DivesCompanion` fixture.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/services/network_fetch_pipeline_test.dart`
Expected: compile errors on `resolve`, `ResolvedNetworkMedia`, `NetworkInsertRequest`.

- [ ] **Step 3: Implement the new API**

In `network_fetch_pipeline.dart`, add after the imports:

```dart
/// What the pipeline learned about one URL or manifest entry before any row
/// exists for it: the caller decides the link, then hands it back to
/// [NetworkFetchPipeline.insertResolved].
class ResolvedNetworkMedia {
  const ResolvedNetworkMedia({
    required this.uri,
    this.entry,
    this.result,
    this.failure,
  });

  final Uri uri;

  /// Present for manifest entries; carries the feed-supplied scalars.
  final ManifestEntry? entry;

  /// Extractor output; null when extraction was skipped (fully prefilled
  /// manifest entry) or failed.
  final UrlExtractionResult? result;

  /// Why extraction failed, when it did.
  final String? failure;

  bool get failed => failure != null;

  /// Manifest wins over extraction: the publisher knows more than EXIF.
  DateTime? get takenAt => entry?.takenAt ?? result?.takenAt;
}

/// A resolved item paired with the ONE thing that owns it. A row with
/// neither link has no business in the library, and one with both would
/// belong to a dive the site never named, so the constructor refuses both.
class NetworkInsertRequest {
  NetworkInsertRequest({required this.media, this.diveId, this.siteId})
    : assert(
        (diveId == null) != (siteId == null),
        'exactly one of diveId / siteId',
      );

  final ResolvedNetworkMedia media;
  final String? diveId;
  final String? siteId;
}
```

Add to `NetworkFetchPipeline` (after `ingestManifestEntries`):

```dart
  /// Extracts metadata for [uris] through the worker pool and per-host
  /// throttle. Writes nothing. Results come back in input order.
  Future<List<ResolvedNetworkMedia>> resolve(List<Uri> uris) {
    return Future.wait([
      for (final uri in uris) _resolveOne(_FillSpec(id: '', uri: uri)),
    ]);
  }

  /// [resolve] for manifest entries. An entry that already carries every
  /// field the extractor would populate skips the network round-trip.
  Future<List<ResolvedNetworkMedia>> resolveManifestEntries(
    List<ManifestEntry> entries,
  ) {
    return Future.wait([
      for (final entry in entries)
        _resolveOne(
          _FillSpec.fromManifest(id: '', uri: Uri.parse(entry.url), entry: entry),
        ),
    ]);
  }

  /// Inserts one row per request, already linked. A failed fetch still
  /// gets its row (orphaned, with a diagnostics record) because the caller
  /// chose a target for it; nothing here ever inserts an unlinked row.
  Future<List<String>> insertResolved(
    List<NetworkInsertRequest> requests, {
    String? subscriptionId,
  }) async {
    final ids = <String>[];
    final nowMillis = _now().millisecondsSinceEpoch;
    for (final request in requests) {
      final media = request.media;
      final entry = media.entry;
      final result = media.result;
      final id = _uuid.v4();
      await _db
          .into(_db.media)
          .insert(
            MediaCompanion.insert(
              id: id,
              filePath: '',
              fileType: Value(_fileTypeFromMediaType(entry?.mediaType)),
              sourceType: Value(entry == null ? 'networkUrl' : 'manifestEntry'),
              subscriptionId: Value(entry == null ? null : subscriptionId),
              entryKey: Value(entry?.entryKey),
              url: Value(result?.url ?? media.uri.toString()),
              diveId: Value(request.diveId),
              siteId: Value(request.siteId),
              latitude: Value(entry?.latitude ?? result?.lat),
              longitude: Value(entry?.longitude ?? result?.lon),
              takenAt: Value(media.takenAt?.millisecondsSinceEpoch),
              width: Value(entry?.width ?? result?.width),
              height: Value(entry?.height ?? result?.height),
              durationSeconds: Value(entry?.durationSeconds),
              caption: Value(entry?.caption),
              isOrphaned: Value(media.failed),
              lastVerifiedAt: Value(media.failed ? null : nowMillis),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      if (media.failed) {
        await _db
            .into(_db.mediaFetchDiagnostics)
            .insertOnConflictUpdate(
              MediaFetchDiagnosticsCompanion.insert(
                mediaItemId: id,
                lastErrorAt: Value(nowMillis),
                lastErrorMessage: Value(media.failure),
                errorCount: const Value(1),
              ),
            );
      }
      // The link is part of the row from its first synced version.
      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: nowMillis,
      );
      ids.add(id);
    }
    if (ids.isNotEmpty) SyncEventBus.notifyLocalChange();
    return ids;
  }

  /// The extraction half of [_processOne], with no database writes.
  Future<ResolvedNetworkMedia> _resolveOne(_FillSpec spec) async {
    if (spec.skipExtract) {
      return ResolvedNetworkMedia(uri: spec.uri, entry: spec.entry);
    }
    await _acquireSlot();
    try {
      final previous = _hostChain[spec.uri.host] ?? Future<void>.value();
      final completer = Completer<void>();
      _hostChain[spec.uri.host] = completer.future;
      try {
        await previous;
      } catch (_) {}
      try {
        await _waitForHostThrottle(spec.uri.host);
        _hostLastCall[spec.uri.host] = _now();
      } finally {
        completer.complete();
      }
      final result = await _extractor.extract(spec.uri);
      if (result.failure != null) {
        return ResolvedNetworkMedia(
          uri: spec.uri,
          entry: spec.entry,
          failure: result.failure,
        );
      }
      return ResolvedNetworkMedia(uri: spec.uri, entry: spec.entry, result: result);
    } catch (e) {
      return ResolvedNetworkMedia(
        uri: spec.uri,
        entry: spec.entry,
        failure: 'pipeline: $e',
      );
    } finally {
      _releaseSlot();
    }
  }
```

Give `_FillSpec` an `entry` field: add `final ManifestEntry? entry;` to the class, set `entry = null` in the URL constructor's initializer list and `entry = entry` in `fromManifest` (rename the constructor parameter to `required ManifestEntry entry` is already the case; assign `this.entry`-style through the initializer list since the class uses initializer lists). Keep the `manifest*` fields; the old `_processOne` still reads them until Task 8.

If `MediaCompanion.insert` has no `diveId` named argument in the generated code, use `diveId: Value(request.diveId)` exactly as for `siteId` (both are nullable columns on the `Media` table; `siteId: Value(siteId)` is already used at line 166).

- [ ] **Step 4: Run the pipeline tests**

Run: `flutter test test/features/media/data/services/network_fetch_pipeline_test.dart`
Expected: PASS, old and new groups.

- [ ] **Step 5: Regenerate mocks, analyze, format, commit**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && dart format lib/ test/`

```bash
git add lib/features/media/data/services/network_fetch_pipeline.dart test
git commit -m "feat(media): add resolve/insertResolved to the network pipeline

Metadata extraction and the row insert become two calls so a caller can
decide the dive or site before anything is written. The old ingest API
stays until every caller has moved."
```

---

### Task 5: Shared target resolution for network media

**Files:**
- Create: `lib/features/media/data/services/network_import_targets.dart`
- Test: create `test/features/media/data/services/network_import_targets_test.dart`

**Interfaces:**
- Consumes: `ResolvedNetworkMedia`, `NetworkInsertRequest` (Task 4); `DiveLinkMatcher` (Task 3); `MediaAttachTarget`.
- Produces:
  ```dart
  /// Forces every item onto [target] (dive or site context).
  List<NetworkInsertRequest> requestsForTarget(List<ResolvedNetworkMedia> media, MediaAttachTarget target);
  /// Builds requests from the review's decisions, keyed by uri string.
  List<NetworkInsertRequest> requestsFromReview(List<ResolvedNetworkMedia> media, Map<String, MediaAttachTarget> targets);
  /// Review candidates for resolved media, keyed by uri string.
  List<ImportCandidate> candidatesFor(List<ResolvedNetworkMedia> media, {String Function(ResolvedNetworkMedia)? title});
  /// Unattended: keeps only confident matches. Returns requests plus the skipped count.
  Future<({List<NetworkInsertRequest> requests, int skipped})> requestsForConfidentMatches(List<ResolvedNetworkMedia> media, DiveLinkMatcher matcher, {String? diverId});
  ```

- [ ] **Step 1: Write the test**

Create `test/features/media/data/services/network_import_targets_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';

class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ResolvedNetworkMedia resolved(String url, {DateTime? takenAt, String? failure}) =>
    ResolvedNetworkMedia(
      uri: Uri.parse(url),
      failure: failure,
      result: takenAt == null
          ? null
          : UrlExtractionResult(url: url, finalUrl: url, takenAt: takenAt),
    );

Dive dive(String id, DateTime start) => Dive(
  id: id,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(const Duration(minutes: 50)),
);

class _ThrowingDiveRepo implements DiveRepository {
  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async => throw StateError('dives unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final a = resolved('https://e.com/a.jpg', takenAt: DateTime.utc(2026, 6, 12, 9, 10));
  final b = resolved('https://e.com/b.jpg', takenAt: DateTime.utc(2026, 6, 13, 9, 10));
  final broken = resolved('https://e.com/c.jpg', failure: 'HTTP 404');

  test('requestsForTarget attaches everything to the dive', () {
    final requests = requestsForTarget([a, broken], const DiveAttachTarget('d1'));
    expect(requests.map((r) => r.diveId), ['d1', 'd1']);
    expect(requests.map((r) => r.siteId), [null, null]);
  });

  test('requestsForTarget attaches everything to the site', () {
    final requests = requestsForTarget([a], const SiteAttachTarget('s1'));
    expect(requests.single.siteId, 's1');
    expect(requests.single.diveId, isNull);
  });

  test('candidatesFor keys on the uri and carries takenAt and error', () {
    final candidates = candidatesFor([a, broken]);
    expect(candidates[0].key, 'https://e.com/a.jpg');
    expect(candidates[0].takenAt, DateTime.utc(2026, 6, 12, 9, 10));
    expect(candidates[1].error, 'HTTP 404');
    expect(candidates[1].takenAt, isNull);
  });

  test('requestsFromReview keeps only decided items', () {
    final requests = requestsFromReview([a, b, broken], {
      'https://e.com/a.jpg': const DiveAttachTarget('d1'),
      'https://e.com/c.jpg': const SiteAttachTarget('s1'),
    });
    expect(requests, hasLength(2));
    expect(requests[0].media, same(a));
    expect(requests[0].diveId, 'd1');
    expect(requests[1].media, same(broken));
    expect(requests[1].siteId, 's1');
  });

  test('requestsForConfidentMatches inserts confident only', () async {
    final matcher = DiveLinkMatcher(
      diveRepository: _FakeDiveRepo([dive('d1', DateTime(2026, 6, 12, 9))]),
    );

    final out = await requestsForConfidentMatches([a, b, broken], matcher);

    expect(out.requests.single.media, same(a));
    expect(out.requests.single.diveId, 'd1');
    expect(out.skipped, 2);
  });

  test('a matcher failure skips that entry instead of aborting the batch', () async {
    final matcher = DiveLinkMatcher(diveRepository: _ThrowingDiveRepo());

    final out = await requestsForConfidentMatches([a, b], matcher);

    expect(out.requests, isEmpty);
    expect(out.skipped, 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/helpers/network_import_targets_test.dart`
Expected: compile error, helper file missing.

- [ ] **Step 3: Implement the helper**

Create `lib/features/media/data/services/network_import_targets.dart`:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';

final _log = LoggerService.forClass(NetworkInsertRequest);

/// The three ways resolved network media gets its link: forced onto the
/// picker's target, decided in the review, or matched unattended.

NetworkInsertRequest _request(ResolvedNetworkMedia media, MediaAttachTarget target) {
  return switch (target) {
    DiveAttachTarget(:final diveId) => NetworkInsertRequest(
      media: media,
      diveId: diveId,
    ),
    SiteAttachTarget(:final siteId) => NetworkInsertRequest(
      media: media,
      siteId: siteId,
    ),
  };
}

/// Every item attaches to [target]: the picker was opened from a dive or a
/// site, and that is what the user is adding to.
List<NetworkInsertRequest> requestsForTarget(
  List<ResolvedNetworkMedia> media,
  MediaAttachTarget target,
) {
  return [for (final m in media) _request(m, target)];
}

/// Review rows for [media], keyed by the URI string.
List<ImportCandidate> candidatesFor(
  List<ResolvedNetworkMedia> media, {
  String Function(ResolvedNetworkMedia)? title,
}) {
  return [
    for (final m in media)
      ImportCandidate(
        key: m.uri.toString(),
        title: title?.call(m) ?? (m.entry?.caption ?? m.uri.pathSegments.lastOrNull ?? m.uri.toString()),
        takenAt: m.takenAt,
        error: m.failure,
      ),
  ];
}

/// Requests for the items the review decided on, in [media] order.
List<NetworkInsertRequest> requestsFromReview(
  List<ResolvedNetworkMedia> media,
  Map<String, MediaAttachTarget> targets,
) {
  return [
    for (final m in media)
      if (targets[m.uri.toString()] case final target?) _request(m, target),
  ];
}

/// Unattended path (subscription polling): only a confident timestamp
/// match earns a row. Everything else is skipped, not inserted, and will
/// be examined again the next time it shows up as new.
Future<({List<NetworkInsertRequest> requests, int skipped})>
requestsForConfidentMatches(
  List<ResolvedNetworkMedia> media,
  DiveLinkMatcher matcher, {
  String? diverId,
}) async {
  final requests = <NetworkInsertRequest>[];
  var skipped = 0;
  for (final m in media) {
    final takenAt = m.takenAt;
    if (m.failed || takenAt == null) {
      skipped++;
      continue;
    }
    // One entry's lookup failing must not take the whole poll down with
    // it; the entry stays absent and is examined again next time.
    final TimestampMatch match;
    try {
      match = await matcher.match(takenAt, diverId: diverId);
    } catch (e, stackTrace) {
      _log.warning(
        'Skipping ${m.uri}: dive lookup failed',
        error: e,
        stackTrace: stackTrace,
      );
      skipped++;
      continue;
    }
    if (match.kind != TimestampMatchKind.confident) {
      skipped++;
      continue;
    }
    requests.add(NetworkInsertRequest(media: m, diveId: match.diveId));
  }
  return (requests: requests, skipped: skipped);
}
```

If `LoggerService.warning` does not exist with that signature, use whichever of `warn`/`warning`/`info` the class exposes (`grep -n "void \(warn\|warning\|info\)(" lib/core/services/logger_service.dart`).

- [ ] **Step 4: Run, analyze, format, commit**

Run: `flutter test test/features/media/data/services/network_import_targets_test.dart && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib/features/media/data/services/network_import_targets.dart test/features/media/data/services/network_import_targets_test.dart
git commit -m "feat(media): shared link resolution for network imports"
```

---

### Task 6: URL tab resolves before it inserts

**Files:**
- Modify: `lib/features/media/presentation/providers/url_tab_providers.dart` (state, notifier, `networkFetchPipelineProvider`)
- Modify: `lib/features/media/presentation/widgets/url_tab.dart`
- Test: `test/features/media/presentation/widgets/url_tab_test.dart`

**Interfaces:**
- Consumes: `NetworkFetchPipeline.resolve` / `insertResolved`, `requestsForTarget`, `candidatesFor`, `requestsFromReview`, `MediaImportReviewPage`, `ImportReviewResult`.
- Produces:
  ```dart
  // UrlTabState: `autoMatchByDate` removed; `bool resolving` added (default false).
  Future<List<ResolvedNetworkMedia>> UrlTabNotifier.resolveDraft();      // parses draft lines, resolves, clears the draft, sets/clears `resolving`
  Future<List<String>> UrlTabNotifier.commitRequests(List<NetworkInsertRequest> requests); // inserts, stamps committedIds
  ```
  `UrlTabNotifier.commit({target})` is removed.

- [ ] **Step 1: Update the URL tab tests**

In `test/features/media/presentation/widgets/url_tab_test.dart`:

1. Delete the test `'autoMatchByDate checkbox is on by default'` (line 216) and, inside the `'site target'` group, the test `'hides the dive auto-match checkbox'`.
2. Replace the test `'committing calls notifier.commit and shows undo snack'` with:

```dart
  testWidgets('Add resolves the draft and inserts against the dive target', (
    tester,
  ) async {
    final resolved = ResolvedNetworkMedia(
      uri: Uri.parse('https://example.com/a.jpg'),
    );
    when(pipeline.resolve(any)).thenAnswer((_) async => [resolved]);
    when(
      pipeline.insertResolved(any, subscriptionId: anyNamed('subscriptionId')),
    ).thenAnswer((_) async => ['m1']);

    await tester.pumpWidget(
      wrap(
        const UrlTab(target: DiveAttachTarget('dive-1')),
        seed: const UrlTabState(draftLines: ['https://example.com/a.jpg']),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final requests = verify(
      pipeline.insertResolved(captureAny, subscriptionId: anyNamed('subscriptionId')),
    ).captured.single as List<NetworkInsertRequest>;
    expect(requests.single.diveId, 'dive-1');
    expect(requests.single.siteId, isNull);
    expect(find.text('Added 1 URL'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('with no target, Add opens the review page', (tester) async {
    final resolved = ResolvedNetworkMedia(
      uri: Uri.parse('https://example.com/a.jpg'),
    );
    when(pipeline.resolve(any)).thenAnswer((_) async => [resolved]);

    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(draftLines: ['https://example.com/a.jpg']),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaImportReviewPage), findsOneWidget);
    verifyNever(
      pipeline.insertResolved(any, subscriptionId: anyNamed('subscriptionId')),
    );
  });
```

3. In the test `'undo calls notifier.undoCommit(ids)'`, replace its `when(pipeline.ingest(...))` stub with the two `when(...)` stubs above (resolve returning one item, insertResolved returning `['m1']`) and give the `UrlTab` a `DiveAttachTarget('dive-1')` so Add inserts directly. Keep the undo assertions.
4. In the `'site target'` group, replace `'ingests against the site with dive matching off'` with:

```dart
    testWidgets('inserts against the site', (tester) async {
      final resolved = ResolvedNetworkMedia(
        uri: Uri.parse('https://example.com/a.jpg'),
      );
      when(pipeline.resolve(any)).thenAnswer((_) async => [resolved]);
      when(
        pipeline.insertResolved(any, subscriptionId: anyNamed('subscriptionId')),
      ).thenAnswer((_) async => ['m1']);

      await tester.pumpWidget(
        wrap(
          const UrlTab(target: SiteAttachTarget('site-1')),
          seed: const UrlTabState(draftLines: ['https://example.com/a.jpg']),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final requests = verify(
        pipeline.insertResolved(captureAny, subscriptionId: anyNamed('subscriptionId')),
      ).captured.single as List<NetworkInsertRequest>;
      expect(requests.single.siteId, 'site-1');
      expect(requests.single.diveId, isNull);
    });
```

5. Add imports for `media_import_review_page.dart`, `network_fetch_pipeline.dart` (for `ResolvedNetworkMedia` / `NetworkInsertRequest`), and `package:submersion/l10n/arb/app_localizations.dart`. Remove any `autoMatchByDate:` argument from seeded states. In `wrap`, change `MaterialApp(home: Scaffold(body: child))` to

```dart
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
```

because the review page reads `context.l10n`. The resolved fixtures above carry no `takenAt`, so the review never reads `importSuggestionProvider` and no dive repository override is needed.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/url_tab_test.dart`
Expected: compile errors (`resolve` not on the mock until regenerated; `resolving` field missing).

- [ ] **Step 3: Rework the notifier**

In `url_tab_providers.dart`:

- In `UrlTabState`: remove `autoMatchByDate` (field, constructor default, `copyWith`, `props`); add `final bool resolving;` with default `false`, in `copyWith` and `props`.
- Remove `setAutoMatchByDate`.
- Replace `commit` with:

```dart
  /// Parses each non-empty draft line and resolves the OK URIs through the
  /// pipeline: metadata only, no rows. Clears the draft so the UI returns
  /// to its blank state, and flags [UrlTabState.resolving] while the fetch
  /// runs (it used to run in the background; now the link decision waits
  /// on it).
  Future<List<ResolvedNetworkMedia>> resolveDraft() async {
    final uris = <Uri>[];
    for (final raw in state.draftLines) {
      final result = UrlValidator.parse(raw);
      if (result is UrlValidationOk) {
        uris.add(result.uri);
      }
    }
    state = state.copyWith(resolving: true);
    try {
      return await _pipeline.resolve(uris);
    } finally {
      state = state.copyWith(resolving: false, draftLines: const []);
    }
  }

  /// Inserts the decided rows and stamps [UrlTabState.committedIds] for
  /// the undo path.
  Future<List<String>> commitRequests(List<NetworkInsertRequest> requests) async {
    final ids = await _pipeline.insertResolved(requests);
    state = state.copyWith(committedIds: ids);
    return ids;
  }
```

- Update the class doc list accordingly (`resolveDraft`, `commitRequests` instead of `commit`; drop the `setAutoMatchByDate` bullet).
- In `networkFetchPipelineProvider`, delete the `diveBoundsLoader:` argument and its comment (matching now happens in the callers). Remove the now-unused `DiveBounds`/`diveRepositoryProvider` imports if nothing else in the file uses them.

- [ ] **Step 4: Rework the widget**

In `url_tab.dart`:

- Replace `_commit` with:

```dart
  Future<void> _commit() async {
    final notifier = ref.read(urlTabNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final resolved = await notifier.resolveDraft();
    if (!mounted) return;
    _multiLine.text = '';

    final target = widget.target;
    if (target != null) {
      final ids = await notifier.commitRequests(
        requestsForTarget(resolved, target),
      );
      if (!mounted) return;
      _showUndo(messenger, notifier, ids);
      return;
    }

    // No owner: every URL needs a dive or a site before it may land.
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidatesFor(resolved),
          onConfirm: (targets) async {
            final requests = requestsFromReview(resolved, targets);
            final ids = await notifier.commitRequests(requests);
            _showUndo(messenger, notifier, ids);
            return ImportReviewResult(
              linked: ids.length,
              skipped: resolved.length - requests.length,
            );
          },
        ),
      ),
    );
  }

  void _showUndo(
    ScaffoldMessengerState messenger,
    UrlTabNotifier notifier,
    List<String> ids,
  ) {
    messenger.showSnackBar(
      SnackBar(
        // TODO(media): l10n, pluralization
        content: Text('Added ${ids.length} URL${ids.length == 1 ? '' : 's'}'),
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => notifier.undoCommit(ids),
        ),
      ),
    );
  }
```

- Delete the `if (!_isSiteSession) Row(... Checkbox ...)` block and the `_isSiteSession` getter.
- Change the Add button to show progress while resolving:

```dart
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canCommit && !state.resolving ? _commit : null,
          child: state.resolving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // TODO(media): l10n
              : const Text('Add'),
        ),
      ),
```

- Update the `target` doc comment on `UrlTab`: "A [DiveAttachTarget] attaches every added URL to that dive and a [SiteAttachTarget] to that site. With no target, the resolved URLs go through [MediaImportReviewPage] so each one is given a dive or a site before it is inserted."
- Add imports: `package:submersion/features/media/presentation/pages/media_import_review_page.dart`, `package:submersion/features/media/domain/entities/import_candidate.dart`, `package:submersion/features/media/data/services/network_import_targets.dart`.

- [ ] **Step 5: Regenerate mocks and run**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/media/presentation/widgets/url_tab_test.dart test/features/media/presentation/providers/`
Expected: PASS. If a provider test under `test/features/media/presentation/providers/` referenced `setAutoMatchByDate` or `commit(`, update it to `resolveDraft` / `commitRequests` with the same stubs as Step 1.

- [ ] **Step 6: Analyze, format, commit**

Run: `flutter analyze && dart format lib/ test/`

```bash
git add lib test
git commit -m "feat(media): URL tab resolves metadata before inserting

A URL added from a dive now attaches to that dive; from a site, to the
site; with no owner it goes through the import review. The auto-match
checkbox is gone because the review shows the match instead."
```

---

### Task 7: Manifest import and polling insert linked rows only

**Files:**
- Modify: `lib/features/media/presentation/widgets/manifest_mode_panel.dart:89-135`
- Modify: `lib/features/media/data/services/subscription_poller.dart:60-75` (constructor), `:160-230` (`_applyDiff`)
- Modify: the provider that builds `SubscriptionPoller` (`grep -rn "SubscriptionPoller(" lib` to find it; it lives beside `subscriptionPollerProvider`)
- Test: `test/features/media/data/services/subscription_poller_test.dart`; create `test/features/media/presentation/widgets/manifest_mode_panel_import_test.dart`

**Interfaces:**
- Consumes: `resolveManifestEntries`, `insertResolved`, `requestsForConfidentMatches`, `candidatesFor`, `requestsFromReview`, `MediaImportReviewPage`.
- Produces: `SubscriptionPoller({required subscriptions, required mediaRepo, required fetchService, required pipeline, required DiveLinkMatcher diveLinkMatcher})`.

- [ ] **Step 1: Update the poller test**

In `test/features/media/data/services/subscription_poller_test.dart`:

- Add imports for `dive_link_matcher.dart`, `dive_repository_impl.dart`, and `dive.dart`, and a fake:

```dart
class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _dive(String id, DateTime start) => Dive(
  id: id,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(const Duration(minutes: 50)),
);
```

- In `setUp`, insert a dive row `d1` at `2024-06-01 12:00 UTC` into `db.dives` (the FK needs a real row) and build the matcher: `matcher = DiveLinkMatcher(diveRepository: _FakeDiveRepo([_dive('d1', DateTime.utc(2024, 6, 1, 11, 50))]));`. Every `SubscriptionPoller(` construction in the file gets `diveLinkMatcher: matcher`.
- The fixture `_entry` defaults `takenAt` to `2024-06-01 12:00 UTC`, inside `d1`'s window, so the existing `'success: new entries are inserted and queued in pipeline'` test keeps its row count; add to its assertions `expect(rows.every((r) => r.diveId == 'd1'), isTrue);` where `rows` is whatever it already reads back.
- Add a new test:

```dart
  test('an entry with no confident dive is skipped and retried next poll', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
      isActive: true,
    );
    final unmatched = _entry(
      'k-far',
      'https://feed.example.com/far.jpg',
      takenAt: DateTime.utc(2024, 9, 1, 12),
    );
    final fetcher = _StaticFetcher({
      sub.manifestUrl: ManifestFetchSuccess(parsed: _parsed([unmatched])),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
      diveLinkMatcher: matcher,
    );

    await poller.pollNow(sub.id, DateTime.utc(2024, 9, 2));
    expect(await mediaRepo.getAllBySubscription(sub.id), isEmpty);

    // The dive gets logged later; the next poll picks the entry up.
    final later = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
      diveLinkMatcher: DiveLinkMatcher(
        diveRepository: _FakeDiveRepo([
          _dive('d1', DateTime.utc(2024, 9, 1, 11, 50)),
        ]),
      ),
    );
    await later.pollNow(sub.id, DateTime.utc(2024, 9, 3));
    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows.single.entryKey, 'k-far');
    expect(rows.single.diveId, 'd1');
  });
```

Match the `createSubscription` argument names to what the existing tests in the file use.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/services/subscription_poller_test.dart`
Expected: compile error, `diveLinkMatcher` is not a parameter.

- [ ] **Step 3: Rework the poller**

In `subscription_poller.dart`:

- Add `required this.diveLinkMatcher,` to the constructor and `final DiveLinkMatcher diveLinkMatcher;` beside `pipeline`; import `package:submersion/features/media/data/services/dive_link_matcher.dart` and `package:submersion/features/media/data/services/network_import_targets.dart`.
- Replace the final block of `_applyDiff` (from `// Hand the freshly-introduced entries to the pipeline.` to the end of the method) with:

```dart
    // Fresh entries are resolved first and inserted only against a
    // confident dive match: nobody is here to pick a dive, and a row with
    // no dive has no place in the library. Anything skipped is still absent
    // from the DB, so the next poll sees it as new and tries again.
    if (newEntries.isNotEmpty) {
      final resolved = await pipeline.resolveManifestEntries(newEntries);
      final decided = await requestsForConfidentMatches(resolved, diveLinkMatcher);
      final ids = await pipeline.insertResolved(
        decided.requests,
        subscriptionId: sub.id,
      );
      _log.info(
        'Polled ${sub.id} at ${now.toIso8601String()}: '
        '${ids.length} new entries inserted, ${decided.skipped} skipped '
        '(no confident dive)',
      );
    }
```

- Update the class doc bullet that says "new `entryKey`s -> hand to [NetworkFetchPipeline.ingestManifestEntries]" to "new `entryKey`s -> resolve, match, insert the confident ones".
- Find the provider constructing the poller (`grep -rn "SubscriptionPoller(" lib`) and pass `diveLinkMatcher: DiveLinkMatcher(diveRepository: ref.watch(diveRepositoryProvider))`.

- [ ] **Step 4: Run the poller test**

Run: `flutter test test/features/media/data/services/subscription_poller_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the manifest panel import test**

Create `test/features/media/presentation/widgets/manifest_mode_panel_import_test.dart`. The seeded-notifier and stub-fetcher pattern is copied from `manifest_mode_panel_test.dart:28-52`; the pipeline is a hand-rolled fake so no mock generation is needed:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_mode_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _SeededManifestTabNotifier extends ManifestTabNotifier {
  _SeededManifestTabNotifier(ManifestTabState seed, {required super.fetchService}) {
    state = seed;
  }
}

class _StubFetcher implements ManifestFetchService {
  const _StubFetcher();

  @override
  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async => const ManifestFetchSuccess(
    parsed: ManifestParseResult(format: ManifestFormat.json, entries: []),
  );

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Resolves every entry as-is and records what gets inserted.
class _FakePipeline implements NetworkFetchPipeline {
  final List<List<NetworkInsertRequest>> inserted = [];

  @override
  Future<List<ResolvedNetworkMedia>> resolveManifestEntries(
    List<ManifestEntry> entries,
  ) async => [
    for (final e in entries)
      ResolvedNetworkMedia(uri: Uri.parse(e.url), entry: e),
  ];

  @override
  Future<List<String>> insertResolved(
    List<NetworkInsertRequest> requests, {
    String? subscriptionId,
  }) async {
    inserted.add(requests);
    return [for (var i = 0; i < requests.length; i++) 'm$i'];
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  // No takenAt: the review shows "No matching dive" and never touches a
  // dive repository, which keeps this test free of that provider.
  const entry = ManifestEntry(entryKey: 'k1', url: 'https://feed.example.com/a.jpg');

  Widget host(_FakePipeline pipeline) {
    const stub = _StubFetcher();
    return ProviderScope(
      overrides: [
        manifestFetchServiceProvider.overrideWithValue(stub),
        networkFetchPipelineProvider.overrideWithValue(pipeline),
        manifestTabProvider.overrideWith(
          (ref) => _SeededManifestTabNotifier(
            const ManifestTabShowingPreview(
              url: 'https://feed.example.com/m.json',
              result: ManifestParseResult(
                format: ManifestFormat.json,
                entries: [entry],
              ),
            ),
            fetchService: stub,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ManifestModePanel()),
      ),
    );
  }

  testWidgets('Import opens the review and inserts nothing until confirmed', (
    tester,
  ) async {
    final pipeline = _FakePipeline();
    await tester.pumpWidget(host(pipeline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaImportReviewPage), findsOneWidget);
    expect(find.text('No matching dive'), findsOneWidget);
    expect(pipeline.inserted, isEmpty);
  });
}
```

If `ManifestModePanel`'s Import button text differs from `'Import'`, read `manifest_preview_pane.dart` for the exact label. `ManifestEntry` has a `const` constructor (`manifest_entry.dart:50`).

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/manifest_mode_panel_import_test.dart`
Expected: FAIL, the panel still calls `ingestManifestEntries` and no review page appears.

- [ ] **Step 7: Rework the panel commit**

In `manifest_mode_panel.dart`, replace `_commit` with:

```dart
  /// Triggered by the Import button. Resolves the entries, lets the user
  /// give each one a dive or a site in [MediaImportReviewPage], and only
  /// then creates the subscription row and inserts the decided entries.
  Future<void> _commit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String? committedSubscriptionId;
    List<String>? committedMediaIds;
    bool subscriptionPersisted = false;

    await ref
        .read(manifestTabProvider.notifier)
        .commit(
          onCommit: (preview) async {
            final pipeline = ref.read(networkFetchPipelineProvider);
            final resolved = await pipeline.resolveManifestEntries(
              preview.result.entries,
            );
            if (!mounted) return;
            await navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => MediaImportReviewPage(
                  candidates: candidatesFor(resolved),
                  onConfirm: (targets) async {
                    final subRepo = ref.read(
                      manifestSubscriptionRepositoryProvider,
                    );
                    final format =
                        preview.formatOverride ?? preview.result.format;
                    // Every commit creates a subscription row because the
                    // pipeline keys manifest rows on it (the partial unique
                    // index on `(subscription_id, entry_key)`). Subscribe off
                    // means an inert `isActive: false` row that Undo removes.
                    final created = await subRepo.createSubscription(
                      manifestUrl: preview.url,
                      format: format,
                      pollIntervalSeconds: preview.pollIntervalSeconds,
                      isActive: preview.subscribe,
                    );
                    subscriptionPersisted = preview.subscribe;
                    committedSubscriptionId = created.id;
                    final requests = requestsFromReview(resolved, targets);
                    final ids = await pipeline.insertResolved(
                      requests,
                      subscriptionId: created.id,
                    );
                    committedMediaIds = ids;
                    return ImportReviewResult(
                      linked: ids.length,
                      skipped: resolved.length - requests.length,
                    );
                  },
                ),
              ),
            );
          },
        );

    if (!mounted) return;
    final ids = committedMediaIds;
    final subId = committedSubscriptionId;
    if (ids == null || subId == null) {
      // Cancelled in the review, or the fetch failed: nothing was created.
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        // TODO(media): l10n, pluralization
        content: Text(
          'Imported ${ids.length} entr${ids.length == 1 ? 'y' : 'ies'}',
        ),
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => _undoCommit(
            mediaIds: ids,
            subscriptionId: subId,
            deleteSubscription: !subscriptionPersisted,
          ),
        ),
      ),
    );
  }
```

Add imports for `package:submersion/features/media/presentation/pages/media_import_review_page.dart`, `package:submersion/features/media/domain/entities/import_candidate.dart`, and `package:submersion/features/media/data/services/network_import_targets.dart`. `_undoCommit` is unchanged.

- [ ] **Step 8: Run, regenerate mocks, analyze, format, commit**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/media/presentation/widgets/manifest_mode_panel_import_test.dart test/features/media/data/services/subscription_poller_test.dart test/features/media/presentation/widgets/url_tab_test.dart && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib test
git commit -m "feat(media): manifest import and polling insert linked rows only

One-shot imports go through the review; the unattended poller inserts
only confident matches and re-examines skipped entries on the next poll."
```

---

### Task 8: Delete the old pipeline API

**Files:**
- Modify: `lib/features/media/data/services/network_fetch_pipeline.dart`
- Test: `test/features/media/data/services/network_fetch_pipeline_test.dart`

- [ ] **Step 1: Confirm nothing calls the old API**

Run: `grep -rn "\.ingest(\|ingestManifestEntries\|diveBoundsLoader\|\.idle()" lib test --include="*.dart" | grep -v "network_fetch_pipeline"`
Expected: no matches in `lib/`; only the old pipeline tests in `test/`.

- [ ] **Step 2: Prune the tests**

In `network_fetch_pipeline_test.dart`, delete every test that calls `ingest(` or `ingestManifestEntries(` and the whole `group('auto-match', ...)`. Re-express the two behaviors worth keeping against `resolve`:

```dart
  test('resolve respects the 4-concurrent fan-out', () async {
    final urls = [for (var i = 0; i < 8; i++) 'https://h$i.example.com/a.jpg'];
    final gates = {for (final u in urls) u: Completer<void>()};
    var active = 0;
    var peak = 0;
    final extractor = _StubExtractor(
      results: {for (final u in urls) u: _ok(u)},
      gates: gates,
      onCall: (_) {
        active++;
        if (active > peak) peak = active;
      },
    );
    final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

    final pending = pipeline.resolve([for (final u in urls) Uri.parse(u)]);
    await Future<void>.delayed(Duration.zero);
    expect(peak, 4);
    for (final g in gates.values) {
      active--;
      g.complete();
    }
    final resolved = await pending;
    expect(resolved, hasLength(8));
  });

  test('resolve throttles the same host to one call per 250ms', () async {
    var now = DateTime.utc(2024, 1, 1);
    final calls = <DateTime>[];
    const a = 'https://same.example.com/a.jpg';
    const b = 'https://same.example.com/b.jpg';
    final extractor = _StubExtractor(
      results: {a: _ok(a), b: _ok(b)},
      onCall: (_) => calls.add(now),
    );
    final pipeline = NetworkFetchPipeline(
      db: db,
      extractor: extractor,
      now: () => now,
    );

    final pending = pipeline.resolve([Uri.parse(a), Uri.parse(b)]);
    // Let the first call start, then advance the clock so the second
    // clears the throttle window.
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(milliseconds: 300));
    await pending;

    expect(calls, hasLength(2));
    expect(calls[1].difference(calls[0]), greaterThanOrEqualTo(const Duration(milliseconds: 250)));
  });
```

Adapt to the way the existing concurrency and throttle tests drive the fake clock and gates (lines 208-295); keep their mechanics, change the entry point to `resolve`.

- [ ] **Step 3: Delete the implementation**

In `network_fetch_pipeline.dart` delete: `ingest`, `ingestManifestEntries`, `idle`, `_scheduleFill`, `_runFill`, `_processOne`, `_patchSuccess`, `_markVerifiedNoExtract`, `_tryAutoMatch`, `_markFailed`, the `_running` list, the `_diveBoundsLoader` / `_matcher` fields and constructor parameters, and the `autoMatch` field of `_FillSpec` (and its constructor parameters). Remove the `DivePhotoMatcher` import. Rewrite the file header comment: drop the "Adapted from plan" deviations list and describe the two-step contract: "`resolve` extracts metadata through a bounded worker pool with a per-host throttle and writes nothing; `insertResolved` inserts rows that already carry their dive or site link."

- [ ] **Step 4: Regenerate mocks, run, analyze, format, commit**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/media/data/services/ test/features/media/presentation/widgets/url_tab_test.dart && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib test
git commit -m "refactor(media): remove insert-first ingest from the network pipeline"
```

---

### Task 9: Console: Unlinked gone, Missing becomes a Library chip

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart:15-22,47-64`
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_filter_bar.dart` (add the chip)
- Create: `lib/features/media/presentation/widgets/media_missing_banner.dart`
- Modify: `lib/features/media/presentation/pages/media_library_view.dart` (banner)
- Modify: `lib/features/media/presentation/providers/media_library_providers.dart:179-184` (delete `unlinkedCountProvider`; add `missingOfflineCountProvider`)
- Modify: `lib/features/media/domain/entities/media_library_filter.dart:5-7`
- Modify: `lib/features/media/data/repositories/media_library_repository.dart` (`countUnlinked`, health switch)
- Delete: `lib/features/media/presentation/pages/media_unlinked_inbox_view.dart`, `pages/media_missing_view.dart`, `providers/media_inbox_providers.dart`
- Modify: `lib/l10n/arb/app_*.arb`
- Test: modify `test/features/media/presentation/media_console_scaffold_test.dart`, `media_section_page_test.dart`, `media_library_filter_bar_test.dart`, `media_library_providers_test.dart`, `test/features/media/domain/media_library_filter_json_test.dart`, `test/features/media/data/media_library_repository_test.dart`; create `test/features/media/presentation/widgets/media_missing_banner_test.dart`; delete `media_inbox_test.dart`, `media_missing_view_test.dart`

**Interfaces:**
- Produces: `enum MediaConsoleSection { library, sources, transfers, importMedia }`; `enum MediaHealthFilter { missing }`; `final missingOfflineCountProvider = FutureProvider<int>` (in `media_library_providers.dart`, reading `mediaLibraryNotifierProvider`); `class MediaMissingBanner extends ConsumerWidget { const MediaMissingBanner({required bool isEmpty}); }`.
- Removes: `MediaConsoleSection.unlinked`, `.missing`; `unlinkedCountProvider`; `MediaLibraryRepository.countUnlinked`; `media_console_unlinked`, `media_console_missing`, `media_inbox_*`, `media_import_staysUnlinked` ARB keys.

- [ ] **Step 1: Write the banner and chip tests**

Create `test/features/media/presentation/widgets/media_missing_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_missing_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({required bool isEmpty, int offline = 0}) {
    return ProviderScope(
      overrides: [
        missingOfflineCountProvider.overrideWith((ref) async => offline),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaMissingBanner(isEmpty: isEmpty)),
      ),
    );
  }

  testWidgets('history stays reachable with nothing missing', (tester) async {
    await tester.pumpWidget(host(isEmpty: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Repair...'), findsNothing);
  });

  testWidgets('missing rows get the Repair entry point', (tester) async {
    await tester.pumpWidget(host(isEmpty: false));
    await tester.pumpAndSettle();
    expect(find.text('Repair...'), findsOneWidget);
  });

  testWidgets('offline volumes are reported', (tester) async {
    await tester.pumpWidget(host(isEmpty: false, offline: 2));
    await tester.pumpAndSettle();
    expect(find.text('2 on offline volumes'), findsOneWidget);
  });
}
```

Append to `test/features/media/presentation/media_library_filter_bar_test.dart` inside `main` (add the override `missingCountProvider.overrideWith((ref) async => 3)` to `host()`):

```dart
  testWidgets('Missing files chip toggles the health filter and shows the count', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Missing files (3)'), findsOneWidget);
    await tester.tap(find.text('Missing files (3)'));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(mediaLibraryFilterProvider).health,
      MediaHealthFilter.missing,
    );

    await tester.tap(find.text('Missing files (3)'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(mediaLibraryFilterProvider).health, isNull);
  });
```

In `test/features/media/presentation/media_console_scaffold_test.dart`, add:

```dart
  testWidgets('the console has exactly four destinations', (tester) async {
    expect(MediaConsoleSection.values, [
      MediaConsoleSection.library,
      MediaConsoleSection.sources,
      MediaConsoleSection.transfers,
      MediaConsoleSection.importMedia,
    ]);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/media_missing_banner_test.dart test/features/media/presentation/media_library_filter_bar_test.dart test/features/media/presentation/media_console_scaffold_test.dart`
Expected: compile error (banner missing), chip not found, enum mismatch.

- [ ] **Step 3: ARB changes**

In all eleven catalogs: delete `media_console_unlinked`, `media_console_missing`, `media_inbox_chooseDive`, `media_inbox_empty`, `media_inbox_keep`, `media_inbox_linkChip`, `media_inbox_linkToDive`, `media_inbox_linkToSite`, `media_import_staysUnlinked`, `media_import_linkTitle`, `media_import_linkConfirm`, `media_import_linkedResult` (and their `@` metadata in `app_en.arb`). Add:

| Key | en | de | es | fr | it | nl |
| --- | --- | --- | --- | --- | --- | --- |
| `media_library_filter_missing` | Missing files | Fehlende Dateien | Archivos faltantes | Fichiers manquants | File mancanti | Ontbrekende bestanden |
| `media_library_filter_missingCount` | Missing files ({count}) | Fehlende Dateien ({count}) | Archivos faltantes ({count}) | Fichiers manquants ({count}) | File mancanti ({count}) | Ontbrekende bestanden ({count}) |

| Key | pt | ar | he | hu | zh |
| --- | --- | --- | --- | --- | --- |
| `media_library_filter_missing` | Arquivos ausentes | ملفات مفقودة | קבצים חסרים | Hiányzó fájlok | 缺失的文件 |
| `media_library_filter_missingCount` | Arquivos ausentes ({count}) | ملفات مفقودة ({count}) | קבצים חסרים ({count}) | Hiányzó fájlok ({count}) | 缺失的文件（{count}） |

`media_library_filter_missingCount` gets an int `count` placeholder block. Keep `media_missing_empty`, `media_missing_offlineVolumes`, `media_missing_repair`, `media_repairHistory_title`.

Run: `flutter gen-l10n`

- [ ] **Step 4: Providers and repository**

In `media_library_providers.dart`, delete `unlinkedCountProvider` and add after `missingCountProvider`:

```dart
/// Of the rows currently shown by the Missing filter, how many sit on
/// unmounted volumes (informational: those are offline, not broken, and
/// the repair wizard skips them). One probe per mount root per pass.
final missingOfflineCountProvider = FutureProvider<int>((ref) async {
  final state = ref.watch(mediaLibraryNotifierProvider);
  final isOnline = VolumeStatus().newPassProbe();
  var offline = 0;
  for (final entry in state.entries) {
    if (!entry.item.isOrphaned) continue;
    final path = entry.item.localPath ?? entry.item.filePath;
    if (path == null || path.isEmpty) continue;
    if (!await isOnline(path)) offline++;
  }
  return offline;
});
```

with `import 'package:submersion/features/media/data/services/volume_status.dart';`.

In `media_library_repository.dart`: delete `countUnlinked` and the `MediaHealthFilter.unlinked` case. In `media_library_filter.dart`: `enum MediaHealthFilter { missing }` with doc "Library health facet: rows whose backing file is missing (persisted orphan flag)."

Delete `media_inbox_providers.dart`, `media_unlinked_inbox_view.dart`, `media_missing_view.dart`, `test/features/media/presentation/media_inbox_test.dart`, `media_missing_view_test.dart`.

- [ ] **Step 5: Scaffold, section page, banner, filter bar, library view**

`media_console_scaffold.dart`: enum becomes `library, sources, transfers, importMedia`; remove the two `_label` and `_icon` arms.

`media_section_page.dart`: drop `unlinkedCount`, the two `MediaConsoleSection.unlinked/missing` switch arms, the inbox and missing view imports; badge map becomes `{MediaConsoleSection.library: missingCount}`.

Create `media_missing_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_history_view.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_wizard_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the Library while the Missing files chip is active: the
/// offline-volume count, the repair wizard, and the repair history.
class MediaMissingBanner extends ConsumerWidget {
  const MediaMissingBanner({super.key, required this.isEmpty});

  /// Whether the filtered list has nothing in it. The wizard needs rows;
  /// the history is exactly what the user checks when there are none.
  final bool isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(missingOfflineCountProvider).value ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (offline > 0)
            Expanded(
              child: Text(
                context.l10n.media_missing_offlineVolumes(offline),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            const Spacer(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: context.l10n.media_repairHistory_title,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MediaRepairHistoryView(),
              ),
            ),
          ),
          if (!isEmpty)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.build_outlined),
              label: Text(context.l10n.media_missing_repair),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MediaRepairWizardPage(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

In `media_library_filter_bar.dart` `build`, add `final missingCount = ref.watch(missingCountProvider).value ?? 0;` and insert after the dates chip (before the `if (!filter.isEmpty)` block):

```dart
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.warning_amber_outlined, size: 18),
            label: Text(
              missingCount == 0
                  ? context.l10n.media_library_filter_missing
                  : context.l10n.media_library_filter_missingCount(missingCount),
            ),
            selected: filter.health == MediaHealthFilter.missing,
            onSelected: (on) => _update(
              ref,
              (f) => f.copyWith(health: on ? MediaHealthFilter.missing : null),
            ),
          ),
```

Update the class doc to list "missing files" among the chips.

In `media_library_view.dart` `build`, insert between the filter-bar `Padding` and the `Expanded(child: _buildBody(...))`:

```dart
        if (ref.watch(mediaLibraryFilterProvider).health ==
            MediaHealthFilter.missing)
          MediaMissingBanner(isEmpty: state.entries.isEmpty),
```

and, in `_buildBody`, make the empty state say `media_missing_empty` when the health filter is active:

```dart
    if (state.entries.isEmpty) {
      final missing =
          ref.watch(mediaLibraryFilterProvider).health ==
          MediaHealthFilter.missing;
      return Center(
        child: Text(
          missing
              ? context.l10n.media_missing_empty
              : context.l10n.media_library_empty,
        ),
      );
    }
```

- [ ] **Step 6: Fix the remaining test references**

- `media_library_providers_test.dart`: delete the `countUnlinked` override (line 52) and the `unlinkedCountProvider` assertion (line 172).
- `media_library_filter_json_test.dart`: replace every `MediaHealthFilter.unlinked` with `MediaHealthFilter.missing`; keep the test that decodes `'health': 'exploded'` to null and add one more expectation in it: `expect(MediaLibraryFilter.fromJson({'health': 'unlinked'}).health, isNull, reason: 'an album saved before the facet was removed degrades to no constraint');`.
- `media_library_repository_test.dart`: delete the two `countUnlinked` tests and, in `'mediaType, health, and dive filters compile correctly'`, remove the unlinked-page assertion block (keep the missing/mediaType/dive parts).
- `media_section_page_test.dart`: if it overrides `unlinkedCountProvider` or `missingViewProvider`, remove those overrides.
- `test/architecture/repository_tick_stream_test.dart:165`: update the comment to name `missingCountProvider` only.
- Run `grep -rn "unlinkedCountProvider\|MediaHealthFilter.unlinked\|countUnlinked\|media_inbox_\|MediaUnlinkedInboxView\|MediaMissingView\|missingViewProvider\|media_import_link_page\|inboxSuggestionProvider" lib test --include="*.dart"` and fix any leftover.

- [ ] **Step 7: Run the console tests, analyze, format, commit**

Run: `flutter test test/features/media/presentation test/features/media/domain test/features/media/data/media_library_repository_test.dart test/architecture && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib test
git commit -m "feat(media): fold Unlinked and Missing into the Library

Unlinked media no longer exists, so its inbox goes. Missing files become
a Library filter chip with the repair tools in a banner above the grid,
and the Library entry carries the missing-count badge."
```

---

### Task 10: Orphan sweep runs every launch

**Files:**
- Modify: `lib/features/media_store/data/media_orphan_backlog_sweep.dart`
- Modify: `lib/core/presentation/pages/startup_page.dart:676-700` (comment and call)
- Test: `test/features/media_store/media_orphan_backlog_sweep_test.dart`

**Interfaces:**
- Produces: `Future<int> MediaOrphanBacklogSweep.run({DateTime? now})`; constructor loses `prefs`; `flagKey` removed.

- [ ] **Step 1: Rewrite the sweep test**

Replace the two tests in `media_orphan_backlog_sweep_test.dart` with (keep the fixtures; drop the `SharedPreferences` import, the `prefs:` argument, `_ThrowingMediaRepository` stays):

```dart
  test('sweeps every old unlinked row on each run', () async {
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    final orphan = await repo.createMedia(
      item('orphan.jpg', hash: 'h1', uploadedAt: DateTime(2026, 2)),
    );
    final url = await repo.createMedia(
      item('url.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    expect(await sweep.run(now: sweepTime), 2);
    expect(await repo.getMediaById(orphan.id), isNull);
    expect(await repo.getMediaById(url.id), isNull);
    expect(await repo.getMediaById(linked.id), isNotNull);
    final entry = (await queue.allForTesting()).single;
    expect(entry.direction, 'delete');
    expect(entry.contentHash, 'h1');

    // A second run is idempotent on a clean library.
    expect(await sweep.run(now: sweepTime), 0);

    // A row that arrives later (a peer that has not upgraded yet can still
    // sync one in) is caught on a later launch once it is old enough.
    final late = await repo.createMedia(item('late-orphan.jpg'));
    expect(await sweep.run(now: sweepTime), 1);
    expect(await repo.getMediaById(late.id), isNull);
  });

  test('a row younger than the age guard is left alone', () async {
    await repo.createMedia(item('fresh.jpg'));
    expect(await sweep.run(now: DateTime.now()), 0);
  });

  test('a repository failure propagates', () async {
    final broken = MediaOrphanBacklogSweep(
      mediaRepository: _ThrowingMediaRepository(),
      coordinator: MediaDeletionCoordinator(
        mediaRepository: repo,
        queue: () => queue,
      ),
    );
    await expectLater(broken.run(now: sweepTime), throwsStateError);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media_store/media_orphan_backlog_sweep_test.dart`
Expected: compile error, `run` undefined / `prefs` required.

- [ ] **Step 3: Rewrite the sweep**

Replace `media_orphan_backlog_sweep.dart` with:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';

/// Removes unlinked media rows: originally the one-time backlog left by the
/// old FK SET NULL cascade, now the safety net behind the rule that every
/// row carries a dive or site link from its insert.
///
/// Runs on every launch rather than once behind a flag. The query is one
/// indexed SELECT that is empty on a healthy library, and a device that has
/// not upgraded yet can still sync an unlinked row in; a per-launch pass
/// removes it the next day instead of never. Rows younger than 24 hours are
/// left alone so an insert racing this query is never caught mid-flight.
///
/// Runs through the repository layer, not a schema migration: tombstones
/// need the live sync clock, and the coordinator's enqueue-before-delete
/// path needs the transfer queue. Every step is idempotent.
class MediaOrphanBacklogSweep {
  MediaOrphanBacklogSweep({
    required MediaRepository mediaRepository,
    required MediaDeletionCoordinator coordinator,
  }) : _mediaRepository = mediaRepository,
       _coordinator = coordinator;

  static const Duration ageGuard = Duration(hours: 24);

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _coordinator;
  final _log = LoggerService.forClass(MediaOrphanBacklogSweep);

  /// Returns the number of rows swept. Throws on repository failure so the
  /// caller can log it; the next launch simply runs again.
  Future<int> run({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(ageGuard);
    final ids = await _mediaRepository.getSweepableOrphanIds(olderThan: cutoff);
    if (ids.isNotEmpty) {
      _log.info('Sweeping ${ids.length} unlinked media rows');
      await _coordinator.deleteMultipleMedia(ids);
    }
    return ids.length;
  }
}
```

In `startup_page.dart`: remove `prefs: SharedPreferences.getInstance,` from the construction, change `await sweep.runIfNeeded();` to `await sweep.run();`, and replace the comment block above it with:

```dart
    // Unlinked-media sweep, every launch. Fire-and-forget: it must not delay
    // first frame and runs against the now-open databases. Empty on a
    // healthy library; catches anything a not-yet-upgraded peer syncs in.
```

Remove the `shared_preferences` import from `startup_page.dart` only if nothing else in the file uses it (`grep -n "SharedPreferences" lib/core/presentation/pages/startup_page.dart`).

- [ ] **Step 4: Run, analyze, format, commit**

Run: `flutter test test/features/media_store/ && flutter analyze && dart format lib/ test/`
Expected: PASS, clean.

```bash
git add lib test
git commit -m "feat(media): run the unlinked-media sweep on every launch

With every creator linking at insert, the sweep is a safety net rather
than a one-time backlog fix, and a per-launch pass also cleans up rows a
not-yet-upgraded peer syncs in."
```

---

### Task 11: Whole-tree verification and hand-off

**Files:**
- Modify: `docs/superpowers/specs/2026-08-23-media-attached-or-absent-design.md` (status line only)

- [ ] **Step 1: Leftover symbol scan**

Run: `grep -rn "retainInLibrary: Value(true)\|markRetainedInLibrary\|libraryLevelSourceTypes\|kLibraryLevelSourceTypes\|importPhotosToLibrary\|MediaHealthFilter.unlinked\|unlinkedCountProvider\|MediaConsoleSection.unlinked\|MediaConsoleSection.missing\|ingestManifestEntries\|_tryAutoMatch\|autoMatchByDate" lib test --include="*.dart"`
Expected: no matches.

Run: `git diff origin/main...HEAD -U0 -- . ':(exclude)lib/l10n/arb/app_localizations*' ':(exclude)*.mocks.dart' | grep '^+' | grep -v '^+++' | LC_ALL=C grep -n $'\xe2\x80\x94\|\xe2\x80\x93' | head` (the two byte sequences are the em-dash and en-dash characters, spelled out so the plan itself contains neither)
Expected: no lines introduced by this branch (compare against `git diff origin/main --stat` scope; pre-existing dashes in untouched lines are fine).

- [ ] **Step 2: Format, analyze, full suite**

Run: `dart format lib/ test/ && flutter analyze`
Expected: no changes, no issues.

Run: `flutter test 2>&1 | tail -5`
Expected: the summary line shows zero failures. A lone failure in a file this branch never touched should be checked against the flake list in the project memory (`weight_planner` "planned lead is a total", `sync_replace_library`, `settings_load_zone_escape`) and rerun alone before being treated as a regression.

- [ ] **Step 3: Update the spec status and commit**

Change the spec's `**Status:**` line to `approved 2026-08-23, implemented on this branch`.

```bash
git add docs/superpowers/specs/2026-08-23-media-attached-or-absent-design.md
git commit -m "docs(media): mark attached-or-absent spec implemented"
```

- [ ] **Step 4: Push and open the PR**

Run: `git push -u origin worktree-media-attached-or-absent`

Open a PR against `main` titled `feat(media): every media row is attached to a dive or site` whose body summarizes: the invariant; Unlinked section removed and Missing as a Library chip with a repair banner; library import, URL tab, manifest import and polling resolve links before inserting; site unlink routed through the unlink service (fixing a hard delete of dive-linked photos); per-launch sweep; no schema bump; the twelve ARB keys removed and thirteen added across eleven catalogs. Do not include any generated-with attribution or session link in the body.
