# Shared dive-site library: design

Issue: #2567. Release: v1.8.3.

## Problem

Sharing between profiles is all-or-nothing inside one synced library. A dive
group cannot keep a common site catalogue (notes, hazards, access, mooring,
parking) without also sharing personal dives, and one member's deletion
reaches every profile (#2151). The group in #2567 has about fifty divers who
each keep a personal logbook and want one site catalogue that everyone reads,
most edit, and a few referents control.

## Outcome

A diver connects a shared site library hosted on storage its members control (an S3
bucket or a WebDAV folder, with a prefix). The library's sites appear in the
Sites list, map, filters and site picker beside personal sites, and dives link
to them like any site. Edits to a library site sync both ways, field by field,
with the member who made each edit recorded. Members choose which personal
sites to add to the library. Owners manage roles and review suggestions from
read-only members. Personal dives never leave the personal library, and library
sites never enter it.

## Decisions taken in design

| Question | Decision |
| --- | --- |
| Scope for v1.8.3 | Everything in the issue: library, attribution, roles |
| Enforcement | Storage credentials are the hard boundary; a roles file in the library drives the UI and the suggestion workflow |
| Member identity | One member id per diver profile, synced, so every device of a profile is the same member |
| Merge | Per field, last writer wins, no conflict cards |
| Site payload | All site columns, site types, tags, species, mapped features; no media |
| Push | The personal row becomes the library site, same id |
| Referent delete | Members with dives on the site keep a personal copy; others lose it |
| Suggestions | Proposed field edits with a note, reviewed by owners |
| Approach | Separate subsystem with one document per site; library sites stored in `dive_sites` |

## Storage layout

Every library lives in `submersion-sites` at the top of the bucket or server,
beside `submersion-sync` and `submersion-media`, under the folder the owners
chose (`site-sync` is `submersion-sites/site-sync/`; an empty folder is
`submersion-sites` itself). All files are JSON.

| File | Written by | Content |
| --- | --- | --- |
| `submersion-shared-library.json` | creator, once | library id (UUID), name, `formatVersion: 1`, created-by member id, created-at |
| `members/<memberId>.json` | each member | display name, joined-at, app version |
| `roles.json` | owners | `{ "owners": [memberId], "editors": [memberId] }`; unlisted members are readers |
| `sites/<siteId>.json` | editors and owners | the site document |
| `suggestions/<suggestionId>.json` | any member | a proposed edit |

A prefix with no manifest is not a library: the connect flow offers to create
one there. A manifest with a `formatVersion` above 1 marks the library "needs
a newer app" and nothing is read or written.

### Site document

The site id is the UUID of the `dive_sites` row, so one document maps to one
local row on every device.

```json
{
  "id": "…",
  "formatVersion": 1,
  "deleted": false,
  "fields": {
    "name": "…", "description": "…", "latitude": 0, "longitude": 0,
    "minDepth": null, "maxDepth": null, "difficulty": null,
    "waterType": null, "bodyOfWater": null, "city": null, "island": null,
    "country": null, "region": null, "rating": null, "notes": "…",
    "hazards": "…", "accessNotes": "…", "mooringNumber": "…",
    "parkingInfo": "…", "altitude": null, "entryMethod": null,
    "exitMethod": null,
    "siteTypes": ["Reef", "Wall"],
    "tags": ["Group favourite"],
    "species": [{ "name": "…", "scientificName": "…" }],
    "features": [{ "id": "…", "type": "…", "name": "…", "latitude": 0,
                   "longitude": 0, "bearingDeg": null, "depthMeters": null,
                   "notes": "" }]
  },
  "clocks": {
    "name": { "hlc": "…", "memberId": "…" },
    "deleted": { "hlc": "…", "memberId": "…" }
  }
}
```

Every `dive_sites` column travels except `diverId`, `isShared`, `createdAt`,
`updatedAt` and `hlc`. Each child list (`siteTypes`, `tags`, `species`,
`features`) is one clocked field and merges as a unit. `deleted` is a clocked
field, so a delete is an ordinary edit and a later undelete wins it back.
Clocks reuse the existing `Hlc` class with the member id as node id, so a
clock already names its editor. Unknown keys in a document are preserved on
round trip so a newer app's additions survive an older app's upload.

## Sync

`SharedLibraryService.sync(libraryId)` runs one library at a time and never
overlaps itself or a personal sync (one shared in-flight guard, see Triggers).

1. Read the manifest. Missing, unparseable or newer format: record the state
   and stop.
2. Download `roles.json` and list `members/`; refresh the local role and
   member caches. Write our own member card if it is missing or our display
   name changed.
3. List `sites/`. For each entry whose `modifiedTime` differs from the one
   stored in `shared_site_state`, download and merge the document. An entry
   with no local row creates one.
4. For each site whose state row is dirty, build the document from the local
   row and clocks, upload it, then read its `modifiedTime` back with
   `getFileInfo` and store it, so a concurrent overwrite is not mistaken for
   our own write. A permission error flips `readOnlyDetected` and leaves the
   site dirty.
5. Upload pending outgoing suggestions. Owners list `suggestions/` and
   download new ones; a locally held suggestion whose file has gone is
   dropped.
6. Record `lastSyncAt` and clear or set `lastError`.

### Merge

Per clocked field: the greater HLC wins, a tie keeps local, a missing clock is
treated as oldest. A winning remote field overwrites the local column and
clock. A winning local field leaves the site dirty so the merged document is
uploaded. A member whose upload was overwritten still holds their clocks, so
the next sync re-merges and re-uploads them; the folder converges without
compare-and-swap.

Local edits to a library site stamp the edited fields with a fresh HLC under
the member id and set the dirty flag, in the site repository write path.
Child edits (types, tags, species, features) stamp their list's clock.

### Change detection

`listFiles` returns `modifiedTime` on S3 and WebDAV, so one list call finds
changed documents. A document whose time moved but merges to no change costs
one download.

## Local data model

New tables in `lib/core/database/tables/shared_library_tables.dart`, one
migration rung (289), with a `beforeOpen` backstop in a part file per the
repository's rules.

| Table | Synced | Columns |
| --- | --- | --- |
| `shared_libraries` | no | id, name, connectedAccountId, prefix, formatVersion, readOnlyDetected, rolesJson, lastSyncAt, lastError |
| `shared_library_members` | no | libraryId, memberId, displayName, joinedAt; PK (libraryId, memberId) |
| `shared_library_memberships` | yes | id, diverId, libraryId, memberId, displayName, libraryName, backendKind, locationHint, createdAt, updatedAt, hlc |
| `shared_site_state` | no | siteId PK, libraryId, clocksJson, remoteModifiedTime, dirty, lastEditorMemberId, lastEditedAtMs |
| `shared_site_suggestions` | no | id, libraryId, siteId, memberId, memberName, note, fieldsJson, createdAt, direction (outgoing, incoming), status (pending, uploaded, withdrawn), remoteModifiedTime |

`dive_sites` gains a nullable text column `sharedLibraryId`. A library site is
a `dive_sites` row with that column set, `diverId` null and `isShared` false.
The column is not on the personal-sync wire (see the boundary below).

`shared_library_memberships` is a synced entity registered the usual three
ways (table, serializer cases and `parentRefs`, `hlcTargets`). `locationHint`
holds the bucket or host plus prefix, never credentials. The member id is
generated once per diver profile on the first join and reused for every
library.

Site types and tags arrive by name and resolve case-insensitively against the
subscribing diver's vocabulary, created when missing and owned by that diver.
Species resolve by scientific name, then common name, created when missing.
Features keep the ids in the document.

### Visibility

`VisibilityFilter.applyToDiveSites` and `sqlFragment` for sites gain one
clause: a row is visible when its `sharedLibraryId` is in the set of library
ids the current diver holds a `shared_library_memberships` row for. The query
language site filter and the name index use the same fragment. Hides still
apply. `SharedItemPolicy` gets a library branch: a library row is never
"ownerless, anyone may destroy"; destroy and edit follow the role.

### Personal-sync boundary

Three guards in the existing pipeline, nothing else changes there:

1. `_exportDiveSites`, the site child exports and the base export skip rows
   whose `sharedLibraryId` is set.
2. `_mergeEntity` ignores an incoming personal `diveSites` row, or a site
   child row, whose local site belongs to a library.
3. Deleting a library row locally logs no personal tombstone, and
   `_applyRemoteDeletions` ignores a personal tombstone for a library row.

A second device of the same member receives the membership through personal
sync but holds no library rows until it connects the library with its own
credentials. A dive linked to a library site on an unconnected device shows
the site as "in shared site library, not connected on this device" with a link to
connect. A stale personal copy from before a push is adopted in place on
connect, since the ids match.

## Behaviour

### Connect, create, join

Settings > Shared site libraries > Connect a library: pick or add an S3 or WebDAV
connected account, enter the prefix, read the manifest. No manifest: "Create
library" asks for a name, writes the manifest and `roles.json` with the
creator as owner. Manifest present: "Join". Both write the member card and a
membership row, then run a first sync.

### Roles

Effective role on a device is the lower of the `roles.json` role (owner,
editor, reader when unlisted) and what the credentials allow. The credential
check is passive: a permission error on upload sets `readOnlyDetected` and the
UI switches to the reader experience with an explanation. The documented
storage policy: referents get full access; everyone else gets read everywhere
plus write to `members/` and `suggestions/`.

| Role | Can |
| --- | --- |
| reader | see sites, link dives, hide sites, suggest edits, rename themselves, leave |
| editor | reader, plus add personal sites, edit library sites, delete and undelete them |
| owner | editor, plus manage roles, rename the library, accept and dismiss suggestions |

Owners manage roles on the Members page, which rewrites `roles.json`. The
last owner cannot be demoted.

### Push ("Add to shared site library")

Editors and owners, personal sites only. Sets `sharedLibraryId`, clears
`diverId` and `isShared`, seeds a clock for every field with a fresh HLC
under the member id, snapshots children by name, inserts a dirty state row.
Dives, plans, features and media links are untouched because the id does not
change. Available from the site detail properties menu and as a bulk action
in the Sites list, with a library picker when more than one is connected.

### Delete, undelete, leave

An editor or owner deleting a library site sets `deleted: true` with a clock
and uploads. On every device, when the tombstone arrives or the member
leaves the library:

- a site that any dive or plan on this device links to is kept as a personal
  site under a new id, with dives, plans, features and media relinked by the
  helpers `mergeSites` uses, so an undelete in the library cannot collide;
- a site nothing links to is removed locally, with no personal tombstone.

A reader's delete is refused in the UI; a suggestion can propose it.
Undelete (editors and owners) sets `deleted: false` with a newer clock.

### Suggestions

A reader opens a library site in the edit page, which runs in suggestion
mode: title "Suggest changes", a note field, Save becomes Send, and the save
writes a `shared_site_suggestions` row instead of touching the site. The next
sync uploads it with the site id, member id and name, only the changed fields
(children included when changed), the note and created-at. The reader sees
their pending suggestions on the site detail page and can withdraw one that
has not been handled.

Owners get an inbox grouped by site. Each row opens a review sheet with the
note and a field-by-field before and after. Accept applies the fields with
clocks attributed to the suggester's member id, marks the site dirty and
deletes the file; dismiss deletes the file. A suggestion whose site is
deleted can only be dismissed. Files in `suggestions/` are never edited in
place, so two owners handling the same one is safe.

### Attribution

The site detail header of a library site shows the library name and "Last
edited by <name>, <date>" from the newest clock. Names resolve through the
member cache, falling back to a shortened member id. A History entry in the
properties menu lists each field with its last editor and time. Accepted
suggestions show the suggester as editor. Renaming a display name rewrites
the member card and the membership row; history follows the id.

## Screens

- **Settings > Shared site libraries** (`lib/features/shared_library/presentation/`):
  list of connected libraries (name, role, member count, last sync, status),
  Connect a library. Library page: Sync now, display name, role, Members
  (owners manage), Suggestions inbox (owners), Add my sites (editors and
  owners), Leave, error and read-only banners.
- **Sites list and map**: a group badge on library site tiles and markers,
  library name in the tooltip; filter sheet gains Library (personal or each
  library); group-by gains Library; bulk action Add to shared site library.
- **Site detail**: library name and attribution line in the header; History
  in the properties menu; actions by role (Edit and Delete, or Suggest
  changes and pending suggestions); Add to shared site library on personal sites;
  Connect on this device on an unconnected device.
- **Site edit page**: suggestion mode for readers; the Share-with-profiles
  toggle is hidden for library sites.
- **Suggestions inbox** (owners): list grouped by site, review sheet with
  Accept and Dismiss.
- **Dive detail and site picker**: the badge beside library site names.

All new text is localised in English and the ten other locales.

## Triggers

`SharedLibraryNotifier` syncs on launch and resume under the personal
auto-sync preferences, after a 5-second debounce when a library site or
suggestion changes locally, and on Sync now. It shares one in-flight guard
with personal sync: each waits for the other to finish, so two merges never
touch the database at once.

## Error handling

Every storage call is wrapped; a failure sets the library's `lastError`,
shown on its page, and never blocks another library or personal sync. An
unparseable document is skipped and logged and its modification time is not
stored, so it retries next sync. A permission error on upload sets read-only
and keeps the site dirty, so a credential change resumes the upload. Local
writes to a library site always succeed offline; the dirty flag carries them.

## Testing

- Document codec: round trip, unknown keys preserved, missing clocks oldest.
- Per-field merge: random edit sequences over two or three members on a
  shared `FakeCloudStorageProvider`, asserting every field and clock
  converges after each member syncs twice; the overwritten-upload race
  converges on the next round.
- Push: ids unchanged, children captured by name, dirty state row.
- Delete and leave: linked sites survive under a new id with dives relinked;
  unlinked ones are removed; no personal tombstone.
- Personal-sync guards: the two-device convergence harness with a library
  row, asserting it is never exported, overwritten or deleted by the peer.
- Roles and suggestions: reader saves become suggestion files; owner accept
  applies fields attributed to the suggester and deletes the file; dismiss
  deletes; read-only detection on a permission error from the fake.
- Visibility: library rows visible only to profiles with a membership; hides
  apply.
- Widget tests: library page, site detail header by role, suggestion mode,
  inbox.
- `test/architecture/` and `test/shared/` after the new files land.

## Out of scope

Encryption of the library folder (the existing decorator can wrap the provider
later), media in the library, Dropbox, Google Drive and iCloud as library
backends (their folders are private to one account), standalone comments,
conflict cards, and the public community backend of roadmap 14.2 and 14.3.
