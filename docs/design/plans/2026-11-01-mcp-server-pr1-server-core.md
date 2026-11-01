# MCP Server PR 1: Server Core and Read Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a loopback-only MCP server inside the running desktop app, behind a debug-mode-gated settings page, with `list_divers`, `query` and `get_records` (dives) tools and two resources, so an agent on the same machine can find and read a diver's dives across every profile.

**Architecture:** A new `lib/features/agent_access/` feature owns a process-wide `AgentAccessServer` singleton that wraps `mcp_dart`'s `StreamableMcpServer` (host `127.0.0.1`, path `/mcp`, bearer token, host and origin allowlists). Tools are plain Dart classes behind an `AgentTool` interface that knows nothing about `mcp_dart`; one builder registers them per MCP session. Every request resolves `DatabaseService.instance.database` fresh, passes a gate (demo mode, app lock, database available) and a per-diver context (settings, unit prefs, name index, root scope) built from the existing repositories.

**Tech Stack:** Flutter 3.47.0, Dart ^3.10, Riverpod ^3.4.2 (`package:submersion/core/providers/provider.dart` barrel), Drift ^2.34.3, `mcp_dart ^2.4.3` (new), `flutter_secure_storage ^11.0.0`, `shared_preferences`.

**Spec:** `docs/design/specs/2026-11-01-mcp-server-design.md`. This plan implements its first phase. Later phases are listed under "Roadmap" at the end.

## Global Constraints

- Bind to `127.0.0.1` only; never `0.0.0.0` or `::`.
- Accept only `Host` values `localhost`, `127.0.0.1` or `[::1]` (with the bound port); refuse others.
- If an `Origin` header is present it must be a loopback origin; otherwise refuse.
- Every request, including `initialize`, carries `Authorization: Bearer <token>`; missing or wrong is refused.
- Token: 32 random bytes, base64url, generated when the diver first enables the server, stored with `flutter_secure_storage`, regenerable.
- Server off by default; all settings per device in SharedPreferences, never synced diver settings.
- Until the final write PR, the settings entry point is shown only while debug mode is on.
- Every tool checks `DemoModeGate` first (sealed feature `agentAccess`), refuses while the app is locked, and returns `database_unavailable` while `DatabaseService.instance.databaseOrNull` is null.
- Tool responses: metric values with the unit in the key (`max_depth_m`, `water_temp_c`, `start_pressure_bar`, `weight_kg`), never bare numbers. `DateTime` values are wall-clock UTC: format with `toIso8601String()` without `toLocal()`.
- `query` parses bare numbers in the named (or active) diver's units via `unitPrefsFromSettings(getSettingsForDiver(id) ?? const AppSettings())`.
- Tool and resource text is English only (agent-facing). Settings UI strings go in `lib/l10n/arb/app_en.arb` and all ten other ARBs, then `flutter gen-l10n`; `test/l10n/untranslated_english_values_test.dart` rejects multi-word values identical to English.
- No new database table, column or migration in this PR.
- Files 200 to 400 lines, 800 max; `dart format .` before every commit; TDD; no emojis; no em-dashes.
- Imports grouped dart, flutter, packages, local. Riverpod via the provider barrel.
- Run `flutter test test/architecture test/shared` after adding any `lib/` file (guards scan all of `lib/`).
- No attribution of any tool in commits, PR or comments. PR body links the tracking issue with `Refs #<n>` (this PR does not resolve it). The PR changes a settings page, so it needs before and after screenshots per `docs/contributing/pull-requests.md`.

## Review Focus

1. A non-active diver whose depth unit is feet types `depth > 100` in `query`; the number must convert as feet, not metres (Task 6 test `parses bare numbers in the named divers units`).
2. A request arriving while a restore or storage move has the database swapped out must return a `database_unavailable` tool error, not a 500 or an unhandled `StateError` (Task 3 test `gate returns database_unavailable while databaseOrNull is null`, Task 9 e2e test `tool error while database unavailable`).
3. The configured port is already taken when the diver enables the server; the app must keep running and the status must say why (Task 10 test `reports port in use and stays stopped`).
4. `restartApp` disposes and rebuilds the scope at once; starting while the previous server is still closing must not fail with address in use (Task 10 test `start waits for a pending stop on the same port`).
5. A media item of source type signature carries image bytes; no tool response may include them (Task 7 test `media documents never carry imageData`).

---

## File Structure

Create under `lib/features/agent_access/`:

- `domain/agent_access_settings.dart`: `AgentAccessSettings` value type and defaults.
- `domain/agent_tool_error.dart`: `AgentToolErrorCode` enum, `AgentToolException`.
- `domain/agent_tool.dart`: `AgentTool` interface, `AgentToolContext`.
- `data/agent_access_preferences.dart`: SharedPreferences wrapper.
- `data/agent_access_token_store.dart`: secure storage wrapper.
- `data/agent_tool_gate.dart`: demo, lock, database checks.
- `data/diver_context.dart`: `DiverContext`, `DiverContextLoader`.
- `data/root_scope.dart`: `rootScopeFor`.
- `data/documents/diver_document.dart`, `data/documents/dive_document.dart`, `data/documents/media_document.dart`: JSON mappers.
- `data/tools/list_divers_tool.dart`, `data/tools/query_tool.dart`, `data/tools/get_records_tool.dart`, `data/tools/agent_tool_registry.dart`.
- `data/resources/agent_resource.dart`, `data/resources/query_language_resource.dart`, `data/resources/units_resource.dart`.
- `data/server/request_authenticator.dart`: constant-time bearer check.
- `data/server/mcp_server_builder.dart`: registers tools and resources on an `McpServer`.
- `data/server/agent_access_server.dart`: process-wide host over `StreamableMcpServer`, status stream.
- `presentation/providers/agent_access_providers.dart`: settings notifier, token store, status, lifecycle controller.
- `presentation/pages/agent_access_page.dart`, `presentation/widgets/agent_access_snippets.dart`, `presentation/widgets/agent_access_status_card.dart`.

Modify:

- `pubspec.yaml` (`# Networking` group): add `mcp_dart: ^2.4.3` with a why comment.
- `lib/app.dart` `_SubmersionAppState.initState` (near line 185): start the lifecycle controller on desktop.
- `lib/features/settings/presentation/pages/data_tools_page.dart`: add the Agent access row (debug gated).
- `lib/core/router/app_router.dart` (child routes of `/settings`, near line 1484): `agent-access` route.
- `lib/features/settings/presentation/pages/data_settings_pane.dart` (`dataPanePage`, near line 102).
- `test/core/router/app_router_test.dart` `locations` list (near lines 2160 to 2235).
- `lib/features/demo_mode/domain/demo_sealed_feature.dart`: add `agentAccess`.
- `test/architecture/demo_seal_engine_gates_test.dart` `_gates` list.
- `lib/l10n/arb/app_*.arb` (eleven files).
- `macos/Runner/ReleaseNoSandbox.entitlements`: refresh the stale "client only" comment.
- `docs/developer/agent-access.md` (new), `docs/user/` page deferred to the final PR.

Tests mirror `lib/` under `test/` with `_test.dart`.

---

### Task 1: Dependency, settings value type and preferences

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/agent_access/domain/agent_access_settings.dart`
- Create: `lib/features/agent_access/data/agent_access_preferences.dart`
- Test: `test/features/agent_access/data/agent_access_preferences_test.dart`

**Interfaces:**
- Produces:
  - `const kAgentAccessDefaultPort = 47831;`
  - `class AgentAccessSettings { const AgentAccessSettings({this.enabled = false, this.port = kAgentAccessDefaultPort, this.confirmWrites = true}); final bool enabled; final int port; final bool confirmWrites; AgentAccessSettings copyWith({bool? enabled, int? port, bool? confirmWrites}); }` with `==` and `hashCode`.
  - `class AgentAccessPreferences { AgentAccessPreferences(SharedPreferences prefs); static const enabledKey = 'agent_access_enabled'; static const portKey = 'agent_access_port'; static const confirmWritesKey = 'agent_access_confirm_writes'; AgentAccessSettings read(); Future<void> write(AgentAccessSettings settings); }`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `# Networking`, after `http`, add `mcp_dart: ^2.4.3  # In-app MCP server for agent access (Streamable HTTP on loopback)`. Run `flutter pub get`. Expected: resolves without downgrading `http` (lock has 1.6.0) or `meta` (1.19.0).

- [ ] **Step 2: Write the failing preferences test**

```dart
// test/features/agent_access/data/agent_access_preferences_test.dart
test('defaults are off, port 47831, confirm on', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = AgentAccessPreferences(await SharedPreferences.getInstance());
  expect(prefs.read(), const AgentAccessSettings());
  expect(prefs.read().enabled, isFalse);
  expect(prefs.read().port, 47831);
  expect(prefs.read().confirmWrites, isTrue);
});
test('write then read round-trips every field', () async { ... write(enabled: true, port: 50000, confirmWrites: false) ... });
test('an invalid stored port falls back to the default', () async {
  SharedPreferences.setMockInitialValues({'agent_access_port': 70000});
  expect(prefs.read().port, kAgentAccessDefaultPort);
});
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/agent_access/data/agent_access_preferences_test.dart`
Expected: FAIL, missing imports.

- [ ] **Step 4: Implement the value type and the preferences class**

Valid port range for `read()`: 1024 to 65535; anything else returns the default.

- [ ] **Step 5: Run the test to verify it passes, then format and commit**

Run: `flutter test test/features/agent_access/data/agent_access_preferences_test.dart`
Expected: PASS.

```bash
dart format lib/features/agent_access test/features/agent_access
git add pubspec.yaml pubspec.lock lib/features/agent_access/domain/agent_access_settings.dart lib/features/agent_access/data/agent_access_preferences.dart test/features/agent_access/data/agent_access_preferences_test.dart
git commit -m "feat(agent-access): add mcp_dart and per-device agent access settings"
```

---

### Task 2: Token store

**Files:**
- Create: `lib/features/agent_access/data/agent_access_token_store.dart`
- Test: `test/features/agent_access/data/agent_access_token_store_test.dart`

**Interfaces:**
- Consumes: `FallbackSecureStorage` (`lib/core/services/secure_storage/fallback_secure_storage.dart`), test fake `InMemoryKeychain` (`test/support/fake_keychain_storage.dart`).
- Produces: `class AgentAccessTokenStore { AgentAccessTokenStore({FlutterSecureStorage? storage, Random? random}); static const key = 'agent_access_token'; Future<String?> read(); Future<String> ensure(); Future<String> regenerate(); Future<void> clear(); }`. `ensure()` returns the stored token or generates one. Tokens are 32 bytes from `Random.secure()` encoded `base64Url` without padding (43 characters).

- [ ] **Step 1: Write the failing test**

```dart
test('ensure generates a 43-char base64url token once', () async {
  final store = AgentAccessTokenStore(storage: InMemoryKeychain());
  final a = await store.ensure();
  expect(a, hasLength(43));
  expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(a), isTrue);
  expect(await store.ensure(), a);
});
test('regenerate replaces the token', () async { expect(await store.regenerate(), isNot(a)); });
test('clear removes it', () async { await store.clear(); expect(await store.read(), isNull); });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/agent_access/data/agent_access_token_store_test.dart`
Expected: FAIL, class missing.

- [ ] **Step 3: Implement the store** following `EncryptionKeyStore` (`lib/core/services/sync/crypto/encryption_key_store.dart`): wrap the given storage in `FallbackSecureStorage`.

- [ ] **Step 4: Run to verify it passes, format, commit**

```bash
git add lib/features/agent_access/data/agent_access_token_store.dart test/features/agent_access/data/agent_access_token_store_test.dart
git commit -m "feat(agent-access): store the bearer token in secure storage"
```

---

### Task 3: Tool interface, error model and gate

**Files:**
- Create: `lib/features/agent_access/domain/agent_tool_error.dart`
- Create: `lib/features/agent_access/domain/agent_tool.dart`
- Create: `lib/features/agent_access/data/agent_tool_gate.dart`
- Modify: `lib/features/demo_mode/domain/demo_sealed_feature.dart` (add `agentAccess`)
- Modify: `test/architecture/demo_seal_engine_gates_test.dart` (`_gates` entry)
- Test: `test/features/agent_access/data/agent_tool_gate_test.dart`

**Interfaces:**
- Consumes: `DemoModeGate.instance.ensureNotDemo(DemoSealedFeature)`, `DatabaseService.instance.databaseOrNull`.
- Produces:
  - `enum AgentToolErrorCode { demoMode, appLocked, databaseUnavailable, invalidArgument, parseError, unknownDiver, notFound, tooManyIds, internal }` with `String get wire` returning snake_case (`demo_mode`, `app_locked`, `database_unavailable`, `invalid_argument`, `parse_error`, `unknown_diver`, `not_found`, `too_many_ids`, `internal`).
  - `class AgentToolException implements Exception { const AgentToolException(this.code, this.message, {this.details}); final AgentToolErrorCode code; final String message; final Map<String, Object?>? details; Map<String, Object?> toJson(); }` producing `{'error': code.wire, 'message': ..., 'details': ...}`.
  - `class AgentToolContext { const AgentToolContext({required this.db, required this.clientName}); final AppDatabase db; final String? clientName; }`
  - `abstract interface class AgentTool { String get name; String get description; Map<String, Object?> get inputSchema; Future<Map<String, Object?>> call(Map<String, Object?> args, AgentToolContext context); }`
  - `class AgentToolGate { AgentToolGate({required bool Function() isLocked}); AppDatabase open(); }` where `open()` throws `AgentToolException(demoMode)`, then `appLocked`, then `databaseUnavailable`, else returns the live database. The demo check is `DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.agentAccess)` as the first statement of `open()`, with no `await` in the method.

- [ ] **Step 1: Write the failing gate test**

```dart
setUp(setUpTestDatabase); tearDown(() async { await tearDownTestDatabase(); applyGlobalTestDefaults(); });
test('gate refuses while demo mode is active', () {
  DemoModeGate.instance.debugActive = true;
  expect(() => AgentToolGate(isLocked: () => false).open(),
      throwsA(isA<AgentToolException>().having((e) => e.code, 'code', AgentToolErrorCode.demoMode)));
});
test('gate refuses while the app is locked', ...appLocked...);
test('gate returns database_unavailable while databaseOrNull is null', () async {
  await tearDownTestDatabase(); // resetForTesting leaves databaseOrNull null
  expect(() => gate.open(), throwsA(...databaseUnavailable...));
});
test('gate returns the live database otherwise', () { expect(gate.open(), same(DatabaseService.instance.database)); });
test('toJson carries wire code and message', () { expect(const AgentToolException(AgentToolErrorCode.tooManyIds, 'max 50').toJson(), {'error': 'too_many_ids', 'message': 'max 50', 'details': null}); });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/agent_access/data/agent_tool_gate_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the enum, exception, interface and gate**; add `agentAccess` to `DemoSealedFeature`.

- [ ] **Step 4: Register the gate with the architecture guard**

Add to `_gates` in `test/architecture/demo_seal_engine_gates_test.dart` an `ensure` entry for `lib/features/agent_access/data/agent_tool_gate.dart`, signature `AppDatabase open()`, feature `agentAccess`.

- [ ] **Step 5: Run the gate test, the guard, and the global-state scan**

Run: `flutter test test/features/agent_access/data/agent_tool_gate_test.dart test/architecture/demo_seal_engine_gates_test.dart test/architecture/test_global_state_restored_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
git add lib/features/agent_access/domain lib/features/agent_access/data/agent_tool_gate.dart lib/features/demo_mode/domain/demo_sealed_feature.dart test/architecture/demo_seal_engine_gates_test.dart test/features/agent_access/data/agent_tool_gate_test.dart
git commit -m "feat(agent-access): tool interface, error codes and demo, lock, database gate"
```

---

### Task 4: Per-diver context and root scope

**Files:**
- Create: `lib/features/agent_access/data/diver_context.dart`
- Create: `lib/features/agent_access/data/root_scope.dart`
- Test: `test/features/agent_access/data/diver_context_test.dart`
- Test: `test/features/agent_access/data/root_scope_test.dart`

**Interfaces:**
- Consumes: `DiverRepository.getAllDivers()`, `getDiverById(String)`, `getDefaultDiver()` (`lib/features/divers/data/repositories/diver_repository.dart`); `DiverSettingsRepository.getSettingsForDiver(String)` returning `AppSettings?`; `unitPrefsFromSettings(UnitFormatterSettings)` (`lib/features/query/presentation/providers/query_unit_prefs_provider.dart:7`); `NameIndexLoader(db).load(diverId:, l10n:)` (`lib/features/query/data/name_index_loader.dart:66`); `l10nForLocaleTag(String)` (`lib/l10n/l10n_extension.dart:16`); `VisibilityFilter.sqlFragment({tableAlias, diverId, conjunction, kind})` and `equipmentSqlFragment(...)` (`lib/core/data/visibility/visibility_filter.dart:162`, `:114`); `SharedItemKind` (`lib/core/data/visibility/shared_item_policy.dart:12`); `QueryScope` typedef `({String sql, List<Object> params})` (`lib/features/query/data/query_id_set_runner.dart:10`); `QueryEntity.diverScopeColumn`.
- Produces:
  - `class DiverContext { final String diverId; final AppSettings settings; final UnitPrefs prefs; final NameIndex names; UnitFormatter get formatter; }`
  - `class DiverContextLoader { DiverContextLoader({required AppDatabase db, required DiverRepository divers, required DiverSettingsRepository settings, required String localeTag, required Future<String?> Function() activeDiverId}); Future<DiverContext> load({String? diverId}); Future<String> resolveDiverId(String? requested); }`. `resolveDiverId(null)` returns the active id (falling back to the default diver); an unknown id throws `AgentToolException(unknownDiver)`. Settings fall back to `const AppSettings()`.
  - `QueryScope? rootScopeFor(QueryEntity root, String diverId, {String alias = 'r0'})`: dives, buddies, centers, certifications, courses give `(sql: '$alias.diver_id = ?', params: [diverId])`; sites and trips give the owner-or-shared visibility fragment for `SharedItemKind.site` / `.trip` adapted from `SqlFragment` (strip the leading conjunction, unwrap `Variable` values into raw params); equipment uses `equipmentSqlFragment`; species returns null.

- [ ] **Step 1: Write the failing context test** (real database via `setUpTestDatabase()`; insert two divers, one with `depthUnit: DepthUnit.feet` saved through `DiverSettingsRepository`)

```dart
test('resolveDiverId falls back to the active diver', ...);
test('resolveDiverId rejects an unknown id with unknown_diver', ...);
test('load builds prefs from the named divers settings', () async {
  final ctx = await loader.load(diverId: feetDiver.id);
  expect(ctx.prefs.depth, DepthUnit.feet);
});
test('load builds an empty name index when the diver has no names', () async { expect(ctx.names.candidates(QuerySubject.sites, 'x'), isEmpty); });
```

- [ ] **Step 2: Write the failing root scope test** (real database; a site owned by diver A shared to diver B, a site owned by C hidden from B)

```dart
test('dives scope is a plain diver_id equality', () { expect(rootScopeFor(diveQueryEntity, 'me')!.sql, 'r0.diver_id = ?'); });
test('species has no scope', () { expect(rootScopeFor(speciesQueryEntity, 'me'), isNull); });
test('sites scope sees shared sites and hides hidden ones', () async {
  final ids = await QueryIdSetRunner(db).ids(compileQuery(null, siteQueryEntity, appQueryRegistry), scope: rootScopeFor(siteQueryEntity, diverB.id));
  expect(ids, containsAll([ownSite.id, sharedSite.id]));
  expect(ids, isNot(contains(hiddenSite.id)));
});
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/agent_access/data/`
Expected: FAIL.

- [ ] **Step 4: Implement `DiverContextLoader` and `rootScopeFor`**

For the fragment adaptation, `SqlFragment.whereClause` begins with `" $conjunction "`; pass `conjunction: ''` if the API allows, otherwise trim the leading conjunction token. Params come from `Variable.value`.

- [ ] **Step 5: Run to verify they pass, format, commit**

```bash
git add lib/features/agent_access/data/diver_context.dart lib/features/agent_access/data/root_scope.dart test/features/agent_access/data/diver_context_test.dart test/features/agent_access/data/root_scope_test.dart
git commit -m "feat(agent-access): per-diver context and visibility-aware root scopes"
```

---

### Task 5: `list_divers` tool

**Files:**
- Create: `lib/features/agent_access/data/documents/diver_document.dart`
- Create: `lib/features/agent_access/data/tools/list_divers_tool.dart`
- Test: `test/features/agent_access/data/tools/list_divers_tool_test.dart`

**Interfaces:**
- Consumes: `DiverRepository.getAllDivers()`, `getDiveCountsByDiver()` (`diver_repository.dart:174`), `DiverContextLoader.resolveDiverId(null)`, `getSettingsForDiver`.
- Produces:
  - `Map<String, Object?> diverDocument(Diver diver, {required bool isActive, required int diveCount, required AppSettings settings})` with keys exactly: `id`, `name`, `is_active`, `is_default`, `dive_count`, `units` (map: `depth` in `m|ft`, `temperature` in `c|f`, `pressure` in `bar|psi`, `volume` in `l|cuft`, `weight` in `kg|lb`), `date_format` (`DateFormatPreference.pattern`), `time_format` (`12h|24h`). No other `Diver` field is emitted.
  - `class ListDiversTool implements AgentTool { ListDiversTool({required DiverContextLoader loader, required DiverRepository divers, required DiverSettingsRepository settings}); }` with `name = 'list_divers'`, empty-object `inputSchema`, result `{'divers': [...]}`.

- [ ] **Step 1: Write the failing test** (two divers, one active, counts 3 and 0, feet diver)

```dart
test('lists every profile with units and active flag', () async {
  final out = await tool.call({}, ctx);
  final divers = out['divers'] as List;
  expect(divers, hasLength(2));
  final a = divers.singleWhere((d) => d['id'] == active.id);
  expect(a['is_active'], isTrue);
  expect(a['dive_count'], 3);
  expect(a['units'], {'depth': 'm', 'temperature': 'c', 'pressure': 'bar', 'volume': 'l', 'weight': 'kg'});
});
test('document never includes email, phone, medical or photo fields', () {
  expect(doc.keys, unorderedEquals(['id','name','is_active','is_default','dive_count','units','date_format','time_format']));
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/agent_access/data/tools/list_divers_tool_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `diverDocument` and `ListDiversTool`**

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/agent_access/data/tools/list_divers_tool_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
git add lib/features/agent_access/data/documents/diver_document.dart lib/features/agent_access/data/tools/list_divers_tool.dart test/features/agent_access/data/tools/list_divers_tool_test.dart
git commit -m "feat(agent-access): list_divers tool"
```

---

### Task 6: `query` tool

**Files:**
- Create: `lib/features/agent_access/data/tools/query_tool.dart`
- Create: `lib/features/agent_access/data/documents/dive_summary_document.dart`
- Test: `test/features/agent_access/data/tools/query_tool_test.dart`

**Interfaces:**
- Consumes: `QueryParser(registry, root, ParseContext(prefs:, now:, names:)).parse(text)` returning `ParseOk(node)` / `ParseFailure(error)` (`lib/core/query/syntax/query_parser.dart:105`, `:117`); `QueryError.code`, `.offset`, `.length`, `.message`, `.suggestions`; `validateQuery(node, root, registry)`; `compileQuery(node, root, appQueryRegistry, diverId:)`; `QueryIdSetRunner(db).ids(compiled, scope:)` and `.count(...)`; `awaitServiceStatusIfRead` is provider-bound, so instead refuse queries whose `compiled.tablesTouched` contains `'equipment_service_status'` with `invalidArgument` ("serviceDue is not available to agents yet") in this PR; `DiveRepository.getSummariesByIds(List<String>)` chunked by `kSeriesIdChunkSize` (`lib/features/dive_log/data/repositories/series_id_chunks.dart`); `DiveSummary` fields; the nine roots are `QuerySubject.values.take(9)` mapped through `appQueryRegistry.entityFor`.
- Produces:
  - `class QueryTool implements AgentTool { QueryTool({required DiverContextLoader loader, required DiveRepository dives}); }` with `name = 'query'`; `inputSchema` properties: `root` (string enum of the nine subject names), `query` (string, default empty), `diver_id` (string), `include_summaries` (boolean, default false), `limit` (integer 1 to 5000, default 500), `offset` (integer, default 0); `required: ['root']`.
  - Result: `{'root': 'dives', 'diver_id': ..., 'total': int, 'ids': [...], 'offset': int, 'limit': int, 'has_more': bool, 'summaries': [...]?}`. Ids are sorted ascending for stable paging. Summaries are present only when `include_summaries` is true and root is dives (other roots in PR 2).
  - Parse failures throw `AgentToolException(parseError, error.message, details: {'offset': ..., 'length': ..., 'code': error.code.name, 'suggestions': [...]})`; validation errors likewise with `details: {'errors': [...]}`.
  - `Map<String, Object?> diveSummaryDocument(DiveSummary s)` with keys: `id`, `dive_number`, `name`, `date_time` (ISO 8601), `max_depth_m`, `bottom_time_s`, `runtime_s`, `water_temp_c`, `rating`, `is_favorite`, `excluded_from_stats`, `is_planned`, `dive_mode`, `site_name`, `site_country`, `trip_id`, `trip_name`, `tags` (names), `safety_finding_count`.

- [ ] **Step 1: Write the failing test** (real database: diver A metric with dives at 20 m and 40 m, both at a site named "Blue Hole"; diver B feet with one dive at 35 m at a different site)

```dart
test('empty query returns every dive of the active diver, sorted', ...total 2, ids sorted...);
test('parses bare numbers in the named divers units', () async {
  final out = await tool.call({'root': 'dives', 'query': 'depth > 100', 'diver_id': diverB.id}, ctx);
  expect(out['total'], 1); // 35 m is 114 ft
  final outA = await tool.call({'root': 'dives', 'query': 'depth > 100'}, ctx);
  expect(outA['total'], 0); // metric: nothing deeper than 100 m
});
test('resolves names through the divers name index', () async { expect((await tool.call({'root': 'dives', 'query': 'site:"Blue Hole"'}, ctx))['total'], 2); });
test('parse failure surfaces offset and suggestions', () async {
  await expectLater(tool.call({'root': 'dives', 'query': 'dpeth > 3'}, ctx),
      throwsA(isA<AgentToolException>().having((e) => e.code, 'code', AgentToolErrorCode.parseError).having((e) => e.details!['offset'], 'offset', 0)));
});
test('unknown root is invalid_argument', ...);
test('paging honours limit and offset with has_more', ...limit 1 -> has_more true...);
test('include_summaries returns unit-named keys', () async { expect(summaries.first.keys, contains('max_depth_m')); expect(summaries.first.keys, isNot(contains('maxDepth'))); });
test('a query touching equipment_service_status is refused in this phase', ...);
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/agent_access/data/tools/query_tool_test.dart`

- [ ] **Step 3: Implement `QueryTool`**

Order per call: resolve diver via `DiverContextLoader.load(diverId:)`, new `QueryParser` per parse with `now: DateTime.now()`, `validateQuery` before `compileQuery` (the compiler throws `QueryCompileError` on an unvalidated tree), then `rootScopeFor`, then `ids` and `count` through `QueryIdSetRunner`.

- [ ] **Step 4: Run to verify it passes, format, commit**

```bash
git add lib/features/agent_access/data/tools/query_tool.dart lib/features/agent_access/data/documents/dive_summary_document.dart test/features/agent_access/data/tools/query_tool_test.dart
git commit -m "feat(agent-access): query tool over the entity query language"
```

---

### Task 7: Dive documents and `get_records` (dives)

**Files:**
- Create: `lib/features/agent_access/data/documents/dive_document.dart`
- Create: `lib/features/agent_access/data/documents/media_document.dart`
- Create: `lib/features/agent_access/data/tools/get_records_tool.dart`
- Test: `test/features/agent_access/data/documents/dive_document_test.dart`
- Test: `test/features/agent_access/data/tools/get_records_tool_test.dart`

**Interfaces:**
- Consumes: `DiveRepository.getDiveById(String)` (`dive_repository_impl.dart:793`, loads tanks, weights, tags and the full profile, but not buddies, sightings or media); `BuddyRepository.getBuddiesForDive(String)` (`buddy_repository.dart:396`); `SpeciesRepository.getSightingsForDive(String)` (`species_repository.dart:239`); `MediaRepository.getMediaForDive(String)` (`media_repository.dart:73`); `DiveTypeRepository.getAllDiveTypes({diverId})` for type names; `Dive`, `DiveTank`, `DiveWeight`, `DiveProfilePoint` (`lib/features/dive_log/domain/entities/dive.dart`); `MediaItem` (never emit `imageData`).
- Produces:
  - `const kGetRecordsMaxIds = 50; const kProfileDefaultLimit = 500; const kProfileMaxLimit = 2000;`
  - `Map<String, Object?> diveDocument(Dive dive, {List<BuddyWithRole>? buddies, List<Sighting>? sightings, List<MediaItem>? media, Map<String, String> typeNames, Set<String> include, int profileOffset, int profileLimit})`. Top-level keys always present: `id`, `diver_id`, `dive_number`, `name`, `date_time`, `entry_time`, `exit_time`, `bottom_time_s`, `runtime_s`, `max_depth_m`, `avg_depth_m`, `water_temp_c`, `air_temp_c`, `visibility_m`, `rating`, `notes`, `dive_mode`, `is_planned`, `is_favorite`, `excluded_from_stats`, `site` (`{id, name, country, region, latitude, longitude}` or null), `trip` (`{id, name}` or null), `dive_center` (`{id, name}` or null), `weight_kg`, `surface_interval_s`, `gf_low`, `gf_high`. Optional blocks keyed by `include` members `tanks`, `buddies`, `tags`, `types`, `weights`, `sightings`, `media`, `profile`. `tanks[]`: `{id, name, volume_l, working_pressure_bar, start_pressure_bar, end_pressure_bar, o2_fraction, he_fraction, role}`. `profile`: `{offset, limit, total, samples: [{t_s, depth_m, temperature_c, pressure_bar}]}`. `media[]` from `mediaDocument`: `{id, source_type, file_path, local_path, url, thumbnail_path, captured_at}` and nothing else.
  - `class GetRecordsTool implements AgentTool { GetRecordsTool({required DiverContextLoader loader, required DiveRepository dives, required BuddyRepository buddies, required SpeciesRepository species, required MediaRepository media, required DiveTypeRepository diveTypes}); }` with `name = 'get_records'`; `inputSchema` properties: `entity` (string enum `['dives']` in this PR), `ids` (array of string, 1 to 50), `include` (array of the eight block names), `diver_id`, `profile_offset`, `profile_limit`; `required: ['entity', 'ids']`. Result `{'entity': 'dives', 'records': [...], 'missing': [ids not found or not visible to the resolved diver]}`. More than 50 ids throws `tooManyIds`.

- [ ] **Step 1: Write the failing document test** (build a `Dive` in memory with two tanks, a profile of 1200 points, a signature `MediaItem` with `imageData`)

```dart
test('always emits metric unit-named keys and ISO dates without toLocal', ...);
test('profile is paged by offset and limit', () { final p = doc['profile'] as Map; expect((p['samples'] as List).length, 500); expect(p['total'], 1200); });
test('blocks appear only when included', () { expect(docWithoutTanks.containsKey('tanks'), isFalse); });
test('media documents never carry imageData', () { for (final m in doc['media'] as List) { expect((m as Map).keys, isNot(contains('imageData'))); expect(m.keys, isNot(contains('image_data'))); } });
```

- [ ] **Step 2: Write the failing tool test** (real database, two dives for diver A, one for diver B)

```dart
test('returns documents for visible ids and lists the rest as missing', () async {
  final out = await tool.call({'entity': 'dives', 'ids': [a1.id, b1.id, 'nope'], 'include': ['tanks']}, ctx);
  expect((out['records'] as List).map((r) => r['id']), [a1.id]);
  expect(out['missing'], unorderedEquals([b1.id, 'nope']));
});
test('more than 50 ids is too_many_ids', ...);
test('buddies and sightings come from their repositories', ...include buddies -> names present...);
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/agent_access/data/documents test/features/agent_access/data/tools/get_records_tool_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the documents and `GetRecordsTool`**

A dive is visible when its `diverId` equals the resolved diver; load buddies, sightings and media only for the blocks the caller included.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/features/agent_access/data/documents test/features/agent_access/data/tools/get_records_tool_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
git add lib/features/agent_access/data/documents/dive_document.dart lib/features/agent_access/data/documents/media_document.dart lib/features/agent_access/data/tools/get_records_tool.dart test/features/agent_access/data/documents/dive_document_test.dart test/features/agent_access/data/tools/get_records_tool_test.dart
git commit -m "feat(agent-access): get_records tool with dive documents"
```

---

### Task 8: Resources and the tool registry

**Files:**
- Create: `lib/features/agent_access/data/resources/agent_resource.dart`
- Create: `lib/features/agent_access/data/resources/query_language_resource.dart`
- Create: `lib/features/agent_access/data/resources/units_resource.dart`
- Create: `lib/features/agent_access/data/tools/agent_tool_registry.dart`
- Test: `test/features/agent_access/data/resources/query_language_resource_test.dart`
- Test: `test/features/agent_access/data/tools/agent_tool_registry_test.dart`

**Interfaces:**
- Consumes: `appQueryRegistry.entityFor(subject).fields`, each a `QueryField` (`lib/core/query/registry/query_field.dart:73`) with `key`, `aliases`, `type` (`FieldType`), `dimension` (`FieldDimension`) and `enumValues`; there is no English description field (`labelKey` is a localization key), so the listing shows key, type, dimension, aliases and enum values; the grammar section of `docs/design/specs/2026-09-25-entity-query-language-design.md` lines 139 to 208 as the source for a Dart string constant `kQueryGrammarText`.
- Produces:
  - `abstract interface class AgentResource { String get uri; String get name; String get mimeType; Future<String> read(AgentToolContext context); }`
  - `class QueryLanguageResource implements AgentResource` with `uri = 'submersion://query-language'`, `mimeType = 'text/markdown'`; `read` returns `kQueryGrammarText` followed by a generated `## <root>` section per root listing every field as `- key (type, dimension) aliases: a, b; values: x, y` (aliases and values only when present), then a `Units` line saying bare numbers take the diver's units from `list_divers`.
  - `class UnitsResource implements AgentResource` with `uri = 'submersion://units'`, `mimeType = 'application/json'`; `read` returns a JSON array of `{diver_id, units, date_format, time_format}` built with `diverDocument` fields for every profile.
  - `class AgentToolRegistry { AgentToolRegistry({required List<AgentTool> tools, required List<AgentResource> resources}); List<AgentTool> get tools; List<AgentResource> get resources; AgentTool toolNamed(String name); static AgentToolRegistry standard({required DiverContextLoader loader, required DiverRepository divers, required DiverSettingsRepository settings, required DiveRepository dives, required BuddyRepository buddies, required SpeciesRepository species, required MediaRepository media, required DiveTypeRepository diveTypes}); }`. `toolNamed` throws `AgentToolException(notFound)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('query language resource lists every root and every dive field', () async {
  final text = await QueryLanguageResource().read(ctx);
  for (final root in QuerySubject.values.take(9)) { expect(text, contains('## ${root.name}')); }
  expect(text, contains('- depth'));
  expect(text, contains('- waterTemp'));
});
test('standard registry exposes list_divers, query and get_records', () { expect(registry.tools.map((t) => t.name), unorderedEquals(['list_divers', 'query', 'get_records'])); });
test('toolNamed throws not_found for unknown names', ...);
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/agent_access/data/resources test/features/agent_access/data/tools/agent_tool_registry_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the resources and the registry**

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/agent_access/data/resources test/features/agent_access/data/tools/agent_tool_registry_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
git add lib/features/agent_access/data/resources lib/features/agent_access/data/tools/agent_tool_registry.dart test/features/agent_access/data/resources test/features/agent_access/data/tools/agent_tool_registry_test.dart
git commit -m "feat(agent-access): query language and units resources, tool registry"
```

---

### Task 9: MCP server host, security and end-to-end

**Files:**
- Create: `lib/features/agent_access/data/server/request_authenticator.dart`
- Create: `lib/features/agent_access/data/server/mcp_server_builder.dart`
- Create: `lib/features/agent_access/data/server/agent_access_server.dart`
- Test: `test/features/agent_access/data/server/request_authenticator_test.dart`
- Test: `test/features/agent_access/data/server/agent_access_server_security_test.dart`
- Test: `test/features/agent_access/data/server/agent_access_server_e2e_test.dart`

**Interfaces:**
- Consumes (from `package:mcp_dart/mcp_dart.dart`): `StreamableMcpServer({required McpServer Function(String sessionId) serverFactory, String host, int port, String path, FutureOr<StreamableMcpAuthenticationResult> Function(dynamic request)? authenticationHandler, bool enableDnsRebindingProtection, Set<String>? allowedHosts, Set<String>? allowedOrigins, bool enableJsonResponse, McpProtocol protocol})` with `Future<void> start()`, `Future<void> stop()`, `int get boundPort`; `StreamableMcpAuthenticationResult.allow()` / `.unauthorized(errorDescription:)`; `McpServer(Implementation(name:, version:), options:)`; `McpServer.registerTool(String name, {String? title, String? description, inputSchema, required ToolFunction callback})` where `ToolFunction = FutureOr<CallToolResult> Function(Map<String, dynamic> args, RequestHandlerExtra extra)` and `extra.clientInfo?.name`; `McpServer.registerResource(String name, String uri, metadata, ReadResourceCallback)` returning `ReadResourceResult(contents: [TextResourceContents(uri:, text:, mimeType:)])`; `CallToolResult(content: [TextContent(text:)], structuredContent:, isError:)`; `JsonSchema` builders (`JsonSchema.object(properties:, required:)`, `.string(enumValues:, description:)`, `.integer(minimum:, maximum:)`, `.boolean()`, `.array(items:)`). Verify in the package source under `~/.pub-cache/hosted/pub.dev/mcp_dart-2.4.3/` (a) the exact type `registerTool` accepts for `inputSchema` and whether `JsonSchema.fromJson(Map)` exists, (b) the `Host` and `Origin` value formats `allowedHosts` / `allowedOrigins` compare against, (c) whether `authenticationHandler` runs for GET and DELETE as well as POST. If (c) is false, fall back to owning a `dart:io` `HttpServer` and routing each request to a per-session `StreamableHTTPServerTransport.handleRequest(request)` after the checks; the tests below are transport-agnostic.
- Produces:
  - `class RequestAuthenticator { RequestAuthenticator(String Function() expectedToken); bool accepts(String? authorizationHeader); }` using a constant-time comparison over UTF-8 bytes (compare all bytes, no early return; length mismatch still walks the shorter length then fails).
  - `McpServer buildMcpServer({required AgentToolRegistry registry, required AgentToolGate gate, required String appVersion})`: registers every tool with `inputSchema` from the tool's map and a callback that calls `gate.open()`, builds `AgentToolContext(db:, clientName: extra.clientInfo?.name)`, runs the tool, and returns `CallToolResult(content: [TextContent(text: jsonEncode(result))], structuredContent: result)`; an `AgentToolException` becomes `CallToolResult(isError: true, content: [TextContent(text: jsonEncode(e.toJson()))], structuredContent: e.toJson())`; any other exception becomes code `internal` with the exception type name only. Registers each resource likewise.
  - `class AgentAccessStatus { const AgentAccessStatus({required this.listening, required this.port, this.error, this.lastRequestAt}); String get url => 'http://127.0.0.1:$port/mcp'; }`
  - `class AgentAccessServer { AgentAccessServer._(); static final AgentAccessServer instance = AgentAccessServer._(); Future<void> start({required int port, required String Function() token, required McpServer Function() serverFactory}); Future<void> stop(); AgentAccessStatus get status; Stream<AgentAccessStatus> get statusStream; }`. `start` awaits any in-flight `stop` first; a bind failure (`SocketException`) leaves `listening` false with `error` set and does not throw. Each accepted request updates `lastRequestAt`. `allowedHosts = {'127.0.0.1:$port', 'localhost:$port', '[::1]:$port'}` and `allowedOrigins = {'http://127.0.0.1:$port', 'http://localhost:$port', 'http://[::1]:$port'}` in whatever format (b) requires. `enableJsonResponse: true`.

- [ ] **Step 1: Write the failing authenticator test**

```dart
test('accepts the exact bearer token', () { expect(auth.accepts('Bearer $t'), isTrue); });
test('rejects missing header, wrong scheme, wrong token, prefix of token, token plus suffix', ...five expects false...);
```

- [ ] **Step 2: Write the failing security test** (start `AgentAccessServer.instance` on port 0 in `setUp`, read `status.port`; drive raw HTTP with `Socket.connect('127.0.0.1', port)` so the `Host` header is under test control; body is a JSON-RPC `initialize` request)

```dart
test('refuses a foreign Host header', () async { expect(statusLine(await rawRequest(host: 'evil.example:$port', auth: ok)), anyOf(contains(' 403 '), contains(' 421 '), contains(' 400 '))); });
test('refuses a non-loopback Origin', () async { expect(statusOf(await rawRequest(origin: 'https://evil.example', auth: ok)), isNot(200)); });
test('accepts a loopback Origin', () async { expect(statusOf(await rawRequest(origin: 'http://localhost:$port', auth: ok)), 200); });
test('refuses initialize without a token', () async { expect(statusOf(await rawRequest(auth: null)), 401); });
test('refuses a wrong token', () async { expect(statusOf(await rawRequest(auth: 'Bearer nope')), 401); });
test('server is bound to loopback only', () async { expect((await ServerSocket.bind(InternetAddress.anyIPv4, port)).close(), completes); });
test('a tool call without a token is refused even with a session', ...);
```

- [ ] **Step 3: Write the failing end-to-end test** (real database with one diver and two dives; `McpClient(Implementation(name: 'agent-access-test', version: '1.0.0'))` connected through `StreamableHttpClientTransport(Uri.parse(status.url), opts: StreamableHttpClientTransportOptions(requestInit: {'headers': {'Authorization': 'Bearer $token'}}))`; verify the `requestInit` header shape in the package source)

```dart
test('lists the three tools and two resources', () async { expect((await client.listTools()).tools.map((t) => t.name), unorderedEquals(['list_divers', 'query', 'get_records'])); expect((await client.listResources()).resources.map((r) => r.uri), unorderedEquals(['submersion://query-language', 'submersion://units'])); });
test('query then get_records round trip', () async { final q = await client.callTool(CallToolRequest(name: 'query', arguments: {'root': 'dives'})); final ids = (q.structuredContent!['ids'] as List); final g = await client.callTool(CallToolRequest(name: 'get_records', arguments: {'entity': 'dives', 'ids': ids})); expect((g.structuredContent!['records'] as List).first['max_depth_m'], 20.0); });
test('tool error while database unavailable', () async { await tearDownTestDatabase(); final r = await client.callTool(CallToolRequest(name: 'list_divers', arguments: {})); expect(r.isError, isTrue); expect(r.structuredContent!['error'], 'database_unavailable'); });
test('demo mode refuses every tool', () async { DemoModeGate.instance.debugActive = true; ... expect(r.structuredContent!['error'], 'demo_mode'); });
test('client name reaches the tool context', ...a test tool registered only in this test echoes context.clientName == 'agent-access-test'...);
```

- [ ] **Step 4: Run all three to verify they fail**

Run: `flutter test test/features/agent_access/data/server`

- [ ] **Step 5: Implement authenticator, builder and server**

`serverFactory` ignores the session id and returns `buildMcpServer(...)`; `Implementation(name: 'submersion', version: appVersion)`.

- [ ] **Step 6: Run to verify they pass**

Run: `flutter test test/features/agent_access/data/server`
Expected: PASS. Then run the whole feature: `flutter test test/features/agent_access`.

- [ ] **Step 7: Format and commit**

```bash
git add lib/features/agent_access/data/server test/features/agent_access/data/server
git commit -m "feat(agent-access): loopback MCP server with token, host and origin checks"
```

---

### Task 10: Lifecycle providers and app wiring

**Files:**
- Create: `lib/features/agent_access/presentation/providers/agent_access_providers.dart`
- Modify: `lib/app.dart` (`_SubmersionAppState.initState`, near line 185)
- Test: `test/features/agent_access/presentation/providers/agent_access_providers_test.dart`
- Test: `test/features/agent_access/data/server/agent_access_server_lifecycle_test.dart`
- Modify: `test/app_test.dart` only if the eager read needs an override (see Step 5).

**Interfaces:**
- Consumes: `sharedPreferencesProvider` (`settings_providers.dart:1446`), `appLockNotifierProvider` (`lib/core/presentation/providers/app_lock_provider.dart:10`), `hasDesktopWindow()` (`lib/core/services/window_fullscreen.dart:179`), `validatedCurrentDiverIdProvider`, `diverRepositoryProvider`, `diverSettingsRepositoryProvider` (`settings_providers.dart:1451`), `localeProvider` (`settings_providers.dart:3584`), `SettingsNotifier.settingsLoaded` (`:1569`), the pattern of `nearbyLinkManagerProvider` (`lib/features/settings/presentation/providers/nearby_providers.dart:67`).
- Produces:
  - `final agentAccessPreferencesProvider = Provider<AgentAccessPreferences>`
  - `final agentAccessSettingsProvider = NotifierProvider<AgentAccessSettingsNotifier, AgentAccessSettings>` with methods `Future<void> setEnabled(bool)`, `Future<void> setPort(int)`, `Future<void> setConfirmWrites(bool)`.
  - `final agentAccessTokenStoreProvider = Provider<AgentAccessTokenStore>`
  - `final agentAccessStatusProvider = StreamProvider<AgentAccessStatus>` over `AgentAccessServer.instance.statusStream`.
  - `final agentAccessControllerProvider = Provider<AgentAccessController>`; `class AgentAccessController { AgentAccessController(Ref ref); Future<void> sync(); Future<String> regenerateToken(); }`. `sync()` reads settings: enabled and `hasDesktopWindow()` starts (or restarts on a port change) the server with a factory that builds `DiverContextLoader(db: DatabaseService.instance.database, divers: ref.read(diverRepositoryProvider), settings: ref.read(diverSettingsRepositoryProvider), localeTag: ref.read(localeProvider), activeDiverId: () => ref.read(validatedCurrentDiverIdProvider.future))`, `AgentToolRegistry.standard(...)` from the repository providers, `AgentToolGate(isLocked: () => ref.read(appLockNotifierProvider))` and `buildMcpServer(registry:, gate:, appVersion: (await ref.read(packageInfoProvider.future)).version)` (`packageInfoProvider`, `settings_providers.dart:1441`); disabled stops it. The factory runs per MCP session, so it always sees the current database handle. The provider listens to `agentAccessSettingsProvider` and calls `sync()` on each change, awaits `settingsLoaded` before the first start, and registers `ref.onDispose(() => unawaited(AgentAccessServer.instance.stop()))`. `regenerateToken()` rotates the token; running sessions use the new token on their next request because the authenticator reads the token through a function.

- [ ] **Step 1: Write the failing lifecycle tests**

```dart
test('reports port in use and stays stopped', () async {
  final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  await AgentAccessServer.instance.start(port: blocker.port, token: () => 't', serverFactory: fakeFactory);
  expect(AgentAccessServer.instance.status.listening, isFalse);
  expect(AgentAccessServer.instance.status.error, isNotNull);
});
test('start waits for a pending stop on the same port', () async {
  await server.start(port: 0, ...); final port = server.status.port;
  final stopping = server.stop();                 // not awaited
  await server.start(port: port, ...);            // must not throw or fail to bind
  expect(server.status.listening, isTrue); await stopping;
});
```

- [ ] **Step 2: Write the failing provider test**

```dart
test('controller starts the server when enabled on desktop and stops when disabled', () async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS; addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), agentAccessTokenStoreProvider.overrideWithValue(AgentAccessTokenStore(storage: InMemoryKeychain())), ...getBaseOverrides-style settings...]);
  addTearDown(container.dispose);
  container.read(agentAccessControllerProvider);
  await container.read(agentAccessSettingsProvider.notifier).setEnabled(true);
  await pumpUntil(() => AgentAccessServer.instance.status.listening);
  await container.read(agentAccessSettingsProvider.notifier).setEnabled(false);
  await pumpUntil(() => !AgentAccessServer.instance.status.listening);
});
test('controller never starts on a non-desktop platform', ...TargetPlatform.android...);
test('disposing the container stops the server', ...);
```

- [ ] **Step 3: Run to verify they fail**, **Step 4: Implement providers and the controller**

- [ ] **Step 5: Wire `app.dart`**

In `_SubmersionAppState.initState`, next to the nearby manager lines, add `if (hasDesktopWindow()) ref.listenManual(agentAccessControllerProvider, (_, _) {});`. Run `flutter test test/app_test.dart`; if it needs an override (widget tests report Android, so it should not), add `agentAccessControllerProvider.overrideWithValue(...)` to `getBaseOverrides` in `test/helpers/mock_providers.dart`.

- [ ] **Step 6: Run the feature tests, the app test and the architecture guards**

Run: `flutter test test/features/agent_access test/app_test.dart test/architecture test/shared`
Expected: PASS (`provider_change_tick_test` must not flag the new providers; none reads a table directly).

- [ ] **Step 7: Format and commit**

```bash
git add lib/features/agent_access/presentation/providers lib/app.dart test/features/agent_access/presentation test/features/agent_access/data/server/agent_access_server_lifecycle_test.dart
git commit -m "feat(agent-access): start and stop the MCP server from settings"
```

---

### Task 11: Settings page, Data tools row, route and strings

**Files:**
- Create: `lib/features/agent_access/presentation/pages/agent_access_page.dart`
- Create: `lib/features/agent_access/presentation/widgets/agent_access_status_card.dart`
- Create: `lib/features/agent_access/presentation/widgets/agent_access_snippets.dart`
- Modify: `lib/features/settings/presentation/pages/data_tools_page.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/features/settings/presentation/pages/data_settings_pane.dart`, `test/core/router/app_router_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the ten other ARBs
- Test: `test/features/agent_access/presentation/pages/agent_access_page_test.dart`
- Modify: `test/features/settings/presentation/pages/data_tools_page_test.dart`

**Interfaces:**
- Consumes: `DataRowTile` (`lib/features/settings/presentation/widgets/data_row_tile.dart`), `context.pushSettingsPage(route)` (`settings_pane_navigator.dart:20`), `debugModeNotifierProvider`, `demoModeActiveProvider`, `agentAccessSettingsProvider`, `agentAccessStatusProvider`, `agentAccessControllerProvider`, `agentAccessTokenStoreProvider`, `AppScaffoldMessenger` for the copy confirmation SnackBar (no action button, so no persist requirement).
- Produces:
  - `class AgentAccessPage extends ConsumerWidget` at route `/settings/agent-access` (`GoRoute(path: 'agent-access', name: 'agentAccess')`), also mapped in `dataPanePage` as `['agent-access'] => const AgentAccessPage()`, and added to the router test `locations` list.
  - Page content, top to bottom: enable `SwitchListTile`; `AgentAccessStatusCard` (listening or stopped, URL, last request time via the diver's formatter, the error text when set); port `ListTile` opening a numeric dialog (1024 to 65535); token `ListTile` masked by default with Reveal, Copy and Regenerate (Regenerate confirms first); `SwitchListTile` "Ask before applying changes" (stored now, read by PR 4); `AgentAccessSnippets` with three copy buttons.
  - `String claudeCodeSnippet({required String url, required String token})` returns `claude mcp add --transport http submersion $url --header "Authorization: Bearer $token"`.
  - `String claudeDesktopSnippet({required String url, required String token})` returns the JSON `{"mcpServers": {"submersion": {"command": "npx", "args": ["-y", "mcp-remote", "$url", "--transport", "http-only", "--header", "Authorization:${AUTH_HEADER}"], "env": {"AUTH_HEADER": "Bearer $token"}}}}` pretty-printed (the token goes through `env` because Claude Desktop mangles spaces in `args`).
  - `String genericSnippet(...)` returns `URL: $url` and `Header: Authorization: Bearer $token` on two lines.
  - Data tools row: `DataRowTile(icon: Icons.smart_toy_outlined, title: l10n.settings_agentAccess_title, subtitle: l10n.settings_agentAccess_subtitle, route: 'agent-access', enabled: !demoActive)` shown only when `ref.watch(debugModeNotifierProvider)` is true and `hasDesktopWindow()`. `DataToolsPage` becomes a `ConsumerWidget`.
  - ARB keys (English values): `settings_agentAccess_title` "Agent access", `settings_agentAccess_subtitle` "Let an AI agent on this computer read and change your logbook", `settings_agentAccess_enable` "Enable agent access", `settings_agentAccess_statusListening` "Listening", `settings_agentAccess_statusStopped` "Stopped", `settings_agentAccess_lastRequest` "Last request {time}", `settings_agentAccess_portInUse` "Port {port} is already in use", `settings_agentAccess_port` "Port", `settings_agentAccess_token` "Access token", `settings_agentAccess_reveal` "Reveal", `settings_agentAccess_copy` "Copy", `settings_agentAccess_regenerate` "Regenerate", `settings_agentAccess_regenerateConfirm` "Every connected agent will need the new token. Continue?", `settings_agentAccess_confirmWrites` "Ask before applying changes", `settings_agentAccess_confirmWritesSubtitle` "Show a confirmation in Submersion before an agent changes records", `settings_agentAccess_snippets` "Connect a client", `settings_agentAccess_claudeCode` "Claude Code", `settings_agentAccess_claudeDesktop` "Claude Desktop (via mcp-remote)", `settings_agentAccess_generic` "Other clients", `settings_agentAccess_copied` "Copied", `settings_agentAccess_scopeNote` "Agents can see every diver profile on this computer." Each of the ten other locales gets a real translation.

- [ ] **Step 1: Capture the before screenshots** of Settings > Data > Advanced > Data tools (debug mode on), light and dark, phone and desktop widths, before touching the page. Store them outside the repo for the PR gist.

- [ ] **Step 2: Write the failing page test** (`testApp` helper with overrides: prefs, token store with `InMemoryKeychain`, `agentAccessStatusProvider.overrideWith((_) => Stream.value(const AgentAccessStatus(listening: true, port: 47831)))`, a no-op controller)

```dart
testWidgets('shows URL and masked token when listening', (t) async { expect(find.text('http://127.0.0.1:47831/mcp'), findsOneWidget); expect(find.textContaining('Bearer'), findsNothing); });
testWidgets('reveal shows the token, copy puts the Claude Code snippet on the clipboard', ...mock SystemChannels.platform clipboard...);
testWidgets('toggling enable calls setEnabled', ...);
testWidgets('port in use error is shown', ...status error -> l10n text...);
```

- [ ] **Step 3: Update the Data tools page test**: add overrides (`sharedPreferencesProvider`, `logFileServiceProvider`) and two cases: with debug off the row count stays 4; with debug on and `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` it is 5 and the new row has the agent access title.

- [ ] **Step 4: Run to verify they fail**

Run: `flutter test test/features/agent_access/presentation test/features/settings/presentation/pages/data_tools_page_test.dart`

- [ ] **Step 5: Add ARB strings to all eleven files and regenerate**

Run: `flutter gen-l10n`, then `flutter test test/l10n`
Expected: parity and untranslated checks PASS.

- [ ] **Step 6: Implement the page, widgets, row, route and pane entry**; add `'agent-access'` to the router test `locations` list.

- [ ] **Step 7: Run page, settings, router and guard tests**

Run: `flutter test test/features/agent_access test/features/settings/presentation/pages/data_tools_page_test.dart test/core/router/app_router_test.dart test/architecture test/shared`
Expected: PASS (`list_tile_trailing_width_test` bans buttons in `ListTile.trailing`: put Reveal, Copy and Regenerate in a `Wrap` below the tile, not in `trailing`).

- [ ] **Step 8: Capture the after screenshots** (same four of Data tools, plus the Agent access page in light and dark, phone and desktop).

- [ ] **Step 9: Format and commit**

```bash
dart format lib test
git add lib/features/agent_access/presentation lib/features/settings/presentation/pages/data_tools_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/data_settings_pane.dart lib/l10n test/core/router/app_router_test.dart test/features/agent_access/presentation test/features/settings/presentation/pages/data_tools_page_test.dart
git commit -m "feat(agent-access): settings page with token, status and client snippets"
```

---

### Task 12: Entitlement comment, developer doc, whole-suite check and PR

**Files:**
- Modify: `macos/Runner/ReleaseNoSandbox.entitlements` (comment only)
- Create: `docs/developer/agent-access.md`
- Verify: `test/macos_entitlements_test.dart`

- [ ] **Step 1: Refresh the entitlement comment** near `keychain_gated_authenticator.dart:47`'s claim and in `ReleaseNoSandbox.entitlements`: the sandboxed build already carries `com.apple.security.network.server` (#3785) and the agent access server uses it. Run `flutter test test/macos_entitlements_test.dart`.

- [ ] **Step 2: Write `docs/developer/agent-access.md`**: the feature folder map, the `AgentTool` contract, how a tool is registered, the security checks and their tests, the error codes table, the debug-mode gate and which PR removes it, and the roadmap below. Run `python3.14 scripts/check_docs_links.py`.

- [ ] **Step 3: Run the pre-push checks locally**

Run: `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test test/features/agent_access test/architecture test/shared test/l10n test/core/router test/app_test.dart test/macos_entitlements_test.dart`
Expected: all PASS, analyze clean.

- [ ] **Step 4: Commit**

```bash
git add macos/Runner/ReleaseNoSandbox.entitlements lib/core/services/security docs/developer/agent-access.md
git commit -m "docs(agent-access): developer guide and entitlement comment"
```

- [ ] **Step 5: Open the PR** against `main` with `Refs #<tracking issue>`, the Summary naming the debug-mode gate, and the screenshots attached through the project's `PR screenshots: submersion-app/submersion` gist as `<pr>-<nn>-<screen>-<state>.png`. The tracking issue must exist first; the maintainer opens it.

---

## Roadmap (later plans, one PR each, all behind the debug-mode gate until PR 6)

- **PR 2, reads for every entity:** `get_records` for the other eight roots and child entities, `list_records` for non-root entities, summaries for non-dive roots, `awaitServiceStatusIfRead` support so `serviceDue` queries work.
- **PR 3, SQL window:** `sql_query` on a read-only second connection with the same cipher key and `registerAppSqlFunctions`, the denied list pinned to the change log policy by a guard test, row cap, between-rows time cap, and the generated `submersion://schema` resource.
- **PR 4, write core:** change set format, `preview_changes` (pure read), `apply_changes` (atomic, `SyncCoordinator.run`, `ChangeLogScope.run` with new `ChangeLogSource.agent`), `revert_operation`, the in-app confirmation dialog honouring `confirmWrites`, `refreshAfterRuleWrites`, dives first.
- **PR 5 series, write coverage:** one PR per entity family until the coverage guard (every repository create, update or delete method maps to a change set entity) passes.
- **PR 6, release:** remove the debug-mode gate, user documentation, release note.

## Self-review notes

- Spec coverage for this phase: transport and security (Task 9), lifecycle and modes (Tasks 3, 10), diver profiles (Tasks 4, 5), units (Tasks 4, 6, 7), `list_divers` (5), `query` (6), `get_records` dives (7), resources (8), settings page (11), reuse map honoured (4 to 9), risks: stale UI not applicable to reads; database swap (3, 10); demo (3, 9); credentials (5, 7).
- Deferred from the spec to later PRs on purpose: `get_records` for non-dive entities, `list_records`, `serviceDue` queries, `submersion://units/{diver_id}` as a template (served as one `submersion://units` document here), the SQL window, every write path.
- Names used across tasks: `AgentTool`, `AgentToolContext`, `AgentToolException`, `AgentToolErrorCode`, `AgentToolGate.open()`, `DiverContextLoader.load/resolveDiverId`, `rootScopeFor`, `AgentToolRegistry.standard`, `buildMcpServer`, `AgentAccessServer.instance.start/stop/status/statusStream`, `AgentAccessStatus`, `agentAccessSettingsProvider`, `agentAccessControllerProvider`, `agentAccessStatusProvider`, `agentAccessTokenStoreProvider`.
