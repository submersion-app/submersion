# Enum Reference

Reference documentation for all enums used in Submersion.

**Location:** `lib/core/constants/enums.dart`

## Dive Enums

### DiveType

Types of dives.

| Value | Display Name |
|-------|--------------|
| `recreational` | Recreational |
| `technical` | Technical |
| `freedive` | Freedive |
| `training` | Training |
| `wreck` | Wreck |
| `cave` | Cave |
| `ice` | Ice |
| `night` | Night |
| `drift` | Drift |
| `deep` | Deep |
| `altitude` | Altitude |
| `shore` | Shore |
| `boat` | Boat |
| `liveaboard` | Liveaboard |

### DiveMode

Diving mode/configuration.

| Value | Display Name | Description |
|-------|--------------|-------------|
| `oc` | Open Circuit | Standard scuba |
| `ccr` | Closed Circuit Rebreather | CCR diving |
| `scr` | Semi-Closed Rebreather | SCR diving |

### Visibility

Water visibility conditions.

| Value | Display Name |
|-------|--------------|
| `excellent` | Excellent (>30m / >100ft) |
| `good` | Good (15-30m / 50-100ft) |
| `moderate` | Moderate (5-15m / 15-50ft) |
| `poor` | Poor (<5m / <15ft) |
| `unknown` | Unknown |

### WaterType

Type of water body.

| Value | Display Name |
|-------|--------------|
| `salt` | Salt Water |
| `fresh` | Fresh Water |
| `brackish` | Brackish |

### CurrentStrength

Underwater current intensity.

| Value | Display Name |
|-------|--------------|
| `none` | None |
| `light` | Light |
| `moderate` | Moderate |
| `strong` | Strong |

### CurrentDirection

Direction of underwater current.

| Value | Display Name |
|-------|--------------|
| `north` | North |
| `northEast` | North-East |
| `east` | East |
| `southEast` | South-East |
| `south` | South |
| `southWest` | South-West |
| `west` | West |
| `northWest` | North-West |
| `variable` | Variable |
| `none` | None |

### EntryMethod

Method of water entry/exit.

| Value | Display Name |
|-------|--------------|
| `shore` | Shore Entry |
| `boat` | Boat Entry |
| `backRoll` | Back Roll |
| `giantStride` | Giant Stride |
| `seatedEntry` | Seated Entry |
| `ladder` | Ladder |
| `platform` | Platform |
| `jetty` | Jetty/Dock |
| `other` | Other |

---

## Tank Enums

### TankRole

Purpose of tank during dive.

| Value | Display Name | Description |
|-------|--------------|-------------|
| `backGas` | Back Gas | Primary breathing gas |
| `stage` | Stage | Carried stage bottle |
| `deco` | Deco | Decompression gas |
| `bailout` | Bailout | CCR bailout |
| `sidemountLeft` | Sidemount Left | Left sidemount |
| `sidemountRight` | Sidemount Right | Right sidemount |
| `pony` | Pony Bottle | Emergency bottle |

### TankMaterial

Tank construction material.

| Value | Display Name |
|-------|--------------|
| `aluminum` | Aluminum |
| `steel` | Steel |
| `carbonFiber` | Carbon Fiber |

---

## Equipment Enums

### EquipmentType

Categories of diving equipment.

| Value | Display Name |
|-------|--------------|
| `regulator` | Regulator |
| `bcd` | BCD |
| `wetsuit` | Wetsuit |
| `drysuit` | Drysuit |
| `fins` | Fins |
| `mask` | Mask |
| `computer` | Dive Computer |
| `tank` | Tank |
| `weights` | Weights |
| `light` | Light |
| `camera` | Camera |
| `smb` | SMB |
| `reel` | Reel |
| `knife` | Knife |
| `hood` | Hood |
| `gloves` | Gloves |
| `boots` | Boots |
| `other` | Other |

### EquipmentStatus

Current equipment status.

| Value | Display Name |
|-------|--------------|
| `active` | Active |
| `needsService` | Needs Service |
| `inService` | In Service |
| `retired` | Retired |
| `loaned` | Loaned Out |
| `lost` | Lost |

### ServiceType

Type of equipment service.

| Value | Display Name |
|-------|--------------|
| `annual` | Annual Service |
| `repair` | Repair |
| `inspection` | Inspection |
| `overhaul` | Overhaul |
| `replacement` | Part Replacement |
| `cleaning` | Cleaning |
| `calibration` | Calibration |
| `warranty` | Warranty Service |
| `recall` | Recall/Safety |
| `other` | Other |

### WeightType

Type of weight system.

| Value | Display Name |
|-------|--------------|
| `belt` | Weight Belt |
| `integrated` | Integrated Weights |
| `ankleWeights` | Ankle Weights |
| `trimWeights` | Trim Weights |
| `backplate` | Backplate Weights |
| `mixed` | Mixed/Combined |

---

## People Enums

### BuddyRole

Role on a dive.

| Value | Display Name |
|-------|--------------|
| `buddy` | Buddy |
| `diveGuide` | Dive Guide |
| `instructor` | Instructor |
| `student` | Student |
| `diveMaster` | Divemaster |
| `solo` | Solo |

### CertificationAgency

Certification agencies.

| Value | Display Name |
|-------|--------------|
| `padi` | PADI |
| `ssi` | SSI |
| `naui` | NAUI |
| `sdi` | SDI |
| `tdi` | TDI |
| `gue` | GUE |
| `raid` | RAID |
| `bsac` | BSAC |
| `cmas` | CMAS |
| `iantd` | IANTD |
| `psai` | PSAI |
| `other` | Other |

### CertificationLevel

Certification levels.

| Value | Display Name |
|-------|--------------|
| `openWater` | Open Water |
| `advancedOpenWater` | Advanced Open Water |
| `rescue` | Rescue Diver |
| `diveMaster` | Divemaster |
| `instructor` | Instructor |
| `masterInstructor` | Master Instructor |
| `courseDirector` | Course Director |
| `nitrox` | Nitrox |
| `advancedNitrox` | Advanced Nitrox |
| `decompression` | Decompression |
| `trimix` | Trimix |
| `cavern` | Cavern |
| `cave` | Cave |
| `wreck` | Wreck |
| `sidemount` | Sidemount |
| `rebreather` | Rebreather |
| `techDiver` | Tech Diver |
| `other` | Other |

---

## Profile Enums

### ProfileEventType

Types of events on dive profile.

| Value | Display Name | Severity |
|-------|--------------|----------|
| `descentStart` | Descent Start | info |
| `descentEnd` | Descent End | info |
| `ascentStart` | Ascent Start | info |
| `safetyStopStart` | Safety Stop Start | info |
| `safetyStopEnd` | Safety Stop End | info |
| `decoStopStart` | Deco Stop Start | info |
| `decoStopEnd` | Deco Stop End | info |
| `gasSwitch` | Gas Switch | info |
| `maxDepth` | Max Depth | info |
| `ascentRateWarning` | Ascent Rate Warning | warning |
| `ascentRateCritical` | Ascent Rate Critical | alert |
| `decoViolation` | Deco Violation | alert |
| `missedStop` | Missed Deco Stop | alert |
| `lowGas` | Low Gas Warning | warning |
| `cnsWarning` | CNS Warning | warning |
| `cnsCritical` | CNS Critical | alert |
| `ppO2High` | High ppO2 | warning |
| `ppO2Low` | Low ppO2 | warning |
| `setpointChange` | Setpoint Change | info |
| `bookmark` | Bookmark | info |
| `alert` | Alert | alert |
| `note` | Note | info |

### EventSeverity

Event severity levels.

| Value | Display Name |
|-------|--------------|
| `info` | Info |
| `warning` | Warning |
| `alert` | Alert |

### AscentRateCategory

Ascent rate safety categories.

| Value | Display Name | Color | Rate |
|-------|--------------|-------|------|
| `safe` | Safe | Green | ≤9 m/min |
| `warning` | Warning | Yellow | 9-12 m/min |
| `danger` | Danger | Red | >12 m/min |

**Helper Method:**

```dart
// Get category from ascent rate in m/min
AscentRateCategory.fromRate(10.5) // returns AscentRateCategory.warning
```

---

## Wildlife Enums

### SpeciesCategory

Marine life categories.

| Value | Display Name |
|-------|--------------|
| `fish` | Fish |
| `shark` | Shark |
| `ray` | Ray |
| `mammal` | Mammal |
| `turtle` | Turtle |
| `invertebrate` | Invertebrate |
| `coral` | Coral |
| `plant` | Plant/Algae |
| `other` | Other |

---

## Usage Examples

### Accessing Enum Values

```dart
// Get display name
DiveType.recreational.displayName // "Recreational"

// Check enum value
if (dive.visibility == Visibility.excellent) { ... }

// Iterate all values
for (final type in EquipmentType.values) {
  print(type.displayName);
}
```

### Parsing from String

```dart
// Parse DiveMode from database code
DiveMode.fromCode('ccr') // DiveMode.ccr

// Default fallback
DiveMode.fromCode('unknown') // DiveMode.oc (default)
```

### Using with Helpers

```dart
// Get ascent rate category
final rate = 11.5; // m/min
final category = AscentRateCategory.fromRate(rate);
// category == AscentRateCategory.warning

// Get event icon
final event = ProfileEventType.gasSwitch;
final icon = event.iconName; // "swap_horiz"
```

