# Media: Import, Transfers and Sources as top-bar buttons

Date: 2026-11-15. Release: v1.8.5.

## Why

Media > Photos/Videos shows five tabs: Library, Gear, Sources, Transfers and
Import. Only Library and Gear are places to browse. Import, Transfers and
Sources are actions, so they read wrong as tabs. The Import tab makes this
plain: its whole page is one "Import media..." button.

## Goals

- The tab strip holds only places to browse: Library and Gear.
- Import, Transfers and Sources become buttons at the end of the tab row, at
  every width.
- No feature is lost: the import flow, the transfer queue, browse by source,
  watched folders, Scan now and auto-apply all stay reachable from Media.

## Non-goals

- No change to the import flow itself, the desktop drop-to-import, the
  transfer queue's behaviour, or the watcher.
- No change to Settings' own Transfers and Media Sources pages, beyond
  Media's Transfers button reusing the Transfers page.
- No new badge on the Transfers button (the tab had none).

## Anti-goals

- An extra header row on phones. The buttons share the tab row.
- Moving watched-folder setup out of the Media section.

## Approaches considered

1. **All three become buttons (chosen).** Sources opens its existing screen
   as a page of its own. Everything stays in Media; the strip is Library and
   Gear.
2. Move Sources to Settings > Media Sources and drop browse by source (the
   Library filter sheet has a Source filter). Leanest bar, but folder setup
   leaves Media.
3. Keep Sources a tab and move only Import and Transfers. Smallest change,
   but leaves one action among the tabs.

Eric picked 1.

## Design

```
Photos/Videos | Documents
Library   Gear                 [Import] [Transfers] [Sources]
```

- **Tabs:** Library and Gear. The Library's missing-files badge stays.
- **Buttons:** icon buttons with tooltips, at the trailing end of the tab
  row, in both the phone app bar and the desktop pane header.
  - **Import** opens the picker straight away (the same flow the Import tab's
    button and a desktop drop start), then the review page as today.
  - **Transfers** pushes the Settings Transfers page (queue list plus Clear
    completed and multi-select) as a page over Media; Back returns to Media.
    Opened from Media the page is titled Transfers, matching the button;
    Settings keeps calling it Uploads (decided during the build).
  - **Sources** pushes the existing Sources screen in a page with its own app
    bar. Tapping a source sets the Library filter as today, closes the page,
    and selects the Library tab (even if Gear was showing).
- **Web:** only the Transfers button shows; the browser can neither import
  nor watch folders (unchanged from today's tab set).
- Import and Sources keep the demo seal guards they have today.

## Left to the builder

- Icon choice for each button.
- Whether `MediaImportView`'s now-unused page body is deleted (its static
  `launchImport` stays, since the desktop drop uses it).
- Tab-row layout mechanics (the strip must stay scrollable and leave room for
  the buttons at narrow widths).
- Dropping strings that no longer show (`media_console_import`,
  `media_console_transfers`, `media_import_intro`) only if nothing else uses
  them.
