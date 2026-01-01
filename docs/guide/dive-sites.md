# Dive Sites & Maps

Build your personal database of dive sites with GPS coordinates, maps, conditions, and access information.

## Site Database

The **Sites** tab shows all your dive sites in a list or map view.

<div class="screenshot-placeholder">
  <strong>Screenshot: Site List View</strong><br>
  <em>List of dive sites with dive counts and ratings</em>
</div>

### Switching Views

Toggle between:
- **List View** - Scrollable list sorted by name or dive count
- **Map View** - Interactive map with clustered markers

<div class="screenshot-placeholder">
  <strong>Screenshot: Site Map View</strong><br>
  <em>Map showing dive sites with cluster markers</em>
</div>

## Creating a Dive Site

1. Tap **+ Add Site** from the Sites tab
2. Enter the required information
3. Optionally capture GPS location
4. Save the site

### Site Fields

| Field | Description |
|-------|-------------|
| **Name** | Site name (required) |
| **Description** | Details about the site |
| **Country** | Country location |
| **Region** | State/province/region |
| **Latitude/Longitude** | GPS coordinates |
| **Min Depth** | Shallowest point |
| **Max Depth** | Deepest point |
| **Difficulty** | Beginner, Intermediate, Advanced, Technical |
| **Rating** | Your 1-5 star rating |
| **Hazards** | Currents, boats, marine life, etc. |
| **Access Notes** | How to get there, entry points |
| **Mooring Number** | Mooring buoy ID |
| **Parking Info** | Parking availability |
| **Notes** | Any other information |

## GPS Location

### Capture Current Location

If you're at the dive site:

1. Tap **Use My Location**
2. Allow location permission if prompted
3. Coordinates are automatically filled

<div class="tip">
<strong>Tip:</strong> Capture location at the entry point for accurate positioning.
</div>

### Manual Entry

Enter coordinates manually in decimal format:
- Latitude: 7.3456 (positive for North)
- Longitude: 134.4567 (positive for East)

### Map Picker

1. Tap the **map icon** next to coordinates
2. Pan and zoom to find the location
3. Tap to place the marker
4. Confirm selection

## Map Features

### Marker Clustering

When zoomed out, nearby sites are grouped into clusters:
- Number shows count of sites in cluster
- Tap cluster to zoom in
- Clusters expand as you zoom

### Marker Colors

Markers are color-coded by difficulty:
- **Green** - Beginner
- **Blue** - Intermediate
- **Orange** - Advanced
- **Red** - Technical
- **Gray** - Unrated

### Map Controls

- **Pinch** - Zoom in/out
- **Drag** - Pan around
- **Double-tap** - Zoom in
- **Tap marker** - View site details

## Weather Integration

If you've configured the OpenWeatherMap API key:

1. Open a site detail page
2. View current weather conditions
3. See forecast for upcoming days

[Configure weather API &rarr;](guide/settings.md#api-keys)

## Tide Integration

With the World Tides API configured:

1. Open a site with coordinates
2. View current tide status
3. See tide predictions

[Configure tide API &rarr;](guide/settings.md#api-keys)

## Nearby Sites

When creating a new dive:

1. If you have location enabled
2. Nearby sites are suggested
3. Tap to quick-select

## Site Statistics

Each site detail page shows:

| Statistic | Description |
|-----------|-------------|
| **Total Dives** | How many times you've dived here |
| **Last Dive** | Date of most recent dive |
| **Depth Range** | Your min/max depths at this site |
| **Avg Visibility** | Average visibility from your dives |

## Importing Sites

Import sites from:
- **CSV files** - Spreadsheet format
- **Other apps** - Via UDDF import

[Learn about importing &rarr;](guide/import-export.md)

## Tips for Site Management

### Naming Conventions

Be consistent with naming:
- "Blue Corner, Palau" not just "Blue Corner"
- Include identifiers: "Wreck of the Thistlegorm"
- Use local names when helpful

### Depth Information

- **Min Depth** = Typical recreational depth
- **Max Depth** = Maximum possible depth
- Helps filter sites for different certification levels

### Hazards Documentation

Note important hazards:
- Strong currents and their patterns
- Boat traffic areas
- Jellyfish seasons
- Down currents or surge

### Access Notes

Include practical information:
- Shore entry points
- Parking locations
- Entry fees
- Best times to dive
- Local regulations
