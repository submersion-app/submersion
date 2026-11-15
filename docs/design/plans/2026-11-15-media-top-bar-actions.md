# Media top-bar actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Media > Photos/Videos keeps only Library and Gear as tabs; Import, Transfers and Sources become icon buttons at the end of the tab row.

**Architecture:** `MediaConsoleSection` shrinks to `{library, gear}`. A new `MediaConsoleAction` enum and `mediaConsoleActionsFor(caps)` decide which buttons show; `MediaConsoleScaffold` renders them beside the `TabBar` in one row and reports taps through `onAction`. `MediaSectionPage` handles each action: Import calls the existing `MediaImportView.launchImport`, Transfers pushes the existing Settings `TransfersPage`, Sources pushes a new `MediaSourcesSectionPage` that pops `true` when a source is browsed.

**Tech Stack:** Flutter, Riverpod, flutter_test widget tests.

**Spec:** `docs/design/specs/2026-11-15-media-top-bar-actions-design.md`

## Global Constraints

- Tabs: Library and Gear only. The Library missing-files badge stays.
- Buttons sit at the trailing end of the tab row at every width; no extra header row on phones.
- Button order: Import, Transfers, Sources. Tooltips reuse `media_console_import` ("Import"), `media_console_transfers` ("Transfers"), `media_console_sources` ("Sources").
- Web (`DeviceCapabilities.web`, `mediaAttach == false`): Transfers only.
- No change to the import flow, desktop drop import, the transfer queue, the watcher, or Settings' own pages.
- Demo seal guards stay where they are today (the picker and Add folder).
- No em-dashes; no emojis; `p.join` for paths; tests restore any global state they replace.

## Review Focus

1. A 320px phone: "Library", "Equipment" and three icons share one row without overflow (tabs scroll, icons stay put).
2. Sources opened from the Gear tab, then a source tapped: the page closes, the Library shows and the tab indicator moves to Library.
3. Sources opened and closed with Back without browsing: the tab that was showing stays selected.
4. The divider under the row spans the full width, icons included, where the bar is the page's colour, and is absent on a coloured bar.
5. Web: no Import or Sources button, Transfers present.

---

### Task 1: Scaffold renders actions beside two tabs

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart`
- Test: `test/features/media/presentation/media_console_scaffold_test.dart`, `test/features/media/presentation/media_console_sections_test.dart`

**Interfaces:**
- Produces:
  - `enum MediaConsoleSection { library, gear }`
  - `enum MediaConsoleAction { importMedia, transfers, sources }` (declaration order is display order)
  - `List<MediaConsoleAction> mediaConsoleActionsFor(DeviceCapabilities caps)`: `caps.mediaAttach ? MediaConsoleAction.values : const [MediaConsoleAction.transfers]`
  - `mediaConsoleSectionsFor` is removed (both platforms show both tabs; the scaffold uses `MediaConsoleSection.values`).
  - `MediaConsoleScaffold` gains `required ValueChanged<MediaConsoleAction> onAction`.
  - Each button is an `IconButton` with key `ValueKey('media_console_action_${action.name}')`, tooltip from the strings above, icons `Icons.add_photo_alternate_outlined` (import), `Icons.swap_vert` (transfers), `Icons.source_outlined` (sources).

- [ ] **Step 1: Update the tests first**
  - `media_console_sections_test.dart`: replace the two `mediaConsoleSectionsFor` tests with `natively every action is offered` (`mediaConsoleActionsFor(currentDeviceCapabilities())` equals `MediaConsoleAction.values`) and `a browser offers only Transfers` (`mediaConsoleActionsFor(DeviceCapabilities.web)` equals `[MediaConsoleAction.transfers]`). Keep `gear tab is offered right after the library` and the Equipment label test.
  - `media_console_scaffold_test.dart`: `host` takes `ValueChanged<MediaConsoleAction>? onAction`. Rename `the console has exactly five destinations` to `the console has exactly two tabs` expecting `[library, gear]`. Rewrite `a browser has no Sources or Import tab (#4121)` as `a browser shows only the Transfers button (#4121)`: finds the transfers key, not the import or sources keys. Add:
    - `tapping each button fires onAction at width $width` (both widths): tap each key, expect the matching `MediaConsoleAction`.
    - `buttons share the tab row at width $width`: each button's vertical centre equals the `TabBar`'s within 1px, and the buttons sit right of the last tab.
    - `a 320px phone fits two tabs and three buttons`: `tester.takeException()` is null and all three keys are hit-testable.
  - Update `stacked tabs drop the divider on a coloured bar only` to check the row's bottom border (see Step 3) rather than `TabBar.dividerColor`.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/media/presentation/media_console_scaffold_test.dart test/features/media/presentation/media_console_sections_test.dart`
Expected: compile errors on `MediaConsoleAction` and `onAction`.

- [ ] **Step 3: Implement**
  Build the row as `PreferredSize(preferredSize: tabBar.preferredSize, child: Row([Expanded(child: tabBar), ...buttons, SizedBox(width: 4)]))` (4, not 8: at 360px the wider gap squeezed the tab strip). The `TabBar` always gets `dividerColor: Colors.transparent`; when the old code wanted a divider, the row draws it instead as a `DecoratedBox` bottom border in `theme.colorScheme.outlineVariant`, so it runs under the buttons too. Button colour follows `AppBarTabColors.unselected`, so it reads on a coloured bar. Remove the five-tab labels from `_label`.

- [ ] **Step 4: Run the tests and see them pass**

Same command. Expected: all pass.

- [ ] **Step 5: Commit** `feat(media): Import, Transfers and Sources as buttons beside the Media tabs` (with Task 3, since the page will not compile alone; see Task 3 Step 5).

### Task 2: Sources as its own page

**Files:**
- Create: `lib/features/media/presentation/pages/media_sources_section_page.dart`
- Test: `test/features/media/presentation/media_sources_section_page_test.dart`

**Interfaces:**
- Produces: `class MediaSourcesSectionPage extends StatelessWidget` with `@visibleForTesting final Future<String?> Function()? pickFolderOverride`. A `Scaffold` with `AppBar(title: Text(l10n.media_console_sources))` over `MediaSourcesSectionView(onBrowseSource: () => Navigator.of(context).pop(true), pickFolderOverride: ...)`. Pushed as `Navigator.push<bool>`; `true` means a source was browsed.

- [ ] **Step 1: Write the failing tests**
  - `the page titles itself Sources and shows the sources view`: `find.text('Sources')` in an `AppBar`, `find.byType(MediaSourcesSectionView)` one.
  - `browsing a source pops with true`: push it from a host button with `sourceCountsProvider` overridden to `{MediaSourceType.platformGallery: 7}` and `watchedRootsProvider` to `[]`; tap `find.widgetWithText(ListTile, '7')`; the awaited result is `true` and the page is gone.
  - `Back pops with null`: tap `BackButton`; result is `null`.

- [ ] **Step 2: Run, expect failure** (`flutter test test/features/media/presentation/media_sources_section_page_test.dart`: file missing).

- [ ] **Step 3: Implement** the page as above.

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit** `feat(media): Sources opens as its own page`.

### Task 3: The Media page handles the buttons

**Files:**
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`
- Test: `test/features/media/presentation/media_section_page_test.dart`

**Interfaces:**
- Consumes: Task 1's `MediaConsoleAction`, `onAction`; Task 2's `MediaSourcesSectionPage`; `MediaImportView.launchImport(context, ref, {pick})`; `TransfersPage` from `lib/features/media_store/presentation/pages/transfers_page.dart`.
- Produces: `MediaSectionPage` gains `@visibleForTesting final Future<List<AssetInfo>> Function(BuildContext)? importPickOverride`, passed as `pick` to `launchImport`.

- [ ] **Step 1: Update the tests first**
  - Replace `switching sections swaps library and transfers content` with `switching tabs swaps the library and the gear gallery` (tap `Equipment`, expect `GearGalleryView`; tap `Library`, expect `MediaLibraryView`).
  - Add `the Transfers button opens the Transfers page over Media`: tap `media_console_action_transfers`, expect `TransfersPage`; tap `BackButton`, expect `MediaLibraryView` again.
  - Add `the Import button opens the picker straight away`: `importPickOverride` records that it was called and returns `[]`; tap `media_console_action_import`; the flag is set and `MediaLibraryView` is still showing.
  - Replace `browsing a source jumps to Library and moves the tab with it` with `browsing a source from Gear closes Sources and selects Library`: select `Equipment`, tap `media_console_action_sources`, expect `MediaSourcesSectionPage`; tap `find.widgetWithText(ListTile, '7')`; expect `MediaSourcesSectionPage` gone, `MediaLibraryView` shown, the strip's `TabController.index == MediaConsoleSection.library.index`.
  - Add `closing Sources with Back keeps the current tab`: select `Equipment`, open Sources, tap `BackButton`; `GearGalleryView` still shown, controller index is gear.
  - The `TabBar` finder in the remaining tests anchors on `find.text('Library')` instead of `'Sources'`.

- [ ] **Step 2: Run, expect failure** (`flutter test test/features/media/presentation/media_section_page_test.dart`).

- [ ] **Step 3: Implement** `onAction` in `_MediaSectionPageState`: `importMedia` calls `MediaImportView.launchImport(context, ref, pick: widget.importPickOverride)`; `transfers` pushes `MaterialPageRoute(builder: (_) => TransfersPage(title: l10n.media_console_transfers))` (`TransfersPage` gains an optional `title`; null keeps Settings' Uploads); `sources` awaits `Navigator.of(context).push<bool>(...)` and, when `true` and mounted, sets `_section = MediaConsoleSection.library`. The `child` switch covers `library` and `gear` only.

- [ ] **Step 4: Run Tasks 1 to 3's test files, expect pass.**

- [ ] **Step 5: Commit** Tasks 1 and 3 together: `feat(media): Import, Transfers and Sources as buttons beside the Media tabs`.

### Task 4: Retire the Import tab's page body and its strings

**Files:**
- Modify: `lib/features/media/presentation/pages/media_import_view.dart`, every `lib/l10n/arb/app_*.arb`, generated l10n outputs
- Test: `test/features/media/presentation/media_import_view_test.dart`

**Interfaces:**
- Produces: `MediaImportView` becomes `abstract final class MediaImportView` holding only its statics (`libraryWindowStart`, `importResolved`, `launchImport`). The name stays to spare `media_drop_import.dart` and `species_photo_import_helper.dart` a rename; its doc comment says it is the dive-less import entry point. `launchOverride` and `build` go.

- [ ] **Step 1: Update the test.** Drop `renders intro and launch button`. The remaining tests drive `MediaImportView.launchImport(context, ref, pick: ...)` from a host `FilledButton` instead of the view's own button; their assertions are unchanged.

- [ ] **Step 2: Run, expect failure** (`flutter test test/features/media/presentation/media_import_view_test.dart`: still compiles against the widget, so first make the class change and confirm the old test fails to compile, then the new one passes).

- [ ] **Step 3: Implement.** Remove `media_import_intro` and `media_import_launch` (and their `@` entries) from every ARB file only after `grep -rn` shows no other user. Run `flutter gen-l10n`.

- [ ] **Step 4: Run** the import view, import resolved, drop import and species import tests. Expected: pass.

- [ ] **Step 5: Commit** `refactor(media): drop the Import tab's page and its strings`.

### Task 5: Checks and after screenshots

- [ ] `dart format .`, then `flutter analyze` with no issues.
- [ ] `flutter test test/features/media test/architecture test/shared` passes.
- [ ] After screenshots with the scratch harness (`PHASE=after`), phone and desktop: the Media library, the Sources page, the Transfers page.
- [ ] Delete `integration_test/media_bar_scratch_test.dart` before any commit under `integration_test/`.
