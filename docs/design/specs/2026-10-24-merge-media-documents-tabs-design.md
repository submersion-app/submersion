# Merge Media and Documents into Training-style tabs

Date: 2026-10-24
Status: concept, analysis only, no implementation plan written yet
Issue: #3631

## Problem

Media and Documents sit as two separate main-nav destinations
(`lib/shared/widgets/nav/nav_destinations.dart:158-171`), placed next to each
other as groundwork for exactly this merge (#3381). Both are reference
collections a diver browses incidentally rather than logging sections, so
they should share one nav slot, the way Certifications and Courses now share
Training (#3437).

Training's merge is the precedent to follow: one nav entry, two addresses
that each still work on their own, one host widget holding both tabs warm
under a `TabController`, a `SectionTitleToggle` as the shared title. The
pieces are `lib/core/router/training_locations.dart`,
`lib/features/training/presentation/pages/training_page.dart`,
`lib/features/training/presentation/widgets/training_section_toggle.dart`,
and the two `GoRoute`s in `lib/core/router/app_router.dart:835-958` that both
build `TrainingPage` under the shared `kTrainingHostPageKey`.

Media and Documents are not Certifications and Courses, though. Both tab
candidates already carry their own internal chrome that the Training pair
never had to reconcile:

- `/media` builds `MediaSectionPage`
  (`lib/features/media/presentation/pages/media_section_page.dart`), which
  owns its *own* four-way internal switch (Library, Sources, Transfers,
  Import - `MediaConsoleSection`,
  `lib/features/media/presentation/widgets/media_console_scaffold.dart:16`)
  rendered as a `TabBar` inside its own `AppBar` (inline beside the title or
  stacked at the bottom, depending on width -
  `media_console_scaffold.dart:145-181`). None of these four sub-sections has
  its own address.
- `/documents` builds `DocumentsPage`
  (`lib/features/documents/presentation/pages/documents_page.dart:28-125`),
  which already runs its own `MasterDetailScaffold` with
  `sectionId: 'documents'` on wide screens and its own `Scaffold`+`AppBar` on
  phone (`documents_page.dart:378-386`), plus four query parameters
  (`type`, `filter`, `owner`, `tag`) wired from the route
  (`app_router.dart:900-913`).

Neither page follows the `headerTitle: SectionHeaderTitle?` contract
`CertificationListPage`/`CourseListPage` use to let their host replace the
title (`certification_list_page.dart:33-37, 79-88`). Both build their app bar
chrome themselves today. Adapting that contract, and deciding where
`MediaConsoleScaffold`'s own tab strip goes once it no longer owns the app
bar, is the real work here - everything else is mechanical repetition of the
Training pattern.

## Decisions

- **Nav entry.** One new nav destination replaces `media` and `documents` in
  `kNavDestinations`. Working id `media-documents`; `route: '/media'` directly
  (Media first, matching today's display order at
  `nav_destinations.dart:158-171`), `extraMatchPaths: ['/documents']`.
  Unlike Training, which taps a dedicated stub address (`/training`) that
  redirects to `/certifications`, this does not need its own stub: `route` is
  simply the path `context.go()` is called with on tap
  (`main_scaffold.dart:148-149`, `nav_shortcuts.dart`), and nav-rail/bottom-bar
  selection scores `route` and every `extraMatchPaths` entry as independent
  path prefixes, highest-segment-count wins (`nav_selection.dart:13-37`).
  `/media` already exists as a real route (`app_router.dart:1082-1088`), so
  reusing it directly is sufficient and needs no new redirect `GoRoute` at
  all - simpler than Training's own precedent, not a deviation that costs
  anything. `accent: 'media'`, following Training's `accent: 'certifications'`
  precedent of borrowing the first tab's colour (`nav_destinations.dart:154`);
  `feature_accent_colors.dart` needs no new entry, `media` and `documents`
  already have their own light/dark colours
  (`feature_accent_colors.dart:29,47,79,85`).
- **Locations file.** New `lib/core/router/media_documents_locations.dart`,
  mirroring `training_locations.dart` exactly: a `MediaDocumentsTab` enum
  (`media('/media', 'media')`, `documents('/documents', 'documents')`), a
  `mediaDocumentsTabForPath`, `kMediaDocumentsHostPageKey`, and a
  `mediaDocumentsHostPage(child)` helper.
- **Routing.** `/media` and `/documents` keep their existing addresses and
  subroutes exactly as they are (`/documents/new`, `/documents/:id`,
  `/documents/:id/edit` stay put; `/media` keeps having none). Both
  `GoRoute`s build one new `MediaDocumentsPage(tab: ...)` host under
  `kMediaDocumentsHostPageKey`, replacing today's direct
  `MediaSectionPage`/`DocumentsPage` children at `app_router.dart:900-913`
  and `app_router.dart:1082-1088`. Every existing deep link into Documents
  (`document_detail_page.dart:54,192,238` go to `/documents`,
  `/documents/:id`, `/documents/:id/edit`) keeps working unchanged, exactly
  as Training's tab-owned addresses do today.
- **Host widget.** `MediaDocumentsPage`
  (`lib/features/media_documents/presentation/pages/media_documents_page.dart`,
  new feature folder) copies `TrainingPage`'s structure line for line:
  `TabController`, `_visited` set, per-tab `FocusScopeNode`, per-tab
  `GlobalKey`, the desktop `Stack`+`Visibility(maintainState: true)` branch,
  the phone `TabBarView` branch, address sync through `context.goInPlace`, a
  `_queries` map reused unchanged for Documents' four query parameters -
  Training already has one for exactly this purpose
  (`training_page.dart:65-67, 186-187`), nothing new to design.
  Each tab body is wrapped in `MasterDetailRouteScope(path: tab.path, child:
  ...)`, exactly as `TrainingPage._buildTab` already does
  (`training_page.dart:205-209`). This is not optional: both
  `CertificationListPage` and `CourseListPage` build their own
  `MasterDetailScaffold` internally (`certification_list_page.dart:74-92`,
  `course_list_page.dart:195-203`) and read the URL's `?selected=`/`?mode=`
  query for their desktop split pane; `DocumentsPage` does the same
  (`sectionId: 'documents'`, `documents_page.dart:91-97`). Without the scope,
  Documents' hidden `MasterDetailScaffold` would try to read the URL while
  the diver is actually looking at Media with some unrelated query string
  mounted behind it on desktop, and vice versa. Media has no internal
  `MasterDetailScaffold` today, so the scope is a harmless no-op for it, but
  the host wraps both tabs unconditionally, matching Training's own
  unconditional wrap rather than special-casing one tab.
- **Documents keeps its contract, gains the `headerTitle` wiring.**
  `DocumentsPage` and `DocumentsListContent` gain an optional
  `headerTitle: SectionHeaderTitle?` parameter, threaded into the phone
  `AppBar` (`documents_page.dart:378-386`, `appBarTitleWidget`/`toolbarHeight`
  swapped for `headerTitle`'s slot like `TableModeLayout` already does for
  Certifications, `certification_list_page.dart:79-88`) and into
  `_compactHeader` for the desktop `MasterDetailScaffold` pane bar
  (`documents_page.dart:406-431`), dropping its own `Text(l10n.documents_
  title)` in both places. No change to `MasterDetailScaffold` itself or to
  `sectionId: 'documents'` - that machinery is untouched, only the title
  source changes.
- **There is no single shared app bar to put Media's inner strip into -
  each tab still builds its own.** The first draft of this concept assumed a
  host-level app bar both tabs render into, the way `MediaConsoleScaffold`'s
  current single `Scaffold` does. That assumption does not hold: Training has
  no such thing either. `TabPinnedAppBar`
  (`lib/shared/widgets/tab_pinned_app_bar.dart:15-60`) takes one
  `PreferredSizeWidget child` *per tab* and translates/hides it so only the
  centred one shows - it overlays two independently-built bars to look like
  one fixed bar during a slide, it does not host a bar the tabs share.
  `CertificationListPage` and `CourseListPage` each build their own app bar
  content from the same `trainingHeaderTitle(tab: tab)` factory
  (`training_section_toggle.dart:62-109`); there is no `TrainingPage`-owned
  `Scaffold` at all. Correcting this changes what needs to be designed:
  - `MediaSectionPage` and `DocumentsPage` each keep building their own
    `Scaffold`/`AppBar` (Media gains one; Documents already has one). Both
    take an optional `headerTitle: SectionHeaderTitle?`, built by a new
    `mediaDocumentsHeaderTitle({required controller, required tab})`
    factory mirroring `trainingHeaderTitle` - same outer
    `MediaDocumentsSectionToggle` widget (a `SectionTitleToggle` over
    `MediaDocumentsTab.values`, mirroring `TrainingSectionToggle`,
    `training_section_toggle.dart:18-51`) in the `title` on both tabs, with
    each tab's own app bar wired to `headerTitle.pinAppBar` so
    `TabPinnedAppBar` can hold the title still during the phone slide,
    exactly as `CertificationListPage`'s `phoneAppBarPin:
    widget.headerTitle?.pinAppBar` already does
    (`certification_list_page.dart:88`).
  - Media's inner strip (Library/Sources/Transfers/Import) is **not** shared
    chrome and needs no pinning of its own: it stays exactly where it is
    today, inside `MediaSectionPage`'s own app bar, as that tab's `bottom`
    (or inline beside its own title, by its existing
    `appFlowTabsFitInline` measurement) - just no longer inside a
    `MediaConsoleScaffold`-owned `Scaffold`, but inside the `AppBar` that
    `MediaSectionPage` now builds itself with `title: headerTitle.build(...)`
    and `bottom:` the extracted `TabBar` (`_tabBar()` made public,
    `media_console_scaffold.dart:104-132`). It slides away with the rest of
    Media's body when the diver switches to Documents, which is correct:
    it is Media-specific, not something that needs to look continuous across
    the switch the way the outer title does.
  - Consequence: outer and inner tab strips never compete for the same row's
    width budget - they are two independent rows on two independent
    per-tab-owned bars, not one shared bar trying to fit both. The "second
    row in the body" option this draft originally rejected is, once the
    shared-app-bar premise is corrected, simply where the inner strip
    already lives - there was never a real alternative to design around
    here, only the mistaken premise that it had to move.
  - One real, smaller implementation detail remains: `appBarTabsFitInline`
    currently measures a plain string title
    (`media_console_scaffold.dart:145-153`, `widget.title` is a `String`).
    With the title replaced by `MediaDocumentsSectionToggle`, the inline-fit
    check needs the toggle's rendered width instead of a measured string -
    a measurement-source change, not a structural one, and it affects only
    Media's own existing inline/stacked decision, not the outer switch.
  - The desktop master-detail case needs no special handling beyond this:
    Media has no detail pane today (`MediaSectionPage` always renders its
    full-width console, `media_section_page.dart:50-64`), so the host's
    desktop branch shows it exactly like Documents' master-detail panes,
    just full width.
- **Shortcuts and saved nav order.** `nav_id_aliases.dart` gets two new
  entries, `'media': 'media-documents'` and `'documents': 'media-documents'`,
  exactly mirroring the existing `'certifications'/'courses': 'training'`
  pair (`nav_id_aliases.dart:19-22`). Anyone with Media or Documents pinned
  individually today keeps their slot, landing on the merged entry - the same
  loss of granularity Training already accepted: neither Library/Sources/
  Transfers/Import nor the Media/Documents split gets its own pinnable
  shortcut, only the top-level `media-documents` entry does.
- **l10n.** One new key, `nav_mediaDocumentsSubtitle` (mirroring
  `nav_trainingSubtitle`, "Media and documents" or similar), added to every
  `app_<locale>.arb` file, not just `app_en.arb`. The merged entry's own
  label reuses `nav_media` rather than adding a dedicated
  `nav_mediaDocuments` key - Media is the entry's default landing tab
  (`route: '/media'`), so its existing label already reads correctly as the
  entry's label, the same way reusing an existing string would for any
  other default-tab nav entry. `nav_media` and `nav_documents` stay as-is
  beyond that; they still label the two tabs via `SectionTitleToggle`'s
  `labels`, the same way `nav_certifications`/`nav_courses` still label
  Training's two tabs (`training_section_toggle.dart:37-40`) even though
  `nav_training` is the nav entry's own, separate label.

## UI implications

- The merged nav entry shows "Media" as its default label with a "Media and
  documents"-style subtitle, matching Training's `subtitle:
  (l10n) => l10n.nav_trainingSubtitle` (`nav_destinations.dart:153`).
- Opening the entry from a cold nav tap lands on `/media` (first tab,
  mirroring Training landing on Certifications).
- The Media tab shows the outer Media/Documents switch as the app bar title
  and the Library/Sources/Transfers/Import switch under it (inline or
  stacked by width, same rule as today). The Documents tab shows only the
  outer switch; no second-level strip.
- Switching from Media to Documents (or back) keeps Documents' current
  filters (type/expiring/personal/tag chips) exactly where they were, the
  same way Training's tab switch preserves a tab's last query.
- Deep links (`/documents?type=insurance`, a detail page's `/documents/:id`)
  keep working unchanged; only what renders around them changes.

## Edge cases

- A diver who has Media's `sources` or `transfers` sub-section open and
  switches to the Documents tab and back: `MediaConsoleScaffold`'s own
  `TabController` for the inner switch lives inside `MediaSectionPage`'s
  `State`, which the host's `AutomaticKeepAliveClientMixin`/`Visibility(
  maintainState: true)` keeps alive exactly like Training keeps
  `CertificationListPage`'s state alive today - the inner sub-section
  selection survives an outer tab round trip for free, no extra wiring
  needed.
- A stored nav order carrying both `media` and `documents` as two distinct
  entries (today's normal case) collapses to one `media-documents` slot via
  `normalizeNavOrder`'s existing dedup-on-first-occurrence rule
  (`nav_destinations.dart:274-292`) - the second alias resolves to an id
  already in the result list and is dropped, so no duplicate slot appears and
  the entry keeps the earlier of the two positions.
  - This may move the merged entry earlier in the diver's own order than
    either Media or Documents individually sat (if Documents was pinned
    ahead of Media, the merged entry takes Documents' old slot). This is the
    same ordering quirk Training's merge already accepted
    (`kRenamedNavIds` comment at `nav_id_aliases.dart:19-22`: "certifications
    is the one a save writes back").
- Width at Media's own inline/stacked breakpoint is unaffected by the outer
  switch: since the two strips sit on separate, independently-owned app
  bars (see above), only the measurement source changes (toggle width
  instead of a string), not the fit logic itself or its interaction with
  another row's budget.
- `MediaSectionPage`'s watcher auto-scan kick on `initState`
  (`media_section_page.dart:26-42`) must still fire exactly once per cold
  Media visit, not once per outer tab switch - this already follows from
  `AutomaticKeepAliveClientMixin` keeping `_MediaSectionPageState` alive
  across switches rather than recreating it, the same guarantee Training
  relies on for its own tabs' `initState`-driven work.

## Testing

- `nav_destinations_test.dart` (16-entry id list,
  `test/shared/widgets/nav/nav_destinations_test.dart:36-55, 119-120`):
  update to 15 entries, `media`/`documents` replaced by `media-documents`.
- A `normalizeNavOrder` test for the alias collapse: a stored order
  containing both `media` and `documents` ids produces one `media-documents`
  entry at the earlier id's position, mirroring the existing
  `certifications`/`courses`-merge test if one exists (check first), not
  re-derived from scratch.
- Widget tests for `MediaDocumentsPage`, mirroring whatever exists for
  `TrainingPage`: tab switch via tap updates the address; a direct address
  hit selects the right tab; a tab's state (scroll, open form, Media's inner
  sub-section) survives a switch away and back; focus moves with the switch.
- Widget test confirming Media's inner strip appears only on the Media tab
  and not on Documents, and that it is not affected by, and does not affect,
  the outer switch's own fit/pin behaviour.
- Widget test that Documents' `MasterDetailScaffold` does not react to a
  query string present while Media is the active tab (the
  `MasterDetailRouteScope` guard), and vice versa after switching.
- `DocumentsPage`/`DocumentsListContent` tests updated for the new
  `headerTitle` parameter, following whatever pattern
  `CertificationListPage`'s equivalent tests already use.
- Golden/width tests for the two-row app bar (outer switch + inner Media
  strip) at the inline/stacked breakpoint, phone and desktop.

## Out of scope / open questions

- Exact wording of `nav_mediaDocuments`/`nav_mediaDocumentsSubtitle` across
  all locales - an implementation plan drafts the English copy first, for
  review, before touching every `.arb` file.
- Whether `MediaConsoleScaffold`'s split (tab-bar widget vs. content) should
  be a mechanical extraction or a larger rename/cleanup of that file; this
  concept only requires that the `AppBar` it currently owns stops being
  built there.
- Whether Documents' own `_menu` (export action, `documents_page.dart:388-
  402`) moves into the shared host's app bar actions or stays per-tab; not
  resolved here, follows whatever `appBarActions`-style mechanism
  `CertificationListPage` already demonstrates
  (`certification_list_page.dart:129-166`).
- No decision yet on whether this ships as one PR or is split (host +
  Documents header rewiring first, Media's app bar split second); size this
  when writing the implementation plan.
