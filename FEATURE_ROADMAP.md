# Submersion Feature Roadmap
## Comprehensive Development Plan

> **Last Updated:** 2025-12-17
> **Current Version:** 1.1.0 (v1.1 Complete)
> **Status:** v1.0 ✅ COMPLETE | v1.1 ✅ COMPLETE | v1.5 📋 Planned

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
| Runtime tracking | 📋 Planned | v1.5 | Add separate field for total runtime |
| Custom dive types (user-defined) | 📋 Planned | v1.5 | |

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
| Weather | 📋 Planned | v1.5 | Free-text or API integration |
| Altitude | 📋 Planned | v1.5 | For altitude dive calculations |

**v1.5 Tasks:**
- [ ] Weather API integration (OpenWeatherMap) with historical data
- [ ] Tide information integration
- [ ] Auto-populate conditions from GPS + date/time

---

## 1.4 Notes & Tags

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Free-text notes | ✅ Implemented | MVP | Rich text field |
| Star rating (1-5) | ✅ Implemented | MVP | |
| Favorite flag | ✅ Implemented | v1.1 | Boolean flag with toggle in list/detail |
| Tags (many-to-many with colors) | ✅ Implemented | v1.1 | Chip selector with autocomplete |
| Tag-based filtering | ✅ Implemented | v1.1 | With tag statistics |
| Smart collections based on tags | 📋 Planned | v2.0 | Saved filters |

---

# Category 2: Dive Profile & Telemetry

## 2.1 Profile Visualization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Time-depth profile chart | ✅ Implemented | MVP | Using fl_chart |
| Temperature overlay | ✅ Implemented | MVP | Toggle on/off |
| Zoom and pan controls | ✅ Implemented | v1.1 | Pinch/scroll zoom, pan when zoomed |
| Touch markers/tooltips | ✅ Implemented | v1.1 | Shows depth, time, temp at touch point |
| Profile markers/events | 📋 Planned | v1.5 | Descent, safety stop, gas switch, alerts |
| Ascent rate indicators | 📋 Planned | v1.5 | Color-code dangerous ascents |
| Ceiling / NDL curve | 📋 Planned | v1.5 | Requires deco algorithm |
| ppO₂ curve, CNS/OTU | 📋 Planned | v1.5 | Technical diving |
| SAC/RMV overlay | 📋 Planned | v1.5 | Instantaneous gas consumption |
| Profile export as PNG | 📋 Planned | v2.0 | Export chart image for sharing |

**v1.5 Tasks:**
- [ ] Profile event markers (table: `dive_profile_events` with type, timestamp, description)
- [ ] Ascent rate calculation and color overlay (green <9m/min, yellow 9-12, red >12)
- [ ] NDL curve from Bühlmann implementation
- [ ] CNS O₂ toxicity tracking for nitrox/trimix
- [ ] OTU (Oxygen Tolerance Unit) calculation
- [ ] ppO₂ graph for CCR dives

---

## 2.2 Multi-Profile Support

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multiple computers per dive | 📋 Planned | v1.5 | Backup computer, bottom timer |
| Profile comparison (buddies) | 📋 Planned | v2.0 | Side-by-side view |
| Profile merging | 📋 Planned | v2.0 | Combine multiple sources |

**v1.5 Tasks:**
- [ ] Add `computer_id` to dive_profiles table
- [ ] UI to select active profile when multiple exist
- [ ] Indicate which profile is "primary" for statistics

**v2.0 Tasks:**
- [ ] Side-by-side profile comparison view
- [ ] Buddy profile import (from shared UDDF)

---

## 2.3 Profile Editing

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Smoothing / cleaning bad samples | 📋 Planned | v2.0 | Outlier removal |
| Manual profile drawing | 📋 Planned | v2.0 | For dives without computer |
| Segment editing | 📋 Planned | v2.0 | Adjust timestamps, depths |

**v2.0 Tasks:**
- [ ] Profile outlier detection algorithm (sudden depth jumps)
- [ ] Smoothing algorithm (moving average)
- [ ] Manual profile editor with touch/mouse drawing
- [ ] Segment selection and adjustment UI
- [ ] Profile export as PNG image for sharing

---

# Category 3: Dive Computer Connectivity

## 3.1 Connectivity Types

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| USB cable transfers | 📋 Planned | v1.5 | Via libdivecomputer |
| Bluetooth Classic | 📋 Planned | v1.5 | flutter_blue_plus |
| Bluetooth LE (BLE) | 📋 Planned | v1.5 | flutter_blue_plus |
| Infrared (legacy) | 🔮 Future | v3.0 | Limited hardware support |
| Wi-Fi / cloud devices | 📋 Planned | v2.0 | Garmin, Shearwater cloud API |

**v1.5 Tasks (Critical Path):**
- [ ] Integrate libdivecomputer via FFI (Dart bindings to C library)
- [ ] Device detection and pairing UI
- [ ] Bluetooth connection manager (scanning, pairing, reconnection)
- [ ] USB device enumeration and selection
- [ ] Progress indicator during download (% complete, dive count)

---

## 3.2 Device Support

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| 300+ dive computer models | 📋 Planned | v1.5 | Via libdivecomputer |
| Per-device presets | 📋 Planned | v1.5 | Save connection settings |
| Favorite devices | 📋 Planned | v1.5 | Quick-select dropdown |

**v1.5 Tasks:**
- [ ] Create `dive_computers` table (name, manufacturer, model, connection_type, last_used)
- [ ] Device library with 300+ model definitions from libdivecomputer
- [ ] Auto-detection of device model via USB VID/PID or BT service UUID
- [ ] Device configuration persistence (COM port, BT address, connection params)

---

## 3.3 Download Behavior

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Download new dives only | 📋 Planned | v1.5 | Track last download timestamp |
| Force download all | 📋 Planned | v1.5 | Override with checkbox |
| Auto-download when connected | 📋 Planned | v2.0 | Background sync |
| Duplicate detection | 📋 Planned | v1.5 | Match by date+time+depth |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Rename dive computers | 📋 Planned | v1.5 | "Bob's Perdix", "Backup Computer" |
| Associate dives with computer | 📋 Planned | v1.5 | Which computer recorded dive |
| Firmware update via app | 📋 Planned | v2.0 | Shearwater-specific |
| Remote configuration | 📋 Planned | v2.0 | Set gases, alarms, units |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multi-tank support | ✅ Implemented | MVP | Unlimited tanks with add/remove buttons |
| Tank volume, pressures | ✅ Implemented | MVP | Start/end/working pressure |
| Tank material | ✅ Implemented | v1.1 | Steel, Aluminum, Carbon Fiber |
| Tank role | ✅ Implemented | v1.1 | Back gas, stage, deco, bailout, sidemount, pony |
| Tank presets | ✅ Implemented | v1.1 | AL40/63/80, HP80/100/120, LP85, Steel 10/12/15L |
| Save custom tank presets | 📋 Planned | v1.5 | User-defined configurations |

---

## 4.2 Gas Composition

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| O₂ %, He %, N₂ balance | ✅ Implemented | MVP | Air, Nitrox, Trimix |
| Gas naming | ✅ Implemented | v1.1 | "EAN32", "TMX 18/45" auto-generated |
| Gas mix templates | ✅ Implemented | v1.1 | Air, EAN32/36/40/50, O₂, Trimix blends |
| Gas changes on profile | 📋 Planned | v1.5 | Mark switch points |

**v1.5 Tasks:**
- [ ] Gas switch events on profile (table: `gas_switches` with timestamp, tank_id)
- [ ] Profile segment coloring based on active gas
- [ ] Gas switch markers on profile chart

---

## 4.3 Calculated Metrics

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| SAC / RMV (per dive) | ✅ Implemented | MVP | Surface Air Consumption Rate |
| MOD calculation | ✅ Implemented | MVP | Maximum Operating Depth in entity |
| END calculation | ✅ Implemented | MVP | Equivalent Narcotic Depth in entity |
| SAC per segment | 📋 Planned | v1.5 | Time-based or depth-based segments |
| SAC per cylinder | 📋 Planned | v1.5 | For multi-tank dives |
| CNS / OTU tracking | 📋 Planned | v1.5 | O₂ toxicity tracking |

**v1.5 Tasks:**
- [ ] Segment SAC calculation (5-minute segments or depth-based)
- [ ] SAC trend chart (line chart showing SAC over time for a dive)
- [ ] CNS% calculation per dive (accumulated O₂ exposure)
- [ ] OTU calculation (Oxygen Tolerance Units)
- [ ] CNS/OTU display on dive detail page with warnings if exceeded limits

---

## 4.4 Deco & Algorithms

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Bühlmann ZH-L16 with GF | 📋 Planned | v1.5 | Industry-standard deco algorithm |
| Calculated vs DC ceiling | 📋 Planned | v1.5 | Compare app calc with computer |
| NDL display | 📋 Planned | v1.5 | No Decompression Limit |
| OC/CCR support | 📋 Planned | v1.5 | Open Circuit / Closed Circuit Rebreather |
| Setpoints, diluent, bailout | 📋 Planned | v1.5 | CCR-specific fields |

**v1.5 Tasks (Deco Algorithm Implementation):**
- [ ] Implement Bühlmann ZH-L16C algorithm in Dart
- [ ] Gradient Factors (GF Low/High) configuration in settings
- [ ] 16-compartment tissue loading calculation
- [ ] NDL calculation for any depth/gas combination
- [ ] Ceiling calculation (M-values with GF)
- [ ] Deco schedule generation (stop depth/time)
- [ ] Display NDL/ceiling on profile chart
- [ ] TTS (Time To Surface) calculation

**v1.5 CCR Support:**
- [ ] Add `dive_mode` enum (OC, CCR, SCR) to dives table
- [ ] CCR-specific fields: setpoint(s), diluent, bailout gas
- [ ] Setpoint changes as profile events
- [ ] ppO₂ calculation and display

---

## 4.5 Planning Utilities

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Dive planner (multi-level) | 📋 Planned | v1.5 | Plan dives before doing them |
| Multi-gas planning | 📋 Planned | v1.5 | Gas switches, deco gases |
| Repetitive dive planning | 📋 Planned | v1.5 | Surface interval, tissue loading |
| Gas consumption projections | 📋 Planned | v1.5 | Based on SAC history |
| What-if scenarios | 📋 Planned | v2.0 | Deeper/longer/different gas |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Manage sites, regions, countries | ✅ Implemented | MVP | Full CRUD |
| Depth range (min/max) | ✅ Implemented | v1.1 | |
| Difficulty levels | ✅ Implemented | v1.1 | Beginner/Intermediate/Advanced/Technical |
| Hazards, access notes | ✅ Implemented | v1.1 | Free-text fields |
| Mooring numbers, parking | ✅ Implemented | v1.1 | For boat/shore diving |
| Common marine life | 📋 Planned | v1.5 | Link species to sites |

**v1.5 Tasks:**
- [ ] Many-to-many relationship between sites and species (common sightings)
- [ ] Display "Commonly Seen" species list on site detail page

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
| Dive Activity Map | 📋 Planned | v1.5 | Heat map of all dives |
| Offline maps | 📋 Planned | v1.5 | For travel to remote areas |

**v1.5 Tasks:**
- [ ] Offline map tile caching using flutter_map tile storage
- [ ] Download map region for offline use (bounding box selector)
- [ ] Heat map visualization of dive activity (intensity = dive count)

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
| Push notifications | 📋 Planned | v1.5 | For overdue service |

**v1.5 Tasks:**
- [ ] Local notifications for service due dates
- [ ] Configurable reminder advance (7 days, 14 days, 30 days before due)

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

**v1.5 Tasks:**
- [ ] Import buddies from contacts (mobile)
- [ ] Share dives with buddies (export UDDF, send via email/messaging)

---

## 7.2 Digital Signatures

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Buddy signatures | 📋 Planned | v1.5 | For training logs |
| Instructor signatures | 📋 Planned | v1.5 | Professional logs |
| Signature capture | 📋 Planned | v1.5 | Touch/stylus drawing |

**v1.5 Tasks:**
- [ ] Signature widget (canvas drawing with save as PNG)
- [ ] Store signatures in Media table linked to dives
- [ ] Display signatures on dive detail page and PDF export
- [ ] Timestamp and signer name with signature

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
| Scanned card images | 📋 Planned | v2.0 | Deferred with photos |

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
| Associate with courses | 📋 Planned | v1.5 | Course entity |
| Instructor comments | 📋 Planned | v1.5 | Rich text field |
| E-signatures | 📋 Planned | v1.5 | Digital signature |

**v1.5 Tasks:**
- [ ] Course entity (name, agency, start_date, completion_date, instructor, cert_id)
- [ ] Link dives to courses (many-to-one)
- [ ] Instructor notes field on dives
- [ ] Training log export (PDF with instructor signature)

---

## 8.4 Personal & Medical Data

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Medical clearance dates | 📋 Planned | v1.5 | For commercial divers |
| Emergency contacts | 📋 Planned | v1.5 | Critical for safety |
| Medical documents | 📋 Planned | v2.0 | PDF storage |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Water type | ✅ Implemented | v1.0 | Fresh, salt, brackish |
| Hazards | ✅ Implemented | v1.1 | Site-level hazards field |
| Entry altitude | 📋 Planned | v1.5 | For altitude dive tables |
| Tides | 📋 Planned | v1.5 | State, height, time |

**v1.5 Tasks:**
- [ ] Tide API integration (NOAA, Tides.info)
- [ ] Display tide state at dive time
- [ ] Altitude field with warning if >300m (affects NDL)

---

## 9.2 Marine Life Tracking

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Species database | ✅ Implemented | MVP | 40+ pre-seeded species |
| Tag species per dive | ✅ Implemented | MVP | Sightings with counts |
| Taxonomy, photos | 📋 Planned | v1.5 | Scientific names, images |
| Stats per species | 📋 Planned | v1.5 | First/last seen, depth range |
| Distribution map | 📋 Planned | v2.0 | Map of sightings |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Attach photos/videos to dives | 📋 Planned | v2.0 | Media table exists, needs UI |
| Auto-match by timestamp | 📋 Planned | v2.0 | EXIF datetime matching |
| Tag species in photos | 📋 Planned | v2.0 | Image annotation |
| Color correction | 📋 Planned | v2.0 | Blue filter removal |
| Depth/time overlay | 🔮 Future | v3.0 | Requires camera integration |

**v2.0 Tasks:**
- [ ] Photo/video picker in dive edit form
- [ ] Attach multiple media files to dive (many-to-many)
- [ ] Media storage strategy (local file copy vs reference, cloud upload option)
- [ ] Display photo gallery on dive detail page
- [ ] Full-screen photo viewer with swipe
- [ ] Caption and datetime per photo
- [ ] Export dive with photos (ZIP archive)
- [ ] Bulk photo import with auto-match to dives
- [ ] EXIF datetime parsing and fuzzy matching (within ±2 hours)
- [ ] GPS extraction from photos (suggest site creation)
- [ ] Photo thumbnail generation and caching
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
| Filter by tags, gas, gear | 📋 Planned | v1.5 | |
| Saved filters ("Smart Logs") | 📋 Planned | v2.0 | Persistent filter sets |

**v1.5 Tasks:**
- [ ] Expand filter UI with all available criteria (tags, equipment, buddy, gas mix, certification)
- [ ] "Advanced Search" page with all filter options
- [ ] Recent searches history
- [ ] Bulk export (export selected dives to CSV/UDDF/PDF)
- [ ] Bulk edit (change trip, add tag to multiple dives)

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
| SAC trends | 📋 Planned | v1.5 | Line chart over time |
| Temperature graphs | 📋 Planned | v1.5 | Preferred temp range |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| PDF logbook export | ✅ Implemented | MVP | Basic layout |
| Custom report designer | 📋 Planned | v2.0 | Drag-drop fields |
| Pre-made layouts | 📋 Planned | v1.5 | A5, 3-ring, agency style |
| Professional logs | 📋 Planned | v1.5 | For instructors, DMs |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Open-circuit planner | 📋 Planned | v1.5 | Multi-level plans |
| Multi-gas plans | 📋 Planned | v1.5 | With deco stops |
| Repetitive dive planning | 📋 Planned | v1.5 | Surface interval, tissue loading |
| Save planned dives | 📋 Planned | v1.5 | Mark as "planned" in DB |

*See "4.5 Planning Utilities" for detailed task list*

---

## 11.2 Deco Calculator

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Real-time simulation | 📋 Planned | v1.5 | Interactive depth/time |
| NDL, ceiling, tissue loading | 📋 Planned | v1.5 | Visual display |

**v1.5 Tasks:**
- [ ] Deco Calculator page (separate from planner)
- [ ] Sliders for depth, time, gas mix
- [ ] Real-time display of: NDL, ceiling, TTS, tissue loading bar chart (16 compartments)
- [ ] "Add to Planner" button to convert calc to plan

---

## 11.3 Gas Calculators

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| MOD calculator | ✅ Implemented | MVP | In GasMix entity |
| EAD / END calculator | ✅ Implemented | MVP | In GasMix entity |
| Best-mix calculator | 📋 Planned | v1.5 | Target depth → O₂% |
| Gas consumption calculator | 📋 Planned | v1.5 | Based on SAC, depth, time |
| Rock-bottom calculator | 📋 Planned | v1.5 | Emergency gas reserve |

**v1.5 Tasks:**
- [ ] Calculators page with tabs: MOD, Best Mix, Gas Consumption, Rock Bottom
- [ ] MOD: Input O₂%, ppO₂ limit → Output MOD
- [ ] Best Mix: Input target depth, ppO₂ limit → Output ideal O₂%
- [ ] Gas Consumption: Input depth, time, SAC, tank size → Output pressure consumed
- [ ] Rock Bottom: Input depth, ascent rate, SAC, buddy SAC, tank size → Output min reserve pressure

---

## 11.4 Convenience Tools

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Surface interval planner | 📋 Planned | v1.5 | How long to wait |
| Altitude conversion | 📋 Planned | v2.0 | Altitude dive tables |

**v1.5 Tasks:**
- [ ] Surface Interval Tool: Input previous dive (depth, time, gas) + desired next dive → Output min surface interval
- [ ] Display tissue loading chart showing saturation decreasing over time

---

# Category 12: Cloud Sync, Backup & Multi-Device

## 12.1 Cloud Accounts

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Anonymous usage | ✅ Implemented | MVP | Local-first, no account required |
| Optional cloud account | 📋 Planned | v2.0 | Opt-in only |

**v2.0 Tasks:**
- [ ] Backend service (Firebase, Supabase, or custom)
- [ ] User authentication (email/password, OAuth)
- [ ] Opt-in cloud sync toggle in settings
- [ ] Privacy policy and data handling docs

---

## 12.2 Synchronization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Desktop ↔ mobile ↔ web sync | 📋 Planned | v2.0 | Requires backend |
| Multi-device support | 📋 Planned | v2.0 | Login on multiple devices |
| Conflict resolution | 📋 Planned | v2.0 | Last-write-wins or manual |

**v2.0 Tasks:**
- [ ] Drift schema with `last_modified_at`, `device_id`, `is_deleted` for all tables
- [ ] Sync engine (bidirectional, incremental)
- [ ] Conflict detection and resolution UI
- [ ] Sync status indicator (last synced, pending changes)
- [ ] "Force push" and "force pull" options for troubleshooting

---

## 12.3 Backup

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Local backup export | ✅ Implemented | MVP | Full SQLite export |
| Online backup servers | 📋 Planned | v2.0 | Automatic cloud backup |
| Sync via Dropbox | 📋 Planned | v2.0 | 3rd-party storage sync |

**v2.0 Tasks:**
- [ ] Automatic daily backup to cloud (if opted in)
- [ ] Backup history (keep last N backups)
- [ ] Restore from cloud backup

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
| DAN DL7 export | 📋 Planned | v1.5 | Research data format |
| Excel export | 📋 Planned | v1.5 | .xlsx format |
| Google Earth KML export | 📋 Planned | v1.5 | Map all dive sites |
| HTML export | 📋 Planned | v2.0 | Web-viewable logbook |

**v1.5 Tasks:**
- [ ] DAN DL7 export (research format specification)
- [ ] Excel export with multiple sheets (dives, sites, equipment, statistics)
- [ ] KML export (placemark per dive site with description bubble)

**v2.0 Tasks:**
- [ ] HTML export (static website with CSS, images, interactive map)
- [ ] MySQL dump export (for migration to other systems)

---

## 13.2 Interoperability

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Import from Subsurface | 📋 Planned | v1.5 | UDDF or XML |
| Import from MacDive | 📋 Planned | v1.5 | CSV or proprietary format |
| Import from other apps | 📋 Planned | v1.5 | Diving Log, DiveMate, etc. |
| Upload to divelogs.de | 📋 Planned | v2.0 | API integration |
| Garmin Connect integration | 📋 Planned | v2.0 | Import Garmin watch dives |

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

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Universal CSV import | ✅ Implemented | MVP | Configurable column mapping |
| Format auto-detection | 📋 Planned | v1.5 | Guess format from headers |

**v1.5 Tasks:**
- [ ] Smart format detection (analyze CSV headers, suggest mapping)
- [ ] Import templates for common apps (save column mappings)
- [ ] Import validation (check required fields, data types)

---

# Category 14: Social, Community & Travel Features

## 14.1 Social Sharing

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Share dives to social media | 📋 Planned | v2.0 | FB, Instagram, Twitter |
| Generate composite images | 📋 Planned | v2.0 | Profile + photo + stats |
| Share links | 📋 Planned | v2.0 | Web view of dive (requires backend) |

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

**v2.0 Tasks:**
- [ ] Community backend (user accounts, public profiles)
- [ ] Public dive site database (user submissions)
- [ ] Site photos, reviews, difficulty ratings
- [ ] "Discover" tab with nearby sites, popular sites, new sites

---

## 14.3 Booking & Commerce

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
| Multiple divers per database | 📋 Planned | v2.0 | DiveMate-style |
| Account switching | 📋 Planned | v2.0 | Shared devices |
| Family subscription | 🔮 Future | v3.0 | Monetization strategy |

**v2.0 Tasks:**
- [ ] Diver entity (name, certs, profile)
- [ ] Add `diver_id` to dives table
- [ ] Diver switcher in settings or main nav
- [ ] Per-diver stats and filtering

---

## 15.3 Accessibility & Localization

| Feature | Status | Phase | Notes |
|---------|--------|-------|-------|
| Multi-language support | 📋 Planned | v2.0 | i18n with ARB files |
| Screen reader support | 📋 Planned | v1.5 | Accessibility testing |
| Keyboard navigation | 📋 Planned | v1.5 | Desktop accessibility |
| High contrast themes | 📋 Planned | v2.0 | Accessibility feature |

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
-- Species extensions: scientific_name, taxonomy_class, image_url
```

## v2.0 Tables (Planned)

```sql
-- users (for cloud sync)
-- divers (for multi-user support)
-- saved_filters (Smart Logs)
-- Sync fields: last_modified_at, device_id, is_deleted
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

## v1.5 (Planned)
- [ ] Dive computer import (50+ models)
- [ ] Bühlmann algorithm validated
- [ ] Dive planner with deco schedules
- [ ] Performance with 5000+ dives

## v2.0 (Planned)
- [ ] Cloud sync at scale
- [ ] 7+ language translations
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

# Monetization (Future)

**Free Forever:**
- Unlimited local dives
- All core logging features
- CSV/UDDF/PDF export
- No ads, no tracking

**Premium (v2.0+):**
- Cloud sync and backup
- Multi-device support
- Community features
- Advanced statistics

---

**Document Version:** 2.0  
**Last Updated:** 2025-12-17
