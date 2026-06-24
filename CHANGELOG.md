# Changelog

All notable changes to Submersion are documented in this file.


## 1.5.6 (2026-06-24)

### Features

- default ascent-rate toggles off, unify naming
- adopt replaced library via bounded streaming (fixes #358)
- streaming replace-adopt apply with parity test (#358)
- bounded recordIdsFor id enumeration for streaming adopt (#358)
- bulk dive-mode + rebreather cascade (mode/setpoints/scrubber) with OC contradiction guard
- bulk form Weather group (wind/cloud/precipitation/humidity/description)
- bulk form Conditions group (water/visibility/current/swell/entry-exit/altitude/pressure)
- bulk form collections (tags/equipment/buddies/weights/tanks/sightings) with Add/Remove/Replace
- add BulkCollectionModeSelector
- bulk form Logistics + Notes groups with save/confirm/undo flow
- add BulkField set + scalar DivesCompanion builder
- add BulkFieldGate field wrapper
- open bulk-edit route from multi-select toolbar; remove superseded bulk sheet
- add BulkDiveEditPage + /dives/bulk-edit route
- add DiveEditPage bulk mode (constructor, isBulk, build branch skeleton)
- add Select-by-date-range to multi-select toolbars
- shift-click range selection with a selection anchor
- add bulkDiveEditServiceProvider
- add BulkDiveEditService.undo (per-dive restore)
- add BulkDiveEditService.apply with snapshot capture
- add BulkEditSnapshot data holder
- add BulkEditRequest and collection-op model
- add bulk sightings add and replace
- add bulk buddy add/remove/replace for dives
- add bulk weights add and replace
- add bulk tank add (onlyIfEmpty) and replace
- add bulk equipment add/remove/replace
- add DiveRepository.bulkReplaceTags
- add DiveRepository.bulkAppendNotes
- add DiveRepository.bulkUpdateFields generic bulk scalar update
- flatten The Dive group to rows + restore calculate buttons (#388)
- one-tap calculate affordance on FormRow.text (#388)
- graph ascent rate (#242)
- emit UDDF-shaped payload with tanks/deco/gps/sourceUuid
- orchestrate extractors into enriched ImportedDive
- extend ImportedDive with tanks/deco/summary fields
- extract dive summary/session/settings fields
- extract profile samples with recorded deco fields
- extract tanks and pressure series from msgs 319/323
- extract gas mixes from dive_gas messages
- map Garmin product codes to model names
- resolve local wall-clock from FIT local_timestamp
- add FIT constants and GenericMessage field access
- enable trackpad scroll/pinch zoom on all 17 map sites
- two-finger trackpad scroll/pinch zooms the dive profile chart
- add kind-aware TrackpadZoomMap two-finger-scroll zoom wrapper
- add trackpadScrollZoomDelta helper

### Bug Fixes

- address PR review on recordIdsFor (#358)
- defer log construction off the delegate queue; cover retry paths
- retry OSTC nano BLE downloads, unblock the notification queue (#394)
- add Deselect All to master-detail selection bar; pair with Select All on phone
- address PR review (bulk dive-type error msg, localized null option, empty-ids route guard, dirty tracking)
- address review - bulkAddTanks evaluates onlyIfEmpty once per dive; bulkUpdateFields no-ops on empty companion
- address review - fix shift-click anchor walk; fail-fast on unsupported owned-collection modes
- restore numeric input filters on metric rows + harden calc-icon tests (Copilot review #392)
- address Copilot review on ascent-rate graphing
- refresh home tab dive providers on direct DB writes (#217)
- correct real-file timezone base and multi-gas/AI tank handling
- map recorded ceiling and entry/exit GPS onto imported dives
- persist entry/exit GPS in createDive
- keep SAC curve when tank pressure is keyed to a stale tank (#276)
- address review - catch struct.error in guard, chain platform onError (#318)
- stop save from overriding cleared Country/Region
- address review - fail-closed guard + guard BLE discovery (#318)
- prevent and diagnose 16 KB-page native load crash (#318)
- flip trackpad scroll zoom direction (up = out, down = in)
- 16 KB page-align liblibdc_jni.so for Android 15+

### Refactoring

- extract in-memory adopt as debug reference seam (#358)
- drop unused StatCell profile glyph (#388)
- move timestamp normalization into FitTimeResolver
- TrackpadZoomMap via arena-winning recognizer

### Documentation

- implementation plan for streaming replace-adopt (#358)
- bulk dive editing form implementation plan (#150)
- bulk dive editing spec + engine plan (#150)
- plans
- clarify home-tab reactivity comments (Copilot review, #217)
- add Garmin FIT import design spec and implementation plan
- trackpad scroll-to-zoom spec and implementation plan
- release notes

### Tests

- cover ascent-rate changes; harden sync fallback
- cover all collection ops, tank cards, notes-append (bulk methods 90%)
- cover numeric scalar conversion paths in bulk save
- cover nothing-selected guard + collection-mode save path
- cover all buildScalarCompanion branches (100%)
- cover bulk save flow end-to-end (gate, toggle, confirm, DB apply)
- const MaterialApp in bulk form test (analyzer)
- comprehensive bulk-edit coverage (service ops, provider, selection widget tests)
- raise patch coverage + fix test formatting
- cover air-integration path + address Copilot review
- cover provider seam + use-my-location; settle after save
- raise patch coverage for the #318 error-handler changes
- cover trackpad zoom rollout + address PR review

### CI/CD

- bump actions/download-artifact from 7 to 8
- bump actions/checkout from 6 to 7

### Chores

- bump version to 1.5.6+108
- bump submodule to OSTC3 BLE retry (4ac9867)
- remove orphaned forms_statCell_useProfileValue (#388)

### Other

- i18n(dive-log): localize all bulk-edit form strings (17 keys across 11 locales)
- i18n(dive-log): localize bulk-form Conditions/Weather field labels via existing keys
- apply canonical dart format to bulk-edit files
- i18n(dive-log): add select-by-date-range tooltip in all 11 locales
- reword unit-volume fallback comment; clearer non-null local in test
- docs+test: address second Copilot review


## 1.5.5 (2026-06-22)

### Chores

- bump version to 1.5.5+107


## 1.5.4 (2026-06-21)

### Features

- double-tap-hold to pan on profile chart (touch)
- desktop hover select and click-drag pan on profile chart
- trackpad pinch zoom-to-cursor and two-finger pan on profile chart
- anchor dive profile zoom to cursor/pinch via ProfileChartViewport
- add chartDragIntent pointer-kind drag routing
- add chartFocalFraction plot-rect focal mapping
- add ProfileChartViewport for cursor-anchored profile zoom
- localized internal/SD-card chooser dialog (#300)
- Android internal/SD-card chooser via external dirs (#300)
- Android SAF folder picker + label display (#300)
- ref-aware restore/delete/history for SAF backups (#300)
- route performBackup through BackupTarget with SAF self-heal (#300)
- add BackupTarget abstraction (filesystem + SAF) (#300)
- add BackupSafPort seam over the SAF facade (#300)
- scaffold submersion_saf plugin for SAF backups (#300)

### Bug Fixes

- surface Android serial I/O errors as IO, not timeout (#334)
- fail fast on serial EOF/error, harden read tests (#334)
- identify Halcyon Symbios Handset instead of HUD (#357)
- accumulate USB-serial reads to the full packet (#334)
- read gas-strip flag via ref.read in gesture paths (PR review)
- trackpad pinch/pan jumped to the lower-right corner on macOS
- gate profile-chart drag-pan to a live single-pointer count
- route trackpad pinch solely through the cursor-anchored handler
- OSTC nano (hw_ostc3) downloads over BLE (#280)
- import all o2 sensors, not only the first one
- drop OC depth x FO2 fallback for CCR/SCR CNS
- compute CCR/SCR CNS from measured loop ppO2
- identify Scubapro G2 HUD instead of Aladin Sport Matrix (#285)

### Refactoring

- extract testable chooser dialog + resolveAndroidDbDir; coverage:ignore native glue (#300)
- extract BackupDatabaseAdapter to break the backup_target import cycle (#300)

### Documentation

- add dive profile chart zoom & navigation spec and plan

### Tests

- cover SAF port/target/restore + db-location chooser; patch coverage 32% -> 97% (#300)
- cover trackpad two-finger-scroll pan on profile chart

### Chores

- bump version to 1.5.4+106
- add Copilot code-review instructions for Dart 3 semantics

### Other

- cancel DB-location pick on dismiss, clear chooser, cancel SAF pick on detach (#300)
- dart format SAF backup sources (#300)


## 1.5.4 (2026-06-20)

### Features

- adopt base via streaming temp-file apply (#358)
- streaming base reader + checksum-verifying part file sink
- USB-serial dive computer support on Android (#334)

### Bug Fixes

- correct Halcyon Symbios Tx/Rx direction (#288)
- harden base import on truncated/partless manifests (review)
- serial-over-USB downloads on macOS/iOS (#334)

### Documentation

- implementation plan for streaming base import (#358)
- spec streaming base import to fix iCloud sync OOM (#358)

### Tests

- deterministic base temp-file cleanup check
- convergence covers streaming base adoption end to end (#358)
- parity between streaming and in-memory base apply (#358)

### Chores

- bump version to 1.5.4+105

### Other

- try all USB ports + non-blank serial error message (#364)
- flush dives on cancel + validate USB permission device (#364)


## 1.5.4 (2026-06-20)

### Features

- show City/Island/Body of Water on the site detail view (#344)
- add City/Island/Body of Water to the site edit form (#344)
- add city/island/body-of-water table columns (#344)
- add city/island/body-of-water suggestion helpers (#344)
- map city/island/bodyOfWater in repository read, write, search (#344)
- include city/island in DiveSite.locationString (#344)
- add city, island, bodyOfWater to DiveSite entity (#344)
- add city and island columns to dive_sites (schema v90) (#344)

### Bug Fixes

- trim values in locationString for whitespace consistency (#344)
- carry city/island/bodyOfWater through site merge (#344)
- write Symbios commands to Tx on Windows and Linux too (#288)
- write Halcyon Symbios commands to Tx, not Rx (#288)
- force path-style addressing for dotted bucket names
- import and use ccr o2 sensor data correctly
- map 'cavern' text to cavern dive type in all import parsers

### Refactoring

- resolve selected characteristics by index, not UUID (#356 review)

### Documentation

- clarify selector tie-break is input-order, not handle-order (#356 review)
- implementation plan for dive site City/Island/Body of Water (#344)
- design spec for dive site City/Island/Body of Water fields (#344)
- release notes
- add agent skills section to CLAUDE.md
- initial shared context for agent sessions

### Tests

- verify edit form persists City/Island/Body of Water (#344)
- add v90 migration guard, relax v89 version tripwire (#344)
- verify dive site location fields round-trip through serialization (#344)

### CI/CD

- make test shard modulus 0-based to match matrix.shard
- split codegen into its own job to shorten the serial prefix
- guard against empty test shard running the whole suite
- make generated-code packaging robust to wc formatting
- shard tests by file, not by case
- parallelize pipeline to cut wall-clock ~49m -> ~15-18m

### Chores

- bump version to 1.5.4+104
- bump version to 1.5.4+103

### Other

- dart format and fix doc-comment HTML lint (#344)
- i18n(sites): add city/island/body-of-water labels in all locales (#344)


## 1.5.4 (2026-06-20)

### Features

- show City/Island/Body of Water on the site detail view (#344)
- add City/Island/Body of Water to the site edit form (#344)
- add city/island/body-of-water table columns (#344)
- add city/island/body-of-water suggestion helpers (#344)
- map city/island/bodyOfWater in repository read, write, search (#344)
- include city/island in DiveSite.locationString (#344)
- add city, island, bodyOfWater to DiveSite entity (#344)
- add city and island columns to dive_sites (schema v90) (#344)

### Bug Fixes

- trim values in locationString for whitespace consistency (#344)
- carry city/island/bodyOfWater through site merge (#344)
- write Symbios commands to Tx on Windows and Linux too (#288)
- write Halcyon Symbios commands to Tx, not Rx (#288)
- force path-style addressing for dotted bucket names
- import and use ccr o2 sensor data correctly
- map 'cavern' text to cavern dive type in all import parsers

### Refactoring

- resolve selected characteristics by index, not UUID (#356 review)

### Documentation

- clarify selector tie-break is input-order, not handle-order (#356 review)
- implementation plan for dive site City/Island/Body of Water (#344)
- design spec for dive site City/Island/Body of Water fields (#344)
- release notes
- add agent skills section to CLAUDE.md
- initial shared context for agent sessions

### Tests

- verify edit form persists City/Island/Body of Water (#344)
- add v90 migration guard, relax v89 version tripwire (#344)
- verify dive site location fields round-trip through serialization (#344)

### CI/CD

- make test shard modulus 0-based to match matrix.shard
- split codegen into its own job to shorten the serial prefix
- guard against empty test shard running the whole suite
- make generated-code packaging robust to wc formatting
- shard tests by file, not by case
- parallelize pipeline to cut wall-clock ~49m -> ~15-18m

### Chores

- bump version to 1.5.4+103

### Other

- dart format and fix doc-comment HTML lint (#344)
- i18n(sites): add city/island/body-of-water labels in all locales (#344)


## 1.5.4 (2026-06-18)

### Features

- release scoped backup dir after each write
- arm security-scoped bookmark around backup writes; reset stale to default
- pick custom folder via security-scoped bookmark on Apple platforms
- dedicated BackupBookmarkHandler
- dedicated BackupBookmarkHandler (multi-slot, folder picker)
- persist backup-folder security-scoped bookmark
- BackupBookmarkService channel wrapper (Dart side)

### Bug Fixes

- re-mint a stale backup bookmark instead of using it as-is
- keep junction membership when a payload reinserts a deleted key
- guard tile error logging against a throwing toString
- never let an unusable backup location brick startup
- log tile load failures instead of swallowing them
- always merge a complete public-CA bundle on Windows
- route keychain ops to the working store on the macOS no-sandbox build
- default extractFromDive sacUnit to pressurePerMin
- honor SAC unit preference in dives table column
- address review - union machine roots, comment accuracy
- address review - ROOT-only anchors, non-throwing cause
- trust the Windows certificate store for TLS

### Tests

- cover mixed contradicted/genuine-delete set edit
- raise patch coverage to ~96% (error/unsupported + resolveBackupsDirectory)
- cover the tile error handler
- cover dive list tile SAC extra-field rendering
- bring patch coverage to 100%

### Chores

- bump version to 1.5.4+102


## 1.5.3 (2026-06-17)

### Chores

- bump version to 1.5.3+101


## 1.5.2 (2026-06-17)

### Features

- expose prior-experience fields in Diver Profile hub
- gate iCloud tile by capability and localize failures
- add iCloud availability strings for all locales
- add native getICloudAvailability on iOS
- add native getICloudAvailability on macOS
- expose iCloudAvailabilityProvider
- add ICloudAvailability status to ICloudNativeService

### Bug Fixes

- drop keychain-access-groups from no-sandbox DMG entitlements
- assert sentinel copyWith param types in debug
- let Diver.copyWith clear nullable fields
- address PR review and raise iCloud patch coverage
- retry on legacy keychain for ad-hoc no-sandbox build
- drop macOS-only SecTask from iOS handler (fixes iOS build)
- pressure SAC records query uses backGas-only, matching sacPressure contract
- statistics SQL aggregates tanks per dive
- dive table SAC column sums all tanks, not just first
- sacPressure uses back gas tank only on multi-tank dives

### Refactoring

- remove orphaned DiverEditPage and /divers route tree

### Documentation

- plans
- add wiki documentation redesign implementation plan
- clarify ICloudAvailability unsupported/unknown semantics

### Tests

- address review feedback

### Chores

- bump version to 1.5.2+100
- bump version to 1.5.2+99

### Other

- Fix analyze and format issues
- Add missing test
- Modify foreground of Save button on dive detail page


## 1.5.2 (2026-06-17)

### Features

- expose prior-experience fields in Diver Profile hub
- gate iCloud tile by capability and localize failures
- add iCloud availability strings for all locales
- add native getICloudAvailability on iOS
- add native getICloudAvailability on macOS
- expose iCloudAvailabilityProvider
- add ICloudAvailability status to ICloudNativeService

### Bug Fixes

- assert sentinel copyWith param types in debug
- let Diver.copyWith clear nullable fields
- address PR review and raise iCloud patch coverage
- retry on legacy keychain for ad-hoc no-sandbox build
- drop macOS-only SecTask from iOS handler (fixes iOS build)

### Refactoring

- remove orphaned DiverEditPage and /divers route tree

### Documentation

- plans
- add wiki documentation redesign implementation plan
- clarify ICloudAvailability unsupported/unknown semantics

### Tests

- address review feedback

### Chores

- bump version to 1.5.2+99


## 1.5.1 (2026-06-15)

### Bug Fixes

- show Cloud Sync entry on all platforms

### Documentation

- release notes
- release notes

### Chores

- bump version to 1.5.1+98


## 1.5.0 (2026-06-15)

### Features

- surface post-restore notice and replaced-library adopt at the app root
- expose a root navigator key for app-wide dialogs
- detect a replaced library on launch regardless of auto-sync toggles
- post-restore sync notice + replace review action in all locales
- arm the post-restore sync intent on a Merge restore
- Reset Sync State clears the established anchor and post-restore intent
- force a gate-bypassing sync after a Merge restore
- anchor the provider and clear the post-restore intent on sync success
- add SyncState.postRestoreSyncing flag
- expose post-restore intent and established-provider store providers
- add EstablishedProviderStore anchor (survives restore)
- add PostRestoreSyncStore for the Merge-restore sync intent
- show combined career totals with logged+prior breakdown (#331)
- add prior-experience entry to diver edit form (#331)
- add prior-experience strings in all locales (#331)
- add pure CareerTotals combine logic (#331)
- persist prior-experience fields in diver repository (#331)
- add prior-experience fields to Diver entity (#331)
- add prior dive experience columns to divers (v84, #331)
- translate Surface GPS + gas-timeline strings into all locales
- complete the changeset cutover (replace/adopt + peer discovery)
- cut performSync over to the changeset transport (steady-state)
- epoch-filter the changeset reader
- integrate changeset transport into SyncService.performChangesetSync
- add stale-restore detector (HLC-vs-cloud-manifest backstop)
- verify changeset/base checksums on read
- add changeset-log compaction (threshold + base rewrite + inline prune)
- add ChangesetReader (peer discovery, fetch decision, cursor advance)
- add ChangesetWriter (base + changeset publish, no-op, manifest-authority seq recovery)
- add ChangesetCodec (encode/decode changesets and chunked bases)
- HLC-watermark delta export (exportChangeset) with parent-gathered children
- add changeset header fields to SyncPayload
- make media, species, field_presets first-class HLC entities (v85)
- add BaseChunker for resumable base slicing
- add SyncManifest model
- add ChangesetLogLayout flat naming and peer discovery
- add PublishStateStore for per-provider publish position
- add PeerCursorStore for per-peer download cursors
- add v84 schema for changeset-log cursors and publish state
- make downloads prominent buttons, collapse CI badges to one
- redesign with hero banner, feature showcase, and collapsible build docs
- add showcase image script and generated feature-row images
- add hero banner compose script and generated banner
- harden backend switching against data-loss and split-brain
- hide Google Drive provider until fully implemented
- cloud backup off by default and coupled to sync state
- provider-neutral wording in S3 settings strings
- require S3 endpoint URL and fix form clarity issues
- simplify S3 config form with auto-detected region
- l10n strings for simplified S3 config form
- persist server-corrected S3 region
- self-heal S3 region from server hints
- derive S3 region from endpoint hostname
- replace banner and adopt-restored-library dialog
- awaiting-adoption state, silent empty adopt, pending replace launch trigger
- restore dialog offers merge vs replace-everywhere
- strings for restore Replace mode and library adoption
- restore modes, pending replace intent, history validation parity
- adopt replaced library as authoritative apply
- gate every sync on the library epoch marker
- execute library replace (marker-first wipe and re-seed)
- library epoch marker read/write on SyncService
- realign library epoch from mirror when launch detects a restore
- stamp sync payloads with their library epoch
- add library epoch store (mirror + pending replace intent)
- add library epoch marker model
- add last-accepted library epoch to sync metadata

### Bug Fixes

- gate the pending-replace launch intent on a configured provider
- make replaced-library detection surface-only (no auto-sync)
- dedicated app-root replaced-library banner string; bump en @@last_modified
- await provider restoration in _initialize so post-restore work runs on launch
- address second Copilot review round on PR #332
- address PR #332 review feedback
- established provider is not first-contact (restore no longer re-gates)
- watch base-entity tables in watchDiveDetailChanges; drop redundant watch
- refresh the whole dive detail page after a sync
- make changeset compaction pruning best-effort
- version deletions with HLCs + address PR #330 review findings
- verify base integrity against the manifest checksums on read
- cold-start a base instead of crashing when the cloud manifest is missing
- recover instead of bricking when a backend's marked library is unreadable
- correct ARCHITECTURE.md link path to docs/ARCHITECTURE.md
- recover sync_metadata columns stranded past v77 collisions (v83)
- recover databases stranded by the v77 schema-version collision (v82)
- platform-aware libdc cache and revert Xcode 26.5 upgrade
- address PR review + raise patch coverage
- assign gas from reported gas mixes when no tank records exist
- await region-correction persist on signOut/saveConfig
- treat persisted googledrive selection as no provider
- move backup location below frequency and retention
- address PR review feedback round 2
- route corrected-region replays through the 5xx retry path
- explain S3 region mismatch instead of access denied
- edge-trigger PacketReadBuffer semaphore on empty->non-empty
- persist recorded per-sample TTS so the divecomputer TTS source works
- address PR review feedback
- migrate pre-migration dialog compat tests to RestoreMode contract

### Refactoring

- extract reusable adopt-replaced-library dialog
- keep RGBA through trim in prepare_showcase for clean edges
- wrap compose_hero in main(), add makedirs guard
- extract active-diver realign for reuse by sync adoption

### Documentation

- add wiki documentation redesign design spec
- spec + plan for smoother database restore
- add prior dive experience design + implementation plan (#331)
- correct DeletionLog.hlc nullability comment
- reflect incremental sync in the multi-device guide
- reconcile spec section 4 to the implemented flat ssv1 layout
- add Phase 6 (restore + coexistence + performSync wiring) plan
- add Phase 5 (resumability + compaction) implementation plan
- add Phase 4 (read path) implementation plan
- add Phase 3 (write path) implementation plan
- add Phase 2 (serialization) implementation plan
- add Phase 1 (foundation) implementation plan
- add incremental changeset-log sync design spec
- add multi-device sync guide with Cloudflare R2 walkthrough
- document README asset regeneration scripts
- add README redesign spec and implementation plan
- add S3 config simplification plan and design spec
- spec and plan for S3 config simplification
- restore Replace mode implementation plan
- add restore Replace mode (library epoch) design

### Tests

- cover the app-root sync-state listener
- poll for conditions instead of fixed sleeps; close test DBs; pin widget-test locale
- restore-resume two-device convergence
- address PR review feedback on test doubles
- add in-memory FakeCloudStorageProvider test double
- skip backend-switch widget tests on non-Apple platforms
- raise patch coverage to 98.8 percent

### CI/CD

- remove Claude Code and Claude Code Review workflows

### Chores

- bump version to 1.5.0+97
- satisfy analyzer (package imports, const companions, doc comment)
- remove old unused January screenshot sets (iPad/iPhone/macOS)
- adopt Xcode 26.5 recommended project settings

### Other

- dart format post-restore store tests
- scope screenshots gitignore negation to readme/ to keep junk ignored
- stop gitignoring committed docs/assets/screenshots
- Potential fix for pull request finding
- fix const and doc-comment lints in epoch tests


## 1.4.9+96 (2026-06-11)

### Features

- responsive two-column edit form on wide windows
- rebuild site edit on shared form sections incl. merge mode
- guard embedded cancel with discard confirmation
- persistent fields for validated rows, decoration override
- adopt EditFormScaffold, dirty guard and error auto-expand
- rebuild Experience and rare groups, lock group order
- rebuild Trip and Buddies groups
- rebuild Conditions group with temperature hero
- rebuild Gas & Gear group with tank cards and smart collapse
- add TankCard with inline expanding tank editor
- rebuild The Dive group on shared form primitives
- add EditFormScaffold with discard guard and embedded header
- add AddSectionRow for rare form sections
- add UnitField numeric input with unit suffix
- add FormRow label/value variants with inline text editing
- add StatStrip hero stats with in-place editing and profile affordance
- add collapsible FormSection with summary, invitation and error states
- add FormStyle design tokens for shared form system
- confirm first-contact library merges before syncing
- detect twin device identities via per-upload nonces
- surface the S3 provider tile and config route
- add S3 configuration page with live connection test
- add S3 sync settings strings in en and all 10 locales
- register CloudProviderType.s3 and the S3 provider singleton
- add S3StorageProvider implementing CloudStorageProvider
- persist S3 config as a secure-storage blob
- add minimal SigV4-signed S3 API client (put/get, retry)
- complete SigV4 signing against AWS test vectors
- add SigV4 hashing, key derivation, and encoding primitives
- add S3Config entity for the S3 sync backend
- detect same-device restores via a rotating instance token
- auto-detect a database restore on launch and re-baseline
- auto-refresh entity lists after sync via Drift table-change ticks
- include state/province in dive center location
- make diver-merge undo reachable from the UI
- stamp HLCs on the three config tables that bypass the choke point
- stamp HLCs on writes and use them in the merge decision
- add nullable hlc column to conflict-capable tables (v77)
- add Hybrid Logical Clock value type + SyncClock service
- per-device sync files to remove the write-write race
- undoable diver merge + localize the merge banner UI
- detect and merge duplicate diver profiles from sync
- surface Cloud Sync in Settings (route + iOS/macOS tile)
- enlarge default heat-map cloud radius and opacity
- load and cache heat-map fragment program
- add density-heatmap helper functions with tests
- warn on near-duplicate sites in the picker
- autocomplete site name + warn on near-duplicates
- autocomplete the region field, scoped by country
- autocomplete the site country field
- add SuggestionField autocomplete widget
- add SimilarValueHint near-duplicate widget
- add distinct-value suggestion helpers
- add ISO 3166 country name constant
- add Sorensen-Dice fuzzy matching utility

### Bug Fixes

- preserve GATT notification boundaries in BLE read streams
- harden numeric stat input and guard save-time parsing
- guard scaffold pop with context.mounted, enforce UnitField numerics
- shrink tank card stats so the pressure range fits on phone
- address PR review feedback
- localize the first-sync merge dialog's Cancel button
- keep the upload nonce when the upload times out
- restore accents on the Hungarian Sync Now label
- close the first-sync guard's reentrancy window
- harden twin detection against false positives
- reset keeps tombstones and retires the old device file
- retire the legacy shared sync file after merging it
- validate payload checksums over the writer's encoding
- Reset Sync State adopts a fresh device identity
- clear sync metadata on S3 sign-out while retaining credentials
- surface keychain failures on the S3 page, harden fields
- close probe clients, guard provider caches, sub-prefix folders
- make S3 credentials load() total over malformed blobs
- wrap S3 parse failures in CloudStorageException
- collapse header whitespace per SigV4, document sign() contracts
- harden S3Config per review - total displayHost, trimmed secret, path rejection
- address PR review on restore detection
- re-baseline sync after a database restore
- address review — diver-stats tick, species + tag/buddy, DI consistency
- address PR review — scope silent reloads + use diveRepositoryProvider
- address PR #306 review round 2 (Copilot)
- keep children of a parent revived in the same sync payload
- cover all deletable-parent FKs + repair dangling refs at apply
- stop deletions resurrecting from a peer's stale live copy
- resolve PR #303 review -- change-bus on settings/preset writes, per-device launch check
- check for null or empty
- make diver-merge undo a true inverse of sync state
- import-filter device-local keys, harden clock seed, deletion safety
- HLC authoritative over conflict branch; stop dropping failed records
- guard v77 index creation against partial-schema migration fixtures
- add 77 to migrationVersions
- address PR #302 review feedback
- code-review polish on the sync-hardening batch
- compute surface interval from timestamps when column is null
- correct getTopDiveCenters SQL to use city/state/country columns
- exclude built-in catalog rows from the sync payload
- close cross-device deletion propagation gaps
- include six previously-orphaned user-data tables in SyncData
- defer FK checks, add courses, exclude device-local settings
- surface apply failures as errors instead of masking as conflicts
- export media and certifications via toJson() too
- export all non-BLOB entities via toJson() for symmetric sync
- export dives via toJson() so all fields survive sync
- export isPlanned so dives apply on receiving devices
- include dives logged on the last day of a trip
- compute days-since-diving by calendar day not 24h period
- use effectiveRuntime for longest dive in dive log summary
- tune heat-map cloud defaults after visual review
- prevent duplicate-key crash in the surface GPS map
- use proper marine icons for species categories
- add missing en l10n keys + picker hint import (#292)
- rebase Swift exit-GPS patch onto upstream GNSS-status check
- show updated dive number after renumbering Fixes #240

### Refactoring

- extract picker sheets from dive edit page
- extract diveRepositoryProvider to break import cycles
- replace fetchRecord hand-maintained maps with Drift's toJson()
- render heat map via density-colorized shader

### Performance

- encode BLOBs as base64 instead of JSON byte arrays

### Documentation

- record implementation deviations in design spec
- add edit form redesign implementation plan
- add edit form redesign design spec and mockup
- add upgrade-path hardening implementation plan
- align S3 spec with review-driven implementation changes
- correct two SigV4 test vectors (computationally verified)
- add S3 sync backend implementation plan
- add S3-compatible sync storage backend design spec
- record device-local settings-key audit
- record Phase 0 iCloud sync diagnosis (merge masks apply errors as conflicts)
- add iCloud sync all-data spec + Phase 0 diagnostic plan
- add heat-map redesign spec and implementation plan
- implementation plan for site field autocomplete (#292)
- design spec for dive site & location field autocomplete (#292)
- release notes

### Tests

- raise PR patch coverage above 90%
- pin legacy-file retirement safety invariants
- cover the S3 tile states and sign-out credential retention
- pin S3 store error propagation; clarify load() docs
- pin S3 client behavior; fix retry wrapping and UTF-8 decode
- rename error-path tests to match the path they exercise
- cover auto-refresh tick/silent-reload paths (patch coverage ~35->94%)
- cover conflict resolution; fix stale comments; harden blob/merge tests
- cover the v77 hlc migration upgrade path
- reproduce A->B no-op; receiving merge relabels apply error as conflict
- add serializer symmetry round-trip test
- add in-memory fake CloudStorageProvider for diagnostics
- add runtime-only longest dive coverage to dive summary widget

### CI/CD

- bump codecov/codecov-action from 6 to 7

### Chores

- bump version to 1.4.9+96
- translate first-sync merge strings into all locales
- refresh Podfile.lock checksum for libdivecomputer_plugin
- silence experimental/coroutine errors on windows

### Other

- add density-colorized heat-map fragment shader
- i18n: add similar-site hint strings across all locales


## 1.4.9 (2026-05-29)

### Bug Fixes

- respect depth unit in Time at Depth Ranges chart
- honor user date format + count duration inclusively
- refresh paginated dive list after applying matches

### Chores

- bump version to 1.4.9+95

### Other

- vendor patches via fork submodule so CI builds include them
- Update docs


## 1.4.8 (2026-05-27)

### Features

- staged map + confirm review screen (responsive) + l10n
- add MatchSitesMap (dive + candidate pins, tap to select)
- add sensitivity setting UI and wire it through
- persist configurable siteMatchSensitivity setting
- wire route, dives-list action, and post-download match button
- add SiteMatchReviewNotifier and review page
- add SiteMatchingService with dedup, coincidence guard, and rollback
- add DiveRepository.setSite and getDivesNeedingSiteMatch
- add pure matcher, domain types, and sensitivity presets

### Bug Fixes

- localize dive-row title + short-circuit empty confirm
- use the diver icon for the surface-GPS site marker
- partition review summary + v76 migration step
- make apply errors transient; preserve fatal error in copyWith
- refresh dive list after applying site matches
- show 'Match Dives to Sites' in default list view menu, not only table mode
- address PR review (unlink guard, in-query id filter, l10n, Change action, settings tile)
- prevent popup menu overflow with flexible match-sites label

### Refactoring

- address review — value-equality provider key + rank candidates once
- staged notifier (proposals/selections/confirm)
- split service into computeProposals + applyConfirmed

### Documentation

- add site-match review map + staged-confirm implementation plan
- add site-match review map + staged-confirm design spec
- add GPS site-matching implementation plan
- add GPS site-matching design spec

### Tests

- cover notifier/page/map for staged review (patch >=90%); drop dead map didUpdateWidget
- raise patch coverage above 90% (notifier, page, repo, import-summary, settings)
- add setSiteMatchSensitivity override to remaining settings mocks

### Chores

- bump version to 1.4.8+94
- regenerate mocks for new DiveRepository methods

### Other

- i18n: translate site-matching strings across 10 locales


## 1.4.7 (2026-05-25)

### Features

- seed gas timeline strip visibility from defaultShowGasTimeline setting
- default the gas timeline strip to hidden
- wire interactive map into detail page, remove Open in Maps
- add SurfaceGpsSection and fullscreen DiveLocationsMapPage
- add shared DiveLocationsMap widget
- add l10n strings for site row, map title, copy toast
- expose gas timeline default visibility toggle
- hydrate gas timeline visibility from setting
- add setDefaultShowGasTimeline setter
- persist defaultShowGasTimeline in DiverSettingsRepository
- add default_show_gas_timeline column with v75 migration
- add defaultShowGasTimeline to AppSettings model
- show source-attribution badge on Surface GPS values
- attribute GPS to the source that recorded it
- record GPS on the dive data-source provenance
- carry GPS on DiveDataSource provenance
- add GPS columns to dive_data_sources (schema v74)
- add Surface GPS collapsible section with drift and open-in-maps
- show entry/exit pins and drift line on header map
- register Surface GPS dive-detail section
- add Surface GPS section expansion state
- add formatDistance for drift readout
- add geo distance/bearing helpers for dive drift
- expose GPS entry/exit on Dive entity and hydrate from DB
- persist Swift GPS entry/exit on downloaded dives
- add GPS entry/exit columns to dives (schema v73)
- carry GPS entry/exit on DownloadedDive
- map GPS entry/exit through all platform converters
- add GPS entry/exit to Pigeon ParsedDive
- read Swift GPS entry/exit into parsed-dive struct
- add GPS entry/exit fields to parsed-dive struct
- expose Shearwater Swift exit GPS via DC_FIELD_LOCATION flags
- add used gas to dive profile chart
- add isOxygen classification to GasMix and GasSwitchWithTank
- add date field to RankingItem class
- close networkUrl resolver gap by parameterizing HttpUrlMediaResolver
- route Network Sources from the Media Sources page
- add NetworkSourcesPage hosting the three cards + scan
- add NetworkScanDialog for live scan progress + summary
- add NetworkCacheCard for size + clear UX
- add ManifestSubscriptionCard for subscription management
- add CredentialsHostCard for saved-hosts management
- add network sources Riverpod providers
- add CachedNetworkImageDiagnostics for size + clear
- add NetworkScanService for user-triggered HTTP scan
- add HostRateLimiter for per-host concurrency + spacing
- add NetworkScanProgress and NetworkScanReport value objects
- wire Subscribe toggle, poll-interval picker, and Import commit
- add ManifestModePanel with fetch + preview UI
- wire subscription poller scheduler with 30s warmup
- add SubscriptionPoller single-pass diff cycle
- extend network fetch pipeline for manifestEntry items
- register ManifestEntryResolver in the resolver registry
- add ManifestSubscriptionRepository for synced + per-device state
- add ManifestFetchService (HTTP + sniff + parse)
- add ManifestFormatSniffer for content-type and body detection
- add CsvManifestParser
- add AtomManifestParser for Atom/RSS feeds
- add JsonManifestParser for Submersion v1 JSON manifests
- add ManifestEntry, ManifestFormat, and ManifestParseResult value types
- swap URL placeholder for new URL tab in picker
- wire cached_network_image with auth + LRU caps
- add URL tab UI, review pane, and sign-in sheet
- add URL tab Riverpod providers (commit/undo, sign-in)
- add network fetch pipeline (sync insert + background fill)
- add UrlMetadataExtractor with range + full-GET fallback
- add NetworkUrlResolver for HTTP-fetched media
- add NetworkCredentialsService with secure storage
- add NetworkCredentialsRepository
- add URL validator for bulk import
- add Local files diagnostics + Settings subsection
- add right-click context menu for local-file items (desktop)
- wire Files-tab commit flow with bookmark persistence + undo
- wire FilesTab into photo picker tab shell
- add FileReviewPane and FileReviewCard + wire into FilesTab
- add folder picker + auto-match-by-date wiring
- add FilesTab widget skeleton with file-picker action
- add Files tab state notifier
- promote LocalFileResolver from stub to full multi-platform
- add readBookmarkBytes/readUriBytes native methods
- add LocalBookmarkStorage for iOS/macOS bookmark persistence
- add DivePhotoMatcher shared matching service
- add ExtractedFile and MatchedSelection value objects
- add ExifExtractor service for local file metadata
- add Media Sources settings page under Data
- auto-populate originDeviceId for device-local sources
- add LocalMediaPlatform Dart wrapper
- add LocalMediaHandler for persistable URI perms
- add LocalMediaHandler for security-scoped bookmarks
- add MediaItemView universal display widget
- add UnavailableMediaPlaceholder widget
- register media source resolver registry as a provider
- add SignatureResolver
- add PlatformGalleryResolver
- add MediaSourceResolverRegistry
- add MediaSourceResolver abstract interface
- persist source-type fields in MediaRepository
- add Drift tables for subscriptions/connectors/credentials
- mirror new media columns in Drift Media table
- add source-type fields to MediaItem entity
- add MediaSourceData sealed class
- add VerifyResult and MediaSourceMetadata value objects
- add MediaSourceType enum
- backfill source_type and add indexes
- add subscription/connector/credential tables
- add media table columns for source-type extension
- bump schema to v72 for media source extension
- decode ZRAWDATA profiles via libdivecomputer_plugin
- MacDive SQLite import (Milestone 3 of 4)
- wire MacDiveXmlParser into universal import pipeline
- MacDive value mapper for water type / entry type / rating
- MacDiveXmlParser produces unified ImportPayload
- MacDiveXmlReader parses MacDive native XML into typed models
- MacDive unit converter (imperial ↔ SI canonical)
- MacDive XML typed value classes
- detect MacDive native XML format
- add ImportFormat.macdiveXml and source override
- persist MacDive waypoint gas switches via existing gasSwitches pipe
- persist MacDive dive/site metadata to DB
- persist UDDF <dive id> as dive_data_sources.source_uuid
- extract site waterType / bodyOfWater / difficulty / flag and source UUID
- extract MacDive extended dive fields (weather, boat, operator, ...) and source UUID
- add LinkRefIndex for ref-kind disambiguation
- add source_uuid to dive_data_sources for cross-format import dedup

### Bug Fixes

- cap map fit zoom so tiles render for clustered GPS points
- guard v75 diver_settings migration for partial-schema tests
- show SAC on graph for imports without tank volume
- use primary gas mix when tank gas link is unknown
- restore tank pressure on reparse
- persist entry/exit GPS on reparse
- rebuild libdivecomputer when patched sources change
- resolve duplicate diveLog_detail_label_entry/exit keys
- guard v73 migration ALTER and update section/props counts
- address PR review feedback
- honor pinned Flutter version on Windows runners
- exclude zero-volume tanks from SAC by tank role; report SAC in L/min
- interpret dive_date_time as UTC when converting to DateTime
- use separate functions for SAC by tank role
- wire applyMediaCacheCaps at app boot to enforce 75 MB memory cap
- reject TZ-abbreviation RFC 822 dates rather than silently treating as UTC
- cancel warm-up timer on SubscriptionPollerScheduler dispose
- repair malformed coverage:ignore-start marker that was hanging CI
- format best/worst SAC dates according to user preference
- tolerate corrupted credentials blobs in headersFor
- set _lastReport before emitting finished event
- store localPath alongside bookmarkRef on macOS for context-menu actions
- filter video imports from Files tab pending Phase 3 video support
- parse EXIF dates as wall-clock-UTC for matcher consistency
- add context.mounted check after reverifyAll await
- use readBookmarkBytes on iOS/macOS to avoid security-scope leak
- sync state.match when removeFile drops a staged file
- route files to Unmatched when auto-match is disabled
- close Exif handle on attribute-read failure
- tolerate per-item failures in reverifyAll + handle onTap errors
- tighten _persistOne return type, fix Link button count + l10n TODO
- use package:path for filename + add l10n TODO markers
- clear isExtracting when picker skips files + extra render tests
- apply picker buffer in UTC to match scanner exactly
- apply wall-clock-UTC→local conversion in photo picker
- wire up Open Settings button + remove dead l10n key
- address 4 follow-up Copilot review comments on PR #268
- register Phase 1 LocalFileResolver + harden MediaItemView
- address PR #268 review comments
- wire PlatformGalleryResolver through AssetResolutionService
- preserve mini profile chart detail
- emit sample tank pressure via allTankPressures key
- dedupe source name in detection label; parse MacDive sample <time> as decimal seconds
- SQLite gas-mix cast, remove broken ZRAWDATA decoder
- propagate fatal FFI errors + add Perdix 2/NERD 2 models
- dedup buddyRefs / tagRefs + use MacDiveValueMapper.rating
- address PR #254 review round 2 — MacDive XML polish
- address PR #254 review — MacDive XML consumer compatibility
- use const for constants, remove unused import
- route MacDive waterType/entryType through MacDiveValueMapper
- trim mixRef + order-independent tank lookup in test
- use Value.absent() for missing companion fields
- extract equipment from standard <diver><owner><equipment> location
- record gasMixRef on samples carrying <switchmix>
- ensure equipmentused refs from both before/after sections are captured

### Refactoring

- centralize chart layout constants
- consolidate wall-clock-UTC parsing into shared helper
- delegate gallery match to DivePhotoMatcher
- route trip photos through MediaItemView
- route all dive media items through MediaItemView
- wrap photo picker in tab shell
- remove legacy UnavailablePhotoPlaceholder
- use UnavailableMediaPlaceholder in trip photo widgets
- use MediaItemView in trip photo viewer
- use MediaItemView in photo viewer page
- use MediaItemView in dive media section
- drop dive_number_of_day column; it's derivable
- drop low-value extractions and unused LinkRefIndex

### Documentation

- add gas timeline default visibility design spec and plan
- add interactive map implementation plan
- add interactive map redesign spec
- spec + plan for Shearwater Swift GPS entry/exit points
- correct scanAll cancellation behavior in NetworkScanService
- correct clearCache() doc to acknowledge rethrow on failure
- add JSON manifest v1 schema spec
- add Phase 3a (URL bulk import) implementation plan
- add Phase 3b (manifest import) implementation plan
- add Phase 3c (settings + scan) implementation plan
- refresh LocalBookmarkStorage class doc to readBookmarkBytes flow
- add Phase 2 (Local Files) implementation plan
- clarify LocalMediaHandler bookmark options vs macOS
- add media source extension design + Phase 1 plan
- preserve ZSAMPLES findings on main (closing PR #260)
- retarget Phase 2 plan to concrete ZRAWDATA + parseRawDiveData
- Phase 2 plan references main as target (PR #256 merged)
- record Phase 1 NO-GO + Phase 2 pivot to ZRAWDATA via libdivecomputer
- fix stale inspect.py reference in README content (renamed to blob_inspect.py)
- MacDive ZSAMPLES Phase 1 spike implementation plan
- MacDive SQLite ZSAMPLES profile decoding design
- reflect dive_number_of_day removal in Milestone 1 plan
- fix link to roadmap

### Tests

- add setDefaultShowGasTimeline to remaining SettingsNotifier mocks
- cover Surface GPS UI, header map, and expand-state provider
- assert provider returns NetworkScanService instance, not closure type
- add failing widget tests for URL tab + sign-in sheet
- add failing tests for network fetch pipeline
- add failing tests for UrlMetadataExtractor
- add failing tests for NetworkUrlResolver
- add failing tests for NetworkCredentialsService
- add failing tests for NetworkCredentialsRepository
- add failing tests for URL validator
- cover compute() isolate path + remaining matcher branches
- cover Local files diagnostics card + Re-verify tile
- cover FileReviewCard render + remove tap
- cover androidUriUsageProvider + localFilesDiagnosticsProvider
- cover scanGalleryForTrip / scanGalleryForDive helpers
- mock native_exif channel to cover EXIF parse paths
- cover BytesData round-trip + ignore Android branch
- add readBookmarkBytes / readUriBytes platform-check tests
- cover reverifyAll catch + Equatable + ignore Android URI usage
- add coverage for getAllBySourceType
- verify phase-1 local-only tables don't sync
- seed v71 media table in older migration test fixtures
- cover PlatformException + _defaultParse + optional sample fields
- real-sample test covers ZRAWDATA decode path
- MacDive XML real-sample regression (gated)
- strengthen MacDive XML wizard test to exercise parser
- imperial-unit fixture and tests for MacDive XML reader
- make MacDive real-sample suite portable and skip-safe
- MacDive real-sample regression (gated)
- replace parser-only test with real integration test for source_uuid
- lock down <infinity/> surface interval handling
- rename and expand v70 migration test to match house convention

### Chores

- bump version to 1.4.7+93
- ignore submodule working-tree dirtiness
- refresh stale mocks for new MediaRepository methods
- re-format exif_extractor_test after coverage additions
- final coverage:ignore polish for unreachable branches
- tighten coverage:ignore regions for picker / right-click
- mark Android-only branches as coverage:ignore
- mark FilesTab picker / commit callbacks as coverage:ignore
- mark right-click context menu as coverage:ignore
- @Deprecated matchPhotoToDive + align picker buffers
- remove unused dart:typed_data import
- CHANGELOG and plan update for M2 completion
- regenerate mocks for applyImportedMetadata
- changelog and plan update for M1 completion

### Other

- format v75 migration test
- dart format generated Pigeon bindings (CI format gate)
- apply dart format to GPS test files
- i18n: use correct German umlauts Fixes #262
- Fixed formatting.
- Added new test to group 'updateDive' that verifies a tank validation error by attempting to update with an empty tank ID.
- Fixed test still using empty tank ID.
- Added validation that all tanks have non-empty IDs on update to prevent data loss. Added test to verify that an ArgumentError is thrown when updating a dive with a tank that has an empty id.
- i18n(heatmap): reposition fast and slow labels
- Address Claude code review comments
- Clarify fallback behavior in MetricSourceInfo documentation
- Rebase changes on current main
- Update pp02 and CNS to be gas-aware, consistent with deco model
- change 0.79 hard-coded constants to either airN2Fraction or inspiredSurfaceN2Bar
- pull out DC or calculated feature and revert to merged view
- code review fixes
- revert unrelated changes
- Add gas-aware imported profile deco analysis
- Fixed formatting issues.
- dart format coverage tests
- promote empty-logbook fixture to const
- fix analyzer info issues (unused import, missing const)
- skip M1 Task 3 after finding non-existent bug
- narrow M1 Task 1 source_uuid to dive_data_sources only
- Added integration test that verifies that no data is deleted from either tank_pressure_profiles or gas_switches when a dive is updated.
- Fixed inline comments to match changed behavior.
- Replaced delete & re-insert approach for updating dives with a real update mechanism.
- Fixed Dart style convention.
- Changed prio of start/end pressure data source. Prio #1 is now tank metadata, prio #2 is now first/last value from tank_pressure_profiles


## Unreleased

### Added

- MacDive UDDF imports now capture substantially richer dive data: boat
  name and captain, dive operator, surface conditions, weather (stored
  in the existing weather description field), plus site water type, body
  of water, and difficulty rating.
- **MacDive native XML import.** MacDive's own `.xml` logbook format is now
  a first-class import source. Unlike MacDive UDDF (which doesn't emit tags),
  the native XML export carries dive tags — so users migrating tag metadata
  from MacDive should choose this format. Supports both Imperial and Metric
  unit modes; depths/temperatures/pressures are converted to the canonical
  internal units at the reader boundary.
- **MacDive (XML) source override** in the import wizard's detected-source
  dropdown, alongside the existing MacDive (CSV) option.
- **MacDive SQLite import.** Direct import from MacDive's Core Data
  SQLite database. Captures the same entity set as MacDive XML — dives,
  sites, buddies, tags, and gear inventory — plus per-dive tank and gas
  mix linkage drawn from the `ZTANKANDGAS` join table. Cross-format
  deduplication via source UUIDs: if you've already imported the same
  dives via MacDive UDDF or XML, re-importing from SQLite won't create
  duplicates.
- **MacDive (SQLite) source override** in the import wizard's
  detected-source dropdown, alongside MacDive (CSV) and MacDive (XML).
- Cross-format import deduplication: stable per-dive UUIDs from MacDive,
  Shearwater Cloud, Subsurface SSRF, and generic UDDF are now preserved on
  the `dive_data_sources` sidecar. Re-importing the same dives in a
  different format no longer creates duplicates.

### Fixed

- MacDive UDDF: equipment / gear now imports correctly. The parser
  previously only scanned Submersion's private equipment extension,
  missing the standard UDDF gear location (`<diver><owner><equipment>`)
  where MacDive and other compliant exporters place their inventory.
- MacDive UDDF: `<equipmentused><link ref>` is now captured from both
  `<informationbeforedive>` and `<informationafterdive>`.
- MacDive UDDF: `<surfaceintervalbeforedive><infinity/></…>` is now
  explicitly handled as "no prior dive" rather than relying on silent
  int-parse failure.

### Known limitations (to be addressed in a follow-up)

- Gas switch markers (`<switchmix ref>`) in MacDive dive profiles are
  parsed but not yet persisted to the profile samples table. A future
  milestone will wire them through, likely via the dive-events table.

### Known limitations

- Profile samples (depth/time-series data) are NOT imported from
  MacDive SQLite. MacDive stores sample data in `ZDIVE.ZSAMPLES`
  using a proprietary binary format that isn't publicly documented
  and isn't standard bplist or any common compression. Users who
  need time-series profile data should use the MacDive UDDF import
  path instead, which decodes MacDive's UDDF profile correctly.
- The MacDive SQLite path reads critters (marine-life sightings),
  dive events, service records, and certifications into its typed
  row graph, but these are not yet emitted into the import payload —
  the unified importer doesn't have entity types for critters,
  events, or service records, and certification emission is scoped
  for a follow-up. For now, only the dive/site/buddy/tag/gear subset
  is persisted.


## 1.4.6 (2026-04-22)

### Bug Fixes

- log download failures to the file log (#258)
- DB readonly-rollback recovery + cooperative import cancellation (#255)

### Documentation

- implementation plans for MacDive import milestones 1-4
- design spec for robust MacDive import (UDDF, XML, SQLite, photos)

### Chores

- bump version to 1.4.6+92
- changelog + plan update for MacDive UDDF gap-fill milestone

### Other

- ignore sample data
- Revert "chore: changelog + plan update for MacDive UDDF gap-fill milestone"


## 1.4.5 (2026-04-21)

### Features

- customizable bottom nav primary slots on phone (#250)
- optionally share sites and trips across dive profiles (#249)
- add Cmd+Shift+D to open diver switcher
- Slice D - dive-level metadata + provenance fill-out (#247)
- Slice C.2 - extended SSRF profile events (#244)
- Slice C - profile events + source tagging (#243)
- Slice A - setpoint + partial cylinders (#236)
- add region picker page for offline map downloads
- add map style selector (Street, Topo, Satellite) (#233)
- store raw dive data from dive computers (#176) (#230)
- add Overview page in Statistics section (#167) (#229)
- add map style selector (Street, Topo, Satellite)

### Bug Fixes

- show hours underwater on second line in narrow hero bar
- increase test surface size for desktop appearance hub
- add Map Style picker to desktop settings layout
- make v64 migration defensive for missing diver_settings table
- wrap LocationPickerMap test in ProviderScope
- resolve analyze errors in map style feature

### Documentation

- add implementation plan for raw dive data storage (#176)
- add design spec for raw dive data storage (#176)
- add implementation plan for Statistics Overview (#167)
- add design spec for Statistics Overview page (#167)

### CI/CD

- trigger build

### Chores

- bump version to 1.4.5+91

### Other

- i18n: translate 24 missing shared-sites/trips strings across 10 locales
- i18n: translate 35 missing strings across 10 locales
- Revert "Merge main into Jaibar/main to resolve conflicts for PR #193"
- apply dart format to map style files


## 1.4.4 (2026-04-15)

### Features

- highlight last-visited course on phone-mode list return
- highlight last-visited certification on phone-mode list return
- highlight last-visited dive center on phone-mode list return
- highlight last-visited equipment on phone-mode list return
- highlight last-visited buddy on phone-mode list return
- highlight last-visited site on phone-mode list return
- highlight last-visited trip on phone-mode list return
- highlight last-visited dive on phone-mode list return

### Bug Fixes

- compact x-axis years when crowded on dives-per-year (#174)
- move units from ticks to axis labels on Time at Depth chart
- widen and right-align y-axis labels on CategoryBarChart (#175)
- accept TLDs longer than 4 chars in email validation (#208)
- pass raw args to Drift customStatement, unblocks delete/link (#157)
- use runtime (fallback bottom_time) for total dive time
- match other lists' highlight via isSelected (full tint, no left-border)
- route highlight via new isHighlighted tile param to keep checkbox correct
- route highlight through isHighlighted param, add compact test
- scope dive numbering to active diver and refresh after delete

### Refactoring

- drop redundant isSelected arg on DenseBuddyListTile

### Documentation

- implementation plan for phone-mode list highlight
- correct audit findings in highlight spec — 7 tap handlers also need patching
- spec for highlighting last-visited item in phone-mode lists

### Tests

- add compact-mode highlight test; refresh provider doc comment

### Chores

- bump version to 1.4.4+90
- regenerate mocks for diver-scoped numbering signature change

### Other

- normalize tile highlight alpha to 0.5 across all list views


## 1.4.4 (2026-04-14)

### Features

- re-import all dives from dive computer (#206) (#216)
- default detailed-card stat2 to runtime
- pre-migration database backup (#210)
- localize dive computer section
- require explicit selection for import duplicates (#200) (#209)
- show/hide tags toggle on detailed dive cards

### Bug Fixes

- dissolve splash into app UI instead of hard swap
- Mares Puck 4 descriptor match + import-duplicates design spec (#204)
- new dive center and trip now stick when created from dive form (#201)
- per-diver computer records and cascade diver deletion (#199)
- wrap release workflow expression in ${{ }} to avoid YAML tag parse error
- clean stale native asset state before iOS/macOS CI builds
- exclude appcast from beta releases
- skip Claude Code Review on fork PRs

### Documentation

- spec for re-import all dives (#206)
- added plans
- spec for issue #200 - require explicit selection on duplicate imports
- added plan

### CI/CD

- bump softprops/action-gh-release from 2 to 3 (#213)
- bump actions/checkout from 4 to 6 (#212)

### Chores

- bump version to 1.4.4+89
- upgrade 7 major dependencies with API migrations (#194)
- upgrade 66 package dependencies (#192)

### Other

- i18n: translate 71 missing strings across 10 locales


## 1.4.3 (2026-04-09)

### Features

- improve table row selection UX and simplify built-in presets
- replace sine-wave depth model with Perlin noise, micro-events, and workload-driven gas consumption
- add Perlin noise, diver personality, and micro-events for profile realism
- change UDDF generator default sample interval from 10s to 5s
- expand Standard table preset from 6 to 22 columns
- table mode full-width default, details toggle, and entity settings (#184)
- add column configuration and field category l10n strings
- table view with customizable columns and card fields (#56) (#139)

### Bug Fixes

- formatting
- correct FIT import timezone offset for dive times
- simplify dive computer stats to only show dives imported and last download
- handle CertificationLevel enum type in UDDF import display
- use displayName instead of shortLabel for table column headers
- correct Report an Issue URL and open browser on tap (#177)
- handle label overflow caused by new field on dive planner (#181)

### Documentation

- add implementation plan for expanded Standard table preset
- add implementation plan for UDDF generator improvements
- add design spec for expanded Standard table preset
- add design spec for UDDF generator improvements (#186)
- add implementation plan for startup migration progress (#186)
- add design spec for startup migration progress indicator (#186)
- add implementation plan for table mode full-width and details toggle
- add spec for table mode full-width layout and details toggle

### Chores

- bump version to 1.4.3+88
- remove orphaned uddf_adapter_test.mocks.dart
- remove dead UddfAdapter and FitAdapter

### Other

- Add Claude Code GitHub Workflow (#183)
- Handle average depth imports correctly from computers that do not support it (#180)
- Fix/additional uddf ssrf properties (#170)


## 1.4.2 (2026-04-05)

### Bug Fixes

- await dive list instead of reading synchronously (#62)
- remove _showPressure gate that blocked all tank pressure lines
- restore startup check with background guard (#107)
- stop programmatic background check that suppresses manual dialog (#107)
- show MOD and MND for Air gas mix (#138)
- load tank pressure data for single-tank dives in SAC calculation
- apply tank preset name when defaulting imported dives
- inline release notes HTML in appcast.xml to fix empty update dialog
- use runtime instead of bottom time for longest dive record
- add User-Agent to OSM tile requests, correct package name (#134)
- use correct column name in computer stats temperature query

### Chores

- bump version to 1.4.2+87

### Other

- Deprecate legacy pressure field, fix multi-tank import (#115) (#136)


## 1.4.1 (2026-04-03)

### Bug Fixes

- add missing MinimumOSVersion to AppFrameworkInfo.plist

### Chores

- bump version to 1.4.1+86


## 1.4.1 (2026-04-03)

### Features

- drag-and-drop file import with mobile sharing intents (#128)
- redesign homepage and declutter list page toolbars
- add dashboard hero stat translations for all 10 locales
- reorganize hero - icon left, responsive phone/desktop layouts
- rebuild page layout - 4 sections from 7
- restyle quick actions as vertical button stack
- restyle personal records as compact vertical list
- compact alerts banner replacing full card layout
- rewrite hero header with integrated stats and diver name
- add dashboard hero stat label keys
- add Simplified Chinese localization (#113)
- chinese localization plans

### Bug Fixes

- move Equipment view mode to overflow menu, fix iOS overflow icon
- normalize master-detail headers, update import/export text, add translations
- align Kotlin JVM target to each subproject's Java target
- move tabs into master panel in master-detail mode
- fix selection mode including highlighted dive and normalize icon spacing
- prevent non-CSV payload from being cleared during Map Fields animation
- also refresh paginated dive list on tag changes
- also refresh paginated dive list on tag changes
- await parsing in confirmSource so SSRF auto-advances past Map Fields
- invalidate divesProvider on tag changes to refresh dive list and homepage
- remove trophy icon from personal records header
- change hero stat label to 'dives this year'
- show '0' instead of '0m' for zero hours underwater
- allow hero stat labels to wrap naturally
- always show records card with placeholders, reduce recent dives to 3
- prevent stat labels from wrapping mid-word in hero bar
- increase phone hero stat numbers to 22px
- align stat numbers vertically in phone hero bar
- uniform stat font size in phone mode, remove dives-this-month
- push icon to far right edge in desktop layout
- move icon and diver name to right side of hero bar
- increase phone diver name font to 16px
- match phone hero height to desktop with compact fonts
- use 80px icon in both phone and desktop layouts
- restore phone icon to original 80px size
- match desktop activity stat font size to career stats (24px)
- make equipment tabs compact with pill-style indicator
- replace propane tank icon with scuba tank icon (#109) (#124)
- correct Simplified Chinese translation errors
- address PR #114 review feedback (#120)
- eliminate false safety stop markers on shallow dives (#114)
- resolve NDL line zigzag artifacts on multi-surface-interval dives
- tag formatting fix

### Documentation

- add drag-and-drop file import design spec
- add dashboard revamp implementation plan
- add dashboard revamp design spec
- mdi icons
- false-positive safety stop mitigation design

### CI/CD

- bump codecov/codecov-action from 5 to 6 (#119)

### Chores

- bump version to 1.4.1+85
- remove MinimumOSVersion from AppFrameworkInfo.plist
- remove unused activity_status_row, stat_summary_card, quick_stats_row

### Other

- Revert "fix(android): align Kotlin JVM target to each subproject's Java target"
- Rearchitect CSV import with staged pipeline (#116)
- Fix/volume conversion (#126)
- Issue-115 SSRF multi-cylinder dives don't convert over to gas switch … (#122)
- Bugfix/logger test fix (#106)
- add CSV import rearchitect implementation plan
- add CSV import rearchitect design spec
- Issue 36 - JNI interface being obfuscated in android build (#105)


## 1.4.0 (2026-03-29)

### Bug Fixes

- remove build number from macOS CFBundleShortVersionString

### Chores

- bump version to 1.4.0+84


## 1.4.0 (2026-03-29)

### Features

- add dive detail section config translations for 9 locales
- design docs

### Bug Fixes

- appcast version handling
- version display bug in update dialog
- auto_updater_windows threading violation (#83) (#100)
- fix pre-push hook for worktrees

### Documentation

- add implementation plan for auto_updater threading fix (#83)
- add design spec for auto_updater_windows threading fix (#83)
- add Shearwater Cloud database import design spec
- add implementation plan for duration-bottomtime rename and SAC fix
- add debug log viewer implementation plan
- add debug log viewer design spec
- update duration-bottomtime spec with SAC calculation fix
- add import tag selector design spec

### Chores

- bump version to 1.4.0+83

### Other

- Feature/debug log viewer (#98)
- Feature/dive detail section config (#97)
- Feature/duration bottomtime rename sac fix (#95)
- Feature/shearwater cloud import (#96)
- fix/dive-planner-units (#93)
- Feature/import tag selector (#94)
- Issue-71 UDDF handle switchmix switching with out explicit tank reference (#92)
- Issue-87 gas mixes floating point numbers not rounded for display (#91)
- Feature/data import overhaul (#89)
- issue-70 UDDF dual-tank only shows one tank on dive profile (#86)
- Bugix/default local (#88)


## 1.3.7 (2026-03-24)

### Features

- build all platforms on PRs
- add DenseBuddyListTile and integrate view mode for buddies
- add DenseEquipmentListTile and integrate view mode for equipment
- integrate view mode toggle and tile switching for dive centers
- add CompactDiveCenterListTile and DenseDiveCenterListTile widgets
- integrate view mode toggle and tile switching for trips
- add CompactTripListTile and DenseTripListTile widgets
- integrate view mode toggle and tile switching for sites
- add CompactSiteListTile and DenseSiteListTile widgets
- add per-feature list view mode dropdowns to Appearance settings
- add 5 per-feature list view mode settings
- add 5 list view mode columns to DiverSettings (schema v52)

### Bug Fixes

- stabilize list tile and header sizing in selection mode (#73)
- use UTC wall-time for CSV date/time parsing (fixes #60) (#75)
- allow date pickers to select dates before year 2000
- preserve original timestamps in site merge undo
- debounce search inputs and expand dive search to all related fields (#55)
- quote DART_DEFINES in CodeQL workflow and merge C/C++ analysis into Swift job

### Refactoring

- move ListViewModeToggle to shared/widgets, add availableModes
- rename DiveListViewMode to ListViewMode

### Documentation

- add git submodule init step to setup instructions
- add buddy merge implementation plan
- address spec review feedback for buddy merge design
- add buddy merge feature design spec
- add list view modes all features implementation plan
- update spec with rename, selection mode, and gradient notes
- add list view density modes design spec for all features

### CI/CD

- revert fork PR support for Claude code review
- enable Claude code review on fork PRs
- bump github/codeql-action from 3 to 4 (#80)
- replace CodeQL default setup with custom workflow for Swift and Java/Kotlin analysis
- add explicit permissions to workflows to resolve CodeQL alerts
- exclude generated l10n files from code coverage

### Chores

- bump version to 1.3.7+82
- regenerate uddf entity importer test mocks
- update CLAUDE.md
- add --comment flag to Claude code review prompt
- allow gh/git CLI in Claude code review workflow
- enable verbose output for Claude code review workflow
- disable the swift, java, and c++ codeql steps
- add CODEOWNERS for automatic review assignment

### Other

- Feature/cressi leonardo import (#43)
- Fix/macdive uddf import (Fixes #28) (#42)
- Add search to USB Cable tab when adding a USB dive computer manually for import (#68)
- Feature/buddy merge (#66)
- Add reserve pressure user input to dive planner (#67)
- Feature/sites merge (#54)
- format dive center tile files


## 1.3.6 (2026-03-21)

### Features

- add dive list view mode dropdown to Appearance settings
- integrate view mode toggle and tile switching in dive list
- add DiveListViewModeToggle segmented button
- add DenseDiveListTile widget
- add CompactDiveListTile widget
- wire DiveListViewMode through settings layer
- add dive_list_view_mode column to DiverSettings (schema v51)
- add DiveListViewMode enum

### Bug Fixes

- formatting
- replace SegmentedButton with PopupMenuButton for view mode toggle
- add dive list view mode dropdown to desktop settings page
- normalize wall-clock-as-UTC and local times in media matching
- open schema version check in read-write mode to allow WAL recovery

### Documentation

- add compact dive list view implementation plan
- add compact dive list view design spec
- add multi-computer dive consolidation implementation plan
- address spec review feedback for multi-computer consolidation
- add multi-computer dive consolidation design spec

### Chores

- bump version to 1.3.6+81
- update changelog

### Other

- Fix/air consumption unit conversion (#52)
- Feature/site picker search (Issue #49) (#51)


## 1.3.5 (2026-03-19)

### Features

- add dive number field to dive edit form
- add dive number field translations
- auto-assign dive numbers during dive computer import
- add diveNumber parameter to importProfile()
- add translations for default tank preset keys in all locales
- add default preset indicator and import toggle to Tank Presets page
- add localization keys for default tank preset feature
- apply default tank preset fallback in entity importer and providers
- apply default tank preset in DiveEditPage
- add import tank defaults utility for per-field fallback
- add DefaultTankPresetResolver utility
- persist defaultTankPreset and applyDefaultTankToImports in repository and sync
- add defaultTankPreset and applyDefaultTankToImports to AppSettings
- add defaultTankPreset and applyDefaultTankToImports columns to DiverSettings

### Bug Fixes

- pre-populate dive number field with next sequential number
- use wall-clock-as-UTC convention for Subsurface XML import times
- Fix dive list sorting.
- invalidate stale caches for import stats, buddy unlink, and buddy delete.
- prevent unnecessary recalculation and fix right axis "None" selection
- clarify default tank UI with description text and better toggle label
- move setDefaultTankPreset inside context.mounted guard
- preserve existing startPressure in backfill, set _tanksDirty on load
- add missing endPressure: 50 in _addTank()
- create backup directory before copying in DatabaseService.backup()

### Documentation

- add implementation plan for dive number auto-assign and edit
- address spec review feedback for dive number design
- add design spec for dive number auto-assignment and manual editing
- add implementation plan for default tank preset feature
- add design spec for default tank preset feature

### Chores

- bump version to 1.3.5+80
- bump version to 1.3.4+79
- regenerate l10n files after description key addition
- update pubspec.lock after dependency resolution on new environment


## 1.3.3 (2026-03-18)

### Features

- add schema version-mismatch guard to prevent older app from opening newer database
- add Fix Dive Times settings page for bulk-fix tool
- add DiveTimeMigrationService for bulk-fix offset logic
- add importVersion column and wall-clock-as-UTC migration (schema v49)
- construct wall-clock-as-UTC DateTime from raw components in mapper
- pass raw datetime components instead of UTC epoch
- add nativeGetDiveTimezone JNI binding
- pass raw datetime components instead of UTC epoch
- replace dateTimeEpoch with raw component fields in Pigeon API

### Bug Fixes

- pass raw datetime components instead of epoch in dive converters
- use UTC bounds for all dive date range queries
- use DateTime.utc for manual dive entry (wall-clock-as-UTC)

### Documentation

- add dive time timezone fix implementation plan
- add dive_import_providers to files changed table
- address spec review findings for dive time timezone fix
- add dive time timezone fix design spec

### Chores

- bump version to 1.3.3+78
- formatting
- formatting


## 1.3.2 (2026-03-16)

### Chores

- bump version to 1.3.2+77
- disable cloud sync UI options until bugs are addressed


## 1.3.2 (2026-03-15)

### Features

- wire SubsurfaceXmlParser and add integration test with real export
- add trip and tag parsing with deduplication
- add site parsing with GPS, geo taxonomy, and UUID whitespace trimming
- add cylinder/tank, weight, and profile sample parsing
- add dive metadata parsing (buddy, notes, visibility, current, salinity)
- scaffold SubsurfaceXmlParser with value helpers and minimal dive parsing

### Bug Fixes

- show imported buddies in review step and fix profile temperature
- import buddies as proper entities and fill sparse profile data
- import Subsurface buddies and divemasters as proper Buddy entities
- import Subsurface buddies and divemasters as proper Buddy entities
- interpolate sparse pressure data in Subsurface XML profile samples
- auto-select newly created dive site when returning to dive edit page

### Documentation

- add Subsurface XML import implementation plan
- fix spec review issues in Subsurface XML import design
- add Subsurface XML import design spec

### Tests

- add edge case and error handling tests

### Chores

- bump version to 1.3.2+76
- update README.md


## 1.3.1 (2026-03-14)

### Bug Fixes

- prevent black screen on startup from failed database migration

### Chores

- bump version to 1.3.1+75


## 1.3.0 (2026-03-14)

### Features

- migrate all display widgets to resolved asset providers
- add unavailable photo placeholder widget and l10n key
- add resolved asset providers for cross-device photo display
- add AssetResolutionService with tiered matching and cache
- initialize local cache database at app startup
- add LocalAssetCacheRepository with CRUD and backoff logic
- add LocalCacheDatabaseService singleton for local cache lifecycle
- add local cache Drift database for cross-device asset resolution
- weather documentation
- add weather localization strings
- add weather fields to universal import mapping
- add weather fields to UDDF export
- add weather fields to sync serializer
- add weather columns to Excel export
- add weather columns to CSV export
- auto-fetch weather on new dive creation
- replace Conditions with Environment section on dive detail page
- replace Conditions with Environment section on dive edit page
- add wind speed formatting to UnitFormatter
- add weather Riverpod providers
- add WeatherRepository for fetch + persist orchestration
- add WeatherService HTTP client for Open-Meteo API
- add WeatherMapper for Open-Meteo API response mapping
- map weather fields in DiveRepository
- add weather columns to dives table (migration v48)
- create WeatherData value object
- add weather fields to Dive entity
- add CloudCover, Precipitation, WeatherSource enums
- handle zero-dive incremental download with up-to-date message
- add incremental download toggle and completion messages to download page
- wire fingerprint logic into DownloadNotifier for incremental download
- pass fingerprint to libdc_download_run
- pass fingerprint to libdc_download_run
- pass fingerprint through JNI to libdc_download_run
- pass fingerprint to libdc_download_run for incremental download
- add fingerprint parameter to DiveComputerService.startDownload
- add fingerprint parameter to Pigeon startDownload API
- add lastDiveFingerprint schema column and repository support
- add lastDiveFingerprint field to DiveComputer entity
- add selectNewestFingerprint utility for incremental download

### Bug Fixes

- verify cached asset IDs are still loadable before returning
- update Submersion preset column count test to 21
- wire up l10n keys for weather UI and fix _hasEnvironmentData
- invalidate stale provider cache so incremental download uses stored fingerprint
- replace hardcoded strings with l10n keys for incremental download UI

### Tests

- add escalating backoff coverage for local asset cache
- add integration tests for fingerprint persistence in DownloadNotifier

### Chores

- bump version to 1.3.0+74
- localization update
- format code and fix lint warnings for weather feature
- documentation update
- formatting
- translations
- fix mock override and format generated code for incremental download


## 1.2.25 (2026-03-12)

### Features

- add PIN code auth and access code support
- wire PIN code callback and submitPinCode in HostApiImpl
- handle PIN code and access code ioctls in JNI layer
- add PIN code and access code support to BleIoHandler/BleIoStream
- wire PIN code callback and submitPinCode in HostApiImpl
- add PIN code and access code ioctl handlers to BleIoStream
- wire PIN code dialog into download UI pages
- create PIN code dialog widget for BLE authentication
- add pinRequired phase, submitPinCode, remove setDialogContext
- add PinCodeRequestEvent and submitPinCode to DiveComputerService
- add PIN code Pigeon API (submitPinCode + onPinCodeRequired)

### Bug Fixes

- resolve location failure after fresh permission grant

### Chores

- bump version to 1.2.25+73
- add ble pin code plan


## 1.2.24 (2026-03-11)

### Bug Fixes

- retry location capture when first attempt fails on cold start

### Chores

- bump version to 1.2.24+72


## 1.2.24 (2026-03-11)

### Bug Fixes

- decouple store uploads from GitHub release and notify on upload failures

### Chores

- bump version to 1.2.24+71
- added translations


## 1.2.23 (2026-03-10)

### Bug Fixes

- declare location data collection in privacy manifests and improve macOS purpose string
- refactor github release workflow to require all builds to succeed before uploading to any app store.
- replace flutter-action internal actions/cache@v4 with explicit actions/cache@v5

### Chores

- bump version to 1.2.23+70


## 1.2.23 (2026-03-10)

### Bug Fixes

- failing test due to label change
- release.sh use project directory for generating the changelog.
- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+69
- bump version to 1.2.23+68
- bump version to 1.2.23+67
- add code optimization plan


## 1.2.23 (2026-03-10)

### Bug Fixes

- release.sh use project directory for generating the changelog.
- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+68
- bump version to 1.2.23+67
- add code optimization plan


## 1.2.23 (2026-03-10)

### Bug Fixes

- UI improvements for phone layout and settings organization

### Chores

- bump version to 1.2.23+67
- add code optimization plan

## 1.1.2 (2026-02-16)

### Chores

- bump version to 1.1.2+39

### Other

- Fix: appcast feed URL pointed to incorrect repo
- generate favicon without rounded corners or alpha

## 1.1.1 (2026-02-16)

### Features

- add unified release script
- add changelog generation from conventional commits

### Bug Fixes

- skip Claude code review for Dependabot PRs
- disable Codecov fail_ci_if_error until repo is configured
- allow Dependabot bot in Claude code review workflow
- add Codecov token and graceful fallback
- include build-ios in appcast job dependencies
- match analyze strictness between CI and release preflight

### Documentation

- add PR template with test plan checklist
- add CI/CD pipeline overhaul implementation plan
- add CI/CD pipeline overhaul design

### CI/CD

- bump actions/download-artifact from 4 to 7 (#17)
- bump actions/checkout from 4 to 6 (#19)
- bump actions/setup-java from 4 to 5 (#20)
- bump actions/upload-artifact from 4 to 6 (#15)
- bump actions/setup-python from 5 to 6 (#18)
- bump codecov/codecov-action from 4 to 5 (#16)
- add integration tests on macOS for pull requests
- enforce coverage threshold via Codecov
- add weekly performance benchmark workflow
- add Dependabot for GitHub Actions, pub, and Bundler
- use changelog for release notes and add post-release validation
- add retry logic for notarization and Fastlane uploads
- pin Flutter version via shared config file

### Chores

- bump version to 1.1.1+38

### Other

- Updates section in Settings/About should not show on iOS or Android

Format follows [Keep a Changelog](https://keepachangelog.com/).
