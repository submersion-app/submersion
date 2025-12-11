# Submersion Feature Roadmap
## Comprehensive Development Plan

> **Last Updated:** 2025-12-11
> **Current Version:** 0.1.0+1 (MVP Complete)
> **Status:** Production-ready core, expanding to feature parity with industry leaders

---

## Executive Summary

This roadmap represents the path to making Submersion a best-in-class dive logging application by incorporating features from industry leaders (Subsurface, MacDive, Shearwater Cloud, Dive+, Diving Log 6.0, DiveMate, DiverLog+, Garmin Dive, PADI apps).

**Current State:** ✅ MVP Complete
- Core dive logging, sites, equipment, marine life, statistics
- CSV/UDDF/PDF import/export
- Local-first architecture with SQLite storage

**Target State:** Feature-complete professional dive logging platform
- Multi-platform (iOS, Android, macOS, Windows, Linux, Web)
- Dive computer connectivity (300+ models)
- Advanced technical diving support (CCR, trimix, deco planning)
- Photo/video management with AI species identification
- Community features and social sharing
- Optional cloud sync for multi-device users

---

## Roadmap Phases

### Phase Definitions

| Phase | Timeline | Focus | Status |
|-------|----------|-------|--------|
| **MVP** | Complete | Core dive logging workflow | ✅ Done |
| **v1.0** | 3-4 months | Production-ready with essential features | 🟡 In Progress |
| **v1.5** | 4-6 months | Technical diving & dive computer integration | 📋 Planned |
| **v2.0** | 8-12 months | Advanced features & social | 📋 Planned |
| **v3.0** | 12-18 months | Community platform & AI features | 🔮 Future |

---

## Feature Status Legend

- ✅ **Implemented** - Feature is complete and working
- 🟡 **In Progress** - Currently being developed
- 📋 **Planned** - Scheduled for upcoming phase
- 🔮 **Future** - Long-term roadmap item
- ⚠️ **Blocked** - Waiting on dependency or decision
- 🎯 **Priority** - Critical for next release

---

# Category 1: Core Dive Log Entry

## 1.1 Basic Metadata

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Dive number (auto-increment) | ✅ Implemented | MVP | - | Works but could add gap detection |
| Date and time in/out | ✅ Implemented | MVP | - | Single datetime field currently |
| Total bottom time | ✅ Implemented | MVP | - | Auto-calculated from profile |
| Runtime tracking | 📋 Planned | v1.5 | Medium | Add separate field for total runtime |
| Surface interval calculation | 📋 Planned | v1.5 | High | Between successive dives |
| Max depth, average depth | ✅ Implemented | MVP | - | |
| Min/max temperature | ✅ Implemented | MVP | - | From profile data |
| Dive type (20+ types) | ✅ Implemented | MVP | - | Recreational, tech, wreck, cave, night, etc. |

**v1.0 Enhancements:**
- [ ] Separate entry/exit time fields (currently single timestamp)
- [ ] Auto-calculate surface interval from previous dive
- [ ] Dive numbering with gap detection and re-numbering utility

**v1.5 Enhancements:**
- [ ] Custom dive types (user-defined)
- [ ] Multi-day dive trip grouping

---

## 1.2 Location & Site

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Site name, region, country | ✅ Implemented | MVP | - | Full site database |
| GPS coordinates | ✅ Implemented | MVP | - | Lat/long with map view |
| Boat / operator name | 🟡 In Progress | v1.0 | 🎯 High | Add dedicated fields |
| Trip grouping | 📋 Planned | v1.5 | Medium | Multi-dive trips with dates |
| Liveaboard tracking | 📋 Planned | v2.0 | Low | Specialized trip type |

**v1.0 Tasks:**
- [ ] Add `boat_name`, `operator_name`, `dive_center` fields to dives table
- [ ] Create Dive Center/Operator entity with contact info, location
- [ ] Site picker with "Add New Site" quick action
- [ ] GPS from device location when creating dive (mobile)

**v1.5 Tasks:**
- [ ] Trip entity linking multiple dives
- [ ] Trip summary page (stats, photos, export)
- [ ] Trip templates (liveaboard, resort week, local weekend)

---

## 1.3 Conditions

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Visibility (numeric + qualitative) | ✅ Implemented | MVP | - | Enum: Poor/Fair/Good/Excellent |
| Current (direction + strength) | 📋 Planned | v1.0 | Medium | Add fields |
| Waves / swell height | 📋 Planned | v1.0 | Medium | Add field |
| Weather | 📋 Planned | v1.5 | Low | Free-text or API integration |
| Air temperature | ✅ Implemented | MVP | - | Separate from water temp |
| Entry/exit method | 📋 Planned | v1.0 | Medium | Shore, boat, zodiac, giant stride, etc. |
| Water type | 📋 Planned | v1.0 | Low | Fresh, salt, brackish |
| Altitude | 📋 Planned | v1.5 | Low | For altitude dive calculations |

**v1.0 Tasks:**
- [ ] Add `current_direction` (enum: N/S/E/W/NE/etc.), `current_strength` (enum: None/Slight/Moderate/Strong)
- [ ] Add `swell_height_meters`, `entry_method`, `exit_method` (enums)
- [ ] Add `water_type` enum (Fresh, Salt, Brackish)
- [ ] Conditions section in dive edit form with icons

**v1.5 Tasks:**
- [ ] Weather API integration (OpenWeatherMap) with historical data
- [ ] Tide information integration
- [ ] Auto-populate conditions from GPS + date/time

---

## 1.4 Notes & Tags

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Free-text notes | ✅ Implemented | MVP | - | Rich text field |
| Star rating (1-5) | ✅ Implemented | MVP | - | |
| Favorite flag | 📋 Planned | v1.0 | Low | Boolean flag |
| Arbitrary tags | 📋 Planned | v1.5 | Medium | Many-to-many tags |
| Smart collections based on tags | 📋 Planned | v2.0 | Low | Saved filters |

**v1.0 Tasks:**
- [ ] Add `is_favorite` boolean to dives table
- [ ] Favorite icon in dive list and detail
- [ ] Filter by favorites

**v1.5 Tasks:**
- [ ] Tags entity with many-to-many relationship
- [ ] Tag input widget (chip selector)
- [ ] Tag-based filtering and search
- [ ] Tag statistics (most used, tag clouds)

---

# Category 2: Dive Profile & Telemetry

## 2.1 Profile Visualization

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Time-depth profile chart | ✅ Implemented | MVP | - | Using fl_chart |
| Zoom and pan controls | 📋 Planned | v1.0 | 🎯 High | fl_chart supports this |
| Profile markers/events | 📋 Planned | v1.5 | High | Descent, safety stop, gas switch, alerts |
| Temperature overlay | ✅ Implemented | MVP | - | Toggle on/off |
| Ascent rate indicators | 📋 Planned | v1.5 | High | Color-code dangerous ascents |
| Ceiling / NDL curve | 📋 Planned | v1.5 | 🎯 High | Requires deco algorithm |
| ppO₂ curve, CNS/OTU | 📋 Planned | v1.5 | Medium | Technical diving |
| SAC/RMV overlay | 📋 Planned | v1.5 | Medium | Instantaneous gas consumption |

**v1.0 Tasks:**
- [ ] Implement InteractiveChart with pan/zoom gestures
- [ ] Add touch markers showing exact depth/time/temp at touch point
- [ ] Pinch-to-zoom on mobile, scroll-to-zoom on desktop
- [ ] Profile export as PNG image for sharing

**v1.5 Tasks:**
- [ ] Profile event markers (table: `dive_profile_events` with type, timestamp, description)
- [ ] Ascent rate calculation and color overlay (green <9m/min, yellow 9-12, red >12)
- [ ] NDL curve from Bühlmann implementation
- [ ] CNS O₂ toxicity tracking for nitrox/trimix
- [ ] OTU (Oxygen Tolerance Unit) calculation
- [ ] ppO₂ graph for CCR dives

---

## 2.2 Multi-Profile Support

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Multiple computers per dive | 📋 Planned | v1.5 | Medium | Backup computer, bottom timer |
| Profile comparison (buddies) | 📋 Planned | v2.0 | Low | Side-by-side view |
| Profile merging | 📋 Planned | v2.0 | Low | Combine multiple sources |

**v1.5 Tasks:**
- [ ] Add `computer_id` to dive_profiles table
- [ ] UI to select active profile when multiple exist
- [ ] Indicate which profile is "primary" for statistics

**v2.0 Tasks:**
- [ ] Side-by-side profile comparison view
- [ ] Buddy profile import (from shared UDDF)

---

## 2.3 Profile Editing

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Smoothing / cleaning bad samples | 📋 Planned | v2.0 | Low | Outlier removal |
| Manual profile drawing | 📋 Planned | v2.0 | Low | For dives without computer |
| Segment editing | 📋 Planned | v2.0 | Low | Adjust timestamps, depths |

**v2.0 Tasks:**
- [ ] Profile outlier detection algorithm (sudden depth jumps)
- [ ] Smoothing algorithm (moving average)
- [ ] Manual profile editor with touch/mouse drawing
- [ ] Segment selection and adjustment UI

---

# Category 3: Dive Computer Connectivity

## 3.1 Connectivity Types

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| USB cable transfers | 📋 Planned | v1.5 | 🎯 High | Via libdivecomputer |
| Bluetooth Classic | 📋 Planned | v1.5 | 🎯 High | flutter_blue_plus |
| Bluetooth LE (BLE) | 📋 Planned | v1.5 | 🎯 High | flutter_blue_plus |
| Infrared (legacy) | 🔮 Future | v3.0 | Low | Limited hardware support |
| Wi-Fi / cloud devices | 📋 Planned | v2.0 | Medium | Garmin, Shearwater cloud API |

**v1.5 Tasks (Critical Path):**
- [ ] Integrate libdivecomputer via FFI (Dart bindings to C library)
- [ ] Device detection and pairing UI
- [ ] Bluetooth connection manager (scanning, pairing, reconnection)
- [ ] USB device enumeration and selection
- [ ] Progress indicator during download (% complete, dive count)

---

## 3.2 Device Support

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| 300+ dive computer models | 📋 Planned | v1.5 | 🎯 High | Via libdivecomputer |
| Per-device presets | 📋 Planned | v1.5 | Medium | Save connection settings |
| Favorite devices | 📋 Planned | v1.5 | Low | Quick-select dropdown |

**v1.5 Tasks:**
- [ ] Create `dive_computers` table (name, manufacturer, model, connection_type, last_used)
- [ ] Device library with 300+ model definitions from libdivecomputer
- [ ] Auto-detection of device model via USB VID/PID or BT service UUID
- [ ] Device configuration persistence (COM port, BT address, connection params)

---

## 3.3 Download Behavior

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Download new dives only | 📋 Planned | v1.5 | 🎯 High | Track last download timestamp |
| Force download all | 📋 Planned | v1.5 | Medium | Override with checkbox |
| Auto-download when connected | 📋 Planned | v2.0 | Low | Background sync |
| Duplicate detection | 📋 Planned | v1.5 | 🎯 High | Match by date+time+depth |

**v1.5 Tasks:**
- [ ] Store `last_download_timestamp` per dive computer
- [ ] Duplicate detection algorithm (fuzzy match on datetime + depth within tolerance)
- [ ] "New Dives" vs "All Dives" toggle in download wizard
- [ ] Conflict resolution UI (keep existing, replace, create duplicate)

**v2.0 Tasks:**
- [ ] Background BLE scanning and auto-download (mobile)
- [ ] Notification when new dives detected

---

## 3.4 Device Management

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Rename dive computers | 📋 Planned | v1.5 | Low | "Bob's Perdix", "Backup Computer" |
| Associate dives with computer | 📋 Planned | v1.5 | Medium | Which computer recorded dive |
| Firmware update via app | 📋 Planned | v2.0 | Low | Shearwater-specific |
| Remote configuration | 📋 Planned | v2.0 | Low | Set gases, alarms, units |

**v1.5 Tasks:**
- [ ] Add `computer_id` to dives table (which device imported this dive)
- [ ] Computer detail page showing all dives from that device
- [ ] Computer stats (total dives, last used, battery level if available)

**v2.0 Tasks:**
- [ ] Firmware update wizard (download firmware, flash via BLE)
- [ ] Computer settings sync (read/write computer config)

---

# Category 4: Gases, Tanks & Technical Diving

## 4.1 Multiple Tanks Per Dive

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Multi-tank support | ✅ Implemented | MVP | - | Currently 3 tanks max in UI |
| Tank volume, pressures | ✅ Implemented | MVP | - | Start/end pressure |
| Tank material | 📋 Planned | v1.0 | Low | Steel vs aluminum |
| Tank location | 📋 Planned | v1.5 | Medium | Back gas, stage, deco, bailout |
| Unlimited tanks | 📋 Planned | v1.0 | Medium | Remove UI limit |

**v1.0 Tasks:**
- [ ] Remove artificial 3-tank limit in dive edit form
- [ ] Dynamic tank list with Add/Remove buttons
- [ ] Add `tank_type` enum (Back Gas, Stage, Deco, Bailout, Sidemount Left/Right)
- [ ] Add `material` enum (Steel, Aluminum, Carbon Fiber)

---

## 4.2 Gas Composition

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| O₂ %, He %, N₂ balance | ✅ Implemented | MVP | - | Air, Nitrox, Trimix |
| Gas changes on profile | 📋 Planned | v1.5 | High | Mark switch points |
| Gas naming | 📋 Planned | v1.0 | Low | "EAN32", "TMX 18/45" |

**v1.0 Tasks:**
- [ ] Add common gas mix templates (Air, EAN32, EAN36, O₂, TMX 18/45, TMX 21/35)
- [ ] Gas mix name auto-generation based on O₂/He percentages

**v1.5 Tasks:**
- [ ] Gas switch events on profile (table: `gas_switches` with timestamp, tank_id)
- [ ] Profile segment coloring based on active gas
- [ ] Gas switch markers on profile chart

---

## 4.3 Calculated Metrics

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| SAC / RMV (per dive) | ✅ Implemented | MVP | - | Surface Air Consumption Rate |
| SAC per segment | 📋 Planned | v1.5 | Medium | Time-based or depth-based segments |
| SAC per cylinder | 📋 Planned | v1.5 | Low | For multi-tank dives |
| MOD calculation | ✅ Implemented | MVP | - | Maximum Operating Depth in entity |
| END calculation | ✅ Implemented | MVP | - | Equivalent Narcotic Depth in entity |
| CNS / OTU tracking | 📋 Planned | v1.5 | 🎯 High | O₂ toxicity tracking |

**v1.5 Tasks:**
- [ ] Segment SAC calculation (5-minute segments or depth-based)
- [ ] SAC trend chart (line chart showing SAC over time for a dive)
- [ ] CNS% calculation per dive (accumulated O₂ exposure)
- [ ] OTU calculation (Oxygen Tolerance Units)
- [ ] CNS/OTU display on dive detail page with warnings if exceeded limits

---

## 4.4 Deco & Algorithms

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Bühlmann ZH-L16 with GF | 📋 Planned | v1.5 | 🎯 High | Industry-standard deco algorithm |
| Calculated vs DC ceiling | 📋 Planned | v1.5 | High | Compare app calc with computer |
| NDL display | 📋 Planned | v1.5 | 🎯 High | No Decompression Limit |
| OC/CCR support | 📋 Planned | v1.5 | Medium | Open Circuit / Closed Circuit Rebreather |
| Setpoints, diluent, bailout | 📋 Planned | v1.5 | Medium | CCR-specific fields |

**v1.5 Tasks (Deco Algorithm Implementation):**
- [ ] Implement Bühlmann ZH-L16C algorithm in Dart
- [ ] Gradient Factors (GF Low/High) configuration in settings
- [ ] 16-compartment tissue loading calculation
- [ ] NDL calculation for any depth/gas combination
- [ ] Ceiling calculation (M-values with GF)
- [ ] Deco schedule generation (stop depth/time)
- [ ] Display NDL/ceiling on profile chart
- [ ] TTS (Time To Surface) calculation

**CCR Support (v1.5):**
- [ ] Add `dive_mode` enum (OC, CCR, SCR) to dives table
- [ ] CCR-specific fields: setpoint(s), diluent, bailout gas
- [ ] Setpoint changes as profile events
- [ ] ppO₂ calculation and display

---

## 4.5 Planning Utilities

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Dive planner (multi-level) | 📋 Planned | v1.5 | 🎯 High | Plan dives before doing them |
| Multi-gas planning | 📋 Planned | v1.5 | High | Gas switches, deco gases |
| Repetitive dive planning | 📋 Planned | v1.5 | Medium | Surface interval, tissue loading |
| Gas consumption projections | 📋 Planned | v1.5 | Medium | Based on SAC history |
| What-if scenarios | 📋 Planned | v2.0 | Low | Deeper/longer/different gas |

**v1.5 Tasks:**
- [ ] Dive Planner page with depth/time segment editor
- [ ] Add segments (depth, duration, gas mix)
- [ ] Real-time deco calculation as user edits plan
- [ ] Display: runtime, TTS, NDL, ceiling, gas consumed per tank
- [ ] Save planned dives to database (mark as `planned: true`)
- [ ] Convert planned dive to actual dive after logging

**v2.0 Tasks:**
- [ ] Repetitive dive planner with tissue loading from previous dive
- [ ] "Extend dive" tool (add 5 mins at depth, recalculate deco)
- [ ] "Add safety" tool (extend safety stop, add deep stop)

---

# Category 5: Locations, Dive Sites & Maps

## 5.1 Dive Site Database

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Manage sites, regions, countries | ✅ Implemented | MVP | - | Full CRUD |
| Typical depth, difficulty | 📋 Planned | v1.0 | Medium | Add fields |
| Common marine life | 📋 Planned | v1.5 | Low | Link species to sites |
| Hazards, access notes | 📋 Planned | v1.0 | Medium | Free-text fields |
| Mooring numbers | 📋 Planned | v1.0 | Low | For boat diving |

**v1.0 Tasks:**
- [ ] Add `typical_depth_min`, `typical_depth_max`, `difficulty` (Beginner/Intermediate/Advanced/Technical) to sites table
- [ ] Add `hazards`, `access_notes`, `mooring_number`, `parking_info` text fields
- [ ] Expand site detail page with new fields
- [ ] Site editing form with all fields

**v1.5 Tasks:**
- [ ] Many-to-many relationship between sites and species (common sightings)
- [ ] Display "Commonly Seen" species list on site detail page

---

## 5.2 GPS Integration

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Manual GPS entry | ✅ Implemented | MVP | - | Lat/long fields |
| Capture GPS from phone | 📋 Planned | v1.0 | 🎯 High | Auto-populate on mobile |
| GPS from photo EXIF | 📋 Planned | v1.5 | Medium | Extract and suggest site |

**v1.0 Tasks:**
- [ ] On dive create (mobile), capture device GPS and suggest nearby sites
- [ ] "Use My Location" button in site edit form
- [ ] Reverse geocoding to populate country/region from GPS (use geocoding service)

**v1.5 Tasks:**
- [ ] EXIF parsing from photo attachments
- [ ] If photo has GPS and dive doesn't, suggest using photo GPS
- [ ] Bulk site creation from photo library

---

## 5.3 Maps & Visualization

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Map of all dive sites | ✅ Implemented | MVP | - | Using flutter_map + OpenStreetMap |
| Dive Activity Map | 📋 Planned | v1.5 | Low | Heat map of all dives |
| Offline maps | 📋 Planned | v1.5 | 🎯 High | For travel to remote areas |
| Marker clustering | 📋 Planned | v1.0 | Medium | Group nearby sites |

**v1.0 Tasks:**
- [ ] Marker clustering on dive sites map (group when zoomed out)
- [ ] Tap cluster to zoom in, tap marker to view site detail
- [ ] Different marker colors based on dive count or rating

**v1.5 Tasks:**
- [ ] Offline map tile caching using flutter_map tile storage
- [ ] Download map region for offline use (bounding box selector)
- [ ] Heat map visualization of dive activity (intensity = dive count)

---

## 5.4 External Data Sources

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Online dive site database lookup | 📋 Planned | v2.0 | Low | Import from community sources |
| Dive site reviews | 📋 Planned | v2.0 | Low | User-generated content |

**v2.0 Tasks:**
- [ ] Integration with public dive site APIs (e.g., Open Dive Sites, PADI Travel)
- [ ] Import site details from online sources
- [ ] User reviews and ratings (requires backend)

---

# Category 6: Gear & Equipment Management

## 6.1 Gear Inventory

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Track 20+ equipment types | ✅ Implemented | MVP | - | BCD, reg, fins, suit, computer, etc. |
| Serial, purchase date, cost | ✅ Implemented | MVP | - | All tracked |
| Size, notes, status | 📋 Planned | v1.0 | Low | Add size field |
| Photos of gear | 📋 Planned | v1.5 | Low | Attach images |

**v1.0 Tasks:**
- [ ] Add `size` field to equipment (S/M/L/XL or numeric)
- [ ] Add `status` enum (Active, Retired, Sold, Lost, In Service)
- [ ] Filter equipment by status

**v1.5 Tasks:**
- [ ] Attach photos to equipment items
- [ ] Display photo thumbnails in equipment list

---

## 6.2 Gear Groupings / "Bags"

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Equipment sets | ✅ Implemented | MVP | - | Named collections |
| Predefined configs | 📋 Planned | v1.0 | Medium | Templates for dive types |
| Quick-select sets per dive | 📋 Planned | v1.0 | Medium | One-click apply |

**v1.0 Tasks:**
- [ ] Equipment set templates (Tropical Single Tank, Cold Water Drysuit, Technical Twinset, Sidemount, Photography)
- [ ] "Apply Equipment Set" button in dive edit form (auto-populate dive_equipment)
- [ ] Save current dive's equipment as new set

---

## 6.3 Maintenance

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Service history | ✅ Implemented | MVP | - | Last service date, interval |
| Service reminders | ✅ Implemented | MVP | - | Visual warnings |
| Service records detail | 📋 Planned | v1.0 | 🎯 High | ServiceRecord entity exists but no UI |
| Notifications | 📋 Planned | v1.5 | Medium | Push notifications for overdue service |

**v1.0 Tasks (Critical):**
- [ ] Create Service Records feature
- [ ] CRUD operations for service records (date, shop, cost, work performed, next due)
- [ ] Service history list on equipment detail page
- [ ] Service log export to PDF

**v1.5 Tasks:**
- [ ] Local notifications for service due dates
- [ ] Configurable reminder advance (7 days, 14 days, 30 days before due)

---

## 6.4 Per-Dive Gear Usage

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Gear selected per dive | ✅ Implemented | MVP | - | Many-to-many relationship |
| Weight system & amount | 📋 Planned | v1.0 | Medium | Belt vs integrated, lead amount |
| Gas / cylinder config | ✅ Implemented | MVP | - | Per-tank gas mixes |

**v1.0 Tasks:**
- [ ] Add `weight_system` enum (Belt, Integrated, Trim Pockets, Ankle Weights) to dives table
- [ ] Add `total_weight_kg` field
- [ ] Weight calculator based on exposure suit, tank type, water type

---

# Category 7: People - Buddies, Instructors, Agencies

## 7.1 Buddy Management

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Buddy contact list | 📋 Planned | v1.0 | 🎯 High | Currently free-text field |
| Cert levels, agencies | 📋 Planned | v1.0 | Medium | Store buddy details |
| Mark buddies per dive | ✅ Implemented | MVP | - | Text field only |
| Roles (buddy/guide/instructor) | 📋 Planned | v1.0 | Medium | Enum field |

**v1.0 Tasks (Critical Path):**
- [ ] Create Buddy entity (name, email, phone, certification_level, agency, photo, notes)
- [ ] Buddy repository with CRUD operations
- [ ] Buddy list page (search, add, edit, delete)
- [ ] Convert dive `buddy` text field to many-to-many relationship (dive_buddies junction table)
- [ ] Buddy picker in dive edit form (multi-select with roles)
- [ ] Add `role` enum to dive_buddies (Buddy, Dive Guide, Instructor, Student, Solo)
- [ ] Buddy detail page showing all dives together, stats

**v1.5 Tasks:**
- [ ] Import buddies from contacts (mobile)
- [ ] Share dives with buddies (export UDDF, send via email/messaging)

---

## 7.2 Digital Signatures

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Buddy signatures | 📋 Planned | v1.5 | Low | For training logs |
| Instructor signatures | 📋 Planned | v1.5 | Low | Professional logs |
| Signature capture | 📋 Planned | v1.5 | Low | Touch/stylus drawing |

**v1.5 Tasks:**
- [ ] Signature widget (canvas drawing with save as PNG)
- [ ] Store signatures in Media table linked to dives
- [ ] Display signatures on dive detail page and PDF export
- [ ] Timestamp and signer name with signature

---

## 7.3 Dive Centers / Shops

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Track shops/centers | 📋 Planned | v1.0 | Medium | Name, location, contact |
| Link dives to centers | 📋 Planned | v1.0 | Medium | Foreign key |
| Boat names | 📋 Planned | v1.0 | Medium | Add to dive |

**v1.0 Tasks:**
- [ ] Create DiveCenter entity (name, location, GPS, phone, email, website, notes)
- [ ] DiveCenter repository and CRUD UI
- [ ] Add `dive_center_id` foreign key to dives table
- [ ] Dive center picker in dive edit form
- [ ] Dive center detail page (all dives at this center, stats)

---

# Category 8: Training, Certifications & Medical Info

## 8.1 Certifications

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Store cert levels, agencies | 📋 Planned | v1.0 | 🎯 High | Core feature for pros |
| Cert numbers, issue dates | 📋 Planned | v1.0 | 🎯 High | |
| Instructor names | 📋 Planned | v1.0 | Medium | Link to Buddy entity |
| Scanned card images | 📋 Planned | v1.0 | High | Photo attachments |

**v1.0 Tasks (Critical Path):**
- [ ] Create Certification entity (agency, level, cert_number, issue_date, expiry_date, instructor_name, card_image_path, notes)
- [ ] Certification repository and CRUD UI
- [ ] Certifications page (list all certs, add/edit/delete)
- [ ] Certification card photo upload and display
- [ ] Common agencies enum (PADI, SSI, NAUI, SDI, TDI, GUE, RAID, etc.)
- [ ] Common certification levels enum (Open Water, Advanced, Rescue, Divemaster, Instructor, etc.)
- [ ] Expiry date warnings (red badge if expired, yellow if expiring soon)

---

## 8.2 Digital Cards (eCards)

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| eCard wallet | 📋 Planned | v1.5 | Low | Display certs in wallet format |
| QR codes | 📋 Planned | v2.0 | Low | Scannable verification |

**v1.5 Tasks:**
- [ ] Certification wallet view (card-style UI)
- [ ] Export cert card as image (shareable)

**v2.0 Tasks:**
- [ ] Generate QR codes for certs (encode cert number, agency, level)
- [ ] QR code verification (backend required)

---

## 8.3 Training Dives

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Mark dives as training | 📋 Planned | v1.0 | Medium | Boolean flag or dive type |
| Associate with courses | 📋 Planned | v1.5 | Low | Course entity |
| Instructor comments | 📋 Planned | v1.5 | Low | Rich text field |
| E-signatures | 📋 Planned | v1.5 | Low | Digital signature |

**v1.0 Tasks:**
- [ ] "Training" dive type already exists (no change needed)
- [ ] Add `training_course` text field to dives (e.g., "Advanced Open Water", "Nitrox")

**v1.5 Tasks:**
- [ ] Course entity (name, agency, start_date, completion_date, instructor, cert_id)
- [ ] Link dives to courses (many-to-one)
- [ ] Instructor notes field on dives
- [ ] Training log export (PDF with instructor signature)

---

## 8.4 Personal & Medical Data

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Medical clearance dates | 📋 Planned | v1.5 | Low | For commercial divers |
| Medical documents | 📋 Planned | v2.0 | Low | PDF storage |
| Emergency contacts | 📋 Planned | v1.5 | Medium | Critical for safety |

**v1.5 Tasks:**
- [ ] Add Medical/Personal section to Settings
- [ ] Emergency contact(s) with name, phone, relationship
- [ ] Medical clearance expiry date with reminder
- [ ] Blood type, allergies, medications (encrypted storage)

**v2.0 Tasks:**
- [ ] Medical document storage (PDF of medical clearance)
- [ ] Export profile with certs + medical for dive operations

---

# Category 9: Environment, Wildlife & Photography

## 9.1 Environmental Details

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Water type | 📋 Planned | v1.0 | Low | Fresh, salt, brackish |
| Entry altitude | 📋 Planned | v1.5 | Low | For altitude dive tables |
| Tides | 📋 Planned | v1.5 | Low | State, height, time |
| Hazards | 📋 Planned | v1.0 | Medium | Per-site or per-dive |

**v1.0 Tasks:**
- [ ] Add `water_type` enum to dives table
- [ ] Add `hazards` text field to dives (or use site hazards)

**v1.5 Tasks:**
- [ ] Tide API integration (NOAA, Tides.info)
- [ ] Display tide state at dive time
- [ ] Altitude field with warning if >300m (affects NDL)

---

## 9.2 Marine Life Tracking

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Species database | ✅ Implemented | MVP | - | 40+ pre-seeded species |
| Tag species per dive | ✅ Implemented | MVP | - | Sightings with counts |
| Taxonomy, photos | 📋 Planned | v1.5 | Low | Scientific names, images |
| Stats per species | 📋 Planned | v1.5 | Low | First/last seen, depth range |
| Distribution map | 📋 Planned | v2.0 | Low | Map of sightings |

**v1.5 Tasks:**
- [ ] Add `scientific_name`, `taxonomy_class`, `image_url` to species table
- [ ] Species photo library (local or remote images)
- [ ] Species detail page (description, typical depth, geographic range, photo)
- [ ] Species statistics (total sightings, depth range, sites seen, first/last sighting)

**v2.0 Tasks:**
- [ ] Species distribution map (heatmap of sightings)
- [ ] "Life list" progress tracker (total species seen)
- [ ] Rare species badges

---

## 9.3 Underwater Photography

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Attach photos/videos to dives | 📋 Planned | v1.0 | 🎯 High | Media table exists, needs UI |
| Auto-match by timestamp | 📋 Planned | v1.5 | Medium | EXIF datetime matching |
| Tag species in photos | 📋 Planned | v2.0 | Low | Image annotation |
| Color correction | 📋 Planned | v2.0 | Low | Blue filter removal |
| Depth/time overlay | 🔮 Future | v3.0 | Low | Requires camera integration |

**v1.0 Tasks (Critical Path):**
- [ ] Photo/video picker in dive edit form
- [ ] Attach multiple media files to dive (many-to-many)
- [ ] Media storage strategy (local file copy vs reference, cloud upload option)
- [ ] Display photo gallery on dive detail page
- [ ] Full-screen photo viewer with swipe
- [ ] Caption and datetime per photo
- [ ] Export dive with photos (ZIP archive)

**v1.5 Tasks:**
- [ ] Bulk photo import with auto-match to dives
- [ ] EXIF datetime parsing and fuzzy matching (within ±2 hours)
- [ ] GPS extraction from photos (suggest site creation)
- [ ] Photo thumbnail generation and caching

**v2.0 Tasks:**
- [ ] Species tagging in photos (tap to tag, bounding box)
- [ ] Species recognition suggestions (ML model)
- [ ] Blue/green color cast removal filter
- [ ] Underwater white balance correction

**v3.0 Tasks:**
- [ ] Real-time depth/time overlay for supported camera housings (Weefine, SeaLife)

---

# Category 10: Search, Filters, Statistics & Reports

## 10.1 Search & Filtering

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Full-text search | ✅ Implemented | MVP | - | Notes, sites, buddies |
| Filter by date range | ✅ Implemented | MVP | - | |
| Filter by location, depth | ✅ Implemented | MVP | - | |
| Filter by tags, gas, gear | 📋 Planned | v1.5 | Medium | After tags implemented |
| Saved filters ("Smart Logs") | 📋 Planned | v2.0 | Low | Persistent filter sets |

**v1.5 Tasks:**
- [ ] Expand filter UI with all available criteria (tags, equipment, buddy, gas mix, certification)
- [ ] "Advanced Search" page with all filter options
- [ ] Recent searches history

**v2.0 Tasks:**
- [ ] Save filter configurations as "Smart Logs"
- [ ] Smart Log management (name, description, icon)
- [ ] Quick access to Smart Logs from home page

---

## 10.2 Statistics

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Total dives, bottom time | ✅ Implemented | MVP | - | |
| Breakdown by year/country/site | ✅ Implemented | MVP | - | Top sites chart |
| Depth/time histograms | ✅ Implemented | MVP | - | Depth distribution |
| SAC trends | 📋 Planned | v1.5 | Medium | Line chart over time |
| Temperature graphs | 📋 Planned | v1.5 | Low | Preferred temp range |
| Best/worst/deepest/longest | 📋 Planned | v1.0 | Low | Superlatives page |

**v1.0 Tasks:**
- [ ] "Records" page with cards for: Deepest Dive, Longest Dive, Coldest Water, Best Visibility, Most Species Seen, Longest Dive Trip
- [ ] Each record card shows dive link with photo

**v1.5 Tasks:**
- [ ] SAC trend line chart (average SAC per month over last 2 years)
- [ ] Temperature preference chart (histogram of water temps)
- [ ] Dive frequency chart (dives per month/year)
- [ ] Dive type breakdown (pie chart)
- [ ] Gas mix usage (how often EAN32, TMX, etc.)

**v2.0 Tasks:**
- [ ] Advanced analytics dashboard (customizable widgets)
- [ ] Year-in-review summary (auto-generated at year end)

---

## 10.3 Reports & Printing

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| PDF logbook export | ✅ Implemented | MVP | - | Basic layout |
| Custom report designer | 📋 Planned | v2.0 | Low | Drag-drop fields |
| Pre-made layouts | 📋 Planned | v1.5 | Low | A5, 3-ring, agency style |
| Professional logs | 📋 Planned | v1.5 | Medium | For instructors, DMs |

**v1.5 Tasks:**
- [ ] Multiple PDF templates (Simple, Detailed, Professional, PADI-style, NAUI-style)
- [ ] Template selection in export dialog
- [ ] Professional template with space for signatures, stamps
- [ ] Include certification cards in PDF export

**v2.0 Tasks:**
- [ ] Custom report builder (select fields, layout, sorting)
- [ ] Save custom report templates
- [ ] Export to Excel/CSV with custom fields

---

# Category 11: Planning & Calculators

## 11.1 Dive Planner

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Open-circuit planner | 📋 Planned | v1.5 | 🎯 High | Multi-level plans |
| Multi-gas plans | 📋 Planned | v1.5 | High | With deco stops |
| Repetitive dive planning | 📋 Planned | v1.5 | Medium | Surface interval, tissue loading |
| Save planned dives | 📋 Planned | v1.5 | Medium | Mark as "planned" in DB |

**v1.5 Tasks (Covered in Category 4.5 - Duplicate Reference):**
- See "4.5 Planning Utilities" for detailed task list

---

## 11.2 Deco Calculator

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Real-time simulation | 📋 Planned | v1.5 | High | Interactive depth/time |
| NDL, ceiling, tissue loading | 📋 Planned | v1.5 | High | Visual display |

**v1.5 Tasks:**
- [ ] Deco Calculator page (separate from planner)
- [ ] Sliders for depth, time, gas mix
- [ ] Real-time display of: NDL, ceiling, TTS, tissue loading bar chart (16 compartments)
- [ ] "Add to Planner" button to convert calc to plan

---

## 11.3 Gas Calculators

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| MOD calculator | ✅ Implemented | MVP | - | In GasMix entity |
| Best-mix calculator | 📋 Planned | v1.5 | Low | Target depth → O₂% |
| Gas consumption calculator | 📋 Planned | v1.5 | Medium | Based on SAC, depth, time |
| Rock-bottom calculator | 📋 Planned | v1.5 | Medium | Emergency gas reserve |

**v1.5 Tasks:**
- [ ] Calculators page with tabs: MOD, Best Mix, Gas Consumption, Rock Bottom
- [ ] MOD: Input O₂%, ppO₂ limit → Output MOD
- [ ] Best Mix: Input target depth, ppO₂ limit → Output ideal O₂%
- [ ] Gas Consumption: Input depth, time, SAC, tank size → Output pressure consumed
- [ ] Rock Bottom: Input depth, ascent rate, SAC, buddy SAC, tank size → Output min reserve pressure

---

## 11.4 Convenience Tools

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Surface interval planner | 📋 Planned | v1.5 | Low | How long to wait |
| EAD / END calculator | ✅ Implemented | MVP | - | In GasMix entity |
| Altitude conversion | 📋 Planned | v2.0 | Low | Altitude dive tables |

**v1.5 Tasks:**
- [ ] Surface Interval Tool: Input previous dive (depth, time, gas) + desired next dive → Output min surface interval
- [ ] Display tissue loading chart showing saturation decreasing over time

---

# Category 12: Cloud Sync, Backup & Multi-Device

## 12.1 Cloud Accounts

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Optional cloud account | 📋 Planned | v2.0 | Medium | Post-MVP as stated in docs |
| Anonymous usage | ✅ Implemented | MVP | - | Local-first, no account required |

**v2.0 Tasks:**
- [ ] Backend service (Firebase, Supabase, or custom)
- [ ] User authentication (email/password, OAuth)
- [ ] Opt-in cloud sync toggle in settings
- [ ] Privacy policy and data handling docs

---

## 12.2 Synchronization

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Desktop ↔ mobile ↔ web sync | 📋 Planned | v2.0 | Medium | Requires backend |
| Multi-device support | 📋 Planned | v2.0 | Medium | Login on multiple devices |
| Conflict resolution | 📋 Planned | v2.0 | Medium | Last-write-wins or manual |

**v2.0 Tasks:**
- [ ] Drift schema with `last_modified_at`, `device_id`, `is_deleted` for all tables
- [ ] Sync engine (bidirectional, incremental)
- [ ] Conflict detection and resolution UI
- [ ] Sync status indicator (last synced, pending changes)
- [ ] "Force push" and "force pull" options for troubleshooting

---

## 12.3 Backup

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Local backup export | ✅ Implemented | MVP | - | Full SQLite export |
| Online backup servers | 📋 Planned | v2.0 | Low | Automatic cloud backup |
| Sync via Dropbox | 📋 Planned | v2.0 | Low | 3rd-party storage sync |

**v2.0 Tasks:**
- [ ] Automatic daily backup to cloud (if opted in)
- [ ] Backup history (keep last N backups)
- [ ] Restore from cloud backup

---

## 12.4 Offline Behavior

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Full offline logging | ✅ Implemented | MVP | - | Local-first design |
| Deferred sync | 📋 Planned | v2.0 | Medium | Queue changes when offline |

**v2.0 Tasks:**
- [ ] Offline queue for pending sync operations
- [ ] Auto-sync when connectivity restored
- [ ] Sync conflict warnings and resolution

---

# Category 13: Import, Export & Interoperability

## 13.1 File Formats

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| CSV import/export | ✅ Implemented | MVP | - | Dives, sites, equipment |
| UDDF import/export | ✅ Implemented | MVP | - | v3.2.0 compliant |
| DAN DL7 export | 📋 Planned | v1.5 | Low | Research data format |
| PDF export | ✅ Implemented | MVP | - | Printable logbook |
| HTML export | 📋 Planned | v2.0 | Low | Web-viewable logbook |
| Excel export | 📋 Planned | v1.5 | Low | .xlsx format |
| Google Earth KML export | 📋 Planned | v1.5 | Low | Map all dive sites |

**v1.5 Tasks:**
- [ ] DAN DL7 export (research format specification)
- [ ] Excel export with multiple sheets (dives, sites, equipment, statistics)
- [ ] KML export (placemark per dive site with description bubble)

**v2.0 Tasks:**
- [ ] HTML export (static website with CSS, images, interactive map)
- [ ] MySQL dump export (for migration to other systems)

---

## 13.2 Interoperability

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Import from Subsurface | 📋 Planned | v1.5 | Medium | UDDF or XML |
| Import from MacDive | 📋 Planned | v1.5 | Low | CSV or proprietary format |
| Import from other apps | 📋 Planned | v1.5 | Low | Diving Log, DiveMate, etc. |
| Upload to divelogs.de | 📋 Planned | v2.0 | Low | API integration |
| Garmin Connect integration | 📋 Planned | v2.0 | Low | Import Garmin watch dives |

**v1.5 Tasks:**
- [ ] Import wizard with app selection (Subsurface, MacDive, Diving Log, etc.)
- [ ] Per-app parser (detect format, map fields)
- [ ] Dry-run preview before importing

**v2.0 Tasks:**
- [ ] divelogs.de API integration (upload/download dives)
- [ ] Garmin Connect API (import dive activity FIT files)
- [ ] Automatic conversion from Garmin Descent dive computers

---

## 13.3 Universal Import

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Universal CSV import | ✅ Implemented | MVP | - | Configurable column mapping |
| Format auto-detection | 📋 Planned | v1.5 | Low | Guess format from headers |

**v1.5 Tasks:**
- [ ] Smart format detection (analyze CSV headers, suggest mapping)
- [ ] Import templates for common apps (save column mappings)
- [ ] Import validation (check required fields, data types)

---

# Category 14: Social, Community & Travel Features

## 14.1 Social Sharing

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Share dives to social media | 📋 Planned | v2.0 | Low | FB, Instagram, Twitter |
| Generate composite images | 📋 Planned | v2.0 | Low | Profile + photo + stats |
| Share links | 📋 Planned | v2.0 | Low | Web view of dive (requires backend) |

**v2.0 Tasks:**
- [ ] "Share Dive" action with platform picker
- [ ] Generate shareable image (profile chart, photo, depth/time/location text overlay)
- [ ] Share as PNG or link (if cloud sync enabled)
- [ ] Public dive view page (web) with privacy settings

---

## 14.2 Community Maps & Logs

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| View community dive sites | 📋 Planned | v2.0 | Low | Requires backend |
| Explore nearby sites | 📋 Planned | v2.0 | Low | GPS-based search |
| User-submitted site photos | 📋 Planned | v2.0 | Low | Photo gallery per site |

**v2.0 Tasks:**
- [ ] Community backend (user accounts, public profiles)
- [ ] Public dive site database (user submissions)
- [ ] Site photos, reviews, difficulty ratings
- [ ] "Discover" tab with nearby sites, popular sites, new sites

---

## 14.3 Booking & Commerce

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Browse/book fun dives | 🔮 Future | v3.0 | Low | PADI Adventures-style |
| Book courses | 🔮 Future | v3.0 | Low | Integration with dive shops |
| Pass cert details to bookings | 🔮 Future | v3.0 | Low | Auto-fill diver info |

**v3.0 Tasks (Future):**
- [ ] Partner with dive operators for booking API
- [ ] Dive trip search (location, date range, price)
- [ ] In-app booking with payment
- [ ] Auto-populate diver profile (certs, medical, emergency contact)

---

# Category 15: UX, Customization & Quality-of-Life

## 15.1 Layout & Customization

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Customizable logbook columns | 📋 Planned | v2.0 | Low | Show/hide fields |
| Dark mode | ✅ Implemented | MVP | - | Light/Dark/System |
| Themes | 📋 Planned | v2.0 | Low | Custom color schemes |
| Quick actions | 📋 Planned | v1.5 | Low | iOS shortcuts, Android widgets |

**v1.5 Tasks:**
- [ ] iOS 3D Touch shortcuts (Add Dive, View Last Dive)
- [ ] Android home screen widgets (dive count, last dive, next service due)

**v2.0 Tasks:**
- [ ] Customizable dive list columns (user selects which fields to show)
- [ ] Theme editor (custom colors, fonts)
- [ ] Layout presets (Compact, Detailed, Photo-focused)

---

## 15.2 Tags & Smart Collections

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Per-dive tags | 📋 Planned | v1.5 | Medium | (Covered in Category 1.4) |
| Smart lists | 📋 Planned | v2.0 | Low | Auto-updating filtered views |

**v2.0 Tasks:**
- See Category 10.1 "Saved Filters" for Smart Logs implementation

---

## 15.3 Multi-User / Family Support

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Multiple divers per database | 📋 Planned | v2.0 | Low | DiveMate-style |
| Account switching | 📋 Planned | v2.0 | Low | Shared devices |
| Family subscription | 🔮 Future | v3.0 | Low | Monetization strategy |

**v2.0 Tasks:**
- [ ] Diver entity (name, certs, profile)
- [ ] Add `diver_id` to dives table
- [ ] Diver switcher in settings or main nav
- [ ] Per-diver stats and filtering

---

## 15.4 Accessibility & Localization

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Multi-language support | 📋 Planned | v2.0 | 🎯 High | i18n with ARB files |
| Screen reader support | 📋 Planned | v1.5 | Medium | Accessibility testing |
| Keyboard navigation | 📋 Planned | v1.5 | Low | Desktop accessibility |
| High contrast themes | 📋 Planned | v2.0 | Low | Accessibility feature |

**v1.5 Tasks:**
- [ ] Accessibility audit (screen reader testing on iOS/Android)
- [ ] Semantic labels for all interactive elements
- [ ] Focus order testing and fixes
- [ ] Keyboard shortcuts (desktop)

**v2.0 Tasks:**
- [ ] flutter_localizations integration
- [ ] ARB files for: English, Spanish, French, German, Italian, Dutch, Portuguese
- [ ] Localized date/time/number formats
- [ ] RTL language support (Arabic, Hebrew)
- [ ] Translation management workflow (POEditor, Crowdin)

---

# Category 16: Manufacturer-Specific & Advanced Features

## 16.1 Advanced Hardware Integration

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Assistant dive computer (smartphone housing) | 🔮 Future | v3.0 | Low | Dive+ + Weefine style |
| Remote DC configuration | 📋 Planned | v2.0 | Low | Bluetooth settings sync |
| Firmware updates via app | 📋 Planned | v2.0 | Low | Shearwater-specific |

**v3.0 Tasks:**
- [ ] Bluetooth depth sensor integration (if hardware available)
- [ ] Real-time dive tracking mode (display current depth, time, NDL)
- [ ] Post-dive auto-upload from phone dive computer data

---

## 16.2 Partner Ecosystem Integration

| Feature | Status | Phase | Priority | Notes |
|---------|--------|-------|----------|-------|
| Shearwater Cloud sync | 📋 Planned | v2.0 | Low | API integration |
| Garmin Dive sync | 📋 Planned | v2.0 | Low | Import from Garmin |
| PADI eCard integration | 📋 Planned | v2.0 | Low | Display PADI certs |

**v2.0 Tasks:**
- [ ] Shearwater Cloud API (import dives from cloud)
- [ ] Garmin Connect API (import Descent dive activities)
- [ ] PADI app integration (OAuth, fetch eCards)

---

# Implementation Priorities by Phase

## ✅ MVP (Complete)

**Completed Features:**
- Core dive logging (CRUD, detail, list)
- Dive profiles with charts
- Multi-tank support with gas mixes
- Dive sites with map view
- Equipment management with service tracking
- Equipment sets
- Marine life species tracking
- Basic statistics (total dives, depth distribution, dives by month, top sites)
- CSV, UDDF, PDF import/export
- Database backup/restore
- Settings (units, theme, defaults)
- Search and filtering

**Lines of Code:** ~14,305 Dart lines across 45 files

---

## 🟡 v1.0 (Production Release) - Est. 3-4 Months

**Goal:** Production-ready app suitable for 80% of recreational divers

**Critical Path Features:**

### Photos & Media (🎯 HIGHEST PRIORITY)
- [ ] Photo/video attachment to dives
- [ ] Photo gallery view
- [ ] Caption and metadata
- [ ] Export dives with photos

### Buddy System (🎯 HIGH PRIORITY)
- [ ] Buddy entity and CRUD
- [ ] Convert dive buddy field to many-to-many relationship
- [ ] Buddy roles (buddy, guide, instructor)
- [ ] Buddy detail page with shared dive history

### Certifications (🎯 HIGH PRIORITY)
- [ ] Certification entity and CRUD
- [ ] Certification card photo storage
- [ ] Expiry warnings
- [ ] Certifications page

### Service Records (🎯 HIGH PRIORITY)
- [ ] Service record entity and CRUD
- [ ] Service history per equipment item
- [ ] Service log export

### Dive Conditions Enhancements
- [ ] Current, swell, entry/exit method fields
- [ ] Water type field
- [ ] Boat name, operator, dive center fields

### Dive Center/Operator Management
- [ ] Dive center entity and CRUD
- [ ] Link dives to dive centers
- [ ] Dive center detail page

### Equipment Enhancements
- [ ] Equipment size field
- [ ] Equipment status field
- [ ] Equipment set templates
- [ ] Weight system and amount fields

### UX Improvements
- [ ] Zoom/pan on profile charts
- [ ] Touch markers on profiles
- [ ] Auto-capture GPS on mobile (dive creation)
- [ ] Reverse geocoding for sites
- [ ] Map marker clustering
- [ ] "Records" page (deepest, longest, coldest, etc.)

### Testing & Quality
- [ ] Unit tests for repositories (80% coverage goal)
- [ ] Widget tests for key flows
- [ ] Integration tests (dive creation, import, export)
- [ ] Performance testing (1000+ dives)
- [ ] Error handling improvements
- [ ] Fix N+1 query issues in dive repository

**Estimated Effort:**
- Photos: 2 weeks
- Buddies: 1.5 weeks
- Certifications: 1.5 weeks
- Service Records: 1 week
- Dive Centers: 1 week
- Testing: 2 weeks
- Polish & bug fixes: 2 weeks
- **Total: ~11 weeks**

---

## 📋 v1.5 (Technical Diving & DC Integration) - Est. 4-6 Months After v1.0

**Goal:** Advanced features for technical divers and dive computer users

**Major Features:**

### Dive Computer Integration (🎯 CRITICAL)
- [ ] libdivecomputer FFI integration
- [ ] Bluetooth connection manager
- [ ] USB device enumeration
- [ ] Device detection and pairing UI
- [ ] Download wizard with progress
- [ ] 300+ model support
- [ ] Duplicate detection
- [ ] Conflict resolution
- [ ] Dive computer entity and management
- [ ] Last download timestamp tracking

### Decompression & Dive Planning (🎯 CRITICAL)
- [ ] Bühlmann ZH-L16C algorithm implementation
- [ ] Gradient factors configuration
- [ ] Tissue loading calculations
- [ ] NDL calculator
- [ ] Ceiling calculation and display
- [ ] TTS (Time To Surface)
- [ ] Deco schedule generation
- [ ] Dive planner page (multi-level, multi-gas)
- [ ] Repetitive dive planning
- [ ] Gas consumption projections
- [ ] Save/load planned dives

### Technical Diving Support
- [ ] Profile event markers (gas switches, deco stops, alerts)
- [ ] Ascent rate warnings
- [ ] CNS O₂ toxicity tracking
- [ ] OTU calculations
- [ ] ppO₂ graph for CCR dives
- [ ] CCR dive mode (setpoints, diluent, bailout)
- [ ] Gas switch visualization on profile
- [ ] SAC/RMV per segment
- [ ] MOD/END/Best-Mix calculators page

### Photo Enhancements
- [ ] Bulk photo import with timestamp matching
- [ ] EXIF GPS extraction
- [ ] Auto-suggest sites from photo GPS
- [ ] Photo thumbnail caching

### Advanced Features
- [ ] Tags system (many-to-many)
- [ ] Tag-based filtering
- [ ] Trip grouping
- [ ] Trip summary pages
- [ ] Offline map tile caching
- [ ] Map region download for offline
- [ ] Species detail pages with photos
- [ ] Species statistics

### Data Portability
- [ ] Excel export
- [ ] KML export (Google Earth)
- [ ] DAN DL7 export
- [ ] Import from Subsurface, MacDive, Diving Log
- [ ] Import wizard with format detection

### UX & Accessibility
- [ ] iOS shortcuts, Android widgets
- [ ] Screen reader support
- [ ] Keyboard navigation (desktop)
- [ ] Accessibility audit and fixes

**Estimated Effort:**
- DC Integration: 6-8 weeks
- Deco Algorithms: 4-6 weeks
- Dive Planner: 3-4 weeks
- Technical Diving: 2-3 weeks
- Photos: 2 weeks
- Other Features: 4-5 weeks
- Testing: 3-4 weeks
- **Total: ~24-30 weeks**

---

## 📋 v2.0 (Social, Cloud & Community) - Est. 8-12 Months After v1.0

**Goal:** Community platform with optional cloud sync

**Major Features:**

### Cloud Sync & Multi-Device
- [ ] Backend service (Firebase/Supabase/custom)
- [ ] User authentication
- [ ] Opt-in cloud sync
- [ ] Sync engine (bidirectional, incremental)
- [ ] Conflict resolution
- [ ] Multi-device support
- [ ] Automatic cloud backups

### Community Features
- [ ] Public profiles
- [ ] Community dive site database
- [ ] Site photos, reviews, ratings
- [ ] Discover nearby sites
- [ ] Share dives to social media
- [ ] Generate shareable images
- [ ] Public dive view pages

### Advanced Statistics & Reports
- [ ] SAC trend charts
- [ ] Dive frequency charts
- [ ] Temperature preference charts
- [ ] Advanced analytics dashboard
- [ ] Year-in-review auto-generation
- [ ] Saved filters (Smart Logs)
- [ ] Custom PDF report templates

### Advanced Customization
- [ ] Customizable dive list columns
- [ ] Theme editor
- [ ] Layout presets
- [ ] Multi-diver support (family accounts)
- [ ] Diver switching

### Localization
- [ ] i18n implementation
- [ ] 7+ language translations
- [ ] RTL support
- [ ] Localized formats

### Partner Integrations
- [ ] Shearwater Cloud API
- [ ] Garmin Connect API
- [ ] PADI eCard integration
- [ ] divelogs.de API

### Advanced Features
- [ ] Profile editing (smoothing, outliers)
- [ ] Manual profile drawing
- [ ] Profile comparison (buddies)
- [ ] Species tagging in photos
- [ ] Color correction filters
- [ ] HTML export
- [ ] Digital signatures

**Estimated Effort:**
- Backend & Sync: 8-10 weeks
- Community Features: 6-8 weeks
- Advanced Stats: 3-4 weeks
- Localization: 4-5 weeks
- Integrations: 4-5 weeks
- Other Features: 4-5 weeks
- Testing: 4-5 weeks
- **Total: ~33-42 weeks**

---

## 🔮 v3.0 (AI & Advanced Platform) - 12-18+ Months

**Goal:** Next-generation dive logging with AI and advanced hardware integration

**Features:**
- [ ] Species recognition from photos (ML model)
- [ ] Assistant dive computer (smartphone in housing)
- [ ] Real-time dive tracking mode
- [ ] Dive trip booking & commerce
- [ ] Course booking integration
- [ ] Family subscription plans
- [ ] Advanced profile analytics
- [ ] Predictive dive planning (AI suggestions)
- [ ] Social networking features
- [ ] Buddy finding / matching
- [ ] Dive group organization
- [ ] Event planning
- [ ] Web-based dive planning tools

**Estimated Effort:** Ongoing development post-v2.0

---

# Data Model Extensions Required

## New Tables for v1.0

```sql
-- Buddies
CREATE TABLE buddies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  certification_level TEXT,
  agency TEXT,
  photo_path TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Dive Buddies (many-to-many with roles)
CREATE TABLE dive_buddies (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  buddy_id TEXT NOT NULL REFERENCES buddies(id) ON DELETE CASCADE,
  role TEXT NOT NULL, -- Buddy, Guide, Instructor, Student, Solo
  created_at INTEGER NOT NULL,
  UNIQUE(dive_id, buddy_id)
);

-- Certifications
CREATE TABLE certifications (
  id TEXT PRIMARY KEY,
  agency TEXT NOT NULL,
  level TEXT NOT NULL,
  cert_number TEXT,
  issue_date INTEGER NOT NULL,
  expiry_date INTEGER,
  instructor_name TEXT,
  card_image_path TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Service Records
CREATE TABLE service_records (
  id TEXT PRIMARY KEY,
  equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  service_date INTEGER NOT NULL,
  shop_name TEXT,
  cost_currency TEXT,
  cost_amount REAL,
  work_performed TEXT,
  next_service_due INTEGER,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Dive Centers / Operators
CREATE TABLE dive_centers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT,
  country TEXT,
  gps_latitude REAL,
  gps_longitude REAL,
  phone TEXT,
  email TEXT,
  website TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Extend dives table
ALTER TABLE dives ADD COLUMN dive_center_id TEXT REFERENCES dive_centers(id);
ALTER TABLE dives ADD COLUMN boat_name TEXT;
ALTER TABLE dives ADD COLUMN operator_name TEXT;
ALTER TABLE dives ADD COLUMN current_direction TEXT;
ALTER TABLE dives ADD COLUMN current_strength TEXT;
ALTER TABLE dives ADD COLUMN swell_height_meters REAL;
ALTER TABLE dives ADD COLUMN entry_method TEXT;
ALTER TABLE dives ADD COLUMN exit_method TEXT;
ALTER TABLE dives ADD COLUMN water_type TEXT;
ALTER TABLE dives ADD COLUMN weight_system TEXT;
ALTER TABLE dives ADD COLUMN total_weight_kg REAL;
ALTER TABLE dives ADD COLUMN is_favorite INTEGER DEFAULT 0;

-- Extend equipment table
ALTER TABLE equipment ADD COLUMN size TEXT;
ALTER TABLE equipment ADD COLUMN status TEXT DEFAULT 'Active';

-- Extend dive_sites table
ALTER TABLE dive_sites ADD COLUMN typical_depth_min REAL;
ALTER TABLE dive_sites ADD COLUMN typical_depth_max REAL;
ALTER TABLE dive_sites ADD COLUMN difficulty TEXT;
ALTER TABLE dive_sites ADD COLUMN hazards TEXT;
ALTER TABLE dive_sites ADD COLUMN access_notes TEXT;
ALTER TABLE dive_sites ADD COLUMN mooring_number TEXT;
ALTER TABLE dive_sites ADD COLUMN parking_info TEXT;
```

## New Tables for v1.5

```sql
-- Tags
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  created_at INTEGER NOT NULL
);

-- Dive Tags (many-to-many)
CREATE TABLE dive_tags (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  UNIQUE(dive_id, tag_id)
);

-- Trips
CREATE TABLE trips (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER NOT NULL,
  location TEXT,
  resort_name TEXT,
  liveaboard_name TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Extend dives table
ALTER TABLE dives ADD COLUMN trip_id TEXT REFERENCES trips(id);

-- Dive Computers
CREATE TABLE dive_computers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  manufacturer TEXT NOT NULL,
  model TEXT NOT NULL,
  serial_number TEXT,
  connection_type TEXT, -- USB, BT Classic, BLE
  connection_address TEXT, -- COM port, BT address
  last_download_timestamp INTEGER,
  last_used INTEGER,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Extend dives table (track which computer)
ALTER TABLE dives ADD COLUMN computer_id TEXT REFERENCES dive_computers(id);

-- Gas Switches (profile events)
CREATE TABLE gas_switches (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  tank_id TEXT NOT NULL REFERENCES dive_tanks(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL
);

-- Profile Events
CREATE TABLE profile_events (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,
  event_type TEXT NOT NULL, -- Descent, Ascent, SafetyStop, DecoStop, Alert, GasSwitch
  description TEXT,
  created_at INTEGER NOT NULL
);

-- CCR Support
ALTER TABLE dives ADD COLUMN dive_mode TEXT DEFAULT 'OC'; -- OC, CCR, SCR
ALTER TABLE dive_tanks ADD COLUMN tank_role TEXT DEFAULT 'BackGas'; -- BackGas, Stage, Deco, Bailout, Diluent

-- Extend species table
ALTER TABLE species ADD COLUMN scientific_name TEXT;
ALTER TABLE species ADD COLUMN taxonomy_class TEXT;
ALTER TABLE species ADD COLUMN image_url TEXT;
ALTER TABLE species ADD COLUMN description TEXT;

-- Extend dive_sites table (altitude)
ALTER TABLE dive_sites ADD COLUMN altitude_meters REAL;
```

## New Tables for v2.0

```sql
-- Users (for cloud sync)
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Divers (for multi-user support)
CREATE TABLE divers (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  name TEXT NOT NULL,
  date_of_birth INTEGER,
  blood_type TEXT,
  allergies TEXT,
  medications TEXT,
  medical_clearance_date INTEGER,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  emergency_contact_relationship TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Extend all major tables for sync
ALTER TABLE dives ADD COLUMN last_modified_at INTEGER;
ALTER TABLE dives ADD COLUMN device_id TEXT;
ALTER TABLE dives ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE dives ADD COLUMN diver_id TEXT REFERENCES divers(id);

-- Saved Filters (Smart Logs)
CREATE TABLE saved_filters (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  filter_json TEXT NOT NULL, -- JSON-encoded filter criteria
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

---

# Dependencies & Prerequisites

## Technical Dependencies

### For v1.0:
- **Photos:** image_picker, photo_view (already in pubspec.yaml ✅)
- **GPS:** geolocator, geocoding (need to add)
- **Testing:** mockito, flutter_test (mockito already added ✅)

### For v1.5:
- **Dive Computers:**
  - libdivecomputer C library (external dependency)
  - dart:ffi for native bindings
  - flutter_blue_plus (already in pubspec.yaml ✅)
  - usb_serial (for USB dive computers - add)
- **Decompression:**
  - Custom Dart implementation (no external lib needed)
  - Complex math library support

### For v2.0:
- **Backend:** Firebase SDK OR Supabase SDK OR custom REST API
- **Auth:** firebase_auth or supabase_auth
- **Storage:** firebase_storage or supabase_storage
- **i18n:** flutter_localizations, intl (already in pubspec.yaml ✅)

## Feature Dependencies (Blockers)

- **Photos (v1.0)** → blocks: EXIF GPS (v1.5), Species Tagging (v2.0), Photo Color Correction (v2.0)
- **Buddies (v1.0)** → blocks: Buddy Signatures (v1.5), Profile Sharing (v2.0)
- **Tags (v1.5)** → blocks: Smart Logs (v2.0), Tag-based Stats (v2.0)
- **Deco Algorithm (v1.5)** → blocks: Dive Planner (v1.5), NDL Display (v1.5), Deco Calculator (v1.5)
- **Dive Computers (v1.5)** → blocks: Computer-specific features (v2.0)
- **Cloud Sync (v2.0)** → blocks: Community Features (v2.0), Social Sharing (v2.0)

---

# Non-Functional Requirements

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| App launch time | <2 seconds | Cold start to home screen |
| Dive list load (100 dives) | <500ms | With thumbnails |
| Dive detail load | <200ms | Including profile chart |
| Search results | <300ms | Full-text search |
| Export 100 dives to PDF | <5 seconds | With photos |
| Database size (1000 dives) | <50MB | Excluding photos |
| Memory usage | <200MB | On mobile devices |

## Platform Support

| Platform | v1.0 | v1.5 | v2.0 | Notes |
|----------|------|------|------|-------|
| iOS | ✅ | ✅ | ✅ | iOS 13+ |
| Android | ✅ | ✅ | ✅ | Android 7+ |
| macOS | ✅ | ✅ | ✅ | macOS 11+ |
| Windows | ✅ | ✅ | ✅ | Windows 10+ |
| Linux | ✅ | ✅ | ✅ | Desktop Linux |
| Web | 🔮 | 🔮 | ✅ | v2.0+ (cloud sync required) |

## Testing Coverage Targets

| Phase | Unit Tests | Widget Tests | Integration Tests |
|-------|------------|--------------|-------------------|
| v1.0 | 80% | 60% | Key flows |
| v1.5 | 85% | 70% | All features |
| v2.0 | 90% | 80% | Comprehensive |

---

# Success Metrics

## v1.0 Release Criteria
- [ ] All critical v1.0 features implemented
- [ ] 80%+ unit test coverage
- [ ] 60%+ widget test coverage
- [ ] Zero critical bugs
- [ ] <5 known medium-priority bugs
- [ ] Performance targets met
- [ ] App store submissions approved (iOS, Android)
- [ ] Documentation complete (user guide, FAQ)

## v1.5 Release Criteria
- [ ] Dive computer import working for 50+ models
- [ ] Bühlmann algorithm validated against known tables
- [ ] Dive planner producing correct deco schedules
- [ ] Beta testing with 100+ technical divers
- [ ] Performance with 5000+ dives tested

## v2.0 Release Criteria
- [ ] Cloud sync tested with 10,000+ users
- [ ] Localization complete for 7+ languages
- [ ] Native speakers validate translations
- [ ] Community features tested with beta users
- [ ] Privacy policy and GDPR compliance validated

---

# Risk Assessment

## High-Risk Items

| Risk | Impact | Mitigation |
|------|--------|------------|
| libdivecomputer integration complexity | High | Start early, allocate extra time, consider alternatives |
| Deco algorithm bugs (safety-critical) | Critical | Extensive testing, validation against known tables, disclaimer |
| Cloud sync data loss | High | Thorough testing, conflict resolution, backup strategy |
| Photo storage scaling | Medium | Compression, cloud storage option, local cleanup tools |
| Performance with large databases | Medium | Early performance testing, optimization, pagination |

## Medium-Risk Items

| Risk | Impact | Mitigation |
|------|--------|------------|
| Third-party API changes (Shearwater, Garmin) | Medium | Abstraction layer, fallback options |
| Platform-specific bugs (Bluetooth, USB) | Medium | Per-platform testing, community bug reports |
| Translation quality | Low | Native speaker validation, community contributions |

---

# Monetization Strategy (Future Consideration)

## Free Tier (Always Free)
- Unlimited local dives
- All core logging features
- CSV/UDDF/PDF export
- No ads, no tracking

## Premium Features (Optional Subscription - v2.0+)
- Cloud sync and backup
- Multi-device support
- Advanced statistics
- Community features
- Priority support
- Early access to new features

## Potential Revenue Streams (v3.0+)
- Premium subscription ($5/month, $50/year)
- Family plan (5 divers, $10/month)
- Dive operator partnerships (commission on bookings)
- Sponsored dive site content
- Equipment vendor affiliates (Amazon, ScubaPro, etc.)

**Philosophy:** Keep core logging free forever, charge for convenience (cloud) and community features.

---

# Development Workflow Recommendations

## Sprint Structure (2-week sprints)

### v1.0 Sprints (11 weeks = 5.5 sprints)
1. **Sprint 1-2:** Photos & Media (4 weeks)
2. **Sprint 3:** Buddy System (2 weeks)
3. **Sprint 4:** Certifications + Service Records (2 weeks)
4. **Sprint 5:** Dive Centers, Conditions, Equipment (2 weeks)
5. **Sprint 6:** Testing & Quality (2 weeks)

### v1.5 Sprints (24-30 weeks = 12-15 sprints)
1. **Sprints 1-4:** Dive Computer Integration (8 weeks)
2. **Sprints 5-7:** Deco Algorithm + Planner (6 weeks)
3. **Sprints 8-9:** Technical Diving Features (4 weeks)
4. **Sprints 10-11:** Photo Enhancements, Trips, Tags (4 weeks)
5. **Sprints 12-13:** Offline Maps, Species, Import/Export (4 weeks)
6. **Sprints 14-15:** Testing, Polish, Docs (4 weeks)

## Git Branching Strategy
- `main` - production-ready code
- `develop` - integration branch for next release
- `feature/feature-name` - feature branches
- `release/v1.0.0` - release candidate branches
- `hotfix/bug-description` - production hotfixes

## Code Review Requirements
- All PRs require review
- Automated CI checks (linting, tests)
- No direct commits to main/develop

---

# Appendix: Competitor Feature Matrix

## Feature Parity Checklist

| Feature Category | Subsurface | MacDive | Shearwater Cloud | Diving Log | Submersion v1.0 | Submersion v1.5 | Submersion v2.0 |
|------------------|------------|---------|------------------|------------|-----------------|-----------------|-----------------|
| **Core Logging** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Dive Profiles** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Multi-Tank** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Dive Computers** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Photos** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Equipment Mgmt** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Marine Life** | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Statistics** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Deco Algorithm** | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Dive Planner** | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **CCR Support** | ✅ | Partial | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Cloud Sync** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **Mobile App** | ✅ | ✅ | ✅ | Partial | ✅ | ✅ | ✅ |
| **Desktop App** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Offline Support** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **UDDF Support** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Buddy Mgmt** | Partial | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Certifications** | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Maps** | Partial | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Community** | ❌ | ❌ | Partial | ❌ | ❌ | ❌ | ✅ |

---

# Conclusion

This roadmap represents a comprehensive plan to build Submersion into a best-in-class dive logging platform. The phased approach ensures:

1. **v1.0** delivers a production-ready app for recreational divers
2. **v1.5** adds advanced features for technical divers and dive computer users
3. **v2.0** builds a community platform with optional cloud features
4. **v3.0** introduces AI and next-generation features

The local-first, privacy-focused architecture differentiates Submersion from cloud-dependent competitors while the open-source GPL-3.0 license ensures long-term community sustainability.

**Next Steps:**
1. Review and approve this roadmap
2. Prioritize v1.0 features for first sprint
3. Begin implementation with Photos & Media feature
4. Establish testing framework
5. Plan for v1.0 release in Q2 2025

---

**Document Metadata:**
- **Version:** 1.0
- **Last Updated:** 2025-12-11
- **Author:** Development Team
- **Status:** Draft for Review
- **Next Review:** After v1.0 Sprint 1
