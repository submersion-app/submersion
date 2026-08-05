# divelogs.de Sync — Phase 2 (Push Dives + Compare/Review Sync Page) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users push local dives to divelogs.de and see a cheap two-way compare ("N to pull / M to push") on a dedicated sync page reachable from the Connected Accounts roster.

**Architecture:** A stateless planner diffs the remote `GET /divelist` against local `DiveSummary` rows using the #494 time-gated matcher; unmatched remote dives are pull candidates, unmatched local dives are push candidates. Push is a lossy projection (`DivelogsExportMapper`) committed via chunked `POST /dives`. Pull continues to go through the Phase 1 import wizard (which already has fetch + dedup + review); the sync page links to it rather than duplicating that flow.

**Tech Stack:** Flutter/Dart, Riverpod (plain), `package:http` + `MockClient`, Phase 1's `DivelogsApiClient`/`DivelogsAuthManager`/`DivelogsAccountAdapter`.

**Spec:** `docs/superpowers/specs/2026-07-16-divelogs-de-sync-design.md` (Phase 2 sections: push path, sync page).

**Stacking:** builds on branch `worktree-divelogs-sync` (Phase 1, PR #603). If #603 has merged, branch from main instead and adjust nothing else.

## Global Constraints

- Same as Phase 1: metric domain units; wall-clock timestamps represented as UTC (`DateTime.utc` / parse with `Z` suffix); `dart format .` clean before every commit; no emojis; no Co-Authored-By or session URL in commits; new user-facing strings into `app_en.arb` AND all 10 non-English locales, then `flutter gen-l10n`; run tests per-file; push with `--no-verify` (hook checks main tree) after in-worktree verification.
- API mandatory fields for a pushed dive: `date`, `time`, `duration` (seconds), `maxdepth`. A local dive that cannot produce all four is UNPUSHABLE and is excluded with a count shown to the user, never sent.
- Stateless create-only model: push never updates or deletes; nothing is written back onto local dives after a push. Re-running compare after a push must show the pushed dives as matched.
- `GET /divelist`'s response shape is unconfirmed (spec open question 3, asked of Rainer). The divelist model must parse tolerantly and the planner must degrade to time-only matching when depth/duration are absent. Revisit when Rainer answers.
- Chunk size for `POST /dives`: 50 dives per request (spec assumption, open question 5), with a 200 ms courtesy delay between chunks.

---

### Task 1: Divelist model + API client `getDivelist()` / `postDives()`

**Files:**
- Modify: `lib/core/services/divelogs/divelogs_models.dart`
- Modify: `lib/core/services/divelogs/divelogs_api_client.dart`
- Test: `test/core/services/divelogs/divelogs_models_test.dart` (extend)
- Test: `test/core/services/divelogs/divelogs_api_client_test.dart` (extend)

**Interfaces:**
- Consumes: Phase 1's `DivelogsApiClient` internals (`_get`, `_decode`, `_baseUri`, 401-retry loop).
- Produces:
  - `class DivelogsDivelistEntry { final String id; final DateTime dateTime; final int? durationSeconds; final double? maxDepth; static DivelogsDivelistEntry? fromJson(Map<String, dynamic> json); }` — returns null (not throws) when id or date/time are unusable; `dateTime` is wall-clock UTC.
  - `class DivelogsDivelistResult { final List<DivelogsDivelistEntry> entries; final int skippedCount; }`
  - On `DivelogsApiClient`: `Future<DivelogsDivelistResult> getDivelist()` and `Future<void> postDives(List<Map<String, dynamic>> dives)` (throws `DivelogsApiException` on non-2xx; one 401 retry like `_get`).

- [ ] **Step 1: Write the failing model tests**

Append to `divelogs_models_test.dart`:

```dart
group('DivelogsDivelistEntry', () {
  test('parses id, date/time (wall-clock UTC), duration, maxdepth', () {
    final entry = DivelogsDivelistEntry.fromJson({
      'id': 4711,
      'date': '2022-09-03',
      'time': '14:42:00',
      'duration': 2808,
      'maxdepth': 12,
    })!;
    expect(entry.id, '4711');
    expect(entry.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
    expect(entry.durationSeconds, 2808);
    expect(entry.maxDepth, 12.0);
  });

  test('tolerates missing duration and maxdepth', () {
    final entry = DivelogsDivelistEntry.fromJson({
      'id': '9',
      'date': '2022-09-03',
      'time': '14:42:00',
    })!;
    expect(entry.durationSeconds, isNull);
    expect(entry.maxDepth, isNull);
  });

  test('accepts a combined datetime field as fallback', () {
    final entry = DivelogsDivelistEntry.fromJson({
      'id': 9,
      'datetime': '2022-09-03 14:42:00',
    })!;
    expect(entry.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
  });

  test('returns null when id or date is unusable', () {
    expect(
      DivelogsDivelistEntry.fromJson({'date': '2022-09-03'}),
      isNull,
    );
    expect(DivelogsDivelistEntry.fromJson({'id': 1}), isNull);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/divelogs/divelogs_models_test.dart`
Expected: FAIL — `DivelogsDivelistEntry` undefined.

- [ ] **Step 3: Implement the model**

Append to `divelogs_models.dart`:

```dart
/// One row of GET /divelist — the cheap compare key set. The endpoint's
/// exact shape is undocumented (spec open question 3), so parsing is
/// tolerant: unusable rows yield null and are counted, never thrown.
class DivelogsDivelistEntry {
  final String id;
  final DateTime dateTime; // wall-clock UTC, same convention as DivelogsDive
  final int? durationSeconds;
  final double? maxDepth;

  const DivelogsDivelistEntry({
    required this.id,
    required this.dateTime,
    this.durationSeconds,
    this.maxDepth,
  });

  static DivelogsDivelistEntry? fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['dive_id'];
    if (rawId == null) return null;

    DateTime? dateTime;
    final date = _asNonEmptyString(json['date']);
    if (date != null) {
      final time = _asNonEmptyString(json['time']) ?? '00:00:00';
      dateTime = DateTime.tryParse('${date}T${time}Z');
    } else {
      final combined = _asNonEmptyString(json['datetime']);
      if (combined != null) {
        dateTime = DateTime.tryParse('${combined.replaceFirst(' ', 'T')}Z');
      }
    }
    if (dateTime == null) return null;

    return DivelogsDivelistEntry(
      id: '$rawId',
      dateTime: dateTime,
      durationSeconds: _asInt(json['duration']),
      maxDepth: _asDouble(json['maxdepth']),
    );
  }
}

class DivelogsDivelistResult {
  final List<DivelogsDivelistEntry> entries;
  final int skippedCount;

  const DivelogsDivelistResult({required this.entries, this.skippedCount = 0});
}
```

- [ ] **Step 4: Run model tests to verify pass**

Run: `flutter test test/core/services/divelogs/divelogs_models_test.dart`
Expected: PASS.

- [ ] **Step 5: Write failing client tests**

Append to `divelogs_api_client_test.dart` (reuse the existing `client(...)` helper):

```dart
test('getDivelist parses array body and counts unusable rows', () async {
  final api = client(
    (req) async {
      expect(req.url.path, '/api/divelist');
      return http.Response(
        jsonEncode([
          {'id': 1, 'date': '2022-09-03', 'time': '10:00:00'},
          {'no_id': true},
        ]),
        200,
      );
    },
  );
  final result = await api.getDivelist();
  expect(result.entries, hasLength(1));
  expect(result.entries.single.id, '1');
  expect(result.skippedCount, 1);
});

test('getDivelist tolerates object body with dives/divelist key', () async {
  final api = client(
    (req) async => http.Response(
      jsonEncode({
        'divelist': [
          {'id': 1, 'date': '2022-09-03', 'time': '10:00:00'},
        ],
      }),
      200,
    ),
  );
  expect((await api.getDivelist()).entries, hasLength(1));
});

test('postDives sends JSON array body with bearer header', () async {
  late http.Request captured;
  final api = client((req) async {
    captured = req;
    return http.Response('{"success": true}', 200);
  });
  await api.postDives([
    {'date': '2022-09-03', 'time': '10:00:00', 'duration': 60, 'maxdepth': 5},
  ]);
  expect(captured.method, 'POST');
  expect(captured.url.toString(), 'https://divelogs.de/api/dives');
  expect(captured.headers['Authorization'], 'Bearer t1');
  expect(captured.headers['Content-Type'], startsWith('application/json'));
  final body = jsonDecode(captured.body) as List;
  expect(body, hasLength(1));
});

test('postDives retries once on 401 then succeeds', () async {
  var calls = 0;
  final api = client(
    (req) async {
      calls++;
      if (req.headers['Authorization'] == 'Bearer t1') {
        return http.Response('', 401);
      }
      return http.Response('{}', 200);
    },
    tokens: ['t1', 't2'],
  );
  await api.postDives([
    {'duration': 60},
  ]);
  expect(calls, 2);
});

test('postDives throws DivelogsApiException on 400', () async {
  final api = client((req) async => http.Response('bad', 400));
  expect(
    () => api.postDives([<String, dynamic>{}]),
    throwsA(
      isA<DivelogsApiException>().having((e) => e.statusCode, 'status', 400),
    ),
  );
});
```

- [ ] **Step 6: Run to verify failure, then implement client methods**

Run: `flutter test test/core/services/divelogs/divelogs_api_client_test.dart` — expect FAIL. Then in `divelogs_api_client.dart`:

1. Generalize the request loop: rename `_get(String path)`'s body into
   `_send(String path, {String method = 'GET', Object? jsonBody})` and keep
   `_get` as `_send(path)`. The loop body changes only in how the request is
   issued:

```dart
Future<http.Response> _send(
  String path, {
  String method = 'GET',
  Object? jsonBody,
}) async {
  var authRetried = false;
  while (true) {
    final token = await _getBearerToken();
    final uri = _baseUri.replace(path: '${_baseUri.path}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      if (jsonBody != null) 'Content-Type': 'application/json',
    };
    final http.Response response;
    try {
      response = method == 'POST'
          ? await _http.post(uri, headers: headers, body: jsonEncode(jsonBody))
          : await _http.get(uri, headers: headers);
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
    return response;
  }
}

Future<http.Response> _get(String path) => _send(path);
```

2. Add the two endpoints:

```dart
Future<DivelogsDivelistResult> getDivelist() async {
  final response = await _get('/divelist');
  final decoded = _decode(response.body, '/divelist');
  final List<dynamic> rows;
  if (decoded is List) {
    rows = decoded;
  } else if (decoded is Map && decoded['divelist'] is List) {
    rows = decoded['divelist'] as List;
  } else if (decoded is Map && decoded['dives'] is List) {
    rows = decoded['dives'] as List;
  } else {
    throw const DivelogsApiException(0, 'Unexpected /divelist response');
  }
  final entries = <DivelogsDivelistEntry>[];
  var skipped = 0;
  for (final row in rows) {
    final entry = row is Map
        ? DivelogsDivelistEntry.fromJson(Map<String, dynamic>.from(row))
        : null;
    if (entry == null) {
      skipped++;
    } else {
      entries.add(entry);
    }
  }
  return DivelogsDivelistResult(entries: entries, skippedCount: skipped);
}

/// Bulk-create dives (create-only; the caller chunks).
Future<void> postDives(List<Map<String, dynamic>> dives) async {
  await _send('/dives', method: 'POST', jsonBody: dives);
}
```

- [ ] **Step 7: Run all divelogs service tests**

Run: `flutter test test/core/services/divelogs/`
Expected: PASS (all Phase 1 tests still green plus the new ones).

- [ ] **Step 8: Commit**

```bash
dart format .
git add -A lib/core/services/divelogs test/core/services/divelogs
git commit -m "feat: add divelogs.de divelist and bulk dive-create endpoints"
```

---

### Task 2: `DivelogsExportMapper` — domain `Dive` to divelogs JSON

**Files:**
- Create: `lib/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart`
- Test: `test/features/divelogs_sync/data/mappers/divelogs_export_mapper_test.dart`

**Interfaces:**
- Consumes: domain `Dive`/`DiveTank`/`GasMix`/`DiveProfilePoint` (`lib/features/dive_log/domain/entities/dive.dart`), `Dive.effectiveEntryTime` (`DateTime`), `Dive.effectiveRuntime` (`Duration?`).
- Produces: `class DivelogsExportMapper { const DivelogsExportMapper(); Map<String, dynamic>? mapDive(Dive dive); }` — null when the API's mandatory fields (`date`/`time`/`duration`/`maxdepth`) cannot be produced. The lossy projection is intentional (spec: push path).

Projection rules (all metric, matching the API schema):
- `date` = `yyyy-MM-dd`, `time` = `HH:mm:ss` from `dive.effectiveEntryTime` (wall-clock; format the UTC components directly, no timezone conversion).
- `duration` = `dive.effectiveRuntime?.inSeconds` — if null/zero, the dive is unmappable (return null).
- `maxdepth` = `dive.maxDepth ?? dive.calculateMaxDepthFromProfile()` — if null, return null.
- `meandepth` = `dive.avgDepth` when > 0.
- `sampledata`/`samplerate`: only when the profile has 2+ points AND the timestamp deltas are uniform (every `profile[i+1].timestamp - profile[i].timestamp` equals the first delta, delta > 0). Emit `samplerate` = delta and one entry per point: `{'d': depth, 't': temperature}` when the point has temperature, else the bare depth number. Non-uniform profiles omit sampledata entirely (divelogs assumes a fixed rate).
- `tanks` = one map per `DiveTank`: `o2`/`he` from `gasMix`, `start_pressure`/`end_pressure`/`vol`/`wp` from `startPressure`/`endPressure`/`volume`/`workingPressure` (each only when non-null and, for vol/wp, > 0), `tankname` from `name` when non-null.
- `buddy` = `dive.buddy` when non-null; `divesite` = `dive.site?.name`; `lat`/`lng` from `dive.site?.location ?? dive.entryLocation` (both coordinates or neither); `location` = site `country`/`region` joined with ", " (skipping nulls; omit when empty).
- `notes` = `dive.notes` when non-empty; `airtemp` = `dive.airTemp`; `depthtemp` = `dive.waterTemp`; `weights` = `dive.weightAmount` when > 0; `surface_interval` = `dive.surfaceInterval?.inSeconds` when > 0; `dc_model` = `dive.diveComputerModel`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart';

void main() {
  const mapper = DivelogsExportMapper();

  Dive dive({
    Duration? runtime = const Duration(seconds: 2808),
    double? maxDepth = 18.5,
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: 'd1',
    dateTime: DateTime.utc(2022, 9, 3, 14, 42, 30),
    entryTime: DateTime.utc(2022, 9, 3, 14, 42, 30),
    runtime: runtime,
    maxDepth: maxDepth,
    avgDepth: 7.9,
    notes: 'nice dive',
    buddy: 'Buddy',
    airTemp: 28,
    waterTemp: 21,
    weightAmount: 4,
    surfaceInterval: const Duration(hours: 1),
    diveComputerModel: 'Suunto D6',
    profile: profile,
    site: const DiveSite(
      id: 's1',
      name: 'Shinenead',
      location: GeoPoint(24.6, 35.1),
      country: 'Egypt',
      region: 'Red Sea',
    ),
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 12,
        workingPressure: 200,
        startPressure: 214.5,
        endPressure: 103,
        gasMix: GasMix(o2: 28),
        name: 'Main',
      ),
    ],
  );

  test('maps mandatory and optional fields to API schema keys', () {
    final json = mapper.mapDive(dive())!;
    expect(json['date'], '2022-09-03');
    expect(json['time'], '14:42:30');
    expect(json['duration'], 2808);
    expect(json['maxdepth'], 18.5);
    expect(json['meandepth'], 7.9);
    expect(json['buddy'], 'Buddy');
    expect(json['divesite'], 'Shinenead');
    expect(json['lat'], 24.6);
    expect(json['lng'], 35.1);
    expect(json['location'], 'Egypt, Red Sea');
    expect(json['notes'], 'nice dive');
    expect(json['airtemp'], 28);
    expect(json['depthtemp'], 21);
    expect(json['weights'], 4);
    expect(json['surface_interval'], 3600);
    expect(json['dc_model'], 'Suunto D6');
    final tank = (json['tanks'] as List).single as Map<String, dynamic>;
    expect(tank['o2'], 28.0);
    expect(tank['he'], 0.0);
    expect(tank['start_pressure'], 214.5);
    expect(tank['end_pressure'], 103);
    expect(tank['vol'], 12);
    expect(tank['wp'], 200);
    expect(tank['tankname'], 'Main');
  });

  test('emits uniform profiles as sampledata with samplerate', () {
    final json = mapper.mapDive(
      dive(
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 1, temperature: 13),
          DiveProfilePoint(timestamp: 10, depth: 10),
          DiveProfilePoint(timestamp: 20, depth: 5),
        ],
      ),
    )!;
    expect(json['samplerate'], 10);
    final samples = json['sampledata'] as List;
    expect(samples[0], {'d': 1.0, 't': 13.0});
    expect(samples[1], 10.0);
    expect(samples[2], 5.0);
  });

  test('omits sampledata for non-uniform profiles', () {
    final json = mapper.mapDive(
      dive(
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 1),
          DiveProfilePoint(timestamp: 7, depth: 10),
          DiveProfilePoint(timestamp: 20, depth: 5),
        ],
      ),
    )!;
    expect(json.containsKey('sampledata'), isFalse);
    expect(json.containsKey('samplerate'), isFalse);
  });

  test('returns null when duration or maxdepth cannot be produced', () {
    expect(mapper.mapDive(dive(runtime: null)), isNull);
    expect(mapper.mapDive(dive(maxDepth: null)), isNull);
  });

  test('falls back to profile max depth when maxDepth is null', () {
    final json = mapper.mapDive(
      dive(
        maxDepth: null,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 3),
          DiveProfilePoint(timestamp: 10, depth: 9.5),
        ],
      ),
    );
    expect(json, isNotNull);
    expect(json!['maxdepth'], 9.5);
  });
}
```

(Adjust the `Dive`/`DiveSite` fixture construction if any named parameter differs — both constructors were verified in Phase 1; `DiveSite` requires `id` and `name`, `GeoPoint` is positional `(lat, lng)`.)

Note: `dive(runtime: null)` still has an empty profile and no `bottomTime`/`exitTime`, so `effectiveRuntime` is null — that is what makes it unmappable.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divelogs_sync/data/mappers/divelogs_export_mapper_test.dart`
Expected: FAIL — mapper missing.

- [ ] **Step 3: Implement the mapper**

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Projects a domain Dive onto the divelogs.de dive JSON schema.
///
/// Lossy by design (spec: push path): one profile channel, tanks, site
/// name + GPS, buddy string, notes, temps, weights. Returns null when the
/// API's mandatory fields (date/time/duration/maxdepth) cannot be
/// produced; the caller reports such dives as skipped.
class DivelogsExportMapper {
  const DivelogsExportMapper();

  Map<String, dynamic>? mapDive(Dive dive) {
    final entry = dive.effectiveEntryTime;
    final durationSeconds = dive.effectiveRuntime?.inSeconds;
    final maxDepth = dive.maxDepth ?? dive.calculateMaxDepthFromProfile();
    if (durationSeconds == null || durationSeconds <= 0 || maxDepth == null) {
      return null;
    }

    String two(int v) => v.toString().padLeft(2, '0');
    final json = <String, dynamic>{
      'date': '${entry.year}-${two(entry.month)}-${two(entry.day)}',
      'time': '${two(entry.hour)}:${two(entry.minute)}:${two(entry.second)}',
      'duration': durationSeconds,
      'maxdepth': maxDepth,
    };

    final avg = dive.avgDepth;
    if (avg != null && avg > 0) json['meandepth'] = avg;
    if (dive.buddy != null) json['buddy'] = dive.buddy;
    final siteName = dive.site?.name;
    if (siteName != null && siteName.isNotEmpty) json['divesite'] = siteName;
    final location = dive.site?.location ?? dive.entryLocation;
    if (location != null) {
      json['lat'] = location.latitude;
      json['lng'] = location.longitude;
    }
    final locality = [
      dive.site?.country,
      dive.site?.region,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    if (locality.isNotEmpty) json['location'] = locality;
    if (dive.notes.isNotEmpty) json['notes'] = dive.notes;
    if (dive.airTemp != null) json['airtemp'] = dive.airTemp;
    if (dive.waterTemp != null) json['depthtemp'] = dive.waterTemp;
    final weight = dive.weightAmount;
    if (weight != null && weight > 0) json['weights'] = weight;
    final surfaceInterval = dive.surfaceInterval?.inSeconds;
    if (surfaceInterval != null && surfaceInterval > 0) {
      json['surface_interval'] = surfaceInterval;
    }
    if (dive.diveComputerModel != null) {
      json['dc_model'] = dive.diveComputerModel;
    }

    final tanks = dive.tanks
        .map(
          (t) => <String, dynamic>{
            'o2': t.gasMix.o2,
            'he': t.gasMix.he,
            if (t.startPressure != null) 'start_pressure': t.startPressure,
            if (t.endPressure != null) 'end_pressure': t.endPressure,
            if (t.volume != null && t.volume! > 0) 'vol': t.volume,
            if (t.workingPressure != null && t.workingPressure! > 0)
              'wp': t.workingPressure,
            if (t.name != null && t.name!.isNotEmpty) 'tankname': t.name,
          },
        )
        .toList();
    if (tanks.isNotEmpty) json['tanks'] = tanks;

    _addProfile(json, dive.profile);
    return json;
  }

  /// divelogs sampledata assumes one fixed sample rate, so only uniform
  /// profiles are exported; anything else is omitted rather than distorted.
  void _addProfile(Map<String, dynamic> json, List<DiveProfilePoint> profile) {
    if (profile.length < 2) return;
    final delta = profile[1].timestamp - profile[0].timestamp;
    if (delta <= 0) return;
    for (var i = 1; i < profile.length; i++) {
      if (profile[i].timestamp - profile[i - 1].timestamp != delta) return;
    }
    json['samplerate'] = delta;
    json['sampledata'] = [
      for (final point in profile)
        if (point.temperature != null)
          {'d': point.depth, 't': point.temperature}
        else
          point.depth,
    ];
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/divelogs_sync/data/mappers/divelogs_export_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: project domain dives onto the divelogs.de push schema"
```

---

### Task 3: `DivelogsSyncPlanner` — the two-way diff

**Files:**
- Create: `lib/features/divelogs_sync/domain/services/divelogs_sync_planner.dart`
- Test: `test/features/divelogs_sync/domain/services/divelogs_sync_planner_test.dart`

**Interfaces:**
- Consumes: `DivelogsDivelistEntry` (Task 1), `DiveSummary` (`lib/features/dive_log/domain/entities/dive_summary.dart` — fields `id`, `diveNumber`, `name`, `dateTime`, `entryTime`, `maxDepth`, `bottomTime`, `runtime`), `DiveMatcher` (`lib/features/dive_import/domain/services/dive_matcher.dart`).
- Produces:
  - `class DivelogsSyncPlan { final List<DivelogsDivelistEntry> pullCandidates; final List<DiveSummary> pushCandidates; final int matchedCount; }`
  - `class DivelogsSyncPlanner { const DivelogsSyncPlanner({DiveMatcher matcher = const DiveMatcher()}); DivelogsSyncPlan plan({required List<DivelogsDivelistEntry> remote, required List<DiveSummary> local}); }` — pure function, no I/O.

Matching rules (deterministic, documented in code):
- Hard time gate: a remote entry and local summary can only match when their wall-clock times differ by at most 15 minutes (`DiveMatcher`'s zero band). Local time = `entryTime ?? dateTime`; local duration = `runtime ?? bottomTime`.
- When BOTH sides have depth and duration, score with `matcher.calculateMatchScore` and require `matcher.isPossibleDuplicate(score)` (>= 0.5).
- When either side lacks depth or duration (unconfirmed `/divelist` shape), a time-gate pass alone is a match — degraded but safe, since 15 minutes of overlap on the same account almost always means the same dive.
- One-to-one greedy matching: process remote entries in ascending time order; each takes its best-scoring (or nearest-in-time, for degraded matches) unmatched local summary.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_sync_planner.dart';

void main() {
  const planner = DivelogsSyncPlanner();

  DivelogsDivelistEntry remote(
    String id,
    DateTime at, {
    int? duration = 2808,
    double? depth = 12,
  }) => DivelogsDivelistEntry(
    id: id,
    dateTime: at,
    durationSeconds: duration,
    maxDepth: depth,
  );

  DiveSummary local(
    String id,
    DateTime at, {
    Duration? runtime = const Duration(seconds: 2808),
    double? depth = 12,
  }) => DiveSummary(
    id: id,
    dateTime: at,
    entryTime: at,
    runtime: runtime,
    maxDepth: depth,
    isFavorite: false,
    diveTypeIds: const [],
    tags: const [],
    sortTimestamp: at.millisecondsSinceEpoch,
  );

  final t0 = DateTime.utc(2022, 9, 3, 14, 42);

  test('matched pairs are neither pulled nor pushed', () {
    final plan = planner.plan(
      remote: [remote('r1', t0)],
      local: [local('l1', t0)],
    );
    expect(plan.pullCandidates, isEmpty);
    expect(plan.pushCandidates, isEmpty);
    expect(plan.matchedCount, 1);
  });

  test('remote-only dives are pull candidates, local-only are push', () {
    final plan = planner.plan(
      remote: [
        remote('r1', t0),
        remote('r2', t0.add(const Duration(days: 1))),
      ],
      local: [
        local('l1', t0),
        local('l2', t0.add(const Duration(days: 2))),
      ],
    );
    expect(plan.pullCandidates.map((e) => e.id), ['r2']);
    expect(plan.pushCandidates.map((s) => s.id), ['l2']);
    expect(plan.matchedCount, 1);
  });

  test('time gate: 20 minutes apart is not a match', () {
    final plan = planner.plan(
      remote: [remote('r1', t0)],
      local: [local('l1', t0.add(const Duration(minutes: 20)))],
    );
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, hasLength(1));
  });

  test('same time but wildly different depth/duration is not a match', () {
    final plan = planner.plan(
      remote: [remote('r1', t0, duration: 2808, depth: 40)],
      local: [local('l1', t0, runtime: const Duration(minutes: 5), depth: 3)],
    );
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, hasLength(1));
  });

  test('degraded match: divelist without depth/duration matches on time', () {
    final plan = planner.plan(
      remote: [remote('r1', t0, duration: null, depth: null)],
      local: [local('l1', t0.add(const Duration(minutes: 5)))],
    );
    expect(plan.pullCandidates, isEmpty);
    expect(plan.pushCandidates, isEmpty);
    expect(plan.matchedCount, 1);
  });

  test('one-to-one: a single local dive cannot match two remote entries', () {
    final plan = planner.plan(
      remote: [remote('r1', t0), remote('r2', t0.add(const Duration(minutes: 3)))],
      local: [local('l1', t0)],
    );
    expect(plan.matchedCount, 1);
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, isEmpty);
  });
}
```

(If `DiveSummary`'s constructor requires additional parameters, supply the minimal defaults its declaration shows — it is a plain data class at `dive_summary.dart:11-56`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divelogs_sync/domain/services/divelogs_sync_planner_test.dart`
Expected: FAIL — planner missing.

- [ ] **Step 3: Implement the planner**

```dart
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Result of comparing the remote divelist with local dive summaries.
class DivelogsSyncPlan {
  final List<DivelogsDivelistEntry> pullCandidates;
  final List<DiveSummary> pushCandidates;
  final int matchedCount;

  const DivelogsSyncPlan({
    required this.pullCandidates,
    required this.pushCandidates,
    required this.matchedCount,
  });
}

/// Stateless two-way diff for the create-only sync model (spec: sync
/// engine). Matching is time-gated (15 min, DiveMatcher's zero band) with
/// depth/duration refinement when both sides carry them; the undocumented
/// /divelist shape may omit depth/duration, in which case the time gate
/// alone decides (degraded but safe on a single user's account).
class DivelogsSyncPlanner {
  const DivelogsSyncPlanner({this.matcher = const DiveMatcher()});

  final DiveMatcher matcher;

  static const Duration _timeGate = Duration(minutes: 15);

  DivelogsSyncPlan plan({
    required List<DivelogsDivelistEntry> remote,
    required List<DiveSummary> local,
  }) {
    final sortedRemote = [...remote]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final unmatchedLocal = [...local];
    final pull = <DivelogsDivelistEntry>[];
    var matched = 0;

    for (final entry in sortedRemote) {
      DiveSummary? best;
      var bestKey = double.negativeInfinity;
      for (final summary in unmatchedLocal) {
        final key = _matchKey(entry, summary);
        if (key != null && key > bestKey) {
          best = summary;
          bestKey = key;
        }
      }
      if (best != null) {
        unmatchedLocal.remove(best);
        matched++;
      } else {
        pull.add(entry);
      }
    }

    return DivelogsSyncPlan(
      pullCandidates: pull,
      pushCandidates: unmatchedLocal,
      matchedCount: matched,
    );
  }

  /// Returns a comparable match quality (higher is better), or null when
  /// the pair does not match.
  double? _matchKey(DivelogsDivelistEntry entry, DiveSummary summary) {
    final localTime = summary.entryTime ?? summary.dateTime;
    final timeDiff = entry.dateTime.difference(localTime).abs();
    if (timeDiff > _timeGate) return null;

    final localDuration = summary.runtime ?? summary.bottomTime;
    final hasFullData =
        entry.durationSeconds != null &&
        entry.maxDepth != null &&
        localDuration != null &&
        summary.maxDepth != null;
    if (!hasFullData) {
      // Degraded: time-gate only. Rank by time proximity below any real
      // score so scored matches win when available.
      return -timeDiff.inSeconds.toDouble() / _timeGate.inSeconds;
    }

    final score = matcher.calculateMatchScore(
      wearableStartTime: entry.dateTime,
      wearableMaxDepth: entry.maxDepth!,
      wearableDurationSeconds: entry.durationSeconds!,
      existingStartTime: localTime,
      existingMaxDepth: summary.maxDepth!,
      existingDurationSeconds: localDuration.inSeconds,
    );
    return matcher.isPossibleDuplicate(score) ? score : null;
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/divelogs_sync/domain/services/divelogs_sync_planner_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: add stateless two-way divelogs.de sync planner"
```

---

### Task 4: `DivelogsPushService` — chunked create-only push

**Files:**
- Create: `lib/features/divelogs_sync/domain/services/divelogs_push_service.dart`
- Test: `test/features/divelogs_sync/domain/services/divelogs_push_service_test.dart`

**Interfaces:**
- Consumes: `DivelogsApiClient.postDives` (Task 1), `DivelogsExportMapper` (Task 2), domain `Dive`.
- Produces:
  - `class DivelogsPushResult { final int pushed; final int skippedUnmappable; final String? error; bool get failed => error != null; }`
  - `class DivelogsPushService { DivelogsPushService({required DivelogsApiClient api, DivelogsExportMapper mapper = const DivelogsExportMapper(), int chunkSize = 50, Future<void> Function(Duration)? delay}); Future<DivelogsPushResult> push(List<Dive> dives, {void Function(int done, int total)? onProgress}); }`
- Behavior: maps all dives (unmappable ones counted, never sent); sends chunks of `chunkSize` via `postDives` with a 200 ms courtesy delay between chunks (injectable `delay` for tests, default `Future.delayed`); `onProgress(done, total)` after each chunk (counts mapped dives); a `DivelogsApiException` stops the push and reports how many were already pushed plus the error message — no rollback (create-only + stateless compare make re-runs converge).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_push_service.dart';

void main() {
  Dive dive(int n, {Duration? runtime = const Duration(minutes: 45)}) => Dive(
    id: 'd$n',
    dateTime: DateTime.utc(2022, 9, n + 1, 10),
    entryTime: DateTime.utc(2022, 9, n + 1, 10),
    runtime: runtime,
    maxDepth: 10.0 + n,
  );

  DivelogsApiClient api(Future<http.Response> Function(http.Request) handler) =>
      DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient(handler),
      );

  DivelogsPushService service(
    DivelogsApiClient client, {
    int chunkSize = 2,
  }) => DivelogsPushService(
    api: client,
    chunkSize: chunkSize,
    delay: (_) async {},
  );

  test('chunks dives and reports progress', () async {
    final batches = <int>[];
    final progress = <(int, int)>[];
    final result = await service(
      api((req) async {
        batches.add((jsonDecode(req.body) as List).length);
        return http.Response('{}', 200);
      }),
    ).push(
      [dive(1), dive(2), dive(3)],
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(batches, [2, 1]);
    expect(progress, [(2, 3), (3, 3)]);
    expect(result.pushed, 3);
    expect(result.skippedUnmappable, 0);
    expect(result.failed, isFalse);
  });

  test('unmappable dives are counted and not sent', () async {
    var sent = 0;
    final result = await service(
      api((req) async {
        sent += (jsonDecode(req.body) as List).length;
        return http.Response('{}', 200);
      }),
    ).push([dive(1), dive(2, runtime: null)]);
    expect(sent, 1);
    expect(result.pushed, 1);
    expect(result.skippedUnmappable, 1);
  });

  test('a failed chunk stops the push and reports partial progress',
      () async {
    var call = 0;
    final result = await service(
      api((req) async {
        call++;
        return call == 1 ? http.Response('{}', 200) : http.Response('', 500);
      }),
    ).push([dive(1), dive(2), dive(3)]);
    expect(result.pushed, 2);
    expect(result.failed, isTrue);
    expect(result.error, contains('500'));
  });

  test('empty mapped list makes no network calls', () async {
    final result = await service(
      api((req) async => fail('no call expected')),
    ).push([dive(1, runtime: null)]);
    expect(result.pushed, 0);
    expect(result.skippedUnmappable, 1);
  });
}
```

- [ ] **Step 2: Run to verify failure, then implement**

Run: `flutter test test/features/divelogs_sync/domain/services/divelogs_push_service_test.dart` — expect FAIL. Then:

```dart
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart';

class DivelogsPushResult {
  final int pushed;
  final int skippedUnmappable;
  final String? error;

  const DivelogsPushResult({
    required this.pushed,
    required this.skippedUnmappable,
    this.error,
  });

  bool get failed => error != null;
}

/// Create-only bulk push. A failure stops the run and reports partial
/// progress; no rollback is needed because the next compare simply matches
/// whatever was already created (stateless model, spec: push path).
class DivelogsPushService {
  DivelogsPushService({
    required DivelogsApiClient api,
    this.mapper = const DivelogsExportMapper(),
    this.chunkSize = 50,
    Future<void> Function(Duration)? delay,
  }) : _api = api,
       _delay = delay ?? Future.delayed;

  final DivelogsApiClient _api;
  final DivelogsExportMapper mapper;
  final int chunkSize;
  final Future<void> Function(Duration) _delay;

  static const Duration _interChunkDelay = Duration(milliseconds: 200);

  Future<DivelogsPushResult> push(
    List<Dive> dives, {
    void Function(int done, int total)? onProgress,
  }) async {
    final mapped = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final dive in dives) {
      final json = mapper.mapDive(dive);
      if (json == null) {
        skipped++;
      } else {
        mapped.add(json);
      }
    }

    var pushed = 0;
    for (var start = 0; start < mapped.length; start += chunkSize) {
      if (start > 0) await _delay(_interChunkDelay);
      final chunk = mapped.sublist(
        start,
        start + chunkSize > mapped.length ? mapped.length : start + chunkSize,
      );
      try {
        await _api.postDives(chunk);
      } on DivelogsApiException catch (e) {
        return DivelogsPushResult(
          pushed: pushed,
          skippedUnmappable: skipped,
          error: e.message,
        );
      }
      pushed += chunk.length;
      onProgress?.call(pushed, mapped.length);
    }
    return DivelogsPushResult(pushed: pushed, skippedUnmappable: skipped);
  }
}
```

- [ ] **Step 3: Run tests to verify pass**

Run: `flutter test test/features/divelogs_sync/domain/services/divelogs_push_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A lib/features/divelogs_sync test/features/divelogs_sync
git commit -m "feat: add chunked create-only divelogs.de push service"
```

---

### Task 5: Sync page UI + routing from the Connected Accounts roster

**Files:**
- Create: `lib/features/divelogs_sync/presentation/pages/divelogs_sync_page.dart`
- Modify: `lib/core/router/app_router.dart` (settings routes, next to `connected-accounts`)
- Modify: `lib/features/settings/presentation/pages/connected_accounts_page.dart` (`_AccountTile` gains `onTap` for divelogs)
- Modify: `lib/l10n/arb/app_en.arb` + all 10 non-English arb files
- Test: `test/features/divelogs_sync/presentation/pages/divelogs_sync_page_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4 (`getDivelist`, `DivelogsSyncPlanner`, `DivelogsPushService`), Phase 1's `DivelogsAccountAdapter.authManagerFor`, `divelogsHttpClientProvider`, `connectedAccountsRepositoryProvider`, `accountProviderRegistryProvider`, `diveRepositoryProvider` (`getDiveSummaries({diverId, limit})`, `getDivesByIds(List<String>)`), `currentDiverProvider`.
- Produces: route `/settings/divelogs-sync` (name `divelogsSync`); the sync page.

Page behavior (a `ConsumerStatefulWidget`, phase enum like `DivelogsFetchStep`):
1. **Load**: `getByKind(AccountKind.divelogs)`. No account → message with a button routing to `/transfer/divelogs-import` (the connect flow lives in the wizard). Account with `needsSignIn` status → same routing. Account signed in → show a Compare button (and run compare automatically on first load).
2. **Compare**: `getDivelist()` + `getDiveSummaries(diverId: account.diverId ?? currentDiver?.id, limit: 1000000)` → `DivelogsSyncPlanner().plan(...)`. Uses the same diver-binding guard as Phase 1: if `account.diverId` differs from the active diver, show the wrong-diver message (reuse `divelogs_fetch_wrongDiver`).
3. **Result view**: three summary rows — matched count, "Pull: N new from divelogs.de" with a button that routes to `/transfer/divelogs-import` (the wizard IS the pull review; its dedup makes the counts consistent), and "Push: M dives not on divelogs.de" with a checkbox list (`CheckboxListTile` per push candidate: dive number, name/`effectiveName` fallback to date, formatted date) all checked by default, plus a "Push selected" button.
   - Note: the spec sketches per-dive toggles for both directions on this page; pull toggles are intentionally delegated to the wizard's existing review step to avoid duplicating selection UI (deviation recorded in the spec's sync-page section intent — compare, then review — which this preserves).
4. **Push**: `getDivesByIds(selectedIds)` → `DivelogsPushService(api: ...).push(dives, onProgress: ...)` with a linear progress indicator; on completion show "Pushed N dives" (+ "M could not be converted" when `skippedUnmappable > 0`), and on `result.failed` show the error with a Retry that re-runs compare first (stateless convergence). After any push, automatically re-run compare.
5. All strings via `context.l10n`; dates formatted with the existing localization utilities used by `DiveSummary` lists (check `dive_list_item` for the date format helper; a plain `MaterialLocalizations.of(context).formatShortDate` is acceptable).

New l10n keys (en values; translate into all 10 non-English locales, mirroring Phase 1's script approach):

```json
"divelogsSync_title": "divelogs.de Sync",
"divelogsSync_notConnected": "No divelogs.de account is connected yet. Start an import to sign in.",
"divelogsSync_openImport": "Open divelogs.de import",
"divelogsSync_compare": "Compare",
"divelogsSync_comparing": "Comparing with divelogs.de...",
"divelogsSync_matched": "{count} dives already in sync",
"@divelogsSync_matched": { "placeholders": { "count": { "type": "int" } } },
"divelogsSync_pullHeader": "Pull: {count} new on divelogs.de",
"@divelogsSync_pullHeader": { "placeholders": { "count": { "type": "int" } } },
"divelogsSync_pullReview": "Review and pull in the import wizard",
"divelogsSync_pushHeader": "Push: {count} dives not on divelogs.de",
"@divelogsSync_pushHeader": { "placeholders": { "count": { "type": "int" } } },
"divelogsSync_pushSelected": "Push selected",
"divelogsSync_pushing": "Pushing dives to divelogs.de...",
"divelogsSync_pushDone": "Pushed {count} dives to divelogs.de.",
"@divelogsSync_pushDone": { "placeholders": { "count": { "type": "int" } } },
"divelogsSync_pushSkipped": "{count} dives could not be converted and were skipped.",
"@divelogsSync_pushSkipped": { "placeholders": { "count": { "type": "int" } } },
"divelogsSync_pushFailedPartial": "Push stopped after {count} dives: {error}",
"@divelogsSync_pushFailedPartial": { "placeholders": { "count": { "type": "int" }, "error": { "type": "String" } } },
"divelogsSync_nothingToSync": "Everything is in sync."
```

Router addition (inside the `/settings` routes, next to `connected-accounts`):

```dart
GoRoute(
  path: 'divelogs-sync',
  name: 'divelogsSync',
  builder: (context, state) => const DivelogsSyncPage(),
),
```

`_AccountTile` addition in `connected_accounts_page.dart` — give the `ListTile` an `onTap` that is non-null only for divelogs:

```dart
onTap: account.kind == AccountKind.divelogs
    ? () => context.push('/settings/divelogs-sync')
    : null,
```

- [ ] **Step 1: Write the failing widget test**

Model the harness on `test/features/import_wizard/presentation/widgets/divelogs_fetch_step_test.dart` (same overrides: `sharedPreferencesProvider`, `accountCredentialsStoreProvider`, `divelogsHttpClientProvider`, `allDiversProvider`, `currentDiverProvider`; same `setUpTestDatabase` + `tester.runAsync` + pinned `locale: Locale('en')` + l10n delegates). Cover:

```dart
testWidgets('shows connect prompt when no account exists', (tester) async {
  // pump DivelogsSyncPage with no account rows
  // expect find.text('No divelogs.de account is connected yet. Start an import to sign in.')
});

testWidgets('compare renders pull/push/matched sections', (tester) async {
  // seed: create account via connectedAccountsRepositoryProvider
  //   (kind: divelogs, diverId: 'diver-1') and write DivelogsCredentials
  //   with a bearerToken so status == signedIn and no login call happens
  // MockClient: GET /api/divelist returns two remote entries, one matching
  //   a seeded local dive (insert via diveRepositoryProvider.createDive with
  //   entryTime/runtime/maxDepth), one new
  // expect pull header contains '1', push header contains the count of
  //   unmatched local dives, matched row contains '1'
});

testWidgets('push posts selected dives and reports the count', (tester) async {
  // same seeding; MockClient handles POST /api/dives returning 200 and
  //   captures the body; tap 'Push selected'; expect the POST body length
  //   equals the push-candidate count and 'Pushed 1 dives' (l10n plural
  //   simple form) appears; expect a second GET /api/divelist (auto re-compare)
});
```

Write these three tests in full (arrange/act/assert as sketched — the seeding and MockClient plumbing are mechanical repetitions of the Phase 1 widget test; `diveRepositoryProvider.createDive(Dive(...))` inserts local dives).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/divelogs_sync/presentation/pages/divelogs_sync_page_test.dart`
Expected: FAIL — page missing.

- [ ] **Step 3: Implement the page, route, tile tap, and l10n keys**

Implement `DivelogsSyncPage` per the behavior spec above (phases: `loading`, `notConnected`, `wrongDiver`, `comparing`, `plan`, `pushing`, `error`). Structure it like `DivelogsFetchStep`: a private phase enum, `_compare()` and `_push()` async methods guarded with `if (!mounted) return;`, services constructed exactly as the fetch step does:

```dart
final adapter = ref.read(accountProviderRegistryProvider)
    .adapterFor(AccountKind.divelogs) as DivelogsAccountAdapter;
final manager = adapter.authManagerFor(account);
final api = DivelogsApiClient(
  getBearerToken: manager.getToken,
  onTokenRejected: manager.invalidateToken,
  httpClient: ref.read(divelogsHttpClientProvider),
);
```

Add the arb keys to `app_en.arb` and translated equivalents to all 10 non-English arb files (same insertion-script approach as Phase 1), run `flutter gen-l10n`, add the `GoRoute`, and the `_AccountTile.onTap`.

- [ ] **Step 4: Run tests, analyze, and the existing suites this touches**

Run: `flutter test test/features/divelogs_sync test/features/import_wizard test/core/services/divelogs test/l10n && flutter analyze`
Expected: all PASS, no analyze issues.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A lib test
git commit -m "feat: add divelogs.de sync page with compare and chunked push"
```

---

### Task 6: Verification sweep

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes, no issues.

- [ ] **Step 2: Run the touched surface**

```bash
flutter test \
  test/core/services/divelogs \
  test/features/divelogs_sync \
  test/features/import_wizard \
  test/features/universal_import/data/services \
  test/core/services/accounts
```
Expected: all PASS.

- [ ] **Step 3: Full suite in the worktree**

Run: `flutter test` (background it; ~4 minutes). Fix anything red — check for exact-latest tripwires if any schema-adjacent constant changed (none should; Phase 2 has NO schema migration).

- [ ] **Step 4: Manual smoke note + commit any fixes**

macOS smoke (sign in, compare, push a dive, re-compare shows it matched) remains pending on a real divelogs.de account — record in the PR description. Commit fixes if any:

```bash
dart format .
git add -A
git commit -m "test: divelogs.de phase 2 verification fixes"
```

(Do not push or open a PR — that is a separate, user-triggered step; note this branch stacks on PR #603.)

---

## Deferred (do NOT build now)

- Gear + certifications sync (Phase 3), pictures (Phase 4).
- `LogbookSyncCapable` members: still a marker. The sync page constructs services directly (same as the Phase 1 fetch step); promote shared construction into the capability interface only when a second logbook service exists (YAGNI).
- Divelist-shape refinements once Rainer answers spec open question 3 (the tolerant parser + degraded matching cover the unknowns until then).

## Open assumptions (confirm with Rainer, do not block)

- `/divelist` rows carry `id` + `date`/`time` (or a combined `datetime`), optionally `duration`/`maxdepth`.
- `POST /dives` accepts up to 50 dives per request.
- `sampledata` on POST assumes one fixed `samplerate` per dive.
