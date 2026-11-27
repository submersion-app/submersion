# Equipment list: assembly view

Source: discussion #4118, suggestion 4 ("Collapsible equipment assemblies").
Release: v1.8.7.

## Intent

Divers who break a complex rig into individually tracked parts (an SF2
rebreather with its head, O2 cells, scrubber canister and bailout regulator,
each with its own service clocks) see every part as its own row on the
Equipment page, scattered across type groups (cells under Sensors, the
bailout under Regulators). The master inventory becomes hard to scan.

The assembly view folds each assembly's parts under the assembly's own row,
so the inventory reads as the rigs the diver owns, and any rig can be opened
to reach its parts. The individual view is today's flat list. The diver
switches between the two.

Two parent links already exist, and the view folds both:

- **Components** (#1487, #2629): any item with at least one
  `equipment_components` row is an assembly, a part can sit in several
  assemblies, and assemblies can nest.
- **Installed in** (`EquipmentItem.parentEquipmentId`, v202): a replaceable
  part (an O2 cell, a battery) installed in one host, shown as "Installed
  parts" on the host's condition card.

In this document "assembly" means any item with at least one part by either
link, and "part" means an item held by either link. List rows already show assembly and
"part of" chips plus a parts count, and the dive gear pickers already hide
parts that come along with their assembly (#2514). What is missing is the
parent/child structure on the inventory list itself. Issue #3364 / PR #4366
folded type and location groups, not assemblies.

## Goals

- The Equipment list can show parts nested under their assembly, indented,
  with the assembly row foldable.
- The diver can switch between assembly view and individual view.
- Existing divers land on assembly view, with every assembly folded.
  Divers with no assemblies see no change at all.
- An opened assembly stays open across launches and devices.

## Non-goals

- The table view: it stays flat (it already has a components column).
- The dive gear pickers, equipment set pickers, exports, PDFs and the
  inventory report: unchanged.
- Editing assemblies from the list (drag a part onto an assembly, and so
  on).
- Any change to the components data model.

## Anti-goals

- A part must never disappear. If the view cannot place a part under a
  visible assembly, it shows at the top level as it does today.
- A filter or search must still find a part. A matching part is never hidden
  inside a folded assembly.
- No schema change and no migration rung for this feature.

## Decisions (approved)

1. **Where a part shows in assembly view.** A part moves under its assembly
   and leaves its own type group. A nested assembly folds inside its
   parent. A part in two assemblies shows under each one. A part whose
   assembly is not on the list (filtered out, retired and hidden by the
   status filter) stays at the top level in its own type group.
2. **Default.** Assembly view is on for everyone, existing divers included,
   with each assembly folded.
3. **Both links nest.** "Installed in" parts fold under their host exactly
   as components do, and a host with only installed parts is foldable too.
4. **Approach A.** The switch is one more axis of the synced
   `EquipmentArrangement` JSON, shown on the Equipment page's sort sheet
   with the other page-only grouping switches. An absent key reads as on. Opened
   assemblies are remembered in the existing synced fold list
   (`listArrangements.equipmentCollapsedGroups`) as "opened" keys. Expand
   all also opens assemblies; Collapse all folds them again.

### Approaches considered

- **A (chosen):** switch in the arrangement JSON, opened assemblies in the
  existing fold list. No schema change, consistent fold behaviour, syncs.
- **B:** same behaviour with a dedicated `list_arrangements` column, a
  migration rung, a sync serializer arm and a conflict-screen entry. All
  plumbing, the only gain a separate conflict line for one switch.
- **C:** like A but opened assemblies held in memory only, so each launch
  starts all folded. Simpler, but a diver who keeps one rig open reopens it
  every launch, unlike type and place folds.

## Design

### Setting

- `EquipmentArrangement` gains `nestParts` (bool, default `true`), with
  `copyWith`, `toJson` key `nestParts`, per-axis fallback in `fromJson`
  (absent or non-bool reads as `true`), and `==` / `hashCode`.
- The switch tile goes in the Equipment page's sort sheet only, through the
  `pageGrouping` slot of `EquipmentSortSheetLayout` that "Group by location"
  already uses, not in the shared `EquipmentGroupingControls` (which the
  dive surfaces' arrange sheet also renders, where the switch would do
  nothing). Title "Show parts under their assembly", subtitle along the
  lines of "Fold each assembly's parts under it". New l10n keys in
  `app_en.arb`, and the other locales per the repo's l10n workflow.
- Only the Equipment page reads `nestParts`. Every other consumer of the
  arrangement (pickers, PDF, exports) ignores it.
- From this build on, `EquipmentArrangement` keeps keys it does not know
  and writes them back, so a later axis survives a round trip through this
  build. Known limitation: a build older than this one drops `nestParts`
  when it saves the arrangement, which reads as on again. Accepted; it
  only affects a diver who turned the view off and then changed the sort
  on a device running an older build.

### Which modes nest

- Detailed and compact list modes nest when `nestParts` is on.
- Dense mode is not offered for gear today, but if it is reached it follows
  `nestParts` too (builder's call), even though its sort sheet hides the
  switch.
- Table mode never nests.

### Layout

Nesting is a pass over the already arranged rows, so `arrangeEquipment`
(shared with PDF templates) does not change.

- Input: the arranged groups (and location sections when grouping by
  location), the part graph, and the set of item ids on the list after
  filtering.
- **Part graph.** The union of the component edges (`ComponentsIndex`) and
  the installed-in edges (`parentEquipmentId` of every item on the list).
  An item that is both a component of X and installed in X is one child of
  X, listed once.
- **Placement unit.** Grouping by location, nesting happens within one place
  section: a part nests under an assembly only when both are in the same
  place. A part stored somewhere else stays in its own place, where it
  shows today. Not grouping by location, the whole list is one unit.
- **Top-level items.** An item is top level in its unit when none of its
  parents is on the list in the same unit. Every top-level item keeps its
  own type group and position from the arrangement.
- **Children.** Under an assembly row, its parts that are on the list in the
  same unit follow: components first, in template order
  (`EquipmentComponent.sortOrder`, ties by row id, as
  `ComponentsIndex.fromRows` already sorts), then installed parts by cell
  slot and then name, the order `childEquipmentProvider` gives the
  condition card. Both are orders the diver already sees on the item's own
  page, so the list reads the way the rig goes together. A part that is
  itself an assembly nests its own parts the same way.
- **Shared parts** appear under every assembly on the list that holds them.
- **Corrupt loops.** Walking down from the top-level items, an item already
  on the current path is not descended into again. After the walk, any item
  on the list that was not placed anywhere (every one of its parents is
  inside a loop with no top-level entry) is added at the top level in its
  own type group, so a loop never hides its members.
- **Type headings.** A type group whose items all moved under assemblies
  disappears (it has nothing at the top level). Type heading counts count
  top-level rows only.
- **Indentation.** Each nesting level indents the row by one step. The
  indent stops growing after the fourth level so deep rigs stay readable at
  phone width.

### Folds

- Fold key for an assembly: `asm:<equipmentId>`, documented in
  `equipment_fold_keys.dart`. Unlike type and place keys, its presence in
  the stored list means **opened**, because assemblies start folded.
  Unknown-key preservation means an older build keeps these keys through
  a single fold or unfold. Known limitation: an older build's Expand all
  writes an empty list, which drops every `asm:` key and so folds every
  assembly on newer builds. Accepted.
- The fold is per assembly item, not per path: opening a shared
  sub-assembly opens it everywhere it appears.
- For layout, the effective collapsed set is the stored folded type and
  place keys plus `asm:<id>` for every assembly on the list that is not
  opened. The reveal logic subtracts from that set as it does today.
- **Reveal.** `foldKeysByItem` for a nested item lists its place and type
  keys and the `asm:` keys of the first path that reaches it (outermost
  first), so opening a part from outside the list (a deep link, a new item,
  a restored selection) opens exactly one path to it.
- **Expand all** opens every group and every assembly on the list (stores
  the `asm:` keys of every assembly on the list, clears folded keys).
- **Collapse all** folds the outermost groups as today, and also removes
  every stored `asm:` key, folding all assemblies.
- **The menu entries** are offered whenever the list shows any fold: a type
  or place heading, or a foldable assembly row. With type and location
  grouping both off, Expand all and Collapse all still appear when an
  assembly is on screen, and act on the assemblies alone.
- **While a filter is on** folds are session-only today and every group
  starts open. Assemblies follow the same rule: during a filter every
  assembly starts open, so a matching part is visible. Toggles during a
  filter stay in memory and are dropped when the filter changes or clears.
- The 300-key cap applies to the combined list, oldest first, as today.

### Assembly row

- The assembly's row is the existing item tile plus a fold chevron before
  the leading content (open or folded). Tapping the chevron toggles the
  fold. Tapping the rest of the row opens the item, as today.
- The parts-count chip is the folded summary. In assembly view it counts
  the row's children by both links (so a host with only installed cells
  gets one); the individual view keeps today's component-only chip. The
  service badge reads the rollup clock (#1487); if that rollup does not
  already include installed parts, the folded row still shows the worst
  clock of its hidden children by either link (builder to check and
  extend).
- A nested part's tile drops the chip naming the assembly it sits under (it
  would repeat the row above). Chips naming its other assemblies stay.

### Keyboard and selection

- Keyboard stops: an assembly row is both an item stop and a fold. Enter
  opens the item. Right opens a folded assembly; Left on an open assembly
  folds it; Left on a nested item moves to (or folds) the assembly it sits
  under, as Left on an item under a type heading does now.
- A shared part appears more than once. Its first occurrence keeps the item
  id as its navigation key; later occurrences get a path-qualified key, and
  the layout maps every navigation key back to its item. Selection marks
  every occurrence of a selected item.
- Selection mode works per item. Ticking an assembly does not tick its
  parts. Shift-click ranges walk visible rows and skip folded parts, as
  ranges already skip folded groups.

## Constraints

- `equipment_list_content.dart` is 1800 lines; new code goes in new files
  (a nesting layout helper next to `equipment_list_rows.dart`, a chevron
  widget, a part file for any new list-content methods), not into that
  file.
- Units, l10n and accessibility follow existing list tiles: the chevron has
  a semantics label ("Show parts" / "Hide parts") and a 48 dp hit area.
- Works across the range: a diver with no assemblies (no visible change), a
  diver with one SF2 of 12 parts, and a large inventory with dozens of
  assemblies, nested two or three levels deep, at phone and desktop widths.

## Left to the builder

- Exact widget structure of the chevron and indent.
- Where the nesting pass lives and how it is tested, as long as it is pure
  and unit tested (no widget needed for placement, both links, loops,
  shared parts, locations and reveal paths).

## Calls made during review

Settled without asking, open to correction:

- The switch lives on the Equipment page's sort sheet only (page-only
  grouping slot), not in the controls shared with the dive surfaces.
- The arrangement keeps unknown keys from now on; older builds dropping
  `nestParts` is an accepted limitation.
- Expand all and Collapse all are offered when only assemblies fold.
- Dense mode follows `nestParts` if reached.
- Installed parts list after components, by cell slot then name.
- Exact l10n wording beyond the intent above.
