# Submersion Data Codemap

> Freshness: 2026-01-21 | Schema Version: 14 | Tables: 32

## Database Overview

SQLite database via Drift ORM. Schema at `lib/core/database/database.dart`.

## Core Tables

### Divers (Multi-profile)
```
divers
├── id (PK)
├── name, email, phone
├── photoPath
├── emergency_contact_* (name, phone, relation)
├── medical_* (notes, bloodType, allergies)
├── insurance_* (provider, policyNumber, expiryDate)
├── notes, isDefault
└── createdAt, updatedAt

diver_settings (1:1 with divers)
├── id (PK), diverId (FK)
├── units: depth, temp, pressure, volume, weight, sac
├── formats: time, date
├── themeMode
├── defaults: diveType, tankVolume, startPressure
├── deco: gfLow, gfHigh, ppO2Max*, cnsWarning, ascentRate*
├── appearance: showDepthColored*, showMapBackground*
└── profile markers: showMaxDepth, showPressureThreshold
```

### Dive Log
```
dives
├── id (PK), diverId (FK)
├── diveNumber, diveDateTime, entryTime, exitTime
├── duration, runtime (seconds)
├── maxDepth, avgDepth (meters)
├── waterTemp, airTemp (celsius)
├── visibility, diveType
├── buddy, diveMaster, notes, rating
├── siteId (FK), diveCenterId (FK), tripId (FK)
├── conditions: current*, swell, entry/exit, waterType
├── altitude, surfacePressure, surfaceIntervalSeconds
├── gradient factors: gfLow, gfHigh
├── computer: model, serial, computerId (FK)
├── weight: amount, type
├── isFavorite, isPlanned
├── CCR: setpoint_low/high/deco
├── SCR: scrType, injectionRate, additionRatio, orificeSize, assumedVo2
├── Diluent: diluentO2, diluentHe
├── Loop: loopO2Min/Max/Avg, loopVolume
├── Scrubber: type, duration, remaining
└── cnsStart, cnsEnd, otu

dive_profiles (time-series)
├── id (PK), diveId (FK), computerId (FK)
├── isPrimary
├── timestamp (sec), depth, pressure, temperature
├── heartRate, ascentRate, ceiling, ndl
└── CCR: setpoint, ppO2

dive_tanks
├── id (PK), diveId (FK), equipmentId (FK)
├── volume, workingPressure
├── startPressure, endPressure
├── o2Percent, hePercent
├── tankOrder, tankRole, tankMaterial
├── tankName, presetName
```

### Locations
```
dive_sites
├── id (PK), diverId (FK)
├── name, description
├── latitude, longitude
├── minDepth, maxDepth, difficulty
├── country, region
├── rating, notes
├── hazards, accessNotes, mooringNumber, parkingInfo

dive_centers
├── id (PK), diverId (FK)
├── name, location, lat/long, country
├── phone, email, website
├── affiliations, rating, notes
```

### Equipment
```
equipment
├── id (PK), diverId (FK)
├── name, type, brand, model
├── serialNumber, size, status
├── purchase: date, price, currency
├── service: lastDate, intervalDays
├── notes, isActive

service_records
├── id (PK), equipmentId (FK)
├── serviceType, serviceDate
├── provider, cost, currency
├── nextServiceDue, notes

equipment_sets (named collections)
├── id (PK), diverId (FK)
├── name, description

equipment_set_items (junction)
└── setId (PK,FK), equipmentId (PK,FK)

dive_equipment (junction)
└── diveId (PK,FK), equipmentId (PK,FK)
```

### Social
```
buddies
├── id (PK), diverId (FK)
├── name, email, phone
├── certificationLevel, certificationAgency
├── photoPath, notes

dive_buddies (junction with role)
├── id (PK), diveId (FK), buddyId (FK)
├── role (buddy, guide, instructor, etc.)

certifications
├── id (PK), diverId (FK)
├── name, agency, level
├── cardNumber, issueDate, expiryDate
├── instructor: name, number
├── photoFrontPath, photoBackPath, notes
```

### Organization
```
trips
├── id (PK), diverId (FK)
├── name, startDate, endDate
├── location, resortName, liveaboardName, notes

tags
├── id (PK), diverId (FK)
├── name, color

dive_tags (junction)
└── id (PK), diveId (FK), tagId (FK)

dive_types (custom types)
├── id (PK), diverId (FK)
├── name, isBuiltIn, sortOrder
```

### Marine Life
```
species (catalog)
├── id (PK)
├── commonName, scientificName
├── category, description, photoPath

sightings
├── id (PK), diveId (FK), speciesId (FK)
├── count, notes
```

### Advanced Features
```
dive_weights (multiple per dive)
├── id (PK), diveId (FK)
├── weightType, amountKg, notes

dive_computers (devices)
├── id (PK), diverId (FK)
├── name, manufacturer, model, serialNumber
├── connectionType, bluetoothAddress
├── lastDownloadTimestamp, diveCount
├── isFavorite, notes

dive_profile_events (markers)
├── id (PK), diveId (FK)
├── timestamp, eventType, severity
├── description, depth, value, tankId

gas_switches
├── id (PK), diveId (FK)
├── timestamp, tankId (FK), depth

tank_pressure_profiles (AI transmitter data)
├── id (PK), diveId (FK), tankId (FK)
├── timestamp, pressure

tank_presets (custom configs)
├── id (PK), diverId (FK)
├── name, displayName
├── volumeLiters, workingPressureBar
├── material, description, sortOrder

tide_records
├── id (PK), diveId (FK)
├── heightMeters, tideState, rateOfChange
├── highTideHeight/Time, lowTideHeight/Time
```

### Sync Infrastructure
```
sync_metadata (global state)
├── id (PK='global')
├── lastSyncTimestamp, deviceId
├── syncProvider, remoteFileId, syncVersion

sync_records (per-record tracking)
├── id (PK)
├── entityType, recordId
├── localUpdatedAt, syncedAt
├── syncStatus (synced, pending, conflict)
├── conflictData (JSON)

deletion_log (soft deletes)
├── id (PK)
├── entityType, recordId, deletedAt
```

## Domain Entities

Located in `lib/features/<feature>/domain/entities/`.

| Entity | Key Fields | Path |
|--------|------------|------|
| Dive | id, dateTime, maxDepth, duration, tanks[], profile[], equipment[] | dive_log/domain/entities/dive.dart |
| DiveTank | id, volume, gasMix, start/endPressure, role | (embedded in dive.dart) |
| DiveProfilePoint | timestamp, depth, pressure, temp, ppO2 | (embedded in dive.dart) |
| GasMix | o2%, he%, computed n2%, MOD, END | (embedded in dive.dart) |
| DiveSite | id, name, lat/long, depth range, country | dive_sites/domain/entities/dive_site.dart |
| Buddy | id, name, email, certification | buddies/domain/entities/buddy.dart |
| Certification | id, name, agency, level, dates | certifications/domain/entities/certification.dart |
| EquipmentItem | id, name, type, brand, status | equipment/domain/entities/equipment_item.dart |
| ServiceRecord | id, type, date, cost, provider | equipment/domain/entities/service_record.dart |
| Trip | id, name, dates, location | trips/domain/entities/trip.dart |
| Tag | id, name, color | tags/domain/entities/tag.dart |
| DiveCenter | id, name, location, contact | dive_centers/domain/entities/dive_center.dart |
| Species | id, commonName, scientificName, category | marine_life/domain/entities/species.dart |
| DiveTypeEntity | id, name, isBuiltIn | dive_types/domain/entities/dive_type_entity.dart |
| TankPresetEntity | id, name, volume, pressure, material | tank_presets/domain/entities/tank_preset_entity.dart |
| DiveComputer | id, name, manufacturer, model | dive_log/domain/entities/dive_computer.dart |

## Enums

Located at `lib/core/constants/enums.dart`:

- DiveType (14 types: recreational, technical, freedive, wreck, cave, etc.)
- EquipmentType (18 types: regulator, bcd, wetsuit, computer, etc.)
- Visibility (5 levels)
- CurrentStrength/Direction
- WaterType (salt, fresh, brackish)
- BuddyRole, CertificationAgency, CertificationLevel
- ServiceType, EquipmentStatus
- WeightType, TankRole, TankMaterial
- DiveMode (oc, ccr, scr)
- ScrType (cmf, pascr, escr)
- ProfileEventType (22 event types)
- AscentRateCategory
