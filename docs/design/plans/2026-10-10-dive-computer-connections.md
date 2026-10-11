# Dive Computer Connections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One `dive_computers` record per physical device whichever path it
arrives by, with a synced list of the connections (BLE, Bluetooth Classic,
USB, infrared, file format, cloud provider) it has been downloaded through,
and each device remembering its own transport and address.

**Architecture:** A pure serial-identity module gives every matcher one
definition of "same serial" (Shearwater hex equals its decimal), and the
download/cloud matchers accept a blank manufacturer or model. A new synced
child table `dive_computer_connections` (deterministic v5 ids, device-local
`address` and `local_last_used_at`) is written by every download/import path,
seeded from existing data by a local-only `beforeOpen` heal, folded by merge,
and read by the saved-computer download route and a new Connections card.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_test, ARB l10n.

**Spec:** `docs/design/specs/2026-10-10-dive-computer-connections-design.md`

## Global Constraints

- No em-dashes or en-dashes as prose punctuation anywhere (code, comments, docs, commits).
- No AI-tool attribution of any kind in committed text, commits or PR text.
- Shearwater serials are stored as 8-character UPPERCASE hex.
- The serial rewrite and the connection seed are local-only: no HLC bump, no `markRecordPending`, no `updated_at` change.
- Connection ids: `Uuid().v5(kDiveComputerConnectionNamespace, '<computerId>|<kind>|<detail or empty>')`, namespace `7bd854b9-1e72-422b-8f8e-784bd64924b7` (frozen).
- `dive_computer_connections` has NO unique index (replicated table).
- Device-local wire keys: `address`, `localLastUsedAt` on entity type `diveComputerConnections`.
- Legacy `dive_computers.connection_type` / `bluetooth_address` keep being written as a mirror of the last direct connection.
- Kind wire values: `ble`, `bluetoothClassic`, `usb`, `infrared`, `file`, `cloud`. The spec's `serial` kind folds into `usb`: the app's `DeviceConnectionType` has no serial value and USB serial downloads already arrive as `usb`.
- Cloud details: `garminConnect`, `suuntoCloud`. File details: `ImportFormat.name` (e.g. `fit`, `shearwaterDb`, `uddf`, `macdiveXml`).
- New l10n keys in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh); hu stays ASCII-only. ARB files are feature-grouped: insert next to a neighbouring `diveComputer_` key, never at the end.
- Files: 800 lines max. New UI goes in new widget files; do not grow `device_detail_page.dart` (already 1,083 lines).
- Paths in tests via `p.join` / `Directory.systemTemp`; tests restore any global state they replace.
- After each task: `dart format .`, `flutter analyze` (0 issues), the task's tests. After any new `lib/` file: `flutter test test/architecture/ test/shared/`.

## Review Focus

1. **Another computer answers a saved-computer download** (#1423 same-model fallback picks a second Perdix): the reported serial disagrees with the stored one, so no connection may be recorded or rebound for this record. Test in Task 9.
2. **All-digit Shearwater filename serial** (`12345678` is hex) must never be converted by the heal; only download-provenance rows are. Test in Task 5.
3. **A computer downloaded only on another device**: connection rows exist but none has a local address, so the saved download shows the "no direct download" view instead of connecting to a stale legacy address. Test in Task 11.
4. **Sync round trip keeps this device's address**: an inbound connection row from a peer must not blank `address` / `local_last_used_at`. Test in Task 6.
5. **Merging two records that both have `(ble)`**: the fold must produce one survivor row (not a v5 collision insert error) with the max timestamps and the local address. Test in Task 10.

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/core/database/computer_serial_identity.dart` | Pure: Shearwater family detection, serial match keys, serial comparison, canonical download serial |
| Modify `lib/core/database/imported_computer_identity.dart` | `matchImportedComputer` uses the shared serial rule, takes optional `manufacturer` |
| Modify `lib/core/database/dive_computer_gear_identity.dart` | `matchGearTwin` serial tier uses the shared rule |
| Modify `lib/features/dive_computer/domain/services/dive_computer_merge_rules.dart` | duplicate detection and conflict check use the shared rule and name agreement |
| Modify `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | `findByHardwareIdentity` nullable manufacturer/model, shared rule; pass manufacturer to import match; `deleteComputer` tombstones connections |
| Create `lib/core/database/shearwater_serial_heal.dart` | beforeOpen local-only rewrite of download-provenance Shearwater serials to hex |
| Create `lib/core/database/tables/dive_computer_connection_tables.dart` | Drift table `DiveComputerConnections` |
| Create `lib/features/dive_computer/domain/entities/dive_computer_connection.dart` | Entity, `DiveComputerConnectionKind`, id derivation |
| Create `lib/features/dive_computer/data/repositories/dive_computer_connection_repository.dart` | record, watch, local-address lookup, fold, delete |
| Create `lib/core/database/dive_computer_connection_seed.dart` | beforeOpen local-only seeding from existing data |
| Create `lib/features/dive_computer/domain/services/download_connection_selection.dart` | Pure: pick the connection for a saved download and build the computer view |
| Create `lib/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart` | Repository + per-computer + all-connections providers |
| Create `lib/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart` | Connections card |
| Create `lib/features/dive_computer/presentation/utils/connection_presentation.dart` | Icon + label for a connection (shared by card, list, merge sheet) |
| Modify download, adapters, importers, router, detail/list pages, merge sheet/repository, sync files, ARB files | wiring |

---

### Task 1: Shared serial identity module

**Files:**
- Create: `lib/core/database/computer_serial_identity.dart`
- Test: `test/core/database/computer_serial_identity_test.dart`

**Interfaces:**
- Produces:
  - `bool isShearwaterFamily({String? manufacturer, String? model})`
  - `Set<String> serialMatchKeys(String? serial, {required bool shearwater})`
  - `bool computerSerialsMatch(String? a, String? b, {required bool shearwater})`
  - `bool shearwaterPair({String? manufacturerA, String? modelA, String? manufacturerB, String? modelB})`
  - `String? canonicalDownloadedSerial({String? vendor, String? product, String? serial})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';

void main() {
  group('isShearwaterFamily', () {
    test('manufacturer Shearwater', () {
      expect(isShearwaterFamily(manufacturer: ' shearwater '), isTrue);
    });
    test('model alone, with or without the brand prefix', () {
      expect(isShearwaterFamily(model: 'Perdix 2'), isTrue);
      expect(isShearwaterFamily(model: 'Shearwater Teric'), isTrue);
      expect(isShearwaterFamily(model: 'NERD 2'), isTrue);
      expect(isShearwaterFamily(model: 'Peregrine TX'), isTrue);
    });
    test('other brands are not', () {
      expect(isShearwaterFamily(manufacturer: 'Garmin', model: 'Descent Mk3'),
          isFalse);
      expect(isShearwaterFamily(model: 'Petrelli 9'), isFalse);
      expect(isShearwaterFamily(), isFalse);
    });
  });

  group('computerSerialsMatch', () {
    test('Shearwater hex equals its decimal both ways', () {
      // 0xA1B2C3D4 == 2712847316
      expect(computerSerialsMatch('A1B2C3D4', '2712847316', shearwater: true),
          isTrue);
      expect(computerSerialsMatch('2712847316', 'a1b2c3d4', shearwater: true),
          isTrue);
    });
    test('hex with leading zeros', () {
      // 0x00BC614E == 12345678
      expect(computerSerialsMatch('00BC614E', '12345678', shearwater: true),
          isTrue);
    });
    test('different Shearwater serials do not match', () {
      expect(computerSerialsMatch('A1B2C3D4', '2712847317', shearwater: true),
          isFalse);
    });
    test('non-Shearwater serials compare as text only', () {
      expect(computerSerialsMatch('00BC614E', '12345678', shearwater: false),
          isFalse);
      expect(computerSerialsMatch(' ab 12 ', 'AB 12', shearwater: false),
          isTrue);
    });
    test('blank never matches', () {
      expect(computerSerialsMatch('', '', shearwater: true), isFalse);
      expect(computerSerialsMatch(null, '1', shearwater: false), isFalse);
    });
    test('decimal above 32 bits gets no hex key', () {
      expect(serialMatchKeys('4294967296', shearwater: true), {'4294967296'});
    });
  });

  group('shearwaterPair', () {
    test('true when either side is Shearwater', () {
      expect(shearwaterPair(modelA: 'Perdix 2', manufacturerB: 'Shearwater'),
          isTrue);
      expect(shearwaterPair(modelA: 'Perdix 2'), isTrue);
      expect(shearwaterPair(modelA: 'D5', manufacturerB: 'Suunto'), isFalse);
    });
  });

  group('canonicalDownloadedSerial', () {
    test('Shearwater decimal becomes 8-char uppercase hex', () {
      expect(
        canonicalDownloadedSerial(
            vendor: 'Shearwater', product: 'Perdix 2', serial: '2712847316'),
        'A1B2C3D4',
      );
      expect(
        canonicalDownloadedSerial(
            vendor: 'Shearwater', product: 'Petrel 3', serial: '12345678'),
        '00BC614E',
      );
    });
    test('other vendors pass through trimmed', () {
      expect(
        canonicalDownloadedSerial(vendor: 'Ratio', product: 'iX3M 2', serial: ' 74691 '),
        '74691',
      );
    });
    test('blank is null; non-numeric Shearwater is uppercased', () {
      expect(canonicalDownloadedSerial(vendor: 'Shearwater', serial: '  '), isNull);
      expect(canonicalDownloadedSerial(vendor: 'Shearwater', serial: 'a1b2c3d4'),
          'A1B2C3D4');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/computer_serial_identity_test.dart`
Expected: FAIL, `computer_serial_identity.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/database/imported_computer_identity.dart';

/// One definition of "these two serials name the same dive computer"
/// (issue #3106), shared by every matcher: file imports, downloads, cloud
/// imports, duplicate detection and the gear twin.
///
/// Shearwater is the one family whose serial reaches Submersion in two
/// radixes. The computer stores it as eight ASCII hex characters; a
/// Shearwater Cloud export keeps that text in the log filename, while
/// libdivecomputer hex-decodes it into a uint32 that every platform bridge
/// prints in decimal. So for a Shearwater, `A1B2C3D4` and `2712847316` are
/// the same serial.

const Set<String> _shearwaterModelRoots = {
  'perdix',
  'petrel',
  'predator',
  'teric',
  'peregrine',
  'tern',
  'nerd',
};

final RegExp _hex8 = RegExp(r'^[0-9a-f]{8}$');
final RegExp _digits = RegExp(r'^\d{1,10}$');
const int _maxUint32 = 0xFFFFFFFF;

/// Whether [manufacturer] / [model] name a Shearwater computer. A file import
/// often has no manufacturer, so the model alone (with or without a leading
/// "Shearwater") is enough.
bool isShearwaterFamily({String? manufacturer, String? model}) {
  if (normalizeComputerIdentityPart(manufacturer) == 'shearwater') return true;
  var m = normalizeComputerIdentityPart(model);
  if (m.startsWith('shearwater ')) m = m.substring('shearwater '.length);
  if (m.isEmpty) return false;
  return _shearwaterModelRoots.contains(m.split(' ').first);
}

/// Whether either side of a comparison is a Shearwater, which is when the
/// hex/decimal equivalence applies.
bool shearwaterPair({
  String? manufacturerA,
  String? modelA,
  String? manufacturerB,
  String? modelB,
}) =>
    isShearwaterFamily(manufacturer: manufacturerA, model: modelA) ||
    isShearwaterFamily(manufacturer: manufacturerB, model: modelB);

/// The normalized forms [serial] can be compared under. Empty for a blank
/// serial, which matches nothing.
Set<String> serialMatchKeys(String? serial, {required bool shearwater}) {
  final normalized = normalizeComputerIdentityPart(serial);
  if (normalized.isEmpty) return const {};
  final keys = {normalized};
  if (!shearwater) return keys;
  if (_hex8.hasMatch(normalized)) {
    keys.add(int.parse(normalized, radix: 16).toString());
  }
  if (_digits.hasMatch(normalized)) {
    final value = int.parse(normalized);
    if (value <= _maxUint32) {
      keys.add(value.toRadixString(16).padLeft(8, '0'));
    }
  }
  return keys;
}

/// Whether [a] and [b] are the same serial. Blank never matches.
bool computerSerialsMatch(String? a, String? b, {required bool shearwater}) {
  final left = serialMatchKeys(a, shearwater: shearwater);
  if (left.isEmpty) return false;
  return serialMatchKeys(b, shearwater: shearwater).any(left.contains);
}

/// The serial to store for a download that libdivecomputer reported as
/// [serial] for [vendor] / [product]: trimmed, and for a Shearwater the
/// 8-character uppercase hex the computer itself shows. Null when blank.
String? canonicalDownloadedSerial({
  String? vendor,
  String? product,
  String? serial,
}) {
  final trimmed = serial?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (!isShearwaterFamily(manufacturer: vendor, model: product)) return trimmed;
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed.toUpperCase();
  final value = int.tryParse(trimmed);
  if (value == null || value > _maxUint32) return trimmed;
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/database/computer_serial_identity_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, guards, commit**

```bash
dart format lib/core/database/computer_serial_identity.dart test/core/database/computer_serial_identity_test.dart
flutter analyze
flutter test test/architecture/ test/shared/
git add lib/core/database/computer_serial_identity.dart test/core/database/computer_serial_identity_test.dart
git commit -m "feat(dive-computer): one serial identity rule with Shearwater hex and decimal"
```

---

### Task 2: Matchers use the shared rule and accept a blank manufacturer

**Files:**
- Modify: `lib/core/database/imported_computer_identity.dart` (`matchImportedComputer`)
- Modify: `lib/core/database/dive_computer_gear_identity.dart` (`matchGearTwin` serial tier)
- Modify: `lib/features/dive_computer/domain/services/dive_computer_merge_rules.dart` (`duplicateCandidatesFor`, `serialNumbersConflict`)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`findByHardwareIdentity`, `findOrRegisterImportedComputer`)
- Modify callers of `findByHardwareIdentity`: `dive_computer_adapter.dart`, `garmin_cloud_adapter.dart`, `suunto_dive_import_core.dart` (signature becomes nullable; they keep passing values)
- Test: `test/core/database/imported_computer_identity_test.dart` (extend), `test/core/database/dive_computer_gear_identity_test.dart` (extend), `test/features/dive_computer/domain/services/dive_computer_merge_rules_test.dart` (extend), `test/features/dive_log/data/repositories/dive_computer_hardware_identity_test.dart` (create)

Find the existing test files first: `ls test/core/database/ | grep -i computer; find test -name "dive_computer_merge_rules_test.dart"`. Extend existing files where they exist; create where they do not.

**Interfaces:**
- Consumes: Task 1 `computerSerialsMatch`, `shearwaterPair`.
- Produces:
  - `matchImportedComputer({required String model, String? manufacturer, String? serialNumber, String? diverId, required Iterable<ImportedComputerCandidate> candidates})`
  - `Future<DiveComputer?> findByHardwareIdentity({String? manufacturer, String? model, required String serialNumber, String? diverId})`
  - `bool identityPartsCompatible(String? a, String? b)` and `bool computerModelsCompatible({String? brandA, String? modelA, String? brandB, String? modelB})` exported from `dive_computer_merge_rules.dart` (used by the repository too).

- [ ] **Step 1: Write failing tests**

Add to the merge rules test (build `DiveComputer` with the file's existing helper, or this one if none):

```dart
DiveComputer dc(String id, {String? manufacturer, String? model, String? serial, String diver = 'd1'}) =>
    DiveComputer(
      id: id,
      diverId: diver,
      name: id,
      manufacturer: manufacturer,
      model: model,
      serialNumber: serial,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

group('issue #3106 duplicate cases', () {
  test('Shearwater file (hex, no manufacturer) vs BLE (decimal)', () {
    final file = dc('file', model: 'Perdix 2', serial: 'A1B2C3D4');
    final ble = dc('ble', manufacturer: 'Shearwater', model: 'Perdix 2', serial: '2712847316');
    expect(duplicateCandidatesFor(ble, [file, ble]).map((c) => c.id), ['file']);
    expect(duplicateCandidatesFor(file, [file, ble]).map((c) => c.id), ['ble']);
    expect(serialNumbersConflict([file, ble]), isFalse);
  });
  test('Garmin FIT (no manufacturer) vs Connect', () {
    final fit = dc('fit', model: 'Descent Mk3', serial: '3412345678');
    final cloud = dc('cloud', manufacturer: 'Garmin', model: 'Descent Mk3', serial: '3412345678');
    expect(duplicateCandidatesFor(cloud, [fit, cloud]).map((c) => c.id), ['fit']);
  });
  test('brand folded into the model still agrees', () {
    final file = dc('file', model: 'Shearwater Teric', serial: '0A0B0C0D');
    final ble = dc('ble', manufacturer: 'Shearwater', model: 'Teric', serial: '168496141');
    expect(duplicateCandidatesFor(ble, [file, ble]).map((c) => c.id), ['file']);
  });
  test('two different Shearwater serials still conflict', () {
    final a = dc('a', manufacturer: 'Shearwater', model: 'Perdix 2', serial: 'A1B2C3D4');
    final b = dc('b', manufacturer: 'Shearwater', model: 'Perdix 2', serial: '2712847317');
    expect(serialNumbersConflict([a, b]), isTrue);
  });
});
```

Add to the imported identity test:

```dart
test('a hex file serial adopts the decimal BLE row (#3106)', () {
  final match = matchImportedComputer(
    model: 'Perdix 2',
    serialNumber: 'A1B2C3D4',
    diverId: 'd1',
    candidates: const [
      ImportedComputerCandidate(
        id: 'ble', diverId: 'd1', manufacturer: 'Shearwater',
        model: 'Perdix 2', serialNumber: '2712847316'),
    ],
  );
  expect(match?.id, 'ble');
});
test('decimal equivalence does not apply outside Shearwater', () {
  final match = matchImportedComputer(
    model: 'D5',
    manufacturer: 'Suunto',
    serialNumber: '00BC614E',
    candidates: const [
      ImportedComputerCandidate(id: 'x', model: 'D5', serialNumber: '12345678'),
    ],
  );
  expect(match, isNull);
});
```

Add to the gear identity test:

```dart
test('serial tier treats Shearwater hex and decimal as one (#3106)', () {
  final twin = matchGearTwin(
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: 'A1B2C3D4',
    diverId: 'd1',
    candidates: [
      GearTwinCandidate(id: 'g1', diverId: 'd1', brand: 'Shearwater', model: 'Perdix 2', serialNumber: '2712847316'),
    ],
  );
  expect(twin?.id, 'g1');
});
```

(Check `GearTwinCandidate`'s constructor in `dive_computer_gear_identity.dart` and match its named parameters exactly.)

Create `test/features/dive_log/data/repositories/dive_computer_hardware_identity_test.dart`, using the in-memory DB helper the sibling repository tests use (copy the `setUp`/`tearDown` from `test/features/dive_log/data/repositories/dive_computer_repository_*_test.dart`; insert the diver row first, `dive_computers.diver_id` is a real FK):

```dart
test('FIT row without manufacturer is found by the Garmin cloud lookup', () async {
  await repo.createComputer(computer(id: 'fit', manufacturer: null, model: 'Descent Mk3', serial: '3412345678'));
  final found = await repo.findByHardwareIdentity(
    manufacturer: 'Garmin', model: 'Descent Mk3', serialNumber: '3412345678', diverId: 'd1');
  expect(found?.id, 'fit');
});
test('Shearwater file row is found by a hex BLE serial, case-insensitively', () async {
  await repo.createComputer(computer(id: 'file', manufacturer: null, model: 'Perdix 2', serial: 'a1b2c3d4'));
  final found = await repo.findByHardwareIdentity(
    manufacturer: 'Shearwater', model: 'Perdix 2', serialNumber: 'A1B2C3D4', diverId: 'd1');
  expect(found?.id, 'file');
});
test('a different non-blank manufacturer still misses', () async {
  await repo.createComputer(computer(id: 'x', manufacturer: 'Suunto', model: 'Descent Mk3', serial: '3412345678'));
  final found = await repo.findByHardwareIdentity(
    manufacturer: 'Garmin', model: 'Descent Mk3', serialNumber: '3412345678', diverId: 'd1');
  expect(found, isNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/ test/features/dive_computer/domain/services/ test/features/dive_log/data/repositories/dive_computer_hardware_identity_test.dart`
Expected: the new cases FAIL.

- [ ] **Step 3: Implement**

In `dive_computer_merge_rules.dart`, add the import `package:submersion/core/database/computer_serial_identity.dart` and `package:submersion/core/database/dive_computer_gear_identity.dart`, then replace `duplicateCandidatesFor`, `_compatible` and `serialNumbersConflict` with:

```dart
List<DiveComputer> duplicateCandidatesFor(
  DiveComputer target,
  Iterable<DiveComputer> all,
) {
  if (normalizeComputerIdentityPart(target.serialNumber).isEmpty) {
    return const [];
  }
  final diver = normalizeComputerIdentityPart(target.diverId);
  return [
    for (final candidate in all)
      if (candidate.id != target.id &&
          normalizeComputerIdentityPart(candidate.diverId) == diver &&
          identityPartsCompatible(target.manufacturer, candidate.manufacturer) &&
          computerModelsCompatible(
            brandA: target.manufacturer,
            modelA: target.model,
            brandB: candidate.manufacturer,
            modelB: candidate.model,
          ) &&
          _sameSerial(target, candidate))
        candidate,
  ];
}

bool _sameSerial(DiveComputer a, DiveComputer b) => computerSerialsMatch(
  a.serialNumber,
  b.serialNumber,
  shearwater: shearwaterPair(
    manufacturerA: a.manufacturer,
    modelA: a.model,
    manufacturerB: b.manufacturer,
    modelB: b.model,
  ),
);

/// Two identity fragments agree after normalisation, or either is blank.
bool identityPartsCompatible(String? a, String? b) {
  final left = normalizeComputerIdentityPart(a);
  final right = normalizeComputerIdentityPart(b);
  return left.isEmpty || right.isEmpty || left == right;
}

/// Two models are compatible when either is blank, or when the two
/// brand + model pairs name the same device however each source split the
/// name ("Shearwater Teric" vs "Shearwater" + "Teric").
bool computerModelsCompatible({
  String? brandA,
  String? modelA,
  String? brandB,
  String? modelB,
}) {
  if (normalizeComputerIdentityPart(modelA).isEmpty ||
      normalizeComputerIdentityPart(modelB).isEmpty) {
    return true;
  }
  return computerNamesAgree(
    brandA: brandA,
    modelA: modelA,
    brandB: brandB,
    modelB: modelB,
  );
}

bool serialNumbersConflict(Iterable<DiveComputer> records) {
  final withSerial = [
    for (final record in records)
      if (normalizeComputerIdentityPart(record.serialNumber).isNotEmpty) record,
  ];
  for (var i = 0; i < withSerial.length; i++) {
    for (var j = i + 1; j < withSerial.length; j++) {
      if (!_sameSerial(withSerial[i], withSerial[j])) return true;
    }
  }
  return false;
}
```

Keep the doc comments above each, updated to mention the shared rule (#3106).

In `imported_computer_identity.dart`, add `String? manufacturer,` to `matchImportedComputer`, import `computer_serial_identity.dart`, and replace the serial tier:

```dart
    if (normalizedSerial.isNotEmpty) {
      final shearwater = shearwaterPair(
        manufacturerA: manufacturer,
        modelA: model,
        manufacturerB: candidate.manufacturer,
        modelB: candidate.model,
      );
      if (computerSerialsMatch(
        serialNumber,
        candidate.serialNumber,
        shearwater: shearwater,
      )) {
        return candidate;
      }
      continue;
    }
```

(`computer_serial_identity.dart` imports `imported_computer_identity.dart` for `normalizeComputerIdentityPart`; a mutual import between the two library files is legal Dart. If the analyzer or an architecture guard objects, move `normalizeComputerIdentityPart` into `computer_serial_identity.dart` and re-export it from `imported_computer_identity.dart` with `export 'computer_serial_identity.dart' show normalizeComputerIdentityPart;`.)

Leave `importedDiveComputerId` unchanged: its key lowercases the serial, so uppercase hex from Task 4 derives the same id as before.

In `dive_computer_gear_identity.dart`, replace the serial tier of `matchGearTwin`:

```dart
  if (wantSerial.isNotEmpty) {
    return _single(
      sameDiver.where(
        (c) => computerSerialsMatch(
          serialNumber,
          c.serialNumber,
          shearwater: shearwaterPair(
            manufacturerA: manufacturer,
            modelA: model,
            manufacturerB: c.brand,
            modelB: c.model,
          ),
        ),
      ),
    );
  }
```

In `dive_computer_repository_impl.dart`, import `computer_serial_identity.dart` and `dive_computer_merge_rules.dart` (show `identityPartsCompatible, computerModelsCompatible`), and change `findByHardwareIdentity`:

```dart
  Future<domain.DiveComputer?> findByHardwareIdentity({
    String? manufacturer,
    String? model,
    required String serialNumber,
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      final normalizedDiverId = diverId?.trim();
      if (normalizedDiverId != null && normalizedDiverId.isNotEmpty) {
        query.where((t) => t.diverId.equals(normalizedDiverId));
      }

      // Matched in Dart: a stored value may carry whitespace or the other
      // Shearwater radix, and a file import may have left the manufacturer
      // or model blank (#3106). A blank side is compatible, a non-blank
      // pair must agree.
      final rows = await query.get();
      for (final row in rows) {
        if (!identityPartsCompatible(row.manufacturer, manufacturer)) continue;
        if (!computerModelsCompatible(
          brandA: row.manufacturer,
          modelA: row.model,
          brandB: manufacturer,
          modelB: model,
        )) {
          continue;
        }
        final shearwater = shearwaterPair(
          manufacturerA: row.manufacturer,
          modelA: row.model,
          manufacturerB: manufacturer,
          modelB: model,
        );
        if (computerSerialsMatch(
          row.serialNumber,
          serialNumber,
          shearwater: shearwater,
        )) {
          return _mapRowToComputer(row);
        }
      }
      return null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find dive computer by hardware identity',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `findOrRegisterImportedComputer`, pass `manufacturer: manufacturer,` to `matchImportedComputer`.

In `dive_computer_adapter.dart` `ensureComputer`, the guard currently requires manufacturer and model to be non-blank before the lookup. Relax it to require only the serial:

```dart
    if (normalizedSerial?.isNotEmpty == true) {
      var existing = await _computerRepository.findByHardwareIdentity(
        manufacturer: normalizedManufacturer,
        model: normalizedModel,
        serialNumber: normalizedSerial!,
        diverId: _diverId,
      );
```

and keep the #422 second lookup, passing `manufacturer: normalizedManufacturer`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/database/ test/features/dive_computer/ test/features/dive_log/data/repositories/ test/features/import_wizard/`
Expected: PASS (fix any existing test that asserted the old exact-manufacturer behaviour only if it encoded the bug; otherwise investigate).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A lib/core/database lib/features/dive_computer lib/features/dive_log/data/repositories lib/features/import_wizard test
git commit -m "feat(dive-computer): match computers across radix and blank manufacturer"
```

(Stage explicit paths; check `git status` first so no sibling-worktree file is swept in.)

---

### Task 3: Store Shearwater download serials as hex

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart` (completion handler, `_persistDeviceInfo`)
- Test: `test/features/dive_computer/presentation/providers/download_notifier_persist_test.dart` (find the existing `_persistDeviceInfo` tests: `grep -rln "persistDeviceInfo\|Rebinding" test/features/dive_computer`; extend that file)

**Interfaces:**
- Consumes: Task 1 `canonicalDownloadedSerial`, `computerSerialsMatch`, `shearwaterPair`.
- Produces: `DownloadState.serialNumber` is canonical (hex for Shearwater). `ensureComputer` and the import service then store hex in the computer, the dive snapshot and the data source, since they all read it from there.

- [ ] **Step 1: Write failing tests** (in the existing notifier test file, reusing its fake service that emits pigeon events)

```dart
test('a Shearwater decimal serial is stored and exposed as hex (#3106)', () async {
  // Arrange a saved Shearwater computer with no serial, start a download
  // with a device whose recognizedModel is Shearwater Perdix 2, then emit
  // DownloadCompleteEvent(serialNumber: '2712847316', ...).
  // Assert: notifier state.serialNumber == 'A1B2C3D4'
  // and the repository's updateComputer received serialNumber 'A1B2C3D4'.
});
test('a stored decimal and a reported hex are the same serial', () async {
  // Saved computer serialNumber '2712847316' (pre-heal row), reported '2712847316'
  // converts to 'A1B2C3D4'; assert updateComputer IS called (not refused as
  // "another computer answered") and stores 'A1B2C3D4'.
});
```

Write both as full tests with the file's existing arrange helpers; the comments above say exactly what each arranges and asserts.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test <that test file>`
Expected: FAIL (state holds `2712847316`).

- [ ] **Step 3: Implement**

In the `pigeon.DownloadCompleteEvent` case, canonicalize once and use it for both state and persistence:

```dart
        final model = _device?.recognizedModel;
        final canonicalSerial = canonicalDownloadedSerial(
          vendor: model?.manufacturer,
          product: reportedProduct ?? model?.model,
          serial: serialNumber,
        );
        state = state.copyWith(
          phase: DownloadPhase.complete,
          progress: DownloadProgress.complete(totalDives),
          serialNumber: canonicalSerial,
          ...
        );
        ...
        _persistDeviceInfo(canonicalSerial, firmwareVersion, reportedProduct);
```

In `_persistDeviceInfo`, replace `storedSerial != serialNumber` with the shared rule:

```dart
    if (storedSerial != null &&
        serialNumber != null &&
        !computerSerialsMatch(
          storedSerial,
          serialNumber,
          shearwater: shearwaterPair(
            manufacturerA: computer.manufacturer,
            modelA: computer.model,
            manufacturerB: _device?.recognizedModel?.manufacturer,
            modelB: _device?.recognizedModel?.model,
          ),
        )) {
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_computer/ test/features/import_wizard/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_computer/presentation/providers/download_providers.dart test/features/dive_computer
git commit -m "feat(dive-computer): store Shearwater download serials as hex"
```

---

### Task 4: File imports pass the manufacturer; Shearwater file serials uppercase

**Files:**
- Modify: `lib/features/dive_import/domain/entities/imported_dive.dart` (add `computerManufacturer`)
- Modify: `lib/features/dive_import/data/services/fit_parser_service.dart` (set it from `fileId.manufacturer`)
- Modify: `lib/features/universal_import/data/parsers/fit_import_parser.dart` (map it to `diveComputerManufacturer`)
- Modify: `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` (manufacturer + uppercase serial)
- Test: extend `test/features/dive_import/data/services/fit_parser_service_test.dart`, `test/features/universal_import/data/parsers/fit_import_parser_test.dart`, `test/features/universal_import/data/services/shearwater_dive_mapper_test.dart` (locate with `find test -name "*fit_parser*" -o -name "*shearwater_dive_mapper*"`)

**Interfaces:**
- Produces: `ImportedDive.computerManufacturer` (`String?`); `String? fitManufacturerName(int? id)` in `fit_parser_service.dart` (1 gives `Garmin`, 23 gives `Suunto`, else null).

- [ ] **Step 1: Write failing tests**

```dart
test('fitManufacturerName maps Garmin and Suunto', () {
  expect(fitManufacturerName(1), 'Garmin');
  expect(fitManufacturerName(23), 'Suunto');
  expect(fitManufacturerName(255), isNull);
  expect(fitManufacturerName(null), isNull);
});
```

In the FIT import parser test, a parsed dive with `computerManufacturer: 'Garmin'` produces `diveData['diveComputerManufacturer'] == 'Garmin'`.

In the Shearwater mapper test, a filename `Perdix 2[a1b2c3d4]#12 2024-1-1 10-00-00.swlogzp` yields `diveComputerSerial == 'A1B2C3D4'` and `diveComputerManufacturer == 'Shearwater'`.

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

`imported_dive.dart`: add `final String? computerManufacturer;`, the constructor parameter `this.computerManufacturer,` next to `computerModel`, and the field in `props` next to `computerModel`.

`fit_parser_service.dart`:

```dart
/// The manufacturer a FIT `file_id.manufacturer` code names, for the codes
/// whose dive computers Submersion imports. Null for any other code, which
/// leaves the computer's manufacturer blank as before (#3106).
String? fitManufacturerName(int? id) => switch (id) {
  1 => 'Garmin',
  23 => 'Suunto',
  _ => null,
};
```

and in the `ImportedDive(...)` construction: `computerManufacturer: fitManufacturerName(fileId?.manufacturer),`.

`fit_import_parser.dart`, next to the model mapping:

```dart
    if (dive.computerManufacturer != null) {
      diveData['diveComputerManufacturer'] = dive.computerManufacturer;
    }
```

`shearwater_dive_mapper.dart`:

```dart
      'diveComputerModel': filenameInfo.model,
      'diveComputerManufacturer': filenameInfo.model == null
          ? null
          : ShearwaterFilenameParser.vendorProduct(filenameInfo.model!)?.$1,
      'diveComputerSerial': filenameInfo.serial?.toUpperCase(),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_import/ test/features/universal_import/`
Expected: PASS. A golden or snapshot that pinned a lowercase serial or a missing manufacturer key is updated only after confirming it is this change.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_import lib/features/universal_import test/features/dive_import test/features/universal_import
git commit -m "feat(dive-import): record the computer manufacturer from FIT and Shearwater files"
```

---

### Task 5: Rewrite existing download-provenance Shearwater serials to hex

**Files:**
- Create: `lib/core/database/shearwater_serial_heal.dart`
- Modify: `lib/core/database/migrations/helpers/data_source_migrations.dart` (private wrapper + test hook, like `_backfillImportedDiveComputers`)
- Modify: `lib/core/database/migrations/before_open.dart` (call it immediately BEFORE `_backfillImportedDiveComputers()`)
- Test: `test/core/database/shearwater_serial_heal_test.dart`

**Interfaces:**
- Consumes: Task 1 `isShearwaterFamily`, `canonicalDownloadedSerial`.
- Produces: `Future<int> healShearwaterDownloadSerials(DatabaseConnectionUser db)` (returns rows rewritten); `AppDatabase.healShearwaterDownloadSerialsForTest()`.

- [ ] **Step 1: Write failing tests** (use the in-memory `AppDatabase` setup from `test/core/database/imported_computer_backfill_test.dart`; insert rows with `customStatement`)

```dart
test('a downloaded Shearwater decimal serial becomes hex, no clock stamp', () async {
  await insertComputer(id: 'c1', manufacturer: 'Shearwater', model: 'Perdix 2',
      serial: '2712847316', connectionType: 'bluetooth', hlc: 'h1', updatedAt: 5);
  expect(await db.healShearwaterDownloadSerialsForTest(), 1);
  final row = await readComputer('c1');
  expect(row['serial_number'], 'A1B2C3D4');
  expect(row['hlc'], 'h1');
  expect(row['updated_at'], 5);
});
test('an all-digit file serial is left alone (it is already hex)', () async {
  await insertComputer(id: 'f1', manufacturer: null, model: 'Perdix 2',
      serial: '12345678', connectionType: null);
  expect(await db.healShearwaterDownloadSerialsForTest(), 0);
  expect((await readComputer('f1'))['serial_number'], '12345678');
});
test('a row with a dive_computer data source counts as downloaded', () async {
  await insertComputer(id: 'c2', manufacturer: 'Shearwater', model: 'Teric',
      serial: '12345678', connectionType: null);
  await insertDiveWithSource(computerId: 'c2', sourceFormat: 'dive_computer');
  expect(await db.healShearwaterDownloadSerialsForTest(), 1);
  expect((await readComputer('c2'))['serial_number'], '00BC614E');
});
test('non-Shearwater and already-hex rows are untouched; second run is a no-op', () async {
  await insertComputer(id: 'r1', manufacturer: 'Ratio', model: 'iX3M 2',
      serial: '74691', connectionType: 'bluetooth');
  await insertComputer(id: 'h1', manufacturer: 'Shearwater', model: 'Perdix',
      serial: 'A1B2C3D4', connectionType: 'bluetooth');
  expect(await db.healShearwaterDownloadSerialsForTest(), 0);
  expect(await db.healShearwaterDownloadSerialsForTest(), 0);
});
```

Write `insertComputer`, `readComputer`, `insertDiveWithSource` as local helpers with `customStatement` / `customSelect`, inserting the diver row first and filling every NOT NULL column (`name`, `created_at`, `updated_at`, the dive's required columns: copy them from the backfill test's dive insert).

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement** `shearwater_serial_heal.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';

const Set<String> _directConnectionTypes = {
  'bluetooth',
  'ble',
  'bluetoothclassic',
  'usb',
  'infrared',
};

/// Rewrite the serial of every DOWNLOADED Shearwater computer from the
/// decimal libdivecomputer reports to the 8-character uppercase hex the
/// computer shows (issue #3106).
///
/// Only download provenance identifies a decimal serial. A Shearwater Cloud
/// export keeps the hex text of the log filename, and an all-digit hex
/// serial such as `12345678` is indistinguishable from a decimal one by its
/// characters alone, so a row qualifies only when its connection type is a
/// direct transport or a `source_format = 'dive_computer'` data source
/// points at it.
///
/// Local-only and idempotent: no HLC bump, no pending mark, `updated_at`
/// untouched. Every device on this version derives the same value, so a
/// synced fleet converges without traffic, and no device pushes a restamp
/// that could override a rename made elsewhere. Matching treats both forms as
/// one serial, so a peer that has not upgraded yet still lines up.
Future<int> healShearwaterDownloadSerials(DatabaseConnectionUser db) async {
  final cols = (await db
          .customSelect("PRAGMA table_info('dive_computers')")
          .get())
      .map((c) => c.read<String>('name'))
      .toSet();
  if (!cols.containsAll(
      {'id', 'manufacturer', 'model', 'serial_number', 'connection_type'})) {
    return 0;
  }
  final sourceCols = (await db
          .customSelect("PRAGMA table_info('dive_data_sources')")
          .get())
      .map((c) => c.read<String>('name'))
      .toSet();
  final hasSources = sourceCols.containsAll({'computer_id', 'source_format'});

  final rows = await db.customSelect('''
    SELECT c.id, c.manufacturer, c.model, c.serial_number, c.connection_type,
      ${hasSources ? "EXISTS (SELECT 1 FROM dive_data_sources s WHERE s.computer_id = c.id AND s.source_format = 'dive_computer')" : '0'} AS downloaded
    FROM dive_computers c
    WHERE c.serial_number IS NOT NULL
  ''').get();

  var rewritten = 0;
  for (final row in rows) {
    final serial = row.read<String>('serial_number').trim();
    if (!RegExp(r'^\d+$').hasMatch(serial)) continue;
    final manufacturer = row.readNullable<String>('manufacturer');
    final model = row.readNullable<String>('model');
    if (!isShearwaterFamily(manufacturer: manufacturer, model: model)) continue;
    final connection =
        row.readNullable<String>('connection_type')?.trim().toLowerCase();
    final downloaded = _directConnectionTypes.contains(connection) ||
        row.read<int>('downloaded') == 1;
    if (!downloaded) continue;
    final hex = canonicalDownloadedSerial(
      vendor: 'Shearwater',
      serial: serial,
    );
    if (hex == null || hex == serial) continue;
    await db.customStatement(
      'UPDATE dive_computers SET serial_number = ? WHERE id = ?',
      [hex, row.read<String>('id')],
    );
    rewritten++;
  }
  return rewritten;
}
```

In `data_source_migrations.dart`, next to `_backfillImportedDiveComputers`:

```dart
  /// Rewrite downloaded Shearwater serials to hex (issue #3106). Body lives
  /// in `shearwater_serial_heal.dart`.
  Future<void> _healShearwaterDownloadSerials() =>
      healShearwaterDownloadSerials(this);

  /// Test-only hook exercising the #3106 serial heal directly.
  Future<int> healShearwaterDownloadSerialsForTest() =>
      healShearwaterDownloadSerials(this);
```

In `before_open.dart`, immediately above the `_backfillImportedDiveComputers()` block:

```dart
    // Data self-heal (issue #3106): store downloaded Shearwater serials in
    // the hex the computer shows, before the #1288 pass below matches file
    // imports against them. Local-only, no HLC bump.
    await _healShearwaterDownloadSerials();
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/database/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, guards, commit**

```bash
dart format . && flutter analyze && flutter test test/architecture/ test/shared/
git add lib/core/database test/core/database
git commit -m "feat(dive-computer): rewrite downloaded Shearwater serials to hex"
```

---

### Task 6: `dive_computer_connections` table, schema v277, sync registration

Precedent: `equipment_locations` (v268, entity `equipmentLocations`): its own
`hlc` and `updated_at`, last-writer-wins, exported by `hlc > since`, NOT
parent-gated. Do not copy `trip_equipment`'s parent-gated wiring.

**Files:**
- Create: `lib/core/database/tables/dive_computer_connection_tables.dart` (tables must not be declared in `database.dart`; `test/core/database/database_table_libraries_test.dart` enforces it)
- Modify: `lib/core/database/database.dart`: import the table library; add `DiveComputerConnections,` to `@DriftDatabase(tables: [...])` with a `// Download connections per computer (v277, issue #3106)` comment; `currentSchemaVersion = 277`; append `277,` to `migrationVersions` with a `// v277: dive_computer_connections (issue #3106). Table-only rung, no backfill; the floor does not move.` comment. `minimumCompatibleSchemaVersion` stays 275.
- Create: `lib/core/database/migrations/helpers/dive_computer_connection_migrations.dart` (part file, `_assertDiveComputerConnectionSchema()`), registered as a `part` in `lib/core/database/migrations/app_database_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart`: after the v276 rung, `if (from < 277) { await _assertDiveComputerConnectionSchema(); }` then `if (from < 277) await reportProgress();`
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart`: `// v277 backstop: dive_computer_connections and its computer index (idempotent).` then `await _assertDiveComputerConnectionSchema();`
- Modify: `lib/core/database/performance_indexes.dart`: register `idx_dive_computer_connections_computer` (precedent: the trip_equipment index entry)
- Modify: `lib/core/data/repositories/sync_repository.dart` `hlcTargets`: `'diveComputerConnections': (table: 'dive_computer_connections', pk: 'id'),`
- Modify: `lib/core/services/sync/sync_service.dart`: `mergeOrder` entry `(type: 'diveComputerConnections', records: data.diveComputerConnections, hasUpdatedAt: true)` right after `diveComputers`; `entityHasUpdatedAt` `'diveComputerConnections': true,`; `parentRefs` `'diveComputerConnections': [(field: 'computerId', parent: 'diveComputers', nullable: false)],`
- Modify: `lib/core/services/sync/sync_data_serializer.dart`, every point the `equipmentLocations` entity has, and NOT `parentGatedChildEntities` / `parentGatedTables`:
  - `SyncData` field, constructor default `const []`, `toJson` (order matches `_baseTables`), `fromJson` `_parseList`
  - `_baseTables` spec `(key: 'diveComputerConnections', table: _db.diveComputerConnections, blob: false, full: null)` at the matching position
  - `_buildSyncData`: `diveComputerConnections: await _safeExport('diveComputerConnections', () => _exportDiveComputerConnections(hlcSince)),` (no `_withPendingChildren`)
  - `_exportDiveComputerConnections(hlcSince)`: `hlc > since`, rows mapped through `withoutDeviceLocalColumns('diveComputerConnections', row.toJson())` (precedent `_exportDiveComputers`)
  - `fetchRecord` and `fetchRecords` cases, both wrapped in `withoutDeviceLocalColumns` (precedent: the `diveComputers` cases)
  - `upsertRecord` case: `insertOnConflictUpdate(DiveComputerConnectionRow.fromJson(_withTimestampDefaults(data)).toCompanion(false))`; `upsertRecords` batch case
  - `recordIdsFor`: `return plain(_db.diveComputerConnections, _db.diveComputerConnections.id);`
  - `_syncTableFor` and `deleteRecord` cases
- Modify: `lib/core/services/sync/device_local_fields.dart`: `'diveComputerConnections': {'address', 'localLastUsedAt'},` with a comment that both belong to the device that made the connection
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart`: a step BEFORE `dive_computers`: `(table: 'dive_computer_connections', entityType: 'diveComputerConnections', where: 'computer_id IN (SELECT id FROM dive_computers WHERE diver_id = ?1)')` (Task 7's `deleteComputer` tombstones connections, so the diver delete must too)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/equipment_fields.dart` (next to `bluetoothAddress`): `ConflictField` entries for `kind`, `detail`, `firstUsedAt`, `lastUsedAt`, `address`, `localLastUsedAt` (exempt: `id`, `hlc`, `createdAt`, `updatedAt`, and the FK `computerId`), with new `settings_conflict_field_connectionKind`, `_connectionDetail`, `_firstUsedAt`, `_lastUsedAt`, `_connectionAddress`, `_localLastUsedAt` keys in all 11 ARB files, next to `settings_conflict_field_bluetoothAddress`. Pick `FieldKind` values from the catalogue's existing ones (shortText, dateTime or the closest).
- Modify: `docs/user/multi-device-sync.md` "What Syncs Between Devices": connections sync; their address and last-used-here stay on each device.
- Test: `test/core/database/migration_v277_dive_computer_connections_test.dart` (create), `test/core/services/sync/dive_computer_connection_sync_test.dart` (create, precedent `equipment_location_sync_test.dart`), and extend the hand-kept lists: `test/core/services/sync/sync_parent_refs_completeness_test.dart` `syncedTables` (`'dive_computer_connections': 'diveComputerConnections'`), `sync_data_serializer_batch_coverage_test.dart` targets, `sync_serializer_fetch_record_test.dart`, `diver_delete_tombstones_test.dart` seeders.

**Interfaces:**
- Produces: Drift table `DiveComputerConnections` (accessor `diveComputerConnections`, row class `DiveComputerConnectionRow`), entity type `'diveComputerConnections'`, SQL table `dive_computer_connections`.

Table definition:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_profile_tables.dart';

/// The ways one dive computer has reached the library (issue #3106): a
/// direct transport (BLE, Bluetooth Classic, USB, infrared), a file format,
/// or a cloud provider. One row per (computer, kind, detail), on a
/// deterministic id so two devices recording the same connection converge.
///
/// No unique index on purpose: a unique constraint on a replicated table
/// makes an inbound sync insert throw instead of merge.
@DataClassName('DiveComputerConnectionRow')
class DiveComputerConnections extends Table {
  TextColumn get id => text()();
  TextColumn get computerId => text().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// `ble`, `bluetoothClassic`, `usb`, `infrared`, `file` or `cloud`.
  TextColumn get kind => text()();

  /// The file format (`ImportFormat.name`) or cloud provider; null for a
  /// direct transport.
  TextColumn get detail => text().nullable()();

  IntColumn get firstUsedAt => integer()();
  IntColumn get lastUsedAt => integer()();

  /// Device-local: this device's BLE identifier or USB port. Never synced.
  TextColumn get address => text().nullable()();

  /// Device-local: when this device last used the connection. Never synced.
  IntColumn get localLastUsedAt => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

(Copy the `coverage:ignore-file` header comment from `dive_profile_tables.dart`.)

Helper:

```dart
part of '../app_database_migrations.dart';

extension DiveComputerConnectionMigrations on AppDatabase {
  /// v277 (issue #3106): the dive computer connections table and its
  /// computer index. Idempotent: the ladder rung and the beforeOpen backstop
  /// both call it, so a database restored or adopted past v277 without the
  /// table still gets it.
  Future<void> _assertDiveComputerConnectionSchema() async {
    if (!await _tableExists('dive_computers')) return;
    if (!await _tableExists('dive_computer_connections')) {
      await Migrator(this).createTable(diveComputerConnections);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_computer_connections_computer '
      'ON dive_computer_connections (computer_id)',
    );
  }
}
```

(Match the precedent helper's exact `part of` / extension / `_tableExists` shape in `helpers/equipment_location_migrations.dart`; if it uses a private extension name or a mixin, follow that.)

- [ ] **Step 1: Write failing tests**
  - Migration (pattern: `migration_v268_equipment_locations_test.dart`): `AppDatabase.currentSchemaVersion >= 277`, `migrationVersions` contains 277; upgrading a v276 file creates the table, all columns and the index; the backstop recreates a missing table on a file already at 277; a fixture without `dive_computers` does not throw.
  - Sync (pattern: `equipment_location_sync_test.dart`): an exported changeset row has no `address` / `localLastUsedAt` keys; applying a peer row for an id that exists locally with `address: 'AA:BB'`, `localLastUsedAt: 9` keeps both and takes the peer's `lastUsedAt`; a peer tombstone deletes the row; `fetchRecord` output has no device-local keys.
- [ ] **Step 2: Run to verify failure:** `flutter test test/core/database/migration_v277_dive_computer_connections_test.dart test/core/services/sync/dive_computer_connection_sync_test.dart`
- [ ] **Step 3: Implement** every bullet in Files, then `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`.
- [ ] **Step 4: Run tests:** `flutter test test/core/database/ test/core/services/sync/ test/features/settings/presentation/conflicts/ test/features/divers/`
- [ ] **Step 5: Format, analyze, guards, commit**

```bash
dart format . && flutter analyze && flutter test test/architecture/ test/shared/
git add lib/core lib/features/divers lib/features/settings lib/l10n docs/user/multi-device-sync.md test/core test/features/settings test/features/divers
git commit -m "feat(dive-computer): add the dive computer connections table"
```

---

### Task 7: Connection entity and repository

**Files:**
- Create: `lib/features/dive_computer/domain/entities/dive_computer_connection.dart`
- Create: `lib/features/dive_computer/data/repositories/dive_computer_connection_repository.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`deleteComputer` tombstones connection rows before the delete)
- Test: `test/features/dive_computer/domain/entities/dive_computer_connection_test.dart`, `test/features/dive_computer/data/repositories/dive_computer_connection_repository_test.dart`

**Interfaces:**
- Consumes: Task 6 table.
- Produces:

```dart
enum DiveComputerConnectionKind {
  ble, bluetoothClassic, usb, infrared, file, cloud;

  bool get isDirect => this != file && this != cloud;
  static DiveComputerConnectionKind? fromWire(String? value);
  /// The legacy `dive_computers.connection_type` mirror value.
  String? get legacyConnectionType; // ble/bluetoothClassic -> 'bluetooth', usb -> 'usb', infrared -> 'infrared', cloud -> 'cloud', file -> null
  DeviceConnectionType? get deviceConnectionType; // direct kinds only
  static DiveComputerConnectionKind fromDevice(DeviceConnectionType type);
}

const String kDiveComputerConnectionNamespace = '7bd854b9-1e72-422b-8f8e-784bd64924b7';
String diveComputerConnectionId({required String computerId, required DiveComputerConnectionKind kind, String? detail});

class DiveComputerConnection extends Equatable {
  final String id; final String computerId; final DiveComputerConnectionKind kind;
  final String? detail; final DateTime firstUsedAt; final DateTime lastUsedAt;
  final String? address; final DateTime? localLastUsedAt;
  bool get isDirect; bool get reachableHere; // direct && non-blank address
  DiveComputerConnection copyWith({...});
}

class DiveComputerConnectionRepository {
  DiveComputerConnectionRepository({AppDatabase? database, SyncRepository? syncRepository});
  Stream<void> watchChanges();
  Future<List<DiveComputerConnection>> forComputer(String computerId);
  Future<Map<String, List<DiveComputerConnection>>> forComputers(Iterable<String> computerIds);
  Future<String?> computerIdForLocalAddress({required String address, String? diverId});
  Future<DiveComputerConnection> recordConnection({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    String? address,
    DateTime? usedAt,
  });
  Future<void> foldInto({required String survivorId, required List<String> duplicateIds, required int now});
  Future<void> deleteForComputer(String computerId);
}
```

Rules `recordConnection` must implement:
- id from `diveComputerConnectionId`; `usedAt` defaults to `DateTime.now()`.
- Missing row: insert with `firstUsedAt = lastUsedAt = usedAt`, `address` (trimmed, blank as null), `localLastUsedAt = address != null || kind.isDirect ? usedAt : null`, then `markRecordPending(entityType: 'diveComputerConnections', recordId: id, localUpdatedAt: now)`.
- Existing row: `lastUsedAt = max(existing, usedAt)`, `firstUsedAt = min`, `address` replaced when a non-blank one is given, `localLastUsedAt = usedAt` for a direct kind; mark pending only when `lastUsedAt` or `firstUsedAt` changed (device-local-only changes stamp nothing, per #2947; precedent for the rule: the `isDeviceLocalColumn` check in `diver_settings_repository.dart`).
- `SyncEventBus.notifyLocalChange()` after a pending mark; never inside a caller's transaction (take a `notify` flag defaulting to true, as the #1453 series repoint does, and pass false from `foldInto`).
- `computerIdForLocalAddress`: compares case-insensitively (`bluetoothAddressesMatch` semantics, uppercase both), direct kinds only, joined to `dive_computers` filtered by diver when given, newest `local_last_used_at` first.
- `foldInto` (inside the caller's transaction): for every duplicate row, compute the survivor id for the same `(kind, detail)`, upsert by merging timestamps (min first, max last, max local), keep a non-blank address (survivor's wins), mark the survivor row pending, delete the duplicate row and `logDeletion(entityType: 'diveComputerConnections', recordId: oldId)`.
- `deleteForComputer`: select the ids, delete them, then `logDeletions(entityType: 'diveComputerConnections', recordIds: ids)` (precedent `TripEquipmentRepository.deleteByTripId`). `deleteComputer` calls it just before its own `logDeletion(entityType: 'diveComputers', ...)`, so the cascade never deletes a row without a tombstone.

- [ ] **Step 1: Write failing tests**: id determinism (`diveComputerConnectionId` stable, differs by kind/detail, `detail: null` equals `detail: ''`); `fromWire` round trip; first record inserts and marks pending; second record of the same connection with an older `usedAt` keeps `lastUsedAt`; a new address replaces the stored one; an address-only re-record marks nothing pending; `computerIdForLocalAddress` matches `aa:bb` to `AA:BB` and ignores file/cloud rows and another diver's computer; `deleteForComputer` writes a tombstone per row.
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement** both files and the `deleteComputer` call.
- [ ] **Step 4: Run tests** `flutter test test/features/dive_computer/ test/features/dive_log/data/repositories/`
- [ ] **Step 5: Format, analyze, guards, commit** `feat(dive-computer): record download connections per computer`

---

### Task 8: Seed connections for existing computers

**Files:**
- Create: `lib/core/database/dive_computer_connection_seed.dart`
- Modify: `data_source_migrations.dart` (wrapper + `seedDiveComputerConnectionsForTest()`), `before_open.dart` (call AFTER `_backfillImportedDiveComputers()`, so computers that pass registers also get their file connections)
- Test: `test/core/database/dive_computer_connection_seed_test.dart`

**Interfaces:**
- Consumes: Task 7 `diveComputerConnectionId`, `DiveComputerConnectionKind`.
- Produces: `Future<int> seedDiveComputerConnections(DatabaseConnectionUser db)` (rows inserted).

Rules (raw SQL, PRAGMA-guarded like `imported_computer_backfill.dart`, `INSERT OR IGNORE`, no HLC, no pending):
- Only computers with no `dive_computer_connections` row at all.
- Direct: `connection_type` `bluetooth`/`ble` gives `ble`, `bluetoothclassic` gives `bluetoothClassic`, `usb` gives `usb`, `infrared` gives `infrared`; `address = bluetooth_address`; `first_used_at = created_at`; `last_used_at = local_last_used_at = COALESCE(last_download_timestamp, updated_at)`. (Check the unit of `last_download_timestamp` in `_mapRowToComputer` and convert to the same millisecond epoch the new table uses.)
- Cloud: `connection_type = 'cloud'` gives `cloud` with detail `garminConnect` when the manufacturer normalizes to `garmin`, `suuntoCloud` for `suunto`, else no row.
- File: one row per distinct non-null `dive_data_sources.source_file_format` where the source's `computer_id` is this computer (or the source's `computer_id` is null and its dive's `computer_id` is), excluding `source_format = 'dive_computer'`; first/last from MIN/MAX of the source rows' `created_at` when that column exists, else the computer's `created_at`.
- `created_at = updated_at = ` the seed time.

- [ ] **Step 1: Write failing tests**: a BLE computer seeds one `ble` row carrying its address; a cloud Garmin seeds `cloud/garminConnect`; a file-imported computer with FIT and UDDF sources seeds two `file` rows; a computer that already has any connection row is skipped; a second run inserts 0; seeded rows have `hlc IS NULL` and no `sync_records` pending row (check the table the sync repository writes pending marks to).
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests** `flutter test test/core/database/`
- [ ] **Step 5: Format, analyze, guards, commit** `feat(dive-computer): seed connections from existing computers`

---

### Task 9: Every path records its connection; known computers resolve by local address

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (`resolveKnownComputer`, `ensureComputer`, constructor gets a `DiveComputerConnectionRepository`)
- Modify: the adapter's construction sites (router `_DiveComputerDownloadWizardRoute`, `_DiveComputerDiscoveryWizardRoute`, and any other `DiveComputerAdapter(` call: `grep -rn "DiveComputerAdapter(" lib test`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (collect `(computerId, format)` during the data-source writes near lines 3105 and 3216; record each once before `return _DiveImportResult(`)
- Modify: `lib/features/import_wizard/data/adapters/garmin_cloud_adapter.dart` and `suunto_dive_import_core.dart` (record `cloud` in the `importedCountByComputerId` loop next to `updateLastDownload`)
- Modify: `lib/features/dive_log/presentation/providers/dive_computer_providers.dart` (`savedComputersByAddressProvider` also maps local connection addresses)
- Create: `lib/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart` (repository provider, `diveComputerConnectionsProvider`, `allDiveComputerConnectionsProvider`; signatures under Task 12's Interfaces, defined here because Tasks 9, 11 and 12 all read them)
- Test: adapter tests (`test/features/import_wizard/data/adapters/dive_computer_adapter_*_test.dart`), importer test, cloud adapter tests, provider test

**Interfaces:**
- Consumes: Task 7 repository and kinds; Task 1 serial rule.
- Produces: `DiveComputerAdapter({..., DiveComputerConnectionRepository? connectionRepository})` defaulting to `DiveComputerConnectionRepository()` so existing tests compile.

`ensureComputer` rule: after `_computer` is resolved (both modes, including the known-computer early return, which must now fall through to the recording step), record `kind = DiveComputerConnectionKind.fromDevice(device.connectionType)`, `address = device.address`, UNLESS this is a known computer whose stored serial and the reported serial are both non-blank and do not match under `computerSerialsMatch` (another computer answered; Review Focus 1). Wrap the record in try/catch and log: bookkeeping must not fail the download (#2439).

`resolveKnownComputer`: for any direct transport, first `connectionRepository.computerIdForLocalAddress(address: device.address, diverId: _diverId)` then `getComputerById`; fall back to the existing `findByBluetoothAddress` for BLE/Classic.

UDDF importer: format detail is `diveSourceFormat?.name ?? 'uddf'`; skip when `computerId` is null; record with `usedAt: now` (the importer's `now`).

Cloud: Garmin `kind: cloud, detail: 'garminConnect'`; Suunto `detail: 'suuntoCloud'`.

- [ ] **Step 1: Write failing tests**
  - BLE first download records `(ble, address)`; a known-computer USB download records `(usb, port)` and resolves the computer by the port, so `lastDiveFingerprint` reaches the download (assert `adapter.computer` is set after `resolveKnownComputer` for a USB device whose port has a local connection).
  - Known computer, reported serial `2712847317` vs stored `A1B2C3D4`: no connection recorded.
  - Known computer, reported `A1B2C3D4` vs stored `2712847316`: recorded.
  - A FIT import records `(file, fit)` once for a 10-dive file; a Shearwater import then a BLE download of the same serial leaves one computer with two connections.
  - Garmin cloud import records `(cloud, garminConnect)`; FIT file first then Connect leaves ONE computer (end-to-end on the in-memory DB with the real repository).
  - `savedComputersByAddressProvider` contains a computer under a USB port held only in a connection row.
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests** `flutter test test/features/import_wizard/ test/features/dive_import/ test/features/dive_log/ test/features/dive_computer/`
- [ ] **Step 5: Format, analyze, commit** `feat(dive-computer): record each download and import path as a connection`

---

### Task 10: Merge folds connections

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_merge_repository.dart` (inside the transaction, before the duplicate delete loop: `await _connections.foldInto(survivorId: survivorId, duplicateIds: duplicates, now: now);`; constructor takes an optional `DiveComputerConnectionRepository`)
- Test: extend `test/features/dive_log/data/repositories/dive_computer_merge_repository_test.dart`

- [ ] **Step 1: Write failing tests**: survivor has `(ble)` with no address, last used 10; duplicate has `(ble)` with address `AA`, last used 20, and `(file, shearwaterDb)`; after merge the survivor has exactly two rows, `(ble)` with address `AA` and lastUsedAt 20, plus `(file, shearwaterDb)`; the duplicate's two ids are tombstoned; no row references the deleted computer.
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests** `flutter test test/features/dive_log/data/repositories/`
- [ ] **Step 5: Format, analyze, commit** `feat(dive-computer): merge combines both records' connections`

---

### Task 11: Saved download picks this device's connection; `?connection=`

**Files:**
- Create: `lib/features/dive_computer/domain/services/download_connection_selection.dart`
- Modify: `lib/core/router/app_router.dart` (route reads `state.uri.queryParameters['connection']`; `_DiveComputerDownloadWizardRoute` gets `connectionId`, watches `diveComputerConnectionsProvider(computerId)` too, and builds the adapter's `knownComputer` with `computerForDownload`; reset the adapter in `didUpdateWidget` when `connectionId` changes)
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (`_connectionTypeFromString` returns `DeviceConnectionType?`, null for unknown; callers treat null as "no direct transport")
- Test: `test/features/dive_computer/domain/services/download_connection_selection_test.dart`, extend the download step widget test

**Interfaces:**
- Produces:

```dart
/// The direct connection a saved-computer download should use on this
/// device: [connectionId] when given and reachable here, else the reachable
/// one with the newest localLastUsedAt. Null when none is reachable here.
DiveComputerConnection? connectionForDownload(
  List<DiveComputerConnection> connections, {
  String? connectionId,
});

/// [computer] as the download wizard should see it: connectionType and
/// bluetoothAddress from [selected]. With no connection rows at all the
/// computer is returned unchanged (legacy columns still drive it); with rows
/// but none reachable here, both fields are cleared so the wizard shows the
/// "no direct download" view instead of dialing a stale address.
DiveComputer computerForDownload(
  DiveComputer computer,
  List<DiveComputerConnection> connections, {
  DiveComputerConnection? selected,
});
```

`computerForDownload` builds a new `DiveComputer(...)` with every field copied explicitly (copyWith cannot clear to null).

- [ ] **Step 1: Write failing tests**: newest-local wins; explicit id wins; explicit id of a file connection or a connection with no local address falls back to the newest reachable; rows but none reachable clears both fields; no rows returns the same instance; `_connectionTypeFromString('cloud')` no longer means BLE (widget test: a computer with connectionType `cloud` and an address shows `DcNoDirectDownloadView`).
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests** `flutter test test/features/dive_computer/ test/features/import_wizard/ test/core/router/`
- [ ] **Step 5: Format, analyze, guards, commit** `feat(dive-computer): download a saved computer over a chosen connection`

---

### Task 12: Connections card, list icon, merge sheet line, l10n

**Files:**
- Consume: `lib/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart` (created in Task 9)
- Create: `lib/features/dive_computer/presentation/utils/connection_presentation.dart`
- Create: `lib/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart`
- Modify: `device_detail_page.dart` (insert `DiveComputerConnectionsCard(computer: computer)` after the info card; remove the Connection info row and `_getConnectionName`; header icon from the newest connection; net line count must not grow)
- Modify: `device_list_page.dart` (`_getConnectionIcon` replaced by `connectionIcon` of the newest connection from `allDiveComputerConnectionsProvider`, falling back to the legacy column)
- Modify: `dive_computer_merge_sheet.dart` (each record's subtitle adds the connection labels)
- Modify: all 11 ARB files; regenerate with `flutter gen-l10n`
- Test: `test/features/dive_computer/presentation/widgets/dive_computer_connections_card_test.dart`, `test/features/dive_computer/presentation/utils/connection_presentation_test.dart`, extend list page and merge sheet tests

**Interfaces:**
- Provider signatures (created in Task 9):
  - `final diveComputerConnectionRepositoryProvider = Provider<DiveComputerConnectionRepository>(...)`
  - `final diveComputerConnectionsProvider = FutureProvider.family<List<DiveComputerConnection>, String>(...)` (invalidates on `watchChanges()`), sorted by `lastUsedAt` desc
  - `final allDiveComputerConnectionsProvider = FutureProvider<Map<String, List<DiveComputerConnection>>>(...)` over `allDiveComputersProvider`
  - `IconData connectionIcon(DiveComputerConnectionKind? kind)`; `String connectionLabel(AppLocalizations l10n, DiveComputerConnection c)`

Labels: `ble` uses `diveComputer_connectionType_ble`, `bluetoothClassic` uses `diveComputer_connectionType_bluetooth`, `usb` and `infrared` their existing keys, `file` uses `diveComputer_connections_fileFormat(format: ImportFormat.values.byName(detail).displayName)` (unknown detail uses the detail text), `cloud/garminConnect` uses `diveComputer_connections_cloudGarmin`, `cloud/suuntoCloud` uses `diveComputer_connections_cloudSuunto`, other cloud uses `diveComputer_connections_cloudOther`. Icons: bluetooth, usb, sensors, `Icons.description_outlined` for file, `Icons.cloud_outlined` for cloud, watch for null.

New keys (en; translate for the other 10, hu ASCII-only):

| Key | en |
| --- | --- |
| `diveComputer_connections_title` | `Connections` |
| `diveComputer_connections_empty` | `No downloads or imports recorded yet` |
| `diveComputer_connections_lastUsed` | `Last used {when}` (placeholder `when`: String) |
| `diveComputer_connections_thisDevice` | `This device` |
| `diveComputer_connections_downloadVia` | `Download via {connection}` (placeholder `connection`: String; tooltip/semantics) |
| `diveComputer_connections_fileFormat` | `{format} file` (placeholder `format`: String) |
| `diveComputer_connections_cloudGarmin` | `Garmin Connect` |
| `diveComputer_connections_cloudSuunto` | `Suunto app` |
| `diveComputer_connections_cloudOther` | `Cloud import` |

Card rows: leading `connectionIcon`, title `connectionLabel`, subtitle `diveComputer_connections_lastUsed(when: formatLastDownload(context, c.lastUsedAt, units: units))` plus a `This device` `Chip` when `c.reachableHere`, trailing `IconButton(Icons.download)` with tooltip `downloadVia` only when `c.reachableHere`, pushing `/dive-computers/${computer.id}/download?connection=${c.id}`. Empty list shows the empty text. Loading shows nothing (no reserved space, like the duplicate banner). Respect `ListTile` trailing width guard (`test/architecture/list_tile_trailing_width_test.dart`).

- [ ] **Step 1: Write failing tests**: card lists a BLE row with This device and a download button, a FIT row without either; tapping download pushes the `?connection=` route (use the GoRouter test harness the detail page tests use); labels for every kind; list page shows `Icons.cloud_outlined` for a cloud-only computer; merge sheet subtitle includes `Shearwater DB file` for a file-only record. Pump in both light and dark themes once each.
- [ ] **Step 2: Run to verify failure**
- [ ] **Step 3: Implement** presentation utils, card, page edits, ARB keys (all locales), `flutter gen-l10n`.
- [ ] **Step 4: Run tests** `flutter test test/features/dive_computer/ test/l10n/ test/architecture/ test/shared/` and the generated-l10n staleness check the pre-push hook runs.
- [ ] **Step 5: Format, analyze, commit** `feat(dive-computer): show each computer's connections`

---

### Task 13: Docs and full verification

**Files:**
- Modify: the user doc that describes dive computers (`grep -rln "dive computer" docs/user | head`), adding a short "Connections" section: what is listed, "This device", Download via, and that Shearwater serials now show in hex.
- Modify: `docs/user/multi-device-sync.md` (already touched in Task 6; confirm the connection rows sync and the address and last-used-here do not).

- [ ] **Step 1:** Write the doc sections.
- [ ] **Step 2:** `dart format .`, `flutter analyze`, `python3.14 scripts/check_docs_links.py`, then the affected suites: `flutter test test/core/ test/features/dive_computer/ test/features/dive_log/ test/features/import_wizard/ test/features/dive_import/ test/features/universal_import/ test/architecture/ test/shared/`.
- [ ] **Step 3:** Scan the branch diff for em and en dashes with a Python one-liner that counts code points 0x2014 and 0x2013 in `git diff origin/main` output (excluding `*.g.dart`); it must report zero. Build the characters with `chr()`, never a literal escape in a tool argument.
- [ ] **Step 4:** Commit `docs(dive-computer): document computer connections`.
