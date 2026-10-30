# How-To Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (this repo builds features inline, never through subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add thirteen task-based how-to guides for brand-new divers to the user guide, with a real screenshot at every step that needs one.

**Architecture:** Flat `docs/user/how-to-*.md` pages, an index page and a new sidebar section, published by the website's docsify viewer straight from `main`. Phase 1 writes every guide with screenshot markers and opens a draft PR; phase 2, after demo mode merges, captures and inserts the screenshots, and only then is the PR marked ready. `scripts/check_docs_links.py` gains two guards so the structure cannot drift.

**Tech Stack:** Markdown (GitHub-flavoured, docsify 5 with docsify-plugin-flexible-alerts), Python 3 stdlib for the guard, macOS app window and iOS Simulator for capture.

**Spec:** `docs/design/specs/2026-10-18-how-to-guides-design.md`

> **Resumed (2026-10-26):** Tasks 1 and 2 were done before the pause. The Settings > Data refactor and the Git backend have merged; the spec's "Resumed after the Settings > Data refactor" section records what changed. The two sync guides are now one (Task 3), so every later task moved up one number.

## Global Constraints

- No em dashes, and no en dashes as prose punctuation, anywhere (guides, plan, commits, PR). Scan every file before committing with the **dash scan**: `perl -CSD -ne 'print "$ARGV:$.: $_" if /[\x{2013}\x{2014}]/; close ARGV if eof' <files>` (prints nothing when clean).
- No tool attribution in any committed text, commit message or PR text.
- Guides are flat files in `docs/user/` named `how-to-*.md`; the index is `docs/user/how-to-guides.md`.
- Images live in `docs/user/images/how-to/<guide-slug>/<nn>-<what-it-shows>.png`, `<nn>` two digits in step order. `<guide-slug>` is the page name without `how-to-` and `.md` (for `how-to-sync-backups-photos.md` it is `sync-backups-photos`).
- Phase 1 screenshot marker, one per image, on its own line where the image will go:
  `<!-- screenshot: images/how-to/<guide-slug>/<nn>-<name>.png: <what it shows>; <mac|iphone>; <state> -->`
- Phase 2 image line: `![<alt text describing the screen>](images/how-to/<guide-slug>/<nn>-<name>.png)`.
- Every guide has these sections in this order: H1 title, one-sentence outcome, `## Before you start`, numbered step sections, `## Check it worked`, `## If something goes wrong`, `## Next steps`. A guide may add its own H2s where the flow needs them (a later-use section such as "Getting new dives later" after `## Check it worked`, or "When someone leaves" in the library guide).
- Callouts use `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!IMPORTANT]` only.
- UI names are bold and copied from `lib/l10n/arb/app_en.arb` values, never from memory. Menu paths use the form **Settings > Data > Sync between devices**.
- Where a phone and a desktop path differ, the step names both.
- A number with a unit in prose gives both systems: "18 m (60 ft)".
- Migration guides are titled "Moving from <App> to Submersion"; export steps inside the other app are written only, never screenshotted.
- No real person's data in any image or example value: no real names, e-mails, bucket names, keys, account IDs, home sites or real dives.
- Commit messages: `docs(user-guide): <summary>` for guide pages, `feat(docs): <summary>` for the guard script.

## Review Focus

1. **A label the app does not use.** A reader looks for a button the guide names and it is not there, or is worded differently (the Settings > Data refactor renamed most of that section, so older docs and memory are unreliable). Each guide task runs the label check in Task 2's Interfaces block, and Task 12 re-checks every label on screen.
2. **A link that works on GitHub but not on the website** (or the reverse). Anchors must use the docsify slug. `check_docs_links.py` already fails on this; every task runs it.
3. **A migration guide promising data that does not come across.** "What comes across" lists are taken from the parser and its tests, not from the format table in `import-export.md`. Each migration task names the parser to read.
4. **Phone and desktop readers diverging.** A step written for the desktop sidebar strands a phone reader. Each guide task checks the navigation path in `lib/core/router/` and the nav layout before writing a step.
5. **Personal data in a screenshot.** Task 13 inspects every image at full size before inserting it, and screens that would show real dives are not captured at all.

---

## Phase 1: guides with screenshot markers

### Task 1: Guard: every how-to guide is listed in the index

**Files:**
- Modify: `scripts/check_docs_links.py` (`check_user_docs`, near the sidebar check)
- Test: `scripts/check_docs_links_test.py` (`UserDocsTests`)

**Interfaces:**
- Produces: a failure line `docs/user/<page>: not linked from how-to-guides.md, so the How-To Guides index misses it` for any `how-to-*.md` page (other than `how-to-guides.md`) the index does not link. No failure when `how-to-guides.md` does not exist and no `how-to-*.md` page exists.

- [ ] **Step 1: Write the failing tests** in `UserDocsTests`:
  - `test_how_to_page_missing_from_index_fails`: write `docs/user/how-to-guides.md` (`# How-To Guides\n`) and `docs/user/how-to-media-sync.md` (`# Set Up Media Sync\n`), link both from the sidebar; assert exactly one failure containing `how-to-media-sync.md` and `how-to-guides.md`.
  - `test_how_to_page_in_index_passes`: same, with the index linking `[Media](how-to-media-sync.md)`; assert `[]`.
  - `test_how_to_page_without_index_fails`: a `how-to-media-sync.md` linked from the sidebar and no index page; assert one failure naming `how-to-guides.md`.
- [ ] **Step 2: Run them and see them fail:** `python3.14 scripts/check_docs_links_test.py -k how_to -v` gives 2 failures (the passing case already passes).
- [ ] **Step 3: Implement** in `check_user_docs`: collect the index's link basenames the same way the sidebar's are collected (reuse `_unfenced_lines`, `_link_targets`, `SCHEME_RE`), then fail each `how-to-*.md` page not in that set. Add constants `USER_HOW_TO_INDEX = "how-to-guides.md"` and `USER_HOW_TO_PREFIX = "how-to-"` beside `USER_SIDEBAR`.
- [ ] **Step 4: Run the full test file and the real check:** `python3.14 scripts/check_docs_links_test.py -v` (all pass) and `python3.14 scripts/check_docs_links.py` (OK on the real tree).
- [ ] **Step 5: Commit** `feat(docs): check every how-to guide is listed in its index`.

### Task 2: Index page, sidebar section and home-page link

**Files:**
- Create: `docs/user/how-to-guides.md`
- Modify: `docs/user/_sidebar.md` (new section after **Getting Started**)
- Modify: `docs/user/README.md` (the "New here?" note)

**Interfaces:**
- Produces: the index page with three headed groups, **Get set up** (sync, backups and photos; shared library), **Use the app** (GPS, dive logging, display) and **Moving from another app**, each line `- [<Guide title>](<page>.md): <what you will have when you finish>`. Each later task adds its own line to the index and the sidebar.
- Produces: the sidebar block, first line `**How-To Guides**`, then `- [All How-To Guides](how-to-guides.md)`; migration guides go under a nested `- Moving from another app` item, indented two spaces.
- Produces the **label check** every guide task runs. From the repo root:

  ```bash
  python3.14 - docs/user/how-to-<slug>.md <<'EOF'
  import json, re, sys
  values = {v for k, v in json.load(open("lib/l10n/arb/app_en.arb")).items() if not k.startswith("@") and isinstance(v, str)}
  text = open(sys.argv[1]).read()
  for bold in sorted(set(re.findall(r"\*\*([^*]+)\*\*", text))):
      for part in [p.strip() for p in bold.split(">")]:
          if not any(part == v or part in v for v in values):
              print("NOT IN ARB:", part)
  EOF
  ```

  Every `NOT IN ARB` line is either fixed or confirmed as non-UI emphasis (a field the reader types, a heading word) by reading the widget that renders that screen.

- [ ] **Step 1:** Write `how-to-guides.md`: H1 `How-To Guides`, two sentences on who they are for and how they differ from the reference pages, and the three group headings with no entries yet.
- [ ] **Step 2:** Add the sidebar section after **Getting Started**, containing only the index link for now.
- [ ] **Step 3:** In `README.md`, extend the "New here?" note with a sentence linking [How-To Guides](how-to-guides.md).
- [ ] **Step 4: Verify:** `python3.14 scripts/check_docs_links.py` passes; the dash scan over `docs/user/how-to-guides.md docs/user/_sidebar.md` prints nothing, and `docs/user/README.md` gains no new hits.
- [ ] **Step 5: Commit** `docs(user-guide): add the How-To Guides section and index`.

### Guide task pattern (Tasks 3 to 10)

Every guide task follows these steps; each task below lists only its files, sources and content decisions.

- [ ] **Step 1: Trace the real flow** in the listed source files: every screen in order, its title, the buttons and fields used, where it differs between phone and desktop, and the error states a new user is likely to hit. Write nothing until the flow is traced.
- [ ] **Step 2: Write the page** in the Global Constraints section order, with a screenshot marker after each step a reader needs to see.
- [ ] **Step 3: Add** the page's line to `how-to-guides.md` and to the sidebar.
- [ ] **Step 4: Verify:** run the label check (Task 2) and resolve every line; `python3.14 scripts/check_docs_links.py` passes; the dash scan finds nothing.
- [ ] **Step 5: Commit** `docs(user-guide): add the <guide title> how-to`.

### Task 3: Set Up Sync, Backups and Photos

**Files:** Create `docs/user/how-to-sync-backups-photos.md`; modify `docs/user/set-up-this-device.md` (step 1's list of accounts gains a Git repository, for sync and backups). Sources: `lib/features/settings/presentation/pages/set_up_device_page.dart`, `lib/features/settings/presentation/widgets/set_up_device/` (the account, sync, backups and photos steps, the done view, the Data page card and the Settings root card), `lib/features/settings/presentation/providers/set_up_flow_provider.dart`, `lib/features/settings/presentation/widgets/accounts/account_chooser.dart` and `account_sign_in.dart`, and `lib/features/setup_wizard/presentation/` (how first run reaches the four steps after **Profile** and **Units**); `docs/user/set-up-this-device.md`, `multi-device-sync.md`, `backup-and-restore.md`, `media-sync.md`.

- H2s after the outcome: `## Before you start`, `## On your first device`, `## On your second device`, `## Check it worked`, `## Using a different account`, `## If something goes wrong`, `## Next steps`.
- First device starts in the first-run wizard after **Profile** and **Units**. A `> [!TIP]` covers readers who tapped **Not now** or whose device predates the flow: the **Set up this phone** card at the top of **Settings > Data**, **Continue**. Then step 1 (Google Drive, sign in), step 2 (**Turn on sync**, **Keep devices in step automatically** on), step 3 (**Back up automatically**, **Also keep a copy in** Google Drive), step 4 (**Keep photo copies in** Google Drive with **Upload new photos automatically** and **Use cellular data**, or **Skip**), and the done screen.
- Second device: the same account in step 1; **Download library** on a device with no dives, or **Combine them** (default) versus **Replace the dives here with the library** with what each costs; step 4's **Use the photo copies in** Google Drive.
- Encryption: one line linking `encrypted-sync.md`, placed where the traced flow first meets encryption.
- `## Using a different account`: iCloud (Apple devices, App Store builds), Dropbox, **My own server** (S3-compatible or WebDAV; link `multi-device-sync.md#example-cloudflare-r2-s3-compatible`), Git (sync and backups only, so photos need a second account or **Skip**; link `multi-device-sync.md#git-repositories`), a few lines each.
- Before you start: a Google account, your second device with Submersion installed, about 10 minutes.
- `set-up-this-device.md` correction: step 1 names Git beside the other accounts, says it holds sync and backups only, and links `multi-device-sync.md#git-repositories`. One commit for the guide, one for the correction.

### Task 4: Set Up a Shared Site Library

**Files:** Create `docs/user/how-to-shared-site-library.md`; modify `docs/user/shared-site-libraries.md` (the sentence ending "have an equivalent per-key prefix setting"). Sources: `lib/features/shared_library/presentation/pages/connect_shared_library_page.dart`, `shared_libraries_page.dart`, `shared_library_page.dart`, `shared_library_members_page.dart`; `docs/user/shared-site-libraries.md`.

- Parts as H2s: `## For the organizer: create the library`, `## For members: join the library`, `## For the organizer: approve members`, `## Everyone: using the shared sites`, `## When someone leaves`.
- Organizer: create an R2 bucket only for the library (written R2 dashboard steps); one R2 API token per member, permission **Object Read & Write**, scoped to that bucket; connect, **Create library**, store the **recovery code**; send each member the library folder, the bucket endpoint and their own key.
- `> [!WARNING]` that R2 cannot limit a key to folders, so a member's key can write or delete anything in the library bucket; signatures stop a forged or altered edit counting; backups repair deletions; strict reader keys need AWS S3 (link to `shared-site-libraries.md#s3-compatible-storage`).
- Member: **Connect a library**, enter the library folder, add the server with **My own server** and their own key, **Check location**, **Join**; until approved they read but their writes do not count.
- `## When someone leaves`: **Remove from library** on the **Members** page stops their edits and suggestions counting; deleting their R2 key stops them reading; **Allow back** if they return. This is the reason each member gets their own key.
- What stays private: notes and rating, dives and photos (from the reference page).
- Reference correction: R2 limits keys to buckets, not folders; say so, keep the other services' sentence accurate.

### Task 5: Log GPS Tracks on Your Phone

> **Unblocked:** #3704 was fixed by PR #3709 (the import wizard now sweeps tracks on every import). Written after phase 1's other guides.

**Files:** Create `docs/user/how-to-gps-track-logging.md`. Sources: `lib/features/gps_log/data/services/gps_track_recorder.dart`, `gps_track_match_service.dart`, `lib/features/gps_log/presentation/widgets/gps_record_card.dart`, `gps_recording_strip.dart`, `lib/features/tracks/presentation/pages/tracks_page.dart`, `gps_track_detail_page.dart`; platform permission strings in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`.

- The boat day: before leaving (location permission, including background where the platform asks), start recording as the boat leaves, phone stays on the boat, stop at the dock, download the computer (link to `how-to-log-a-dive.md`), each dive picks up its position from the track, see the track under **Tracks**.
- Battery and permission advice only as far as the code supports it (what happens when the app is backgrounded or the phone locks, from the recorder).
- If something goes wrong: no position on a dive (track does not cover the dive's time, matching rules from the match service), recording stopped in the background.

### Task 6: Log a Dive from Your Computer

**Files:** Create `docs/user/how-to-log-a-dive.md`. Sources: `lib/features/dive_computer/presentation/` (discovery, pairing, download widgets and `device_list_page.dart`, `device_detail_page.dart`), `lib/features/dive_log/presentation/` (dive edit and detail pages); `docs/user/dive-computer.md`, `dive-logging.md`, `first-dive.md`.

- Connect the computer the first time (Bluetooth and USB; BLE PIN), download, review what came in (no screenshot marker for the review screen; written only).
- From "open the new dive" on, introduced with "Your dive will look something like this one": site, buddy, gear, conditions, photos, then the finished dive and its profile.
- Link to `first-dive.md` for manual entry.

### Task 7: Customize the Display

**Files:** Create `docs/user/how-to-customize-display.md`. Sources: `lib/features/settings/presentation/pages/section_appearance_page.dart`, `home_appearance_page.dart`, `nav_customization_page.dart`, the appearance and units settings pages under `lib/features/settings/presentation/`; `docs/user/settings.md`.

- Order: look and feel (theme, light or dark, display size); units and formats (revisit the setup wizard's choice, fine-tune); the Dashboard (status chips, home cards, order); the dive list (Detailed, Compact or Table, fields, colour cards by depth, duration or temperature); navigation (phone bottom bar, desktop sidebar).
- Next steps links to `dive-profiles.md` for chart overlays.

### Task 8: Moving from MacDive to Submersion

**Files:** Create `docs/user/how-to-move-from-macdive.md`. Sources: `lib/features/universal_import/data/parsers/macdive_xml_parser.dart`, `macdive_sqlite_parser.dart` and their tests under `test/features/universal_import/data/parsers/`, `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart`; `docs/design/specs/2026-04-21-macdive-import-design.md`.

- Establishes the migration shape every later migration task copies: what comes across and what does not (from the parsers and tests), export (written), import through the wizard, review (duplicates, sites, buddies, gear), check it worked.
- Recommends one route (XML export or reading the SQLite database) with the reason, mentions the other.
- Resolves issue #2621: where MacDive's database file lives, per platform MacDive runs on, and how to reach a hidden Library folder on macOS. Take the path from the parser's design docs and tests; if they do not give it, ask the maintainer rather than guessing.

### Task 9: File-based migrations

**Files:** Create `docs/user/how-to-move-from-subsurface.md`, `how-to-move-from-shearwater-cloud.md`, `how-to-move-from-diving-log.md`, `how-to-move-from-dan-divecloud.md`. Sources per guide: `subsurface_xml_parser.dart` and `parsers/subsurface/`; `shearwater_cloud_parser.dart`; `divinglog_sqlite_parser.dart`; `dan_dl7_import_parser.dart` and `parsers/dl7/`; each with its tests.

- Same shape as Task 8. (The optional Subsurface sample-data CSV is left out: no wizard step exposes it, so a reader could not follow the step.) Diving Log says its XML export is not readable yet and to use the database file. DAN covers the DiveCloud ZIP.
- One commit per guide.

### Task 10: Cloud migrations

**Files:** Create `docs/user/how-to-move-from-garmin-connect.md`, `how-to-move-from-suunto.md`, `how-to-move-from-divelogs-de.md`. Sources: `lib/features/transfer/presentation/pages/transfer_page.dart` and the cloud import flows it opens (Garmin, Suunto, divelogs.de), `fit_import_parser.dart`; `docs/user/import-export.md`.

- Same shape. Screenshot markers stop at the sign-in step; the import review is written only.
- Garmin recommends **Transfer > Cloud** and mentions FIT files and the watch by cable. Suunto says DM5 users export UDDF.
- One commit per guide.

### Task 11: Open the draft PR

- [ ] **Step 1:** `dart format .` (no Dart changes expected), `python3.14 scripts/check_docs_links_test.py`, `python3.14 scripts/check_docs_links.py`, and the dash scan over `docs/user/how-to-*.md docs/design/plans/2026-10-18-how-to-guides.md`.
- [ ] **Step 2:** Push and open the PR as a **draft** from the repo template: `Closes #3510`, `Closes #2621`, links to the spec and this plan, Follow-ups lists the two reference-page corrections (R2 keys in `shared-site-libraries.md`, Git in `set-up-this-device.md`) and #2621. The template's Screenshots section is deleted (no app UI path is touched); the Summary says the guide images land in phase 2 before the PR leaves draft.

## Phase 2: screenshots (after demo mode merges)

As run, demo mode sealed sync, backups, imports and downloads, so capture used the sample logbook as an ordinary logbook, and a local stand-in for Google Drive for the setup guide. The spec's Screenshots section records this; where it differs, it replaces Tasks 12 and 13 below.

### Task 12: Prepare capture and re-check the flows

- [ ] **Step 1:** Ask the maintainer to confirm demo mode keeps its logbook apart from `~/Documents/Submersion` and allows sync, backups, photo copies, a shared library, file imports and a dive computer download. If not, stop and revisit the capture plan with them.
- [ ] **Step 2:** Merge `origin/main` (ccd_host `sync_with_base_branch`) and re-run the label check on every guide, rewriting any step whose label changed since phase 1. Prepare a fresh, empty data folder for the setup guide's first-run captures.
- [ ] **Step 3:** Start a local S3-compatible server for the library guide (a MinIO binary or moto server; no Docker), with made-up bucket and keys recorded only in the scratchpad.
- [ ] **Step 4:** Collect sample import files: from demo mode where it provides them, else from `test/fixtures/` (macdive_xml, macdive_sqlite, suunto, universal_import, the Subsurface CSVs) or a small file built for the purpose; never a maintainer export.

### Task 13: Capture and insert, one guide at a time

- [ ] **Step 1:** Launch the app on the demo logbook (the `run` skill): macOS window at 1280 x 800 points for Mac shots; iOS Simulator (an iPhone) for `iphone` markers, with the boat route GPX played as the simulated location for the GPS guide. The maintainer signs in to Google for Task 3 and brings the dive computer for Task 6.
- [ ] **Step 2:** Capture each marker's screen in the stated state. Resize Mac shots to 1600 px wide and phone shots to 600 px wide (`sips --resampleWidth`), aiming under 250 KB each.
- [ ] **Step 3:** Open every image at full size and check for personal data; recapture any that shows some.
- [ ] **Step 4:** Replace each marker with its image line; re-check every bold label against the screen.
- [ ] **Step 5:** `python3.14 scripts/check_docs_links.py` passes (all image paths resolve). Commit per guide: `docs(user-guide): add screenshots to the <guide title> how-to`.

### Task 14: Guard: no screenshot marker left in a how-to guide

**Files:** Modify `scripts/check_docs_links.py` (`check_user_docs`); test in `scripts/check_docs_links_test.py`.

- [ ] **Step 1: Failing tests:** `test_screenshot_marker_in_how_to_fails` (a `how-to-x.md` holding `<!-- screenshot: images/how-to/x/01-a.png: a; mac; b -->` gives one failure containing `screenshot marker`); `test_screenshot_marker_in_reference_page_passes` (the same line in `dive-sites.md` gives no failure, since reference pages keep their placeholders).
- [ ] **Step 2:** Run them; one fails.
- [ ] **Step 3: Implement:** for pages starting `how-to-`, an unfenced line containing `<!-- screenshot:` fails with `docs/user/<page>:<line>: screenshot marker left in a how-to guide; capture the image and replace the marker`.
- [ ] **Step 4:** Full test file passes; the real check passes on the tree.
- [ ] **Step 5: Commit** `feat(docs): fail a how-to guide that still holds a screenshot marker`.

### Task 15: Ready for review

- [ ] **Step 1:** Send all screenshots to the maintainer in one SendUserFile call (they are committed, so the PR diff shows them).
- [ ] **Step 2:** Update the PR description, mark it ready for review, then continue with build-feature steps 6 to 9 (two review rounds, Copilot, auto-fix).
