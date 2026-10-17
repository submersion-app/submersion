# Training: one nav entry for Certifications and Courses

Date: 2026-10-17. Target release: v1.8.3.

## Why

The main nav list is too long, and Certifications and Courses are two entries
for one topic. They are not even next to each other today (Certifications sits
after Dive Centers, Courses after Documents). Merging them into a single
**Training** entry shortens the list by one and puts the two together.

How the diver uses them decides the shape:

- **Certifications is the main job.** The diver goes there to look up their
  certification cards: the card images and the card details (number, agency,
  date, instructor). Reaching a card must stay as quick as it is now.
- **Courses is the secondary job.** The diver opens it to reminisce or to
  explore their training data, not for anything time-critical.

## Goals

- One nav entry, labelled **Training**, replaces the Certifications and
  Courses entries on every nav surface (desktop rail, phone bottom bar, phone
  More sheet, nav customization in Settings).
- Training opens on Certifications. Courses is one tap away.
- Both screens keep everything they do today.

## Non-goals

- No change to the Certifications or Courses screens' content, list rows,
  detail pages, edit pages, wallet, table columns, sort or search. (Their
  headers change to carry the tab switch, and they now live inside the
  Training host page.)
- No new combined list, timeline or overview of certifications and courses
  together (considered and rejected: see "Rejected layouts").
- No data, schema or sync change.
- No change to the Certifications and Courses entries in Settings (section
  appearance, column configuration): they stay as two separate sections.

## Anti-goals (a failure even if it technically works)

- Any extra tap, or any extra wait, between opening Training and seeing the
  certifications list.
- Any existing link into a certification or course breaking: links from a
  dive's course row, a document's owner, search and query results, the card
  wallet shortcut, import flows, notifications.
- A diver who had Certifications or Courses placed in their bottom bar or
  rail losing that slot.

## The design (decided)

### Nav entry

- Label **"Training"**, placed where Certifications is now (after Dive
  Centers). The Courses entry is removed from its old place after Documents.
- Training is a movable entry like the two it replaces.
- Tapping Training opens the Certifications screen.
- Training is the selected nav entry on any certification or course page
  (lists, details, edit pages, the wallet).

### The screen: two tabs

Chosen layout (option A from the brainstorming mockups): **Certifications |
Courses**, opening on Certifications.

- The Certifications tab is today's Certifications screen, unchanged: search,
  sort, view mode (list and table), select items, the wallet button, the add
  button, and on desktop the master-detail layout (list left, details right).
- The Courses tab is today's Courses screen, unchanged, in the same way.
- The tab switch is present in every layout of both screens: phone, desktop
  master-detail, and table mode. Table mode must not hide it, because there
  is no other way to reach Courses from the Certifications screen.
- **Swiping (user decision).** On phone layouts the diver can swipe left and
  right between the two tabs, as Equipment | Sets does. Desktop layouts switch
  by clicking the tab only (my call, matching Equipment, where a sideways
  trackpad gesture would otherwise fight the list and table).
- **Each tab keeps its place (user decision).** Switching to the other tab and
  back returns the first tab exactly as it was: scroll position, search text,
  filters, multi-select selection, and on desktop the item open in the detail
  pane (including an edit or create form in progress). This holds for tab
  switches within Training; leaving Training for another nav entry and coming
  back may start fresh, as every other section does today. This goes beyond
  Equipment, which keeps its place on phone but clears the open item on
  desktop.
- The Courses tab is built the first time the diver opens it, so opening
  Training costs nothing extra over opening Certifications today (my call).
- Training always opens on the Certifications tab when entered from the nav.
  It does not remember that the diver was last on Courses.

### Addresses stay where they are

- `/certifications/...` and `/courses/...` stay valid and unchanged. They are
  the two tabs. Every existing link (a dive's course row, document owners,
  search results, the wallet shortcut and so on) keeps landing on the right
  screen with no change at the call site.
- A new `/training` address opens the Certifications tab.

### Saved nav layouts carry over

- A stored nav order that contains `certifications` or `courses` reads either
  as `training`, in the slot of whichever came first. The second one is then a
  duplicate and is dropped. This is the same mechanism GPS Log to Tracks used
  (#2833, `kRenamedNavIds` in `lib/shared/widgets/nav/nav_id_aliases.dart`).
- Downgrade safety: when the order is saved, `certifications` is written right
  after `training` (as `withLegacyNavIds` does for a rename) so an older build
  that reads the order puts Certifications in Training's slot. `courses` is
  not written: the older build appends it in its canonical place. Writing both
  side by side would make an older build put Courses in the next slot too,
  pushing another destination out of the phone bottom bar or promoting
  Courses out of More. (Builder check; my call.)

## Constraints and things the builder must know

- **The alias map is one-to-one today.** `kRenamedNavIds` maps one old id to
  one new id, and `withLegacyNavIds` inverts it (`new -> old`), which keeps
  whichever old id comes last in the map. Two old ids now map to `training`,
  but only `certifications` should be written back (see "Saved nav layouts
  carry over"), so the inversion must pick that one deliberately rather than
  by map order.
- **Header accent icon lookup.** `FeatureAppBarTitle` finds a header's accent
  icon by looking its feature id up in `kNavDestinations`. Removing the
  `courses` destination would silently drop the Courses header's icon, which
  must stay. The lookup needs another source for `courses` (and
  `certifications`, if the destination id changes).
- **Back after switching tabs.** A tab switch replaces the current page rather
  than stacking or resetting it: system back from either tab goes where it
  went before the switch (Home after a nav tap; Home again when the Home
  attention chip pushed `/certifications`). It never steps back to the other
  tab. (Builder check; my call.)
- **Nav selection** is a segment-aware prefix match on the destination's
  `route` plus `extraMatchPaths` (`lib/shared/widgets/nav/nav_selection.dart`).
  Training needs to match `/training`, `/certifications` and `/courses`.
- **Header precedent: Equipment | Sets.** Equipment already switches between
  two sections from its header, with the two names sitting where the title
  would be and the current one in a pill
  (`lib/features/equipment/presentation/widgets/equipment_section_toggle.dart`,
  issue #2256 and #2776). Training reuses that look and behaviour so the app
  has one way of doing a two-section switch. Equipment drives it from one
  `TabController` with a `TabBarView` on phone, inside one page at one
  address. Training has two addresses, so it needs **one host page that stays
  mounted while the address changes** between `/certifications` and
  `/courses`, with the address kept in step with the tab (a swipe or a tab tap
  updates the address; navigating to either address selects its tab). On
  desktop each tab's selection lives in the query string (`?selected=`, and
  the edit and create modes), so the host remembers each tab's query and puts
  it back when the diver returns to that tab.
- **This host page is the risky part of the build.** go_router decides
  whether a page is rebuilt or kept by its page key, and the tab switch must
  replace the current address (see "Back after switching tabs") without
  remounting the host. Candidates: both list routes return their page with
  the same page key so the Navigator updates the existing route in place, or
  a shell route around the two route trees. Prove the chosen mechanism keeps
  state across a switch in a widget test before building the rest on it.
  Detail, edit and wallet pages keep their current addresses and still open
  on top of the host as they do today.
- **Localization:** 11 locales (`lib/l10n/arb/`). New strings need all of
  them. The More sheet shows a destination's subtitle.
- **Architecture guards** in `test/architecture/` and adoption guards in
  `test/shared/` scan all of `lib/`; run them after adding files.
- **Nav shortcuts:** the Card wallet shortcut (`certification-wallet` in
  `lib/shared/widgets/nav/nav_shortcuts.dart`) keeps working unchanged. Its
  canonical path stays `/certifications/wallet`.
- Screenshots of the nav and both tabs, before and after, light and dark,
  phone and desktop, go in the PR (repo rule for UI changes).

## Calls made without the user (check these)

1. **Header style.** The tab switch is the Equipment-style title switch
   ("Certifications | Courses" in the header, current one in a pill) rather
   than a separate tab strip under a "Training" title as drawn in the mockup.
   It reuses an existing pattern and costs no extra vertical space. The nav
   entry still says Training.
2. **Subtitle in the More sheet:** "Certifications and courses", replacing
   Courses' old "Training & Education" subtitle.
3. **Icon and colour:** the nav entry uses the school (graduation cap) icon
   and the Certifications accent colour. Each tab's header keeps its own
   screen's accent icon and colour as today.
4. **Card wallet shortcut label** keeps "Certifications" as its parent label
   (it describes where the wallet lives, which is still the Certifications
   tab).
5. **Old Courses subtitle string** (`nav_coursesSubtitle`) is removed once
   nothing uses it. `nav_certifications` and `nav_courses` stay, since Settings
   and the tab names use them.
6. **Swipe on phone only.** Desktop switches by click, as Equipment does.
7. **Courses is built on first visit**, then kept, so opening Training is no
   slower than opening Certifications today.
8. **Back after a switch** goes where it went before the switch, never to the
   other tab.
9. **Downgrade write** carries only `certifications` after `training`.

## Left to the builder

- How the header switch is shared with Equipment (a shared widget generalized
  from `EquipmentSectionToggle`, or a sibling of it), and how it fits the
  phone app bar, the desktop pane header and the table-mode header.
- The host page mechanism (see "This host page is the risky part").
- Whether `/training` is a redirect or its own route.
- Test design, in TDD order, covering at least: nav id migration (one old id,
  both old ids in either order, downgrade write), nav selection on each
  address, `/training` landing, the switch working both ways in every layout,
  swipe on phone, each tab keeping its place across a switch (scroll, search,
  desktop open item), back after a switch, and the switch being reachable in
  table mode.

## Rejected layouts

- **Cards up top, courses below** (one scrolling overview page). Rejected for
  the two-tab layout.
- **One training timeline** mixing certifications and courses, newest first.
  Good for reminiscing, but the diver scans past courses to reach a card,
  which fights the main job.
