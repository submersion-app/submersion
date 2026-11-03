# Plain-word dive search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A diver can type what they remember about a dive (`ressel in october 2018 with mike`, `shearwater nitrox`) and find it, with no syntax, on every platform.

**Architecture:** Two mechanisms. Single words stay additive: new `textSearchSql` entries and `TextSearchExpansion`s on the dive entity add meanings alongside the text match, so no result is lost. Phrases and filler words live in the parser, behind one optional `QueryEntity.plainWords` member that only the dive entity sets; a date phrase becomes the same `ConditionNode` that `date in ...` produces.

**Tech Stack:** Flutter, Dart, Riverpod, Drift over SQLite, `intl`.

**Spec:** `docs/design/specs/2026-11-02-dive-search-plain-words-design.md`

## Global Constraints

- No schema change, no migration, no sync change.
- `flutter analyze`, `dart format .` and the affected tests before each commit. `test/architecture/` and `test/shared/` after adding any file under `lib/`.
- Paths in tests go through `p.join`. A test that changes process-wide state restores it in `addTearDown`.
- No file over 800 lines. `query_parser.dart` is 741 lines, so phrase reading goes in its own file.
- New `textSearchSql` tables must be declared in `textSearchTables`.
- String binds never compare against a `CAST(... AS INTEGER)` expression: see the comment on `kDiveNumberTextSearch`. A `{values}` placeholder may appear once per expansion, because the compiler adds the binds once.
- Every new user-visible string goes in all 11 ARB files, then `flutter gen-l10n`; run `test/l10n` before pushing ARB edits.
- No em-dashes anywhere. No mention of any AI tool in commits.
- Stage explicit paths, never `git add -A`.

## Review Focus

1. **Half-typed text.** `ressel in`, `last`, `since`, `between 2018 and`, `oct`: each keystroke must parse as plain words, with no error flicker. Test in Task 3.
2. **Negating a word on a dive with empty columns.** `not shearwater` must return a dive with no gear, no trip and NULL columns. `_text` joins alternatives with OR, and `NOT (NULL OR 0)` is NULL, so check this before trusting it. Test in Task 5; if it fails, wrap the alternatives so the term compiles to 0 or 1.
3. **Capitals.** `October 2018`, `LAST YEAR`, `Nitrox`, `SALT WATER` read the same as lower case. Tests in Tasks 3 and 6.
4. **Other number scripts.** `٢٠١٨` is a year word, as it is a dive number today. Test in Task 6.
5. **A filler word that is the whole search, and one that is a real term.** `the` alone still searches, and `with mike` drops only `with`. `-with` and `"with"` still search for it. Test in Task 3.

---

### Task 1: Two-period date ranges in the grammar

**Files:**
- Modify: `lib/core/query/syntax/date_grammar.dart`
- Test: `test/core/query/syntax/date_grammar_forms_test.dart`

**Interfaces:**
- Produces: `parseDateText` also reads `<period> to <period>` and `between <period> and <period>`, returning the first period's start and the second period's end.

- [ ] **Step 1: Write the failing tests**

```dart
test('two periods span the first start to the second end', () {
  expect(parseDateText('2018 to 2020', now: now), (
    start: DateTime(2018, 1, 1),
    end: DateTime(2020, 12, 31),
  ));
  expect(parseDateText('between 2018 and 2020', now: now), (
    start: DateTime(2018, 1, 1),
    end: DateTime(2020, 12, 31),
  ));
  expect(parseDateText('march 2018 to june 2019', now: now), (
    start: DateTime(2018, 3, 1),
    end: DateTime(2019, 6, 30),
  ));
});

test('reversed or open-ended periods are not a range', () {
  expect(parseDateText('2020 to 2018', now: now), isNull);
  expect(parseDateText('since 2018 to 2020', now: now), isNull);
  expect(parseDateText('2018 to', now: now), isNull);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/query/syntax/date_grammar_forms_test.dart`
Expected: FAIL on the new tests.

- [ ] **Step 3: Implement in `parseDateText`**

Add `_periodRange = RegExp(r'^(.+)\s+to\s+(.+)$')` and `_between = RegExp(r'^between\s+(.+)\s+and\s+(.+)$')`. Check them straight after `_isoRange`, before `_since`, so `since 2018 to 2020` is refused rather than read as `since`. Both sides must parse with non-null `start` and `end`, and the second period's end must not be before the first period's start. Otherwise return null. Keep `_isoRange` as it is.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/core/query/syntax/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/query/syntax/date_grammar.dart test/core/query/syntax/date_grammar_forms_test.dart
git commit -m "feat(query): read two periods as a date range"
```

### Task 2: `in` and `between` after a word that is not an operand

**Files:**
- Modify: `lib/core/query/syntax/query_parser.dart` (`_primary`, `_operatorFollows`)
- Test: `test/core/query/syntax/query_parser_test.dart`

**Interfaces:**
- Produces: `in` after a word is an operator only when `[` follows it, or the word resolves to a date field. `between` after a word is an operator only when the word resolves to a field. Symbol operators are unchanged. Applies to every entity.

- [ ] **Step 1: Write the failing tests**

```dart
test('in after a word that is no date field reads as plain words', () {
  expect(ok(metric(), 'ressel in 2018'), isA<AndNode>());
  expect(ok(metric(), 'buddy in 2018'), isA<AndNode>());
});

test('in stays an operator for a date field or a list', () {
  expect(ok(metric(), 'date in 2025'), isA<ConditionNode>());
  expect(ok(metric(), 'depth in [10, 20]'), isA<ConditionNode>());
});

test('a mistyped field before a list still suggests the field', () {
  expect(bad(metric(), 'dpeth in [10, 20]').error.suggestions, contains('depth'));
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/query/syntax/query_parser_test.dart`
Expected: FAIL on the first test. Note any existing test that pins the old error for a non-field word; update those to the new behaviour only.

- [ ] **Step 3: Implement**

Replace `_operatorFollows(after)` in `_primary` with `_operatorFollows(t, after)`. For `in`, read `_tokens[_pos + 2]` for the `[` and otherwise use `resolvePath` to test for a date field. For `between`, require `resolvePath(...).error == null`. Mirror `_presenceFollows`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/core/query/ test/features/global_search/ test/features/query/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/query/syntax/query_parser.dart test/core/query/syntax/query_parser_test.dart
git commit -m "fix(query): read in after a non-field word as plain words"
```

### Task 3: Date phrases, filler words and label phrases in the parser

**Files:**
- Modify: `lib/core/query/registry/query_entity.dart`
- Modify: `lib/core/query/syntax/query_parser.dart`
- Create: `lib/core/query/syntax/query_plain_words.dart`
- Test: `test/core/query/syntax/query_plain_words_test.dart`

**Interfaces:**
- Produces, in `query_entity.dart`:

```dart
@immutable
class PlainWordReading {
  /// The date field a date phrase filters on.
  final String dateField;

  /// Whether these lower-cased words, in order, are one term (`salt water`).
  final bool Function(List<String> words) isPhrase;

  const PlainWordReading({required this.dateField, required this.isPhrase});
}
```

  `QueryEntity` gains `final PlainWordReading? plainWords;`, default null.
- Produces, in `query_plain_words.dart`:
  - `({DateRange range, int length})? readDatePhrase(List<Token> tokens, int start, DateTime now)`
  - `int? readLabelPhrase(List<Token> tokens, int start, bool Function(List<String>) isPhrase)`
  - `bool isFillerWord(String word, String? language)`
- Produces: `ParseContext` gains `final String? language;`, default null (English only).

- [ ] **Step 1: Write the failing tests**

Build a `plainDives` entity from `fixtureDives.fields` and `.relations` with `plainWords: PlainWordReading(dateField: 'date', isPhrase: (w) => w.join(' ') == 'salt water')`, and parse with `QueryParser(fixtureRegistry, plainDives, context)`.

```dart
QueryNode read(String text) => (parser.parse(text) as ParseOk).node!;
ConditionNode range(int y, int m) => ...; // date in the month

test('month and year is one date condition', () {
  expect(read('ressel october 2018'), AndNode([TextNode(['ressel']), range(2018, 10)]));
  expect(read('October 2018'), range(2018, 10));
  expect(read('OCT 2018'), range(2018, 10));
});
test('a lone year stays a word; after in or during it is a date', () {
  expect(read('ressel 2018'), AndNode([TextNode(['ressel']), TextNode(['2018'])]));
  expect(read('ressel in 2018'), AndNode([TextNode(['ressel']), year(2018)]));
  expect(read('during 2018'), year(2018));
});
test('relative, open-ended and iso forms', () {
  expect(read('last year'), year(now.year - 1));
  expect(read('since 2020'), isA<ConditionNode>().having((c) => c.op, 'op', QueryOp.gte));
  expect(read('before 2020'), isA<ConditionNode>().having((c) => c.op, 'op', QueryOp.lte));
  expect(read('2018-10'), range(2018, 10));
  expect(read('2018 to 2020'), isA<ConditionNode>());
});
test('filler words drop only as bare terms beside another term', () {
  expect(read('ressel with mike'), AndNode([TextNode(['ressel']), TextNode(['mike'])]));
  expect(read('the'), TextNode(['the']));
  expect(read('with the'), AndNode([TextNode(['with']), TextNode(['the'])]));
  expect(read('"with" mike'), AndNode([TextNode(['with']), TextNode(['mike'])]));
  expect(read('-with mike'), AndNode([NotNode(TextNode(['with'])), TextNode(['mike'])]));
});
test('a filler in the app language drops; a foreign one does not', () {
  expect(readIn('fr', 'ressel avec mike'), AndNode([TextNode(['ressel']), TextNode(['mike'])]));
  expect(read('ressel avec mike'), hasLength3Terms);
});
test('quoted phrases stay text; a negated phrase is a date', () {
  expect(read('"last year"'), TextNode(['last', 'year']));
  expect(read('not last year'), NotNode(year(now.year - 1)));
});
test('a label phrase is one term', () {
  expect(read('salt water'), TextNode(['salt', 'water']));
  expect(read('SALT WATER'), TextNode(['SALT', 'WATER']));
});
test('half-typed text never fails', () {
  for (final t in ['ressel in', 'last', 'since', 'between 2018 and', 'oct', 'in']) {
    expect(parser.parse(t), isA<ParseOk>(), reason: t);
  }
});
test('an entity without plainWords reads the same text as words', () {
  final node = (QueryParser(fixtureRegistry, fixtureDives, context).parse('october 2018') as ParseOk).node;
  expect(node, AndNode([TextNode(['october']), TextNode(['2018'])]));
});
test('each phrase survives a print and parse', () {
  for (final t in ['october 2018', 'last year', 'since 2020', '2018 to 2020']) {
    final node = read(t);
    expect(read(printer.print(node)), node, reason: t);
  }
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/query/syntax/query_plain_words_test.dart`
Expected: FAIL to compile, `PlainWordReading` not found.

- [ ] **Step 3: Implement `query_plain_words.dart`**

`readDatePhrase`: try windows of 6 down to 1 tokens from `start`, stopping at the first token that is not `TokenKind.word` or `TokenKind.number`. Join the text with a space and call `parseDateText`. A one-token window holding a bare year is not a phrase. If the token at `start` is `in` or `during`, try `start + 1` with the bare year allowed, and add one to the length.

`readLabelPhrase`: windows of 4 down to 2, word tokens only, lower-cased, returning the length.

`isFillerWord`: English set `with, in, at, on, from, the, of, near, during`, plus a const map keyed on language code:

| Language | Words |
| --- | --- |
| de | mit, im, am, an, auf, von, der, die, das |
| es | con, en, de, del, el, la |
| fr | avec, en, au, de, du, le, la |
| it | con, in, al, di, del, il, la |
| nl | met, op, bij, van, de, het |
| pt | com, em, no, na, de, do, da |

Hungarian, Arabic, Hebrew and Chinese have no entry.

- [ ] **Step 4: Wire the parser**

Add `plainWords` to `QueryEntity`, and `language` to `ParseContext`.

In `_primary`, ahead of the number and word branches and only when `_entity.plainWords` is set and `t` is a word or number token that is not already an operand (`!_operatorFollows(t, after) && !_presenceFollows(t)`): try `readDatePhrase`, then `readLabelPhrase`. A date phrase returns through a new `_dateRangeNode(FieldPath, DateRange)` that shares `_dateCondition`'s branching: a range gives `inList`, one bound gives `gte` or `lte`, a single day gives `eq`.

In `_and`, when `_entity.plainWords != null`, note the indices of parts that were one bare word token (`_pos` advanced by one, token kind word, `part is TextNode`) and `isFillerWord(token.text, context.language)`. Drop them after the loop if any other part remains.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/core/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/query/registry/query_entity.dart lib/core/query/syntax/query_parser.dart lib/core/query/syntax/query_plain_words.dart test/core/query/syntax/query_plain_words_test.dart
git commit -m "feat(query): read date phrases and filler words in plain text"
```

### Task 4: Pass the app language to the parser

**Files:**
- Modify: `lib/core/query/presentation/query_editor_context.dart`
- Modify: `lib/features/query/presentation/entity_query_editor.dart`
- Modify: `lib/features/query/presentation/providers/query_unit_prefs_provider.dart`
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Modify: `lib/features/global_search/presentation/global_search_text_reader.dart`
- Modify: `lib/features/global_search/presentation/providers/global_search_providers.dart`
- Test: `test/features/query/presentation/providers/query_language_provider_test.dart`

**Interfaces:**
- Consumes: `ParseContext.language` (Task 3).
- Produces: `queryLanguageProvider`, a `Provider<String>` of the language code of the app's locale (`localeProvider`, with `system` resolved through `exploreDeviceLocaleProvider`). `QueryEditorContext` gains `final String? language`, passed to its parser and kept by `copyWith`.

- [ ] **Step 1: Write the failing test**

```dart
test('reads the set language, and the device language for system', () {
  expect(languageWith(locale: 'fr'), 'fr');
  expect(languageWith(locale: 'pt-BR'), 'pt');
  expect(languageWith(locale: 'system', device: const Locale('de')), 'de');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/query/presentation/providers/query_language_provider_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Add the provider using `exploreLocaleTag`, taking the part before `-` or `_`. Set `language` in `watchQueryEditorContext`, `readQueryEditorContext` and `_editorContext`, using `ref.watch` or `ref.read` to match their other fields. Pass it in `GlobalSearchTextReader.check` and `globalSearchProvider`. Leave the agent query tool on the default, since its callers write English.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/query/ test/features/global_search/ test/features/dive_log/presentation/widgets/search/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/query/presentation/query_editor_context.dart lib/features/query/presentation/entity_query_editor.dart lib/features/query/presentation/providers/query_unit_prefs_provider.dart lib/features/dive_log/presentation/widgets/search/dive_search_header.dart lib/features/global_search/presentation/global_search_text_reader.dart lib/features/global_search/presentation/providers/global_search_providers.dart test/features/query/presentation/providers/query_language_provider_test.dart
git commit -m "feat(query): pass the app language to the query parser"
```

### Task 5: Search the records attached to a dive

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart`
- Create: `lib/features/marine_life/query/sighting_text_search.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart`

**Interfaces:**
- Consumes: `builtInSpeciesIdsMatching` from `species_text_search.dart`.
- Produces: `kSightingTranslatedTextSearch`, a `TextSearchExpansion` over `sightings.species_id`.

- [ ] **Step 1: Write the failing tests**

Seed through the repository test helpers used in `dive_repository_weekday_filter_test.dart`. Add a helper `Future<List<String>> found(String text)` that parses with `QueryParser(appQueryRegistry, diveQueryEntity, ...)` and returns ids from `getDiveSummaries(filter: DiveFilterState(query: node))`.

```dart
test('a gear brand, model or name finds the dive', ...);        // 'apeks', 'mtx', 'my reg'
test('tank-linked gear and tank regulators count', ...);
test('a trip name, location, resort or liveaboard finds the dive', ...);
test('a sighted species finds the dive, in any language', ...); // 'turtle', a translated name
test('a course name finds the dive', ...);
test('a computer name, maker or model finds the dive', ...);    // 'shearwater', 'perdix'
test('not shearwater keeps a dive with nothing attached', ...); // Review Focus 2
test('a write to an added table refreshes an active search', ...);
```

The last test uses `getDiveSummaries` through the list notifier or the change tick the existing `watchDivesChanges` tests use, writing only to `sightings`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart`
Expected: FAIL, no dive found.

- [ ] **Step 3: Implement**

Append to `textSearchSql` in the shape of the existing templates, with fresh aliases:

- Gear: `EXISTS (SELECT 1 FROM equipment tq WHERE <kDiveGearJoinSql with {to}=tq, {from}={r}> AND (name OR brand OR model LIKE))`. Build it with `.replaceAll`, so the list stops being `const`.
- Trip: `EXISTS (SELECT 1 FROM trips ttr WHERE ttr.id = {r}.trip_id AND (name, location, resort_name, liveaboard_name))`.
- Species: `EXISTS (SELECT 1 FROM sightings tsg JOIN species tsp ON tsp.id = tsg.species_id WHERE tsg.dive_id = {r}.id AND (common_name, scientific_name))`.
- Course: `EXISTS (SELECT 1 FROM dive_courses tdc JOIN courses tcr ON tcr.id = tdc.course_id WHERE tdc.dive_id = {r}.id AND (name, location))`.
- Computer: `unicode_lower({r}.dive_computer_model) LIKE ...` and `EXISTS (SELECT 1 FROM dive_computers tdco WHERE tdco.id = {r}.computer_id AND (name, manufacturer, model))`.

Add `equipment, dive_equipment, dive_tanks, trips, sightings, species, dive_courses, courses, dive_computers` to `textSearchTables`, plus whatever `tankRegulatorIdsOfDiveSql` reads. Add `kSightingTranslatedTextSearch` to `textSearchExpansions`. If Review Focus 2 fails, fix it in `QueryCompiler._text`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart test/features/query/ test/features/global_search/ test/core/query/`
Expected: PASS. `query_registry_guards_test.dart` proves the declared tables match.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/query/dive_query_entity.dart lib/features/marine_life/query/sighting_text_search.dart test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart
git commit -m "feat(dive-log): search gear, trips, species, courses and computers"
```

### Task 6: Words that stand for a value

**Files:**
- Create: `lib/features/dive_log/query/dive_word_meanings.dart`
- Modify: `lib/features/dive_log/query/dive_query_entity.dart`
- Modify: `lib/features/dive_log/query/dive_number_query.dart` (share the digit folding)
- Test: `test/features/dive_log/query/dive_word_meanings_test.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart`

**Interfaces:**
- Consumes: `PlainWordReading` (Task 3), `TextSearchExpansion`.
- Produces: `kDiveWordExpansions` (`List<TextSearchExpansion>`), and `final kDivePlainWords = PlainWordReading(dateField: 'date', isPhrase: diveLabelPhrase)`, set on `diveQueryEntity.plainWords`. The word lookups are pure and public for tests: `diveYearTerms`, `diveMonthTerms`, `diveWeekdayTerms`, `diveModeTerms`, `diveEntryTerms`, `diveWaterTerms`, `diveGasTerms`, `diveEanTerms`, each `Iterable<String> Function(String term)`.

- [ ] **Step 1: Write the failing lookup tests**

```dart
test('years', () {
  expect(diveYearTerms('2018'), ['2018']);
  expect(diveYearTerms('٢٠١٨'), ['2018']);
  expect(diveYearTerms('1899'), isEmpty);
  expect(diveYearTerms('500'), isEmpty);
});
test('months use the full name, in any language', () {
  expect(diveMonthTerms('october'), ['10']);
  expect(diveMonthTerms('OCTOBER'), ['10']);
  expect(diveMonthTerms('octobre'), ['10']);
  expect(diveMonthTerms('oktober'), ['10']);
  expect(diveMonthTerms('oct'), isEmpty);
  expect(diveMonthTerms('jan'), isEmpty);
});
test('weekdays use sqlite numbering', () {
  expect(diveWeekdayTerms('sunday'), ['0']);
  expect(diveWeekdayTerms('saturday'), ['6']);
  expect(diveWeekdayTerms('sat'), isEmpty);
});
test('settings match whole labels and the listed words', () {
  expect(diveModeTerms('rebreather'), unorderedEquals(['ccr', 'scr']));
  expect(diveModeTerms('open circuit'), ['oc']);
  expect(diveModeTerms('open'), isEmpty);
  expect(diveEntryTerms('shore'), ['shore']);
  expect(diveEntryTerms('back roll'), ['backRoll']);
  expect(diveEntryTerms('other'), isEmpty);
  expect(diveWaterTerms('saltwater'), ['salt']);
  expect(diveWaterTerms('salt water'), ['salt']);
  expect(diveWaterTerms('water'), isEmpty);
});
test('gas words', () {
  expect(diveGasTerms('nitrox'), ['nitrox']);
  expect(diveGasTerms('Trimix'), ['trimix']);
  expect(diveEanTerms('ean32'), ['32']);
  expect(diveEanTerms('ean'), isEmpty);
});
test('a multi-word label is a phrase', () {
  expect(diveLabelPhrase(['salt', 'water']), isTrue);
  expect(diveLabelPhrase(['back', 'roll']), isTrue);
  expect(diveLabelPhrase(['open', 'water']), isFalse);
});
```

- [ ] **Step 2: Write the failing database tests**

```dart
test('the four searches from the issue', () async {
  expect(await found('ressel october 2018'), [ressel2018Oct.id]);
  expect(await found('ressel in 2018'), unorderedEquals([ressel2018Oct.id, ressel2018Mar.id]));
  expect(await found('france october 2018'), [france.id]);
  expect(await found('ressel with mike'), [resselWithMike.id]);
});
test('a lone year also keeps notes and the dive number', ...);
test('month, weekday, mode, entry, water, gas and favourite each find a dive', ...);
test('entry follows the site when the dive has none', ...);
test('water type follows the site when the dive has none', ...);
test('trimix skips an air dive; air skips 21/35; ean32 skips 32/10', ...);
test('a month name that is also a buddy finds both', ...);
test('favorite in 2018 finds favourites of that year', ...);
test('not shore keeps a dive with no entry method', ...);
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/dive_log/query/dive_word_meanings_test.dart test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart`
Expected: FAIL to compile, then FAIL on no dive found.

- [ ] **Step 4: Implement `dive_word_meanings.dart`**

Maps are top-level `final`, so they build lazily once. Month and weekday names come from `dateTimeSymbolMap()` (`MONTHS`, `STANDALONEMONTHS`, `WEEKDAYS`, `STANDALONEWEEKDAYS`) for each `AppLocalizations.supportedLocales` language code. Labels come from `lookupAppLocalizations(locale).enum_diveMode_*`, `.enum_entryMethod_*`, `.enum_waterType_*`, lower-cased, leaving out `enum_entryMethod_other`. Aliases are in the spec's table, plus `jetty` and `dock`. Move `_asciiDigits` from `dive_number_query.dart` to a shared public `asciiDigits` there.

Expansions, one `{values}` each. Bind strings; do not cast:

| Word | SQL |
| --- | --- |
| Year | `strftime('%Y', {r}.dive_date_time / 1000, 'unixepoch') IN ({values})` |
| Month | `strftime('%m', ...)`, values zero-padded |
| Weekday | `strftime('%w', ...)` |
| Mode | `{r}.dive_mode IN ({values})` |
| Entry | `<_effectiveEntryMethod> IN ({values})` |
| Exit | `{r}.exit_method IN ({values})` |
| Water | `<_effectiveWaterType> IN ({values})` |
| Favourite | `{r}.is_favorite IN ({values})`, value `1` |
| Gas | `EXISTS (SELECT 1 FROM dive_tanks tgm WHERE tgm.dive_id = {r}.id AND CASE WHEN tgm.he_percent > 0 THEN 'trimix' WHEN tgm.o2_percent > 22 THEN 'nitrox' WHEN tgm.o2_percent >= 20 THEN 'air' END IN ({values}))` |
| eanNN | `EXISTS (SELECT 1 FROM dive_tanks tge WHERE tge.dive_id = {r}.id AND tge.he_percent = 0 AND printf('%d', ROUND(tge.o2_percent)) IN ({values}))` |

The gas `CASE` mirrors `GasMix.isTrimix`, `isNitrox` and `isAir`. Make the `_effective*` strings reachable by passing them in as arguments to a `diveWordExpansions(entry:, water:)` builder, called from `dive_query_entity.dart`. Set `plainWords: kDivePlainWords` and add the expansions there.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/features/dive_log/ test/features/query/ test/features/global_search/ test/core/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/query/dive_word_meanings.dart lib/features/dive_log/query/dive_query_entity.dart lib/features/dive_log/query/dive_number_query.dart test/features/dive_log/query/dive_word_meanings_test.dart test/features/dive_log/data/repositories/dive_repository_plain_word_search_test.dart
git commit -m "feat(dive-log): read dates, gas and dive settings in plain words"
```

### Task 7: Marked date chips

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_date_chip_label.dart`
- Modify: `lib/features/dive_log/presentation/widgets/active_filter_chips.dart`
- Modify: `lib/features/query/presentation/dive_query_chips.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_date_chip_label_test.dart`
- Test: `test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`

**Interfaces:**
- Consumes: `topLevelConjuncts`, `diveLog_filterChip_dateRange`, `_from`, `_until`, `UnitFormatter.formatMonthDayWithYear`.
- Produces: `String? diveDateChipLabel(QueryNode node, {required AppLocalizations l10n, required UnitFormatter units})`, null for anything but a chip-table condition on the `date` field. `_chip` gains `bool isDate = false`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a whole year', () => expect(label(inList(2018, 1, 1, 2018, 12, 31)), '2018'));
test('a whole month', () => expect(label(inList(2018, 10, 1, 2018, 10, 31)), 'October 2018'));
test('a month in the diver language', () => expect(labelIn('fr', month(2018, 10)), 'octobre 2018'));
test('a single day', () => expect(label(eq(2018, 10, 14)), units.formatMonthDayWithYear(DateTime(2018, 10, 14))));
test('any other range uses the range wording', ...);
test('gte and lte use the from and until wording', ...);
test('strict, negated and other fields stay null', () {
  expect(label(ConditionNode(FieldPath(['date']), QueryOp.gt, DateValue(d))), isNull);
  expect(label(NotNode(month(2018, 10))), isNull);
  expect(label(TextNode(['2018'])), isNull);
  expect(label(ConditionNode(FieldPath(['year']), QueryOp.eq, NumberValue(2018, null))), isNull);
});
```

In `active_filter_chips_test.dart`:

```dart
testWidgets('a date condition shows a calendar icon and removes alone', ...);
testWidgets('a word chip has no calendar icon', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_date_chip_label_test.dart test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Whole month uses `DateFormat.yMMMM(l10n.localeName)`. In `activeDiveFilterChips`, walk `topLevelConjuncts(filter.query)` by index beside `queryLabels`, showing `diveDateChipLabel(...) ?? queryLabels[i]` and `isDate` when the label is not null. Removal stays `removeDiveQueryChip(filter, i)`.

`_chip` with `isDate`: `avatar: Icon(Icons.calendar_today, size: 14)`, `backgroundColor: colorScheme.primaryContainer`, `side: BorderSide(color: colorScheme.primary)`. Text in `onPrimaryContainer`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_date_chip_label.dart lib/features/dive_log/presentation/widgets/active_filter_chips.dart lib/features/query/presentation/dive_query_chips.dart test/features/dive_log/presentation/widgets/dive_date_chip_label_test.dart test/features/dive_log/presentation/widgets/active_filter_chips_test.dart
git commit -m "feat(dive-log): show understood dates as marked chips"
```

### Task 8: Hint, Try chip and user guide

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files, `diveLog_search_fieldHint`)
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_suggestions.dart`
- Modify: `docs/user/dive-logging.md`
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_suggestions_test.dart`

**Interfaces:** none.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('the Try chips offer last year', (tester) async {
  await pumpSuggestions(tester);
  await tester.tap(find.text('last year'));
  expect(hintApplied, 'last year');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/search/dive_search_suggestions_test.dart`
Expected: FAIL, no such chip.

- [ ] **Step 3: Implement**

Add `'last year'` to `hints` after the depth hint. Set `diveLog_search_fieldHint` to `Search site, buddy, gear or date` in `app_en.arb`, and a translation of the same length or shorter in the other 10 files, because the current hint was tightened for a 390 px phone. Run `flutter gen-l10n`.

In `docs/user/dive-logging.md` section Search, replace the words list with what plain words now reach, with `ressel in october 2018 with mike` as the example, and note that quotes search for exact words.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/search/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

Stage the 11 ARB files and generated `app_localizations*.dart` by name, plus the suggestions file, its test and the guide.

```bash
git commit -m "feat(dive-log): teach plain-word search in the search hint"
```

### Task 9: Measure and finish

**Files:**
- Test: a throwaway script in the session scratchpad, not committed.

- [ ] **Step 1: Measure**

Seed a 10,000 dive temp database with gear, sightings and buddies. Time `getDiveSummaries` with the query from `ressel october 2018` and from `shearwater nitrox mike`, on this branch and on `main`, five runs each, in a desktop debug build's Dart VM.

- [ ] **Step 2: Apply the stop condition**

If the list query more than doubles or passes 150 ms, stop and bring the numbers to the maintainer. Otherwise record both sets of numbers for the PR description.

- [ ] **Step 3: Final checks**

Run: `dart format .`, then `flutter analyze`, then `flutter test test/architecture/ test/shared/ test/core/query/ test/features/query/ test/features/global_search/ test/features/dive_log/ test/features/rules/ test/l10n/`
Expected: no issues, all PASS.
