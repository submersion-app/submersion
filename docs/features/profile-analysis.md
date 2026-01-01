# Profile Analysis

Interactive dive profile visualization with depth, temperature, pressure, and decompression overlays.

## Profile Chart

When you download dives from a dive computer, Submersion stores and visualizes the full profile data.

<div class="screenshot-placeholder">
  <strong>Screenshot: Dive Profile Chart</strong><br>
  <em>Full dive profile with depth curve and overlays</em>
</div>

## Chart Features

### Interactive Controls

| Action | Result |
|--------|--------|
| **Pinch** | Zoom in/out on time axis |
| **Drag** | Pan left/right through dive |
| **Tap** | Place marker at point |
| **Double-tap** | Reset zoom |

### Touch Markers

Tap anywhere on the profile to see data at that moment:

| Data Point | Description |
|------------|-------------|
| **Time** | Runtime from dive start |
| **Depth** | Current depth |
| **Temperature** | Water temperature |
| **Pressure** | Tank pressure (if AI) |
| **Ascent Rate** | Rate of depth change |
| **NDL** | No-deco limit remaining |
| **Ceiling** | Deco ceiling (if applicable) |

## Overlays

Toggle different data overlays:

### Temperature

Shows water temperature throughout the dive:
- Blue shading for cold water
- Warmer colors for warmer water
- Temperature scale on right axis

### Tank Pressure

If your dive computer has air integration:
- Pressure curve over time
- SAC calculation
- Consumption rate visualization

### Heart Rate

If your computer records heart rate:
- BPM throughout the dive
- Peak and average values

## Ascent Rate Visualization

Ascent rate is color-coded for safety:

| Rate | Color | Meaning |
|------|-------|---------|
| ≤ 9 m/min | Green | Safe |
| 9-12 m/min | Yellow | Caution |
| > 12 m/min | Red | Too fast |

The profile line changes color based on your ascent rate, making it easy to spot fast ascents.

<div class="tip">
<strong>Tip:</strong> Adjust ascent rate thresholds in Settings > Decompression.
</div>

## Decompression Overlay

For dives requiring decompression:

### Ceiling Curve

A shaded area shows your deco ceiling:
- Red shading = above ceiling (violation)
- Normal shading = ceiling depth
- Extends down as tissue loading increases

### NDL Display

For no-deco portions:
- NDL countdown visible
- Transitions to ceiling when exceeded

[Learn more about decompression &rarr;](features/decompression.md)

## Profile Events

Special events are marked on the profile:

| Event | Marker | Description |
|-------|--------|-------------|
| **Descent** | Blue down arrow | Start of descent |
| **Bottom** | Blue dot | Reached max depth |
| **Ascent Start** | Blue up arrow | Started ascending |
| **Safety Stop** | Green bar | Safety stop performed |
| **Deco Stop** | Orange bar | Mandatory deco stop |
| **Gas Switch** | Yellow circle | Changed gas mix |
| **Alert** | Red triangle | Computer warning |

## Multi-Profile Support

If you dive with multiple computers:

### Profile Selector

A dropdown lets you switch between profiles:
- Each computer's data shown separately
- Compare profiles side by side
- One profile marked as "primary" for stats

### Primary Profile

The primary profile is used for:
- Statistics calculations
- SAC rate
- NDL/ceiling data

To change primary:
1. Open dive detail
2. Tap profile selector
3. Tap **Set as Primary** on desired profile

## Profile Data

### Sample Rate

Computers record data at different intervals:
- High-end: Every 1-2 seconds
- Mid-range: Every 4-10 seconds
- Basic: Every 20-30 seconds

Higher sample rates = smoother profiles.

### Data Points

Each sample includes:

| Field | Source |
|-------|--------|
| Depth | Computer depth sensor |
| Temperature | Computer temp sensor |
| Pressure | Air integration transmitter |
| Heart Rate | HRM strap (if connected) |
| Ceiling | Calculated by computer |
| NDL | Calculated by computer |

### Calculated Data

Submersion calculates additional data:

| Calculated | Description |
|------------|-------------|
| Ascent Rate | Rate between samples |
| SAC | From pressure drop |
| Average Depth | Mathematical average |
| Bottom Time | Time below 85% max |

## Export

### Profile to Image

Save profile chart as image:
1. Open dive detail
2. Go to profile
3. Tap share icon
4. Select **Save as Image**

### Profile Data

Export raw profile data:
1. Export dive as UDDF
2. Profile samples included
3. Import into other software

## Tips

### Best Practice

- Download from computer promptly
- Profile data preserved forever
- Zoom in to analyze specific moments

### Analysis Ideas

- Review fast ascents
- Check SAC during different phases
- Correlate temp changes with depth
- Analyze safety stop execution
