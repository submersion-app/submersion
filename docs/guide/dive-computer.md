# Dive Computer Integration

Download dives directly from 300+ dive computer models via Bluetooth or USB.

## Supported Computers

Submersion uses libdivecomputer to support most major dive computer brands:

### Fully Tested

| Brand | Models |
|-------|--------|
| **Shearwater** | Perdix, Petrel, Teric, Peregrine |
| **Suunto** | D-series, Vyper, Zoop, EON series |
| **Mares** | Puck Pro, Smart, Quad |
| **Aqualung** | i-series, Calm series |
| **Garmin** | Descent series |
| **Oceanic** | Multiple models |
| **Scubapro** | G2, Galileo series |

### Connection Types

| Type | Description |
|------|-------------|
| **Bluetooth Classic** | Older Bluetooth standard |
| **Bluetooth LE (BLE)** | Low energy Bluetooth |
| **USB** | Wired connection (requires adapter) |

## Setting Up Your Computer

### First-Time Pairing

1. Go to **Settings** > **Dive Computers**
2. Tap **+ Add Computer**
3. Put your dive computer in **Transfer Mode**
4. Tap **Scan for Devices**
5. Select your computer from the list
6. Wait for pairing to complete
7. Name your computer (e.g., "My Perdix")

<div class="screenshot-placeholder">
  <strong>Screenshot: Device Discovery</strong><br>
  <em>Scanning for nearby dive computers</em>
</div>

### Transfer Mode

Each computer enters transfer mode differently:

| Brand | How to Enable |
|-------|---------------|
| **Shearwater** | Menu > Bluetooth > Enable |
| **Suunto** | Settings > Connectivity > Enable |
| **Mares** | Settings > Transfer Mode |
| **Garmin** | Settings > Dive App Connection |

Consult your computer's manual for specific instructions.

## Downloading Dives

### Quick Download

1. Put computer in transfer mode
2. Open Submersion
3. Go to **Dives** tab
4. Tap **Download** icon in app bar
5. Select your computer
6. Wait for download

<div class="screenshot-placeholder">
  <strong>Screenshot: Download Progress</strong><br>
  <em>Downloading dives with progress indicator</em>
</div>

### From Computer Page

1. Go to **Settings** > **Dive Computers**
2. Tap your computer
3. Tap **Download Dives**

## Download Options

### Incremental Download

By default, Submersion only downloads **new dives** (since last download).

### Force Full Download

To re-download all dives:
1. Go to computer settings
2. Tap **Download All Dives**
3. Confirm

<div class="warning">
<strong>Note:</strong> Full download may take several minutes for computers with many dives.
</div>

## Duplicate Detection

Submersion automatically detects duplicates:

### How It Works

1. Compares date/time, depth, duration
2. Fuzzy matching accounts for clock drift
3. Duplicate dives are flagged

### Duplicate Actions

When duplicates are found:
- **Skip** - Don't import (default)
- **Update** - Merge new data into existing
- **Import Anyway** - Create duplicate entry

## Profile Data

Downloaded dives include full profile data:

| Data Point | Description |
|------------|-------------|
| **Depth** | Sampled every 1-10 seconds |
| **Temperature** | Water temperature |
| **Pressure** | Tank pressure (if AI) |
| **Heart Rate** | If supported by computer |
| **NDL** | No-decompression limit |
| **Ceiling** | Deco ceiling (if applicable) |

### Profile Analysis

After download, access full analysis:
- [Profile visualization](features/profile-analysis.md)
- [Decompression data](features/decompression.md)
- [O2 toxicity tracking](features/oxygen-tracking.md)

## Multi-Computer Support

### Multiple Devices

You can pair multiple dive computers:
- Different computers for different diving
- Backup computers on same dive
- Shared device (rental)

### Multi-Profile Dives

If you dive with multiple computers simultaneously:
1. Download from each computer
2. Dives are matched by time
3. Each profile is stored separately
4. Select **primary profile** for statistics

<div class="tip">
<strong>Tip:</strong> The primary profile is used for statistics. Usually choose your most accurate computer.
</div>

## Computer Statistics

Each computer page shows:

| Stat | Description |
|------|-------------|
| **Dives Downloaded** | Total from this computer |
| **Last Download** | When last synced |
| **Deepest Dive** | Max depth recorded |
| **Longest Dive** | Max duration recorded |
| **Date Range** | First to last dive |

## Troubleshooting

### Computer Not Found

- Ensure computer is in transfer mode
- Check Bluetooth is enabled on phone/computer
- Try restarting both devices
- Move devices closer together

### Connection Fails

- Check battery on dive computer
- Try forgetting and re-pairing
- Update dive computer firmware
- Ensure Submersion has Bluetooth permission

### Partial Download

- Check dive computer battery
- Don't move away during transfer
- Try downloading fewer dives at once

### Missing Profile Data

Some older computers don't store profiles:
- Dive summary only (no samples)
- Limited to depth/time data
- No temperature or pressure

### Wrong Time Zone

If dive times are offset:
1. Check computer's clock setting
2. Adjust in Submersion if needed
3. Computer time should match local time when diving

## Permissions

Submersion needs these permissions:

| Permission | Purpose |
|------------|---------|
| **Bluetooth** | Communicate with computers |
| **Location** | Required for Bluetooth on Android |
| **Nearby Devices** | Android 12+ Bluetooth access |

## Best Practices

### Regular Downloads

- Download after each dive or dive day
- Don't wait until memory is full
- Keeps log current

### Before Trips

- Download all dives before traveling
- Backup to export file
- Verify everything is synced

### After Firmware Updates

- Re-pair if connection issues
- Download may reset to full
- Check all dives transferred
