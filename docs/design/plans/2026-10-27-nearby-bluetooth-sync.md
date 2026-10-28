# Nearby Bluetooth Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync a diver's logbook between two of their own devices directly over Bluetooth LE, through a reusable nearby link, per the approved design.

**Architecture:** Three layers under `lib/core/services/nearby/`: a carrier (`universal_ble`, faked in tests) that moves bytes; a link (framing, X25519 handshake, pairing code, AES-GCM session) that turns a connection into an authenticated message channel; and a sync protocol that exchanges per-writer HLC watermarks, exports a delta or a full copy with the existing serializer, and applies through new public `SyncService` wrappers. A link manager owns scanning, advertising, session arbitration and the automatic triggers; Settings, a pairing page and a home chip sit on top.

**Tech Stack:** Flutter, Riverpod, Drift, `universal_ble` 3.1.x, `cryptography` (X25519, HKDF, AES-256-GCM), `flutter_secure_storage` through `FallbackSecureStorage`.

**Spec:** `docs/design/specs/2026-10-26-nearby-bluetooth-sync-design.md`

## Global Constraints

- Bluetooth LE only, through `universal_ble ^3.1.2`; no other carrier.
- Linux never advertises (`BleCapabilities.supportsPeripheralApi` is false there); it scans only.
- The nearby peer cursor provider id is the string `nearby`.
- Base parts are 256 KiB (`262144` bytes); a resume offer is honoured for 24 hours.
- Automatic re-sync: on discovery, 5 s after a local change, otherwise not more than once per peer per 10 minutes.
- The pairing code is six digits, zero padded.
- The nearby auto-sync switch is device-local: `SyncPreferences` key `sync_nearby_auto`, default `true`.
- No em-dashes, no emojis, no AI-tool names anywhere in the repo.
- Every new file under `lib/core/database/tables/` or `migrations/` stays under 800 lines; `before_open.dart` is at 797 lines and gains nothing.
- A device-local table must not name a column `hlc` (`sync_hlc_target_registration_test` scans for it).
- Every new l10n key goes into all 11 ARB files under `lib/l10n/arb/` with a non-English value in each (`arb_parity_test`, `untranslated_english_values_test`), then `flutter gen-l10n`.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests; after adding any file under `lib/`, `flutter test test/architecture test/shared`.
- Imports grouped dart, flutter, packages, local. Immutable models. No hardcoded secrets.

## Review Focus

1. A peer that connects, sends a hello with a bogus protocol version or a 2 GB frame length, and stalls: the link must drop it without allocating the claimed size and without blocking other peers. Pinned in Task 2 (length cap) and Task 4 (hello timeout).
2. Both devices connect to each other in the same second: exactly one session survives, in both directions, with no sync run twice. Pinned in Task 10.
3. The link drops mid-base after part 17 of 40 and comes back an hour later: the receiver asks for part 18 and the result applies once. Pinned in Task 8.
4. Nearby sync applies rows older than the cloud watermark while a cloud publish is running: `SyncCoordinator.run` serialises them, and the pull-back lands after the publish, not under it. Pinned in Task 7.
5. The paired peer unpairs this device and connects anyway: this device sees `notPaired`, records it on the row, and raises the chip; no rows cross. Pinned in Task 4 and Task 14.

---

## File structure

New, under `lib/core/services/nearby/`:

| File | Responsibility |
| --- | --- |
| `nearby_carrier.dart` | `NearbyCarrier`, `NearbyEndpoint`, `NearbyPeerSighting` interfaces |
| `nearby_frame.dart` | `NearbyMessage`, `NearbyMessageType`, `FrameEncoder`, `FrameDecoder` |
| `nearby_crypto.dart` | `NearbyHandshake`, `NearbySessionCipher`, code and key derivation |
| `nearby_hello.dart` | `NearbyHello` model, intents, error codes |
| `nearby_session.dart` | `NearbySession`: hello exchange, pairing or verification, yields `NearbyChannel` |
| `nearby_pair_store.dart` | pair secrets in secure storage |
| `nearby_peer_store.dart` | Drift store over `nearby_peers` |
| `nearby_watermarks.dart` | per-writer max HLC query, writer set, null-hlc count |
| `nearby_export_planner.dart` | delta-or-full decision and per-writer filter |
| `nearby_sync_engine.dart` | `NearbySyncEngine` port and `DatabaseNearbySyncEngine` adapter |
| `nearby_sync_protocol.dart` | the session conversation over a `NearbyChannel` |
| `nearby_link_manager.dart` | lifecycle, arbitration, triggers, error recording |
| `ble/ble_nearby_carrier.dart` | `universal_ble` carrier (central and peripheral) |
| `ble/ble_chunker.dart` | MTU chunk split and reassembly |
| `ble/nearby_gatt.dart` | service and characteristic UUID constants |

Modified: `lib/core/database/tables/nearby_tables.dart` (new), `lib/core/database/migrations/helpers/nearby_migrations.dart` (new), `rungs_v231_onward.dart`, `app_database_migrations.dart`, `before_open_table_backstops.dart`, `database.dart` (import, export, tables list, version 319), `sync_service.dart` (two public wrappers), `tombstone_horizon.dart`, `sync_service.dart` GC call site, `sync_preferences.dart`, `sync_providers.dart` (behavior settings), `cloud_sync_page.dart`, `gauge_providers.dart`, `gauge_strip.dart`, `home_appearance_page.dart`, `app_router.dart`, `data_settings_pane.dart`, `app.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `Info.plist` (ios and macos).

New UI: `lib/features/settings/presentation/providers/nearby_providers.dart`, `widgets/sync/nearby_devices_section.dart`, `widgets/sync/nearby_device_sheet.dart`, `pages/nearby_pair_page.dart`.

Test support: `test/support/in_memory_nearby_carrier.dart`, `test/support/fake_nearby_sync_engine.dart`.

---

### Task 1: Framing

**Files:**
- Create: `lib/core/services/nearby/nearby_frame.dart`
- Test: `test/core/services/nearby/nearby_frame_test.dart`

**Interfaces:**
- Produces:
  - `enum NearbyMessageType { hello(1), pairConfirm(2), pairReject(3), watermarks(4), changeset(5), basePart(6), applied(7), error(8), bye(9), baseOffer(10), baseRequest(11) }` with `final int code` and `static NearbyMessageType? fromCode(int)`.
  - `class NearbyMessage { final NearbyMessageType type; final Uint8List body; }`
  - `class FrameEncoder { static Uint8List encode(NearbyMessageType type, Uint8List body); }`: 4-byte big-endian length of (1 + body), then the type code byte, then the body.
  - `class FrameDecoder { FrameDecoder({int maxFrameBytes = 1 << 20}); void add(Uint8List chunk); Stream<NearbyMessage> get messages; }`: reassembles across arbitrary chunk boundaries; a declared length above `maxFrameBytes` adds a `FrameTooLarge` error to the stream and discards the buffer. An unknown type code is emitted as an `UnknownMessageType(code)` stream error and that frame is skipped.

- [ ] **Step 1: Write the failing tests**

```dart
test('encode then decode round-trips one message', ...);          // bytes split at every index 0..n
test('decoder reassembles two messages from one chunk', ...);
test('decoder rejects a frame longer than maxFrameBytes', ...);   // expects FrameTooLarge error, then a later valid frame still decodes
test('decoder skips an unknown type code', ...);                  // code 200 -> UnknownMessageType error, next frame decodes
```

- [ ] **Step 2: Run `flutter test test/core/services/nearby/nearby_frame_test.dart`; expect compile failure**
- [ ] **Step 3: Implement `nearby_frame.dart` as specified above**
- [ ] **Step 4: Run the test; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): message framing for the nearby link`

---

### Task 2: Handshake, code and session cipher

**Files:**
- Create: `lib/core/services/nearby/nearby_crypto.dart`
- Test: `test/core/services/nearby/nearby_crypto_test.dart`

**Interfaces:**
- Consumes: `cryptography` package (`X25519()`, `Hkdf(hmac: Hmac.sha256(), outputLength: 32)`, `AesGcm.with256bits()`).
- Produces:
  - `class NearbyHandshake { static Future<NearbyHandshake> start(); Uint8List get publicKey; Future<NearbySharedSecret> complete(Uint8List peerPublicKey, {required bool isInitiator}); }`
  - `class NearbySharedSecret` (immutable): `String get pairingCode` (six digits: HKDF with info `submersion-nearby-sas-v1`, salt `initiatorPub || responderPub`, 4 bytes big-endian, `% 1000000`, padded), `Future<Uint8List> pairSecret()` (info `submersion-nearby-pair-v1`, 32 bytes), `Future<NearbySessionCipher> sessionCipher({Uint8List? pairSecret, required bool isInitiator})` (info `submersion-nearby-session-v1` with ikm `pairSecret || ecdh` when paired, `submersion-nearby-session-unpaired-v1` with ikm `ecdh` when not).
  - `class NearbySessionCipher { Future<Uint8List> seal(Uint8List plaintext); Future<Uint8List> open(Uint8List box); }`: nonce is 4-byte direction (0 for initiator to responder, 1 the other way) + 8-byte counter per direction; `open` throws `NearbyAuthFailure` on a bad tag; the counter never repeats (throws after 2^63).

- [ ] **Step 1: Write the failing tests**

```dart
test('both sides derive the same six-digit code', ...);           // start() twice, cross-complete, codes equal, length 6, all digits
test('a third public key gives a different code', ...);
test('sessionCipher seal/open round-trips in both directions', ...);
test('open fails on a flipped byte', ...);                         // throws NearbyAuthFailure
test('paired and unpaired session keys differ', ...);
```

- [ ] **Step 2: Run the test file; expect compile failure**
- [ ] **Step 3: Implement `nearby_crypto.dart`**
- [ ] **Step 4: Run the test; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): handshake, pairing code and session cipher`

---

### Task 3: Carrier interfaces and the in-memory carrier

**Files:**
- Create: `lib/core/services/nearby/nearby_carrier.dart`
- Create: `test/support/in_memory_nearby_carrier.dart`
- Test: `test/core/services/nearby/in_memory_nearby_carrier_test.dart`

**Interfaces:**
- Produces:
  - `abstract class NearbyEndpoint { Stream<Uint8List> get inbound; Future<void> send(Uint8List bytes); Future<void> close(); bool get isInitiator; String get transportId; }`
  - `class NearbyPeerSighting { final String transportId; final DateTime seenAt; }`
  - `abstract class NearbyCarrier { bool get canAdvertise; Future<void> startAdvertising(); Future<void> stopAdvertising(); Future<void> startScanning(); Future<void> stopScanning(); Stream<NearbyPeerSighting> get sightings; Stream<NearbyEndpoint> get incoming; Future<NearbyEndpoint> connect(String transportId); Stream<NearbyAvailability> get availability; }` with `enum NearbyAvailability { ready, bluetoothOff, unauthorized, unsupported }`.
  - `class InMemoryNearbyHub { InMemoryNearbyCarrier join(String transportId, {bool canAdvertise = true}); }`: carriers joined to one hub see each other's advertisers as sightings; `connect` yields a pipe pair; `hub.cutAfterBytes(transportId, n)` closes both ends after `n` bytes have crossed (for resume tests).

- [ ] **Step 1: Write the failing tests**

```dart
test('a scanning carrier sees an advertising carrier', ...);
test('connect yields two endpoints whose bytes cross both ways', ...);
test('a scan-only carrier never appears as a sighting', ...);
test('cutAfterBytes closes both endpoints', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement the interface file and the hub**
- [ ] **Step 4: Run; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): carrier interface and in-memory test carrier`

---

### Task 4: Hello and the link session

**Files:**
- Create: `lib/core/services/nearby/nearby_hello.dart`, `lib/core/services/nearby/nearby_session.dart`
- Test: `test/core/services/nearby/nearby_session_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:
  - `enum NearbyIntent { sync, pair }`; `enum NearbyErrorCode { newerApp, olderApp, differentLibrary, notPaired, protocol, busy }`.
  - `class NearbyHello { final int protocolVersion; final String deviceId; final String deviceName; final String appVersion; final int schemaVersion; final String? epochId; final Uint8List publicKey; final NearbyIntent intent; Map<String, Object?> toJson(); factory NearbyHello.fromJson(...); }` with `static const currentProtocolVersion = 1;` JSON keys `v, id, name, app, schema, epoch, pub (base64), intent`.
  - `class NearbyIdentity { final String deviceId; final String deviceName; final String appVersion; final int schemaVersion; final String? epochId; final bool hasDives; }` (what this device puts in its hello; `hasDives` travels as key `dives`).
  - `class NearbyChannel { final NearbyHello peer; final bool isInitiator; Future<void> send(NearbyMessageType type, Uint8List body); Stream<NearbyMessage> get messages; Future<void> close(); }` (encrypted after hello).
  - `abstract class NearbyPairSecrets { Future<Uint8List?> secretFor(String peerDeviceId); Future<void> store(String peerDeviceId, Uint8List secret); Future<void> remove(String peerDeviceId); }` (interface here; the secure-storage implementation is Task 5).
  - `class NearbySession { NearbySession({required NearbyEndpoint endpoint, required NearbyIdentity identity, required NearbyPairSecrets secrets, Duration helloTimeout = const Duration(seconds: 10)}); Future<NearbyChannel> openSync(); Future<NearbyPairing> openPairing(); }`
  - `class NearbyPairing { final NearbyHello peer; final String code; Future<NearbyChannel> confirm(); Future<void> reject(); }`: `confirm` sends `pairConfirm` (encrypted with the unpaired session key), waits for the peer's `pairConfirm` (or `pairReject`, which throws `NearbyPairingRejected`), stores the pair secret on both sides, and returns a channel re-keyed with the pair secret.
  - Refusals throw `NearbySessionRefused(code)` after sending `error` with the code as the body's single byte, then `bye`. The initiator sends hello first; the responder replies.

Rules implemented here: hello carrying `protocolVersion > currentProtocolVersion` is refused with `newerApp`; intent `sync` from a peer with no stored secret is refused with `notPaired`; epochs both non-null and different are refused with `differentLibrary` (for both intents); for `pair`, when both already hold dives the caller is told through `NearbyPairing.bothPopulated` (set from `identity.hasDives` and `peer.hasDives`, add `bool hasDives` to hello, key `dives`). Schema differences are not refused here; the sync protocol handles them per direction (Task 8). A hello that does not arrive within `helloTimeout` closes the endpoint and throws `NearbyHelloTimeout`.

- [ ] **Step 1: Write the failing tests** (two `NearbySession`s over an `InMemoryNearbyHub` pipe; in-memory `NearbyPairSecrets` fake)

```dart
test('openPairing on both sides shows the same code and confirm stores one secret each', ...);
test('reject on one side throws NearbyPairingRejected on the other and stores nothing', ...);
test('openSync with stored secrets yields encrypted channels that exchange a message', ...);
test('openSync against a peer that removed its secret refuses with notPaired', ...);
test('different non-null epochs refuse with differentLibrary', ...);
test('a newer protocol version refuses with newerApp', ...);
test('no hello within helloTimeout throws NearbyHelloTimeout', ...);  // fakeAsync
test('bothPopulated is true only when both hellos carry dives', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement `nearby_hello.dart` and `nearby_session.dart`**
- [ ] **Step 4: Run; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): hello exchange, pairing and encrypted channel`

---

### Task 5: Pair secrets, the `nearby_peers` table and its store

**Files:**
- Create: `lib/core/services/nearby/nearby_pair_store.dart`, `lib/core/services/nearby/nearby_peer_store.dart`
- Create: `lib/core/database/tables/nearby_tables.dart`, `lib/core/database/migrations/helpers/nearby_migrations.dart`
- Modify: `lib/core/database/database.dart` (import at the top block, `export` line, `NearbyPeers` after `LocalPublishStates` in `@DriftDatabase(tables:)`, `currentSchemaVersion = 319`, `319` appended to `migrationVersions` with a one-line comment), `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung `if (from < 319) await _assertNearbyPeersTable(); if (from < 319) await reportProgress();`), `lib/core/database/migrations/app_database_migrations.dart` (`part 'helpers/nearby_migrations.dart';`), `lib/core/database/migrations/before_open_table_backstops.dart` (`// v319 backstop: nearby peers (local, idempotent).` + call).
- Test: `test/core/database/migration_v319_nearby_peers_test.dart`, `test/core/services/nearby/nearby_pair_store_test.dart`, `test/core/services/nearby/nearby_peer_store_test.dart`

**Interfaces:**
- Produces:
  - Table `NearbyPeers` (`@DataClassName('NearbyPeer')`): `peerDeviceId` text PK, `displayName` text, `pairedAt` int, `lastSyncedAt` int nullable, `lastSeenAt` int nullable, `peerAppliedHlcHigh` text nullable, `lastError` text nullable, `resumeBaseId` text nullable, `resumePartIndex` int nullable, `resumeOfferedAt` int nullable.
  - `enum NearbyPeerError { newerApp, peerOlderApp, differentLibrary, notPaired, applyFailed, bluetoothOff, unreachable }` with `bool get isLasting` (true for the first five).
  - `class NearbyPeerStore { NearbyPeerStore(AppDatabase db); Stream<List<NearbyPeer>> watchAll(); Future<List<NearbyPeer>> all(); Future<NearbyPeer?> get(String id); Future<void> upsertPaired({required String peerDeviceId, required String displayName, required int pairedAt}); Future<void> rename(String id, String name); Future<void> markSeen(String id, int at); Future<void> markSynced(String id, {required int at, String? peerAppliedHlcHigh}); Future<void> setError(String id, NearbyPeerError? error); Future<void> setResume(String id, {String? baseId, int? partIndex, int? offeredAt}); Future<void> remove(String id); }`
  - `class SecureNearbyPairStore implements NearbyPairSecrets { SecureNearbyPairStore({FlutterSecureStorage? storage}); }` keys `nearby_pair_<peerDeviceId>`, base64 values, through `FallbackSecureStorage`.
  - `nearby_migrations.dart`: `extension NearbyMigrations on AppDatabase { Future<void> _assertNearbyPeersTable() async { await Migrator(this).createTable(nearbyPeers); } }` (use `createTable` guarded by `_tableExists('nearby_peers')` the way the derived-metrics helper guards).

- [ ] **Step 1: Write the failing tests**

```dart
// migration test, modelled on migration_v317_tank_inspection_baselines_test.dart lines 108-118
test('v319 is in the ladder and did not move the sync floor', ...);
test('a v318 database gains nearby_peers on open', ...);           // open at 318 via the ladder helper the v317 test uses, assert sqlite_master has the table
// pair store, with InMemoryKeychain from test/support/fake_keychain_storage.dart
test('store then secretFor returns the same bytes; remove clears it', ...);
// peer store
test('upsertPaired, markSynced, setError and remove round-trip', ...);
test('watchAll emits after each change', ...);
```

- [ ] **Step 2: Run the three files; expect compile failure**
- [ ] **Step 3: Add the table, helper, rung, backstop, version bump, then `dart run build_runner build --delete-conflicting-outputs`, then the stores**
- [ ] **Step 4: Run the three files and `flutter test test/core/database test/core/services/sync/sync_hlc_target_registration_test.dart`; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): nearby_peers table, pair secrets and peer store`

---

### Task 6: Watermarks and the export planner

**Files:**
- Create: `lib/core/services/nearby/nearby_watermarks.dart`, `lib/core/services/nearby/nearby_export_planner.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (rename `_computeChecksum` to `computeChecksum`, `@visibleForTesting` not needed; it is now a public helper used by the planner)
- Test: `test/core/services/nearby/nearby_watermarks_test.dart`, `test/core/services/nearby/nearby_export_planner_test.dart`

**Interfaces:**
- Consumes: `SyncRepository.hlcTargets` (`Map<String, ({String table, String pk})>`), `Hlc.parse`, `SyncPayload`, `SyncData.toJson`.
- Produces:
  - `class NearbyWatermarks { final Map<String, String> highByWriter; final int rowsWithoutHlc; Map<String, Object?> toJson(); factory NearbyWatermarks.fromJson(...); }`
  - `class NearbyWatermarkQuery { NearbyWatermarkQuery(AppDatabase db); Future<NearbyWatermarks> read(); }`: for every table in `hlcTargets` present in `sqlite_master`, `SELECT substr(hlc, 24) AS w, MAX(hlc) AS h FROM "<t>" WHERE hlc IS NOT NULL GROUP BY w`, plus the same over `deletion_log`, merged by max; `rowsWithoutHlc` is the sum of `COUNT(*) WHERE hlc IS NULL` over the same tables.
  - `enum NearbyExportKind { delta, full }`
  - `class NearbyExportPlanner { static NearbyExportKind decide({required NearbyWatermarks mine, required NearbyWatermarks peers}); static String? deltaWatermark(NearbyWatermarks peers); static SyncPayload filterByWriter(SyncPayload payload, NearbyWatermarks peers, SyncDataSerializer serializer); }`: `decide` returns `full` when `mine.rowsWithoutHlc > 0`, when `peers.highByWriter` is empty, or when any key of `mine.highByWriter` is missing from `peers.highByWriter`; `deltaWatermark` is the minimum value of `peers.highByWriter`; `filterByWriter` drops from every `SyncData` list and every deletions list each row whose `hlc` string has a writer present in `peers.highByWriter` with `row.hlc <= peers.highByWriter[writer]` (string compare), keeps rows with a null `hlc`, and rebuilds the payload with `checksum: serializer.computeChecksum(data.toJson())`.

- [ ] **Step 1: Write the failing tests** (`setUpTestDatabase()`; insert dives with hlcs for writers `aaa` and `bbb`, one with null hlc; a deletion_log row)

```dart
test('read groups the highest hlc per writer across tables and tombstones', ...);
test('read counts rows without hlc', ...);
test('decide is full when the peer lacks a writer I hold', ...);
test('decide is full when I hold rows without hlc', ...);
test('decide is full when the peer map is empty', ...);
test('decide is delta when the peer knows every writer', ...);
test('filterByWriter keeps only rows above the peer watermark for their writer and validates', ...); // validateChecksum(filtered) is true
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement both files and the rename**
- [ ] **Step 4: Run both files and `flutter test test/core/services/sync/sync_data_serializer_test.dart`; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): per-writer watermarks and export planner`

---

### Task 7: Public apply wrappers and the engine adapter

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (add two public methods next to `debugApplyPayload`)
- Modify: `lib/core/services/sync/changeset_log/publish_state_store.dart` (add `Future<void> pullBackPublishedHlc(String toHlc)`)
- Create: `lib/core/services/nearby/nearby_sync_engine.dart`, `test/support/fake_nearby_sync_engine.dart`
- Test: `test/core/services/nearby/database_nearby_sync_engine_test.dart`, `test/core/services/sync/changeset_log/publish_state_store_test.dart` (extend)

**Interfaces:**
- Produces in `SyncService`:
  - `Future<NearbyApplyResult> applyNearbyPayload(SyncPayload payload, {required DateTime? lastSync})` and `Future<NearbyApplyResult> applyNearbyBaseFile(String filePath, {required DateTime? lastSync, void Function(double fraction)? onProgress})`, both `SyncCoordinator.run` around the private merge, returning `({int recordsApplied, int conflictsFound, int recordsFailed})` as the typedef `NearbyApplyResult` declared in `nearby_sync_engine.dart`? No: declare `typedef NearbyApplyResult = ({int recordsApplied, int conflictsFound, int recordsFailed});` in `sync_service.dart` so the engine file imports it.
  - `PublishStateStore.pullBackPublishedHlc(String toHlc)`: for every row whose `publishedHlcHigh` is non-null and greater than `toHlc` (string compare), set it to `toHlc` and `updatedAt` to now; rows with null are untouched.
  - `abstract class NearbySyncEngine { Future<NearbyIdentity> identity(); Future<NearbyWatermarks> watermarks(); Future<SyncPayload> exportDelta(String watermark); Future<StreamedBase> exportFull(); Future<NearbyApplyResult> applyPayload(SyncPayload p, {required String peerDeviceId}); Future<NearbyApplyResult> applyBaseFile(String path, {required String peerDeviceId, void Function(double)? onProgress}); Future<void> recordApplied({required String peerDeviceId, required String? appliedHlcHigh, required String? lowestAppliedHlc}); Future<void> recordPeerAck({required String peerDeviceId, required String? peerAppliedHlcHigh}); Future<void> adoptEpoch(String epochId); }`
  - `class DatabaseNearbySyncEngine implements NearbySyncEngine` built from `SyncService`, `SyncDataSerializer`, `SyncRepository`, `PeerCursorStore`, `PublishStateStore`, `NearbyPeerStore`, `LibraryEpochStore`, `NearbyWatermarkQuery`, `SyncDeviceMetadata`, `AppDatabase.currentSchemaVersion`. `applyPayload` passes `lastSync` from `NearbyPeerStore.get(peer).lastSyncedAt`; `recordApplied` upserts `SyncPeerCursors` (provider `nearby`, `lastSeqApplied: 0`, `appliedHlcHigh`), calls `pullBackPublishedHlc(lowestAppliedHlc)` when non-null, and `markSynced`; `exportDelta` calls `serializer.exportChangeset(deviceId:, hlcWatermark:, deletions: await syncRepository.getDeletionsSince(...)` (use whatever the `ChangesetWriter` passes; copy that call), `epochId:`); `exportFull` calls `exportBaseToTempFile` with the same deletions and epoch. `adoptEpoch` writes `LibraryEpochStore.setLastAccepted(LibraryEpochMarker(epochId:, replacedAt: now, deviceId: mine))` and `SyncRepository.setLastAcceptedEpochId`.
  - `FakeNearbySyncEngine` in test support: scripted watermarks, canned payloads, records every call.

- [ ] **Step 1: Write the failing tests** (`setUpTestDatabase()`, a `SyncService` built like `test/core/services/sync/sync_service_test.dart` does)

```dart
test('pullBackPublishedHlc lowers only watermarks above toHlc', ...);
test('applyNearbyPayload merges a dive and reports recordsApplied 1', ...);
test('applyNearbyPayload waits for a running SyncCoordinator body', ...);   // start run(() => completer.future), call apply, assert not applied until completer completes
test('recordApplied writes the nearby cursor and pulls the cloud watermark back', ...);
test('exportDelta carries rows above the watermark and the library epoch', ...);
test('adoptEpoch stores the marker in the prefs store and the repository', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run the new tests plus `flutter test test/core/services/sync/sync_service_test.dart test/core/services/sync/changeset_log`; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): public apply wrappers and the nearby sync engine adapter`

---

### Task 8: The sync protocol

**Files:**
- Create: `lib/core/services/nearby/nearby_sync_protocol.dart`
- Test: `test/core/services/nearby/nearby_sync_protocol_test.dart`

**Interfaces:**
- Consumes: `NearbyChannel` (Task 4), `NearbySyncEngine` and `FakeNearbySyncEngine` (Task 7), `NearbyExportPlanner` (Task 6), `NearbyPeerStore` (Task 5).
- Produces:
  - `class NearbySyncOutcome { final NearbyPeerError? error; final int applied; final int sent; }`
  - `class NearbySyncProtocol { NearbySyncProtocol({required NearbyChannel channel, required NearbySyncEngine engine, required NearbyPeerStore peers, Directory Function()? tempDir, DateTime Function() now = DateTime.now, void Function(int sentBytes, int totalBytes)? onProgress}); Future<NearbySyncOutcome> run(); }`
  - Message bodies (JSON unless stated): `watermarks` = `NearbyWatermarks.toJson()`; `changeset` = gzip of `serializePayload`; `baseOffer` = `{baseId, partCount, byteLength, toHlc}`; `baseRequest` = `{fromIndex}`; `basePart` = 4-byte index + raw bytes (256 KiB slices of the base file); `applied` = `{appliedHlcHigh, lowestAppliedHlc}`; `error` = one byte `NearbyErrorCode.index`.
  - Order: responder sends `watermarks` first; initiator exports and sends; responder applies and sends `applied`; then the initiator sends `watermarks` and the roles swap; then `bye`.
  - Schema per direction: a receiver whose `identity.schemaVersion < peer.schemaVersion` sends `error(newerApp)` instead of `watermarks` and the outcome records `newerApp` on this side and `peerOlderApp` on the sender's side; a receiver whose `peer.schemaVersion < AppDatabase.minimumCompatibleSchemaVersion` sends `error(olderApp)` and records `peerOlderApp` (the sender records `newerApp`). The other direction still runs.
  - Epoch: before the first `watermarks`, if `identity.epochId == null && peer.epochId != null` call `engine.adoptEpoch(peer.epochId)`; if both null and this side is the initiator, mint `Uuid().v4()`, adopt it, and send it in the `watermarks` body under key `epoch` for the responder to adopt.
  - Resume: on `baseOffer`, if `peers.get(peer).resumeBaseId == baseId` and `resumeOfferedAt` is within 24 h, reply `baseRequest{fromIndex: resumePartIndex + 1}` and append to the existing temp file `<tempDir>/nearby-base-<baseId>.json`; otherwise `fromIndex: 0` to a fresh file. After each part, `setResume`. After `partCount` parts, apply the file and clear resume. The sender keeps the base file at `<tempDir>/nearby-base-<baseId>.json` and deletes it after `applied` or 24 h.
  - `lowestAppliedHlc` is the minimum `hlc` string over every row and tombstone in the applied payload (for a base, the minimum seen while streaming through `BaseJsonStreamReader.parse`, or the file's `sinceHlc` when the engine wrapper reports it; the builder picks the cheaper and tests it).

- [ ] **Step 1: Write the failing tests** (two protocols over one `InMemoryNearbyHub` pipe and Task 4 sessions; `FakeNearbySyncEngine` on each side; `fakeAsync` where timing matters)

```dart
test('two caught-up peers exchange deltas and both record applied', ...);
test('an empty-map peer receives a full copy in 256 KiB parts', ...);     // fake exportFull writes a 700 000 byte file; expect 3 parts
test('a cut after part 1 resumes from part 2 on the next run', ...);      // hub.cutAfterBytes, second run, assert baseRequest fromIndex 2 and the file applies once
test('an offer older than 24 h restarts from part 0', ...);
test('a newer peer schema yields newerApp here and peerOlderApp there, and the other direction still syncs', ...);
test('a null epoch adopts the peer epoch; two nulls mint one shared epoch', ...);
test('applied carries lowestAppliedHlc and recordApplied receives it', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement `nearby_sync_protocol.dart`** (keep it under 400 lines; split base streaming into `nearby_base_transfer.dart` if it grows)
- [ ] **Step 4: Run; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): watermark exchange, delta and resumable full copy`

---

### Task 9: Bluetooth carrier

**Files:**
- Modify: `pubspec.yaml` (add `universal_ble: ^3.1.2` with a comment block, next to `cryptography_flutter`), `android/app/src/main/AndroidManifest.xml` (`<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />` beside `BLUETOOTH_CONNECT`), `ios/Runner/Info.plist` and `macos/Runner/Info.plist` (both Bluetooth usage strings become "Submersion uses Bluetooth to connect to dive computers and to sync with your other devices nearby.")
- Create: `lib/core/services/nearby/ble/nearby_gatt.dart`, `lib/core/services/nearby/ble/ble_chunker.dart`, `lib/core/services/nearby/ble/ble_nearby_carrier.dart`
- Test: `test/core/services/nearby/ble/ble_chunker_test.dart`

**Interfaces:**
- Produces:
  - `nearby_gatt.dart`: `const nearbyServiceUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e01'; const nearbyInboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e02'; const nearbyOutboxUuid = '6e2f8a40-93b1-4c52-8d7e-0c3a5b1d9e03';`
  - `class BleChunker { static List<Uint8List> split(Uint8List bytes, int mtu)` (chunks of `mtu - 3`, minimum 20); no reassembly class: the link's `FrameDecoder` reassembles, so the carrier just forwards every notification or write as a chunk.
  - `class BleNearbyCarrier implements NearbyCarrier`: central side uses `UniversalBle.startScan(scanFilter: ScanFilter(withServices: [nearbyServiceUuid]))`, `connect`, `requestMtu(517)`, `discoverServices`, `subscribeNotifications(outbox)`, `write(inbox, withoutResponse: true)`; peripheral side uses `UniversalBlePeripheral.addService(BlePeripheralService(uuid: nearbyServiceUuid, characteristics: [inbox: write + writeWithoutResponse, writeable; outbox: notify, readable]))`, `startAdvertising(services: [nearbyServiceUuid])` with no local name, `setWriteRequestHandlers` feeding the endpoint for that `deviceId`, `characteristicSubscriptionStream` creating an incoming `NearbyEndpoint` when a central subscribes to the outbox and closing it on unsubscribe or `connectionStateStream` disconnect, `updateCharacteristicValue(deviceId:)` to send, `mtuChangedStream` or `getMaximumNotifyLength` for the chunk size. `canAdvertise = BleCapabilities.supportsPeripheralApi`. `availability` maps `UniversalBle.availabilityStream`. Sends on an endpoint are serialised through a per-endpoint queue so chunks never interleave.

- [ ] **Step 1: Write the failing chunker test**

```dart
test('split uses mtu minus 3 and never below 20', ...);
test('split of an empty payload yields no chunks', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Add the dependency (`flutter pub get`), the manifest and plist changes, then implement the three files**
- [ ] **Step 4: Run the chunker test and `flutter analyze`; expect PASS and no issues. Build once for macOS (`flutter build macos --debug`) to confirm the plugin links.**
- [ ] **Step 5: Commit** `feat(nearby): Bluetooth LE carrier through universal_ble`

---

### Task 10: Link manager

**Files:**
- Create: `lib/core/services/nearby/nearby_link_manager.dart`
- Test: `test/core/services/nearby/nearby_link_manager_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `enum NearbyLinkState { off, idle, scanning, syncing }`
  - `class NearbyLinkManager { NearbyLinkManager({required NearbyCarrier carrier, required NearbySyncEngine engine, required NearbyPairSecrets secrets, required NearbyPeerStore peers, required bool Function() autoSyncEnabled, Stream<void>? localChanges, DateTime Function() now = DateTime.now, Duration changeDebounce = const Duration(seconds: 5), Duration perPeerCooldown = const Duration(minutes: 10)}); Future<void> setForeground(bool inForeground); Future<void> refresh(); Future<NearbySyncOutcome> syncNow(String peerDeviceId); Future<NearbyPairing> startPairing(String transportId); Future<void> enterPairingMode(); Future<void> leavePairingMode(); Stream<List<NearbyPeerSighting>> get pairableSightings; Stream<NearbySyncProgress> get progress; NearbyLinkState get state; Future<void> unpair(String peerDeviceId); Future<void> dispose(); }`
  - `class NearbySyncProgress { final String peerDeviceId; final int sentBytes; final int totalBytes; }`
  - Behaviour: runs (scan, and advertise when `canAdvertise`) only when in foreground and (`autoSyncEnabled()` and `peers.all()` is non-empty, or pairing mode). Every sighting is connected (transport ids are anonymous); after hello, a peer not in the store is closed with `bye` unless in pairing mode. Arbitration: when a second session with the same `peer.deviceId` opens while one is running, the one whose initiator has the lower `deviceId` (string order) is kept and the other closed before any sync message. A peer syncs at most once per `perPeerCooldown` unless a local change arrived after its last sync (debounced by `changeDebounce`). `syncNow` ignores the cooldown. After `NearbyPairing.confirm()` succeeds, the manager calls `peers.upsertPaired` with the hello's name and runs the sync protocol on the returned channel at once. `unpair` removes the secret, the peer row and the `nearby` cursor (`PeerCursorStore.resetForProvider` is too broad; add `PeerCursorStore.remove(peerDeviceId, provider)` in this task). Outcomes write `markSeen`, `setError` (null on success), and `bluetoothOff` on every row while availability is not `ready`.

- [ ] **Step 1: Write the failing tests** (`InMemoryNearbyHub` with two managers, `FakeNearbySyncEngine`, `fakeAsync`)

```dart
test('two paired managers in foreground sync once on discovery', ...);
test('simultaneous connects keep exactly one session and sync once', ...);   // both see each other at t=0; assert one run per side
test('a local change triggers a re-sync after the debounce despite the cooldown', ...);
test('no re-sync within the cooldown without a change', ...);
test('an unknown peer is dropped after hello outside pairing mode', ...);
test('in pairing mode an unknown peer is offered as a pairing', ...);
test('a failed session records the error on the row; success clears it', ...);
test('bluetoothOff marks every row and nothing connects', ...);
test('unpair removes secret, row and cursor', ...);
test('nothing scans with auto off and no pairing mode', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): link manager with discovery, arbitration and auto sync`

---

### Task 11: Tombstone horizon

**Files:**
- Modify: `lib/core/services/sync/changeset_log/tombstone_horizon.dart`, `lib/core/services/sync/sync_service.dart` (the GC call at ~925), `lib/core/services/sync/changeset_log/local_only_tombstone_gc.dart`
- Test: `test/core/services/sync/changeset_log/tombstone_horizon_test.dart` (extend)

**Interfaces:**
- Produces: `TombstoneHorizon.compute` gains `List<NearbyPeer> nearbyPeers = const []` and `int nowMillis`: a nearby peer with `lastSeenAt` older than `SyncLiveness.retirementPeriodMillis` is skipped; one with null `peerAppliedHlcHigh` blocks; otherwise its value joins the minimum. Both GC call sites pass `await nearbyPeerStore.all()`; `SyncService` gains an optional `NearbyPeerStore? nearbyPeers` constructor argument wired in `syncServiceProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a nearby peer with an older ack lowers the horizon', ...);
test('a nearby peer that never acked blocks GC', ...);
test('a nearby peer silent past the retirement period is ignored', ...);
```

- [ ] **Step 2: Run; expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run the file and `flutter test test/core/services/sync`; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): nearby peers hold tombstones back`

---

### Task 12: Settings preference, providers and the Nearby devices section

**Files:**
- Modify: `lib/core/services/sync/sync_preferences.dart` (`_nearbyAutoKey = 'sync_nearby_auto'`, `bool get nearbyAutoEnabled => _prefs.getBool(_nearbyAutoKey) ?? true;`, setter), `lib/features/settings/presentation/providers/sync_providers.dart` (`SyncBehaviorSettings.nearbyAutoEnabled` + `setNearbyAutoEnabled`)
- Create: `lib/features/settings/presentation/providers/nearby_providers.dart` (`nearbyPeerStoreProvider`, `nearbyPairStoreProvider`, `nearbyCarrierProvider` (BLE in the app, overridable), `nearbySyncEngineProvider`, `nearbyLinkManagerProvider` (`// no-tick:` comment, `ref.onDispose(dispose)`), `nearbyPeersProvider = StreamProvider<List<NearbyPeer>>`, `nearbyProgressProvider`)
- Create: `lib/features/settings/presentation/widgets/sync/nearby_devices_section.dart`, `lib/features/settings/presentation/widgets/sync/nearby_device_sheet.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (insert `const Divider(), const NearbyDevicesSection(),` after the keep-in-step `SwitchListTile`, before the `Divider` and `SyncAdvancedSection`)
- l10n keys (all 11 ARBs): `settings_nearby_title` "Nearby devices", `settings_nearby_auto_title` "Sync nearby automatically", `settings_nearby_auto_subtitle` "When a paired device is open nearby, over Bluetooth", `settings_nearby_auto_subtitle_linux` "This computer can be found only by devices that advertise", `settings_nearby_pair` "Pair a device", `settings_nearby_status_synced` "Synced {when}" (placeholder `when`, String), `settings_nearby_status_syncing` "Syncing: {sent} of {total}", `settings_nearby_status_notSeen` "Not seen since {when}", `settings_nearby_status_never` "Not synced yet", `settings_nearby_error_newerApp` "Needs a newer app version", `settings_nearby_error_peerOlderApp` "{name} needs an update", `settings_nearby_error_differentLibrary` "Not the same library", `settings_nearby_error_notPaired` "Unpaired on the other device", `settings_nearby_error_applyFailed` "Could not apply its changes", `settings_nearby_error_bluetoothOff` "Bluetooth is off", `settings_nearby_error_unreachable` "Could not connect", `settings_nearby_sheet_rename` "Rename", `settings_nearby_sheet_syncNow` "Sync now", `settings_nearby_sheet_unpair` "Unpair", `settings_nearby_unpair_confirm` "Unpair {name}? It will need pairing again to sync nearby."
- Test: `test/features/settings/presentation/widgets/sync/nearby_devices_section_test.dart`, `test/core/services/sync/sync_preferences_test.dart` (extend)

**Interfaces:**
- Produces: `class NearbyDevicesSection extends ConsumerWidget` (header, switch keyed `nearby-auto`, one `ListTile` per peer with a status dot `Icon(Icons.circle, size: 10)` coloured ok/idle/warn by `colorScheme.primary`, `onSurfaceVariant`, `tertiary`, subtitle from status, `onTap` opens `NearbyDeviceSheet`, and a `TextButton.icon` "Pair a device" that `context.push('/settings/cloud-sync/nearby-pair')`). Times format through the app's existing relative-time helper (the one the Sync status card uses).

- [ ] **Step 1: Write the failing tests** (override `nearbyPeersProvider`, `nearbyProgressProvider`, `syncBehaviorProvider`)

```dart
test('nearbyAutoEnabled defaults to true and persists false', ...);
testWidgets('lists each paired device with its status line', ...);
testWidgets('a lasting error shows its message and the warn dot', ...);
testWidgets('toggling the switch calls setNearbyAutoEnabled', ...);
testWidgets('tapping a row opens the sheet with rename, sync now, unpair', ...);
testWidgets('Pair a device pushes the pairing route', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement, add the ARB keys to all 11 files, run `flutter gen-l10n`**
- [ ] **Step 4: Run the tests plus `flutter test test/l10n test/features/settings/presentation/pages/cloud_sync_page_test.dart`; expect PASS**
- [ ] **Step 5: Commit** `feat(settings): Nearby devices section on the Sync page`

---

### Task 13: Pairing page and route

**Files:**
- Create: `lib/features/settings/presentation/pages/nearby_pair_page.dart`
- Modify: `lib/core/router/app_router.dart` (child route `GoRoute(path: 'nearby-pair', name: 'nearbyPair', builder: (_, __) => const NearbyPairPage())` under `cloud-sync`), `lib/features/settings/presentation/pages/data_settings_pane.dart` (`['cloud-sync', 'nearby-pair'] => const NearbyPairPage()`), `test/core/router/app_router_test.dart` (`locations` list gains `/settings/cloud-sync/nearby-pair`)
- l10n keys: `nearbyPair_title` "Pair a device", `nearbyPair_looking` "Looking for devices…", `nearbyPair_hint` "Open Submersion on the other device and tap Pair a device there too.", `nearbyPair_found` "Found {name}. Check that it shows this code, then confirm on both.", `nearbyPair_sameCode` "Same code", `nearbyPair_notMine` "Not mine", `nearbyPair_bothPopulated` "Both devices have dives. Pairing merges them into one logbook.", `nearbyPair_differentLibrary` "This device is on a different library.", `nearbyPair_permissionDenied` "Submersion needs Bluetooth permission to find nearby devices.", `nearbyPair_openSettings` "Open settings", `nearbyPair_done` "Paired with {name}"
- Test: `test/features/settings/presentation/pages/nearby_pair_page_test.dart`

**Interfaces:**
- Produces: `class NearbyPairPage extends ConsumerStatefulWidget`: on init `enterPairingMode()`; lists `pairableSightings` as tiles named by hello when known, else "Submersion device"; tap calls `startPairing(transportId)` and shows the code (`Text` style `displayMedium`, letter spacing 8, digits grouped `482 913`) with the two buttons; `confirm()` then `markSynced` happens through the manager's first sync; `pop` on success with a `SnackBar` `nearbyPair_done`; on dispose `leavePairingMode()`. Availability `unauthorized` shows the permission text and an "Open settings" button (`openAppSettings` from `permission_handler` if present in pubspec, else `UniversalBle.requestPermissions()`); `bluetoothOff` shows the existing Bluetooth-off wording the dive computer pages use.

- [ ] **Step 1: Write the failing tests** (override `nearbyLinkManagerProvider` with a fake exposing a `StreamController` of sightings and a scripted `NearbyPairing`)

```dart
testWidgets('shows Looking and the hint while no sightings', ...);
testWidgets('tapping a sighting shows the six-digit code and both buttons', ...);
testWidgets('Same code calls confirm and pops with the done snackbar', ...);
testWidgets('Not mine calls reject and returns to the list', ...);
testWidgets('bothPopulated shows the merge notice above the code', ...);
test('the route table and the data pane resolve /settings/cloud-sync/nearby-pair', ...);
```

- [ ] **Step 2: Run; expect compile failure**
- [ ] **Step 3: Implement, ARB keys, `flutter gen-l10n`**
- [ ] **Step 4: Run the tests plus `flutter test test/core/router/app_router_test.dart test/l10n`; expect PASS**
- [ ] **Step 5: Commit** `feat(settings): nearby pairing page`

---

### Task 14: Home chip

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/gauge_providers.dart` (`HomeChipType.nearby` appended after `documents`; `DashboardGauges.nearbyAttention` as `({String name, int more})?`, computed from `nearbyPeersProvider`: first peer whose `lastError?.isLasting == true`, `more` = count of the rest), `lib/features/dashboard/presentation/widgets/gauge_strip.dart` (a chip after the sync chip: icon `Icons.bluetooth_outlined`, label `dashboard_gauges_nearby(name)` or `dashboard_gauges_nearbyMore(name, more)`, tone `warn`, tap `context.push('/settings/cloud-sync')`), `lib/features/settings/presentation/pages/home_appearance_page.dart` (`HomeChipType.nearby => l10n.settings_homeChips_nearby`)
- l10n keys: `dashboard_gauges_nearby` "Nearby: {name} needs attention", `dashboard_gauges_nearbyMore` "Nearby: {name} and {more} more need attention", `settings_homeChips_nearby` "Nearby devices"
- Test: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart` (extend) and `gauge_providers_test.dart` (extend)

- [ ] **Step 1: Write the failing tests**

```dart
test('nearbyAttention names the first lasting error and counts the rest', ...);
test('nearbyAttention is null when every error is transient', ...);
testWidgets('the nearby chip renders only with attention and is hideable', ...);
```

- [ ] **Step 2: Run; expect failure**
- [ ] **Step 3: Implement, ARB keys, `flutter gen-l10n`**
- [ ] **Step 4: Run `flutter test test/features/dashboard test/features/settings/presentation/pages/home_appearance_page_test.dart test/l10n`; expect PASS**
- [ ] **Step 5: Commit** `feat(dashboard): nearby devices attention chip`

---

### Task 15: App lifecycle wiring

**Files:**
- Modify: `lib/app.dart` (`initState`: `ref.read(nearbyLinkManagerProvider).setForeground(true)` after the launch sync; `didChangeAppLifecycleState`: `setForeground(false)` on `backgrounded`, `setForeground(true)` on `resumed`), `lib/features/settings/presentation/providers/nearby_providers.dart` (`localChanges: SyncEventBus.changes`, `autoSyncEnabled: () => ref.read(syncPreferencesProvider).nearbyAutoEnabled`; a `ref.listen(syncBehaviorProvider)` that calls `refresh()` when `nearbyAutoEnabled` changes; `refresh()` also after `unpair` and after pairing)
- Test: `test/app_lifecycle_nearby_test.dart` (or extend the existing app lifecycle test if one covers `_maybeSyncOnResume`)

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('resume and background toggle the link manager foreground flag', ...);  // fake manager records calls
```

- [ ] **Step 2: Run; expect failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run the test, `flutter analyze`, `flutter test test/architecture test/shared`; expect PASS**
- [ ] **Step 5: Commit** `feat(nearby): start and stop the nearby link with the app lifecycle`

---

### Task 16: Final checks

- [ ] **Step 1: `dart format .` then `flutter analyze`; expect no issues**
- [ ] **Step 2: `flutter test test/core/services/nearby test/core/services/sync test/core/database test/features/settings test/features/dashboard test/l10n test/architecture test/shared test/core/router`; expect all green**
- [ ] **Step 3: Build for macOS debug and run the app; open Settings > Data > Sync, confirm the Nearby devices block renders, open Pair a device, confirm the permission prompt or the Looking state; capture the after screenshots (Sync page, pairing page, light and dark)**
- [ ] **Step 4: Commit any formatting** `chore(nearby): format`
