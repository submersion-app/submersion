# Submersion - Remaining Tasks

> **Generated:** 2026-02-03
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

---

## Category 13: Import, Export & Interoperability

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
| Species photos | Local or remote images |
| Distribution map | Map of sightings |
| AI species identification | Upload photo, AI identifies species |
| Offline species ID | Works without internet connection |

**Tasks:**
- [ ] Species photo library (local or remote images)
- [ ] Species distribution map (heatmap of sightings)
- [ ] "Life list" progress tracker (total species seen)
- [ ] Rare species badges
- [ ] AI-powered species identification from photos (ML model)
- [ ] Offline species recognition database
- [ ] Species identification confidence scores

### 9.3 Underwater Photography
| Feature | Notes |
|---------|-------|
| Video support in logs | Attach and play videos |
| Tag species in photos | Image annotation |
| Color correction | Blue filter removal |
| Shareable dive cards | Generate visual summary for social media |

**Tasks:**
- [ ] Caption and datetime editing per photo
- [ ] Export dive with photos (ZIP archive)
- [ ] Bulk photo import with auto-match to dives
- [ ] GPS extraction from photos (suggest site creation)
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
| Garmin Connect cloud API | Cloud sync (not file-based) |

**Tasks:**
- [ ] Garmin Connect cloud API integration
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

# Summary

## Task Counts by Phase

| Phase | Remaining Features | Remaining Tasks |
|-------|-------------------|-----------------|
| **v1.5** | ~7 features | ~11 tasks |
| **v2.0** | ~65+ features | ~105+ tasks |
| **v3.0** | ~4 features | Future scope |

## v1.5 Priority Areas
1. Import from other dive log apps
2. Accessibility improvements
3. Performance testing with large datasets

---

**Document Version:** 2.7
**Updated:** 2026-02-09 (Removed completed 9.2 Marine Life Tracking from v1.5; species photos moved to v2.0)
