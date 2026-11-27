# Equipment detail card order and visibility

Issue: #4975

## Goal

The cards on a gear item's page come in a fixed order. The diver can now
reorder them and hide the ones they do not need, under
**Settings > Appearance > Equipment > Equipment Details**, the way Site
Details already works (#1884).

## Decisions

- **One order for every type.** A card a type does not have (dive computer,
  transmitter, passport, twin set, unit configurations, ...) is skipped
  where it sits. One order per type would multiply the settings for little
  gain.
- **The passport is one block.** The cylinder passport entry (fills,
  inspection, tag, trip) and the gear passport entry of other gear are one
  section, `passport`; the passport page has its own layout.
- **Cards can be hidden.** A hidden card that can be edited still reaches the
  page while it is unlocked: it waits on the add strip, marked hidden, as
  on Site Details (#4527). Calculated cards (exposure, condition trends,
  sharing history) are simply not built while hidden.
- **The header stays pinned.** Name, photo and status are not a section.
- **The order applies while unlocked**, and to a new item's page, so no
  card jumps when the page unlocks.
- **No in-page display-options menu and no list layout.** The issue asks for
  the order and visibility only; both can follow later.

## Sections

`EquipmentDetailSectionId`, declared in today's page order, which is the
default order:

| Section | Edit card | Shown when |
|---|---|---|
| diveComputer | diveComputer | type is computer |
| details | details | always |
| transmitter | - | type is transmitter |
| location | location | always |
| passport | - | stored item; tank, or not wishlist |
| twinSet | twinSet | type is tank |
| serviceClocks | serviceClocks | not wishlist |
| exposure | - | stored item |
| condition | conditionFindings | stored item (findings, trends) |
| childItems | - | type hosts children |
| photos | photos | stored item |
| observations | observations | stored item |
| components | components | stored item |
| unitConfigurations | - | type is rebreather |
| linkedFiles | legacyFiles | stored item, while files are left |
| sharingHistory | - | two or more profiles |
| serviceHistory | serviceHistory | stored item |
| notes | notes | notes, or open in the sitting |
| documents | documents | always |

## Layout

Today some cards bring their own gap (they hide themselves after loading)
and others get one from the page. The body now uses one rule: **every
section brings its own top gap of 24**. The self-hiding cards already put
theirs on top, except `DiveComputerSection`, whose bottom gap moves to the
top. With that rule the default order renders exactly as before.

## Storage and sync

- `diver_settings.equipment_detail_sections` (TEXT, nullable), schema
  v391, JSON in the `site_detail_sections` shape. Null reads as the
  defaults. Additive and nullable, so the sync floor does not move; it
  syncs on the diver settings row.
- `EquipmentDetailSectionConfig` reuses `detail_section_order.dart`: a saved
  order is kept, unknown ids are dropped, and a card added later joins after
  its nearest preceding card.
- `AppSettings.equipmentDetailSections`, `setEquipmentDetailSections`,
  `resetEquipmentDetailSections`, the conflict catalogue entry and the agent
  SQL column note.

## Tests

- Config: the default order matches the page's former order, JSON round
  trip, unknown ids dropped, a missing card joins a saved order where the
  default puts it, garbage reads as the defaults.
- Settings: setter and reset, repository round trip.
- Settings page: lists every card, toggling and reordering are saved, reset.
- Detail page: a hidden card is not built, a saved order is applied, a hidden
  editable card appears on the add strip while unlocked.

## Risks checked

- **Card jumps between locked and unlocked:** both read the same order.
- **Hidden details card on a new item:** the details card waits on the
  strip, the diver can still bring it in before saving.
- **Spacing drift:** covered by the one-gap rule; the self-hiding cards
  keep their gaps inside, so a hidden or empty card leaves no gap.
- **Schema number collision:** renumber on merge if another PR takes 391.
