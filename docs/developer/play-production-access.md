# Google Play production access application

Working document for the production access application on the personal
developer account holding `app.submersion`. Everything here is derived from
the code in this repository as of version 1.8.0 (version code 128), not from
the store listing, so re-check the sections marked **VERIFY** before pasting.

Companion to `docs/developer/release-process.md`, which covers the release
pipeline itself. The one-line change that lands after approval is documented
in "After approval" at the bottom.

## Contents

1. [Before you open the form](#1-before-you-open-the-form)
2. [Production access application answers](#2-production-access-application-answers)
3. [Data safety form](#3-data-safety-form)
4. [Store listing, rating and target audience](#4-store-listing-rating-and-target-audience)
5. [Policy pre-flight audit](#5-policy-pre-flight-audit)
6. [After approval](#6-after-approval)
7. [Appendix A: Egress inventory](#appendix-a-egress-inventory)

---

## 1. Before you open the form

Four items to clear first. The first has been done in this repository and
needs publishing; the rest are yours to confirm.

### 1.1 The privacy policy contradicted the app (rewritten here, still to publish)

**Status:** the rewrite is done. `PRIVACY.md` in this repository now discloses
everything below. What remains is publishing it at a public HTTPS URL, which
is tracked in the open items.

The rest of this section records what was wrong and why, because the Data
safety answers in section 3 have to stay consistent with it.

As of 2026-03-06, `PRIVACY.md` described an app that talked to exactly one
remote service. The shipped app talks to many. Google's reviewers compare the
Data safety declaration against the hosted privacy policy, and a declaration
that discloses transfers the policy denies is a documented rejection cause.

What the policy said before the rewrite:

> Submersion does not operate any remote servers, and your data is not
> transmitted to any server owned or operated by Submersion.

That sentence is true and worth keeping. The problem is the surrounding
claims, which read as "nothing leaves the device except a Google Drive
backup". What actually leaves the device:

| Destination | What is sent | Triggered by |
|---|---|---|
| Google Drive, Dropbox, S3-compatible storage (user's own account) | Encrypted sync and backup envelopes | User enables sync or takes a backup |
| `nominatim.openstreetmap.org` | Dive site coordinates, for reverse geocoding | User geocodes a site |
| `tile.openstreetmap.org`, `tile.opentopomap.org`, `server.arcgisonline.com`, `data.geo.admin.ch` | Map tile requests, which imply the viewed area | User opens a map |
| `connectapi.garmin.com`, `sso.garmin.com` | Garmin account credentials via Garmin's own OAuth, then dive downloads | User connects Garmin Connect |
| `lr.adobe.io`, `ims-na1.adobelogin.com` | Adobe account OAuth, then photo library queries | User connects Lightroom |
| `www.googleapis.com`, `oauth2.googleapis.com` | Google account OAuth for Drive scope | User connects Google Drive |
| iNaturalist, GBIF, NOAA, EMODnet, GMRT and similar | Coordinates, for nearby species and bathymetry | User opens those features |
| `api.github.com` | Nothing user-specific; update check | Automatic |

That table is a summary. The complete inventory, built by enumerating
transport primitives rather than endpoint strings, is in Appendix A. The short
version: roughly fifteen third parties can receive a dive site's coordinates,
and the only thing that contacts the network without a user action is the
GitHub update check.

Every one of these is user-initiated and optional, which is a strong story.
It just has to be the story the policy tells.

A second gap: the policy did not disclose that data belonging to *other
people* leaves the device. Dive buddy photos, phone numbers and email
addresses, certification card scans and handwritten signature images are all
carried in the sync payload. See 3.2.1. A user reading the old policy would
not expect their buddy's face and phone number to be uploaded on their behalf.

A third gap, found when this PR was reviewed: **the encryption the policy
implied is optional and off by default.** `syncEncryptionEnabled` and
`dbEncryptionEnabled` both read `?? false`, and the media store has no
encryption at all. An interim draft of this document asserted end-to-end
encryption as a property of the app and recommended ticking it on the Data
safety form. That would have been a false security declaration. See 3.4.

**Done:** `PRIVACY.md` now enumerates the destinations above, discloses the
third-party data, separates the encrypted and unencrypted upload paths, and
states plainly which encryption settings are off by default. It also keeps the
strongest true line in the policy: dive gallery photos and video are referenced
in place and are never uploaded unless a media store is attached.

**Still to do:** serve it at a stable public HTTPS URL. Play requires a URL,
not a file. The app has no in-app privacy policy link at all (nothing in
`lib/` launches one), so there is no existing URL to reuse.

**VERIFY:** is `https://submersion.app/privacy` live? The domain is in use
(`adobe_ims_auth_manager.dart:53` uses `https://submersion.app/lightroom/callback`
as an OAuth redirect), but nothing in the app links to a policy page. If the
page does not exist, the GitHub-rendered `PRIVACY.md` is an acceptable interim
URL and Google accepts it.

### 1.2 Confirm the closed test actually satisfies the rule

The requirement is 12 testers **opted in continuously** for 14 days, not 12
testers who ever joined. Testers who opted out mid-window break continuity and
the console counts them out. Check Play Console under the closed track's
testers tab before applying; if the count reads 11, the form will either be
unavailable or the application will be declined on the spot.

### 1.3 Gather your tester evidence

Section 2 needs specifics you have and this document does not: how you
recruited, what they said, what you changed. The raw material is in:

- The GitHub issues filed during the test window
- `github.com/submersion-app/beta-builds` releases and their feedback
- `CHANGELOG.md` entries dated inside the window

Pull the date range of the closed test and diff the changelog across it. That
gives you the "what changed because of testing" answer with real version
numbers, which reads far better than a generic claim.

### 1.4 Complete the two in-console declarations

Both are separate from the production access form and both gate publishing:

- **Data safety** (section 3 below)
- **Foreground service permissions** (section 5.1 below), because the app
  declares `FOREGROUND_SERVICE_LOCATION` and genuinely uses it

---

## 2. Production access application answers

Google's form is free text across roughly six prompts. Exact wording varies;
match the drafted answer to the prompt it fits. Answers below are written to
be specific, because the reviewers are reading for evidence that a real app
with real users exists.

Sections marked **[FILL]** cannot be drafted from the repository. Do not ship
them as written.

### "What is your app about?"

> Submersion is a dive logging application for recreational and technical
> scuba divers. It records dives in full detail (depth, duration,
> temperatures, conditions, cylinders and gas mixes, buddies, sites and marine
> life), downloads dive data directly from over 350 dive computer models
> across 30 manufacturers over Bluetooth LE and USB, and analyses the
> resulting profiles with a Buhlmann ZH-L16C decompression model including
> per-compartment tissue loading, CNS percentage and OTU tracking.
>
> It also plans dives: multi-segment open-circuit, CCR, SCR and PSCR profiles,
> bailout validation, gas blending and MOD calculations.
>
> The application is local-first. Dive data lives in a SQLite database on the
> user's own device, which can optionally be encrypted at rest and unlocked
> with a passphrase or biometrics. There is no Submersion server, no account,
> no subscription and no advertising. Optional synchronisation between a
> user's own devices runs through storage the user already owns (Google Drive,
> Dropbox, iCloud or S3-compatible storage) and can optionally be end-to-end
> encrypted.
>
> Submersion is free and open source under GPL-3.0. The full source is at
> github.com/submersion-app/submersion.

### "Who is your target audience?"

> Certified scuba divers, from newly certified recreational divers logging
> their first dives through to technical divers running trimix, closed-circuit
> rebreathers and staged decompression. Secondary audiences are dive
> instructors and divemasters tracking student dives and equipment service
> schedules, and dive professionals who need an exportable, non-proprietary
> dive record.
>
> The application is aimed at adults. It is not directed at children, contains
> no user-generated content shared between users, and has no social or
> messaging features.

### "Why will your app be useful to users?"

> Dive logging software today splits into two groups: desktop applications
> with dated interfaces and no mobile presence, and mobile applications that
> hold a diver's log in a proprietary cloud the diver cannot export from.
>
> Submersion is the same application on Android, iOS, macOS, Windows and
> Linux, with identical detail and analysis on each, in 11 languages. The dive
> log is an SQLite database the diver owns, optionally encrypted at rest, and
> exportable at any time to UDDF 3.2, CSV, Excel, KML, GPX and PDF. Nothing is
> locked in and nothing depends on a service continuing to exist.
>
> For technical divers specifically, the decompression instrumentation (16
> tissue compartments for nitrogen and helium, user-set gradient factors, CNS
> and OTU totals across days and weeks, bailout validation against the worst
> point of a planned profile) is not available in any other free mobile
> application.
>
> Dive computer support is built on libdivecomputer, the same open-source
> library behind Subsurface, which is what makes 350+ computer models across
> 30 manufacturers practical rather than aspirational.

### "How did you recruit your testers?" **[FILL]**

Answer honestly and concretely. What reviewers want to see is that testers are
real people using the app, not accounts assembled to clear the threshold.

Structure that works:

> Testers were recruited from [where: the project's GitHub issue tracker, the
> existing iOS App Store user base, dive club contacts, the r/scuba community,
> and so on]. [N] testers joined, of whom [N] own dive computers in the
> supported set, which was the main thing I needed covered, since dive
> computer download is the highest-risk area of the app and needs real
> hardware to exercise.
>
> The project has been publishing beta builds publicly throughout at
> github.com/submersion-app/beta-builds, and the iOS build has been on the
> App Store [since DATE], which gave me an existing pool of users to invite.

The App Store presence is worth stating plainly. A reviewer seeing a shipping
iOS app at apps.apple.com/us/app/submersion-dive-log/id6757456915 is seeing
evidence this is not a throwaway listing.

### "What feedback did you receive, and how did you act on it?" **[FILL]**

This is the answer that decides the application. Generic text ("testers found
it useful, I fixed some bugs") is what declined applications look like. Give
three or four concrete items in this shape:

> **[Issue]:** [What a tester reported, in their terms.]
> **[Response]:** [What changed, with the version it shipped in.]

Candidates you can source from the changelog and issue tracker, phrased as
examples of the shape to use:

> - A tester reported that dive computer downloads produced duplicate dives
>   when the same dive was already in the log. I added a duplicate review step
>   that scores the match and offers four resolutions rather than silently
>   merging or silently duplicating.
> - Testers on the Play closed track were not seeing release notes on new
>   builds while TestFlight testers were. The upload pipeline was writing the
>   notes to a path the uploader did not read. Fixed in [version].

Pull the real ones. Two or three specific, traceable items beat six vague ones.

### "How did you engage with your testers during the test?" **[FILL]**

> Testers reported issues through the project's public GitHub issue tracker at
> github.com/submersion-app/submersion/issues and through [direct channel].
> Every reported issue was triaged and [N] were fixed and shipped to the
> closed track during the test window. Builds were published to testers [at
> what cadence: on every merge to main / weekly], each with release notes
> describing what changed.

The continuous beta pipeline is genuinely unusual for a solo application and
is worth stating, because it demonstrates a maintained release process rather
than a one-off build.

### "Why is your app ready for production?"

> The application has been in continuous development and public beta for
> [DURATION] and is already shipping to production on the Apple App Store
> (apps.apple.com/us/app/submersion-dive-log/id6757456915), where it has been
> through Apple's full review, including their privacy and permissions review.
>
> Engineering practice backing that claim:
>
> - A test suite of [N] tests runs on every change, sharded across CI, with
>   coverage reporting through Codecov and architecture guard tests that fail
>   the build on layering violations.
> - Automated static analysis treats analyzer info-level findings as fatal,
>   repository-wide.
> - CodeQL security scanning runs on every pull request.
> - Release builds are produced by an automated pipeline for all five
>   platforms from a single tagged commit.
> - The database carries a versioned migration ladder with an automatic backup
>   taken before any schema upgrade.
>
> The closed test found no crash-level defects that remain open. [Adjust if
> untrue.]

**VERIFY:** fill in the test count before submitting. `flutter test` reports
it, or read it off a recent CI run.

### "What are your plans after launching to production?"

> Submersion is an actively maintained open-source project, not a finished
> artefact. Every change merged to main is published as a beta build, and
> stable releases are promoted from that beta channel, so the production track
> will receive regular, tested updates rather than sporadic ones.
>
> Near-term priorities are expanding verified dive computer support (the
> library supports 350+ models; the number verified against physical hardware
> is smaller, and growing that list depends on testers with the hardware),
> broadening language coverage beyond the current 11, and continuing the
> decompression and planning work that technical divers ask for.
>
> Because the project is GPL-3.0 and developed in the open, issue tracking,
> roadmap and release history are all public at
> github.com/submersion-app/submersion.

---

## 3. Data safety form

Google's definitions, which decide every answer below:

- **Collected** means transmitted off the device. It does not mean "sent to
  the developer". Submersion has no server, but data that leaves the device
  for a third party is still collected under this definition.
- **Shared** means transferred to a third party. Google explicitly excludes
  transfers made "based on a specific user-initiated action, where the user is
  adequately informed". Every off-device transfer in Submersion is
  user-initiated and optional, so **Shared = No** throughout is defensible,
  provided the revised privacy policy informs the user (see 1.1).

### 3.1 The one genuinely ambiguous call

Sync and backup to the user's own Google Drive, Dropbox, iCloud or S3 bucket.

**Encryption here is opt-in and off by default.** `SyncPreferences`
(`lib/core/services/sync/sync_preferences.dart:44`) reads
`syncEncryptionEnabled` as `?? false`, and the provider wiring in
`lib/features/settings/presentation/providers/sync_providers.dart:483` is
explicit about the consequence: "No session (disabled, or enabled-but-locked)
resolves to the raw provider." A user who enables sync without enabling
encryption uploads a readable dive log. When encryption is on, the payload is
AES-256-GCM sealed on device with a key that never leaves it
(`sync_envelope.dart`), and no third party can read it.

The same is true of the database itself: `SecurityPreferences.dbEncryptionEnabled`
(`lib/core/services/security/security_preferences.dart:22`) is also `?? false`,
so encryption at rest is a Settings option rather than a property of the app.

Two defensible readings of the collection question:

1. **Declare it collected.** The bytes leave the device, so by the literal
   definition it is collection. Tick "Data is end-to-end encrypted".
2. **Declare it not collected.** The developer never receives it and no third
   party can read it, so nothing is meaningfully collected.

**Recommendation: reading 1.** Over-declaring has never caused a rejection.
Under-declaring is a policy violation that can suspend the app, and if a
reviewer decompiles the app and finds Dropbox and S3 upload paths against a
declaration of "no data collected", that is exactly the finding that triggers
one.

Reading 2 is also much weaker than it first appears, precisely because
encryption is off by default. The argument "no third party can read it"
applies only to users who went looking for the setting.

The table below follows reading 1.

### 3.2 Declaration table

Answer "Yes" to the gate question ("Does your app collect or share any of the
required user data types?").

For every row marked Collected: **Shared = No**, **Ephemeral = No**,
**Required or optional = Optional (users can choose whether to provide it)**,
**Purpose = App functionality**, and tick **Data is encrypted in transit**,
which is true everywhere because every destination is HTTPS.

Do **not** tick "Data is end-to-end encrypted" on any row. See 3.4.

| Data type | Collected | Why |
|---|---|---|
| **Location: Approximate** | Yes | Map tile requests to OSM, OpenTopoMap, ArcGIS and swisstopo imply the viewed area |
| **Location: Precise** | Yes | Dive site coordinates sent to Nominatim for reverse geocoding; coordinates sent to iNaturalist, GBIF and bathymetry services for nearby species and seafloor data; `GpsTracks.points` holds a gzipped JSON array of `[timestamp, lat, lon, accuracy]` fixes and rides the encrypted sync payload (`database.dart:528`) |
| **Personal info: Name** | Yes | Diver profile name and buddy names are rows in the encrypted sync payload |
| **Personal info: Email address** | Yes | Returned by Google, Dropbox, Garmin and Adobe OAuth when the user connects that account, and used to label the connection |
| **Personal info: User IDs** | Yes | OAuth subject identifiers for connected accounts |
| **Personal info: Address** | No | Not collected |
| **Personal info: Phone number** | **Yes** | Traced: the `Buddies` table has a `phone` column (`database.dart:2339`) and the `buddies` entity is in the sync payload. Dive buddy phone numbers therefore leave the device when sync is enabled. Note these are third parties' numbers, not the user's |
| **Personal info: Other info** | Yes | Certification records (agency, level, number, dates), dive notes and free-text fields in the encrypted sync payload. Buddy email addresses are also stored (`Buddies.email`) and synced |
| **Financial info** | No | No payments, no in-app purchases, no subscriptions |
| **Health and fitness** | No | HealthKit integration is iOS-only. The Android manifest declares no Health Connect permissions, verified: no `health` permissions in `android/app/src/main/AndroidManifest.xml`. Dive depth and duration are logged as dive records, not as health data |
| **Messages** | No | No messaging features |
| **Photos and videos** | **Yes** | Two separate upload paths, protected differently. Five image blob columns ride the encrypted sync payload (profile photos, certification card front and back, signature images). Dive gallery photos and video do not, but the opt-in media store uploads them **unencrypted**. Do not tick end-to-end encrypted on this row. See 3.2.1 |
| **Audio files** | No | Not collected |
| **Files and docs** | Yes | `ImportedFiles.bytes` retains every imported dive log file verbatim (`database.dart:3365`) and is in the sync payload, as is `RawDiveData.rawData`, the raw bytes libdivecomputer returned from the dive computer. Encrypted database envelopes are written to the user's chosen cloud storage |
| **Calendar** | No | Not accessed |
| **Contacts** | Yes | Buddy records are contact information by Play's definition (names, email addresses, phone numbers) and they ride the sync payload however they were entered. They can also come from the device address book on either platform: `READ_CONTACTS` is declared on Android by #2192 (see 5.8) |
| **App activity** | No | No analytics. Verified: no Firebase, Sentry, Crashlytics, Amplitude, Mixpanel or any analytics SDK in `pubspec.yaml` |
| **Web browsing** | No | Not collected |
| **App info and performance: Crash logs** | No | No crash reporting SDK |
| **App info and performance: Diagnostics** | No | No diagnostics reporting |
| **Device or other IDs** | No | No advertising ID, no device identifiers transmitted |

#### 3.2.1 Which images leave the device, and which do not

Traced through `lib/core/database/database.dart` and
`lib/core/services/sync/sync_data_serializer.dart`. The distinction matters
because it is the difference between a true declaration and a false one.

**Correction.** An earlier draft of this document claimed dive gallery photos
never leave the device. That is wrong, and the error mattered enough to call
out rather than quietly patch. There are two upload paths, not one, and only
one of them is encrypted.

**Path 1, the sync payload, encrypted only if the user turned encryption on.**
Dive gallery photos and video are *not* in it. They are stored as references: `Media.filePath` plus
`Media.platformAssetId` point at the asset in the operating system's own photo
library, and those bytes are never copied into app storage. That part of the
original claim holds.

**Path 2, the media store, not encrypted.** `lib/features/media_store/`
implements a separate, opt-in upload of dive photos and video to Google Drive,
Dropbox, iCloud or S3, so media is available across a user's devices. Traced
through `media_upload_pipeline.dart` and every adapter in
`lib/core/services/media_store/`: there is no encryption anywhere in the
feature. A case-insensitive search for `encrypt`, `cipher` or `aesgcm` across
`lib/features/media_store/` returns nothing. Photos go up over HTTPS and sit
in the user's cloud as ordinary readable files.

It is genuinely opt-in: `MediaStoreAttachState.attachedStoreId()` returns null
until the user attaches a store, so nothing uploads by default.

**Consequence for the form:** answer Yes for Photos and videos, and do **not**
tick "Data is end-to-end encrypted" on that row. The media store has no
encryption at all, and sync encryption is off by default, so the tick would be
false twice over. A false security declaration is a worse finding than a
missing one.

**Leaves the device when sync or backup is enabled.** Five blob columns hold
real image bytes and all five are in the sync payload:

| Column | Contents |
|---|---|
| `Divers.photo` | The user's own profile photo, a 512x512 JPEG |
| `Buddies.photo` | A dive buddy's profile photo, a 512x512 JPEG |
| `Certifications.photoFront` | Scan or photo of the front of a certification card |
| `Certifications.photoBack` | Scan or photo of the back of a certification card |
| `Media.imageData` | Handwritten signature images, used when `fileType` is a signature type |

The database comments say so directly. On `Buddies.photo`:

> Stored on the row so it syncs with the buddy rather than depending on a
> device-local path.

And the transport is confirmed rather than inferred:
`sync_data_serializer.dart:51` defines a value serializer whose entire purpose
is base64-encoding blob columns for sync export and import.

**Why this matters beyond the checkbox.** Three of these five are personal
data belonging to someone other than the user: a dive buddy's face, their
phone number, their email address, and their handwritten signature. A
certification card scan is closer to an identity document than to a photo,
since it carries a full name, a certification number, an issuing agency and a
date.

None of this is a policy problem in itself: it goes only to storage the user
already controls. But it is not protected the way an earlier draft of this
document claimed. Sync encryption is off unless the user enables it, so by
default a buddy's face, phone number and signature are uploaded in readable
form. It is a *disclosure* problem: the original `PRIVACY.md` did not
mention that buddy photos, buddy contact details or certification card images
are transmitted anywhere, and a user reading it would not expect a third
party's data to be uploaded on their behalf. Add it to the revision in 1.1.

### 3.3 Security practices section

| Question | Answer | Basis |
|---|---|---|
| Is all user data encrypted in transit? | **Yes** | Every network destination is HTTPS. Verified across `lib/`: no plain `http://` endpoints other than XML namespace URIs, which are identifiers rather than requests |
| Is data end-to-end encrypted? | **No** | Available but off by default on all three paths. See 3.4 |
| Do you provide a way for users to request data deletion? | **Yes** | Data can be deleted in-app at any time, uninstalling removes the local database, and cloud sync files are in storage the user controls directly |
| Have you committed to the Play Families Policy? | **No** | Target audience is adults; see 4.4 |
| Has your app been independently validated against a global security standard? | **No** | Do not claim this without a completed MASA audit |

### 3.4 The end-to-end encryption tick: do not use it

**Leave "Data is end-to-end encrypted" unticked on every row.**

An earlier draft of this document said the opposite, and the reasoning is
worth keeping so the mistake is not repeated. Reading
`lib/core/services/sync/crypto/sync_envelope.dart` shows AES-256-GCM sealing
with a device-held key and a doc comment describing "the byte form of every
encrypted sync file". That is accurate, and it says nothing about whether the
encrypting layer is in the chain at all.

It often is not. Three separate switches, all defaulting to off:

| Setting | Default | Source |
|---|---|---|
| `syncEncryptionEnabled` | `false` | `sync_preferences.dart:44` |
| `dbEncryptionEnabled` | `false` | `security_preferences.dart:22` |
| Media store encryption | Does not exist | `lib/features/media_store/` |

`sync_providers.dart:483` decides whether to wrap the cloud provider, and its
comment states the outcome plainly: "No session (disabled, or
enabled-but-locked) resolves to the raw provider."

Play's tick asserts that the data **is** end-to-end encrypted, not that it can
be. For a user who never opened Settings, none of it is. Ticking it would be a
false security declaration, which is a materially worse finding than a missing
one, and it is trivially checkable by anyone who installs the app and syncs.

**What to tick instead:** "Data is encrypted in transit", on every collected
row. That one is unconditionally true. Every destination in Appendix A is
HTTPS, verified across `lib/`: no plain `http://` request endpoints, only XML
namespace URIs, which are identifiers rather than requests.

**What to say if asked:** end-to-end encryption is available for sync and for
the database at rest, and users are encouraged to enable it. That is an honest
description of an optional feature, and it is what `PRIVACY.md` now says.

---

## 4. Store listing, rating and target audience

### 4.1 App name and short description

App name (30 characters maximum):

```text
Submersion: Dive Log
```

20 characters. Alternative if you want the category signal: `Submersion Scuba Dive Log`, 25 characters.

Short description (80 characters maximum):

```text
Dive logging and decompression analysis. Your data, your device, no account.
```

76 characters. Alternatives:

```text
Log dives, download your computer, analyse deco. Local-first and open source.
```

77 characters.

```text
Scuba dive log with 350+ dive computers, deco analysis and no cloud lock-in.
```

76 characters.

### 4.2 Full description (4000 characters maximum)

```text
Download your dive computer, check the deco on the profile, plan tomorrow's dive with the gas you actually have, and keep every bit of it on your own hardware. Rec or tech, single tank or rebreather, it all fits in the same logbook.

Free and open source. No account, no subscription, no ads, no tracking.

COMPREHENSIVE DIVE LOGGING
Depth, duration, temperatures, conditions, weather and tide. Any number of cylinders: air, nitrox, trimix, CCR and SCR. Buddies, divemasters, trips, tags, ratings and signatures. Browse as cards or as a sortable table with the columns you choose.

350+ DIVE COMPUTERS
Download straight from your computer over Bluetooth LE or USB, across 30 manufacturers, powered by libdivecomputer. Incremental downloads fetch only what is new. Duplicate review scores each match and offers four ways to resolve it. Two computers on one dive show their profiles overlaid.

PROFILE AND DECOMPRESSION ANALYSIS
Buhlmann ZH-L16C with your own gradient factors. All 16 tissue compartments for nitrogen and helium. CNS percentage, OTU and ppO2 with daily and weekly totals. Your computer's NDL, ceiling and TTS shown beside the model's.

DIVE PLANNING AND GAS
Multi-segment plans for open circuit, CCR, SCR and PSCR. Bailout checked against the worst moment of the profile. Contingencies, range tables and repetitive-dive seeding. MOD, best mix, rock bottom and a real-gas blender with fill costs.

SITES, MAPS AND MARINE LIFE
3,600 dive sites and 3,600 dive centers built in. Marker clustering, a dive heat map and downloadable offline map regions. Bathymetry overlays and 3D seafloor terrain. 685 species, recorded per dive and per site.

PHOTOS, GEAR AND CERTIFICATIONS
Photos and video matched to a dive by capture time, each shot marked at its depth on the profile. Equipment with service schedules, reminders and running costs. A wallet of certification cards, plus courses and checklists.

STATISTICS AND RECORDS
Ten pages of analysis: totals, progression, conditions, gas and more. Personal records for deepest, longest, coldest and warmest. Breakdowns by year, country, site and dive type. SAC trends, depth distribution and ascent-rate analysis.

YOUR DATA, ENCRYPTED
No server. No account. No lock-in.
- Optional encryption at rest, opened with your fingerprint, face or a passphrase
- Optional end-to-end encrypted sync between your own devices through your own Google Drive, Dropbox or S3 storage
- Encrypted backups, one taken automatically before every database upgrade
- Export to UDDF 3.2, CSV, Excel, KML, GPX and printable PDF

WHY SUBMERSION
Most dive logging software is either a desktop application stuck in the past or a mobile app that holds your dive history in a cloud you cannot export from. Submersion is the same application on Android, iOS, macOS, Windows and Linux, with the same detail and the same analysis everywhere, in 11 languages. Your dive log is a database file you own.

Open source under GPL-3.0. Source, issue tracker and roadmap:
github.com/submersion-app/submersion

IMPORTANT
Submersion is a dive logging and analysis tool. It is not a dive computer and must not be used as one. Decompression calculations are for planning and review only. Always dive with a functioning dive computer or tables, and within the limits of your training and certification.
```

That closing disclaimer is not optional padding. A decompression model in a
consumer app invites a safety question, and answering it before it is asked is
the difference between a listing that reads as responsible and one that reads
as a liability.

### 4.3 Graphic assets checklist

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512 x 512 PNG, 32-bit, under 1 MB, no transparency | Derive from `flutter_launcher_icons.yaml` source art |
| Feature graphic | 1024 x 500 PNG or JPEG, no transparency, no alpha | **Needs creating.** The README banner at `assets/brand/readme-banner.png` is the obvious starting point, reflowed to 1024 x 500 |
| Phone screenshots | 2 to 8 required. 16:9 or 9:16, each side 320 to 3840 px | `docs/assets/screenshots/readme/` holds 14 candidates, but they are desktop or composite layouts. **Needs real Android phone captures** |
| 7-inch tablet screenshots | Optional, up to 8 | Recommended: the app supports tablets and Play surfaces a "not designed for tablets" notice without them |
| 10-inch tablet screenshots | Optional, up to 8 | Same |

Suggested phone screenshot set, in order, drawn from what the README already
demonstrates works visually:

1. Dive detail with the profile, events and deco status
2. Dive computer download with the duplicate review step
3. Tissue loading panel across the 16 compartments
4. Dive site map with clustered markers and the heat map
5. Dive planner with a multi-segment profile and deco schedule
6. Statistics overview with totals and personal records
7. Gas blender showing the fill procedure
8. Data settings showing encryption, sync and export

Capture these on a real device or an emulator at phone resolution. Reusing the
desktop composites will look wrong at phone aspect ratio and reviewers do
notice.

### 4.4 Target audience and content rating

**Target audience: 18 and over.**

Rationale: selecting any age band under 18 pulls the app into the Play
Families Policy, which adds requirements around content, ads, data collection
and a separate review path. Submersion has nothing that benefits from that.
The trade-off is that junior certifications start at age 10, so an under-18
band is arguably accurate; it is not worth the added review surface, and
`PRIVACY.md` already states the app is not directed at children under 13.
Answer "No" to appealing to children.

**Content rating questionnaire (IARC):** category "Utility, Productivity,
Communication or Other". Expect every substantive question to be No:

| Question area | Answer |
|---|---|
| Violence, sexual content, profanity, controlled substances | No |
| Gambling or simulated gambling | No |
| User-generated content shared with other users | No. There are no social features and no server to share through |
| User communication features | No |
| Shares user location with other users | No. Location is used in-app and, if sync is enabled, in the user's own encrypted storage. It is never shared with other users |
| Digital purchases | No |
| Ads | No |

Expected outcome: Everyone / PEGI 3 or equivalent.

**Other declarations:**

| Declaration | Answer |
|---|---|
| Ads: does your app contain ads? | No |
| App category | Sports, or Health and Fitness. Sports is the better fit; Health and Fitness attracts extra scrutiny of health data claims that Submersion does not need to invite on Android, where HealthKit is not in play |
| Government app | No |
| Financial features | None |
| Health apps declaration | Not applicable. No Health Connect permissions are declared on Android |
| News app | No |
| COVID-19 contact tracing | No |
| Data deletion URL | Not required. No accounts exist, so there is nothing to delete server-side |

---

## 5. Policy pre-flight audit

Audited: `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, and the
network call sites in `lib/`.

### 5.1 Foreground service location (action required)

**Finding:** the manifest declares `FOREGROUND_SERVICE` and
`FOREGROUND_SERVICE_LOCATION`, and
`lib/features/gps_log/data/services/gps_track_recorder.dart:240` passes a
`ForegroundNotificationConfig` to geolocator, so a location-typed foreground
service really does start. No `<service>` element appears in the app manifest
because geolocator's library manifest supplies it through the manifest merger.

**Consequence:** Play Console requires a Foreground service permissions
declaration, reviewed by a human, including a video showing the feature in
use. This is the item most likely to add a round trip to your timeline, so do
it before or alongside the production access application rather than after.

**Declaration text:**

> Core use case: **Location**.
>
> Submersion records a GPS surface track while a dive boat is under way, so
> that dive sites can be positioned accurately and the surface interval route
> logged. Recording is started explicitly by the user and stopped explicitly by
> the user.
>
> A foreground service is required because the recording must continue while
> the screen is off. On a dive boat the phone is stowed or pocketed for the
> entire transit, which is exactly the period being recorded. Without a
> foreground service, Android suspends location updates and the track has
> holes over precisely the interval that matters.
>
> Alternatives considered and rejected: WorkManager and periodic background
> tasks cannot deliver the continuous, high-frequency location updates a track
> requires. The app does not request ACCESS_BACKGROUND_LOCATION; recording only
> runs while the user has explicitly started it and a persistent notification
> is displayed throughout.

That last sentence matters. Declaring a location foreground service *without*
background location permission is a strong position, and saying so explicitly
saves the reviewer from wondering.

**Video to record:** open the app, start GPS track recording, show the
persistent notification, lock the screen, unlock, show the track still
accumulating, stop recording. Under a minute. Upload unlisted to YouTube and
link it in the declaration.

### 5.2 Permission inventory

| Permission | Justification | Play risk |
|---|---|---|
| `INTERNET` | Sync, imports, map tiles, update check | None |
| `USE_BIOMETRIC` | Biometric unlock for app lock | None |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Attaching dive photos and video | Low. See 5.3 |
| `READ_EXTERNAL_STORAGE` (maxSdkVersion 32) | Pre-Android 13 media access | None. Correctly capped |
| `ACCESS_MEDIA_LOCATION` | Reads photo EXIF coordinates to suggest a dive site | Low, but declare the purpose in the privacy policy |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT` | Dive computer download | None. The `neverForLocation` flag is correct and helpful |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (maxSdkVersion 30) | Legacy BLE | None. Correctly capped |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Dive site coordinates, GPS track, BLE scanning on Android 11 and below | Medium. Tied to the 5.1 declaration |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | GPS surface track | **High. Declaration required. See 5.1** |
| `SCHEDULE_EXACT_ALARM` | Gear maintenance reminders | Medium. See 5.4 |
| `RECEIVE_BOOT_COMPLETED` | Re-arm reminders after reboot | None |
| `POST_NOTIFICATIONS` | Maintenance reminders | None |
| `READ_CONTACTS` | Selecting a dive buddy from the address book. Declared by #2192; absent from this branch until that merges | Low. Dangerous but not restricted, so no Permissions Declaration Form. It is a declared permission every review will see |

**Absent and worth noting:** no `ACCESS_BACKGROUND_LOCATION`, no
`QUERY_ALL_PACKAGES`, no `MANAGE_EXTERNAL_STORAGE`, no `REQUEST_INSTALL_PACKAGES`,
no `SMS` or `CALL_LOG` permissions. Those are the permissions that trigger the
heavyweight review paths, and the app requests none of them.

### 5.3 Photo and video permissions policy

**Finding:** the app declares broad `READ_MEDIA_IMAGES` and
`READ_MEDIA_VIDEO` rather than using the Android photo picker, which requires
no permission at all.

**Policy position:** Google's Photo and Video Permissions policy restricts
broad media access to apps where it is core functionality. Submersion
qualifies: it matches an entire photo library against dive times by capture
timestamp, which the one-shot picker structurally cannot do, since the user
cannot know which of 2,000 holiday photos fall inside a dive.

**Risk:** low but non-zero. If Play surfaces a media permissions declaration
form, the answer is:

> Core use case: **Photo or video gallery, backup or transfer**.
>
> Submersion matches a diver's photo library against logged dive times to
> attach photos and video to the correct dive automatically, and places each
> shot at its depth on the dive profile using its capture timestamp. This
> requires reading capture timestamps across the library rather than a
> user-selected subset, because the user cannot identify which photos fall
> inside a dive without the app performing that match. Media is referenced in
> place and is not copied into app storage.

That last sentence is true and load-bearing: your "links only, never copied"
architecture is a genuine privacy advantage here, so say it.

### 5.4 Exact alarms

**Finding:** the app declares `SCHEDULE_EXACT_ALARM`, not `USE_EXACT_ALARM`.
That is the correct choice. `USE_EXACT_ALARM` is restricted to alarm clock and
calendar apps and would likely be rejected here.
`SCHEDULE_EXACT_ALARM` is user-grantable and revocable.

**Residual question:** gear maintenance reminders are date-based, not
time-critical to the minute. An inexact alarm would serve them and would drop
the permission entirely. Not a blocker for this application, but worth an
issue: fewer sensitive permissions is a smaller review surface on every future
update.

### 5.5 No analytics, no ads, no trackers

**Finding:** confirmed by inspection of `pubspec.yaml`. No Firebase, Sentry,
Crashlytics, Amplitude, Mixpanel, or advertising SDK. No advertising ID access.

This is worth stating in the application. Reviewers see very few applications
with a genuinely empty tracker list, and it corroborates the local-first claim
rather than merely asserting it.

### 5.6 Target SDK

**Finding:** `android/app/build.gradle` sets `compileSdk = 37` and
`targetSdk = flutter.targetSdkVersion`.

**VERIFY:** resolve what `flutter.targetSdkVersion` evaluates to on your
Flutter version and confirm it meets Play's current minimum for new releases.
Play enforces a rolling target API level floor and rejects uploads below it.
If the resolved value is below the floor, pin `targetSdk` explicitly rather
than inheriting it.

`minSdk = 26` (Android 8.0) is fine and is a deliberate floor, not a default.

### 5.7 Open source and GPL-3.0

**Finding:** the app is GPL-3.0 and the full source is public.

No Play policy conflict. Play does not require source disclosure or forbid it.
Worth mentioning in the application as evidence of good faith: a reviewer can
verify every claim about data handling by reading the code, which is a
stronger position than most applicants can offer.

### 5.8 Contacts access on Android

Found during the egress sweep rather than looked for. Recorded because it
touches a Data safety row and adds a permission.

`READ_CONTACTS` was declared nowhere: not in
`android/app/src/main/AndroidManifest.xml`, and not in the merged manifest
either, since `flutter_contacts` 2.3.1 ships an Android manifest containing no
`uses-permission` elements at all. Meanwhile `isContactImportSupported` in
`lib/shared/utils/contact_import_support.dart` returned true for Android, so
the UI offered the feature. Android denies a runtime request for an undeclared
permission immediately, without showing a dialog, and the permission never
appears in system settings, so the user could not grant it. The feature had
never run on Android.

Fixed in #2192, which closes #2191. It declares the permission, adds a test
pairing the Dart platform gate to the manifest in both directions so they
cannot drift apart again, and routes the user to system settings after a
permanent denial.

**Merge order:** #2192 is a separate PR. Until it merges, this branch's tree
does not contain the declaration, so the 5.2 inventory row and the 3.2
justification describe the post-merge state. If #2192 is closed without
merging, revert those two and restore the iOS-only wording in `PRIVACY.md`.

**For this application:** the Data safety answer does not change. The Contacts
row in 3.2 was already Yes for a reason independent of the address book, which
is that buddy records are contact information by Play's definition however they
were entered. `READ_CONTACTS` is a dangerous permission but not a restricted
one, so it needs no Permissions Declaration Form, though it does add one more
declared permission that every review will see.

---

## 6. After approval

One switch, documented in `docs/developer/release-process.md`:

`PLAY_BETA_TRACK` defaults to `alpha` in `android/fastlane/Fastfile`. Once
production access is granted, open testing becomes available and the default
can move to `beta`. The helper validates the value and accepts only `alpha` or
`beta`, so a typo fails loudly rather than uploading to the wrong track.

Change the default in the `beta_track` helper, or set `PLAY_BETA_TRACK=beta`
in `.github/workflows/beta.yml` and `.github/workflows/promote.yml`.

The `promote-play` leg of the release pipeline, which currently cannot
succeed, starts working at the same moment. Verify the first promotion with a
staged rollout: `promote_to_production` already defaults to `rollout: "1.0"`,
which is 100 percent. For the first production release, pass a smaller value
explicitly.

---

## Appendix A: Egress inventory

Built by enumerating transport primitives and working outward, not by
grepping endpoint strings. The string approach missed Open-Meteo, NOAA tides
and every bathymetry source, because those build their URLs with
`Uri.https(hostConstant, path)` and never contain a literal URL.

Method, repeatable when a feature is added:

1. Every caller of an HTTP verb: `grep -rlE "\.(get|post|put|patch|delete|head|send|read)\("` across `lib/` and `packages/`
2. Every raw transport: `HttpClient(`, `Socket.connect`, `SecureSocket`, `WebSocket`
3. Every host constant reached through `Uri.https(_host, ...)`
4. Native code in `packages/` (Kotlin, Swift) for platform-channel egress
5. Non-network handoff: share sheet, `url_launcher`, printing, log export

### A.1 Automatic, no user action

| Destination | Sends | Notes |
|---|---|---|
| `api.github.com`, `github.com` | Nothing user-specific | Update check (`github_update_service.dart`). The server sees an IP address and a version |

That is the entire automatic list. Nothing else contacts the network unless a
user opens a feature or connects an account.

### A.2 Opt-in, user connects their own account

| Destination | Sends | Encrypted by Submersion |
|---|---|---|
| Google Drive | Sync and backup payload; media store uploads | Payload **only if the user enabled encryption**, off by default; media never |
| Dropbox | Sync and backup payload; media store uploads | Payload **only if the user enabled encryption**, off by default; media never |
| iCloud | Sync and backup payload; media store uploads | Payload **only if the user enabled encryption**, off by default; media never |
| S3-compatible storage | Sync and backup payload; media store uploads | Payload **only if the user enabled encryption**, off by default; media never |
| `sso.garmin.com`, `connectapi.garmin.com` | Garmin credentials, then dive downloads | Provider TLS only |
| `api.sports-tracker.com` | Suunto Cloud credentials, then dive downloads | Provider TLS only |
| `ims-na1.adobelogin.com`, `lr.adobe.io` | Adobe OAuth, then Lightroom library queries | Provider TLS only |
| User-configured media host | Credentials and requests to a NAS or server the user names (`network_scan_service.dart`, `network_url_resolver.dart`, `manifest_fetch_service.dart`) | Provider TLS only |

### A.3 Feature-triggered, no account, receives dive coordinates

This is the group that was under-counted. Opening the right screens can send a
dive site's coordinates to any of these:

| Destination | Feature |
|---|---|
| `nominatim.openstreetmap.org` | Reverse and forward geocoding |
| `tile.openstreetmap.org`, `tile.opentopomap.org`, `server.arcgisonline.com`, `data.geo.admin.ch` | Map tiles, which imply the viewed area |
| `archive-api.open-meteo.com` | Historical weather for a dive's date and place |
| `api.open-meteo.com` | Elevation lookup |
| `api.tidesandcurrents.noaa.gov` | Tide stations near a site |
| `api.inaturalist.org` | Species lookup |
| `api.gbif.org` | Nearby species |
| `data-gis.unep-wcmc.org` | Marine protected areas |
| `pae-paha.pacioos.hawaii.edu`, `coralreefwatch.noaa.gov` | Reef health |
| `services9.arcgis.com` | Reef habitat |
| `erddap.emodnet.eu`, `gis.ngdc.noaa.gov`, `www.gmrt.org`, `data.geo.admin.ch` | Bathymetry and seafloor terrain |

Roughly fifteen independent third parties can learn where a user dives,
depending on which features they open. Each request is TLS-encrypted in
transit and plaintext to the operator receiving it. None of them receives a
name, an account or an identifier; they receive coordinates and an IP address.

This does not change any Data safety answer, since Location: Precise was
already Yes. It does change what an honest privacy policy has to say, and it
is the one part of section 1.1 that remains outstanding.

### A.4 User-initiated handoff, not network

| Path | Notes |
|---|---|
| Share sheet (`share_plus`, 9 call sites) | The user hands an export or a photo to another app they choose |
| `url_launcher` | Opens a URL in the system browser |
| `printing` | Renders a PDF to a printer or share target |
| Log file | Written locally; the user attaches it to a bug report by hand. `log_redactor.dart` masks credentials before they reach the file |

Nothing here uploads on its own. Each is a deliberate user action.

### A.5 Confirmed not egress

Checked because each one looked like it might be, and was not:

| Subsystem | Finding |
|---|---|
| OCR (`packages/submersion_ocr`) | On-device. Android uses `com.google.mlkit:text-recognition:16.0.1`, the **bundled** model shipped in the APK, so no model download and no image upload. iOS and macOS use Apple's Vision framework. No network code in the package |
| libdivecomputer (`packages/libdivecomputer_plugin`) | BLE and USB only, local transport |
| Health | iOS HealthKit only, read-only. No Health Connect permission on Android |
| Analytics and crash reporting | None. No SDK in `pubspec.yaml` |
| Dive gallery photo bytes | Not in the sync payload. Uploaded only through the opt-in media store (3.2.1) |

## Open items

Collected from the **[FILL]** and **VERIFY** markers above:

- [x] ~~Revise `PRIVACY.md` to disclose all network destinations~~ Done (1.1)
- [x] ~~Correct the encryption claims~~ Done: sync, database and media
      encryption are each optional or absent, and the Data safety form must
      not claim end-to-end encryption (1.1, 3.4)
- [ ] Confirm the privacy policy is served at a public HTTPS URL (1.1)
- [ ] Confirm 12 testers stayed opted in for 14 continuous days (1.2)
- [ ] Write the tester recruitment answer (2)
- [ ] Write the tester feedback and response answer, with versions (2)
- [ ] Write the tester engagement answer (2)
- [ ] Fill in the test count and beta duration (2)
- [x] ~~Confirm whether a buddy record can hold a phone number~~ Traced: yes,
      `Buddies.phone` exists and syncs. Declared (3.2)
- [x] ~~Confirm whether media sync uploads image bytes or metadata only~~
      Traced: dive gallery media is references only, but profile photos,
      certification card scans and signature images are uploaded as base64.
      Declared (3.2.1)
- [x] ~~Disclose the third-party data transfer (buddy photos, phone numbers,
      email addresses, certification scans) in `PRIVACY.md`~~ Done: added the
      "Information About Other People" section and corrected the contradictory
      claims (1.1, 3.2.1)
- [x] ~~Enumerate every egress path~~ Done: Appendix A
- [x] ~~Disclose the coordinate fan-out (roughly fifteen third parties) in
      `PRIVACY.md`~~ Done (A.3)
- [ ] Complete the Foreground service permissions declaration and record the
      video (5.1)
- [ ] Resolve `flutter.targetSdkVersion` against Play's current floor (5.6)
- [ ] Create the 1024 x 500 feature graphic (4.3)
- [ ] Capture Android phone screenshots at phone aspect ratio (4.3)
