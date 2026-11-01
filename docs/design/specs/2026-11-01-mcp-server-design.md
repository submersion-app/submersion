# Agent access to the logbook: an in-app MCP server

Date: 2026-11-01
Status: design, awaiting approval
Related: entity query language (`2026-09-25-entity-query-language-design.md`),
change log (#3922), bulk dive edit, rules engine

## Intent

Let a diver point an AI agent of their choice (Claude Desktop, Claude Code,
an IDE agent, anything that speaks the Model Context Protocol) at their own
Submersion logbook, on the same desktop machine, and have it do the things
the app does not have a screen for.

Three moments drove this design:

1. **Make something Submersion does not make.** A presentation about a trip,
   a year in review, a report for an instructor. The agent reads the dives,
   sites, buddies and profiles and builds the artefact elsewhere.
2. **Answer a question the app has no chart for.** "Average descent rate on
   dives deeper than 30 m in a drysuit." The agent computes it from the raw
   data, so the app never needs a screen for every statistic.
3. **Clean up bad data at scale, by intent.** "Those forty dives have the
   buddy misspelled." "My 2024 Red Sea trip logged temperatures in the wrong
   unit." The agent finds and fixes them instead of the diver working row by
   row or bending the bulk edit tools to fit.

Two of the three are reads, and the third is correction rather than entry.
The product is a flexible front end over data the app already holds, not a
second logbook.

## Goals

- Any MCP client on the same machine can read the whole logbook, across
  every diver profile on the device, and change any record the app lets a
  diver edit.
- Reads come three ways: the existing query language for finding records,
  structured fetch tools that return typed JSON, and a read-only SQL window
  for anything the first two cannot express.
- Every write is previewed without touching the database, optionally
  confirmed inside Submersion, applied as one change log operation, and
  revertable from the change log feed like any other operation.
- Agent writes behave exactly like the diver's own edits afterwards: the UI
  refreshes, derived data is recomputed, and the changes sync to the diver's
  other devices.
- Works on the three desktop builds (macOS, Windows, Linux) with nothing
  installed beyond Submersion and the diver's agent client.
- Off until the diver turns it on.

## Non-goals

- Phones and tablets. Mobile agent clients reach MCP servers over the
  network only, and iOS does not allow a background listener. Dives logged
  on a phone reach the agent through the desktop app via sync.
- Working while the app is closed. The server lives inside the running app.
- Any hosted, cloud or relay component.
- A shim or helper executable shipped alongside the app. Clients that only
  speak stdio (Claude Desktop today) use the community `mcp-remote` bridge,
  documented from the settings page.
- A chat or agent UI inside Submersion. The agent lives in the client.
- Exposing credential tables, connected accounts, sync bookkeeping or caches
  in any form.
- Serving media bytes. Media stays as links, the same as everywhere in the
  app.

## Anti-goals

These would make the feature a failure even if every tool worked:

- An agent changing records with no preview and no single Revert.
- A web page, through DNS rebinding or a cross-site request, reaching the
  server.
- The server listening by default, or reachable from another machine.
- Agent writes that skip sync stamping, so they vanish on the next merge or
  never reach other devices.
- The app showing stale lists after an agent writes.

## Constraints

Decided by Eric during the brainstorm:

- Same-machine desktop only, app running, no server component anywhere else.
- No shim binary.
- Preview is a pure computation. It must not open a transaction, not even
  one that is rolled back.
- The in-Submersion confirmation dialog for writes is a per-device setting,
  default on.
- Both structured fetch tools and a read-only SQL window are in scope.
- Writes are available for everything the app lets a diver edit: create,
  update and delete, on every editable entity.
- The agent works across every diver profile on the device.

Hard technical constraints found in the codebase survey:

- The server must run inside the app process and use the app's own database
  handle through the existing repositories and services. A second process
  writing the same file would miss the optional SQLCipher key, the
  `foreign_keys` and `recursive_triggers` pragmas the change log depends on,
  the custom SQL functions compiled text searches call (`unicode_lower`),
  Drift's stream notifications, `SyncEventBus.notifyLocalChange()`, sync
  stamping and the derived-data refresh.
- Writes must take their turn behind sync merges, restores, demo mode
  switches and storage moves through `SyncCoordinator.run`, and must never
  cache the `AppDatabase` handle, because the app can rebuild its
  `ProviderScope`.
- Every new way for data to enter or leave the app checks `DemoModeGate`,
  and the architecture guard tests under `test/architecture/` and
  `test/shared/` scan all of `lib/`.

## Architecture

### Where it lives

A `lib/features/agent_access/` feature (name is the builder's call) owning:

- the HTTP listener and MCP protocol layer,
- the tool and resource implementations, each a thin adapter over an
  existing repository or service,
- the write plan computer and plan store,
- the confirmation dialog,
- the settings page section and its providers.

The server is created by a provider that depends on the database service and
the settings' initial load, so it is torn down and recreated with the
`ProviderScope` and never outlives a database swap. It starts only after
settings have loaded, because tools read diver unit preferences and a
pre-load read would see placeholder defaults.

### Transport

Streamable HTTP, the current MCP remote transport, bound to `127.0.0.1`
only, at a single `/mcp` path. There is no stdio transport in the app.

Client onboarding from the settings page:

- Claude Code and other HTTP-capable clients: a copy-ready
  `claude mcp add --transport http ...` line carrying the URL and token.
- Claude Desktop: a copy-ready `claude_desktop_config.json` entry that runs
  `npx mcp-remote <url> --header "Authorization: Bearer <token>"`
  (exact flags are the builder's call; the snippet must work as pasted).

Protocol layer: the builder picks between the community `mcp_dart` package
(has a Streamable HTTP server transport), the Dart team's `dart_mcp` (check
whether its server side has gained Streamable HTTP by build time) or a small
hand-rolled JSON-RPC layer over `shelf`, which is already a transitive
dependency. Whichever is chosen, the tool and resource implementations must
not depend on the package's types beyond a thin registration layer, so the
protocol package can be swapped.

### Security

All four are requirements, not options. Each has a test.

1. Bind to loopback only. Never `0.0.0.0` or `::`.
2. Accept only requests whose `Host` is `localhost`, `127.0.0.1` or `[::1]`
   (with the port). Anything else is refused before the body is read.
3. If an `Origin` header is present, it must be a loopback origin; otherwise
   refuse. Browsers always send `Origin` on cross-site requests, which is
   the attack this blocks.
4. Every request, including `initialize`, carries
   `Authorization: Bearer <token>`. A missing or wrong token is refused.

The token is 32 random bytes, base64url, generated when the diver first
enables the server, stored with `flutter_secure_storage` (already a
dependency), shown and copyable in settings, with a Regenerate button that
invalidates every configured client at once.

Port: a fixed default chosen by the builder from the unassigned range, user
changeable in settings, because client configs embed the URL. If the port is
busy the server does not start and the settings page says so.

### Lifecycle and modes

- Starts when the app starts if the setting is on; stops when the diver
  turns it off; restarts when the port changes.
- While demo mode is active every tool returns a clear "demo logbook is
  open" error. The builder registers a `DemoSealedFeature` for it so the
  demo guard test covers the path. (My call: the sample logbook exists to
  show the app, and agent writes into it would confuse.)
- Writes run inside `SyncCoordinator.run` so they take a turn behind merges.
  Reads do not.
- The settings page shows whether the server is listening, the URL, and the
  time of the last request.

## Diver profiles

Every tool takes an optional `diver_id`. When omitted it means the active
diver, which matches what the app's own screens show. `list_divers` returns
every profile on the device with its id, name, whether it is active, and its
unit preferences. The read-only SQL window sees all profiles and every row
carries its `diver_id`; the schema resource says so.

The change log already splits an operation that touched two divers' records
into one operation per diver. An agent apply that spans profiles therefore
lands as one operation per diver, each revertable on its own. The apply
result reports every operation id.

Shared library sites and other shared records keep their permission rules;
the repository path enforces them and the agent gets the same refusal a
diver would.

## Units

Storage is metric. Tool responses carry metric values with the unit in the
key name (`max_depth_m`, `water_temp_c`, `start_pressure_bar`,
`weight_kg`), never bare numbers. `list_divers` and a `units` resource
report each profile's display preferences so the agent can convert when it
presents. Tool input schemas name units the same way.

The query language is the one place bare numbers carry a unit by convention
(the diver's preference). A `query` call parses with the named (or active)
diver's preferences, exactly as the app's own filter bar does, and the tool
description says so.

## Reads

### `list_divers`

Profiles on the device: id, display name, active flag, unit preferences,
dive count.

### `query`

Input: `root` (one of the registry's list roots: dives, sites, equipment,
trips, buddies, centers, certifications, courses, species), `query` (query
language text, may be empty for "everything"), `diver_id`, paging cursor,
`include_summaries` flag.

Output: matching ids, total count, and when asked a compact summary per
record (`DiveSummary` for dives; a small builder-defined summary for other
roots). A parse failure returns the offset, message and suggestions the
parser already produces, as a structured error, never an exception.

Reuses the parse, validate, compile, run chain in `lib/core/query/` and
`lib/features/query/data/query_id_set_runner.dart`, with the diver scope
applied the way `query_id_set_providers.dart` applies it, including the
`serviceDue` cache wait when that field is read.

### `get_records`

Input: `entity`, `ids` (capped per call, builder picks the cap), `fields`
(optional list; omitted means the default full document), `include`
(children such as tanks, buddies, tags, weights, sightings, media links,
profile samples), `diver_id`.

Output: one JSON document per record, metric with unit-named keys, children
nested. Profile samples are returned only when asked and are paged, since a
long dive has thousands of samples.

There is no domain `Dive.toJson()`. The builder writes a small mapper per
entity over the domain entities (or `DiveSummary` plus the detail loaders),
not over Drift rows or the sync serializer, so the shape is stable and
device-local and credential columns can never leak by accident.

### `list_records`

For entities that are not query roots (checklists, documents, incidents,
planner plans, templates, saved queries, cylinder configs, dive computers
and the child entities), a paged listing by `entity` and `diver_id` with a
compact summary per record, so an agent can find an id to fetch or change
without writing SQL. (My call; the SQL window could do it, but a structured
path keeps the common case typed.)

### `sql_query` (read-only window)

Input: `sql` (a single statement), `params` (optional bound parameters),
`max_rows`.

Output: column names, rows, whether the row cap was hit, elapsed time.

Rules:

- Runs on a second in-process connection opened read-only (SQLite read-only
  open mode plus `PRAGMA query_only`), with the same SQLCipher key and the
  same custom SQL functions registered as the main connection. Read-only is
  enforced by the engine, not by inspecting the SQL text.
- Statements that touch a denied table or column are refused. The denied
  set is its own list, kept in one file: tables holding credentials, keys
  or tokens (connected accounts, network credential hosts, shared library
  keys), sync bookkeeping (`sync_*`), nearby peers, local publish and
  subscription state, and the change log tables, plus the credential
  columns the change log policy lists
  (`lib/core/database/change_log/change_log_policy.dart`). Derived analytics
  tables (dive derived metrics, sensor summaries, quality findings,
  equipment findings and service status, trip day weather, rule runs) stay
  readable: they are exactly what the statistics case wants. A guard test
  pins the list against the policy: every table the policy classes as
  excluded must appear either in the denied list or in an explicit
  "readable derived" list, so a new excluded table forces a decision.
  Enforcement must come from the engine's own view of the statement (for
  example, `EXPLAIN` output's table opens mapped through `sqlite_schema`) or
  from views that omit the denied columns, never from a regex over the text.
  The builder picks the mechanism; the test suite includes an attempt to
  read each denied table through a view, a subquery and a CTE.
- A row cap and a time cap, both reported in the result and both the
  builder's numbers. The pinned `sqlite3` package exposes no interrupt and
  the native build omits the progress callback, so the time cap is enforced
  by stepping the cursor row by row and stopping between rows, closing the
  statement. A sort or aggregate over a huge join that produces no row for a
  long time cannot be stopped this way; the tool description says so, and
  the row cap still bounds the result. Calling `sqlite3_interrupt` through
  FFI is allowed only with a test on all three desktop platforms, and CI
  runs Linux only, so it is optional, not required.
- One statement per call. Multiple statements are refused.

### Resources

- `submersion://schema`: the tables and columns the SQL window may read,
  with a one-line meaning per column, units, enum values, and the join keys.
  Generated from the Drift schema at build time or startup, not maintained
  by hand, with the denied tables and columns removed.
- `submersion://query-language`: the grammar and the field list per root.
  The grammar section of the query language spec and the per-entity field
  registries are the source; the builder generates the field list from the
  registry so it cannot drift.
- `submersion://units/{diver_id}`: that profile's unit preferences.

Tool and resource text is English only. It is read by agents, not shown to
divers.

## Writes

### Coverage and release gate

Every entity the app lets a diver create, edit or delete is in scope, and
the feature does not ship until all of them are covered (Eric's decision).
The reviewer's census of `lib/features/*/data/repositories` gives the
checklist: dives and their children, sites and site features, equipment
with components, sets, locations, service records, schedules and shares,
trips, checklists, buddies, centers, certifications and currency rules,
courses and requirements, species, tags, dive types, roles, documents,
incidents, planner plans, saved queries, cylinder configs, weight entries,
pre-dive templates and dive computers. The builder's plan enumerates every
create, update and delete method and maps each to a change set entity.

A guard test under `test/architecture/` fails when a repository under
`lib/features/*/data/repositories` gains a create, update or delete method
that no change set entity covers, so "any record" stays true after
release.

Until the last write PR lands, the settings section, the server and the
release note stay behind the debug mode flag (`DebugModeNotifier`), so no
diver sees a half-covered feature. Read tools may be complete earlier, but
they ship with the writes.

### The change set

A write request is a change set: an ordered list of operations, each one of

- `create` with `entity`, `diver_id`, and field values,
- `update` with `entity`, `id`, field values, and relation changes
  (`add`/`remove`/`set` for tags, types, buddies, equipment, courses, site,
  tanks, weights, sightings),
- `delete` with `entity` and `id`,

plus a `label` the agent writes in the diver's language, used as the change
log operation label.

Field names and units follow the `get_records` documents, so an agent can
read a record, edit the JSON, and send it back.

### `preview_changes`

Pure computation. The server reads the current rows for every referenced
record, computes the resulting values, and returns a plan:

- per record: entity, id (or "new"), diver, each changed field with old and
  new value, relation additions and removals;
- blocked items with a reason: record not found, value outside the sanity
  range the query registry and `QualityThresholds` already define, a
  permission the repository would refuse, a referenced record that does not
  exist (an unknown buddy id), an entity the change log cannot revert;
- counts per entity and per diver;
- a `plan_id` and an expiry (my call: 15 minutes).

The plan stores, for every referenced record, the version marker it was
computed against (`updated_at` or `hlc`, builder's choice) so apply can
detect changes made since.

No transaction is opened, no trigger fires, no stream ticks. A test asserts
this by wrapping the query executor and counting `beginTransaction` and
table-update notifications during a preview: both must be zero.

The rule engine's existing `preview()` runs the change and rolls back; it is
not reused for this. Its action vocabulary
(`lib/features/rules/domain/entities/rule_action.dart`) and the bulk edit
request (`lib/features/dive_log/domain/entities/bulk_edit_request.dart`)
are the right starting points for describing a change, extended to cover
the fields they leave out (depth, water temperature, date and time) and the
other entities.

### Confirmation inside Submersion

When the setting is on (default), `apply_changes` does not proceed until
the diver confirms in the app. The app raises its window and shows a dialog
naming the client (from the MCP `initialize` client info), the label, and
the counts per entity and per diver, with the full plan one tap away in the
same list shape the agent received. Allow applies; Deny returns a
`not_confirmed` error to the agent with no change made. If the diver does
nothing for five minutes (my call) the request fails the same way.

When the setting is off, `apply_changes` proceeds at once. The setting is
per device and does not sync.

### `apply_changes`

Input: `plan_id`.

Behaviour:

1. Refuse if the plan is expired or unknown.
2. Re-read the version markers. If any referenced record changed since the
   preview, refuse the whole plan with the list of changed records and ask
   for a new preview. All or nothing (my call): the diver confirmed exactly
   this plan, so a partial apply would not be what they saw.
3. Wait for the confirmation when enabled.
4. Inside `SyncCoordinator.run`, open a `ChangeLogScope.run` with a new
   source `agent` and the agent's label, and inside the scope body open one
   database transaction around every operation (the scope itself stays
   outside the transaction, as its documentation requires; the rule engine
   does the same). Perform every operation through the existing repository
   methods (`updateDive`, `updateSite`, `updateBuddy`, `updateEquipment`,
   the bulk primitives, the create and delete methods); their own
   transactions nest into the outer one. The repositories do the
   validation, child writes, sync stamping (`markRecordPending`) and change
   notifications, which Drift defers to the commit. The server never writes
   a table directly.
5. The apply is atomic. If any repository refuses an operation, the
   transaction rolls back, nothing has changed, and the result names the
   refusing items so the agent can re-preview without them. A plan size cap
   (builder's number) keeps the transaction short enough for the UI and
   sync to tolerate.
6. After the commit, call `refreshAfterRuleWrites` (or its equivalent for
   the entities touched) so quality scans, sensor summaries and derived
   metrics run.
7. Return the change log operation ids (one per diver touched) and counts.

The scope body contains the writes and nothing else, so a diver's own save
during the apply is not filed under the agent's operation.

### `revert_operation`

Input: a change log `operation_id` the agent received from `apply_changes`.

Calls `settleAll()`, plans the revert with `ChangeLogRevertService`, and
executes it. Returns the same "changed since" and blocked information the
app's own Revert shows. Operations with another source can be reverted too;
the change log already allows that from the feed, and refusing it here
would only make the agent tell the diver to click the button themselves.

### Change log integration

- New `ChangeLogSource.agent` with label and icon in
  `lib/features/change_log/presentation/change_log_labels.dart` and ARB
  strings in every locale. The feed row shows the localized source label
  and the agent's own label, the same way a rule run shows the rule's name.
  The client name is not persisted (no change log schema change); it
  appears in the confirmation dialog and in the apply result.
- Existing settle, merge and revert behaviour is unchanged. The settle
  scheduler's quiet period means a revert immediately after an apply must
  call `settleAll()` first; the `revert_operation` tool does.

## Settings page

A per-device section inside the existing Data tools page (Settings > Data >
Advanced > Data tools, `data_tools_page.dart`), Eric's placement, visible
on desktop only. Until the write surface is complete (see Coverage and
release gate) the section is shown only while debug mode is on:

- Enable agent access (off by default). Turning it on generates the token
  and starts the server.
- Status: listening or not, URL, last request time, the error if the port
  is busy.
- Port, editable.
- Token: masked with reveal, Copy, Regenerate.
- Ask before applying changes (on by default).
- Copy snippets: Claude Code, Claude Desktop (via `mcp-remote`), generic
  URL and header.
- A short explanation of what an agent can see, naming the all-profiles
  scope, and a link to the user documentation.

All settings here use the SharedPreferences pattern (`DebugModeNotifier`
style), never the synced diver settings, because a device's listening state
and token must not travel to other devices.

## Reuse map

| Need | Existing code |
| --- | --- |
| Find records by intent | `QueryParser`, `validateQuery`, `compileQuery`, `QueryIdSetRunner` (`lib/core/query/`, `lib/features/query/data/`) |
| Diver scope for query roots | `query_id_set_providers.dart`, `VisibilityFilter` |
| Compact dive rows | `DiveSummary`, `DiveRepository.getSummariesByIds` |
| Describe a change | `BulkEditRequest`, `BulkField`, rule actions |
| Sanity ranges | query registry ranges, `QualityThresholds` |
| Apply writes correctly | repository `update*`/`create*`/`delete*` methods, bulk primitives, `markRecordPending` |
| One revertable operation | `ChangeLogScope.run`, `ChangeLogRevertService`, `ChangeLogRepository.settleAll` |
| Post-write refresh | `refreshAfterRuleWrites` |
| Serialize with merges | `SyncCoordinator.run` |
| Units | `UnitFormatter`, `unitPrefsFromSettings` |
| Demo mode | `DemoModeGate`, `DemoSealedFeature` |
| Per-device setting | `DebugModeNotifier` pattern |
| Secrets | `flutter_secure_storage` |
| Sandbox | macOS `Release.entitlements` already has `network.server` (#3785) |

## Risks and answers

| Risk | Answer in this design |
| --- | --- |
| UI stale after agent writes | Writes go through repositories, which notify Drift and the sync bus |
| Writes never sync | Repositories stamp `markRecordPending`; the server never writes tables directly |
| Diver's own edit filed under the agent's operation | Scope body is the writes only; apply is short |
| Web page reaches the server | Loopback bind, Host allowlist, Origin check, bearer token on every request |
| Credentials leak through SQL | Own denied list, pinned to the change log policy by a guard test, enforced by the engine's view of the statement, tested through views, subqueries and CTEs |
| Runaway SQL | Row cap and a between-rows time cap; the limit for statements that stream no rows is stated to the agent |
| Preview has side effects | Pure read computation; test asserts zero transactions and zero table updates |
| Plan drifts from what was confirmed | Plan id, version markers, all-or-nothing staleness refusal |
| Database swap mid-request | Server owned by a provider tied to the database service; `SyncCoordinator.run` for writes |
| Demo logbook edited by an agent | Every tool checks the demo gate |
| Unit confusion | Unit-named keys everywhere, units resource, query tool states its convention |

## Testing

TDD applies. Minimum coverage:

- Transport: loopback bind; refused `Host`; refused `Origin`; missing and
  wrong token on `initialize` and on a tool call.
- `query`: parse error shape; diver scope; cross-profile by `diver_id`;
  paging.
- `get_records`: no device-local or credential column in any document
  (assert against the policy's column lists); samples only when asked.
- `sql_query`: a write statement fails on the read-only connection; each
  denied table refused directly, through a view, a subquery and a CTE; row
  cap; time cap stops a long row-producing statement between rows.
- `preview_changes`: zero `beginTransaction`, zero table updates; blocked
  reasons; cross-diver counts.
- `apply_changes`: one operation per diver with source `agent`; stale plan
  refused; `not_confirmed` on Deny and on timeout; a repository refusal
  rolls back every operation; records stamped pending;
  `refreshAfterRuleWrites` called.
- `revert_operation`: round trip restores values and deleted records.
- Demo mode: every tool refuses while the gate is active, and the test
  restores the gate (global state scan).
- One end-to-end test driving the server over loopback with an MCP client
  library, covering `initialize`, a read, a preview and an apply.
- Coverage guard: every repository create, update or delete method maps to
  a change set entity.
- Architecture guards (`test/architecture/`, `test/shared/`) stay green
  after every new `lib/` file.

## Documentation

- User guide page: what agent access is, what an agent can see and change,
  how to connect Claude Code and Claude Desktop, how to revert, how to turn
  it off.
- Developer page: the tool surface, the change set format, how to add a
  tool, how the denied set is derived.
- Release note under the current version's notes.

## Left to the builder

- Protocol package choice and the thin registration layer.
- Port number, caps, timeouts, plan expiry, paging sizes.
- Exact JSON shapes for documents, summaries, plans and errors, kept
  consistent across entities.
- Mechanism for enforcing the denied table set on the SQL window.
- How the schema and query-language resources are generated.
- Version marker used for staleness.
- Dialog layout and how the window is raised on each platform.
- Feature folder name and file split (200 to 400 lines per file, 800 max).
- Whether to add MCP prompts (for example a "clean up buddy names" recipe).
  Not required.
- Phasing. A natural order: server core with security, `list_divers`,
  `query`, `list_records` and `get_records`; then the SQL window and
  resources; then writes, the dialog and the change log source, entity
  family by entity family; then docs and snippet polish. Each phase is a PR
  with its own issue link, and everything stays behind debug mode until the
  final write PR removes the gate.

## Later, not now

- A stdio shim shipped with the app, if divers find the bridge too hard.
- Rendering profile images or exporting files from a tool, for the
  presentation case.
- Curated statistics tools over `InsightsRepository`.
- Subscribing an agent to change notifications.

## Decision record

| Decision | By |
| --- | --- |
| Same machine, app running, nothing hosted | Eric |
| No shim binary; `mcp-remote` bridge for stdio-only clients | Eric |
| Preview never opens a transaction | Eric |
| Confirmation dialog optional, default on | Eric |
| Structured fetch tools and read-only SQL, both | Eric |
| Writes for every editable entity, create, update, delete | Eric |
| Agent works across all diver profiles | Eric |
| Every editable entity writable before release; hidden behind debug mode until then | Eric |
| Settings section inside the Data tools page | Eric |
| Streamable HTTP on loopback, bearer token, Host and Origin checks | design |
| Server off by default; per-device settings | design |
| Tool list and resource list above | design |
| Plan id with expiry; all-or-nothing staleness refusal | design |
| `revert_operation` included; can revert any source | design |
| Demo mode refuses every tool | design |
| Metric values with unit-named keys; query parses in the diver's units | design |
| SQL denied list is its own list (credentials, sync, peers, change log), pinned to the policy by a guard test; derived analytics readable | design |
| Apply is atomic: one transaction, any refusal rolls back everything | design |
| Time cap by stepping rows; FFI interrupt optional | design |
| Client name shown live, not persisted in the change log | design |
| `list_records` tool for entities that are not query roots | design |
