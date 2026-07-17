# divelogs.de Sync — Phase 3 (Gear + Certifications) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pull divelogs.de gear and certifications into Submersion through the import wizard (with dive-to-gear links), and push local equipment/certifications back from the sync page, create-only in both directions.

**Architecture:** Pull rides the existing universal-import pipeline — the divelogs fetch simply adds `ImportEntityType.equipment` and `ImportEntityType.certifications` entities to the payload (per-item review, dedup by `name|type` and `name|agency` compound keys, and `equipmentRefs` dive-linking all already exist). Push adds a pure-function `GearCertSyncPlanner` plus a push service that creates unmatched gear/certs remotely; because `POST /gear` does not document a returned id, pushed dives resolve `gearitems` ids by re-fetching `GET /gear` after gear push.

**Tech Stack:** Same as Phases 1–2. No schema migration.

**Spec:** `docs/superpowers/specs/2026-07-16-divelogs-de-sync-design.md` (Phase 3 section).

## Global Constraints

- Same as Phases 1–2 (metric units, wall-clock UTC, `dart format .` clean, no emojis, no commit attribution, l10n into all 11 locales + `flutter gen-l10n`, per-file tests, `--no-verify` push after in-worktree verification).
- divelogs.de API (verified from the OpenAPI spec):
  - `GET /gear` list; `POST /gear` body `{name, geartype (number), purchasedate, last_servicedate, discarddate, servicedives, servicemonths, standard, add_to_existing}` — response documents only "Success", NO created id.
  - `GET /geartypes` (unauthenticated) returns the geartype id/name reference list (exact shape unconfirmed — parse tolerantly).
  - `GET /certifications` returns `[{id, name, date, org, typ, scans}]`; `POST /certifications` is **multipart/form-data** with mandatory `name` + `date` (YYYY-MM-DD), optional `org`; response includes the created `id`.
  - Dives carry `gearitems: [numeric ids]`.
- Create-only both directions; no updates or deletes; scans/photos stay Phase 4.
- Pull-side per-endpoint resilience: a failure fetching gear or certifications degrades to a payload warning — it must never abort the dive pull.
- Sync-page push for gear/certs is a single "Sync gear & certifications" action with counts (no per-item checkboxes — low-risk reference data; per-item review exists on the pull side via the wizard). Per-dive checkboxes remain for dives. This is a deliberate simplification of the spec's sketch; record it in code comments.

---

### Task 1: Gear/certification models + API endpoints

**Files:**
- Modify: `lib/core/services/divelogs/divelogs_models.dart`
- Modify: `lib/core/services/divelogs/divelogs_api_client.dart`
- Test: `test/core/services/divelogs/divelogs_models_test.dart` (extend)
- Test: `test/core/services/divelogs/divelogs_api_client_test.dart` (extend)

**Interfaces:**
- Consumes: existing `_send`/`_get`/`_decode` plumbing and the `_asDouble/_asInt/_asNonEmptyString` helpers.
- Produces:
  - `DivelogsDive` gains `final List<String> gearItemIds;` (parsed from `json['gearitems']`, each element stringified; default `const []`).
  - `class DivelogsGearItem { final String id; final String name; final int? geartypeId; final DateTime? purchaseDate; final DateTime? lastServiceDate; final DateTime? discardDate; static DivelogsGearItem? fromJson(Map<String, dynamic>); }` — null when id or name unusable; dates parsed as wall-clock UTC via `DateTime.tryParse('${value}T00:00:00Z')`.
  - `class DivelogsCertification { final String? id; final String name; final DateTime? date; final String? org; static DivelogsCertification? fromJson(Map<String, dynamic>); }` — null when name missing.
  - On the client: `Future<List<DivelogsGearItem>> getGear()`, `Future<Map<int, String>> getGeartypes()` (tolerant: accepts `[{id, name}]`, `{geartypes: [...]}`, or `{"1": "Regulator"}` map form; unauthenticated but sent through `_get` anyway — the bearer header is harmless), `Future<List<DivelogsCertification>> getCertifications()`, `Future<void> postGear(Map<String, dynamic> gear)` (JSON POST via `_send`), `Future<void> postCertification({required String name, required String date, String? org})` (**multipart** POST with the same 401-invalidate-retry-once semantics — see Step 3).

- [ ] **Step 1: Write the failing model tests** — append to `divelogs_models_test.dart`:

```dart
group('DivelogsGearItem', () {
  test('parses fields with wall-clock UTC dates', () {
    final gear = DivelogsGearItem.fromJson({
      'id': 45,
      'name': 'Apex XTX50',
      'geartype': 1,
      'purchasedate': '2007-05-12',
      'last_servicedate': '2024-01-02',
      'discarddate': null,
    })!;
    expect(gear.id, '45');
    expect(gear.name, 'Apex XTX50');
    expect(gear.geartypeId, 1);
    expect(gear.purchaseDate, DateTime.utc(2007, 5, 12));
    expect(gear.lastServiceDate, DateTime.utc(2024, 1, 2));
    expect(gear.discardDate, isNull);
  });

  test('returns null without id or name', () {
    expect(DivelogsGearItem.fromJson({'name': 'X'}), isNull);
    expect(DivelogsGearItem.fromJson({'id': 1}), isNull);
  });
});

group('DivelogsCertification', () {
  test('parses fields', () {
    final cert = DivelogsCertification.fromJson({
      'id': 123,
      'name': 'Open Water Diver',
      'date': '2022-06-15',
      'org': 'PADI',
    })!;
    expect(cert.id, '123');
    expect(cert.name, 'Open Water Diver');
    expect(cert.date, DateTime.utc(2022, 6, 15));
    expect(cert.org, 'PADI');
  });

  test('returns null without a name', () {
    expect(DivelogsCertification.fromJson({'id': 1}), isNull);
  });
});

test('DivelogsDive parses gearitems as string ids', () {
  final dive = DivelogsDive.fromJson({
    'id': 1,
    'date': '2022-09-03',
    'time': '10:00:00',
    'duration': 60,
    'maxdepth': 5,
    'gearitems': [45, 62],
  });
  expect(dive.gearItemIds, ['45', '62']);
});
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/core/services/divelogs/divelogs_models_test.dart`, expect compile FAIL.

- [ ] **Step 3: Implement models and endpoints**

Models (append; also add `gearItemIds` to `DivelogsDive` — field, constructor param `this.gearItemIds = const []`, and in `fromJson`: `gearItemIds: json['gearitems'] is List ? [for (final g in json['gearitems'] as List) '$g'] : const []`):

```dart
DateTime? _asUtcDate(Object? v) {
  final s = _asNonEmptyString(v);
  return s == null ? null : DateTime.tryParse('${s}T00:00:00Z');
}

/// One row of GET /gear. Tolerant: unusable rows yield null.
class DivelogsGearItem {
  final String id;
  final String name;
  final int? geartypeId;
  final DateTime? purchaseDate;
  final DateTime? lastServiceDate;
  final DateTime? discardDate;

  const DivelogsGearItem({
    required this.id,
    required this.name,
    this.geartypeId,
    this.purchaseDate,
    this.lastServiceDate,
    this.discardDate,
  });

  static DivelogsGearItem? fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['gear_id'];
    final name = _asNonEmptyString(json['name']);
    if (rawId == null || name == null) return null;
    return DivelogsGearItem(
      id: '$rawId',
      name: name,
      geartypeId: _asInt(json['geartype']),
      purchaseDate: _asUtcDate(json['purchasedate']),
      lastServiceDate: _asUtcDate(json['last_servicedate']),
      discardDate: _asUtcDate(json['discarddate']),
    );
  }
}

/// One row of GET /certifications. Tolerant: unusable rows yield null.
class DivelogsCertification {
  final String? id;
  final String name;
  final DateTime? date;
  final String? org;

  const DivelogsCertification({
    this.id,
    required this.name,
    this.date,
    this.org,
  });

  static DivelogsCertification? fromJson(Map<String, dynamic> json) {
    final name = _asNonEmptyString(json['name']);
    if (name == null) return null;
    final rawId = json['id'];
    return DivelogsCertification(
      id: rawId == null ? null : '$rawId',
      name: name,
      date: _asUtcDate(json['date']),
      org: _asNonEmptyString(json['org']),
    );
  }
}
```

Client — a private list-extraction helper plus the five endpoints. For multipart with retry, mirror `_send`'s loop but build a fresh `http.MultipartRequest` each attempt:

```dart
List<dynamic> _rows(Object? decoded, String endpoint, List<String> listKeys) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    for (final key in listKeys) {
      if (decoded[key] is List) return decoded[key] as List;
    }
  }
  throw DivelogsApiException(0, 'Unexpected $endpoint response');
}

Future<List<DivelogsGearItem>> getGear() async {
  final response = await _get('/gear');
  final rows = _rows(_decode(response.body, '/gear'), '/gear', const [
    'gear',
    'gearitems',
  ]);
  return [
    for (final row in rows)
      if (row is Map)
        ...?_maybe(DivelogsGearItem.fromJson(Map<String, dynamic>.from(row))),
  ];
}

Future<List<DivelogsCertification>> getCertifications() async {
  final response = await _get('/certifications');
  final rows = _rows(
    _decode(response.body, '/certifications'),
    '/certifications',
    const ['certifications'],
  );
  return [
    for (final row in rows)
      if (row is Map)
        ...?_maybe(
          DivelogsCertification.fromJson(Map<String, dynamic>.from(row)),
        ),
  ];
}

List<T>? _maybe<T>(T? value) => value == null ? null : [value];

/// Geartype reference list: id -> display name. Accepts array-of-objects,
/// wrapped, or id->name map forms (shape unconfirmed, spec open question).
Future<Map<int, String>> getGeartypes() async {
  final response = await _get('/geartypes');
  final decoded = _decode(response.body, '/geartypes');
  final result = <int, String>{};
  if (decoded is Map && decoded.values.every((v) => v is String)) {
    decoded.forEach((k, v) {
      final id = int.tryParse('$k');
      if (id != null) result[id] = v as String;
    });
    return result;
  }
  final rows = _rows(decoded, '/geartypes', const ['geartypes']);
  for (final row in rows) {
    if (row is Map) {
      final id = row['id'];
      final name = row['name'];
      if (id is num && name is String) result[id.toInt()] = name;
    }
  }
  return result;
}

Future<void> postGear(Map<String, dynamic> gear) async {
  await _send('/gear', method: 'POST', jsonBody: gear);
}

Future<void> postCertification({
  required String name,
  required String date,
  String? org,
}) async {
  var authRetried = false;
  while (true) {
    final token = await _getBearerToken();
    final request = http.MultipartRequest(
      'POST',
      _baseUri.replace(path: '${_baseUri.path}/certifications'),
    )..headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['date'] = date;
    if (org != null) request.fields['org'] = org;
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on Exception {
      throw const DivelogsApiException(0, 'Could not reach divelogs.de.');
    }
    if (response.statusCode == 401) {
      _onTokenRejected();
      if (!authRetried) {
        authRetried = true;
        continue;
      }
      throw const DivelogsApiException(
        401,
        'divelogs.de sign-in expired. Sign in again in Settings.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DivelogsApiException(
        response.statusCode,
        'divelogs.de API error ${response.statusCode}',
      );
    }
    return;
  }
}
```

- [ ] **Step 4: Write failing client tests** — append to `divelogs_api_client_test.dart` (reuse the `client(...)` helper): `getGear` parses an array and skips a no-name row; `getGeartypes` accepts both `[{id, name}]` and `{"1": "Regulator"}` forms; `getCertifications` parses the documented array; `postGear` sends a JSON POST to `/api/gear`; `postCertification` sends multipart fields `name`/`date`/`org` (assert `captured.headers['Content-Type']` starts with `multipart/form-data` and the body contains the field values) and retries once on 401 (tokens `['t1','t2']`, count calls == 2). Write these as full `test(...)` blocks following the exact style of the existing `postDives` tests in the same file.

- [ ] **Step 5: Run to green** — `flutter test test/core/services/divelogs/`, expect PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A lib/core/services/divelogs test/core/services/divelogs
git commit -m "feat: add divelogs.de gear, geartype, and certification endpoints"
```

---

### Task 2: Reference mappers (geartype ↔ EquipmentType, org → agency, name → level)

**Files:**
- Create: `lib/features/divelogs_sync/data/mappers/divelogs_reference_mappers.dart`
- Test: `test/features/divelogs_sync/data/mappers/divelogs_reference_mappers_test.dart`

**Interfaces:**
- Consumes: `EquipmentType`, `CertificationAgency`, `CertificationLevel` (`lib/core/constants/enums.dart`).
- Produces (all pure, top-level or static on `abstract final class DivelogsReferenceMappers`):
  - `static EquipmentType equipmentTypeForGeartypeName(String? name)` — keyword table over the lowercased geartype name, English AND German synonyms (divelogs.de's home locale): regulator/lungenautomat/atemregler → `regulator`; bcd/jacket/wing/tarierweste → `bcd`; drysuit/trocken → `drysuit`; suit/anzug/wetsuit/nass → `wetsuit`; fin/flosse → `fins`; mask/maske → `mask`; computer → `computer`; tank/cylinder/flasche → `tank`; weight/blei → `weights`; light/lamp/lampe → `light`; camera/kamera → `camera`; boot/füßling/fussling → `boots`; glove/handschuh → `gloves`; hood/haube → `hood`; knife/messer → `knife`; reel → `reel`; smb/boje → `smb`; anything else/null → `other`. Check drysuit BEFORE wetsuit (both contain "suit").
  - `static String? geartypeNameForEquipmentType(EquipmentType type, Map<int, String> geartypes)` → returns the FIRST remote geartype name whose mapped `equipmentTypeForGeartypeName` equals `type`, else null; and `static int? geartypeIdForEquipmentType(EquipmentType type, Map<int, String> geartypes)` same but returning the id.
  - `static CertificationAgency agencyForOrg(String? org)` — trim/lowercase, match against `CertificationAgency.values` by `.name` and `.displayName.toLowerCase()`; else `CertificationAgency.other`.
  - `static CertificationLevel? levelForName(String name)` — lowercased trim-match against each `CertificationLevel`'s `displayName` (verify the getter name in `enums.dart`; it is the human string used in dropdowns), else null. The original text is preserved in the certification's `name` field regardless.

- [ ] **Step 1: Write the failing test** — cover: `'Regulator'`/`'Atemregler'` → regulator; `'Trockentauchanzug'` → drysuit (not wetsuit); `'Nassanzug'` → wetsuit; `null`/`'Gadget'` → other; round-trip `geartypeIdForEquipmentType(EquipmentType.bcd, {1: 'Regulator', 2: 'Jacket'})` → 2 and → null when nothing maps; `agencyForOrg('PADI')` → padi, `'ssi '` → ssi, `'Some Club'` → other, `null` → other; `levelForName('Open Water')`/`'open water'` → the corresponding level, `'Fancy Specialty XYZ'` → null. Write the complete test file in the established style.

- [ ] **Step 2: Run red, implement, run green** — implementation is a keyword table (list of `(List<String> keywords, EquipmentType type)` records iterated in order, drysuit keywords before wetsuit) plus the two enum matchers as specified. Complete code follows directly from the Interfaces block; no I/O, no state.

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: map divelogs.de geartypes and orgs onto domain enums"
```

---

### Task 3: Pull — gear + certifications into the import payload

**Files:**
- Modify: `lib/features/universal_import/data/services/divelogs_import_service.dart`
- Modify: `lib/features/universal_import/data/services/divelogs_dive_mapper.dart` (dive maps gain `equipmentRefs`)
- Test: `test/features/universal_import/data/services/divelogs_import_service_test.dart` (extend), `test/features/universal_import/data/services/divelogs_dive_mapper_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1 endpoints/models, Task 2 mappers, `ImportEntityType.equipment`/`.certifications`, `EquipmentStatus`.
- Produces:
  - `DivelogsDiveMapper.mapDive` adds `'equipmentRefs': [for (final id in dive.gearItemIds) gearKey(id)]` when `gearItemIds` is non-empty, with `static String gearKey(String id) => 'divelogs-gear-$id';`.
  - `DivelogsImportService.fetchAllDives()` additionally fetches gear + geartypes + certifications and emits:
    - Equipment maps: `{'uddfId': DivelogsDiveMapper.gearKey(g.id), 'name': g.name, 'type': DivelogsReferenceMappers.equipmentTypeForGeartypeName(geartypes[g.geartypeId]), 'purchaseDate': g.purchaseDate, 'lastServiceDate': g.lastServiceDate, 'status': g.discardDate != null ? EquipmentStatus.retired : EquipmentStatus.active, 'isActive': g.discardDate == null}` (null-valued optional keys omitted).
    - Certification maps: `{'uddfId': 'divelogs-cert-${c.id ?? c.name}', 'name': c.name, 'agency': DivelogsReferenceMappers.agencyForOrg(c.org), 'issueDate': c.date, 'level': DivelogsReferenceMappers.levelForName(c.name)}` (null level/issueDate omitted).
    - A `DivelogsApiException` from the gear, geartypes, or certifications fetch is caught per-endpoint and becomes an `ImportWarning(severity: warning, message: 'Gear could not be fetched from divelogs.de: <msg>')` (respectively certifications); geartypes failure just means all types map to `other`. Dive fetching is never affected.

- [ ] **Step 1: Write the failing tests**

Mapper test additions: a dive with `gearItemIds: ['45', '62']` maps to `equipmentRefs: ['divelogs-gear-45', 'divelogs-gear-62']`; empty ids → no `equipmentRefs` key.

Import-service test additions (extend the existing MockClient `service(...)` harness so the handler serves `/api/dives`, `/api/gear`, `/api/geartypes`, `/api/certifications`):
- Payload contains an equipment entity with `uddfId 'divelogs-gear-45'`, `type EquipmentType.regulator` (geartypes `{1: 'Regulator'}`, gear row geartype 1), `status EquipmentStatus.active`.
- A discarded gear row (`discarddate` set) maps to `status EquipmentStatus.retired` and `isActive false`.
- Payload contains a certification entity with `agency CertificationAgency.padi` for org `'PADI'` and `issueDate DateTime.utc(2022, 6, 15)`.
- A dive whose JSON has `gearitems: [45]` produces a dive map with `equipmentRefs ['divelogs-gear-45']`.
- A 500 on `/api/gear` yields a payload that still contains the dives plus one warning mentioning gear; certifications analogous.
- Existing tests must remain green (the wizard flow test in `divelogs_fetch_step_test.dart` serves only `/api/dives` — update its MockClient to also serve empty `[]` for the three new endpoints).

- [ ] **Step 2: Run red, implement**

In `fetchAllDives`, after the dives fetch:

```dart
final warnings = <ImportWarning>[];
Map<int, String> geartypes = const {};
var gear = const <DivelogsGearItem>[];
var certs = const <DivelogsCertification>[];
try {
  geartypes = await _api.getGeartypes();
} on DivelogsApiException {
  // Types degrade to EquipmentType.other; not user-visible enough to warn.
}
try {
  gear = await _api.getGear();
} on DivelogsApiException catch (e) {
  warnings.add(ImportWarning(
    severity: ImportWarningSeverity.warning,
    message: 'Gear could not be fetched from divelogs.de: ${e.message}',
  ));
}
try {
  certs = await _api.getCertifications();
} on DivelogsApiException catch (e) {
  warnings.add(ImportWarning(
    severity: ImportWarningSeverity.warning,
    message:
        'Certifications could not be fetched from divelogs.de: ${e.message}',
  ));
}
```

then build the entity maps per the Interfaces block and merge `warnings` with the existing skipped-dives warning. Keep the method name `fetchAllDives`.

- [ ] **Step 3: Run green** — `flutter test test/features/universal_import/data/services test/features/import_wizard`, expect PASS.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: pull divelogs.de gear and certifications through the import wizard"
```

---

### Task 4: `GearCertSyncPlanner` — push-side diff

**Files:**
- Create: `lib/features/divelogs_sync/domain/services/gear_cert_sync_planner.dart`
- Test: `test/features/divelogs_sync/domain/services/gear_cert_sync_planner_test.dart`

**Interfaces:**
- Consumes: `DivelogsGearItem`/`DivelogsCertification` (Task 1), `EquipmentItem`, `Certification` domain entities.
- Produces:
  - `class GearCertSyncPlan { final List<EquipmentItem> pushGear; final List<Certification> pushCerts; final int matchedGear; final int matchedCerts; final int pullGear; final int pullCerts; final int certsMissingDate; }` (pull counts are informational — pull itself happens in the wizard; `certsMissingDate` counts local certs excluded from push for lacking the API-mandatory date).
  - `class GearCertSyncPlanner { const GearCertSyncPlanner(); GearCertSyncPlan plan({required List<DivelogsGearItem> remoteGear, required List<DivelogsCertification> remoteCerts, required List<EquipmentItem> localGear, required List<Certification> localCerts}); }`
- Matching rules (create-only, name-keyed):
  - Gear: normalized name equality (`name.trim().toLowerCase()`); one-to-one (a remote name consumes one local item). Local unmatched → `pushGear`; remote unmatched → `pullGear` count.
  - Certifications: normalized name equality AND, when BOTH sides have a date, same calendar date (`y/m/d` of the wall-clock UTC values). Local unmatched → `pushCerts`; remote unmatched → `pullCerts` count.
  - Retired/lost local gear is still matchable but never pushed (`pushGear` excludes items with `status` in `{retired, lost}` or `isActive == false`).
  - Local certs without an `issueDate` are excluded from `pushCerts` (the API requires `date`) — track them as `final int certsMissingDate;` on the plan for the summary line.

- [ ] **Step 1: Write the failing test** — cases: matched gear by case-insensitive name; local-only active gear → pushGear; retired local gear matched but never pushed; remote-only gear → pullGear count; cert matched by name+date; same name different date → both push and pull; local cert without issueDate → excluded from pushCerts and counted in certsMissingDate. Write the full test file (fixtures: `EquipmentItem(id:, name:, type: EquipmentType.regulator, status:, isActive:)`, `Certification(id:, name:, agency: CertificationAgency.padi, issueDate:, createdAt: now, updatedAt: now)`).

- [ ] **Step 2: Run red, implement** — straightforward set arithmetic over normalized-name maps (`Map<String, List<...>>` to keep one-to-one consumption); ~80 lines, pure.

- [ ] **Step 3: Run green, commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: add create-only gear and certification sync planner"
```

---

### Task 5: Gear/cert push service + `gearitems` on pushed dives

**Files:**
- Create: `lib/features/divelogs_sync/domain/services/divelogs_gear_cert_push_service.dart`
- Modify: `lib/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart`
- Modify: `lib/features/divelogs_sync/domain/services/divelogs_push_service.dart`
- Test: `test/features/divelogs_sync/domain/services/divelogs_gear_cert_push_service_test.dart`, extend `divelogs_export_mapper_test.dart` and `divelogs_push_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `class GearCertPushResult { final int gearPushed; final int certsPushed; final String? error; bool get failed => error != null; }`
  - `class DivelogsGearCertPushService { DivelogsGearCertPushService({required DivelogsApiClient api}); Future<GearCertPushResult> push({required List<EquipmentItem> gear, required List<Certification> certs, required Map<int, String> geartypes}); }` — for each gear item: `postGear({'name': item.name, if (geartypeId != null) 'geartype': geartypeId, if (item.purchaseDate != null) 'purchasedate': <yyyy-MM-dd>, if (item.lastServiceDate != null) 'last_servicedate': <yyyy-MM-dd>})` with `geartypeId = DivelogsReferenceMappers.geartypeIdForEquipmentType(item.type, geartypes)`; for each cert: `postCertification(name: cert.name, date: <yyyy-MM-dd of issueDate>, org: cert.agency == CertificationAgency.other ? null : cert.agency.displayName)`. Sequential; a `DivelogsApiException` stops the run and reports partial counts (same convergence argument as dives).
  - `DivelogsExportMapper.mapDive` gains an optional parameter: `Map<String, dynamic>? mapDive(Dive dive, {Map<String, String> remoteGearIdByName = const {}})` — when the dive has linked `equipment`, emit `'gearitems': [int ids]` for every item whose `name.trim().toLowerCase()` appears in the map (values are the remote id strings, parsed to int; unparseable ids skipped).
  - `DivelogsPushService.push` gains the same passthrough parameter `{Map<String, String> remoteGearIdByName = const {}}` and forwards it to the mapper.
  - Shared date helper: extract Phase 2's `date`/`two()` formatting into a top-level `String divelogsDate(DateTime d)` in `divelogs_export_mapper.dart` and reuse it in the gear/cert service.

- [ ] **Step 1: Write the failing tests** — gear service: pushes two gear items and one cert with correct bodies (capture requests; assert geartype id resolved via `{2: 'Jacket'}` for a `bcd` item, purchasedate formatted `yyyy-MM-dd`, cert multipart fields, org `'PADI'`); a 500 on the second call stops and reports `gearPushed == 1`. Mapper: a dive with `equipment: [EquipmentItem(name: 'Apex XTX50', ...)]` and `remoteGearIdByName: {'apex xtx50': '45'}` emits `gearitems: [45]`; without the map entry, no `gearitems` key. Write full tests in the established style.

- [ ] **Step 2: Run red, implement, run green** — `flutter test test/features/divelogs_sync`, expect PASS.

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: push gear and certifications to divelogs.de with dive gear links"
```

---

### Task 6: Sync page — gear & certifications section

**Files:**
- Modify: `lib/features/divelogs_sync/presentation/pages/divelogs_sync_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + all 10 non-English arb files
- Test: extend `test/features/divelogs_sync/presentation/pages/divelogs_sync_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4, 5; `equipmentRepositoryProvider` (`lib/features/equipment/presentation/providers/equipment_providers.dart`, `getAllEquipment({diverId})`), `certificationRepositoryProvider` (`lib/features/certifications/presentation/providers/certification_providers.dart`, `getAllCertifications({diverId})`).
- Produces: the page's `_compare()` additionally fetches remote gear/certs/geartypes and local equipment/certs, stores `GearCertSyncPlan? _gearCertPlan` and `Map<int, String> _geartypes`; `_push()` fetches remote gear once beforehand and passes `remoteGearIdByName` (built as `{g.name.trim().toLowerCase(): g.id}`) into `DivelogsPushService.push`; a new `_pushGearCerts()` runs `DivelogsGearCertPushService` then re-runs `_compare()`.

Page behavior additions (plan view):
- A "Gear & certifications" section after the dive sections showing: matched counts line, pull counts line (informational, wizard link already exists above), and — when `pushGear`/`pushCerts` are non-empty — a summary line "Push: N gear items, M certifications" plus a `FilledButton.tonal` "Sync gear & certifications" invoking `_pushGearCerts()`. When `certsMissingDate > 0`, a caption noting how many certifications need an issue date before they can be pushed.
- Gear/cert fetch failures during `_compare` must not break the dive compare: wrap in try/catch and render the section with an inline error line instead.

New l10n keys (en; translate into all 10 non-English locales with proper diacritics, same insertion-script approach; placeholders typed like Phase 2's):

```json
"divelogsSync_gearCertHeader": "Gear & certifications",
"divelogsSync_gearCertMatched": "{gear} gear items and {certs} certifications already in sync",
"divelogsSync_gearCertPush": "Push: {gear} gear items, {certs} certifications",
"divelogsSync_gearCertPushButton": "Sync gear & certifications",
"divelogsSync_gearCertPushDone": "Pushed {gear} gear items and {certs} certifications.",
"divelogsSync_gearCertPushFailed": "Gear/certification push stopped: {error}",
"divelogsSync_certsMissingDate": "{count} certifications need an issue date before they can be pushed.",
"divelogsSync_gearCertUnavailable": "Gear and certifications could not be compared: {error}"
```

- [ ] **Step 1: Extend the widget test** — the existing MockClient handlers gain `/api/gear`, `/api/geartypes`, `/api/certifications` routes. Add: (a) compare shows the gear/cert section with push counts when a local-only equipment item + cert exist (seed via `EquipmentRepository().createEquipment(...)` and `CertificationRepository().createCertification(...)` with `diverId: 'diver-1'` before pumping); (b) tapping "Sync gear & certifications" POSTs to `/api/gear` and `/api/certifications` and re-compares. Write the tests fully, following the file's existing seeding style.

- [ ] **Step 2: Run red, implement page + l10n, `flutter gen-l10n`, run green** — `flutter test test/features/divelogs_sync test/l10n && flutter analyze`.

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: sync gear and certifications from the divelogs.de sync page"
```

---

### Task 7: Verification sweep

- [ ] **Step 1:** `dart format . && flutter analyze` — no changes, no issues.
- [ ] **Step 2:** `flutter test test/core/services/divelogs test/features/divelogs_sync test/features/import_wizard test/features/universal_import/data/services` — all PASS.
- [ ] **Step 3:** Full suite in the background. Known pre-existing flake: isolated backup/setup-wizard failures that pass in isolation (see memory `flaky-backup-tests-full-suite`) — verify any failure against that pattern before treating it as real.
- [ ] **Step 4:** Commit any fixes; do not push (user-triggered step; branch carries PR #603).

## Deferred (do NOT build now)

- Pictures/scans (Phase 4) — `scans` on certifications and `POST /pictures` stay untouched.
- Gear service records/schedules mapping (`servicedives`/`servicemonths`) — Submersion's service tracking is richer; create-only name-level sync only.
- Per-item push checkboxes for gear/certs (deliberate simplification; revisit on user feedback).

## Open assumptions (confirm with Rainer, do not block)

- `GET /gear` rows carry `id` + `name`; `GET /geartypes` returns an id/name list; `POST /gear` returns no id (we re-fetch after push).
- `gearitems` on `POST /dives` accepts the numeric ids from `GET /gear`.
- Certification `org` free-text matches common agency names.
