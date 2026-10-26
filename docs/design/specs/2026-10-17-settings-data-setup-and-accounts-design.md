# Settings > Data: one setup, one account model, plain words

Date: 2026-10-17. Status: design approved in brainstorming, awaiting the plan.
Issue: to be opened before the first PR; every PR of this program links it with
`Refs`, the last one with `Closes`.

Related: #3390 and #3394 (health strip, shipped in #3450), #3388 and #3460
(Connected Accounts placement), #2303 (guided reconnect of a mismatched media
store), #1356 (a diver who could not tell whether photo sync worked).

Inventory of today's pages, flows and controls:
[findings/2026-10-17-settings-data-inventory.md](../findings/2026-10-17-settings-data-inventory.md).
That document is the "nothing may be lost" checklist for this design.

Mockups from the brainstorm, kept for reference (wireframes, not pixel specs):
[the four directions](assets/2026-10-17-settings-data-directions-mockup.html),
[the setup walk-through](assets/2026-10-17-settings-data-setup-walkthrough-mockup.html),
[the pages underneath](assets/2026-10-17-settings-data-pages-mockup.html).

## 1. Intent

A diver who is not technical opens Settings > Data wanting two things: their
dives safe, and their dives on every device they own. Today that takes three
separate journeys (database sync, backups, photo copies) that each choose a
cloud place in a different way, use different words for the same things, and
disagree about whether something is set up. The inventory counts five surfaces
that pick a cloud place in four different patterns, six names for the sync
feature, and three rules for "is photo storage set up". Issue #1356 shows the
result: a diver verified "Connected to iCloud" while every photo sat at
"Waiting" with no error.

This design makes the three journeys one journey and the pages underneath one
shape, without removing any control that exists today.

The user's words for the goal: simplify and standardize the interface so that
it is easier to understand and navigate, but it should not lose any of the
functionality.

## 2. Goals, non-goals, anti-goals

### Goals

- One place to sign in (Connected accounts) and one account picker, used by
  setup, by every feature page and by shared site libraries.
- One re-runnable guided setup, "Set up this device", with four steps: where
  the data lives, dives on every device, a backup off this device, photos on
  every device. The first-run wizard runs the same four steps.
- Every feature page opens the same way: the account it uses, one status line
  in plain words, the switches that matter, and everything else under
  Advanced.
- One vocabulary across the Data section, applied to every page it reaches.
- A second device joins without retyping what the first device already told
  the app, wherever the data allows it.
- Every control that exists today keeps existing. Some move; none disappear.

### Non-goals

- No new cloud backend and no change to the sync engine's rules: first-contact
  combine, adopt after a replace, replace from this device, epochs, conflicts
  and encryption all keep their current semantics and dialogs. Replace and
  join (section 6.4.1) is a device-side operation layered on the existing
  pull, not a change to those rules.
- No change to the health model's levels or to the strip's visual design
  (#3450). New reason texts are allowed.
- No change to Database storage, Offline maps, Import options or Data tools
  beyond moving their rows under Advanced on the Data page.
- No change inside the Shared site libraries pages other than using the shared
  account picker where they pick an account today.
- Lightroom stays behind its feature flag.
- No change to the frozen connected-account id namespace or to the natural
  keys that derive account ids (`account_identity.dart`). Grouping happens in
  the UI, not in the data.
- No cloud-side migration of existing libraries, backups or media stores.

### Anti-goals

- Nagging. The setup card can be hidden, the photo step is optional, and a
  diver who deliberately skips a step is not asked again on every visit.
- A modal trap. Every step has a way out, state survives leaving, and the
  flow can be re-entered at any point.
- Silent side effects. Today picking a backup folder silently turns the cloud
  copy off, and signing out of sync silently turns it off too. Every such
  effect becomes explicit or stops happening.
- Losing a control to tidiness. A row that moves under Advanced keeps its page
  and its dialogs behind it.

## 3. The shape

```
Settings > Data
  health strip and attention lines (unchanged)
  "Set up this phone" card: the four steps with their status, Continue
  facts line (unchanged)
  Your data
    Backups                    status in words
    Sync between devices       status in words
    Photos & videos            status in words, or Set up
    Shared site libraries      status in words
    Connected accounts         accounts and their state
  Advanced
    Database storage, Offline maps, Import options, Data tools,
    Set up this phone again (when the card is hidden or complete)
```

Each of the four feature pages opens with the same block:

```
[ Using: Google Drive, eric@example.com, signed in        Change ]
  one status line in plain words
  the two or three switches that matter
  ... the feature's own rows ...
Advanced
  everything else the page has today, re-parented, nothing removed
  Stop <doing this> on this phone
```

Accounts are the join: step 1 of the setup, every Change button and the shared
library connect page all open the same account sheet, which lists the accounts
the diver already has, then the kinds that can be added.

## 4. Vocabulary

Applied everywhere the Data section reaches, in all eleven locales. Sentence
case for every title, row and button. "Phone", "tablet", "laptop" or
"computer" where the device type is known, "device" otherwise.

| Today (several forms) | From now on |
| --- | --- |
| Database Cloud Sync, Cloud Sync, Cloud sync, Sync, Database sync, App-managed cloud sync | Sync between devices (page and row); "Sync" on the strip |
| Backup & Restore, Backups & Sync, Automatic Backups | Backups (page and row); "Backups" on the strip |
| Photos & Media, Media Storage, media store, cloud store, Where copies are kept | Photos & videos (page and row); "copies in the cloud" for the stored copies; "Photos" on the strip |
| Shared Site Libraries | Shared site libraries; "Libraries" on the strip |
| Connected Accounts, Sign-ins | Connected accounts; an "account" |
| Cloud Provider, provider, backend, sync backend, cloud storage, storage service, bucket, server | account (the thing you sign in to); "My own server" for S3 and WebDAV |
| Transfers, uploads, Back up now (on a photo), Not backed up (on a photo) | Uploads; "copied" / "not copied yet" on a photo |
| Sign Out, Disconnect, Remove Configuration, Remove configuration | On a feature page: "Stop syncing on this phone", "Stop keeping copies on this phone". On an account: "Sign out on this phone", "Remove from all devices" |
| Test Connection, Test connection, Check, Check location, Test credentials | Check connection (Check location stays on shared libraries, where it checks a folder) |
| Auto Sync, Sync on Launch, Sync on Resume | Keep devices in step automatically; Also sync at launch; Also sync when the app returns |
| Cloud backup, Store backups in the cloud, Upload backups to cloud storage | Copy to {account}; "Also keep a copy in {account}" in the setup step |
| Export Backup, Save to File | Save a backup file; Save to a folder |
| Restore from File, Import a backup from any location | Restore from a file |
| Ready to sync (with no account) | Not set up |

Kept as they are: Combine (the first-contact merge), Adopt (after a replace),
Replace the library with this phone's copy, passphrase and recovery code for
sync encryption, password and recovery code for backup files, Repair, Rebuild,
Wipe.

Status lines are one sentence: what is true, and when. Examples: "Backed up
3 hours ago, copy in Google Drive", "In step with Eric's iPhone, 12 minutes
ago", "1,228 of 1,240 copied, 12 uploading", "Only on this phone", "Not set
up". Red is reserved for data that may not be protected, as the health model
already does.

## 5. The Data page

`DataSectionContent` keeps its flat layout, the health strip, the attention
lines and the facts line exactly as #3450 built them.

Order, top to bottom:

1. Health strip and attention lines.
2. The "Set up this phone" card (section 6), when it has something to show.
3. Facts line.
4. Header "Your data": Backups, Sync between devices, Photos & videos,
   Shared site libraries, Connected accounts. Each row shows the feature's
   health mark (as today) and a one-sentence status subtitle from section 4.
   A feature that is not set up shows a trailing "Set up" button that opens
   the matching setup step directly; the row itself still opens the page.
5. Header "Advanced": Database storage, Offline maps, Import options, Data
   tools, each a row that pushes its page. Import options becomes a small page
   holding the three import controls that sit inline today (auto site
   matching, tank pressure at surfacing, tag imports automatically). "Set up
   this phone again" appears here when the card is hidden or complete.

The row subtitles are driven by the same health model inputs the strip uses,
so a row can never contradict the strip.

Desktop and tablet (master-detail at 1100 px and wider): the same content in
the detail pane. Sub-pages keep opening as full pages over the split, as
today. The setup steps open the same way.

The Settings root row reads "Data" with the subtitle "Backups, sync and
photos".

## 6. "Set up this phone"

### 6.1 What it is

One re-runnable flow with four steps. It replaces three things that exist
today: the Photos & Media guided-setup checklist (and its toolbar icon), the
"Finish setting up this device" pending card (`PendingSetupCard`) on the
Settings root and the hub, and the setup wizard's "Backups & Sync" step. It is
the only place the first-time journey is explained.

### 6.2 Where it appears

- On the Data page, under the strip, as a card: title "Set up this phone"
  (or "Finish setting up this phone" once at least one step is done), a
  "2 of 4" count, the four steps with a mark each (done, next, not yet,
  skipped), and a Continue button that opens the next step that is neither
  done nor skipped.
- On the Settings root, at the top of the list, where the pending card sits
  today, but only while a step is neither done nor skipped. The root card is
  a compact form: title, count, Continue.
- A "Set up" button on a feature row that is not set up opens that feature's
  step directly.
- Under Advanced, "Set up this phone again" reopens the flow from step 1 with
  every step shown, even the done ones, each pre-filled from the current
  state.
- In the first-run wizard, as steps of the wizard (section 6.6).

### 6.3 Hiding and skipping

- The card's overflow menu offers "Hide this card". Hidden is per device and
  permanent until the diver reopens the flow from Advanced, or until a new
  item that needs the diver appears (section 6.5), which shows the card again
  with only that item.
- The photo step has a Skip button. A skipped step counts as settled: the card
  does not show it as outstanding, and the Photos row reads "Copies are not
  kept in the cloud" with a "Set up" button, which is enough.
- Steps 2 and 3 have "Not now", which leaves the step outstanding, returns to
  the Data page and does not hide the card. A diver who never wants sync hides
  the card; the health strip keeps its existing "Recommended" line, which is
  the calm reminder #3450 chose.
- Nothing in the flow is persisted until the step's primary button is tapped.
  Leaving a step halfway changes nothing.
- Devices that predate this feature start with the card hidden and the photo
  step settled (the user's decision). The seed runs once, when the hidden and
  skipped preferences are absent and the database already holds a diver; a
  fresh install never seeds. Those devices still get the card when something
  needs them (section 6.5), and reach the flow through the "Set up" buttons
  on the rows and through Advanced. The health strip's recommendation lines
  remain their only reminder, as today.

### 6.4 The four steps

Each step is a page with a title, one or two sentences, the controls, and a
bottom row: a quiet Back (or Not now on step 1), and a primary button whose
label says what it does ("Next", "Turn on sync", "Download library").

**Step 1, "Where should Submersion keep your data?"** (second device: "Where
is your data?")

- The account sheet (section 7.4) inline: accounts already signed in on this
  device first, then the kinds that can be added here: iCloud ("Uses your
  Apple ID. Nothing to sign in to."), Google Drive ("Sign in with Google"),
  Dropbox ("Sign in with Dropbox"), My own server ("S3-compatible storage or a
  WebDAV server"). Kinds follow today's platform and build gating: iCloud on
  Apple builds that carry the entitlement, Google Drive where its sign-in can
  run, Dropbox where the build has an app key.
- Choosing an OAuth kind runs today's sign-in for that kind (native sheet,
  system browser with the wait dialog, Dropbox code dialog). Choosing My own
  server opens the server form (section 7.5) with Check connection.
- A note: "Your dives are stored only in the account you choose. Submersion
  has no server of its own."
- Also here, as a quiet link: "I have a backup file instead", which opens
  Restore from a file. The first-run wizard shows this as its existing
  "Restore a backup file" choice instead.
- Done when the chosen account is signed in on this device. Nothing else is
  written: no feature is turned on by step 1.

**Step 2, "Dives on every device"**

- Opens with "Signed in to {account}" and then one of:
  - No library in the account: "{Account} has no Submersion library yet. The
    {n} dives on this phone will become the library all your devices share."
    Primary button "Turn on sync".
  - A library exists and this device has no dives: "Found your library in
    {account}, last changed {when} on {device}. This {device} has no dives of
    its own, so the library is simply downloaded." Primary button "Download
    library". The sentence names what the sync manifest knows (device name
    and time); it does not give a dive count, because the manifest carries
    none and adding one would change the sync format.
  - A library exists and this device has dives: the same sentence, then two
    choices, "Combine them" (default; the explanation today's Combine
    Libraries dialog gives, including that dives logged separately on both
    devices will appear twice) and "Replace this {device}'s dives with the
    library" (a backup of this device's dives is made first). Primary button
    "Combine and download" or "Replace and download". Combine is today's
    first-contact merge. Replace is a new operation, "replace and join",
    specified in section 6.4.1.
  - The library is encrypted: a passphrase or recovery code field appears
    above the primary button; the step does not proceed without it.
  - The library was replaced and awaits adoption, or an upload was left
    unfinished: the existing texts from the wizard's sync connect step, with
    "Check again" and "Start fresh" where the wizard has them.
- A switch, "Keep devices in step automatically", on by default, with the
  subtitle "A few seconds after each change, at launch and when the app
  returns".
- The primary button performs today's first sync with the chosen outcome,
  showing progress in place ("Uploading your library", "Downloading your
  library", with the existing step texts), and turns on automatic sync and
  its two companions (launch, resume) when the switch is on.
- The account is the one chosen in step 1, even when other accounts are
  signed in on the device. The first upload or download happens in this step,
  immediately, as the wizard's pull does today; it is not deferred to Finish.
- Done when the sync account is set and the first sync has completed. Apart
  from replace and join, the outcomes use the exact code paths of
  `runSyncNow`, `SyncConnectStep` and the adopt dialog; nothing new is
  invented about libraries.

#### 6.4.1 Replace and join (new operation)

Today the first-contact gate offers Combine only; discarding a device's dives
in favour of the library has no path short of Reset Database followed by a
fresh setup. The user decided to build it. It exists only in Settings mode: a
fresh install has no dives to replace, and the wizard's fresh-path pivot (an
account that already holds a library) keeps its adopt-or-start-fresh choice.

What it does, in order:

1. Confirms. A dialog repeats the count ("This {device}'s {n} dives are
   replaced by the library in {account}. A backup of them is saved first and
   stays under Backups.") and requires the word "Replace" to be typed, as
   "Replace the library with this phone's copy" and Reset Database require a
   typed word today. The step's primary button only opens this dialog.
2. Backs up this device's database as an ordinary History entry, pinned so
   retention never removes it, with the note "Before joining the library,
   {date}". Restoring it later is today's Restore from History.
3. Detaches this device from any media store and clears its upload queue.
   Files on the device are left alone. Step 4 re-attaches to the library's
   announced store.
4. Clears this device's library through the Reset Database data path, but
   keeps what Reset discards today: the accounts and their credentials on
   this device, the chosen sync account, App Lock, and the database
   encryption setting, which is applied to the new database before anything
   is downloaded. The device keeps its sync identity; it has never published
   to this library, so nothing on the backend refers to it.
5. Downloads the library the way the wizard's pull does for an empty device,
   including the passphrase gate, and realigns the active diver.
6. Reloads the app, as Reset Database and Restore do today, behind a
   full-screen page: "Your {n} dives were set aside and the library was
   downloaded. Submersion will reload." The card is derived state, so after
   the reload the Data page shows it at step 3 and the flow continues.

A failure before step 4 leaves the device untouched. A failure during or
after step 4 leaves the set-aside backup in History and hands recovery to the
restore journal's existing "A restore did not finish" startup path; the
builder extends that journal rather than inventing a second recovery.

**Step 3, "A backup that survives a lost phone"**

- Opens with "Library uploaded, {n} dives in {account}" when step 2 just ran.
- Two sentences: "Sync keeps devices in step. A backup is a copy from a moment
  in time that you can go back to."
- "Back up automatically", on by default, subtitle "Weekly. The last 10 are
  kept on this phone." (desktop: "Weekly, while Submersion is open. The last
  10 are kept on this computer.")
- "Also keep a copy in {account}", on by default, subtitle "Same account as
  sync". Shown only when an account exists; otherwise the step explains that a
  copy off this device needs an account or a backup folder, with a link to
  Backups.
- A note: "Schedule, folder, password protection and old backups are under
  Backups."
- Primary button "Next" writes the two settings. Done when automatic backups
  are on and a copy goes off this device (cloud copy on, or a custom backup
  folder already set).

**Step 4, "Photos on every device", optional**

- First device, no store announced: "Keep copies of your photos and videos in
  {account} so your other devices can show them. Your originals stay where
  they are." Switch "Keep photo copies in {account}", off by default, with the
  count of attached photos and videos in its subtitle. When on, two more
  switches: "Upload new photos automatically" (on) and "Use cellular data"
  (off). Note: "Turn it on later under Photos & videos. Nothing is uploaded
  until you do."
- Second device, a store is announced by the library: "Your {device} keeps
  copies of {n} photos and videos in {account}. Show them on this {device}
  too?" Switch "Use the photo copies in {account}", on by default, subtitle
  "Same account. Nothing to type." when the store's account is the one this
  device just signed in to; otherwise the subtitle names the account and the
  primary button first signs in to it through the account sheet. "Upload
  photos added on this {device} automatically", on.
- Primary button "Next": attaches (first device: creates the store on the
  account; second device: attaches to the announced store), applies the
  switches, and offers "Upload everything already attached" as a one-tap
  action on the done screen rather than inside the step. Skip settles the
  step.
- Done when this device is attached to a store. Skipped counts as settled.

**Done screen**: "This phone is set up", with one line per outcome (account;
dives: "412 in the library, kept in step automatically"; backups: "Weekly,
with a copy in Google Drive"; photos: "Copies shared with Eric's iPhone" or
"Copies not kept in the cloud"), and the sentence "On your other devices, open
Submersion, choose {account}, and the same library appears." Done returns to
the Data page.

### 6.5 Later: the card as the "finish setting up" card

When something needs the diver after setup, the card returns with only that
item, in the same place as today's pending card, using the pending setup
service's existing item kinds:

- An account needs sign-in: "Sign in to {account} again. Sync and backups are
  paused until you do." Button "Sign in" opens the account sheet's sign-in for
  that account.
- The library announces a store this device is not attached to: step 4 in its
  second-device form.
- The store marker no longer matches: today's reconnect item, routed to Photos
  & videos; the guided adopt, rebuild or detach choice remains issue #2303.

Dismissing such an item is per device and permanent, as today. The health
strip keeps showing the matching attention line, as today, so dismissing the
card never hides a problem.

### 6.6 The first-run wizard and the Setup assistant

One implementation. The wizard (`lib/features/setup_wizard`) keeps its shell,
its welcome fork, Profile, Units and Finish, and its "I have existing
Submersion data" choices. Its "Backups & Sync" step and its "Connect cloud
sync" pull step are replaced by the four steps above, rendered as wizard
steps:

- Fresh path: Welcome, Profile, Units, Step 1, Step 2, Step 3, Step 4, Finish.
  "Skip setup" keeps skipping to Profile and Finish. When the account chosen in
  Step 1 already holds a library, Step 2 offers only "Download library" in its
  own second-device wording, and downloading moves the wizard onto the
  existing-data ending: Finish creates no diver profile, the name typed on
  Profile is not used, and the active diver is realigned to the library's. The
  old "Keep fresh" choice is dropped (decided 2026-10-25): on a device with no
  dives its only effect was a second profile of the same diver. A diver who
  wants a separate logbook goes Back and picks another account.
- Existing-data path: Welcome, the existing choice (Restore a backup file,
  Connect cloud sync, Open an existing folder). "Connect cloud sync" runs
  Step 1 and Step 2, then Step 3 and Step 4, then Finish. Restore and Open an
  existing folder are unchanged. When the account holds no library, the wizard
  switches to the fresh path at Profile, as today; Step 1 keeps the account
  already chosen, and Step 2 then offers "Turn on sync" to upload the new
  logbook.
- Each step writes when its primary button is tapped, exactly as in Settings
  (decided 2026-10-25): the account connection, the library download, the
  backup switches and the photo copies. Finish applies only what the wizard
  owns, the profile and the units, and the wizard draft no longer holds backup
  or connected-provider fields. A diver who leaves the wizard partway keeps the
  steps already done; the setup card shows what is left. Back to an earlier
  step undoes nothing; its answer is changed by pressing its button again.
- Finish creates the diver from the Profile name and the Units only when the
  device holds no diver once the steps are done (decided 2026-10-25). A
  downloaded library keeps its own divers and their units, and the active
  diver is realigned as the pull does today, so on the existing-data path
  Finish creates no diver profile. A wizard quit after Step 2 uploaded and
  then rerun meets its own upload in Step 2, downloads it, and Finish still
  creates the diver because the device has none: nobody is left without a
  diver.
- In the wizard, Step 1 does not show "I have a backup file instead": the
  wizard's own "Restore a backup file" choice covers it. Step 1 has "Not now"
  in the wizard (decided 2026-10-25): it skips Step 2, which has nothing to
  sync without an account, and opens Step 3, which can still turn on
  automatic backups on this device and explains that a copy needs an
  account; Step 4 then shows its note. "Not now" on Steps 2 and 3 moves on to
  the next step instead of closing the flow, since first launch has nowhere
  to return to; the step stays outstanding and the card shows it later. Skip
  on Step 4 settles it, as in Settings.
- Step 2 has an "in step" state, for a device whose sync already names the
  chosen account and has synced (the Setup assistant, Settings' Set up this
  device again, or Back after a download): "The dives here are in step with
  your library in {account}." with Next, instead of offering Combine or
  Replace for a library the device already shares.
- Settings > Manage > "Setup assistant" runs Units, then the four steps, then
  Finish, with every step pre-filled from the current state. Its subtitle
  becomes "Revisit units, backups, sync and photos".

The step widgets are shared between the wizard and Settings; only the shell
differs (the wizard's surface style versus a pushed page with an app bar). On
the step pages the wizard hides its own bottom bar: each step keeps its own
back and primary buttons.

## 7. Accounts

### 7.1 The concept

An account is a sign-in: an Apple ID (iCloud), a Google account, a Dropbox
account, or one server the diver controls (an S3-compatible endpoint and
bucket, or a WebDAV server). Dives and photo copies each use a folder of their
own inside the account, with the default names used today (`submersion-sync/`
and `submersion-media/` for S3; `Submersion` and `Submersion Media` for
WebDAV). Backup copies go to the `Submersion Backups` folder inside the sync
folder, exactly where today's cloud copy puts them, whichever account is the
copy destination. So a diver who picks the same server explicitly keeps seeing
the cloud-only backups already there.

### 7.2 Identity stays as it is

The connected-account roster, its deterministic ids and its natural keys do
not change. An S3 or WebDAV roster row continues to be one endpoint plus one
prefix or folder, so sync and media on the same server remain two rows with
the same credentials, exactly as `account_identity.dart` documents. The UI
groups rows into one account:

- Group key: kind plus the server part of the natural key (S3: display host
  and bucket; WebDAV: the DAV root). OAuth kinds are one row each already.
- The group shows one label (the server, or the account email), one sign-in
  state, and "Used for" as the union of its rows' usages.
- Signing in to a group stores the credentials on every row in the group on
  this device. Adding a role on a server that already has a row (for example
  turning on photo copies on the sync server) creates the role's row with the
  group's credentials and the role's default folder, with no form shown.
- Signing out of or removing a group applies to every row in it, with the
  existing confirmation that lists affected features.

Which rows exist, since a row always carries a role's folder in its id:

- The first row of a My own server group is the sync-role row with the
  default sync folder. Step 1's Save and "Add account" create that row, with
  the credentials, whether or not sync uses it yet; its usage line then reads
  "Not used yet". When sync later picks the account it uses this row. The
  backup copy also goes through this row (section 7.1), so a backups-only
  server needs nothing more.
- The media-role row and any library-role rows are created when that role
  first uses the account on any device, with the group's credentials.
- The pending setup service raises "Sign in to {account}" only for accounts
  this device needs: its sync account, the account of the store the library
  announces, and the accounts of its own library memberships. Today it asks
  for every roster row a device lacks credentials for, which is also the
  leftover-Lightroom defect in the inventory.

Existing roster rows need no migration. Two rows that today read
"dive-sync @ minio" and "dive-media @ minio" appear as one account "minio"
with two folders.

### 7.3 What the data gains

Two additive, nullable, synced columns, one migration rung, no backfill of
existing rows:

- `connected_accounts.location`: a secret-free description of where the
  account points, kind-specific (S3: display host, endpoint, bucket, region,
  path style; WebDAV: DAV root; OAuth kinds: null). Written when a device
  creates the row or signs in to it. It lets a second device sign in to an
  account another device added by typing only the secret.
- `media_stores.account_id`: the roster row the attached store lives on.
  Written on attach. Together with the existing announcement it lets a second
  device attach with nothing to type when it already holds that account's
  credentials, which is the common case of one account for everything. Legacy
  rows with a null account id fall back to today's behaviour: the step asks
  for the details, pre-filled with what the display hint and location allow.

A backup copy destination is a device preference, `BackupSettings` gaining the
account id of the copy destination, where null means "same as sync". No schema
change for that.

### 7.4 The account sheet

One widget, used by step 1, by every "Change" button on the feature pages, and
by the shared library connect and change-connection pages in place of their
"Storage account" dropdown plus "Add storage account" card.

- Section one, "Your accounts": the groups from section 7.2, each with its
  sign-in state on this device. A group that is not signed in here shows
  "Sign in to use it here" and signs in when chosen. The caller can restrict
  kinds (shared libraries allow only S3 and WebDAV, as today).
- Section two, "Add an account": the kinds that are not yet present and that
  this platform and build support, in the order iCloud, Google Drive, Dropbox,
  My own server.
- When the choice has consequences the sheet says so inline before confirming,
  reusing today's texts: switching sync to another account shows today's
  "Switch sync backend?" explanation (data stays where it was, the next sync
  combines, other devices keep using the old account until switched); changing
  the photo copies account explains that this device stops using the current
  copies and starts or joins a store on the new account, with today's
  marker checks unchanged.

### 7.5 My own server

The S3 and WebDAV forms exist once, as the "My own server" form: a segmented
choice between S3-compatible and WebDAV, then today's fields (address, bucket
or folder root, keys or user name and password, the plain-HTTP warning, the
untrusted certificate dialog, Advanced with region, folder names and path
style), and "Check connection" plus "Save". Saving creates the account group;
the roles get their default folders. The per-feature folder names remain
editable under Advanced in the account's detail view.

### 7.6 The Connected accounts page

- The list of account groups: icon, label, identifier, sign-in state
  ("Signed in", "Not signed in on this phone", "Unavailable on this phone"),
  and "Used for ..." across this device's features, plus "used for ... on
  {device}" where the roster shows another device uses it.
- "Add account" in the app bar opens section two of the sheet.
- Tapping a row opens the account's detail view: sign-in state; "Used on this
  phone for ..."; "Sign in again" (new; runs the kind's sign-in and stores the
  credentials on the group's rows); for My own server, the server details with
  Check connection, Save and Forget certificate, and the folders each role
  uses; then "Sign out on this phone" and "Remove from all devices", with
  today's confirmations and their lists of affected features.
- Today's overflow actions and texts move into the detail view; the row itself
  becomes tappable. The empty state keeps "No accounts connected yet" with an
  "Add account" button.
- The iCloud "Sign out on this device" that does nothing today is not offered
  for iCloud; the detail view says "Managed by your Apple ID in device
  settings".

## 8. The pages underneath

Every control named in the inventory has a home; the appendix lists the moves.
Each page below starts with the block of section 3.

### 8.1 Sync between devices (today Database Cloud Sync)

- Using row: the sync account, or "Not set up" with a "Set up" button that
  opens step 1 and 2.
- Status line: "In step with {devices}, {when}", "Syncing ...", "{n} changes
  waiting", "Not synced yet", "Sync is paused: ..." with the existing reasons,
  "Only on this phone" when no account is set. The status is tappable when it
  reports an error and opens Troubleshoot, as today.
- Banners: the existing conditional banners (library replaced, passphrase
  needed, first sync waiting, peers on other versions, library moved, old
  backend cleanup, duplicate diver profiles, custom database folder) stay,
  reworded to the vocabulary. "Delete old data" on the cleanup banner gains a
  confirmation.
- "Keep devices in step automatically" switch; "Sync now" with the pending
  count; "Resolve conflicts" row when there are conflicts.
- Advanced: "Also sync at launch" and "Also sync when the app returns"
  (greyed out while automatic sync is off, which they do not do today);
  "Encryption" (opens today's section as a page: turn on, change passphrase,
  new recovery code, turn off, enter passphrase when locked); "Devices using
  this library" (today's devices page); "Troubleshoot" (repair, rebuild from
  this device, remove this device's files, wipe, unchanged inside); "Replace
  the library with this phone's copy" (typed confirmation unchanged); "Stop
  syncing on this phone".
- "Stop syncing on this phone" does what Sign Out does today to sync state and
  the provider selection, keeps the account signed in, and pins a backup copy
  destination of "same as sync" to the account sync was using, so backups
  keep going to the same place instead of silently turning off.
- Gone from this page: the five provider tiles, the S3 and WebDAV gear icons
  and the Dropbox account dialog. Their functions live in the account sheet
  and the account detail view. Reconnecting the same provider (today: tapping
  the selected tile) is the account's "Sign in again".

### 8.2 Backups (today Backup & Restore)

- Status line first: "Backed up {when}, copy in {account}", "Backed up {when},
  on this phone only", "Not backed up yet", "Last backup failed: {when}".
- "Back up automatically" with the frequency in its subtitle (tap to change).
- Using row: "Copy to {account}", subtitle "Same account as sync" when the
  preference is null, with Change; or "No copy off this phone" with "Choose an
  account". The copy destination is any account the sheet offers, and the
  sheet also offers "No copy off this phone", which is today's cloud backup
  switch turned off. The backup service resolves the provider instance from
  the account's sync-role row the way sync does, so the files land where
  today's cloud copy lands.
- "Back up now" (with the note dialog) and "Restore from a file" (today's
  dialogs, unchanged, including Merge on next sync and Replace everywhere).
- History, unchanged inside: date, note, counts and size, automatic tag,
  device or cloud icon, pin, and the row menu with Restore and Delete,
  including cloud-only rows and the stricter delete text for them.
- Advanced: "Keep the last {n} backups"; "Backup folder on this phone" with
  "Change" and the new "Use default"; "Save a backup file" (today's Export
  Backup sheet: note, Save to a folder, Share); "Password protection"
  (today's backup encryption section: encrypt, change password, regenerate
  recovery code, turn off, re-encrypt existing); "Set-aside databases" when
  any exist.
- Picking a backup folder no longer turns the cloud copy off; both can be on.
  Turning the cloud copy on no longer resets the folder. The health rule "a
  copy off this device" is unchanged and is satisfied by either.
- The pre-restore barrier, the Restore complete page, the unrecognized
  backups page and the scheduled-run notifications are unchanged.

### 8.3 Photos & videos (today the Photos & Media hub plus Media Storage)

One page. The toolbar checklist icon goes.

- Header "Copies in the cloud". Using row: the store's account, or "Not set
  up" with "Set up" (opens step 4). Status: "{copied} of {total} copied, {n}
  uploading", "Waiting for a connection", "{n} waiting to retry", "Uploads
  paused: {reason}" (today's suspended notice reasons), "Finish setting up
  this phone" when an item is pending.
- "Upload new photos automatically", "Use cellular data", and "Uploads" (the
  Transfers page, unchanged inside: states, retry, select, clear completed,
  the paused notice). The dashboard chip "{n} uploads pending" still opens it.
- Header "Where photos come from": "Photo library and files" (today's Media
  Sources page, unchanged inside: counts, re-verify, check all, Android URI
  permissions, hidden Lightroom card).
- Advanced: "Upload quality" (photos and video, with the compression hints);
  "Upload everything already attached"; "Verify the copies" (today's Verify
  library, with its result text); "Network sources" (today's page, unchanged);
  "Show source badges on thumbnails"; "Cache" (the two sliders and Empty
  cache); "Export media report"; "Stop keeping copies on this phone"
  (today's Disconnect: this device only, nothing deleted).
- Changing the account for copies runs today's detach and attach with the
  existing marker checks; the sheet explains the consequence first.
- The per-item Backup section in the media info panel renames to "Copies in
  the cloud" with "Copy now" and "Retry upload"; the re-upload menu is
  unchanged.

### 8.4 Shared site libraries

Unchanged, except: the connect page and the change-connection page use the
account sheet restricted to S3 and WebDAV in place of the "Storage account"
dropdown and the inline "Add storage account" card; "Check" on the connect
page becomes "Check location" to match the change-connection page; the Data
row subtitle becomes a status ("None joined", "{n} libraries, last sync
{when}", "{library}: your edits are on hold").

### 8.5 Database storage, Offline maps, Import options, Data tools

Unchanged inside. Import options is a new small page holding the three
controls that are inline today. The custom-folder rule still disables sync;
the Sync page's custom-folder banner stays; the provider controls that today
remain tappable in that mode are replaced by the Using row reading "Off while
the database is in a custom folder" with a link to Database storage.

## 9. Health model hooks

The card, the strip and the row subtitles read the same inputs, so they cannot
disagree. The card's step states are derived, not stored:

| Step | Done when | Settled when skipped |
| --- | --- | --- |
| 1 Account | the sync account (or, with no sync, any account) is signed in on this device | never skippable |
| 2 Dives | a sync account is set and a first sync completed | Not now leaves it outstanding; Hide this card hides it |
| 3 Backup | automatic backups on, and a copy goes off this device (cloud copy or custom folder) | same |
| 4 Photos | this device is attached to a store | Skip settles it (per device) |

"Hidden" and "photo step skipped" are per-device preferences. The health
evaluators gain no new levels. New reason texts: "Sign in to {account} again"
replaces the generic "Sync paused: sign in" where the account is known, and
the photo rule reads the store's account to decide whether a pending attach
needs a sign-in.

The three "is it set up" rules the inventory found collapse to two uses of one
truth: the card and the strip use the health inputs; the Photos page's
"Connected" status keeps meaning "the store could be opened with this device's
credentials", shown as the status line, which is a stricter, runtime fact and
is labelled as such ("Checking ...", "Could not reach {account}").

## 10. Constraints

- Every string localized in all eleven ARB files; renamed strings get new keys
  so stale translations cannot linger; times follow a colon as in #3450.
- Files stay under the 800-line guide; `cloud_sync_page.dart` (1,525 lines)
  is split as it is reshaped, not grown. New widgets live in small files under
  `lib/features/settings/presentation/` and `lib/features/setup_wizard/`.
- Tables live in `lib/core/database/tables/`, migration rungs in
  `lib/core/database/migrations/`; the two new columns are nullable and
  additive; older devices on the fleet keep working through the existing
  cross-version rules (newer-schema changes are held until they update).
- Platform and build gating of account kinds is exactly today's: nothing is
  offered that cannot authenticate on this build.
- Tests restore any global state they replace; architecture and adoption
  guards under `test/architecture/` and `test/shared/` run after every PR.
- The frozen account id namespace and natural keys are not touched.
- Every PR of this program carries before and after screenshots (phone and
  desktop widths, light and dark where colours change), per the PR rules.
- User docs (`docs/user/`) that describe Settings > Data, backups, sync and
  media sync are updated in the PR that changes each page; the inventory
  notes `docs/user/media-sync.md` is already behind.

## 11. Phasing

Each PR leaves the app consistent and merges to main; the order matters
because later PRs build on the account sheet.

1. **Words and the Data page.** The vocabulary table applied to the Data page
   and its row subtitles, the Advanced fold with the Import options page, the
   "Set up" buttons wired to today's pages, the Settings root subtitle. No
   behaviour change.
2. **Accounts.** The account group view, the account sheet, Add account, the
   detail view with Sign in again, the My own server form shared by all
   callers, `connected_accounts.location`. Sync between devices adopts the
   Using row and the Advanced fold; the provider tiles and gear icons go.
   Shared libraries adopt the sheet.
3. **Backups.** The copy destination preference and Change, Use default, the
   explicit no-silent-off rules, the page reordered and its Advanced fold.
4. **Photos & videos.** The hub and Media Storage merged, `media_stores.account_id`,
   attach by account, the renamed statuses, Stop keeping copies.
5. **Replace and join.** The operation of section 6.4.1 as a service with its
   own tests and recovery, not yet reachable from the UI.
6. **Set up this phone.** The card, the four steps as shared widgets (step 2
   wiring in replace and join), the done rules, the upgrade seed, replacement
   of the pending card and the Photos checklist, the done screen.
7. **First run.** The wizard and the Setup assistant run the shared steps;
   the old Backups & Sync and sync connect steps are deleted.

Release notes are written per PR under the existing conventions; the user
guide for setup is rewritten once in PR 6 and touched up in PR 7.

## 12. Decisions and calls

Decided by the user during the brainstorm: the direction (one guided setup on
top of an account-first model, with the plain-words pass throughout); the four
steps and their order; the shape of the pages underneath; the first-run wizard
sharing the steps; building replace and join rather than offering Combine
only; and existing devices starting with the card hidden.

Calls made by the designer, marked so they can be checked while reading; none
were specified by the user beyond the approved mockups.

- "Keep devices in step automatically" is on by default in the flow, and its
  two companions follow it. Today nothing turns automatic sync on.
- Automatic backups and the cloud copy are on by default in the flow once an
  account exists.
- Encryption, for the library and for backup files, is not in the flow. It
  stays under Advanced on the feature pages. The second-device step still
  unlocks an encrypted library, because it must.
- Photos are the optional step: off by default on a first device, on by
  default when the library already keeps copies.
- S3 and WebDAV become one "My own server" entry; an account is the server
  and bucket in the UI while the roster keeps one row per role underneath.
- The card can be hidden; the health strip's recommendation line stays as the
  only reminder afterwards.
- The backup copy gets an explicit destination instead of silently following
  sync, and a backup folder and a cloud copy may both be on.
- "Delete old data" on the old-backend banner gains a confirmation.
- The Photos page's runtime "Connected" check is kept as the status line
  rather than dropped, because it is the only one of the three truths that
  knows whether the store can actually be reached.
- The device word in titles ("phone", "laptop") comes from the platform
  through the `deviceKind` select the ARB files already have; where it cannot
  be told apart the title says "device".
- A My own server account's first roster row is the sync-role row, created on
  Save even before sync uses it; the backup copy goes through that row to the
  same folder as today.
- Sign-in reminders are raised only for accounts a device needs, not for
  every roster row.
- Step 2 names the library by device and time only; no dive count is added to
  the sync manifest.
- The Backups copy sheet offers "No copy off this phone" as the off control.
- Replace and join requires the typed word "Replace", pins its set-aside
  backup, keeps the device's accounts and security settings, and ends in the
  same reload that Reset Database and Restore use today.
- The upgrade seed hides the card and settles the photo step once, only on
  devices whose database already holds a diver.

## 13. Left to the builder

- Widget and provider shapes, file splits, and how the step widgets are
  hosted by both the wizard shell and a pushed Settings page.
- The exact form of `connected_accounts.location` (one JSON column or a few
  typed columns) and of the sync serializer arms for the two new columns.
- How the backup service resolves a provider instance from an account id,
  reusing the account-first credential resolution that sync already has.
- How the account group is derived (a pure function over roster rows plus
  this device's credential presence) and tested as a table.
- Exact reason wording within the one-line rule, and icons.
- Whether the done screen's "Upload everything already attached" queues
  immediately or opens the Photos page.
- Test strategy per PR, including the widget tests for the card, the steps in
  both shells, the sheet, and the migration of existing single-role S3 and
  WebDAV setups into the grouped view.

## Appendix: where every control goes

Today's control, as named in the inventory, and its new home. "Same" means
the page and dialogs behind the row are unchanged.

| Today | New home |
| --- | --- |
| Data: Backup & Restore, Database Cloud Sync, Shared Site Libraries, Photos & Media, Connected Accounts rows | Your data: Backups, Sync between devices, Shared site libraries, Photos & videos, Connected accounts |
| Data: Database Storage, Offline Maps | Advanced, same |
| Data: Auto site matching, Tank pressure at surfacing, Tag imports automatically | Advanced > Import options, same controls |
| Data: Fix Dive Times, Link buddy names, Retype gear marked Other, Data quality | Advanced > Data tools, same |
| Settings root and hub: Finish setting up this device card | The Set up this phone card (section 6.5) |
| Photos & Media: Guided setup icon and checklist | The Set up this phone card and steps |
| Cloud Sync: provider tiles (iCloud, Google Drive, S3, WebDAV, Dropbox) | The account sheet (Change on the Using row; Add account) |
| Cloud Sync: S3 and WebDAV gear, configuration pages, Remove configuration | Connected accounts > account detail (My own server form, Check connection, Save, Forget certificate); removal is Remove from all devices |
| Cloud Sync: Dropbox account dialog, Disconnect | Connected accounts > account detail > Sign out on this phone |
| Cloud Sync: status card, Last synced, pending changes | The status line |
| Cloud Sync: all conditional banners | Same, reworded |
| Cloud Sync: Sync Now | Sync now |
| Cloud Sync: Resolve Conflicts | Same |
| Cloud Sync: Auto Sync, Sync on Launch, Sync on Resume | Keep devices in step automatically; Advanced > Also sync at launch, Also sync when the app returns |
| Cloud Sync: End-to-end encryption section | Advanced > Encryption, same dialogs |
| Cloud Sync: Troubleshoot Sync (repair, rebuild, devices, remove files, wipe) | Advanced > Troubleshoot and Advanced > Devices using this library, same |
| Cloud Sync: Sign Out | Advanced > Stop syncing on this phone (sync only; account stays) |
| Cloud Sync: Replace cloud library | Advanced > Replace the library with this phone's copy, same |
| Backup: Export Backup (note, Save to File, Share) | Advanced > Save a backup file, same sheet |
| Backup: Restore from File and its dialogs | Restore from a file, same |
| Backup: Automatic backups, Frequency | Back up automatically, frequency in its subtitle |
| Backup: Keep backups | Advanced > Keep the last {n} backups |
| Backup: Backup Location, Change | Advanced > Backup folder on this phone, Change, Use default (new) |
| Backup: Cloud backup switch | Copy to {account} Using row with Change |
| Backup: Backup Now, note dialog | Back up now, same dialog |
| Backup: Backup encryption section | Advanced > Password protection, same dialogs |
| Backup: Set-aside databases | Advanced, same |
| Backup: History and row actions | Same |
| Media Storage: Provider chooser and forms, Copy settings from Sync, Use my sync server, Connect buttons | The account sheet; adding a role on an existing server needs no form |
| Media Storage: Connected to, Upload photos automatically, Upload photos on cellular | Using row and status line; Upload new photos automatically; Use cellular data |
| Media Storage: Upload quality | Advanced > Upload quality |
| Media Storage: Upload existing library | Advanced > Upload everything already attached; also offered on the done screen |
| Media Storage: Verify library | Advanced > Verify the copies |
| Media Storage: transfer summary row, View transfers | Status line; Uploads |
| Media Storage: Disconnect | Advanced > Stop keeping copies on this phone |
| Media Storage: Export media report | Advanced, same |
| Hub: Photo library & sources, Media Sources page | Where photos come from > Photo library and files, same |
| Hub: Network sources (via Media Sources) | Advanced > Network sources, same |
| Hub: Show source badges on thumbnails | Advanced, same |
| Hub: Cache sliders, Empty cache | Advanced > Cache, same |
| Transfers page and dashboard chip | Uploads, same |
| Connected Accounts: rows, Sign out on this device, Remove from library | Account groups; detail view with Sign in again (new), Sign out on this phone, Remove from all devices |
| Shared libraries: Storage account dropdown, Add storage account card | The account sheet restricted to S3 and WebDAV |
| Setup wizard: Backups & Sync step, Connect cloud sync step | Steps 1 to 4 |
| Manage: Setup assistant | Units, then the four steps |
