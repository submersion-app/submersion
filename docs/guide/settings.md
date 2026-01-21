# Settings

Customize Submersion to match your preferences and diving style.

## Accessing Settings

Tap the **Settings** tab (gear icon) in the navigation bar.

<div class="screenshot-placeholder">
  <strong>Screenshot: Settings Page</strong><br>
  <em>Main settings page with all options</em>
</div>

## Units

Configure your preferred measurement units:

| Setting | Options |
|---------|---------|
| **Depth** | Meters, Feet |
| **Temperature** | Celsius, Fahrenheit |
| **Pressure** | Bar, PSI |
| **Volume** | Liters, Cubic Feet |
| **Weight** | Kilograms, Pounds |
| **SAC** | L/min, cu ft/min |

<div class="tip">
<strong>Tip:</strong> Units are stored per-diver, so each profile can have different preferences.
</div>

## Appearance

### Theme Mode

| Option | Description |
|--------|-------------|
| **Light** | Always light theme |
| **Dark** | Always dark theme |
| **System** | Follow device setting |

## Decompression Settings

Configure the Buhlmann algorithm parameters:

### Gradient Factors

| Setting | Default | Description |
|---------|---------|-------------|
| **GF Low** | 30 | Gradient factor at depth |
| **GF High** | 70 | Gradient factor at surface |

<div class="tip">
<strong>Common Presets:</strong>
<ul>
<li>Conservative: 30/70</li>
<li>Moderate: 40/85</li>
<li>Aggressive: 55/95</li>
</ul>
</div>

### O2 Limits

| Setting | Default | Description |
|---------|---------|-------------|
| **ppO2 Max Working** | 1.4 bar | Limit during working portion |
| **ppO2 Max Deco** | 1.6 bar | Limit during deco stops |
| **CNS Warning** | 80% | When to show warning |

### Ascent Rate

| Setting | Default | Description |
|---------|---------|-------------|
| **Warning Rate** | 9 m/min | Yellow warning threshold |
| **Critical Rate** | 12 m/min | Red alert threshold |

### Profile Display

| Setting | Default | Description |
|---------|---------|-------------|
| **Show Ceiling** | On | Display deco ceiling curve |
| **Show Ascent Rate** | On | Color-code ascent rate |
| **Show NDL** | On | Display NDL on profile |

## Default Values

Set defaults for new dives:

| Setting | Description |
|---------|-------------|
| **Default Dive Type** | Pre-selected dive type |
| **Default Tank Volume** | Pre-filled tank size |
| **Default Start Pressure** | Pre-filled start pressure |

## API Keys

Enable external services by adding API keys:

### OpenWeatherMap

For weather data at dive sites:

1. Sign up at [openweathermap.org](https://openweathermap.org/)
2. Get your free API key
3. Enter in **Settings** > **API Keys** > **Weather**

### World Tides

For tide predictions:

1. Sign up at [worldtides.info](https://www.worldtides.info/)
2. Get your API key
3. Enter in **Settings** > **API Keys** > **Tides**

## Cloud Sync

Configure cloud synchronization:

### Google Drive

1. Go to **Settings** > **Cloud Sync**
2. Tap **Connect Google Drive**
3. Sign in with your Google account
4. Grant permissions
5. Sync is enabled

### iCloud

1. Go to **Settings** > **Cloud Sync**
2. Tap **Connect iCloud**
3. Sign in if prompted
4. Sync is enabled

Submersion uses an app-managed JSON sync file stored in a **Submersion Sync** folder
in your cloud provider. If you switch to a custom storage folder, app-managed cloud
sync is disabled and your storage provider handles syncing instead.

### Sync Options

| Option | Description |
|--------|-------------|
| **Auto Sync** | Sync automatically when data changes |
| **Sync on Launch** | Run a sync when the app starts |
| **Sync on Resume** | Run a sync when returning to the app |
| **Sync Now** | Manual sync trigger |
| **Last Sync** | When last synced |

## Diver Profiles

### Switching Divers

If you have multiple profiles:

1. Go to **Settings** > **Divers**
2. Tap the profile you want to use
3. That profile becomes active

### Adding a Diver

1. Go to **Settings** > **Divers**
2. Tap **+ Add Diver**
3. Enter name and details
4. Save

### Editing Your Profile

1. Go to **Settings** > **Divers**
2. Tap **Edit** on your profile
3. Update information:
   - Name, email, phone
   - Emergency contact
   - Medical info
   - Insurance details
4. Save changes

### Deleting a Profile

<div class="warning">
<strong>Warning:</strong> Deleting a profile removes ALL associated data including dives, sites, and gear.
</div>

1. Go to **Settings** > **Divers**
2. Swipe left on the profile
3. Tap **Delete**
4. Confirm deletion

## Dive Computers

Manage paired dive computers:

| Action | Description |
|--------|-------------|
| **Add** | Pair a new computer |
| **Rename** | Change display name |
| **Remove** | Unpair a computer |
| **Download** | Fetch dives |

[Learn more about dive computers &rarr;](guide/dive-computer.md)

## Import/Export

Access data management:

| Action | Description |
|--------|-------------|
| **Import** | UDDF, CSV, or backup |
| **Export** | UDDF, CSV, or PDF |
| **Backup** | Full database backup |
| **Restore** | Restore from backup |

[Learn more about import/export &rarr;](guide/import-export.md)

## About

View app information:

| Info | Description |
|------|-------------|
| **Version** | Current app version |
| **Build** | Build number |
| **Licenses** | Open source licenses |
| **GitHub** | Link to repository |
| **Report Issue** | Link to issue tracker |

## Resetting Settings

To reset all settings to defaults:

1. Go to **Settings** > **About**
2. Tap **Reset Settings**
3. Confirm

<div class="warning">
<strong>Note:</strong> This resets preferences only, not your dive data.
</div>

## Per-Diver Settings

Many settings are stored per-diver:

| Per-Diver | Global |
|-----------|--------|
| Units | Theme |
| GF settings | API keys |
| Default values | Cloud accounts |
| Display options | App version |

This means each diver can have their own preferences when switching profiles.
