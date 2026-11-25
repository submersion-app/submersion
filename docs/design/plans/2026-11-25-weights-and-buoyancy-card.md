# Weights and Buoyancy Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dive page's Weights card and Buoyancy card with one "Weights and buoyancy" card: the weights list on top, the buoyancy model below.

**Architecture:** The Buoyancy card loses its own `Card` and header and becomes a body widget; its header buttons become a reusable actions widget. The Weights card becomes a rows widget. A new merged card composes the two under a `RecordCardHeader` and is the `weights` section's content. The `buoyancy` section id, its pair and its fade reason are retired.

**Tech Stack:** Flutter, Riverpod, flutter_test, ARB l10n (`flutter gen-l10n`).

**Spec:** `docs/design/specs/2026-11-25-weights-and-buoyancy-card-design.md` (issue #5005)

## Global Constraints

- Card title is `l10n.diveDetailSection_weights_name`, whose English value becomes "Weights and buoyancy" (all 12 ARB locales updated).
- The weights edit card (`diveEditCards[weights]`, its id, title "Weight", `isEmpty`, editor) is unchanged.
- A saved `{"id":"buoyancy",...}` entry is dropped on read, as `reefHealth` is; no stored setting is rewritten.
- Units always go through `UnitFormatter`.
- No em-dashes anywhere; no emojis; files stay under 800 lines.

## Review Focus

1. Weights logged on a dive the model cannot run (no cylinder, no suit, or a null outcome): the card must still show the list. Test in Task 4.
2. Cylinders but no lead: the card shows the model with the "no lead recorded" hint and no list. Test in Task 4.
3. The model reloads after a dive edit: the card must keep its model part (no flicker), as the pair test "weights-buoyancy-reload" pinned. Ported in Task 4.
4. A narrow (phone, 360 px) card with the pencil showing: the header with What if? and info must not overflow. Test in Task 3.
5. A saved order from before this change that hid Weights and showed Buoyancy: the merged card stays hidden; one that only names `buoyancy` loses nothing else. Test in Task 4.

---

### Task 1: Split the Buoyancy card into a body and header actions

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart`
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_header_actions.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_section_test.dart`, create `test/features/dive_log/presentation/widgets/buoyancy_header_actions_test.dart`

**Interfaces:**
- Produces: `BuoyancySection({required String diveId, required UnitFormatter units, Dive? dive})`, now with no `Card` and no header: a `Column` of readout and chart, breakdown, lead block, safety rows, hints. Still `SizedBox.shrink()` when the outcome is null.
- Produces: `BuoyancyHeaderActions({required BuoyancyTwinOutcome outcome, required UnitFormatter units, required bool compact})`: the What if? button (an `IconButton` with tooltip when `compact`, else `TextButton.icon`) and the `HeaderInfoButton`, as a `Row(mainAxisSize: min)`.
- Produces: `static double BuoyancyHeaderActions.fullWidth(BuildContext context)`: the label's rendered width plus the button and info chrome (52 + 48), for callers deciding `compact`.

- [ ] **Step 1:** Move the header tests (`the header offers a what-if, not an edit (#4585)`, `the info sheet names the What if? button`, `header uses an info icon instead of the hover tooltip`, the two narrow-header tests) into `buoyancy_header_actions_test.dart`, pumping `BuoyancyHeaderActions` with `compact: false` and `true`. Add: `compact shows only the icon, with the label as tooltip` (`find.text('What if?')` finds nothing, `find.byTooltip('What if?')` finds one).
- [ ] **Step 2:** In `buoyancy_section_test.dart` change `renders nothing when the outcome is null` to expect `find.byType(BuoyancyThroughDive)` finds nothing; add `has no card or title of its own` (`find.byType(Card)` and `find.text('BUOYANCY')` find nothing with an outcome).
- [ ] **Step 3:** Run both files; expect compile failure / FAIL.
- [ ] **Step 4:** Implement: move `_header`, `_infoSlotWidth`, `_headerChromeWidth`, `_whatIfLabelWidth` into `BuoyancyHeaderActions`; `BuoyancySection._card` returns the column without `Card`, `Padding` or header.
- [ ] **Step 5:** Run both files; expect PASS. `flutter analyze` the two lib files.
- [ ] **Step 6:** Commit `refactor(dive-log): split the Buoyancy card into body and header actions`.

### Task 2: Weights card becomes a rows widget

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_weight_section.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_weight_gear_lead_test.dart`

**Interfaces:**
- Produces: `DiveWeightRows({required Dive dive})` (replaces `DiveWeightSection`): the same rows (typed entries, else positive legacy weight, then lead gear with "From equipment"), then a bold Total row (`diveLog_detail_label_total`, `units.formatWeight(dive.recordedWeightKg)`) only when there are two or more rows. No `Card`, no header, no `Divider`.

- [ ] **Step 1:** Update the gear-lead tests to pump `DiveWeightRows`; add `one entry shows no total row` (belt only: `find.textContaining('Total')` finds nothing) and `two entries show the total` (belt 4.5 + plate 2.5: finds `Total` and `7.0 kg`).
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement `DiveWeightRows`; keep `_WeightDisplay`.
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Commit together with Task 3 (Task 2 alone leaves the section list without a Weights card).

### Task 3: The merged card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_weights_buoyancy_card.dart`
- Test: create `test/features/dive_log/presentation/widgets/dive_detail/dive_weights_buoyancy_card_test.dart`

**Interfaces:**
- Consumes: `BuoyancySection`, `BuoyancyHeaderActions` (Task 1), `DiveWeightRows` (Task 2), `buoyancyTwinProvider`.
- Produces: `DiveWeightsBuoyancyCard({required Dive dive, required Dive stored, required bool showWeights})`. `dive` draws the weights rows (the sitting's dive); `stored` drives the model (`buoyancyTwinProvider(stored.id)`, `BuoyancySection(dive: stored)`).

Layout: `Card > Padding(16) > Column`: a `LayoutBuilder` around `RecordCardHeader(title: diveDetailSection_weights_name, leading: Icon(Icons.waves, primary), trailing: outcome == null ? null : BuoyancyHeaderActions(compact: maxWidth < titleRoom + BuoyancyHeaderActions.fullWidth(context)))` where `titleRoom` is 32 (icon) + 40 (pencil, always reserved so unlocking does not change the compact choice); then, when `showWeights`, `SizedBox(12)` and `DiveWeightRows`; then, when both parts show, `Divider(height: 24)`; then `BuoyancySection` when the outcome is non-null.

- [ ] **Step 1:** Write tests (override `buoyancyTwinProvider` with `buoyancyOutcome()` or null, as `buoyancy_section_test` does):
  - `shows the weights list above the model` (`Weight Belt` top < `Lead for next time` top; one `Card`).
  - `title is Weights and buoyancy` (finds the text; `BUOYANCY` and `Weight` titles absent).
  - `no outcome: list only, no What if?` (null outcome: finds `Weight Belt`, no `What if?`, no `Divider`).
  - `showWeights false: model only` (no `Weight Belt`, finds `Lead for next time`).
  - `nothing overflows at 360 and 1100 px` (loop, `tester.takeException()` is null).
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement `DiveWeightsBuoyancyCard`.
- [ ] **Step 4:** Run Task 2 and Task 3 tests; expect PASS.
- [ ] **Step 5:** Commit Tasks 2 and 3 as `feat(dive-log): one card for weights and buoyancy`.

### Task 4: Retire the Buoyancy section and wire the merged card

**Files:**
- Modify: `lib/core/constants/dive_detail_sections.dart` (enum value, display name 'Weights and buoyancy', description, icon, l10n switches, `defaultSections`, add `static const String legacyBuoyancyId = 'buoyancy'` and drop it in `_configsForEntry`)
- Modify: `lib/core/constants/dive_detail_section_pairs.dart` (remove the pair; doc lists five pairs)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_content.dart` (the `weights` case; remove the `buoyancy` case and the `weights` pair case)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (doc comment lists five pairs)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart` (remove `buoyancy` from `diveCardFadeReason`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_gas_cards.dart` (remove `DiveDetailBuoyancySection`)
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,ja,nl,pt,zh}.arb`: `diveDetailSection_weights_name` and `_description` take the combined values below; delete `diveDetailSection_buoyancy_description`; regenerate with `flutter gen-l10n`.
- Tests: `test/core/constants/dive_detail_sections_test.dart`, `test/core/constants/dive_detail_section_pairs_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`, `.../dive_detail_page_section_config_test.dart`, `.../dive_detail_page_unlock_gear_{cards,pairs,sets,}_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_fade_test.dart`, `.../editing/dive_edit_cards_test.dart`, plus any count assert `flutter analyze` or a run turns up.

The `weights` case:

```dart
case DiveDetailSectionId.weights:
  final showWeights = _onPage(ref, id, presence, stored, edit);
  if (!showWeights && !watchHasBuoyancy(ref, stored)) return null;
  return DiveWeightsBuoyancyCard(dive: dive, stored: stored, showWeights: showWeights);
```

`_framed` already gives an open card with null content the editor, so an open card with neither part still opens.

Translations (name / description):

| Locale | Name | Description |
| --- | --- | --- |
| en | Weights and buoyancy | Weights carried, buoyancy through the dive, lead for next time, ditchable weight |
| ar | الأوزان والطفو | الأوزان المحمولة، الطفو خلال الغطسة، الرصاص للمرة القادمة، والوزن القابل للإسقاط |
| de | Gewichte und Auftrieb | Mitgeführte Gewichte, Auftrieb im Tauchgangverlauf, Blei fürs nächste Mal, abwerfbares Blei |
| es | Lastres y flotabilidad | Lastres llevados, flotabilidad durante la inmersión, lastre para la próxima vez, lastre soltable |
| fr | Lestage et flottabilité | Lests portés, flottabilité pendant la plongée, lest pour la prochaine fois, lest largable |
| he | משקולות וציפה | משקולות שנשאו, ציפה לאורך הצלילה, משקולות לפעם הבאה ומשקל הניתן להשלכה |
| hu | Súlyok és felhajtóerő | Vitt súlyok, felhajtóerő a merülés során, ólom a következő alkalomra, ledobható ólom |
| it | Zavorra e assetto | Zavorra portata, assetto durante l'immersione, zavorra per la prossima volta, zavorra sganciabile |
| ja | ウェイトと浮力 | 携行したウェイト、ダイブ中の浮力、次回のウェイト量、投棄可能なウェイト |
| nl | Gewichten en drijfvermogen | Meegenomen gewichten, drijfvermogen tijdens de duik, lood voor de volgende keer, afwerpbaar lood |
| pt | Pesos e flutuabilidade | Pesos levados, flutuabilidade durante o mergulho, lastro para a próxima vez, lastro descartável |
| zh | 配重与浮力 | 携带的配重、整个潜水过程的浮力、下次的配重和可抛弃配重 |

- [ ] **Step 1:** Tests first:
  - sections test: `a saved buoyancy entry is dropped` (JSON with `weights` visible and `buoyancy` hidden parses to configs with no entry named `buoyancy` and `weights` visible); `a saved order that hid weights keeps the merged card hidden`; update the values count (one fewer).
  - pairs test: Weights has no partner; five pairs.
  - paired sections test: replace the Weights + Buoyancy pair tests with page tests: `weights and buoyancy render as one card` (one `Card` holding both `Weight Belt` and `Lead for next time`, no `ResponsiveSectionPair` around it); port the reload test (`the merged card keeps its model through a reload`); `weights with no model still show` (outcome null); `a dive with cylinders and no lead shows the model alone`.
  - fade test: the merged card does not fade while unlocked.
- [ ] **Step 2:** Run those files; expect FAIL.
- [ ] **Step 3:** Implement the lib changes and ARB edits; `flutter gen-l10n`.
- [ ] **Step 4:** `flutter analyze`; fix every remaining reference to `DiveDetailSectionId.buoyancy` and `DiveWeightSection` in tests.
- [ ] **Step 5:** Run every test file touched in Tasks 1 to 4 by path; expect PASS.
- [ ] **Step 6:** `dart format .`; commit `feat(dive-log): retire the Buoyancy section for the merged card`.

### Task 5: After screenshots

- [ ] Re-run the throwaway golden (`test/_pr_shots/`, not committed) with `--dart-define=STAGE=after`, view each, copy to the scratchpad, then delete `test/_pr_shots/`.
