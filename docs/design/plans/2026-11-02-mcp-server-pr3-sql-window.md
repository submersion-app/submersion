# MCP Server PR 3: Read-Only SQL Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent can answer a question the structured tools do not cover by running one read-only SQL statement, and no statement can reach a credential, a key, sync bookkeeping or the change log, however it is written.

**Architecture:** Each call runs on a worker isolate that opens its own short-lived read-only connection, so the app stays responsive and no handle outlives a call. The connection starts a read transaction, compiles the statement, and reads SQLite's `EXPLAIN` bytecode to see every b-tree and column the program touches. Root pages map through `sqlite_schema` to tables and indexes. Anything denied or unknown refuses the statement before a row is stepped.

**Tech Stack:** Dart, `package:sqlite3` 3.5.1 with SQLCipher, Drift for the live schema, `mcp_dart` only inside `mcp_server_builder.dart`.

**Spec:** the `sql_query` section of `docs/design/specs/2026-11-01-mcp-server-design.md`. Roadmap: `docs/design/plans/2026-11-01-mcp-server-pr1-server-core.md`.

## What the spike proved

Run against the pinned library (SQLite 3.53.3, SQLCipher 4.17.0):

- `compile_options` holds `OMIT_AUTHORIZATION` and `OMIT_PROGRESS_CALLBACK`, so `sqlite3_set_authorizer` does not exist in this build and no progress callback is available. `EXPLAIN` is the engine's only view of a statement here.
- Views, CTEs and subqueries are flattened: every one of them showed `OpenRead` on the base table's root page.
- `WHERE cred > 'a'` and `cred IS NULL` over an index read the column with a seek and no `Column` opcode. An index holding a denied column must therefore be refused outright, not checked column by column.
- `ATTACH`, `BEGIN`, `PRAGMA query_only=0` and `PRAGMA table_info` all report `isReadOnly`. The read-only flag says nothing about statement kind, so the kind has its own allowlist.
- `pragma_*`, `json_each` and `dbstat` compile to `VOpen` with an opaque pointer in P4, so they cannot be told apart. All virtual tables are refused and the tool description says so.
- A sorter's output reads back through `Column` on a cursor no `OpenRead` opened. Such a cursor is safe: its data had to come through a checked base read.

## Decisions

The spec leaves these to the builder.

| Decision | Choice | Why |
| --- | --- | --- |
| Where it runs | One worker isolate per call, through `Isolate.run` | A synchronous step on the UI isolate would freeze the app; a sort can run for seconds |
| Connection lifetime | Opened and closed inside the call | A restore, storage move or encryption toggle cannot strand a handle, because none outlives a call. The path and key are read at call time |
| Row cap | 500 by default, `max_rows` up to 5000 | Enough for an analysis, small enough for a model's context |
| Time cap | 10 seconds | Checked between rows by the worker |
| Result size cap | 2 MiB, reported as `size_cap_hit` | One `printf` can build a gigabyte string that a row cap would pass |
| A statement that streams no rows | The tool answers at cap plus 2 seconds with `still_running: true`; later calls answer `sql_busy` until the worker ends | Neither `Isolate.kill` nor the worker can stop a native step. See Known limits |
| Blobs | `{"blob_bytes": n}`, never the bytes | Same rule as the documents from PR 2 |
| Unknown tables | Refused | `sqlite_stat1`, `sqlite_sequence` and anything the change log policy has not classified. A new table must be classified before it is readable |
| `sqlite_schema` | Readable | Agents look there first, and it holds structure, not data |
| Excluded tables the spec does not name | Denied, except the derived list below | Nothing in them helps a diver's question |

### Readable excluded tables

`dive_derived_metrics`, `dive_sensor_summaries`, `equipment_condition_reviews`, `equipment_findings`, `equipment_service_status`, `gps_track_points_local`, `quality_findings`, `rule_run_changes`, `rule_runs`, `trip_day_weather`.

### Denied tables

`cached_regions`, `change_log_context`, `change_log_events`, `change_log_fields`, `change_log_operations`, `connected_accounts`, `deletion_log`, `local_publish_states`, `media_fetch_diagnostics`, `media_repair_log`, `media_subscription_state`, `nearby_peers`, `network_credential_hosts`, `pending_photo_suggestions`, `scheduled_notifications`, `shared_libraries`, `shared_library_backups`, `shared_library_members`, `shared_library_memberships`, `shared_site_states`, `shared_site_suggestions`, `sync_metadata`, `sync_peer_cursors`, `sync_records`, `view_configs`.

### Denied columns

`changeLogCredentialColumns`. Today only `media_subscriptions.credentials_host_id` sits on a readable table, but the check stays generic so a future column is covered by adding it to the policy.

## Known limits

- **A statement that never yields a row cannot be stopped.** `WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM c) SELECT count(*) FROM c` runs until the app quits, on its worker thread. The spec accepted this. `sqlite3_interrupt` through FFI would fix it, but the spec allows that only with a test on all three desktop platforms, and CI runs Linux only.
- **`submersion://schema` cannot give a meaning for every column.** Drift keeps no descriptions, so meanings come from the comments in `lib/core/database/tables/`, which cover under a third of the 2132 columns. The spec's "one-line meaning per column, units, enum values" is met as far as those comments go. Every column still has its name, type, nullability and keys, and the header states the storage conventions. Enum columns are plain text in the schema, so the header tells the agent to read the values with `SELECT DISTINCT`.

## Global Constraints

- Read-only is enforced by the engine: read-only open mode plus `PRAGMA query_only = ON`.
- Enforcement never depends on matching table or column names in the SQL text. The one text check is the leading keyword, an allowlist that fails closed.
- `EXPLAIN` runs after the transaction starts, so the root pages and the program come from one snapshot.
- Refusal messages name the table or column and never carry a row value.
- The debug-mode gate on `agentAccessAvailableProvider` stays. No table, column or migration. No user-facing strings.
- Files 200 to 400 lines, 800 max; `dart format .`; TDD; no emojis; no em-dashes.
- Run `flutter test test/architecture test/shared` after adding any `lib/` file.
- PR body says `Refs #4071`, never `Closes`. No attribution of any tool anywhere.

## Review Focus

1. Every denied table is unreachable directly and through a view, a subquery and a CTE, on the real schema (Task 4, `no denied table is reachable`).
2. A predicate on a denied column over an index reads no `Column` opcode and must still be refused (Task 2, `an index holding a denied column is refused`).
3. A table the policy has never heard of is refused, so a new table fails closed (Task 2, `an unknown root is refused`).
4. A statement that never returns leaves the tool answering, and the next call answers `sql_busy` (Task 5, `a runaway statement does not hold the caller`).
5. A plain and a SQLCipher file both work, and a call after the file changes reads the new file (Task 5).

---

## File Structure

Create under `lib/features/agent_access/data/`:

- `sql/sql_denied_set.dart`: the denied tables, the readable excluded tables, `kSqlDeniedColumns`, and `sqlTableReadable`.
- `sql/sql_read_catalog.dart`: `SqlReadCatalog`, root page to table or index, loaded from the connection.
- `sql/sql_statement_guard.dart`: `sqlLeadingKeyword`, `SqlExplainStep`, `inspectSqlProgram`. Pure, no sqlite import.
- `sql/sql_window.dart`: `SqlWindowRequest`, `SqlWindowResult`, `runSqlWindow`. Synchronous and testable without an isolate.
- `sql/sql_window_runner.dart`: `SqlWindowRunner`, the isolate, the deadline and the busy flag.
- `tools/sql_query_tool.dart`: `SqlQueryTool`.
- `resources/schema_resource.dart`: `submersion://schema`.
- `resources/sql_column_notes.generated.dart`: table to column to comment, generated.

Create `tool/generate_sql_column_notes.dart`, whose `renderSqlColumnNotes` the freshness test also calls.

Modify `domain/agent_tool_error.dart`, `tools/agent_tool_registry.dart`, `presentation/providers/agent_access_providers.dart`, `docs/developer/agent-access.md`, and the spec's `sql_query` section.

## Tasks

### Task 1: Denied set and guard

- [ ] Write `sql_denied_set_test.dart`: every `excluded` table in `changeLogTables` is in exactly one of the denied and readable sets; both sets hold only excluded tables; every `sync_*` and `change_log_*` table is denied; `kSqlDeniedColumns` equals `changeLogCredentialColumns`.
- [ ] Write `sql_denied_set.dart` to pass.

### Task 2: Program inspection

- [ ] Write `sql_statement_guard_test.dart` with hand-built `SqlExplainStep` lists and a hand-built catalogue: allowed read passes; denied table, denied index, unknown root, non-main database, register root (P5 0x10), `VOpen`, `OpenWrite` and a denied `Column` position all refuse; `OpenDup` carries its source's root; a `Column` on an unopened cursor passes; `an index holding a denied column is refused`; `an unknown root is refused`.
- [ ] Add keyword cases: `SELECT`, `WITH`, `VALUES` pass after spaces, `--` and `/* */` comments; `PRAGMA`, `ATTACH`, `BEGIN`, `EXPLAIN`, an empty string and an unterminated comment refuse.
- [ ] Write `sql_statement_guard.dart`, failing closed on `OpenRead`, `ReopenIdx`, `OpenWrite`, `VOpen`, `Column` and `IsType`.

### Task 3: Catalogue

- [ ] Write `sql_read_catalog_test.dart` on a real file: tables and indexes map by root; `sqlite_schema` is root 1 and readable; a denied table's autoindex is denied; a readable table with a denied column reports its position; an index over that column is denied; such a table that is `WITHOUT ROWID` or has a generated column is denied whole.
- [ ] Write `sql_read_catalog.dart`.

### Task 4: The window

- [ ] Add `test/features/agent_access/data/sql/sql_window_fixture.dart`: a real `AppDatabase` written to a temp file, with a view over each denied table added by a writable connection.
- [ ] Write `sql_window_test.dart`: rows, column names and elapsed time; `max_rows` and `row_cap_hit`; bound parameters and a wrong count; `size_cap_hit`; blobs as sizes; `Infinity` as text; `unicode_lower` and `dive_ambient_bar` work; a write refuses; two statements refuse; `no denied table is reachable` directly, by view, by subquery and by CTE; `media_subscriptions` reads every column but `credentials_host_id`, and `SELECT *` on it refuses by name.
- [ ] Write `sql_window.dart`: open read-only, `applyConnectionBasics`, `PRAGMA query_only = ON`, `BEGIN`, the keyword check, prepare with `checkNoTail`, refuse anything not read-only, load the catalogue, inspect `EXPLAIN`, bind, step with the caps, close.

### Task 5: Runner

- [ ] Write `sql_window_runner_test.dart`: a call runs on a worker and returns; `a runaway statement does not hold the caller`, using a short cap, then `sql_busy`; the target getter is read on each call so a changed path takes effect; a SQLCipher file opens with its key; a missing file answers `database_unavailable`.
- [ ] Write `sql_window_runner.dart`. Keep the worker function top level so no closure captures the runner.
- [ ] Add `sqlRefused` (`sql_refused`), `sqlError` (`sql_error`) and `sqlBusy` (`sql_busy`).

### Task 6: Tool

- [ ] Write `sql_query_tool_test.dart`: arguments validate; refusals map to their wire codes; the result is the documented JSON; the description states the caps, the refused constructs, the no-row limit and how raw times are stored.
- [ ] Write `sql_query_tool.dart`. Register it in `AgentToolRegistry.standard`, taking one `SqlWindowRunner`.
- [ ] In the controller, hold one runner for the server's life, since the 2026 protocol builds a server per request. Its target reads `DatabaseService.instance.databasePath` and `databaseKeyHex` at call time.
- [ ] Add a `sql_query` case to `agent_access_server_e2e_test.dart`.

### Task 7: Schema resource

- [ ] Write `tool/generate_sql_column_notes.dart`, run it, and commit `sql_column_notes.generated.dart`.
- [ ] Write `sql_column_notes_fresh_test.dart` comparing `renderSqlColumnNotes` with the committed file.
- [ ] Write `schema_resource_test.dart`: every readable table is listed; no denied table or column appears, by name, anywhere in the text; foreign keys appear as join keys; a note appears on its column; the header states the conventions.
- [ ] Write `schema_resource.dart` from the live schema through `context.db`. Register it.

### Task 8: Docs

- [ ] Update `docs/developer/agent-access.md`: the map, how the guard works, how to classify a new table.
- [ ] Update the spec's `sql_query` section with the facts the spike found and the worker isolate.
- [ ] Run `dart format .`, a whole-repo `flutter analyze`, `flutter test test/features/agent_access test/architecture test/shared`, and the same under `TZ=Australia/Sydney`.
