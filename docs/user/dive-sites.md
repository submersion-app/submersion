# Dive Sites

Build your personal database of the places you dive, with GPS coordinates, depth ranges, hazards, access notes and attachments, and let the map tie everything together.

> [!NOTE]
> **Where to find it:** Tap or click **Sites** in the navigation rail (desktop) or the bottom bar (phone). On a phone it is one of the default bottom-bar slots; if you have moved it, it is under **More**.

<!-- screenshot: images/dive-sites/site-list.png: site list view showing sites with dive counts and ratings -->

## Adding a site

Tap the **Add Site** button (the floating button on a phone; on desktop the same button sits in the top-right area of the detail pane). You can also create a site while picking one for a dive: the name you searched for is filled in for you.

The edit form is divided into collapsible sections. Only the **Name** field is required; everything else is optional and can be filled in later.

### Identity

| Field | Notes |
|-------|-------|
| **Name** | Required. As you type, autocomplete suggests names from your existing sites. A similarity hint appears if your new name is close to one you already have, which catches duplicates before they happen. |
| **Description** | Free-text overview of the site. |
| **Country** | Autocomplete draws from the countries already in your site list. |
| **Region** | Autocomplete suggests regions already used for the same country; fuzzy matching is enabled so partial names surface near-matches. |
| **City**, **Island**, **Body of Water** | More location detail, all optional. |

### Location (GPS coordinates)

Two quick-capture buttons are provided:

- **Use My Location** reads the device GPS and fills in latitude and longitude. On mobile, if permission is denied, a snackbar links directly to app settings. When the device returns a location, country and region are reverse-geocoded and pre-filled if those fields are still blank.
- **Pick from Map** opens a full-screen interactive map where you tap to drop a pin. Country and region are reverse-geocoded from the pin position and pre-filled if still blank.

You can also type decimal latitude and longitude directly. Coordinates are validated on save (latitude −90 to 90, longitude −180 to 180).

> [!TIP]
> You do not need to be at the dive site to add it. Use **Pick From Map** to place a pin anywhere in the world, or type in coordinates you have from a GPS device or chart.

### Altitude

Record the site's altitude above sea level in metres (or feet if you use imperial). When you enter a non-zero altitude, the form shows an **altitude group indicator**: a color-coded badge (informational, caution, warning, or severe) that signals how altitude affects decompression calculations. This matters for inland and high-altitude lake diving.

### Dive info

| Field | Notes |
|-------|-------|
| **Min depth** | Shallowest point of the site, in your unit preference. |
| **Max depth** | Deepest point. On narrow screens both fields appear in a condensed stat strip at the top of the section. |
| **Difficulty** | Choice chip: Beginner, Intermediate, Advanced, or Technical. |
| **Rating** | Your 1 to 5 star rating. Tap a star to set; a **Clear** link removes it. |
| **Water Type** | Salt, fresh, or brackish. |

### Access and safety

| Field | Notes |
|-------|-------|
| **Access Notes** | Entry and exit points, how to reach the site. |
| **Mooring Number** | Mooring buoy identifier for boat dives. |
| **Parking Information** | Parking availability, fees and tips. |
| **Entry Method** / **Exit Method** | How you usually get in and out (shore, boat, back roll, and so on). |
| **Hazards** | Currents, boat traffic, marine life warnings, or other hazards. |

### Site types and tags

**Site types** describe the kind of site: reef, wreck, cave, and so on. Pick one or more from the built-in types or your own; **Manage types** (also **Settings > Manage > Site Types**) adds, renames or hides them. **Tags** work as they do for dives (see [Logging Dives](dive-logging.md)).

### Life and notes

- **Expected Species**: link species you expect to encounter at this site. These appear on the site detail and feed into marine life tracking. (See [Marine Life and Photos](marine-life-and-photos.md).)
- **Notes**: any other free-text information.
- **Share with all dive profiles**: visible only when two or more diver profiles exist. Turn it on to make the site visible to every profile. **Settings > Shared data** has **Share all my sites** to share every site at once, and **Share new sites and trips by default**.

<!-- screenshot: images/dive-sites/site-detail.png: site detail page showing all fields -->

## On the site's page

Besides everything you entered, the site's detail page shows:

- **Dive Statistics** for the site, from the dives you logged there.
- **Dives at this Site**, each opening its dive.
- **Tides**, with no API key needed: from the nearest NOAA tide station when one is close, otherwise an ocean-model estimate (shown with its grid resolution and a caveat for complex coastlines). Times are in the site's local time.
- **Attachments**: photos, site maps, PDFs and other files for the site. Give each one a category (**Access and entry**, **Anchorage and mooring**, **Parking**, **Site map**, **Underwater**, or **General**) and they are grouped under those headings, with maps and PDFs shown full width. An attachment's details change its category and display size; its file name stays as it is, because that is how your other devices find the file.

## The map

<!-- screenshot: images/dive-sites/site-map.png: clustered site map with heat map overlay -->

The Sites map is an interactive world map backed by OpenStreetMap tiles. Toggle to it with the map icon in the app bar (on mobile it opens a dedicated map page; on desktop the map appears in the right pane alongside the list).

### Marker clusters

When multiple sites are close together the map groups them into a numbered cluster bubble. Tapping a cluster animates the map to zoom in and spread the markers apart. Individual site markers are color-coded:

- **Rating-based color** (if the site has a rating): dark green for 4.5 and up, green from 4.0, blue from 3, orange from 2, red below 2.
- **Dive-count color** (no rating set): purple for 10 or more dives, shades of blue for fewer, grey for unvisited sites.

The map scrolls continuously across the 180th meridian, so sites around Fiji or the wider Pacific stay in one piece instead of splitting across the map's edges.

A selected marker enlarges and highlights. Tapping it a second time deselects it.

### Info card

Tapping any marker shows an info card with the site name, location string, dive count, and rating. Tapping **Details** on the card opens the full site detail page.

### Density heat map

The heat map layer shows where your diving activity is concentrated. Toggle it with the heat-map button in the map toolbar (top-right of the map pane). The overlay renders a density-colorized gradient directly over the tile layer: cooler colors for sparse visits, warmer colors where many dives are recorded.

### Map / list split pane (desktop)

On a window at least 1100 px wide the Sites screen uses a split-pane layout: the list occupies the left column and the interactive map fills the right. Selecting a site in the list animates the map to center on that site's marker; tapping a marker highlights the matching row in the list and shows the info card.

### Fit all sites

The crosshairs icon in the map toolbar zooms and pans so that all your sites with valid coordinates are visible at once.

### Offline tile caching

Map tiles are cached locally after the first load, so the map remains usable in areas with limited connectivity. Cached tiles update automatically when a connection is available.

## List, table, and filter views

The site list supports three display modes, **Detailed**, **Compact**, and **Table**, selectable from the overflow menu (three-dot icon in the app bar). **Group by** **Country & region** gathers the list under collapsible country and region headings. Table mode shows a customizable column grid; tap the column-settings icon to add, remove, reorder, or pin columns from the full set of site fields.

Use the filter icon to narrow the list by:

- Country and region
- Difficulty level
- Maximum depth range
- Site type
- Tags
- Minimum rating
- Has GPS coordinates (yes / no)
- Has logged dives (yes / no)

Use the sort icon to order by name, rating, difficulty, max depth, dive count, or when you last dived there.

## Importing sites

Choose **Import** from the overflow menu on the Sites list. Type a place name or choose a quick-search chip (Caribbean, Red Sea, Thailand, Indonesia, Maldives, Philippines). Results appear in two sections:

- **My Sites**: matches from your own site database, shown with a "Saved" badge. Tapping one opens its detail page.
- **Import from Database**: results from the bundled global site database. Tap a result card to preview its description, depth, coordinates, and feature tags, then tap **Import to My Sites**.

Imported sites populate name, description, country, region, GPS coordinates, max depth, and any feature tags from the source record. You can edit any field after import.

The same overflow menu offers **Fill in missing location details** (looks up country and region for sites that have coordinates but no place names) and **Refresh place names** (looks them up again, in your chosen place-name language).

## Picking a site for a dive

Wherever you choose a site (on a dive, a planned dive, or a trip day), the same sheet opens: a search bar that matches every location field, a **Nearby** section when your location is known, and your sites grouped under collapsible country and region headings.

## Merging duplicate sites

If you end up with more than one entry for the same place, choose **Select items** from the list's overflow menu, select them, and tap **Merge Selected**. The merge form (**Merge Sites**) opens with all sections expanded and pre-filled from the first site. For every field that differs between the two sites, a cycle button (two-arrow icon) appears so you can step through the values from each source and keep the one you want. Coordinates, difficulty, and rating each have their own cycle control. Confirm to combine them into one site and relink every dive that was associated with any of them; **Undo** is offered right after.

## GPS auto-matching of dives to sites

When you download dives from a dive computer that records GPS entry or exit positions, Submersion can automatically match each dive to a nearby site, or surface candidates for you to review.

### How matching works

For each dive with a recorded GPS position, the matcher:

1. Ranks every candidate site (your existing sites plus the bundled database) by great-circle distance from the dive's GPS position, nearest first.
2. Applies a two-radius confidence rule:
   - If any **existing** site falls within the **inner radius**, only existing sites compete: an existing site always takes precedence over creating a new entry from the bundled database.
   - The nearest candidate in the winning pool is an **auto-match** when it is the only one in the pool, or when the next nearest is at least the **separation margin** farther away.
   - If no candidate falls inside the inner radius but some fall within the outer radius, the dive is marked **Suggested** and queued for the review screen.
   - No candidates within the outer radius means **No Match**.
3. Every dive then goes to the review screen: auto-matches arrive already selected, suggestions wait for your choice, and dives with no match are listed so you can create a site for them.

### Sensitivity presets

Three presets control the inner radius, outer radius, and separation margin:

| Preset | Inner radius | Outer radius | Separation |
|--------|-------------|-------------|------------|
| **Strict** | 100 m (330 ft) | 500 m (1640 ft) | 100 m (330 ft) |
| **Balanced** (default) | 150 m (490 ft) | 1000 m (3280 ft) | 75 m (245 ft) |
| **Relaxed** | 300 m (985 ft) | 2000 m (6560 ft) | 50 m (165 ft) |

Change the preset with **Auto site matching** in **Settings > Data**.

> [!TIP]
> **Strict** works well when your sites have precise GPS marks and your dive computer records accurate surface positions. **Relaxed** is better when you surface well away from the entry point, or when GPS accuracy on your computer is limited.

### Reviewing matches

After an import, the summary offers **Match N dives to sites**, which opens the review screen; you can also reach it from the overflow menu on the Dives list (**Match Dives to Sites**). It shows each dive that needs a decision alongside a map panel centered on the dive's GPS position. For each dive:

- A list of nearby candidate sites appears (your existing sites and bundled database sites), each showing its distance from the dive position, depth range, location, rating, and difficulty.
- Tap a candidate card to assign it. The card highlights and the dive row shows a check.
- On wide screens, the map panel and candidate cards appear on the right while the dive list is on the left. On narrow screens, the map and cards expand inline below the focused dive row.

A dive with no candidate within range shows **No nearby site**, with **Create site here** to make a new site at its GPS position.

Nothing is linked until you tap **Confirm N matches**, which writes every selected match at once, auto-matches included. Deselect any you disagree with first.

## See also

- [Dive Logging](dive-logging.md): record a dive and link it to a site
- [Trips](trips.md): group dives from the same location or voyage
- [Marine Life and Photos](marine-life-and-photos.md): attach species and photos to a site
- [Import / Export](import-export.md): import dive data from a computer or file
