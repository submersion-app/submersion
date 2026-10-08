# Unified Dive Search, PR 1: the Search Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Dives Search overlay and Filter icon with one search icon that opens a live search row (plain words, quoted phrases, query syntax) over the dive list, with a jump-to-dive list, a Within filters / All dives toggle, Open in Insights, and close-with-Undo.

**Architecture:** `diveFilterProvider` stays the only search state. The search row (`DiveSearchHeader`) sits in the list body under the app bar of every layout, edits `DiveFilterState.query` through the existing `QueryTextField`, and is shown while the user opened it or anything is filtered. A new `axesSuspended` flag on `DiveFilterState`, honoured in `toQuery()`, implements "All dives". The query compiler's multi-word `TextNode` becomes an exact phrase.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` via `core/providers/provider.dart`), Drift, go_router, gen-l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-02-unified-dive-search-design.md` (read sections 3, 4.1, 5, 6, 7, 8 and 11 before starting). Issue: #2773.

## Global Constraints

- Never use the em-dash character or an en-dash as punctuation, anywhere (code, comments, commits, ARB values).
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file.
- Every user-visible string goes through `context.l10n`; every new key is translated into all 10 non-en ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh) and `flutter gen-l10n` runs LAST, after all ARBs hold their translations.
- Paths in tests are built with `p.join`, never `/`.
- A test that changes process-wide state restores it in `addTearDown`.
- Files stay under 800 lines; new files under about 300.
- Imports grouped: dart, flutter, packages, local.
- Units shown to the diver follow the active diver's unit settings (`UnitFormatter(ref.watch(settingsProvider))`).
- Run `dart format .` before every commit.
- Commit messages: conventional (`feat(dive-log): ...`), no trailers.
- The PR body must contain `Refs #2773` and screenshots (before/after, phone and desktop widths).

## Review Focus

1. **Typing during the debounce while something else writes the filter** (a scope-toggle tap or a chip removal inside 300 ms): the typed text must not be reverted and the later debounced write must not drop the other change. Pinned in Task 7.
2. **Desktop mouse click on a jump-to-dive row:** the mouse press would normally unfocus the field and hide the list before the click lands; the dive must still open. Pinned in Task 9.
3. **A search that matches nothing:** the search row must stay on screen (today the empty state replaces the whole list body including the chips). Pinned in Task 10.
4. **Undo after the row has collapsed** (or after the diver navigated away, which disposes the header's `WidgetRef`): Undo must still restore the search. Pinned in Task 8.
5. **"All dives" left on after the panel axes are cleared, then a new axis added from the Filter sheet:** the new axis must apply, not arrive dimmed. Pinned in Task 6.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/core/query/compiler/query_compiler.dart` | modify | multi-word `TextNode` = phrase |
| `lib/features/dive_log/domain/models/dive_filter_state.dart` | modify | `axesSuspended`, `panelAxisCount`, `effective` |
| `lib/features/dive_log/query/dive_filter_query.dart` | modify | `toQuery()` honours `axesSuspended` |
| `lib/features/dive_log/presentation/widgets/active_filter_chips.dart` | modify | dim + lock axis chips while suspended |
| `lib/core/query/presentation/query_text_field.dart` | modify | optional external `focusNode`, `onEscape` |
| `lib/features/dive_log/presentation/providers/dive_search_providers.dart` | create | open/visible/focus providers, jump results provider, constants |
| `lib/features/dive_log/presentation/widgets/search/close_dive_search.dart` | create | close + Undo snackbar |
| `lib/features/dive_log/presentation/widgets/search/dive_search_scope_toggle.dart` | create | Within filters / All dives |
| `lib/features/dive_log/presentation/widgets/search/dive_jump_list.dart` | create | inline jump-to-dive rows |
| `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart` | create | the search row, toggle, jump list, chips, Insights, Clear all |
| `lib/features/dive_log/presentation/widgets/search/dive_search_action.dart` | create | the one app-bar search icon |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | modify | header placement, remove Search/Filter icons and `_buildActiveFiltersBar` |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | modify | table-mode icons, delete `DiveSearchDelegate` |
| `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` | modify | Apply clears `axesSuspended` |
| `lib/core/accessibility/app_shortcuts.dart` | modify | Cmd/Ctrl+F opens and focuses the row |
| `lib/l10n/arb/app_*.arb` + generated | modify | 9 new keys |

---

### Task 1: Worktree setup and the quoted-phrase rule

**Files:**
- Modify: `lib/core/query/compiler/query_compiler.dart` (method `_text`, about line 137)
- Test: `test/core/query/compiler/query_compiler_scalar_test.dart` (test "text search ORs every template per word and ANDs words", about line 228)
- Test: `test/features/dive_log/query/dive_query_semantics_test.dart` (test "text search matches literally", about line 127)

**Interfaces:**
- Consumes: nothing.
- Produces: a `TextNode` with N words compiles to ONE term `'%<words joined by a single space>%'` per search template. The WHERE shape for a one-word node is unchanged: `((t1 OR t2 ...))`.

- [ ] **Step 0: Initialise the worktree** (fresh worktrees lack submodules, packages and codegen)

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: all three finish without errors.

- [ ] **Step 1: Rewrite the compiler test to the new rule**

In `test/core/query/compiler/query_compiler_scalar_test.dart`, replace the whole test `'text search ORs every template per word and ANDs words'` with:

```dart
  test('one text node is one term: a word, or a quoted phrase in order', () {
    final word = c(TextNode(['night']));
    expect(
      word.where,
      "((r0.notes LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM dive_sites ts "
      "WHERE ts.id = r0.site_id AND ts.name LIKE ? ESCAPE '\\')))",
    );
    expect(word.params, ['%night%', '%night%']);

    // A multi-word node only comes from quotes or a builder text row: the
    // words must appear together, in this order (#2773).
    final phrase = c(TextNode(['night', 'dive']));
    expect(phrase.where, word.where);
    expect(phrase.params, ['%night dive%', '%night dive%']);
    expect(phrase.tablesTouched, {'dives', 'dive_sites'});
  });

  test('bare words stay separate terms through an AND', () {
    final q = c(AndNode([TextNode(['night']), TextNode(['dive'])]));
    expect(q.params, ['%night%', '%night%', '%dive%', '%dive%']);
  });

  test('a phrase escapes LIKE wildcards like a word does', () {
    expect(c(TextNode(['100%', 'night'])).params.first, '%100\\% night%');
  });
```

- [ ] **Step 2: Add the end-to-end phrase expectations**

In `test/features/dive_log/query/dive_query_semantics_test.dart`, inside the test `'text search matches literally, including % (Review Focus 3)'`, append before its closing `});`:

```dart
    // Quotes are an exact phrase (#2773); bare words each match anywhere.
    expect(await ids('"night dive"'), {'d3'});
    expect(await ids('"dive night"'), isEmpty);
    expect(await ids('dive night'), {'d3'});
    expect(await ids('"manta ray"'), {'d1'});
    expect(await ids('"ray manta"'), isEmpty);
```

- [ ] **Step 3: Run both files and watch the new expectations fail**

Run: `flutter test test/core/query/compiler/query_compiler_scalar_test.dart test/features/dive_log/query/dive_query_semantics_test.dart`
Expected: FAIL. The phrase test reports params `[%night%, %night%, %dive%, %dive%]`; `"dive night"` returns `{d3}` instead of empty.

- [ ] **Step 4: Implement the phrase rule**

In `lib/core/query/compiler/query_compiler.dart`, replace the body of `_text` from `tables.addAll(entity.textSearchTables);` to the end of the method with:

```dart
    tables.addAll(entity.textSearchTables);
    // One node is one search term: a bare word, or a quoted phrase (or a
    // builder text row) whose words must appear together, in order. Bare
    // words arrive as separate one-word nodes under an AND (#2773).
    final term = '%${escapeLike(words.join(' '))}%';
    final alts = <String>[];
    for (final t in entity.textSearchSql) {
      alts.add(substituteRow(t, alias));
      for (var i = 0; i < countPlaceholders(t); i++) {
        params.add(term);
      }
    }
    return '((${alts.join(' OR ')}))';
  }
```

- [ ] **Step 5: Run the query test folders**

Run: `flutter test test/core/query test/features/dive_log/query`
Expected: PASS. If another test asserted the old AND-of-words params for a multi-word `TextNode`, update it to the phrase params (that is the intended behaviour change, spec 5.7).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/query/compiler/query_compiler.dart test/core/query/compiler/query_compiler_scalar_test.dart test/features/dive_log/query/dive_query_semantics_test.dart
git commit -m "feat(query): match quoted text as an exact phrase"
```

---

### Task 2: `axesSuspended`, `panelAxisCount` and `effective` on the filter state

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/dive_log/query/dive_filter_query.dart` (start of `toQuery()`)
- Test: `test/features/dive_log/domain/models/dive_filter_state_test.dart`
- Test: `test/features/dive_log/query/dive_filter_query_test.dart`

**Interfaces:**
- Produces:
  - `final bool axesSuspended;` (constructor default `false`)
  - `int get panelAxisCount` = `activeAxisCount` minus 1 when `query != null`
  - `DiveFilterState get effective` = `DiveFilterState(query: query)` when suspended, else `this`
  - `copyWith({..., bool? axesSuspended})`
  - `toQuery()` returns `query` alone when `axesSuspended`

- [ ] **Step 1: Write the failing state tests**

Append inside `main()` of `test/features/dive_log/domain/models/dive_filter_state_test.dart` (add `import 'package:submersion/core/query/domain/query_node.dart';` if absent):

```dart
  group('axesSuspended (#2773)', () {
    final q = TextNode(['manta']);

    test('defaults off and joins value equality', () {
      const a = DiveFilterState(minDepth: 30);
      expect(a.axesSuspended, isFalse);
      expect(a, isNot(a.copyWith(axesSuspended: true)));
      expect(
        a.copyWith(axesSuspended: true).hashCode,
        isNot(a.hashCode),
      );
    });

    test('copyWith keeps it unless told otherwise', () {
      final s = const DiveFilterState(
        minDepth: 30,
      ).copyWith(axesSuspended: true);
      expect(s.copyWith(maxDepth: 40).axesSuspended, isTrue);
      expect(s.copyWith(axesSuspended: false).axesSuspended, isFalse);
    });

    test('suspended axes still count, so the search stays open', () {
      final s = DiveFilterState(minDepth: 30, query: q, axesSuspended: true);
      expect(s.activeAxisCount, 2);
      expect(s.hasActiveFilters, isTrue);
    });

    test('panelAxisCount leaves the query out', () {
      expect(DiveFilterState(query: q).panelAxisCount, 0);
      expect(DiveFilterState(minDepth: 30, query: q).panelAxisCount, 1);
      expect(const DiveFilterState(minDepth: 30).panelAxisCount, 1);
    });

    test('effective is the query alone while suspended', () {
      final s = DiveFilterState(minDepth: 30, query: q, axesSuspended: true);
      expect(s.effective, DiveFilterState(query: q));
      final live = DiveFilterState(minDepth: 30, query: q);
      expect(identical(live.effective, live), isTrue);
    });
  });
```

- [ ] **Step 2: Write the failing lowering test**

Append inside `main()` of `test/features/dive_log/query/dive_filter_query_test.dart`:

```dart
  test('suspended axes lower to the query alone (#2773)', () {
    final q = TextNode(['manta']);
    expect(
      DiveFilterState(minDepth: 30, query: q, axesSuspended: true).toQuery(),
      q,
    );
    expect(
      const DiveFilterState(minDepth: 30, axesSuspended: true).toQuery(),
      isNull,
    );
  });
```

- [ ] **Step 3: Run and watch them fail**

Run: `flutter test test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_log/query/dive_filter_query_test.dart`
Expected: compile errors, `axesSuspended` / `panelAxisCount` / `effective` not defined.

- [ ] **Step 4: Add the field to `DiveFilterState`**

In `dive_filter_state.dart`:

1. After the `final QueryNode? query;` declaration (and its doc comment) add:

```dart

  /// "All dives" in the search row (#2773): while true every axis other
  /// than [query] is kept but not applied, so the typed search runs over
  /// the whole log. Only the dive list's search row sets it; Open in
  /// Insights hands over [effective] instead, since Insights has no toggle.
  final bool axesSuspended;
```

2. In the const constructor, after `this.query,` add `this.axesSuspended = false,`.

3. After the `activeAxisCount` getter add:

```dart

  /// Active axes the Refine panel owns: everything but the typed [query].
  int get panelAxisCount => activeAxisCount - (query != null ? 1 : 0);

  /// What actually applies: the query alone while [axesSuspended].
  DiveFilterState get effective =>
      axesSuspended ? DiveFilterState(query: query) : this;
```

4. In `operator ==`, change the last line `other.query == query;` to:

```dart
          other.query == query &&
          other.axesSuspended == axesSuspended;
```

5. In `hashCode`, after `query,` add `axesSuspended,`.

6. In `copyWith`, add the parameter `bool? axesSuspended,` after `QueryNode? query,`, and in the returned constructor after the `query:` line add:

```dart
      axesSuspended: axesSuspended ?? this.axesSuspended,
```

- [ ] **Step 5: Honour it in `toQuery()`**

In `lib/features/dive_log/query/dive_filter_query.dart`, make the first statement of `toQuery()`:

```dart
    // "All dives" (#2773): the axes stay set but only the typed query runs.
    if (axesSuspended) return query;
```

- [ ] **Step 6: Run the tests, including the census**

Run: `flutter test test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_log/query`
Expected: PASS (the census finds `axesSuspended` named in `dive_filter_query.dart`).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/models/dive_filter_state.dart lib/features/dive_log/query/dive_filter_query.dart test/features/dive_log/domain/models/dive_filter_state_test.dart test/features/dive_log/query/dive_filter_query_test.dart
git commit -m "feat(dive-log): let a dive search suspend its filter axes"
```

---

### Task 3: Localized strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 others; regenerate `lib/l10n/arb/app_localizations*.dart`
- Create (throwaway, not committed): `$SCRATCH/add_search_keys.py` where `$SCRATCH` is the session scratchpad

**Interfaces:**
- Produces getters: `diveLog_search_fieldHint`, `diveLog_search_refineTooltip`, `diveLog_search_closeTooltip`, `diveLog_search_scopeWithin`, `diveLog_search_scopeAll`, `diveLog_search_jumpTitle`, `diveLog_search_openInsights`, `diveLog_search_cleared`, `diveLog_search_undo` (all plain `String`, no placeholders).

- [ ] **Step 1: Write the insertion script**

The hint keeps the query syntax (`depth > 30m`) and ASCII quotes literal in every locale, since that is what the diver types.

```python
# add_search_keys.py: inserts the PR 1 search keys into every ARB as text,
# anchored on an existing key line, so no other block is reformatted.
import json, pathlib, sys

ARB = pathlib.Path(sys.argv[1])
KEYS = {
  "en": ["Words, \"exact phrase\" or depth > 30m", "Refine", "Close search", "Within filters", "All dives", "Jump to dive", "Open in Insights", "Search cleared", "Undo"],
  "ar": ["كلمات أو \"عبارة دقيقة\" أو depth > 30m", "تحسين البحث", "إغلاق البحث", "ضمن عوامل التصفية", "كل الغوصات", "الانتقال إلى غوصة", "فتح في الرؤى", "تم مسح البحث", "تراجع"],
  "de": ["Wörter, \"genaue Phrase\" oder depth > 30m", "Verfeinern", "Suche schließen", "Innerhalb der Filter", "Alle Tauchgänge", "Zum Tauchgang springen", "In Einblicken öffnen", "Suche zurückgesetzt", "Rückgängig"],
  "es": ["Palabras, \"frase exacta\" o depth > 30m", "Refinar", "Cerrar búsqueda", "Dentro de los filtros", "Todas las inmersiones", "Ir a la inmersión", "Abrir en Análisis", "Búsqueda borrada", "Deshacer"],
  "fr": ["Mots, \"expression exacte\" ou depth > 30m", "Affiner", "Fermer la recherche", "Dans les filtres", "Toutes les plongées", "Aller à la plongée", "Ouvrir dans les analyses", "Recherche effacée", "Annuler"],
  "he": ["מילים, \"ביטוי מדויק\" או depth > 30m", "צמצום", "סגירת החיפוש", "בתוך המסננים", "כל הצלילות", "מעבר לצלילה", "פתיחה בתובנות", "החיפוש נוקה", "ביטול"],
  "hu": ["Szavak, \"pontos kifejezés\" vagy depth > 30m", "Szűkítés", "Keresés bezárása", "A szűrőkön belül", "Összes merülés", "Ugrás a merüléshez", "Megnyitás az Elemzésekben", "Keresés törölve", "Visszavonás"],
  "it": ["Parole, \"frase esatta\" o depth > 30m", "Affina", "Chiudi ricerca", "Nei filtri", "Tutte le immersioni", "Vai all'immersione", "Apri in Analisi", "Ricerca cancellata", "Annulla"],
  "nl": ["Woorden, \"exacte zin\" of depth > 30m", "Verfijnen", "Zoeken sluiten", "Binnen filters", "Alle duiken", "Naar duik springen", "Openen in Inzichten", "Zoekopdracht gewist", "Ongedaan maken"],
  "pt": ["Palavras, \"frase exata\" ou depth > 30m", "Refinar", "Fechar busca", "Dentro dos filtros", "Todos os mergulhos", "Ir para o mergulho", "Abrir em Análises", "Busca limpa", "Desfazer"],
  "zh": ["词语、\"精确短语\"或 depth > 30m", "细化", "关闭搜索", "在筛选范围内", "全部潜水", "跳转到潜水", "在洞察中打开", "已清除搜索", "撤消"],
}
NAMES = ["fieldHint", "refineTooltip", "closeTooltip", "scopeWithin", "scopeAll", "jumpTitle", "openInsights", "cleared", "undo"]
ANCHOR = '"diveLog_listPage_tooltip_searchDives"'

for loc, values in KEYS.items():
    path = ARB / f"app_{loc}.arb"
    lines = path.read_text(encoding="utf-8").split("\n")
    idx = next(i for i, l in enumerate(lines) if l.lstrip().startswith(ANCHOR))
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    new = [f'{indent}"diveLog_search_{n}": {json.dumps(v, ensure_ascii=False)},' for n, v in zip(NAMES, values)]
    assert not any(f'"diveLog_search_{NAMES[0]}"' in l for l in lines), loc
    lines[idx + 1 : idx + 1] = new
    path.write_text("\n".join(lines), encoding="utf-8")
    print(loc, "ok")
```

- [ ] **Step 2: Run it and regenerate**

```bash
python3.14 "$SCRATCH/add_search_keys.py" lib/l10n/arb
flutter gen-l10n
grep -A1 "get diveLog_search_scopeAll" lib/l10n/arb/app_localizations_de.dart
```

Expected: eleven `ok` lines; the grep shows `'Alle Tauchgänge'` (not English). The anchor line ends with a comma in every file, so the inserted lines (each ending in a comma) keep the JSON valid.

- [ ] **Step 3: Verify every locale changed evenly**

Run: `git diff --numstat lib/l10n/arb/`
Expected: every `app_XX.arb` shows `9 0`; each generated `app_localizations_XX.dart` shows additions.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n(dive-log): add strings for the unified dive search row"
```

---

### Task 4: Dim and lock axis chips while suspended

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/active_filter_chips.dart`
- Test: `test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`

**Interfaces:**
- Consumes: `DiveFilterState.axesSuspended` (Task 2).
- Produces: while suspended, every axis chip renders at opacity 0.4 with no delete icon; query chips are unchanged.

- [ ] **Step 1: Write the failing test**

Read the top of `active_filter_chips_test.dart` for its host helper (it pumps `activeDiveFilterChips(context, ref, provider)` inside a `Wrap`). Add a test following that file's pattern, with a provider seeded by:

```dart
DiveFilterState(
  minDepth: 30,
  query: TextNode(['manta']),
  axesSuspended: true,
)
```

and these expectations:

```dart
    final depthChip = find.ancestor(
      of: find.textContaining('30'),
      matching: find.byType(Chip),
    );
    expect(depthChip, findsOneWidget);
    expect(tester.widget<Chip>(depthChip).onDeleted, isNull);
    expect(
      find.ancestor(of: depthChip, matching: find.byType(Opacity)),
      findsOneWidget,
    );
    final queryChip = find.widgetWithText(Chip, 'manta');
    expect(tester.widget<Chip>(queryChip).onDeleted, isNotNull);
```

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`
Expected: FAIL, the depth chip has an `onDeleted`.

- [ ] **Step 3: Implement**

1. Change `_chip` at the bottom of the file to:

```dart
Widget _chip(
  BuildContext context,
  String label,
  VoidCallback? onRemove, {
  bool dimmed = false,
}) {
  final chip = Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
  );
  return dimmed ? Opacity(opacity: 0.4, child: chip) : chip;
}
```

2. In `activeDiveFilterChips`, right after `final chips = <Widget>[];` add:

```dart
  // "All dives" (#2773): the axes stay visible but dimmed and locked, so
  // the diver sees what will come back when the search returns to them.
  final suspended = filter.axesSuspended;
  Widget axisChip(String label, VoidCallback onRemove) =>
      _chip(context, label, suspended ? null : onRemove, dimmed: suspended);
```

3. Route every AXIS chip through it, leaving the query chip alone:

```bash
sed -i '' '/queryLabels\[i\]/! s/_chip(context, /axisChip(/' lib/features/dive_log/presentation/widgets/active_filter_chips.dart
grep -n "_chip(context\|axisChip(" lib/features/dive_log/presentation/widgets/active_filter_chips.dart
```

Expected grep: twelve `axisChip(` call sites, one `_chip(context, queryLabels[i]`, plus the `axisChip` definition line calling `_chip(context, label, ...`.

- [ ] **Step 4: Run the chip tests and the Connections filter tab tests**

Run: `flutter test test/features/dive_log/presentation/widgets/active_filter_chips_test.dart test/features/connections`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/active_filter_chips.dart test/features/dive_log/presentation/widgets/active_filter_chips_test.dart
git commit -m "feat(dive-log): dim suspended filter chips"
```

---

### Task 5: `QueryTextField` takes an external focus node and an Escape handler

**Files:**
- Modify: `lib/core/query/presentation/query_text_field.dart`
- Test: `test/core/query/presentation/query_text_field_test.dart`

**Interfaces:**
- Produces: two optional constructor parameters, `FocusNode? focusNode` (the field uses it instead of its own and does NOT dispose it) and `VoidCallback? onEscape` (called when Escape is pressed while the field has focus).

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `query_text_field_test.dart` (add `import 'package:flutter/services.dart';`):

```dart
  testWidgets('uses an outside focus node and leaves it undisposed', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            focusNode: focus,
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(fieldKey)).focusNode,
      same(focus),
    );
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    // Still usable: the field did not dispose a node it does not own.
    expect(() => focus.hasFocus, returnsNormally);
  });

  testWidgets('Escape in the field calls onEscape', (tester) async {
    var escaped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            onEscape: () => escaped++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(escaped, 1);
  });
```

- [ ] **Step 2: Run and watch them fail**

Run: `flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: compile error, no `focusNode` / `onEscape` parameter.

- [ ] **Step 3: Implement**

1. Add `import 'package:flutter/services.dart';` under the flutter material import.
2. Add to the constructor `this.focusNode, this.onEscape,` and the fields:

```dart
  /// Focus for the text field; the field makes and disposes its own when
  /// null. An outside node stays the caller's to dispose.
  final FocusNode? focusNode;

  /// Called on Escape while the field has focus.
  final VoidCallback? onEscape;
```

3. In the state, replace `final _focus = FocusNode();` with:

```dart
  final _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
```

4. In `initState` keep `_focus.addListener(_onFocusChange);`. Add to `didUpdateWidget`, as its first statement after `super.didUpdateWidget(old);`:

```dart
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus).removeListener(_onFocusChange);
      _focus.addListener(_onFocusChange);
    }
```

5. In `dispose`, replace the `_focus..removeListener(...)..dispose();` cascade with:

```dart
    _focus.removeListener(_onFocusChange);
    _ownFocus.dispose();
```

6. In `build`, wrap the `TextField(...)` expression (the first child of the Column) as:

```dart
        CallbackShortcuts(
          bindings: {
            if (widget.onEscape != null)
              const SingleActivator(LogicalKeyboardKey.escape): widget.onEscape!,
          },
          child: TextField(
            // unchanged arguments
          ),
        ),
```

- [ ] **Step 4: Run the core query presentation tests**

Run: `flutter test test/core/query/presentation`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/query/presentation/query_text_field.dart test/core/query/presentation/query_text_field_test.dart
git commit -m "feat(query): let a query text field share focus and handle Escape"
```

---

### Task 6: Search providers, and the Filter sheet ending a suspension

**Files:**
- Create: `lib/features/dive_log/presentation/providers/dive_search_providers.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (`_applyFilters`, about line 1588)
- Test: `test/features/dive_log/presentation/providers/dive_search_providers_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `diveFilterProvider`, `diveRepositoryProvider`, `validatedCurrentDiverIdProvider`, `safetyReviewDisabledRulesProvider`, `DiveRepository.getDiveSummaries({String? diverId, DiveFilterState filter, int limit, Set<String> disabledSafetyRules})`, `DiveRepository.watchDivesChanges()`.
- Produces:
  - `const Duration kDiveSearchDebounce = Duration(milliseconds: 300);`
  - `const int kDiveJumpResultLimit = 5;`
  - `final diveSearchBarOpenProvider = StateProvider<bool>(...)` (false)
  - `final diveSearchFocusPendingProvider = StateProvider<bool>(...)` (false)
  - `final diveSearchBarVisibleProvider = Provider<bool>(...)` = open OR `hasActiveFilters`
  - `final diveJumpResultsProvider = FutureProvider.autoDispose.family<List<DiveSummary>, QueryNode>(...)`
  - Opening the row is two writes, done by each caller (Task 11, Task 12): `diveSearchBarOpenProvider = true` and `diveSearchFocusPendingProvider = true`.

- [ ] **Step 1: Write the failing provider tests**

Create `test/features/dive_log/presentation/providers/dive_search_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeRepository implements DiveRepository {
  DiveFilterState? lastFilter;
  int? lastLimit;
  String? lastDiver;
  Object? failWith;

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    dynamic cursor,
    int? offset,
    int limit = 50,
    dynamic sort,
    Set<String> disabledSafetyRules = const {},
  }) async {
    if (failWith != null) throw failWith!;
    lastFilter = filter;
    lastLimit = limit;
    lastDiver = diverId;
    return [DiveSummary(id: 'd1', dateTime: DateTime(2026, 3, 1))];
  }

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer makeContainer(_FakeRepository repo) {
    final c = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        safetyReviewDisabledRulesProvider.overrideWithValue(const {}),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the row shows when opened or when anything is filtered', () {
    final c = makeContainer(_FakeRepository());
    expect(c.read(diveSearchBarVisibleProvider), isFalse);
    c.read(diveSearchBarOpenProvider.notifier).state = true;
    expect(c.read(diveSearchBarVisibleProvider), isTrue);
    c.read(diveSearchBarOpenProvider.notifier).state = false;
    c.read(diveFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 30,
    );
    expect(c.read(diveSearchBarVisibleProvider), isTrue);
  });

  test('jump results run the typed query alone, newest first, capped', () async {
    final repo = _FakeRepository();
    final c = makeContainer(repo);
    // A filter on the list must not narrow the jump list.
    c.read(diveFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 30,
    );
    final q = TextNode(['manta']);
    final sub = c.listen(diveJumpResultsProvider(q), (_, _) {});
    addTearDown(sub.close);
    final rows = await c.read(diveJumpResultsProvider(q).future);
    expect(rows.single.id, 'd1');
    expect(repo.lastFilter, DiveFilterState(query: q));
    expect(repo.lastLimit, kDiveJumpResultLimit);
    expect(repo.lastDiver, 'me');
  });

  test('a failing jump query yields no rows instead of an error', () async {
    final repo = _FakeRepository()..failWith = StateError('boom');
    final c = makeContainer(repo);
    final q = TextNode(['manta']);
    final sub = c.listen(diveJumpResultsProvider(q), (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(diveJumpResultsProvider(q).future), isEmpty);
  });
}
```

If `getDiveSummaries`'s real parameter types for `cursor`/`sort` make the `dynamic` override fail to compile, copy the exact parameter list from `dive_repository_impl.dart:2218` (types `DiveSummaryCursor?` and `SortState<DiveSortField>?` with their imports).

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/providers/dive_search_providers_test.dart`
Expected: compile error, `dive_search_providers.dart` missing.

- [ ] **Step 3: Create the providers file**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How long typing rests before the dive list re-runs the search (#2773).
const Duration kDiveSearchDebounce = Duration(milliseconds: 300);

/// Rows in the inline jump-to-dive list under the search field.
const int kDiveJumpResultLimit = 5;

const _log = LoggerService('DiveSearch');

/// The diver opened the search row (the search icon, Cmd/Ctrl+F, or
/// focusing the field). The row also shows whenever anything is filtered;
/// see [diveSearchBarVisibleProvider].
final diveSearchBarOpenProvider = StateProvider<bool>((ref) => false);

/// Set by whatever opens the row and wants the caret in it; the row takes
/// the request (and clears it) once it is built.
final diveSearchFocusPendingProvider = StateProvider<bool>((ref) => false);

/// Whether the search row is on screen: opened, or anything filtered, so a
/// search is never active out of sight (spec decision 9).
final diveSearchBarVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(diveSearchBarOpenProvider) ||
      ref.watch(diveFilterProvider).hasActiveFilters,
);

/// The jump-to-dive rows for [query]: the typed query ALONE over every dive
/// of the diver, ignoring the list's other axes, newest first. A failure
/// hides the rows rather than surfacing an error over the list.
final diveJumpResultsProvider = FutureProvider.autoDispose
    .family<List<DiveSummary>, QueryNode>((ref, query) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      try {
        return await repository.getDiveSummaries(
          diverId: diverId,
          filter: DiveFilterState(query: query),
          limit: kDiveJumpResultLimit,
          disabledSafetyRules: ref.watch(safetyReviewDisabledRulesProvider),
        );
      } catch (e, stackTrace) {
        _log.error('Jump-to-dive query failed', error: e, stackTrace: stackTrace);
        return const <DiveSummary>[];
      }
    });
```

- [ ] **Step 4: Run the provider tests**

Run: `flutter test test/features/dive_log/presentation/providers/dive_search_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing sheet test (Review Focus 5)**

In `test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`, add a test using that file's existing host (it opens `DiveFilterSheet` against a `StateProvider<DiveFilterState>`). Seed the provider with `DiveFilterState(query: TextNode(['manta']), axesSuspended: true)`, tap the sheet's Apply button (find it the way the file's other Apply tests do, `find.text('Apply')` under `locale: en`), then:

```dart
    expect(container.read(provider).axesSuspended, isFalse);
    expect(container.read(provider).query, TextNode(['manta']));
```

(If the file reads state through `ProviderScope.containerOf`, use that.)

- [ ] **Step 6: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart`
Expected: FAIL, `axesSuspended` is still true.

- [ ] **Step 7: Make Apply end a suspension**

In `dive_filter_sheet.dart` `_applyFilters`, inside the `current.copyWith(` call, add as the first argument:

```dart
      // A filter applied here is meant to take effect: leave "All dives".
      axesSuspended: false,
```

- [ ] **Step 8: Run the sheet tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_query_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_explore_axes_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/providers/dive_search_providers.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart test/features/dive_log/presentation/providers/dive_search_providers_test.dart test/features/dive_log/presentation/widgets/dive_filter_sheet_test.dart
git commit -m "feat(dive-log): add dive search row state and jump-to-dive results"
```

---

### Task 7: The search row (`DiveSearchHeader`) with live, debounced filtering

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Create: `lib/features/dive_log/presentation/widgets/search/close_dive_search.dart` (stub here, finished in Task 8)
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`

**Interfaces:**
- Consumes: Task 5 (`QueryTextField.focusNode/onEscape`), Task 6 providers, `DiveFilterSheet(ref: ref)`.
- Produces:
  - `class DiveSearchHeader extends ConsumerStatefulWidget { const DiveSearchHeader({super.key, required this.onOpenDive}); final ValueChanged<DiveSummary> onOpenDive; }`
  - keys: `const kDiveSearchFieldKey = ValueKey('dive-search-field');`, `kDiveSearchRefineKey`, `kDiveSearchCloseKey`, `kDiveSearchInsightsKey` (`ValueKey('dive-search-refine')`, `'dive-search-close'`, `'dive-search-insights'`)
  - `void closeDiveSearch(BuildContext context, WidgetRef ref)` in `close_dive_search.dart`

- [ ] **Step 1: Create the close stub so the header compiles**

`close_dive_search.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';

/// Closes the search row. Task 8 adds clearing with Undo.
void closeDiveSearch(BuildContext context, WidgetRef ref) {
  ref.read(diveSearchBarOpenProvider.notifier).state = false;
}
```

- [ ] **Step 2: Write the failing header tests**

Create `test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHeader(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
    bool open = true,
    List<DiveSummary> jump = const [],
    ValueChanged<DiveSummary>? onOpenDive,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => open),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) async => jump),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveSearchHeader(onOpenDive: onOpenDive ?? (_) {});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DiveFilterState filterOf() => container.read(diveFilterProvider);

  testWidgets('hidden while closed and nothing is filtered', (tester) async {
    await pumpHeader(tester, open: false);
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
  });

  testWidgets('typing filters the list after the debounce', (tester) async {
    await pumpHeader(tester);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    expect(filterOf().query, isNull, reason: 'still inside the debounce');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
  });

  testWidgets('invalid text shows an error and keeps the last query', (
    tester,
  ) async {
    await pumpHeader(tester, filter: DiveFilterState(query: TextNode(['manta'])));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'depth >');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    final field = tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));
    expect(field.decoration?.errorText, isNotNull);
  });

  testWidgets('an outside query change re-prints the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['wreck']),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));
    expect(field.controller!.text, 'wreck');
  });

  // Review Focus 1.
  testWidgets('another write inside the debounce keeps both changes', (
    tester,
  ) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    container.read(diveFilterProvider.notifier).state = filterOf().copyWith(
      axesSuspended: true,
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));
    expect(field.controller!.text, 'manta', reason: 'typing not reverted');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    expect(filterOf().axesSuspended, isTrue);
  });

  testWidgets('a focus request puts the caret in the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveSearchFocusPendingProvider.notifier).state = true;
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isFalse);
  });

  testWidgets('the refine button badges the panel axis count', (tester) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
    );
    final badge = find.descendant(
      of: find.byKey(kDiveSearchRefineKey),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`
Expected: compile error, `dive_search_header.dart` missing.

- [ ] **Step 4: Create the header**

`lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/close_dive_search.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveSearchFieldKey = ValueKey('dive-search-field');
const kDiveSearchRefineKey = ValueKey('dive-search-refine');
const kDiveSearchCloseKey = ValueKey('dive-search-close');
const kDiveSearchInsightsKey = ValueKey('dive-search-insights');

/// The dive list's one search row (#2773): plain words, quoted phrases and
/// query syntax in one field, filtering the list as the diver types. It
/// sits under every layout's app bar, outside the list's loading and empty
/// states, and shows while opened or while anything is filtered.
class DiveSearchHeader extends ConsumerStatefulWidget {
  const DiveSearchHeader({super.key, required this.onOpenDive});

  /// Opens one dive, the way tapping its list row does.
  final ValueChanged<DiveSummary> onOpenDive;

  @override
  ConsumerState<DiveSearchHeader> createState() => _DiveSearchHeaderState();
}

class _DiveSearchHeaderState extends ConsumerState<DiveSearchHeader> {
  final _focus = FocusNode();
  Timer? _debounce;

  /// The field's latest clean tree, ahead of the debounced write.
  QueryNode? _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(diveFilterProvider).query;
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeFocusRequest());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Focusing the field opens the row, so clearing the text never
    // collapses it under the caret.
    if (_focus.hasFocus) {
      ref.read(diveSearchBarOpenProvider.notifier).state = true;
    }
    setState(() {});
  }

  void _takeFocusRequest() {
    if (!mounted || !ref.read(diveSearchFocusPendingProvider)) return;
    ref.read(diveSearchFocusPendingProvider.notifier).state = false;
    // After the frame: the field may only now be built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onQueryChanged(QueryNode? node) {
    setState(() => _local = node);
    _debounce?.cancel();
    _debounce = Timer(kDiveSearchDebounce, () {
      final notifier = ref.read(diveFilterProvider.notifier);
      // Read at write time, so a change made during the debounce survives.
      notifier.state = notifier.state.copyWith(
        query: node,
        clearQuery: node == null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(diveSearchFocusPendingProvider, (_, pending) {
      if (pending) _takeFocusRequest();
    });
    ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      // Only a change to the QUERY from outside (a chip removed, a saved
      // search loaded) replaces the text; another axis changing mid-debounce
      // must not revert what the diver is typing.
      if (previous?.query == next.query || next.query == _local) return;
      _debounce?.cancel();
      setState(() => _local = next.query);
    });

    if (!ref.watch(diveSearchBarVisibleProvider)) {
      return const SizedBox.shrink();
    }
    final filter = ref.watch(diveFilterProvider);
    final l10n = context.l10n;
    final editorContext = QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: ref.watch(queryUnitPrefsProvider),
      names: ref.watch(queryNameIndexProvider).value ?? NameIndex.empty,
      labels: AppQueryLabels(context),
      now: DateTime.now,
    );
    final panelAxes = filter.panelAxisCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QueryTextField(
                  context: editorContext,
                  value: _local,
                  onChanged: _onQueryChanged,
                  hintText: l10n.diveLog_search_fieldHint,
                  describeError: (e) => describeQueryError(l10n, e),
                  fieldKey: kDiveSearchFieldKey,
                  focusNode: _focus,
                  onEscape: () => closeDiveSearch(context, ref),
                ),
              ),
              IconButton(
                key: kDiveSearchRefineKey,
                tooltip: l10n.diveLog_search_refineTooltip,
                icon: Badge(
                  isLabelVisible: panelAxes > 0,
                  label: Text('$panelAxes'),
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DiveFilterSheet(ref: ref),
                ),
              ),
              IconButton(
                key: kDiveSearchCloseKey,
                tooltip: l10n.diveLog_search_closeTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => closeDiveSearch(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

(Tasks 8 to 10 add the jump list, the scope toggle and the chips row to the `children` list.)

- [ ] **Step 5: Run the header tests**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`
Expected: PASS. If `queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty)` fails to type-check, use `overrideWith((ref) => Future.value(NameIndex.empty))`.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/search test/features/dive_log/presentation/widgets/search
git commit -m "feat(dive-log): add the live dive search row"
```

---

### Task 8: Closing with Undo

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/search/close_dive_search.dart`
- Test: `test/features/dive_log/presentation/widgets/search/close_dive_search_test.dart`

**Interfaces:**
- Consumes: `diveSearchBarOpenProvider`, `diveFilterProvider`, l10n `diveLog_search_cleared`, `diveLog_search_undo`.
- Produces: `closeDiveSearch(context, ref)` collapses the row; with an active search it also resets to `const DiveFilterState()` and shows a snackbar whose Undo restores the snapshot and reopens the row, even after the row is gone.

- [ ] **Step 1: Write the failing tests (Review Focus 4)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, DiveFilterState filter) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) async => const []),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveSearchHeader(onOpenDive: (_) {});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('closing an idle row just collapses it', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('closing an active search clears it, and Undo brings it back', (
    tester,
  ) async {
    final active = DiveFilterState(minDepth: 30, query: TextNode(['manta']));
    await pump(tester, active);
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), const DiveFilterState());
    // The row has collapsed; Undo comes from the snackbar alone.
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
    expect(find.text('Search cleared'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), active);
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
  });

  testWidgets('Escape in the field closes like the button', (tester) async {
    await pump(tester, DiveFilterState(query: TextNode(['manta'])));
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), const DiveFilterState());
  });
}
```

Add `import 'package:flutter/services.dart';` for `LogicalKeyboardKey`.

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/close_dive_search_test.dart`
Expected: FAIL on the second test (filter not cleared).

- [ ] **Step 3: Implement**

Replace `close_dive_search.dart` with:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Closes the search row (#2773). With anything searched or filtered it
/// also clears the search, offering Undo.
void closeDiveSearch(BuildContext context, WidgetRef ref) {
  // The container, not [ref]: Undo runs from the snackbar, possibly after
  // the diver has left the list and the widget owning [ref] is gone.
  final container = ProviderScope.containerOf(context, listen: false);
  final snapshot = container.read(diveFilterProvider);
  container.read(diveSearchBarOpenProvider.notifier).state = false;
  if (!snapshot.hasActiveFilters) return;
  container.read(diveFilterProvider.notifier).state = const DiveFilterState();
  final l10n = context.l10n;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_search_cleared),
        action: SnackBarAction(
          label: l10n.diveLog_search_undo,
          onPressed: () {
            container.read(diveFilterProvider.notifier).state = snapshot;
          },
        ),
      ),
    );
}
```

- [ ] **Step 4: Run the search widget tests**

Run: `flutter test test/features/dive_log/presentation/widgets/search`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/search/close_dive_search.dart test/features/dive_log/presentation/widgets/search/close_dive_search_test.dart
git commit -m "feat(dive-log): close the dive search with Undo"
```

---

### Task 9: Jump-to-dive list and the scope toggle

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_jump_list.dart`
- Create: `lib/features/dive_log/presentation/widgets/search/dive_search_scope_toggle.dart`
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart` (`children` list)
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart` (append)

**Interfaces:**
- Consumes: `diveJumpResultsProvider`, `kDiveJumpResultLimit`, `DiveFilterState.axesSuspended/panelAxisCount`.
- Produces: `DiveJumpList({required QueryNode query, required ValueChanged<DiveSummary> onOpen})`; `DiveSearchScopeToggle()` (const); keys `ValueKey('dive-jump-<id>')` per row and `ValueKey('dive-search-scope')` on the toggle.

- [ ] **Step 1: Append the failing tests**

Add to `dive_search_header_test.dart` (imports: `package:flutter/gestures.dart`, `package:flutter/foundation.dart`):

```dart
  final jumpRows = [
    DiveSummary(id: 'd1', dateTime: DateTime(2026, 3, 1), siteName: 'Manta Point'),
  ];

  testWidgets('the jump list shows only while focused with a query', (
    tester,
  ) async {
    await pumpHeader(tester, jump: jumpRows);
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsNothing);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsOneWidget);
    expect(find.text('Jump to dive'), findsOneWidget);
  });

  testWidgets('tapping a jump row opens that dive', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, jump: jumpRows, onOpenDive: (d) => opened = d);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dive-jump-d1')));
    await tester.pump();
    expect(opened?.id, 'd1');
  });

  // Review Focus 2: a mouse press outside a desktop field unfocuses it.
  testWidgets('a desktop mouse click on a jump row still opens it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    DiveSummary? opened;
    await pumpHeader(tester, jump: jumpRows, onOpenDive: (d) => opened = d);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('dive-jump-d1')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(opened?.id, 'd1');
  });

  testWidgets('the scope toggle shows only with panel axes', (tester) async {
    await pumpHeader(tester, filter: DiveFilterState(query: TextNode(['a'])));
    expect(find.byKey(const ValueKey('dive-search-scope')), findsNothing);
  });

  testWidgets('All dives suspends the axes; Within filters restores them', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
    );
    await tester.tap(find.text('All dives'));
    await tester.pumpAndSettle();
    expect(filterOf().axesSuspended, isTrue);
    expect(filterOf().minDepth, 30);
    await tester.tap(find.text('Within filters'));
    await tester.pumpAndSettle();
    expect(filterOf().axesSuspended, isFalse);
  });
```

- [ ] **Step 2: Run and watch them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`
Expected: FAIL, no jump rows and no toggle.

- [ ] **Step 3: Create the jump list**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest dives matching the typed query over the WHOLE log, ignoring
/// the list's other filters (#2773, the Search overlay's old job).
class DiveJumpList extends ConsumerWidget {
  const DiveJumpList({super.key, required this.query, required this.onOpen});

  final QueryNode query;
  final ValueChanged<DiveSummary> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dives =
        ref.watch(diveJumpResultsProvider(query)).value ??
        const <DiveSummary>[];
    if (dives.isEmpty) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    // Inside the field's tap region: on desktop a mouse press anywhere
    // else unfocuses the field, which would hide these rows before the
    // click on one of them landed.
    return TextFieldTapRegion(
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                context.l10n.diveLog_search_jumpTitle,
                style: theme.textTheme.labelMedium,
              ),
            ),
            for (final d in dives)
              ListTile(
                key: ValueKey('dive-jump-${d.id}'),
                dense: true,
                title: Text(
                  d.siteName ?? d.name ?? units.formatMonthDayWithYear(d.dateTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${units.formatMonthDayWithYear(d.dateTime)} · '
                  '${units.formatDepth(d.maxDepth)}',
                ),
                onTap: () => onOpen(d),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create the scope toggle**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Within filters / All dives (#2773): All dives keeps the filter axes but
/// runs only the typed search, so any dive can be found while filtered.
class DiveSearchScopeToggle extends ConsumerWidget {
  const DiveSearchScopeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(diveFilterProvider);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SegmentedButton<bool>(
        key: const ValueKey('dive-search-scope'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: false, label: Text(l10n.diveLog_search_scopeWithin)),
          ButtonSegment(value: true, label: Text(l10n.diveLog_search_scopeAll)),
        ],
        selected: {filter.axesSuspended},
        onSelectionChanged: (s) {
          final notifier = ref.read(diveFilterProvider.notifier);
          notifier.state = notifier.state.copyWith(axesSuspended: s.first);
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Add both to the header**

In `dive_search_header.dart`, import the two files and append to the outer `Column`'s `children` after the field `Padding`:

```dart
        if (_focus.hasFocus && _local != null)
          DiveJumpList(query: _local!, onOpen: widget.onOpenDive),
        if (panelAxes > 0) const DiveSearchScopeToggle(),
```

- [ ] **Step 6: Run the search tests**

Run: `flutter test test/features/dive_log/presentation/widgets/search`
Expected: PASS. If the macOS mouse test fails with the row gone, confirm the jump list is wrapped in `TextFieldTapRegion` (that is the fix, not a test change).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/search test/features/dive_log/presentation/widgets/search
git commit -m "feat(dive-log): jump to any dive and search all dives while filtered"
```

---

### Task 10: Chips row with Open in Insights, and the header in the dive list

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`build` about line 1082, `_buildTableModeScaffold` about line 1669, `_buildTableView` about line 1729, `_buildDiveList` about line 1904, `_buildActiveFiltersBar` about line 2114)
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart` (append)
- Test: `test/features/dive_log/presentation/widgets/dive_list_search_row_test.dart` (create)

**Interfaces:**
- Consumes: `activeDiveFilterChips`, `insightsFilterProvider`, `DiveFilterState.effective`, `_handleItemTap(DiveSummary)` in `DiveListContent`.
- Produces: the header owns the chips row (chips, Open in Insights, Clear all); `_buildActiveFiltersBar` is deleted.

- [ ] **Step 1: Append the failing Insights test to the header test**

This one needs a router. Add (imports: `package:go_router/go_router.dart`, `package:submersion/features/insights/presentation/providers/insights_filter_provider.dart`, `package:submersion/l10n/arb/app_localizations.dart`):

```dart
  testWidgets('Open in Insights hands over the effective search', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return DiveSearchHeader(onOpenDive: (_) {});
              },
            ),
          ),
        ),
        GoRoute(path: '/insights', builder: (_, _) => const Text('Insights page')),
      ],
    );
    addTearDown(router.dispose);
    final q = TextNode(['manta']);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveFilterProvider.overrideWith(
            (ref) => DiveFilterState(minDepth: 30, query: q, axesSuspended: true),
          ),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, _) async => const []),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveSearchInsightsKey));
    await tester.pumpAndSettle();
    expect(find.text('Insights page'), findsOneWidget);
    expect(container.read(insightsFilterProvider), DiveFilterState(query: q));
  });

  testWidgets('Clear all empties the search', (tester) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(filterOf(), const DiveFilterState());
  });
```

(`diveLog_filterChip_clearAll` reads "Clear all" in English; check `app_en.arb` and use its exact value.)

- [ ] **Step 2: Create the failing dive-list test (Review Focus 3)**

`test/features/dive_log/presentation/widgets/dive_list_search_row_test.dart`, modelled on `dive_list_content_query_chip_test.dart` (copy its `_MockPaginatedNotifier` and `buildContent`, add the two search overrides):

```dart
// buildContent(filter, dives) as in dive_list_content_query_chip_test.dart,
// with these extra overrides:
//   queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
//   diveJumpResultsProvider.overrideWith((ref, _) async => const []),
// and the summaries list taken from the `dives` parameter.

  testWidgets('the search row stays when nothing matches', (tester) async {
    await tester.pumpWidget(
      await buildContent(DiveFilterState(query: TextNode(['nomatch'])), const []),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
    expect(find.text('nomatch'), findsWidgets);
  });

  testWidgets('the row and chips sit above a filtered list', (tester) async {
    final dives = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    await tester.pumpWidget(
      await buildContent(const DiveFilterState(favoritesOnly: true), dives),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
    expect(find.byType(Chip), findsWidgets);
  });
```

- [ ] **Step 3: Run and watch them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart test/features/dive_log/presentation/widgets/dive_list_search_row_test.dart`
Expected: FAIL (no Insights button; no search row in the list).

- [ ] **Step 4: Add the chips row to the header**

Imports: `package:go_router/go_router.dart`, `active_filter_chips.dart`, `insights_filter_provider.dart`. Append to the outer `Column`'s `children` after the toggle line:

```dart
        if (filter.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: activeDiveFilterChips(
                        context,
                        ref,
                        diveFilterProvider,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  key: kDiveSearchInsightsKey,
                  onPressed: () {
                    // What applies, not what is set: Insights has no
                    // "All dives" toggle to show a suspension with.
                    ref.read(insightsFilterProvider.notifier).state =
                        filter.effective;
                    context.go('/insights');
                  },
                  child: Text(l10n.diveLog_search_openInsights),
                ),
                TextButton(
                  onPressed: () => ref.read(diveFilterProvider.notifier).state =
                      const DiveFilterState(),
                  child: Text(l10n.diveLog_filterChip_clearAll),
                ),
              ],
            ),
          ),
```

- [ ] **Step 5: Put the header in every dive-list layout**

In `dive_list_content.dart`:

1. Import `search/dive_search_header.dart`.
2. In `build`, list path: replace `final content = paginatedAsync.when(...);` 's use by wrapping it. Right after the `final content = paginatedAsync.when(...)` statement add:

```dart
          // The search row sits OUTSIDE the loading and empty states, so a
          // search that matches nothing never takes its own field away.
          final body = Column(
            children: [
              DiveSearchHeader(onOpenDive: _handleItemTap),
              Expanded(child: content),
            ],
          );
```

   Then use `body` instead of `content` in both places below it (`Expanded(child: content)` in the master-pane `Column`, and `body: content` in the `Scaffold`).
3. In `_buildTableModeScaffold`, change `Expanded(child: content),` to:

```dart
              DiveSearchHeader(onOpenDive: _handleItemTap),
              Expanded(child: content),
```

4. In `_buildTableView`, delete the line `if (filter.hasActiveFilters) _buildActiveFiltersBar(context),`.
5. In `_buildDiveList`, delete the line `if (hasActiveFilters) _buildActiveFiltersBar(context),`. If `hasActiveFilters` becomes unused there, leave the parameter (it is passed by `build`) unless `flutter analyze` flags it; then remove the parameter and its argument.
6. Delete the whole `_buildActiveFiltersBar` method.

- [ ] **Step 6: Run the dive-list widget tests**

Run: `flutter test test/features/dive_log/presentation`
Expected: the two new files PASS. Older tests that looked for the old filter bar's "Clear all" `TextButton` or chips still find them (now inside the header). If a test fails because the list body now starts with the search row (for example a test measuring the first row's offset, such as `dive_list_grouping_paused_test.dart`), fix the test's expectation to account for the header only when the header is visible in that test; do not hide the header.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "feat(dive-log): show the search row above every dive list layout"
```

---

### Task 11: One search icon in every app bar; retire the Search overlay and Filter icon

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_search_action.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildAppBar` search + filter buttons, `_buildCompactAppBar` search + filter buttons)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (table `appBarActions` search + filter buttons; delete `DiveSearchDelegate`, about lines 537 to 705)
- Delete: `test/features/dive_log/presentation/pages/dive_search_delegate_test.dart` (find its exact path with `git ls-files | grep dive_search_delegate_test`)
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_action_test.dart`

**Interfaces:**
- Produces: `DiveSearchAction({super.key, this.iconSize})`, an `IconButton` with key `ValueKey('dive-search-action')`, tooltip `diveLog_listPage_tooltip_searchDives`, icon `Icons.search` in a `Badge` visible while `hasActiveFilters`. Pressing it: when the row is visible and nothing is filtered, closes the row; otherwise opens the row and requests focus.

- [ ] **Step 1: Write the failing action tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_action.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, DiveFilterState filter) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [...base, diveFilterProvider.overrideWith((ref) => filter)],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const DiveSearchAction();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens the row and asks for focus', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(const ValueKey('dive-search-action')));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isTrue);
  });

  testWidgets('a second press on an idle open row closes it', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(const ValueKey('dive-search-action')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dive-search-action')));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isFalse);
  });

  testWidgets('badged while anything is filtered', (tester) async {
    await pump(tester, const DiveFilterState(minDepth: 30));
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(find.byTooltip('Search dives'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_action_test.dart`
Expected: compile error, file missing.

- [ ] **Step 3: Create the action**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dives app bar's one search entry (#2773), shared by the phone,
/// desktop and table layouts. It replaces the old Search overlay and the
/// Filter icon; the badge is the Filter icon's old job.
class DiveSearchAction extends ConsumerWidget {
  const DiveSearchAction({super.key, this.iconSize});

  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(diveFilterProvider).hasActiveFilters;
    return IconButton(
      key: const ValueKey('dive-search-action'),
      tooltip: context.l10n.diveLog_listPage_tooltip_searchDives,
      icon: Badge(
        isLabelVisible: filtered,
        child: Icon(Icons.search, size: iconSize),
      ),
      onPressed: () {
        final open = ref.read(diveSearchBarOpenProvider.notifier);
        if (ref.read(diveSearchBarVisibleProvider) && !filtered) {
          open.state = false;
          return;
        }
        open.state = true;
        ref.read(diveSearchFocusPendingProvider.notifier).state = true;
      },
    );
  }
}
```

- [ ] **Step 4: Swap it into the three app bars**

1. `dive_list_content.dart` `_buildAppBar`: replace the two `IconButton`s (the one with `Icons.search` calling `showSearch(...)` and the one with the `Badge` around `Icons.filter_list` opening `DiveFilterSheet`) with `const DiveSearchAction(),`.
2. `_buildCompactAppBar`: replace the same two buttons with `const DiveSearchAction(iconSize: 20),`.
3. `dive_list_page.dart` table `appBarActions`: replace the same two buttons with `const DiveSearchAction(iconSize: 20),`.
4. Import `search/dive_search_action.dart` in both files.
5. Delete the `DiveSearchDelegate` class from `dive_list_page.dart` (from its doc comment `/// Search delegate for diving through dive logs` to its closing brace).
6. Run `flutter analyze lib/features/dive_log` and remove imports it reports unused (for example `dive_list_page.dart` in `dive_list_content.dart`, or `dive_filter_sheet.dart`, if nothing else uses them; `diveSearchProvider` and `searchDiveSummaries` STAY, the pre-dive link picker uses them).

- [ ] **Step 5: Update the tests that used the old icons**

```bash
git rm $(git ls-files | grep dive_search_delegate_test)
grep -rln "DiveSearchDelegate\|Icons.filter_list\|tooltip_filterDives\|Filter dives\|'Search dives'" test/features/dive_log test/features/insights test/core
```

For each hit in a dive-list test:
- a tap on `Icons.filter_list` (or the "Filter dives" tooltip) that then expects the Filter sheet: tap `ValueKey('dive-search-action')`, `pumpAndSettle`, tap `kDiveSearchRefineKey`, then keep the sheet expectations.
- a tap on `Icons.search` expecting the overlay: rewrite to enter text in `kDiveSearchFieldKey` and expect the filtered list (or delete the test when it only exercised the overlay, which `dive_search_delegate_test.dart` covered).
- a badge assertion on the filter icon: assert on `DiveSearchAction`'s `Badge`.
Insights tests (`insights_filter_action_test.dart`) keep `Icons.filter_list`: Insights still has its own filter icon; leave them.

- [ ] **Step 6: Run the dive log and insights tests**

Run: `flutter test test/features/dive_log test/features/insights test/features/connections`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): one search icon replaces the search overlay and filter icon"
```

(Stage explicit paths: `-A` limited to these two directories.)

---

### Task 12: Cmd/Ctrl+F opens and focuses the search row

**Files:**
- Modify: `lib/core/accessibility/app_shortcuts.dart` (the `keyF` binding, about line 272)
- Test: `test/core/accessibility/app_shortcuts_navigation_test.dart` (test "search shortcut pushes a poppable sub-page")

**Interfaces:**
- Consumes: `diveSearchBarOpenProvider`, `diveSearchFocusPendingProvider`.
- Produces: Ctrl/Cmd+F writes both providers to true, then `context.go('/dives')` unless the current path already is `/dives`. The catalog label "Search dives" is unchanged, so `shortcut_display.dart` needs no edit.

- [ ] **Step 1: Rewrite the test**

In `app_shortcuts_navigation_test.dart`: remove the `search` child route from the host router; make the host read the container (wrap the `CallbackShortcuts` in a `Builder` that stores `ProviderScope.containerOf(context)` into a `late ProviderContainer container;` declared in `main`). Replace the search test with:

```dart
    testWidgets('search shortcut opens and focuses the dive search row', (
      tester,
    ) async {
      final router = await pumpShortcutHost(tester);
      await pressControl(tester, LogicalKeyboardKey.digit2);
      expect(locationOf(router), '/sites');

      await pressControl(tester, LogicalKeyboardKey.keyF);

      expect(locationOf(router), '/dives');
      expect(container.read(diveSearchBarOpenProvider), isTrue);
      expect(container.read(diveSearchFocusPendingProvider), isTrue);
    });

    testWidgets('on the dive list it does not navigate', (tester) async {
      final router = await pumpShortcutHost(tester);
      await pressControl(tester, LogicalKeyboardKey.keyF);
      expect(locationOf(router), '/dives');
      expect(router.routerDelegate.canPop(), isFalse);
    });
```

Note `/sites` must also host the bindings for the first test to reach Ctrl+F there: give the `/sites` route the same `CallbackShortcuts(bindings: AppShortcuts.globalBindings(context), child: const Focus(autofocus: true, child: Text('Sites')))` builder.

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test test/core/accessibility/app_shortcuts_navigation_test.dart`
Expected: FAIL, the shortcut pushes `/dives/search`.

- [ ] **Step 3: Implement**

Import `package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart` and replace the `keyF` binding with:

```dart
      // Search: the dive list's search row (#2773), opened with the caret
      // in it. From another section this switches to Dives, like digit1.
      platformShortcut(LogicalKeyboardKey.keyF): () {
        final container = ProviderScope.containerOf(context, listen: false);
        container.read(diveSearchBarOpenProvider.notifier).state = true;
        container.read(diveSearchFocusPendingProvider.notifier).state = true;
        final path = GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.uri.path;
        if (path != '/dives') context.go('/dives');
      },
```

- [ ] **Step 4: Run the accessibility tests**

Run: `flutter test test/core/accessibility test/accessibility`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/accessibility/app_shortcuts.dart test/core/accessibility/app_shortcuts_navigation_test.dart
git commit -m "feat(accessibility): Cmd/Ctrl+F opens the dive search row"
```

---

### Task 13: Verify, screenshot and open the PR

**Files:** none new.

- [ ] **Step 1: Static checks**

```bash
dart format --set-exit-if-changed .
flutter analyze
```

Expected: no changes; no issues (infos are fatal in CI).

- [ ] **Step 2: Architecture guards, then the full suite once**

```bash
flutter test test/architecture
scripts/run_all_tests.sh
```

Expected: PASS. (Check `df -h /Volumes/fltmp` first if the run stalls; a full RAM-disk TMPDIR hangs `flutter test` silently.)

- [ ] **Step 3: Grep for leftovers**

```bash
grep -rn "DiveSearchDelegate\|showSearch(context" lib test
perl -CSD -ne 'print "$ARGV:$.: $_" if /\x{2014}/; close ARGV if eof' $(git diff --name-only origin/main...HEAD)
```

Expected: both empty.

- [ ] **Step 4: Screenshots**

Capture before (on `origin/main`) and after, at phone width (about 390 px) and desktop width (about 1280 px), light and dark: the Dives app bar idle; the row open and empty; typing `"blue hole" depth > 30m` with the jump list; All dives selected with dimmed chips; an invalid query's error line; the Undo snackbar after closing. Save the image files outside the repo and hand them to the maintainer (gh cannot upload images).

- [ ] **Step 5: Push and open the PR**

Push the branch, then open a PR to `main` titled `feat(dive-log): one search bar for the Dives list (1 of 4)` whose body has a Summary (what changed, what retired: the Search overlay and the Filter icon; Explore and Advanced Search still present until PRs 2 and 3), a Test plan, the Screenshots section listing each image, and `Refs #2773`. No attribution lines.
