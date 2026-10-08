# Gradient Factors & Dive Events from Dive Computers - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Capture gradient factors, per-sample decompression data, and all dive events from dive computers during download, store them persistently, and display them on the dive profile chart.

**Architecture:** This is a "widen the pipe" change across every layer of the dive computer download stack. The C native bridge currently captures only 4 of 10+ available sample types and skips the deco model field entirely. We extend the C struct, Swift bridge, Pigeon API, Dart mapper, database schema, import pipeline, domain entities, and chart rendering. The database schema already has many of the needed columns (ceiling, ndl, setpoint, ppO2 in DiveProfiles; gradientFactorLow/High in Dives; DiveProfileEvents table) but they are not populated from dive computer downloads.

**Tech Stack:** C (libdivecomputer), Swift (macOS native), Pigeon (code gen), Dart/Flutter, Drift ORM, fl_chart

---

## Phase 1: C Layer - Extend Structs and Sample Callback

### Task 1: Extend `libdc_sample_t` with all sample fields

**Files:**

- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:115-121`

**Step 1: Add new fields to libdc_sample_t**

Replace the existing `libdc_sample_t` struct (lines 115-121) with:

```c
typedef struct {
    unsigned int time_ms;      // milliseconds since dive start
    double depth;              // meters
    double temperature;        // celsius (NAN if unavailable)
    double pressure;           // bar (NAN if unavailable)
    unsigned int tank;         // tank index (UINT32_MAX if unavailable)
    // New fields for full sample capture
    unsigned int heartbeat;    // bpm (UINT32_MAX if unavailable)
    double setpoint;           // bar (NAN if unavailable)
    double ppo2;               // bar (NAN if unavailable, first sensor)
    double cns;                // percentage 0-100 (NAN if unavailable)
    unsigned int rbt;          // remaining bottom time in seconds (UINT32_MAX if unavailable)
    // Decompression status at this sample
    unsigned int deco_type;    // 0=NDL, 1=safetystop, 2=decostop, 3=deepstop (UINT32_MAX if unavailable)
    unsigned int deco_time;    // seconds (NDL seconds or stop time remaining)
    double deco_depth;         // stop depth in meters (NAN if unavailable)
    unsigned int deco_tts;     // Time To Surface in seconds (UINT32_MAX if unavailable)
} libdc_sample_t;
```swift
**Step 2: Add event struct and decomodel fields to libdc_parsed_dive_t**

Add a new event struct before `libdc_parsed_dive_t` (after line 134):

```c
#define LIBDC_MAX_EVENTS 256

typedef struct {
    unsigned int time_ms;      // milliseconds since dive start
    unsigned int type;         // parser_sample_event_t enum value
    unsigned int flags;        // event-specific flags
    unsigned int value;        // event-specific value
} libdc_event_t;
```text
Extend `libdc_parsed_dive_t` (after line 163, before closing brace) with:

```c
    // Decompression model from dive computer
    unsigned int deco_model_type;  // 0=none, 1=buhlmann, 2=vpm, 3=rgbm, 4=dciem
    int deco_conservatism;         // personal adjustment (0 = neutral)
    unsigned int gf_low;           // gradient factor low 0-100 (0 if unknown)
    unsigned int gf_high;          // gradient factor high 0-100 (0 if unknown)

    // Events (dynamically allocated)
    libdc_event_t *events;
    unsigned int event_count;
    unsigned int event_capacity;
```text
**Step 3: Update libdc_parsed_dive_free declaration**

No change needed - the existing declaration covers freeing. But ensure implementation frees events array.

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h
git commit -m "feat: extend C structs for full sample capture and deco model"
```diff
---

### Task 2: Update `sample_callback` to capture all sample types

**Files:**

- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:89-164`

**Step 1: Add push_event helper function**

Add after `push_sample()` (after line 109):

```c
static void push_event(libdc_parsed_dive_t *dive,
                        unsigned int time_ms,
                        unsigned int type,
                        unsigned int flags,
                        unsigned int value) {
    if (dive->event_count >= dive->event_capacity) {
        unsigned int new_cap = dive->event_capacity == 0 ? 64 :
                               dive->event_capacity * 2;
        if (new_cap > LIBDC_MAX_EVENTS) {
            new_cap = LIBDC_MAX_EVENTS;
        }
        if (dive->event_count >= new_cap) {
            return;  // at capacity
        }
        libdc_event_t *new_buf = realloc(dive->events,
                                          new_cap * sizeof(libdc_event_t));
        if (new_buf == NULL) {
            return;
        }
        dive->events = new_buf;
        dive->event_capacity = new_cap;
    }
    libdc_event_t *evt = &dive->events[dive->event_count++];
    evt->time_ms = time_ms;
    evt->type = type;
    evt->flags = flags;
    evt->value = value;
}
```text
**Step 2: Update sample_callback initialization in DC_SAMPLE_TIME case**

Replace lines 142-150 with:

```c
    case DC_SAMPLE_TIME:
        push_sample(state);
        state->has_pending_sample = 1;
        state->current_sample.time_ms = value->time;
        state->current_sample.depth = 0.0;
        state->current_sample.temperature = NAN;
        state->current_sample.pressure = NAN;
        state->current_sample.tank = UINT32_MAX;
        state->current_sample.heartbeat = UINT32_MAX;
        state->current_sample.setpoint = NAN;
        state->current_sample.ppo2 = NAN;
        state->current_sample.cns = NAN;
        state->current_sample.rbt = UINT32_MAX;
        state->current_sample.deco_type = UINT32_MAX;
        state->current_sample.deco_time = 0;
        state->current_sample.deco_depth = NAN;
        state->current_sample.deco_tts = UINT32_MAX;
        break;
```text
**Step 3: Add new DC_SAMPLE_* cases**

Replace the `default: break;` (line 161) with:

```c
    case DC_SAMPLE_HEARTBEAT:
        state->current_sample.heartbeat = value->heartbeat;
        break;
    case DC_SAMPLE_SETPOINT:
        state->current_sample.setpoint = value->setpoint;
        break;
    case DC_SAMPLE_PPO2:
        state->current_sample.ppo2 = value->ppo2.value;
        break;
    case DC_SAMPLE_CNS:
        state->current_sample.cns = value->cns * 100.0;  // fraction to percentage
        break;
    case DC_SAMPLE_RBT:
        state->current_sample.rbt = value->rbt;
        break;
    case DC_SAMPLE_DECO:
        state->current_sample.deco_type = value->deco.type;
        state->current_sample.deco_time = value->deco.time;
        state->current_sample.deco_depth = value->deco.depth;
        state->current_sample.deco_tts = value->deco.tts;
        break;
    case DC_SAMPLE_EVENT:
        push_event(state->dive,
                   state->current_sample.time_ms,
                   value->event.type,
                   value->event.flags,
                   value->event.value);
        break;
    default:
        break;
```text
**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_download.c
git commit -m "feat: capture all sample types and events in sample_callback"
```diff
---

### Task 3: Extract DC_FIELD_DECOMODEL in parse_dive

**Files:**

- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:166-267`

**Step 1: Add DECOMODEL extraction after DIVEMODE (after line 222)**

```c
    // Extract decompression model.
    dc_decomodel_t decomodel = {0};
    if (dc_parser_get_field(parser, DC_FIELD_DECOMODEL, 0, &decomodel) == DC_STATUS_SUCCESS) {
        dive->deco_model_type = decomodel.type;  // DC_DECOMODEL_NONE=0, BUHLMANN=1, VPM=2, RGBM=3, DCIEM=4
        dive->deco_conservatism = decomodel.conservatism;
        dive->gf_low = decomodel.params.gf.low;
        dive->gf_high = decomodel.params.gf.high;
    }
```text
**Step 2: Initialize deco model fields in parse_dive (after line 171)**

After `dive->max_temp = NAN;` add:

```c
    dive->deco_model_type = 0;  // DC_DECOMODEL_NONE
    dive->deco_conservatism = 0;
    dive->gf_low = 0;
    dive->gf_high = 0;
    dive->events = NULL;
    dive->event_count = 0;
    dive->event_capacity = 0;
```text
**Step 3: Free events in dive_callback (line 287)**

After `free(dive.samples);` add:

```c
    free(dive.events);
```text
**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_download.c
git commit -m "feat: extract DC_FIELD_DECOMODEL (gradient factors) from dive computer"
```diff
---

## Phase 2: Swift Bridge - Map New C Fields to Pigeon Messages

### Task 4: Update convertParsedDive() in Swift

**Files:**

- Modify: `packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift:292-388`

**Step 1: Extend ProfileSample mapping (around line 318-331)**

Replace the sample conversion loop to include new fields. Change the sample mapping at ~line 328:

```swift
// Inside the samples mapping loop:
let sample = ProfileSample(
    timeSeconds: Int64(dive.samples[i].time_ms / 1000),
    depthMeters: dive.samples[i].depth,
    temperatureCelsius: dive.samples[i].temperature.isNaN ? nil : dive.samples[i].temperature,
    pressureBar: dive.samples[i].pressure.isNaN ? nil : dive.samples[i].pressure,
    tankIndex: dive.samples[i].tank == UInt32.max ? nil : Int64(dive.samples[i].tank),
    heartRate: dive.samples[i].heartbeat == UInt32.max ? nil : Double(dive.samples[i].heartbeat),
    setpoint: dive.samples[i].setpoint.isNaN ? nil : dive.samples[i].setpoint,
    ppO2: dive.samples[i].ppo2.isNaN ? nil : dive.samples[i].ppo2,
    cns: dive.samples[i].cns.isNaN ? nil : dive.samples[i].cns,
    rbt: dive.samples[i].rbt == UInt32.max ? nil : Int64(dive.samples[i].rbt),
    decoType: dive.samples[i].deco_type == UInt32.max ? nil : Int64(dive.samples[i].deco_type),
    decoTime: dive.samples[i].deco_type == UInt32.max ? nil : Int64(dive.samples[i].deco_time),
    decoDepth: dive.samples[i].deco_depth.isNaN ? nil : dive.samples[i].deco_depth,
    tts: dive.samples[i].deco_tts == UInt32.max ? nil : Int64(dive.samples[i].deco_tts)
)
```text
**Step 2: Map events from C array (replace line 385 where events is always empty)**

Replace the empty events list with:

```swift
// Map events from C array
var events: [DiveEvent] = []
for i in 0..<Int(dive.event_count) {
    let evt = dive.events[i]
    let eventType = mapEventType(evt.type)
    let event = DiveEvent(
        timeSeconds: Int64(evt.time_ms / 1000),
        type: eventType,
        data: [
            "flags": String(evt.flags),
            "value": String(evt.value),
        ]
    )
    events.append(event)
}
```typescript
**Step 3: Add event type mapping helper**

Add a helper function (before or after convertParsedDive):

```swift
private func mapEventType(_ type: UInt32) -> String {
    switch Int32(type) {
    case 0: return "none"
    case 1: return "decostop"
    case 2: return "rbt"
    case 3: return "ascent"
    case 4: return "ceiling"
    case 5: return "workload"
    case 6: return "transmitter"
    case 7: return "violation"
    case 8: return "bookmark"
    case 9: return "surface"
    case 10: return "safetystop"
    case 11: return "gaschange"       // deprecated
    case 12: return "safetystop_voluntary"
    case 13: return "safetystop_mandatory"
    case 14: return "deepstop"
    case 15: return "ceiling_safetystop"
    case 16: return "floor"
    case 17: return "divetime"
    case 18: return "maxdepth"
    case 19: return "olf"
    case 20: return "po2"
    case 21: return "airtime"
    case 22: return "rgbm"
    case 23: return "heading"         // deprecated
    case 24: return "tissuelevel"
    case 25: return "gaschange2"      // deprecated
    default: return "unknown_\(type)"
    }
}
```text
**Step 4: Map deco model fields on ParsedDive (near line 374-385)**

Add deco model fields to the ParsedDive constructor call:

```swift
// Map decompression model
let decoAlgorithm: String?
switch dive.deco_model_type {
case 1: decoAlgorithm = "buhlmann"
case 2: decoAlgorithm = "vpm"
case 3: decoAlgorithm = "rgbm"
case 4: decoAlgorithm = "dciem"
default: decoAlgorithm = nil
}

// In ParsedDive constructor:
// decoAlgorithm: decoAlgorithm,
// gfLow: dive.gf_low > 0 ? Int64(dive.gf_low) : nil,
// gfHigh: dive.gf_high > 0 ? Int64(dive.gf_high) : nil,
// conservatism: dive.deco_conservatism != 0 ? Int64(dive.deco_conservatism) : nil,
```text
**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift
git commit -m "feat: map all C sample fields and events to Pigeon messages in Swift bridge"
```text
---

## Phase 3: Pigeon API - Extend Message Definitions

### Task 5: Add new fields to Pigeon API definition

**Files:**

- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:53-130`

**Step 1: Extend ProfileSample class (lines 53-68)**

Add new fields after `heartRate`:

```dart
class ProfileSample {
  const ProfileSample({
    required this.timeSeconds,
    required this.depthMeters,
    this.temperatureCelsius,
    this.pressureBar,
    this.tankIndex,
    this.heartRate,
    // New: full sample capture
    this.setpoint,
    this.ppO2,
    this.cns,
    this.rbt,
    this.decoType,
    this.decoTime,
    this.decoDepth,
    this.tts,
  });

  final int timeSeconds;
  final double depthMeters;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankIndex;
  final double? heartRate;
  // New fields
  final double? setpoint;    // Current setpoint (bar) for CCR/SCR
  final double? ppO2;        // Measured ppO2 (bar)
  final double? cns;         // CNS percentage (0-100)
  final int? rbt;            // Remaining bottom time (seconds)
  final int? decoType;       // 0=NDL, 1=safetystop, 2=decostop, 3=deepstop
  final int? decoTime;       // Seconds (NDL time or stop time remaining)
  final double? decoDepth;   // Stop depth in meters
  final int? tts;            // Time To Surface (seconds)
}
```text
**Step 2: Extend ParsedDive class (lines 103-130)**

Add deco model fields after `diveMode`:

```dart
class ParsedDive {
  const ParsedDive({
    required this.fingerprint,
    required this.dateTimeEpoch,
    required this.maxDepthMeters,
    required this.avgDepthMeters,
    required this.durationSeconds,
    this.minTemperatureCelsius,
    this.maxTemperatureCelsius,
    required this.samples,
    required this.tanks,
    required this.gasMixes,
    required this.events,
    this.diveMode,
    // New: decompression model
    this.decoAlgorithm,
    this.gfLow,
    this.gfHigh,
    this.conservatism,
  });

  final String fingerprint;
  final int dateTimeEpoch;
  final double maxDepthMeters;
  final double avgDepthMeters;
  final int durationSeconds;
  final double? minTemperatureCelsius;
  final double? maxTemperatureCelsius;
  final List<ProfileSample> samples;
  final List<TankInfo> tanks;
  final List<GasMix> gasMixes;
  final List<DiveEvent> events;
  final String? diveMode;
  // New fields
  final String? decoAlgorithm;  // 'buhlmann', 'vpm', 'rgbm', 'dciem', or null
  final int? gfLow;             // Gradient Factor Low (0-100), null if unknown
  final int? gfHigh;            // Gradient Factor High (0-100), null if unknown
  final int? conservatism;      // Personal adjustment (-3 to +3 typical)
}
```text
**Step 3: Regenerate Pigeon code**

Run:

```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart
```text
This regenerates:

- `lib/src/generated/dive_computer_api.g.dart`
- `macos/Classes/DiveComputerApi.g.swift`

**Step 4: Verify the generated Swift code compiles**

The generated `DiveComputerApi.g.swift` will have the new fields. Verify the Swift bridge file (`DiveComputerHostApiImpl.swift`) uses the correct new constructor parameters.

**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart
git add packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart
git add packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift
git commit -m "feat: extend Pigeon API with deco model and full sample fields"
```text
---

## Phase 4: Dart Domain Layer - DownloadedDive and Mapper

### Task 6: Add events list and deco model to DownloadedDive

**Files:**

- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart:85-254`

**Step 1: Write test for DownloadedDive deco model fields**

Create test file: `test/features/dive_computer/domain/entities/downloaded_dive_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  group('DownloadedDive', () {
    test('should store deco algorithm and gradient factors', () {
      final dive = DownloadedDive(
        startTime: DateTime(2024, 1, 1, 10, 0),
        durationSeconds: 3600,
        maxDepth: 30.0,
        profile: const [],
        decoAlgorithm: 'buhlmann',
        gfLow: 30,
        gfHigh: 70,
        conservatism: 0,
      );

      expect(dive.decoAlgorithm, 'buhlmann');
      expect(dive.gfLow, 30);
      expect(dive.gfHigh, 70);
      expect(dive.conservatism, 0);
    });

    test('should store events list', () {
      final events = [
        DownloadedEvent(
          timeSeconds: 120,
          type: 'safetystop',
          flags: 0,
          value: 0,
        ),
      ];
      final dive = DownloadedDive(
        startTime: DateTime(2024, 1, 1, 10, 0),
        durationSeconds: 3600,
        maxDepth: 30.0,
        profile: const [],
        events: events,
      );

      expect(dive.events.length, 1);
      expect(dive.events.first.type, 'safetystop');
    });
  });

  group('ProfileSample', () {
    test('should store deco status fields', () {
      final sample = ProfileSample(
        timeSeconds: 60,
        depth: 20.0,
        ndl: 45,
        ceiling: 0.0,
        decoType: 0,
        tts: 120,
        cns: 5.2,
        ppo2: 0.5,
        setpoint: 1.3,
        rbt: 300,
      );

      expect(sample.ndl, 45);
      expect(sample.ceiling, 0.0);
      expect(sample.decoType, 0);
      expect(sample.tts, 120);
      expect(sample.cns, 5.2);
      expect(sample.ppo2, 0.5);
      expect(sample.setpoint, 1.3);
      expect(sample.rbt, 300);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_computer/domain/entities/downloaded_dive_test.dart`
Expected: FAIL (missing fields)

**Step 3: Add deco model fields to DownloadedDive class**

Add to `DownloadedDive` class (after `fingerprint` field, ~line 117):

```dart
  /// Decompression algorithm used by the dive computer
  final String? decoAlgorithm;  // 'buhlmann', 'vpm', 'rgbm', 'dciem'

  /// Gradient Factor Low setting (0-100)
  final int? gfLow;

  /// Gradient Factor High setting (0-100)
  final int? gfHigh;

  /// Personal conservatism adjustment
  final int? conservatism;

  /// Events reported by the dive computer
  final List<DownloadedEvent> events;
```text
Update constructor to include these (with defaults):

```dart
    this.decoAlgorithm,
    this.gfLow,
    this.gfHigh,
    this.conservatism,
    this.events = const [],
```text
**Step 4: Add DownloadedEvent class**

Add after `GasSwitchEvent` class (~line 254):

```dart
/// An event reported by the dive computer during the dive.
class DownloadedEvent {
  final int timeSeconds;
  final String type;
  final int flags;
  final int value;

  const DownloadedEvent({
    required this.timeSeconds,
    required this.type,
    this.flags = 0,
    this.value = 0,
  });
}
```text
**Step 5: Add deco fields to ProfileSample**

The ProfileSample class already has `ppo2`, `cns`, `ndl`, `ceiling`, `ascentRate` fields (lines 161-173). Add missing fields:

```dart
  final double? setpoint;    // Current setpoint (bar)
  final int? rbt;            // Remaining bottom time (seconds)
  final int? decoType;       // 0=NDL, 1=safetystop, 2=decostop, 3=deepstop
  final int? decoTime;       // Seconds (NDL time or stop time remaining)
  final double? decoDepth;   // Stop depth in meters
  final int? tts;            // Time To Surface (seconds)
```text
Update the constructor to include these fields.

**Step 6: Run test to verify it passes**

Run: `flutter test test/features/dive_computer/domain/entities/downloaded_dive_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/dive_computer/domain/entities/downloaded_dive.dart
git add test/features/dive_computer/domain/entities/downloaded_dive_test.dart
git commit -m "feat: add deco model, events, and full sample fields to DownloadedDive"
```text
---

### Task 7: Update parsed_dive_mapper to map new fields

**Files:**

- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart:5-41`
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`

**Step 1: Write test for mapper with new fields**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

void main() {
  group('parsedDiveToDownloaded', () {
    test('should map gradient factors from ParsedDive', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1704067200,  // 2024-01-01 00:00 UTC
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.0,
        durationSeconds: 3600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
        decoAlgorithm: 'buhlmann',
        gfLow: 30,
        gfHigh: 70,
        conservatism: 0,
      );

      final result = parsedDiveToDownloaded(parsed);

      expect(result.decoAlgorithm, 'buhlmann');
      expect(result.gfLow, 30);
      expect(result.gfHigh, 70);
      expect(result.conservatism, 0);
    });

    test('should map events from ParsedDive', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1704067200,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.0,
        durationSeconds: 3600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [
          pigeon.DiveEvent(
            timeSeconds: 120,
            type: 'safetystop',
            data: {'flags': '0', 'value': '0'},
          ),
        ],
      );

      final result = parsedDiveToDownloaded(parsed);

      expect(result.events.length, 1);
      expect(result.events.first.type, 'safetystop');
      expect(result.events.first.timeSeconds, 120);
    });

    test('should map deco sample fields', () {
      final parsed = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1704067200,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 20.0,
            decoType: 0,
            decoTime: 45,
            decoDepth: 0.0,
            tts: 120,
            cns: 5.2,
            ppO2: 0.5,
            setpoint: 1.3,
            rbt: 300,
          ),
        ],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      final result = parsedDiveToDownloaded(parsed);
      final sample = result.profile.first;

      expect(sample.ndl, 45);  // decoType 0 = NDL, so decoTime is NDL seconds
      expect(sample.tts, 120);
      expect(sample.cns, 5.2);
      expect(sample.ppo2, 0.5);
      expect(sample.setpoint, 1.3);
      expect(sample.rbt, 300);
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: FAIL

**Step 3: Update parsedDiveToDownloaded() implementation**

In the sample mapping loop, add new field mappings:

```dart
DownloadedDive parsedDiveToDownloaded(pigeon.ParsedDive parsed) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(
    parsed.dateTimeEpoch * 1000,
    isUtc: true,
  );

  return DownloadedDive(
    startTime: dateTime,
    durationSeconds: parsed.durationSeconds,
    maxDepth: parsed.maxDepthMeters,
    avgDepth: parsed.avgDepthMeters,
    minTemperature: parsed.minTemperatureCelsius,
    maxTemperature: parsed.maxTemperatureCelsius,
    fingerprint: parsed.fingerprint,
    decoAlgorithm: parsed.decoAlgorithm,
    gfLow: parsed.gfLow,
    gfHigh: parsed.gfHigh,
    conservatism: parsed.conservatism,
    profile: parsed.samples
        .map(
          (s) => ProfileSample(
            timeSeconds: s.timeSeconds,
            depth: s.depthMeters,
            temperature: s.temperatureCelsius,
            pressure: s.pressureBar,
            tankIndex: s.tankIndex,
            heartRate: s.heartRate?.toInt(),
            setpoint: s.setpoint,
            ppo2: s.ppO2,
            cns: s.cns,
            rbt: s.rbt,
            decoType: s.decoType,
            decoTime: s.decoTime,
            decoDepth: s.decoDepth,
            tts: s.tts,
            // Derive NDL from deco: when decoType == 0 (NDL), decoTime is the NDL value
            ndl: s.decoType == 0 ? s.decoTime : null,
            // Derive ceiling from deco: decoDepth is the ceiling for stop types
            ceiling: (s.decoType != null && s.decoType! > 0) ? s.decoDepth : 0.0,
          ),
        )
        .toList(),
    tanks: parsed.tanks
        .map(
          (t) => DownloadedTank(
            index: t.index,
            o2Percent: parsed.gasMixes
                .firstWhere(
                  (g) => g.index == t.gasMixIndex,
                  orElse: () => const pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
                )
                .o2Percent,
            hePercent: parsed.gasMixes
                .firstWhere(
                  (g) => g.index == t.gasMixIndex,
                  orElse: () => const pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
                )
                .hePercent,
            startPressure: t.startPressureBar,
            endPressure: t.endPressureBar,
            volumeLiters: t.volumeLiters,
          ),
        )
        .toList(),
    events: parsed.events
        .map(
          (e) => DownloadedEvent(
            timeSeconds: e.timeSeconds,
            type: e.type,
            flags: int.tryParse(e.data?['flags'] ?? '') ?? 0,
            value: int.tryParse(e.data?['value'] ?? '') ?? 0,
          ),
        )
        .toList(),
  );
}
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/dive_computer/data/services/parsed_dive_mapper.dart
git add test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
git commit -m "feat: map deco model, events, and full sample data in parsed_dive_mapper"
```text
---

## Phase 5: Database Schema - Add Missing Columns

### Task 8: Add new columns to DiveProfiles and Dives tables

**Files:**

- Modify: `lib/core/database/database.dart:186-216` (DiveProfiles table)
- Modify: `lib/core/database/database.dart:107-108` (Dives table)
- Modify: `lib/core/database/database.dart:1093` (schemaVersion)
- Modify: `lib/core/database/database.dart:1096+` (migration)

**Step 1: Add new columns to DiveProfiles table**

After `ppO2` (line 208), add:

```dart
  // Computer-reported decompression data
  RealColumn get cns => real().nullable()(); // CNS% at sample (0-100)
  IntColumn get tts => integer().nullable()(); // Time To Surface (seconds)
  IntColumn get rbt => integer().nullable()(); // Remaining Bottom Time (seconds)
  TextColumn get decoType =>
      text().nullable()(); // 'ndl', 'safetystop', 'decostop', 'deepstop'
```text
**Step 2: Add decoAlgorithm to Dives table**

After `gradientFactorHigh` (line 108), add:

```dart
  // Decompression algorithm used by the dive computer
  TextColumn get decoAlgorithm =>
      text().nullable()(); // 'buhlmann', 'vpm', 'rgbm', 'dciem'
  IntColumn get decoConservatism =>
      integer().nullable()(); // Personal adjustment setting
```text
**Step 3: Bump schema version**

Change line 1093: `int get schemaVersion => 40;`

**Step 4: Add migration**

In the migration strategy, add a case for version 40:

```dart
if (from < 40) {
  // Add computer-reported deco data to profile samples
  await m.addColumn(diveProfiles, diveProfiles.cns);
  await m.addColumn(diveProfiles, diveProfiles.tts);
  await m.addColumn(diveProfiles, diveProfiles.rbt);
  await m.addColumn(diveProfiles, diveProfiles.decoType);
  // Add deco algorithm to dives
  await m.addColumn(dives, dives.decoAlgorithm);
  await m.addColumn(dives, dives.decoConservatism);
}
```text
**Step 5: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 6: Verify build passes**

Run: `flutter analyze`
Expected: No errors

**Step 7: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat: add deco model and computer-reported sample columns (schema v40)"
```text
---

## Phase 6: Import Pipeline - Persist New Fields

### Task 9: Extend ProfilePointData with new fields

**Files:**

- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:1160-1178`

**Step 1: Add new fields to ProfilePointData**

```dart
class ProfilePointData {
  final int timestamp;
  final double depth;
  final double? pressure;
  final double? temperature;
  final int? heartRate;
  final int? tankIndex;
  // New: computer-reported data
  final double? setpoint;
  final double? ppO2;
  final double? cns;
  final int? ndl;
  final double? ceiling;
  final int? tts;
  final int? rbt;
  final String? decoType;  // 'ndl', 'safetystop', 'decostop', 'deepstop'

  const ProfilePointData({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.tankIndex,
    this.setpoint,
    this.ppO2,
    this.cns,
    this.ndl,
    this.ceiling,
    this.tts,
    this.rbt,
    this.decoType,
  });
}
```text
**Step 2: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "feat: extend ProfilePointData with computer-reported deco fields"
```text
---

### Task 10: Update importProfile() to persist new fields and GF

**Files:**

- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:689-932`

**Step 1: Add deco model parameters to importProfile()**

Add to the method signature:

```dart
Future<String> importProfile({
  required String computerId,
  required DateTime profileStartTime,
  required List<ProfilePointData> points,
  required int durationSeconds,
  double? maxDepth,
  double? avgDepth,
  bool isPrimary = false,
  String? diverId,
  List<TankData>? tanks,
  // New: deco model from dive computer
  String? decoAlgorithm,
  int? gfLow,
  int? gfHigh,
  int? decoConservatism,
  // New: events from dive computer
  List<DownloadedEvent>? events,
}) async
```text
**Step 2: Set GF and deco model on new dive creation**

In the DivesCompanion creation (around lines 740-760), add:

```dart
// After diveComputerFirmware:
gradientFactorLow: gfLow != null ? Value(gfLow) : const Value.absent(),
gradientFactorHigh: gfHigh != null ? Value(gfHigh) : const Value.absent(),
decoAlgorithm: decoAlgorithm != null ? Value(decoAlgorithm) : const Value.absent(),
decoConservatism: decoConservatism != null ? Value(decoConservatism) : const Value.absent(),
```sql
**Step 3: Persist new profile point fields in batch insert**

In the profile points batch insert (around lines 797-819), extend the DiveProfilesCompanion:

```dart
DiveProfilesCompanion(
  id: Value(_uuid.v4()),
  diveId: Value(diveId),
  computerId: Value(computerId),
  timestamp: Value(point.timestamp),
  depth: Value(point.depth),
  pressure: Value(tankZeroPressure),  // existing logic
  temperature: Value(point.temperature),
  heartRate: Value(point.heartRate),
  isPrimary: Value(isPrimary),
  // New: computer-reported data
  setpoint: Value(point.setpoint),
  ppO2: Value(point.ppO2),
  cns: Value(point.cns),
  ndl: Value(point.ndl),
  ceiling: Value(point.ceiling),
  tts: Value(point.tts),
  rbt: Value(point.rbt),
  decoType: Value(point.decoType),
)
```sql
**Step 4: Persist events to DiveProfileEvents table**

After the profile points batch insert, add events batch insert:

```dart
// Insert events from dive computer
if (events != null && events.isNotEmpty) {
  final now = DateTime.now();
  await _db.batch((b) {
    b.insertAll(
      _db.diveProfileEvents,
      events.map(
        (e) => DiveProfileEventsCompanion.insert(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: e.timeSeconds,
          eventType: _mapDownloadedEventType(e.type),
          severity: _mapEventSeverity(e.type),
          depth: Value(_findDepthAtTimestamp(points, e.timeSeconds)),
          value: Value(e.value.toDouble()),
          createdAt: now.millisecondsSinceEpoch,
        ),
      ).toList(),
    );
  });
}
```typescript
**Step 5: Add event type mapping helper**

```dart
String _mapDownloadedEventType(String dcEventType) {
  switch (dcEventType) {
    case 'safetystop':
    case 'safetystop_voluntary':
      return 'safetyStopStart';
    case 'safetystop_mandatory':
      return 'safetyStopStart';  // with severity = warning
    case 'decostop':
      return 'decoStopStart';
    case 'deepstop':
      return 'decoStopStart';
    case 'ascent':
      return 'ascentRateWarning';
    case 'violation':
      return 'decoViolation';
    case 'ceiling':
    case 'ceiling_safetystop':
      return 'decoViolation';
    case 'bookmark':
      return 'bookmark';
    case 'surface':
      return 'ascentStart';
    case 'gaschange':
    case 'gaschange2':
      return 'gasSwitch';
    case 'po2':
      return 'ppO2High';
    default:
      return 'note';  // generic fallback for unknown events
  }
}

String _mapEventSeverity(String dcEventType) {
  switch (dcEventType) {
    case 'violation':
    case 'ceiling':
    case 'ceiling_safetystop':
      return 'alert';
    case 'ascent':
    case 'safetystop_mandatory':
    case 'po2':
      return 'warning';
    default:
      return 'info';
  }
}

double? _findDepthAtTimestamp(List<ProfilePointData> points, int timeSeconds) {
  for (final point in points) {
    if (point.timestamp == timeSeconds) return point.depth;
  }
  // Find closest point
  ProfilePointData? closest;
  int minDiff = 999999;
  for (final point in points) {
    final diff = (point.timestamp - timeSeconds).abs();
    if (diff < minDiff) {
      minDiff = diff;
      closest = point;
    }
  }
  return closest?.depth;
}
```text
**Step 6: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "feat: persist GF, deco model, sample deco data, and events during import"
```typescript
---

### Task 11: Update callers of importProfile to pass new data

**Files:**

- Search for all callers of `importProfile()` and update them to pass GF, events, and new sample fields.

**Step 1: Find callers**

Search for `importProfile(` across the codebase. Typical callers are in:

- `lib/features/dive_computer/data/services/dive_import_service.dart` or similar
- The download notifier that orchestrates import after download

**Step 2: Update each caller**

Where `DownloadedDive` data is converted to `ProfilePointData` list, extend the mapping:

```dart
// Existing pattern (find and update):
final points = downloadedDive.profile
    .map((s) => ProfilePointData(
          timestamp: s.timeSeconds,
          depth: s.depth,
          pressure: s.pressure,
          temperature: s.temperature,
          heartRate: s.heartRate,
          tankIndex: s.tankIndex,
          // New fields:
          setpoint: s.setpoint,
          ppO2: s.ppo2,
          cns: s.cns,
          ndl: s.ndl,
          ceiling: s.ceiling,
          tts: s.tts,
          rbt: s.rbt,
          decoType: _mapDecoType(s.decoType),
        ))
    .toList();
```text
Where `importProfile()` is called, add:

```dart
await repository.importProfile(
  // ... existing params ...
  decoAlgorithm: downloadedDive.decoAlgorithm,
  gfLow: downloadedDive.gfLow,
  gfHigh: downloadedDive.gfHigh,
  decoConservatism: downloadedDive.conservatism,
  events: downloadedDive.events,
);
```text
Add decoType mapping helper:

```dart
String? _mapDecoType(int? decoType) {
  if (decoType == null) return null;
  switch (decoType) {
    case 0: return 'ndl';
    case 1: return 'safetystop';
    case 2: return 'decostop';
    case 3: return 'deepstop';
    default: return null;
  }
}
```text
**Step 3: Commit**

```bash
git add lib/features/dive_computer/
git commit -m "feat: pass deco model, events, and full sample data through import pipeline"
```text
---

## Phase 7: Domain Entity + Repository Read

### Task 12: Extend DiveProfilePoint with new fields

**Files:**

- Modify: `lib/features/dive_log/domain/entities/dive.dart` (DiveProfilePoint class, ~line 643)

**Step 1: Write test for DiveProfilePoint with deco fields**

```dart
// In test/features/dive_log/domain/entities/dive_profile_point_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveProfilePoint', () {
    test('should include computer-reported deco fields', () {
      final point = DiveProfilePoint(
        timestamp: 60,
        depth: 20.0,
        ndl: 45,
        ceiling: 0.0,
        cns: 5.2,
        tts: 120,
        rbt: 300,
        decoType: 'ndl',
      );

      expect(point.ndl, 45);
      expect(point.ceiling, 0.0);
      expect(point.cns, 5.2);
      expect(point.tts, 120);
      expect(point.rbt, 300);
      expect(point.decoType, 'ndl');
    });

    test('should include fields in Equatable props', () {
      final a = DiveProfilePoint(timestamp: 60, depth: 20.0, ndl: 45);
      final b = DiveProfilePoint(timestamp: 60, depth: 20.0, ndl: 45);
      final c = DiveProfilePoint(timestamp: 60, depth: 20.0, ndl: 30);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_profile_point_test.dart`
Expected: FAIL

**Step 3: Add new fields to DiveProfilePoint**

Add after existing `ppO2` field:

```dart
  final int? ndl;          // No-deco limit (seconds), from computer
  final double? ceiling;   // Deco ceiling (meters), from computer
  final double? cns;       // CNS % at sample, from computer
  final int? tts;          // Time To Surface (seconds), from computer
  final int? rbt;          // Remaining Bottom Time (seconds), from computer
  final String? decoType;  // 'ndl', 'safetystop', 'decostop', 'deepstop'
  final double? ascentRate; // m/min, from computer or calculated
```text
Update constructor, copyWith(), and Equatable props list.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_profile_point_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart
git add test/features/dive_log/domain/entities/dive_profile_point_test.dart
git commit -m "feat: add computer-reported deco fields to DiveProfilePoint"
```text
---

### Task 13: Add decoAlgorithm to Dive entity

**Files:**

- Modify: `lib/features/dive_log/domain/entities/dive.dart` (Dive class)

**Step 1: Add decoAlgorithm and decoConservatism fields**

After `gradientFactorHigh` (~line 58), add:

```dart
  final String? decoAlgorithm;     // 'buhlmann', 'vpm', 'rgbm', 'dciem'
  final int? decoConservatism;     // Personal adjustment setting
```text
Update constructor, copyWith(), and Equatable props.

**Step 2: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart
git commit -m "feat: add decoAlgorithm and decoConservatism to Dive entity"
```text
---

### Task 14: Update repository to read new fields from database

**Files:**

- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

**Step 1: Update all DiveProfilePoint constructors in repository**

Find all places where `DiveProfilePoint(` is constructed from database rows (approximately 5 locations based on grep results). Each currently looks like:

```dart
domain.DiveProfilePoint(
  timestamp: p.timestamp,
  depth: p.depth,
  pressure: p.pressure,
  temperature: p.temperature,
  heartRate: p.heartRate,
  heartRateSource: p.heartRateSource,
)
```text
Update each to include the new fields:

```dart
domain.DiveProfilePoint(
  timestamp: p.timestamp,
  depth: p.depth,
  pressure: p.pressure,
  temperature: p.temperature,
  heartRate: p.heartRate,
  heartRateSource: p.heartRateSource,
  setpoint: p.setpoint,
  ppO2: p.ppO2,
  ndl: p.ndl,
  ceiling: p.ceiling,
  cns: p.cns,
  tts: p.tts,
  rbt: p.rbt,
  decoType: p.decoType,
  ascentRate: p.ascentRate,
)
```text
Locations to update (found via grep):

- Line 223-230
- Line 353-360
- Line 433 (minimal, just timestamp+depth — leave as-is for performance)
- Line 2187-2194

**Step 2: Update _mapRowToDiveWithPreloadedData for Dive entity**

Ensure `decoAlgorithm` and `decoConservatism` are mapped from the Dives row to the Dive entity. Find the Dive constructor call in `_mapRowToDiveWithPreloadedData` (~line 1711+) and `_mapRowToDive` (~line 1933+) and add:

```dart
decoAlgorithm: row.decoAlgorithm,
decoConservatism: row.decoConservatism,
```text
**Step 3: Verify build passes**

Run: `flutter analyze`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart
git commit -m "feat: read computer-reported deco data and deco model from database"
```text
---

## Phase 8: Profile Analysis - Use Computer GF and Prefer Computer Data

### Task 15: Use dive-specific GF in ProfileAnalysisService

**Files:**

- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart`
- Modify: caller that creates ProfileAnalysisService (likely in a provider or the dive detail page)

**Step 1: Write test for GF override**

```dart
// test/features/dive_log/data/services/profile_analysis_gf_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  group('ProfileAnalysisService with custom GF', () {
    test('should use provided GF values for calculations', () {
      // GF 30/70 (conservative)
      final conservative = ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70);
      // GF 55/90 (liberal)
      final liberal = ProfileAnalysisService(gfLow: 0.55, gfHigh: 0.90);

      // Same dive profile - 30m for 20 minutes
      final depths = [0.0, 10.0, 20.0, 30.0, 30.0, 30.0, 20.0, 10.0, 5.0, 0.0];
      final timestamps = [0, 60, 120, 180, 600, 1200, 1260, 1320, 1380, 1440];

      final conservativeResult = conservative.analyze(
        diveId: 'test',
        depths: depths,
        timestamps: timestamps,
      );
      final liberalResult = liberal.analyze(
        diveId: 'test',
        depths: depths,
        timestamps: timestamps,
      );

      // Liberal GF should show higher NDL values (less conservative)
      // At the bottom portion, NDL should differ
      // Find a point where both have NDL data
      final conservativeNdl = conservativeResult.ndlCurve[4]; // at 30m, 600s
      final liberalNdl = liberalResult.ndlCurve[4]; // same point

      expect(liberalNdl, greaterThan(conservativeNdl),
          reason: 'Liberal GF should have higher NDL than conservative');
    });
  });
}
```text
**Step 2: Run test to verify it passes (GF is already parameterized)**

Run: `flutter test test/features/dive_log/data/services/profile_analysis_gf_test.dart`
Expected: PASS (the service already accepts gfLow/gfHigh in constructor)

**Step 3: Update provider/caller to pass dive-specific GF**

Find where `ProfileAnalysisService` is instantiated. Update it to use the dive's GF when available:

```dart
// When creating the service for a specific dive:
final gfLow = dive.gradientFactorLow != null
    ? dive.gradientFactorLow! / 100.0
    : defaultGfLow;
final gfHigh = dive.gradientFactorHigh != null
    ? dive.gradientFactorHigh! / 100.0
    : defaultGfHigh;

final analysisService = ProfileAnalysisService(
  gfLow: gfLow,
  gfHigh: gfHigh,
);
```text
**Step 4: Commit**

```bash
git add lib/features/dive_log/ test/features/dive_log/
git commit -m "feat: use dive-specific gradient factors in profile analysis"
```text
---

### Task 16: Prefer computer-reported deco data on chart

**Files:**

- Find the widget/provider that feeds data to `DiveProfileChart`
- This is where `ProfileAnalysis` results are passed as chart curves

**Step 1: Identify where chart data is assembled**

Search for where `DiveProfileChart(` is constructed with curves. Likely in:

- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` or
- `lib/features/dive_log/presentation/widgets/dive_profile_section.dart`

**Step 2: Add logic to prefer computer-reported data**

When building chart curves, check if the dive's profile points have computer-reported NDL/ceiling data:

```dart
// Check if profile has computer-reported deco data
final hasComputerDecoData = dive.profile.any((p) => p.ndl != null || p.ceiling != null);

List<int>? ndlCurve;
List<double>? ceilingCurve;

if (hasComputerDecoData) {
  // Use computer-reported values
  ndlCurve = dive.profile.map((p) => p.ndl ?? -1).toList();
  ceilingCurve = dive.profile.map((p) => p.ceiling ?? 0.0).toList();
} else {
  // Fall back to calculated values from ProfileAnalysis
  ndlCurve = analysis?.ndlCurve;
  ceilingCurve = analysis?.ceilingCurve;
}
```text
Apply same pattern for TTS, CNS, ppO2 curves.

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/
git commit -m "feat: prefer computer-reported deco data on dive profile chart"
```text
---

## Phase 9: Chart Event Display

### Task 17: Implement event marker rendering on dive profile chart

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

**Step 1: Identify the _buildEventLines() method**

This method currently returns an empty list (~line 2484). Replace it with actual event marker implementation.

**Step 2: Implement event markers as vertical lines with tooltips**

```dart
List<VerticalLine> _buildEventLines(ColorScheme colorScheme) {
  if (widget.events == null || widget.events!.isEmpty) return [];

  return widget.events!.map((event) {
    Color color;
    double strokeWidth;
    List<double> dashArray;

    switch (event.severity) {
      case EventSeverity.alert:
        color = Colors.red.withValues(alpha: 0.7);
        strokeWidth = 2.0;
        dashArray = [4, 4];
        break;
      case EventSeverity.warning:
        color = Colors.orange.withValues(alpha: 0.6);
        strokeWidth = 1.5;
        dashArray = [4, 4];
        break;
      case EventSeverity.info:
      default:
        color = colorScheme.outline.withValues(alpha: 0.4);
        strokeWidth = 1.0;
        dashArray = [2, 4];
        break;
    }

    return VerticalLine(
      x: event.timestamp.toDouble(),
      color: color,
      strokeWidth: strokeWidth,
      dashArray: dashArray,
      label: VerticalLineLabel(
        show: true,
        alignment: Alignment.topRight,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
        labelResolver: (_) => event.displayName,
      ),
    );
  }).toList();
}
```text
**Step 3: Update ExtraLinesData to use vertical lines (not horizontal)**

Find the `extraLinesData` in the chart build method and change from horizontal to vertical:

```dart
extraLinesData: ExtraLinesData(
  verticalLines: _showEvents && widget.events != null
      ? _buildEventLines(colorScheme)
      : [],
),
```text
**Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart
git commit -m "feat: render dive computer events as vertical markers on profile chart"
```text
---

### Task 18: Load events from database and pass to chart

**Files:**

- Modify: repository to load events for a dive
- Modify: provider/widget that builds the chart to include events

**Step 1: Find or create method to load events for a dive**

In `dive_repository_impl.dart`, search for existing event loading method. If none exists, add:

```dart
Future<List<ProfileEvent>> getEventsForDive(String diveId) async {
  final rows = await (_db.select(_db.diveProfileEvents)
        ..where((e) => e.diveId.equals(diveId))
        ..orderBy([(e) => OrderingTerm.asc(e.timestamp)]))
      .get();

  return rows.map((row) => ProfileEvent(
    id: row.id,
    diveId: row.diveId,
    timestamp: row.timestamp,
    eventType: ProfileEventType.values.firstWhere(
      (t) => t.name == row.eventType,
      orElse: () => ProfileEventType.note,
    ),
    severity: EventSeverity.values.firstWhere(
      (s) => s.name == row.severity,
      orElse: () => EventSeverity.info,
    ),
    description: row.description,
    depth: row.depth,
    value: row.value,
    tankId: row.tankId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  )).toList();
}
```text
**Step 2: Wire events into the chart widget**

In the dive detail page or profile section, load events and pass to chart:

```dart
final events = await ref.read(diveRepositoryProvider).getEventsForDive(dive.id);

DiveProfileChart(
  profile: dive.profile,
  // ... existing params ...
  events: events,
  showEvents: true,
)
```text
**Step 3: Commit**

```bash
git add lib/features/dive_log/
git commit -m "feat: load dive computer events from database and display on chart"
```diff
---

## Phase 10: Verification and Cleanup

### Task 19: Run full test suite and fix issues

**Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

**Step 3: Format code**

Run: `dart format lib/ test/`

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test failures and analyzer issues from GF/events feature"
```

---

### Task 20: Manual verification with dive computer

**Step 1: Connect a dive computer and download dives**

Verify:

- Gradient factors appear in dive details
- Events show as markers on the profile chart
- NDL/ceiling curves from computer display correctly
- No regressions in existing download flow

**Step 2: Verify with a dive computer that reports GF (e.g., Shearwater)**

Check that:

- `decoAlgorithm` = "buhlmann"
- `gfLow` and `gfHigh` are populated with the computer's settings
- Profile analysis uses the computer's GF values

---

## File Summary

### Files to Create

| File | Purpose |
|------|---------|
| `test/features/dive_computer/domain/entities/downloaded_dive_test.dart` | Tests for extended DownloadedDive |
| `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart` | Tests for mapper with new fields |
| `test/features/dive_log/domain/entities/dive_profile_point_test.dart` | Tests for DiveProfilePoint deco fields |
| `test/features/dive_log/data/services/profile_analysis_gf_test.dart` | Tests for GF override |

### Files to Modify

| File | Changes |
|------|---------|
| `packages/.../libdc_wrapper.h` | Extend C structs |
| `packages/.../libdc_download.c` | Capture all sample types + DECOMODEL |
| `packages/.../DiveComputerHostApiImpl.swift` | Map new C fields to Pigeon |
| `packages/.../pigeons/dive_computer_api.dart` | Extend Pigeon API messages |
| `packages/.../lib/src/generated/dive_computer_api.g.dart` | Auto-generated |
| `packages/.../macos/Classes/DiveComputerApi.g.swift` | Auto-generated |
| `lib/features/dive_computer/domain/entities/downloaded_dive.dart` | Add events, deco model |
| `lib/features/dive_computer/data/services/parsed_dive_mapper.dart` | Map new fields |
| `lib/core/database/database.dart` | Schema v40, new columns |
| `lib/core/database/database.g.dart` | Auto-generated |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Persist new fields |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Read new fields |
| `lib/features/dive_log/domain/entities/dive.dart` | Add deco fields to entities |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | Use dive GF |
| `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` | Event markers |
| Import caller files (dive_import_service, download_notifier) | Pass new data |
| Chart assembly files (dive detail page or profile section) | Prefer computer data |
