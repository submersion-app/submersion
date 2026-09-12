# Dives-only UDDF: participants, roles and gear

Date: 2026-09-12
Issues: #1718 (gear), plus a new issue for participants (to be opened)
Depends on: PR #1788 (issue #1737, `<buddyroles>` and `DiveRole.leaderIds`)

## Problem

The dives-only UDDF export (`UddfExportService.generateDivesUddfContent`,
reached from the dive detail page, the dive list selection and the buddy
detail page) writes only the legacy free-text `dive.diveMaster` and
`dive.buddy` fields for participants. It declares no `<diver><buddy>`
records, writes no `<link ref="buddy_...">`, and takes no names from linked
people. A dive whose participants are all linked people, the normal case,
exports with no participants and no roles.

It also carries no gear (#1718): no item definitions, no `<equipmentused>`,
no `<components>` or `<gearlinks>`, and no `<divecomputer>` declaration, so
`<divecomputercontrol>` is written with an empty declared set.

The full backup export handles all of this. The two paths diverged because
the dives-only service hand-writes its per-dive elements instead of sharing
the full export's writers.

## Goals

- A dives-only file carries every linked participant with their exact role,
  and the gear used on each dive, in the same shapes the full export uses,
  so the existing full import path restores them.
- The user controls whether participants and gear are shared, and a shared
  file never carries contact details or purchase data.
- Participant and gear writing is one implementation shared by both export
  paths.

## Non-goals

- Standard typed UDDF equipment elements (`regulator`, `bcd`, ...) under
  `<owner><equipment>`. The full export does not write them either.
- Equipment sets. A set-applied gear row imports as loose gear.
- Any other part of the dives-only output (tags, weights, gas switches,
  weather, trips). Unchanged.
- The legacy dives-only import service (`uddf_import_service.dart`), which
  has no UI caller.
- The full export's output. The refactor that routes it through the shared
  writers must leave it unchanged.

## File contents

### Include dive participants (default on)

- `<diver>`: one `<buddy id="buddy_<id>">` per person linked to any
  exported dive, and only those people. Trimmed: `<personal>` first and last
  name, and `<certification>` level and agency. No email, phone or notes.
- `<informationbeforedive>`, per dive:
  - `<divemaster>` holding the names of the dive's leaders (roles in
    `DiveRole.leaderIds`), joined with ", ". When the dive links no leader,
    the legacy `dive.diveMaster` text, as the full export does.
  - One `<link ref="buddy_<id>">` per participant. Solo is skipped.
- `<informationafterdive>`, per dive: an inline `<buddy><personal>` for each
  participant whose role is neither a leader nor solo. When there is none,
  the legacy `dive.buddy` text.
- `<applicationdata><submersion>`: `<buddyroles>` rows for every participant
  whose role is not plain buddy, and `<diveroles>` definitions for the
  custom (not built in) roles those rows reference.

When off, none of the above is written, including the legacy free-text
fallbacks.

### Include gear (default on)

- `<diver><owner id="owner">`: no `<personal>`. Holds
  `<equipment><divecomputer id="<computerRefId>">` with model and serial for
  each distinct computer on the exported dives. `<divecomputercontrol>`
  receives exactly these ids as its declared set.
- `<informationbeforedive><equipmentused>`, per dive: one
  `<equipmentref>equip_<id></equipmentref>` per gear row, and the dive
  computer `<link>`.
- `<applicationdata><submersion>`:
  - `<equipment><item id="equip_<id>">` for each distinct item on the
    exported dives, without `purchasedate`, `purchaseprice` or
    `purchasecurrency`. `parentref` is written only when the parent item is
    also in the file.
  - `<components>` rows whose parent and component are both in the file.
  - `<gearlinks>` for the dives with provenance rows.

When off, none of the above is written. The owner element is written only
when there is a computer to declare.

### Shared rules

- All private sections live in one top-level
  `<applicationdata><submersion>` wrapper, together with the existing data
  source records. The full import service reads only the first top-level
  `<applicationdata>` for everything except data sources.
- The per-dive inline `<applicationdata>` for custom fields is unchanged.
- Nothing is declared that no exported dive references, so every IDREF in
  the file resolves.

## Data flow

- `UddfExportOptions` gains `includeParticipants` and `includeGear`, both
  default `true`, with `copyWith`. The full export ignores them.
- `showExportDestinationSheetWithOptions` gains `showDiveContentToggles`
  (default `false`) and returns
  `ExportChoice = ({ExportDestination destination, UddfExportOptions options})`.
  The three dives-only callers pass `true`. The transfer page keeps only the
  raw data checkbox and reads `choice.options.includeRawData`.
- Four new ARB keys (title and subtitle for each checkbox), in all 11
  locales.
- `UddfDivesExtras` holds `diveBuddies` (dive id to `List<BuddyWithRole>`)
  and `components` (`List<EquipmentComponent>`), with a const empty
  constructor.
- `uddfDivesExtrasFetchProvider(diveIds, options)`, modeled on
  `uddfSourceFetchProvider`, calls `BuddyRepository.getBuddiesForDives` only
  when `includeParticipants` is on and loads components only when
  `includeGear` is on.
- Declared people and custom roles are derived in the service from
  `diveBuddies`. Items and computers are derived from the already hydrated
  `dive.gear`, `diveComputerModel` and `diveComputerSerial`.
- `generateDivesUddfContent`, `exportDivesToUddf`, `saveDivesToUddfFile` and
  the `ExportService` pass-throughs gain
  `UddfDivesExtras extras = const UddfDivesExtras.empty()`.
- Each dives-only widget fetches extras next to its existing data source
  fetch and passes them through.

## Code structure

| File | Change |
| --- | --- |
| new `lib/core/services/export/uddf/uddf_participant_writers.dart` | `UddfParticipantWriters`: `writeBuddyDeclarations(builder, people, {trimmed})`, `writeLeaders(builder, dive, rows)`, `writeLinks(builder, rows)`, `writeInlineBuddies(builder, dive, rows)` |
| new `lib/core/services/export/uddf/uddf_gear_writers.dart` | `UddfGearWriters`: `writeEquipmentUsed(builder, dive)`, `writeOwnerComputers(builder, ownerId, dives)` returning the declared computer ids |
| new `lib/core/services/export/uddf/uddf_dives_extras.dart` | `UddfDivesExtras` and `uddfDivesExtrasFetchProvider` |
| `uddf_export_builders.dart` | `buildDiveElement` calls the extracted writers; `buildApplicationData` gains `omitPurchaseDetails` and writes `parentref` only for a parent in the file |
| `uddf_full_export_service.dart` | `<diver>` block calls `writeBuddyDeclarations(trimmed: false)` and `writeOwnerComputers`; `declaredComputerIds` comes from the writer |
| `uddf_export_service.dart` | `<diver>` section, gated per-dive writer calls, one `buildApplicationData` call replacing the hand-written data source wrapper |
| `export_service.dart`, `dive_detail_page.dart`, `dive_list_content.dart`, `buddy_detail_page.dart`, `export_destination_sheet.dart`, `transfer_page.dart`, 11 ARB files | Plumbing |

`uddf_export_builders.dart` is already over the 800-line limit; nothing new
is added to it beyond the two parameters, and the extraction shrinks it.

## Commit sequence

1. Refactor: extract the writers, route the full export through them. The
   existing full export suites pass unchanged.
2. Options, extras bundle and fetch provider.
3. Dives-only participants.
4. Dives-only gear.
5. Sheet checkboxes, l10n and the three callers.

## Testing

TDD throughout; each new test is watched failing before its fix.

1. Refactor guard: every suite under `test/core/services/export/uddf/`
   passes unchanged after commit 1, plus new unit tests for the extracted
   writers written before the code moves.
2. `uddf_dives_export_participants_test.dart`: trimmed declarations, links,
   leaders and legacy fallback, solo skipped, inline plain buddies,
   `<buddyroles>` and custom `<diveroles>` inside the single wrapper, and
   the checkbox off omitting everything including legacy text.
3. `uddf_dives_export_gear_test.dart`: `<equipmentused>`, items without
   purchase fields, `parentref` only for a parent in the file, filtered
   components, `<gearlinks>`, id-only owner with `<divecomputer>` and
   `<divecomputercontrol>` linking to it, exactly one top-level
   `<applicationdata>`, and the checkbox off omitting everything.
4. `uddf_dives_export_round_trip_test.dart`, DB-backed like
   `uddf_buddy_roles_round_trip_test.dart`: export selected dives, import
   into a clean database through the full import service and entity
   importer. Every role comes back exact (guide, divemaster, instructor,
   student, custom, plain buddy); assembly provenance survives; a
   set-applied row lands loose; the computer is declared; no duplicate
   people.
5. Fetch provider: no buddy or component query when its checkbox is off.
6. Sheet widget test: checkboxes only with `showDiveContentToggles`, the
   returned options reflect them, the transfer page is unchanged. The three
   caller widget tests override `uddfDivesExtrasFetchProvider`.
7. `dart format .`, whole-project `flutter analyze`, and one run of the
   export, dive_log, buddies, transfer and shared widget suites.

## Delivery

A PR stacked on #1788's branch, opened now. It gets no CI until #1788
merges and it is retargeted to `main`, so the local runs above are the gate
until then. The PR closes #1718 and the new participants issue.
