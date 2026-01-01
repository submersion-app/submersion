# Feature Roadmap

This roadmap outlines planned features and development phases for Submersion.

## Status Legend

| Icon | Status |
|------|--------|
| :white_check_mark: | Implemented |
| :construction: | In Progress |
| :clipboard: | Planned |
| :crystal_ball: | Future |

## Phase Overview

| Phase | Timeline | Focus | Status |
|-------|----------|-------|--------|
| **MVP** | Complete | Core dive logging | :white_check_mark: Done |
| **v1.0** | Complete | Production-ready | :white_check_mark: Done |
| **v1.1** | Complete | UX, GPS, maps, testing | :white_check_mark: Done |
| **v1.5** | 4-6 months | Technical diving & computers | :construction: In Progress |
| **v2.0** | 8-12 months | Cloud sync & social | :clipboard: Planned |
| **v3.0** | 12-18 months | Community platform | :crystal_ball: Future |

---

## v1.0 - Foundation (Complete)

Core dive logging functionality.

### Dive Logging
- :white_check_mark: Dive number, date, time, duration
- :white_check_mark: Max/average depth, temperature
- :white_check_mark: 20+ dive types
- :white_check_mark: Star rating, notes

### Tanks & Gases
- :white_check_mark: Multiple tanks per dive
- :white_check_mark: Air, Nitrox, Trimix support
- :white_check_mark: Volume, pressure tracking
- :white_check_mark: SAC/RMV calculation
- :white_check_mark: MOD, END calculations

### Dive Sites
- :white_check_mark: Site database with GPS
- :white_check_mark: Region, country, description
- :white_check_mark: Map visualization
- :white_check_mark: Depth range, difficulty

### Equipment
- :white_check_mark: 20+ equipment types
- :white_check_mark: Service tracking
- :white_check_mark: Equipment sets
- :white_check_mark: Per-dive gear selection

### People
- :white_check_mark: Buddy management with roles
- :white_check_mark: Dive center tracking
- :white_check_mark: Certification records

### Import/Export
- :white_check_mark: UDDF import/export
- :white_check_mark: CSV import/export
- :white_check_mark: PDF logbook export

---

## v1.1 - Enhanced UX (Complete)

Usability improvements and better GPS integration.

### Dive Logging
- :white_check_mark: Separate entry/exit times
- :white_check_mark: Surface interval calculation
- :white_check_mark: Dive number gap detection
- :white_check_mark: Favorite dive flag
- :white_check_mark: Tag system with colors

### Profile Visualization
- :white_check_mark: Zoom and pan controls
- :white_check_mark: Touch markers with tooltips
- :white_check_mark: Temperature overlay toggle

### GPS & Maps
- :white_check_mark: Capture GPS from phone
- :white_check_mark: Reverse geocoding
- :white_check_mark: Nearby site suggestions
- :white_check_mark: Map marker clustering
- :white_check_mark: Color-coded markers

### Equipment
- :white_check_mark: Tank material tracking
- :white_check_mark: Tank role (back gas, stage, etc.)
- :white_check_mark: Tank presets
- :white_check_mark: Quick-select equipment sets

### Testing
- :white_check_mark: 165+ unit tests
- :white_check_mark: 48+ widget tests
- :white_check_mark: Integration tests
- :white_check_mark: Performance tests

---

## v1.5 - Technical Diving (In Progress)

Dive computer integration and decompression support.

### Dive Computer Connectivity :white_check_mark:
- :white_check_mark: libdivecomputer FFI integration
- :white_check_mark: Bluetooth Classic/LE support
- :white_check_mark: USB connectivity
- :white_check_mark: 300+ dive computer models
- :white_check_mark: Device pairing wizard
- :white_check_mark: Progress indicators
- :white_check_mark: Incremental downloads
- :white_check_mark: Duplicate detection

### Decompression Algorithm :white_check_mark:
- :white_check_mark: Bühlmann ZH-L16C implementation
- :white_check_mark: Gradient Factor support (GF Low/High)
- :white_check_mark: NDL calculation
- :white_check_mark: Ceiling calculation
- :white_check_mark: TTS (Time To Surface)
- :white_check_mark: 16-compartment tissue loading display
- :white_check_mark: Deco stop schedule

### O₂ Toxicity :white_check_mark:
- :white_check_mark: CNS% tracking (NOAA tables)
- :white_check_mark: OTU calculation
- :white_check_mark: ppO₂ monitoring
- :white_check_mark: Warning/critical thresholds

### Profile Analysis :white_check_mark:
- :white_check_mark: Profile event markers
- :white_check_mark: Ascent rate indicators
- :white_check_mark: NDL curve overlay
- :white_check_mark: Ceiling curve overlay
- :white_check_mark: SAC/RMV overlay

### Multi-Profile Support :white_check_mark:
- :white_check_mark: Multiple computers per dive
- :white_check_mark: Profile selector UI
- :white_check_mark: Primary profile indicator

### Weather Integration :white_check_mark:
- :white_check_mark: OpenWeatherMap API
- :white_check_mark: World Tides API
- :white_check_mark: Auto-populate conditions

### Planned for v1.5
- :clipboard: Dive planner with deco schedules
- :clipboard: Gas calculators (Best Mix, Rock Bottom)
- :clipboard: CCR/Rebreather support
- :clipboard: Gas switch events on profile
- :clipboard: Custom tank presets
- :clipboard: Offline map tiles
- :clipboard: Service due notifications

---

## v2.0 - Cloud & Community (Planned)

Multi-device sync and social features.

### Cloud Sync
- :clipboard: Optional cloud account
- :clipboard: Multi-device sync
- :clipboard: Automatic backup
- :clipboard: Conflict resolution

### Multi-User Support
- :white_check_mark: Multiple divers per database
- :white_check_mark: Account switching
- :clipboard: Family subscriptions

### Localization
- :clipboard: Multi-language support (7+ languages)
- :clipboard: RTL language support
- :clipboard: Localized formats

### Photography
- :clipboard: Attach photos/videos to dives
- :clipboard: Auto-match by timestamp
- :clipboard: Photo galleries
- :clipboard: Species tagging

### Advanced Statistics
- :clipboard: Customizable dashboards
- :clipboard: Year-in-review summary
- :clipboard: SAC trend analysis
- :clipboard: Temperature preferences

### Social Features
- :clipboard: Share dives to social media
- :clipboard: Shareable dive images
- :clipboard: Public dive view pages

### Partner Integration
- :clipboard: Shearwater Cloud sync
- :clipboard: Garmin Connect import
- :clipboard: PADI eCard integration

---

## v3.0 - Platform (Future)

Community features and advanced integrations.

### Community Platform
- :crystal_ball: Community dive site database
- :crystal_ball: User reviews and ratings
- :crystal_ball: Site photo galleries
- :crystal_ball: Discover nearby sites

### Advanced Features
- :crystal_ball: AI species recognition
- :crystal_ball: Dive recommendations
- :crystal_ball: Booking integration
- :crystal_ball: Course booking

### Hardware
- :crystal_ball: Smartphone as dive computer
- :crystal_ball: Real-time data display
- :crystal_ball: Depth/time overlays

---

## Contributing to the Roadmap

### Suggest Features

1. Check if already planned
2. Open a [discussion](https://github.com/submersion-app/submersion/discussions)
3. Describe the use case

### Implement Features

1. Pick from planned items
2. Comment on related issue
3. Follow [PR guidelines](contributing/pull-requests.md)

### Priority Considerations

When planning features, we consider:

| Factor | Weight |
|--------|--------|
| User demand | High |
| Safety impact | Critical |
| Technical complexity | Medium |
| Maintenance burden | Medium |
| Platform consistency | High |

---

## Platform Support

| Platform | Status | Version |
|----------|--------|---------|
| iOS | :white_check_mark: | iOS 13+ |
| Android | :white_check_mark: | Android 7+ |
| macOS | :white_check_mark: | macOS 11+ |
| Windows | :white_check_mark: | Windows 10+ |
| Linux | :white_check_mark: | Desktop |
| Web | :clipboard: v2.0 | Requires sync |

---

## Philosophy

### Local-First
Data stays on your device. Cloud sync is optional.

### Privacy-Focused
No tracking, no ads. Your data is yours.

### Open Source
Community-driven development.

### Free Core
Essential features are always free.

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| MVP | 2024-Q2 | Core logging, sites, equipment |
| v1.0 | 2024-Q3 | Buddies, certs, trips, import/export |
| v1.1 | 2024-Q4 | GPS, maps, tags, testing |
| v1.5 | 2025 | Dive computers, deco, O₂ toxicity |

