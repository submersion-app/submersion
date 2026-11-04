# Data quality inbox: name what a finding is about (issue #4209)

## Goal

1. The message after a full library scan reports the same number the home
   screen gauge and the Dives menu badge show.
2. Every finding about one source, computer or tank says which one, in the
   card, on the repair button and in the follow-up sheet or dialog.
3. The values a finding stores are shown, and the display bugs listed in the
   issue are fixed.

Out of scope: detector thresholds, and the empty `evidence` slot of the card.

## Decisions

### D1 Scan message counts open findings

`_runFullScan` no longer shows `QualityScanSummary.findingsProduced`. After
the scan it reads `QualityFindingsRepository.watchOpenCount(diverId:)` once,
for the active diver: the same query as `openQualityFindingsCountProvider`, so
the snackbar, the badge and the dashboard cannot disagree. Dismissed findings
and pair findings counted twice across batches drop out by construction.
`dataQuality_scan_done` keeps its key; its copy now says "open" items.

### D2 Subjects resolved once per page

A finding names its subject through params: `sourceId` (clock offset,
source conflict), `tankId` (pressure anomaly, tank assignment),
`tankIdA`/`tankIdB` (twin tanks). A new batched lookup
(`QualityFindingSubjectQuery`, one query for sources, one for tanks) resolves
them into `QualityFindingSubjects`:

- Source label: the saved computer's display name (via
  `dive_data_sources.computer_id`), else `computer_model`, else none.
- Tank label: "Tank n", n being the tank's 1-based position among its dive's
  tanks ordered by `tank_order` (the numbering dive detail uses), plus the
  tank name when it has one.

The inbox watches it through a family provider keyed by the referenced ids,
only when a finding in scope references one, like the computer names today.

### D3 Card shows the subject

- The "Recorded by ..." row falls back to the source label when the finding's
  `computerId` names no saved computer.
- A new "Tank: ..." row lists the tank or tanks of a tank finding.

### D4 Buttons name the source

- "Fix {computer}'s clock by {offset}", "Make {source} the primary source"
  and "Split {source} into its own dive", falling back to today's unnamed
  labels when no label resolves. The name is the one the card's "Recorded
  by" row shows, so button and row never disagree.
- Tank repair buttons stay unnamed: the card's tank row says which tank, and
  every tank repair acts on the tank(s) of its own finding.

### D5 Sheet and dialog name the source

- `showTimeShiftSheet` takes an optional `subject` and shows it as a line
  under the title.
- "Make this source primary" asks first, naming the source, because the
  repair has no snackbar undo (`QualityRepairExecutor.setPrimarySource`).

### D6 Values for the dive time and temperature conflicts

`dataQuality_msg_sourceDuration` and `dataQuality_msg_sourceTemp` take
`{primary}` and `{source}`, like the depth conflict.

### D7 Display bugs

- Temperature jump: new `temperatureDelta` formatter backed by
  `UnitFormatter.formatTemperatureDelta`.
- Clock offset: `dataQuality_msg_clock_offset` is replaced by
  `..._offsetAhead` / `..._offsetBehind`, both ICU plurals on the hours.
- Durations: one helper renders seconds as "n s" below two minutes and
  "n min" above, through new unit strings; used by sample gaps, the rate
  message (`{seconds}` becomes a formatted `{duration}`) and the dive time
  conflict.
- Gas: air and oxygen use the localized gas names, other mixes
  `GasMix.name`. The ppO2 and hypoxic findings also store `hePercent`, so
  trimix keeps its helium; findings written before fall back to He 0.
  No detector version bump: the next scan rewrites params anyway, and a bump
  would raise the "new checks" banner for a wording change.

## Tests (written first)

- `quality_finding_message_test`: values, plural/direction, delta, durations,
  gas labels.
- New `quality_finding_subjects_test`: source and tank labels from a test
  database, fallbacks.
- `quality_finding_card_test`: tank row, recorded-by fallback, named buttons.
- `time_shift_sheet_test`: subject line.
- `data_quality_inbox_page_test`: scan message uses the open count; set
  primary asks first and does nothing on cancel.
- `gas_mod` detector test: `hePercent` stored.

## Localization

All new and changed strings in all 11 locales; Arabic plurals with every
category the l10n tests require.
