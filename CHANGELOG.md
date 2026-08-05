# Changelog

All notable changes to Submersion are documented in this file.


## 1.7.1 (2026-07-30)

### Features

- add DD.MM.YYYY dot-separated date format
- translate gas calculator, weather, and CNS keys
- render descriptions from the WMO code at display time
- keep the WMO code and stop generating English prose
- v137 adds dives.weather_code and clears generated prose
- add English keys for gas calculator results
- pure consumption math using the tank working pressure
- pure rock-bottom math with problem-solving time at depth
- add TankSpec separating water capacity from free gas
- add UnitSlider bound to a canonical-unit axis
- add UnitAxis to declare slider ranges in canonical units

### Bug Fixes

- stop idle syncs rotting the upload-nonce ring into a false twin (#733)
- pin pure-Dart HKDF for data key derivation (#737)
- address Copilot review feedback on PR #682
- drop Computer source toggle from the ceiling line (#755)
- map UDDF decostop depth to the sample ceiling
- map Subsurface stopdepth to the sample ceiling
- include state/province in location display
- let users draw by disabling sheet drag-to-dismiss
- keep large dive numbers inside the list-tile badge
- fix imported-center View action (route + lingering snackbar)
- make the insurance gauge chip tappable
- register no-fly as a direct child of /planning
- route gear chips to /equipment instead of /gear
- localize the CNS/O2 card and convert max ppO2 depth
- surface pressure and swell height follow diver units
- rewire all four calculators onto unit-safe inputs
- best mix rounds O2 down and reports its own MOD
- keep desktop imports off gallery-only code paths
- scope the picker's Done action to the Gallery tab
- let the Files tab link photos the date matcher rejected
- persist real file paths for desktop photo imports

### Refactoring

- remove unused duplicate addressSummary getter

### Performance

- query only the dedupe lookup the selection needs

### Documentation

- implementation plan for gas calculator, weather, and CNS unit fixes
- spec for gas calculator, weather, and CNS unit correctness
- correct FileReviewPane's stale "Stateless" doc

### Tests

- cover findByHardwareIdentity in DiveComputerRepository
- assert navigation for all insurance chip states
- cover noFly builder and harden the regression assertion

### Chores

- bump version to 1.7.1+118

### Other

- Fixed embedded dive to site navigation
- use const for the fixed test depth
- Add missing comma in `sync_data_serializer.dart` default settings from AI mistake
- Potential fix for pull request finding
- Add missing default settings in `sync_data_serializer.dart`
- Keep dive computer BLE identities device-local
- Added auto-generation and improved naming logic and unit tests for certification name


## 1.7.0 (2026-07-25)

### Features

- add macOS View menu zoom items
- add display size control to Appearance settings
- add zoom in/out/reset keyboard shortcuts
- rename a saved plan from the overflow menu
- apply display zoom at the app root
- prompt for a plan name on first save
- add device-local display zoom provider
- extract plan name dialog and mark the title editable
- add DisplayZoomScope for app-wide true zoom
- add display zoom constants and value clamping
- add default plan name generator
- show the transcode hint on any incapable device
- drive quality dropdowns from synced providers
- add MediaUploadQualityPolicy over synced settings
- add raw key-value accessors to AppSettingsRepository
- run the account deduplicator after the migration
- add the startup account deduplicator
- add ConnectedAccountsRepository.ensure
- add deterministic connected-account identity
- match wizard ocean brightness to the splash
- resolve splash brightness from cached theme mode
- mirror theme mode into prefs for pre-db surfaces
- swap OceanBackground dark palette to Abyss Blue
- add startup brightness resolver with cached theme mode
- attention chips with per-chip visibility settings
- gauge strip shows only due/overdue gear, capped at 6
- responsive monitor-first home page assembly
- recent sites map card
- year-in-review card
- on-this-day dives card
- recent photos ribbon
- milestones provider and card
- hero header with left logo and quiet desktop stats
- add always-on GaugeStrip and UrgentBanner
- add responsive DashboardGrid layout widget
- show a not-backed-up badge on media tiles
- opportunistic 30-day verify sweep
- manual Verify Library action
- fleet-wide verify sweep timestamp (schema v136)
- verify library sweep service
- verify-sweep repository helpers
- reap stale multipart upload sessions
- list in-progress multipart uploads
- one-time backlog sweep for orphaned media rows
- dive deletion cascades to dive-only media
- cascade partition, synced unlink, and sweepable-orphan query
- Linux ffmpegthumbnailer video thumbnails
- Windows shell video thumbnails
- macOS QuickLook video thumbnails
- resolve local video thumbnails via VideoThumbnailService
- add VideoThumbnailService with disk cache
- add generateVideoThumbnail channel wrapper
- transfers page renders delete entries
- route media deletion flows through the deletion coordinator
- deletion coordinator enqueues blob deletes before rows die
- abort stranded S3 multipart sessions on terminal failure
- worker routes delete entries, cellular gate exempts them
- delete processor with drain-time refcount guard
- countRowsWithHash refcount for blob deletion
- delete-intent queue entries with per-hash idempotency
- local cache DB v6 adds transfer queue payload column
- sticky per-day headers in the trip story
- sticky day header widget for the trip story
- add TripStoryDay.isSurface
- map-only pinned story header with 180px floor
- delete the open plan from the canvas with confirm and undo
- show a persisted-gated Delete plan menu item in the canvas
- add l10n strings for delete-plan action
- add deco stop band toggles to legend and settings
- draw the deco stop band on the dive profile chart
- add stepped deco stop band renderer
- add deco stop band visibility and source settings
- add deco stop band settings columns (schema v133)
- resolve deco stop band source independently of ceiling
- populate quantized decoStopCurve on ProfileAnalysis
- add deco stop quantization and step transition helpers
- Windows MediaTranscoder transcode + progress (unverified on Windows)
- Windows plugin scaffold + WinRT probe (unverified on Windows)
- return ChannelTranscodeEngine on Windows
- surface a trash button on saved-plan rows
- Android Media3 probe + transcode (Kotlin)
- Android plugin scaffold + Media3 deps
- dispatch to AVFoundation engine on Apple
- AVFoundation probe + transcode (Swift)
- Dart DarwinAvfEngine channel client
- convert to plugin with darwin scaffold (iOS+macOS)
- Linux ffmpeg hint on the upload quality section
- wire PlatformVideoTranscoder + availability providers
- PlatformVideoTranscoder adapter with ceiling rule
- transcode-once pipeline integration for video
- deterministic transcode staging in cache store
- bitrate-based video presets + ceiling rule
- Linux ffmpeg engine with process-runner seam
- scaffold submersion_transcoder with probe DTOs
- per-item re-upload quality action in the photo viewer
- Upload quality settings section
- upload quality strings across 11 locales
- wire compressor defaults + reupload entry point
- resolver serves compressed renditions with freshness
- per-item re-upload override with guarded delete
- pipeline branches uploads on quality level
- v130 reconcile legacy service intervals into clocks
- table Next Service Due column reads clocks
- add clock-based Service Due list sort
- remove legacy service settings from edit form
- flag overdue gear from service clocks
- list badges use clocks only, drop legacy fallback
- queue overrideLevel column + enqueueReupload
- detail header service state from clocks; drop mark-as-serviced
- MediaCompressor seam + pure-Dart ImageCompressor
- rendition cache pool with freshness check
- per-media-type upload quality policy
- compressed stamps, refcounts, and backfill fix
- add compressed rendition fields to MediaItem
- add v130 compressed rendition columns
- add renditionKey store-key derivation
- add MediaUploadQuality enum and presets
- backfill hlc on legacy media_enrichment rows (self-heal)
- replicate media_enrichment as a first-class HLC entity
- add hlc column to media_enrichment (schema v130)
- add no-fly countdown, safety hub, and altitude flag (safety phase 2)
- add no-fly guideline classifier service
- add reset-to-north compass on rotatable maps
- cycle water type when merging sites
- auto-fill dive water type from the assigned site
- edit water type in the site editor
- persist and hydrate site water type
- hide Lightroom UI pending Adobe review
- rename Cloud Sync to Database Cloud Sync (tile + page title)
- Subsurface-exact pSCR O2 model, hypoxia warning, ratio setting
- recreational NDL-maximization solver
- passive semi-closed rebreather (pSCR) breathing mode
- one-tap embedded Connect with Adobe on the settings page
- signInWithEmbeddedCredential helper (begin/capture/complete)
- injectable redirect-capture wrapper over flutter_web_auth_2
- flutter_web_auth_2 dep + embedded Native App credential constants
- Native App auth - refresh-token-optional connect, per-connection redirect, reauth signal
- VPM-B decompression model validated against golden vectors
- optional refresh token + per-connection redirect uri in auth data
- wire v120 columns through domain, repo, engine, sync (per-segment setpoint/mode, plan start time, deco switch depth)
- schema v120 - plan start time, per-segment setpoint/mode, per-tank deco switch depth
- review inbox page, cards, badges, settings screen
- l10n keys for inbox, findings and repairs (11 locales)
- through-the-dive simulation panel
- buoyancy twin outputs in Gear & Weights
- what-if buoyancy re-simulation sheet
- weighting history strip comparing carried vs modeled lead
- inbox providers, detector toggles, watch queries
- net buoyancy chart with per-moment breakdown
- repair actions and executor
- buoyancy detail section with final-stop diagnosis
- profile repair math over edited-profile pattern
- tank pressure series and record repairs
- bulkShiftDiveTimes with snapshot restore
- targeted scan hooks on import and save
- wing lift capacity capture (schema v119)
- scan service, scheduler and providers
- detector registry and SQL pre-filters
- gas, tank-assignment and source detectors
- temperature and pressure detectors
- profile gap, spike and rate detectors
- clock, duplicate and split detectors
- plan mode chip cycles OC, CCR, and SCR
- dive quality context and builder
- SCR breathing mode reuses the validated CMF loop model
- assemble and provide buoyancy twin per dive
- findings repository with scan-apply semantics
- finding entity, deterministic ids, thresholds
- rates setup section and O2-narcotic toggle
- register qualityFindings entity for sync
- anchor detection and derived twin outputs
- edit ascent and descent rate in plan state
- per-sample buoyancy twin simulator
- plan ascent rate affects the computed schedule; wire descent rate
- quality_findings table, migration v118
- schedule policy descent rate and ascent-rate bands
- neoprene compression curve and drysuit gas budget
- gas mix density module for cylinder swing
- surface safety hub from planning and tools pages
- segment list reflects and drives chart selection
- drag, double-click, gas menu, and keyboard editing on the chart
- bridge equipment attributes into buoyancy traits
- attribute-derived prior ladder and per-type factor functions
- GearBuoyancyTraits attribute snapshot with panel parser
- replaceSegment mutation for chart splits
- pure edit controller for on-chart waypoint editing
- Mission Control three-pane layout, phone tab deck, header chips
- stat tiles, editor pane, and results pane
- plan setup accordion hosting decomposed settings sections
- setup sections extracted from the settings panel
- icon rail shell, full-width hub, drop 440px sidebar
- layout state providers and pane/tab l10n keys
- Dive Info, Access & Safety, Life & Notes sections on rows
- Identity and Location sections extracted onto rows
- conditions and weather on rows, profile row, section icons
- row-scale tanks, Gas & Gear overlines and unified actions
- SuggestionFormRow autocomplete row primitive
- EnumPickerRow bottom-sheet enum picker row
- row-shaped inline editing for FormRow.text; rating clear affordance
- FormOverline, FormAppendRow, FormEmptyRow primitives
- CNS method picker with provenance, source links, 11 locales
- FormSection v2 header-in-card chrome
- shared plan kit vocabulary, adopt in results sheet
- cut PlanCanvasPage over to PlanProfileChart, drop fl_chart chart
- PlanProfileChart widget with layered painters and scrub
- series painter with fill, ghost, mean depth, flags, stop tags
- backdrop painter with grid, axes, and ceiling no-go band
- respect CNS method setting in profile analysis and planners
- persist CNS calculation method per diver (schema v113)
- dash and label paint utilities for the plan chart
- thread CNS method through calculators, default Shearwater-style
- CnsCalculationMethod with three CNS rate algorithms
- collision-avoiding stop tag layouter
- pure chart geometry with hit-testing and tick logic
- theme-derived chart palette for the new plan chart
- add near-miss incident log (safety phase 4)
- add offline emergency card with bundled hotlines and chamber directory (safety phase 3)
- add bundled emergency numbers and chamber datasets with loader
- add no-fly countdown, safety hub, and altitude flag (safety phase 2)
- add no-fly guideline classifier service
- translate safety review strings into all locales
- localize pre-dive checklist strings across all locales
- equipment attributes in CSV export
- equipment attribute filter axis and dives-by-suit-thickness chart
- add safety review settings page with analyze-all action
- add pre-dive entry points to dashboard, tools, and trips
- add quiet safety findings badge to dive list
- add pre-dive section to dive detail and add-dive sheet
- attribute rows on the equipment detail page
- add safety review section to dive detail
- type-driven attribute form and custom fields editor
- auto-link pre-dive sessions to imported dives
- add pre-dive session runner, sessions list, and start sheet
- attribute-backed EquipmentItem with diff-save repository
- add safety review settings (master toggle and per-rule set)
- add pre-dive template editor
- add pre-dive checklist providers, routes, and templates page
- register safety review tables in sync serializer and streaming apply
- register pre-dive checklist entities for sync
- attribute labels in all 11 locales with resolver
- add safety findings repository, providers, and profile-write invalidation
- seed built-in pre-dive checklist templates
- add pre-dive session repository with immutability guards
- attribute catalog for all 18 equipment types
- add dive safety review tables and settings columns (schema v116)
- wire equipmentAttributes through serializer, merge order, and HLC registries
- add pre-dive template repository
- add pre-dive session engine and item composer
- equipment_attributes table + v115 migration with legacy column copy
- add sawtooth profile rule
- add pre-dive checklist domain entities
- add omitted safety stop rule
- add pre-dive checklist tables (schema v113)
- add missed deco stop and high surface GF rules
- add safety review engine with rapid ascent rule
- service ledger strings for all locales
- per-clock service reminders and trip nag
- pre-trip gear service alerts
- service due card and clock-aware alerts and badges
- manage service types page
- service clocks card on equipment detail
- service clock providers and trip alerts
- register serviceKinds and serviceSchedules entities
- service kind/schedule repositories, usage query, auto-attach, child tombstones
- add Perdix dive computer overlay to photo viewer (#168)
- ServiceDueEngine with date/dive/hour triggers
- service ledger domain entities
- schema v113 service ledger tables, seeds, backfill
- add DraggablePerdixOverlay drag and playback wrapper
- add PerdixFace dive computer display widget with l10n labels
- add PerdixFaceResolver for media playback readouts
- add Perdix overlay settings (enabled flag and position)
- active course progress card
- add/edit requirement and template picker sheets
- retirement fence -- cloud-wins rejoin preserving pending records
- requirements section on course detail page
- course requirement tracker strings for all locales
- retire idle devices with marker-first log deletion
- requirement progress and suggestion providers
- fleet-acked tombstone GC replaces the 90-day purge
- register courseRequirements and courseRequirementDives entities
- writer publishes ack map and heartbeats stale manifests
- reader ack tracking, retired-peer skip, manifest reporting
- course requirement repository with linking, templates, and tombstones
- liveness constants and fleet-acked tombstone horizon
- manifest appliedPeerHlc acknowledgment map
- course requirement starter template catalog
- retirement marker file name and model
- course requirement domain entities and progress roll-up
- v112 tombstone dedupe index + peer ack column
- add course_requirements and course_requirement_dives tables (v112)
- domain-neutral copy and translucent redesign for the setup wizard
- Shearwater Perdix 3 download support (V2 protocol)
- reuse retained key on re-enable; document per-artifact key semantics
- translate default & geofenced equipment set strings (#583)
- clear the default flag when the switch is turned off (#583)
- backup-encryption settings section + encrypted export
- backup-encryption enable + change-password dialogs
- localize all locales + sync/robustness fixes (#583)
- reencryptExistingBackups in-place migration
- silent restore via the stored backup key
- encrypt Save-to-File and Share exports when enabled
- encrypt local + cloud backups when backup encryption is on
- inject BackupEncryptionKeyStore + _activeBackupKey helper
- add BackupTarget.writeSource for pre-encrypted artifacts
- UI for default + geofenced sets (#583)
- apply default/geofenced set on download + file import (#583)
- repository, providers, and sync for default+geofenced sets (#583)
- schema, entities, and selector for default+geofenced sets (#583)
- add BackupEncryptionService (local key lifecycle)
- add BackupEncryptionKeyStore (backup-scoped key custody)
- add backupEncryptionEnabled preference flag
- rebuild Overview tab as interactive trip story (closes #166)
- assemble trip story view with scroll-linked map
- add pinned story map header with camera animator
- add trip story hero with planned-trip extras
- add trip story day chapter card
- add dive sparkline and day rhythm bar widgets
- add trip story strings in all locales
- add sparkline downsampling and day rhythm layout math
- add tripStoryProvider composing story sources
- multiple certifications per buddy via unified ownership (#553)
- add per-site diver history aggregates
- add batched getSightingsForDives query
- add buildTripStory composition function
- add trip story domain entities
- account-first cloud-provider resolution (completes the Phase-1 deviation)
- add pan (two-finger/trackpad) and discoverable zoom controls
- widen tissue compartment (Z) axis for readability and labels
- cross-device descriptors, hub, guided setup, network files (Phases 2-4)
- Lightroom rides connected accounts; retire connector_accounts
- sync selection persisted by connected account
- media store connect flows create and use accounts
- media store attach state and construction by account
- startup migration seeds accounts from legacy config
- Google Drive, iCloud, and Lightroom account adapters
- S3 and Dropbox account adapters with per-account keys
- capability interfaces and provider registry
- per-account keychain credentials store
- ConnectedAccountsRepository with sync pending marks
- register connectedAccounts in sync engine
- schema v107 connected_accounts table and sync_account_id
- AccountKind enum and ConnectedAccount entity
- label tissue axes with titles and tick values (time/%/compartment)
- show tissue axes, grid, and hover tooltip on the tissue scene
- wire tissue chrome and hover picking into the viewport
- add tissue frame and chrome painters
- add tissue hover tooltip widget
- add 3D tissue tooltip and saturation-state strings
- add nearest-vertex tissue surface picker
- add AxisFrame geometry for tissue axes and grid
- expose tissue surface grid and runtime providers
- emit TissueSurfaceGrid alongside the tissue mesh
- pair Details+Conditions and Buddies+Signatures side by side on wide panes
- CCR diluent resolution and loop gas-segment builder
- hold the CCR setpoint through TTS/schedule ascents for setpoint-bearing segments
- show dive mode in the Details card (#569)
- persist gauge dive mode on live download (#569)
- detect gauge mode on reparse and skip tank synthesis (#569)
- exclude gauge dives from gas statistics (#569)
- hide gas/deco detail sections for gauge dives (#569)
- hide tank controls in gauge mode edit form (#569)
- short-circuit gauge dives to profile-only analysis in providers (#569)
- add gauge dive mode with profile-only analysis (#569)
- add gauge dive mode strings (#569)
- remove the 3D View preview card from dive detail
- Compare in 3D from the detail source section + l10n backfill
- Compare in 3D action on the dives selection bar
- compare-dives page + route
- Computers comparison mode in the 3D view
- shared CompareProfile3dView (view owns the profile cap)
- optional time-plane scrub cursor
- compare readout (per-profile depth + delta)
- compare legend (focus + reference + max delta)
- previous/next buttons + arrow keys on dive detail
- DiveNavButtons previous/next widget + l10n
- orderedDiveIds + diveNeighbors providers
- getOrderedDiveIds query for adjacent-dive navigation
- multi-dive comparison adapter
- computer-source comparison adapter
- CompareGeometryService (side-by-side + overlay)
- reference-based DivergenceBuilder
- optional opacity on RibbonBuilder.build
- comparison profile primitives + resampler
- light scenes with directional shading and slim the ribbon
- retain scroll per trip and per liveaboard tab in detail pane
- retain scroll on dive/site/course/cert/center/equipment/buddy detail
- make tissue scene a 3D extrusion of the Subsurface heatmap
- make the tissue scene legible
- add spatial site seascape scene (Suunto-style topo)
- add career terrain scene (stacked dive history)
- add tissue saturation scene switcher, readout, and controls
- add tissue chain deriver and providers
- add tissue surface builder, geometry service, seam axis
- add tissue chain replay service
- add unit-aware depth grid planes
- add fullscreen 3D page with scrub and readout
- add interactive three_js scene viewport
- add three_js mesh adapter
- add 3D preview card to dive detail
- add software projector and preview painter
- add geometry service and scene providers
- add scene marker layout
- add scene data entity and profile lookup
- add deco ceiling surface builder
- add temperature strata mesh builder
- add ribbon and depth-curtain mesh builders
- add metric-to-color palette
- add MeshData and SceneBounds scene normalization
- add three_js dependencies and platform spike
- startup auto-poll trigger on the dive list page
- suggestion row with confirm and dismiss on dive detail
- scan actions on dive detail and trip overview, Open in Lightroom in viewer
- connect flow, settings page, route, and localized strings (11 locales)
- serviceConnector upload eligibility with thumb-only videos
- riverpod wiring, serviceConnector registry registration, auto-poll provider
- connector resolver fills the serviceConnector registry slot
- scan service - window merge, dedup, confident attach, suggestions, poll
- per-device connector scan state in SharedPreferences
- confidence-bearing timestamp matching on DivePhotoMatcher
- connector columns on pending suggestions + suggestion CRUD and remote-asset dedup queries (schema v104)
- connector accounts repository (first consumer of the v72 table)
- partner API client with abuse-guard stripping and pagination
- Adobe IMS OAuth2+PKCE auth manager
- secure auth store for BYO Adobe credentials
- gear and weights section with live weight prediction
- dated body weight history in diver profile
- advanced buoyancy and dry weight fields on gear edit
- weighting feedback capture on dive edit
- data-driven weight planner tool replacing static calculator
- calibration and prediction providers
- placement predictor with largest-remainder rounding
- hybrid weight prediction engine with calibration
- weighted ridge regression solver
- gear feature priors and physics terms
- batch weight history observations query
- plan equipment junction and planned weight snapshot
- weighting feedback fields on dives
- buoyancy and dry weight metadata fields
- dated body weight entries with sync + providers
- wire diver_weight_entries and dive_plan_equipment into changeset sync
- add three_js flythrough spike page behind debug menu
- schema v104 for weight prediction (feedback, buoyancy, weight entries, plan equipment)
- persist heading in download and reparse pipelines
- capture DC_SAMPLE_BEARING and serialize heading on all platforms
- carry heading through DiveProfilePoint and repositories
- add dive_profiles.heading column (schema v105)
- let first-run users change the sync backend after connecting
- include custom dive roles in UDDF full backup/restore
- dive roles management page under Settings
- my-role editing on dive edit page and detail display
- role selector with custom-role creation and Me chip
- persist the diver's own role on dives (#547)
- resolve per-dive buddy roles from dive_roles table
- sync dive_roles (custom rows only, tombstones, adopt-safe)
- dive role l10n strings and localized display
- DiveRole entity, repository, and providers
- add dive_roles table and dives.diver_role column (v103)
- agency-first certification fields with dependent level list (#546)
- filter level dropdown by selected agency (#546)
- add agency-specific certification levels and catalog (#546)
- phase 4 exit coverage
- provider chooser with dropbox, drive, icloud connect
- per-provider connect flows
- provider-typed attach state and runtime
- icloud media adapter over the ubiquity container
- google drive media adapter with resumable sessions
- dropbox media adapter with session resume
- dropbox session primitives and range download
- phase 3 exit coverage
- transfer progress bars
- store-backed video playback path
- video uploads with resume and progress wiring
- S3 multipart upload with resume and streamed download
- queue resume-state and progress persistence
- progress and resume hooks on MediaObjectStore
- phase 2 exit coverage
- backfill and transfer policy toggles
- per-tile transfer badges
- transfers view with retry
- thumbnail routing in store resolution
- thumbnail objects in the upload pipeline
- thumbnail generator
- network-aware worker gating and drain triggers
- observable transfer queue with retry and defer
- transfer policies and video eligibility gate
- route first run and settings entry to the setup wizard
- existing-data path with restore, sync pull, and folder adopt
- finish step applies draft and offers feature links
- backup schedule and cloud sync connection step
- appearance step with live language preview
- units step with locale-aware preset and fine-tuning
- wizard shell with fork and profile steps
- draft apply service with race-safe settings seeding
- phase 1 end-to-end coverage
- setup wizard draft notifier and preview locale provider
- setup wizard domain model and step computation
- connect flow, media storage settings page
- add setup wizard strings in all locales
- unlock banner, troubleshoot status, encrypted restore prompt (#520)
- store fallback resolution in MediaItemView
- upload pipeline, worker, enqueue-on-attach
- end-to-end encryption section with enable and manage flows (#520)
- content-addressed cache with LRU eviction
- credentials store and attach state
- S3 adapter and store identity marker
- MediaObjectStore interface, fake, and contract
- smv1 key derivation and streamed hashing
- local cache DB v2 with transfer queue
- media entity + repository upload stamps
- register .zxu/.zxl document types and document DiverLog migration
- register mediaStores in sync engine
- encrypted cloud backup upload, restore, plaintext cleanup (#520)
- show attached photo counts in import summary
- add v103 schema (media stamps + media_stores table)
- attach DiveCloud photos to imported dives
- expand ZIP archives at file intake
- framed self-decrypting .sbe backup encryption (#520)
- riverpod wiring for encryption session and provider wrap (#520)
- ZIP expansion service for DiveCloud archives
- wire DAN DL7 into detection, registry, and source apps
- encryption lifecycle service - enable, unlock, rotate slots, self-heal (#520)
- DAN DL7 parser with Aqualung ZAR enrichment
- awaitingPassphrase halt for encrypted libraries (#520)
- parse the DiverLog+ AQUALUNG ZAR dialect
- encrypting cloud storage decorator (#520)
- local key custody, keyslot mirror, encryption preference (#520)
- add DL7 unit conversions
- recovery code generation on the EFF short wordlist (#520)
- add DAN DL7 segment reader
- keyslot file with Argon2id passphrase/recovery wrapping (#520)
- SBE1 encrypted envelope with python-generated KAT vectors (#520)

### Bug Fixes

- stop the cache leaking superseded files and the movie tile overclaiming
- give store-cached videos a container extension they can be opened by
- play and preview store-backed videos on synced devices
- guard the save flow against re-entry
- drop a stale site name when the site changes mid-lookup
- normalize inside DisplayZoomScope instead of trusting callers
- compute the plan summary after the naming flow
- surface unknown display-channel methods instead of no-opping
- snap zoom levels so 100% compares exactly
- lay the child out at the logical size, not the window size
- give the strict-close worker wait a checkpoint-sized budget
- honor the awaitWorkerShutdown contract on repeat calls
- make app-exit database close wait for the real SQLite close
- clear both library-epoch anchors so Repair cannot strand a device
- survive a page pop during a quality save
- fail closed when the iCloud container is unavailable
- make ensure() safe against a concurrent insert
- adapt to renamed media transfer summary API, UTC year range
- dedupe sites by name+coords, cap urgent banner, localize settings hub
- make the legacy S3 credential store injectable
- reuse the S3 account when the provider type flips
- stop minting a new account on every connect
- localize on-this-day minutes, de-flake anniversary test
- year hours rounding, indexed year query, stricter grid test
- make worker disposal stick across an in-flight drain
- stop reporting parked transfers as work in progress
- reduce hero banner padding
- smaller hero greeting, larger logo
- tighten hero right padding, enlarge quiet stats
- drop deepest stat from hero, shrink logo to 56px
- restore hero logo to right side at original size
- remove unbounded flex and intrinsic layout failures
- serve the compressed rendition when no original was uploaded
- a present-but-unreadable file verifies as transient, not orphaned
- probe readability, not just existence, for localFile resolve
- auto-verify bails without an active store descriptor
- bogus future fleet timestamp cannot suppress auto-verify
- drain sweep repairs before stamping the fleet timestamp
- private temp dir on Linux, thread pool on Windows
- check the remaining HRESULTs in HBitmapToPng
- refresh attach state on connect and disconnect
- move thumbnail-ready message off the colliding WM_APP + 1
- gate video poster generation to desktop platforms
- self-heal corrupt poster cache; move poster bytes on Windows
- session reaping is best-effort within the verify sweep
- qualify kThumbnailReadyMsg at its use inside the worker lambda
- treat a failed bookmark read as a null blob
- guard cache-dir failure, offload Windows extraction, doc accuracy
- include videos in upload backfill candidates
- use stream logical size when reading encoded PNG (Windows)
- enqueue Files-tab imports for upload
- format-agnostic poster cache extension, doc accuracy
- review round 2 on video thumbnail native handlers
- close first-part multipart leak and extension-variant orphans
- address review feedback on video thumbnail handlers
- hydrate media taken_at as wall-clock-UTC
- paint the ceiling line's shaded fill
- scope backfill candidates to dive- or site-linked media
- key the surface lead-in on each series' own profile (PR review)
- apply the t=0 readout to the inline tooltip and remaining curves
- describe t=0 in the readout instead of repeating the first sample
- compute pressure-based lead-ins, fix smoothing, cover mini charts
- extend every profile curve back to t=0, not just depth
- draw the depth trace from the surface at t=0 (#684)
- treat blank itinerary port and notes as absent
- address review on retry gating and exact-second matching
- self-sizing sticky day header for scaled text
- resolve gallery assets by exact capture second
- restore undo summary from persisted row, not in-memory outcome
- delete targets route planId, closing load-window race
- sweep stranded temp files on no-op restore + a11y label (PR review)
- don't let post-swap cleanup abort a succeeded restore (PR review)
- skip summaries watch on :planId route; SnackBar persist:false (#406)
- clear errorMessage when reclaiming a stranded row (PR review)
- read (not watch) repo in reclaim provider (PR review)
- navigate off dead route when plan already gone; pin test locale
- make the restore test seam one-shot and reset-safe (PR review)
- await transfer reclaim before wiring drains (PR review)
- keep the database open during large-DB restore so pages don't red-screen
- run transfer reclaim once per process, not per drain (PR review)
- recover orphaned 'transferring' uploads on drain
- stop master-pane selection toolbar from overflowing
- never leave a Windows .tmp on failure + quiesce dispatcher on teardown (PR review)
- Windows probe bitrate fallback, headless progress drop, test asserts (PR review)
- marshal Windows progress to platform thread + guard dimensions/root path (PR review)
- read source height off main thread in Android transcode (PR review)
- probe off main thread + drop redundant manifest package (PR review)
- harden Android Media3 error paths (PR review)
- share one progress stream across engine instances
- pin AVF reader PCM to the AAC encoder rate/channels
- clean up temp on all AVF failure paths; nullglob CI loop
- use readerFailed case + sync ios Podfile.lock (PR review)
- treat a gas change at the first sample as the initial gas (#679)
- Apple finalize/concurrency/error-message (PR review)
- unique progressIds + NaN-safe Apple probe (PR review)
- convert rename failure to TranscodeException (PR review)
- derive bitrate on N/A ffprobe + sync error-handling spec
- harden Apple AVFoundation engine (PR review)
- force mp4 muxer + auto-dispose availability check (review)
- sweep stranded transcode on original upload + doc fixes (review)
- record stored rendition size on dedup (PR review)
- fall back to original on TranscodeException (PR review)
- gallery ceiling rule + deterministic label tests (PR review)
- harden upload pipeline + rendition cache (PR review)
- guard dive_id column in the v132 bottom-time backfill
- truly exit compare mode when plans drop below two
- stop storing bottom time equal to runtime
- open saved plan with a single back press
- refresh safety review after sync and analyze-all
- deterministic tie-break for the Service Due sort
- guard ref use after await in the sync-pull gate
- cancel the auto-sync debounce timer on reset
- invalidate service urgency provider on schedule writes
- run disableForDatabaseReset guards independently
- guard v4 overrideLevel migration against v1 full-create path
- configure interval when adding a no-default service clock
- show enabled but unconfigured service clocks
- stop restored/reset data from vanishing under cloud sync
- keep @DriftDatabase on AppDatabase; detect edited legacy dives
- give the synthesized source the deterministic backfill id
- render 3D/spatial/compare for dives missing a data-source row
- enable encrypted sync on secondary devices after unlock
- translate built-in dive type names (#643)
- use AMV instead of SAC in the German UI (#640)
- prefilter withProfiles to primary samples only
- route detail-chip count through l10n
- hydrate detector toggles at startup
- dedupe dive headers + localize last-scan time
- address round-3 review comments
- stop the upload-pipeline test leaking async work past teardown
- address round-2 review comments
- localize the Safety section title on the mobile tile
- store/show incident occurredAt as wall-clock UTC
- guard user numeric attributes for finiteness
- droppable lead from placement in the through-dive twin
- sanitize BCD lift capacity before the bladder term
- address PR review comments and raise test coverage
- guard haversine NaN and stop the ticker on no-fly expiry
- localized geocoded countries, ISO country field, comment accuracy
- tighten attribute-prior edge cases from PR review
- drop dead safetyHub_* hub-link keys stranded by the merge
- address PR #635 review on the stale-bond repair
- mark edit form initialized after populating controllers
- address PR #611 review round 2 on the incident edit form
- gate runner overflow menu by strict-order actionability
- compute plan droppable lead from per-WeightType placement
- self-heal stale BLE bonds on the connect path (#621)
- suppress same-suit history strip for a suitless dive
- hide alerts banner when no renderable alert
- drop redundant chamber call menu item; align docs to v126
- use double bounds for clamp to avoid int-return crash
- self-invalidate no-fly status at expiry (Copilot review)
- treat non-positive wing lift capacity as null
- address PR #611 review — incident edit robustness, sync test coverage, route docs
- localize the unnamed-tank breakdown label
- address Copilot round-4 review (emergency card / dashboard)
- skip zero-duration plan segments in synthesizePlanProfile
- scope dive-summary lookups to the active diver (round 3)
- localize overdue-service note; pin test locales
- address Copilot round-2 review on emergency card
- pin compass reset animation to its original controller
- avoid duplicate timestamp in 5 m square profile; pin test locales
- sample the clock once in the no-fly alert text
- renumber no-fly migration v124 -> v125 after main collision
- address Copilot round 3 + raise no-fly patch coverage
- address Copilot follow-up on no-fly (round 2)
- address Copilot review on no-fly hub
- seed compass rotation on mount/swap; fix map test l10n
- date-attr picker caps at today; fix number-format test
- address Copilot follow-up review round 2 on PR #608
- address Copilot review on emergency card
- keep custom fields colliding with curated keys in CSV
- handle disposal mid-reset; harden compass test
- restrict suit-thickness filter to exposure suits
- address Copilot follow-up review on PR #608
- align dive-list badge with per-rule disables
- address Copilot review on PR #608
- translate Environment section/subsection headers (#622)
- localize weather and dive-condition enum values (#622)
- make junction authoritative for buddy/DM columns
- translate weather field titles for issue #622
- address round-6 Copilot review comments
- show junction buddies in table Buddy/Dive Master columns
- address copilot follow-up review round 3
- address copilot follow-up review round 2
- address copilot follow-up review
- saveReview bumps parent dive HLC so reviews sync
- reactivity, batched applyTemplate, atomic deleteCourse
- correct chart tooltip index; debounce twin re-simulation
- resolve relative next-page href against the request URI
- clamp stop tags to vertical bounds
- stop catalog scan per-page, not on first past-end asset
- unit-aware rate sliders; consume unavailable setup focus
- validate RecreationalNdlSolver args, fail fast on misuse
- drop pending pSCR edit on invalid input; fix provider doc
- repaint charts on style/textDirection change; pin test locale
- query captured_after so oldest-first scans reach in-window assets
- format ccr_ui_test + clarify geometry/pSCR docstrings
- make the connector-video play button semantically actionable
- make the Open-in-Lightroom launchUrl calls explicitly fire-and-forget
- address round-4 review comments
- address PR #617 review comments
- hydrate history/plan twins correctly; hu typo
- address service-ledger PR review batch 3
- address service-ledger PR review comments
- rapid-ascent rule uses fixed design thresholds
- address second-round PR #612 review comments
- address round-3 review comments
- address round-2 review comments
- address PR #617 review comments
- address PR #612 review comments
- ensureDeletionLogIndex only dedupes on real duplicates
- connector videos show poster + Open in Lightroom instead of failing local playback
- tolerant asset parsing - a list where a scalar was expected crashed the whole scan
- scan uses a single capture cursor (captured_after/before are mutually exclusive) + surface API error body
- dedupe 'Go to dive' in finding cards (footer + repair action)
- address Copilot review on attribute thickness/number fields
- move Dives review entry into the overflow menu (all app-bar variants)
- move Data quality entry under Settings > Data (was Unknown section on wide layout)
- smooth depth into the suit term to de-noise the curve
- hydrate typed weights and equipment for the twin
- label the net-buoyancy chart axes
- autoDispose badge providers, stub in test base overrides
- add no-fly to wide planning sidebar and correct stale incident routes
- setup accordion PageStorage bool collided with TextField scroll restore
- editor pane always visible on desktop, drop drawer, compact segment tiles
- suppress time tick labels that collide with the axis unit label
- merge safety review rows in sync apply and harden disabled-rules decode
- renumber pre-dive checklist migration to v117 (ladder collision)
- PRAGMA-guard v115 legacy copy for minimal old-schema databases
- account for seeded built-ins in template repository tests
- bump dive detail section count expectations to 19
- GC exempts only durably fenced peers; spec marker semantics
- address PR review - distinct item counts, diver-scoped custom kinds, pinned test locales
- defer Perdix overlay controller-removal rebuild past tree finalization
- renumber service ledger migration v113 to v115 (open PR claims)
- make v113 backstop self-guarding for partial fixture databases
- package imports, settings mock stubs, mini profile header overflow guard
- drop deleted hw_frog.c from platform build source lists
- prompt for passphrase when restoring encrypted backup in setup wizard
- stop encrypted-restore passphrase dialog from over-popping the navigator
- create temp dir before restoring on fresh installs
- carry exit GPS through ImportedDiveConverter for #586
- second review pass on #586
- address #587 re-review (round 5) - error-path hardening
- trip-story review round 15 (6 comments)
- address #587 re-review (round 4)
- address #587 re-review (round 3)
- address #586 review + raise patch coverage to ~92%
- address #587 re-review (round 2)
- correct liveaboard port day-index + bound media concurrency (PR review round 14)
- address #587 review feedback
- address trip-story review round 13 (16 comments)
- clamp rhythm-bar track height so it never goes negative (PR review round 12)
- extend story day span to cover out-of-range itinerary days (PR review round 11)
- only draw the story route polyline with 2+ points (PR review round 10)
- best-effort media/sightings + pin-tap camera (PR review round 9)
- gate cert commit on a dirty flag + localize detail error (#553 review)
- assert CertificationEditPage mode contract (#553 review)
- dismiss scan loading dialogs via captured navigator (PR review round 7)
- inject CertificationRepository into _importBuddies (#553 CI)
- address PR re-review (round 6) for #553
- preserve staged cert updatedAt on unchanged Save (#553 review)
- address PR review round 5 (effectiveEntryTime, scroll threshold, vessel overflow)
- address PR re-review (round 4) for #553
- address PR review round 4 (active-day fallback, species merge key)
- drive S3 _save provider work through the app container so a mid-save pop can't crash on ref-after-dispose or skip the global refresh
- address PR re-review (round 3) for #553
- address PR review round 3 (reactivity, painter/delegate equality)
- gate account-first resolution on settled account so a credential-edit reload uses the legacy singleton, not a stale per-account key
- address PR re-review for #553
- clamp hover tooltip using its real measured size
- address PR review for #553
- run global sync-state refresh before S3 re-derivation await so a mid-save pop can't leave dependent screens stale
- mounted guards after account-derivation awaits; mirror failure falls back to legacy resolution
- guard AxisFrame divisions against 0; make wireframe step int explicit
- best-effort legacy Dropbox key clear on sign-out (never abort sign-out on keychain error)
- remove unused import in trip story view
- disconnect clears both credential locations (bidirectional mirror + legacy clear on Dropbox sign-out)
- re-track hover tooltip on camera changes; drop dead compartments branch
- align tissue provider nullability with builder; validate picker arrays
- guard account-first resolution against a stale account of the wrong kind during the provider-type transition
- anchor tissue Y tick labels from sceneMinY to match tick geometry
- restrict tissue-pick depth tie-break to exact screen-point overlap
- per-axis tick colors + localized zoom button tooltips
- wire accountCredentialsStoreProvider into the S3 adapter so test overrides reach it
- pan-aware tooltip screenPos + stop trackpad pan from rotating
- async volume-mount probe so an offline share can't block the UI isolate
- second device with synced account but no local creds can sign in (gate on device status, reuse roster row)
- address PR review — cache invalidation, repaint keys, bounds guards, RTL, picker perf
- review - break core->presentation cycle, refresh Dropbox blob on connect, sync-tick on account selection, checked Lightroom adapter
- migration retries reuse persisted account ids (no duplicates, no misassignment)
- disconnect through the adapter so the cached manager is evicted
- review round 2 - updatedAt semantics, adopted-row pending marks, connectS3 kind guard
- review findings - deletion tombstones, manager-backed disconnects, sync-S3 never adopts media-S3
- startup rekey reads adopted roster; selection bookkeeping best-effort
- career terrain has no scrub cursor (drop inherited ScrubPath)
- cover DiveMode.gauge in the CCR segment switch after rebase
- analyze CCR dives with loop gas segments in both analysis paths (issue #455)
- run CCR dives through the gas-segment deco path (issue #455)
- immutable DiveIdSet family key + scrub-bar play/pause tooltip
- gauge analysis honors user ascent-rate settings; explicit freedive mapping (#569)
- keep real reported tank records for gauge downloads (#569)
- address second-round PR #565 review comments
- stable source partition in compare adapter; dispose test notifier
- address PR #565 review comments
- correct horizontal drag-rotation direction
- respect unit preferences for height in body weight entry
- replace fragile PageStorage retention with deferred-restore retainer
- override flutter_angle with Flutter 3.44 embedder fix fork
- pickFirst duplicate libc++_shared.so from flutter_angle
- package import in auth store
- restore libdivecomputer submodule pointer to main's pinned commit
- align empty state with dive list (log-first-dive + add-dive sheet)
- symlink macOS Pigeon output to iOS copy to prevent staleness
- correct finish-screen feature routes (/gear->/equipment, /stats->/statistics)
- advance libdivecomputer submodule to match main (Perdix 3 descriptor)
- address PR #548 re-review comments (#520)
- sync-error state handling + surface iCloud-unavailable message
- temp-dir safety, client lifecycle, preflight and queue hardening
- thumb-first resolution, gallery-only passthrough, staging cleanup
- harden resume parsing, clear stale errors, forward content type
- recognize the Shearwater Perdix 3 during BLE scanning
- carry entry/exit GPS onto the target when folding dives (#542)
- handle pull failures in the sync-connect step
- address PR #548 review + raise patch coverage to 97% (#520)
- create the sync temp dir before writing (macOS #554)
- address PR review — settings re-entry backup state, cloud-backup toggle, PageController resync
- mirror effectiveRuntime edge cases and fully order site query
- deterministic tie-breakers for personal-record queries
- row-safe WAL checkpoint + honest hydration benchmark timing
- trim terms, accurate limit notice, and cleaner layering
- S3 redirect bounce, back navigation, drop appearance step
- use sandbox-safe temp dir and tidy empty-archive extraction
- clean up ZIP temp dirs and stale photo state

### Refactoring

- make the iCloud platform seam a single enum
- remove quality from device-local policies
- read upload quality from the synced policy
- seed the migration at deterministic ids
- address review feedback on the localFile readability fix
- address third PR 705 review pass
- address second PR 705 review pass
- address PR 705 review feedback
- address PR 704 review feedback
- extract shared backup-status predicate
- drop redundant story dive sparkline
- return stderr from the process-runner contract (review)
- generalize DarwinAvfEngine to ChannelTranscodeEngine (shared by Apple+Android)
- drop redundant clock invalidation on configure-tap
- batch enrichment backfill; complete parent-refs coverage
- log+rethrow in getDiverCount; keep reset stack trace
- schedule override dialog takes schedule + kind
- centralize the legacy data-source id format
- thread the dive-type resolver into the list tiles
- drop unused ref param from showStartSessionSheet
- address review on compass control
- address PR review — rename flag, fix docs, redirect route
- await repository writes in requirement_tile callbacks
- localize picker tab labels; pin en locale in media-sources/picker tests (PR #619 review)
- consolidate photo sources under Photo library & sources; retire hidden-picker-tabs toggle
- dissolve safety hub into planning, settings, and profile surfaces
- dive planner hub row is a normal clickable tool tile
- drop icon rail and shell - tools render full-bleed
- retire hero slot and stale chrome tokens
- centralize wizard surface alphas; add branch-step hug test
- scope buddies watch to the pair, self-contained signatures diveId
- memoize derived CCR loop ascent plan; guard fixture minute-40 lookup
- drop unused CompareProfile3dView.title param
- wrap shortcuts at _buildContent call site to shrink diff
- career terrain delegates to CompareGeometryService
- generalize renderable to scene-agnostic Scene3d
- replace three_js engine with interactive CustomPainter viewport
- promote PKCE helpers from dropbox to shared core/services/oauth
- drop @visibleForTesting on prod helper; de-dupe dive-plan index DDL
- move wizard step primitives to lib/shared/widgets/wizard

### Performance

- persist the slider on release instead of every notch
- cascade reuses the rows it already read; guard empty partition
- evaluate chosen-set clocks in parallel
- evaluate active clocks once; watch urgency only when needed
- scope pre-push tests to files changed in the push
- count divers instead of loading all for the restore gate
- run data-source backfill after the performance-index heal
- index equipment attributes once in gearFeatureFor
- reuse the fence check's folder listing for the pull
- stable onDaySelected identity so the map header doesn't rebuild each frame (PR review round 8)
- split tissue chrome into static + dynamic overlay painters
- re-project only the picked vertex on camera change
- hoist nullable-depth cast out of the frame-rate readout builder
- commit _currentDatabasePath only after verified open (WS5 review 5)
- evaluate effective-runtime subquery once for longest dive
- strict close in reinitializeAtPath verify-fail path (WS5 review 4)
- strict close keeps connection ref on failure (WS5 review 3)
- apply strict close to all reopen-after-close paths (WS5 review 2)
- strict close on reopen paths + reset lastOpenMode (WS5 review 2)
- single version read + fail-fast migrator close (WS5 review)
- deterministic bounded ordering + empty-query guard
- execute SQLite off the UI isolate (WS5)
- SQL-bounded home providers, no hot-path getAllDives (WS4)
- decimate analysis curves and scope the series cache (WS3)
- lean hydration for the analysis lookback path (WS2)
- bounded DiveSummary search hydration (WS1)
- bracket ready-to-first-frame timing; attribute debug startup freeze to JIT + getAllDives
- checkpoint WAL after heal; startup step timing; re-baseline findings
- self-heal performance indexes in beforeOpen
- vmcap VM-service profiler tool and measurement runbook
- canonical index list, db_bench tool, WS0 SQL baseline

### Documentation

- drop em-dashes from the v1.7.0 release notes
- regenerate the changelog for 1.6.1
- document recently merged PRs in v1.7.0 release notes
- sync the zoom spec and plan with the implemented API
- correct the display zoom ARB key list
- record the OverflowBox constraint fix
- update _openDatabase comment for BackgroundDatabaseConnection
- implementation plan for naming a saved dive plan
- implementation plan for app-wide display zoom
- design for naming a saved dive plan
- design for app-wide display zoom
- plan synced media upload quality
- spec synced media upload quality
- add connected accounts deduplication implementation plan
- add connected accounts deduplication design
- add dark deep splash and hero implementation plan
- add dark deep splash and hero background design
- add Home page redesign implementation plan
- add Home page redesign design spec
- add v1.7.0 release notes
- drop the 'See it in action' section heading
- tighten and lighten the header subtitle
- put logo and title on the same line in the header
- put logo and title on the same line in the header
- simplify header and move downloads to dedicated section
- correct the upload-pipeline scope claim in the design spec
- implementation plan for local-media upload badge
- design for local-media auto-upload and not-backed-up badge
- implementation plan for orphan prevention PR 4 (Verify Library)
- resolve orphan-predicate verification gate; PR 3 plan (cascade + backlog sweep)
- correct toWallClockUtc reference in comments
- implementation plan for local-file video thumbnails
- implementation plan for orphan prevention PR 2 (blob delete fast path)
- design spec for local-file video thumbnails
- implementation plan for orphan prevention PR 1 (backfill scoping)
- design spec for media store orphan prevention
- implementation plan for trip story scroll polish
- design spec for trip story scroll polish
- implementation plan for deleting a dive plan from the canvas
- point requeueStale doc at its once-per-process caller
- add Code of Conduct and Contributing guide
- design for deleting a dive plan from the canvas
- correct stale v130 refs to v133 for compressed-rendition columns
- design and implementation plan for the deco stop band
- implementation plan for video transcoding Phase B4 (Windows MediaTranscoder)
- implementation plan for video transcoding Phase B3 (Android Media3)
- implementation plan for video transcoding Phase B2 (Apple AVFoundation)
- implementation plan for video transcoding Phase B1
- design spec for video transcoding (upload quality Phase B)
- reference hasAnyDiversProvider.future in the restore-gate comment
- implementation plan for equipment service clock unification
- correct spec GC scope (general sweep unbuilt; Phase A does targeted delete only)
- Phase A implementation plan for adjustable media upload quality
- spec for unifying equipment service on clocks + add-timer fix
- media_enrichment sync implementation plan
- design spec for adjustable media upload quality
- add phase 2 no-fly countdown implementation plan
- implementation plan for water type from dive site (#624)
- design spec for water type from dive site (#624)
- clarify paging fake models ordering/pagination, not null-capture assets
- reconcile design + plan to shipped schema v114
- Lightroom Native App embedded-connect implementation plan (Plan 2)
- Lightroom approval walkthrough page + resubmission email drafts
- Lightroom Native App auth core implementation plan (Plan 1)
- Lightroom connect via OAuth Native App design (unified BYO + embedded)
- phase 5 implementation plan - SCR breathing mode (validated slice)
- phase 4 implementation plan - rates and gas options (no-schema slice)
- data quality assistant plan 2 (repairs and inbox UI)
- buoyancy digital twin implementation plan
- data quality assistant plan 1 (data and detection engine)
- buoyancy digital twin design
- weight planner attribute-informed priors implementation plan
- phase 3 implementation plan - on-chart editing
- attribute-informed buoyancy priors for the weight planner
- data quality assistant design spec
- phase 2 implementation plan - Mission Control layout
- changelog entry for configurable CNS calculation method
- edit form chrome redesign implementation plan
- CNS calculation method spec and implementation plan (issue #578)
- phase 1 implementation plan - chart + design system
- edit form chrome redesign design freeze
- planner UI redesign + Subsurface parity design spec
- mark safety features spec implemented
- add phase 4 near-miss log implementation plan
- add phase 3 emergency card implementation plan
- add phase 2 no-fly countdown implementation plan
- correct logDeletion comment to reference the v113 index
- correct Perdix overlay hit-testing comment
- renumber safety review schema claim to v116 (v115 taken by PR #602)
- add pre-dive checklist implementation plan
- add phase 1 implementation plan for post-dive safety review
- equipment attributes implementation plan (10 tasks); align spec with backup/date ground truth
- gear service ledger implementation plan
- implementation plan for Perdix video overlay (#168)
- add safety features design spec (review, no-fly, emergency card, near-miss)
- add pre-dive checklist feature design spec
- design spec for Perdix-style media playback overlay (#168)
- gear service ledger design spec
- equipment type-specific attributes design
- mark tombstone GC spec implemented
- add course requirement tracker implementation plan
- implementation plan for fleet-acked tombstone GC and device retirement
- add course requirement tracker design spec
- design spec for fleet-acked tombstone GC and device retirement
- add PR artifact links design spec and implementation plan
- implementation plan for default & geofenced equipment sets (#583)
- spec for default & geofenced equipment sets (#583)
- implementation plan for app-wide encrypted backups (#580)
- design spec for app-wide encrypted backups (#580)
- record trip story implementation deviations
- add trip story implementation plan
- add trip story design spec (issue #166 + interactive breakdown)
- correct stale no-on-canvas-text claims (axis_frame + plan)
- record post-review revisions (labels, Z width, pan/zoom, review fixes)
- spec and plan for tissue axes, grid, and tooltips
- clarify ascentGasPlan null behavior for setpoint-bearing segments
- add CCR loop-aware deco/TTS implementation plan (issue #455)
- connected accounts phase 1 implementation plan
- media linking and storage program design spec
- correct gauge plan l10n to 11 locales (add zh) (#569)
- add gauge dive mode implementation plan (#569)
- add gauge dive mode design spec (#569)
- implementation plan for previous/next navigation
- implementation plan for 3D profile comparison
- design for previous/next adjacent-dive navigation
- design spec for 3D profile comparison (dives + computers)
- record retainer revision superseding PageStorageKey approach
- implementation plan for detail pane scroll retention
- drop redundant scaffold bucket after spike; keys alone suffice
- design for detail pane scroll retention
- add tissue saturation 3D scene design spec
- add Terms of Use for third-party API integrations
- drop three_js from 3D flythrough spec and PR 2 plan (CustomPainter reversal)
- add 3D flythrough PR 2 plan and spec addendum
- mark 3D flythrough PR 1 plan progress (PR #563)
- Lightroom auto-linking implementation plan + spec corrections from code exploration
- add dive 3D view implementation plan
- add 3D flythrough PR 1 implementation plan; fix TTS storage note in spec
- add Lightroom cloud auto-linking design spec
- add dive 3D view design spec
- add 3D dive flythrough design spec
- add weight prediction implementation plan
- add weight prediction design spec
- v1.6.1.115 release notes for encrypted cloud sync (#520)
- forbid Claude Code attribution and session URL in PR descriptions
- dive roles implementation plan (11 tasks, v103)
- agency-dependent certification levels implementation plan (#546)
- dive roles design spec (custom roles #551, own role #547)
- agency-dependent certification levels design (#546)
- media store phase 4 implementation plan
- media store phase 3 implementation plan
- reword temp-dir test comment (Copilot review #555)
- media store phase 2 implementation plan
- select main isolate; require-arg usage syntax
- explain getMergedProfile is intentionally unfiltered for parity
- split provider doc comments after analysisDiveProvider insert
- describe the setup wizard first-run flow
- setup wizard implementation plan
- media store phase 1 implementation plan
- setup wizard for new databases (discussion #523) design spec
- DiverLog+ / DAN DL7 import implementation plan
- encrypted cloud sync implementation plan + cryptography deps (#520)
- media store (cloud media storage backend) design spec
- encrypted cloud sync (E2E) design spec (#520)
- DiverLog+ / DAN DL7 import design spec
- WS0 in-app verification on the live database

### Tests

- name the photo cache test for what it asserts
- stop the poster test comment claiming a JPEG fixture
- pin Intl.defaultLocale in the plan name generator tests
- await the stalled close and drop the unreliable WAL assertion
- drive the container lookup through an injected seam
- assert upload quality keys are not device-local
- cover the managed-kind anchor and the startup guarantee
- pin locale to en in widget-test harnesses
- cover recentPhotosProvider and gear tie-break branches
- cover Home appearance entry in both settings twins
- cover chips, cards, providers and review fixes
- exercise the bookmark branch on every host, not just Apple
- raise PR 705 patch coverage to 90%
- name the library-level orphan fixtures for their source type
- dive-deleted media contract - cascade for dive-only, unlink for library
- compressed backfill exclusion tests the stamp, not linkage
- link backfill service fixtures to a dive
- cover the t=0 lead-in paths flagged by Codecov
- cover the resolution tier ladder and stale-cache clearing
- pin Intl.defaultLocale in day header tests
- cover Darwin progress routing/clamp/cancel (PR review)
- cover initial-gas detection across sample intervals
- Windows MediaTranscoder integration test
- Android Media3 integration test + fix darwin test rename
- macOS AVFoundation integration test (ffmpeg-synthesized input)
- real-ffmpeg smoke test with synthesized fixture
- pin en locale and close the DB in teardown for the new tests
- also cover the reset sync-disable failure path
- cover disableForDatabaseReset, reset gate, and getDiverCount error
- relax v129 tripwire; v130 owns the exact-latest schema assertion
- end-to-end compressed photo upload + cross-device read
- mock SharedPreferences in end-to-end test (pipeline reads quality policy)
- const MaterialApp in service clocks card test (lint)
- stub per-dive findings badge stream in shared overrides
- pin gloves/boots strength in the no-attributes regression
- raise near-miss patch coverage to ~93% + localize list error
- prove GearBuoyancyTraits equality is by list content
- reconcile dive-detail section count to 20 after merge
- add emergency_chambers to parentRefs completeness guard
- fix v125 schema tripwire and raise emergency-card patch coverage
- restore exact-latest schema-version tripwire in the v119 test
- raise patch coverage to ~93%
- cover v124 no-fly migration and exact-latest tripwire
- make CSV export fixture const (--fatal-infos)
- pin en locale in chart and what-if widget tests
- compare enum localization against getters, not literals
- raise PR #608 patch coverage above 90%
- cover course requirement tables in parentRefs completeness guard
- direct ConnectorVideoItem test (fix CI coverage collection)
- restore FlutterWebAuth2Platform.instance after the redirect-capture test (PR #617 review)
- raise patch coverage above 90%
- cover embedded dive->site navigation paths
- raise patch coverage on the native-app connect diff
- assert renamed Database Cloud Sync app bar title
- relax the v112 exact-latest tripwire to gte
- pin en locale in settings-page widget test (PR #617 review)
- align Perdix overlay position mocks with production clamping
- disable ambient scan scheduler globally in tests
- move exact-latest schema tripwire to the v120 migration test
- VPM-B golden vectors + generator (bwaite/vpmb BSD-2 reference)
- remove unused import in sync test
- twin agrees with static engine at the weighting convention
- engine-level attribute-prior behavior coverage
- adapt site/dive edit suites to v2 header-in-card chrome
- macOS-gated golden images for the plan chart
- cross-validate CNS methods against issue #578 references
- raise service ledger patch coverage past 90 percent
- update section count assertions for safety review section
- pin en locale in Perdix overlay widget tests
- usage-sample dedup and trip reminder coverage
- address #588 review
- raise #587 patch coverage to ~97% and harden per review
- taller viewport so the new encryption section doesn't push history off-screen
- raise trip story patch coverage to ~91%
- cover Dropbox sign-out catch, connect-flow account refresh, and matching-kind fallback (patch coverage 73%->93%)
- address PR review — pin en locale, closeTo, drop unused dayDate
- tolerant dy compare in ResponsiveSectionPair row test
- pin CCR fixture TTS against Subsurface (issue #455)
- reparse gauge maps to gauge; unknown mode uses unrecognized string (#569)
- raise patch coverage - getOrderedDiveIds filter/diverId branches, dive-detail nav navigation
- lock in detail-pane scroll retention contract
- exclude GL viewport from coverage (device-matrix verified)
- raise patch coverage for geometry service, providers, and page
- raise patch coverage - settings page suite, dialog error paths, viewer action, entity equality, auto-poll failure
- raise patch coverage for the weight prediction feature
- raise patch coverage across adapters, page, and providers
- raise patch coverage for the dive roles feature
- cover merge-mode certification cycling; make catalog abstract final (#546)
- raise WS5 patch coverage to ~94%
- raise patch coverage to 90%+ for the wizard
- clarify newer-than-app test rejects before any Drift open
- cover diver-scoped records and the SQL count providers
- cover zoomed decimation, dense overlays, and MOD line (WS3)
- cover startup step timing; scope coverage to real logic
- cover search provider and DiveSearchDelegate
- DL7 end-to-end batch integration coverage
- no-plaintext-leak invariant and encrypted two-device convergence (#520)
- update restore-service doubles for the encryptionSecret parameter (#520)
- env-gated real-sample regression suite for DL7
- query-plan regression tests for performance indexes

### CI/CD

- run each integration test file in its own flutter test invocation
- bound the macOS integration-test job to 25 min
- scan only PR/push commits for the override marker (two-dot log)
- clarify that the inert-path case globs match nested paths
- add an escape hatch to force the full pipeline
- skip test/build jobs when a change touches no Dart
- shard tests 4->8 to roughly halve test wall-clock
- bump actions/download-artifact from 4 to 8
- bump actions/github-script from 7 to 9
- bump actions/setup-python from 6 to 7
- install libwebkit2gtk-4.1-dev for the Linux build
- TEMPORARY debug job to isolate photo_viewer coverage collection
- connector-video line diagnostic + standard lcov field order
- merge shard coverage into one Codecov upload (fix zeroed patch coverage)
- install libwebkit2gtk-4.1-dev for the Linux build
- make PR-target binding merge-commit-safe; use GITHUB_SERVER_URL
- harden artifact-links per review
- address review on artifact-links
- add PR comment with build artifact download links
- upload testable build artifacts and PR number on pull requests
- wait for all coverage uploads before status
- enable git long paths on Windows for the flutter_angle git dependency
- install CMake 3.31.4 in Android build for flutter_angle

### Chores

- bump version to 1.7.0+117
- register submersion_transcoder plugin (pod install)
- format engine + commit pubspec.lock for submersion_transcoder dep
- temporary [LR-SCAN] diagnostics for the empty-scan investigation
- lock flutter_web_auth_2 pods
- register embedded Adobe redirect scheme (iOS/Android/macOS)
- regenerate plugin registrants for flutter_web_auth_2
- post-implementation sweep
- bump CocoaPods lockfile stamp to 1.17.0
- preserve error+stackTrace when logging swallowed sign-out and account-derivation failures
- drop unused import
- delete orphaned Dive3dPreviewCard widget + test
- add 3D comparison strings (English; locales pending)
- regenerate macOS Podfile.lock after flutter_angle removal
- register flutter_angle in platform plugin registrants
- regenerate plugin registrant for cryptography_flutter (#548)
- finalization sweep, plan checklist complete
- verification fixes for setup wizard

### Other

- i18n(zoom): translate display size strings into all locales
- i18n(planner): add plan name dialog title and fallback label
- Revert "docs(readme): put logo and title on the same line in the header"
- delete release nots
- format the dive-deleted media sync contract test
- format PR 3 tests
- format new delete fast path tests
- format backfill scope test
- register transcoder plugin in generated registrant
- Apply suggestions from code review
- backtick angle-bracket paths in transcode doc comment
- docs+perf: renumber spec/plan to v131; pre-dive evaluates only chosen set
- Bound the HEIC meta box read (PR review)
- Guard HEIC extent read + add iloc v2 coverage (PR review)
- Harden HEIC parser against malformed input (PR review)
- Read HEIC/HEIF capture time on desktop
- format media_repository_compressed_test
- Address PR review r2: harden mvhd version + accurate decode-error tile
- Address PR review: dispose guard + explicit icon centering
- Match photos and videos to dives by capture time on desktop
- Address sync review feedback
- Remove internal continuity notes from PR
- Add sync investigation continuity notes
- Make epoch filtering strict and report skipped peers
- Fix sync of legacy peers after epoch adoption
- dart format the built-in reference-data contract test
- const the infinite-lift traits to satisfy analyze
- dart format safety settings test
- test/docs: address copilot follow-up review round 4
- drop the shard-coverage-merge experiment
- clear stale completedAt on dive edit; make once-per-course link atomic
- fixes based on github copilot suggestions and fixes.
- Potential fix for pull request finding
- fix missing import for settings_providers
- fix linting warnings and undefined identifiers in dive log and site navigation tests
- Potential fix for pull request finding
- Created a comprehensive test suite for the newly implemented nested navigation and embedded site details in the dive log.
- wall-clock-as-UTC dive dates and once-per-course link invariant
- cover the totalCount==0 dashboard filter with an in-progress course
- Enhanced Dive Log to Site Navigation
- address PR #601 feedback
- null-aware element in dive label
- Add support for wetsuit thickness parsing in weight planner
- Updated formatting with dart format
- Delete CNAME
- Create CNAME
- Potential fix for pull request finding
- - Incremented `currentSchemaVersion` to `v112` and updated migration versions in tests to prevent version mismatch errors. - Removed unnecessary line breaks for improved code readability.
- Potential fix for pull request finding
- Potential fix for pull request finding
- ### Add thickness property to equipment models
- update gitignore
- i18n(backup): add backup-encryption strings (en + 10 locales)
- Update issue templates
- perf/a11y(trips): address PR review round 6
- clean suggestions-row test lints
- const DivePhotoMatcher call sites
- drop unused test import
- null-aware map elements in token forms
- Revert "feat(debug): add three_js flythrough spike page behind debug menu"
- l10n: translate sync encryption strings into all locales (#520)


## 1.6.1 (2026-07-25)

### Features

- add macOS View menu zoom items
- add display size control to Appearance settings
- add zoom in/out/reset keyboard shortcuts
- rename a saved plan from the overflow menu
- apply display zoom at the app root
- prompt for a plan name on first save
- add device-local display zoom provider
- extract plan name dialog and mark the title editable
- add DisplayZoomScope for app-wide true zoom
- add display zoom constants and value clamping
- add default plan name generator
- show the transcode hint on any incapable device
- drive quality dropdowns from synced providers
- add MediaUploadQualityPolicy over synced settings
- add raw key-value accessors to AppSettingsRepository
- run the account deduplicator after the migration
- add the startup account deduplicator
- add ConnectedAccountsRepository.ensure
- add deterministic connected-account identity
- match wizard ocean brightness to the splash
- resolve splash brightness from cached theme mode
- mirror theme mode into prefs for pre-db surfaces
- swap OceanBackground dark palette to Abyss Blue
- add startup brightness resolver with cached theme mode
- attention chips with per-chip visibility settings
- gauge strip shows only due/overdue gear, capped at 6
- responsive monitor-first home page assembly
- recent sites map card
- year-in-review card
- on-this-day dives card
- recent photos ribbon
- milestones provider and card
- hero header with left logo and quiet desktop stats
- add always-on GaugeStrip and UrgentBanner
- add responsive DashboardGrid layout widget
- show a not-backed-up badge on media tiles
- opportunistic 30-day verify sweep
- manual Verify Library action
- fleet-wide verify sweep timestamp (schema v136)
- verify library sweep service
- verify-sweep repository helpers
- reap stale multipart upload sessions
- list in-progress multipart uploads
- one-time backlog sweep for orphaned media rows
- dive deletion cascades to dive-only media
- cascade partition, synced unlink, and sweepable-orphan query
- Linux ffmpegthumbnailer video thumbnails
- Windows shell video thumbnails
- macOS QuickLook video thumbnails
- resolve local video thumbnails via VideoThumbnailService
- add VideoThumbnailService with disk cache
- add generateVideoThumbnail channel wrapper
- transfers page renders delete entries
- route media deletion flows through the deletion coordinator
- deletion coordinator enqueues blob deletes before rows die
- abort stranded S3 multipart sessions on terminal failure
- worker routes delete entries, cellular gate exempts them
- delete processor with drain-time refcount guard
- countRowsWithHash refcount for blob deletion
- delete-intent queue entries with per-hash idempotency
- local cache DB v6 adds transfer queue payload column
- sticky per-day headers in the trip story
- sticky day header widget for the trip story
- add TripStoryDay.isSurface
- map-only pinned story header with 180px floor
- delete the open plan from the canvas with confirm and undo
- show a persisted-gated Delete plan menu item in the canvas
- add l10n strings for delete-plan action
- add deco stop band toggles to legend and settings
- draw the deco stop band on the dive profile chart
- add stepped deco stop band renderer
- add deco stop band visibility and source settings
- add deco stop band settings columns (schema v133)
- resolve deco stop band source independently of ceiling
- populate quantized decoStopCurve on ProfileAnalysis
- add deco stop quantization and step transition helpers
- Windows MediaTranscoder transcode + progress (unverified on Windows)
- Windows plugin scaffold + WinRT probe (unverified on Windows)
- return ChannelTranscodeEngine on Windows
- surface a trash button on saved-plan rows
- Android Media3 probe + transcode (Kotlin)
- Android plugin scaffold + Media3 deps
- dispatch to AVFoundation engine on Apple
- AVFoundation probe + transcode (Swift)
- Dart DarwinAvfEngine channel client
- convert to plugin with darwin scaffold (iOS+macOS)
- Linux ffmpeg hint on the upload quality section
- wire PlatformVideoTranscoder + availability providers
- PlatformVideoTranscoder adapter with ceiling rule
- transcode-once pipeline integration for video
- deterministic transcode staging in cache store
- bitrate-based video presets + ceiling rule
- Linux ffmpeg engine with process-runner seam
- scaffold submersion_transcoder with probe DTOs
- per-item re-upload quality action in the photo viewer
- Upload quality settings section
- upload quality strings across 11 locales
- wire compressor defaults + reupload entry point
- resolver serves compressed renditions with freshness
- per-item re-upload override with guarded delete
- pipeline branches uploads on quality level
- v130 reconcile legacy service intervals into clocks
- table Next Service Due column reads clocks
- add clock-based Service Due list sort
- remove legacy service settings from edit form
- flag overdue gear from service clocks
- list badges use clocks only, drop legacy fallback
- queue overrideLevel column + enqueueReupload
- detail header service state from clocks; drop mark-as-serviced
- MediaCompressor seam + pure-Dart ImageCompressor
- rendition cache pool with freshness check
- per-media-type upload quality policy
- compressed stamps, refcounts, and backfill fix
- add compressed rendition fields to MediaItem
- add v130 compressed rendition columns
- add renditionKey store-key derivation
- add MediaUploadQuality enum and presets
- backfill hlc on legacy media_enrichment rows (self-heal)
- replicate media_enrichment as a first-class HLC entity
- add hlc column to media_enrichment (schema v130)
- add no-fly countdown, safety hub, and altitude flag (safety phase 2)
- add no-fly guideline classifier service
- add reset-to-north compass on rotatable maps
- cycle water type when merging sites
- auto-fill dive water type from the assigned site
- edit water type in the site editor
- persist and hydrate site water type
- hide Lightroom UI pending Adobe review
- rename Cloud Sync to Database Cloud Sync (tile + page title)
- Subsurface-exact pSCR O2 model, hypoxia warning, ratio setting
- recreational NDL-maximization solver
- passive semi-closed rebreather (pSCR) breathing mode
- one-tap embedded Connect with Adobe on the settings page
- signInWithEmbeddedCredential helper (begin/capture/complete)
- injectable redirect-capture wrapper over flutter_web_auth_2
- flutter_web_auth_2 dep + embedded Native App credential constants
- Native App auth - refresh-token-optional connect, per-connection redirect, reauth signal
- VPM-B decompression model validated against golden vectors
- optional refresh token + per-connection redirect uri in auth data
- wire v120 columns through domain, repo, engine, sync (per-segment setpoint/mode, plan start time, deco switch depth)
- schema v120 - plan start time, per-segment setpoint/mode, per-tank deco switch depth
- review inbox page, cards, badges, settings screen
- l10n keys for inbox, findings and repairs (11 locales)
- through-the-dive simulation panel
- buoyancy twin outputs in Gear & Weights
- what-if buoyancy re-simulation sheet
- weighting history strip comparing carried vs modeled lead
- inbox providers, detector toggles, watch queries
- net buoyancy chart with per-moment breakdown
- repair actions and executor
- buoyancy detail section with final-stop diagnosis
- profile repair math over edited-profile pattern
- tank pressure series and record repairs
- bulkShiftDiveTimes with snapshot restore
- targeted scan hooks on import and save
- wing lift capacity capture (schema v119)
- scan service, scheduler and providers
- detector registry and SQL pre-filters
- gas, tank-assignment and source detectors
- temperature and pressure detectors
- profile gap, spike and rate detectors
- clock, duplicate and split detectors
- plan mode chip cycles OC, CCR, and SCR
- dive quality context and builder
- SCR breathing mode reuses the validated CMF loop model
- assemble and provide buoyancy twin per dive
- findings repository with scan-apply semantics
- finding entity, deterministic ids, thresholds
- rates setup section and O2-narcotic toggle
- register qualityFindings entity for sync
- anchor detection and derived twin outputs
- edit ascent and descent rate in plan state
- per-sample buoyancy twin simulator
- plan ascent rate affects the computed schedule; wire descent rate
- quality_findings table, migration v118
- schedule policy descent rate and ascent-rate bands
- neoprene compression curve and drysuit gas budget
- gas mix density module for cylinder swing
- surface safety hub from planning and tools pages
- segment list reflects and drives chart selection
- drag, double-click, gas menu, and keyboard editing on the chart
- bridge equipment attributes into buoyancy traits
- attribute-derived prior ladder and per-type factor functions
- GearBuoyancyTraits attribute snapshot with panel parser
- replaceSegment mutation for chart splits
- pure edit controller for on-chart waypoint editing
- Mission Control three-pane layout, phone tab deck, header chips
- stat tiles, editor pane, and results pane
- plan setup accordion hosting decomposed settings sections
- setup sections extracted from the settings panel
- icon rail shell, full-width hub, drop 440px sidebar
- layout state providers and pane/tab l10n keys
- Dive Info, Access & Safety, Life & Notes sections on rows
- Identity and Location sections extracted onto rows
- conditions and weather on rows, profile row, section icons
- row-scale tanks, Gas & Gear overlines and unified actions
- SuggestionFormRow autocomplete row primitive
- EnumPickerRow bottom-sheet enum picker row
- row-shaped inline editing for FormRow.text; rating clear affordance
- FormOverline, FormAppendRow, FormEmptyRow primitives
- CNS method picker with provenance, source links, 11 locales
- FormSection v2 header-in-card chrome
- shared plan kit vocabulary, adopt in results sheet
- cut PlanCanvasPage over to PlanProfileChart, drop fl_chart chart
- PlanProfileChart widget with layered painters and scrub
- series painter with fill, ghost, mean depth, flags, stop tags
- backdrop painter with grid, axes, and ceiling no-go band
- respect CNS method setting in profile analysis and planners
- persist CNS calculation method per diver (schema v113)
- dash and label paint utilities for the plan chart
- thread CNS method through calculators, default Shearwater-style
- CnsCalculationMethod with three CNS rate algorithms
- collision-avoiding stop tag layouter
- pure chart geometry with hit-testing and tick logic
- theme-derived chart palette for the new plan chart
- add near-miss incident log (safety phase 4)
- add offline emergency card with bundled hotlines and chamber directory (safety phase 3)
- add bundled emergency numbers and chamber datasets with loader
- add no-fly countdown, safety hub, and altitude flag (safety phase 2)
- add no-fly guideline classifier service
- translate safety review strings into all locales
- localize pre-dive checklist strings across all locales
- equipment attributes in CSV export
- equipment attribute filter axis and dives-by-suit-thickness chart
- add safety review settings page with analyze-all action
- add pre-dive entry points to dashboard, tools, and trips
- add quiet safety findings badge to dive list
- add pre-dive section to dive detail and add-dive sheet
- attribute rows on the equipment detail page
- add safety review section to dive detail
- type-driven attribute form and custom fields editor
- auto-link pre-dive sessions to imported dives
- add pre-dive session runner, sessions list, and start sheet
- attribute-backed EquipmentItem with diff-save repository
- add safety review settings (master toggle and per-rule set)
- add pre-dive template editor
- add pre-dive checklist providers, routes, and templates page
- register safety review tables in sync serializer and streaming apply
- register pre-dive checklist entities for sync
- attribute labels in all 11 locales with resolver
- add safety findings repository, providers, and profile-write invalidation
- seed built-in pre-dive checklist templates
- add pre-dive session repository with immutability guards
- attribute catalog for all 18 equipment types
- add dive safety review tables and settings columns (schema v116)
- wire equipmentAttributes through serializer, merge order, and HLC registries
- add pre-dive template repository
- add pre-dive session engine and item composer
- equipment_attributes table + v115 migration with legacy column copy
- add sawtooth profile rule
- add pre-dive checklist domain entities
- add omitted safety stop rule
- add pre-dive checklist tables (schema v113)
- add missed deco stop and high surface GF rules
- add safety review engine with rapid ascent rule
- service ledger strings for all locales
- per-clock service reminders and trip nag
- pre-trip gear service alerts
- service due card and clock-aware alerts and badges
- manage service types page
- service clocks card on equipment detail
- service clock providers and trip alerts
- register serviceKinds and serviceSchedules entities
- service kind/schedule repositories, usage query, auto-attach, child tombstones
- add Perdix dive computer overlay to photo viewer (#168)
- ServiceDueEngine with date/dive/hour triggers
- service ledger domain entities
- schema v113 service ledger tables, seeds, backfill
- add DraggablePerdixOverlay drag and playback wrapper
- add PerdixFace dive computer display widget with l10n labels
- add PerdixFaceResolver for media playback readouts
- add Perdix overlay settings (enabled flag and position)
- active course progress card
- add/edit requirement and template picker sheets
- retirement fence -- cloud-wins rejoin preserving pending records
- requirements section on course detail page
- course requirement tracker strings for all locales
- retire idle devices with marker-first log deletion
- requirement progress and suggestion providers
- fleet-acked tombstone GC replaces the 90-day purge
- register courseRequirements and courseRequirementDives entities
- writer publishes ack map and heartbeats stale manifests
- reader ack tracking, retired-peer skip, manifest reporting
- course requirement repository with linking, templates, and tombstones
- liveness constants and fleet-acked tombstone horizon
- manifest appliedPeerHlc acknowledgment map
- course requirement starter template catalog
- retirement marker file name and model
- course requirement domain entities and progress roll-up
- v112 tombstone dedupe index + peer ack column
- add course_requirements and course_requirement_dives tables (v112)
- domain-neutral copy and translucent redesign for the setup wizard
- Shearwater Perdix 3 download support (V2 protocol)
- reuse retained key on re-enable; document per-artifact key semantics
- translate default & geofenced equipment set strings (#583)
- clear the default flag when the switch is turned off (#583)
- backup-encryption settings section + encrypted export
- backup-encryption enable + change-password dialogs
- localize all locales + sync/robustness fixes (#583)
- reencryptExistingBackups in-place migration
- silent restore via the stored backup key
- encrypt Save-to-File and Share exports when enabled
- encrypt local + cloud backups when backup encryption is on
- inject BackupEncryptionKeyStore + _activeBackupKey helper
- add BackupTarget.writeSource for pre-encrypted artifacts
- UI for default + geofenced sets (#583)
- apply default/geofenced set on download + file import (#583)
- repository, providers, and sync for default+geofenced sets (#583)
- schema, entities, and selector for default+geofenced sets (#583)
- add BackupEncryptionService (local key lifecycle)
- add BackupEncryptionKeyStore (backup-scoped key custody)
- add backupEncryptionEnabled preference flag
- rebuild Overview tab as interactive trip story (closes #166)
- assemble trip story view with scroll-linked map
- add pinned story map header with camera animator
- add trip story hero with planned-trip extras
- add trip story day chapter card
- add dive sparkline and day rhythm bar widgets
- add trip story strings in all locales
- add sparkline downsampling and day rhythm layout math
- add tripStoryProvider composing story sources
- multiple certifications per buddy via unified ownership (#553)
- add per-site diver history aggregates
- add batched getSightingsForDives query
- add buildTripStory composition function
- add trip story domain entities
- account-first cloud-provider resolution (completes the Phase-1 deviation)
- add pan (two-finger/trackpad) and discoverable zoom controls
- widen tissue compartment (Z) axis for readability and labels
- cross-device descriptors, hub, guided setup, network files (Phases 2-4)
- Lightroom rides connected accounts; retire connector_accounts
- sync selection persisted by connected account
- media store connect flows create and use accounts
- media store attach state and construction by account
- startup migration seeds accounts from legacy config
- Google Drive, iCloud, and Lightroom account adapters
- S3 and Dropbox account adapters with per-account keys
- capability interfaces and provider registry
- per-account keychain credentials store
- ConnectedAccountsRepository with sync pending marks
- register connectedAccounts in sync engine
- schema v107 connected_accounts table and sync_account_id
- AccountKind enum and ConnectedAccount entity
- label tissue axes with titles and tick values (time/%/compartment)
- show tissue axes, grid, and hover tooltip on the tissue scene
- wire tissue chrome and hover picking into the viewport
- add tissue frame and chrome painters
- add tissue hover tooltip widget
- add 3D tissue tooltip and saturation-state strings
- add nearest-vertex tissue surface picker
- add AxisFrame geometry for tissue axes and grid
- expose tissue surface grid and runtime providers
- emit TissueSurfaceGrid alongside the tissue mesh
- pair Details+Conditions and Buddies+Signatures side by side on wide panes
- CCR diluent resolution and loop gas-segment builder
- hold the CCR setpoint through TTS/schedule ascents for setpoint-bearing segments
- show dive mode in the Details card (#569)
- persist gauge dive mode on live download (#569)
- detect gauge mode on reparse and skip tank synthesis (#569)
- exclude gauge dives from gas statistics (#569)
- hide gas/deco detail sections for gauge dives (#569)
- hide tank controls in gauge mode edit form (#569)
- short-circuit gauge dives to profile-only analysis in providers (#569)
- add gauge dive mode with profile-only analysis (#569)
- add gauge dive mode strings (#569)
- remove the 3D View preview card from dive detail
- Compare in 3D from the detail source section + l10n backfill
- Compare in 3D action on the dives selection bar
- compare-dives page + route
- Computers comparison mode in the 3D view
- shared CompareProfile3dView (view owns the profile cap)
- optional time-plane scrub cursor
- compare readout (per-profile depth + delta)
- compare legend (focus + reference + max delta)
- previous/next buttons + arrow keys on dive detail
- DiveNavButtons previous/next widget + l10n
- orderedDiveIds + diveNeighbors providers
- getOrderedDiveIds query for adjacent-dive navigation
- multi-dive comparison adapter
- computer-source comparison adapter
- CompareGeometryService (side-by-side + overlay)
- reference-based DivergenceBuilder
- optional opacity on RibbonBuilder.build
- comparison profile primitives + resampler
- light scenes with directional shading and slim the ribbon
- retain scroll per trip and per liveaboard tab in detail pane
- retain scroll on dive/site/course/cert/center/equipment/buddy detail
- make tissue scene a 3D extrusion of the Subsurface heatmap
- make the tissue scene legible
- add spatial site seascape scene (Suunto-style topo)
- add career terrain scene (stacked dive history)
- add tissue saturation scene switcher, readout, and controls
- add tissue chain deriver and providers
- add tissue surface builder, geometry service, seam axis
- add tissue chain replay service
- add unit-aware depth grid planes
- add fullscreen 3D page with scrub and readout
- add interactive three_js scene viewport
- add three_js mesh adapter
- add 3D preview card to dive detail
- add software projector and preview painter
- add geometry service and scene providers
- add scene marker layout
- add scene data entity and profile lookup
- add deco ceiling surface builder
- add temperature strata mesh builder
- add ribbon and depth-curtain mesh builders
- add metric-to-color palette
- add MeshData and SceneBounds scene normalization
- add three_js dependencies and platform spike
- startup auto-poll trigger on the dive list page
- suggestion row with confirm and dismiss on dive detail
- scan actions on dive detail and trip overview, Open in Lightroom in viewer
- connect flow, settings page, route, and localized strings (11 locales)
- serviceConnector upload eligibility with thumb-only videos
- riverpod wiring, serviceConnector registry registration, auto-poll provider
- connector resolver fills the serviceConnector registry slot
- scan service - window merge, dedup, confident attach, suggestions, poll
- per-device connector scan state in SharedPreferences
- confidence-bearing timestamp matching on DivePhotoMatcher
- connector columns on pending suggestions + suggestion CRUD and remote-asset dedup queries (schema v104)
- connector accounts repository (first consumer of the v72 table)
- partner API client with abuse-guard stripping and pagination
- Adobe IMS OAuth2+PKCE auth manager
- secure auth store for BYO Adobe credentials
- gear and weights section with live weight prediction
- dated body weight history in diver profile
- advanced buoyancy and dry weight fields on gear edit
- weighting feedback capture on dive edit
- data-driven weight planner tool replacing static calculator
- calibration and prediction providers
- placement predictor with largest-remainder rounding
- hybrid weight prediction engine with calibration
- weighted ridge regression solver
- gear feature priors and physics terms
- batch weight history observations query
- plan equipment junction and planned weight snapshot
- weighting feedback fields on dives
- buoyancy and dry weight metadata fields
- dated body weight entries with sync + providers
- wire diver_weight_entries and dive_plan_equipment into changeset sync
- add three_js flythrough spike page behind debug menu
- schema v104 for weight prediction (feedback, buoyancy, weight entries, plan equipment)
- persist heading in download and reparse pipelines
- capture DC_SAMPLE_BEARING and serialize heading on all platforms
- carry heading through DiveProfilePoint and repositories
- add dive_profiles.heading column (schema v105)
- let first-run users change the sync backend after connecting
- include custom dive roles in UDDF full backup/restore
- dive roles management page under Settings
- my-role editing on dive edit page and detail display
- role selector with custom-role creation and Me chip
- persist the diver's own role on dives (#547)
- resolve per-dive buddy roles from dive_roles table
- sync dive_roles (custom rows only, tombstones, adopt-safe)
- dive role l10n strings and localized display
- DiveRole entity, repository, and providers
- add dive_roles table and dives.diver_role column (v103)
- agency-first certification fields with dependent level list (#546)
- filter level dropdown by selected agency (#546)
- add agency-specific certification levels and catalog (#546)
- phase 4 exit coverage
- provider chooser with dropbox, drive, icloud connect
- per-provider connect flows
- provider-typed attach state and runtime
- icloud media adapter over the ubiquity container
- google drive media adapter with resumable sessions
- dropbox media adapter with session resume
- dropbox session primitives and range download
- phase 3 exit coverage
- transfer progress bars
- store-backed video playback path
- video uploads with resume and progress wiring
- S3 multipart upload with resume and streamed download
- queue resume-state and progress persistence
- progress and resume hooks on MediaObjectStore
- phase 2 exit coverage
- backfill and transfer policy toggles
- per-tile transfer badges
- transfers view with retry
- thumbnail routing in store resolution
- thumbnail objects in the upload pipeline
- thumbnail generator
- network-aware worker gating and drain triggers
- observable transfer queue with retry and defer
- transfer policies and video eligibility gate
- route first run and settings entry to the setup wizard
- existing-data path with restore, sync pull, and folder adopt
- finish step applies draft and offers feature links
- backup schedule and cloud sync connection step
- appearance step with live language preview
- units step with locale-aware preset and fine-tuning
- wizard shell with fork and profile steps
- draft apply service with race-safe settings seeding
- phase 1 end-to-end coverage
- setup wizard draft notifier and preview locale provider
- setup wizard domain model and step computation
- connect flow, media storage settings page
- add setup wizard strings in all locales
- unlock banner, troubleshoot status, encrypted restore prompt (#520)
- store fallback resolution in MediaItemView
- upload pipeline, worker, enqueue-on-attach
- end-to-end encryption section with enable and manage flows (#520)
- content-addressed cache with LRU eviction
- credentials store and attach state
- S3 adapter and store identity marker
- MediaObjectStore interface, fake, and contract
- smv1 key derivation and streamed hashing
- local cache DB v2 with transfer queue
- media entity + repository upload stamps
- register .zxu/.zxl document types and document DiverLog migration
- register mediaStores in sync engine
- encrypted cloud backup upload, restore, plaintext cleanup (#520)
- show attached photo counts in import summary
- add v103 schema (media stamps + media_stores table)
- attach DiveCloud photos to imported dives
- expand ZIP archives at file intake
- framed self-decrypting .sbe backup encryption (#520)
- riverpod wiring for encryption session and provider wrap (#520)
- ZIP expansion service for DiveCloud archives
- wire DAN DL7 into detection, registry, and source apps
- encryption lifecycle service - enable, unlock, rotate slots, self-heal (#520)
- DAN DL7 parser with Aqualung ZAR enrichment
- awaitingPassphrase halt for encrypted libraries (#520)
- parse the DiverLog+ AQUALUNG ZAR dialect
- encrypting cloud storage decorator (#520)
- local key custody, keyslot mirror, encryption preference (#520)
- add DL7 unit conversions
- recovery code generation on the EFF short wordlist (#520)
- add DAN DL7 segment reader
- keyslot file with Argon2id passphrase/recovery wrapping (#520)
- SBE1 encrypted envelope with python-generated KAT vectors (#520)

### Bug Fixes

- guard the save flow against re-entry
- drop a stale site name when the site changes mid-lookup
- normalize inside DisplayZoomScope instead of trusting callers
- compute the plan summary after the naming flow
- surface unknown display-channel methods instead of no-opping
- snap zoom levels so 100% compares exactly
- lay the child out at the logical size, not the window size
- give the strict-close worker wait a checkpoint-sized budget
- honor the awaitWorkerShutdown contract on repeat calls
- make app-exit database close wait for the real SQLite close
- clear both library-epoch anchors so Repair cannot strand a device
- survive a page pop during a quality save
- fail closed when the iCloud container is unavailable
- make ensure() safe against a concurrent insert
- adapt to renamed media transfer summary API, UTC year range
- dedupe sites by name+coords, cap urgent banner, localize settings hub
- make the legacy S3 credential store injectable
- reuse the S3 account when the provider type flips
- stop minting a new account on every connect
- localize on-this-day minutes, de-flake anniversary test
- year hours rounding, indexed year query, stricter grid test
- make worker disposal stick across an in-flight drain
- stop reporting parked transfers as work in progress
- reduce hero banner padding
- smaller hero greeting, larger logo
- tighten hero right padding, enlarge quiet stats
- drop deepest stat from hero, shrink logo to 56px
- restore hero logo to right side at original size
- remove unbounded flex and intrinsic layout failures
- serve the compressed rendition when no original was uploaded
- a present-but-unreadable file verifies as transient, not orphaned
- probe readability, not just existence, for localFile resolve
- auto-verify bails without an active store descriptor
- bogus future fleet timestamp cannot suppress auto-verify
- drain sweep repairs before stamping the fleet timestamp
- private temp dir on Linux, thread pool on Windows
- check the remaining HRESULTs in HBitmapToPng
- refresh attach state on connect and disconnect
- move thumbnail-ready message off the colliding WM_APP + 1
- gate video poster generation to desktop platforms
- self-heal corrupt poster cache; move poster bytes on Windows
- session reaping is best-effort within the verify sweep
- qualify kThumbnailReadyMsg at its use inside the worker lambda
- treat a failed bookmark read as a null blob
- guard cache-dir failure, offload Windows extraction, doc accuracy
- include videos in upload backfill candidates
- use stream logical size when reading encoded PNG (Windows)
- enqueue Files-tab imports for upload
- format-agnostic poster cache extension, doc accuracy
- review round 2 on video thumbnail native handlers
- close first-part multipart leak and extension-variant orphans
- address review feedback on video thumbnail handlers
- hydrate media taken_at as wall-clock-UTC
- paint the ceiling line's shaded fill
- scope backfill candidates to dive- or site-linked media
- key the surface lead-in on each series' own profile (PR review)
- apply the t=0 readout to the inline tooltip and remaining curves
- describe t=0 in the readout instead of repeating the first sample
- compute pressure-based lead-ins, fix smoothing, cover mini charts
- extend every profile curve back to t=0, not just depth
- draw the depth trace from the surface at t=0 (#684)
- treat blank itinerary port and notes as absent
- address review on retry gating and exact-second matching
- self-sizing sticky day header for scaled text
- resolve gallery assets by exact capture second
- restore undo summary from persisted row, not in-memory outcome
- delete targets route planId, closing load-window race
- sweep stranded temp files on no-op restore + a11y label (PR review)
- don't let post-swap cleanup abort a succeeded restore (PR review)
- skip summaries watch on :planId route; SnackBar persist:false (#406)
- clear errorMessage when reclaiming a stranded row (PR review)
- read (not watch) repo in reclaim provider (PR review)
- navigate off dead route when plan already gone; pin test locale
- make the restore test seam one-shot and reset-safe (PR review)
- await transfer reclaim before wiring drains (PR review)
- keep the database open during large-DB restore so pages don't red-screen
- run transfer reclaim once per process, not per drain (PR review)
- recover orphaned 'transferring' uploads on drain
- stop master-pane selection toolbar from overflowing
- never leave a Windows .tmp on failure + quiesce dispatcher on teardown (PR review)
- Windows probe bitrate fallback, headless progress drop, test asserts (PR review)
- marshal Windows progress to platform thread + guard dimensions/root path (PR review)
- read source height off main thread in Android transcode (PR review)
- probe off main thread + drop redundant manifest package (PR review)
- harden Android Media3 error paths (PR review)
- share one progress stream across engine instances
- pin AVF reader PCM to the AAC encoder rate/channels
- clean up temp on all AVF failure paths; nullglob CI loop
- use readerFailed case + sync ios Podfile.lock (PR review)
- treat a gas change at the first sample as the initial gas (#679)
- Apple finalize/concurrency/error-message (PR review)
- unique progressIds + NaN-safe Apple probe (PR review)
- convert rename failure to TranscodeException (PR review)
- derive bitrate on N/A ffprobe + sync error-handling spec
- harden Apple AVFoundation engine (PR review)
- force mp4 muxer + auto-dispose availability check (review)
- sweep stranded transcode on original upload + doc fixes (review)
- record stored rendition size on dedup (PR review)
- fall back to original on TranscodeException (PR review)
- gallery ceiling rule + deterministic label tests (PR review)
- harden upload pipeline + rendition cache (PR review)
- guard dive_id column in the v132 bottom-time backfill
- truly exit compare mode when plans drop below two
- stop storing bottom time equal to runtime
- open saved plan with a single back press
- refresh safety review after sync and analyze-all
- deterministic tie-break for the Service Due sort
- guard ref use after await in the sync-pull gate
- cancel the auto-sync debounce timer on reset
- invalidate service urgency provider on schedule writes
- run disableForDatabaseReset guards independently
- guard v4 overrideLevel migration against v1 full-create path
- configure interval when adding a no-default service clock
- show enabled but unconfigured service clocks
- stop restored/reset data from vanishing under cloud sync
- keep @DriftDatabase on AppDatabase; detect edited legacy dives
- give the synthesized source the deterministic backfill id
- render 3D/spatial/compare for dives missing a data-source row
- enable encrypted sync on secondary devices after unlock
- translate built-in dive type names (#643)
- use AMV instead of SAC in the German UI (#640)
- prefilter withProfiles to primary samples only
- route detail-chip count through l10n
- hydrate detector toggles at startup
- dedupe dive headers + localize last-scan time
- address round-3 review comments
- stop the upload-pipeline test leaking async work past teardown
- address round-2 review comments
- localize the Safety section title on the mobile tile
- store/show incident occurredAt as wall-clock UTC
- guard user numeric attributes for finiteness
- droppable lead from placement in the through-dive twin
- sanitize BCD lift capacity before the bladder term
- address PR review comments and raise test coverage
- guard haversine NaN and stop the ticker on no-fly expiry
- localized geocoded countries, ISO country field, comment accuracy
- tighten attribute-prior edge cases from PR review
- drop dead safetyHub_* hub-link keys stranded by the merge
- address PR #635 review on the stale-bond repair
- mark edit form initialized after populating controllers
- address PR #611 review round 2 on the incident edit form
- gate runner overflow menu by strict-order actionability
- compute plan droppable lead from per-WeightType placement
- self-heal stale BLE bonds on the connect path (#621)
- suppress same-suit history strip for a suitless dive
- hide alerts banner when no renderable alert
- drop redundant chamber call menu item; align docs to v126
- use double bounds for clamp to avoid int-return crash
- self-invalidate no-fly status at expiry (Copilot review)
- treat non-positive wing lift capacity as null
- address PR #611 review — incident edit robustness, sync test coverage, route docs
- localize the unnamed-tank breakdown label
- address Copilot round-4 review (emergency card / dashboard)
- skip zero-duration plan segments in synthesizePlanProfile
- scope dive-summary lookups to the active diver (round 3)
- localize overdue-service note; pin test locales
- address Copilot round-2 review on emergency card
- pin compass reset animation to its original controller
- avoid duplicate timestamp in 5 m square profile; pin test locales
- sample the clock once in the no-fly alert text
- renumber no-fly migration v124 -> v125 after main collision
- address Copilot round 3 + raise no-fly patch coverage
- address Copilot follow-up on no-fly (round 2)
- address Copilot review on no-fly hub
- seed compass rotation on mount/swap; fix map test l10n
- date-attr picker caps at today; fix number-format test
- address Copilot follow-up review round 2 on PR #608
- address Copilot review on emergency card
- keep custom fields colliding with curated keys in CSV
- handle disposal mid-reset; harden compass test
- restrict suit-thickness filter to exposure suits
- address Copilot follow-up review on PR #608
- align dive-list badge with per-rule disables
- address Copilot review on PR #608
- translate Environment section/subsection headers (#622)
- localize weather and dive-condition enum values (#622)
- make junction authoritative for buddy/DM columns
- translate weather field titles for issue #622
- address round-6 Copilot review comments
- show junction buddies in table Buddy/Dive Master columns
- address copilot follow-up review round 3
- address copilot follow-up review round 2
- address copilot follow-up review
- saveReview bumps parent dive HLC so reviews sync
- reactivity, batched applyTemplate, atomic deleteCourse
- correct chart tooltip index; debounce twin re-simulation
- resolve relative next-page href against the request URI
- clamp stop tags to vertical bounds
- stop catalog scan per-page, not on first past-end asset
- unit-aware rate sliders; consume unavailable setup focus
- validate RecreationalNdlSolver args, fail fast on misuse
- drop pending pSCR edit on invalid input; fix provider doc
- repaint charts on style/textDirection change; pin test locale
- query captured_after so oldest-first scans reach in-window assets
- format ccr_ui_test + clarify geometry/pSCR docstrings
- make the connector-video play button semantically actionable
- make the Open-in-Lightroom launchUrl calls explicitly fire-and-forget
- address round-4 review comments
- address PR #617 review comments
- hydrate history/plan twins correctly; hu typo
- address service-ledger PR review batch 3
- address service-ledger PR review comments
- rapid-ascent rule uses fixed design thresholds
- address second-round PR #612 review comments
- address round-3 review comments
- address round-2 review comments
- address PR #617 review comments
- address PR #612 review comments
- ensureDeletionLogIndex only dedupes on real duplicates
- connector videos show poster + Open in Lightroom instead of failing local playback
- tolerant asset parsing - a list where a scalar was expected crashed the whole scan
- scan uses a single capture cursor (captured_after/before are mutually exclusive) + surface API error body
- dedupe 'Go to dive' in finding cards (footer + repair action)
- address Copilot review on attribute thickness/number fields
- move Dives review entry into the overflow menu (all app-bar variants)
- move Data quality entry under Settings > Data (was Unknown section on wide layout)
- smooth depth into the suit term to de-noise the curve
- hydrate typed weights and equipment for the twin
- label the net-buoyancy chart axes
- autoDispose badge providers, stub in test base overrides
- add no-fly to wide planning sidebar and correct stale incident routes
- setup accordion PageStorage bool collided with TextField scroll restore
- editor pane always visible on desktop, drop drawer, compact segment tiles
- suppress time tick labels that collide with the axis unit label
- merge safety review rows in sync apply and harden disabled-rules decode
- renumber pre-dive checklist migration to v117 (ladder collision)
- PRAGMA-guard v115 legacy copy for minimal old-schema databases
- account for seeded built-ins in template repository tests
- bump dive detail section count expectations to 19
- GC exempts only durably fenced peers; spec marker semantics
- address PR review - distinct item counts, diver-scoped custom kinds, pinned test locales
- defer Perdix overlay controller-removal rebuild past tree finalization
- renumber service ledger migration v113 to v115 (open PR claims)
- make v113 backstop self-guarding for partial fixture databases
- package imports, settings mock stubs, mini profile header overflow guard
- drop deleted hw_frog.c from platform build source lists
- prompt for passphrase when restoring encrypted backup in setup wizard
- stop encrypted-restore passphrase dialog from over-popping the navigator
- create temp dir before restoring on fresh installs
- carry exit GPS through ImportedDiveConverter for #586
- second review pass on #586
- address #587 re-review (round 5) - error-path hardening
- trip-story review round 15 (6 comments)
- address #587 re-review (round 4)
- address #587 re-review (round 3)
- address #586 review + raise patch coverage to ~92%
- address #587 re-review (round 2)
- correct liveaboard port day-index + bound media concurrency (PR review round 14)
- address #587 review feedback
- address trip-story review round 13 (16 comments)
- clamp rhythm-bar track height so it never goes negative (PR review round 12)
- extend story day span to cover out-of-range itinerary days (PR review round 11)
- only draw the story route polyline with 2+ points (PR review round 10)
- best-effort media/sightings + pin-tap camera (PR review round 9)
- gate cert commit on a dirty flag + localize detail error (#553 review)
- assert CertificationEditPage mode contract (#553 review)
- dismiss scan loading dialogs via captured navigator (PR review round 7)
- inject CertificationRepository into _importBuddies (#553 CI)
- address PR re-review (round 6) for #553
- preserve staged cert updatedAt on unchanged Save (#553 review)
- address PR review round 5 (effectiveEntryTime, scroll threshold, vessel overflow)
- address PR re-review (round 4) for #553
- address PR review round 4 (active-day fallback, species merge key)
- drive S3 _save provider work through the app container so a mid-save pop can't crash on ref-after-dispose or skip the global refresh
- address PR re-review (round 3) for #553
- address PR review round 3 (reactivity, painter/delegate equality)
- gate account-first resolution on settled account so a credential-edit reload uses the legacy singleton, not a stale per-account key
- address PR re-review for #553
- clamp hover tooltip using its real measured size
- address PR review for #553
- run global sync-state refresh before S3 re-derivation await so a mid-save pop can't leave dependent screens stale
- mounted guards after account-derivation awaits; mirror failure falls back to legacy resolution
- guard AxisFrame divisions against 0; make wireframe step int explicit
- best-effort legacy Dropbox key clear on sign-out (never abort sign-out on keychain error)
- remove unused import in trip story view
- disconnect clears both credential locations (bidirectional mirror + legacy clear on Dropbox sign-out)
- re-track hover tooltip on camera changes; drop dead compartments branch
- align tissue provider nullability with builder; validate picker arrays
- guard account-first resolution against a stale account of the wrong kind during the provider-type transition
- anchor tissue Y tick labels from sceneMinY to match tick geometry
- restrict tissue-pick depth tie-break to exact screen-point overlap
- per-axis tick colors + localized zoom button tooltips
- wire accountCredentialsStoreProvider into the S3 adapter so test overrides reach it
- pan-aware tooltip screenPos + stop trackpad pan from rotating
- async volume-mount probe so an offline share can't block the UI isolate
- second device with synced account but no local creds can sign in (gate on device status, reuse roster row)
- address PR review — cache invalidation, repaint keys, bounds guards, RTL, picker perf
- review - break core->presentation cycle, refresh Dropbox blob on connect, sync-tick on account selection, checked Lightroom adapter
- migration retries reuse persisted account ids (no duplicates, no misassignment)
- disconnect through the adapter so the cached manager is evicted
- review round 2 - updatedAt semantics, adopted-row pending marks, connectS3 kind guard
- review findings - deletion tombstones, manager-backed disconnects, sync-S3 never adopts media-S3
- startup rekey reads adopted roster; selection bookkeeping best-effort
- career terrain has no scrub cursor (drop inherited ScrubPath)
- cover DiveMode.gauge in the CCR segment switch after rebase
- analyze CCR dives with loop gas segments in both analysis paths (issue #455)
- run CCR dives through the gas-segment deco path (issue #455)
- immutable DiveIdSet family key + scrub-bar play/pause tooltip
- gauge analysis honors user ascent-rate settings; explicit freedive mapping (#569)
- keep real reported tank records for gauge downloads (#569)
- address second-round PR #565 review comments
- stable source partition in compare adapter; dispose test notifier
- address PR #565 review comments
- correct horizontal drag-rotation direction
- respect unit preferences for height in body weight entry
- replace fragile PageStorage retention with deferred-restore retainer
- override flutter_angle with Flutter 3.44 embedder fix fork
- pickFirst duplicate libc++_shared.so from flutter_angle
- package import in auth store
- restore libdivecomputer submodule pointer to main's pinned commit
- align empty state with dive list (log-first-dive + add-dive sheet)
- symlink macOS Pigeon output to iOS copy to prevent staleness
- correct finish-screen feature routes (/gear->/equipment, /stats->/statistics)
- advance libdivecomputer submodule to match main (Perdix 3 descriptor)
- address PR #548 re-review comments (#520)
- sync-error state handling + surface iCloud-unavailable message
- temp-dir safety, client lifecycle, preflight and queue hardening
- thumb-first resolution, gallery-only passthrough, staging cleanup
- harden resume parsing, clear stale errors, forward content type
- recognize the Shearwater Perdix 3 during BLE scanning
- carry entry/exit GPS onto the target when folding dives (#542)
- handle pull failures in the sync-connect step
- address PR #548 review + raise patch coverage to 97% (#520)
- create the sync temp dir before writing (macOS #554)
- address PR review — settings re-entry backup state, cloud-backup toggle, PageController resync
- mirror effectiveRuntime edge cases and fully order site query
- deterministic tie-breakers for personal-record queries
- row-safe WAL checkpoint + honest hydration benchmark timing
- trim terms, accurate limit notice, and cleaner layering
- S3 redirect bounce, back navigation, drop appearance step
- use sandbox-safe temp dir and tidy empty-archive extraction
- clean up ZIP temp dirs and stale photo state

### Refactoring

- make the iCloud platform seam a single enum
- remove quality from device-local policies
- read upload quality from the synced policy
- seed the migration at deterministic ids
- address review feedback on the localFile readability fix
- address third PR 705 review pass
- address second PR 705 review pass
- address PR 705 review feedback
- address PR 704 review feedback
- extract shared backup-status predicate
- drop redundant story dive sparkline
- return stderr from the process-runner contract (review)
- generalize DarwinAvfEngine to ChannelTranscodeEngine (shared by Apple+Android)
- drop redundant clock invalidation on configure-tap
- batch enrichment backfill; complete parent-refs coverage
- log+rethrow in getDiverCount; keep reset stack trace
- schedule override dialog takes schedule + kind
- centralize the legacy data-source id format
- thread the dive-type resolver into the list tiles
- drop unused ref param from showStartSessionSheet
- address review on compass control
- address PR review — rename flag, fix docs, redirect route
- await repository writes in requirement_tile callbacks
- localize picker tab labels; pin en locale in media-sources/picker tests (PR #619 review)
- consolidate photo sources under Photo library & sources; retire hidden-picker-tabs toggle
- dissolve safety hub into planning, settings, and profile surfaces
- dive planner hub row is a normal clickable tool tile
- drop icon rail and shell - tools render full-bleed
- retire hero slot and stale chrome tokens
- centralize wizard surface alphas; add branch-step hug test
- scope buddies watch to the pair, self-contained signatures diveId
- memoize derived CCR loop ascent plan; guard fixture minute-40 lookup
- drop unused CompareProfile3dView.title param
- wrap shortcuts at _buildContent call site to shrink diff
- career terrain delegates to CompareGeometryService
- generalize renderable to scene-agnostic Scene3d
- replace three_js engine with interactive CustomPainter viewport
- promote PKCE helpers from dropbox to shared core/services/oauth
- drop @visibleForTesting on prod helper; de-dupe dive-plan index DDL
- move wizard step primitives to lib/shared/widgets/wizard

### Performance

- persist the slider on release instead of every notch
- cascade reuses the rows it already read; guard empty partition
- evaluate chosen-set clocks in parallel
- evaluate active clocks once; watch urgency only when needed
- scope pre-push tests to files changed in the push
- count divers instead of loading all for the restore gate
- run data-source backfill after the performance-index heal
- index equipment attributes once in gearFeatureFor
- reuse the fence check's folder listing for the pull
- stable onDaySelected identity so the map header doesn't rebuild each frame (PR review round 8)
- split tissue chrome into static + dynamic overlay painters
- re-project only the picked vertex on camera change
- hoist nullable-depth cast out of the frame-rate readout builder
- commit _currentDatabasePath only after verified open (WS5 review 5)
- evaluate effective-runtime subquery once for longest dive
- strict close in reinitializeAtPath verify-fail path (WS5 review 4)
- strict close keeps connection ref on failure (WS5 review 3)
- apply strict close to all reopen-after-close paths (WS5 review 2)
- strict close on reopen paths + reset lastOpenMode (WS5 review 2)
- single version read + fail-fast migrator close (WS5 review)
- deterministic bounded ordering + empty-query guard
- execute SQLite off the UI isolate (WS5)
- SQL-bounded home providers, no hot-path getAllDives (WS4)
- decimate analysis curves and scope the series cache (WS3)
- lean hydration for the analysis lookback path (WS2)
- bounded DiveSummary search hydration (WS1)
- bracket ready-to-first-frame timing; attribute debug startup freeze to JIT + getAllDives
- checkpoint WAL after heal; startup step timing; re-baseline findings
- self-heal performance indexes in beforeOpen
- vmcap VM-service profiler tool and measurement runbook
- canonical index list, db_bench tool, WS0 SQL baseline

### Documentation

- document recently merged PRs in v1.7.0 release notes
- sync the zoom spec and plan with the implemented API
- correct the display zoom ARB key list
- record the OverflowBox constraint fix
- update _openDatabase comment for BackgroundDatabaseConnection
- implementation plan for naming a saved dive plan
- implementation plan for app-wide display zoom
- design for naming a saved dive plan
- design for app-wide display zoom
- plan synced media upload quality
- spec synced media upload quality
- add connected accounts deduplication implementation plan
- add connected accounts deduplication design
- add dark deep splash and hero implementation plan
- add dark deep splash and hero background design
- add Home page redesign implementation plan
- add Home page redesign design spec
- add v1.7.0 release notes
- drop the 'See it in action' section heading
- tighten and lighten the header subtitle
- put logo and title on the same line in the header
- put logo and title on the same line in the header
- simplify header and move downloads to dedicated section
- correct the upload-pipeline scope claim in the design spec
- implementation plan for local-media upload badge
- design for local-media auto-upload and not-backed-up badge
- implementation plan for orphan prevention PR 4 (Verify Library)
- resolve orphan-predicate verification gate; PR 3 plan (cascade + backlog sweep)
- correct toWallClockUtc reference in comments
- implementation plan for local-file video thumbnails
- implementation plan for orphan prevention PR 2 (blob delete fast path)
- design spec for local-file video thumbnails
- implementation plan for orphan prevention PR 1 (backfill scoping)
- design spec for media store orphan prevention
- implementation plan for trip story scroll polish
- design spec for trip story scroll polish
- implementation plan for deleting a dive plan from the canvas
- point requeueStale doc at its once-per-process caller
- add Code of Conduct and Contributing guide
- design for deleting a dive plan from the canvas
- correct stale v130 refs to v133 for compressed-rendition columns
- design and implementation plan for the deco stop band
- implementation plan for video transcoding Phase B4 (Windows MediaTranscoder)
- implementation plan for video transcoding Phase B3 (Android Media3)
- implementation plan for video transcoding Phase B2 (Apple AVFoundation)
- implementation plan for video transcoding Phase B1
- design spec for video transcoding (upload quality Phase B)
- reference hasAnyDiversProvider.future in the restore-gate comment
- implementation plan for equipment service clock unification
- correct spec GC scope (general sweep unbuilt; Phase A does targeted delete only)
- Phase A implementation plan for adjustable media upload quality
- spec for unifying equipment service on clocks + add-timer fix
- media_enrichment sync implementation plan
- design spec for adjustable media upload quality
- add phase 2 no-fly countdown implementation plan
- implementation plan for water type from dive site (#624)
- design spec for water type from dive site (#624)
- clarify paging fake models ordering/pagination, not null-capture assets
- reconcile design + plan to shipped schema v114
- Lightroom Native App embedded-connect implementation plan (Plan 2)
- Lightroom approval walkthrough page + resubmission email drafts
- Lightroom Native App auth core implementation plan (Plan 1)
- Lightroom connect via OAuth Native App design (unified BYO + embedded)
- phase 5 implementation plan - SCR breathing mode (validated slice)
- phase 4 implementation plan - rates and gas options (no-schema slice)
- data quality assistant plan 2 (repairs and inbox UI)
- buoyancy digital twin implementation plan
- data quality assistant plan 1 (data and detection engine)
- buoyancy digital twin design
- weight planner attribute-informed priors implementation plan
- phase 3 implementation plan - on-chart editing
- attribute-informed buoyancy priors for the weight planner
- data quality assistant design spec
- phase 2 implementation plan - Mission Control layout
- changelog entry for configurable CNS calculation method
- edit form chrome redesign implementation plan
- CNS calculation method spec and implementation plan (issue #578)
- phase 1 implementation plan - chart + design system
- edit form chrome redesign design freeze
- planner UI redesign + Subsurface parity design spec
- mark safety features spec implemented
- add phase 4 near-miss log implementation plan
- add phase 3 emergency card implementation plan
- add phase 2 no-fly countdown implementation plan
- correct logDeletion comment to reference the v113 index
- correct Perdix overlay hit-testing comment
- renumber safety review schema claim to v116 (v115 taken by PR #602)
- add pre-dive checklist implementation plan
- add phase 1 implementation plan for post-dive safety review
- equipment attributes implementation plan (10 tasks); align spec with backup/date ground truth
- gear service ledger implementation plan
- implementation plan for Perdix video overlay (#168)
- add safety features design spec (review, no-fly, emergency card, near-miss)
- add pre-dive checklist feature design spec
- design spec for Perdix-style media playback overlay (#168)
- gear service ledger design spec
- equipment type-specific attributes design
- mark tombstone GC spec implemented
- add course requirement tracker implementation plan
- implementation plan for fleet-acked tombstone GC and device retirement
- add course requirement tracker design spec
- design spec for fleet-acked tombstone GC and device retirement
- add PR artifact links design spec and implementation plan
- implementation plan for default & geofenced equipment sets (#583)
- spec for default & geofenced equipment sets (#583)
- implementation plan for app-wide encrypted backups (#580)
- design spec for app-wide encrypted backups (#580)
- record trip story implementation deviations
- add trip story implementation plan
- add trip story design spec (issue #166 + interactive breakdown)
- correct stale no-on-canvas-text claims (axis_frame + plan)
- record post-review revisions (labels, Z width, pan/zoom, review fixes)
- spec and plan for tissue axes, grid, and tooltips
- clarify ascentGasPlan null behavior for setpoint-bearing segments
- add CCR loop-aware deco/TTS implementation plan (issue #455)
- connected accounts phase 1 implementation plan
- media linking and storage program design spec
- correct gauge plan l10n to 11 locales (add zh) (#569)
- add gauge dive mode implementation plan (#569)
- add gauge dive mode design spec (#569)
- implementation plan for previous/next navigation
- implementation plan for 3D profile comparison
- design for previous/next adjacent-dive navigation
- design spec for 3D profile comparison (dives + computers)
- record retainer revision superseding PageStorageKey approach
- implementation plan for detail pane scroll retention
- drop redundant scaffold bucket after spike; keys alone suffice
- design for detail pane scroll retention
- add tissue saturation 3D scene design spec
- add Terms of Use for third-party API integrations
- drop three_js from 3D flythrough spec and PR 2 plan (CustomPainter reversal)
- add 3D flythrough PR 2 plan and spec addendum
- mark 3D flythrough PR 1 plan progress (PR #563)
- Lightroom auto-linking implementation plan + spec corrections from code exploration
- add dive 3D view implementation plan
- add 3D flythrough PR 1 implementation plan; fix TTS storage note in spec
- add Lightroom cloud auto-linking design spec
- add dive 3D view design spec
- add 3D dive flythrough design spec
- add weight prediction implementation plan
- add weight prediction design spec
- v1.6.1.115 release notes for encrypted cloud sync (#520)
- forbid Claude Code attribution and session URL in PR descriptions
- dive roles implementation plan (11 tasks, v103)
- agency-dependent certification levels implementation plan (#546)
- dive roles design spec (custom roles #551, own role #547)
- agency-dependent certification levels design (#546)
- media store phase 4 implementation plan
- media store phase 3 implementation plan
- reword temp-dir test comment (Copilot review #555)
- media store phase 2 implementation plan
- select main isolate; require-arg usage syntax
- explain getMergedProfile is intentionally unfiltered for parity
- split provider doc comments after analysisDiveProvider insert
- describe the setup wizard first-run flow
- setup wizard implementation plan
- media store phase 1 implementation plan
- setup wizard for new databases (discussion #523) design spec
- DiverLog+ / DAN DL7 import implementation plan
- encrypted cloud sync implementation plan + cryptography deps (#520)
- media store (cloud media storage backend) design spec
- encrypted cloud sync (E2E) design spec (#520)
- DiverLog+ / DAN DL7 import design spec
- WS0 in-app verification on the live database

### Tests

- pin Intl.defaultLocale in the plan name generator tests
- await the stalled close and drop the unreliable WAL assertion
- drive the container lookup through an injected seam
- assert upload quality keys are not device-local
- cover the managed-kind anchor and the startup guarantee
- pin locale to en in widget-test harnesses
- cover recentPhotosProvider and gear tie-break branches
- cover Home appearance entry in both settings twins
- cover chips, cards, providers and review fixes
- exercise the bookmark branch on every host, not just Apple
- raise PR 705 patch coverage to 90%
- name the library-level orphan fixtures for their source type
- dive-deleted media contract - cascade for dive-only, unlink for library
- compressed backfill exclusion tests the stamp, not linkage
- link backfill service fixtures to a dive
- cover the t=0 lead-in paths flagged by Codecov
- cover the resolution tier ladder and stale-cache clearing
- pin Intl.defaultLocale in day header tests
- cover Darwin progress routing/clamp/cancel (PR review)
- cover initial-gas detection across sample intervals
- Windows MediaTranscoder integration test
- Android Media3 integration test + fix darwin test rename
- macOS AVFoundation integration test (ffmpeg-synthesized input)
- real-ffmpeg smoke test with synthesized fixture
- pin en locale and close the DB in teardown for the new tests
- also cover the reset sync-disable failure path
- cover disableForDatabaseReset, reset gate, and getDiverCount error
- relax v129 tripwire; v130 owns the exact-latest schema assertion
- end-to-end compressed photo upload + cross-device read
- mock SharedPreferences in end-to-end test (pipeline reads quality policy)
- const MaterialApp in service clocks card test (lint)
- stub per-dive findings badge stream in shared overrides
- pin gloves/boots strength in the no-attributes regression
- raise near-miss patch coverage to ~93% + localize list error
- prove GearBuoyancyTraits equality is by list content
- reconcile dive-detail section count to 20 after merge
- add emergency_chambers to parentRefs completeness guard
- fix v125 schema tripwire and raise emergency-card patch coverage
- restore exact-latest schema-version tripwire in the v119 test
- raise patch coverage to ~93%
- cover v124 no-fly migration and exact-latest tripwire
- make CSV export fixture const (--fatal-infos)
- pin en locale in chart and what-if widget tests
- compare enum localization against getters, not literals
- raise PR #608 patch coverage above 90%
- cover course requirement tables in parentRefs completeness guard
- direct ConnectorVideoItem test (fix CI coverage collection)
- restore FlutterWebAuth2Platform.instance after the redirect-capture test (PR #617 review)
- raise patch coverage above 90%
- cover embedded dive->site navigation paths
- raise patch coverage on the native-app connect diff
- assert renamed Database Cloud Sync app bar title
- relax the v112 exact-latest tripwire to gte
- pin en locale in settings-page widget test (PR #617 review)
- align Perdix overlay position mocks with production clamping
- disable ambient scan scheduler globally in tests
- move exact-latest schema tripwire to the v120 migration test
- VPM-B golden vectors + generator (bwaite/vpmb BSD-2 reference)
- remove unused import in sync test
- twin agrees with static engine at the weighting convention
- engine-level attribute-prior behavior coverage
- adapt site/dive edit suites to v2 header-in-card chrome
- macOS-gated golden images for the plan chart
- cross-validate CNS methods against issue #578 references
- raise service ledger patch coverage past 90 percent
- update section count assertions for safety review section
- pin en locale in Perdix overlay widget tests
- usage-sample dedup and trip reminder coverage
- address #588 review
- raise #587 patch coverage to ~97% and harden per review
- taller viewport so the new encryption section doesn't push history off-screen
- raise trip story patch coverage to ~91%
- cover Dropbox sign-out catch, connect-flow account refresh, and matching-kind fallback (patch coverage 73%->93%)
- address PR review — pin en locale, closeTo, drop unused dayDate
- tolerant dy compare in ResponsiveSectionPair row test
- pin CCR fixture TTS against Subsurface (issue #455)
- reparse gauge maps to gauge; unknown mode uses unrecognized string (#569)
- raise patch coverage - getOrderedDiveIds filter/diverId branches, dive-detail nav navigation
- lock in detail-pane scroll retention contract
- exclude GL viewport from coverage (device-matrix verified)
- raise patch coverage for geometry service, providers, and page
- raise patch coverage - settings page suite, dialog error paths, viewer action, entity equality, auto-poll failure
- raise patch coverage for the weight prediction feature
- raise patch coverage across adapters, page, and providers
- raise patch coverage for the dive roles feature
- cover merge-mode certification cycling; make catalog abstract final (#546)
- raise WS5 patch coverage to ~94%
- raise patch coverage to 90%+ for the wizard
- clarify newer-than-app test rejects before any Drift open
- cover diver-scoped records and the SQL count providers
- cover zoomed decimation, dense overlays, and MOD line (WS3)
- cover startup step timing; scope coverage to real logic
- cover search provider and DiveSearchDelegate
- DL7 end-to-end batch integration coverage
- no-plaintext-leak invariant and encrypted two-device convergence (#520)
- update restore-service doubles for the encryptionSecret parameter (#520)
- env-gated real-sample regression suite for DL7
- query-plan regression tests for performance indexes

### CI/CD

- run each integration test file in its own flutter test invocation
- bound the macOS integration-test job to 25 min
- scan only PR/push commits for the override marker (two-dot log)
- clarify that the inert-path case globs match nested paths
- add an escape hatch to force the full pipeline
- skip test/build jobs when a change touches no Dart
- shard tests 4->8 to roughly halve test wall-clock
- bump actions/download-artifact from 4 to 8
- bump actions/github-script from 7 to 9
- bump actions/setup-python from 6 to 7
- install libwebkit2gtk-4.1-dev for the Linux build
- TEMPORARY debug job to isolate photo_viewer coverage collection
- connector-video line diagnostic + standard lcov field order
- merge shard coverage into one Codecov upload (fix zeroed patch coverage)
- install libwebkit2gtk-4.1-dev for the Linux build
- make PR-target binding merge-commit-safe; use GITHUB_SERVER_URL
- harden artifact-links per review
- address review on artifact-links
- add PR comment with build artifact download links
- upload testable build artifacts and PR number on pull requests
- wait for all coverage uploads before status
- enable git long paths on Windows for the flutter_angle git dependency
- install CMake 3.31.4 in Android build for flutter_angle

### Chores

- register submersion_transcoder plugin (pod install)
- format engine + commit pubspec.lock for submersion_transcoder dep
- temporary [LR-SCAN] diagnostics for the empty-scan investigation
- lock flutter_web_auth_2 pods
- register embedded Adobe redirect scheme (iOS/Android/macOS)
- regenerate plugin registrants for flutter_web_auth_2
- post-implementation sweep
- bump CocoaPods lockfile stamp to 1.17.0
- preserve error+stackTrace when logging swallowed sign-out and account-derivation failures
- drop unused import
- delete orphaned Dive3dPreviewCard widget + test
- add 3D comparison strings (English; locales pending)
- regenerate macOS Podfile.lock after flutter_angle removal
- register flutter_angle in platform plugin registrants
- regenerate plugin registrant for cryptography_flutter (#548)
- finalization sweep, plan checklist complete
- verification fixes for setup wizard

### Other

- i18n(zoom): translate display size strings into all locales
- i18n(planner): add plan name dialog title and fallback label
- Revert "docs(readme): put logo and title on the same line in the header"
- delete release nots
- format the dive-deleted media sync contract test
- format PR 3 tests
- format new delete fast path tests
- format backfill scope test
- register transcoder plugin in generated registrant
- Apply suggestions from code review
- backtick angle-bracket paths in transcode doc comment
- docs+perf: renumber spec/plan to v131; pre-dive evaluates only chosen set
- Bound the HEIC meta box read (PR review)
- Guard HEIC extent read + add iloc v2 coverage (PR review)
- Harden HEIC parser against malformed input (PR review)
- Read HEIC/HEIF capture time on desktop
- format media_repository_compressed_test
- Address PR review r2: harden mvhd version + accurate decode-error tile
- Address PR review: dispose guard + explicit icon centering
- Match photos and videos to dives by capture time on desktop
- Address sync review feedback
- Remove internal continuity notes from PR
- Add sync investigation continuity notes
- Make epoch filtering strict and report skipped peers
- Fix sync of legacy peers after epoch adoption
- dart format the built-in reference-data contract test
- const the infinite-lift traits to satisfy analyze
- dart format safety settings test
- test/docs: address copilot follow-up review round 4
- drop the shard-coverage-merge experiment
- clear stale completedAt on dive edit; make once-per-course link atomic
- fixes based on github copilot suggestions and fixes.
- Potential fix for pull request finding
- fix missing import for settings_providers
- fix linting warnings and undefined identifiers in dive log and site navigation tests
- Potential fix for pull request finding
- Created a comprehensive test suite for the newly implemented nested navigation and embedded site details in the dive log.
- wall-clock-as-UTC dive dates and once-per-course link invariant
- cover the totalCount==0 dashboard filter with an in-progress course
- Enhanced Dive Log to Site Navigation
- address PR #601 feedback
- null-aware element in dive label
- Add support for wetsuit thickness parsing in weight planner
- Updated formatting with dart format
- Delete CNAME
- Create CNAME
- Potential fix for pull request finding
- - Incremented `currentSchemaVersion` to `v112` and updated migration versions in tests to prevent version mismatch errors. - Removed unnecessary line breaks for improved code readability.
- Potential fix for pull request finding
- Potential fix for pull request finding
- ### Add thickness property to equipment models
- update gitignore
- i18n(backup): add backup-encryption strings (en + 10 locales)
- Update issue templates
- perf/a11y(trips): address PR review round 6
- clean suggestions-row test lints
- const DivePhotoMatcher call sites
- drop unused test import
- null-aware map elements in token forms
- Revert "feat(debug): add three_js flythrough spike page behind debug menu"
- l10n: translate sync encryption strings into all locales (#520)


## Unreleased

### Features

- configurable CNS calculation method: NOAA stepped table (classic),
  Shearwater-style linear interpolation (new default), or Subsurface-style
  exponential fit (#578). Calculated CNS values decrease slightly under the
  new default; select "classic" in Settings > Decompression to reproduce
  previous values. The picker's "About these methods" section explains each
  method's origin with source links.


## 1.6.1 (2026-07-10)

### Bug Fixes

- round Android USB serial bulk reads up to whole packets (#318)

### Documentation

- baseline + WS0 index-integrity implementation plan
- large-database performance (phase 3) design spec

### Chores

- bump version to 1.6.1+116


## 1.6.1 (2026-07-09)

### Bug Fixes

- buffer Android USB serial reads at bulk-packet granularity (#318)

### Documentation

- release notes

### Chores

- bump version to 1.6.1+115

### Other

- Fix trip scan analysis issues
- Address trip scan timezone review
- Address trip scan review comments
- Fix trip gallery photo scan and spinner dismissal


## 1.6.0 (2026-07-09)

### Features

- implement parseRawDiveData
- implement parse_raw_dive_data
- add nativeParseRawDive JNI binding
- anchor site picker on dive GPS and seed New Dive Site coords
- seed new-site form from initialLocation + geocode; wire /sites/new extra
- anchor distance/sort on dive GPS, unit-aware readout
- add auto-scaling unit-aware formatGeoDistance
- rebuild backend from this device when a replace is stuck (offline uploader)
- cloud-clear actions on Troubleshoot screen (3a remove, 3b typed-confirm wipe)
- wipe all cloud sync data incl. epoch markers (Troubleshoot 3b)
- remove this device's cloud sync files (Troubleshoot 3a)
- tap the sync error banner to open Troubleshoot Sync
- Troubleshoot Sync screen with Repair Sync action (replaces Reset tile)
- comprehensive local Repair (reset + epoch markers + temp sweep)
- add LibraryEpochStore.clear() for comprehensive local repair
- v102 migration re-links stranded tank pressure series (#510)
- let an interrupted download import the dives it already pulled
- per-file attribution in review and summary
- accept multi-file and folder drops
- file triage step for multi-file batches
- multi-select picker and desktop folder pick
- batch parse pipeline with merge and cross-file dedup
- add bulk import strings in all locales
- detect duplicate dives across files within an import batch
- add PayloadMerger for multi-file bulk import
- tri-state bulk editing for tags, dive types, buddies
- tri-state bulk gear editing; hide save-as-set in bulk
- tri-state BulkMembershipEditor widget
- tri-state membership delta logic for bulk edit
- per-item membership count queries for bulk edit
- scan entry point and localized strings
- scan flow from photo to prefilled dive
- platform engine provider
- Linux Tesseract engine
- Windows.Media.Ocr implementation
- submersion_ocr plugin with Apple Vision engine
- Android ML Kit engine
- import a local image file as dive media
- fuzzy site name resolver
- DivePrefill support in DiveEditPage create mode
- support manual Consolidate for file imports in UniversalAdapter
- layout-aware logbook parser
- page-level unit inference
- flag exact source_uuid re-imports as existing-source so they default to skip
- label table and geometric value binder
- shorthand value normalizer
- domain models and OcrEngine interface
- show estimated tank pressure lines on all profile chart hosts (#197)
- label estimated tanks in the profile legend
- mark estimated tank pressure in chart tooltip and readout
- render estimated tank pressure lines straight on the profile chart
- add estimatedTankPressuresProvider composing real+estimated pressures
- synthesize linear tank pressure series for manual dives
- add buildActiveTankIntervals for per-tank gas windows
- replace Tanks and SAC by Cylinder cards with CylindersCard
- add unified CylindersCard widget
- add Cylinders section strings, trim SAC-segments description
- hub leads with the planner; deco calculator gains altitude/salinity
- multi-plan compare with overlaid profiles and diff table
- versioned .subplan share file with import
- printable dive slate PDF export
- range table section in the results sheet
- range table service over deviated engine runs
- plan-vs-actual overlay on the dive detail profile chart
- persist convert-to-dive with plan back-link
- follow-a-dive picker with tissue seeding and logged SAC auto-fill
- seed plan outcome tissues from a followed dive
- carry followed-dive and linked-dive context on plan state
- contingency overlays and tables on the canvas
- contingency config in the planner editing state
- turn pressure and rock-bottom validation
- contingency service for deviation and lost-gas plans
- CCR canvas controls and bailout readouts
- worst-case bailout solver
- CCR mode and setpoints in the planner editing state
- CCR loop deco schedules and consumption in PlanEngine
- CCR loop as a depth-dependent ascent gas plan
- localize the canvas UI in all locales
- Live Profile Canvas page and route cutover
- saved plans sheet with open, duplicate, and delete
- status chips and results sheet on PlanOutcome
- live canvas chart with ceiling, gas switches, and scrub
- canvas data providers on PlanEngine
- persist plans - save and load wired into the planner
- PlanEngine consumption and severity-sorted plan issues
- PlanEngine schedule generation on the DecoModel seam
- DivePlanRepository with full sync participation
- DivePlan domain aggregate
- register dive plan tables across the sync pipeline
- dive plan tables at schema v100

### Bug Fixes

- preserve built-in reference data across replace-adopt
- set plugin targetSdk so DownloadIsolationTest can run
- make DiveMarshalingTest compile
- guard _geocodeSeed against ref use-after-dispose
- keep header from overflowing with the longer dive-distance label
- stamp track endTime from stop time, not last fix
- prevent NaN crash on dives with a flat tank pressure series
- address PR review round 2
- address batch-cancel data loss and CSV-specific triage copy
- address PR review — guard Troubleshoot during sync, narrow temp-dir fallback
- use correct tank volume/pressure keys in MacDive DB mapper (#517)
- Recent dives follows the dive list display settings (#506)
- resilient sync temp dir default (app container, fallback to systemTemp when path_provider absent)
- write base temp files to the app temp dir, not /tmp (#509)
- address PR review round 2 (batch error handling, test hygiene)
- make orphan-to-tank pairing deterministic (PR review)
- show SAC by cylinder on re-keyed and profileless dives (#510)
- route Android SAF pre-migration backup to the sandbox default
- address PR review - separator-agnostic basenames, id-keyed file attribution, localized batch label
- deliver dives oldest-first and preserve manifest records behind deleted dives (#480)
- keep JNI-resolved serial handler methods from R8 stripping (#318)
- sort bulk membership rows by label for stable order
- tri-state no-op rows show no misleading subtitle
- save-as-set stamps active diver so the set is visible
- rewind Windows OCR stream, align spec with code
- native Android ML Kit in submersion_ocr plugin
- keep a stranded dive visible in the summary when consolidation fold and cleanup both fail
- gate dive matcher on time so far-apart dives are not flagged as duplicates
- clamp estimated pressure tail to endPressure (float drift)

### Refactoring

- hold picked files as a list in wizard state
- extract shared MatchScorer for both dive matchers
- remove orphaned file-import consolidation UI and state
- remove dead standalone UDDF import path
- remove inert fingerprint/depthTolerance params from matcher path

### Performance

- start estimated-pressure provider fetches concurrently

### Documentation

- plans
- spec and plan for raw dive parsing on Android and Linux
- add design spec + implementation plan
- qualify oldest-first delivery as driver-dependent (PR review)
- sync error recovery implementation plan + spec refinements (#509)
- clarify the non-Apple backup-dir branch is not desktop-only (PR review)
- sync error recovery design spec (#509)
- add bulk file import implementation plan (#501)
- add bulk file import design spec (#501)
- add bulk file import implementation plan (#501)
- correct keep-rule comment -- implements-wildcard pins class names too (#318)
- add bulk file import design spec (#501)
- bulk membership editing design + implementation plan
- mark OCR logbook import spec implemented
- spec and plan for dive matching time-gate and file-import consolidation
- implementation plan for OCR paper logbook import
- design spec for OCR paper logbook import
- implementation plan for linear tank pressure line (#197)
- implementation plan for linear tank pressure line (#197)
- design spec for linear tank pressure line (#197)
- trailing block shows gas used in the diver's volume unit
- implementation plan for unified Cylinders card
- add dive planner phase 7 (outputs + hub) plan
- add dive planner phase 6 (log integration) plan
- add Phase 5 contingencies implementation plan
- add Phase 4 CCR + bailout implementation plan
- add Phase 3 Live Profile Canvas implementation plan
- add Phase 2 plan domain/persistence/PlanEngine implementation plan

### Tests

- distinguish dropped volumeLiters from a wrong value
- separator-agnostic basename in fake picker; fix folder-scan doc
- raise #509 patch coverage to ~97%
- back GlobalDropTarget drop tests with real temp files
- stub repairSync in SyncNotifier fakes; drop redundant imports
- cover partial-import capture/advance and retry actions
- make v102 idempotency test actually re-run the repair (PR review)
- raise bulk-import patch coverage to ~95% (batch flow, widgets, merger arms)
- end-to-end bulk import batch integration test
- fail fast when the foreach test script overflows its buffers
- cover bulk membership wiring; raise patch coverage to 90%
- bulk apply handles add+remove for one collection with undo
- lock in bulk equipment add-merges-not-wipes behavior
- raise patch coverage to 98 percent
- sample-page fixture suite for the parser
- raise phase 7 outputs coverage; address review comments
- cover preset chip and time-series pressure fallback
- raise phase 6 log-integration coverage; address review comment
- raise phase 5 contingency coverage; address review comments
- raise phase 4 CCR patch coverage; address review comments
- raise phase 3 canvas patch coverage; address review comments
- raise phase 2 patch coverage; address review comments
- expect repeated table headers with contingency sections

### Chores

- bump version to 1.6.0+114
- regenerate Podfile.lock for submersion_ocr plugin
- gitignore plugin android/.gradle build caches
- remove dead cylinder SAC card code and obsolete l10n keys
- translate phase 7 planner strings into all locales
- translate phase 6 planner strings into all locales
- analyzer cleanups in phase 2 tests

### Other

- Remove startup photo-enrichment backfill (undo #516)
- Revert "Potential fix for pull request finding"
- Potential fix for pull request finding
- i18n(site-picker): add dive-distance header + distance-away strings
- Split maintenance task run() (void) from backfill() count (PR review)
- Backfill photo profile-marker enrichment via a startup maintenance runner (#511)
- Populate dive name from Garmin FIT source filename (#507)
- i18n(import): pluralize the import-partial download count string
- Address PR review and raise GPS patch coverage above 90%
- Remove stray Gradle cache files and ignore package android/.gradle
- Fix CI schema pin and harden GPS recorder/matching paths (PR review)
- Remove Planning and ToolsPage GPS Logger entry points
- Add GPS Logger quick action to dashboard
- Show app-wide recording strip while a GPS session is active
- Add GPS Log destination to navigation model and desktop rail
- Relocate GPS Logger route to top-level /gps-log with redirect
- Add nav and recording-strip localization keys for GPS Log
- Add GPS logger discoverability implementation plan
- Add GPS logger discoverability design spec
- Surface GPS Logger in planning hub and desktop sidebar
- const bulk-edit requests; apply canonical format
- i18n(dive-log): strings for tri-state bulk membership editor
- Guard orphan track recovery and pluralize point counts (PR review)
- Add GPS Logger page, tools card, route, and localized strings
- Add background location permissions for GPS track logging
- Add GpsTrackRecorder with accuracy gate, keepalive, checkpointing
- Trigger GPS track matching after dive import and after sync merge
- Add GPS track match sweep, dive GPS stamping, reparse GPS guard
- Add pure GPS track position matcher with interpolation and tolerance
- Sync gps_tracks table through changeset serializer and merge registries
- Add GpsTrackRepository with buffer, checkpoint, recovery, tombstones
- i18n(dive-log): add estimated-pressure suffix string in all locales
- Add GPS track domain entities, blob codec, wall-clock conversion
- Add gps_tracks and gps_track_points_local tables (schema v101)
- Add GPS track logging implementation plan
- Add GPS track logging design spec (discussion #289)
- const-construct preset test fixture


## 1.5.9 (2026-07-05)

### Features

- draggable readout card on fullscreen profile
- add draggable readout card widget
- add fullscreen readout card hint string
- persist fullscreen readout card position
- honor dive altitude and water type in analysis and planning
- compressibility-correct gas consumption
- DecoModel interface with BuhlmannGf implementation
- SchedulePolicy with gas-switch minimums and O2 air breaks
- constant-ppO2 CCR tissue loading
- BreathingConfig with OC, constant-ppO2 CCR, and SCR modes
- thread DiveEnvironment through the Buhlmann engine
- pressure-space compartment ceiling and env-aware SurfGF
- add DiveEnvironment for altitude and salinity aware pressure
- flow tags onto stats line when they fit
- sources bar in the fullscreen dive profile
- localize multi-source attribution strings in all locales
- split-into-separate-dive action in the data sources section menu
- dive detail and fullscreen pages follow the active source with SourceBar
- DiveSplitService splits a data source into a separate dive
- chart renders active source with typed color-coded overlays
- SourceBar widget with activate, overlay, and management menu
- active-source, overlay, and per-source analysis providers
- group dive profiles by data source id, fixing unknown-computer attribution
- shared source name resolver with source-type fallbacks
- enable Consolidate action in dive computer import review
- infer cylinder role on dive-computer download
- show dive computer friendly name in data sources and attribution
- set the registered Dropbox app key, lighting up the tile
- scope temperature/surface-interval/time-at-depth stats by the filter
- scope time, equipment, and profile stats by the filter
- distinguish video markers with a videocam icon
- fullscreen profile page with instrument bar and playback (#443, #169)
- adaptive instrument bar with customize sheet
- sync round-trip coverage, remove dead ProfileSelectorWidget, update docs
- wire photo markers into dive detail profile charts (#162)
- add Photo Markers to default visible metrics
- template management pages, routes, settings entry (#164)
- per-computer chart overlays follow toggle bar; real names; tank source badges
- upcoming section with countdown and checklist progress (#164)
- render photo markers on the dive profile chart with legend toggle
- checklist tab and overview card on trip detail (#164)
- hide Dropbox tile until app key is configured
- per-source comparison grid in Data Sources section
- add PhotoMarkerOverlay with clustering and preview card
- apply-template sheet and save-as-template dialog (#164)
- add photo marker model and clustering layout
- combine dialog consolidates overlapping dives with primary selector
- item tile, edit sheet, and trip checklist section (#164)
- transport controls with minimap scrub slider
- add showPhotoMarkers legend state seeded from settings
- surface buddy credentials in dive buddy picker (#395)
- scope marine-life stats by the filter
- readout tile widget for instrument bar
- use shared instructor picker with credential autofill (#395)
- checklist and upcoming-trip strings in all locales (#164)
- instrument tile model with adaptive deco-aware selection
- add persisted defaultShowPhotoMarkers setting (schema v96)
- scope social and geographic stats by the filter
- instructor picker with snapshot autofill and linked detail row (#395)
- riverpod providers (#164)
- persist fullscreen instrument tile preferences
- localize Dropbox sync strings into all locales
- cascade checklist items on trip delete (#164)
- show professional roles on buddy detail page (#395)
- scope gas and SAC stats by the filter
- position utilities and unified review provider
- trip checklist repository with copy-on-apply templates (#164)
- frame-based ticking with compressed replay speeds
- add Dropbox tile and connect dialog to Cloud Sync settings
- add legendLeading slot to dive profile chart
- checklist template repository (#164)
- scope overview and progression stats by the filter
- register Dropbox as a CloudProviderType
- auto-suggest consolidate at import, fingerprint dedup for all sources, full-fidelity consolidate
- add DropboxStorageProvider implementing CloudStorageProvider
- add Dropbox API v2 client with error mapping and pagination
- domain entities and derived trip status (#164)
- register checklist entities across the sync layer (#164)
- add Dropbox OAuth PKCE auth manager
- add checklist tables and v95 migration for trip planning (#164)
- add Dropbox auth store (keychain-backed refresh token blob)
- add Dropbox PKCE helpers and app key constant
- dive-detail merge uses consolidation service with undo; drop mergeDives
- professional roles editor on buddy edit page (#395)
- strings for buddy professional roles and instructor picker (#395)
- scope conditions stats by the filter
- merge moves credentials and re-points certification links (#395)
- unlink moves attributed tanks, pressures, events
- add filter entry point and active-filter bar
- transactional DiveConsolidationService with snapshot undo
- register buddyRoles entity and certification instructor FK (#395)
- add quick date presets to the filter sheet
- instructorId link on entity and repository (#395)
- translate dive name strings into all locales (#400)
- pure DiveConsolidationBuilder with classify, tank dedup, preview
- BuddyRoleCredential entity, role CRUD, providers (#395)
- dive name in CSV and UDDF exports (#400)
- show dive name in detail header and search (#400)
- stamp computerId on tanks, pressures, events at import
- add buddy_roles table and certifications.instructor_id (v94) (#395)
- dive name field in the edit form (#400)
- DiveField.diveName opt-in title with site fallback (#400)
- scope Overview totals by an independent stats filter
- add name to Dive entity, DiveSummary, and repository (#400)
- add computer_id attribution to tanks, pressures, events (v94)
- add nullable name column to dives (v94) (#400)
- add DiveFilterState-to-SQL subquery builder
- use optimal ascent gas for deco schedule
- add Plan ascent with selector to deco settings
- drive OC profile analysis with the optimal ascent gas plan
- add persisted ascentGasSet diver setting (schema v94)
- plumb ascent gas plan into getDecoStatus and profile processing
- thread AscentGasPlan through ascent primitives with MOD split
- add AscentGasPlan strategy for gas-aware ascent
- warn when a surface interval exceeds 30 minutes (#449)
- highlight inserted surface time in the combine preview (#449)
- depth-line profile preview in the combine dialog (#449)
- select merged dive after combine; gap samples at native cadence (#449)
- Combine action with undo snackbar (#449)
- CombineDivesDialog with overlap routing (#449)
- full-fidelity undo (#449)
- transactional apply with gap synthesis (#449)
- DiveMergeSnapshot capture (#449)
- collection merging with tank id map (#449)
- first-non-empty metadata merge (#449)
- merged stats with surface-excluded avgDepth (#449)
- DiveMergeResult and merged timeline (#449)
- add DiveMergeBuilder.classify (#449)
- SyncDataSerializer.fetchRecords batched read
- worker Pass 2/3 streaming dataRows with backpressure
- worker Pass 1 (scalars + deletions)
- BaseParseClient isolate spawn/handshake/dispose
- stream a base snapshot to a temp file in bounded memory (#358)
- BasePartFileSource streams a base temp file into checksummed parts (#358)
- route serial downloads through :dc SerialDownloadClient (#318)
- SerialDownloadClient with linkToDeath crash detection (#318)
- DiveDownloadService (:dc host) + native crash-test hook (#318)
- SerialDownloadRunner (serial download inside :dc) (#318)
- ParsedDive<->byte[] marshaling for :dc IPC (#318)
- AIDL contract for :dc download service (#318)
- SerialDownloadRequest parcelable for :dc IPC (#318)
- declare :dc download service + isolation guard (#318)
- crash-survivable serial download tracing (#318)
- implement parse of raw data on Windows
- gate iCloud tile by capability and localize failures
- add iCloud availability strings for all locales
- add native getICloudAvailability on iOS
- add native getICloudAvailability on macOS
- expose iCloudAvailabilityProvider
- add ICloudAvailability status to ICloudNativeService
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
- staged map + confirm review screen (responsive) + l10n
- add MatchSitesMap (dive + candidate pins, tap to select)
- add sensitivity setting UI and wire it through
- persist configurable siteMatchSensitivity setting
- wire route, dives-list action, and post-download match button
- add SiteMatchReviewNotifier and review page
- add SiteMatchingService with dedup, coincidence guard, and rollback
- add DiveRepository.setSite and getDivesNeedingSiteMatch
- add pure matcher, domain types, and sensitivity presets
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
- highlight last-visited course on phone-mode list return
- highlight last-visited certification on phone-mode list return
- highlight last-visited dive center on phone-mode list return
- highlight last-visited equipment on phone-mode list return
- highlight last-visited buddy on phone-mode list return
- highlight last-visited site on phone-mode list return
- highlight last-visited trip on phone-mode list return
- highlight last-visited dive on phone-mode list return
- re-import all dives from dive computer (#206) (#216)
- default detailed-card stat2 to runtime
- pre-migration database backup (#210)
- localize dive computer section
- require explicit selection for import duplicates (#200) (#209)
- show/hide tags toggle on detailed dive cards
- add map style selector (Street, Topo, Satellite)
- improve table row selection UX and simplify built-in presets
- replace sine-wave depth model with Perlin noise, micro-events, and workload-driven gas consumption
- add Perlin noise, diver personality, and micro-events for profile realism
- change UDDF generator default sample interval from 10s to 5s
- expand Standard table preset from 6 to 22 columns
- table mode full-width default, details toggle, and entity settings (#184)
- add column configuration and field category l10n strings
- table view with customizable columns and card fields (#56) (#139)
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
- add dive detail section config translations for 9 locales
- design docs
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
- add dive list view mode dropdown to Appearance settings
- integrate view mode toggle and tile switching in dive list
- add DiveListViewModeToggle segmented button
- add DenseDiveListTile widget
- add CompactDiveListTile widget
- wire DiveListViewMode through settings layer
- add dive_list_view_mode column to DiverSettings (schema v51)
- add DiveListViewMode enum
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
- add schema version-mismatch guard to prevent older app from opening newer database
- add Fix Dive Times settings page for bulk-fix tool
- add DiveTimeMigrationService for bulk-fix offset logic
- add importVersion column and wall-clock-as-UTC migration (schema v49)
- construct wall-clock-as-UTC DateTime from raw components in mapper
- pass raw datetime components instead of UTC epoch
- add nativeGetDiveTimezone JNI binding
- pass raw datetime components instead of UTC epoch
- replace dateTimeEpoch with raw component fields in Pigeon API
- wire SubsurfaceXmlParser and add integration test with real export
- add trip and tag parsing with deduplication
- add site parsing with GPS, geo taxonomy, and UUID whitespace trimming
- add cylinder/tank, weight, and profile sample parsing
- add dive metadata parsing (buddy, notes, visibility, current, salinity)
- scaffold SubsurfaceXmlParser with value helpers and minimal dive parsing
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
- rewrite chart options dialog with collapsible sections and SegmentedButton source selectors
- add l10n keys for chart option section headers and source labels
- swap Ceiling/Events in primary legend toggles
- add explicit source set methods and toggleSection to ProfileLegend
- add sectionExpanded state to ProfileLegendState
- prevent user from navigating away from an active dive computer download without warning/cancel.
- add Android App Bundle (AAB) to release workflow
- add Data Sources settings section for HealthKit UI visibility
- add Data Sources settings section for HealthKit UI visibility
- improve SAC segments and add date/time to tide cards
- add scan device gallery for individual dives
- add manual Find matching dives button on trip detail
- trigger dive scan after trip save
- add batch assignDivesToTrip to TripListNotifier
- add DiveAssignmentDialog for trip dive scanning
- add localization strings for trip dive scanning
- add batch assignDivesToTrip to TripRepository
- add findCandidateDivesForTrip to TripRepository
- add DiveCandidate entity for trip dive scanning
- link dive computer on dive detail to device detail page
- included Windows and Linux build instructions in readme.
- add liveaboard trip UI, enhance tissue loading interactions, and sync l10n
- add liveaboard_detail_records and trip_itinerary_days tables, schema v46
- add tripType field to Trip entity
- add ItineraryDay domain entity with auto-generation
- add LiveaboardDetails domain entity
- add TripType and DayType enums for trip type system
- add cumulative tissue loading, OTU tracking, and three-tier OTU display
- remove reset() from processProfile to support cumulative tissue loading
- redesign tissue loading card with viz modes, color schemes, and layout fixes
- add tissue color scheme and viz mode settings persistence
- add tissue color scheme enums and color functions
- pass spotIndex directly in onPointSelected callback
- add missing translations for all 9 locales (124 keys)
- add TabBar to equipment page with Equipment and Sets tabs
- add l10n keys for equipment tab bar
- show MOD and MND for non-air tanks on dive detail page
- update existing END calculations to respect o2Narcotic setting
- add MND/END tab to gas calculators page
- create MND/END calculator widget
- add MND/END calculator Riverpod providers
- add bidirectional MND input to tank editor
- display MND alongside MOD in tank editor
- add narcosis settings (O2 narcotic, END limit) to decompression UI
- add o2Narcotic and endLimit settings for MND calculation
- add MND calculation and o2Narcotic flag to GasMix
- database reset and dive profile pressure fixes
- deco stats. Range analysis refactoring. Small visual changes in dive info page.
- tissue heat map enhancements
- tissue heat map
- visual enhancements to dive details profile graph, decompression status, and oxygen toxicity cards.
- add theme gallery with 5 selectable visual themes
- add merge bottom sheet for combining tags
- add selection mode with single and bulk delete
- add tag management page with CRUD and search
- add mergeTags() and deleteTags() to TagListNotifier
- add tag management localization strings
- add mergeTags() and public getTagUsageCount()
- full Windows + Linux platform parity with BLE, serial, and CI
- add serial/USB transport for macOS/iOS
- full sample/event/deco parity in Kotlin mapping
- expand JNI to all 14 sample fields, events, and deco model
- extract shared Swift into darwin package, iOS gains full parity
- scaffold shared Swift package for iOS/macOS
- Data Source Preferences UI in settings and appearance pages
- legend badges show data source indicator (DC/Calc*)
- profileAnalysisProvider reads metric sources from ProfileLegendState
- add per-metric data source fields to ProfileLegendState
- database migration v42 and per-metric source settings
- refactor overlayComputerDecoData for per-metric source selection
- add MetricDataSource enum and MetricSourceInfo type
- gradient factors, per-sample deco data, and dive event markers
- extend C native bridge for full sample capture and deco model
- recalculate buttons for max depth, avg depth, and runtime for dives with a dive profile.
- recalculate buttons for max depth, avg depth, and runtime for dives with a dive profile.
- populate average depth for dives that have a dive profile
- display CNS and OTU on dive profile graph
- recursive CNS calculation incorporating previous dives.
- update snackbar messaging to display skipped duplicate count
- add migration to de-duplicate media and create unique index
- show already-linked photos as dimmed/non-selectable in photo picker
- filter duplicate assets in MediaImportService
- add getLinkedAssetIdsForDive to MediaRepository
- add multi-select mode with bulk unlink to DiveMediaSection
- integrate DragSelectGridView into PhotoPickerPage
- add DragSelectGridView shared widget
- add deleteMultipleMedia to MediaListNotifier
- add l10n strings for bulk media selection
- add deleteMultipleMedia to MediaRepository
- redesign BackupSettingsPage with file-based actions
- add ExportBottomSheet widget
- add l10n strings for file-based backup/restore
- add export/import/location methods to providers
- add getValidatedBackupHistory with stale entry pruning
- use configurable backup location in performBackup
- add restoreFromFile for arbitrary file restore
- add exportBackupToTemp for share sheet export
- add exportBackupToPath for user-chosen export location
- add validateBackupFile with SQLite and table checks
- add backupLocation persistence to BackupPreferences
- add backupLocation field to BackupSettings
- add DeviceModel.fromDescriptor() and DiscoveredDevice.fromPigeon()
- Windows plugin with C++ Pigeon API
- Linux plugin with GObject Pigeon API and multi-arch macOS fix
- Android plugin with BLE transport and JNI wrapper
- iOS plugin with CoreBluetooth BLE transport
- implement discovery and download on macOS
- implement device descriptor enumeration on macOS
- wire up dc_version() on macOS via C wrapper
- macOS plugin scaffold with podspec and stub HostApi
- add DiveComputerService with stream-based API and tests
- add Pigeon API schema and generated code
- scaffold libdivecomputer plugin package
- replace deco/O2 sections with responsive compact panels
- add CompactO2ToxicityPanel widget for condensed O2 display
- add CompactDecoPanel widget for condensed deco display
- add card color settings to sync data serializer
- add l10n keys for card color attribute and gradient settings
- add card color attribute dropdown and gradient preset picker UI
- use generic attribute-based card coloring in list builders
- add OTU and max ppO2 to paginated dive summary query
- map card color settings columns in DiverSettingsRepository
- add card color settings columns (schema v35)
- replace showDepthColoredDiveCards with cardColorAttribute settings
- add CardColorAttribute enum, gradient presets, and DiveSummary fields
- add profile editor entry points to dive detail page
- add ProfileEditorPage and register route
- add editor toolbar and context panel widgets
- add ProfileEditorChart widget
- add outlier suggestion provider for dive detail badge
- add ProfileEditorNotifier state management
- add profile editing repository methods
- add waypoint interpolation for manual profile drawing
- add range operations (shift depth, shift time, delete)
- add profile smoothing and outlier removal
- add ProfileEditingService with outlier detection
- add OutlierResult and ProfileWaypoint domain entities
- add unified release script
- add changelog generation from conventional commits
- add platform download badges to README
- add auto-update controls to settings About section
- add appcast generation and checksums to release workflow
- add Sparkle configuration to macOS Info.plist
- integrate UpdateBanner into MainScaffold
- add UpdateBanner widget for update notifications
- add Riverpod providers for auto-update state management
- add UpdatePreferences for auto-update settings persistence
- add SparkleUpdateService for macOS/Windows auto-update
- add GitHub update service for Linux/Android
- add UpdateChannel and UpdateStatus domain entities
- include custom fields in PDF export
- import custom fields from UDDF applicationdata element
- include custom fields in UDDF export via applicationdata
- import custom fields from CSV with custom: prefix
- include custom fields in CSV export
- integrate custom fields into search and filtering
- add Custom Fields section to dive detail page
- add Custom Fields section to dive edit page
- add localization keys for custom fields
- add custom field Riverpod providers
- integrate custom fields into DiveRepository load/save
- add DiveCustomFieldRepository with CRUD and batch loading
- add dive_custom_fields table (schema v34)
- add customFields list to Dive entity
- add DiveCustomField domain entity
- add macOS screenshot capture and full_release to Fastlane
- make screenshot integration test responsive to desktop NavigationRail
- add unified multi-platform release workflow
- add macOS Fastlane config for Mac App Store distribution
- add release signing config to Android build
- add configurable performance data generator with light/realistic/heavy presets
- instrument repository and provider hot paths with PerfTimer
- add PerfTimer utility for performance measurement
- add accessibility annotations and keyboard navigation (Section 15.3)
- Universal import wizard (Section 13.2/13.3)
- Marine life tracking enhancement (Section 9.2)
- icon variant preview scripts for exploring color options
- complete Apple Watch import pipeline with database persistence
- add Apple Watch import entry point in Settings
- add wearable import route to router
- add WearableImportPage and WearableDiveCard UI
- add Riverpod providers for wearable import
- implement HealthKitService for Apple Watch import
- configure iOS/macOS HealthKit entitlements
- add database columns for wearable tracking
- add DiveMatcher for duplicate detection
- add WearableImportService abstract interface
- add WearableDive and WearableProfileSample entities
- add health package for HealthKit integration
- Add save-to-file option for Excel and KML exports
- Add Excel and KML export functionality
- handle deep linking from notification taps
- schedule notifications when settings are loaded
- add background service for notification refresh
- initialize notification service on app launch
- add notification override UI to equipment edit page
- add notifications settings section to settings page
- configure Android for notifications and boot receiver
- configure iOS for background notifications
- create notification providers
- create NotificationScheduler service
- create ScheduledNotificationRepository
- create NotificationService for local notifications
- add notification settings methods and providers
- add notification settings to AppSettings and repository
- create NotificationSettings entity
- add notification fields to equipment repository
- add notification override fields to EquipmentItem entity
- add scheduled_notifications table (schema v28)
- add notification override columns to equipment (schema v27)
- add notification columns to diver_settings (schema v26)
- add notification dependencies
- integrate map view toggle in list page
- integrate map view toggle in list page
- integrate map view toggle in list page
- extract DiveCenterMapContent for embedded map view
- add map view toggle support
- add MapViewToggleButton widget
- add mapBuilder parameter for map view toggle
- integrate MapListScaffold into DiveActivityMapPage
- add onItemTapForMap for map mode selection
- integrate MapListScaffold into DiveCenterMapPage
- add onItemTapForMap for map mode selection
- integrate MapListScaffold into SiteMapPage
- add onItemTapForMap for map mode selection
- add MapListScaffold for desktop split-pane map view
- add CollapsibleListPane widget for animated collapse
- add MapInfoCard widget for map selection overlay
- add MapListSelectionProvider for split-pane state management
- add wallet button to list page
- add certification wallet card
- create CertificationWalletCard dashboard widget
- add wallet route to app router
- integrate CertificationShareSheet in wallet page
- create CertificationShareSheet for export options
- create CertificationCardRenderer for image export
- create CertificationWalletPage with full-screen stack
- create CertificationEcardStack with swipe navigation
- create CertificationEcard widget with agency branding
- add brand colors to CertificationAgency enum
- show linked certification on course detail page
- display signatures in PDF dive exports
- add buddy signatures section to dive detail
- create BuddySignaturesSection widget
- create BuddySignatureRequestSheet widget
- create BuddySignatureCard widget
- add buddy signature providers
- add buddy signature storage methods
- add SignatureType enum and role field
- add signatureType column for buddy signatures
- initialize tile cache service at app startup
- add navigation to Offline Maps and Activity Map
- add routes for DiveActivityMapPage and OfflineMapsPage
- add DiveActivityMapPage for dive heat map
- add Coverage heat map view to SiteMapPage
- add HeatMapControls widget
- add HeatMapLayer widget with gradient rendering
- add heat map data providers
- add HeatMapPoint entity
- add OfflineMapsPage for managing cached regions
- add RegionDownloadDialog for download configuration
- add RegionSelector widget for bounding box selection
- add offline map providers
- add TileCacheService for tile caching
- add OfflineMapRepository
- add cached_regions table for offline maps
- add CachedRegion entity
- add flutter_map_tile_caching dependency
- wire up photo scan and link functionality
- add scan results dialog for photo linking confirmation
- add trip media scanner service for timestamp matching
- add trip gallery route
- add trip-scoped photo viewer with dive context overlays
- add trip gallery page with photos grouped by dive
- integrate photo section into trip detail page
- add trip photo section widget with preview row
- add trip media providers for aggregated photo queries
- add DiveMediaSection widget for dive detail page
- add Riverpod providers for media state management
- add MediaRepository for CRUD operations
- add EnrichmentService for dive profile interpolation
- add MediaItem domain entity with tests
- add database schema for underwater photography
- add trips and bulk delete to v1.0 roadmap

### Bug Fixes

- resolve instrument tiles against the rendered profile
- stop card drags resetting legend toggles; stabilize card width
- canonicalize non-finite readout card fractions to the default corner
- clamp readout card fractions at seed and persist boundaries
- address PR #484 review feedback
- date split-off dives by their source entry time; align spec with Unlink removal
- address PR review - primary split family rows, snapshots, panel sync, stale overlays
- Dive Computer row follows the active source; badge every attributed tank
- tighten source pill height and make the whole pill activate
- compute the primary source's analysis from its own bucket
- label overlay tooltip rows with their metric and add overlay temperature
- address PR review - metadata-only sources, tooltip lower-bound, CJK suffix spacing
- exclude matchedExistingSource re-downloads from bulk consolidate count
- overlay keepRemote conflict apply; cover upsert switch
- stop caching null analysis lost to a dive-load race
- limit null-overwrite upsert to HLC-bearing entities
- import gas switches from Garmin FIT files (#404)
- surface Shearwater UDDF multi-gas tanks and gas switches (#404)
- track scrub cursor across multiple dive computers
- preserve columns a peer omits when applying a merge
- fall back to a streamed base when the adopted watermark is null
- propagate cleared (null) fields through the merge (#474)
- publish post-adopt edits as base-less changesets, not a full base
- stop UNIQUE constraint crash seeding sync_metadata on fresh DB
- stop Overview crash from reified vars list type
- show one focus dot on the velocity-coloured depth line
- clear stale instructor number on picker switch; sentinel copyWith (#395)
- converge duplicate (buddyId, role) rows in setRolesForBuddy (#395)
- reset credential id on role change to avoid live-row tombstone (#395)
- don't trap the save-as-template dialog on save failure
- reject non-professional roles in setRolesForBuddy (#395)
- guard save/apply dialogs against dismissal during async work
- clear stale browser error after a successful reopen
- bump updatedAt on merge relink and certification re-point (#395)
- keep species-detail and dashboard stats unfiltered
- re-assert v97 objects in beforeOpen to survive version collisions (#395)
- sync parentRefs for v94 FKs, graceful consolidation errors, prefetched source-key cache
- prevent checklist progress label overflow
- use collision-free (title, category) dedupe key
- localize merge dive dialog strings in all locales
- close final-review gaps in fullscreen profile page
- dialog owns its controllers so it survives exit animation
- override filtered stats provider in prior-experience test
- renumber checklist migration to v97 to recover DBs stranded at v96 (#164)
- 2D marker clustering and id-based card selection
- honor title and date slot assignments on detailed cards
- address PR review on roles editor sync and merge-save guard (#395)
- surface browser-open failure and empty-account fallback in Dropbox UI
- include enriched videos in profile chart markers
- make deleteTrip's cascade atomic
- use grammatical plurals in checklist apply confirmation
- union junction data on consolidate, honest warnings, guarded fold failures
- use date-only arithmetic for template due-date offsets
- abort apply-template sheet on unmount, never apply silently
- scope new templates to active diver, harden item editor
- place photoMarkers metric key alphabetically
- persist tank computerId through entity round-trips
- preserve unknown role rows and stop no-op HLC churn
- unwedge Dropbox connect dialog on non-storage exceptions
- route Dropbox disconnect through canonical sign-out with backup warning
- invalidate per-dive detail providers after combine-consolidation
- update activeSecondaryCount tests to account for showPhotoMarkers
- add maxLines to picker item label; drop test error swallow (#395)
- reconcile Hungarian Dropbox OAuth terminology
- skip re-downloaded sources, compensate failed consolidate imports, deterministic uuid wrapper
- guard Dropbox dialog against dispose during async auth, add tile tests
- override filtered stats provider in overview page test
- atomic saveItems preserving createdAt; cover sync tombstones (#164)
- seed merge form with post-merge role credentials (#395)
- let dive profile chart fill bounded-height parents (#443)
- guard Dropbox auth manager against malformed token/account responses
- surface invalid-consolidation reasons; test real confirm handler
- unlink keeps shared tanks with their remaining rows; sync-mark new dive
- normalize whitespace-only names via shared effectiveName getter
- batch fetchRecords case, e2e test, and schema-check entry for buddyRoles (#395)
- place zh dive name keys adjacent to diveNumber label (#400)
- const constructor on sealed classification base
- stop tissue bar highlight overflowing its slot
- stop double-counting stop loading in the deco schedule
- drop unused import and guard empty gas list in AscentGasPlan
- address PR review on Tab-traversal guard (#444)
- constrain Tab traversal to the active pane while editing (#444)
- show hover tooltips on the Ascent Rate depth line
- address PR review findings (#449)
- scroll the merged dive into view after combining (#449)
- use UINT_MAX to avoid windows.h max() macro
- flat surface interval in the combine preview chart (#449)
- harden reparse - model bounds check, safe test fixture loader
- highlight merged dive row in the list after combine (#449)
- gap boundaries from profile extent + densified surface samples (#449)
- match Subsurface's GF ascent (fixed deep anchor + clear-to-next-stop)
- keep TTS mandatory-only, report the safety stop separately
- reason-specific message in combine invalid panel (#449)
- final review fixes - source attribution, computer link, preview bottom time (#449)
- surface apply failure as error snackbar (#449)
- restore parent tanks before FK children in undo (#449)
- carry courseId in metadata merge (#449)
- package imports and drop unused test import (#449)
- chunk fetchRecords IN-clause + bound isolate message wait (PR #448)
- harden base-parse handshake + legacy-deletion parity (PR #415 review)
- preserve device-local settings on Replace-adopt (#358, PR #447)
- bound Replace-adopt memory via delete-all-then-insert (#358)
- stream base compaction to bound memory (#358)
- stream base publish to fix iOS OOM on large libraries (#358)
- address PR review + Android build compile error (#318)
- address PR review and raise iCloud patch coverage
- retry on legacy keychain for ad-hoc no-sandbox build
- drop macOS-only SecTask from iOS handler (fixes iOS build)
- show Cloud Sync entry on all platforms
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
- respect depth unit in Time at Depth Ranges chart
- honor user date format + count duration inclusively
- refresh paginated dive list after applying matches
- localize dive-row title + short-circuit empty confirm
- use the diver icon for the surface-GPS site marker
- partition review summary + v76 migration step
- make apply errors transient; preserve fatal error in copyWith
- refresh dive list after applying site matches
- show 'Match Dives to Sites' in default list view menu, not only table mode
- address PR review (unlink guard, in-query id filter, l10n, Change action, settings tile)
- prevent popup menu overflow with flexible match-sites label
- cap map fit zoom so tiles render for clustered GPS points
- show updated dive number after renumbering Fixes #240
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
- log download failures to the file log (#258)
- DB readonly-rollback recovery + cooperative import cancellation (#255)
- show hours underwater on second line in narrow hero bar
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
- dissolve splash into app UI instead of hard swap
- Mares Puck 4 descriptor match + import-duplicates design spec (#204)
- new dive center and trip now stick when created from dive form (#201)
- per-diver computer records and cascade diver deletion (#199)
- wrap release workflow expression in ${{ }} to avoid YAML tag parse error
- clean stale native asset state before iOS/macOS CI builds
- exclude appcast from beta releases
- skip Claude Code Review on fork PRs
- increase test surface size for desktop appearance hub
- add Map Style picker to desktop settings layout
- make v64 migration defensive for missing diver_settings table
- wrap LocationPickerMap test in ProviderScope
- resolve analyze errors in map style feature
- formatting
- correct FIT import timezone offset for dive times
- simplify dive computer stats to only show dives imported and last download
- handle CertificationLevel enum type in UDDF import display
- use displayName instead of shortLabel for table column headers
- correct Report an Issue URL and open browser on tap (#177)
- handle label overflow caused by new field on dive planner (#181)
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
- add missing MinimumOSVersion to AppFrameworkInfo.plist
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
- remove build number from macOS CFBundleShortVersionString
- appcast version handling
- version display bug in update dialog
- auto_updater_windows threading violation (#83) (#100)
- fix pre-push hook for worktrees
- stabilize list tile and header sizing in selection mode (#73)
- use UTC wall-time for CSV date/time parsing (fixes #60) (#75)
- allow date pickers to select dates before year 2000
- preserve original timestamps in site merge undo
- debounce search inputs and expand dive search to all related fields (#55)
- quote DART_DEFINES in CodeQL workflow and merge C/C++ analysis into Swift job
- formatting
- replace SegmentedButton with PopupMenuButton for view mode toggle
- add dive list view mode dropdown to desktop settings page
- normalize wall-clock-as-UTC and local times in media matching
- open schema version check in read-write mode to allow WAL recovery
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
- strip pre-release suffix from VersionInfoVersion in Inno Setup
- pass raw datetime components instead of epoch in dive converters
- use UTC bounds for all dive date range queries
- use DateTime.utc for manual dive entry (wall-clock-as-UTC)
- show imported buddies in review step and fix profile temperature
- import buddies as proper entities and fill sparse profile data
- import Subsurface buddies and divemasters as proper Buddy entities
- import Subsurface buddies and divemasters as proper Buddy entities
- interpolate sparse pressure data in Subsurface XML profile samples
- auto-select newly created dive site when returning to dive edit page
- prevent black screen on startup from failed database migration
- verify cached asset IDs are still loadable before returning
- update Submersion preset column count test to 21
- wire up l10n keys for weather UI and fix _hasEnvironmentData
- invalidate stale provider cache so incremental download uses stored fingerprint
- replace hardcoded strings with l10n keys for incremental download UI
- resolve location failure after fresh permission grant
- retry location capture when first attempt fails on cold start
- decouple store uploads from GitHub release and notify on upload failures
- declare location data collection in privacy manifests and improve macOS purpose string
- refactor github release workflow to require all builds to succeed before uploading to any app store.
- replace flutter-action internal actions/cache@v4 with explicit actions/cache@v5
- failing test due to label change
- release.sh use project directory for generating the changelog.
- UI improvements for phone layout and settings organization
- detect build-number-only version bumps in update checks
- left-align all toggle items in chart options dialog
- prevent toggle desync and tap overlap in chart options dialog
- update activeSecondaryCount to include Ceiling, exclude Events
- split appcast into per-platform items so WinSparkle compares matching version formats
- ensure BLE bonding before download to prevent first-time pairing failure
- handle stale BLE bond keys causing Aqualung download failure on Android
- prevent UI freeze when loading dives from multi-dive trips
- Android bluetooth fixes
- dispatch Pigeon FlutterApi calls to main thread on Android
- upload to play store should set release state to draft
- request Bluetooth runtime permissions on Android before BLE scanning
- fastlane always uploads android build to internal testing
- remove HealthKit entitlements for macos
- remove unused downloads entitlement and add missing location entitlement for macOS sandbox
- explicitly identify HealthKit functionality in Settings UI for App Store Guideline 2.5.1
- photo-library entitlement for non-sandbox macos build
- hide Check for Updates menu item in Mac App Store builds
- show end date in tide card headers when time range spans midnight
- suppress noisy google_fonts errors in theme registry test
- remove accidentally committed untranslated.json and fix trip photo test
- declare output files in libdivecomputer podspec build phase
- use root navigator to dismiss loading dialogs in trip overview
- update test mocks for new TripRepository and TripListNotifier methods
- markdown lint errors
- generate changelog from previous tag when HEAD is tagged
- make equipment list card subtitle and trailing consistent
- hide Apple Watch import on macOS
- remove the HealthKit entitlements from the non-sandbox entitlements file.
- use two-pass codesign to prevent broken app bundle after update
- restore file picker in DMG release by embedding entitlements
- resolve two auto-update bugs: first-tap no-op and invalid signature
- windows release buid fix
- implement EdDSA signing for Sparkle auto-updates
- bug deleting a trip
- make libdivecomputer build cache architecture-aware
- capitalize app display name for Play Store readiness (#25)
- add HealthKit UI disclosure for App Store guideline 2.5.1 and fix liveaboard migration crash
- improve dive profile chart layout and tissue loading interactions
- correct doc comment, display name, and add design note
- default TissueColorScheme.fromName to thermal
- resolve equipment tab cross-navigation and scroll-to-selected bugs
- clear selected item when switching equipment tabs
- wrap master-detail layout in Scaffold to fix unbounded height
- code quality improvements for MND feature
- The phone-mode appearance_page.dart only had the Light/Dark/System toggle (_buildThemeSelector), but was missing the Theme Gallery tile that lets users pick color themes
- visual and formatting changes on dive details page
- show tank name and profile-derived pressures in dive details
- derive tank start/end pressure from profile data instead of preset working pressure
- visual changes for small screens. Version bump.
- Remove the playback button on dive details page until the functionality can be more thought-out.
- dive details visual changes.
- linux build failure fix
- migrate RadioListTile to RadioGroup API
- add defensive null check and named sentinel constant
- some dive computers always report tts=0 which overrides app-calculated values.
- tide info not showing for dives imported from dive computers.
- address code review findings for bulk media selection
- skip Claude code review for Dependabot PRs
- disable Codecov fail_ci_if_error until repo is configured
- allow Dependabot bot in Claude code review workflow
- add Codecov token and graceful fallback
- include build-ios in appcast job dependencies
- match analyze strictness between CI and release preflight
- add Windows enclosure to appcast.xml generation
- improve isNewer version comparison and add edge case tests
- add Equatable, copyWith, and progress validation to UpdateStatus
- address code review issues for custom fields
- use OffsetLayer.toImage for desktop screenshot capture
- improve release workflow error handling and consistency
- add Fastlane sensitive file patterns to macOS .gitignore
- add null-safe property access with clear error messages
- resolve analyzer warnings in wearables feature
- skip notification and background services on desktop platforms
- fix card capture by using Stack+Opacity instead of Offstage
- remove custom AnimatedBuilder, add navigation guard
- prevent Row overflow in course card
- prevent RangeError for short agency names
- commit pubspec.lock for reproducible builds
- add const to DiveSite constructor in gallery test
- connect gallery thumbnails to trip photo viewer
- improve DiveMediaSection widget quality

### Refactoring

- remove Unlink; Split absorbs its clone-on-demand tank handling
- address review feedback on friendly-name fallbacks
- route fullscreen profile to the new page, drop old view
- extract DiveMergeSnapshot.capture for reuse by consolidation
- extract BuddyRoleRepository to keep buddy_repository under size limit (#395)
- extract and parameterize DiveFilterSheet
- address PR #450 review (robust marker + no double deletion read)
- extract reusable adopt-replaced-library dialog
- keep RGBA through trim in prepare_showcase for clean edges
- wrap compose_hero in main(), add makedirs guard
- extract active-diver realign for reuse by sync adoption
- extract picker sheets from dive edit page
- extract diveRepositoryProvider to break import cycles
- replace fetchRecord hand-maintained maps with Drift's toJson()
- render heat map via density-colorized shader
- address review — value-equality provider key + rank candidates once
- staged notifier (proposals/selections/confirm)
- split service into computeProposals + applyConfirmed
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
- drop redundant isSelected arg on DenseBuddyListTile
- move ListViewModeToggle to shared/widgets, add availableModes
- rename DiveListViewMode to ListViewMode
- extract dive profile metrics into dedicated sub-page
- remove equipment sets navigation shortcuts
- extract EquipmentSetListContent widget from EquipmentSetListPage
- remove orphaned TagManagementDialog
- remove auto-cleanup of unused tags
- delete old BLE protocols, connection manager, and flutter_blue_plus
- rewrite download providers to use DiveComputerService
- rewrite discovery providers to use DiveComputerService
- default deco and O2 sections to collapsed state
- update settings page to show card color attribute name
- generalize DiveListTile coloring to support any attribute
- move profile editor entry points to DiveEditPage
- replace Match with API key-based automatic signing
- move Apple Watch import to Transfer > Dive Computers
- address code review feedback

### Performance

- set-based tank-id lookup in per-source pressure filtering
- defer the redundant self-base publish after adopt
- record peer cursors after adopt so the next sync doesn't re-pull
- _mergeEntity read-decide-write (batched fetch + upsert)
- offload base-apply parse to a worker isolate with inline fallback
- batch adopt upserts to fix the large-library freeze (#358)
- encode BLOBs as base64 instead of JSON byte arrays
- move Buhlmann profile analysis off UI thread via compute() isolate
- configure fl_chart touch threshold for faster spot detection
- memoize tooltip construction by spotIndex
- skip gesture arena for single-finger chart drag
- use ValueNotifier for selected point to reduce rebuild scope
- optimize data generator and calibrate benchmark thresholds

### Documentation

- design spec for unified Cylinders card on dive details
- add fullscreen draggable readout card implementation plan
- release notes
- add fullscreen draggable readout card design spec
- add Phase 1 deco engine implementation plan
- add dive planner redesign design spec
- add Phase 1 deco engine implementation plan
- add dive planner redesign design spec
- add multi-source attribution implementation plan
- add multi-source attribution design spec
- fullscreen profile redesign implementation plan (#443, #169)
- fullscreen dive profile redesign design (#443, #169)
- fix schema version renumbering in trips/checklists design doc
- add photo markers implementation plan (#162)
- add photo markers on dive profile chart design (#162)
- implementation plan for upcoming trips with checklists (#164)
- add Dropbox sync provider implementation plan
- design spec for upcoming trips with checklists (#164)
- add Dropbox sync provider design spec
- mention name field in searchDives doc comment (#400)
- implementation plan for buddy/instructor integration (#395)
- add multi-computer consolidation completion implementation plan
- add design spec for buddy/instructor integration (#395)
- implementation plan for dive naming (#400)
- add multi-computer consolidation completion design spec
- design spec for dive naming (#400)
- implementation plan for filterable statistics (#453)
- gas-aware ascent implementation plan
- design spec for filterable statistics (#453)
- add combine-dives implementation plan (#449)
- add combine-dives (sequential merge) design spec (#449)
- implementation plan for streaming base publish (#358)
- design for streaming base publish (write-side OOM #358)
- android download process-isolation implementation plan (#318)
- android download process-isolation design (#318)
- clarify ICloudAvailability unsupported/unknown semantics
- release notes
- release notes
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
- add site-match review map + staged-confirm implementation plan
- add site-match review map + staged-confirm design spec
- add GPS site-matching implementation plan
- add GPS site-matching design spec
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
- implementation plans for MacDive import milestones 1-4
- design spec for robust MacDive import (UDDF, XML, SQLite, photos)
- add implementation plan for raw dive data storage (#176)
- add design spec for raw dive data storage (#176)
- add implementation plan for Statistics Overview (#167)
- add design spec for Statistics Overview page (#167)
- implementation plan for phone-mode list highlight
- correct audit findings in highlight spec — 7 tap handlers also need patching
- spec for highlighting last-visited item in phone-mode lists
- spec for re-import all dives (#206)
- added plans
- spec for issue #200 - require explicit selection on duplicate imports
- added plan
- add implementation plan for expanded Standard table preset
- add implementation plan for UDDF generator improvements
- add design spec for expanded Standard table preset
- add design spec for UDDF generator improvements (#186)
- add implementation plan for startup migration progress (#186)
- add design spec for startup migration progress indicator (#186)
- add implementation plan for table mode full-width and details toggle
- add spec for table mode full-width layout and details toggle
- add drag-and-drop file import design spec
- add dashboard revamp implementation plan
- add dashboard revamp design spec
- mdi icons
- false-positive safety stop mitigation design
- add implementation plan for auto_updater threading fix (#83)
- add design spec for auto_updater_windows threading fix (#83)
- add Shearwater Cloud database import design spec
- add implementation plan for duration-bottomtime rename and SAC fix
- add debug log viewer implementation plan
- add debug log viewer design spec
- update duration-bottomtime spec with SAC calculation fix
- add import tag selector design spec
- add git submodule init step to setup instructions
- add buddy merge implementation plan
- address spec review feedback for buddy merge design
- add buddy merge feature design spec
- add list view modes all features implementation plan
- update spec with rename, selection mode, and gradient notes
- add list view density modes design spec for all features
- add compact dive list view implementation plan
- add compact dive list view design spec
- add multi-computer dive consolidation implementation plan
- address spec review feedback for multi-computer consolidation
- add multi-computer dive consolidation design spec
- add implementation plan for dive number auto-assign and edit
- address spec review feedback for dive number design
- add design spec for dive number auto-assignment and manual editing
- add implementation plan for default tank preset feature
- add design spec for default tank preset feature
- add dive time timezone fix implementation plan
- add dive_import_providers to files changed table
- address spec review findings for dive time timezone fix
- add dive time timezone fix design spec
- add Subsurface XML import implementation plan
- fix spec review issues in Subsurface XML import design
- add Subsurface XML import design spec
- add trip auto-add dives implementation plan
- add trip auto-add dives design document
- add tissue heat map visualization implementation plan
- add tissue heat map visualization redesign design doc
- add equipment sets visibility implementation plan
- add equipment sets visibility design
- add MND calculation design and implementation plan
- add platform parity implementation plan
- add platform parity design for full dive computer support
- add design doc and implementation plan for bulk media selection
- add libdivecomputer platform channels design
- mark profile editing tasks as complete in roadmap
- add profile editing implementation plan
- add profile editing feature design
- add PR template with test plan checklist
- add CI/CD pipeline overhaul implementation plan
- add CI/CD pipeline overhaul design
- add auto-update implementation plan
- add auto-update design for non-app store releases
- add custom fields design and implementation plan
- add macOS release automation implementation plan
- add macOS release automation design
- add release secrets setup guide
- update release checklist for automated workflow
- add multi-platform GitHub releases implementation plan
- add multi-platform GitHub releases design
- add performance testing README
- add performance testing implementation plan
- add performance testing design for 5000+ dives
- update roadmap and remaining tasks for completed accessibility feature (Section 15.3)
- add accessibility & keyboard navigation design (Section 15.3)
- add wearable integration implementation plan
- Add wearable integration design for Apple Watch Ultra
- Add design for profile right Y-axis selection
- Add Excel and KML export feature design
- add PDF templates design document
- add gear maintenance notifications design
- add implementation plan for map view toggle
- add detailed implementation plan for map-list split pane
- Add map-list split-pane design document
- mark certification eCards tasks as complete
- add certification eCards implementation plan
- add certification eCards wallet design
- update roadmap with buddy signatures and PDF export
- mark digital signatures tasks as complete
- add buddy signatures implementation plan
- add buddy digital signatures design
- update roadmap with Maps & Visualization completion
- add maps & visualization implementation plan
- add maps & visualization feature design
- add trip photo galleries implementation plan
- add trip photo galleries design document
- Add design for common marine life feature
- update TODO to reflect photo deferral to v2.0
- add comprehensive feature roadmap and development todo list

### Tests

- pin detail-page tooltip placement above the chart box
- property tests for deco model invariants
- golden-vector suite cross-validated against independent python model
- update GPS section tests for the expanded-by-default change
- raise #453 patch coverage from 65% to ~96%
- cover buddy edit page professional-roles load and save (#395)
- assert tile due-date chip via DateFormat, not a hardcoded string
- assert due-date chip via DateFormat, not a hardcoded string
- raise patch coverage above 90 percent (#395)
- mark checklist table column getters coverage:ignore
- cover the checklist item/template edit sheets and dialogs
- add broad apply()-vs-SQL parity invariant
- cover import consolidation seam, synthesized sources, undo failure path
- strengthen unique-species filter test with a distinct species
- checklist entities round-trip through sync serializer (#164)
- verification fixes for buddy/instructor integration (#395)
- add showPhotoMarkers legend provider tests
- pin saveAsTemplate after-start due date drops to dateless (#164)
- assert daysUntilStart clamp and elapsed-trip isInProgress (#164)
- cover checklist tables in parent-refs completeness test (#164)
- assert buddyRoles tombstone on merge credential drop (#395)
- cover reparse-path computerId attribution
- exercise real onUpgrade path for v94 migration (#395)
- exercise v94 upgrade path and guard idempotency
- register v94 in migration ladder tripwire
- reconcile TTS oracles with the GF deep-anchor ascent model
- fixture shape + clean-room ZHL-16C TTS cross-check for gas-aware ascent
- update provider epoch tests for the deferred self-base publish
- document zero-length semantics for duration-less dives (#449)
- raise #448 patch coverage to ~97% (fetchRecords + isolate paths)
- cover batched upsertRecords (all 40 entities) + empty base part
- instrumented proof a :dc native crash spares the app (#318)
- address review feedback
- cover the app-root sync-state listener
- poll for conditions instead of fixed sleeps; close test DBs; pin widget-test locale
- restore-resume two-device convergence
- address PR review feedback on test doubles
- add in-memory FakeCloudStorageProvider test double
- skip backend-switch widget tests on non-Apple platforms
- raise patch coverage to 98.8 percent
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
- cover notifier/page/map for staged review (patch >=90%); drop dead map didUpdateWidget
- raise patch coverage above 90% (notifier, page, repo, import-summary, settings)
- add setSiteMatchSensitivity override to remaining settings mocks
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
- add compact-mode highlight test; refresh provider doc comment
- add edge case and error handling tests
- add escalating backoff coverage for local asset cache
- add integration tests for fingerprint persistence in DownloadNotifier
- add widget tests for collapsible sections, source buttons, and badge count
- add widget tests for TagMergeSheet
- add widget tests for TagManagePage
- add repository tests for merge, delete, and no auto-cleanup
- add per-metric source selection integration tests
- add ParsedDive mapper and toPigeon round-trip tests
- add inline smoke tests and heavy performance benchmarks
- add unit tests for CachedRegion entity
- add unit tests for HeatMapPoint

### CI/CD

- remove Claude Code and Claude Code Review workflows
- bump codecov/codecov-action from 6 to 7
- bump softprops/action-gh-release from 2 to 3 (#213)
- bump actions/checkout from 4 to 6 (#212)
- trigger build
- bump codecov/codecov-action from 5 to 6 (#119)
- revert fork PR support for Claude code review
- enable Claude code review on fork PRs
- bump github/codeql-action from 3 to 4 (#80)
- replace CodeQL default setup with custom workflow for Swift and Java/Kotlin analysis
- add explicit permissions to workflows to resolve CodeQL alerts
- exclude generated l10n files from code coverage
- replace Windows ZIP artifact with Inno Setup installer
- bump actions/download-artifact from 7 to 8 (#23)
- bump actions/checkout from 4 to 6 (#24)
- bump actions/upload-artifact from 6 to 7 (#22)
- bump actions/cache from 4 to 5 (#21)
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
- add concurrency control to screenshots workflow
- split screenshots workflow into parallel capture + upload jobs
- add screenshot capture to screenshots workflow

### Chores

- bump version to 1.5.9+113
- expand SAC by Cylinder and Surface GPS cards by default
- drop the attribution badge from Avg Depth in the Details card
- remove the disabled Merge with another dive menu entry
- drop attribution badges from the header stat metrics
- remove superseded multi-computer toggle path and legacy name accessors
- drop orphaned course-buddy-picker strings; fix test fixture
- bump version to 1.5.1+98
- bump version to 1.5.0+97
- satisfy analyzer (package imports, const companions, doc comment)
- remove old unused January screenshot sets (iPad/iPhone/macOS)
- adopt Xcode 26.5 recommended project settings
- bump version to 1.4.9+96
- translate first-sync merge strings into all locales
- refresh Podfile.lock checksum for libdivecomputer_plugin
- bump version to 1.4.9+95
- bump version to 1.4.8+94
- regenerate mocks for new DiveRepository methods
- bump version to 1.4.7+93
- silence experimental/coroutine errors on windows
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
- bump version to 1.4.6+92
- changelog + plan update for MacDive UDDF gap-fill milestone
- bump version to 1.4.5+91
- bump version to 1.4.4+90
- regenerate mocks for diver-scoped numbering signature change
- bump version to 1.4.4+89
- upgrade 7 major dependencies with API migrations (#194)
- upgrade 66 package dependencies (#192)
- bump version to 1.4.3+88
- remove orphaned uddf_adapter_test.mocks.dart
- remove dead UddfAdapter and FitAdapter
- bump version to 1.4.2+87
- bump version to 1.4.1+86
- bump version to 1.4.1+85
- remove MinimumOSVersion from AppFrameworkInfo.plist
- remove unused activity_status_row, stat_summary_card, quick_stats_row
- bump version to 1.4.0+84
- bump version to 1.4.0+83
- bump version to 1.3.7+82
- regenerate uddf entity importer test mocks
- update CLAUDE.md
- add --comment flag to Claude code review prompt
- allow gh/git CLI in Claude code review workflow
- enable verbose output for Claude code review workflow
- disable the swift, java, and c++ codeql steps
- add CODEOWNERS for automatic review assignment
- bump version to 1.3.6+81
- update changelog
- bump version to 1.3.5+80
- bump version to 1.3.4+79
- regenerate l10n files after description key addition
- update pubspec.lock after dependency resolution on new environment
- bump version to 1.3.3+78
- formatting
- formatting
- bump version to 1.3.2+77
- disable cloud sync UI options until bugs are addressed
- bump version to 1.3.2+76
- update README.md
- bump version to 1.3.1+75
- bump version to 1.3.0+74
- localization update
- format code and fix lint warnings for weather feature
- documentation update
- formatting
- translations
- fix mock override and format generated code for incremental download
- bump version to 1.2.25+73
- add ble pin code plan
- bump version to 1.2.24+72
- bump version to 1.2.24+71
- added translations
- bump version to 1.2.23+70
- bump version to 1.2.23+69
- bump version to 1.2.23+68
- bump version to 1.2.23+67
- add code optimization plan
- bump version to 1.2.22+66
- bump version to 1.2.21+65
- fix const lint in SegmentedButton style
- bump version to 1.2.20+64
- bump version to 1.2.19+63
- bump version to 1.2.18+62
- bump version to 1.2.17+61
- add google play store onboarding plan
- bump version to 1.2.16+60
- bump version to 1.2.15+59
- bump version to 1.2.14+58
- bump version to 1.2.13+57
- visual changes in Settings page
- bump version to 1.2.12+56
- bump version to 1.2.10+54
- bump version to 1.2.9+53
- bump version to 1.2.8+52
- bump version to 1.2.7+51
- bump version to 1.2.6+50
- bump version to 1.2.3+47
- bump version to 1.2.1+45
- add Swift Package Manager build artifacts to gitignore
- add libdivecomputer as git submodule
- bump version to 1.1.4+42
- bump version to 1.1.3+41
- bump version to 1.1.3+40
- bump version to 1.1.2+39
- bump version to 1.1.1+38
- bump version to 1.1.0+37
- bump version to 1.1.0+36
- bump version to 1.1.0+35
- bump version to 1.1.0+34
- add auto_updater and package_info_plus dependencies
- remove AppleScript-based macOS screenshot script
- update macOS window size to 1280x800 for App Store screenshots
- retire standalone ios-release workflow
- remove unused ascentTime variable in data generator
- add performance test runner script
- fix lint issue in settings_page.dart
- add .worktrees/ to gitignore for feature development

### Other

- i18n(dive-log): wire existing l10n keys through the filter sheet
- i18n(dive-log): localize filter sheet title and close tooltip
- i18n(statistics): localize filter strings across all locales
- guard velocityBandRuns length; assert global index in hover test
- i18n: translate built-in dive sites map strings into all locales
- shade inserted surface time green in combine preview (#449)
- l10n: fix combine-dives translation nits (es, nl, pt, zh) (#449)
- l10n: translate combine-dives strings into 10 locales (#449)
- dart format post-restore store tests
- scope screenshots gitignore negation to readme/ to keep junk ignored
- stop gitignoring committed docs/assets/screenshots
- Potential fix for pull request finding
- fix const and doc-comment lints in epoch tests
- add density-colorized heat-map fragment shader
- i18n: add similar-site hint strings across all locales
- vendor patches via fork submodule so CI builds include them
- Update docs
- i18n: translate site-matching strings across 10 locales
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
- ignore sample data
- Revert "chore: changelog + plan update for MacDive UDDF gap-fill milestone"
- i18n: translate 24 missing shared-sites/trips strings across 10 locales
- Fixed inline comments to match changed behavior.
- Replaced delete & re-insert approach for updating dives with a real update mechanism.
- Fixed Dart style convention.
- Changed prio of start/end pressure data source. Prio #1 is now tank metadata, prio #2 is now first/last value from tank_pressure_profiles
- i18n: translate 35 missing strings across 10 locales
- Revert "Merge main into Jaibar/main to resolve conflicts for PR #193"
- normalize tile highlight alpha to 0.5 across all list views
- i18n: translate 71 missing strings across 10 locales
- apply dart format to map style files
- Add Claude Code GitHub Workflow (#183)
- Handle average depth imports correctly from computers that do not support it (#180)
- Fix/additional uddf ssrf properties (#170)
- Deprecate legacy pressure field, fix multi-tank import (#115) (#136)
- Revert "fix(android): align Kotlin JVM target to each subproject's Java target"
- Rearchitect CSV import with staged pipeline (#116)
- Fix/volume conversion (#126)
- Issue-115 SSRF multi-cylinder dives don't convert over to gas switch … (#122)
- Bugfix/logger test fix (#106)
- add CSV import rearchitect implementation plan
- add CSV import rearchitect design spec
- Issue 36 - JNI interface being obfuscated in android build (#105)
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
- Feature/cressi leonardo import (#43)
- Fix/macdive uddf import (Fixes #28) (#42)
- Add search to USB Cable tab when adding a USB dive computer manually for import (#68)
- Feature/buddy merge (#66)
- Add reserve pressure user input to dive planner (#67)
- Feature/sites merge (#54)
- format dive center tile files
- Fix/air consumption unit conversion (#52)
- Feature/site picker search (Issue #49) (#51)
- update todo
- Verbage changes
- Verbage changes
- Build fixes
- tag management docs
- CI/CD fixes
- roadmap/todo updates
- version bump
- Data source switching
- Setting to prefer dive computer reported CNS data, or application calculated CNS.
- Setting to prefer dive computer reported CNS data, or application calculated CNS.
- plan for importing all possible data from dive computers.
- Auto appplication reload after restore from backup.
- Store active diver in the database. Backup and restore UI changes.
- Redesigned Diver Profile UI.
- Prevent media from being linked to a dive more than once.
- CI/CD screenshot capture bug fixes
- CI/CD fix for libdivecomputer git submodule
- version bump
- Restore db fix. Colored navigation icons.
- Refactored Backup UI
- Navigation consistency changes. Linux CI/CD build fix.
- Navigation fixes. CI/CD windows and linux fixes.
- fix ci/cd OS builds
- Before creating, look up an existing computer by bluetoothAddress. If one exists, reuse it.
- Revert DIve Computers navigation
- Stop bluetooth scanning when leaving add computer page
- Download cancellation logic
- Fix dive computer state management. Dive download progress fix.
- fix ci/cd OS builds
- fix ci/cd OS builds
- fix ci/cd
- iOS DiveComputerHostApiImpl.swift is now fully in sync with macOS
- Shearwater bluetooth fixes. Import dive computer serial and firmware version from libdc.
- Aqualung bluetooth fixes
- Aqualung bluetooth fixes
- fix flutter analyze errors
- podfile.lock update
- Update the Fastfile stub to match the current UpdateService interface.
- libdivecomputer integration plans
- Aqualung support. Small visual changes in dive details page.
- Aqualung support. Small visual changes in dive details page.
- UI fixes
- Removing ability to color dive cards by ppO2 and OTU.
- Auto-update fix
- changelog
- Fix: appcast feed URL pointed to incorrect repo
- generate favicon without rounded corners or alpha
- changelog
- Updates section in Settings/About should not show on iOS or Android
- macos podfile change
- fix ios release build
- fix macos release build
- fix macos release build
- fix macos release build
- fix ios release build
- fix macos release build
- fix ios release build
- fix macos release build
- fix ios release build
- fix macos release build
- fix ios release build
- fix ios/macos release builds
- delete_release.sh enhancements
- fix macos release build
- fix ios release build
- refresh git cache stats
- bump_version --commit option
- bump_version --commit option
- local build utility scripts
- local build utility scripts
- fix macos release builds
- version bump
- fix ios release builds
- fix macos release builds
- version bump to 1.1.0
- Fix logo caching
- prevent bubble animation from resetting.
- update pre-commit hook to exclude performance tests
- update gitignore
- database migration fix
- version bump
- fix macos release builds
- fix macos release builds
- version bump
- Use xcode 26+ for CI/CD
- Use xcode 26+ for CI/CD
- disable xcode auto-management of build number.
- fix macos release builds
- fix macos release builds
- fix release builds
- fix release builds
- fix release builds
- fix release builds
- fix release builds
- fix release builds
- version bump
- fix macos screenshot uploads
- Doc updates.
- macOS screenshot upload fix
- fix screenshot upload to app store connect.
- security policy doc
- fix screenshot upload to app store connect.
- fix github actions screenshot capture
- fix github actions screenshot capture
- fix github actions screenshot capture
- streamline macos screenshot capture
- back to monolithic CI/CD approach
- Build workflows checkout exact commit that CI tested.
- Cancel old builds when there's a new build
- Refactor CI/CD pipeline
- update warning/hard-ceiling threshold for performance tests
- update warning/hard-ceiling threshold for performance tests
- gemfile update
- automatic backups
- Language settings fix
- Localization support for English, Spanish, French, German, Italian, Dutch, Portuguese, and Hungarian
- don't auto-increment version with fastlane.
- fastlane force delivery
- build fixes
- build fixes
- build fixes
- updated hero banner
- format
- roadmap updates
- roadmap update
- Refactored CSV export
- update roadmap
- version bump
- version bump
- Performance optimizations
- fix failing tests
- Clean up settings/manage menu
- roadmap updates
- dive profile graph color consistency changes.
- launch icon change
- Dive profile graph optimizations
- UDDF import fix
- UDDF import/export fix
- UDDF import/export fix
- apple watch import ui fix
- fix version syncing issue
- build fixes
- build fixes
- build fixes
- version bump
- Update hero header colors
- Revert "new icon"
- new icon
- updated icon
- updated icon
- bump flutter SDK version for android
- fix healthkit tests in CI/CD
- UDDF import/export support for all application data. Refactored export_service.dart (was >7k lines).
- Refactored UDDF import. New application icon.
- Support for importing Garmin FIT files
- update remaining tasks
- update remaining tasks
- version bump
- version bump
- dive profile chart default metrics and right Y-axis value
- dive card profile chart dynamic width
- homepage visual improvements
- Exports have option to save to local file as well as share.
- Fix google_sign_in and image_picker dependency versions
- Fix share_plus dependency version
- Fix geolocator dependency version
- Update pubspec.yaml
- Claude/add privacy manifests f e lg6 (#12)
- Add privacy manifests for App Store compliance (#11)
- fix android build
- iOS build fix
- dependency update on iOS
- version bump
- fix android build
- map view filtering fix
- map view filtering fix
- map view filtering fix
- Trip details map view
- Trip details map view
- Trip details header background map
- PDF logbook export
- fix warnings
- PDF logbook export
- Dive type breakdown
- Export Training Log functionality
- video support for media attached to dives
- notifications on ios/macos
- EXIF parsing from photo attachments. If photo has GPS and dive doesn't, suggest using photo GPS
- TTS calculation fix
- version bump
- TTS changes
- Dive profile graph tweaks
- Dive profile graph tweaks
- Dive profile graph tweaks
- Dive profile graph tweaks
- Dive profile graph tweaks
- Dive profile graph tweaks
- Altitude unit was not being stored in DB per user settings.
- Dive Centers map enhancements
- Map view adjustments
- Map view adjustments
- Map view adjustments
- iCloud sync bug fix
- Map View for Dive Centers
- Reverse gps lookup from dive center address.
- Map tile caching fix. Dives/sites in map view were not clickable when the heatmap layer was enabled.
- ios build fixes
- Added pod repo update step before the macOS build
- version bump
- Dive center full address support. Certificate image export fix.
- Dive center full address support. Certificate image export fix.
- Cert and signature photos stored in database.
- format buddy signature files
- Share dives with buddies
- Filtering available for dive sites.
- organize scripts
- dive center import from local datastore. dive_site_harvester distinguishes between dive sites and dive centers/shops.
- dive center import from local datastore. dive_site_harvester distinguishes between dive sites and dive centers/shops.
- Dive import list is scrollable. Identify duplicate dives upon import.
- Fix Shearwater time format and pressure profile
- fix for CI/CD
- version bump
- fix ios build
- small fixes
- Ability to save dive-data-enriched media metadata back to original media
- update todos
- Linked photo/video support
- Linked photo/video support
- apply dart format to DiveMediaSection
- Support for training courses
- Support for training courses
- Support for training courses
- Update docs
- Marine life features - derived sightings and expected species
- Marine life features - derived sightings and expected species
- Medical/contact data in diver profile
- Medical/contact data in diver profile
- Altitude calculations
- Altitude calculations
- planner navigation fix
- Added list sorting options
- Added list sorting options
- database optimizations
- simplify dive profile chart
- codemaps
- update claude.md
- iCloud sync (#10)
- Tides pyfes (#9)
- Navigation fix
- Navigation fix
- Buddy shared dives fix
- Converted all imports from relative to absolute format
- SAC Per Segment & Per Cylinder Implementation
- Custom tank preset support
- Fixes so that unit settings are respected in Planning sections. Small UI changes. Dive export enhancements.
- update roadmap
- Dive profile range selection and playback. Export dive profiles as png.
- Surface interval planner
- Undo max width on planning tools
- Small UI changes
- Restructure planning/calculators in UI
- Added gas calclators
- Added gas calclators
- Added gas calclators
- Added deco calculator
- Improved search and filtering
- Dive planner implementation
- CCR and SCR support
- CCR and SCR support
- CI/CD iOS build fix
- roundtrip export/import UDDF test
- target newer iOS
- target newer iOS
- Cocoapods cache fix in CI/CD
- version bump
- small changes
- Fix bluetooth permissions on iOS
- fastlane fix
- version bump
- Bluetooth fix
- build automation with Fastlane and Github actions
- version bump
- improved macOS screenshot capture
- fastlane fixes
- fastlane folder organization
- Reverse geolocation on uddf improt for screenshot capture.
- macOS screenshots
- Remove 3rd party API features
- Remove 3rd party API features
- Removed deprecation warning
- Fix screenshots
- Take screenshots with headless simulator
- Fix screenshots
- Fix screenshots
- Fix iPad screenshot rotation
- Fix screenshots
- Fix screenshots
- Fix screenshots
- Screenshot fixes
- Screenshot fixes
- Screenshot fixes
- Screenshot fixes
- Screenshot fixes
- CI/CD screenshot fix
- Home page display changes
- Home page display changes
- Capture landscape iPad screenshots
- Capture landscape iPad screenshots
- Capture landscape iPad screenshots
- Use generate_uddf_test_data.py for generating screenshot data
- Use generate_uddf_test_data.py for generating screenshot data
- Use generate_uddf_test_data.py for generating screenshot data
- Use generate_uddf_test_data.py for generating screenshot data
- screenshot automation fixes
- screenshot automation fixes
- Screenshot path fix
- Fastlane fixes
- CI/CD changes
- fastlane stuff
- Fastlane config stuff
- CI/CD for screenshots
- fastlane config
- Automate screenshot capture
- Time and date format options in settings
- default window size on macos
- script permissions
- test data generation fixes
- test data generation fixes
- Small UI changes. Minimum window width for master-detail view.
- Small UI changes. Minimum window width for master-detail view.
- Improve test data generation and fix import/export
- Improve test data generation and fix import/export
- Master detail view (#8)
- Formatting
- Visual changes. Gradient Factor presets and custom values.
- formatting
- Visual changes
- pre-push hoooks and local dev env setup script
- Visual improvements.
- Better dive filtering options
- Fixed NDL and ceiling calculation
- Fixed NDL and ceiling calculation
- formatting
- Interpolate temperatures across time-series when importing Subsurface UDDFs.
- gitignore
- Add Claude Code GitHub Workflow (#7)
- adding screenshots for app store
- version bump
- Apple app store prep
- Apple app store prep
- Apple app store prep
- Apple app store prep
- Apple app store prep
- apple app store submission prep
- readme update
- split up CI builds by platform
- CI update
- CI build fixes
- CI build fix
- nosandbox file picker entitlements
- No-sandbox build for CI and non-appstore distribution
- CI build fix
- CI build fix
- ad-hoc signing fixes
- ad-hoc signed app for macos CI builds
- fixed production signing and macos entitlements
- formatting
- time handling from libdivecomputer
- pressure threshold changes
- test fixes
- dive profile chart enhancements
- formatting and home page changes
- Fix equipment filtering
- UI updates showing equipment used on dives, number of dives and trips for each piece of equipment, and better display of dives on each trip.
- readme
- SharedPreferences and the SQLite database are independent persistence stores. When the database file is deleted (fresh install, data reset, etc.), SharedPreferences may still contain a current_diver_id pointing to a diver that no longer exists. Attempting to create diver_settings with this stale ID violates the foreign key constraint. The Fix: Before using the stored diver ID, the code now validates that the diver actually exists in the database by calling repository.getDiverById(). If the diver doesn't exist, the stale ID is discarded and the app falls back to the default diver (or null if no divers exist).
- Generate import data (#6)
- pin flutter_blue_plus_winrt to 0.0.10 (#5)
- Roadmap update
- roadmap update
- upgrade to dart 3.10 (#4)
- Generate import data (#3)
- fix builds
- flutter map supress warning
- fix windows build
- Fixed the Windows build failure by vendoring flutter_blue_plus_winrt and patching its WinRT plugin so the missing services loop and shadowed serviceUuid no longer break MSVC compilation. The override in pubspec.yaml makes Flutter pick the patched local copy.
- Multi tank pressure (#2)
- Pinned flutter_blue_plus_winrt to 0.0.9 due to regression
- Dependency upgrades (#1)
- dependency updates
- dependency updates
- flutter updates
- move to un-converged fluter threading model
- CI/CD fixes
- CI/CD optimizations
- disable macos build code signing
- CI/CD build fixes
- enable verbose logging for CI/CD builds
- CI/CD fixes
- formatting fix
- Fix missing trailing commas in dive_profile_chart.dart
- Update CI Flutter version to 3.38.5 to match local environment
- CI use newer version of flutter
- update gitignore
- fixed tests
- CI/CD fixes. Gas switch visualization.
- Add GitHub Actions CI/CD pipeline
- Max depth and tank pressure markers on dive profile graph
- show temp on dive cards
- persist appearance settings
- appearance options
- Nav bar updates
- database migration popup changes
- iOS file selection fixes
- Support user-defined database location
- readme update
- readme update
- Update readme
- fix small code issues
- readme changes
- readme changes
- readme changes
- readme changes
- readme changes
- readme changes
- readme changes
- readme change
- readme changes
- readme changes
- readme change
- readme change
- readme change
- readme change
- readme logo position
- added "home" page
- remove xcode crap
- dive details exit date
- documentation
- readme update
- readme changes
- readme updates
- readme update
- use the app icon
- icon adjustments
- App icon change
- namespace change
- cloud sync fixes
- google drive api
- xcode settings
- support for cloud sync
- local site repository
- divesite api integration
- Duplicate dive detection, incremental downloads, and device stats.
- Implemented integration with public dive site APIs.
- Aqualung BLE device paring support
- USB support for Aqualung i770R
- Manufacturer-Specific BLE Protocols
- libdivecomputer FFI Integration for USB/Serial Devices
- Shearwater dive profile fixes
- Dive import fixes
- shearwater BLE fixes
- shearwater BLE fixes
- dive computer changes
- dive computer import bug fixes
- fix formatting and entitlements
- Dive computer support
- Buddy import bug fix
- formatting fixes
- SAC rate trend chart and segment calculation
- Statistics fixes. SAC Rate display improvements.
- Tank preset enhancements. Restructuring statistics page.
- SAC calculation improvements
- Icon order change
- Import fixes. Tank validations. Visual fixes.
- bulk operations for dive sites
- tank and pressure fixes
- fix trips loading bug
- dart formatting fixes
- dart formatting fixes
- fixed diver profile settings bug. Removed unnecessary database migration code.
- Diver profile delete bug
- Import bug fix
- fixed UDDF import/export
- Trip and Dive Center cache invalidation
- multi-diver profile fixes
- fix custom dive type display
- Added welcome page. All data is now diver-profile specific.
- Improved exports
- import fixes
- Multi-computer profile support.  Profile visualization enhancements. Deco and algorithm calculations.
- updated project docs files
- Dive details chart changes
- reposition dive profile
- Support for multiple divers/profiles
- altitude unit fix
- added support for altitude, weather, and tides
- update to java 21
- gradle fix
- auto-calculate bottom-time
- Runtime support
- Support for custom dive types
- fullscreen map option on dive site page
- Removed weight calculator until feature is ready
- fixed deprecation warnings
- gradle plugin java 17 support
- unneccessary const variables
- suppress sqlite warnings
- fixing multiple small errors
- updated feature roadmap
- testing guide
- Added map clustering and color-coded map markers based on dive site rating.
- Filter equipment by status
- Map location picker for sites
- option to use gps location when creating site
- more dive site details
- Separate Entry/Exit time fields. Auto-calculate surface interval. Dive (re)numbering with gap detection.
- fixed unit bug
- UI enhancements
- Fixed Units
- Unit tests warning fixes
- Support for  multiple weights
- Support for adding tags to dives
- app-specific buddies are imported/exported from/to UUDF
- update roadmap
- Tank & Gas Enhancements. Added tests.
- added dive center picker
- track platform folders and update bundle identifier
- added bulk dive delete and buddy import from contacts.
- roadmap update
- bug fix
- Add test coverage for tab, carriage return, and pipe characters
- Update lib/core/services/export_service.dart
- Standardize empty state icon styling to match original appearance
- Add unit tests for CSV injection prevention
- Fix CSV injection vulnerability in exportTripsToCsv
- Fix copyWith method to properly handle nullable fields
- Remove duplicated _TripPickerSheet widget and use shared TripPickerSheet
- Initial plan
- Update lib/features/dive_log/domain/entities/dive.dart
- Update lib/features/trips/presentation/pages/trip_edit_page.dart
- Initial plan
- Update lib/features/trips/data/repositories/trip_repository.dart
- Update lib/features/trips/presentation/pages/trip_edit_page.dart
- Initial plan
- trip support
- UDDF export/import fix
- Comprehensive UDDF import/export for all application data
- dive profile zoom/pan
- more tests
- added unit tests. Query optimizations. UI updates. Better error handling.
- Added support for dive centers. Backend support for weight, current, and water type. Equipment enhancements.
- added support for cataloging certifications. Additional equipment service details.
- implemented buddy management
- updated docs
- reprioritize feature roadmap
- initial commit
- initial commit
- initial commit
- initial commit
- initial commit
- initial commit
- initial commit
- initial commit


## 1.5.8 (2026-06-29)

### Features

- show built-in sites on the embedded Sites map pane
- show built-in sites on the full-page Sites map
- add built-in site info card with add action
- add recessive built-in site marker layer
- add built-in sites toggle button
- add deduped visible built-in sites provider
- add grid-bucketed built-in site dedup
- expose built-in sites accessor and providers

### Bug Fixes

- release JNI local refs in libdc callbacks (#318)
- wrap long dive-type and weather rows on the dive detail page (#434)
- keep dive-type chips visible during background reloads (#429)
- handle add-site failures with an error snackbar (PR review)
- address PR review — clear built-in selection on hide, add marker semantics, parallel provider loads
- address code review on gas-switch persistence
- persist gas switches on replace-source re-download
- persist gas switches on multi-gas dive-computer dives
- keep all gases on multi-gas dive-computer downloads

### Documentation

- spec for gas-aware ascent in deco calculations

### Tests

- cover built-in selection, import, cluster and provider paths (patch coverage 96%)
- cover the dominant-gas update and gas-switch drop branches

### CI/CD

- bump actions/cache from 5 to 6

### Chores

- bump version to 1.5.8+112
- regenerate Podfile.lock (sqlite3_flutter_libs + permission_handler_apple)
- sync Podfile.lock with sqlite3_flutter_libs

### Other

- format generated Pigeon binding with the pinned Dart (3.44.4)


## 1.5.8 (2026-06-27)

### Bug Fixes

- restore libsqlite3.so bundling (sqlite3_flutter_libs 0.5.x)

### Documentation

- release notes

### CI/CD

- fix Apple builds for Flutter 3.44 (pin Xcode 26 + disable SPM)

### Chores

- bump version to 1.5.8+111
- bump version to 1.5.7+110


## 1.5.7 (2026-06-27)

### CI/CD

- fix Apple builds for Flutter 3.44 (pin Xcode 26 + disable SPM)

### Chores

- bump version to 1.5.7+110


## 1.5.7 (2026-06-26)

### Features

- trim splash fade-out dissolve to 750ms
- remove inline Add custom type from the dive-type field (#414)
- membership-aware dive types in CSV/Excel/PDF (#414)
- import/export multiple dive types per dive (#414)
- show all dive types in detail + table column (#414)
- move bulk dive-type edit to the collection lane (#414)
- bulk dive-type collection op with undo (#414)
- multi-select dive types in the dive editor (#414)
- add multi-select dive-type field widget (#414)
- count dives toward each of their types (#414)
- filter by dive-type membership (#414)
- replicate the dive_dive_types junction (#414)
- bulk add/remove/replace dive types (#414)
- persist and hydrate the dive-type set on create/update (#414)
- model dive types as a list on Dive/DiveSummary (#414)
- add dive_dive_types junction table + v92 migration (#414)
- FlSpotCache for chart series memoization
- feature-preserving profile decimator (unwired)
- import Garmin tank cylinder volume into dives
- carry derived cylinder volume on ImportedTank
- derive Garmin cylinder volume from gas consumption
- Apply Z-factors to SAC calculations and statistics

### Bug Fixes

- make invalidateSelfWhen broadcast-safe (review)
- guard tooltip cache against touched-spot count change
- pause stream self-invalidation for Riverpod 3 auto-pause
- seed built-in timestamps from a single value
- backfill built-in dive types for upgraded databases (v93)
- open the type picker via bottom sheet, not MenuAnchor
- fall back to cached SAC segments on an empty list too
- keep SAC-by-segment card on a transient null analysis
- keep deco/tissue/O2 cards on a transient null analysis
- debounce DB change-tick streams to stop sync stutter
- nav move-down button off-by-one after onReorderItem migration
- wrap filter-sheet content in a Material (Flutter 3.44)
- address PR #418 re-review (#414)
- key chart series cache on full ColorScheme, not Brightness
- document OSTC nano short-profile limitation (#394 follow-up)
- address PR #418 review feedback (#414)
- guard v92 seed for minimal-schema tests; move tripwire to v92 (#414)
- complete OSTC nano BLE downloads (#394)
- always evaluate renamed reflected methods in the #318 guard
- keep serial-USB driver methods from R8 obfuscation (#318)
- exclude later dives from weekly OTU rolling total (#407)
- bulk-edit banner auto-hides and is dismissable (#406)

### Refactoring

- simplify invalidateSelfWhen catch-up guard
- round derived cylinder volume numerically with finiteness guard

### Performance

- memoize lineBarsData via ChartSeriesCache
- combineMultiTankPressures O(N^2) -> O(N) merge-walk

### Documentation

- implementation plan
- implementation plan for multiple dive types (#414)
- design spec for multiple dive types per dive (#414)
- D1a measurement result + Plan B decision (S3 > decimation)
- D1a plan (chart memoization + combineMTP O(N) + decimator)
- design + plan for Garmin FIT tank volume import (#403)
- D1 dive profile chart performance design spec
- dive-details + sync-stutter findings, phase 2 ranking
- cold-start measurement findings (scenario 1)
- app performance findings scaffold + measurement environment
- app performance phase 1 measurement runbook
- app performance investigation design spec
- release notes

### Tests

- guarantee FlutterError.onError restore via addTearDown
- align lost-notification drop to MOCK_CHUNK
- unit-test the #318 ProGuard guard; gate patch coverage at 90%

### CI/CD

- restore codecov patch coverage target to 80%
- fix Apple builds + mocks artifact for the Flutter 3.44 upgrade
- bump pinned Flutter to 3.44.4 to match the SDK upgrade

### Chores

- bump version to 1.5.7+109
- drop obsolete iOS-guard overrides (Xcode 26.5)
- upgrade Flutter to 3.44.4 + required migrations
- tier 2 constraint bumps (notifications 22, package_info 9, native_exif 0.8, sqlite3_flutter_libs 0.6)
- tier 1 within-constraint upgrade (flutter pub upgrade)
- stop tracking generated Mockito mocks
- remove dead legacy DiveType enum (#414)

### Other

- docs/ci: address review nits on the #318 serial-driver guard
- Add defensive guard for aberrant input to gas analysis service
- Fix formatting issue that I forgot to check for
- Handle additional issues introduced (or at least exposed by) latest commits
- Implement code review suggestions
- Add missing test file that somehow went AWOL


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
