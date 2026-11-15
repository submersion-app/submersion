# Raw dive computer data moves to Settings > Data

## Intent

Discarding the raw dive computer data Submersion keeps from each download
(issue #1376) is a data management action, not a dive computer one. Today it
sits on the dive computer pages: a library-wide tile pinned above the Dive
Computers list, and a per-computer button on each computer's page. Both move
to Settings > Data, where the rest of the data management lives.

## Goals

- One place for raw dive computer data: Settings > Data > Advanced > Data
  tools > Raw dive computer data.
- Keep every capability: discard all, and discard one computer's.
- The dive computer pages carry no discard controls afterwards.

## Non-goals

- No change to what a discard does (the service, sync stamping, fingerprints
  kept) or to its dialogs and messages.
- No change to re-parsing (Re-parse dives page, the per-computer
  "Re-parse all" button and its raw-data counts stay where they are).

## Anti-goals

- Losing per-computer discard as a side effect of the move.
- Putting discard on the Re-parse dives page: re-parse and discard are
  opposite decisions, and delete buttons on a re-parse page read as a trap.

## Approaches

1. **Raw dive computer data page in Data tools (chosen).** A new tool row
   opens a page with the total and a discard-all action, then a by-computer
   breakdown with a discard per computer. Nothing is lost; costs one page and
   a per-computer usage query.
2. Move the existing tile as-is into Data tools. About a dozen lines, but
   drops per-computer discard.
3. Fold discard into the Re-parse dives page. Ruled out (see Anti-goals).

## Design

```
Raw dive computer data
  148 dives, 6.2 MB. Kept so these dives can be re-parsed...
  [Discard all]

  By dive computer
  Perdix 2           112 dives, 4.8 MB   [Discard]
  Teric               36 dives, 1.4 MB   [Discard]
  Unknown computer     4 dives, 0.1 MB
```

- **Entry:** a Data tools row (title "Raw dive computer data", a short
  subtitle), shown on every platform: a browser cannot download, but synced
  raw data can still be discarded there.
- **Page:** the total line reuses `diveComputer_rawData_tileSubtitle`; Discard
  all reuses `confirmAndDiscardRawDiveData` with the discard-all message. Each
  computer row reuses the per-computer confirm flow and message. Counts and
  sizes refresh on any `dive_data_sources` change, as the tile does today.
- **Unknown computer:** raw data whose computer entry was deleted is listed
  with no Discard of its own; Discard all clears it.
- **Empty:** with no raw data the page says so and shows no actions.
- **Scope:** library-wide, every diver, matching what a discard already
  covers and what the tile showed.
- **Removed:** `RawDiveDataTile` from the Dive Computers list, and the
  per-computer Discard button from each computer's page.
- **Docs:** `docs/user/settings.md` (Data tools) gains the new tool.

## Left to the builder

- The query for per-computer usage (dives and stored bytes per
  `computer_id`), likely a `RawDiveDataService` method beside `getUsage`.
- How a computer row gets its display name (the computer entity's
  `displayName`, or the same fallback in SQL).
- Strings for the tool row subtitle, the section header and the empty state.
