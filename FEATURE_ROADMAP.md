# Submersion Feature Roadmap
## Comprehensive Development Plan

> **Last Updated:** 2026-02-10
> **Current Version:** 1.1.0 (v1.1 Complete)
> **Status:** v1.0 ✅ COMPLETE | v1.1 ✅ COMPLETE | v1.5 🚧 In Progress
>
> **v1.5 Progress:** Dive Profile & Telemetry (Category 2) ✅ Complete | Profile Visualization (Category 2.1) ✅ Complete | Dive Computer Connectivity (Category 3) ✅ Complete | Cloud Sync (Category 12) ✅ Complete | Statistics (Category 10) ✅ Complete | CCR/SCR Rebreather Support ✅ Complete | Dive Planner (Category 4.5) ✅ Complete | Search & Filtering (Category 10.1) ✅ Complete | Tools & Calculators (Category 11) ✅ Complete | Digital Signatures (Category 7.2) ✅ Complete | Training Dives (Category 8.3) ✅ Complete | Underwater Photography (Category 9.3) ✅ Complete | Maps & Visualization (Category 5.3) ✅ Complete | Certification Cards (Category 8.1) ✅ Complete | Push Notifications (Category 6.3) ✅ Complete | PDF Templates (Category 10.3) ✅ Complete | Wearable Integration v1 (Category 15.5) ✅ Complete | Marine Life Tracking (Category 9.2) ✅ Complete | Universal Import (Category 13.2/13.3) ✅ Complete | Accessibility & Keyboard Navigation (Category 15.3) ✅ Complete | Internationalization & Localization (Category 15.3) ✅ Complete | Custom Fields (Category 1.4) ✅ Complete

---

## Roadmap Phases

| Phase | Timeline | Focus | Status |
|-------|----------|-------|--------|
| **MVP** | Complete | Core dive logging workflow | ✅ Done |
| **v1.0** | Complete | Production-ready with essential features | ✅ Done |
| **v1.1** | Complete | UX improvements, GPS, maps, testing | ✅ Done |
| **v1.5** | 4-6 months | Technical diving & dive computer integration | 📋 Planned |
| **v2.0** | 8-12 months | Advanced features & social | 📋 Planned |
| **v3.0** | 12-18 months | Community platform & AI features | 🔮 Future |

### Status Legend
- ✅ **Implemented** - Feature is complete and working
- 📋 **Planned** - Scheduled for upcoming phase
- 🔮 **Future** - Long-term roadmap item
- 🎯 **Priority** - Critical for next release

---

# Category 1: Core Dive Log Entry

## 1.1 Basic Metadata

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Dive number (auto-increment) | ✅ Implemented | MVP | With gap detection and renumbering |
| Separate entry/exit time fields | ✅ Implemented | v1.1 | Auto-calculated duration |
| Surface interval calculation | ✅ Implemented | v1.1 | Between successive dives |
| Total bottom time | ✅ Implemented | MVP | Auto-calculated from profile |
| Max depth, average depth | ✅ Implemented | MVP | |
| Min/max temperature | ✅ Implemented | MVP | From profile data |
| Dive type (20+ types) | ✅ Implemented | MVP | Recreational, tech, wreck, cave, night, etc. |
| Runtime tracking | ✅ Implemented | v1.5 | Separate field for total runtime (entry→exit) |
| Custom dive types (user-defined) | ✅ Implemented | v1.5 | Database-backed with management UI |
| Auto bottom time calculation | ✅ Implemented | v1.5 | Calculate from dive profile (descent end → ascent start) |

---

## 1.2 Location & Site

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Site name, region, country | ✅ Implemented | MVP | Full site database |
| GPS coordinates | ✅ Implemented | MVP | Lat/long with map view |
| Boat / operator name | ✅ Implemented | v1.0 | Fields added to dive entity |
| Trip grouping | ✅ Implemented | v1.0 | Entity, repository, full UI complete |
| Liveaboard tracking | 📋 Planned | v2.0 | Specialized trip type |

**v1.5 Tasks:**
- [ ] Trip templates (liveaboard, resort week, local weekend)
- [ ] Trip photo galleries (deferred with photos to v2.0)

---

## 1.3 Conditions

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Visibility (numeric + qualitative) | ✅ Implemented | MVP | Enum: Poor/Fair/Good/Excellent |
| Current (direction + strength) | ✅ Implemented | v1.0 | Enums for direction and strength |
| Waves / swell height | ✅ Implemented | v1.0 | |
| Air temperature | ✅ Implemented | MVP | Separate from water temp |
| Entry/exit method | ✅ Implemented | v1.0 | Enums for methods |
| Water type | ✅ Implemented | v1.0 | Fresh, Salt, Brackish |
| Weather API | ✅ Implemented | v1.5 | OpenWeatherMap integration |
| Tide API | ✅ Implemented | v1.5 | World Tides integration |
| Auto-populate conditions | ✅ Implemented | v1.5 | From GPS + date/time |
| Altitude | ✅ Implemented | v1.5 | For altitude dive calculations |

**v1.5 Tasks:**
- [x] Weather API integration (OpenWeatherMap) with historical data
- [x] Tide information integration
- [x] Auto-populate conditions from GPS + date/time

---

## 1.4 Notes & Tags

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Free-text notes | ✅ Implemented | MVP | Rich text field |
| Star rating (1-5) | ✅ Implemented | MVP | |
| Favorite flag | ✅ Implemented | v1.1 | Boolean flag with toggle in list/detail |
| Tags (many-to-many with colors) | ✅ Implemented | v1.1 | Chip selector with autocomplete |
| Tag-based filtering | ✅ Implemented | v1.1 | With tag statistics |
| Custom key:value fields | ✅ Implemented | v1.5 | Freeform metadata with autocomplete key suggestions |
| Custom field search/filter | ✅ Implemented | v1.5 | Full-text + advanced search by key/value |
| Custom fields in export/import | ✅ Implemented | v1.5 | CSV (`custom:` prefix), UDDF (`applicationdata`), PDF |
| Smart collections based on tags | 📋 Planned | v2.0 | Saved filters |

**v1.5 Tasks (Complete):**
- [x] DiveCustomField entity with copyWith and Equatable
- [x] `dive_custom_fields` table (schema v34) with cascade delete and indexes
- [x] DiveCustomFieldRepository with batch loading, key suggestions, replace-all
- [x] DiveRepository integration (load/save custom fields as part of Dive aggregate)
- [x] Riverpod providers (repository singleton + key autocomplete suggestions)
- [x] Dive edit page: reorderable custom fields section with drag handles and autocomplete
- [x] Dive detail page: key:value display section (hidden when empty)
- [x] Full-text search and advanced filter by custom field key/value (EXISTS subquery)
- [x] CSV export/import with `custom:` prefix columns and CSV injection prevention
- [x] UDDF export/import via `<applicationdata>` element
- [x] PDF export with key:value list after notes section
- [x] Localization keys for all 10 languages (11 keys)

---

# Category 2: Dive Profile & Telemetry

## 2.1 Profile Visualization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Time-depth profile chart | ✅ Implemented | MVP | Using fl_chart |
| Temperature overlay | ✅ Implemented | MVP | Toggle on/off |
| Zoom and pan controls | ✅ Implemented | v1.1 | Pinch/scroll zoom, pan when zoomed |
| Touch markers/tooltips | ✅ Implemented | v1.1 | Shows depth, time, temp at touch point |
| Profile markers/events | ✅ Implemented | v1.5 | Descent, safety stop, gas switch, alerts |
| Ascent rate indicators | ✅ Implemented | v1.5 | Color-coded (green <9m/min, yellow 9-12, red >12) |
| Ceiling / NDL curve | ✅ Implemented | v1.5 | Bühlmann ZH-L16C with GF support |
| ppO₂ curve, CNS/OTU | ✅ Implemented | v1.5 | O2ToxicityCard with NOAA tables |
| SAC/RMV overlay | ✅ Implemented | v1.5 | Instantaneous gas consumption |
| Profile export as PNG | ✅ Implemented | v1.5 | Export chart image to Photos or file |
| Range analysis | ✅ Implemented | v1.5 | Drag handles for min/max/avg stats |
| Step-through playback | ✅ Implemented | v1.5 | Animated playback with real-time stats |
| Heart rate overlay | ✅ Implemented | v1.5 | Toggle red HR line on chart |
| Tissue saturation display | ✅ Implemented | v1.5 | 16-compartment bar chart with N2/He |

**v1.5 Tasks:**
- [x] Profile event markers (ProfileEvent entity with type, timestamp, severity)
- [x] Ascent rate calculation and color overlay (green <9m/min, yellow 9-12, red >12)
- [x] NDL curve from Bühlmann implementation
- [x] CNS O₂ toxicity tracking for nitrox/trimix (NOAA exposure tables)
- [x] OTU (Oxygen Tolerance Unit) calculation
- [x] ppO₂ curve display with warnings
- [x] Deco ceiling curve on profile chart
- [x] Interactive timeline updates deco/O2 panels
- [x] SAC/RMV overlay on profile chart
- [x] Profile export as PNG (RepaintBoundary + save to Photos/file)
- [x] Range selection with drag handles (RangeSelectionOverlay widget)
- [x] Range stats panel (min/max/avg for selected portion)
- [x] Step-through playback (PlaybackNotifier with Timer-based advance)
- [x] Playback controls (play/pause, step forward/back, seek slider)
- [x] Playback stats panel (real-time interpolated values at cursor)
- [x] Heart rate overlay toggle (red dashed line with HR data)
- [x] Tissue saturation chart (16-compartment bar chart with N2/He split)

---

## 2.2 Multi-Profile Support

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multiple computers per dive | ✅ Implemented | v1.5 | DiveComputer entity with profiles |
| Profile selector UI | ✅ Implemented | v1.5 | ProfileSelectorWidget for switching |
| Profile comparison (buddies) | 📋 Planned | v2.0 | Side-by-side view |
| Profile merging | 📋 Planned | v2.0 | Combine multiple sources |
| Multi-transmitter support | 📋 Planned | v2.0 | Track multiple tank transmitters (sidemount) |

**v1.5 Tasks:**
- [x] DiveComputer entity (name, manufacturer, model, serial)
- [x] Add `computerId` to dive_profiles table
- [x] UI to select active profile when multiple exist (ProfileSelectorWidget)
- [x] Primary profile indicator for statistics

**v2.0 Tasks:**
- [ ] Side-by-side profile comparison view
- [ ] Buddy profile import (from shared UDDF)

---

## 2.3 Profile Editing

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Smoothing / cleaning bad samples | Done | v2.0 | Weighted moving average with triangular kernel |
| Manual profile drawing | Done | v2.0 | Waypoint-based with linear interpolation |
| Segment editing | Done | v2.0 | Range selection, depth/time shift, delete |
| Outlier detection | Done | v2.0 | Z-score on depth deltas + physical impossibility check |

**v2.0 Tasks:**
- [x] Profile outlier detection algorithm (sudden depth jumps)
- [x] Smoothing algorithm (moving average)
- [x] Manual profile editor with touch/mouse drawing
- [x] Segment selection and adjustment UI
- [ ] Profile export as PNG image for sharing

---

# Category 3: Dive Computer Connectivity

## 3.1 Connectivity Types

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| USB cable transfers | ✅ Implemented | v1.5 | Via libdivecomputer FFI |
| Bluetooth Classic | ✅ Implemented | v1.5 | flutter_blue_plus |
| Bluetooth LE (BLE) | ✅ Implemented | v1.5 | flutter_blue_plus with manufacturer protocols |
| Infrared (legacy) | 🔮 Future | v3.0 | Limited hardware support |
| Wi-Fi / cloud devices | 📋 Planned | v2.0 | Garmin, Shearwater cloud API |

**v1.5 Tasks (Critical Path):**
- [x] Integrate libdivecomputer via FFI (Dart bindings to C library)
- [x] Device detection and pairing UI (multi-step wizard)
- [x] Bluetooth connection manager (scanning, pairing, reconnection)
- [x] USB device enumeration and selection
- [x] Progress indicator during download (% complete, dive count)

---

## 3.2 Device Support

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| 300+ dive computer models | ✅ Implemented | v1.5 | Via libdivecomputer + device library |
| Per-device presets | ✅ Implemented | v1.5 | Save connection settings |
| Favorite devices | ✅ Implemented | v1.5 | Device list page with quick access |

**v1.5 Tasks:**
- [x] Create `dive_computers` table (name, manufacturer, model, connection_type, last_used)
- [x] Device library with 300+ model definitions from libdivecomputer
- [x] Auto-detection of device model via USB VID/PID or BT service UUID
- [x] Device configuration persistence (BT address, connection params)
- [x] Manufacturer-specific BLE protocols (Aqualung, Shearwater, Mares, Suunto)

---

## 3.3 Download Behavior

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Download new dives only | ✅ Implemented | v1.5 | Uses lastDownload timestamp |
| Force download all | ✅ Implemented | v1.5 | Toggle in download settings |
| Auto-download when connected | 📋 Planned | v2.0 | Background sync |
| Duplicate detection | ✅ Implemented | v1.5 | Fuzzy match on time+depth+duration |

**v1.5 Tasks:**
- [x] Store `last_download_timestamp` per dive computer
- [x] Duplicate detection algorithm (fuzzy match on datetime + depth within tolerance)
- [x] "New Dives" vs "All Dives" toggle in download wizard
- [x] Conflict resolution (skip, replace, import as new)

**v2.0 Tasks:**
- [ ] Background BLE scanning and auto-download (mobile)
- [ ] Notification when new dives detected

---

## 3.4 Device Management

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Rename dive computers | ✅ Implemented | v1.5 | Edit dialog in device detail |
| Associate dives with computer | ✅ Implemented | v1.5 | computerId in dive_profiles table |
| Firmware update via app | 📋 Planned | v2.0 | Shearwater-specific |
| Remote configuration | 📋 Planned | v2.0 | Set gases, alarms, units |

**v1.5 Tasks:**
- [x] Add `computer_id` to dives table (which device imported this dive)
- [x] Computer detail page showing all dives from that device
- [x] Computer stats (total dives, deepest, longest, avg depth, temp range, date range)

**v2.0 Tasks:**
- [ ] Firmware update wizard (download firmware, flash via BLE)
- [ ] Computer settings sync (read/write computer config)

---

# Category 4: Gases, Tanks & Technical Diving

## 4.1 Multiple Tanks Per Dive

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multi-tank support | ✅ Implemented | MVP | Unlimited tanks with add/remove buttons |
| Tank volume, pressures | ✅ Implemented | MVP | Start/end/working pressure |
| Tank material | ✅ Implemented | v1.1 | Steel, Aluminum, Carbon Fiber |
| Tank role | ✅ Implemented | v1.1 | Back gas, stage, deco, bailout, sidemount, pony |
| Tank presets | ✅ Implemented | v1.1 | AL40/63/80, HP80/100/120, LP85, Steel 10/12/15L |
| Save custom tank presets | ✅ Implemented | v1.5 | User-defined configurations |

---

## 4.2 Gas Composition

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| O₂ %, He %, N₂ balance | ✅ Implemented | MVP | Air, Nitrox, Trimix |
| Gas naming | ✅ Implemented | v1.1 | "EAN32", "TMX 18/45" auto-generated |
| Gas mix templates | ✅ Implemented | v1.1 | Air, EAN32/36/40/50, O₂, Trimix blends |
| Gas changes on profile | ✅ Implemented | v1.5 | Mark switch points |

**v1.5 Tasks:**
- [x] Gas switch events on profile (table: `gas_switches` with timestamp, tank_id)
- [x] Profile segment coloring based on active gas
- [x] Gas switch markers on profile chart

---

## 4.3 Calculated Metrics

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| SAC / RMV (per dive) | ✅ Implemented | MVP | Surface Air Consumption Rate |
| MOD calculation | ✅ Implemented | MVP | Maximum Operating Depth in entity |
| END calculation | ✅ Implemented | MVP | Equivalent Narcotic Depth in entity |
| CNS% tracking | ✅ Implemented | v1.5 | NOAA exposure tables with warnings |
| OTU tracking | ✅ Implemented | v1.5 | Daily limit tracking with % display |
| ppO₂ monitoring | ✅ Implemented | v1.5 | Warning/critical thresholds (1.4/1.6 bar) |
| SAC per segment | 📋 Planned | v1.5 | Time-based or depth-based segments |
| SAC per cylinder | 📋 Planned | v1.5 | For multi-tank dives |

**v1.5 Tasks:**
- [x] CNS% calculation per dive (accumulated O₂ exposure using NOAA tables)
- [x] OTU calculation (Oxygen Tolerance Units with daily limit tracking)
- [x] CNS/OTU display on dive detail page (O2ToxicityCard)
- [x] ppO₂ curve calculation and warnings
- [x] 68 unit tests for O2 toxicity calculations
- [x] Segment SAC calculation (5-minute segments or depth-based)
- [x] SAC trend chart (line chart showing SAC over time for a dive)

---

## 4.4 Deco & Algorithms

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Bühlmann ZH-L16C with GF | ✅ Implemented | v1.5 | Full algorithm with 16 compartments |
| Gradient Factors | ✅ Implemented | v1.5 | GF Low/High configurable in settings |
| NDL display | ✅ Implemented | v1.5 | Real-time NDL on profile chart |
| Ceiling calculation | ✅ Implemented | v1.5 | M-values with gradient factors |
| Tissue loading display | ✅ Implemented | v1.5 | 16-compartment bar chart (DecoInfoPanel) |
| TTS calculation | ✅ Implemented | v1.5 | Time To Surface with deco stops |
| Deco stop schedule | ✅ Implemented | v1.5 | Stop depth/time with deep stop support |
| Calculated vs DC ceiling | 📋 Planned | v1.5 | Compare app calc with computer |
| OC/CCR support | ✅ Implemented | v1.5 | Open Circuit / Closed Circuit Rebreather |
| SCR support | ✅ Implemented | v1.5 | Semi-Closed Rebreather (moved from v2.0) |
| Setpoints, diluent, bailout | ✅ Implemented | v1.5 | CCR-specific fields |

**v1.5 Tasks (Deco Algorithm Implementation):**
- [x] Implement Bühlmann ZH-L16C algorithm in Dart
- [x] Gradient Factors (GF Low/High) configuration in settings
- [x] 16-compartment tissue loading calculation
- [x] NDL calculation for any depth/gas combination
- [x] Ceiling calculation (M-values with GF)
- [x] Deco schedule generation (stop depth/time)
- [x] Display NDL/ceiling on profile chart
- [x] TTS (Time To Surface) calculation
- [x] DecoInfoPanel with tissue loading visualization
- [x] 141 unit tests for deco algorithms

**v1.5 CCR/SCR Support (Complete):**
- [x] Add `dive_mode` enum (OC, CCR, SCR) to dives table
- [x] CCR-specific fields: setpoint(s), diluent, bailout gas
- [x] Setpoint changes as profile events
- [x] ppO₂ calculation and display (constant for CCR, variable for SCR)
- [x] SCR support: injection rate, supply gas, loop FO₂ calculation
- [x] SCR types: CMF (Constant Mass Flow), PASCR (Passive Addition), ESCR
- [x] Scrubber tracking: type, rated duration, remaining time
- [x] Diluent/supply gas templates (trimix diluents, enriched nitrox for SCR)
- [x] Dive mode selector UI with OC/CCR/SCR segmented button
- [x] CCR settings panel (setpoints, diluent gas selector, scrubber info)
- [x] SCR settings panel (type selector, injection rate, supply gas, loop O₂ measurements)

---

## 4.5 Planning Utilities

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Dive planner (multi-level) | ✅ Implemented | v1.5 | Plan dives before doing them |
| Multi-gas planning | ✅ Implemented | v1.5 | Gas switches, deco gases |
| Repetitive dive planning | ✅ Implemented | v1.5 | Surface interval, tissue loading |
| Gas consumption projections | ✅ Implemented | v1.5 | Based on SAC history |
| What-if scenarios | 📋 Planned | v2.0 | Deeper/longer/different gas |
| Lost gas scenarios | 📋 Planned | v2.0 | Plan for lost decompression gas |
| Turn pressure planning | 📋 Planned | v2.0 | Calculate gas turn pressures for penetration dives |
| Range plans | 📋 Planned | v2.0 | Multiple profiles with different depths/times |

**v1.5 Tasks:**
- [x] Dive Planner page with depth/time segment editor
- [x] Add segments (depth, duration, gas mix)
- [x] Real-time deco calculation as user edits plan
- [x] Display: runtime, TTS, NDL, ceiling, gas consumed per tank
- [x] Save planned dives to database (mark as `isPlanned: true`)
- [x] Convert planned dive to actual dive after logging
- [x] Quick Plan dialog for simple rectangular profiles
- [x] Tank management with gas mix configuration
- [x] Profile chart visualization of planned dive

**v2.0 Tasks:**
- [ ] Repetitive dive planner with tissue loading from previous dive
- [ ] "Extend dive" tool (add 5 mins at depth, recalculate deco)
- [ ] "Add safety" tool (extend safety stop, add deep stop)

---

# Category 5: Locations, Dive Sites & Maps

## 5.1 Dive Site Database

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Manage sites, regions, countries | ✅ Implemented | MVP | Full CRUD |
| Depth range (min/max) | ✅ Implemented | v1.1 | |
| Difficulty levels | ✅ Implemented | v1.1 | Beginner/Intermediate/Advanced/Technical |
| Hazards, access notes | ✅ Implemented | v1.1 | Free-text fields |
| Mooring numbers, parking | ✅ Implemented | v1.1 | For boat/shore diving |
| Common marine life | ✅ Implemented | v1.5 | Link species to sites |

**v1.5 Tasks:**
- [x] Many-to-many relationship between sites and species (common sightings)
- [x] Display "Commonly Seen" species list on site detail page

---

## 5.2 GPS Integration

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Manual GPS entry | ✅ Implemented | MVP | Lat/long fields |
| Capture GPS from phone | ✅ Implemented | v1.1 | "Use My Location" button |
| Nearby site suggestions | ✅ Implemented | v1.1 | On dive create |
| Reverse geocoding | ✅ Implemented | v1.1 | Auto-populate country/region from GPS |
| Map-based location picker | ✅ Implemented | v1.1 | Pick location from interactive map |
| GPS from photo EXIF | 📋 Planned | v1.5 | Extract and suggest site |

**v1.5 Tasks:**
- [ ] EXIF parsing from photo attachments
- [ ] If photo has GPS and dive doesn't, suggest using photo GPS
- [ ] Bulk site creation from photo library

---

## 5.3 Maps & Visualization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Map of all dive sites | ✅ Implemented | MVP | Using flutter_map + OpenStreetMap |
| Marker clustering | ✅ Implemented | v1.1 | Smooth animated zoom on cluster tap |
| Color-coded markers | ✅ Implemented | v1.1 | Based on dive count or rating |
| Dive Activity Map | ✅ Implemented | v1.5 | Heat map of all dives with clustered site markers |
| Offline maps | ✅ Implemented | v1.5 | Tile caching via FMTC with region downloads |
| Site filtering | ✅ Implemented | v1.5 | Filter sites by country, region, difficulty, depth, rating |

**v1.5 Tasks (Complete):**
- [x] Offline map tile caching using flutter_map_tile_caching (FMTC)
- [x] Download map region for offline use (bounding box region selector)
- [x] Heat map visualization of dive activity (intensity = dive count)
- [x] Activity Map page with heat map toggle and fit-all-sites
- [x] Site filtering with active filter bar and chips
- [x] Map View icon in toolbar (Dives and Sites pages)

---

## 5.4 External Data Sources

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Online dive site database lookup | 📋 Planned | v2.0 | Import from community sources |
| Dive site reviews | 📋 Planned | v2.0 | User-generated content |

**v2.0 Tasks:**
- [ ] Integration with public dive site APIs (e.g., Open Dive Sites, PADI Travel)
- [ ] Import site details from online sources
- [ ] User reviews and ratings (requires backend)

---

# Category 6: Gear & Equipment Management

## 6.1 Gear Inventory

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Track 20+ equipment types | ✅ Implemented | MVP | BCD, reg, fins, suit, computer, etc. |
| Serial, purchase date, cost | ✅ Implemented | MVP | All tracked |
| Size, notes, status | ✅ Implemented | v1.0 | S/M/L/XL or numeric |
| Filter equipment by status | ✅ Implemented | v1.1 | Dropdown for all statuses |
| Photos of gear | 📋 Planned | v2.0 | Deferred with photos |

---

## 6.2 Gear Groupings / "Bags"

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Equipment sets | ✅ Implemented | MVP | Named collections |
| Quick-select sets per dive | ✅ Implemented | v1.1 | Apply set from dive edit |
| Save equipment as set | ✅ Implemented | v1.1 | Create set from current dive's equipment |

---

## 6.3 Maintenance

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Service history | ✅ Implemented | MVP | Last service date, interval |
| Service reminders | ✅ Implemented | MVP | Visual warnings |
| Service records detail | ✅ Implemented | v1.0 | Full CRUD with UI |
| Push notifications | ✅ Implemented | v1.5 | For overdue service |

**v1.5 Tasks (Complete):**
- [x] Local notifications for service due dates (NotificationScheduler service)
- [x] Configurable reminder advance in settings (7 days, 14 days, 30 days before due)
- [x] Per-equipment notification override on equipment edit page
- [x] Background service for notification refresh
- [x] Deep linking from notification taps to equipment detail
- [x] iOS/macOS notification configuration
- [x] Android notification and boot receiver configuration
- [x] Desktop platforms gracefully skip notification services

**v2.0 Tasks:**
- [ ] Service log export to PDF (professional format with full history)

---

## 6.4 Per-Dive Gear Usage

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Gear selected per dive | ✅ Implemented | MVP | Many-to-many relationship |
| Weight system & amount | ✅ Implemented | v1.0 | Belt, integrated, trim, ankle, backplate |
| Multiple weight entries | ✅ Implemented | v1.0 | e.g., integrated + trim weights |
| Weight calculator | ✅ Implemented | v1.0 | Based on exposure suit, tank, water type |
| Gas / cylinder config | ✅ Implemented | MVP | Per-tank gas mixes |

---

# Category 7: People - Buddies, Instructors, Agencies

## 7.1 Buddy Management

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Buddy contact list | ✅ Implemented | v1.0 | Full entity with CRUD |
| Cert levels, agencies | ✅ Implemented | v1.0 | Stored on buddy entity |
| Mark buddies per dive | ✅ Implemented | v1.0 | Many-to-many with roles |
| Roles | ✅ Implemented | v1.0 | Buddy, Guide, Instructor, Student, Solo |
| Buddy detail page | ✅ Implemented | v1.0 | Shared dive history and stats |
| Import from contacts | ✅ Implemented | v1.5 | Mobile contact picker |
| Share dives with buddy | ✅ Implemented | v1.5 | UDDF export via share sheet |

**v1.5 Tasks (Complete):**
- [x] Import buddies from contacts (mobile)
- [x] Share dives with buddies (export UDDF, send via email/messaging)

---

## 7.2 Digital Signatures

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Buddy signatures | ✅ Implemented | v1.5 | Student/observer sign-off |
| Instructor signatures | ✅ Implemented | v1.5 | Per-dive signatures for training logs |
| Signature capture | ✅ Implemented | v1.5 | Touch/stylus canvas drawing |
| Signatures in PDF export | ✅ Implemented | v1.5 | Display in exported dive logs |

**v1.5 Tasks (Complete):**
- [x] SignatureCaptureWidget (canvas drawing with save as PNG)
- [x] SignatureStorageService (Media table with fileType='instructor_signature')
- [x] SignatureDisplayWidget (preview, full-view dialog, badge)
- [x] Integration on dive detail page (conditional for training dives)
- [x] Buddy signatures (BuddySignaturesSection, request sheet, save with role)
- [x] Display signatures in PDF export (instructor + buddy signatures)
- [x] BLOB storage for signatures (image_data column for self-contained backup/sync)

---

## 7.3 Dive Centers / Shops

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Track shops/centers | ✅ Implemented | v1.0 | Full entity with CRUD |
| Link dives to centers | ✅ Implemented | v1.0 | FK on dives table |
| Boat names | ✅ Implemented | v1.0 | Field on dive entity |
| Dive center detail page | ✅ Implemented | v1.0 | All dives at center, stats |

---

# Category 8: Training, Certifications & Medical Info

## 8.1 Certifications

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Store cert levels, agencies | ✅ Implemented | v1.0 | Full entity with CRUD |
| Cert numbers, issue dates | ✅ Implemented | v1.0 | |
| Instructor names | ✅ Implemented | v1.0 | |
| Expiry warnings | ✅ Implemented | v1.0 | Red/yellow badges |
| Common agencies enum | ✅ Implemented | v1.0 | PADI, SSI, NAUI, SDI, TDI, GUE, RAID |
| Common levels enum | ✅ Implemented | v1.0 | Open Water through Instructor |
| Scanned card images | ✅ Implemented | v1.5 | Front/back photos stored as BLOB in database |

**v1.5 Tasks (Complete):**
- [x] Add photo_front and photo_back BLOB columns to certifications table
- [x] ImagePicker integration for capturing/selecting card photos
- [x] Display card photos on certification detail page with full-screen viewer
- [x] Photos stored directly in database for easy backup/sync

---

## 8.2 Digital Cards (eCards)

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| eCard wallet | 📋 Planned | v1.5 | Display certs in wallet format |
| QR codes | 📋 Planned | v2.0 | Scannable verification |

**v1.5 Tasks:**
- [ ] Certification wallet view (card-style UI)
- [ ] Export cert card as image (shareable)

**v2.0 Tasks:**
- [ ] Generate QR codes for certs (encode cert number, agency, level)
- [ ] QR code verification (backend required)

---

## 8.3 Training Dives

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Mark dives as training | ✅ Implemented | MVP | "Training" dive type exists |
| Course entity | ✅ Implemented | v1.5 | Full CRUD with instructor, certification link |
| Associate with courses | ✅ Implemented | v1.5 | Dive-course many-to-one, course picker |
| Instructor comments | ✅ Implemented | v1.5 | Using existing notes field |
| E-signatures | ✅ Implemented | v1.5 | Per-dive instructor signatures |
| Course-Certification linking | ✅ Implemented | v1.5 | Bidirectional link with picker UI |
| Training log export | ✅ Implemented | v1.5 | PDF with instructor signatures |

**v1.5 Tasks (Complete):**
- [x] Course entity (name, agency, start_date, completion_date, instructor, cert_id)
- [x] Course UI pages (list with filtering, detail, edit)
- [x] CoursePicker widget for dive edit page
- [x] Bidirectional course-certification navigation
- [x] Signature capture and display on dive detail page
- [x] Link courses to earned certifications (bidirectional)
- [x] Training log export to PDF (ExportService.exportCourseTrainingLogToPdf)
- [x] Export action in Course detail page popup menu

---

## 8.4 Personal & Medical Data

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Medical clearance dates | ✅ Implemented | v1.5 | Expiry tracking with 30-day warning |
| Emergency contacts | ✅ Implemented | v1.5 | Primary and secondary contacts |
| Medications tracking | ✅ Implemented | v1.5 | Text field in diver profile |
| Medical documents | 📋 Planned | v2.0 | PDF storage |

**v1.5 Tasks (Complete):**
- [x] Add Medical/Personal section to Diver Edit page
- [x] Two emergency contacts (primary + secondary) with name, phone, relationship
- [x] Medical clearance expiry date with visual warnings (expired/expiring soon)
- [x] Blood type, allergies, medications fields
- [x] Helper methods: `isMedicalClearanceExpired`, `isMedicalClearanceExpiringSoon`

**v2.0 Tasks:**
- [ ] Medical document storage (PDF of medical clearance)
- [ ] Export profile with certs + medical for dive operations

---

# Category 9: Environment, Wildlife & Photography

## 9.1 Environmental Details

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Water type | ✅ Implemented | v1.0 | Fresh, salt, brackish |
| Hazards | ✅ Implemented | v1.1 | Site-level hazards field |
| Entry altitude | ✅ Implemented | v1.5 | For altitude dive tables |
| Tides | ✅ Implemented | v1.5 | World Tides API integration |

**v1.5 Tasks:**
- [x] Tide API integration (World Tides)
- [x] Display tide state at dive time
- [x] Altitude field with warning if >300m (affects NDL)

---

## 9.2 Marine Life Tracking

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Species database | ✅ Implemented | MVP | 511 pre-seeded species with scientific names |
| Tag species per dive | ✅ Implemented | MVP | Sightings with counts |
| Taxonomy class | ✅ Implemented | v1.5 | taxonomy_class column, is_built_in flag |
| Species management UI | ✅ Implemented | v1.5 | Settings > Manage > Species (list, search, filter, add, edit, delete) |
| Species detail page | ✅ Implemented | v1.5 | Description, per-species statistics, navigation from stats/dive detail |
| Stats per species | ✅ Implemented | v1.5 | Total sightings, dive count, depth range, top sites, first/last seen |
| Reset to defaults | ✅ Implemented | v1.5 | Restore built-in species to original values |
| Species photos | 📋 Planned | v2.0 | Local or remote images |
| Distribution map | 📋 Planned | v2.0 | Map of sightings |
| AI species identification | 📋 Planned | v2.0 | Upload photo, AI identifies species |
| Offline species ID | 📋 Planned | v2.0 | Works without internet connection |

**v1.5 Tasks (Complete):**
- [x] Add `taxonomy_class`, `is_built_in` columns to species table (schema v32)
- [x] Expand species database from 36 to 511 species (JSON asset with scientific names, taxonomy, descriptions)
- [x] Species seed service (JSON asset loader with static cache)
- [x] Species management page (search, category filter, custom/built-in sections)
- [x] Species edit page (add/edit form with all fields)
- [x] Species detail page (header, taxonomy badge, description, statistics section)
- [x] Per-species statistics (total sightings, dive count, depth range, top 5 sites, first/last sighting)
- [x] Reset to defaults (restore built-in species, preserve custom species and sighting data)
- [x] Navigation links from statistics marine life page and dive detail sighting tiles
- [x] 30 tests (repository CRUD, statistics queries, entity behavior)

**v2.0 Tasks:**
- [ ] Species photo library (local or remote images)
- [ ] Species distribution map (heatmap of sightings)
- [ ] "Life list" progress tracker (total species seen)
- [ ] Rare species badges
- [ ] AI-powered species identification from photos (ML model)
- [ ] Offline species recognition database
- [ ] Species identification confidence scores

---

## 9.3 Underwater Photography

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Attach photos/videos to dives | ✅ Implemented | v1.5 | Photo picker with time range filtering |
| Auto-match by timestamp | ✅ Implemented | v1.5 | EXIF datetime matching with tolerance |
| Display photo gallery | ✅ Implemented | v1.5 | DiveMediaSection widget on dive detail |
| Full-screen photo viewer | ✅ Implemented | v1.5 | PhotoViewerPage with pinch-zoom, swipe |
| Metadata overlay | ✅ Implemented | v1.5 | Depth, temp, elapsed time on photos |
| Write dive data to EXIF | ✅ Implemented | v1.5 | In-place modification via native_exif |
| Photo thumbnails | ✅ Implemented | v1.5 | Dynamic loading from device library |
| Video support in logs | 📋 Planned | v2.0 | Attach and play videos |
| Tag species in photos | 📋 Planned | v2.0 | Image annotation |
| Color correction | 📋 Planned | v2.0 | Blue filter removal |
| Shareable dive cards | 📋 Planned | v2.0 | Generate visual summary for social media |
| Depth/time overlay | ✅ Implemented | v1.5 | MiniDiveProfileOverlay on photo viewer |

**v1.5 Tasks (Complete):**
- [x] Photo picker in dive detail page (time range filtering based on dive times)
- [x] Link photos to dives via Media table (many-to-many)
- [x] Media storage strategy (reference to device photo library via platformAssetId)
- [x] Display photo gallery on dive detail page (DiveMediaSection widget)
- [x] Full-screen photo viewer with pinch-zoom and swipe navigation (PhotoViewerPage)
- [x] Metadata overlay showing depth, temperature, elapsed time (BottomMetadataOverlay)
- [x] EXIF datetime parsing for auto-matching photos to dives
- [x] Photo thumbnail generation and caching (assetThumbnailProvider)
- [x] Write dive metadata to photo EXIF (ExifWriteService with native_exif)
- [x] EXIF tags: GPSAltitude (depth), ImageDescription (dive summary)
- [x] Long-press to unlink photo from dive

**v2.0 Tasks:**
- [ ] Caption and datetime editing per photo
- [ ] Export dive with photos (ZIP archive)
- [ ] Bulk photo import with auto-match to dives
- [ ] GPS extraction from photos (suggest site creation)
- [ ] Species tagging in photos (tap to tag, bounding box)
- [ ] Species recognition suggestions (ML model)
- [ ] Blue/green color cast removal filter
- [ ] Underwater white balance correction

---

# Category 10: Search, Filters, Statistics & Reports

## 10.1 Search & Filtering

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Full-text search | ✅ Implemented | MVP | Notes, sites, buddies |
| Filter by date range | ✅ Implemented | MVP | |
| Filter by location, depth | ✅ Implemented | MVP | |
| Bulk delete with undo | ✅ Implemented | v1.0 | Multi-select mode |
| Filter by tags, gas, gear | ✅ Implemented | v1.5 | Multi-select equipment, gas mix O2%, rating, duration |
| Advanced Search page | ✅ Implemented | v1.5 | Full-page search form at `/dives/search` |
| Bulk export | ✅ Implemented | v1.5 | Export selected dives to CSV/UDDF/PDF |
| Bulk edit | ✅ Implemented | v1.5 | Change trip, add/remove tags on multiple dives |
| Saved filters ("Smart Logs") | 📋 Planned | v2.0 | Persistent filter sets |

**v1.5 Tasks (Complete):**
- [x] Expand filter UI with all available criteria (buddy name, equipment, gas mix O2%, rating, duration)
- [x] "Advanced Search" page with collapsible sections for all filter options
- [x] Bulk export (export selected dives to CSV/UDDF/PDF from selection mode)
- [x] Bulk edit (change trip, add/remove tags on multiple dives)
- [x] Repository bulk methods (`bulkUpdateTrip`, `bulkAddTags`, `bulkRemoveTags`)

**v2.0 Tasks:**
- [ ] Save filter configurations as "Smart Logs"
- [ ] Smart Log management (name, description, icon)
- [ ] Quick access to Smart Logs from home page

---

## 10.2 Statistics

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Total dives, bottom time | ✅ Implemented | MVP | |
| Breakdown by year/country/site | ✅ Implemented | MVP | Top sites chart |
| Depth/time histograms | ✅ Implemented | MVP | Depth distribution |
| Records page | ✅ Implemented | v1.0 | Deepest, longest, coldest, warmest, first, last |
| SAC trends | ✅ Implemented | v1.5 | Monthly average over 5 years |
| Temperature graphs | ✅ Implemented | v1.5 | Water temp by month (min/avg/max) |
| Dive type breakdown | ✅ Implemented | v1.5 | Pie chart by dive type |

**v1.5 Tasks:**
- [x] SAC trend line chart (average SAC per month over last 5 years)
- [x] Temperature preference chart (water temp by month with min/avg/max)
- [x] Dive frequency chart (dives per year bar chart)
- [x] Dive type breakdown (pie chart)
- [x] Gas mix usage (pie chart showing Air/Nitrox/Trimix distribution)
- [x] Time pattern charts (day of week, time of day, seasonal)
- [x] Surface interval statistics (avg/min/max)
- [x] Depth progression trend (monthly max depth over 5 years)
- [x] Bottom time trend (average duration by month)
- [x] Cumulative dive count chart

**v2.0 Tasks:**
- [ ] Advanced analytics dashboard (customizable widgets)
- [ ] Year-in-review summary (auto-generated at year end)

---

## 10.3 Reports & Printing

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| PDF logbook export | ✅ Implemented | MVP | Basic layout |
| Signatures in PDF | ✅ Implemented | v1.5 | Instructor + buddy signatures |
| Multiple PDF templates | ✅ Implemented | v1.5 | Simple, Detailed, Professional, PADI-style, NAUI-style |
| Page size options | ✅ Implemented | v1.5 | A4 and Letter sizes |
| Certification cards in PDF | ✅ Implemented | v1.5 | Optional inclusion with front/back images |
| Custom report designer | 📋 Planned | v2.0 | Drag-drop fields |

**v1.5 Tasks (Complete):**
- [x] Display instructor and buddy signatures in PDF export
- [x] Multiple PDF templates (Simple, Detailed, Professional, PADI-style, NAUI-style)
- [x] Template selection in export dialog
- [x] Professional template with space for signatures, stamps
- [x] Include certification cards in PDF export

**v2.0 Tasks:**
- [ ] Custom report builder (select fields, layout, sorting)
- [ ] Save custom report templates
- [ ] Export to Excel/CSV with custom fields

---

# Category 11: Planning & Calculators

## 11.0 Tools Landing Page

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Tools hub page | ✅ Implemented | v1.5 | Unified entry point at `/tools` |
| Calculator navigation | ✅ Implemented | v1.5 | Cards for Deco, Gas, Weight calculators |

**v1.5 Tasks:**
- [x] Tools landing page at `/tools` with card-based navigation
- [x] NavigationRail "Calculator" destination links to Tools page
- [x] Consolidated "Tools" entry in More menu (mobile)

---

## 11.1 Dive Planner

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Open-circuit planner | ✅ Implemented | v1.5 | Multi-level plans |
| Multi-gas plans | ✅ Implemented | v1.5 | With deco stops |
| Repetitive dive planning | ✅ Implemented | v1.5 | Surface interval, tissue loading |
| Save planned dives | ✅ Implemented | v1.5 | Mark as "isPlanned" in DB |

*See "4.5 Planning Utilities" for detailed task list*

---

## 11.2 Deco Calculator

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Real-time simulation | ✅ Implemented | v1.5 | Interactive depth/time sliders |
| NDL, ceiling, tissue loading | ✅ Implemented | v1.5 | Visual display with 16-compartment chart |

**v1.5 Tasks:**
- [x] Deco Calculator page (separate from planner) - `lib/features/deco_calculator/`
- [x] Sliders for depth (0-60m), time (0-120min), gas mix (O2/He with presets)
- [x] Real-time display of: NDL, ceiling, TTS, tissue loading bar chart (16 compartments)
- [x] Gas safety warnings: ppO2, MOD, END with color-coded status
- [x] "Add to Planner" button to convert calc to plan

---

## 11.3 Gas Calculators

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| MOD calculator | ✅ Implemented | MVP | In GasMix entity + dedicated calculator |
| EAD / END calculator | ✅ Implemented | MVP | In GasMix entity |
| Best-mix calculator | ✅ Implemented | v1.5 | Target depth → O₂% |
| Gas consumption calculator | ✅ Implemented | v1.5 | Based on SAC, depth, time |
| Rock-bottom calculator | ✅ Implemented | v1.5 | Emergency gas reserve |

**v1.5 Tasks:**
- [x] Calculators page with tabs: MOD, Best Mix, Gas Consumption, Rock Bottom - `lib/features/gas_calculators/`
- [x] MOD: Input O₂%, ppO₂ limit → Output MOD (with feet conversion)
- [x] Best Mix: Input target depth, ppO₂ limit → Output ideal O₂% (with common mix suggestions)
- [x] Gas Consumption: Input depth, time, SAC, tank size → Output pressure consumed (with breakdown)
- [x] Rock Bottom: Input depth, ascent rate, SAC, buddy SAC, tank size → Output min reserve pressure (buddy breathing scenario)

---

## 11.4 Convenience Tools

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Surface interval planner | 📋 Planned | v1.5 | How long to wait |
| Altitude conversion | ✅ Implemented | v1.5 | Altitude dive tables with pressure calculator |

**v1.5 Tasks:**
- [ ] Surface Interval Tool: Input previous dive (depth, time, gas) + desired next dive → Output min surface interval
- [ ] Display tissue loading chart showing saturation decreasing over time
- [x] AltitudeCalculator with ISA barometric formula (pressure from altitude)
- [x] AltitudeGroup classification (Sea Level, Group 1-3, Extreme) with PADI/SSI compatibility
- [x] Equivalent Ocean Depth (EOD) calculation for altitude diving adjustments
- [x] Tiered warning levels (info/caution/warning/severe) based on altitude group
- [x] Altitude field integration in dive sites, dive log, and dive planner
- [x] Unit-aware display (meters/feet) respecting user settings
- [x] 36 unit tests for altitude calculator

---

# Category 12: Cloud Sync, Backup & Multi-Device

## 12.1 Cloud Accounts

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Anonymous usage | ✅ Implemented | MVP | Local-first, no account required |
| iCloud integration | ✅ Implemented | v1.5 | iOS/macOS cloud sync |
| Google Drive integration | ✅ Implemented | v1.5 | Cross-platform cloud sync |
| Cloud sync UI | ✅ Implemented | v1.5 | Provider selection, sync status, conflicts |

**v2.0 Tasks:**
- [ ] Backend service for user accounts (Firebase, Supabase)
- [ ] User authentication (email/password, OAuth)
- [ ] Privacy policy and data handling docs

---

## 12.2 Synchronization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Desktop ↔ mobile sync | ✅ Implemented | v1.5 | Via iCloud/Google Drive |
| Conflict detection | ✅ Implemented | v1.5 | Tracks conflicts in SyncRecords |
| Conflict resolution UI | ✅ Implemented | v1.5 | Dialog for resolving conflicts |
| Sync status indicator | ✅ Implemented | v1.5 | Last sync time, pending changes |
| Multi-device support | ✅ Implemented | v1.5 | Via cloud storage providers |
| Web sync | 📋 Planned | v2.0 | Requires backend service |

**v1.5 Tasks (Complete):**
- [x] Drift schema with `last_modified_at`, `device_id`, `is_deleted` (SyncMetadata, SyncRecords, DeletionLog tables)
- [x] Sync engine (bidirectional via cloud storage)
- [x] Conflict detection and resolution UI
- [x] Sync status indicator (last synced, pending changes)
- [x] Reset sync state option

**v2.0 Tasks:**
- [ ] Web platform sync (requires backend)
- [ ] "Force push" and "force pull" options for troubleshooting

---

## 12.3 Backup

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Local backup export | ✅ Implemented | MVP | Full SQLite export |
| Cloud backup via iCloud | ✅ Implemented | v1.5 | Apple platforms |
| Cloud backup via Google Drive | ✅ Implemented | v1.5 | Cross-platform |
| Custom folder sync | ✅ Implemented | v1.5 | Dropbox/OneDrive via folder selection |

**v2.0 Tasks:**
- [x] Automatic scheduled backups
- [x] Backup history (keep last N backups)
- [x] One-click restore from cloud backup

---

## 12.4 Offline Behavior

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Full offline logging | ✅ Implemented | MVP | Local-first design |
| Deferred sync | 📋 Planned | v2.0 | Queue changes when offline |

**v2.0 Tasks:**
- [ ] Offline queue for pending sync operations
- [ ] Auto-sync when connectivity restored
- [ ] Sync conflict warnings and resolution

---

# Category 13: Import, Export & Interoperability

## 13.1 File Formats

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| CSV import/export | ✅ Implemented | MVP | Dives, sites, equipment |
| UDDF import/export | ✅ Implemented | MVP | v3.2.0 compliant |
| UDDF buddy/guide export | ✅ Implemented | v1.1 | Export to both legacy and app-specific fields |
| PDF export | ✅ Implemented | MVP | Printable logbook |
| Excel export | ✅ Implemented | v1.5 | Multi-sheet .xlsx with stats |
| Google Earth KML export | ✅ Implemented | v1.5 | Site placemarks with dive history |
| DAN DL7 export | ⏸️ Deferred | v2.0 | No public spec available |
| ePub export | 📋 Planned | v2.0 | Electronic book format for travel |
| HTML export | 📋 Planned | v2.0 | Web-viewable logbook |

**v1.5 Tasks:**
- [x] Excel export with multiple sheets (dives, sites, equipment, statistics)
- [x] KML export (placemark per dive site with description bubble)

**v2.0 Tasks:**
- [ ] ePub export (electronic book for showing experience digitally)
- [ ] HTML export (static website with CSS, images, interactive map)
- [ ] MySQL dump export (for migration to other systems)

---

## 13.2 Interoperability

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Import from Subsurface | ✅ Implemented | v1.5 | UDDF or XML via universal import wizard |
| Import from MacDive | ✅ Implemented | v1.5 | CSV via universal import wizard |
| Import from other apps | ✅ Implemented | v1.5 | Diving Log, DiveMate, etc. via universal import |
| Upload to divelogs.de | 📋 Planned | v2.0 | API integration |
| Garmin Connect integration | 📋 Planned | v2.0 | Import Garmin watch dives |
| Shearwater Cloud import | 📋 Planned | v2.0 | Import from Shearwater cloud |
| Suunto app import | 📋 Planned | v2.0 | Import via Suunto cloud/Movescount |
| Diviac import | 📋 Planned | v2.0 | Import from Diviac online logbook |
| Deepblu import | 📋 Planned | v2.0 | Import from Deepblu platform |

**v1.5 Tasks (Complete):**
- [x] Import wizard with app selection (Subsurface, MacDive, Diving Log, etc.)
- [x] Per-app parser (detect format, map fields)
- [x] Dry-run preview before importing
- [x] 6-step universal import wizard (file selection, source confirmation, field mapping, review, import, summary)
- [x] Format auto-detection for 12+ source apps (Subsurface, MacDive, Diving Log, DiveMate, etc.)
- [x] 9 entity types supported (dives, sites, buddies, equipment, species, certifications, tanks, weights, tags)

**v2.0 Tasks:**
- [ ] divelogs.de API integration (upload/download dives)
- [ ] Garmin Connect API (import dive activity FIT files)
- [ ] Automatic conversion from Garmin Descent dive computers
- [ ] Shearwater Cloud API integration
- [ ] Suunto app/Movescount API integration
- [ ] Diviac API integration
- [ ] Deepblu API integration

---

## 13.3 Universal Import

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Universal CSV import | ✅ Implemented | MVP | Configurable column mapping |
| Format auto-detection | ✅ Implemented | v1.5 | Smart header analysis with source app detection |
| Import templates | ✅ Implemented | v1.5 | Built-in mappings for 12+ apps |
| Import validation | ✅ Implemented | v1.5 | Required fields, data types, dry-run preview |

**v1.5 Tasks (Complete):**
- [x] Smart format detection (analyze CSV headers, suggest mapping)
- [x] Import templates for common apps (built-in column mappings for 12+ source apps)
- [x] Import validation (check required fields, data types, row-level error reporting)
- [x] Dry-run preview with entity counts and validation warnings
- [x] 161 unit tests for universal import feature

---

# Category 14: Social, Community & Travel Features

## 14.1 Social Sharing

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Share dives to social media | 📋 Planned | v2.0 | FB, Instagram, Twitter |
| Generate composite images | 📋 Planned | v2.0 | Profile + photo + stats |
| Share links | 📋 Planned | v2.0 | Web view of dive (requires backend) |
| Shareable dive cards | 📋 Planned | v2.0 | Visual summary image for social |

**v2.0 Tasks:**
- [ ] "Share Dive" action with platform picker
- [ ] Generate shareable image (profile chart, photo, depth/time/location text overlay)
- [ ] Share as PNG or link (if cloud sync enabled)
- [ ] Public dive view page (web) with privacy settings

---

## 14.2 Community Maps & Logs

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| View community dive sites | 📋 Planned | v2.0 | Requires backend |
| Explore nearby sites | 📋 Planned | v2.0 | GPS-based search |
| User-submitted site photos | 📋 Planned | v2.0 | Photo gallery per site |
| Dive site reviews & ratings | 📋 Planned | v2.0 | Rate and review sites |

**v2.0 Tasks:**
- [ ] Community backend (user accounts, public profiles)
- [ ] Public dive site database (user submissions)
- [ ] Site photos, reviews, difficulty ratings
- [ ] "Discover" tab with nearby sites, popular sites, new sites

---

## 14.3 Diver Social Network

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Diver profiles | 📋 Planned | v2.0 | Public profile with stats, certs, dive count |
| Follow buddies | 📋 Planned | v2.0 | Activity feed from followed divers |
| Buddy activity feed | 📋 Planned | v2.0 | New dives, photos, certs from buddies |
| Community groups | 📋 Planned | v2.0 | Dive clubs, schools, interest groups |
| In-app messaging | 📋 Planned | v2.0 | Chat between buddies |
| Public dive feed | 📋 Planned | v2.0 | Discover dive logs from community |
| Digital instructor signatures | 📋 Planned | v2.0 | Instructors verify/sign training logs |

**v2.0 Tasks:**
- [ ] Diver profile page (public view with stats, certifications, dive count)
- [ ] Follow/unfollow other divers
- [ ] Activity feed (new dives, photos, certifications from followed divers)
- [ ] Community groups with forums, events, shared stats
- [ ] In-app messaging between buddies
- [ ] Public dive feed ("Discover" section)
- [ ] Privacy controls (public/private/buddies-only)

---

## 14.4 Booking & Commerce

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Browse/book fun dives | 🔮 Future | v3.0 | PADI Adventures-style |
| Book courses | 🔮 Future | v3.0 | Integration with dive shops |
| Pass cert details to bookings | 🔮 Future | v3.0 | Auto-fill diver info |

---

# Category 15: UX, Customization & Quality-of-Life

## 15.1 Layout & Customization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Dark mode | ✅ Implemented | MVP | Light/Dark/System |
| Customizable logbook columns | 📋 Planned | v2.0 | Show/hide fields |
| Themes | 📋 Planned | v2.0 | Custom color schemes |
| Quick actions | 📋 Planned | v1.5 | iOS shortcuts, Android widgets |

**v1.5 Tasks:**
- [ ] iOS 3D Touch shortcuts (Add Dive, View Last Dive)
- [ ] Android home screen widgets (dive count, last dive, next service due)

**v2.0 Tasks:**
- [ ] Customizable dive list columns (user selects which fields to show)
- [ ] Theme editor (custom colors, fonts)
- [ ] Layout presets (Compact, Detailed, Photo-focused)

---

## 15.2 Multi-User / Family Support

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multiple divers per database | ✅ Done | v1.5 | DiveMate-style |
| Account switching | ✅ Done | v1.5 | Shared devices |

**v1.5 Tasks (Complete):**
- [x] Diver entity (name, certs, profile)
- [x] Add `diver_id` to dives table
- [x] Diver switcher in settings or main nav
- [x] Per-diver stats and filtering

---

## 15.3 Accessibility & Localization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Screen reader support | ✅ Implemented | v1.5 | Semantics on all interactive elements |
| Keyboard navigation | ✅ Implemented | v1.5 | Global shortcuts, focus traversal, help dialog |
| Semantic helpers | ✅ Implemented | v1.5 | Extension methods and label builders |
| Focus management | ✅ Implemented | v1.5 | FocusableCard, AccessiblePage, OrderedTraversalPolicy |
| Shortcuts help dialog | ✅ Implemented | v1.5 | ? key opens categorized shortcut overlay |
| Multi-language support | ✅ Implemented | v1.5 | 10 languages, 3,931 ARB keys, gen-l10n codegen |
| RTL layout support | ✅ Implemented | v1.5 | Arabic & Hebrew with directional EdgeInsets/Alignment |
| Locale-aware formatting | ✅ Implemented | v1.5 | Localized dates, numbers, durations, connector words |
| Language picker | ✅ Implemented | v1.5 | Per-diver locale persistence via Drift |
| High contrast themes | 📋 Planned | v2.0 | Accessibility feature |

**v1.5 Tasks (Complete):**
- [x] Semantic labels on all interactive elements across 200+ files
- [x] Tooltips on all IconButtons
- [x] ExcludeSemantics on decorative elements (icons, dividers, charts)
- [x] FocusTraversalGroup with OrderedTraversalPolicy on page sections
- [x] FocusableCard widget with visible focus ring indicator
- [x] Keyboard shortcut infrastructure (ShortcutCatalog, ShortcutEntry, AppShortcuts)
- [x] Global shortcuts: Cmd+1-5 tab nav, Cmd+N new dive, Cmd+F search, Cmd+W back, ? help
- [x] ShortcutsHelpDialog with categorized shortcut display
- [x] Semantic helper extensions (semanticButton, semanticLabel, excludeFromSemantics)
- [x] Label builder functions (chartSummaryLabel, listItemLabel, statLabel)
- [x] 83 unit/widget tests for accessibility infrastructure

**v1.5 i18n Tasks (Complete):**
- [x] flutter_localizations integration with gen-l10n codegen pipeline
- [x] ARB files for 10 languages: English, Spanish, French, German, Italian, Dutch, Portuguese, Arabic, Hebrew, Hungarian
- [x] 3,931 ARB keys extracted from ~233 presentation files
- [x] Localized date/time/number formats (DateFormat locale, NumberFormat locale, duration labels)
- [x] RTL language support (Arabic, Hebrew) with directional EdgeInsets, Alignment, icon mirroring
- [x] context.l10n convenience extension for concise access to localized strings
- [x] Language picker in Settings with per-diver locale persistence via Drift (schema v33)
- [x] Connector word localization in UnitFormatter (at, From, Until)
- [x] Localization integration tests (locale switching, RTL direction, provider persistence)

**v2.0 Tasks:**
- [ ] Translation management workflow (POEditor, Crowdin)

---

## 15.4 Gamification & Achievements

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Achievement badges | 📋 Planned | v2.0 | Earn badges for milestones |
| Dive milestones | 📋 Planned | v2.0 | 100 dives, 1000m depth, etc. |
| Species life list | 📋 Planned | v2.0 | Track total unique species seen |
| Depth achievements | 📋 Planned | v2.0 | First 20m, 30m, 40m dives |
| Streak tracking | 📋 Planned | v2.0 | Monthly/yearly dive streaks |
| Progress visualization | 📋 Planned | v2.0 | Journey timeline with milestones |

**v2.0 Tasks:**
- [ ] Achievement system with badge definitions
- [ ] Milestone tracking (dive count, depths, locations, species)
- [ ] Badge unlock notifications
- [ ] Achievement showcase on diver profile
- [ ] Progress towards next milestone display
- [ ] Life list tracker (species collection progress)

---

## 15.5 Wearable Integration

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Apple Watch Ultra import | ✅ Implemented | v1.5 | Import dives via HealthKit with 3-step wizard |
| Apple HealthKit integration | ✅ Implemented | v1.5 | Read depth/temperature/heart rate data |
| Duplicate detection | ✅ Implemented | v1.5 | Exact wearableId + fuzzy DiveMatcher scoring |
| Garmin FIT file import | ✅ Implemented | v1.5 | FitParserService + 3-step import wizard |
| Suunto BLE direct download | ✅ Implemented | v1.5 | suunto_ble_protocol, device library support |
| UDDF import | ✅ Implemented | v1.5 | Covers Suunto app/Movescount exports |
| Garmin Connect cloud API | 📋 Planned | v2.0 | Cloud sync (not file-based) |

**v1.5 Tasks (Complete):**
- [x] HealthKit permission and data reading (health package, UNDERWATER_DIVING activity)
- [x] WearableDive / WearableProfileSample domain entities
- [x] DiveMatcher fuzzy scoring (time 50%, depth 30%, duration 20%)
- [x] WearableDiveConverter (WearableDive -> Dive with profile points)
- [x] Import wizard UI: Select dives > Review duplicates > Summary
- [x] Exact dedup via wearableId + fuzzy match via DiveMatcher
- [x] Database: wearableSource/wearableId on dives, heartRateSource on dive_profiles
- [x] Route: /settings/wearable-import (Transfer > Dive Computers > Apple Watch)
- [x] Garmin FIT file parsing and import (FitParserService, fit_tool package)
- [x] FIT import wizard (Transfer > Import from FIT File, 3-step: Pick > Duplicates > Summary)
- [x] Suunto BLE protocol implementation (EON Steel/D5, HDLC framing)
- [x] UDDF import wizard (Transfer > Import from UDDF)

**v2.0 Tasks:**
- [ ] Garmin Connect cloud API integration
- [ ] Automatic sync from connected wearables
- [ ] Merge wearable data with dive computer data

---

## 15.6 Well-being & Safety

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Pre-dive feeling monitor | 📋 Planned | v2.0 | Track readiness before dive |
| Post-dive feeling monitor | 📋 Planned | v2.0 | Track condition after dive |
| Breathing technique analysis | 📋 Planned | v2.0 | SAC improvement suggestions |
| Hydration reminders | 📋 Planned | v2.0 | DCS prevention |
| No-fly countdown | ✅ Implemented | v1.5 | Based on deco status |

**v2.0 Tasks:**
- [ ] Pre/post dive well-being questionnaire
- [ ] Correlation analysis (feeling vs dive parameters)
- [ ] Breathing efficiency tips based on SAC trends
- [ ] Health trend visualization over time

---

# Category 16: Manufacturer-Specific & Advanced Features

## 16.1 Advanced Hardware Integration

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Assistant dive computer | 🔮 Future | v3.0 | Smartphone in housing |
| Remote DC configuration | 📋 Planned | v2.0 | Bluetooth settings sync |
| Firmware updates via app | 📋 Planned | v2.0 | Shearwater-specific |

---

## 16.2 Partner Ecosystem Integration

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Shearwater Cloud sync | 📋 Planned | v2.0 | API integration |
| Garmin Dive sync | 📋 Planned | v2.0 | Import from Garmin |
| PADI eCard integration | 📋 Planned | v2.0 | Display PADI certs |

**v2.0 Tasks:**
- [ ] Shearwater Cloud API (import dives from cloud)
- [ ] Garmin Connect API (import Descent dive activities)
- [ ] PADI app integration (OAuth, fetch eCards)

---

# Data Model Reference

## v1.0/v1.1 Tables (Implemented)

```sql
-- Core entities: dives, dive_sites, equipment, species, sightings
-- v1.0 additions: buddies, dive_buddies, certifications, service_records, 
--                 dive_centers, dive_weights, tank_presets, trips
-- v1.1 additions: tags, dive_tags, entry_time/exit_time on dives,
--                 min_depth/max_depth/difficulty/hazards on sites
```

## v1.5 Tables (Planned)

```sql
-- dive_computers (name, manufacturer, model, connection_type, last_download)
-- gas_switches (dive_id, timestamp, tank_id)
-- profile_events (dive_id, timestamp, event_type, description)
-- CCR fields: dive_mode, tank_role
```

## v1.5 Tables (Implemented)

```sql
-- dive_computers (name, manufacturer, model, connection_type, last_download)
-- dive_profile_events (dive_id, timestamp, event_type, description, severity)
-- gas_switches (dive_id, timestamp, tank_id, depth)
-- tank_pressure_profiles (dive_id, tank_id, timestamp, pressure)
-- divers (multi-user support - fully implemented)
-- diver_settings (per-diver preferences)
-- sync_metadata, sync_records, deletion_log (cloud sync infrastructure)

-- CCR/SCR fields on dives table:
-- dive_mode (oc, ccr, scr)
-- setpoint_low, setpoint_high, setpoint_deco (CCR setpoints in bar)
-- diluent_o2, diluent_he (CCR diluent gas composition)
-- scr_type (cmf, pascr, escr)
-- scr_injection_rate (L/min at surface for CMF)
-- scr_addition_ratio (e.g., 0.33 for 1:3 PASCR)
-- scr_orifice_size (e.g., '40', '50', '60')
-- assumed_vo2 (assumed O2 consumption L/min)
-- loop_o2_min, loop_o2_max, loop_o2_avg (measured loop FO2)
-- loop_volume (liters)
-- scrubber_type, scrubber_duration_minutes, scrubber_remaining_minutes

-- Tank roles extended: diluent, oxygen_supply (for CCR)

-- BLOB storage columns (v23):
-- certifications.photo_front, certifications.photo_back (scanned card images)
-- media.image_data (signature PNG bytes for self-contained backup)

-- Wearable integration columns (v30):
-- dives.wearable_source (e.g., 'apple_health')
-- dives.wearable_id (unique identifier from wearable platform)
-- dive_profiles.heart_rate_source (e.g., 'apple_watch')

-- Marine life tracking columns (v32):
-- species.taxonomy_class (text, e.g., 'Actinopterygii')
-- species.is_built_in (boolean, true for JSON-seeded species)
-- 511 built-in species loaded from assets/data/species.json

-- Custom fields table (v34):
-- dive_custom_fields (id, dive_id, field_key, field_value, sort_order, created_at)
-- CASCADE delete when parent dive is deleted
-- Indexes: idx_dive_custom_fields_dive_id, idx_dive_custom_fields_key
```

## v2.0 Tables (Planned)

```sql
-- users (for backend authentication)
-- saved_filters (Smart Logs)
-- courses (training course tracking)
```

---

# Dependencies

## Current (v1.0/v1.1)
- **Database:** drift, sqlite3
- **Charts:** fl_chart
- **Maps:** flutter_map, latlong2, flutter_map_marker_cluster
- **GPS:** geolocator, geocoding
- **Export:** pdf, csv, xml
- **Testing:** flutter_test, mockito

## v1.5 Requirements
- **Dive Computers:** libdivecomputer (FFI), flutter_blue_plus, usb_serial
- **Deco:** Custom Bühlmann implementation
- **Cloud Sync:** googleapis (Google Drive), icloud_storage
- **Weather/Tides:** http (OpenWeatherMap, World Tides APIs)
- **Offline Maps:** flutter_map_tile_caching (FMTC) with ObjectBox backend
- **Wearables:** health (HealthKit/Google Health Connect)

## v2.0 Requirements
- **Backend:** Firebase/Supabase SDK
- **Auth:** firebase_auth or supabase_auth
- **i18n:** flutter_localizations, intl

---

# Release Criteria

## v1.0 ✅ Complete
- [x] All critical features implemented
- [x] 80%+ unit test coverage (165+ tests)
- [x] 60%+ widget test coverage (48+ tests)
- [x] Zero critical bugs
- [ ] App store submissions (iOS, Android)
- [ ] Documentation (user guide, FAQ)

## v1.1 ✅ Complete
- [x] Entry/exit times, surface interval, dive numbering
- [x] GPS integration, reverse geocoding
- [x] Map marker clustering with color coding
- [x] Profile zoom/pan and touch markers
- [x] Equipment status filtering
- [x] Tags system
- [x] Integration and performance tests

## v1.5 (In Progress)
- [x] Dive computer connectivity (libdivecomputer FFI, BLE, USB)
- [x] 300+ dive computer models supported
- [x] Manufacturer BLE protocols (Aqualung, Shearwater, Mares, Suunto)
- [x] Bühlmann ZH-L16C algorithm implemented (141 unit tests)
- [x] Profile analysis with deco ceiling, NDL, tissue loading
- [x] O₂ toxicity tracking (CNS%, OTU, ppO₂)
- [x] Ascent rate monitoring with warnings
- [x] Multi-computer/profile support
- [x] Duplicate dive detection (fuzzy match on time+depth+duration)
- [x] Incremental downloads (uses lastDownload timestamp)
- [x] Device stats page (deepest, longest, avg depth, temp range)
- [x] Cloud sync via iCloud and Google Drive
- [x] Sync conflict detection and resolution UI
- [x] SAC trend charts (monthly average over 5 years)
- [x] Temperature graphs (water temp by month)
- [x] Dive frequency charts (dives per year)
- [x] Gas mix distribution (pie chart)
- [x] Time pattern analysis (day of week, time of day, seasonal)
- [x] CCR (Closed Circuit Rebreather) support with setpoints, diluent gas, scrubber tracking
- [x] SCR (Semi-Closed Rebreather) support with injection rate, supply gas, loop FO₂ calculation
- [x] SCR types: CMF, PASCR, ESCR with type-specific configuration
- [x] Dive mode selector UI and settings panels for CCR/SCR
- [x] Diluent and SCR supply gas templates
- [x] Dive planner with multi-level segments, deco schedules, gas consumption projections
- [x] Quick Plan dialog for simple rectangular profiles
- [x] Profile chart visualization of planned dives
- [x] Expanded filter UI (buddy, equipment, gas mix O2%, rating, duration)
- [x] Advanced Search page with full filter form (`/dives/search`)
- [x] Bulk export from selection mode (CSV, PDF, UDDF)
- [x] Bulk edit from selection mode (change trip, add/remove tags)
- [x] Profile export as PNG (save to Photos or choose file location)
- [x] Range analysis with drag handles (min/max/avg stats for selected portion)
- [x] Step-through playback with animated cursor and real-time stats
- [x] Heart rate overlay toggle on profile chart
- [x] 16-compartment tissue saturation bar chart (N2/He visualization)
- [x] Personal & Medical Data (emergency contacts, medical clearance, medications)
- [x] Digital Signatures (instructor + buddy signature capture, display, storage, PDF export)
- [x] Training Dives (Course entity, bidirectional course-certification linking)
- [x] Underwater Photography (photo picker, gallery, full-screen viewer, EXIF write)
- [x] Maps & Visualization (Activity map with heat map, offline maps with FMTC, site filtering)
- [x] Certification Card Images (front/back photos with BLOB storage for backup/sync)
- [x] BLOB Storage (signatures and certification photos stored in database for easy backup/export)
- [x] Push Notifications (gear service reminders with configurable advance, per-item overrides, deep linking)
- [x] Training Log Export (PDF with instructor signatures, course info, dive list)
- [x] PDF Templates (Simple, Detailed, Professional, PADI-style, NAUI-style with page size and cert cards)
- [x] Wearable Integration v1 (Apple Watch Ultra import via HealthKit, duplicate detection, 3-step wizard)
- [x] Marine Life Tracking (511 species database, taxonomy, management UI, detail page with stats, reset-to-defaults)
- [x] Universal Import (6-step wizard, 12+ source app detection, 9 entity types, field mapping, dry-run preview, 161 tests)
- [x] Accessibility & Keyboard Navigation (Semantics on 200+ files, global shortcuts, focus traversal, shortcuts help dialog, 83 tests)
- [x] Custom Fields (freeform key:value metadata per dive, autocomplete, reorderable, search/filter, CSV/UDDF/PDF export/import)
- [ ] Performance with 5000+ dives

## v2.0 (Planned)
- [ ] Web platform with backend service
- [x] 7+ language translations (10 languages: EN, ES, FR, DE, IT, NL, PT, AR, HE, HU)
- [ ] Community features beta tested

---

# Platform Support

| Platform | Status | Requirements |
|----------|--------|--------------|
| iOS | ✅ | iOS 13+ |
| Android | ✅ | Android 7+ |
| macOS | ✅ | macOS 11+ |
| Windows | ✅ | Windows 10+ |
| Linux | ✅ | Desktop Linux |
| Web | v2.0 | Requires cloud sync |

---

**Document Version:** 2.23
**Last Updated:** 2026-02-13 (Custom Fields: freeform key:value metadata per dive with autocomplete, reorderable UI, search/filter, CSV/UDDF/PDF export/import)
