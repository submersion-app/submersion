# Dive Logging

Submersion provides comprehensive dive logging with 40+ data fields. This guide covers all the available options.

## Creating a New Dive

From the **Dives** tab, tap the **+ Log Dive** button to open the dive entry form.

<div class="screenshot-placeholder">
  <strong>Screenshot: Dive Entry Form Overview</strong><br>
  <em>The complete dive entry form with all sections visible</em>
</div>

## Dive Entry Fields

### Basic Information

| Field | Description | Required |
|-------|-------------|----------|
| **Dive Number** | Auto-assigned or manual | No |
| **Date & Time** | When the dive started | Yes |
| **Entry Time** | When you entered the water | No |
| **Exit Time** | When you surfaced | No |

<div class="tip">
<strong>Tip:</strong> If you set Entry and Exit times, duration is calculated automatically.
</div>

### Depth & Duration

| Field | Description |
|-------|-------------|
| **Max Depth** | Maximum depth reached (m or ft) |
| **Avg Depth** | Average depth (often from dive computer) |
| **Duration** | Bottom time in minutes |
| **Runtime** | Total time including descent/ascent |

### Location

| Field | Description |
|-------|-------------|
| **Dive Site** | Select from your site database |
| **Dive Center** | Operator/shop you dove with |
| **Trip** | Group dives into trips |

### Conditions

| Field | Options |
|-------|---------|
| **Water Temperature** | Temperature in C or F |
| **Air Temperature** | Surface air temp |
| **Visibility** | Excellent (30m+), Good (15-30m), Moderate (5-15m), Poor (<5m) |
| **Water Type** | Salt, Fresh, Brackish |
| **Current Direction** | N, NE, E, SE, S, SW, W, NW, Variable, None |
| **Current Strength** | None, Light, Moderate, Strong |
| **Swell Height** | Wave height in meters |
| **Entry Method** | Shore, Boat, Back Roll, Giant Stride, etc. |
| **Exit Method** | Same options as entry |

### Tanks & Gas

You can add multiple tanks per dive:

| Field | Description |
|-------|-------------|
| **Volume** | Tank size (e.g., 12L, 80 cu ft) |
| **Working Pressure** | Rated pressure of tank |
| **Start Pressure** | Pressure at dive start |
| **End Pressure** | Pressure at dive end |
| **O2 Percent** | Oxygen percentage (21% for air) |
| **He Percent** | Helium percentage (0% for air/nitrox) |
| **Tank Role** | Back Gas, Stage, Deco, Bailout |
| **Tank Material** | Aluminum, Steel, Carbon Fiber |

<div class="tip">
<strong>Tank Presets:</strong> Use preset buttons like "AL80" or "HP100" to quickly fill in common tank configurations.
</div>

### Technical Diving

For technical divers, additional fields are available:

| Field | Description |
|-------|-------------|
| **Altitude** | Elevation above sea level (for altitude diving) |
| **Surface Pressure** | Ambient pressure if not standard |
| **Surface Interval** | Time since last dive |
| **GF Low / GF High** | Gradient factors used |
| **Dive Mode** | Open Circuit, CCR, SCR |
| **CNS Start** | Starting CNS% |
| **CNS End** | Ending CNS% (calculated if profile exists) |
| **OTU** | Oxygen Tolerance Units accumulated |

### People

| Field | Description |
|-------|-------------|
| **Buddy** | Select from buddy database |
| **Dive Master** | Name of DM/guide |
| **Buddy Role** | Buddy, Guide, Instructor, Student |

### Organization

| Field | Description |
|-------|-------------|
| **Dive Type** | Recreational, Technical, Night, Wreck, Cave, etc. |
| **Tags** | Custom colored tags for organization |
| **Rating** | 1-5 star rating |
| **Favorite** | Mark as favorite for quick access |
| **Notes** | Free-text notes |

## Dive Profile

If you download dives from a dive computer, the profile data is stored and visualized:

<div class="screenshot-placeholder">
  <strong>Screenshot: Dive Profile Chart</strong><br>
  <em>Interactive depth profile with temperature overlay</em>
</div>

Profile features:
- **Zoom & Pan** - Pinch to zoom, drag to pan
- **Touch Markers** - Tap to see data at any point
- **Overlays** - Toggle temperature, pressure, heart rate
- **Ascent Rate** - Color-coded warnings

[Learn more about profile analysis &rarr;](features/profile-analysis.md)

## Dive List Features

### Sorting & Filtering

The dive list can be sorted and filtered:

- **Sort by**: Date, Dive Number, Depth, Duration
- **Filter by**: Date range, Site, Dive Type, Tags

### Search

Use the search bar to find dives by:
- Site name
- Notes content
- Buddy name

### Bulk Operations

Select multiple dives to:
- Delete in bulk
- Export selected dives
- Apply tags

## Multi-Computer Support

If you dive with multiple computers, Submersion tracks profiles from each:

1. The **primary profile** is used for statistics
2. Switch between profiles using the profile selector
3. Each computer is tracked separately with its own dive history

## Automatic Dive Numbering

Submersion automatically numbers your dives:

- New dives get the next sequential number
- If you add a historical dive, numbers adjust
- Renumbering available in Settings if needed

## Equipment Linking

Link equipment to each dive:

1. Scroll to the **Equipment** section
2. Tap **Add Equipment**
3. Select items from your gear catalog

This helps track usage and when gear needs service.

## Weight Tracking

Track your weighting for each dive:

| Weight Type | Description |
|-------------|-------------|
| **Belt** | Traditional weight belt |
| **Integrated** | BCD integrated weights |
| **Trim** | Trim weights for balance |
| **Ankle** | Ankle weights |
| **Backplate** | Backplate weights |

## Marine Life

Log species sightings:

1. Go to the **Sightings** section
2. Tap **Add Sighting**
3. Search the species database
4. Enter count and optional notes

[Learn more about marine life tracking &rarr;](features/marine-life.md)

## Tips for Good Dive Logs

1. **Log immediately** - Details fade quickly after diving
2. **Use notes** - Future you will thank present you
3. **Be consistent** - Use the same fields for better stats
4. **Add context** - Conditions affect dive quality
5. **Rate honestly** - Helps identify your favorite types of diving
