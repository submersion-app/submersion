# Justified-Row Media Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the media library's square column grid with justified rows that keep each item's displayed shape (issue #4738).

**Architecture:** A pure packer turns aspect ratios into rows; a cell table (successor to `MediaGroupedGridTable`) gives every header and tile an exact rectangle that a custom `SliverGridDelegate` lays out lazily; one shared scroll view drives the flat grid and the grouped list. Shapes come from stored size, corrected by ratios learned from decoded thumbnails and kept in a new unsynced local cache table.

**Tech Stack:** Flutter, Riverpod 3 (via `package:submersion/core/providers/provider.dart`), Drift (local cache database).

**Spec:** `docs/design/specs/2026-11-19-justified-media-library-design.md`

## Global Constraints

- Ratio = width / height. Clamp 1/3 to 3. Fallback 4:3 when either stored dimension is missing or not positive. Documents (`MediaType.document`) fixed 3:4, never learned.
- Minimum tile width 48 px: the narrowest ratio a row uses is `max(1/3, 48 / targetHeight)`.
- Overlays: markers (bottom left) and video duration (bottom right) hidden on tiles under 64 px wide.
- A learned ratio is reported only when it differs from the item's unclamped shape by more than 2 %.
- Gap 4 px and side inset 8 px per side; on panes narrower than 600 px gap 2 px and inset 2 px.
- Row height per stop: `64 * (largest / 64)^(step / 6)` with `largest = paneWidth / 2`, never above `paneWidth / 2` nor below 64.
- Decode target: the tile's longest side picks 200, 400 or 800 (`<= 200`, `<= 400`, else 800), as `Size.square`.
- Local cache schema 25 to 26. Nothing in the synced database changes.
- No new user-visible strings (the duration is digits only).
- Never use the em-dash character in code, comments or docs.
- Run only the test files you touched, by path; the pre-push hook runs the guards.

## Review Focus

1. **Pane narrower than one tile at the minimum width** (a 100 px split view): rows of one item each, no negative widths, no overflow. Test in Task 1.
2. **A learned ratio arriving for an item above the viewport:** the cell at the top of the viewport stays put. Test in Task 7.
3. **Empty groups and an empty library:** a table with zero tiles, header-only sections, `cellCount == 0`. Test in Task 5.
4. **Right-to-left:** rows mirror, flush to the left edge in RTL. Test in Task 5.
5. **Decode reported for a video poster or a failed thumbnail:** a video learns from its poster; a failure reports nothing. Test in Task 4.

---

### Task 1: Row packer

**Files:**
- Create: `lib/features/media/presentation/widgets/justified_row_packer.dart`
- Test: `test/features/media/presentation/justified_row_packer_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class JustifiedRow {
    const JustifiedRow({required this.start, required this.widths, required this.height});
    final int start;            // index of the row's first item
    final List<double> widths;  // one per item, in order
    final double height;
    int get count => widths.length;
  }
  List<JustifiedRow> packJustifiedRows({
    required List<double> ratios,   // already clamped to 1/3..3
    required double paneWidth,      // usable width, insets already removed
    required double targetHeight,
    required double gap,
    double minTileWidth = 0,
  });
  ```

- [ ] **Step 1: Write the failing tests.** In one group, each with `gap: 4`, `paneWidth: 1000`, `targetHeight: 200` unless stated:
  - `closed rows end flush`: ratios `[1.5, 0.75, 1.33, 1, 1.78, 0.56, 2.33, 1.5]`; every row but the last satisfies `sum(widths) + gap * (count - 1)` equals 1000 within `1e-9`, and every width equals `ratio * height` within `1e-6` except the last of the row (which absorbs the remainder, within `1e-6` of its ratio * height).
  - `last row keeps the target height and is not stretched`: last row `height == 200`, its width sum below 1000.
  - `single item`: `[1.5]` gives one row, `height 200`, `widths [300]`.
  - `a very wide item gets its own row, scaled down`: `[3]` at `paneWidth: 400` gives `height` `400 / 3`, `widths [400]`.
  - `break closest to the target`: ratios `[1, 1, 1, 1, 3]` at `paneWidth: 1000`: four squares (816 + gaps) and then a 3:1 that would make the row much shorter. Expect the first row to hold 4 items (height about 247, `|log(247/200)|` < `|log(scaled-with-five/200)|`), and the 3:1 to start the next row.
  - `appending changes only the last row`: pack `r` and `r + [1.2, 0.8]`; all rows of the first result except its last are identical (start, widths, height) in the second.
  - `minimum width raises narrow items`: `[1/3]` with `targetHeight: 64`, `minTileWidth: 48` gives `widths [48]`.
  - `pane narrower than the minimum width`: `[1, 1]` at `paneWidth: 30`, `minTileWidth: 48`: two rows of one item, each width 30, height 30, no negative values.
  - `empty`: `[]` gives `[]`.

- [ ] **Step 2: Run to verify they fail.** `flutter test test/features/media/presentation/justified_row_packer_test.dart` fails: `packJustifiedRows` undefined.

- [ ] **Step 3: Implement `packJustifiedRows`.** Greedy from the left. Effective ratio `max(r, minTileWidth / targetHeight)`. Grow a row while its width at `targetHeight` (ratios * height + gaps) is under `paneWidth`. When adding item *k* crosses the edge, compare closing before it (height `hb`) and after it (height `ha`), each the height that makes the row exactly `paneWidth`; pick the smaller `|log(h / targetHeight)|`, ties after; a row is never empty. A closed row: widths `ratio * h`, last width `paneWidth - sum(others) - gaps`. The final open row stays at `targetHeight`, scaled down only if it overflows.

- [ ] **Step 4: Run to verify they pass.** Same command, all green.

- [ ] **Step 5: Commit.** `git add` both files; `git commit -m "feat(media): pack media into justified rows"`.

### Task 2: Shape rules and the duration label

**Files:**
- Create: `lib/features/media/presentation/helpers/media_layout_aspect.dart`
- Modify: `lib/features/media/presentation/helpers/elapsed_time_format.dart`
- Test: `test/features/media/presentation/helpers/media_layout_aspect_test.dart`, `test/features/media/presentation/helpers/elapsed_time_format_test.dart` (create or extend)

**Interfaces:**
- Produces:
  ```dart
  typedef LearnedAspect = ({double ratio, int? width, int? height});
  const double kMediaFallbackAspect = 4 / 3;
  const double kMediaDocumentAspect = 3 / 4;
  const double kMediaMinAspect = 1 / 3;
  const double kMediaMaxAspect = 3;
  double mediaRawAspect(MediaItem item, {LearnedAspect? learned});
  double clampMediaAspect(double raw);
  bool learnedAspectApplies(MediaItem item, LearnedAspect learned); // width/height equal the item's (nulls equal)
  bool decodedAspectDiffers(double raw, Size decoded);             // > 2 %
  String formatClipDuration(int seconds); // m:ss, or h:mm:ss from 3600
  ```

- [ ] **Step 1: Write the failing tests.**
  - `mediaRawAspect`: stored 4000x3000 gives `4/3`; stored 3000x4000 with a learned `(ratio: 0.75, width: 3000, height: 4000)` gives `0.75`; a learned entry recorded for 4000x3000 on an item now 3000x4000 is ignored; null width gives `4/3`; width 0 gives `4/3`; a document with stored 1000x100 gives `0.75`; a document with a learned entry still gives `0.75`; null-dims item with learned `(ratio: 0.5, width: null, height: null)` gives `0.5`.
  - `clampMediaAspect`: `5` gives `3`, `0.1` gives `1/3`, `1.5` gives `1.5`.
  - `decodedAspectDiffers`: raw `1.5`, decoded `Size(300, 200)` is false; `Size(306, 200)` (2 %) is false; `Size(200, 300)` is true.
  - `formatClipDuration`: `0` gives `0:00`, `83` gives `1:23`, `3599` gives `59:59`, `3600` gives `1:00:00`, `3725` gives `1:02:05`.

- [ ] **Step 2: Run both files, expect failures** (undefined names).

- [ ] **Step 3: Implement** the functions above. `mediaRawAspect` order: document fixed, then an applicable learned entry, then stored, then fallback.

- [ ] **Step 4: Run both files, expect green.**

- [ ] **Step 5: Commit** `feat(media): shape rules for library thumbnails`.

### Task 3: Local cache table for learned shapes

**Files:**
- Create: `lib/core/database/local_cache_media_aspect_table.dart` (table class `MediaAspectCache`, table name `media_aspect_cache`, and `kCreateMediaAspectCacheSql`, modelled on `local_cache_vertical_distance_table.dart`)
- Modify: `lib/core/database/local_cache_database.dart` (import/export, tables list, `schemaVersion => 26`, `if (from < 26) await m.createTable(mediaAspectCache);`, backstop `customStatement(kCreateMediaAspectCacheSql)` next to the v25 one)
- Create: `lib/features/media/data/repositories/media_aspect_cache_repository.dart`
- Modify: `lib/core/services/storage/local_cache_sweep.dart` (orphan sweep against `_library.media`, report field `mediaAspectRows` defaulting to 0, added to `rowsDeleted` and `toString`)
- Test: `test/core/database/local_cache_migration_v26_media_aspect_test.dart`, `test/features/media/data/repositories/media_aspect_cache_repository_test.dart`, `test/core/services/storage/local_cache_sweep_test.dart`

**Interfaces:**
- Consumes: `LearnedAspect` (Task 2).
- Produces:
  - Columns: `media_id TEXT PK`, `ratio REAL NOT NULL`, `width INTEGER NULL`, `height INTEGER NULL`, `learned_at INTEGER NOT NULL`.
  - ```dart
    class MediaAspectCacheRepository {
      MediaAspectCacheRepository({LocalCacheDatabase? database});
      Future<Map<String, LearnedAspect>> loadAll();
      Future<void> putAll(Map<String, LearnedAspect> entries); // upsert, one batch
    }
    ```

- [ ] **Step 1: Write the failing tests.** Migration test copied in shape from `local_cache_migration_v25_identification_embeddings_test.dart`: version `>= 26`; fresh DB has columns `['media_id', 'ratio', 'width', 'height', 'learned_at']`; a version 25 DB gains the table and accepts an insert; a version 26 DB missing the table (stamped by a colliding branch) gets it from the backstop. Repository test (in-memory DB): `putAll` then `loadAll` round-trips two entries, one with null dims; a second `putAll` for the same id replaces it. Sweep test: a `media_aspect_cache` row whose media id is absent from the library is deleted and counted in `mediaAspectRows`; one whose media exists is kept.

- [ ] **Step 2: Run the three files, expect failures.**

- [ ] **Step 3: Implement** the table, migration step, backstop line, repository and sweep arm. Run `dart run build_runner build --delete-conflicting-outputs` in the background (never `--build-filter`) for `local_cache_database.g.dart`. Keep `local_cache_database.dart` under 800 lines.

- [ ] **Step 4: Run the three files, expect green.**

- [ ] **Step 5: Commit** `feat(media): local cache for learned thumbnail shapes`.

### Task 4: Learned shapes provider

**Files:**
- Create: `lib/features/media/presentation/providers/media_learned_aspect_provider.dart`
- Test: `test/features/media/presentation/providers/media_learned_aspect_provider_test.dart`

**Interfaces:**
- Consumes: `MediaAspectCacheRepository` (Task 3), `mediaRawAspect`, `decodedAspectDiffers` (Task 2).
- Produces:
  ```dart
  final mediaAspectCacheRepositoryProvider = Provider<MediaAspectCacheRepository>(...);
  final mediaLearnedAspectsProvider =
      AsyncNotifierProvider<MediaLearnedAspectsNotifier, Map<String, LearnedAspect>>(...);
  class MediaLearnedAspectsNotifier extends AsyncNotifier<Map<String, LearnedAspect>> {
    /// Called by a tile with its thumbnail's decoded size.
    void report(MediaItem item, Size decoded);
  }
  ```
  Not autoDispose: the map lives for the app session.

- [ ] **Step 1: Write the failing tests** with a fake repository (records `putAll` calls, serves a fixed `loadAll`):
  - `loads the stored map` (state value equals the fake's map).
  - `a decode matching the item's shape records nothing`: item 4000x3000, decoded `Size(400, 300)`: no state change, no `putAll`.
  - `a rotated decode is learned once per frame`: item 4000x3000, decoded `Size(300, 400)` and a second item in the same frame: after one `SchedulerBinding` frame (`tester.pump()` in a `testWidgets`, or `binding.handleDrawFrame`), state holds both with `ratio 0.75` and their stored dims, and `putAll` was called once with both.
  - `a document is never learned`.
  - `a zero-sized decode is ignored` (`Size(0, 0)`, the failure case).

- [ ] **Step 2: Run, expect failures.**

- [ ] **Step 3: Implement.** `report` queues into a pending map and schedules one post-frame flush (`SchedulerBinding.instance.addPostFrameCallback` plus `ensureVisualUpdate`), which sets `state = AsyncData({...current, ...pending})` and calls `putAll` (errors logged, not thrown). Reports before the load finishes queue and flush after it.

- [ ] **Step 4: Run, expect green.**

- [ ] **Step 5: Commit** `feat(media): learn thumbnail shapes from decoded images`.

### Task 5: Justified cell table and delegate

**Files:**
- Create: `lib/features/media/presentation/widgets/justified_media_grid.dart`
- Delete: `lib/features/media/presentation/widgets/media_grouped_grid.dart` (once Task 7 no longer imports it; delete in Task 7)
- Test: `test/features/media/presentation/justified_media_grid_test.dart` (port the relevant cases of `media_grouped_grid_test.dart`, then delete that file in Task 7)

**Interfaces:**
- Consumes: `packJustifiedRows` (Task 1).
- Produces:
  ```dart
  class JustifiedSection {           // value equality on both lists
    const JustifiedSection({required this.headerExtents, required this.ratios});
    final List<double> headerExtents;
    final List<double> ratios;       // clamped
  }
  class MediaGridPlace { const MediaGridPlace({required this.cell, required this.fraction}); ... } // moved here unchanged
  class JustifiedMediaTable {
    factory JustifiedMediaTable.build({
      required List<JustifiedSection> sections,
      required double paneWidth,
      required double targetHeight,
      required double gap,
      required double inset,           // per side
      double minTileWidth = 48,
    });
    double get paneWidth; double get targetHeight; double get totalExtent; int get cellCount;
    int sectionOf(int cell); int tileIndexOf(int cell); int headerIndexOf(int cell);
    int cellOf(int section, int tileIndex);
    Rect rectOf(int cell);                 // LTR, in content coordinates, inset included
    int minCellAt(double offset); int maxCellAt(double offset);
    SliverGridGeometry geometryOf(int cell, {required bool reverseCrossAxis});
    MediaGridPlace placeAt(double offset); double offsetOf(MediaGridPlace place);
    bool hasSameCellsAs(JustifiedMediaTable other);
  }
  class JustifiedMediaGridDelegate extends SliverGridDelegate {
    const JustifiedMediaGridDelegate(this.table);
  }
  ```
  Vertical layout as today: a section's headers stacked, then its rows separated by `gap`, no gap after the last row; the next section's headers follow directly. Headers span the full `paneWidth` from x 0.

- [ ] **Step 1: Write the failing tests.**
  - `tiles keep their packed rectangles`: two sections (`headerExtents [40]`, ratios of six and three), `paneWidth 1016`, `inset 8`, `gap 4`, `targetHeight 200`: each tile's `rectOf` width/height equal Task 1's packer output for usable width 1000, left starts at 8, rows of a section share `top`, first row top equals the header extent.
  - `rows of a group never mix with the next`: section 2's first tile top equals section 1's last row bottom plus section 2's header extent.
  - `binary search finds row edges`: for an offset inside row r, `minCellAt` is the row's first cell and `maxCellAt` its last.
  - `cellOf inverts sectionOf/tileIndexOf` for every tile.
  - `right to left mirrors`: `geometryOf(cell, reverseCrossAxis: true).crossAxisOffset == paneWidth - rect.right`.
  - `empty`: no sections gives `cellCount 0`, `totalExtent 0`, `placeAt(0)` cell 0; a header-only section has its header and no tiles.
  - `placeAt / offsetOf round-trip` and `hasSameCellsAs` true across a different `targetHeight`, false when a section's tile count changes.

- [ ] **Step 2: Run, expect failures.**

- [ ] **Step 3: Implement** with typed arrays as `MediaGroupedGridTable` does (tops, lefts, widths, heights, cellSections, slots), plus a per-section prefix of first cell index for `cellOf`.

- [ ] **Step 4: Run, expect green.**

- [ ] **Step 5: Commit** `feat(media): lay media out from a justified cell table`.

### Task 6: Row height scale, spacing and decode target

**Files:**
- Modify: `lib/features/media/presentation/providers/media_thumbnail_scale_provider.dart`
- Rename/replace: `lib/features/media/presentation/widgets/media_thumbnail_columns_builder.dart` with `media_thumbnail_row_height_builder.dart`
- Test: `test/features/media/presentation/media_thumbnail_scale_test.dart`

**Interfaces:**
- Produces (column functions and constants that only served columns are removed: `mediaThumbnailMaxColumns`, `mediaThumbnailColumnsForStep`, `kMediaThumbnailMinColumns`, `kMediaThumbnailMaxInset`, `kMediaThumbnailGap`):
  ```dart
  const int kMediaThumbnailSteps = 7;            // unchanged
  const double kMediaThumbnailMinExtent = 64;    // unchanged, now the lowest row height
  const double kMediaThumbnailMinTileWidth = 48;
  const double kMediaThumbnailNarrowPane = 600;
  double mediaThumbnailGap(double paneWidth);    // 2 under 600, else 4
  double mediaThumbnailInset(double paneWidth);  // per side: 2 under 600, else 8
  double mediaThumbnailRowHeightForStep(int step, double paneWidth);
  Size mediaThumbnailDecodeTarget(Size tile);
  class MediaThumbnailScale { int step; double? rowHeight; double rowHeightAt(double paneWidth); copyWith(...) }
  class MediaThumbnailScaleNotifier { setStep; stepBy; void hold(double rowHeight); }
  class MediaThumbnailRowHeightBuilder extends ConsumerWidget {
    const MediaThumbnailRowHeightBuilder({super.key, required this.builder});
    final Widget Function(BuildContext context, double rowHeight) builder;
  }
  ```

- [ ] **Step 1: Rewrite the scale tests:** `rowHeightForStep(0, 1200) == 64`; `rowHeightForStep(6, 1200) == 600`; step 3 at 1200 equals `64 * pow(600 / 64, 0.5)` within `1e-9`; at pane 100 every step gives 64; a held `rowHeight 500` at pane 800 gives 400 (half the pane); `hold` keeps the first value; `setStep` drops it; `stepBy` at an end keeps the hold; `mediaThumbnailGap(599) == 2`, `(600) == 4`; `mediaThumbnailInset(599) == 2`, `(600) == 8`; decode target of `Size(150, 200)` is `Size.square(200)`, of `Size(300, 201)` is `Size.square(400)`, of `Size(900, 300)` is `Size.square(800)`. Builder widget test: hands the builder the step-3 height at the test pane width and holds it after a frame; a resize keeps the held height.

- [ ] **Step 2: Run, expect failures.**

- [ ] **Step 3: Implement** per Global Constraints. Keep the doc comments' reasoning for the 200/400/800 buckets.

- [ ] **Step 4: Run, expect green.** (The library widgets fail to compile until Task 7; run only this file.)

- [ ] **Step 5: Commit** together with Task 7 (they compile only together).

### Task 7: The views: shared justified scroll view, tiles, zoom anchor

**Files:**
- Create: `lib/features/media/presentation/widgets/justified_media_scroll_view.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart` (tile and flat grid), `media_library_grouped_list.dart`, `media_thumbnail_zoom_anchor.dart`
- Delete: `media_grouped_grid.dart`, `test/features/media/presentation/media_grouped_grid_test.dart`
- Test: `test/features/media/presentation/media_library_grid_test.dart`, `media_library_grouped_list_test.dart`, `media_library_grouped_list_place_test.dart`, `media_library_grouped_list_sections_test.dart`, `media_library_grouped_list_attached_test.dart`, `media_library_tile_test.dart`, `widgets/media_library_tile_test.dart` if present (update `columns:` to `rowHeight:`)

**Interfaces:**
- Consumes: Tasks 2, 4, 5, 6.
- Produces:
  ```dart
  // media_thumbnail_zoom_anchor.dart: column helpers removed
  // (mediaThumbnailExtentAfter, mediaThumbnailGridHeight); anchor apply becomes:
  double MediaThumbnailZoomAnchor.scrollOffsetFor({
    required double pixels,   // scroll offset when captured
    required double oldTop,   // anchor tile's top in the old table
    required double newTop,
    required double newHeight,
  });
  // = max(0, pixels + (newTop - oldTop) + fraction * (newHeight - tileExtent))
  // with fraction = clamp((cursorY - tileTop) / tileExtent, 0, 1) as today. The
  // distance below a tile's foot (cursor over a gap) cancels out; padding
  // above the grid is the same in both tables, so it cancels too.

  class JustifiedMediaScrollView extends StatefulWidget {
    const JustifiedMediaScrollView({
      super.key,
      required this.sections,          // List<JustifiedSection>, header extents measured by caller
      required this.rowHeight,
      required this.cellBuilder,       // Widget Function(BuildContext, JustifiedCell cell)
      required this.hasMore,
      required this.onLoadMore,
      this.padding = EdgeInsets.zero,
    });
  }
  class JustifiedCell { int section; int header; int tile; Size size; } // header or tile is -1
  // MediaLibraryGrid and MediaLibraryGroupedList: `columns` replaced by `double rowHeight`; `targetSize` removed
  // (decode target per tile from its size). MediaLibraryTile: `onImageSize` passed to MediaItemView.
  ```

- [ ] **Step 1: Write the failing tests.**
  - Grid: `tiles keep their shape`: three entries 4000x3000, 3000x4000, 1600x900 at 1200 wide: each `MediaLibraryTile`'s size ratio matches within 0.5 px, all share one height.
  - Grid: `the full rows end at the pane edge` (right edge of each closed row's last tile equals pane width minus inset).
  - Grid: `a learned ratio re-lays the tile`: override the learned provider with a fake notifier; report `Size(300, 400)` for a 4000x3000 item via the tile's `MediaItemView.onImageSize` (resolver serving a 3x4 PNG); after a pump the tile is portrait.
  - Grid: `the first layout waits for learned shapes` (provider loading: no tiles; resolved: tiles).
  - Grid + grouped: `zooming in and out keeps the tile under the cursor`: port today's tests; after a wheel step the anchored tile's global top plus fraction times height is within 1 px of the cursor.
  - Grouped: `a learned ratio above the viewport keeps the top cell in place` (Review Focus 2).
  - Grouped: `paging adds rows without moving the rows above`: rebuild with the last group grown by two items; every earlier tile's rect is unchanged.
  - Tile: `a video shows its duration` (`1:23` for 83 s), `hidden when null`, `markers and duration hide under 64 px wide`, `the selection check and badge stay at 48 px`.
  - Existing selection, header tap, load-more and RTL tests keep passing with `rowHeight: 120` in place of `columns: 4`.

- [ ] **Step 2: Run the touched files, expect failures.**

- [ ] **Step 3: Implement.** `JustifiedMediaScrollView` owns what `_MediaLibraryGroupedListState` owns today: `LayoutBuilder` for pane width, table cache keyed on sections/paneWidth/rowHeight, `_keepPlace` (anchor first via `MediaThumbnailZoomAnchorScope.takeFrom`, else `placeAt`/`offsetOf` when `hasSameCellsAs`), `GridView.builder` with `MediaThumbnailWheelZoomPhysics`, `ScrollCacheExtent.viewport(2)`, `JustifiedMediaGridDelegate`, and the near-end load-more listener (400 px). Grid and grouped list build `JustifiedSection`s from entries: ratios `clampMediaAspect(mediaRawAspect(item, learned: map[item.id]))`, watching `mediaLearnedAspectsProvider` and rendering nothing until it has a value. Tiles get `MetaData(MediaThumbnailSlot(row: section, index: tile))` as today, `targetSize: mediaThumbnailDecodeTarget(cell.size)`, and `onImageSize: (s) => ref.read(mediaLearnedAspectsProvider.notifier).report(item, s)`. Tile overlays: `LayoutBuilder` on width; duration chip bottom right with `formatClipDuration`, styled like `MediaTileMarkers`. Delete `media_grouped_grid.dart` and its test.

- [ ] **Step 4: Run every touched test file by path, expect green.** Then `flutter analyze` (whole repo) clean.

- [ ] **Step 5: Commit** Tasks 6 and 7 together: `feat(media): justified rows in the media library`.

### Task 8: Wire the library page and finish

**Files:**
- Modify: `lib/features/media/presentation/pages/media_library_view.dart` (use `MediaThumbnailRowHeightBuilder`, pass `rowHeight`), `media_thumbnail_wheel_zoom.dart` and `media_library_toolbar.dart` only if they referenced removed names
- Test: `test/features/media/presentation/media_thumbnail_wheel_zoom_test.dart`, the library view tests that build the page (`grep -rl MediaLibraryView test/features/media`)

- [ ] **Step 1: Update the page tests** for the row-height builder: the toolbar slider changes tile height (step 0 tiles 64 px tall at 1200 wide); Ctrl + wheel steps it.

- [ ] **Step 2: Run them, expect failures; wire the page; run, expect green.**

- [ ] **Step 3:** `grep -rn "columns:\|ColumnsBuilder\|mediaThumbnailColumnsForStep\|MediaGroupedGrid" lib test` returns nothing media-related. `dart format .`, `flutter analyze` clean.

- [ ] **Step 4: Commit** `feat(media): drive the library from row height`.

- [ ] **Step 5: After screenshots** with the headless renderer (`test/zz_pr_shots_4738/`, never committed), `SHOTS_STATE=after`, same eight shots; delete the renderer folder afterwards.
