# Buddy Card Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (the maintainer's build-feature workflow runs it inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two divers swap buddy cards offline by any of six methods, each landing in one import preview that creates or updates a buddy.

**Architecture:** A pure-Dart `BuddyCard` entity and codec (full JSON and a compact `https://submersion.app/b#...` link) sit under everything. The nearby link from #3737 gains a `card` intent and a swap-screen-only `NearbyCardHost`; a new Multipeer carrier (Swift, iOS and macOS) and the existing BLE carrier both feed it. Android tag emulation (Kotlin `HostApduService`), the existing NFC service, QR, and the share sheet carry the compact or full card into the same preview.

**Tech Stack:** Flutter, Riverpod, Drift, `universal_ble` (existing BLE carrier), `nfc_manager` (existing), `mobile_scanner` and `qr` (existing), `share_plus`, `app_links`, `receive_sharing_intent` (all existing), Kotlin `HostApduService`, Swift `MultipeerConnectivity` and `NearbyInteraction`.

**Spec:** `docs/design/specs/2026-10-28-buddy-card-swap-design.md`

## Global Constraints

- Schema version 321 (main is at 320; 319 is held by PR #3726). If main has moved past 320 when Task 1 starts, take the next free number and say so in the rung comment.
- No table or rung added to `database.dart`: columns in `lib/core/database/tables/`, rung in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, backstop in a `before_open_*` part file.
- Every new synced column gets a conflict catalogue entry (`conflict_field_catalogue_coverage_test.dart` fails otherwise).
- Files stay under 800 lines. `nearby_link_manager.dart` is at 798 and `nearby_session.dart` at 762: new code goes in part files or new files.
- Card hellos carry protocol version 2; `sync` and `pair` hellos keep version 1.
- Card payload in the URL fragment: `https://submersion.app/b#<base64url>`. Never in the query string.
- Photo thumbnail at most 160 px on the long side and 12 KB, JPEG, only in the full card. Never in QR or NFC.
- QR capacity target 2,000 bytes for the link; sticker targets `NdefFit.ntag215Bytes` (504) by default, `ntag216Bytes` (888) when the tag reports it.
- Share defaults: on = photo, phone, email, certifications, dive count, diving since, last dive; off = card details, social handle; name always sent. Medical, allergies, medications, insurance, emergency contacts never appear in any card code path.
- Swap request answer window 60 seconds.
- Units and dates follow the active diver's settings.
- Strings in all 11 ARB locales (`lib/l10n/arb/`), regenerated l10n committed.
- No em dashes in code, comments or strings. `dart format .` and `flutter analyze` clean before each commit; run `test/architecture/` and `test/shared/` after adding `lib/` files.

## Review Focus

1. Both divers tap each other's row at the same moment: exactly one swap, each phone gets one card, no duplicate preview. (Task 8.)
2. A card with long, emoji or right-to-left names and many certifications fit into a QR or a 504-byte sticker: fitting counts encoded bytes, drops in the fixed order, and the preview says something was dropped. (Task 3.)
3. A hostile or broken card (malformed base64, wrong JSON types, a 2 MB photo, a newer `v`, unknown keys) from a file, link, tag or nearby: rejected with a message or read for known keys, never a crash, photo over the cap discarded. (Task 3, Task 6.)
4. A diver with no certifications, no dives, no photo, no phone: the share sheet hides empty fields, the card omits them, and the receiver changes nothing for absent fields. (Task 4, Task 5.)
5. The swap screen closed or the app backgrounded mid-swap: the card session ends, card mode leaves the link manager, nearby sync resumes its own rules, and Android tag emulation stops. (Task 8, Task 10.)

---

### Task 1: Schema 321 columns

**Files:**
- Modify: `lib/core/database/tables/buddy_tables.dart` (Buddies, Certifications)
- Modify: `lib/core/database/tables/diver_tables.dart` (Divers)
- Modify: `lib/core/database/database.dart:298` (`currentSchemaVersion = 321`)
- Create: `lib/core/database/migrations/helpers/buddy_card_migrations.dart` (part of `app_database_migrations.dart`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart` (backstop call)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/people_planning_fields.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (conflict labels)
- Test: `test/core/database/migrations/buddy_card_columns_migration_test.dart`

**Interfaces:**
- Produces columns (Drift getter, SQL name, type, all nullable):
  - Buddies: `cardId` `card_id` text; `socialHandle` `social_handle` text; `cardDiveCount` `card_dive_count` int; `cardDivingSince` `card_diving_since` int (ms since epoch, date); `cardLastDive` `card_last_dive` int (ms, date); `cardReceivedAt` `card_received_at` int (ms).
  - Certifications: `cardId` `card_id` text.
  - Divers: `socialHandle` `social_handle` text; `buddyCardShare` `buddy_card_share` text (JSON, null = defaults).
- Produces `Future<void> _assertBuddyCardColumns()` on `AppDatabase` (idempotent, `PRAGMA table_info` then `ALTER TABLE ... ADD COLUMN` per missing column).

- [ ] **Step 1: Write the failing migration test** `buddy_card_columns_migration_test.dart`: open a v320 fixture database (follow the pattern of the newest test in `test/core/database/migrations/`), migrate, and assert each of the nine columns exists via `PRAGMA table_info`; second test runs `_assertBuddyCardColumns` twice through the test hook and expects no error.
- [ ] **Step 2: Run it** `flutter test test/core/database/migrations/buddy_card_columns_migration_test.dart`. Expected: FAIL (columns missing).
- [ ] **Step 3: Add the columns, the helper, the rung** (`if (from < 321) await _assertBuddyCardColumns(); if (from < 321) await reportProgress();` with a comment naming issue #3728), **the backstop call**, and bump the schema. Run `dart run build_runner build -d`.
- [ ] **Step 4: Add catalogue entries** in `people_planning_fields.dart`, alphabetically: `buddyCardShare` (opaque), `cardDiveCount` (integer kind), `cardDivingSince` and `cardLastDive` (date kind), `cardId` (opaque), `cardReceivedAt` (timestamp kind), `socialHandle` (text). Labels `settings_conflict_field_<key>` in every ARB; `flutter gen-l10n`.
- [ ] **Step 5: Run** the migration test, `test/features/settings/presentation/conflicts/`, and `test/core/database`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(buddies): schema 321 columns for buddy cards`.

### Task 2: Entities and repositories carry the new fields

**Files:**
- Modify: `lib/features/buddies/domain/entities/buddy.dart`, `lib/features/certifications/domain/entities/certification.dart`, `lib/features/divers/domain/entities/diver.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (`createBuddy`, `updateBuddy`, `_mapRowToBuddy`)
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart` (`createCertification`, `updateCertification`, row mapper)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (create, update, mapper)
- Test: `test/features/buddies/data/buddy_repository_card_fields_test.dart`, `test/features/certifications/data/certification_card_id_test.dart`, `test/features/divers/data/diver_social_handle_test.dart`, `test/core/services/sync/buddy_card_columns_sync_test.dart`

**Interfaces:**
- Produces on `Buddy`: `String? cardId`, `String? socialHandle`, `int? cardDiveCount`, `DateTime? cardDivingSince`, `DateTime? cardLastDive`, `DateTime? cardReceivedAt`, all in the constructor, `copyWith` and `props`.
- Produces on `Certification`: `String? cardId`.
- Produces on `Diver`: `String? socialHandle`, `String? buddyCardShare`.

- [ ] **Step 1: Write failing round-trip tests**: create a buddy with all six fields set, read it back by id, expect equal values; same for a certification's `cardId` and a diver's two fields. Sync test: export a buddy row with the fields via `SyncDataSerializer` and apply it to a second test database; expect the fields on the far side, and expect a payload without the keys (an older peer) to leave them null.
- [ ] **Step 2: Run them.** Expected: FAIL (constructor parameters missing).
- [ ] **Step 3: Add the fields** to the entities and write and read them in the repositories' companions and mappers.
- [ ] **Step 4: Run** the four test files and `test/features/buddies test/features/certifications test/features/divers`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): carry buddy card fields through entities and repositories`.

### Task 3: BuddyCard entity and codec

**Files:**
- Create: `lib/features/buddies/domain/entities/buddy_card.dart`
- Create: `lib/features/buddies/domain/services/buddy_card_codec.dart`
- Test: `test/features/buddies/domain/buddy_card_codec_test.dart`

**Interfaces:**
- Produces:
  - `class BuddyCardCert { final String agency; final String name; final String? level; final String? cardNumber; final DateTime? issueDate; }`
  - `class BuddyCard { final int version; final String id; final String name; final String? phone, email, social; final List<BuddyCardCert> certs; final int? dives; final DateTime? since, last; final Uint8List? photo; }` with `copyWith`.
  - `sealed class BuddyCardDecodeResult`; `BuddyCardDecoded(BuddyCard card, {bool newerFormat, bool trimmed})`; `BuddyCardRejected(BuddyCardRejectReason reason)`; `enum BuddyCardRejectReason { notACard, malformed, missingName, missingId }`.
  - `abstract final class BuddyCardCodec` with:
    - `static const int currentVersion = 1;`
    - `static const String linkPrefix = 'https://submersion.app/b#';`
    - `static const String fileExtension = 'subbuddy';`
    - `static const int maxPhotoBytes = 12 * 1024;`
    - `static Uint8List encodeFull(BuddyCard card)` / `static BuddyCardDecodeResult decodeFull(Uint8List bytes)`
    - `static String encodeLink(BuddyCard card, {required int maxBytes})` (drops photo always, then fields in `dropOrder` until `utf8.encode(link).length <= maxBytes`; sets a `t: 1` key when it dropped anything)
    - `static const List<String> dropOrder = ['social', 'last', 'certNumbers', 'lowerCerts', 'since', 'email'];`
    - `static BuddyCardDecodeResult decodeLink(String text)`
    - `static bool isCardLink(String text)` and `static bool isCardFileName(String fileName)`

- [ ] **Step 1: Write failing tests** in `buddy_card_codec_test.dart`:
  - `full round trip keeps every field including photo`
  - `link round trip drops photo and keeps the rest` (assert `decoded.card.photo == null`, other fields equal)
  - `link payload is in the fragment` (`expect(link.startsWith('https://submersion.app/b#'), isTrue); expect(Uri.parse(link).query, isEmpty)`)
  - `link fits 504 bytes for a card with 12 certs and long emoji and Arabic names` (assert `utf8.encode(link).length <= 504` and `trimmed == true`)
  - `fitting drops social before last dive` (a card that fits after one drop keeps `last`, loses `social`)
  - `newer version reads known keys` (`v: 99` with an unknown key gives `newerFormat: true`, fields intact)
  - `rejects malformed base64, non-map JSON, wrong field types, missing name, missing id` (one `expect` per case on the reject reason)
  - `photo over maxPhotoBytes is discarded, card still decodes`
  - `isCardLink accepts the b fragment link and rejects /c, /g and other hosts`; `isCardFileName matches .subbuddy case-insensitively`
- [ ] **Step 2: Run it.** Expected: FAIL (codec missing).
- [ ] **Step 3: Implement** with compact JSON (short keys: `v, i, n, p, e, s, c, d, f, l, ph, t`; certs as `[agency, name, level?, number?, issued?]` arrays) then `base64Url` without padding. Dates as `yyyy-MM-dd` strings. Read every field defensively with type checks; anything wrong for a required key is `malformed`.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): buddy card entity and codec`.

### Task 4: Share choices and building my card

**Files:**
- Create: `lib/features/buddies/domain/entities/buddy_card_share_choices.dart`
- Create: `lib/features/buddies/data/services/buddy_card_builder.dart`
- Create: `lib/features/buddies/presentation/providers/buddy_card_providers.dart`
- Test: `test/features/buddies/domain/buddy_card_share_choices_test.dart`, `test/features/buddies/data/buddy_card_builder_test.dart`

**Interfaces:**
- Consumes: `Diver.buddyCardShare`, `Diver.socialHandle` (Task 2); `BuddyCard` (Task 3).
- Produces:
  - `class BuddyCardShareChoices { final bool photo, phone, email, certifications, cardDetails, diveCount, divingSince, lastDive, social; static const defaults; factory fromJson(String? json); String toJson(); copyWith(...) }` (unknown or missing keys take the default).
  - `class BuddyCardBuilder { BuddyCardBuilder({required DiverRepository divers, required CertificationRepository certifications, required DiveRepository dives}); Future<BuddyCard> build(String diverId, BuddyCardShareChoices choices); Future<Set<BuddyCardField>> availableFields(String diverId); }` with `enum BuddyCardField { photo, phone, email, certifications, cardDetails, diveCount, divingSince, lastDive, social }`.
  - Providers: `myBuddyCardChoicesProvider` (AsyncNotifier reading and saving `Diver.buddyCardShare` for the current diver), `myBuddyCardProvider` (FutureProvider building the full card), `buddyCardBuilderProvider`.

- [ ] **Step 1: Write failing tests**:
  - choices: `defaults match the spec` (each flag), `fromJson(null) is defaults`, `fromJson ignores unknown keys`, `round trip`.
  - builder: `builds name always and only chosen fields`; `dive count is logged dives plus priorDiveCount`; `last is the newest dive date`; `certs are highest first by the buddy certification ladder, without numbers unless cardDetails`; `photo is resized to at most 160 px and 12 KB`; `a diver with nothing filled gives a name-only card and availableFields is empty`; `card id is the diver id`; `never reads medical, insurance or emergency fields` (build from a diver with those set; `encodeFull` bytes contain none of their values).
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.** Rank certs with `primaryCertification`'s ordering and `CertificationCatalog` (as `buddy_repository.dart` `_withPrimaryCerts` does), emitting agency and level display names, never custom ids. Resize following `lib/core/services/images/profile_photo_codec.dart` (`img.copyResize`, then `img.encodeJpg`), stepping JPEG quality down until under 12 KB.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): share choices and building the diver's card`.

### Task 5: Matching and importing a received card

**Files:**
- Create: `lib/features/buddies/domain/services/buddy_card_matcher.dart`
- Create: `lib/features/buddies/domain/services/buddy_card_merge.dart`
- Create: `lib/features/buddies/data/services/buddy_card_importer.dart`
- Test: `test/features/buddies/domain/buddy_card_matcher_test.dart`, `test/features/buddies/domain/buddy_card_merge_test.dart`, `test/features/buddies/data/buddy_card_importer_test.dart`

**Interfaces:**
- Produces:
  - `sealed class BuddyCardMatch`: `CardRecognised(Buddy buddy)`, `CardPossibleMatch(Buddy buddy)`, `CardNew()`. `BuddyCardMatch matchBuddyCard(BuddyCard card, List<Buddy> buddies)`: `cardId == card.id` first; else case-insensitive trimmed name, or digits-only phone, or lower-cased email; else new.
  - `class BuddyCardChange { final String field; final String? from; final String? to; }` and `List<BuddyCardChange> buddyCardChanges(Buddy? existing, BuddyCard card)` for the preview.
  - `class BuddyCardImporter { BuddyCardImporter({required BuddyRepository buddies, required CertificationRepository certifications}); Future<Buddy> addNew(BuddyCard card, {required String diverId}); Future<Buddy> update(Buddy existing, BuddyCard card); }`

- [ ] **Step 1: Write failing tests**:
  - matcher: `recognises by cardId even when the name changed`; `possible match by name, by phone ignoring formatting, by email ignoring case`; `cardId match wins over a name match on another buddy`; `no match is new`; `buddies of another diver are not offered` (caller passes the current diver's list; assert matcher is pure).
  - merge: `changes list only fields the card carries`; `a field absent from the card is not a change`.
  - importer: `addNew writes fields, cardId, cardReceivedAt and one card-made cert per card cert`; `update keeps notes, isFavorite, linkedDiverId and hand-added certs`; `update refreshes a card-made cert with the same agency and name`; `update keeps a card-made cert missing from the new card`; `a field the card omits is left as it was`; `a built-in agency name maps to its enum`; `an unknown agency is stored as Other with the full title as the cert name and creates no custom agency rows`; `headline certification is the card's highest`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.** Agency mapping by `CertificationAgency.values` display name (case-insensitive), level by the built-in level names for that agency; otherwise `CertificationAgency.other`. Write through the repositories (they mark sync pending and notify).
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): match and import received buddy cards`.

### Task 6: Import preview, links and files

**Files:**
- Create: `lib/features/buddies/presentation/pages/buddy_card_preview_page.dart`
- Create: `lib/features/buddies/presentation/services/buddy_card_link_dispatcher.dart`
- Create: `lib/features/buddies/presentation/utils/open_buddy_card.dart` (`Future<void> openBuddyCard(BuildContext, WidgetRef, BuddyCardDecodeResult)` shows a snackbar for a rejection, else pushes the preview)
- Modify: `lib/core/router/app_router.dart` (route `/buddies/card`, `extra: BuddyCardDecoded`)
- Modify: `lib/app.dart` (start the dispatcher beside `_passportLinks`; in `_handleIncomingFile`, a `.subbuddy` name goes to `openBuddyCard` before `handleIncomingFile`)
- Modify: `android/app/src/main/AndroidManifest.xml` (`/b` beside `/c` and `/g` in the app-link and NDEF filters; a `.subbuddy` VIEW filter)
- Modify: `ios/Runner/Info.plist`, `macos/Runner/Info.plist` (`UTExportedTypeDeclarations` `app.submersion.buddy-card`, extension `subbuddy`, conforms to `public.json`; a `CFBundleDocumentTypes` entry)
- Test: `test/features/buddies/presentation/buddy_card_preview_page_test.dart`, `test/features/buddies/presentation/buddy_card_link_dispatcher_test.dart`

**Interfaces:**
- Consumes: Tasks 3 and 5.
- Produces: route name `buddyCardPreview` at `/buddies/card`; `BuddyCardLinkDispatcher({required IncomingLinkSource source, required Future<void> Function(String text) open})` with `start()`, `setReady(bool)`, `dispose()`, mirroring `PassportLinkDispatcher` (repeat window, pending until ready).

- [ ] **Step 1: Write failing tests**:
  - preview: `new card shows Add <name> as a buddy and its fields`; `recognised card shows Update <name> and the change list`; `possible match offers Update and Add as new buddy`; `trimmed card shows the some-details-left-out line`; `newer format shows the newer-app line`; `Discard pops without writing` (importer fake records no call); `Add calls addNew and opens the new buddy`.
  - dispatcher: `opens a card link once within the repeat window`; `ignores /c links and other hosts`; `holds a link until ready`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the page (match computed from `buddyListProvider` for the current diver), dispatcher, route, `app.dart` wiring and platform registrations.
- [ ] **Step 4: Run them**, then `test/app_test.dart` if present and `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): buddy card preview, card links and card files`.

### Task 7: The card session on the nearby link

**Files:**
- Modify: `lib/core/services/nearby/nearby_hello.dart` (`NearbyIntent.card`; `NearbyErrorCode.notSwapping` appended; `static const cardProtocolVersion = 2; static const maxProtocolVersion = 2;`)
- Modify: `lib/core/services/nearby/nearby_frame.dart` (append `cardSummary(15)`, `cardRequest(16)`, `cardAccept(17)`, `cardDecline(18)`, `card(19)`)
- Modify: `lib/core/services/nearby/nearby_session.dart` (`_readHello` refuses above `maxProtocolVersion`; `accept({required bool allowPairing, bool allowCard = false})` routes `card` to the part file; `NearbyIncomingCard`; add `part 'nearby_session_card.dart';`)
- Create: `lib/core/services/nearby/nearby_session_card.dart` (part: `extension NearbySessionCard on NearbySession { Future<NearbyCardChannel> openCard(); }`, the responder branch, `class NearbyCardChannel` with `send`, `messages`, `close` like `NearbyChannel` but no `peer`)
- Test: `test/core/services/nearby/nearby_card_session_test.dart`

**Interfaces:**
- Produces: `Future<NearbyCardChannel> NearbySession.openCard()`; `NearbyIncomingCard(NearbyCardChannel channel)`; `NearbyCardChannel { Stream<NearbyMessage> messages; Future<void> send(NearbyMessageType, Uint8List); Future<void> close(); bool isInitiator; }`.

- [ ] **Step 1: Write failing tests** over `InMemoryNearbyCarrier`:
  - `card session opens with allowCard and exchanges sealed messages both ways`
  - `card hello carries version 2, sync and pair hellos carry version 1`
  - `responder without allowCard refuses with notSwapping`
  - `a version-1-only peer (simulate maxProtocolVersion 1) refuses a card hello with newerApp`
  - `card session needs no pair secret and sends no identity` (assert no `identity` frame in the captured byte stream)
  - `an unsealed error after key check ends the session as a protocol violation`
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.** Unpaired session key: `shared.sessionCipher()` without a pair secret, then `_keyCheck`. No short authentication string.
- [ ] **Step 4: Run it**, then all of `test/core/services/nearby/`. Expected: PASS (sync and pairing tests unchanged).
- [ ] **Step 5: Commit** `feat(nearby): card session intent for buddy card swaps`.

### Task 8: Card mode in the link manager

**Files:**
- Create: `lib/core/services/nearby/nearby_card_host.dart`
- Create: `lib/core/services/nearby/nearby_link_incoming.dart` (part of `nearby_link_manager.dart`; move `_onIncoming` and `_learn` here to make room)
- Modify: `lib/core/services/nearby/nearby_link_manager.dart` (radio wanted while card mode is on; `_onSighting` hands sightings to the host in card mode; `accept(allowCard: _cardHost != null)`; `NearbyIncomingCard` to the host; `enterCardMode(NearbyCardHost)` and `leaveCardMode()`)
- Test: `test/core/services/nearby/nearby_card_host_test.dart`

**Interfaces:**
- Consumes: Task 7; `BuddyCardCodec` (Task 3).
- Produces:
  - `class NearbyCardPeer { final String swapId; final String transportId; final String name; final Uint8List? photo; }`
  - `sealed class NearbyCardEvent`: `CardPeersChanged(List<NearbyCardPeer>)`, `CardRequested(NearbyCardPeer from, NearbyCardDecision decide)`, `CardReceived(NearbyCardPeer from, Uint8List cardBytes)`, `CardSwapFailed(NearbyCardPeer peer, NearbyCardFailure reason)`; `enum NearbyCardFailure { declined, timedOut, lost, newerApp }`; `typedef NearbyCardDecision = void Function(bool accept)`.
  - `class NearbyCardHost { NearbyCardHost({required Uint8List Function() summary, required Uint8List Function() card, Duration answerWindow = const Duration(seconds: 60), Duration summaryRefresh = const Duration(minutes: 2)}); Stream<NearbyCardEvent> get events; Future<void> request(NearbyCardPeer peer); Future<void> dispose(); }`
  - The summary body is JSON `{swapId, name, photo?}`; `swapId` is random per host instance, so a diver seen on two carriers dedupes.

- [ ] **Step 1: Write failing tests** (two hosts over `InMemoryNearbyCarrier` with two managers):
  - `discovery lists the other diver by name and disconnects after the summary`
  - `a device not in card mode is not listed` (its manager refuses with `notSwapping`)
  - `request shows CardRequested on the other side; accept delivers both cards`
  - `decline gives CardSwapFailed.declined and sends no card`
  - `no answer in the window gives timedOut`
  - `both request at once yields one swap and one card each` (Review Focus 1)
  - `leaveCardMode ends a running card session and sync rules resume` (Review Focus 5)
  - `three nearby divers are all listed with one-connection carriers` (summaries do not hold connections)
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.** The lower `swapId` side keeps a simultaneous request. Keep `nearby_link_manager.dart` under 800 lines (`wc -l`).
- [ ] **Step 4: Run it** and all of `test/core/services/nearby/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(nearby): card mode for buddy card swaps`.

### Task 9: Multipeer carrier for Apple devices

**Files:**
- Create: `ios/Runner/MultipeerHandler.swift`, `macos/Runner/MultipeerHandler.swift` (shared logic; register in each `AppDelegate.swift` like `DeviceNameHandler`)
- Modify: `ios/Runner/Info.plist`, `macos/Runner/Info.plist` (`NSLocalNetworkUsageDescription`, `NSBonjourServices` `_subm-card._tcp` and `_subm-card._udp`, `NSNearbyInteractionUsageDescription` on iOS)
- Modify: the Xcode projects to include the new Swift files
- Create: `lib/core/services/nearby/multipeer/multipeer_nearby_carrier.dart`
- Create: `lib/core/services/nearby/composite_nearby_carrier.dart`
- Test: `test/core/services/nearby/multipeer_nearby_carrier_test.dart`, `test/core/services/nearby/composite_nearby_carrier_test.dart`

**Interfaces:**
- Channel `app.submersion/multipeer` (methods: `isSupported`, `start(serviceType)`, `stop`, `connect(peerId)`, `send(peerId, bytes)`, `close(peerId)`) and event channel `app.submersion/multipeer/events` (maps with `type`: `found`, `lost`, `incoming`, `data`, `closed`, `proximity` with `peerId` and `distanceMeters`).
- Produces `class MultipeerNearbyCarrier implements NearbyCarrier` (`canAdvertise` true; `checkAvailability` maps `isSupported`), `Stream<({String transportId, double meters})> get proximity`.
- Produces `class CompositeNearbyCarrier implements NearbyCarrier` over a list of carriers, prefixing transport ids (`ble:`, `mpc:`) so `connect` reaches the right one.

- [ ] **Step 1: Write failing Dart tests** with a fake method channel (`TestDefaultBinaryMessengerBinding`, restored in `addTearDown`): `found event becomes a sighting`; `incoming becomes an endpoint whose inbound carries data events in order`; `send forwards bytes`; `closed closes the endpoint`; `proximity events surface with meters`; composite: `sightings from both carriers are prefixed and connect routes by prefix`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the Dart carrier and composite, then the Swift handler: `MCNearbyServiceAdvertiser` and `MCNearbyServiceBrowser` with service type `subm-card`, `MCSession` with `.required` encryption, reliable sends; on iOS with `NISession.deviceCapabilities.supportsPreciseDistanceMeasurement`, exchange `NIDiscoveryToken`s over the session and emit `proximity`.
- [ ] **Step 4: Run** the Dart tests. Expected: PASS. Build check: `flutter build ios --debug --no-codesign` and `flutter build macos --debug` succeed.
- [ ] **Step 5: Commit** `feat(nearby): Multipeer carrier for Apple devices`.

### Task 10: Android tag emulation

**Files:**
- Create: `android/app/src/main/kotlin/app/submersion/CardEmulationService.kt` (`HostApduService`: SELECT AID `D2760000850101`, SELECT CC file `E103`, SELECT NDEF file `E104`, READ BINARY; serves the current NDEF message from a companion-object holder; empty when none)
- Create: `android/app/src/main/kotlin/app/submersion/CardEmulationHandler.kt` (channel `app.submersion/card_emulation`: `isSupported`, `start(ndefBytes)`, `stop`)
- Create: `android/app/src/main/res/xml/apduservice.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` (service with `BIND_NFC_SERVICE`, `android.nfc.cardemulation.action.HOST_APDU_SERVICE`, `android.hardware.nfc.hce` `required="false"`), `MainActivity.kt` (register the handler)
- Create: `lib/features/buddies/data/services/card_emulation_service.dart` (`abstract interface class CardEmulation { Future<bool> isSupported(); Future<void> start(Uint8List ndefMessage); Future<void> stop(); }`, `ChannelCardEmulation`, `UnsupportedCardEmulation`)
- Test: `test/features/buddies/data/card_emulation_service_test.dart`; `android/app/src/test/kotlin/app/submersion/CardEmulationApduTest.kt`, a new JVM unit-test source set (the module has none yet; add `testImplementation 'junit:junit:4.13.2'`), covering the APDU logic kept in a pure Kotlin `CardEmulationApdu` object that the service delegates to.

**Interfaces:**
- Produces `cardEmulationProvider` (Android: `ChannelCardEmulation`; elsewhere `UnsupportedCardEmulation`).

- [ ] **Step 1: Write failing tests**: Dart `start sends the NDEF bytes over the channel`, `stop is sent`, `unsupported platform reports false`; Kotlin `select AID then CC then READ BINARY returns the CC file`, `select NDEF then READ BINARY at offset returns the NLEN-prefixed message slice`, `unknown command returns 6A82`, `no message gives an empty NDEF file`.
- [ ] **Step 2: Run them** (`flutter test ...`; `cd android && ./gradlew :app:testDebugUnitTest --tests '*CardEmulationApduTest*'`). Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS. `flutter build apk --debug` succeeds.
- [ ] **Step 5: Commit** `feat(buddies): Android NFC tag emulation for buddy cards`.

### Task 11: NFC reading and sticker writing for cards

**Files:**
- Create: `lib/features/buddies/data/services/buddy_card_nfc.dart`
- Test: `test/features/buddies/data/buddy_card_nfc_test.dart`

**Interfaces:**
- Consumes: `NfcTagService` and `nfcTagServiceProvider` (existing), `uriRecord`, `uriOf` (`passport_ndef.dart`), `NdefFit` sizes, `BuddyCardCodec.encodeLink` and `decodeLink`, `CardEmulation`.
- Produces `class BuddyCardNfc { BuddyCardNfc({required NfcTagService tags, required CardEmulation emulation}); Future<BuddyCardDecodeResult> readCard({required String promptIos}); Future<void> writeSticker(BuddyCard card, {required String promptIos}); Future<void> startSharing(BuddyCard card); Future<void> stopSharing(); }`

- [ ] **Step 1: Write failing tests** with a fake `NfcTagService` and fake `CardEmulation`: `readCard returns the card from the first card URI record`; `a passport tag is notACard`; `writeSticker writes one URI record fitted to the tag size`; `writeSticker into a 144-byte tag throws a too-small error`; `startSharing hands emulation an NDEF message with the link`; `readCard stops sharing first and resumes after` (Android receive-by-tap).
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): read and write buddy cards over NFC`.

### Task 12: The swap screen

**Files:**
- Create: `lib/features/buddies/presentation/pages/buddy_swap_page.dart`
- Create: `lib/features/buddies/presentation/widgets/swap/nearby_divers_list.dart`, `share_choices_sheet.dart`, `swap_request_sheet.dart`, `show_card_qr_sheet.dart`, `swap_fallback_buttons.dart`
- Create: `lib/features/buddies/presentation/providers/buddy_swap_providers.dart` (`buddySwapControllerProvider`: enters card mode on the link manager with a host fed by the composite carrier, starts Android sharing, exposes peers and events, leaves everything on dispose and on app pause)
- Modify: `lib/core/router/app_router.dart` (`/buddies/swap`), `lib/features/buddies/presentation/pages/buddy_list_page.dart` and `widgets/buddy_list_content.dart` (app bar action "Swap with a buddy" in each app bar variant)
- Modify: 11 ARB files
- Test: `test/features/buddies/presentation/buddy_swap_page_test.dart`, `test/features/buddies/presentation/share_choices_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 4, 6, 8, 9, 10, 11; `saveAndShareFileBytes` (`file_export_utils.dart`) for Send file; `file_picker` for Open card file (then `openBuddyCard` from Task 6); `PassportMobileScanner(onDetected:)` for Scan code; the `qr` package as in `passport_qr_view.dart`.

- [ ] **Step 1: Write failing widget tests**:
  - `lists nearby divers from the controller and tapping one requests a swap`
  - `incoming request shows the sheet with what will be sent; Swap accepts, Decline declines`
  - `received card opens the preview`
  - `sharing line lists chosen fields and Change opens the sheet`; sheet: `hides fields the diver has not filled`, `name has no switch`, `toggling saves the choices`
  - `Bluetooth refused shows the explanation and settings button and fallbacks still show`
  - `Tap an Android phone shows on iOS only; Receive by tap on Android only; Scan code hidden without a camera`
  - `the hint about both needing the screen open and 1.8.4 is shown under the list`
  - `Open card file picks a .subbuddy file and opens the preview`
  - `leaving the page leaves card mode` (controller fake records leave)
  - `buddy list app bar has the swap action and it opens /buddies/swap`
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** to the mockup (`docs/design/specs/assets/2026-10-28-buddy-card-swap-mockup.html`, layout B and request option A). A diver within 0.2 m on the Multipeer proximity stream is moved to the top and requested once.
- [ ] **Step 4: Run them**, `test/features/buddies/`, `test/architecture/`, `test/shared/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): swap with a buddy screen`.

### Task 13: Card fields on buddy and diver pages

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (a "From <name>'s card" block when any card field is set; social handle row)
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart` (social handle field)
- Modify: the diver profile edit page (find with `grep -rln "emergencyContact" lib/features/divers/presentation/pages`) (social handle field)
- Modify: 11 ARB files
- Test: `test/features/buddies/presentation/buddy_detail_card_block_test.dart`, `test/features/buddies/presentation/buddy_edit_social_test.dart`, `test/features/divers/presentation/diver_edit_social_test.dart`

- [ ] **Step 1: Write failing tests**: `block shows dives, diving since, last dive and received date in the diver's date format`; `block hidden when no card fields`; `edit saves social handle`; `card fields are not editable`; `diver edit saves social handle`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, dates through the preference-aware date formatter (`test/architecture/preference_aware_date_format_test.dart` enforces it).
- [ ] **Step 4: Run them** and `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(buddies): show card details and social handles`.

### Task 14: Companion website PR

Runs in a session in the `submersion-website` repository (this worktree cannot write there).

- [ ] **Step 1:** Add `{ "/": "/b", "comment": "Buddy cards" }` and `{ "/": "/b/*" }` to `.well-known/apple-app-site-association` `components`.
- [ ] **Step 2:** Add a static `/b` page: heading "Submersion buddy card", one line "Open this link on a phone with Submersion to add this diver as a buddy", App Store and Google Play links. No script.
- [ ] **Step 3:** Confirm `.well-known/assetlinks.json` names the app without path limits.
- [ ] **Step 4:** Open the PR with `Refs submersion-app/submersion#3728` and link the app PR.

### Task 15: Final verification

- [ ] **Step 1:** `dart format .`, `flutter analyze` (no issues), `flutter gen-l10n` and confirm no diff in generated files.
- [ ] **Step 2:** `flutter test test/features/buddies test/features/certifications test/features/divers test/core/services/nearby test/core/database test/core/services/sync test/features/settings/presentation/conflicts test/architecture test/shared`, log to the scratchpad, then `grep -c "\[E\]"` the log equals 0.
- [ ] **Step 3:** After screenshots (build-feature step 4.4) of: Buddies list with the swap action, the swap screen with two nearby divers, the request sheet, the preview (new and update), the share choices sheet, the buddy detail card block, light and dark, phone and desktop widths.
- [ ] **Step 4:** Real-device checklist from the spec's last section handed to the maintainer in the PR body.
