# Dive search understands plain words

Date: 2026-11-02
Issue: #3457
Release: v1.8.4
Status: approved

## 1. Why

A diver wants to type what they remember about a dive and see it:
`france october 2018`, `ressel with mike`, `ressel in 2018`. Opening Refine,
picking a filter and setting its value takes too many clicks.

Today every bare word must appear as text somewhere on the dive, and the
dive's date is never checked. So:

| Typed | What happens today | Why |
| --- | --- | --- |
| `ressel october 2018` | Zero dives | `october` and `2018` must appear as text |
| `france 2018` | A stray dive | Its text happens to contain 2018 |
| `ressel with mike` | Mostly works | `with` must appear as text |
| `ressel in 2018` | Parse error, list not updated | `in` after a word reads as an operator, so `ressel` is an unknown field |

Ask already reads sentences, but only on devices with the on-device model, and
only as an explicit action. The typed language already reads dates
(`date:2018`, `date in 2018-10`), but a diver has to know it exists.

The maintainer widened the request beyond dates: a word could be a brand, a
dive type, or anything else a dive carries.

## 2. Goals

1. A diver can type words that describe a dive and find it, in any order, with
   no syntax and on every platform.
2. Words reach everything a dive carries: its text, the records attached to
   it, and values such as dates, gas and entry method.
3. A diver can see which words the app took as a date.

## 3. Non-goals

- Numbers with units as plain words. `30m` is not guessed at, because
  `depth > 30m` already exists.
- Changing Ask, the Refine panel or the empty-results state.
- Ranking results by how well they match. The list keeps its sort.
- Plain-word reading for any record type but dives. Sites, trips and the rest
  gain only the `in` fix (section 7).
- Date phrases in languages other than English (section 5.4).

## 4. What must not go wrong

- **No lost results.** Every word keeps matching what it matches today. New
  meanings are added alongside the text match, so a few extra dives are
  acceptable and a missing dive is not. The date phrases of section 5.3 are the
  one deliberate exception: they replace the text match, and quotes bring it
  back.
- **No schema change.** Nothing here needs a migration or a sync change.
- **A chip never claims more than the filter does.** Chips stay printed from
  the same tree the compiler runs.
- **Typing stays responsive.** See section 10.

## 5. How a search is read

Each term is one clue. A dive must satisfy every clue. That is unchanged. What
changes is how many ways a clue can be satisfied.

### 5.1 Records attached to the dive (new text search columns)

Added to the dive entity's `textSearchSql`, each as an `EXISTS` over its link,
matching with `unicode_lower(...) LIKE` as the other templates do:

| Record | Columns | Reached through |
| --- | --- | --- |
| Gear | name, brand, model | The same set as `kDiveGearJoinSql`: `dive_equipment`, `dive_tanks`, and tank regulators |
| Trip | name, location, resort name, liveaboard name | `dives.trip_id` |
| Species seen | common name, scientific name, plus translated names | `sightings.dive_id` |
| Course | name, location | `dive_courses` |
| Dive computer | name, manufacturer, model, plus `dives.dive_computer_model` | `dives.computer_id` |

Translated species names reuse `builtInSpeciesIdsMatching` in a new
`TextSearchExpansion` over `sightings.species_id`.

Every table added here must be declared in `textSearchTables`, so that list
refresh ticks reach it.

### 5.2 Words that stand for a value (new text search expansions)

Each is a `TextSearchExpansion` added to the dive entity, so it runs alongside
the text match for that word and reaches every surface that compiles dive text.

| Word | Matches |
| --- | --- |
| A year, 1900 to 2200 | Dives in that year |
| A full month name | Dives in that month of any year |
| A full weekday name | Dives on that weekday |
| `ccr`, `scr`, `oc`, `gauge`, `rebreather` | Dive mode (`rebreather` is both CCR and SCR) |
| `shore`, `boat`, and the other entry methods | Entry or exit method |
| `salt`, `saltwater`, `fresh`, `freshwater`, `brackish` | Effective water type, using the same SQL as the `waterType` field |
| `air`, `nitrox`, `trimix`, `ean32` and any `eanNN` | Any tank on the dive holding that gas |
| `favourite`, `favorite` | Favourite dives |

Rules:

- **Months and weekdays use the full name only.** Short forms count only as
  part of a date phrase (section 5.3), so `jan` finds a buddy named Jan and not
  every January dive. `may`, `june` and `august` will pick up some strays. That
  is accepted.
- **All app languages, always.** Like dive types, matching covers every
  language the app ships, not just the active one. The compiler stays
  locale-free and a saved search finds the same dives on every device. Month and
  weekday names come from `dateTimeSymbolMap()`; setting words come from the
  `enum_*` ARB labels through `lookupAppLocalizations`.
- **Whole labels, plus the listed words.** A setting matches its whole label in
  any language, or a word the table above lists. A single word from a longer
  label does not count, so `open` is not a dive mode and `open water` stays a
  search for a course. `Other` never counts.
- **A multi-word label is one term.** Bare words that spell a whole label in a
  row, such as `salt water`, `open circuit` or `back roll`, are read as one
  term. It is the same multi-word `TextNode` a quoted phrase produces, so it
  still matches that text as well as the setting. Without this, `water` would
  have to appear as text and the search would find almost nothing.
- **Bind as strings, and do not cast.** `kDiveNumberTextSearch` records the
  trap: a string bind only compares as a number against a bare INTEGER column.
  The year, month and weekday templates must compare the text `strftime` returns
  (`'2018'`, `'10'`, `'6'`), not the `CAST(... AS INTEGER)` the `year` field
  uses. Dates are wall clock, read the same way as those fields.
- **Gas follows the mix, not the Refine shortcuts.** These use the helium-aware
  rules on the `Dive` entity (`isAir`, `isNitrox`, `isTrimix`): `trimix` is any
  tank with helium, `nitrox` is O2 above 22 with no helium, and `air` has no
  helium. `eanNN` also needs no helium and allows half a percent either side.
  Refine's Trimix option is O2 at or below 21 with no helium check, which would
  make `trimix` find every air dive, so it is not the model here.

### 5.3 Date phrases (new, in the parser)

On an entity that opts in (section 7), the parser tries to read a date phrase
wherever a term starts, longest first. A phrase becomes a date condition, not
text. It reuses `parseDateText`, so it reads the forms that grammar reads:

| Form | Examples |
| --- | --- |
| Month and year | `october 2018`, `oct 2018`, `sept 2021` |
| ISO | `2018-10`, `2018-10-14` |
| Relative | `this year`, `last year`, `this month`, `last month`, `last 90 days`, `past 2 years` |
| Open-ended | `since 2020`, `before 2020`, `since march 2020` |
| Year after `in` or `during` | `in 2018`, `during 2018` |
| Two periods (new in the grammar) | `2018 to 2020`, `between 2018 and 2020`, `march 2018 to june 2019` |

Rules:

- A lone year is never a phrase. `2018` alone is a word (section 5.2), so it
  keeps matching notes and dive number 2018.
- A phrase inside quotes is text. `"last year"` and `"october 2018"` search for
  those words.
- A relative phrase becomes fixed dates when parsed, as `date:"last year"` does
  today. A saved search made from `last year` keeps meaning 2025.
- Reading a phrase never produces an error. Anything the grammar refuses stays
  plain words.
- A negated phrase works: `not last year`, `-2018-10`.
- A phrase's result is the same tree `date in ...` produces, so it validates,
  prints and saves with no new node type.

### 5.4 Filler words (new, in the parser)

On an entity that opts in, a bare filler word is dropped: `with`, `in`, `at`,
`on`, `from`, `the`, `of`, `near`, `during`, plus the same small list in the
diver's app language. English always applies, because that is what the date
grammar reads.

- Only a bare word at the top level of a term list is dropped. A quoted word and
  a negated word stay: `"with"` and `not with` still search for it.
- If every term is filler, none are dropped: `the` alone still searches.
- The filler list is a const map in one Dart file, not ARB text. Parsing already
  happens with a `ParseContext`, which gains the active language. The tree it
  produces is the same on every device, so saved searches are unaffected.

## 6. The `in` fix

`in` after a word is an operator only when a `[` follows it, or the word
resolves to a date field. `between` after a word is an operator only when the
word resolves to a field. Anything else reads as plain words, whether or not the
word names a field, so all of these now search:

| Typed | Today | After |
| --- | --- | --- |
| `ressel in 2018` | Unknown field error | Word `ressel`, date 2018 |
| `favorite in 2018` | Operator error | Favourites, date 2018 |
| `trip in 2018` | Expected `[` error | Word `trip`, date 2018 |

These stay as they are:

- `date in 2018` is a date condition.
- `buddy in ["Mike"]` is a list.
- `dte in [2018]` is still a condition, so a mistyped field in a list form keeps
  its "did you mean" suggestion.

The maintainer accepted the cost: `site in Cozumel` loses its "expected `[`"
error and becomes words, so someone half-remembering the syntax sees few dives
where they used to see a correction.

This fix applies to every entity, because it also stops global search losing a
record type's results to a refusal.

## 7. Where it applies

A new optional `QueryEntity` member, the plain-word reading, carries the date
field to use. Only the dive entity sets it. Date phrases and filler words are
gated on it.

The gate matters: global search parses the same text once per record type, and
a date phrase on an entity with no `date` field would refuse the whole search.
Inside a scoped group such as `gear[...]` the parser's current entity is the
equipment one, so plain-word reading is off there.

| Surface | Gets |
| --- | --- |
| Dives search row and jump list | Everything |
| Global search, dive results | Everything |
| Saved searches holding plain words | Sections 5.1 and 5.2, so they may find a few more dives. The stored tree is unchanged |
| Other surfaces that parse dive queries (Insights, Connections, the agent query tool) | Everything |
| Other record types | The `in` fix only |

Jump list behaviour for a lone number (#3455) is unchanged: exact dive numbers
still lead, then the text and year matches.

## 8. What the diver sees

The field keeps the diver's words until they remove a chip. Removing one
rewrites the field from what is left, as it does today, so filler words disappear
and a date prints as `date in 2018-10`.

**Date chips.** A top-level date condition shows in plain words, in the diver's
language and date format. The chip has a small leading calendar icon, a
`primaryContainer` background and a `primary` border, taken from the theme so it
holds in light and dark. Word chips keep today's look:

| Condition | Chip |
| --- | --- |
| A whole year | `2018` |
| A whole month | `October 2018` |
| A single day | The day, in the diver's date format |
| Any other range | The existing `diveLog_filterChip_dateRange` wording |
| `>=` | The existing `diveLog_filterChip_from` wording |
| `<=` | The existing `diveLog_filterChip_until` wording |

- This applies to any top-level condition on the `date` field, however it was
  written, so `date:2018` gets the same chip. Strict `<` and `>`, and a negated
  date, keep today's printed text, because the plain wording would claim
  something different.
- A lone `2018`, `october` or `nitrox` stays a normal word chip, because it also
  matches other things.
- Every chip stays removable on its own.
- Only the dive list's chips change (`activeDiveFilterChips`, which Connections
  shares). The record lists that use `entityQueryChips` keep their labels.

**Discovery.** The field hint becomes "Search site, buddy, gear or date",
translated, and short enough for a 390 px phone (the current hint was tightened
for that reason). The "Try" chips gain `last year`.

**User guide.** `docs/user/dive-logging.md` section "Search" describes what plain
words now reach.

## 9. Testing

Tests first, per the repo rules.

- **Parser:** every form in 5.3 and 5.4, quoted and negated forms, every-word
  filler, multi-word labels, each row of the section 6 table and its list and
  date exceptions, and a non-dive entity reading the same text unchanged. A
  round trip for each phrase through the printer.
- **Date grammar:** the two-period forms, in `date_grammar_test.dart`, including
  reversed periods, which stay plain words.
- **Compiler and database:** each row of 5.1 and 5.2 finding a real dive through
  `getDiveSummaries`, including the reporter's four searches from section 1, and
  a translated word for each kind. A test that `2018` still finds a dive whose
  notes mention 2018 and dive number 2018.
- **Refresh:** a write to a table added in 5.1 re-runs an active search.
- **Chips:** each row of the chip table, and that `date > x` keeps printed text.
- **Registry guards:** `test/features/query/query_registry_guards_test.dart` and
  `test/architecture/`.
- **l10n:** `test/l10n` for the new hint.

## 10. Performance

Each word gains several `EXISTS` branches, and the search runs after each pause
in typing. Every link table involved already has a `dive_id` index, so no new
index is expected.

Measure a three-word search over a 10,000 dive database before and after, and
put the numbers in the PR. If the list query more than doubles or passes 150 ms
on a desktop debug build, stop and bring the numbers back to the maintainer
before going further.

## 11. Left to the builder

- The exact name and shape of the new `QueryEntity` member.
- How `TextSearchExpansion` expresses a word with no bind value, such as `nitrox`.
- The per-language filler lists, kept short. Hungarian, Arabic, Hebrew and
  Chinese attach these words to other words, so they may have none.
- File layout, within the repo's size limits. `query_parser.dart` is 741 lines,
  so the phrase reading belongs in its own file.
