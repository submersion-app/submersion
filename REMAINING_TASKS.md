# Submersion - Remaining Tasks

> **Generated:** 2026-01-14
> **Source:** FEATURE_ROADMAP.md
> **Current Version:** 1.1.0 (v1.5 In Progress)

This document contains only the features and tasks that are **not yet completed**.

---

## Phase Summary

| Phase | Status | Remaining Focus |
|-------|--------|-----------------|
| **v1.5** | 🚧 In Progress | Remaining v1.5 items below |
| **v2.0** | 📋 Planned | Advanced features, social, backend |
| **v3.0** | 🔮 Future | Community platform, AI features |

---

# v1.5 Remaining Tasks

## Category 1: Core Dive Log Entry

### 1.2 Location & Site
- [ ] Trip templates (liveaboard, resort week, local weekend)
- [ ] Trip photo galleries (deferred with photos to v2.0)

---

## Category 5: Locations, Dive Sites & Maps

### 5.1 Dive Site Database
| Feature | Status | Notes |
|---------|--------|-------|
| Common marine life | 📋 Planned | Link species to sites |

**Tasks:**
- [ ] Many-to-many relationship between sites and species (common sightings)
- [ ] Display "Commonly Seen" species list on site detail page

### 5.2 GPS Integration
| Feature | Status | Notes |
|---------|--------|-------|
| GPS from photo EXIF | 📋 Planned | Extract and suggest site |

**Tasks:**
- [ ] EXIF parsing from photo attachments
- [ ] If photo has GPS and dive doesn't, suggest using photo GPS
- [ ] Bulk site creation from photo library

### 5.3 Maps & Visualization
| Feature | Status | Notes |
|---------|--------|-------|
| Dive Activity Map | 📋 Planned | Heat map of all dives |
| Offline maps | 📋 Planned | For travel to remote areas |

**Tasks:**
- [ ] Offline map tile caching using flutter_map tile storage
- [ ] Download map region for offline use (bounding box selector)
- [ ] Heat map visualization of dive activity (intensity = dive count)

---

## Category 6: Gear & Equipment Management

### 6.3 Maintenance
| Feature | Status | Notes |
|---------|--------|-------|
| Push notifications | 📋 Planned | For overdue service |

**Tasks:**
- [ ] Local notifications for service due dates
- [ ] Configurable reminder advance (7 days, 14 days, 30 days before due)

---

## Category 7: People - Buddies, Instructors, Agencies

### 7.1 Buddy Management
**Tasks:**
- [ ] Import buddies from contacts (mobile)
- [ ] Share dives with buddies (export UDDF, send via email/messaging)

### 7.2 Digital Signatures
| Feature | Status | Notes |
|---------|--------|-------|
| Buddy signatures | 📋 Planned | For training logs |
| Instructor signatures | 📋 Planned | Professional logs |
| Signature capture | 📋 Planned | Touch/stylus drawing |

**Tasks:**
- [ ] Signature widget (canvas drawing with save as PNG)
- [ ] Store signatures in Media table linked to dives
- [ ] Display signatures on dive detail page and PDF export
- [ ] Timestamp and signer name with signature

---

## Category 8: Training, Certifications & Medical Info

### 8.2 Digital Cards (eCards)
| Feature | Status | Notes |
|---------|--------|-------|
| eCard wallet | 📋 Planned | Display certs in wallet format |

**Tasks:**
- [ ] Certification wallet view (card-style UI)
- [ ] Export cert card as image (shareable)

### 8.3 Training Dives
| Feature | Status | Notes |
|---------|--------|-------|
| Associate with courses | 📋 Planned | Course entity |
| Instructor comments | 📋 Planned | Rich text field |
| E-signatures | 📋 Planned | Digital signature |

**Tasks:**
- [ ] Course entity (name, agency, start_date, completion_date, instructor, cert_id)
- [ ] Link dives to courses (many-to-one)
- [ ] Instructor notes field on dives
- [ ] Training log export (PDF with instructor signature)

### 8.4 Personal & Medical Data
| Feature | Status | Notes |
|---------|--------|-------|
| Medical clearance dates | 📋 Planned | For commercial divers |
| Emergency contacts | 📋 Planned | Critical for safety |

**Tasks:**
- [ ] Add Medical/Personal section to Settings
- [ ] Emergency contact(s) with name, phone, relationship
- [ ] Medical clearance expiry date with reminder
- [ ] Blood type, allergies, medications (encrypted storage)

---

## Category 9: Environment, Wildlife & Photography

### 9.2 Marine Life Tracking
| Feature | Status | Notes |
|---------|--------|-------|
| Taxonomy, photos | 📋 Planned | Scientific names, images |
| Stats per species | 📋 Planned | First/last seen, depth range |

**Tasks:**
- [ ] Add `scientific_name`, `taxonomy_class`, `image_url` to species table
- [ ] Species photo library (local or remote images)
- [ ] Species detail page (description, typical depth, geographic range, photo)
- [ ] Species statistics (total sightings, depth range, sites seen, first/last sighting)

---

## Category 10: Search, Filters, Statistics & Reports

### 10.2 Statistics
**Tasks:**
- [ ] Dive type breakdown (pie chart)

### 10.3 Reports & Printing
| Feature | Status | Notes |
|---------|--------|-------|
| Pre-made layouts | 📋 Planned | A5, 3-ring, agency style |
| Professional logs | 📋 Planned | For instructors, DMs |

**Tasks:**
- [ ] Multiple PDF templates (Simple, Detailed, Professional, PADI-style, NAUI-style)
- [ ] Template selection in export dialog
- [ ] Professional template with space for signatures, stamps
- [ ] Include certification cards in PDF export

---

## Category 13: Import, Export & Interoperability

### 13.1 File Formats
| Feature | Status | Notes |
|---------|--------|-------|
| DAN DL7 export | 📋 Planned | Research data format |
| Excel export | 📋 Planned | .xlsx format |
| Google Earth KML export | 📋 Planned | Map all dive sites |

**Tasks:**
- [ ] DAN DL7 export (research format specification)
- [ ] Excel export with multiple sheets (dives, sites, equipment, statistics)
- [ ] KML export (placemark per dive site with description bubble)

### 13.2 Interoperability
| Feature | Status | Notes |
|---------|--------|-------|
| Import from Subsurface | 📋 Planned | UDDF or XML |
| Import from MacDive | 📋 Planned | CSV or proprietary format |
| Import from other apps | 📋 Planned | Diving Log, DiveMate, etc. |

**Tasks:**
- [ ] Import wizard with app selection (Subsurface, MacDive, Diving Log, etc.)
- [ ] Per-app parser (detect format, map fields)
- [ ] Dry-run preview before importing

### 13.3 Universal Import
| Feature | Status | Notes |
|---------|--------|-------|
| Format auto-detection | 📋 Planned | Guess format from headers |

**Tasks:**
- [ ] Smart format detection (analyze CSV headers, suggest mapping)
- [ ] Import templates for common apps (save column mappings)
- [ ] Import validation (check required fields, data types)

---

## Category 15: UX, Customization & Quality-of-Life

### 15.1 Layout & Customization
| Feature | Status | Notes |
|---------|--------|-------|
| Quick actions | 📋 Planned | iOS shortcuts, Android widgets |

**Tasks:**
- [ ] iOS 3D Touch shortcuts (Add Dive, View Last Dive)
- [ ] Android home screen widgets (dive count, last dive, next service due)

### 15.3 Accessibility & Localization
| Feature | Status | Notes |
|---------|--------|-------|
| Screen reader support | 📋 Planned | Accessibility testing |
| Keyboard navigation | 📋 Planned | Desktop accessibility |

**Tasks:**
- [ ] Accessibility audit (screen reader testing on iOS/Android)
- [ ] Semantic labels for all interactive elements
- [ ] Focus order testing and fixes
- [ ] Keyboard shortcuts (desktop)

---

## v1.5 Release Criteria (Remaining)
- [ ] Performance with 5000+ dives

---

# v2.0 Planned Features

## Category 1: Core Dive Log Entry

### 1.2 Location & Site
| Feature | Notes |
|---------|-------|
| Liveaboard tracking | Specialized trip type |

---

## Category 2: Dive Profile & Telemetry

### 2.2 Multi-Profile Support
| Feature | Notes |
|---------|-------|
| Profile comparison (buddies) | Side-by-side view |
| Profile merging | Combine multiple sources |
| Multi-transmitter support | Track multiple tank transmitters (sidemount) |

**Tasks:**
- [ ] Side-by-side profile comparison view
- [ ] Buddy profile import (from shared UDDF)

### 2.3 Profile Editing
| Feature | Notes |
|---------|-------|
| Smoothing / cleaning bad samples | Outlier removal |
| Manual profile drawing | For dives without computer |
| Segment editing | Adjust timestamps, depths |

**Tasks:**
- [ ] Profile outlier detection algorithm (sudden depth jumps)
- [ ] Smoothing algorithm (moving average)
- [ ] Manual profile editor with touch/mouse drawing
- [ ] Segment selection and adjustment UI

---

## Category 3: Dive Computer Connectivity

### 3.1 Connectivity Types
| Feature | Notes |
|---------|-------|
| Wi-Fi / cloud devices | Garmin, Shearwater cloud API |

---

## Category 4: Gases, Tanks & Technical Diving

### 4.5 Planning Utilities
| Feature | Notes |
|---------|-------|
| What-if scenarios | Deeper/longer/different gas |
| Lost gas scenarios | Plan for lost decompression gas |
| Turn pressure planning | Calculate gas turn pressures for penetration dives |
| Range plans | Multiple profiles with different depths/times |

**Tasks:**
- [ ] Repetitive dive planner with tissue loading from previous dive
- [ ] "Extend dive" tool (add 5 mins at depth, recalculate deco)
- [ ] "Add safety" tool (extend safety stop, add deep stop)

---

## Category 5: Locations, Dive Sites & Maps

### 5.4 External Data Sources
| Feature | Notes |
|---------|-------|
| Online dive site database lookup | Import from community sources |
| Dive site reviews | User-generated content |

**Tasks:**
- [ ] Integration with public dive site APIs (e.g., Open Dive Sites, PADI Travel)
- [ ] Import site details from online sources
- [ ] User reviews and ratings (requires backend)

---

## Category 6: Gear & Equipment Management

### 6.1 Gear Inventory
| Feature | Notes |
|---------|-------|
| Photos of gear | Deferred with photos |

### 6.3 Maintenance
**Tasks:**
- [ ] Service log export to PDF (professional format with full history)

---

## Category 8: Training, Certifications & Medical Info

### 8.1 Certifications
| Feature | Notes |
|---------|-------|
| Scanned card images | Deferred with photos |

### 8.2 Digital Cards (eCards)
| Feature | Notes |
|---------|-------|
| QR codes | Scannable verification |

**Tasks:**
- [ ] Generate QR codes for certs (encode cert number, agency, level)
- [ ] QR code verification (backend required)

### 8.4 Personal & Medical Data
| Feature | Notes |
|---------|-------|
| Medical documents | PDF storage |

**Tasks:**
- [ ] Medical document storage (PDF of medical clearance)
- [ ] Export profile with certs + medical for dive operations

---

## Category 9: Environment, Wildlife & Photography

### 9.2 Marine Life Tracking
| Feature | Notes |
|---------|-------|
| Distribution map | Map of sightings |
| AI species identification | Upload photo, AI identifies species |
| Offline species ID | Works without internet connection |

**Tasks:**
- [ ] Species distribution map (heatmap of sightings)
- [ ] "Life list" progress tracker (total species seen)
- [ ] Rare species badges
- [ ] AI-powered species identification from photos (ML model)
- [ ] Offline species recognition database
- [ ] Species identification confidence scores

### 9.3 Underwater Photography
| Feature | Notes |
|---------|-------|
| Attach photos/videos to dives | Media table exists, needs UI |
| Video support in logs | Attach and play videos |
| Auto-match by timestamp | EXIF datetime matching |
| Tag species in photos | Image annotation |
| Color correction | Blue filter removal |
| Shareable dive cards | Generate visual summary for social media |

**Tasks:**
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

## Category 10: Search, Filters, Statistics & Reports

### 10.1 Search & Filtering
| Feature | Notes |
|---------|-------|
| Saved filters ("Smart Logs") | Persistent filter sets |

**Tasks:**
- [ ] Save filter configurations as "Smart Logs"
- [ ] Smart Log management (name, description, icon)
- [ ] Quick access to Smart Logs from home page

### 10.2 Statistics
**Tasks:**
- [ ] Advanced analytics dashboard (customizable widgets)
- [ ] Year-in-review summary (auto-generated at year end)

### 10.3 Reports & Printing
| Feature | Notes |
|---------|-------|
| Custom report designer | Drag-drop fields |

**Tasks:**
- [ ] Custom report builder (select fields, layout, sorting)
- [ ] Save custom report templates
- [ ] Export to Excel/CSV with custom fields

---

## Category 11: Planning & Calculators

### 11.4 Convenience Tools
| Feature | Notes |
|---------|-------|
| Altitude conversion | Altitude dive tables |

---

## Category 12: Cloud Sync, Backup & Multi-Device

### 12.1 Cloud Accounts
**Tasks:**
- [ ] Backend service for user accounts (Firebase, Supabase)
- [ ] User authentication (email/password, OAuth)
- [ ] Privacy policy and data handling docs

### 12.2 Synchronization
| Feature | Notes |
|---------|-------|
| Web sync | Requires backend service |

**Tasks:**
- [ ] Web platform sync (requires backend)
- [ ] "Force push" and "force pull" options for troubleshooting

### 12.3 Backup
**Tasks:**
- [ ] Automatic scheduled backups
- [ ] Backup history (keep last N backups)
- [ ] One-click restore from cloud backup

### 12.4 Offline Behavior
| Feature | Notes |
|---------|-------|
| Deferred sync | Queue changes when offline |

**Tasks:**
- [ ] Offline queue for pending sync operations
- [ ] Auto-sync when connectivity restored
- [ ] Sync conflict warnings and resolution

---

## Category 13: Import, Export & Interoperability

### 13.1 File Formats
| Feature | Notes |
|---------|-------|
| ePub export | Electronic book format for travel |
| HTML export | Web-viewable logbook |

**Tasks:**
- [ ] ePub export (electronic book for showing experience digitally)
- [ ] HTML export (static website with CSS, images, interactive map)
- [ ] MySQL dump export (for migration to other systems)

### 13.2 Interoperability
| Feature | Notes |
|---------|-------|
| Upload to divelogs.de | API integration |
| Garmin Connect integration | Import Garmin watch dives |
| Shearwater Cloud import | Import from Shearwater cloud |
| Suunto app import | Import via Suunto cloud/Movescount |
| Diviac import | Import from Diviac online logbook |
| Deepblu import | Import from Deepblu platform |

**Tasks:**
- [ ] divelogs.de API integration (upload/download dives)
- [ ] Garmin Connect API (import dive activity FIT files)
- [ ] Automatic conversion from Garmin Descent dive computers
- [ ] Shearwater Cloud API integration
- [ ] Suunto app/Movescount API integration
- [ ] Diviac API integration
- [ ] Deepblu API integration

---

## Category 14: Social, Community & Travel Features

### 14.1 Social Sharing
| Feature | Notes |
|---------|-------|
| Share dives to social media | FB, Instagram, Twitter |
| Generate composite images | Profile + photo + stats |
| Share links | Web view of dive (requires backend) |
| Shareable dive cards | Visual summary image for social |

**Tasks:**
- [ ] "Share Dive" action with platform picker
- [ ] Generate shareable image (profile chart, photo, depth/time/location text overlay)
- [ ] Share as PNG or link (if cloud sync enabled)
- [ ] Public dive view page (web) with privacy settings

### 14.2 Community Maps & Logs
| Feature | Notes |
|---------|-------|
| View community dive sites | Requires backend |
| Explore nearby sites | GPS-based search |
| User-submitted site photos | Photo gallery per site |
| Dive site reviews & ratings | Rate and review sites |

**Tasks:**
- [ ] Community backend (user accounts, public profiles)
- [ ] Public dive site database (user submissions)
- [ ] Site photos, reviews, difficulty ratings
- [ ] "Discover" tab with nearby sites, popular sites, new sites

### 14.3 Diver Social Network
| Feature | Notes |
|---------|-------|
| Diver profiles | Public profile with stats, certs, dive count |
| Follow buddies | Activity feed from followed divers |
| Buddy activity feed | New dives, photos, certs from buddies |
| Community groups | Dive clubs, schools, interest groups |
| In-app messaging | Chat between buddies |
| Public dive feed | Discover dive logs from community |
| Digital instructor signatures | Instructors verify/sign training logs |

**Tasks:**
- [ ] Diver profile page (public view with stats, certifications, dive count)
- [ ] Follow/unfollow other divers
- [ ] Activity feed (new dives, photos, certifications from followed divers)
- [ ] Community groups with forums, events, shared stats
- [ ] In-app messaging between buddies
- [ ] Public dive feed ("Discover" section)
- [ ] Privacy controls (public/private/buddies-only)

---

## Category 15: UX, Customization & Quality-of-Life

### 15.1 Layout & Customization
| Feature | Notes |
|---------|-------|
| Customizable logbook columns | Show/hide fields |
| Themes | Custom color schemes |

**Tasks:**
- [ ] Customizable dive list columns (user selects which fields to show)
- [ ] Theme editor (custom colors, fonts)
- [ ] Layout presets (Compact, Detailed, Photo-focused)

### 15.3 Accessibility & Localization
| Feature | Notes |
|---------|-------|
| Multi-language support | i18n with ARB files |
| High contrast themes | Accessibility feature |

**Tasks:**
- [ ] flutter_localizations integration
- [ ] ARB files for: English, Spanish, French, German, Italian, Dutch, Portuguese
- [ ] Localized date/time/number formats
- [ ] RTL language support (Arabic, Hebrew)
- [ ] Translation management workflow (POEditor, Crowdin)

### 15.4 Gamification & Achievements
| Feature | Notes |
|---------|-------|
| Achievement badges | Earn badges for milestones |
| Dive milestones | 100 dives, 1000m depth, etc. |
| Species life list | Track total unique species seen |
| Depth achievements | First 20m, 30m, 40m dives |
| Streak tracking | Monthly/yearly dive streaks |
| Progress visualization | Journey timeline with milestones |

**Tasks:**
- [ ] Achievement system with badge definitions
- [ ] Milestone tracking (dive count, depths, locations, species)
- [ ] Badge unlock notifications
- [ ] Achievement showcase on diver profile
- [ ] Progress towards next milestone display
- [ ] Life list tracker (species collection progress)

### 15.5 Wearable Integration
| Feature | Notes |
|---------|-------|
| Apple Watch Ultra import | Import dives via HealthKit |
| Apple HealthKit integration | Read depth/temperature data |
| Garmin Connect import | Import Descent dive activities |
| Suunto app integration | Import via UDDF/Movescount |

**Tasks:**
- [ ] HealthKit permission and data reading
- [ ] Import Apple Watch Ultra dives (depth, temperature, time)
- [ ] Garmin Connect API integration
- [ ] Automatic sync from connected wearables
- [ ] Merge wearable data with dive computer data

### 15.6 Well-being & Safety
| Feature | Notes |
|---------|-------|
| Pre-dive feeling monitor | Track readiness before dive |
| Post-dive feeling monitor | Track condition after dive |
| Breathing technique analysis | SAC improvement suggestions |
| Hydration reminders | DCS prevention |

**Tasks:**
- [ ] Pre/post dive well-being questionnaire
- [ ] Correlation analysis (feeling vs dive parameters)
- [ ] Breathing efficiency tips based on SAC trends
- [ ] Health trend visualization over time

---

## Category 16: Manufacturer-Specific & Advanced Features

### 16.1 Advanced Hardware Integration
| Feature | Notes |
|---------|-------|
| Remote DC configuration | Bluetooth settings sync |
| Firmware updates via app | Shearwater-specific |

### 16.2 Partner Ecosystem Integration
| Feature | Notes |
|---------|-------|
| Shearwater Cloud sync | API integration |
| Garmin Dive sync | Import from Garmin |
| PADI eCard integration | Display PADI certs |

**Tasks:**
- [ ] Shearwater Cloud API (import dives from cloud)
- [ ] Garmin Connect API (import Descent dive activities)
- [ ] PADI app integration (OAuth, fetch eCards)

---

## v2.0 Release Criteria
- [ ] Web platform with backend service
- [ ] 7+ language translations
- [ ] Community features beta tested

---

# v3.0 Future Features

## Category 3: Dive Computer Connectivity
| Feature | Notes |
|---------|-------|
| Infrared (legacy) | Limited hardware support |

## Category 9: Environment, Wildlife & Photography
| Feature | Notes |
|---------|-------|
| Depth/time overlay | Requires camera integration |

## Category 14: Social, Community & Travel Features

### 14.4 Booking & Commerce
| Feature | Notes |
|---------|-------|
| Browse/book fun dives | PADI Adventures-style |
| Book courses | Integration with dive shops |
| Pass cert details to bookings | Auto-fill diver info |

## Category 16: Manufacturer-Specific & Advanced Features
| Feature | Notes |
|---------|-------|
| Assistant dive computer | Smartphone in housing |

---

# Summary

## Task Counts by Phase

| Phase | Remaining Features | Remaining Tasks |
|-------|-------------------|-----------------|
| **v1.5** | ~25 features | ~45 tasks |
| **v2.0** | ~75+ features | ~115+ tasks |
| **v3.0** | ~5 features | Future scope |

## v1.5 Priority Areas
1. Performance testing with large datasets
2. Remaining export formats (DAN DL7, Excel, KML)
3. Import from other dive log apps
4. Accessibility improvements
5. Digital signatures for training logs
6. Medical/emergency contact info
7. Species detail enhancements

---

**Document Version:** 1.0
**Generated:** 2026-01-14
