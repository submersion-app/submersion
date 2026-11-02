# Agent access (MCP server)

Agent access lets an AI agent on the same desktop machine read, and in later
phases change, the diver's logbook through the Model Context Protocol. The
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
| `data/tools/` | `list_divers`, `query`, `get_records`, `list_records`, and the registry |
| `data/resources/` | `submersion://query-language` and `submersion://units` |
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
   `blocks` for children a caller asks for by name.
3. Copy `scope` from the repository's own list method, so the agent sees what
   the app shows that profile: `owned`, `ownedOrNull`, `ownedOrBuiltIn`,
   `ownedNullOrBuiltIn`, `ownedOrShared`, `rootScope`, `viaParent`, `everyone`,
   or a small function when the rule is its own. A family test pins the entry
   against that list method.
4. Add a repository to `RecordRepositories` if it needs a new one. Keep it
   `late final`, because the bundle is built per request.

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

## Service status in queries

`serviceDue` and `nextServiceDue` compile against `equipment_service_status`,
a local cache that holds the active diver's verdicts only. `query` does not
read it. `serviceStatusOverlay` evaluates the named diver's clocks through
`evaluateServiceClocksForItems`, the same batch the notification scheduler
uses, and returns a CTE named after the cache. SQLite resolves that name first,
so the compiled SQL runs unchanged, the answer is right for any profile, and a
read tool writes nothing. It is why `awaitServiceStatusIfRead` is not used
here: that provider can only answer for the active diver.

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
read-only SQL window with the generated schema resource; the write core (`preview_changes`,
`apply_changes`, `revert_operation`, the confirmation dialog, change log
source `agent`); write coverage per entity family with a guard test; then
the gate removal, user documentation and release note.
