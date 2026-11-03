# Agent access (MCP server)

Agent access lets an AI agent on the same desktop machine read and change the
diver's logbook through the Model Context Protocol. The
design is `docs/design/specs/2026-11-01-mcp-server-design.md`; this page is
the map of the code and the rules it keeps.

Until the write surface is complete, agent access exists only while debug
mode is on, and only on macOS, Windows and Linux: `agentAccessAvailableProvider`
gates both the settings entry point (Settings > Data > Advanced > Data tools >
Agent access) and the listener itself, so turning debug mode off stops a
running server and a persisted "enabled" setting starts nothing without it.
The final write PR removes the debug clause from that one provider; see the
roadmap at the end of `docs/design/plans/2026-11-01-mcp-server-pr1-server-core.md`.

## Where the code lives

Everything is under `lib/features/agent_access/`:

| Path | Responsibility |
| --- | --- |
| `domain/agent_access_settings.dart` | Per-device settings value type and the default port (47831) |
| `domain/agent_tool.dart` | The `AgentTool` interface and `AgentToolContext`; tools never see the protocol package |
| `domain/agent_tool_error.dart` | `AgentToolErrorCode` and `AgentToolException`, the only way a tool refuses |
| `data/agent_access_preferences.dart` | SharedPreferences wrapper (never synced diver settings) |
| `data/agent_access_token_store.dart` | Bearer token in secure storage: 32 random bytes, base64url |
| `data/agent_tool_gate.dart` | Demo mode, app lock and database-available checks, run before every tool |
| `data/diver_context.dart` | Resolves the profile a call acts as: settings, unit prefs, name index |
| `data/root_scope.dart` | The SQL fragment that limits a query root to what one diver may see |
| `data/service_status_overlay.dart` | The named diver's service verdicts, as a CTE that shadows the cache table |
| `data/records/` | The record catalogue: scopes, the reader, the repository bundle |
| `data/records/families/` | One file per family of entities, each returning its catalogue entries |
| `data/documents/` | JSON mappers per family, metric with unit-named keys, and `document_dates.dart` |
| `data/sql/` | The SQL window: the denied set, the bytecode guard, the worker and its runner |
| `data/writes/` | The write catalogue: change sets, field codecs, the planner, the plan store and the applier |
| `data/writes/families/` | One file per family of writable entities, each going through its repository or service |
| `data/tools/` | `list_divers`, `query`, `get_records`, `list_records`, `sql_query`, `preview_changes`, `apply_changes`, `revert_operation`, and the registry |
| `data/resources/` | `submersion://query-language`, `submersion://units` and `submersion://schema` |
| `data/server/` | The loopback listener, the bearer check, and the adapter onto `mcp_dart` |
| `presentation/providers/` | Settings notifier, token store, status stream, lifecycle controller |
| `presentation/pages/`, `presentation/widgets/` | The settings page, status card and client snippets |

## Adding a tool

1. Implement `AgentTool`: a `name`, an English `description` written for an
   agent, an `inputSchema` as a plain JSON Schema map, and `call(args,
   context)`. Resolve the diver with `DiverContextLoader` and read the
   database from `context.db`, never from a cached handle.
2. Refuse with `AgentToolException`; pick an existing `AgentToolErrorCode`
   or add one with a snake_case `wire` name.
3. Register it in `AgentToolRegistry.standard`.
4. Emit metric values with the unit in the key (`max_depth_m`,
   `water_temp_c`, `start_pressure_bar`, `weight_kg`) and dates through
   `document_dates.dart` (see The date rule). A tool that emits times puts
   `kDocumentDateRule` in its description.
5. Test it against a real in-memory database (`setUpTestDatabase()`), and
   add an end-to-end case to `agent_access_server_e2e_test.dart` when the
   tool changes what a client can observe.

`buildMcpServer` wraps every tool: the gate runs first, the result becomes
`CallToolResult` with the JSON in both a text block and `structuredContent`,
and any `AgentToolException` becomes an `isError` result carrying
`{"error": <wire code>, "message": ..., "details": ...}`. On the 2026
protocol the SDK drops `structuredContent` from error results, so clients
read the text block for errors.

## Adding an entity

Every entity an agent can read is one entry in the catalogue. To add one:

1. Write its mapper in the family's file under `data/documents/`: metric,
   unit-named keys, never bytes, no `created_at` or `updated_at`.
2. Add a `RecordEntity<T>` to the family under `data/records/families/`: the
   wire `name`, the `table`, a `scope`, a `load`, the `document`, and
   `summaryKeys`. Give it a `parentColumn` when `parent_id` makes sense, and
   `blocks` for children a caller asks for by name. A child whose repository
   only reads by parent is a `childEntity`, which wires the read by id.
3. Copy `scope` from the repository's own list method, so the agent sees what
   the app shows that profile: `owned`, `ownedOrNull`, `ownedOrBuiltIn`,
   `ownedNullOrBuiltIn`, `ownedOrShared`, `rootScope`, `viaParent`, `everyone`,
   or a small function when the rule is its own. A family test pins the entry
   against that list method.
4. Add a repository to `RecordRepositories` if it needs a new one. Keep it
   `late final`, because the bundle is built per request.

A block that lists rows another entity governs passes them through
`RecordReader.keepVisible` with that entity's scope, so a block never shows a
row the entity itself would refuse.

`record_catalog_guard_test.dart` fails on a tracked table with no decision: a
new table must be an entity, a link, folded into a parent, or listed as
unexposed with a reason. Every read in a family test also runs through
`expectCleanDocument`, which refuses a credential key, a device-local key or
bytes anywhere in a result.

`diver_settings` is the one document built from a Drift row. The table has over
two hundred columns and no domain shape, so `settingsDocument` drops the
device-local and bookkeeping columns and renames the dimensioned ones from
`kSettingUnitKeys`. A new `REAL` column must join that map or
`kUnitlessSettings`, or the guard fails.

## Writes

A write takes two calls. `preview_changes` reads and diffs, and `apply_changes`
runs the plan it stored. The preview never opens a transaction: a rolled back
one would still fire triggers and tick streams, and
`write_planner_test.dart` counts both to prove it.

Apply checks the plan is still true, asks the diver when the setting is on,
then checks again inside `SyncCoordinator.run`, because the dialog can stay
open for five minutes. It then opens `ChangeLogScope.run` with source `agent`,
and inside that one transaction around every operation. A refusal rolls back
everything. The settler files other divers' records under `operation:diver`,
so one apply can return several operation ids, each revertable alone. A
scope that cannot open a change log entry carries on for a diver's own save,
but an apply checks for its entry before the first write and refuses without
one, so every agent change can be reverted. A plan also keeps the database
it was previewed on, so a restored logbook with the same rows refuses it.

A plan with a blocked item gets no `plan_id`, so a diver is never asked to
allow something that cannot run. The dialog raises and focuses the window, so Allow
arms only after `kAgentWriteAllowDelay`, and a click meant for another window
cannot answer it. Deny is live at once. A plan is single use and lasts 15 minutes.
Plans live in `agentWritePlanStoreProvider`, not in the registry, because the
protocol builds a server per request.

A version marker is `updated_at` plus the current ids of each relation the
plan changes, since a link can change without touching its parent row. A record
a plan links to gets a marker too, so one that goes away refuses the plan. A
marker also carries a footprint of what the plan worked out from rows with no
version of their own, a delete's reach or a site's types, and apply works it
out again, so a child added since the preview refuses the plan as well.

What a plan lists is what a write does. An entity reports what an update does
beyond what it names through `sideEffects`: a site link snaps on water type,
entry and exit methods and dive types, a visibility band clears the measured
values, and a moved dive takes its entry and exit times along. A field the set
names is written after the snap and wins, even if it equals the current value.
A field whose write does something even when it equals the row is listed in
`effectFields`, as a dive's `visibility` is, so the plan cannot drop it as
unchanged.

`deleteReach` reports what a delete takes with it. `records` holds what has a
life of its own, such as documents, media and certifications, and `parts` the
rows that only exist as part of the record, such as a dive's tanks. `unlinked`
holds what stays but loses its link, and `linkedDives` the dives that do,
including another profile's. The dialog shows all of that without being opened
except `parts`, which it keeps under the details, since a dive with a profile
has many. `countCascaded` and `countUnlinked` read these from the schema's
foreign keys, so a table added later is counted without anyone remembering to.

The change log covers rows in this database, and a rollback covers them too.
What neither can take back is a blob that has left the media store. A blob
delete is queued as an intent that waits for a drain and does nothing if its
row has come back, so a rollback or revert before the drain loses nothing.
Dive and site deletes pass `holdRemoteMedia`, so a coordinator wired to start
the worker would still wait.

### Adding a writable entity

1. Add a `WritableEntry` under `data/writes/families/` and list it in
   `WriteCatalog`. Its `name` and field keys are the read catalogue's, so a
   document can be edited and sent back.
2. Write through a repository or service, never a table. Most `copyWith`
   methods use `??` and cannot clear a field, and rebuilding a whole entity
   loses any field the mapper forgets, so use a partial companion
   (`BulkDiveEditService`, `BuddyRepository.updateFields`) or clear flags
   (`DiveSite.copyWith`).
3. Add a test that every key in `fields` reaches its column, and read each
   value back through the document.
4. Implement `refuse` for what the repository would quietly ignore.
   `updateSite` keeps a library's values and reports success, so
   `SiteWrites.refuse` blocks that case in the preview.
5. Implement `sideEffects` and `deleteReach` for anything the write path does
   beyond the columns it was given, or a diver allows a change they cannot see.
   Read a repository's delete for what it clears by hand: `countCascaded` sees
   the schema, not that code. A dive's delete also reclaims stored import
   files no other dive uses, which no foreign key shows. A record that goes
   only once everything holding it goes, such as an import file several
   dives share or a photo of a dive and its site, depends on what else the
   set deletes: read `alongside` and count it on one item, so the dialog's
   totals add up.
   A relation whose write copies values from its target, as a dive's site
   does, sets `copiesTarget`, so it cannot follow a change to that target
   earlier in the same set: the plan works out the copy from the target as it
   stands, and the write would copy the changed one.
6. Implement `deletedDocumentOwners` with every owner a delete takes documents
   from, so a refused plan can arm their reminders again. A buddy's lists their
   certifications too.
7. Hold remote media on any delete that cascades to it.
8. Move the repository's methods from
   `test/architecture/agent_write_coverage_baseline.txt` to `covered` in
   `agent_write_coverage_test.dart`. That guard fails on a new repository
   write no entity reaches, and on a baseline line that has gone.

### Known limits

- Many MCP clients time out a request after about a minute, which is shorter
  than the dialog. The server keeps asking, so a later Allow applies a change
  the agent reported as failed. While that dialog is open a second apply
  answers `confirmation_pending`, so a retry cannot queue the same change, and
  the `apply_changes` description tells agents to read the records first.
- The plain `DiveRepository` and `SiteRepository` the tools use never start
  the media worker, so `holdRemoteMedia` changes nothing there: an intent
  drains when anything next starts the worker, and a revert after that
  re-queues the upload through `repairRestoredMedia`.
- A change set cannot refer to a record it creates. Linking a new buddy to a
  dive takes two applies.

## The date rule

Each key's suffix says what kind of date it holds, and `document_dates.dart`
has the only three formatters. Pick by how the value is stored, not by how it
reads: a repository that reads with `isUtc: true` usually holds a wall clock.

| Key | Meaning | Formatter |
| --- | --- | --- |
| `date_time`, `*_time` | Local wall clock of the dive or event, with a nominal `Z`; do not shift it | `wallClock` |
| `*_date` | A calendar date, `2025-03-14` | `calendarDate` |
| `*_at` | A true instant in UTC | `instant` |

`calendarDate` reads the value as held and never goes through `toUtc()`:
most of these are stored as local midnight, so a shift would move them to the
day before.

`wallClock` asserts that its value is flagged UTC, because the right conversion
depends on where a local-flagged value came from. A Drift `dateTime()` column
written from a wall clock reads back local-flagged and needs `toUtc()`. A local
`DateTime` whose digits are the wall clock, such as a plan's start, needs
`asWallClockUtc`.

## Service status in queries

`serviceDue` and `nextServiceDue` compile against `equipment_service_status`,
a local cache that holds the active diver's verdicts only. `query` does not
read it. `serviceStatusOverlay` evaluates the named diver's clocks through
`evaluateServiceClocksForItems`, the same batch the notification scheduler
uses, and returns a CTE named after the cache. SQLite resolves that name first,
so the compiled SQL runs unchanged, the answer is right for any profile, and a
read tool writes nothing. It is why `awaitServiceStatusIfRead` is not used
here: that provider can only answer for the active diver.

## The SQL window

`sql_query` runs one statement on a connection of its own, opened read-only
with `PRAGMA query_only` on a worker isolate and closed when the call ends.
Nothing holds a handle between calls, so a restore, a storage move or an
encryption change needs no handling: the runner reads the path and key on each
call. The runner is a static on the controller rather than part of the
per-request server, because its busy flag has to outlast a request and a scope
rebuild, as a statement that cannot be stopped does.

Read-only says nothing about credentials, so a statement is inspected before
it steps. The bundled SQLite is built with `OMIT_AUTHORIZATION` and
`OMIT_PROGRESS_CALLBACK`, so there is no authorizer to ask. `EXPLAIN` is the
engine's view that remains: by then views, CTEs and subqueries have been
flattened, so every read shows up as an `OpenRead` of a root page, and
`SqlReadCatalog` maps root pages through `sqlite_schema`. `inspectSqlProgram`
fails closed:

- An unknown root, a root in another database and any virtual table refuse.
  That last one covers `pragma_*` and `json_each`, because `VOpen` carries only
  a pointer and they cannot be told apart.
- A denied column refuses at its `Column` step, and an index holding one
  refuses when it opens, because a seek compares the value with no `Column`
  step at all.
- `ATTACH`, `BEGIN` and `PRAGMA` all report read-only, so `sqlLeadingKeyword`
  allows only `SELECT`, `WITH` and `VALUES`. It is the only text check, and it
  is an allowlist. Never add a check that looks for a table name in the text.

Classifying a table: a table the change log policy excludes must go in
`kSqlDeniedTables` or `kSqlReadableExcludedTables`, and a test fails until it
does. A table the policy does not know is refused at runtime. A new credential
column goes in `changeLogCredentialColumns`, which the window reads too. A
column the log should keep recording but an agent should not see goes in
`kSqlDeniedColumns` directly, as `manifest_url` does: a private feed's URL can
carry an access token.

`submersion://schema` comes from the live schema, so it cannot drift. Its notes
come from the comments in `lib/core/database/tables/`, because Drift keeps no
descriptions at runtime. After changing a table, run
`dart run tool/generate_sql_column_notes.dart`; a test fails until the
generated file matches.

SQLite builds a value inside its own step, so only its own limit can bound the
memory; the result size cap applies later and protects the reply, not the
process. `sql_value_limit.dart` sets `SQLITE_LIMIT_LENGTH` through
`sqlite3_limit`, bound directly because the package does not bind it. That
works where the library exports the symbol, as on macOS. The package's Linux
build exports only the functions it binds, so there the call answers false and
a statement can still build a value of up to a gigabyte. The Windows build marks
every API function `dllexport`, so it should work there, but nobody has run it.

A statement that stays inside one native step cannot be stopped: `Isolate.kill`
acts only when the step returns. The call answers with `still_running`, and
later calls answer `sql_busy` until the worker ends. Until then the statement
costs more than its thread: it holds a read snapshot, so the WAL cannot reset
past it, a recursive `UNION` or a sort keeps growing its temporary storage, and
on Windows its open file can block a restore or a storage move.
`sqlite3_interrupt` through FFI would fix this, but it needs a test on all three
desktop platforms and CI runs Linux only.

## Security rules and their tests

All four hold on every request and each has a test in
`test/features/agent_access/data/server/`:

| Rule | Where | Test |
| --- | --- | --- |
| Bind `127.0.0.1` only | `AgentAccessServer.start` | `server is bound to the IPv4 loopback address only` |
| `Host` must be `localhost`, `127.0.0.1` or `::1` | `mcp_dart` DNS rebinding protection, allowlist set by the server | `refuses a foreign Host header` |
| `Origin`, when present, must be a loopback origin | same | `refuses a non-loopback Origin` |
| `Authorization: Bearer <token>` on every request, `initialize` included | `RequestAuthenticator`, constant-time compare | the three token tests |

Without OAuth metadata the package answers a failed token check with 403.
Regenerating the token applies to the next request; the server reads the
token through a function.

## Error codes

| Wire code | Meaning |
| --- | --- |
| `demo_mode` | The sample logbook is open; every tool refuses |
| `app_locked` | App Lock is engaged |
| `database_unavailable` | A restore or storage move has the database swapped out |
| `invalid_argument` | An argument the schema allows but the tool cannot use |
| `parse_error` | Query language parse or validation failure, with offset and suggestions |
| `unknown_diver` | `diver_id` names no profile on this device |
| `not_found` | No such tool or record |
| `too_many_ids` | More ids than `get_records` accepts in one call |
| `sql_refused` | `sql_query` would read something denied, or is not one read-only statement; names the table or column |
| `sql_error` | SQLite rejected the statement, with its message |
| `sql_busy` | An earlier `sql_query` statement is still running and cannot be stopped |
| `internal` | Anything else; the exception type only, never a message that could leak data |

Arguments the schema itself rejects (a wrong type, an unknown property, a
value outside an enum) are refused by the SDK before the tool runs, as a
JSON-RPC error rather than a tool error.

## Lifecycle

`agentAccessControllerProvider` is read once from the app root on desktop.
It starts the listener when the setting is on, stops it when off, and
restarts it on a port change. `AgentAccessServer` is process-wide: a start
waits for any pending stop, so `restartApp` (which rebuilds the provider
scope at once) never collides with the old listener on the port. A bind
failure sets `AgentAccessStatus.error` and the settings page shows it; the
app keeps running.

The server factory runs per MCP session, and per request on the stateless
2026 protocol, so it must stay cheap and must not touch the database.

## Roadmap

The remaining PRs, all behind the debug-mode gate until the last one: the
write core (`preview_changes`,
`apply_changes`, `revert_operation`, the confirmation dialog, change log
source `agent`); write coverage per entity family with a guard test; then
the gate removal, user documentation and release note.
