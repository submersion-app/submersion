# Unified Dive Search, PR 2: the Refine Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Filter sheet and the Advanced Search page with one Refine panel (the union of both forms' axes, in eight collapsible groups, applied with a live "Show N dives" button), used by the dive list's search row, Insights and Connections.

**Architecture:** `RefinePanel` holds one draft `DiveFilterState` seeded from the target provider. Eight small group widgets each edit their own fields of that draft through `onChanged(draft.copyWith(...))`; the panel writes `draft.copyWith(axesSuspended: false)` back on Apply. `showRefinePanel` opens it as a bottom sheet below the master-detail breakpoint and as a right-side panel at or above it. A source-level guard test fails if any `DiveFilterState` field is neither edited by a group nor on a short, explained allowlist.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` via `core/providers/provider.dart`), go_router, gen-l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-02-unified-dive-search-design.md` (sections 4.2, 5.6, 6, 7, 8, 11). Issue #2773. Branch `ericgriffin/dive-search-refine-panel`, stacked on PR 1 (#2789); the PR targets `main` and its body says to review only its own commits.

## Global Constraints

- Never use the em-dash character, or an en-dash as punctuation, anywhere (code, comments, commits, ARB values, PR text).
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file.
- Every user-visible string goes through `context.l10n`; every new key is translated into all 10 non-en ARBs; `flutter gen-l10n` runs LAST. fr/pt plural `=1{...}` branches interpolate their argument; ar/he keep word forms.
- Units shown or typed follow the active diver's settings (`UnitFormatter(ref.watch(settingsProvider))`); stored values stay metric.
- Paths in tests via `p.join`; process-wide state restored in `addTearDown`.
- Files under 800 lines (target under 350 per group file).
- Imports grouped dart, flutter, packages, local.
- `dart format .` before every commit; conventional commit messages, no trailers.
- PR body: `Refs #2773`, screenshots before/after, phone and desktop, light and dark.

## Rulings made while planning (confirm at review)

1. **Group summaries are a count** ("Any", "2 set"), not the label text the mockup showed ("Depth > 30 m"). Labels for site, trip, center, computer and species names need each group's providers in the collapsed header; a count keeps the header cheap. Cost if wrong: one follow-up to render labels.
2. **Where the two forms differed, the panel keeps the better variant:** localized dive type names (sheet), tags filtered to `TagScope.dives` (sheet), the Trimix gas chip (page), buddy-name autocomplete (sheet), the localized minutes suffix (sheet).
3. **Clear all resets the draft only** (including the query); nothing is written until "Show N dives", as the spec's "nothing changes until you press it" requires. Today's sheet wrote and closed at once.
4. **A saved-query chip applies at once and closes the panel, keeping the other axes** (today's sheet behaviour). Spec 4.2's "loads the whole saved search" depends on whole-search saving, which is PR 4; PR 4 changes the chip.
5. **`buddyId`, `diveIds` and `siteIds` get no control.** Neither form edits them (they come from handoffs: buddy page, Connections, Explore places); their chips in the search row stay removable, and the panel preserves them.
6. **The `/dives/search` route redirects to `/dives` and opens the search row**, as spec 5.8 says.

## Review Focus

1. **Unit round trip:** a diver on feet / Fahrenheit opens the panel with a depth, temperature and visibility bound set and presses Show without touching them: the stored metric values must not drift (no re-conversion of a rounded display value). Pinned in Task 5.
2. **Clear all, then Cancel:** nothing changes in the list; Clear all, then Show: everything (query included) clears. Pinned in Task 3.
3. **A computer deleted while its filter is set** resolves to All computers on Show; a computer list still loading keeps the id (the sheet's #1064 rules). Pinned in Task 6.
4. **Insights and Connections** write their own provider, never the dive list's, and Insights stays on Insights after Show. Pinned in Task 10.
5. **Side panel at desktop width:** the list stays visible to the left of the panel, and a tap on that dimmed area closes the panel without applying anything. Pinned in Task 2.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/features/dive_log/presentation/widgets/refine/refine_panel.dart` | create | draft state, header (title, Clear all), saved-query chips, group list, Cancel / Show N |
| `lib/features/dive_log/presentation/widgets/refine/show_refine_panel.dart` | create | bottom sheet vs right-side panel |
| `lib/features/dive_log/presentation/widgets/refine/refine_group_tile.dart` | create | collapsible group scaffold with summary |
| `lib/features/dive_log/presentation/widgets/refine/refine_count_provider.dart` | create | live match count for a draft |
| `lib/features/dive_log/presentation/widgets/refine/groups/refine_date_group.dart` | create | date range, presets, weekdays |
| `.../groups/refine_location_group.dart` | create | site, trip, dive center |
| `.../groups/refine_conditions_group.dart` | create | depth, bottom time, deco, water temp, visibility, water type |
| `.../groups/refine_gas_equipment_group.dart` | create | dive type, gas mix, equipment, gear attributes, suit thickness, computer |
| `.../groups/refine_people_group.dart` | create | buddy name, no buddy, species |
| `.../groups/refine_organization_group.dart` | create | tags, rating, favorites, excluded from statistics |
| `.../groups/refine_custom_fields_group.dart` | create | custom field key and value |
| `.../groups/refine_rules_group.dart` | create | the query editor (Text + Builder) with Save |
| `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart` | modify | Refine button opens the panel |
| `lib/features/insights/presentation/widgets/insights_filter_action.dart` | modify | opens the panel |
| `lib/features/connections/presentation/panel/filter_tab.dart` | modify | opens the panel |
| `lib/core/router/app_router.dart` | modify | `/dives/search` redirects |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, `pages/dive_list_page.dart` | modify | remove the Advanced Search overflow items |
| `dive_filter_sheet.dart`, `pages/dive_search_page.dart` and their tests | delete | replaced |
| `test/features/dive_log/presentation/widgets/refine/...` | create | one test file per unit, plus the axis guard |

`dive_filter_gear_attributes_section.dart`, `searchable_filter_dropdown.dart`, `weekday_filter_selector.dart` and `filter_option_search.dart` are reused unchanged.

## Porting rules (Tasks 4 to 9)

Each group ports builder code from `dive_filter_sheet.dart` (A) or `dive_search_page.dart` (B) at the line ranges given in its task, applying exactly these transformations, and nothing else:

1. A read of a local draft variable `_x` becomes `widget.draft.x` (bool flags: `widget.draft.x ?? false`).
2. `setState(() { _x = v; })` becomes `widget.onChanged(widget.draft.copyWith(x: v, clearX: v == null))`, using the clear flag `copyWith` already has for that field (list fields pass the new list; `favoritesOnly: v ? true : null, clearFavoritesOnly: !v` as A does).
3. Text controllers and focus nodes stay in the group's `State`, seeded in `initState` from `widget.draft` exactly as A's / B's `initState` seeds them (same conversion helpers), and disposed in `dispose`. A group is rebuilt from scratch after Clear all (the panel changes its key), so controllers never need re-seeding from outside.
4. `NumberField.onChanged` keeps its switch: `NumberValue` converts and writes, `NumberBlank` writes null, `NumberInvalid` does nothing (the draft keeps its previous value).
5. Section headings become the group's sub-labels (same l10n keys); the `SizedBox(height: 24)` spacers between sections become `SizedBox(height: 16)`.

---

### Task 1: Live match count and new strings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/refine/refine_count_provider.dart`
- Modify: the 11 ARBs, regenerate
- Test: `test/features/dive_log/presentation/widgets/refine/refine_count_provider_test.dart`

**Interfaces:**
- Produces: `final refineMatchCountProvider = FutureProvider.autoDispose.family<int, DiveFilterState>(...)`; l10n getters `diveLog_refine_title`, `diveLog_refine_groupRules`, `diveLog_refine_groupPeople`, `diveLog_refine_groupCustomFields`, `diveLog_refine_summaryAny`, `diveLog_refine_summaryCount(int count)`, `diveLog_refine_showDives(int count)`, `diveLog_refine_showDivesNoCount`.

- [ ] **Step 1: Write the failing test** (real repository on the test DB, as PR 1's jump provider test)

```dart
// imports as test/features/dive_log/presentation/providers/dive_search_providers_test.dart
void main() {
  late DiveRepository repository;
  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    for (final (id, depth) in [('a', 10.0), ('b', 35.0), ('c', 40.0)]) {
      await repository.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), maxDepth: depth),
      );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repository),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<int> count(ProviderContainer c, DiveFilterState f) {
    final sub = c.listen(refineMatchCountProvider(f), (_, _) {});
    addTearDown(sub.close);
    return c.read(refineMatchCountProvider(f).future);
  }

  test('counts the dives a draft matches', () async {
    final c = make();
    expect(await count(c, const DiveFilterState()), 3);
    expect(await count(c, const DiveFilterState(minDepth: 30)), 2);
  });

  test('a suspended draft counts the query alone', () async {
    final c = make();
    expect(
      await count(c, const DiveFilterState(minDepth: 30, axesSuspended: true)),
      3,
    );
  });
}
```

- [ ] **Step 2: Run, expect a compile failure** (`refine_count_provider.dart` missing).

Run: `flutter test test/features/dive_log/presentation/widgets/refine/refine_count_provider_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// How many dives a Refine panel draft matches, for its "Show N dives"
/// button (#2773). Keyed on the draft's value, so an unchanged draft reuses
/// its answer and every edit asks once.
final refineMatchCountProvider = FutureProvider.autoDispose
    .family<int, DiveFilterState>((ref, draft) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      return repository.getDiveCount(diverId: diverId, filter: draft);
    });
```

- [ ] **Step 4: Add the strings** with a scratchpad script modelled on PR 1's `add_search_keys.py` (anchor on `"diveLog_listPage_tooltip_searchDives"`). Plural keys carry `@` metadata with a `count` placeholder of type `int` in `app_en.arb` only.

| key | en | notes |
|---|---|---|
| `diveLog_refine_title` | Refine | ar تحسين البحث, de Verfeinern, es Refinar, fr Affiner, he צמצום, hu Szűkítés, it Affina, nl Verfijnen, pt Refinar, zh 细化 |
| `diveLog_refine_groupRules` | Rules | ar القواعد, de Regeln, es Reglas, fr Règles, he כללים, hu Szabályok, it Regole, nl Regels, pt Regras, zh 规则 |
| `diveLog_refine_groupPeople` | People & life | ar الأشخاص والكائنات, de Personen & Lebewesen, es Personas y vida marina, fr Personnes et faune, he אנשים וחיים ימיים, hu Személyek és élővilág, it Persone e vita marina, nl Personen & leven, pt Pessoas e vida marinha, zh 人员与生物 |
| `diveLog_refine_groupCustomFields` | Custom fields | ar الحقول المخصصة, de Benutzerdefinierte Felder, es Campos personalizados, fr Champs personnalisés, he שדות מותאמים, hu Egyéni mezők, it Campi personalizzati, nl Aangepaste velden, pt Campos personalizados, zh 自定义字段 |
| `diveLog_refine_summaryAny` | Any | ar أي, de Alle, es Cualquiera, fr Tous, he הכול, hu Bármely, it Qualsiasi, nl Alle, pt Qualquer, zh 任意 |
| `diveLog_refine_summaryCount` | `{count, plural, =1{1 set} other{{count} set}}` | de `=1{{count} gesetzt} other{{count} gesetzt}`, es `=1{{count} activo} other{{count} activos}`, fr `=1{{count} actif} other{{count} actifs}`, it `=1{{count} attivo} other{{count} attivi}`, nl `=1{{count} ingesteld} other{{count} ingesteld}`, pt `=1{{count} ativo} other{{count} ativos}`, hu `=1{{count} beállítva} other{{count} beállítva}`, zh `=1{已设 {count} 项} other{已设 {count} 项}`, ar `=1{عامل واحد} other{{count} عوامل}`, he `=1{מסנן אחד} other{{count} מסננים}` |
| `diveLog_refine_showDives` | `{count, plural, =1{Show 1 dive} other{Show {count} dives}}` | de `=1{{count} Tauchgang anzeigen} other{{count} Tauchgänge anzeigen}`, es `=1{Mostrar {count} inmersión} other{Mostrar {count} inmersiones}`, fr `=1{Afficher {count} plongée} other{Afficher {count} plongées}`, it `=1{Mostra {count} immersione} other{Mostra {count} immersioni}`, nl `=1{{count} duik tonen} other{{count} duiken tonen}`, pt `=1{Mostrar {count} mergulho} other{Mostrar {count} mergulhos}`, hu `=1{{count} merülés megjelenítése} other{{count} merülés megjelenítése}`, zh `=1{显示 {count} 次潜水} other{显示 {count} 次潜水}`, ar `=1{عرض غوصة واحدة} other{عرض {count} غوصات}`, he `=1{הצגת צלילה אחת} other{הצגת {count} צלילות}` |
| `diveLog_refine_showDivesNoCount` | Show dives | ar عرض الغوصات, de Tauchgänge anzeigen, es Mostrar inmersiones, fr Afficher les plongées, he הצגת צלילות, hu Merülések megjelenítése, it Mostra immersioni, nl Duiken tonen, pt Mostrar mergulhos, zh 显示潜水 |

Then `flutter gen-l10n`, then `flutter test test/l10n` (the plural guards must pass).

- [ ] **Step 5: Run the provider test and `test/l10n`; expect PASS. Commit** (`feat(dive-log): add the Refine panel's match count and strings`).

---

### Task 2: Group tile and `showRefinePanel`

**Files:**
- Create: `refine/refine_group_tile.dart`, `refine/show_refine_panel.dart`
- Test: `test/.../refine/show_refine_panel_test.dart`

**Interfaces:**
- Produces:
  - `class RefineGroupTile extends StatelessWidget { const RefineGroupTile({super.key, required this.title, required this.activeCount, required this.child}); }`, an `ExpansionTile` whose subtitle is `diveLog_refine_summaryAny` or `diveLog_refine_summaryCount(activeCount)`, `initiallyExpanded: activeCount > 0`, `childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16)`.
  - `Future<void> showRefinePanel(BuildContext context, {required StateProvider<DiveFilterState> filterProvider, VoidCallback? onApplied})`
  - `const kRefinePanelSideWidth = 440.0;`

- [ ] **Step 1: Tests** (Review Focus 5): at 390x844 the panel opens as a `BottomSheet`; at 1280x800 it opens as a right-aligned `Material` of width `kRefinePanelSideWidth` with the page still painted to its left; tapping the barrier left of the panel closes it without writing the provider. Host: a `Scaffold` with an `ElevatedButton` calling `showRefinePanel` with a test `StateProvider`, plus a stub `RefinePanel`-sized child (Task 3 provides the real panel; for this task `showRefinePanel` takes an optional `@visibleForTesting Widget Function()? builder` used only by this test).

- [ ] **Step 2: Implement**

```dart
/// Opens the Refine panel for [filterProvider] (#2773): a bottom sheet on
/// narrow layouts, a right-side panel from the master-detail breakpoint up
/// so the list stays in view beside it.
Future<void> showRefinePanel(
  BuildContext context, {
  required StateProvider<DiveFilterState> filterProvider,
  VoidCallback? onApplied,
  @visibleForTesting Widget Function()? builder,
}) {
  Widget panel() =>
      builder?.call() ??
      RefinePanel(filterProvider: filterProvider, onApplied: onApplied);
  if (!ResponsiveBreakpoints.isMasterDetail(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: panel()),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        elevation: 8,
        child: SizedBox(
          width: kRefinePanelSideWidth,
          height: double.infinity,
          child: SafeArea(child: panel()),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: child,
    ),
  );
}
```

(`RefinePanel` does not exist until Task 3: in this task the default branch references it behind the import; create `refine_panel.dart` with an empty `RefinePanel` stub `({required filterProvider, onApplied})` returning `SizedBox.shrink()` so the file compiles, replaced in Task 3.)

- [ ] **Step 3: Run the tests; PASS. Commit** (`feat(dive-log): open the Refine panel as a sheet or a side panel`).

---

### Task 3: `RefinePanel` shell (draft, header, chips, actions)

**Files:**
- Modify: `refine/refine_panel.dart` (replace the stub)
- Test: `test/.../refine/refine_panel_test.dart`

**Interfaces:**
- Consumes: `refineMatchCountProvider`, `RefineGroupTile`, `SavedQueryChipRow(subject: QuerySubject.dives, onApply:)`.
- Produces: `class RefinePanel extends ConsumerStatefulWidget { const RefinePanel({super.key, required this.filterProvider, this.onApplied}); }`; keys `kRefineApplyKey = ValueKey('refine-apply')`, `kRefineClearAllKey = ValueKey('refine-clear-all')`, `kRefineCancelKey = ValueKey('refine-cancel')`. State exposes nothing public; groups are added to `_groups(...)` by Tasks 4 to 9.

Behaviour:
- `_draft` seeded in `initState` from `ref.read(widget.filterProvider)`; `_generation` int.
- Header row: title `diveLog_refine_title`, `TextButton(key: kRefineClearAllKey)` with `diveLog_filter_clearAll` that does `setState(() { _draft = const DiveFilterState(); _generation++; })`.
- `SavedQueryChipRow` (dives): `onApply` writes `current.copyWith(query: load.node, axesSuspended: false)` to the provider at once, calls `onApplied`, pops (ruling 4).
- Body: `ListView` of `KeyedSubtree(key: ValueKey(_generation), child: Column(children: _groups()))`.
- Bottom bar (pinned, never scrolls away): `TextButton(key: kRefineCancelKey)` `diveLog_search_cancel` pops; `FilledButton(key: kRefineApplyKey)` labelled `diveLog_refine_showDives(n)` from the count of `_draft`, keeping the last known count while the next loads (a `_lastCount` field) and `diveLog_refine_showDivesNoCount` when unknown or errored (spec 6). Apply: `ref.read(widget.filterProvider.notifier).state = _resolvedDraft().copyWith(axesSuspended: false)`, `onApplied?.call()`, `Navigator.pop`.
- `_resolvedDraft()` runs each group's static `resolveOnApply(DiveFilterState, WidgetRef)` (only the gas and equipment group defines one; the others are identity).

- [ ] **Step 1: Tests** (Review Focus 2):
  - opens with the provider's value; Cancel leaves the provider unchanged;
  - Clear all then Cancel: provider unchanged;
  - Clear all then Show: provider becomes `const DiveFilterState()` (query included);
  - Show writes `axesSuspended: false` even if the provider had it true;
  - the button reads "Show 2 dives" when `refineMatchCountProvider` is overridden to 2, keeps "Show 2 dives" while a new draft's count is pending (`Completer`), and reads "Show dives" when the count errors;
  - a saved chip applies at once, keeps `minDepth`, closes (override `savedQueryLoadsProvider` as `saved_query_chip_row_test.dart` does).
- [ ] **Step 2: Run, FAIL. Step 3: implement. Step 4: PASS. Step 5: Commit** (`feat(dive-log): add the Refine panel shell`).

---

### Task 4: Date group

**Files:** create `groups/refine_date_group.dart`; test `test/.../refine/groups/refine_date_group_test.dart`.

**Interfaces:** every group in Tasks 4 to 9 has this shape:

```dart
class RefineDateGroup extends ConsumerStatefulWidget {
  const RefineDateGroup({super.key, required this.draft, required this.onChanged});
  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'startDate', 'endDate', 'weekdays'};

  static int activeCount(DiveFilterState f) =>
      [f.startDate != null || f.endDate != null, f.weekdays.isNotEmpty]
          .where((a) => a)
          .length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_dateRange;
}
```

and the panel wraps it: `RefineGroupTile(title: RefineDateGroup.title(l10n), activeCount: RefineDateGroup.activeCount(_draft), child: RefineDateGroup(draft: _draft, onChanged: _update))`.

Port: A 380-550 (presets, pickers, clear dates, weekdays) and A 1478-1515 (`_datePresetChip`, `_selectDate`, now taking the group's draft), per the porting rules.

- [ ] Tests (port from `dive_filter_sheet_presets_test.dart`, `dive_filter_sheet_weekday_test.dart` and the date cases of `dive_filter_sheet_interactions_test.dart`): each preset writes its range; All time clears; Clear dates clears; a picked start date writes `startDate`; weekday chip toggles; Clear weekdays clears. Host: a `StatefulBuilder` holding a draft and rendering the group, asserting on the draft.
- [ ] Register the group in `RefinePanel._groups()` (order, with Rules added in Task 8: Rules, Date, Location, Conditions, Gas and equipment, People and life, Organization, Custom fields).
- [ ] Commit (`feat(dive-log): Refine panel date group`).

### Task 5: Conditions group (Review Focus 1)

Fields: `minDepth, maxDepth, minBottomTimeMinutes, maxBottomTimeMinutes, decoOnly, minWaterTemp, maxWaterTemp, minVisibility, maxVisibility, waterTypes`. Title: `diveLog_search_section_conditions`.

Port: A 718-756 (depth), A 1319-1364 (bottom time, localized `units_profileMetric_min` suffix), B 684-716 (deco Any/Yes/No chips), A 760-813 (water temp, `allowNegative`), A 817-866 (visibility), A 870-895 (water types); seeding from A 139-166 and 170.

**Unit drift guard:** a group writes a bound ONLY from `NumberField.onChanged`; seeding a controller never writes the draft. So an untouched bound keeps its stored metric value exactly.

- [ ] Tests (port from the depth/duration/temp/visibility/water-type cases of `dive_filter_sheet_interactions_test.dart`, `dive_filter_sheet_explore_axes_test.dart` and `dive_search_page_depth_units_test.dart`): feet input stores metres; Fahrenheit input stores Celsius (negative allowed); invalid input keeps the bound; emptying clears it; deco chips write true/false/null; water type chips toggle; **with feet and Fahrenheit set and bounds 30.48 m / 21.11 C seeded, rendering the group and reading the draft back without edits returns 30.48 / 21.11 exactly** (Review Focus 1).
- [ ] Register, commit (`feat(dive-log): Refine panel conditions group`).

### Task 6: Gas and equipment group (Review Focus 3)

Fields: `diveTypeId, minO2Percent, maxO2Percent, equipmentIds, equipmentAttrConditions, computerId`. Title: `diveLog_search_section_gasEquipment`.

Port: A 559-592 (dive type, localized names), B 750-808 (gas chips including Trimix), B 812-854 (equipment chips), A 938-1007 plus helpers A 211-229 (suit thickness, `readNumber` parse, `formatDecimalForInput`) and A 1000-1007 (`DiveFilterGearAttributesSection`), A 636-707 plus A 232-259 (computer dropdown, `_computerIdWithin`, `_resolveComputerId`). The split of `equipmentAttrConditions` into suit thickness and gear conditions (A 178-188) moves into the group's `initState`; every edit writes the recombined list (A 1628-1635).

`static DiveFilterState resolveOnApply(DiveFilterState d, WidgetRef ref)`: the deleted-computer rule of A's `_resolveComputerId` (list loaded and id missing: clear; list loading: keep).

- [ ] Tests (port from `dive_filter_sheet_interactions_test.dart` computer, suit and gear cases, `dive_search_page_test.dart` equipment cases, `dive_filter_sheet_typeahead_test.dart` type and computer cases): Trimix writes max 21; suit thickness 2.5 / comma locale; gear category switch clears chips; equipment chip toggles and a duplicated id deselects; **deleted computer resolves to null on apply; loading list keeps the id** (Review Focus 3).
- [ ] Register, commit (`feat(dive-log): Refine panel gas and equipment group`).

### Task 7: Location, People and life, Organization, Custom fields groups

Four small groups, one commit each, same shape as Task 4:

- **Location** (`siteId, tripId, diveCenterId`; title `diveLog_search_section_location`): port A 601-632 (site), B 528-555 (trip), B 559-585 (center). Tests from `dive_search_page_typeahead_test.dart` (site by name, trip by location, center by city).
- **People and life** (`buddyNameFilter, noBuddyOnly, speciesIds`; title `diveLog_refine_groupPeople`): port A 1072-1219 (autocomplete buddy name, no-buddy switch clearing the name) and A 1520-1580 (species chips and autocomplete). Tests from `dive_filter_sheet_autocomplete_test.dart` and the species cases of `dive_filter_sheet_explore_axes_test.dart`.
- **Organization** (`tagIds, minRating, favoritesOnly, excludedFromStatsOnly`; title `diveLog_search_section_organization`): port A 1010-1068 (tags, `TagScope.dives`), A 1276-1315 (stars and Clear rating), A 908-934 (two switches). Tests: tag chip toggles; tapping the selected star clears; switches write true / null.
- **Custom fields** (`customFieldKey, customFieldValue`; title `diveLog_refine_groupCustomFields`): port B 1146-1206. Tests from `dive_search_page_typeahead_test.dart` (key narrowing) plus: clearing the key clears the value.

### Task 8: Rules group

Fields: `query`. Title: `diveLog_refine_groupRules`. Body: `DiveQueryEditor(value: draft.query, onChanged: (n) => onChanged(draft.copyWith(query: n, clearQuery: n == null)), onSave: draft.query == null ? null : () => saveQueryFromEditor(context, ref, subject: QuerySubject.dives, node: draft.query!))`.

- [ ] Tests (port from `dive_search_page_query_test.dart`): a typed query reaches the draft; an existing query prints into the Text tab; Save with no diver shows the existing snackbar; Clear all (panel) clears the query (Task 3 test covers).
- [ ] Register first in `_groups()`, commit (`feat(dive-log): Refine panel rules group`).

### Task 9: No axis lost guard

**Files:** `test/features/dive_log/presentation/widgets/refine/refine_axis_guard_test.dart`.

```dart
/// Spec section 9 item 7 (#2773): every DiveFilterState field is edited by a
/// Refine panel group, or is on this explained list.
const _noControl = {
  'buddyId', // set by the buddy page's "View all"; removable as a chip
  'diveIds', // set by Connections and other handoffs; removable as a chip
  'siteIds', // set by Explore's place lowering; removable as a chip
  'axesSuspended', // the search row's scope toggle owns it
};

void main() {
  test('every DiveFilterState field has a control', () {
    final source = File(
      p.join('lib', 'features', 'dive_log', 'domain', 'models',
          'dive_filter_state.dart'),
    ).readAsStringSync();
    final fields = RegExp(r'^  final [\w<>?, ]+ (\w+);', multiLine: true)
        .allMatches(source)
        .map((m) => m[1]!)
        .toSet();
    final covered = {
      ...RefineRulesGroup.fields,
      ...RefineDateGroup.fields,
      ...RefineLocationGroup.fields,
      ...RefineConditionsGroup.fields,
      ...RefineGasEquipmentGroup.fields,
      ...RefinePeopleGroup.fields,
      ...RefineOrganizationGroup.fields,
      ...RefineCustomFieldsGroup.fields,
      ..._noControl,
    };
    expect(fields.difference(covered), isEmpty);
    expect(covered.difference(fields), isEmpty, reason: 'stale names');
  });

  test('no field is edited by two groups', () {
    final all = [
      RefineRulesGroup.fields, RefineDateGroup.fields,
      RefineLocationGroup.fields, RefineConditionsGroup.fields,
      RefineGasEquipmentGroup.fields, RefinePeopleGroup.fields,
      RefineOrganizationGroup.fields, RefineCustomFieldsGroup.fields,
    ];
    final seen = <String>{};
    for (final f in all.expand((s) => s)) {
      expect(seen.add(f), isTrue, reason: '$f is in two groups');
    }
  });
}
```

- [ ] Run (PASS once Tasks 4 to 8 landed; temporarily drop a field from a group's set to watch it fail, then restore). Commit (`test(dive-log): guard that the Refine panel edits every filter axis`).

### Task 10: Wire the panel in; retire the sheet, the page and the route (Review Focus 4)

**Files:** modify `search/dive_search_header.dart` (Refine button: `showRefinePanel(context, filterProvider: diveFilterProvider)`), `insights_filter_action.dart` (`showRefinePanel(context, filterProvider: insightsFilterProvider)`), `connections/.../filter_tab.dart` ("All filters": `showRefinePanel(context, filterProvider: connectionsFilterProvider)`), `app_router.dart` (replace the `search` route's builder with `redirect: (context, state) { ProviderScope.containerOf(context, listen: false).read(diveSearchBarOpenProvider.notifier).state = true; return '/dives'; }`), `dive_list_content.dart` and `dive_list_page.dart` (remove the three `advanced_search` overflow items and their `onSelected` branches). Delete `dive_filter_sheet.dart`, `dive_search_page.dart`, and their tests listed in the inventory (all `dive_filter_sheet_*` and `dive_search_page_*` files, plus `pages/dive_filter_sheet_test.dart`).

- [ ] Tests: Insights action opens the panel and Show writes `insightsFilterProvider` only, staying on Insights; Connections "All filters" writes `connectionsFilterProvider` only; the header's Refine button opens the panel; `/dives/search` and `/dives/search?section=query` land on `/dives` with `diveSearchBarOpenProvider` true (update `app_router_test.dart:1202-1251`); the overflow menus no longer list Advanced Search (update `dive_list_page_test.dart:805`, `dive_list_content_test.dart:1623`); `insights_page_content_test.dart` and `connections_panel_test.dart` find `RefinePanel` instead of `DiveFilterSheet`.
- [ ] `grep -rn "DiveFilterSheet\|DiveSearchPage\|'/dives/search'" lib test` returns nothing but the router redirect and its test.
- [ ] Commit (`feat(dive-log): open the Refine panel everywhere; retire the filter sheet and Advanced Search`).

### Task 11: Orphaned strings

- [ ] For every key the deleted files used (inventory section 8), `grep -rl` it in `lib` excluding generated localizations; collect the keys with no remaining reference (including `diveLog_listPage_menuAdvancedSearch`, `diveLog_search_appBar`, `diveLog_filter_queryRow`, `diveLog_filter_resizeGrip`, `diveLog_filter_title`, `diveLog_filter_tooltip_close`, `diveLog_search_search`, `diveLog_filter_apply` if unused).
- [ ] Remove them from all 11 ARBs with PR 1's `drop_orphan_keys.py` (key list edited), `flutter gen-l10n`, `flutter analyze`, `flutter test test/l10n`.
- [ ] Commit (`i18n(dive-log): drop strings the filter sheet and Advanced Search used`).

### Task 12: Verify and ship

- [ ] `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test test/architecture`, `scripts/run_all_tests.sh` once.
- [ ] Re-merge PR 1's latest head (`git fetch origin ericgriffin/dives-search-consolidation-f7af5a && git merge FETCH_HEAD`) before the first push, re-run analyze and the dive_log tests.
- [ ] Screenshots via throwaway goldens (PR 1's harness): before (the Filter sheet, Advanced Search) and after (panel as bottom sheet at 390 px, as side panel at 1280 px, one group expanded, Insights opening it), light and dark.
- [ ] Final whole-branch review (most capable model), one fix pass, then push with `git push -u origin ericgriffin/dive-search-refine-panel` and open the PR against `main`: title `feat(dive-log): one Refine panel for every dive filter (2 of 4)`, body with `Refs #2773`, "Stacked on #2789: review only the commits after <PR 1 head>", the rulings above, and the screenshot list.
