# Unified Dive Search, PR 3: the Ask Row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ask questions in plain language from the Dives search row (an "Ask: ..." row, Cmd/Ctrl+Enter, the model download, a "Couldn't use" notice with Undo, and handoff of sentences about sites, gear, buddies, species, trips and centers to their lists), then retire the Explore page, its icon, Cmd/Ctrl+E and `/dives/explore`.

**Architecture:** A new `DiveAskNotifier` (`diveAskProvider`) ports Explore's `ExploreQueryNotifier`: it calls the existing `NlEngine`, parses and compiles with the existing `ExploreCompiler`, and then either replaces only `DiveFilterState.query` (dive sentences) or writes the subject list's filter through one shared `writeSubjectHandoff` function (other subjects). It keeps the last answer (parse, compilation, the query it replaced) so a notice can offer Undo and the ambiguous-name picker. `QueryTextField` gains three small hooks (raw text reports, a text override, extra shortcuts) so the search row can show "Ask: <typed text>", run Ask on Cmd/Ctrl+Enter, and put the sentence back on Undo. The Explore presentation layer is then deleted; its domain and data layers stay.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` / `StateNotifierProvider` via `core/providers/provider.dart`), go_router, gen-l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-02-unified-dive-search-design.md` (sections 3.3, 3.6, 4.1 states 3 and 6, 5.6 `AskController`, 5.8, 6, 7 "Ask" and "Shortcuts" and "Router", 8 row 3, 9 rows 6, 11, 12). Issue #2773. Branch `ericgriffin/dive-search-ask` from `main` at `08d4f1f51d3` (PR 1 #2789 and PR 2 #2807 merged).

## Global Constraints

- Never use the em-dash character, or an en-dash, double hyphen or spaced hyphen as punctuation, anywhere (code, comments, commits, ARB values, PR text).
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file.
- Every user-visible string goes through `context.l10n`; every new key is translated into all 10 non-en ARBs (values in this plan); `@` metadata goes in `app_en.arb` only; `flutter gen-l10n` runs after ARB edits.
- Ask is shown only where the on-device model works (`explorePlatformSupportedProvider` and `exploreAvailabilityProvider`); no Ask row and no Cmd/Ctrl+Enter otherwise (spec 6).
- A dive answer replaces only `query`; every other axis, and `axesSuspended`, is kept (spec 5.6).
- Paths in tests via `p.join`; process-wide state (platform overrides, singletons) restored in `addTearDown`.
- Files under 800 lines; imports grouped dart, flutter, packages, local.
- `dart format .` before every commit; conventional commit messages, no trailers.
- PR body: `Refs #2773`. Screenshots are skipped at the maintainer's request (say so in the PR body's Screenshots section; do not tick "No visible UI change").

## Rulings made while planning (confirm at review)

1. **The ambiguous-name picker survives.** Explore let the diver pick which of two same-named entities a mention meant (`resolveWith`, "Which did you mean by ..."). The spec does not mention it, but the no-loss rule covers it: the notice shows each unresolved mention as a chip that opens the same picker. Cost if wrong: one widget and two tests to remove.
2. **Every dive answer leaves a notice**, so Undo is always reachable: "Couldn't use:" plus the unplaced words (each with its reason as a tooltip) when something was not placed, otherwise "Asked: <sentence>". The notice goes once the dive query moves away from the answer (a chip removed, typing, Clear all), because Undo would then restore the wrong thing.
3. **A sentence about another subject hands off at once only when nothing needs the diver.** When words were not placed or a name is ambiguous, the notice shows first, with the picker and an "Open in list" button; leaving immediately would hide the feedback and the picker on a page the diver has already left.
4. **Asked sentences are still recorded** in the recent-queries cache (as Explore did), so PR 4's recent searches have history; nothing shows them until PR 4.
5. **Typing while an Ask runs cancels it:** the diver's newer text wins over a slow model reply.
6. **The Ask row shows while the field has focus and holds typed text**, and while an Ask runs or its error is on screen. After an answer the field holds the printed query, not typed text, so the row hides until the diver types again.
7. **Dropped with the page, as released by the maintainer:** answer charts and ranked non-dive rows (spec 9 rows 1 and 2). Explore's "Understood" chips are replaced by the search row's own query chips, which already remove one condition at a time.
8. **Kept per spec 5.8:** the Explore domain and data layers, `exploreRepositoryProvider`, `exploreNameIndexProvider`, the gate providers (`exploreEnabledProvider` now gates Cmd/Ctrl+Enter), and the recent-queries repository and providers.

## Review Focus

1. **Typing during an Ask:** the diver asks, then keeps typing before the model answers. The answer must not land over the new text, and the Ask row must not keep spinning. Pinned in Task 3 (controller) and Task 6 (row).
2. **Cmd/Ctrl+Enter inside the 300 ms debounce:** the words typed so far may still be waiting to apply. When the answer arrives first, those words must never land on top of it. Pinned in Task 6.
3. **A sentence the compiler places nothing from** (query null): the list and its chips stay as they were, and the notice lists every word as unused. Pinned in Task 3.
4. **Availability still loading** (first open, or a locale change re-probing): no Ask row and no Cmd/Ctrl+Enter until the probe answers, so the entry never flashes open on the previous locale's answer. Pinned in Task 4.
5. **Undo after the field was re-printed:** Undo puts the sentence back as text without committing it, and the list returns to the query from before the Ask, even though the sentence would parse to a different query. Pinned in Task 1 (field) and Task 6 (row).

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/core/query/presentation/query_text_field.dart` | modify | `onTextChanged`, `textOverride` (`QueryTextOverride`), `shortcuts` |
| `lib/features/explore/presentation/explore_handoff.dart` | create | `writeSubjectHandoff`, `exploreEquipmentFilter` (moved) |
| `lib/features/explore/presentation/providers/recent_query_providers.dart` | create | recent-queries providers (moved out of `explore_providers.dart`) |
| `lib/features/dive_log/presentation/providers/dive_ask_providers.dart` | create | `AskAnswer`, `AskState`, `DiveAskNotifier`, `diveAskProvider` |
| `lib/features/dive_log/presentation/widgets/search/dive_ask_row.dart` | create | the Ask row: ask, running, error, download, downloading |
| `lib/features/dive_log/presentation/widgets/search/dive_ask_notice.dart` | create | "Couldn't use" / "Asked", picker chips, Open in list, Undo, dismiss |
| `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart` | modify | wires the row, the notice, Cmd/Ctrl+Enter, Undo, handoff navigation |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | modify | Explore icon removed |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | modify | two Explore icons removed |
| `lib/core/router/app_router.dart` | modify | `/dives/explore` redirects like `/dives/search` |
| `lib/core/accessibility/app_shortcuts.dart` | modify | Cmd/Ctrl+E removed; "Ask about your dives" catalog entry |
| `lib/core/accessibility/shortcut_display.dart` | modify | label for the new entry, old one removed |
| `lib/features/explore/presentation/pages/explore_page.dart` | delete | |
| `lib/features/explore/presentation/widgets/*.dart` (5 files) | delete | charts, results lists, handoff bar, chip rows |
| `lib/features/explore/presentation/chip_labeler.dart`, `explore_label_lookup.dart` | delete | used only by the chip rows |
| `lib/features/explore/presentation/providers/explore_providers.dart` | delete | replaced by `dive_ask_providers.dart` and `recent_query_providers.dart` |
| `lib/features/explore/presentation/providers/explore_subject_providers.dart` | delete | ranked non-dive rows (dropped) |
| `lib/l10n/arb/app_*.arb` | modify | 5 new keys; orphaned Explore keys removed |

Test files are named in each task.

---

### Task 1: QueryTextField hooks for Ask

**Files:**
- Modify: `lib/core/query/presentation/query_text_field.dart`
- Test: `test/core/query/presentation/query_text_field_test.dart`

**Interfaces:**
- Produces:
  - `class QueryTextOverride { QueryTextOverride(this.text); final String text; }` (compared by identity: a new instance is a new request)
  - `QueryTextField({..., ValueChanged<String>? onTextChanged, QueryTextOverride? textOverride, Map<ShortcutActivator, VoidCallback> shortcuts = const {}})`

- [ ] **Step 1: Write the failing tests**

Add to `test/core/query/presentation/query_text_field_test.dart`, before `testWidgets('a valid query is committed', ...)`:

```dart
  testWidgets('reports every edit of the raw text, parsed or not', (
    tester,
  ) async {
    final texts = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            onTextChanged: texts.add,
            fieldKey: fieldKey,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(fieldKey), 'turtles, in bonaire');
    expect(texts.last, 'turtles, in bonaire');
  });

  group('text override', () {
    late StateSetter setOuter;
    QueryNode? value;
    QueryTextOverride? override;
    var commits = 0;

    Future<void> pumpField(WidgetTester tester) async {
      value = TextNode(['reef']);
      override = null;
      commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                setOuter = setState;
                return QueryTextField(
                  context: context,
                  value: value,
                  onChanged: (n) {
                    commits++;
                    value = n;
                  },
                  textOverride: override,
                  fieldKey: fieldKey,
                );
              },
            ),
          ),
        ),
      );
    }

    String textOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(fieldKey)).controller!.text;

    testWidgets('shows the text without committing it', (tester) async {
      await pumpField(tester);
      setOuter(() => override = QueryTextOverride('turtles below 20m'));
      await tester.pump();
      expect(textOf(tester), 'turtles below 20m');
      expect(commits, 0);
    });

    testWidgets('is applied once, not over later edits', (tester) async {
      await pumpField(tester);
      setOuter(() => override = QueryTextOverride('turtles'));
      await tester.pump();
      await tester.enterText(find.byKey(fieldKey), 'manta');
      setOuter(() {});
      await tester.pump();
      expect(textOf(tester), 'manta');
    });

    // Review Focus 5: Undo writes the old query and the sentence together.
    testWidgets('wins over a new value in the same update', (tester) async {
      await pumpField(tester);
      setOuter(() {
        value = TextNode(['wreck']);
        override = QueryTextOverride('wrecks in malta');
      });
      await tester.pump();
      expect(textOf(tester), 'wrecks in malta');
      expect(commits, 0);
    });
  });

  testWidgets('extra shortcuts fire while the field has focus', (tester) async {
    var asked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            shortcuts: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  () => asked++,
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(asked, 1);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: compile errors, "No named parameter with the name 'onTextChanged'" (and `textOverride`, `shortcuts`, `QueryTextOverride`).

- [ ] **Step 3: Implement**

In `query_text_field.dart`, add above `class QueryTextField`:

```dart
/// A request to show [text] in a [QueryTextField] without committing it
/// (Ask's Undo puts the sentence back this way). Compared by identity, so
/// each new instance is applied once, after any new value in the same
/// update.
class QueryTextOverride {
  QueryTextOverride(this.text);
  final String text;
}
```

Constructor parameters (after `this.onValidityChanged,`):

```dart
    this.onTextChanged,
    this.textOverride,
    this.shortcuts = const {},
```

Fields (after `onValidityChanged`):

```dart
  /// Called with the raw text on every edit by the diver, whether or not
  /// it parses.
  final ValueChanged<String>? onTextChanged;

  /// Text to show without committing it; see [QueryTextOverride].
  final QueryTextOverride? textOverride;

  /// Extra key bindings active while the field has focus.
  final Map<ShortcutActivator, VoidCallback> shortcuts;
```

In `didUpdateWidget`, after the whole `if (widget.value != _committed) {...} else if ... else if ... {}` chain:

```dart
    final override = widget.textOverride;
    if (override != null && !identical(override, old.textOverride)) {
      // After a new value in the same update, so the override wins. The
      // committed tree stays as it is: the text is shown, not applied.
      _controller
        ..text = override.text
        ..selection = TextSelection.collapsed(offset: override.text.length)
        ..setError();
      _error = null;
      _completions = const [];
    }
```

At the top of `_onTextChanged(String text)`:

```dart
    widget.onTextChanged?.call(text);
```

In `build`, the `CallbackShortcuts` bindings become:

```dart
          bindings: {
            ...widget.shortcuts,
            if (widget.onEscape != null)
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onEscape!,
          },
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/query/presentation/query_text_field.dart test/core/query/presentation/query_text_field_test.dart
git commit -m "feat(query): raw text reports, a text override and extra shortcuts on QueryTextField"
```

---

### Task 2: One subject handoff, and the recent-queries providers on their own

**Files:**
- Create: `lib/features/explore/presentation/explore_handoff.dart`
- Create: `lib/features/explore/presentation/providers/recent_query_providers.dart`
- Modify: `lib/features/explore/presentation/providers/explore_subject_providers.dart` (remove `exploreEquipmentFilter` and `_namesStatus`, import `explore_handoff.dart`)
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart` (remove the recent-queries block, import `recent_query_providers.dart`)
- Modify: `lib/features/explore/presentation/widgets/explore_handoff_bar.dart` (import `exploreEquipmentFilter` from `explore_handoff.dart`)
- Move: `test/features/explore/presentation/providers/explore_equipment_filter_test.dart` to `test/features/explore/presentation/explore_handoff_test.dart`
- Create: `test/features/explore/presentation/providers/recent_query_providers_test.dart` (the three recent-query tests moved out of `explore_providers_db_test.dart`)

**Interfaces:**
- Produces:
  - `String writeSubjectHandoff(Ref ref, ParsedSubject subject, QueryNode node)`: writes `node` as the subject list's query (other axes clear) and returns its route: sites `/sites`, equipment `/equipment`, buddies `/buddies`, species `/species`, trips `/trips`, centers `/dive-centers`. Throws `StateError` for `ParsedSubject.dives`.
  - `EquipmentFilterState exploreEquipmentFilter(QueryNode? node)` (unchanged, moved)
  - `recentQueryRepositoryProvider`, `RecentQueryRecorder`, `recentQueryRecorderProvider`, `recentQueriesProvider` (unchanged, moved)

- [ ] **Step 1: Move the tests first**

```bash
git mv test/features/explore/presentation/providers/explore_equipment_filter_test.dart test/features/explore/presentation/explore_handoff_test.dart
```

In the moved file, replace the import of `explore_subject_providers.dart` with:

```dart
import 'package:submersion/features/explore/presentation/explore_handoff.dart';
```

and append inside `main()`:

```dart
  group('writeSubjectHandoff', () {
    final refProbe = Provider<Ref>((ref) => ref);

    Ref refOf(ProviderContainer c) {
      final sub = c.listen(refProbe, (_, _) {});
      addTearDown(sub.close);
      return c.read(refProbe);
    }

    test('each subject writes its own list query and names its route', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ref = refOf(c);
      final node = TextNode(['reef']);
      expect(writeSubjectHandoff(ref, ParsedSubject.sites, node), '/sites');
      expect(c.read(siteFilterProvider).query, node);
      expect(writeSubjectHandoff(ref, ParsedSubject.buddies, node), '/buddies');
      expect(c.read(buddyQueryProvider), node);
      expect(writeSubjectHandoff(ref, ParsedSubject.species, node), '/species');
      expect(c.read(seenSpeciesQueryProvider), node);
      expect(writeSubjectHandoff(ref, ParsedSubject.trips, node), '/trips');
      expect(c.read(tripFilterProvider).query, node);
      expect(
        writeSubjectHandoff(ref, ParsedSubject.centers, node),
        '/dive-centers',
      );
      expect(c.read(diveCenterQueryProvider), node);
      expect(
        writeSubjectHandoff(ref, ParsedSubject.equipment, node),
        '/equipment',
      );
      expect(
        c.read(equipmentFilterProvider).query,
        exploreEquipmentFilter(node).query,
      );
    });

    test('a dive sentence is not a subject handoff', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        () => writeSubjectHandoff(refOf(c), ParsedSubject.dives, TextNode(['x'])),
        throwsStateError,
      );
    });
  });
```

with these imports added:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
```

(If any of these list providers reads settings or a database when first read, add `...await getBaseOverrides()` from `test/helpers/mock_providers.dart` to the container, as `explore_providers_db_test.dart` does.)

Create `test/features/explore/presentation/providers/recent_query_providers_test.dart`: copy the `setUp`/`tearDown`, the `container()` helper and the three tests `'the recorder writes a recent query the list provider reads'`, `'recent queries are scoped to the active locale'` and `'recent queries are scoped to the active diver'` from `explore_providers_db_test.dart`, importing `recent_query_providers.dart` instead of `explore_providers.dart`. Delete those three tests from `explore_providers_db_test.dart`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/explore/presentation/explore_handoff_test.dart test/features/explore/presentation/providers/recent_query_providers_test.dart`
Expected: compile errors, the two new library files do not exist.

- [ ] **Step 3: Implement**

Create `lib/features/explore/presentation/explore_handoff.dart`. Move `exploreEquipmentFilter` and `_namesStatus` (with their doc comments) from `explore_subject_providers.dart` into it unchanged, and add:

```dart
/// Writes [node] as [subject]'s list query and returns the list's route.
/// The list's other axes start clear, so its chips show exactly what the
/// sentence asked for (#2773; Explore's handoff, shared by Ask).
String writeSubjectHandoff(Ref ref, ParsedSubject subject, QueryNode node) {
  switch (subject) {
    case ParsedSubject.sites:
      ref.read(siteFilterProvider.notifier).state = SiteFilterState(
        query: node,
      );
      return '/sites';
    case ParsedSubject.equipment:
      ref.read(equipmentFilterProvider.notifier).state =
          exploreEquipmentFilter(node);
      return '/equipment';
    case ParsedSubject.buddies:
      ref.read(buddyQueryProvider.notifier).state = node;
      return '/buddies';
    case ParsedSubject.species:
      ref.read(seenSpeciesQueryProvider.notifier).state = node;
      return '/species';
    case ParsedSubject.trips:
      ref.read(tripFilterProvider.notifier).state = TripFilterState(
        query: node,
      );
      return '/trips';
    case ParsedSubject.centers:
      ref.read(diveCenterQueryProvider.notifier).state = node;
      return '/dive-centers';
    case ParsedSubject.dives:
      throw StateError('a dive sentence replaces the dive query instead');
  }
}
```

Imports: `core/providers/provider.dart`, `core/query/domain/query_node.dart`, the six list-provider files listed in Step 1, `features/equipment/domain/models/equipment_filter_state.dart` and whatever `exploreEquipmentFilter` already imported, `features/explore/domain/query_model.dart`.

In `explore_subject_providers.dart`, delete the moved code and import `explore_handoff.dart`. In `explore_handoff_bar.dart`, import `explore_handoff.dart` for `exploreEquipmentFilter`.

Create `lib/features/explore/presentation/providers/recent_query_providers.dart` by moving, unchanged, `recentQueryRepositoryProvider`, the `RecentQueryRecorder` typedef, `recentQueryRecorderProvider` and `recentQueriesProvider` (with their comments and imports) out of `explore_providers.dart`; `explore_providers.dart` imports the new file.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/explore`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/explore test/features/explore
git commit -m "refactor(explore): one subject handoff function, recent-query providers in their own file"
```

---

### Task 3: The Ask controller

**Files:**
- Create: `lib/features/dive_log/presentation/providers/dive_ask_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`

**Interfaces:**
- Consumes: `writeSubjectHandoff` (Task 2), `recentQueryRecorderProvider` (Task 2), `nlEngineProvider`, `explorePlatformSupportedProvider`, `exploreNameIndexProvider`, `ExploreCompiler.compile`, `ParsedQuery.fromDecoded`, `mentionKindOf`, `diveFilterProvider`, `queryUnitPrefsProvider`, `localeProvider`.
- Produces:
  - `class AskAnswer { String sentence; ParsedQuery parsed; ExploreCompilation compiled; QueryNode? previousQuery; bool get needsAttention; }`
  - `class AskState { bool running; NlError? error; AskAnswer? answer; }`
  - `class DiveAskNotifier extends StateNotifier<AskState>` with `Future<String?> ask(String sentence)` (returns a route to go to, or null), `String? undo()` (returns the sentence to put back, or null), `void resolveWith(int mentionIndex, NameEntry entry)`, `String? openAnswerList()`, `void dismiss()`, `void cancel()`, `void reset()`, `void prepare()`
  - `final diveAskProvider = StateNotifierProvider<DiveAskNotifier, AskState>(...)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../explore/domain/explore_query_parts.dart';

/// Answers every sentence from [replies] (or [json]); [gates] holds back a
/// sentence's answer until the test completes it.
class _Engine implements NlEngine {
  _Engine([this.json = '']);
  final String json;
  final replies = <String, String>{};
  final gates = <String, Completer<String>>{};
  Object? throwing;
  int compileCalls = 0;
  int prepareCalls = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) {
    compileCalls++;
    if (throwing != null) return Future.error(throwing!);
    if (gates.containsKey(sentence)) return gates[sentence]!.future;
    return Future.value(replies[sentence] ?? json);
  }
}

const _turtles =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
    '[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":["maybe"]}';
const _deep =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gte","value":40,"unit":"m","text":"deep"}],"mentions":[],"time":null,"unplaced":[]}';
const _nothing =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[],"mentions":[],'
    '"time":null,"unplaced":["fluffy clouds"]}';
const _goodSites =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":[]}';
const _sitesWithLeftovers =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":["cosy"]}';

final _bonaire = NameIndex(const [
  NameEntry(
    subject: QuerySubject.sites,
    label: 'Bonaire',
    ids: ['s1', 's2'],
    target: NameTarget.sitePlace,
  ),
]);

void main() {
  late List<String> recorded;

  ProviderContainer make(
    _Engine engine, {
    Future<NameIndex> Function()? names,
    RecentQueryRecorder? recorder,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    recorded = [];
    final c = ProviderContainer(
      overrides: [
        nlEngineProvider.overrideWithValue(engine),
        explorePlatformSupportedProvider.overrideWithValue(true),
        localeProvider.overrideWithValue('en'),
        queryUnitPrefsProvider.overrideWithValue(
          const UnitPrefs(
            depth: DepthUnit.meters,
            temperature: TemperatureUnit.celsius,
            pressure: PressureUnit.bar,
            weight: WeightUnit.kilograms,
            volume: VolumeUnit.liters,
          ),
        ),
        exploreNameIndexProvider.overrideWith(
          (ref) => names?.call() ?? Future.value(_bonaire),
        ),
        recentQueryRecorderProvider.overrideWithValue(
          recorder ?? (sentence, locale, parsed) async => recorded.add(sentence),
        ),
        diveFilterProvider.overrideWith((ref) => filter),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  AskState stateOf(ProviderContainer c) => c.read(diveAskProvider);
  DiveAskNotifier askOf(ProviderContainer c) => c.read(diveAskProvider.notifier);
  DiveFilterState filterOf(ProviderContainer c) => c.read(diveFilterProvider);

  test('a dive answer replaces only the query', () async {
    final c = make(
      _Engine(_turtles),
      filter: DiveFilterState(
        favoritesOnly: true,
        axesSuspended: true,
        query: TextNode(['old']),
      ),
    );
    expect(await askOf(c).ask('Turtles below 20m in Bonaire'), isNull);
    final answer = stateOf(c).answer!;
    expect(filterOf(c).query, answer.compiled.query);
    expect(filterOf(c).favoritesOnly, isTrue);
    expect(filterOf(c).axesSuspended, isTrue);
    expect(answer.previousQuery, TextNode(['old']));
    expect(boundOf(answer.compiled, 'depth', QueryOp.gte), 20);
    expect(answer.compiled.unplaced.single.text, 'maybe');
    expect(recorded, ['Turtles below 20m in Bonaire']);
  });

  test('Undo writes the previous query back and returns the sentence', () async {
    final c = make(_Engine(_turtles), filter: DiveFilterState(query: TextNode(['old'])));
    await askOf(c).ask('Turtles below 20m in Bonaire');
    expect(askOf(c).undo(), 'Turtles below 20m in Bonaire');
    expect(filterOf(c).query, TextNode(['old']));
    expect(stateOf(c).answer, isNull);
  });

  // Review Focus 3.
  test('a sentence that places nothing leaves the filter alone', () async {
    final before = DiveFilterState(minDepth: 10, query: TextNode(['reef']));
    final c = make(_Engine(_nothing), filter: before);
    await askOf(c).ask('fluffy clouds');
    expect(filterOf(c), before);
    expect(stateOf(c).answer!.compiled.unplaced.single.text, 'fluffy clouds');
    expect(stateOf(c).answer!.needsAttention, isTrue);
  });

  test('another subject with nothing to show hands off at once', () async {
    final c = make(_Engine(_goodSites));
    expect(await askOf(c).ask('sites rated 4'), '/sites');
    expect(c.read(siteFilterProvider).query, isNotNull);
    expect(stateOf(c).answer, isNull);
    expect(filterOf(c), const DiveFilterState());
  });

  test('another subject needing the diver waits for Open in list', () async {
    final c = make(_Engine(_sitesWithLeftovers));
    expect(await askOf(c).ask('cosy sites rated 4'), isNull);
    expect(stateOf(c).answer!.needsAttention, isTrue);
    expect(c.read(siteFilterProvider).query, isNull);
    expect(askOf(c).openAnswerList(), '/sites');
    expect(c.read(siteFilterProvider).query, isNotNull);
    expect(stateOf(c).answer, isNull);
  });

  test('picking between two same-named buddies sticks', () async {
    final twins = NameIndex(const [
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['john-a'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['john-b'],
        target: NameTarget.buddyId,
      ),
    ]);
    const withJohn =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","mentions":'
        '[{"kind":"buddy","text":"John Smith"}],"unplaced":[]}';
    final c = make(
      _Engine(withJohn),
      names: () async => twins,
      filter: DiveFilterState(query: TextNode(['old'])),
    );
    await askOf(c).ask('dives with John Smith');
    expect(stateOf(c).answer!.compiled.unresolved, hasLength(1));
    askOf(c).resolveWith(0, twins.entries[1]);
    expect(
      (conditionsIn(filterOf(c).query, [
                'buddies',
              ], QueryOp.eq).single.value!
              as RefValue)
          .id,
      'john-b',
    );
    expect(stateOf(c).answer!.compiled.unresolved, isEmpty);
    // Undo still goes back to before the Ask, not to before the pick.
    expect(stateOf(c).answer!.previousQuery, TextNode(['old']));
  });

  test('a pick past the last mention is ignored', () async {
    final c = make(_Engine(_turtles));
    await askOf(c).ask('x');
    final before = filterOf(c);
    askOf(c).resolveWith(99, _bonaire.entries.single);
    expect(filterOf(c), before);
  });

  test('the notice goes once the dive query moves away from the answer', () async {
    final c = make(_Engine(_turtles));
    await askOf(c).ask('x');
    expect(stateOf(c).answer, isNotNull);
    final notifier = c.read(diveFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(query: TextNode(['other']));
    expect(stateOf(c).answer, isNull);
  });

  test('an engine error is published, the filter untouched', () async {
    final engine = _Engine()..throwing = const NlException(NlError.contextExceeded);
    final c = make(engine, filter: DiveFilterState(query: TextNode(['old'])));
    expect(await askOf(c).ask('x'), isNull);
    expect(stateOf(c).running, isFalse);
    expect(stateOf(c).error, NlError.contextExceeded);
    expect(filterOf(c).query, TextNode(['old']));
  });

  test('a non-object JSON root is a schema mismatch', () async {
    final c = make(_Engine('[1, 2]'));
    await askOf(c).ask('x');
    expect(stateOf(c).error, NlError.schemaMismatch);
  });

  test('text that is not JSON at all is a schema mismatch', () async {
    final c = make(_Engine('not json'));
    await askOf(c).ask('x');
    expect(stateOf(c).error, NlError.schemaMismatch);
  });

  test('an unexpected failure ends the run with an error', () async {
    final c = make(
      _Engine(_turtles),
      names: () async => throw StateError('index build failed'),
    );
    await askOf(c).ask('x');
    expect(stateOf(c).running, isFalse);
    expect(stateOf(c).error, NlError.unknown);
  });

  test('a failed recent-query write does not hide a good answer', () async {
    final c = make(
      _Engine(_turtles),
      recorder: (sentence, locale, parsed) async => throw StateError('full'),
    );
    await askOf(c).ask('x');
    expect(stateOf(c).error, isNull);
    expect(stateOf(c).answer, isNotNull);
  });

  test('an empty sentence never reaches the model', () async {
    final engine = _Engine(_turtles);
    final c = make(engine);
    await askOf(c).ask('   ');
    expect(engine.compileCalls, 0);
  });

  test('a slow reply cannot overwrite a newer request', () async {
    final engine = _Engine()
      ..replies['second'] = _deep
      ..gates['first'] = Completer<String>();
    final c = make(engine);
    final first = askOf(c).ask('first');
    await Future<void>.delayed(Duration.zero);
    await askOf(c).ask('second');
    engine.gates['first']!.complete(_turtles);
    await first;
    expect(stateOf(c).answer!.sentence, 'second');
    expect(boundOf(stateOf(c).answer!.compiled, 'depth', QueryOp.gte), 40);
  });

  // Review Focus 1.
  test('cancel drops the answer still on its way', () async {
    final engine = _Engine()..gates['first'] = Completer<String>();
    final c = make(engine, filter: DiveFilterState(query: TextNode(['typed'])));
    final first = askOf(c).ask('first');
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(c).running, isTrue);
    askOf(c).cancel();
    expect(stateOf(c).running, isFalse);
    engine.gates['first']!.complete(_turtles);
    expect(await first, isNull);
    expect(stateOf(c).answer, isNull);
    expect(filterOf(c).query, TextNode(['typed']));
  });

  test('prepare warms the model once', () async {
    final engine = _Engine(_turtles);
    final c = make(engine);
    askOf(c)
      ..prepare()
      ..prepare();
    await Future<void>.delayed(Duration.zero);
    expect(engine.prepareCalls, 1);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`
Expected: compile error, `dive_ask_providers.dart` does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/presentation/providers/dive_ask_providers.dart`:

```dart
import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/explore_handoff.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// One answered sentence, kept while its notice shows (#2773).
class AskAnswer {
  const AskAnswer({
    required this.sentence,
    required this.parsed,
    required this.compiled,
    required this.previousQuery,
  });

  final String sentence;
  final ParsedQuery parsed;
  final ExploreCompilation compiled;

  /// The dive list's query before the Ask; Undo writes it back.
  final QueryNode? previousQuery;

  /// Words the compiler could not place, or a name with several matches.
  bool get needsAttention =>
      compiled.unplaced.isNotEmpty || compiled.unresolved.isNotEmpty;
}

class AskState {
  const AskState({this.running = false, this.error, this.answer});
  final bool running;
  final NlError? error;
  final AskAnswer? answer;
}

/// Ask from the dive search row (#2773, Explore's sentence flow): the
/// on-device model reads the sentence, the Explore compiler turns it into a
/// query, and a dive answer replaces only the list's query while another
/// subject's answer goes to that subject's list.
class DiveAskNotifier extends StateNotifier<AskState> {
  DiveAskNotifier(this._ref) : super(const AskState()) {
    // The notice belongs to its answer: once the dive query moves away
    // from it (a chip removed, typing, Clear all), Undo would restore the
    // wrong thing, so the notice goes.
    _ref.listen<DiveFilterState>(diveFilterProvider, (_, next) {
      final answer = state.answer;
      if (answer == null || answer.compiled.subject != ParsedSubject.dives) {
        return;
      }
      if (next.query != answer.compiled.query) dismiss();
    });
  }

  final Ref _ref;
  static const _log = LoggerService('DiveAsk');

  /// Bumped by every request and by [cancel]; a reply publishes only while
  /// its request is still the latest.
  int _request = 0;
  bool _prepared = false;

  /// Runs [sentence]. Returns the route of the list it handed off to, or
  /// null when the answer stays here (or failed, or was superseded).
  Future<String?> ask(String sentence) async {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return null;
    final request = ++_request;
    final previousQuery = _ref.read(diveFilterProvider).query;
    state = const AskState(running: true);
    try {
      final locale = _ref.read(localeProvider);
      final json = await _ref
          .read(nlEngineProvider)
          .compile(trimmed, localeTag: locale);
      if (request != _request) return null;
      final parsed = ParsedQuery.fromDecoded(jsonDecode(json));
      final names = await _ref.read(exploreNameIndexProvider.future);
      if (request != _request) return null;
      final route = _publish(
        AskAnswer(
          sentence: trimmed,
          parsed: parsed,
          compiled: _compile(parsed, names),
          previousQuery: previousQuery,
        ),
        handOff: true,
      );
      await _recordRecent(trimmed, locale, parsed);
      return route;
    } on NlException catch (e) {
      _fail(request, e.error);
    } on QuerySchemaException {
      _fail(request, NlError.schemaMismatch);
    } on FormatException {
      _fail(request, NlError.schemaMismatch);
    } catch (e, stackTrace) {
      // Anything else (the name index failing to build, a database error)
      // must still end the run, or the row spins with nothing saying why.
      _log.error('Ask failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
    }
    return null;
  }

  /// Pins mention [mentionIndex] to [entry] and recompiles. The label goes
  /// into the text so the chip reads right; the identity rides along
  /// because two entities can share a label exactly.
  void resolveWith(int mentionIndex, NameEntry entry) {
    final answer = state.answer;
    if (answer == null || mentionIndex >= answer.parsed.mentions.length) {
      return;
    }
    final mentions = [...answer.parsed.mentions];
    mentions[mentionIndex] = QueryMention(
      kind: mentionKindOf(entry.target),
      text: entry.label,
      identity: entry.identity,
    );
    final parsed = ParsedQuery(
      subject: answer.parsed.subject,
      clauses: answer.parsed.clauses,
      mentions: mentions,
      time: answer.parsed.time,
      unplaced: answer.parsed.unplaced,
    );
    final names = _ref.read(exploreNameIndexProvider).value ?? NameIndex.empty;
    _publish(
      AskAnswer(
        sentence: answer.sentence,
        parsed: parsed,
        compiled: _compile(parsed, names),
        previousQuery: answer.previousQuery,
      ),
      handOff: false,
    );
  }

  /// Writes the dive query from before the Ask back and returns the
  /// sentence for the field; null with nothing to undo.
  String? undo() {
    final answer = state.answer;
    if (answer == null) return null;
    state = const AskState();
    if (answer.compiled.subject == ParsedSubject.dives) {
      final notifier = _ref.read(diveFilterProvider.notifier);
      notifier.state = notifier.state.copyWith(
        query: answer.previousQuery,
        clearQuery: answer.previousQuery == null,
      );
    }
    return answer.sentence;
  }

  /// Hands the kept non-dive answer to its list; returns the route.
  String? openAnswerList() {
    final answer = state.answer;
    final node = answer?.compiled.query;
    if (answer == null ||
        node == null ||
        answer.compiled.subject == ParsedSubject.dives) {
      return null;
    }
    state = const AskState();
    return writeSubjectHandoff(_ref, answer.compiled.subject, node);
  }

  /// Hides the notice; a running Ask goes on.
  void dismiss() => state = AskState(running: state.running);

  /// Drops an Ask still waiting on the model (the diver typed on) and its
  /// error; a published answer stays.
  void cancel() {
    _request++;
    if (state.running || state.error != null) {
      state = AskState(answer: state.answer);
    }
  }

  /// Drops everything: the search row was closed or cleared.
  void reset() {
    _request++;
    state = const AskState();
  }

  /// Warms the model up once, where it can run, so the first Ask is not
  /// the cold start.
  void prepare() {
    if (_prepared || !_ref.read(explorePlatformSupportedProvider)) return;
    _prepared = true;
    _ref.read(nlEngineProvider).prepare().catchError((Object _) {});
  }

  ExploreCompilation _compile(ParsedQuery parsed, NameIndex names) =>
      ExploreCompiler.compile(
        parsed,
        ExploreCompilerContext(
          units: _ref.read(queryUnitPrefsProvider),
          names: names,
          now: DateTime.now(),
        ),
      );

  /// Applies [answer]; returns a route when it handed off at once.
  String? _publish(AskAnswer answer, {required bool handOff}) {
    final compiled = answer.compiled;
    if (compiled.subject == ParsedSubject.dives) {
      final query = compiled.query;
      if (query != null) {
        final notifier = _ref.read(diveFilterProvider.notifier);
        notifier.state = notifier.state.copyWith(query: query);
      }
      // After the write: the listener above clears an older notice.
      state = AskState(answer: answer);
      return null;
    }
    final query = compiled.query;
    if (handOff && query != null && !answer.needsAttention) {
      state = const AskState();
      return writeSubjectHandoff(_ref, compiled.subject, query);
    }
    state = AskState(answer: answer);
    return null;
  }

  void _fail(int request, NlError error) {
    if (request != _request) return;
    state = AskState(error: error);
  }

  /// Remembering the sentence is a convenience: a failed write must not
  /// turn an answer the diver can see into an error.
  Future<void> _recordRecent(
    String sentence,
    String locale,
    ParsedQuery parsed,
  ) async {
    try {
      await _ref.read(recentQueryRecorderProvider)(sentence, locale, parsed);
    } catch (e, stackTrace) {
      _log.warning(
        'Could not remember an asked sentence',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final diveAskProvider = StateNotifierProvider<DiveAskNotifier, AskState>(
  (ref) => DiveAskNotifier(ref),
);
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`
Expected: all pass. If `'another subject with nothing to show hands off at once'` fails because the sites compile leaves `rating` unplaced, check `explore_subject_fields.dart` for the site rating field's JSON name and adjust only the fixture's `field`.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/providers/dive_ask_providers.dart test/features/dive_log/presentation/providers/dive_ask_providers_test.dart
git commit -m "feat(dive-log): an Ask controller for the search row"
```

---

### Task 4: The Ask row

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_ask_row.dart`
- Modify: `lib/l10n/arb/app_*.arb` (2 keys), then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/search/dive_ask_row_test.dart`

**Interfaces:**
- Consumes: `diveAskProvider` (Task 3), `exploreAvailabilityProvider`, `explorePlatformSupportedProvider`, `nlEngineProvider`.
- Produces: `const kDiveAskRowKey = ValueKey('dive-ask-row');` and `DiveAskRow({required String text, required VoidCallback onAsk})`.

New strings (`app_en.arb`, after `diveLog_search_jumpTitle`):

```json
  "diveLog_ask_row": "Ask: {text}",
  "@diveLog_ask_row": {"placeholders": {"text": {"type": "String"}}},
  "diveLog_ask_running": "Asking the on-device model",
```

| key | ar | de | es | fr | he | hu | it | nl | pt | zh |
|---|---|---|---|---|---|---|---|---|---|---|
| `diveLog_ask_row` | اسأل: {text} | Fragen: {text} | Preguntar: {text} | Demander : {text} | שאל: {text} | Kérdezd: {text} | Chiedi: {text} | Vraag: {text} | Perguntar: {text} | 提问：{text} |
| `diveLog_ask_running` | جارٍ سؤال النموذج على الجهاز | Das Modell auf dem Gerät wird gefragt | Consultando el modelo del dispositivo | Interrogation du modèle sur l'appareil | שואל את המודל במכשיר | Az eszközön futó modell válaszol | Interrogazione del modello sul dispositivo | Het model op het apparaat wordt gevraagd | Consultando o modelo no dispositivo | 正在询问设备端模型 |

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/search/dive_ask_row_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_row.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';

import '../../../../../helpers/test_app.dart';

class _Engine implements NlEngine {
  _Engine(this.answer);
  NlAvailability answer;
  final downloads = StreamController<double>();
  int downloadCalls = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async => answer;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() {
    downloadCalls++;
    return downloads.stream;
  }

  @override
  Future<String> compile(String sentence, {required String localeTag}) =>
      Completer<String>().future;
}

void main() {
  late int asks;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required _Engine engine,
    bool supported = true,
    Future<NlAvailability>? availability,
  }) async {
    asks = 0;
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          nlEngineProvider.overrideWithValue(engine),
          explorePlatformSupportedProvider.overrideWithValue(supported),
          if (availability != null)
            exploreAvailabilityProvider.overrideWith((ref) => availability),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveAskRow(text: 'turtles in bonaire', onAsk: () => asks++);
          },
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('offers to ask the typed sentence', (tester) async {
    await pump(tester, engine: _Engine(NlAvailability.available));
    expect(find.text('Ask: turtles in bonaire'), findsOneWidget);
    await tester.tap(find.byKey(kDiveAskRowKey));
    expect(asks, 1);
  });

  testWidgets('is absent where the model cannot run', (tester) async {
    await pump(
      tester,
      engine: _Engine(NlAvailability.available),
      supported: false,
    );
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  testWidgets('is absent when the model is unavailable', (tester) async {
    await pump(tester, engine: _Engine(NlAvailability.deviceNotEligible));
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  // Review Focus 4.
  testWidgets('is absent while availability is still being asked', (
    tester,
  ) async {
    await pump(
      tester,
      engine: _Engine(NlAvailability.available),
      availability: Completer<NlAvailability>().future,
    );
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  testWidgets('offers the download, then re-probes', (tester) async {
    final engine = _Engine(NlAvailability.downloadable);
    await pump(tester, engine: engine);
    expect(find.text('Download the on-device model'), findsOneWidget);
    engine.answer = NlAvailability.downloading;
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump();
    expect(engine.downloadCalls, 1);
    expect(find.text('Downloading the model'), findsOneWidget);
    engine.answer = NlAvailability.available;
    await engine.downloads.close();
    await tester.pump();
    await tester.pump();
    expect(find.text('Ask: turtles in bonaire'), findsOneWidget);
  });

  testWidgets('shows the running state and an error in words', (
    tester,
  ) async {
    final c = await pump(tester, engine: _Engine(NlAvailability.available));
    unawaited(c.read(diveAskProvider.notifier).ask('turtles'));
    await tester.pump();
    expect(find.text('Asking the on-device model'), findsOneWidget);
    c.read(diveAskProvider.notifier).reset();
    c.read(diveAskProvider.notifier).state = const AskState(
      error: NlError.quotaExceeded,
    );
    await tester.pump();
    expect(
      find.text('The on-device model is busy. Try again in a moment.'),
      findsOneWidget,
    );
  });
}
```

If `testApp` does not accept `overrides` without base overrides here, prepend `...await getBaseOverrides()` (from `test/helpers/mock_providers.dart`) as the other search tests do. `DiveAskNotifier.state` is protected; if the analyzer refuses the direct write, set the error by asking with a throwing engine instead.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_ask_row_test.dart`
Expected: compile error, `dive_ask_row.dart` does not exist.

- [ ] **Step 3: Implement**

Add the two strings to all 11 ARBs (values above), run `flutter gen-l10n`, then create `dive_ask_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveAskRowKey = ValueKey('dive-ask-row');

/// The search row's Ask action (#2773): "Ask: <typed text>" where the
/// on-device model works, the model download where it can be fetched, and
/// nothing anywhere else.
class DiveAskRow extends ConsumerWidget {
  const DiveAskRow({super.key, required this.text, required this.onAsk});

  final String text;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(explorePlatformSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final availability = ref.watch(exploreAvailabilityProvider);
    // Closed while a probe runs: a locale change re-probes, and the
    // previous locale's answer is still in the AsyncValue meanwhile.
    if (availability.isLoading) return const SizedBox.shrink();
    final l10n = context.l10n;
    final ask = ref.watch(diveAskProvider);
    final Widget row = switch (availability.value) {
      NlAvailability.available => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: ask.running
            ? const _Spinner()
            : const Icon(Icons.auto_awesome),
        title: Text(
          ask.running ? l10n.diveLog_ask_running : l10n.diveLog_ask_row(text.trim()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: ask.error == null
            ? null
            : Text(
                nlErrorText(l10n, ask.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
        onTap: ask.running ? null : onAsk,
      ),
      NlAvailability.downloadable => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: const Icon(Icons.download),
        title: Text(l10n.explore_download_button),
        onTap: () => _download(context, ref),
      ),
      NlAvailability.downloading => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: const _Spinner(),
        title: Text(l10n.explore_download_running),
      ),
      _ => const SizedBox.shrink(),
    };
    // Inside the field's tap region, like the jump rows: on desktop a
    // mouse press elsewhere unfocuses the field before the tap lands.
    return TextFieldTapRegion(child: row);
  }

  void _download(BuildContext context, WidgetRef ref) {
    // The container, not this widget's ref: the download outlives the row.
    // Re-probe however the stream ends, so a failed download offers the
    // button again instead of an uncaught error.
    final container = ProviderScope.containerOf(context, listen: false);
    void reprobe() => container.invalidate(exploreAvailabilityProvider);
    ref
        .read(nlEngineProvider)
        .download()
        .listen((_) {}, onError: (Object _) => reprobe(), onDone: reprobe);
    // Once started, the platform reports it as downloading.
    reprobe();
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// The diver-facing sentence for a model failure.
String nlErrorText(AppLocalizations l10n, NlError e) => switch (e) {
  NlError.unsupportedLocale => l10n.explore_error_unsupportedLocale,
  NlError.contextExceeded => l10n.explore_error_contextExceeded,
  NlError.guardrail => l10n.explore_error_guardrail,
  NlError.refusal => l10n.explore_error_refusal,
  NlError.decodingFailure => l10n.explore_error_decodingFailure,
  NlError.modelNotReady => l10n.explore_error_modelNotReady,
  NlError.quotaExceeded => l10n.explore_error_quotaExceeded,
  NlError.schemaMismatch => l10n.explore_error_schemaMismatch,
  NlError.unknown => l10n.explore_error_unknown,
};
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_ask_row_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/l10n/arb lib/features/dive_log/presentation/widgets/search/dive_ask_row.dart test/features/dive_log/presentation/widgets/search/dive_ask_row_test.dart
git commit -m "feat(dive-log): the Ask row, with the model download"
```

---

### Task 5: The Ask notice

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_ask_notice.dart`
- Modify: `lib/l10n/arb/app_*.arb` (2 keys), then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/search/dive_ask_notice_test.dart`

**Interfaces:**
- Consumes: `diveAskProvider`, `AskAnswer` (Task 3); strings `explore_pickCandidate_title`, `explore_unresolved_noCandidates`, `explore_unplaced_reason_*`, `explore_handoff_list`, `diveLog_search_undo`.
- Produces: `DiveAskNotice({required VoidCallback onUndo, required ValueChanged<String> onOpenList})`; keys `kDiveAskNoticeKey = ValueKey('dive-ask-notice')`, `kDiveAskUndoKey = ValueKey('dive-ask-undo')`, `kDiveAskOpenListKey = ValueKey('dive-ask-open-list')`, `kDiveAskDismissKey = ValueKey('dive-ask-dismiss')`.

New strings (`app_en.arb`, after `diveLog_ask_running`):

```json
  "diveLog_ask_couldNotUse": "Couldn't use:",
  "diveLog_ask_asked": "Asked: {sentence}",
  "@diveLog_ask_asked": {"placeholders": {"sentence": {"type": "String"}}},
```

| key | ar | de | es | fr | he | hu | it | nl | pt | zh |
|---|---|---|---|---|---|---|---|---|---|---|
| `diveLog_ask_couldNotUse` | تعذّر استخدام: | Nicht verwendet: | No se pudo usar: | Non utilisé : | לא ניתן להשתמש: | Nem használható: | Non usato: | Niet gebruikt: | Não foi possível usar: | 无法使用： |
| `diveLog_ask_asked` | سُئل: {sentence} | Gefragt: {sentence} | Preguntado: {sentence} | Demandé : {sentence} | נשאל: {sentence} | Kérdés: {sentence} | Chiesto: {sentence} | Gevraagd: {sentence} | Perguntado: {sentence} | 已提问：{sentence} |

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/search/dive_ask_notice_test.dart`. It drives a real `DiveAskNotifier` with the fake engine and fixtures from Task 3 (copy `_Engine`, `_turtles`, `_nothing`, `_sitesWithLeftovers` and the `withJohn` twins fixture into this file), inside `testApp` with the same overrides as Task 3's `make`:

```dart
  testWidgets('lists the unplaced words, each with its reason', (tester) async {
    final c = await pump(tester, _Engine(_turtles));
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    expect(find.text("Couldn't use:"), findsOneWidget);
    expect(find.text('maybe'), findsOneWidget);
  });

  testWidgets('says what was asked when everything was placed', (tester) async {
    final c = await pump(tester, _Engine(_deep));
    await c.read(diveAskProvider.notifier).ask('deep dives');
    await tester.pump();
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  testWidgets('a name chip opens the picker and the pick applies', (
    tester,
  ) async {
    final c = await pump(tester, _Engine(withJohn), names: twins);
    await c.read(diveAskProvider.notifier).ask('dives with John Smith');
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'John Smith'));
    await tester.pumpAndSettle();
    expect(find.text('Which did you mean by "John Smith"?'), findsOneWidget);
    await tester.tap(find.text('John Smith').last);
    await tester.pumpAndSettle();
    expect(c.read(diveAskProvider).answer!.compiled.unresolved, isEmpty);
  });

  testWidgets('Undo and dismiss', (tester) async {
    var undone = 0;
    final c = await pump(tester, _Engine(_turtles), onUndo: () => undone++);
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskUndoKey));
    expect(undone, 1);
    await tester.tap(find.byKey(kDiveAskDismissKey));
    await tester.pump();
    expect(find.byKey(kDiveAskNoticeKey), findsNothing);
  });

  testWidgets('a non-dive answer offers Open in list', (tester) async {
    String? opened;
    final c = await pump(
      tester,
      _Engine(_sitesWithLeftovers),
      onOpenList: (route) => opened = route,
    );
    await c.read(diveAskProvider.notifier).ask('cosy sites rated 4');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskOpenListKey));
    expect(opened, '/sites');
  });

  testWidgets('a dive answer has no Open in list', (tester) async {
    final c = await pump(tester, _Engine(_turtles));
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    expect(find.byKey(kDiveAskOpenListKey), findsNothing);
  });
```

where `pump` builds `testApp(... child: DiveAskNotice(onUndo: onUndo ?? () {}, onOpenList: onOpenList ?? (_) {}))` and returns the container, and `twins` is the two-John `NameIndex` from Task 3.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_ask_notice_test.dart`
Expected: compile error, `dive_ask_notice.dart` does not exist.

- [ ] **Step 3: Implement**

Add the two strings to all 11 ARBs, run `flutter gen-l10n`, then create `dive_ask_notice.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveAskNoticeKey = ValueKey('dive-ask-notice');
const kDiveAskUndoKey = ValueKey('dive-ask-undo');
const kDiveAskOpenListKey = ValueKey('dive-ask-open-list');
const kDiveAskDismissKey = ValueKey('dive-ask-dismiss');

/// What an Ask did (#2773): the words it could not use, each name it
/// could not pin down (tap to pick), Undo, and for a sentence about sites,
/// gear and the like that still needs the diver, Open in list.
class DiveAskNotice extends ConsumerWidget {
  const DiveAskNotice({
    super.key,
    required this.onUndo,
    required this.onOpenList,
  });

  final VoidCallback onUndo;
  final ValueChanged<String> onOpenList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = ref.watch(diveAskProvider).answer;
    if (answer == null) return const SizedBox.shrink();
    final compiled = answer.compiled;
    final l10n = context.l10n;
    final notifier = ref.read(diveAskProvider.notifier);
    return Padding(
      key: kDiveAskNoticeKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  answer.needsAttention
                      ? l10n.diveLog_ask_couldNotUse
                      : l10n.diveLog_ask_asked(answer.sentence),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final u in compiled.unresolved)
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 16),
                    label: Text(u.mention.text),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _pick(context, ref, u),
                  ),
                for (final w in compiled.unplaced)
                  Tooltip(
                    message: _reason(l10n, w.reason) ?? '',
                    child: Chip(
                      label: Text(w.text),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          if (compiled.subject != ParsedSubject.dives && compiled.query != null)
            TextButton(
              key: kDiveAskOpenListKey,
              onPressed: () {
                final route = notifier.openAnswerList();
                if (route != null) onOpenList(route);
              },
              child: Text(l10n.explore_handoff_list),
            ),
          TextButton(
            key: kDiveAskUndoKey,
            onPressed: onUndo,
            child: Text(l10n.diveLog_search_undo),
          ),
          IconButton(
            key: kDiveAskDismissKey,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close, size: 18),
            onPressed: notifier.dismiss,
          ),
        ],
      ),
    );
  }

  static String? _reason(AppLocalizations l10n, String? reason) =>
      switch (reason) {
        'invalid' => l10n.explore_unplaced_reason_invalid,
        'noAxis' => l10n.explore_unplaced_reason_noAxis,
        'outOfRange' => l10n.explore_unplaced_reason_outOfRange,
        'unknownField' => l10n.explore_unplaced_reason_unknownField,
        'unknownTime' => l10n.explore_unplaced_reason_unknownTime,
        'aggregateWithScope' => l10n.explore_unplaced_reason_aggregateWithScope,
        _ => null,
      };

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    UnresolvedMention u,
  ) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<NameEntry>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.explore_pickCandidate_title(u.mention.text)),
            ),
            if (u.candidates.isEmpty)
              ListTile(subtitle: Text(l10n.explore_unresolved_noCandidates)),
            for (final c in u.candidates)
              ListTile(
                title: Text(c.label),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref.read(diveAskProvider.notifier).resolveWith(u.index, chosen);
    }
  }
}
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_ask_notice_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/l10n/arb lib/features/dive_log/presentation/widgets/search/dive_ask_notice.dart test/features/dive_log/presentation/widgets/search/dive_ask_notice_test.dart
git commit -m "feat(dive-log): the Ask notice, with Undo and the name picker"
```

---

### Task 6: Ask in the search row

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_header_ask_test.dart`

**Interfaces:**
- Consumes: `QueryTextOverride`, `onTextChanged`, `shortcuts` (Task 1); `diveAskProvider` (Task 3); `DiveAskRow` (Task 4); `DiveAskNotice` (Task 5); `exploreEnabledProvider`; `platformShortcut` from `lib/core/accessibility/app_shortcuts.dart`.
- Produces: no new public API.

- [ ] **Step 1: Write the failing tests**

Create `dive_search_header_ask_test.dart`. Build the header like `dive_search_header_test.dart`'s `pumpHeader` (same overrides), adding `nlEngineProvider` (a fake engine with `replies` and `gates` as in Task 3), `explorePlatformSupportedProvider.overrideWithValue(true)`, `exploreAvailabilityProvider.overrideWith((ref) async => NlAvailability.available)`, `localeProvider.overrideWithValue('en')`, `exploreNameIndexProvider.overrideWith((ref) async => NameIndex.empty)` and `recentQueryRecorderProvider.overrideWithValue((s, l, p) async {})`, and wrap the header in a `MaterialApp.router` with routes `/dives` (the header) and `/sites` (`Text('Sites page')`) so a handoff can navigate. Tests:

```dart
  testWidgets('typed text offers Ask, and asking replaces the query', (
    tester,
  ) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    expect(find.text('Ask: deep dives'), findsOneWidget);
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(filterOf().query, isNotNull);
    expect(fieldOf(tester).controller!.text, contains('40'));
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  testWidgets('Cmd/Ctrl+Enter asks', (tester) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  // Review Focus 2.
  testWidgets('words still waiting on the debounce never land on the answer', (
    tester,
  ) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    final answered = filterOf().query;
    expect(answered, isNot(TextNode(['deep'])));
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, answered);
  });

  // Review Focus 1.
  testWidgets('typing while the model works cancels the Ask', (tester) async {
    final engine = _Engine()..gates['deep dives'] = Completer<String>();
    await pumpHeader(tester, engine: engine);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    expect(find.text('Asking the on-device model'), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    engine.gates['deep dives']!.complete(_deep);
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, TextNode(['manta']));
    expect(find.text('Asking the on-device model'), findsNothing);
  });

  // Review Focus 5.
  testWidgets('Undo puts the sentence back and the old query', (tester) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['deep dives'] = _deep,
      filter: DiveFilterState(query: TextNode(['reef'])),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveAskUndoKey));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'deep dives');
    expect(filterOf().query, TextNode(['reef']));
  });

  testWidgets('a sentence about sites opens the site list', (tester) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['sites rated 4'] = _goodSites,
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'sites rated 4');
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.text('Sites page'), findsOneWidget);
  });

  testWidgets('no Ask row and no Cmd/Ctrl+Enter where the model is off', (
    tester,
  ) async {
    final engine = _Engine()..replies['deep dives'] = _deep;
    await pumpHeader(tester, engine: engine, supported: false);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    expect(find.byKey(kDiveAskRowKey), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(engine.compileCalls, 0);
  });

  testWidgets('closing the row drops the notice', (tester) async {
    await pumpHeader(tester, engine: _Engine()..replies['x'] = _nothing);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'x');
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveAskNoticeKey), findsOneWidget);
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(container.read(diveAskProvider).answer, isNull);
  });
```

On macOS test hosts the shortcut is Cmd: set `debugDefaultTargetPlatformOverride = TargetPlatform.linux` in `setUp` and reset it to null in `addTearDown`, so `platformShortcut` reads Control in every run.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_header_ask_test.dart`
Expected: FAIL, no `Ask: deep dives` row (and the other tests fail on the missing row, notice or shortcut).

- [ ] **Step 3: Implement**

In `dive_search_header.dart`:

Imports (added):

```dart
import 'package:flutter/services.dart';
import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_notice.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_row.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
```

State fields (after `_fieldValid`):

```dart
  /// What the diver typed, parsed or not: the sentence Ask would send.
  /// Cleared when the field is re-printed from outside (an answer, a chip
  /// removed), so the Ask row offers only text the diver wrote.
  String _text = '';

  /// Puts a sentence back into the field without applying it (Undo).
  QueryTextOverride? _textOverride;
```

In `_onFocusChange`, inside `if (_focus.hasFocus) {`:

```dart
      ref.read(diveAskProvider.notifier).prepare();
```

New methods (after `_onValidityChanged`):

```dart
  void _onTextChanged(String text) {
    setState(() => _text = text);
    // The diver typed on: their newer text wins over an answer on its way.
    ref.read(diveAskProvider.notifier).cancel();
  }

  Future<void> _ask() async {
    final sentence = _text.trim();
    if (sentence.isEmpty || !ref.read(exploreEnabledProvider)) return;
    // The words typed so far stay on their debounce: if the model answers
    // first, the answer's query write cancels it (the listener below); if
    // the model fails, the words apply as typed text does.
    final route = await ref.read(diveAskProvider.notifier).ask(sentence);
    if (!mounted) return;
    final ask = ref.read(diveAskProvider);
    if (ask.error == null && !ask.running && _text.trim() == sentence) {
      setState(() => _text = '');
    }
    if (route != null && mounted) context.go(route);
  }

  void _undoAsk() {
    final sentence = ref.read(diveAskProvider.notifier).undo();
    if (sentence == null) return;
    setState(() {
      _text = sentence;
      _textOverride = QueryTextOverride(sentence);
    });
    _focus.requestFocus();
  }
```

In `build`, inside the `diveSearchClearTickProvider` listener, after `_debounce?.cancel();`:

```dart
      ref.read(diveAskProvider.notifier).reset();
```

and change its `setState` to also clear the text:

```dart
      setState(() {
        _local = _jumpQuery = null;
        _text = '';
      });
```

In the `diveFilterProvider` listener, change its `setState` to:

```dart
      setState(() {
        _local = _jumpQuery = next.query;
        _text = '';
      });
```

After `final panelAxes = filter.panelAxisCount;`:

```dart
    final ask = ref.watch(diveAskProvider);
    final showAskRow =
        (_focus.hasFocus && _text.trim().isNotEmpty) ||
        ask.running ||
        ask.error != null;
```

`QueryTextField` gains:

```dart
                  onTextChanged: _onTextChanged,
                  textOverride: _textOverride,
                  shortcuts: {
                    if (ref.watch(exploreEnabledProvider))
                      platformShortcut(LogicalKeyboardKey.enter): _ask,
                  },
```

Between the field `Padding` and the jump list:

```dart
        if (showAskRow) DiveAskRow(text: _text, onAsk: _ask),
        DiveAskNotice(
          onUndo: _undoAsk,
          onOpenList: (route) => context.go(route),
        ),
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/search/`
Expected: all pass, the existing header, close and jump tests included.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/search/dive_search_header.dart test/features/dive_log/presentation/widgets/search/dive_search_header_ask_test.dart
git commit -m "feat(dive-log): Ask from the search row, with Cmd/Ctrl+Enter and Undo"
```

---

### Task 7: Retire the Explore page

**Files:**
- Delete: `lib/features/explore/presentation/pages/explore_page.dart`; `lib/features/explore/presentation/widgets/explore_charts.dart`, `explore_results_list.dart`, `explore_subject_results_list.dart`, `explore_handoff_bar.dart`, `explore_chip_rows.dart`; `lib/features/explore/presentation/chip_labeler.dart`, `explore_label_lookup.dart`; `lib/features/explore/presentation/providers/explore_providers.dart`, `explore_subject_providers.dart`
- Delete tests: `test/features/explore/presentation/pages/` (both files), `test/features/explore/presentation/widgets/` (both files), `test/features/explore/presentation/chip_labeler_test.dart`, `explore_label_lookup_test.dart`, `providers/explore_providers_test.dart`, `providers/explore_subject_providers_test.dart`, `test/core/accessibility/app_shortcuts_explore_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (Explore icons and their imports)
- Modify: `lib/core/router/app_router.dart`, `lib/core/accessibility/app_shortcuts.dart`, `lib/core/accessibility/shortcut_display.dart`
- Modify: `lib/l10n/arb/app_*.arb` (1 new key, orphans removed)
- Modify: `test/features/explore/presentation/providers/explore_providers_db_test.dart` (keep only the two query-semantics tests, run through the dive repository; rename the file `explore_compiled_query_db_test.dart`)
- Modify: `test/features/dive_log/presentation/pages/dive_list_explore_entry_test.dart`, `test/core/router/app_router_test.dart`, `test/architecture/provider_tick_build_smoke_test.dart` (only if it references a deleted provider)
- Create: `test/core/accessibility/app_shortcuts_ask_test.dart`

**Interfaces:**
- Consumes: `redirectRetiredDiveSearch` (`app_router.dart`).
- Produces: catalog entry label `'Ask about your dives'` (category `'Search'`, activator `platformShortcut(LogicalKeyboardKey.enter)`, `isGlobal: false`), registered only where `explorePlatformSupportedProvider` is true.

New string (`app_en.arb`, beside `accessibility_shortcut_searchDives`):

```json
  "accessibility_shortcut_askQuestion": "Ask about your dives",
```

| ar | de | es | fr | he | hu | it | nl | pt | zh |
|---|---|---|---|---|---|---|---|---|---|
| اسأل عن غطساتك | Zu deinen Tauchgängen fragen | Preguntar sobre tus inmersiones | Poser une question sur vos plongées | שאל על הצלילות שלך | Kérdezz a merüléseidről | Chiedi delle tue immersioni | Vraag over je duiken | Perguntar sobre seus mergulhos | 询问你的潜水记录 |

- [ ] **Step 1: Write the failing tests**

`test/core/router/app_router_test.dart`: turn the `'diveSearch route redirects to the dive list'` group's loop into one over `(name, location)` pairs, so `/dives/explore` is pinned like `/dives/search`:

```dart
    for (final (name, path, location) in [
      ('diveSearch', 'search', '/dives/search'),
      ('diveSearch', 'search', '/dives/search?section=query'),
      ('explore', 'explore', '/dives/explore'),
    ]) {
      testWidgets('a cold start at $location opens the search row', (
        tester,
      ) async {
        final route = _findRouteByName(router.configuration.routes, name)!;
        expect(route.redirect, same(redirectRetiredDiveSearch));
        // (the rest of the existing body, with
        //  GoRoute(path: path, redirect: redirectRetiredDiveSearch))
      });
    }
```

`test/features/dive_log/presentation/pages/dive_list_explore_entry_test.dart`: drop the `/dives/explore` route and the `tooltip` variable, and replace both tests with:

```dart
  testWidgets('the Dives app bar has no Explore entry, even with the model', (
    tester,
  ) async {
    await pump(tester, enabled: true);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
  });
```

Create `test/core/accessibility/app_shortcuts_ask_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/shortcut_display.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';

void main() {
  test('Cmd/Ctrl+E is gone from the catalog', () {
    AppShortcuts.ensureRegistered();
    expect(
      ShortcutCatalog.instance.entries.where(
        (e) =>
            e.activator.trigger == LogicalKeyboardKey.keyE ||
            e.label == 'Explore with a sentence',
      ),
      isEmpty,
    );
  });

  test('the Ask entry has a translated label', () {
    expect(hasShortcutEntryTranslation('Ask about your dives'), isTrue);
    expect(hasShortcutEntryTranslation('Explore with a sentence'), isFalse);
  });
}
```

(If `globalBindings` must run to register the Ask entry, as it did for Explore, add a widget test that pumps a `ProviderScope` with `explorePlatformSupportedProvider` overridden to true, calls `AppShortcuts.globalBindings(context)` from a `Builder`, and expects an entry labelled `'Ask about your dives'` with `LogicalKeyboardKey.enter`; and the same with false expecting none. Restore the catalog in `addTearDown` the way `app_shortcuts_explore_test.dart` did before deleting it.)

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/router/app_router_test.dart test/features/dive_log/presentation/pages/dive_list_explore_entry_test.dart test/core/accessibility/app_shortcuts_ask_test.dart`
Expected: FAIL: the `explore` route has no redirect, the Explore icon is found, the catalog still lists Cmd/Ctrl+E, no translation for the Ask label.

- [ ] **Step 3: Implement**

1. `app_router.dart`: replace the `explore` route's `builder` with `redirect: redirectRetiredDiveSearch` (keep `path: 'explore'` and `name: 'explore'`, before `':diveId'`), and drop the `explore_page.dart` import. Extend `redirectRetiredDiveSearch`'s doc comment to name both retired routes.
2. `dive_list_page.dart` and `dive_list_content.dart`: delete the three `if (ref.watch(exploreEnabledProvider)) IconButton(... '/dives/explore' ...)` entries and the now-unused `explore_gate_providers.dart` imports.
3. `app_shortcuts.dart`: delete `_openExplore`, `_explorePath`, `_openingExplore`, `_showExploreUnavailable` and the `keyE` binding; rename `_exploreLabel` to `_askLabel = 'Ask about your dives'` and `_syncExploreEntry` to `_syncAskEntry`, registering `ShortcutEntry(label: _askLabel, category: 'Search', activator: platformShortcut(LogicalKeyboardKey.enter))` (not global: it works inside the search field); update the comment in `ensureRegistered`; drop the `nl_engine.dart` import if unused.
4. `shortcut_display.dart`: replace the `'Explore with a sentence'` entry with `'Ask about your dives': (l10n) => l10n.accessibility_shortcut_askQuestion,`.
5. Add `accessibility_shortcut_askQuestion` to all 11 ARBs.
6. Delete the presentation files and tests listed under **Files**.
7. `explore_providers_db_test.dart`: `git mv` it to `explore_compiled_query_db_test.dart`; delete every test except `'query-tree clauses from the compiler run against the database'` and `'a not clause keeps dives with the field unrecorded'`; in those two, replace the `exploreQueryNodeProvider` write and `exploreResultsProvider` read with
   ```dart
   final results = await DiveRepository().getDiveSummaries(
     diverId: null,
     filter: DiveFilterState(query: compiled.query),
     limit: 100,
   );
   ```
   (import `dive_repository_impl.dart` and `dive_filter_state.dart`; drop the provider imports). If `getDiveSummaries` needs a non-null diver id here, read it the way `explore_providers.dart` did: `await c.read(validatedCurrentDiverIdProvider.future)`.
8. Orphaned strings: find every ARB key no Dart file under `lib/` uses any more, and remove it from all 11 ARBs:
   ```bash
   python3 - <<'EOF'
   import json, pathlib, re, subprocess
   keys = [k for k in json.load(open('lib/l10n/arb/app_en.arb', encoding='utf-8')) if not k.startswith('@')]
   src = '\n'.join(p.read_text(encoding='utf-8') for p in pathlib.Path('lib').rglob('*.dart') if '/l10n/arb/' not in str(p))
   orphans = [k for k in keys if not re.search(r'\b' + re.escape(k) + r'\b', src)]
   print(len(orphans)); print('\n'.join(orphans))
   EOF
   ```
   Review the list before deleting: only keys the deleted files used (Explore chip, field, op, value, chart, kind, count, results, title, hint, recent, understood, needsAttention, handoff diveList and insights, shortcut unavailable, `diveLog_listPage_tooltip_explore`, `accessibility_shortcut_exploreWithSentence`) go. Delete each key and its `@key` metadata from every ARB with a JSON-aware script (load, drop keys, dump with `ensure_ascii=False, indent=2` matching the file's existing format, keep a trailing newline), then run `flutter gen-l10n` and check that every ARB has the same key count.
9. `test/architecture/provider_tick_build_smoke_test.dart`: remove any entry naming a deleted provider (`exploreResultsProvider`, `exploreCountProvider`, `exploreChartDataProvider`, `exploreSubjectRowsProvider`, `exploreSubjectCountsProvider`); keep `exploreLegacyBuddyNamesProvider`.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter analyze && flutter test test/core test/features/explore test/features/dive_log test/architecture test/l10n`
Expected: no analyzer issues; all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add -A lib test
git status --short
git commit -m "feat(dive-log): retire the Explore page, its icon, Cmd/Ctrl+E and /dives/explore"
```

(Check `git status --short` before committing: only files this task names may be staged. A stale submodule pointer or another worktree's file must be unstaged.)

---

### Task 8: Whole-branch checks

**Files:** none new.

- [ ] **Step 1: Architecture guards and the full suite**

Run: `flutter test test/architecture` then the full suite (`flutter test`, output to a log file).
Expected: all pass. A failure in a file this branch did not touch is checked against `main` before it is blamed on the branch.

- [ ] **Step 2: Format and analyze**

Run: `dart format --set-exit-if-changed lib test && flutter analyze`
Expected: no changes, no issues.

- [ ] **Step 3: Spec 9 rows for this PR**

Confirm by test name that rows 6 (download prompt in the Ask row, couldn't-place notice with Undo), 11 (non-dive subjects reach their list) and 12 (Cmd/Ctrl+Enter asks) each have a passing test, and that Ruling 1's picker has one. Record the test names in the PR body.
