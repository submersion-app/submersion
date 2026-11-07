# Dive Computers nav shortcut and the browser lock for shortcuts

Issue: #4210. Builds on the nav shortcut catalog of #2936.

## Goal

1. Settings > Appearance > Navigation layout > Add shortcut offers
   **Dive Computers** (Transfer > Dive Computers). It opens like every other
   shortcut: on the alias route `/shortcut/transfer-computers`, as a
   top-level page with no back arrow.
2. A browser treats a shortcut's alias location the way it treats the page
   the shortcut opens, and the picker does not offer a shortcut whose page a
   browser cannot serve. This also closes the same gap for the existing
   Offline maps shortcut.

## The first shortcut whose page lives in a query

Dive Computers has no path of its own: the section is
`/transfer?selected=computers` on every width (the phone opens the section
page from the query, the desktop master-detail selects it from the same
query). Every shortcut so far has a plain `canonicalPath`, and three readers
treat it as a bare path:

| Reader | Today | With a query in `canonicalPath` |
| --- | --- | --- |
| `navShortcutDestination` (`extraMatchPaths: [canonicalPath]`) | prefix match on the page's path | `/transfer` would match every Transfer location, tying with the Transfer tab, so plain `/transfer` could select Dive Computers |
| `_canonicalOf` in `nav_selection.dart` | `Uri(path: canonicalPath)` | `?` is escaped into the path, so the alias location never maps back to Transfer |
| `demoSealedFeatureFor` | `Uri.parse(canonicalPath).path` | fine, but drops the query (no demo seal uses one today) |

`canonicalPath` stays a full location (path plus an optional query), and the
readers learn to parse it:

- `NavShortcut.canonicalUri` (`Uri.parse(canonicalPath)`), the single place
  that parses it.
- `navShortcutForLocation(Uri location)` in `nav_shortcuts.dart`: the
  shortcut whose alias location `location` is (`/shortcut/<id>`, a trailing
  `/...` and a query tolerated, as the demo seal does today), or null. It
  replaces the inline alias parsing in `demoSealedFeatureFor` and
  `_canonicalOf`.
- `navShortcutDestination`: a page addressed by a query is matched by its
  `selection` alone, so `extraMatchPaths` is empty when `canonicalUri` has a
  query. The alias route still matches the shortcut itself.
- `_canonicalOf`: the canonical location is `canonicalUri` with its query
  laid over the alias's. The alias always shows that one page, so a stray
  `?selected=` on the alias cannot point the selection at another section;
  a page without a canonical query keeps the alias query as today.
- `demoSealedFeatureFor` uses the shared helper too. Demo mode seals all of
  `/transfer`, so the new shortcut takes that seal, as the section does.

## Catalog entry

```dart
NavShortcut(
  id: 'transfer-computers',
  group: NavShortcutGroup.settingsAndTools,
  icon: Icons.bluetooth,
  label: (l10n) => l10n.transfer_section_computersTitle,
  navLabel: (l10n) => l10n.navShortcut_short_diveComputers,
  parentLabel: (l10n) => l10n.nav_transfer,
  canonicalPath: '/transfer?selected=computers',
  accent: 'transfer',
  selection: NavSelectionMatch(
    path: '/transfer',
    queryKey: 'selected',
    queryValue: 'computers',
  ),
)
```

- Id `transfer-computers`, not `dive-computers`: it names the page (the
  Transfer section), not the `/dive-computers` route, which is the separate
  device list.
- Icon and title are the Transfer section's own (`transfer_list_content.dart`),
  so the diver recognises the page.
- "Dive Computers" is wider than a bottom-bar slot in several languages, so
  it gets a short nav label (`navShortcut_short_diveComputers`, "Computers"),
  translated in all ARB files like the other short labels.

## Page

`TransferComputersPage` in `lib/features/transfer/presentation/pages/`: a
`Scaffold` with an `AppBar` titled `transfer_section_computersTitle` and
`ComputersSectionContent` as the body. No leading back button: the alias
route has no parent, so go_router builds it as a one-page stack and the
AppBar shows none on its own. `kNavShortcutPages['transfer-computers']`
builds it.

The passive auto-connect scan needs nothing new: `ComputersSectionContent`
subscribes to `computersRouteObserver`, which `GoRouter.observers` merges
into every shell navigator, and the alias route sits in the same shell as
`/transfer`.

## Browser lock

- `webUnavailableFeatureFor` resolves an alias location through
  `navShortcutForLocation` to the shortcut's `canonicalUri` before it checks
  the route prefixes and the page sections. `/shortcut/transfer-computers`
  then locks as `/transfer?selected=computers` does, and
  `/shortcut/offline-maps` as `/settings/offline-maps` does.
- `showNavShortcutPicker` takes an optional `isAvailable` predicate (default:
  every shortcut). `NavOrderEditor` passes one built from
  `deviceCapabilitiesProvider`: a shortcut is available when
  `webUnavailableRedirect(caps, shortcut.canonicalPath)` is null. The picker
  stays a plain widget, so its tests need no provider scope.
- A shortcut already in a nav order (synced from a native device) stays on
  the nav in a browser and opens the "not available in a browser" page, as a
  bookmark to the page itself does. Hiding it would silently change a
  layout the diver made on another device.

## Tests (written first)

- `nav_shortcuts_test.dart`: catalog count 40; `transfer-computers` has a
  short nav label shorter than its label; a query-addressed shortcut has no
  extra match paths and keeps its selection; `navShortcutForLocation` for an
  alias, an alias with a trailing segment and a query, an unknown id and a
  non-alias location.
- `nav_selection_test.dart`: `/transfer` selects the Transfer tab even with
  the Dive Computers shortcut listed first; `/transfer?selected=computers`
  and `/shortcut/transfer-computers` select the shortcut; with the shortcut
  not on the surface, `/shortcut/transfer-computers` selects Transfer.
- `nav_shortcut_pages_test.dart`: `transfer-computers` builds a
  `TransferComputersPage`.
- `web_unavailable_routes_test.dart`: `/shortcut/transfer-computers` and
  `/shortcut/offline-maps` lock; `/shortcut/records` and an unknown id do
  not.
- `nav_shortcut_picker_test.dart`: an `isAvailable` that rejects an entry
  leaves it out of the list.
- Demo seal tests stay green on the shared helper.

## Out of scope

- A shortcut that opens the section inside Transfer with a back arrow to the
  Transfer list: rejected in #4210 so that every shortcut behaves the same.
- Hiding built-in nav destinations in a browser.
