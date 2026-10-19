# Settings > Data: inventory of today's pages and flows

Date: 2026-10-17. Baseline: `main` at 64250c97e80 (after #3450 health strip,
#3463 Connected Accounts out of Photos & Media). Recon for the Settings > Data
simplification brainstorm. Nothing here proposes a change: this is the "nothing
may be lost" checklist and the record of where the flows diverge today.

Line numbers refer to the baseline commit.

## 1. Where Data sits

- Settings is a list of sections (`settings_list_content.dart:40-113`):
  About, Appearance, Data, Apple HealthKit (iOS only), Diver Profile, Safety,
  App Security, Manage, Network, Notifications, Shared data (two or more
  profiles only), Units. Debug is inserted before About when debug mode is on.
- Row 0 of that list is the "Finish setting up this device" card
  (`pending_setup_card.dart`), which renders nothing when there is nothing to
  do. The same card sits at the top of the Photos & Media hub.
- At 1100 px and wider Settings is master-detail: the section list on the
  left, the section content in the detail pane. Every Data sub-page (Backup,
  Cloud Sync, Photos & Media, and so on) is a child route of `/settings` and
  opens as a full page over the split view, not inside the pane
  (`app_router.dart:1321-1669`).
- The Data row reads "Data" with the subtitle "Backup, restore & storage".

## 2. Settings > Data, top to bottom

`data_section_content.dart`. Flat page, no cards (decided in #3450).

### 2.1 Health strip, attention lines, facts line (#3450, #3394)

- Four symbols in one row: Backup, Sync, Libraries, Media. Levels: healthy
  (green check), attention (amber exclamation), failing (red cross), not set up
  (hollow dash). Each is tappable and opens that feature's page.
- One attention line per feature that is failing or needs attention, worst
  first. Backup lines: "Recommended: turn on automatic backups", "Last backup
  failed: {when}", "No backup yet", "Backup overdue (last: {when})", "Last
  backup did not reach the cloud", "No copy off this device". Sync lines
  include "Recommended: turn on cloud sync", "Sync paused: enter passphrase",
  "Sync paused: sign in", "Offline: last synced {when}", "{n} conflicts to
  resolve", "Recommended: turn on automatic sync", "Not synced yet". Media:
  "Photos: finish setting up this device", "Photo transfers are paused".
- Facts line: "{dives} dives · {sites} sites · {n} photos and videos · {size}".
- The four feature rows below carry the same symbol at 16 dp when the feature
  is not "not set up".

### 2.2 Header "Backup & Sync"

#### Backup & Restore (`/settings/backup`, `backup_settings_page.dart`)

Row subtitle: "Create a backup of your data", or "Last backup: {time}".

1. Status line (only after an operation this session; never cleared).
2. Card "Export Backup" ("Save your dive data to a file"): bottom sheet with
   "Note (optional)", "Save to File" (folder picker, not Save As), "Share"
   (hidden on Windows and Linux). One format: the database file, `.db` or
   `.sbe` when backup encryption is on. UDDF, CSV, PDF, Excel and KML live
   under Transfer > Export, not here.
3. Card "Restore from File" ("Import a backup from any location"): any-file
   picker, then "Restore Backup" dialog (details card; when a sync provider is
   configured the radios "Merge on next sync" and "Replace everywhere"; a red
   "Restore" or "Restore and Replace Everywhere"), a second "Replace Library
   Everywhere?" confirmation for Replace, an "Unlock encrypted backup" prompt
   when needed, a full-screen barrier during the restore, then the "Restore
   Complete" page with "Continue" (restarts the app).
4. Section "Automatic Backups":
   - Switch "Automatic backups" (off by default).
   - When on: "Frequency" (Daily, Weekly, Monthly; default Weekly) and
     "Keep backups" (5, 10, 15, 20, 30; default 10; "{count} backups
     currently use {size}").
   - Always shown: "Backup Location" (subtitle: the cloud provider name when
     Cloud backup is on, else the folder name or path, else "Default
     location") with a "Change" action that opens a per-platform folder
     picker. There is no "use default location" control.
   - "Cloud backup" switch ("Upload backups to cloud storage"), shown only
     when a Database Cloud Sync provider is selected and the database is in
     the app default folder. It always uses that sync provider and account.
   - "Backup Now" button, which opens "Back up now" with "Note (optional)".
5. Section "Backup encryption": "Encrypt backups" (password dialog, recovery
   code gate, then "Encrypt existing backups?"); when on: status row, "Change
   password", "Regenerate recovery code", "Turn off encryption".
6. Section "Set-aside databases" (only after a restore that kept copies):
   rows with "Restore" and "Delete".
7. Section "History": date, note, "{n} dives, {m} sites, {size}" with
   "(auto)", a device or cloud icon; pin toggle; overflow "Restore" and
   "Delete". Cloud-only rows are listed from the provider's "Submersion
   Backups" folder (for example after a reinstall).

Scheduling: a WorkManager job every 12 hours on mobile, an hourly timer on
desktop that only runs while the app is open. Mobile posts a system
notification; desktop never notifies.

#### Database Cloud Sync (`/settings/cloud-sync`, `cloud_sync_page.dart`, 1525 lines)

Row subtitle: "Sync via cloud storage", or "Synced: {when}" or
"Synced: {when} · {n} devices".

1. Conditional banners: "Cloud Sync Disabled" (custom database folder, with a
   "Storage Settings" button); "Duplicate diver profiles" with a "Merge" per
   group.
2. Status card: "Ready to sync" (shown even with no provider), "Syncing...",
   "Sync complete", "Sync error" (tappable, opens Troubleshoot), "Conflicts
   detected"; "Last synced: {time}"; "{count} pending changes".
3. Header "Cloud Provider": tiles iCloud, Google Drive, S3-Compatible
   Storage, WebDAV, Dropbox. Tap a tile to connect or switch; the check mark
   appears before authentication runs. iCloud: OS account, no UI. Google
   Drive: native sheet on mobile and the macOS App Store build, system
   browser with a "Continue in your browser" wait dialog on Windows and
   Linux. Dropbox: "Connect Dropbox" dialog, browser approval, paste a code.
   S3 and WebDAV: a gear icon opens a configuration page (Endpoint, Bucket,
   keys, Advanced with Region, Key prefix, path style; or WebDAV address,
   Username, Password, Folder, trusted certificate) with "Test Connection"
   and "Save". Save selects the provider without the switch dialog and
   without the "Connected to" snackbar the other three show.
   "Switch sync backend?" appears when leaving a provider that has synced.
4. Banners above Sync Now, each conditional: library replaced, passphrase
   needed, first sync waiting for confirmation, a device on an older library,
   a device on a newer or older app version, changes that could not be read,
   library moved, old backend cleanup ("Keep" / "Delete old data", the latter
   with no confirmation).
5. "Sync Now" (disabled with the hint "Select a cloud provider to enable sync"
   until a provider exists). The first sync against a cloud library that has
   data while this device also has dives asks "Combine Libraries?" ("Merge and
   Sync"). A replaced library asks "Adopt Restored Library?".
6. Header "Conflicts ({count})" with "Resolve Conflicts" (a stepper dialog with
   "Keep this device's version", "Keep the other device's version", "Keep
   Both", "Apply All").
7. Header "Sync Behavior": "Auto Sync" (off by default; nothing turns it on
   automatically), "Sync on Launch", "Sync on Resume" (both only effective
   while Auto Sync is on, but not greyed out). The same three switches govern
   shared site library sync.
8. Header "End-to-end encryption": "Enable encryption" (passphrase twice,
   "Delete existing unencrypted cloud backups" checkbox, recovery code gate;
   enabling also replaces the cloud library from this device); when on:
   status row, "Change passphrase", "Generate new recovery code", "Turn off
   encryption"; when locked: "Enter passphrase".
9. Header "Advanced": "Troubleshoot Sync" and "Sign Out" (both usable with no
   provider); "Danger Zone" > "Replace cloud library" (type "Replace").

Sub-pages: Troubleshoot Sync ("Repair Sync", "Rebuild backend from this
device", "Devices on this backend", "Remove this device's cloud files", "Wipe
all sync data on this backend" typed WIPE), Devices on this backend (per-device
rows with file counts and a remove action), S3 configuration ("Remove
Configuration"), WebDAV configuration ("Remove configuration").

Other ways in: the health strip, the Home sync chip (long-press), the nav
shortcut "Cloud sync", the Photos & Media guided setup step, the pending setup
card, the setup assistant's "Manage in Settings".

#### Shared Site Libraries (`/settings/shared-libraries`)

Row subtitle: "Dive sites kept together with other divers".

- List page: app bar "+" ("Connect a library"); rows with role, member count
  and last sync; "Not connected on this device" rows for memberships synced
  from another device; empty state with "Connect a library".
- Connect page: "Folder (prefix)" field with helper text, "How to set up
  storage" sheet, "Storage account" dropdown (every S3 or WebDAV Connected
  Account), "Add storage account" inline card (segmented "S3-Compatible
  Storage" / "WebDAV", server fields, "Save account"), "Check", then per
  outcome: "Join {name}", or "Library name" plus "Create library" plus
  "Restore from a backup file", or unlock an encrypted library, or an error
  (test build, needs newer app). This is the only place in the app where an
  account is picked from the roster before a feature uses it.
- Library page: banners (ownership reset, locked, read-only keys, roles
  rejected, last sync failed), "Sync now", About (owners edit), display name
  and role, Members, Suggestions (owners), "Add my sites", Backups (owners),
  "Connection on this device" with "Change connection", ownership actions
  (recovery code, reset), encryption (turn on, change passphrase, turn off),
  "Leave library".
- Sub-pages: Members (approve, reject, change role), Suggestions inbox
  (before/after review, Accept, Dismiss), Backups (back up now with a note,
  pin, export, restore, delete, import), Change connection (same pickers,
  "Check location", "Save connection").

#### Photos & Media (`/settings/photos-media`, `photos_media_hub_page.dart`)

Row subtitle: "Sources & storage".

- App bar action: a checklist icon, "Guided setup" (the only entry to the
  guide anywhere). Guide: "Set up photos & media", three cards with "Set up" /
  "Not set up" chips and an "Open" button: "Photo sources" (opens Media
  Sources), "Media storage" (opens Media Storage), "Cloud sync" (opens
  Database Cloud Sync). Chips refresh on return. No order, skip or finish.
- Pending setup card.
- "Where photos come from": "Photo library & sources" ("Gallery, files and
  import options") opens Media Sources: a static "Photo library" card, "Local
  files" with counts and "Re-verify all local files" and "Check all media",
  Android URI permissions, "Network sources" (saved hosts, manifest
  subscriptions, network image cache, "Scan all network media"), and a hidden
  Lightroom card (feature flag off). Nothing on this page attaches a photo;
  photos are attached from the Media tab, a dive or a site.
- "Where copies are kept": "Media Storage" ("Store photo and video originals
  in your own cloud storage") and "Transfers".
  - Media Storage, not connected: status "No media store connected on this
    device", a segmented "Provider" chooser (S3 default, Dropbox, WebDAV,
    Google Drive where sign-in can run, iCloud on Apple). S3 and WebDAV: the
    same server fields as sync plus "Copy settings from Sync" / "Use my sync
    server", "Test Connection" / "Test connection", and "Save" as the connect
    action. Dropbox: "Connect Dropbox", which only works if Dropbox was linked
    on Database Cloud Sync and otherwise fails with untranslated developer
    text and no link to that page. Google Drive: "Connect Google Drive" with
    interactive sign-in. iCloud: "Connect iCloud". On success the snackbar
    "Media store connected" shows and the page closes itself.
  - Media Storage, connected: "Connected to {hint}", "Upload photos
    automatically", "Upload photos on cellular", "Upload quality" (Photos and
    Video dropdowns), "Upload existing library", "Verify library", a transfer
    summary row, "View transfers", "Disconnect" (detaches this device only),
    "Export media report".
  - Transfers: rows Waiting / Uploading / Removing from cloud / Done / Failed,
    per-row and bulk "Retry", "Select items", "Clear completed", a "Transfers
    paused" notice naming the cause.
- "Display": "Show source badges on thumbnails".
- "Cache": "In-memory image cache" and "Thumbnail disk cache" sliders, "Empty
  cache".

#### Connected Accounts (`/settings/connected-accounts`)

Row subtitle: "Sign-ins used by sync, media storage and shared libraries".
The Data row is now the only entry point (#3463).

- Kinds: Dropbox, Google Drive, iCloud, S3, WebDAV, Adobe Lightroom. Rows are
  created as a side effect of choosing a provider on Cloud Sync or Media
  Storage, or through the shared library inline form. S3 and WebDAV get one
  row per server plus prefix or folder, so "Copy settings from Sync" creates a
  second row.
- Each row: kind icon, label, "{identifier}: Signed in / Needs sign-in /
  Unavailable on this device", "Used for: Database sync, Media storage, Shared
  site library: {name}, Lightroom" or "Not used on this device".
- Actions: overflow "Sign out on this device" and "Remove from library".
  Missing: add, rename, sign in again, and the row is not tappable.
  Re-sign-in happens only through the pending setup card, which routes to
  Cloud Sync, Media Storage or Lightroom.

### 2.3 Header "Storage"

#### Database Storage (`/settings/storage`, `storage_settings_page.dart`)

Row subtitle: "App default location" or "Custom folder".

- "Current Location" card with the path and "{size} • {n} dives • {m} sites".
- "Storage Location": "App Default" and "Custom Folder" (with "Change").
  Choosing a folder that already holds a database opens "Existing Database
  Found" (Use existing / Replace with my data); an empty folder opens "Move
  Database?". A custom folder disables app-managed cloud sync and removes the
  Cloud backup switch.
- "Storage Usage" (`/settings/storage-usage`): groups App Data, Media Cache,
  Caches, Backups, Temporary Files, Exported Files, Raw imported data; a
  "{size} reclaimable" row with "Compact"; an "Unrecognized Backups" notice
  with "Review" leading to a page that can delete files this device wrote.
- "Danger Zone" > "Reset Database" (type "Delete"), then the "Database Reset"
  page with "Continue".

#### Offline Maps (`/settings/offline-maps`)

Row subtitle: "Map tiles and 3D terrain data". Map tiles: cache statistics,
active download, downloaded regions (details, delete), "Download new region"
(region picker, zoom presets), "Clear all map tiles". 3D terrain: "Reload map
data", swissBATHY3D "Update Existing Map Data" and "Delete data", "Reset
remaining bathymetry data".

### 2.4 Header "Import" (`import_preferences_group.dart`)

- "Auto site matching" dropdown (Strict, Balanced, Relaxed).
- "Tank pressure at surfacing" switch.
- "Tag imports automatically" switch.

### 2.5 Header "Data Tools"

- "Fix Dive Times": date range filter, hour offset, preview, per-dive
  selection, "Apply to {count} dives".
- "Link buddy names": dives with legacy buddy text, chips per name, per-dive
  review sheet, "Link {count} dives", Undo.
- "Retype gear marked Other": checklist with "Becomes {type}", "Retype {count}
  items", Undo.
- "Data quality": one switch per detector (14). The findings inbox is under
  the dive list, not Settings.

### 2.6 Related things outside Data

- App Security (own section): App Lock, biometrics, auto-lock, change
  password, new recovery code, "Encrypt database".
- Setup assistant (Settings > Manage): "Revisit units, appearance, and backup
  choices". It runs the first-run wizard in settings mode: Units, Backups &
  Sync, Finish.
- Diagnostics (Settings > About): "View log", "Copy diagnostics", "Open log
  folder".
- Network (own section): proxy mode, manual proxy form, "Test connection".

## 3. The three setup flows side by side

The first-time path on a fresh install, one row per step the diver takes.

| Step | Database sync | Photo copies (media store) | Backup off this device |
| --- | --- | --- | --- |
| Where it starts | Data > Database Cloud Sync | Data > Photos & Media > (Guided setup) > Media storage | Data > Backup & Restore |
| How the destination is chosen | Tap one of five tiles under "Cloud Provider" (iCloud, Google Drive, S3-Compatible Storage, WebDAV, Dropbox) | A segmented "Provider" chooser (S3, Dropbox, WebDAV, Google Drive, iCloud), S3 preselected | No choice. "Cloud backup" is a switch that reuses the sync provider; or "Backup Location" > "Change" picks a folder |
| Sign-in | iCloud: none. Google: sheet or browser. Dropbox: dialog plus pasted code. S3, WebDAV: config page, "Save" | Google: sheet or browser from this page. Dropbox: must already be linked on Cloud Sync. iCloud: none. S3, WebDAV: form on this page, "Save" | None; inherited from sync |
| What confirms success | Snackbar "Connected to {provider}" (not for S3 or WebDAV), a check on the tile, status still "Ready to sync" | Snackbar "Media store connected", then the page closes itself | The green status line after "Backup Now", or the History row's cloud icon |
| What still has to happen | Tap "Sync Now" (possibly "Combine Libraries?"); turn on "Auto Sync" by hand; optionally "Enable encryption" | Reopen Media Storage to see the connected state; tap "Upload existing library" to send what is already attached | Turn on "Automatic backups"; pick Frequency and Keep backups; optionally "Encrypt backups" |
| On a second device | Pick the provider again and sign in; first "Sync Now" adopts or combines | The pending setup card says "Connect media storage ({hint})"; the diver re-picks the provider and retypes the same credentials; nothing is prefilled | Nothing to do; the cloud copy follows the sync provider; cloud-only backups appear in History |
| Where the account ends up | A Connected Accounts row, created as a side effect | A Connected Accounts row, created as a side effect (a second row for S3 or WebDAV copied from sync) | None of its own |
| Disconnect | "Sign Out" (also turns cloud backup off); or the gear's "Remove configuration" / Dropbox "Disconnect" | "Disconnect" (this device only; account and announcement stay, so the pending card returns) | Turn "Cloud backup" off, or pick a folder (which silently turns it off) |
| Secret and recovery code | End-to-end "passphrase" (min 8), own recovery code | None of its own (encryption rides on sync when present) | Backup "password" (min 8), own recovery code |

Two more surfaces do the same job a fourth and fifth way:

- Shared Site Libraries picks an existing account from a "Storage account"
  dropdown, with "Add storage account" inline, and then a folder. The only
  account-first flow in the app.
- The first-run wizard shows provider cards (iCloud, Google Drive, Dropbox,
  S3, WebDAV, a different order with shorter hardcoded names), with no switch
  dialog and no encryption, and adds "Store backups in the cloud".

## 4. Where they diverge

### 4.1 Five surfaces, four patterns, three orders

Choosing a cloud place and signing in happens on Cloud Sync (tile list),
Media Storage (segmented chooser plus form), Shared Libraries (account
dropdown plus folder), the wizard (cards) and the backup page (a switch bound
to sync). The provider order differs between Cloud Sync, Media Storage and the
wizard. The S3 and WebDAV forms exist twice, with different default prefixes
("submersion-sync/" and "submersion-media/") and folders ("Submersion" and
"Submersion Media"), joined only by "Copy settings from Sync" and "Use my sync
server", which create a second account row.

### 4.2 Names

- The sync feature: "Database Cloud Sync" (page and row), "Cloud Sync"
  (banner, reset text), "Cloud sync" (nav, wizard, guide step), "Sync"
  (strip), "Database sync" (accounts), "App-managed cloud sync" (storage).
- The destination: "Cloud Provider", "provider", "backend", "sync backend",
  "cloud storage", "storage service", "server", "bucket" (also for Google
  Drive and iCloud in the media Disconnect dialog), "account", "the cloud".
- The copies of photos: "Media Storage", "Media storage", "media store",
  "cloud store", "Cloud media store", "your own cloud", "copies", "originals".
- Uploading photos is called "Transfers", "uploads", "Back up now" and "Not
  backed up" in the media info panel, while "Backup" on the same Data page
  means the database.
- Stopping: "Sign Out", "Disconnect" (three different scopes: this device's
  media attachment, every device's Lightroom account, the Dropbox link), "Sign
  out on this device", "Remove from library", "Remove Configuration", "Remove
  configuration", "Dismiss".
- Testing: "Test Connection", "Test connection", "Test credentials", "Check",
  "Check location", "Check again".
- Case: Title Case ("Sign Out", "Sync Now", "Backup Now", "Resolve Conflicts",
  "Danger Zone", "Automatic Backups") beside sentence case ("Replace cloud
  library", "Enable encryption", "Automatic backups", "Back up now").

### 4.3 Three answers to "is it set up?"

- The health strip: a saved store id, or Lightroom signed in, or a pending
  item.
- The guide chips: "Media storage" is a saved store id; "Photo sources" is any
  media row in the database (a second device that received rows by sync reads
  "Set up" before anything is configured); "Cloud sync" is a saved provider.
- The Media Storage page: the store could actually be opened with this
  device's credentials.

On a device whose Google session expired these three disagree at once. On
Cloud Sync, "Ready to sync" is the status with no provider at all, and it stays
the title above "Sync paused" subtitles.

### 4.4 Three secrets, three recovery codes

Backup encryption ("password", "Regenerate recovery code", "I have saved my
recovery code"), sync end-to-end encryption ("passphrase", "Generate new
recovery code"), App Security ("password", min 4, "New recovery code", "I saved
my recovery code"). The backup unlock error reuses the sync string "Incorrect
passphrase or recovery code" while its change dialog says "Incorrect password
or recovery code".

### 4.5 Hidden couplings

- The backup cloud copy has no destination of its own. Changing where backups
  go means changing the sync provider. Picking a backup folder silently turns
  Cloud backup off; turning Cloud backup on silently resets the folder.
- Signing out of Cloud Sync, disconnecting Dropbox or removing the S3 or
  WebDAV configuration turns cloud backup off (the dialogs say so).
- A custom database folder disables sync and the cloud backup switch, but the
  provider tiles and Sync Now stay tappable and fail with raw text.
- Dropbox media storage depends on the Dropbox link made on Cloud Sync, and
  linking it there also selects Dropbox as the sync provider.
- "Auto Sync", "Sync on Launch" and "Sync on Resume" also drive shared site
  library sync. The two sub-switches do nothing while Auto Sync is off and are
  not greyed out.
- No connect flow turns Auto Sync on, so the recommended setup the health
  strip asks for ("turn on automatic sync") needs a separate visit to a switch
  below the fold.
- The media "Disconnect" leaves the library's store announcement in place, so
  the same device immediately sees "Connect media storage" and turns amber.

### 4.6 Status feedback

- Cloud Sync shows the check mark before authentication; S3 and WebDAV give
  no "Connected" message at all.
- Media Storage closes itself on connect; the connected state is only seen on
  a second visit.
- The backup status line persists for the session and is never cleared.
- Desktop scheduled backups never notify; a failure shows only as a health
  line.

## 5. Building blocks that already exist

- The setup wizard (`lib/features/setup_wizard`): first run with a fork
  ("Set up a new profile" / "I have existing Submersion data"), fresh path
  Profile, Units, Backups & Sync, Finish; existing path "Restore a backup
  file", "Connect cloud sync" (pulls the library, handles encrypted and
  unfinished libraries), "Open an existing folder". Settings mode (Manage >
  Setup assistant): Units, Backups & Sync, Finish. It has no photo or media
  step.
- The "Finish setting up this device" pending card and
  `PendingSetupService`: "Connect media storage", "Reconnect media storage",
  "Sign in to {label}", per-device dismiss. Fed by the synced store
  announcement and account roster.
- The health model (`lib/features/settings/domain/data_health/`): one
  `FeatureHealth` per feature from pure evaluators; the strip and the row
  marks read the same model.
- The Photos & Media guided setup checklist (`photos_media_setup_page.dart`).
- The synced Connected Accounts roster with per-device credentials, usage
  lines, and account ids derived from the endpoint so devices merge rows.
- "Copy settings from Sync" (S3) and "Use my sync server" (WebDAV) on Media
  Storage.
- The shared library "Storage account" picker plus "Add storage account"
  inline card (`library_location_fields.dart`).
- `authenticateWithBrowserWait`, the shared Google browser wait dialog, used
  by Cloud Sync, Media Storage and the wizard.

## 6. Evidence of real-world confusion

- Issue #1356: a diver verified "Connected to iCloud" on Media Storage while
  every transfer sat at "Waiting" with an alphanumeric name and no error. Two
  of the three causes were bugs, but the recovery was to disconnect and
  reconnect, found by another user by accident; the pending card had already
  said "reconnect cloud storage" before they understood what it meant.
- Issues #3388 and #3460: Connected Accounts moved to Data and out of Photos &
  Media because it "suggests the accounts belong to media only".
- The media linking and storage program spec (2026-07-12, section 7) promised
  a hub with live status rows, Cloud Sync choosing from Connected Accounts, a
  multi-page guided setup reachable from the hub's empty state, and a one-time
  second-device prompt. The code has a status-free hub, provider pickers on
  both pages, a three-card checklist behind an icon, and the pending card.
- `docs/user/media-sync.md` lists four providers (no WebDAV) and says the
  Media Storage page shows the connected state after connecting.

## 7. Defects and gaps noticed on the way

Not design questions. Candidates for issues of their own.

- Raw internal ids in "Failed to initialize {providerName} provider" (for
  example "googledrive"); "Connected to {providerName}" uses untranslated
  English names; the Google Drive check mark's screen-reader label is a
  literal "Connected".
- Hardcoded English: the Dropbox and iCloud media errors ("… is not connected
  or unavailable on this device"), the file picker error, Android SAF export
  status, the database folder picker title, storage migration errors, "dives"
  and "sites" in the Current Location card, the scheduled-backup
  notifications, the debug-mode snackbar, the Fix Dive Times failure
  snackbar, the wizard's provider names.
- A cancelled or failed Google, iCloud or Dropbox connect on Cloud Sync
  probably leaves a Connected Accounts row behind (selection precedes
  sign-in; read from code, not run).
- S3 and WebDAV "Save" skip the backend-switch dialog, leave no "moved" marker
  and offer no old-backend cleanup.
- In custom-folder mode the provider tiles and Sync Now stay enabled and fail
  with raw text; moving to a custom folder does not clear the chosen provider
  or the cloud-backup preference, so the next backup turns amber.
- No way back to the default backup location from the UI.
- "Delete old data" on the old-backend banner deletes without confirmation.
- iCloud "Sign out on this device" does nothing but is offered.
- Leftover Lightroom roster rows raise "Sign in to {name}" items that route to
  a page where Lightroom is hidden; only Dismiss clears them.
- On a phone the App Security section's app bar reads "Settings" because the
  title switch has no case for it; the master-detail doc comment still says
  800 px.
- The Offline Maps empty state points to the site detail page although the
  page has its own download button.
- Sign Out on Cloud Sync has no filled primary button; the reset confirm word
  is case-sensitive where the spec said case-insensitive.
- The adopt copy always says "replaced from a backup", even after "Replace
  cloud library" or an encryption change.
