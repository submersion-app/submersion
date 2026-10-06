# Equipment "Wanted" status (wishlist)

Issue: #2025. Release: v1.8.2.

## Problem

Divers want somewhere to keep gear they intend to buy. Today every equipment
status describes gear the diver owns or once owned (Active, Spare, Needs
Service, In Service, Retired, Sold, Loaned Out, Lost), so a wishlist item has
to be entered as Active and then shows up in dive gear pickers, service
reminders, statistics and the gear value total.

## Decisions (approved in brainstorming)

| Question | Decision |
| --- | --- |
| Shape | A new `EquipmentStatus.wanted` value, not a separate wishlist entity or section |
| Visibility | Hidden from the default Equipment list, like Retired and Sold; seen through the Wanted status filter chip |
| Storage | `isActive=false`, following the Sold precedent |
| Buying it | A "Mark as purchased" action on the detail page |
| Edit form | Relabel price as "Expected price"; hide purchase date, serial number, notification settings and the parent dropdown while Wanted |
| Summary | Owned-gear totals exclude Wanted; separate Wanted count and Wanted value cards when any exist |

## Data model

- `EquipmentStatus.wanted('Wanted')`, declared after `lost`. The enum is stored
  by `name` in the existing TEXT `status` column: no schema version bump, no
  migration rung. Sync serializes status as text, and UDDF/CSV exports write it
  out, so the value round-trips. Older builds read the unknown name back as
  `active` through their existing `firstWhere(orElse:)` fallbacks, but they
  still honour `isActive=false`, so an older synced device shows a Wanted item
  as Retired (out of the kit), never as active gear.
- Saving rule (edit page): `isActive = status not in {retired, sold, wanted}`.

### Why `isActive=false`

Every check that reads `isActive` alone then excludes Wanted with no code
change: `EquipmentItem.isFitted`, `isGearActive` (assembly expansion),
`_activeIdsAmong` (assembly parts added to dives), `getChildEquipment`,
`getEquipmentWithServiceDates`, the dive-computer gear-twin resolver, and the
data-quality installed-children check. A site that is missed errs toward "not
in the kit", which is harmless, rather than toward "owned".

## Carve-outs: places that read `!isActive` as Retired

Each already special-cases Sold; Wanted joins it so it is never shown or
counted as Retired.

- `EquipmentRepository.getRetiredEquipment`: exclude `wanted`.
- `EquipmentRepository.getEquipmentByStatus(retired)`: the `isActive=false`
  branch excludes `wanted`.
- `departedStatusOf` (`equipment_departed_status.dart`): returns Wanted for a
  Wanted item, so a wishlist part still linked into an assembly is badged
  Wanted on the components and part-of lists, never Retired and never
  unbadged as if fitted.
- Edit page status init for legacy rows: an inactive row keeps `wanted` rather
  than being folded into Retired.
- `reactivateEquipment`: unchanged in effect; Wanted is not a terminal status
  it clears, and the list never offers Reactivate for Wanted rows (below).
- Detail page header chip: shows the item's real status (Wanted, Sold, Lost,
  Retired) instead of "Retired" for every inactive item. This also corrects
  Sold items, which currently show a "Retired" chip.

## Explicit exclusions: screens that read all equipment

These read `allEquipmentProvider` or build their own query, and must never
offer gear the diver does not own:

- Equipment list default view (`equipment_filter_query.dart`, status null):
  add `status != wanted` next to the retired and sold checks. The list count's
  denominator uses the same branch, so it drops Wanted too.
- Cylinder-config rebreather dropdown (`cylinder_config_edit_page.dart`).
- Pre-dive session single-item gear dropdown (`start_session_sheet.dart`).
- Dive search gear chips (`refine_gas_equipment_group.dart`).
- The dive filter's gear type chips (`diveGearTypesProvider`, new): a type held
  only by Wanted items is not offered. The Equipment filter sheet's type chips
  (`ownedEquipmentTypesProvider`) keep every status, because its status axis
  can show Wanted gear.
- Equipment list bulk actions: Retire and Reactivate are not offered for
  Wanted items.
- Applying an equipment set to a dive: Wanted members are skipped. The set
  editor only offers active gear, so this only happens when an existing member
  is later edited to Wanted. The filter goes in the shared query
  `EquipmentVisibilityQueries.usableSetMemberIds`, which every set-apply path
  already calls: dive edit (`_addGearNow`, including geofence suggestions),
  the new-dive default set (`dive_equipment_defaulter`), trip gear add, the
  dive-computer set linker, and assembly gear expansion. Retired members keep
  today's behaviour (they are applied); changing that is out of scope.

Left alone on purpose, because Retired already behaves the same way: equipment
search (all statuses), exports, sync, share-all, and import duplicate matching.

## UI

### Edit form (`equipment_edit_page.dart`)

While the selected status is Wanted:

- Purchase price label reads "Expected price". Currency, retailer, SKU and
  product link stay visible.
- Hidden: purchase date, serial number, the service notification card, and the
  parent ("installed in") dropdown.
- Hidden fields keep their controller values; nothing is cleared on save, and
  switching the status away shows them again unchanged.
- Everything else (name, type, brand, model, notes, appearance, size, tags,
  custom fields) is unchanged.

### Detail page (`equipment_detail_page.dart`)

- A Wanted item shows a "Mark as purchased" button in the header card.
- Tapping it calls a new repository method that, in one write with sync
  stamping, sets `status=active`, `isActive=true`, and `purchaseDate` to today
  only when it is null. All other fields are kept. A snackbar confirms "Moved
  to your active gear". Providers are invalidated as for any equipment update.
- The header chip shows the real status for inactive items (see carve-outs).

### Equipment summary (`equipment_summary_widget.dart`)

- Total items and total value (per currency) cover everything except Wanted.
- Active keeps counting `isActive`, which already excludes Wanted.
- When at least one Wanted item exists: a "Wanted" count card, and a
  "Wanted value (<ISO code>)" card per currency, built with `sumByCurrency`.

### List and filter

- The status filter sheet builds its chips from `EquipmentStatus.values`, so a
  Wanted chip appears with no change; its rows come from the generic
  `status == wanted` branch of the filter query.
- List rows already badge any status other than Active.

## Localization

New keys, translated in all 11 locales (ar, de, en, es, fr, he, hu, it, nl,
pt, zh):

- `enum_equipmentStatus_wanted`
- expected price label
- Mark as purchased action and its confirmation snackbar
- summary Wanted count label and Wanted value label (with currency code)

## Testing (TDD)

- Repository: Wanted excluded from `getActiveEquipment` and
  `getRetiredEquipment`; returned by `getEquipmentByStatus(wanted)`; not
  returned by `getEquipmentByStatus(retired)`; mark-as-purchased flips status
  and `isActive`, sets today's date when empty, keeps an existing date.
- Unit: `departedStatusOf` returns Wanted for Wanted; `isFitted` is false.
- Filter query: default view excludes Wanted; Wanted chip returns only Wanted.
- Set apply: a Wanted member is skipped.
- Widgets: edit form hides and relabels while Wanted and restores the fields
  when the status changes; detail page button marks the item purchased; header
  chip reads Sold for a sold item and Wanted for a wanted one; summary shows
  Wanted cards and keeps Wanted out of totals; cylinder-config and pre-dive
  dropdowns omit Wanted.
- `test/architecture/` after adding files under `lib/`.

## Out of scope

- A dedicated wishlist screen or navigation entry.
- Priorities, target dates or reminders for wanted items.
- Changing how Retired set members are applied.
