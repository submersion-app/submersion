# Appearance Settings Reorganization

**Issue:** [#182](https://github.com/submersion-app/submersion/issues/182) — Settings > Appearance is becoming messy  
**Date:** 2026-04-08

## Problem

The Appearance settings page has grown to ~50+ inline settings across 13 sections. Settings are organized by entity type (Dive Log, Sites, Trips, Equipment, etc.) rather than by function, so related settings are scattered and the page requires excessive scrolling. Users cannot quickly find what they need.

## Design

### Approach: Per-Section Sub-Pages

Restructure the Appearance page into a clean hub with global settings and navigation tiles into per-section sub-pages. Each app section (Dives, Sites, Buddies, etc.) gets its own dedicated sub-page containing all appearance settings relevant to that section.

### Main Appearance Page

Two sections, 11 items total (down from ~50):

**General**
| Setting | Type | Notes |
|---------|------|-------|
| Theme | Navigation tile | Opens Theme Gallery page (existing) |
| Theme Mode | Segmented control | System / Light / Dark (matches current implementation) |
| Language | Navigation tile | Opens Language Settings page (existing) |

**Sections**
| Tile | Route |
|------|-------|
| Dives | `/settings/appearance/dives` |
| Dive Sites | `/settings/appearance/sites` |
| Buddies | `/settings/appearance/buddies` |
| Trips | `/settings/appearance/trips` |
| Equipment | `/settings/appearance/equipment` |
| Dive Centers | `/settings/appearance/dive-centers` |
| Certifications | `/settings/appearance/certifications` |
| Courses | `/settings/appearance/courses` |

### Dives Sub-Page

The richest sub-page, absorbing settings from the current Dive Log, Details Pane, Dive Profile, and Dive Details sections.

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Compact, Dense, Table |
| Dive List Fields | Navigation tile | Opens field config for dives (existing ColumnConfigPage, scoped to dives) |

**Cards**
| Setting | Type | Values |
|---------|------|--------|
| Color Cards By | Dropdown | None, Depth, Duration, Temperature |
| Gradient Preset | Preset picker (conditional) | Ocean, Thermal, Sunset, Lava, Arctic, Forest, Custom — shown when Color Cards By is not None |
| Show Map Background | Toggle | On/Off |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |
| Show Profile Panel | Toggle | On/Off |
| Show Data Source Badges | Toggle | On/Off |

**Dive Profile**
| Setting | Type | Values |
|---------|------|--------|
| Right Y-Axis Metric | Dropdown | Temperature, Pressure, Heart Rate, SAC Rate |
| Show Max Depth Marker | Toggle | On/Off |
| Show Pressure Threshold Markers | Toggle | On/Off |
| Show Gas Switch Markers | Toggle | On/Off |
| Default Visible Metrics | Navigation tile | Opens existing DefaultVisibleMetricsPage |

**Dive Details**
| Setting | Type | Values |
|---------|------|--------|
| Section Order & Visibility | Navigation tile | Opens existing DiveDetailSectionsPage |

### Dive Sites Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Compact, Dense, Table |
| Site List Fields | Navigation tile | Opens field config scoped to sites |

**Cards**
| Setting | Type | Values |
|---------|------|--------|
| Show Map Background | Toggle | On/Off |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Buddies Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Dense |
| Buddy List Fields | Navigation tile | Opens field config scoped to buddies |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Trips Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Compact, Dense, Table |
| Trip List Fields | Navigation tile | Opens field config scoped to trips |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Equipment Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Dense |
| Equipment List Fields | Navigation tile | Opens field config scoped to equipment |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Dive Centers Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Compact, Dense, Table |
| Dive Center List Fields | Navigation tile | Opens field config scoped to dive centers |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Certifications Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Table |
| Certification List Fields | Navigation tile | Opens field config scoped to certifications |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

### Courses Sub-Page

**List View**
| Setting | Type | Values |
|---------|------|--------|
| View Mode | Dropdown | Detailed, Table |
| Course List Fields | Navigation tile | Opens field config scoped to courses |

**Table Mode**
| Setting | Type | Values |
|---------|------|--------|
| Show Details Pane | Toggle | On/Off |

## Routing

New routes under the existing `/settings/appearance` path:

```
/settings/appearance                    → Main hub (General + Section tiles)
/settings/appearance/dives              → Dives sub-page
/settings/appearance/sites              → Dive Sites sub-page
/settings/appearance/buddies            → Buddies sub-page
/settings/appearance/trips              → Trips sub-page
/settings/appearance/equipment          → Equipment sub-page
/settings/appearance/dive-centers       → Dive Centers sub-page
/settings/appearance/certifications     → Certifications sub-page
/settings/appearance/courses            → Courses sub-page
```

Existing sub-page routes remain unchanged:
- `/settings/themes` — Theme Gallery
- `/settings/language` — Language Settings
- `/settings/default-metrics` — Default Visible Metrics
- `/settings/dive-detail-sections` — Dive Detail Section Order
- `/settings/column-config` — Column/List Fields Config (now opened with a section query param instead of internal dropdown)

## Desktop Layout Behavior

On desktop (>=800px), the Settings page uses a master-detail scaffold. The new section sub-pages should render as detail content in the right pane when selected from the Appearance section, following the same pattern as the existing `_AppearanceSectionContent` in `settings_page.dart`.

## Implementation Notes

### Files to Create
- A `SectionAppearancePage` widget in `lib/features/settings/presentation/pages/` that takes a section key parameter and renders the appropriate settings for that section. One widget handles all 8 sections, since the simpler sections (Buddies through Courses) share the same structure (View Mode + List Fields + Details Pane) and only Dives and Sites have additional unique settings.

### Files to Modify
- `appearance_page.dart` — gut the current content, replace with hub layout (General + Section tiles)
- `settings_page.dart` — update `_AppearanceSectionContent` to match new hub structure, add section sub-page rendering in master-detail mode
- `app_router.dart` — add 8 new routes under `/settings/appearance/`
- `column_config_page.dart` — accept a section query parameter to pre-select the entity type, hiding the internal dropdown when launched from a section sub-page

### No Data Model Changes
All settings already exist in `AppSettings`. This is purely a UI reorganization — no new settings fields, providers, or database changes needed. The `ColumnConfigPage` already supports all 8 entity types via its internal section selector.

## Testing

- Verify all existing settings are still accessible and functional after reorganization
- Test navigation from hub to each sub-page and back
- Test desktop master-detail rendering of new sub-pages
- Test mobile full-page rendering of new sub-pages
- Verify existing sub-page links (Theme Gallery, Language, Default Metrics, Dive Detail Sections, Column Config) still work
- Update existing `appearance_page_test.dart` to reflect new structure
