# Domain Entities

Reference documentation for Submersion's domain entities.

## Core Entities

### Dive

The primary dive log entry entity.

**Location:** `lib/features/dive_log/domain/entities/dive.dart`

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `diverId` | String? | Reference to diver |
| `diveNumber` | int? | Sequential dive number |
| `dateTime` | DateTime | Dive date/time |
| `entryTime` | DateTime? | Water entry time |
| `exitTime` | DateTime? | Water exit time |
| `duration` | Duration? | Bottom time |
| `runtime` | Duration? | Total runtime |
| `maxDepth` | double? | Maximum depth (meters) |
| `avgDepth` | double? | Average depth (meters) |
| `site` | DiveSite? | Dive site reference |
| `diveCenter` | DiveCenter? | Dive center reference |
| `trip` | Trip? | Trip reference |
| `tanks` | List\<DiveTank\> | Tank configurations |
| `profile` | List\<DiveProfilePoint\> | Profile data points |
| `equipment` | List\<EquipmentItem\> | Equipment used |
| `weights` | List\<DiveWeight\> | Weight configuration |
| `tags` | List\<Tag\> | Applied tags |
| `waterTemp` | double? | Water temperature (°C) |
| `airTemp` | double? | Air temperature (°C) |
| `visibility` | Visibility? | Visibility condition |
| `diveTypeId` | String | Dive type reference |
| `notes` | String | Free-text notes |
| `rating` | int? | 1-5 star rating |
| `isFavorite` | bool | Favorite flag |

**Calculated Properties:**

| Property | Return Type | Description |
|----------|-------------|-------------|
| `effectiveEntryTime` | DateTime | Entry time or dateTime |
| `diveTypeName` | String | Display name for dive type |
| `calculatedDuration` | Duration? | Duration from entry/exit |
| `totalWeight` | double | Sum of all weights |
| `sac` | double? | SAC in L/min at surface |
| `sacPressure` | double? | SAC in bar/min |

**Methods:**

```dart
// Copy with modifications
Dive copyWith({String? id, DateTime? dateTime, ...})

// Calculate bottom time from profile
Duration? calculateBottomTimeFromProfile({double depthThresholdPercent = 0.85})
```

---

### DiveTank

Tank configuration for a dive.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String? | User-friendly name |
| `volume` | double? | Volume in liters |
| `workingPressure` | int? | Rated pressure (bar) |
| `startPressure` | int? | Start pressure (bar) |
| `endPressure` | int? | End pressure (bar) |
| `gasMix` | GasMix | Gas composition |
| `role` | TankRole | Tank purpose |
| `material` | TankMaterial? | Construction material |
| `order` | int | Display order |
| `presetName` | String? | Preset used |

**Calculated Properties:**

| Property | Return Type | Description |
|----------|-------------|-------------|
| `pressureUsed` | int? | Pressure consumed |

---

### GasMix

Gas mixture composition.

| Property | Type | Description |
|----------|------|-------------|
| `o2` | double | Oxygen percentage (0-100) |
| `he` | double | Helium percentage (0-100) |

**Calculated Properties:**

| Property | Return Type | Description |
|----------|-------------|-------------|
| `n2` | double | Nitrogen percentage |
| `isAir` | bool | True if air (20-22% O2, 0% He) |
| `isNitrox` | bool | True if nitrox (>22% O2, 0% He) |
| `isTrimix` | bool | True if trimix (He > 0) |
| `name` | String | Display name (e.g., "EAN32") |

**Methods:**

```dart
// Maximum Operating Depth at given ppO2
double mod({double ppO2 = 1.4})

// Equivalent Narcotic Depth at given depth
double end(double depth)
```

---

### DiveProfilePoint

Single point in the dive profile time series.

| Property | Type | Description |
|----------|------|-------------|
| `timestamp` | int | Seconds from dive start |
| `depth` | double | Depth in meters |
| `pressure` | double? | Tank pressure (bar) |
| `temperature` | double? | Temperature (°C) |
| `heartRate` | int? | Heart rate (bpm) |

---

### DiveWeight

Weight entry for a dive.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `diveId` | String | Parent dive reference |
| `amountKg` | double | Weight in kilograms |
| `type` | WeightType | Type of weight |

---

## Location Entities

### DiveSite

Dive site location.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Site name |
| `description` | String | Description |
| `latitude` | double? | GPS latitude |
| `longitude` | double? | GPS longitude |
| `country` | String? | Country |
| `region` | String? | Region/state |
| `minDepth` | double? | Minimum depth (m) |
| `maxDepth` | double? | Maximum depth (m) |
| `difficulty` | SiteDifficulty? | Difficulty level |
| `hazards` | String? | Known hazards |
| `accessNotes` | String? | Access instructions |
| `mooringNumber` | String? | Mooring buoy number |
| `parkingInfo` | String? | Parking details |

---

### DiveCenter

Dive operator/shop.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Center name |
| `address` | String? | Street address |
| `city` | String? | City |
| `country` | String? | Country |
| `phone` | String? | Phone number |
| `email` | String? | Email address |
| `website` | String? | Website URL |
| `notes` | String | Additional notes |

---

### Trip

Dive trip grouping.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Trip name |
| `startDate` | DateTime? | Trip start date |
| `endDate` | DateTime? | Trip end date |
| `destination` | String? | Destination |
| `notes` | String | Trip notes |

---

## People Entities

### Diver

Diver profile (multi-diver support).

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Diver name |
| `email` | String? | Email address |
| `phone` | String? | Phone number |
| `photoPath` | String? | Profile photo path |
| `emergencyContactName` | String? | Emergency contact |
| `emergencyContactPhone` | String? | Emergency phone |
| `emergencyContactRelation` | String? | Relationship |
| `medicalNotes` | String | Medical notes |
| `bloodType` | String? | Blood type |
| `allergies` | String? | Known allergies |
| `insuranceProvider` | String? | Insurance company |
| `insurancePolicyNumber` | String? | Policy number |
| `insuranceExpiryDate` | DateTime? | Policy expiry |
| `isDefault` | bool | Default diver flag |

---

### Buddy

Dive buddy contact.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Buddy name |
| `email` | String? | Email address |
| `phone` | String? | Phone number |
| `certLevel` | String? | Certification level |
| `certAgency` | String? | Certifying agency |
| `notes` | String | Additional notes |

---

### Certification

Diver certification record.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `agency` | CertificationAgency | Certifying agency |
| `level` | CertificationLevel | Certification level |
| `certNumber` | String? | Certificate number |
| `issueDate` | DateTime? | Issue date |
| `expiryDate` | DateTime? | Expiry date |
| `instructorName` | String? | Instructor name |
| `notes` | String | Additional notes |

---

## Equipment Entities

### EquipmentItem

Piece of diving equipment.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Item name |
| `type` | EquipmentType | Equipment category |
| `manufacturer` | String? | Manufacturer |
| `model` | String? | Model name |
| `serialNumber` | String? | Serial number |
| `purchaseDate` | DateTime? | Purchase date |
| `purchasePrice` | double? | Purchase price |
| `status` | EquipmentStatus | Current status |
| `size` | String? | Size (S/M/L/XL) |
| `lastServiceDate` | DateTime? | Last service date |
| `nextServiceDate` | DateTime? | Next service due |
| `serviceIntervalMonths` | int? | Service interval |
| `notes` | String | Additional notes |

---

### EquipmentSet

Named collection of equipment.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Set name |
| `description` | String | Description |
| `items` | List\<EquipmentItem\> | Equipment in set |

---

### ServiceRecord

Equipment service history entry.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `equipmentId` | String | Equipment reference |
| `serviceDate` | DateTime | Service date |
| `serviceType` | ServiceType | Type of service |
| `provider` | String? | Service provider |
| `cost` | double? | Service cost |
| `notes` | String | Service notes |

---

## Organization Entities

### Tag

Organizational tag.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Tag name |
| `color` | int | Color value (ARGB) |

---

### DiveTypeEntity

Custom dive type.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Type name |
| `isBuiltIn` | bool | System-defined flag |
| `sortOrder` | int | Display order |

---

## Profile Entities

### DiveComputer

Dive computer device.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String? | User-defined name |
| `manufacturer` | String? | Manufacturer |
| `model` | String? | Model name |
| `serial` | String? | Serial number |
| `connectionType` | String? | BLE/USB/etc. |
| `lastDownload` | DateTime? | Last sync time |

---

### ProfileEvent

Event marker on dive profile.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `diveId` | String | Parent dive |
| `timestamp` | int | Seconds from start |
| `eventType` | ProfileEventType | Event type |
| `severity` | EventSeverity | Severity level |
| `description` | String? | Event description |

---

### GasSwitch

Gas switch event.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `diveId` | String | Parent dive |
| `timestamp` | int | Seconds from start |
| `tankId` | String | New tank reference |

---

## Wildlife Entities

### Species

Marine species reference.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `commonName` | String | Common name |
| `scientificName` | String? | Scientific name |
| `category` | SpeciesCategory | Category |
| `description` | String | Description |

---

### MarineSighting

Species sighting on a dive.

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `speciesId` | String | Species reference |
| `speciesName` | String | Species name |
| `count` | int | Number seen |
| `notes` | String | Sighting notes |

