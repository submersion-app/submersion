# Submersion - Remaining Tasks

> **Generated:** 2026-02-03
> **Source:** FEATURE_ROADMAP.md
> **Current Version:** 1.1.0 (v1.5 Nearly Complete - only performance testing remains)

This document contains only the features and tasks that are **not yet completed**.

---

## Phase Summary

| Phase | Status | Remaining Focus |
|-------|--------|-----------------|
| **v2.0** | 🚧 In Progressd | Advanced features, social, backend |
| **v3.0** | 🔮 Future | Community platform, AI features |

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
| Profile merging | Combine multiple sources |
| Multi-transmitter support | Track multiple tank transmitters (sidemount) |

**Tasks:**
- [ ] Side-by-side profile comparison view

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

### 12.4 Offline Behavior
| Feature | Notes |
|---------|-------|
| Deferred sync | Queue changes when offline |

**Tasks:**
- [ ] Offline queue for pending sync operations
- [ ] Auto-sync when connectivity restored
- [ ] Sync conflict warnings and resolution

### 12.5 Auto-update
**Tasks:**
- [ ] Application auto-update for non-app store releases

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
| Shearwater Cloud import | Import from Shearwater cloud |
| Suunto app import | Import via Suunto cloud/Movescount |
| Diviac import | Import from Diviac online logbook |
| Deepblu import | Import from Deepblu platform |

**Tasks:**
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
| Shareable dive cards | Visual summary image for social |

**Tasks:**
- [ ] "Share Dive" action with platform picker
- [ ] Generate shareable image (profile chart, photo, depth/time/location text overlay)
- [ ] Share as PNG or link (if cloud sync enabled)

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

### 16.2 Partner Ecosystem Integration
| Feature | Notes |
|---------|-------|
| Shearwater Cloud sync | API integration |
| PADI eCard integration | Display PADI certs |

**Tasks:**
- [ ] Shearwater Cloud API (import dives from cloud)
- [ ] PADI app integration (OAuth, fetch eCards)

---

# Summary

## Task Counts by Phase

| Phase | Remaining Features | Remaining Tasks |
|-------|-------------------|-----------------|
| **v2.0** | ~65+ features | ~105+ tasks |
| **v3.0** | ~4 features | Future scope |

---

**Document Version:** 3.0
**Updated:** 2026-02-10 (Section 15.3 i18n complete: 10 languages, 3,931 ARB keys, RTL support, locale-aware formatting)
