# Slice C.3 Discovery Findings — UDDF Event Parity

Date: 2026-04-17
Branch: feat/ssrf-slice-c3

---

## Exporter Field Coverage

File: `lib/core/services/export/uddf/uddf_export_builders.dart`

The `profileevents` builder block runs at lines 742–787. Inside each `<event>` element
the exporter writes:

| XML element   | Source expression          | Line | Conditional? |
|---------------|----------------------------|------|--------------|
| `time`        | `event.timestamp.toString()` | 752  | No (always)  |
| `eventtype`   | `event.eventType.name`     | 755  | No (always)  |
| `severity`    | `event.severity.name`      | 759  | No (always)  |
| `depth`       | `event.depth.toString()`   | 761  | Yes (non-null)|
| `value`       | `event.value.toString()`   | 766  | Yes (non-null)|
| `description` | `event.description`        | 772  | Yes (non-null)|
| `tankref`     | `event.tankId`             | 779  | Yes (non-null)|

All seven fields the plan claims are present. No silent drops.

**Match verdict: YES — exporter writes every field the plan's pre-findings enumerate.**

---

## `buildDiveElement` Signature

File: `lib/core/services/export/uddf/uddf_export_builders.dart`, line 93.

```dart
static void buildDiveElement(
  XmlBuilder builder,
  Dive dive,
  List<Buddy>? buddies,
  List<BuddyWithRole> diveBuddyList,
  List<Tag> diveTags,
  List<ProfileEvent> profileEvents,
  List<DiveWeight> diveWeights,
  List<Trip>? trips,
  List<GasSwitchWithTank> gasSwitches, {
  Map<String, List<TankPressurePoint>>? tankPressures,
})
```

Parameter breakdown:

| # | Name | Type | Required? | Default |
|---|------|------|-----------|---------|
| 1 | `builder` | `XmlBuilder` | Yes | — |
| 2 | `dive` | `Dive` | Yes | — |
| 3 | `buddies` | `List<Buddy>?` | Yes (nullable) | — |
| 4 | `diveBuddyList` | `List<BuddyWithRole>` | Yes | — |
| 5 | `diveTags` | `List<Tag>` | Yes | — |
| 6 | `profileEvents` | `List<ProfileEvent>` | Yes | — |
| 7 | `diveWeights` | `List<DiveWeight>` | Yes | — |
| 8 | `trips` | `List<Trip>?` | Yes (nullable) | — |
| 9 | `gasSwitches` | `List<GasSwitchWithTank>` | Yes | — |
| 10 | `tankPressures` | `Map<String, List<TankPressurePoint>>?` | No (named) | `null` |

`profileEvents` is positional parameter #6 — not a named parameter. The round-trip
test must pass it as a positional argument, not `profileEvents: events`.

For the round-trip test, all non-nullable list parameters can be passed as `const []`
except `profileEvents` (which carries the test events) and `buddies`/`trips` (nullable,
pass `null`).

---

## Import Service Public API

File: `lib/core/services/export/uddf/uddf_full_import_service.dart`, line 21.

```dart
Future<UddfImportResult> importAllDataFromUddf(String uddfContent) async
```

- Accepts raw UDDF XML as a `String`.
- Returns `UddfImportResult` (has `.dives` as `List<Map<String, dynamic>>`).
- Parsed events land in `diveData['profileEvents']` at line 872 — the key Task 2
  renames to `'events'` for SSRF/UDDF consumer parity.
- No bytes variant — test passes a `String` directly.

---

## Test Helper Availability

An extensive test file exists at:
`test/core/services/export/uddf/uddf_export_builders_test.dart`

It shows the exact call pattern for `buildDiveElement` with a bare `XmlBuilder`:

```dart
final builder = XmlBuilder();
builder.element('root', nest: () {
  UddfExportBuilders.buildDiveElement(
    builder,
    dive,
    null,        // buddies
    const [],    // diveBuddyList
    const [],    // diveTags
    const [],    // profileEvents
    const [],    // diveWeights
    null,        // trips
    const [],    // gasSwitches
  );
});
final xml = builder.buildDocument().toXmlString();
```

The `UddfFullImportService` is exercised via direct instantiation in
`test/core/services/export/uddf/uddf_macdive_import_test.dart`:

```dart
late UddfFullImportService service;
setUp(() { service = UddfFullImportService(); });
final result = await service.importAllDataFromUddf(_macDiveUddf);
```

**Task 4 can reuse both patterns directly** — no new scaffold needed.

For a valid UDDF document the importer requires a `<uddf>` root element and will
throw `FormatException` otherwise. The round-trip test must wrap the export output
in at minimum:

```xml
<?xml version="1.0"?>
<uddf>
  <profiledata>
    <repetitiongroup id="rg1">
      <!-- UddfExportBuilders.buildDiveElement output here -->
    </repetitiongroup>
  </profiledata>
</uddf>
```

---

## Surprises

1. **`profileEvents` is positional, not named.** The plan's pseudocode shows
   `profileEvents: sourceEvents` (named). The real signature is positional.
   Task 4 must use positional call order (see signature above).

2. **`diveData['profileEvents']` key mismatch confirmed at line 872.** The importer
   stores parsed events under `'profileEvents'`; `_importDives` reads `'events'`
   (line 1244). Task 2's rename is necessary and sufficient.

3. **`tankRef` map key is camelCase.** The importer writes `event['tankRef']` (capital R),
   consistent with how `gasSwitches` consumes `gs['tankRef']` at line 1211.
   This is not consumed by the profile-events path in `_importDives` today (tankRef
   consumption for profile events is out of scope per plan). No action needed.

4. **No divergence from plan pre-findings on field coverage.** All seven fields
   (time, eventtype, severity, depth, value, description, tankref) confirmed written
   by exporter and read by importer.
