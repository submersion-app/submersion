# Trimix Blender Invoice Archive: List View, Filter, Total (issue #1335) — Analysis

Date: 2026-09-02
Issue: [#1335](https://github.com/submersion-app/submersion/issues/1335)
Branch: `fix/issue-1335-archiv-uebersicht` (based on `fix/issue-1335-abrechnung-erweiterung`)

Analysis only. No code, migration, or UI changes in this phase.

## Scope

`fix/issue-1335-abrechnung-erweiterung` (PR #39) introduced a "Pay" action
that archives the running bill (`BlenderInvoiceCard._confirmPay()`) instead
of just clearing it. This phase designs the view that lists what gets
archived: every paid invoice, filterable (at least by date), with a total
over the filtered selection. The `ArchivedInvoice` doc comment already
anticipates this:

> A minimal record rather than a full invoice history feature (that is
> issue #22) - just enough that archiving loses nothing, so a later history
> view has real data to build on instead of starting from zero.

## 1. The existing `ArchivedInvoice` structure

`lib/features/gas_calculators/domain/blending/billed_fill.dart:166-231`:

```dart
const int kMaxArchivedInvoices = 50;

class ArchivedInvoice {
  final String id;
  final DateTime date;
  final String billedTo;
  final List<BilledFill> fills;
  final double? total; // null when paid with an unpriced line still on it
}

List<ArchivedInvoice> appendArchivedCapped(
  List<ArchivedInvoice> invoices,
  ArchivedInvoice invoice,
);
```

- **Storage:** part of `BlenderPreferences` (`archivedInvoices` field,
  `blender_preferences.dart:88/134/189/205/246-253/270`), which is itself
  one JSON blob under the `gas_blender_prefs` settings key
  (`AppSettingsRepository.setBlenderPreferences`/`getBlenderPreferences`) —
  confirmed as real DB persistence, not in-memory-only, in the verification
  comment on PR #29 (2026-09-02 15:11 UTC). Adding fields to
  `ArchivedInvoice` is additive JSON, no Drift migration.
- **Access provider:** `blenderArchivedInvoicesProvider` in
  `gas_blender_providers.dart:92`, a plain
  `StateProvider<List<ArchivedInvoice>>`, oldest-first, capped client-side
  at `kMaxArchivedInvoices = 50` by `appendArchivedCapped` (same
  drop-oldest-on-append shape as `appendCapped` for `billedFills`, and the
  same off-by-one bug class was already fixed once for that sibling
  function per the PR #1215 review noted in the file — worth re-reading if
  this cap logic gets touched again).
- **Written by:** `BlenderInvoiceCard._confirmPay()`
  (`blender_invoice_card.dart:507-546`) only. No delete/edit path exists
  yet for an archived entry.
- **Gap found:** `ArchivedInvoice` has no `currencyCode` field. `total` is
  a bare `double`. The currency it was billed in is only ever the *global*
  `blenderCurrencyProvider` (itself just a mirror of the diver's
  `defaultCurrency`) at render time — not a snapshot at archive time. If
  the diver's default currency changes between two "Pay" clicks, older
  archived totals would silently render in the new currency label when the
  archive view sums or displays them. This matters directly for "Gesamtsumme
  über die gefilterte Auswahl": see §4.

## 2. Existing list + filter + aggregate patterns to reuse

Two established patterns in the codebase, both directly transplantable;
neither requires a new architectural idea.

### Pattern A — `PreDiveSessionsPage` (closest match for the page shape)

- `lib/features/pre_dive/domain/models/pre_dive_session_filter.dart`:
  immutable `PreDiveSessionFilter` (`Equatable`), one field per facet, a
  `dateRange` (`DateTimeRange?`), `hasActiveFilters` getter,
  `apply(sessions, stats)` that filters, and `copyWith(..., clearDateRange:
  bool)` using the clear-sentinel pattern the whole codebase uses for
  nullable `copyWith` fields.
- `lib/features/pre_dive/presentation/providers/pre_dive_providers.dart:88-103`:
  ```dart
  final preDiveSessionFilterProvider =
      StateProvider<PreDiveSessionFilter>((ref) => const PreDiveSessionFilter());

  final filteredPreDiveSessionsProvider =
      Provider<AsyncValue<List<PreDiveSession>>>((ref) {
    final sessionsAsync = ref.watch(preDiveSessionsProvider);
    final filter = ref.watch(preDiveSessionFilterProvider);
    return sessionsAsync.whenData((sessions) => filter.apply(sessions, stats));
  });
  ```
  Comment on the filter provider: *"Ephemeral by design, matching the
  dive-list and trip-list filters: a filter is a view of the current
  screen, not a stored preference."* — the archive filter should be the
  same, a `StateProvider`, not persisted into `BlenderPreferences`.
- `lib/features/pre_dive/presentation/widgets/pre_dive_session_filter_sheet.dart`:
  `showModalBottomSheet(isScrollControlled: true, ...)` →
  `DraggableScrollableSheet`, edits held in local `State` and committed to
  the provider only on "Apply" (so the list behind the sheet does not churn
  while choosing). Date range picked via `showAppDateRangePicker` (already
  used for exactly this kind of history filter in
  `gps_track_date_filter_action.dart`, `media_library_filter_sheet.dart`,
  and `pre_dive_session_filter_sheet.dart`).
- `lib/features/pre_dive/presentation/pages/pre_dive_sessions_page.dart`:
  `AppBar` with a badge-on-filter-icon (`Badge(isLabelVisible:
  filter.hasActiveFilters, ...)`) opening the sheet, a dismissible
  `_ActiveFilterBar` (chips with `onDeleted` clearing one facet at a time),
  and two distinct empty states — "nothing here at all" vs. "your filter
  hides everything" (`_FilteredEmptyState`, with its own "clear all"
  action). This distinction matters here too: an empty archive and an
  over-narrow date range should not look the same.

### Pattern B — Equipment `ServiceHistorySection` (closest match for the money total)

- `lib/features/equipment/domain/entities/maintenance_history_filter.dart`
  + `lib/features/equipment/presentation/widgets/service_history_section.dart`:
  filter is local `State` (not a provider) since it does not need to
  outlive the section; `records.where(_filter.matches).toList()` computed
  inline in `build()`.
- The total, `service_history_section.dart:144-149`:
  ```dart
  final totals = sumByCurrency<ServiceRecord>(
    visible, // the already-filtered list, not the raw one — #1236
    amountOf: (r) => r.cost,
    currencyOf: (r) => r.currency,
    fallbackCode: ref.watch(defaultCurrencyProvider),
  ).where((e) => e.value > 0).toList();
  ```
  `sumByCurrency` (`lib/core/utils/currency.dart:70-91`) is a generic
  helper already built for exactly this: it groups by currency code so a
  history spanning more than one currency never gets added into one
  misleading figure, and is already used twice (equipment cost summary,
  equipment service history). The doc comment on the equipment call site is
  explicit that the total must be computed **from the filtered list**, so
  the displayed sum always matches what is listed below it — the same rule
  applies to the invoice archive's "Gesamtsumme über die gefilterte
  Auswahl".
- Rendered with the same `formatMoney(amount, code)` helper the blender
  cards already use for the running bill (`blender_invoice_card.dart:142`,
  `blender_billing_card.dart`), so no new formatting code is needed.

**Recommendation:** follow Pattern A for the page/sheet/provider shape
(`ArchivedInvoiceFilter` modeled on `PreDiveSessionFilter`, with at least a
`dateRange` facet, possibly `billedTo` as a free-text facet later), and
Pattern B for the total row, once §1's currency gap is closed (below).

## 3. Where the list itself comes from

Unlike `PreDiveSession` (DB-backed, `FutureProvider`) or `ServiceRecord`
(DB-backed, `AsyncNotifier`), `ArchivedInvoice` lives entirely in the
in-memory `blenderArchivedInvoicesProvider` `StateProvider`, seeded once by
`blenderPreferencesLoaderProvider`. That makes the filtered/total providers
simpler than either precedent — no `AsyncValue` unwrapping needed:

```dart
final archivedInvoiceFilterProvider =
    StateProvider<ArchivedInvoiceFilter>((ref) => const ArchivedInvoiceFilter());

final filteredArchivedInvoicesProvider = Provider<List<ArchivedInvoice>>((ref) {
  final invoices = ref.watch(blenderArchivedInvoicesProvider);
  final filter = ref.watch(archivedInvoiceFilterProvider);
  return filter.apply(invoices);
});
```

## 4. Currency gap and its effect on the total

Since `ArchivedInvoice` carries no currency of its own, `sumByCurrency`
cannot actually distinguish invoices billed in different currencies — every
invoice's `total` would be attributed to whatever `fallbackCode` (today's
`blenderCurrencyProvider`) is passed in, even one paid months ago in a
different currency. Two options for the follow-up implementation phase:

- **Minimal:** accept the limitation for now (the blender's currency is a
  single global app setting today, so multi-currency history is already an
  edge case, not the common path) and note it as a known simplification in
  the archive view.
- **Correct:** add an optional `currencyCode` field to `ArchivedInvoice`
  (additive JSON, no migration, same pattern as `freeGasLiters` on
  `BilledGasLine` from the prior phase), snapshotted from
  `blenderCurrencyProvider` at "Pay" time in `_confirmPay()`, with a
  `?? currentCurrency` fallback on read for invoices archived before the
  field existed (mirrors how `freeGasLiters` falls back to pressure display
  for old rows).

Recommend the "Correct" option since it is a small, additive, low-risk
change and makes the archive's total trustworthy from day one rather than
introducing a second known gap on top of the first.

## 5. Routing and entry point

- Gas calculators route the child tools generically: `app_router.dart:282-297`,
  a `gas-calculators` parent `GoRoute` whose `routes:` list is built with
  `for (final id in kGasCalculatorIds) GoRoute(path: id, ...)`. The blender
  itself is a leaf (`gas-calculators/blender`), with no sub-routes today.
- The router already mixes generated and static children within one
  `routes:` list elsewhere (see the comment at `app_router.dart:270`:
  *"static children (compare/chart) still win route matching"* for
  `dive-planner`), so adding one explicit sibling route beside the
  generated loop is an established pattern, not a new one:
  ```dart
  routes: [
    for (final id in kGasCalculatorIds) GoRoute(path: id, ...),
    GoRoute(
      path: 'blender/invoices',
      builder: (context, state) => const BlenderInvoiceArchivePage(),
    ),
  ],
  ```
- `_ManageSectionContent` in `settings_page.dart:2287` (Settings > Manage)
  only lists catalog/configuration entries (dive types, tank presets,
  service types, checklist templates, ...) — a transactional history view
  does not fit that convention, matching how equipment's own history
  sections live under the equipment feature, not under Settings.
- **Recommended entry point:** a small icon button (e.g. `Icons.history`)
  next to the existing edit-date icon in `BlenderInvoiceCard._dateHeader`
  (`blender_invoice_card.dart:197-224`), navigating to
  `gas-calculators/blender/invoices`. That header already holds one
  icon-button-next-to-title row, so a second icon fits the existing layout
  without a new UI region. Also note: this branch (based on `upstream/main`
  via PR #39) does **not** have the Trimix-Mixer settings-page
  reorganisation from PR #29/#1359 (no gear icon, no
  `/settings/trimix-mixer` route) — the entry point must be designed
  against what exists on *this* branch, and reconciled later when the two
  branches eventually merge.

## Open questions for the implementation phase

1. Confirm the "Correct" currency-snapshot option from §4, or explicitly
   accept the "Minimal" simplification instead.
2. Filter facets beyond date range: `billedTo` (free text billed-to name)
   is the only other field on `ArchivedInvoice` besides date/total, and a
   free-text substring filter is a small addition to `apply()` if wanted
   for this phase; can also be deferred.
3. Detail view: should tapping an archived invoice open a read-only
   expansion of its `fills`/`BilledGasLine`s (reusing the existing
   `_fillLine` rendering from `BlenderInvoiceCard`), or is a summary row
   (date, billedTo, total) enough for this phase, with drill-down left to
   the full issue #22 history feature? Not decided here.
