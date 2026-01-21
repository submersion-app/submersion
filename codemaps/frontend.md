# Submersion Frontend Codemap

> Freshness: 2026-01-21 | Pages: ~45 | Widgets: ~100+

## Navigation Architecture

### Router Configuration
`lib/core/router/app_router.dart`

```
GoRouter
├── /welcome (outside shell - no nav bar)
└── ShellRoute (MainScaffold - persistent bottom nav)
    ├── /dashboard
    ├── ShellRoute (PlanningShell - planning tools)
    │   └── /planning/*
    ├── /dives/*
    ├── /sites/*
    ├── /equipment/*
    ├── /buddies/*
    ├── /divers/*
    ├── /certifications/*
    ├── /dive-centers/*
    ├── /trips/*
    ├── /statistics/*
    ├── /records
    ├── /transfer
    ├── /settings/*
    ├── /dive-types
    ├── /tank-presets/*
    └── /dive-computers/*
```

### Bottom Navigation Tabs
Defined in `lib/shared/widgets/main_scaffold.dart`:
- Dashboard (home)
- Planning (tools hub)
- Dives (log)
- Sites
- Equipment
- Statistics
- Settings

## Page Structure by Feature

### Dashboard
```
/dashboard
└── DashboardPage
    ├── StatSummaryCard (total dives, depth, time)
    └── QuickActionsCard (new dive, planning, etc.)
```

### Planning Hub
```
/planning
├── PlanningPage (mobile hub) / PlanningWelcome (wide screens)
└── PlanningShell (master/detail on wide screens)
    ├── /dive-planner → DivePlannerPage
    │   ├── SegmentList, SegmentEditor
    │   ├── PlanTankList
    │   ├── PlanProfileChart
    │   ├── DecoResultsPanel, GasResultsPanel
    │   └── PlanSettingsPanel, SimplePlanDialog
    ├── /deco-calculator → DecoCalculatorPage
    ├── /gas-calculators → GasCalculatorsPage
    ├── /weight-calculator → WeightCalculatorPage
    └── /surface-interval → SurfaceIntervalToolPage
```

### Dive Log
```
/dives
├── DiveListPage → DiveListContent
│   └── Dive cards with profile previews
├── /new → DiveEditPage (3.5k lines)
│   ├── CollapsibleSection (reusable)
│   ├── DiveModeSelector
│   ├── CcrSettingsPanel
│   └── ProfileSelectorWidget
├── /search → DiveSearchPage
└── /:diveId → DiveDetailPage (3.6k lines)
    ├── DiveProfileChart (2.2k lines)
    ├── TissueSaturationPanel/Chart
    ├── DecoInfoPanel
    └── RangeSelectionOverlay
    └── /edit → DiveEditPage
```

### Dive Sites
```
/sites
├── SiteListPage → SiteListContent
├── /map → SiteMapPage
├── /import → SiteImportPage
├── /new → SiteEditPage
└── /:siteId → SiteDetailPage
    └── /edit → SiteEditPage
```

### Equipment
```
/equipment
├── EquipmentListPage → EquipmentListContent
│   └── EquipmentSummaryWidget
├── /sets → EquipmentSetListPage
│   ├── /new → EquipmentSetEditPage
│   └── /:setId → EquipmentSetDetailPage
│       └── /edit → EquipmentSetEditPage
├── /new → EquipmentEditPage
└── /:equipmentId → EquipmentDetailPage (1.3k lines)
    └── /edit → EquipmentEditPage
```

### Social Features
```
/buddies
├── BuddyListPage → BuddyListContent
│   └── BuddyPicker, BuddySummaryWidget
├── /new → BuddyEditPage
└── /:buddyId → BuddyDetailPage
    └── /edit → BuddyEditPage

/divers
├── DiverListPage
├── /new → DiverEditPage
└── /:diverId → DiverDetailPage
    └── /edit → DiverEditPage

/certifications
├── CertificationListPage → CertificationListContent
├── /new → CertificationEditPage
└── /:certificationId → CertificationDetailPage
    └── /edit → CertificationEditPage

/dive-centers
├── DiveCenterListPage → DiveCenterListContent
│   └── DiveCenterPicker, DiveCenterSummaryWidget
├── /new → DiveCenterEditPage
└── /:centerId → DiveCenterDetailPage
    └── /edit → DiveCenterEditPage
```

### Trips
```
/trips
├── TripListPage → TripListContent
│   └── TripPicker, TripSummaryWidget
├── /new → TripEditPage
└── /:tripId → TripDetailPage
    └── /edit → TripEditPage
```

### Statistics
```
/statistics
├── StatisticsPage → StatisticsListContent
│   └── StatSectionCard
├── /gas → StatisticsGasPage
├── /progression → StatisticsProgressionPage
├── /conditions → StatisticsConditionsPage
├── /social → StatisticsSocialPage
├── /geographic → StatisticsGeographicPage
├── /marine-life → StatisticsMarineLifePage
├── /time-patterns → StatisticsTimePatternsPage
├── /equipment → StatisticsEquipmentPage
└── /profile → StatisticsProfilePage

/records → RecordsPage
```

### Settings
```
/settings
├── SettingsPage (1.9k lines)
├── /cloud-sync → CloudSyncPage
├── /storage → StorageSettingsPage
│   └── MigrationConfirmationDialog, MigrationProgressDialog
└── /appearance → AppearancePage

/dive-types → DiveTypesPage
/tank-presets
├── TankPresetsPage
├── /new → TankPresetEditPage
└── /:presetId/edit → TankPresetEditPage
```

### Dive Computers
```
/dive-computers
├── DeviceListPage
├── /discover → DeviceDiscoveryPage
│   └── PinEntryDialog
└── /:computerId → DeviceDetailPage
    └── /download → DeviceDownloadPage
```

### Transfer & Onboarding
```
/transfer → TransferPage → TransferListContent
/welcome → WelcomePage (onboarding)
```

## Shared Components

### Layout
```
lib/shared/widgets/
├── main_scaffold.dart          # Shell with bottom nav
└── master_detail/
    ├── master_detail_scaffold.dart  # Responsive list/detail
    └── responsive_breakpoints.dart  # Width thresholds
```

### Provider Patterns
`lib/shared/providers/selection_providers.dart`
- Selection state for multi-select operations

## Key Widget Sizes (LOC)

| Widget | Lines | Path |
|--------|-------|------|
| DiveEditPage | 3,559 | dive_log/presentation/pages |
| DiveDetailPage | 3,637 | dive_log/presentation/pages |
| DiveProfileChart | 2,213 | dive_log/presentation/widgets |
| SettingsPage | 1,926 | settings/presentation/pages |
| EquipmentDetailPage | 1,346 | equipment/presentation/pages |
| DiveListContent | 1,318 | dive_log/presentation/widgets |

## Providers by Feature

### Core Providers
`lib/core/providers/`
- Re-exports flutter_riverpod
- AsyncValue extensions for error handling

### Feature Providers (selection)
| Feature | Provider File | Key Providers |
|---------|---------------|---------------|
| dive_log | dive_providers.dart | divesProvider, diveByIdProvider |
| dive_log | gas_analysis_providers.dart | sacAnalysisProvider |
| dive_log | profile_analysis_provider.dart | profileAnalysisProvider |
| dive_sites | site_providers.dart | sitesProvider, siteByIdProvider |
| equipment | equipment_providers.dart | equipmentProvider |
| buddies | buddy_providers.dart | buddiesProvider |
| statistics | statistics_providers.dart | statisticsProvider |
| divers | diver_providers.dart | diversProvider, activeDiverProvider |
| settings | settings_providers.dart | diverSettingsProvider |
| dive_planner | dive_planner_providers.dart | planStateProvider |
| dashboard | dashboard_providers.dart | dashboardStatsProvider |

## Theme System

`lib/core/theme/`
- `app_theme.dart` - Material 3 theme data
- `app_colors.dart` - Color palette constants

Features:
- System/Light/Dark mode support
- Per-diver theme preference
- Depth-based dive card coloring (optional)
- Map background on cards (optional)
