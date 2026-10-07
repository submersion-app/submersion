# Dive Sites

Build your personal database of the places you dive — with GPS coordinates, depth ranges, conditions, hazards, and access notes — and let the map tie everything together.

> [!NOTE]
> **Where to find it:** Tap or click **Sites** in the navigation rail (desktop, left side) or the bottom bar (mobile). Sites appears in the 13-item desktop rail and, on phones narrower than 800 px, in the middle slot of the tab bar or under **More**.

<!-- screenshot: images/dive-sites/site-list.png — site list view showing sites with dive counts and ratings -->

## Adding a site

Tap the **+ Add Site** button (floating action button on mobile; the same button appears in the top-right area of the detail pane on desktop).

The edit form is divided into collapsible sections. Only the **Name** field is required; everything else is optional and can be filled in later.

### Identity

| Field | Notes |
|-------|-------|
| **Name** | Required. As you type, autocomplete suggests names from your existing sites. A fuzzy similarity hint appears if your new name is close to one you already have — useful for catching duplicates before they happen. |
| **Description** | Free-text overview of the site. |
| **Country** | Autocomplete draws from the countries already in your site list. |
| **Region** | Autocomplete suggests regions already used for the same country; fuzzy matching is enabled so partial names surface near-matches. |

### Location (GPS coordinates)

Two quick-capture buttons are provided:

- **Use My Location** — reads the device GPS and fills in latitude and longitude. On mobile, if permission is denied, a snackbar links directly to app settings. When the device returns a location, country and region are reverse-geocoded and pre-filled if those fields are still blank.
- **Pick From Map** — opens a full-screen interactive map where you tap to drop a pin. Country and region are reverse-geocoded from the pin position and pre-filled if still blank.

You can also type decimal latitude and longitude directly. Coordinates are validated on save (latitude −90 to 90, longitude −180 to 180).

> [!TIP]
> You do not need to be at the dive site to add it. Use **Pick From Map** to place a pin anywhere in the world, or type in coordinates you have from a GPS device or chart.

### Altitude

Record the site's altitude above sea level in metres (or feet if you use imperial). When you enter a non-zero altitude, the form shows an **altitude group indicator** — a color-coded badge (informational, caution, warning, or severe) that signals how altitude affects decompression calculations. This matters for inland and high-altitude lake diving.

### Dive info

| Field | Notes |
|-------|-------|
| **Min depth** | Shallowest point of the site, in your unit preference. |
| **Max depth** | Deepest point. On narrow screens both fields appear in a condensed stat strip at the top of the section. |
| **Difficulty** | Choice chip: Beginner, Intermediate, Advanced, or Technical. |
| **Rating** | Your 1–5 star rating. Tap a star to set; a **Clear** link removes it. |

### Access and safety

| Field | Notes |
|-------|-------|
| **Access notes** | Entry and exit points, how to reach the site. |
| **Mooring number** | Mooring buoy identifier for boat dives. |
| **Parking info** | Parking availability and tips. |
| **Hazards** | Currents, boat traffic, marine life warnings, or other hazards. |

### Life and notes

- **Expected marine life** — link species you expect to encounter at this site. These appear on the site detail and feed into marine life tracking. (See [Marine Life and Photos](marine-life-and-photos.md).)
- **Notes** — any other free-text information.
- **Share with all profiles** — visible only when two or more diver profiles exist. Toggle to make the site visible across every profile.

<!-- screenshot: images/dive-sites/site-detail.png — site detail page showing all fields -->

## Site conditions

The conditions block inside a site record holds dive-environment data visible on the detail page and filterable in the list:

| Field | Values |
|-------|--------|
| **Water type** | Salt, fresh, or brackish |
| **Typical visibility** | Free text (e.g., "10–20 m") |
| **Typical current** | Free text (e.g., "mild seasonal") |
| **Best season** | Free text |
| **Min / max water temperature** | In your unit preference (°C or °F) |
| **Entry type** | Shore or boat |

## The map

<!-- screenshot: images/dive-sites/site-map.png — clustered site map with heat map overlay -->

The Sites map is an interactive world map backed by OpenStreetMap tiles. Toggle to it with the map icon in the app bar (on mobile it opens a dedicated map page; on desktop the map appears in the right pane alongside the list).

### Marker clusters

When multiple sites are close together the map groups them into a numbered cluster bubble. Tapping a cluster animates the map to zoom in and spread the markers apart. Individual site markers are color-coded:

- **Rating-based color** (if the site has a rating): dark green for 4.5+, green for 4.0–4.5, blue for 3–4, orange for 2–3, red below 2.
- **Dive-count color** (no rating set): purple for 10+ dives, shades of blue for 3–9 dives, grey for unvisited sites.

A selected marker enlarges and highlights. Tapping it a second time deselects it.

### Info card

Tapping any marker shows an info card with the site name, location string, dive count, and rating. Tapping **Details** on the card opens the full site detail page.

### Density heat map

The heat map layer shows where your diving activity is concentrated. Toggle it with the heat-map button in the map toolbar (top-right of the map pane). The overlay renders a density-colorized gradient directly over the tile layer: cooler colors for sparse visits, warmer colors where many dives are recorded.

### Map / list split pane (desktop)

On a window wider than 800 px the Sites screen uses a split-pane layout: the list occupies the left column and the interactive map fills the right. Selecting a site in the list animates the map to center on that site's marker; tapping a marker highlights the matching row in the list and shows the info card.

### Fit all sites

The crosshairs icon in the map toolbar zooms and pans so that all your sites with valid coordinates are visible at once.

### Offline tile caching

Map tiles are cached locally after the first load, so the map remains usable in areas with limited connectivity. Cached tiles update automatically when a connection is available.

## List, table, and filter views

The site list supports three display modes — **Detailed**, **Compact**, and **Table** — selectable from the overflow menu (three-dot icon in the app bar). Table mode shows a customizable column grid; tap the column-settings icon to add, remove, reorder, or pin columns from the full set of site fields.

Use the filter icon to narrow the list by:

- Country and region
- Difficulty level
- Depth range (min and max)
- Minimum rating
- Has GPS coordinates (yes / no)
- Has logged dives (yes / no)

Use the sort icon to order by name, country, region, dive count, max depth, min depth, altitude, rating, or coordinates.

## Importing sites

Tap **Import Sites** from the overflow menu on the Sites list. Type a place name or choose a quick-search chip (Caribbean, Red Sea, Thailand, Indonesia, Maldives, Philippines). Results appear in two sections:

- **My Sites** — matches from your own site database, shown with a "Saved" badge. Tapping one opens its detail page.
- **Import from Database** — results from the bundled global site database. Tap a result card to preview its description, depth, coordinates, and feature tags, then tap **Import to My Sites**.

Imported sites populate name, description, country, region, GPS coordinates, max depth, and any feature tags from the source record. You can edit any field after import.

## Merging duplicate sites

If you end up with two entries for the same place, select both in the list (long-press to start multi-select) and choose **Merge Sites** from the overflow menu. The merge form opens with all sections expanded and pre-filled from the first site. For every field that differs between the two sites, a cycle button (two-arrow icon) appears so you can step through the values from each source and keep the one you want. Coordinates, difficulty, and rating each have their own cycle control. Confirm to combine the two into one site and relink all dives that were associated with either.

## GPS auto-matching of dives to sites

When you download dives from a dive computer that records GPS entry or exit positions, Submersion can automatically match each dive to a nearby site — or surface candidates for you to review.

### How matching works

For each dive with a recorded GPS position, the matcher:

1. Ranks every candidate site (your existing sites plus the bundled database) by great-circle distance from the dive's GPS position, nearest first.
2. Applies a two-radius confidence rule:
   - If any **existing** site falls within the **inner radius**, only existing sites compete — an existing site always takes precedence over creating a new entry from the bundled database.
   - The nearest candidate in the winning pool is an **auto-match** when it is the only one in the pool, or when the next nearest is at least the **separation margin** farther away.
   - If no candidate falls inside the inner radius but some fall within the outer radius, the dive is marked **Suggested** and queued for the review screen.
   - No candidates within the outer radius means **No Match**.
3. Auto-matched dives are linked immediately. Suggested and unmatched dives are held for review.

### Sensitivity presets

Three presets control the inner radius, outer radius, and separation margin:

| Preset | Inner radius | Outer radius | Separation |
|--------|-------------|-------------|------------|
| **Strict** | 100 m (330 ft) | 500 m (1640 ft) | 100 m (330 ft) |
| **Balanced** (default) | 150 m (490 ft) | 1000 m (3280 ft) | 75 m (245 ft) |
| **Relaxed** | 300 m (985 ft) | 2000 m (6560 ft) | 50 m (165 ft) |

Change the preset in **Settings**.

> [!TIP]
> **Strict** works well when your sites have precise GPS marks and your dive computer records accurate surface positions. **Relaxed** is better when you surface well away from the entry point, or when GPS accuracy on your computer is limited.

### Reviewing matches

The review screen appears automatically after a download that produces suggestions, and can also be reached from the overflow menu on the Dives list (**Match dives to sites**). It shows each dive that needs a decision alongside a map panel centered on the dive's GPS position. For each dive:

- A list of nearby candidate sites appears — your existing sites and bundled database sites — each showing its distance from the dive position, depth range, location, rating, and difficulty.
- Tap a candidate card to assign it. The card highlights and the dive row shows a check.
- On wide screens, the map panel and candidate cards appear on the right while the dive list is on the left. On narrow screens, the map and cards expand inline below the focused dive row.

Tap **Confirm** to write all selected matches at once. Auto-matched dives are already linked and do not appear on the review screen.

> [!WARNING]
> If a dive has no nearby candidate sites, it will not appear on the review screen. Add a matching site manually, then re-run **Match dives to sites** from the Dives overflow menu.

## See also

- [Dive Logging](dive-logging.md) — record a dive and link it to a site
- [Trips](trips.md) — group dives from the same location or voyage
- [Marine Life and Photos](marine-life-and-photos.md) — attach species and photos to a site
- [Import / Export](import-export.md) — import dive data from a computer or file
