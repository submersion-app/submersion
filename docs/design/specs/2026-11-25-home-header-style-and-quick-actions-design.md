# Home header style and an optional Quick Actions card: Design

**Date:** 2026-11-25
**Status:** Approved
**Release:** v1.8.6
**Issue:** #5003
**Feature area:** `lib/features/dashboard/`, `lib/features/settings/`

## Why

v1.8.5 rebuilt Home as a technical dashboard (#4824, PR #4826). It replaced the
animated ocean welcome banner with a slim header bar and removed the Quick
Actions card, moving its actions into the bar's + menu. A diver on 1.8.5
(macOS and Android) reports in #5003 that Home now feels like it is missing
something: they liked the welcome banner, and they liked the Quick Actions
card.

The slim bar stays right for divers who want the dense dashboard. Divers who
preferred the old feel get it back by choice, not by default.

## Goals

- A **Header** choice in Settings > Home: **Compact** (today's slim bar) or
  **Banner** (the original welcome banner).
- Banner mode shows the original banner as it was, with a thin row under it
  that holds the + quick actions menu and the status lights.
- An optional **Quick Actions** card on Home that looks just like the
  original card.
- The header choice is made twice, once for phone width and once for wider
  screens, and saved on each device.

## Non-goals

- No change to Home for anyone who does not opt in: Compact stays the
  default, and the Quick Actions card is off by default in every preset.
- No change to the panel grid, the presets' panel lists, the status light
  rules or the + menu's contents.
- No return of the Milestones or Year in Review cards.
- Nothing about Home syncs: the header choices, like the panel layout, stay
  on the device. No database or schema change.

## Anti-goals

- A safety light (overdue gear, expired insurance, closed or conflicting
  flight window) becoming hidden in banner mode.
- Changing any existing diver's Home on upgrade.
- A banner that differs from the original beyond what this document lists.

## Decisions

Decided with the maintainer in conversation:

| Decision | Choice |
| --- | --- |
| How the banner returns | A Header setting that switches between the original banner and the compact bar (not a panel) |
| Default header | Compact |
| Where the + menu and lights go in banner mode | A thin row under the banner (option W); the banner itself stays as it was |
| Quick Actions | Comes back as an optional card on Home, looking just like the original card |
| Where the header choice is stored | On each device (SharedPreferences, next to the panel layout), not synced |
| How many choices | Two per device: one for phone width, one for wider screens (tablet and desktop), applied by the current window width |

Calls made by the author, for the maintainer to check:

| Call | Reason |
| --- | --- |
| The banner scrolls away with the page; the row under it pins to the top once the banner has gone; the compact bar stays pinned as today | The original banner scrolled, and pinning a 90 pt banner would take a large share of a phone screen; pinning the row keeps the + menu and the safety lights in view in both header styles |
| The banner switches between the headline and the desktop quiet stats at 800 pt (`ResponsiveBreakpoints.isDesktop`), as the original did, not at Home's 1200 pt desktop tier | "As it was" |
| In banner mode the page order is: demo-mode card, welcome banner, pinned row, species-model offer, panel grid | Demo mode's way out heads the page (#4436), as it did before PR #4826; the offer belongs with the panels below the header |
| Switching Quick Actions on in the panel list leaves it where it sits in that list (at the end for a preset layout, after Key numbers for an upgraded custom one); the diver drags it to move it | The same as every other panel switched on there |
| The diver avatar on the banner shows with any number of profiles and opens the switcher sheet | Matches the always-shown diver pill approved in #4985 (2026-11-23); the original avatar hid below two profiles |
| Quick Actions is a Home panel (`quickActions`) in the panel list, hidden in every preset | "Optional" on today's Home means a panel the diver switches on and places; it arrives hidden for existing layouts with no migration |
| Quick Actions keeps all six original buttons, Insights and Tracks included | "Just like the original card" |
| Quick Actions is drawn as the original `Card`, not a filled panel | "Just like the original card"; it may look different from the panels beside it |
| The row under the banner uses today's light chips: the full scrolling list from tablet width up, the phone strip's short form on a phone | The lights must look and behave the same in both header styles |
| "Phone width" is Home's existing phone tier (below 800 pt, `homeWidthTierOf`); "wider" is the tablet and desktop tiers together | Home already switches its layout at that width; a third choice for tablet would be one more setting for little gain |
| Nothing stored reads as Compact for both widths | Existing divers see no change on upgrade |

## Approaches

For the header choice:

1. **A Header setting, banner restored as its own widget (chosen).** A device-local
   enum setting picks which header the page builds. The original banner is
   restored from git history as a widget; the compact bar is unchanged.
2. **Banner as a Home panel.** Rejected by the maintainer: the banner is a
   header style, not a panel among panels.

For where the choice is stored:

1. **Per device, one choice for each width class (chosen).** A phone-width
   window and a wide one can each have their own header, and a resized
   desktop or tablet window switches as it crosses the phone width.
2. **Per device, one choice.** Simpler, but a narrowed desktop window would
   keep a header chosen for a wide screen.
3. **Synced with the diver.** Considered and then dropped by the maintainer
   in favour of per device; it would also have needed a schema column and
   sync and conflict handling.

## The header setting

- `HomeHeaderStyle` enum: `compact`, `banner`. Stored by `name`; a missing or
  unknown stored value reads as `compact`.
- Two device-local SharedPreferences keys beside `home_panel_order` in
  `SettingsKeys`: `home_header_style_phone` and `home_header_style_wide`.
  Carried in `AppSettings` and `SettingsNotifier` the way the panel layout
  keys are (read at load, written on change), and kept out of the synced
  diver settings.
- `DashboardPage` reads the one for the current tier: phone tier reads the
  phone key, tablet and desktop read the wide key. Crossing the phone width
  while the app runs switches the header at once.
- No schema change, no migration, nothing synced.

## Settings > Home

`home_appearance_page.dart` gains a **Header** section above the layout
picker with two rows, **Phone width** and **Wider screens**, each a
two-option selector, Compact and Banner. A line under the section says what
each looks like (Compact: "A slim bar with status lights"; Banner: "The
welcome banner with your dive totals") and that the choice is saved on this
device. Changing either applies at once.

## Banner mode

`DashboardPage` builds these inside the scroll view, after the demo-mode card
and before the species-model offer and the panel grid:

1. The **welcome banner**, restored from `hero_header.dart` as it was before
   PR #4826 (commit `dce6b49217b^`):
   - `OceanBackground` (still in `lib/core/presentation/widgets/`) with a 20
     pt corner radius, 12 pt outer margin.
   - Leading: the diver avatar (restored `hero_diver_avatar.dart`), shown
     with any number of profiles, opening `showDiverSwitcherSheet`.
   - The greeting: "Good morning / afternoon / evening, <first name>!" by
     the local hour, with the original loading and error fallbacks.
   - Below 800 pt: the headline under the greeting ("<n> dives logged •
     <h> hours underwater", or "<n> dives" when the diver has prior dives,
     one item per line below 600 pt; the no-dives and all-excluded lines as
     before). From 800 pt (`ResponsiveBreakpoints.isDesktop`, as the
     original): the quiet stats (dives, hours, sites, countries) in the
     middle. `dashboardQuickStatsProvider`, which gave the countries count,
     comes back from history if nothing else provides it.
   - The app icon, 64 pt, at the trailing end. In this mode it opens About
     Submersion (the compact bar's logo does today; the original was
     decorative).
   - The semantics label "Dashboard greeting banner".
2. The **banner row**, about 40 pt tall, in the surface colour with a
   hairline bottom border, pinned to the top once the banner has scrolled
   away (a pinned persistent header):
   - The + quick actions menu (the same `_QuickActionsMenu` the compact bar
     uses, made shareable), at the leading edge.
   - The status lights: from tablet width up, the same scrolling list of
     dense chips the compact bar shows; on a phone, the phone strip's short
     form (amber and red lights named, the rest counted, "All clear" when
     nothing needs attention). The retry chip shows when the lights fail to
     load. Safety lights show even when hidden, as everywhere today.

In banner mode the compact bar and the phone status strip are not built.
Pull to refresh still reloads everything, including the career totals the
banner reads.

## Quick Actions card

- New `HomePanelType.quickActions`, declared after `keyNumbers`. Hidden in
  every preset; existing stored layouts get it hidden, after Key numbers,
  through `resolveHomeLayout`'s usual slotting. A preset layout lists it
  with the other hidden panels at the end.
- Width `sList` (a third of a desktop row, half a tablet row, a full phone
  row). A new height class sized to the original card: title plus six
  full-width buttons, about 340 pt at text scale 1 (scaled like the other
  heights). Panels sharing its row on desktop grow to that height.
- Content restored from `quick_actions_card.dart` (commit `dce6b49217b^`):
  a `Card` with the "Quick Actions" title and, in a column:
  Log Dive (filled, opens the add-dive sheet), Plan Dive (tonal, opens the
  dive planner), Swap with a buddy (only where the device has the radios),
  Insights (outlined, goes to Insights), Tracks (outlined, goes to Tracks),
  Emergency card (outlined, opens the emergency card).
- Listed in the panel list in Settings > Home by its name like
  every panel; its provider-free build means hiding it costs nothing.

## Strings

Restore in all 11 locales, from the translations in git history at
`dce6b49217b^`: the greeting strings (`dashboard_greeting_*`), the banner
strings (`dashboard_hero_*`), `dashboard_semantics_greetingBanner`, and
`dashboard_quickActions_sectionTitle` and `dashboard_quickActions_insights`
if no longer present. New strings (the Header setting's title, the two option
names and descriptions, and the Quick Actions panel's name in the panel list
if it needs one) go in all 11 locales.

## User docs

`docs/user/` pages that describe Home and Settings > Home (Dashboard,
Settings, Customize display) mention the Header choice and the Quick Actions
card.

## Testing

- Setting: both keys default to `compact` with nothing stored; each stored
  value is read back on load; an unknown stored value reads `compact`;
  changing one key leaves the other alone.
- Page: Compact builds the bar and (phone) strip and no banner; Banner builds
  the banner and its row and neither the bar nor the strip. Phone width
  follows the phone key and wider widths the wide key, including a resize
  across 800 pt.
- Banner: the restored banner tests (greeting by hour, first name and
  fallback, prior-dives wording, no-dives and all-excluded lines, quiet
  stats on desktop, narrow line breaks), the avatar with one diver, and the
  logo opening About.
- Banner row: the + menu opens the four actions; a safety light shows even
  when hidden; phone short form; retry chip on error; the row stays on
  screen after the banner scrolls away.
- Page order in banner mode: demo card, banner, row, species offer, grid.
- Quick Actions: the six buttons and their destinations; Swap absent where
  unsupported; hidden in every preset; an existing stored layout gets it
  hidden; no overflow at phone and desktop widths and at text scale 2.
- Layout: the packing tests still fill every row with the new height class
  present.

## Left to the builder

- Exact banner row paddings, within "thin row under the banner".
- How the + menu is shared between the bar and the banner row.
- The new height class's name and exact base value, so the original card
  fits without overflow.
- Where the Header section sits on the Settings page and which selector
  widget it uses, matching the page's existing controls.
- File layout; one file per restored widget is expected.
