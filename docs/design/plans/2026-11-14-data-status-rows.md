# Data status rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settings > Data shows each feature's status once (symbol, name, sentence), and every problem item on the feature pages carries the same mark, which is the only status colour there.

**Architecture:** `FeatureHealth` keeps today's headline and gains `findings` (every problem found) and `subjectId` (a library or account id). `pickHealth` attaches the candidates as findings, so most evaluators get them for free. One shared `HealthMarkedTitle` widget looks a row's reasons up in its feature's findings and draws the 16 dp `HealthSymbol` beside the title.

**Tech Stack:** Flutter, Riverpod (`lib/core/providers/provider.dart`), Equatable, flutter_test.

**Spec:** `docs/design/specs/2026-11-14-data-status-rows-design.md`

## Global Constraints

- Issue #4561, release v1.8.5.
- No new ARB strings; every sentence and level label already exists.
- Colours only through `HealthSymbol` (shared `StatusColors`); live-state icons keep glyph and text, lose colour.
- Every existing evaluator test keeps its assertions (constructor arguments may change).
- Files under the 800-line guard; new widget in its own file.
- No em dashes anywhere; no emojis; imports grouped dart, flutter, packages, local.
- `dart format .`, `flutter analyze`, affected tests and `test/architecture/` before each commit. Never the whole suite.

## Review Focus

1. Backups off while the cloud copy needs sign-in: headline stays `backupCloudSignIn`, and both the auto row and the Copy row are marked (test in Task 2 and Task 7).
2. One library failing and another holding edits: each tile gets its own level; the headline is unchanged (Task 3, Task 9).
3. Media store runtime still loading (`photosStoreReachableProvider` is null): no unreachable finding, never a false amber (Task 4).
4. Photos off with only Lightroom connected: the Data row shows the hollow dash and its "off" sentence with Set up, not a green tick (Task 6).
5. Narrow phone at large text: Sign in again moves under the sentence in its Data row (Task 6).

---

### Task 1: Findings in the health model

**Files:**
- Modify: `lib/features/settings/domain/data_health/feature_health.dart`
- Modify: `lib/features/settings/presentation/widgets/data_health/health_text.dart`
- Test: `test/features/settings/domain/data_health/feature_health_test.dart` (create)

**Interfaces:**
- Produces: `FeatureHealth({..., String? subjectId, List<FeatureHealth> findings = const []})`, both in `props`; `FeatureHealth copyWith({HealthLevel? level, HealthReason? reason, DateTime? when, int? count, String? name, String? subjectId, List<FeatureHealth>? findings})`; `HealthReason.mediaStoreUnreachable`; `FeatureHealth? findingFor(FeatureHealth health, Set<HealthReason> reasons, {String? subjectId})`.
- `pickHealth(feature, candidates)` returns the same headline as today with `findings: candidates`. Healthy (no candidates) has no findings.

- [ ] **Step 1: Write the failing tests**

```dart
test('pickHealth keeps the headline and lists every candidate', () {
  final a = FeatureHealth(feature: DataFeature.sync, level: HealthLevel.attention, reason: HealthReason.syncAutoOff);
  final b = FeatureHealth(feature: DataFeature.sync, level: HealthLevel.failing, reason: HealthReason.syncFailed);
  final h = pickHealth(DataFeature.sync, [a, b]);
  expect(h.reason, HealthReason.syncFailed);
  expect(h.findings, [a, b]);
});
test('healthy has no findings', () => expect(pickHealth(DataFeature.sync, []).findings, isEmpty));
test('findingFor picks the most severe matching reason', ...); // reasons {syncAutoOff, syncFailed} -> syncFailed
test('findingFor with subjectId matches only that subject', ...); // two librariesFailed findings 'a','b'; subjectId 'b' -> the 'b' one; 'c' -> null
test('findingFor ignores reasons not asked for', ...); // -> null
```

Add to the existing `health_text` coverage (or the new file): `healthReasonText` for `mediaStoreUnreachable` with `name: 'B2'` equals `l10n.settings_photos_status_unreachable('B2')`, and with no name equals `l10n.settings_photos_status_pausedUnreachable`.

- [ ] **Step 2: Run** `flutter test test/features/settings/domain/data_health/feature_health_test.dart`. Expected: FAIL (no `findings`).
- [ ] **Step 3: Implement** the interfaces above. `findingFor` keeps the first finding of the highest severity. Add the `mediaStoreUnreachable` arm to `healthReasonText`.
- [ ] **Step 4: Run** the new test and `test/features/settings/domain/data_health/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): health keeps every finding beside its headline`.

### Task 2: Backup findings

**Files:**
- Modify: `lib/features/settings/domain/data_health/backup_health.dart`, `lib/features/settings/presentation/providers/data_health_providers.dart` (`backupHealthProvider`)
- Test: `test/features/settings/domain/data_health/backup_health_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces: `BackupHealthInputs.extraCopyMissingIds` (`List<String>`, default `const []`); the provider passes `settings.lastExtraCopyMissingIds`.

Rules (spec section 1):
- Copy findings: cloud copy missing (when not `copySignIn`), one `backupExtraCopyMissing` per id in `extraCopyMissingIds` with `subjectId` = that id (one finding without a subject when the bool is set and the list is empty), no copy off this device. Same conditions as today.
- Auto off: findings = `[if copySignIn backupCloudSignIn, backupAutoOff, ...copy findings]`; headline = first of them (unchanged: cloud sign-in, else auto off). No failed, overdue or never findings.
- Auto on: today's candidate list, with the extra copy entry expanded per id, through `pickHealth`.

- [ ] **Step 1: Write the failing tests**: auto off plus no off-device copy gives headline `backupAutoOff` and findings reasons `[backupAutoOff, backupNoOffDeviceCopy]`; auto off with a never-run schedule has no `backupNever` finding; auto off with `copySignIn` gives headline `backupCloudSignIn` and findings containing both `backupCloudSignIn` and `backupAutoOff`; `extraCopyMissingIds: ['x', 'y']` gives two `backupExtraCopyMissing` findings with subjects `x` and `y`.
- [ ] **Step 2: Run** `flutter test test/features/settings/domain/data_health/backup_health_test.dart`. Expected: new tests FAIL, old ones pass.
- [ ] **Step 3: Implement** the rules in `evaluateBackupHealth`, and pass the ids in `backupHealthProvider`.
- [ ] **Step 4: Run** the backup health test and `test/features/settings/presentation/providers/data_health_providers_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): backup health reports every finding`.

### Task 3: Sync and library findings

**Files:**
- Modify: `lib/features/settings/domain/data_health/sync_health.dart`, `lib/features/settings/domain/data_health/shared_library_health.dart`, `lib/features/settings/presentation/providers/data_health_providers.dart` (`libraryHealthInputsProvider` passes `id: l.id`)
- Test: `sync_health_test.dart`, `shared_library_health_test.dart` (same folder as above)

**Interfaces:**
- Produces: `LibraryHealthInput.id` (`String`, required). Library findings: one per failed library (`librariesFailed`, `name`, `subjectId: id`) then one per library holding edits (`librariesEditsHeld`, same), in input order. Headline exactly as today, with those findings attached.
- Sync: candidates already go through `pickHealth`; the `syncOff` early return carries `findings: [itself]`; custom folder has none.

- [ ] **Step 1: Write the failing tests**: sync with auto off and conflicts lists both; sync off lists `syncOff`; libraries `a` failed and `b` holding edits give headline `librariesFailed` (`count` 1, name `a`) and findings `[failed a, held b]` with subjects `a`, `b`.
- [ ] **Step 2: Run** both tests. Expected: new tests FAIL (update existing `LibraryHealthInput(...)` calls with an `id` first).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both tests plus `data_health_providers_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): sync and library health report every finding`.

### Task 4: Media findings and the unreachable store

**Files:**
- Modify: `lib/features/settings/domain/data_health/media_health.dart`, `lib/features/settings/presentation/providers/data_health_providers.dart` (`countMediaSetupItems`, `mediaHealthInputsProvider`)
- Test: `media_health_test.dart`, `data_health_providers_test.dart`

**Interfaces:**
- Produces: `MediaHealthInputs({..., required int storeSetupItems, int lightroomSetupItems = 0, bool storeUnreachable = false, String? storeLabel})` with `int get mediaSetupItems => storeSetupItems + lightroomSetupItems` (the not-set-up check reads it unchanged); constants `mediaSetupStore = 'store'`, `mediaSetupLightroom = 'lightroom'` in `media_health.dart`; `({int store, int lightroom}) countMediaSetupItems(List<PendingSetupItem>)` (an account sign-in that names media storage counts as store, Lightroom only as lightroom).
- Candidates, in order: finish setup for the store (`subjectId: mediaSetupStore`) when `storeSetupItems > 0`, for Lightroom (`mediaSetupLightroom`) when `lightroomSetupItems > 0`, transfers paused, then `mediaStoreUnreachable` (attention, `name: storeLabel`) when `storeAttachedHere && storeUnreachable`.
- Provider: `storeUnreachable: attached && ref.watch(photosStoreReachableProvider) == false`; `storeLabel` is the label `PhotosStatusLine` shows (`photosCopiesProvider`'s `label`). Not attached: neither provider is watched.

- [ ] **Step 1: Write the failing tests**: store and Lightroom items give two finish setup findings with the two subjects and headline finish setup; attached and unreachable gives `mediaStoreUnreachable` with the label; not attached and unreachable gives no finding; a provider test where `photosStoreReachableProvider` is overridden to null (loading) gives no unreachable finding; `countMediaSetupItems` splits a Lightroom sign-in from a store attach.
- [ ] **Step 2: Run** both tests. Expected: FAIL.
- [ ] **Step 3: Implement**; update existing `mediaSetupItems:` constructor calls to `storeSetupItems:`.
- [ ] **Step 4: Run** both tests and `data_row_status_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): an unreachable photo store needs attention`.

### Task 5: The shared mark

**Files:**
- Create: `lib/features/settings/presentation/widgets/data_health/health_marked_title.dart`
- Modify: `data_health_providers.dart` (add `healthProviderOf`)
- Test: `test/features/settings/presentation/widgets/data_health/health_marked_title_test.dart`

**Interfaces:**
- Produces: `ProviderListenable<FeatureHealth> healthProviderOf(DataFeature feature)` (backup, sync, sharedLibraries, media providers); `HealthMarkedTitle({Key? key, required Widget title, required DataFeature feature, required Set<HealthReason> reasons, String? subjectId})`, a `ConsumerWidget`. No match: returns `title` alone. Match: `Row(children: [Flexible(child: title), SizedBox(width: 8), HealthSymbol(level: f.level, size: 16, semanticLabel: '<level label>, <reason sentence>')])`.

- [ ] **Step 1: Write the failing tests** (override `backupHealthProvider`): no finding shows only the title; a `backupAutoOff` finding shows a `HealthSymbol` with level attention and semantics label `'${healthLevelLabel(l10n, HealthLevel.attention)}, ${l10n.dataHealth_backup_autoOff}'`; a subject-scoped mark ignores another subject's finding.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): a shared health mark for feature page items`.

### Task 6: Settings > Data rows become the status

**Files:**
- Modify: `lib/features/settings/presentation/widgets/data_row_tile.dart`, `lib/features/settings/presentation/pages/data_section_content.dart`
- Delete: `lib/features/settings/presentation/widgets/data_health/data_health_strip.dart`, `test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart`
- Test: `data_row_tile_test.dart`, `data_section_content_test.dart`, `test/features/settings/presentation/widgets/accounts/sign_in_again_test.dart` (move its strip cases to the row)

**Interfaces:**
- `DataRowTile`: `health` becomes `HealthLevel? healthLevel`; adds `Widget? statusAction`. Enabled with a level: leading is `HealthSymbol(level, size: 24, semanticLabel: healthLevelLabel(...))`, title has no mark. Disabled or no level: leading is `Icon(icon)` as today. `statusAction` sits beside the subtitle while `constraints.maxWidth / textScale >= 300`, under it otherwise (the attention line's rule).
- `DataSectionContent.feature()`: level is `HealthLevel.notSetUp` when `!status.showsHealthMark`, else the health's level. Attention or failing: subtitle `healthReasonText(...)`; otherwise `dataRowStatusText(...)`. `statusAction` is `SignInAgainButton` when `offersSignInAgain(h)`. The strip is removed; order above the rows: Set up card (not in demo), facts line, divider.

- [ ] **Step 1: Write the failing tests**: no `DataHealthStrip` and no `dataHealth_attentionLine` on the page; a failing backup row has a leading `HealthSymbol` (failing) and subtitle `dataHealth_backup_failed(...)`; a signed-out sync row shows `SignInAgainButton` inside the row; at width 320 with text scale 2 the button sits under the sentence; photos off shows `HealthSymbol` with `HealthLevel.notSetUp` and the Set up action; demo mode shows the feature icons and no symbols.
- [ ] **Step 2: Run** `data_row_tile_test.dart` and `data_section_content_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**, delete the strip and its test, and move the Sign in again cases.
- [ ] **Step 4: Run** the three tests plus `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): Data rows carry each feature's status once`.

### Task 7: Backup page marks

**Files:**
- Modify: `lib/features/backup/presentation/widgets/backup_status_line.dart`, `backup_auto_row.dart`, `backup_copy_row.dart`, `backup_extra_copy_rows.dart` (same folder)
- Test: `test/features/backup/presentation/widgets/backup_status_line_test.dart`, `backup_extra_copy_rows_test.dart`, and `backup_auto_row_test.dart`, `backup_copy_row_test.dart` (create if missing)

**Interfaces:**
- Consumes: `HealthMarkedTitle` (Task 5), reasons per the spec's table.
- Status line: reasons `{backupFailed, backupOverdue, backupNever}`; the sign-in branch moves out; icon keeps `error_outline` on failure but has no colour.
- Auto row: `{backupAutoOff}`. Copy row: `{backupCloudCopyMissing, backupCloudSignIn, backupNoOffDeviceCopy}`; when the backup findings hold `backupCloudSignIn`, its subtitle adds `healthReasonText` for that finding and a `SignInAgainButton(feature: DataFeature.backup)`. Extra tile: `{backupExtraCopyMissing}` with `subjectId: account.accountId`.

- [ ] **Step 1: Write the failing tests**: auto off marks the auto row; cloud sign-in puts the sentence and button in the Copy row and not in the status line (Review Focus 1); missed id `x` marks tile `backup-extra-copy-x` only; a failed backup's status line icon has no colour (`Icon.color` null) and its title carries a failing mark.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/backup/presentation/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(backup): mark each backup item that needs attention`.

### Task 8: Sync page marks

**Files:**
- Modify: `lib/features/settings/presentation/widgets/sync/sync_using_row.dart`, `lib/features/settings/presentation/pages/cloud_sync_page.dart`
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart`

**Interfaces:**
- Using row (not-set-up title): `{syncOff}`. Status card title: `{syncSignedOut, syncNeedsPassphrase, syncAwaitingAdoption, syncFailed, syncOffline, syncNeverSynced, syncPeersHeld}`; `_buildStatusIcon` keeps glyphs, no colours. Conflicts header: `{syncConflicts}`, warning glyph and text lose orange. Keep in step switch title: `{syncAutoOff}`.

- [ ] **Step 1: Write the failing tests**: auto-sync off marks Keep in step; a successful sync's status icon has no colour; conflicts mark the header and its text is not orange.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cloud_sync_page_test.dart` and `test/features/settings/presentation/widgets/sync/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): mark each sync item that needs attention`.

### Task 9: Photos and libraries page marks

**Files:**
- Modify: `lib/features/media_store/presentation/widgets/photos_using_row.dart`, `photos_status_line.dart`, `lib/features/media_store/presentation/pages/photos_videos_page.dart`, `lib/features/shared_library/presentation/pages/shared_libraries_page.dart`
- Test: `test/features/media_store/presentation/widgets/photos_status_line_test.dart` (create if missing), `test/features/shared_library/presentation/pages/shared_libraries_page_test.dart`

**Interfaces:**
- Using row: `{mediaFinishSetup}`, `subjectId: mediaSetupStore`. Photo sources row: `{mediaFinishSetup}`, `subjectId: mediaSetupLightroom`. Status line: `{mediaTransfersPaused, mediaStoreUnreachable}`, icon without colour. Library tile: `{librariesFailed, librariesEditsHeld}`, `subjectId: library.id`, icon without colour.

- [ ] **Step 1: Write the failing tests**: unreachable store marks the status line and its icon has no colour; a Lightroom-only setup item marks Photo sources, not the using row; library `a` failing and `b` holding edits mark both tiles at their own levels (Review Focus 2).
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/media_store/presentation/` and `test/features/shared_library/presentation/pages/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media-store): mark photo and library items that need attention`.

### Task 10: Whole-branch checks

- [ ] `dart format .` (no changes), `flutter analyze` (no issues), `flutter test test/architecture/ test/shared/ test/features/settings/ test/features/backup/ test/features/media_store/presentation/ test/features/shared_library/presentation/`. Expected: all pass.
- [ ] `grep -rn "DataHealthStrip\|dataHealth_attentionLine" lib test` returns nothing.
