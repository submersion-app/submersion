# Certification grouping and list/wallet view switch - plan

Issue: #3359

## Goal

Make the certification list's grouping configurable (Status / Agency / None)
instead of hardcoded to Status, and let the same sort bottom sheet switch
between the List and Certification Wallet views, carrying sort and grouping
across the switch.

## Domain layer

New file `lib/features/certifications/presentation/utils/certification_grouping.dart`
(not `domain/utils` -- it depends on `AppLocalizations`, see the Presentation
layer section below):

- `enum CertificationGroupBy { status, agency, none }`
- `class CertificationGroup`: `key`, `label`, `certifications`. No color field
  -- color is a presentation concern, and the issue asks for nothing beyond
  the existing status dots: status groups keep their fixed red/orange/green
  dot, agency groups get a plain text header (no per-agency color; inventing
  one is a design opinion the issue never asked for), none renders no header
  at all.
- `List<CertificationGroup> groupCertificationsFor(CertificationGroupBy groupBy,
  List<Certification> sortedCertifications, {required AppLocalizations l10n,
  CertificationCatalog? catalog})`:
  - `status`: three fixed-order groups (Expired, Expiring Soon, Valid),
    skipping any that end up empty -- mirrors today's inline logic in
    `certification_list_content.dart`.
  - `agency`: one group per `certification.agency` (the primary agency only;
    `additionalCredentials` never create or join a group -- a PADI card with a
    CMAS cross-over groups only under PADI, per the issue's scope decision).
    Groups sort alphabetically by `AgencyEntry.localizedName(l10n)`
    (case/accent folded with the existing `TextCollator`/`textSortKey` from
    `core/text/text_sort.dart`, same as the Dive Sites grouping).
  - `none`: returns `const []`; callers treat an empty group list as "render
    the sorted list flat, no headers" (mirrors `SiteGroupBy.none` returning
    `const []` in `groupSitesFor`).
  - Certifications keep their incoming (already-sorted) order inside each
    group.
- `List<Certification> flattenCertificationGroups(CertificationGroupBy groupBy,
  List<Certification> sortedCertifications, {required AppLocalizations l10n,
  CertificationCatalog? catalog})`: the sorted list unchanged for `none`,
  else the groups' certifications concatenated in group order. Used by the
  list's keyboard navigation and directly by the wallet grid (which has no
  headers at all, even for status/agency -- card order only, per the issue's
  stretch-goal scope decision).

## Presentation layer

- `lib/features/certifications/presentation/providers/certification_grouping_providers.dart`:
  `certificationGroupByProvider = StateProvider<CertificationGroupBy>((ref) =>
  CertificationGroupBy.status)`. App-wide, not routed-scoped, like
  `siteGroupByProvider` -- shared by the list and the wallet page so the
  grouping survives the view switch (issue's explicit requirement).
- `lib/features/certifications/presentation/utils/certification_group_by_display.dart`:
  `localizedName(AppLocalizations)` extension, exhaustive switch.
- `lib/features/certifications/presentation/widgets/certification_group_by_selector.dart`:
  `CertificationGroupBySelector`, a direct port of `SiteGroupBySelector`'s
  `RadioGroup` pattern over `CertificationGroupBy.values`.
- `lib/features/certifications/presentation/widgets/certification_view_switch_selector.dart`:
  - `enum CertificationView { list, wallet }` (route-driven, not a provider --
    the current view is whichever page is on screen, not persisted state).
  - `CertificationViewSwitchSelector({required CertificationView currentView})`:
    a second `RadioGroup` footer section, List / Certification Wallet.
    Selecting the view already showing closes the sheet and does nothing.
    Selecting Wallet from List: `context.push('/certifications/wallet')`
    (same as today's wallet icon). Selecting List from Wallet: `context.pop()`
    if possible, else `context.go('/certifications')` -- the wallet route is
    always pushed from the list, so a pop is always available in practice,
    but the fallback keeps it correct if that ever changes.
- `lib/features/certifications/presentation/widgets/certification_sort_sheet.dart`:
  `showCertificationSortSheet(BuildContext, WidgetRef, {required
  CertificationView currentView, bool includeGroupBySelector = true})`, the
  one place that calls `showSortBottomSheet<CertificationSortField>`. The
  footer is always `CertificationViewSwitchSelector`; when
  `includeGroupBySelector` is true (the default) it is preceded by
  `CertificationGroupBySelector` + a `Divider`. `certification_list_content.dart`
  and `certification_wallet_page.dart` call this with the default (both show
  grouping); `certification_list_page.dart`'s **table-mode** sort button
  (`appBarActions`, currently a bare `showSortBottomSheet` call with no
  footer at all -- a third call site the first pass of this plan missed)
  calls it with `includeGroupBySelector: false`, since "table mode stays
  flat, with no grouping option there" (issue's own wording) but the issue
  does not exclude table mode from the List/Wallet view switch, and table
  mode's sort sheet should offer it for the same reason the phone and
  compact bars do.

## Changes to existing files

- `certification_list_content.dart`: the two existing sort-icon `onPressed`
  call sites switch to `showCertificationSortSheet(context, ref, currentView:
  CertificationView.list)`, replacing the private `_showSortSheet`.
  `_buildCertificationList` replaces its hardcoded expired/expiringSoon/valid
  grouping with `groupCertificationsFor(ref.watch(certificationGroupByProvider),
  sortedCerts, l10n: ..., catalog: ...)`, branching directly on
  `groupBy == CertificationGroupBy.none` for the flat/no-header path (not on
  whether the group list happens to be empty). `_buildSectionHeader` gains a
  nullable color argument: status groups pass their existing fixed color,
  agency groups pass `null` (plain header, no dot). The
  `KeyboardListNavigator` keys use `flattenCertificationGroups(...)` instead
  of the old manual concatenation. Table mode's content widget is
  unaffected (stays flat, no grouping control there, per the issue) --
  only its sort button, in `certification_list_page.dart`, changes (below).
- `certification_wallet_page.dart`: watches `certificationSortProvider` and
  `certificationGroupByProvider`, applies `applyCertificationSorting` then
  `flattenCertificationGroups` before handing the list to
  `CertificationEcardGrid` (today it hands the raw, unsorted list straight
  through). Adds a sort `IconButton` to the `AppBar`'s `actions`, before the
  add button, calling `showCertificationSortSheet(context, ref, currentView:
  CertificationView.wallet)`.
- `certification_list_page.dart`: the table-mode sort `IconButton`'s
  `onPressed` switches from its inline `showSortBottomSheet` call to
  `showCertificationSortSheet(context, ref, currentView: CertificationView.list,
  includeGroupBySelector: false)`.

## Out of scope (per issue)

- No subgrouping, no collapsible groups, no persisting the choice across app
  restarts.
- Visible group headers inside the wallet's card grid: stretch goal, not
  built here -- the grid gets card ordering only.
- The wallet ignoring the list's search/query filter (issue's "related
  finding"): left unfixed here and called out explicitly in the PR
  description as a known, pre-existing limitation, since the issue frames
  fixing it as optional and splitting it as an equally valid option with no
  stated preference -- fixing it here would widen this PR's diff with a
  second, unrelated filtering concern.

## New localization keys (`app_en.arb`, template only)

- `certifications_list_groupBy` ("Group by")
- `certifications_list_groupBy_status` ("Status")
- `certifications_list_groupBy_agency` ("Agency")
- `certifications_list_groupBy_none` ("None")
- `certifications_sortSheet_view_list` ("List")
- `certifications_sortSheet_view_wallet` ("Certification Wallet")
- `certifications_wallet_tooltip_sort` ("Sort")

`test/l10n/arb_parity_test.dart` requires every key translated in all ten
non-English locales (not just present in the English template, as first
assumed here) -- all seven keys were translated into all ten locales as
part of this PR.

## Tests (written first, TDD)

- `test/features/certifications/presentation/utils/certification_grouping_test.dart`:
  status grouping (fixed order, empty groups hidden), agency grouping
  (alphabetical by localized name, primary-agency-only for multi-credential
  cards), none (empty list), flattening for all three modes.
- `certification_list_content_test.dart`: add a group covering status
  grouping (today's behavior, now via the new path), agency grouping, and
  none (no section headers rendered, flat order).
- `certification_wallet_page_test.dart`: add a group covering sort+group
  order reaching the grid, and the new sort button opening the sheet.
- New `certification_view_switch_selector_test.dart` and
  `certification_sort_sheet_test.dart` (or folded into the above) covering
  the List<->Wallet navigation both directions and sort/group state surviving
  the switch.
