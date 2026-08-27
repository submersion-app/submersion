# Media Source Extension — Phase 3b (Manifest Import) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Part 2 of 3 (Phase 3b: Manifest Import).** Depends on Phase 3a (URL bulk import) being complete on the same branch (`feature/media-source-extension-phase3`). Phase 3c (Settings & Scan) follows.

**Goal:** Land the **Manifest** mode of the photo picker's URL tab, so a diver can paste an Atom/RSS, JSON, or CSV manifest URL, fetch it, preview entries, optionally subscribe for periodic polling, and have new feed entries automatically materialized as `MediaItem` rows that ride the eager-fetch pipeline introduced in 3a.

**Architecture:** Three pure-Dart manifest parsers (`atom_manifest_parser.dart`, `json_manifest_parser.dart`, `csv_manifest_parser.dart`) each return a common `List<ManifestEntry>` value type. A `ManifestFormatSniffer` chooses between them via Content-Type → content-shape heuristics. A `ManifestFetchService` ties fetch + sniff + parse together for the UI. A `ManifestSubscriptionRepository` wraps the existing Drift `MediaSubscriptions` (synced) + `MediaSubscriptionState` (per-device) tables. A `SubscriptionPoller` runs on app launch (after a 30 s warm-up) plus a periodic Riverpod timer plus a user-triggered "Poll now" path; each cycle does conditional GET (`If-None-Match` / `If-Modified-Since`), diffs, and feeds new entries into 3a's `network_fetch_pipeline.dart`. The Manifest mode panel in `url_tab.dart` is a stateful widget driven by Riverpod providers in `manifest_tab_providers.dart`.

**Tech Stack:** Flutter 3.x + Material 3, Riverpod 2.x, `package:xml ^6.5.0` (already in `pubspec.yaml`), `package:csv ^6.0.0` (already in `pubspec.yaml`), `package:crypto ^3.0.3` (already in `pubspec.yaml`), `package:http ^1.2.2` (already in `pubspec.yaml`, also used by 3a), Drift (no schema changes — Phase 1's v72 migration already added the `MediaSubscriptions` and `MediaSubscriptionState` tables and the unique partial index `idx_media_subscription_entry`).

**Spec:** [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) lines 428–552 (Phase 3 deliverables 1 [Manifest mode], 4, 5 [manifest entries], 6).

**No new pubspec dependencies are required.** Every package this plan references is already declared in `pubspec.yaml`.

---

## Background Reading

Read these before starting:

- [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) Phase 3 section, especially deliverables 1 (Manifest mode UI), 4 (parsers), 5 (eager fetch, manifest entry path), and 6 (subscription polling).
- [docs/superpowers/plans/2026-04-27-media-source-extension-phase2.md](./2026-04-27-media-source-extension-phase2.md) — companion plan, same conventions, similar widget/provider/repo split.
- The Phase 3a plan (`docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md` — produced in parallel). 3b builds on 3a's `NetworkCredentialsService`, `NetworkUrlResolver`, `UrlMetadataExtractor`, `network_fetch_pipeline.dart`, and the URL-tab segmented-control scaffold. Cross-reference its task numbering when integrating.
- [lib/core/database/database.dart](../../lib/core/database/database.dart) lines 599–630 (the `MediaSubscriptions` and `MediaSubscriptionState` table definitions) and lines 3556–3565 (the partial unique index `idx_media_subscription_entry ON media(subscription_id, entry_key) WHERE subscription_id IS NOT NULL`).
- [lib/features/media/domain/entities/media_item.dart](../../lib/features/media/domain/entities/media_item.dart) (note the existing `subscriptionId` and `entryKey` columns/fields).
- [lib/features/media/domain/value_objects/media_source_metadata.dart](../../lib/features/media/domain/value_objects/media_source_metadata.dart) (returned by every resolver and reused by the manifest entry pipeline).
- [lib/features/media/data/repositories/media_repository.dart](../../lib/features/media/data/repositories/media_repository.dart) (note the try / `_log.error` / rethrow pattern; mirror it).
- [lib/features/media/presentation/providers/media_resolver_providers.dart](../../lib/features/media/presentation/providers/media_resolver_providers.dart) (provider registration pattern — 3b adds a `manifestEntryResolverProvider` and registers it under `MediaSourceType.manifestEntry`).

Conventions:

- TDD throughout. `dart format .` before every commit. NO `Co-Authored-By` lines in commits.
- File naming: `snake_case.dart`. Class naming: `PascalCase`. Provider naming: `<noun>Provider` for read-only data, `<noun>NotifierProvider` for mutable state.
- Wall-clock-as-UTC for any `DateTime` parsed from a manifest. Atom `<published>` and RSS `<pubDate>` arrive in RFC 3339 / RFC 822 with offsets — convert to UTC, then store; the rest of the dive-photo matcher already treats `MediaItem.takenAt` as wall-clock-UTC. CSV/JSON `takenAt` strings without offsets are interpreted as UTC.
- Error isolation in batch loops: every per-item parse / per-subscription poll catches its own exceptions, logs via `_log.error(...)`, and continues with the next item.
- Network HTTP is testable via `package:http/testing.dart` `MockClient`. Don't `// coverage:ignore` HTTP code — pass a `Client` parameter so tests inject `MockClient`.
- Picker callbacks, periodic timers, and `compute()`-bound top-level functions get `// coverage:ignore` with an inline justification.
- After every async gap in widget code: `if (!context.mounted) return;`.
- `compute()` requires top-level functions or static methods. Big manifest parses (Atom / JSON > 64 KB) run there.

---

## File Structure

| Path | Created/Modified | Responsibility |
|---|---|---|
| `lib/features/media/data/parsers/manifest_entry.dart` | Create | Value type. One row from any manifest format. |
| `lib/features/media/data/parsers/manifest_format.dart` | Create | Enum for the three formats + `fromString` / `displayName`. |
| `lib/features/media/data/parsers/manifest_parse_result.dart` | Create | Value type wrapping `format`, `entries`, `title`, `warnings`. |
| `lib/features/media/data/parsers/atom_manifest_parser.dart` | Create | XML parser for Atom `<entry>` and RSS `<item>`. Returns `List<ManifestEntry>`. Top-level `parseAtomManifest(String xml)` for `compute()` use. |
| `lib/features/media/data/parsers/json_manifest_parser.dart` | Create | Submersion JSON manifest v1 parser. SHA fallback for `id`. |
| `lib/features/media/data/parsers/csv_manifest_parser.dart` | Create | CSV parser via `package:csv`. Required `url` header. |
| `lib/features/media/data/parsers/manifest_format_sniffer.dart` | Create | Pick parser by Content-Type → content shape (XML root / JSON top / CSV header). |
| `lib/features/media/data/services/manifest_fetch_service.dart` | Create | Fetch URL → sniff → parse → return `ManifestParseResult`. Error-typed result. |
| `lib/features/media/data/repositories/manifest_subscription_repository.dart` | Create | Drift access for `MediaSubscriptions` + `MediaSubscriptionState`. CRUD + per-cycle state writes. |
| `lib/features/media/data/services/subscription_poller.dart` | Create | Poll cycle: select-due → conditional GET → diff → enqueue into 3a's pipeline. App-launch + periodic + user-triggered. |
| `lib/features/media/data/resolvers/manifest_entry_resolver.dart` | Create | `MediaSourceResolver` for `MediaSourceType.manifestEntry`. Delegates byte fetch to 3a's `NetworkUrlResolver` (entries are HTTP URLs). |
| `lib/features/media/presentation/providers/manifest_tab_providers.dart` | Create | State for the Manifest panel: URL field, fetch progress, parsed entries, subscribe toggle, poll-interval choice, format override. |
| `lib/features/media/presentation/widgets/manifest_mode_panel.dart` | Create | Manifest mode UI inside URL tab: URL field, Fetch button, format detection chip + override, preview pane, Import button. |
| `lib/features/media/presentation/widgets/manifest_preview_pane.dart` | Create | Renders detected format, entry count, first 5 entries, optional subscription controls. |
| `lib/features/media/presentation/widgets/url_tab.dart` | Modify | 3a created the segmented control with a placeholder Manifest panel. Replace the placeholder with `ManifestModePanel`. |
| `lib/features/media/data/services/network_fetch_pipeline.dart` | Modify | 3a created. Extend to handle `sourceType = manifestEntry` (skip EXIF when manifest already supplied `takenAt`/`lat`/`lon`). |
| `lib/features/media/presentation/providers/media_resolver_providers.dart` | Modify | Register `ManifestEntryResolver` under `MediaSourceType.manifestEntry`. Wire app-launch hook for `SubscriptionPoller`. |
| `lib/main.dart` | Modify (minimal) | Schedule `SubscriptionPoller.startAfterWarmup()` after 30 s. Adds 6 lines. |
| `docs/superpowers/specs/manifest_json_v1.md` | Create | User-facing JSON manifest v1 schema documentation. |
| Plus tests for every new file in `test/` (mirror lib/ structure). | | |

`MediaSubscriptions` (synced) and `MediaSubscriptionState` (per-device) are **already** in the schema (Phase 1, v72). The partial unique index `idx_media_subscription_entry ON media(subscription_id, entry_key) WHERE subscription_id IS NOT NULL` is already in place. Cross-device dedup is a free side-effect of that index plus the sync engine.

---

## Task Index

1. `ManifestEntry` value type + `ManifestFormat` enum + `ManifestParseResult`
2. JSON manifest schema documentation (`manifest_json_v1.md`)
3. `JsonManifestParser` (Submersion JSON manifest v1, SHA fallback)
4. `AtomManifestParser` (Atom `<entry>` + RSS `<item>`)
5. `CsvManifestParser` (`package:csv`, header-driven)
6. `ManifestFormatSniffer` (Content-Type → content-shape)
7. `ManifestFetchService` (HTTP + sniff + parse, top-level result type)
8. `ManifestSubscriptionRepository` (Drift CRUD over `MediaSubscriptions` + `MediaSubscriptionState`)
9. `ManifestEntryResolver` + register in resolver registry
10. Extend `network_fetch_pipeline.dart` for `manifestEntry` source type (skip EXIF when manifest pre-filled metadata)
11. `SubscriptionPoller` — single-pass cycle (select-due → conditional GET → diff → insert/patch/orphan)
12. `SubscriptionPoller` — app-launch + periodic timer + Poll-now wiring
13. `ManifestModePanel` UI — URL field + Fetch button + format chip + preview pane
14. `ManifestModePanel` UI — subscription toggle + poll-interval picker + Import button + commit flow

Estimated 14 tasks. Steps inside each task are 2–5 minutes each.

---

## Task 1: `ManifestEntry`, `ManifestFormat`, and `ManifestParseResult` Value Types

**Files:**
- Create: `lib/features/media/data/parsers/manifest_entry.dart`
- Create: `lib/features/media/data/parsers/manifest_format.dart`
- Create: `lib/features/media/data/parsers/manifest_parse_result.dart`
- Test: `test/features/media/data/parsers/manifest_entry_test.dart`
- Test: `test/features/media/data/parsers/manifest_format_test.dart`
- Test: `test/features/media/data/parsers/manifest_parse_result_test.dart`

The value types every parser shares. Equatable for clean test assertions. All optional fields nullable.

- [ ] **Step 1: Write the failing tests for `ManifestEntry`**

Create `test/features/media/data/parsers/manifest_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';

void main() {
  group('ManifestEntry', () {
    test('equality is structural', () {
      final a = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/a.jpg',
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
      );
      final b = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/a.jpg',
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('optional fields default to null', () {
      const e = ManifestEntry(
        entryKey: 'k',
        url: 'https://example.com/x',
      );
      expect(e.takenAt, isNull);
      expect(e.caption, isNull);
      expect(e.thumbnailUrl, isNull);
      expect(e.latitude, isNull);
      expect(e.longitude, isNull);
      expect(e.width, isNull);
      expect(e.height, isNull);
      expect(e.durationSeconds, isNull);
      expect(e.mediaType, isNull);
    });

    test('toString contains entryKey for debugging', () {
      const e = ManifestEntry(entryKey: 'abc-123', url: 'https://x');
      expect(e.toString(), contains('abc-123'));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/parsers/manifest_entry_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `ManifestEntry`**

Create `lib/features/media/data/parsers/manifest_entry.dart`:

```dart
import 'package:equatable/equatable.dart';

/// One entry parsed from a manifest feed (Atom, RSS, JSON, or CSV).
///
/// Stable identity across polls is provided by [entryKey], which is required
/// and unique per `(subscriptionId, entryKey)` (enforced by the partial unique
/// index `idx_media_subscription_entry`).
///
/// All metadata fields are optional. When present, they are written to the
/// resulting `MediaItem` row directly and EXIF extraction is skipped. When
/// absent, the eager fetch pipeline fills them in from EXIF over HTTP.
class ManifestEntry extends Equatable {
  /// Stable identifier within the manifest. For Atom this is `<id>`, for
  /// RSS `<guid>`, for JSON the `id` field (or `SHA(url + takenAt ?? '')`
  /// fallback), for CSV the `id` column (or the same SHA fallback).
  final String entryKey;

  /// Direct URL to the media bytes (image or video).
  final String url;

  /// When the photo/video was captured. Stored wall-clock-as-UTC.
  final DateTime? takenAt;

  /// Free-form caption / title from the feed.
  final String? caption;

  /// Optional thumbnail URL, used for fast preview before the full fetch
  /// completes.
  final String? thumbnailUrl;

  /// Latitude in decimal degrees.
  final double? latitude;

  /// Longitude in decimal degrees.
  final double? longitude;

  /// Pixel width.
  final int? width;

  /// Pixel height.
  final int? height;

  /// Duration in whole seconds. Set for video entries only.
  final int? durationSeconds;

  /// Media kind hint from the feed: `'photo'` or `'video'`. Optional;
  /// the resolver re-derives from MIME type if absent.
  final String? mediaType;

  const ManifestEntry({
    required this.entryKey,
    required this.url,
    this.takenAt,
    this.caption,
    this.thumbnailUrl,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.durationSeconds,
    this.mediaType,
  });

  @override
  List<Object?> get props => [
    entryKey,
    url,
    takenAt,
    caption,
    thumbnailUrl,
    latitude,
    longitude,
    width,
    height,
    durationSeconds,
    mediaType,
  ];

  @override
  String toString() => 'ManifestEntry(entryKey: $entryKey, url: $url)';
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/data/parsers/manifest_entry_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Write tests for `ManifestFormat`**

Create `test/features/media/data/parsers/manifest_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('ManifestFormat', () {
    test('all known names round-trip via fromString', () {
      for (final f in ManifestFormat.values) {
        expect(ManifestFormat.fromString(f.name), equals(f));
      }
    });

    test('fromString returns null for unknown', () {
      expect(ManifestFormat.fromString('xml'), isNull);
      expect(ManifestFormat.fromString(''), isNull);
      expect(ManifestFormat.fromString(null), isNull);
    });

    test('displayName is human-readable', () {
      expect(ManifestFormat.atom.displayName, 'Atom / RSS');
      expect(ManifestFormat.json.displayName, 'JSON');
      expect(ManifestFormat.csv.displayName, 'CSV');
    });
  });
}
```

- [ ] **Step 6: Implement `ManifestFormat`**

Create `lib/features/media/data/parsers/manifest_format.dart`:

```dart
/// Supported manifest container formats.
///
/// Atom and RSS are folded together because the `AtomManifestParser` is
/// tolerant of mixed roots in the wild.
enum ManifestFormat {
  atom,
  json,
  csv;

  String get displayName {
    switch (this) {
      case ManifestFormat.atom:
        return 'Atom / RSS';
      case ManifestFormat.json:
        return 'JSON';
      case ManifestFormat.csv:
        return 'CSV';
    }
  }

  static ManifestFormat? fromString(String? value) {
    if (value == null) return null;
    for (final f in ManifestFormat.values) {
      if (f.name == value) return f;
    }
    return null;
  }
}
```

- [ ] **Step 7: Write and verify `ManifestParseResult`**

Create `test/features/media/data/parsers/manifest_parse_result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

void main() {
  test('ManifestParseResult exposes entries, format, title, warnings', () {
    final r = ManifestParseResult(
      format: ManifestFormat.json,
      title: 'My Feed',
      entries: const [
        ManifestEntry(entryKey: 'a', url: 'https://x/a.jpg'),
      ],
      warnings: const ['skipped row 7: missing url'],
    );
    expect(r.entries, hasLength(1));
    expect(r.title, 'My Feed');
    expect(r.warnings, hasLength(1));
    expect(r.format, ManifestFormat.json);
  });
}
```

Create `lib/features/media/data/parsers/manifest_parse_result.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Outcome of parsing a manifest body. Always returned successfully — per-
/// item parse failures are reported in [warnings] rather than thrown so the
/// preview UI can show "imported 47 of 50 entries; 3 skipped".
class ManifestParseResult extends Equatable {
  final ManifestFormat format;

  /// Optional feed title (Atom `<title>`, JSON `title`, CSV — null).
  final String? title;

  final List<ManifestEntry> entries;

  /// Per-item warnings (e.g. "row 7: missing url"). Caller decides whether
  /// to surface in UI.
  final List<String> warnings;

  const ManifestParseResult({
    required this.format,
    required this.entries,
    this.title,
    this.warnings = const [],
  });

  @override
  List<Object?> get props => [format, title, entries, warnings];
}
```

- [ ] **Step 8: Run and commit**

```bash
flutter test test/features/media/data/parsers/manifest_entry_test.dart \
             test/features/media/data/parsers/manifest_format_test.dart \
             test/features/media/data/parsers/manifest_parse_result_test.dart
dart format lib/features/media/data/parsers/ test/features/media/data/parsers/
git add lib/features/media/data/parsers/ test/features/media/data/parsers/
git commit -m "feat(media): add ManifestEntry, ManifestFormat, and ManifestParseResult value types"
```

Expected: PASS (7 tests total).

---

## Task 2: JSON Manifest v1 Schema Documentation

**Files:**
- Create: `docs/superpowers/specs/manifest_json_v1.md`

A user-facing schema doc (not auto-tested). Drivers: 3a's design spec promised it, the JSON parser will reference it, and downstream user docs will link it.

- [ ] **Step 1: Verify the spec doc directory exists**

```bash
ls docs/superpowers/specs/2026-04-25-media-source-extension-design.md
```

Expected: file exists.

- [ ] **Step 2: Author `manifest_json_v1.md`**

Create `docs/superpowers/specs/manifest_json_v1.md`:

```markdown
# Submersion Manifest — JSON v1

A small JSON-shaped feed format that Submersion can subscribe to. Pair with
the dive-photo workflow: paste the manifest URL into the photo picker's URL
tab → Manifest mode, optionally subscribe, and Submersion will keep your
dive photos in sync as the feed grows.

## Top-level shape

```json
{
  "version": 1,
  "title": "Eric's Dive Photos",
  "items": [ /* 0 or more entries */ ]
}
```

Required: `version` (must be `1`) and `items` (array; may be empty).
Optional: `title` (string).

Unknown top-level fields are ignored — readers should be tolerant.

## Item shape

```json
{
  "id": "dive-2024-04-12-img-001",
  "url": "https://photos.example.com/dive-001.jpg",
  "thumbnailUrl": "https://photos.example.com/dive-001-thumb.jpg",
  "takenAt": "2024-04-12T14:32:00Z",
  "caption": "Yellowtail at the swim-through",
  "mediaType": "photo",
  "lat": 25.123,
  "lon": -80.456,
  "width": 4032,
  "height": 3024,
  "durationSeconds": null
}
```

### Required item fields

| Field | Type | Notes |
|---|---|---|
| `url` | string | Direct URL to media bytes. HTTP(S) only. |

### Optional item fields

| Field | Type | Notes |
|---|---|---|
| `id` | string | Stable identifier. If omitted, Submersion derives `SHA-256(url + takenAt ?? '')` truncated to 32 hex chars. |
| `takenAt` | RFC 3339 timestamp | If no offset is given, interpreted as UTC. |
| `caption` | string | Free-form. Stored as `MediaItem.caption`. |
| `thumbnailUrl` | string | Used for fast list previews. |
| `mediaType` | `"photo"` or `"video"` | Hint; readers may still re-derive from `Content-Type`. |
| `lat` | number | Decimal degrees. |
| `lon` | number | Decimal degrees. |
| `width` | integer | Pixels. |
| `height` | integer | Pixels. |
| `durationSeconds` | integer | For videos. |

Unknown item fields are ignored.

## Stable identity rules

The `(subscriptionId, id)` pair is the stable key Submersion uses to detect
new vs. removed vs. changed entries on subsequent polls. **Never reuse an
`id` for a different photo**, and don't let it change across polls — both
will produce duplicate or orphaned rows.

## Polling expectations

Submersion polls subscriptions at most once per `pollIntervalSeconds / 4`
(or once per hour, whichever is smaller). Servers should support
conditional GET (`ETag` and/or `Last-Modified`) to keep traffic minimal.

## Minimum viable example

```json
{
  "version": 1,
  "items": [
    { "url": "https://example.com/a.jpg" },
    { "url": "https://example.com/b.jpg" }
  ]
}
```

This is valid: each entry will receive a SHA-derived `id`, and the
`takenAt` fields will be filled in from EXIF after the eager fetch pipeline
runs.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/manifest_json_v1.md
git commit -m "docs(media): add JSON manifest v1 schema spec"
```

---

## Task 3: `JsonManifestParser`

**Files:**
- Create: `lib/features/media/data/parsers/json_manifest_parser.dart`
- Test: `test/features/media/data/parsers/json_manifest_parser_test.dart`

Submersion JSON manifest v1. Returns `ManifestParseResult`. Uses `package:crypto` for the SHA fallback `id`. Per-item failures append to `warnings`, not throws. `dart:convert`'s `jsonDecode` is fine; for parses > 64 KB, the caller (`ManifestFetchService`) is responsible for `compute()` dispatch — the parser itself stays synchronous and pure so it works on the isolate side.

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/parsers/json_manifest_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/json_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('JsonManifestParser', () {
    test('parses a complete v1 manifest', () {
      const body = '''
      {
        "version": 1,
        "title": "Test",
        "items": [
          {
            "id": "img-1",
            "url": "https://example.com/a.jpg",
            "takenAt": "2024-04-12T14:32:00Z",
            "caption": "yellowtail",
            "mediaType": "photo",
            "lat": 25.1,
            "lon": -80.4,
            "width": 4032,
            "height": 3024,
            "thumbnailUrl": "https://example.com/a_t.jpg"
          }
        ]
      }''';

      final result = JsonManifestParser().parse(body);

      expect(result.format, ManifestFormat.json);
      expect(result.title, 'Test');
      expect(result.entries, hasLength(1));
      final e = result.entries.single;
      expect(e.entryKey, 'img-1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'yellowtail');
      expect(e.mediaType, 'photo');
      expect(e.latitude, closeTo(25.1, 0.0001));
      expect(e.longitude, closeTo(-80.4, 0.0001));
      expect(e.width, 4032);
      expect(e.height, 3024);
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
    });

    test('falls back to SHA(url + takenAt) when id is missing', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "url": "https://example.com/a.jpg",
            "takenAt": "2024-04-12T14:32:00Z" }
        ]
      }''';

      final r1 = JsonManifestParser().parse(body);
      final r2 = JsonManifestParser().parse(body);
      expect(r1.entries.single.entryKey, isNotEmpty);
      // Stable across runs.
      expect(r1.entries.single.entryKey, r2.entries.single.entryKey);
      // 32 hex chars (truncated SHA-256).
      expect(r1.entries.single.entryKey, hasLength(32));
    });

    test('SHA fallback also works when takenAt is null', () {
      const body = '''
      {
        "version": 1,
        "items": [ { "url": "https://example.com/a.jpg" } ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });

    test('skips an item with no url and emits a warning', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "id": "ok", "url": "https://example.com/a.jpg" },
          { "id": "bad" }
        ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'ok');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('url'));
    });

    test('throws FormatException when version is missing or != 1', () {
      expect(
        () => JsonManifestParser().parse('{"items": []}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => JsonManifestParser().parse('{"version": 2, "items": []}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when items is missing or wrong type', () {
      expect(
        () => JsonManifestParser().parse('{"version": 1}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => JsonManifestParser().parse('{"version": 1, "items": "not a list"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns empty entries list (no warnings) for empty items array', () {
      final r = JsonManifestParser().parse('{"version": 1, "items": []}');
      expect(r.entries, isEmpty);
      expect(r.warnings, isEmpty);
    });

    test('takenAt without offset is interpreted as UTC', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "id": "a", "url": "https://x/a.jpg", "takenAt": "2024-04-12T14:32:00" }
        ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries.single.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/parsers/json_manifest_parser_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `JsonManifestParser`**

Create `lib/features/media/data/parsers/json_manifest_parser.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Parses a Submersion JSON manifest v1 document. See
/// `docs/superpowers/specs/manifest_json_v1.md` for the schema.
///
/// Per-item parse failures are reported in
/// [ManifestParseResult.warnings] rather than thrown. Top-level shape
/// errors (`version != 1`, missing `items`) throw [FormatException] so
/// the caller can show a friendly "this isn't a Submersion JSON manifest"
/// banner.
class JsonManifestParser {
  ManifestParseResult parse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw FormatException('Invalid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('JSON manifest root must be an object');
    }
    final version = decoded['version'];
    if (version != 1) {
      throw FormatException(
        'JSON manifest version must be 1, got: $version',
      );
    }
    final itemsRaw = decoded['items'];
    if (itemsRaw is! List) {
      throw const FormatException('JSON manifest "items" must be a list');
    }
    final title = decoded['title'] is String
        ? decoded['title'] as String
        : null;

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var i = 0; i < itemsRaw.length; i++) {
      final raw = itemsRaw[i];
      try {
        if (raw is! Map) {
          warnings.add('item $i: not an object');
          continue;
        }
        final url = raw['url'];
        if (url is! String || url.isEmpty) {
          warnings.add('item $i: missing or empty url');
          continue;
        }
        final takenAt = _parseTakenAt(raw['takenAt']);
        final id = raw['id'];
        final entryKey = (id is String && id.isNotEmpty)
            ? id
            : _shaFallback(url, takenAt);
        entries.add(ManifestEntry(
          entryKey: entryKey,
          url: url,
          takenAt: takenAt,
          caption: raw['caption'] is String ? raw['caption'] as String : null,
          thumbnailUrl: raw['thumbnailUrl'] is String
              ? raw['thumbnailUrl'] as String
              : null,
          mediaType: raw['mediaType'] is String
              ? raw['mediaType'] as String
              : null,
          latitude: _asDouble(raw['lat']),
          longitude: _asDouble(raw['lon']),
          width: _asInt(raw['width']),
          height: _asInt(raw['height']),
          durationSeconds: _asInt(raw['durationSeconds']),
        ));
      } catch (e) {
        warnings.add('item $i: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.json,
      title: title,
      entries: entries,
      warnings: warnings,
    );
  }

  static DateTime? _parseTakenAt(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed : parsed.toUtc();
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}

/// Top-level wrapper for `compute()` dispatch when the JSON body exceeds
/// 64 KB. Parser is stateless so this is safe.
// coverage:ignore-start
ManifestParseResult parseJsonManifestIsolate(String body) =>
    JsonManifestParser().parse(body);
// coverage:ignore-end
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/parsers/json_manifest_parser_test.dart
```

Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/parsers/json_manifest_parser.dart \
            test/features/media/data/parsers/json_manifest_parser_test.dart
git add lib/features/media/data/parsers/json_manifest_parser.dart \
        test/features/media/data/parsers/json_manifest_parser_test.dart
git commit -m "feat(media): add JsonManifestParser for Submersion v1 JSON manifests"
```

---

## Task 4: `AtomManifestParser`

**Files:**
- Create: `lib/features/media/data/parsers/atom_manifest_parser.dart`
- Test: `test/features/media/data/parsers/atom_manifest_parser_test.dart`

Atom + RSS in one parser. Tolerant of mixed roots (some feeds use `<rss>` outer with Atom-style `<entry>` children). Uses `package:xml`. Top-level `parseAtomManifest(String xml)` for `compute()` use.

Atom mappings:
- `<id>` → `entryKey`
- `<published>` → `takenAt` (UTC)
- `<title>` → `caption`
- `<media:content url="…">` or `<enclosure url="…">` → `url`
- `<media:thumbnail url="…">` → `thumbnailUrl`
- `<georss:point>27.123 -80.456</georss:point>` → `lat` / `lon`

RSS mappings:
- `<guid>` → `entryKey`
- `<pubDate>` → `takenAt` (RFC 822, UTC)
- `<title>` → `caption`
- `<enclosure url="…">` → `url`

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/parsers/atom_manifest_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/atom_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('AtomManifestParser — Atom format', () {
    test('parses canonical Atom entry', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns:georss="http://www.georss.org/georss">
  <title>Test feed</title>
  <entry>
    <id>tag:example.com,2024:photo:1</id>
    <title>Yellowtail</title>
    <published>2024-04-12T14:32:00Z</published>
    <media:content url="https://example.com/a.jpg" type="image/jpeg" />
    <media:thumbnail url="https://example.com/a_t.jpg" />
    <georss:point>25.123 -80.456</georss:point>
  </entry>
</feed>''';

      final r = AtomManifestParser().parse(body);
      expect(r.format, ManifestFormat.atom);
      expect(r.title, 'Test feed');
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'tag:example.com,2024:photo:1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'Yellowtail');
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
      expect(e.latitude, closeTo(25.123, 0.001));
      expect(e.longitude, closeTo(-80.456, 0.001));
    });

    test('falls back to <enclosure> when no media:content', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>e2</id>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/b.jpg" type="image/jpeg" />
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries.single.url, 'https://example.com/b.jpg');
    });
  });

  group('AtomManifestParser — RSS format', () {
    test('parses canonical RSS item', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>RSS feed</title>
    <item>
      <guid>rss-1</guid>
      <title>Reef shark</title>
      <pubDate>Sat, 12 Apr 2024 14:32:00 +0000</pubDate>
      <enclosure url="https://example.com/c.jpg" type="image/jpeg" length="1234" />
    </item>
  </channel>
</rss>''';

      final r = AtomManifestParser().parse(body);
      expect(r.format, ManifestFormat.atom);
      expect(r.title, 'RSS feed');
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'rss-1');
      expect(e.url, 'https://example.com/c.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'Reef shark');
    });

    test('mixed RSS+Atom roots: rss outer with Atom-style entry children works',
        () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"
                   xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <atom:entry>
      <atom:id>mixed-1</atom:id>
      <atom:published>2024-04-12T14:32:00Z</atom:published>
      <media:content url="https://example.com/m.jpg" />
    </atom:entry>
  </channel>
</rss>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'mixed-1');
      expect(r.entries.single.url, 'https://example.com/m.jpg');
    });
  });

  group('AtomManifestParser — error handling', () {
    test('skips entries with no url and emits a warning', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>good</id>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/g.jpg" />
  </entry>
  <entry>
    <id>bad</id>
    <published>2024-04-12T14:32:00Z</published>
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'good');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('bad'));
    });

    test('throws FormatException on non-XML input', () {
      expect(
        () => AtomManifestParser().parse('not xml at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on XML that is neither feed nor rss', () {
      const body = '<?xml version="1.0"?><root><x/></root>';
      expect(
        () => AtomManifestParser().parse(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to SHA when entry id/guid is missing', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/x.jpg" />
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/parsers/atom_manifest_parser_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `AtomManifestParser`**

Create `lib/features/media/data/parsers/atom_manifest_parser.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Parses Atom and RSS manifest feeds. Tolerant of:
/// - Atom feeds with `<feed>` root
/// - RSS feeds with `<rss><channel>` root
/// - Mixed feeds (RSS outer, Atom entries with namespace prefix)
///
/// Per-entry parse failures are appended to
/// [ManifestParseResult.warnings] rather than thrown.
class AtomManifestParser {
  ManifestParseResult parse(String body) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlException catch (e) {
      throw FormatException('Invalid XML: ${e.message}');
    }

    final root = doc.rootElement;
    final isFeed = _localName(root) == 'feed';
    final isRss = _localName(root) == 'rss';
    if (!isFeed && !isRss) {
      throw FormatException(
        'XML root must be <feed> or <rss>, got: ${root.name.qualified}',
      );
    }

    final title = _firstText(root, 'title') ??
        (isRss ? _firstText(_rssChannel(root) ?? root, 'title') : null);

    // Both kinds of entry node — search the whole tree, since mixed feeds
    // nest Atom <entry> inside RSS <channel>.
    final entryNodes = doc.descendants
        .whereType<XmlElement>()
        .where((el) {
          final ln = _localName(el);
          return ln == 'entry' || ln == 'item';
        })
        .toList();

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var i = 0; i < entryNodes.length; i++) {
      final node = entryNodes[i];
      try {
        final url = _extractUrl(node);
        if (url == null || url.isEmpty) {
          final id = _extractEntryKey(node, null) ?? '<entry $i>';
          warnings.add('$id: no media url');
          continue;
        }
        final takenAt = _extractTakenAt(node);
        final entryKey = _extractEntryKey(node, null) ?? _shaFallback(url, takenAt);
        entries.add(ManifestEntry(
          entryKey: entryKey,
          url: url,
          takenAt: takenAt,
          caption: _firstText(node, 'title'),
          thumbnailUrl: _findUrlAttr(node, 'thumbnail'),
          latitude: _extractLat(node),
          longitude: _extractLon(node),
        ));
      } catch (e) {
        warnings.add('entry $i: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.atom,
      title: title,
      entries: entries,
      warnings: warnings,
    );
  }

  // --- helpers ---

  static String _localName(XmlElement el) => el.name.local;

  static XmlElement? _rssChannel(XmlElement rssRoot) =>
      rssRoot.childElements.firstWhere(
        (el) => _localName(el) == 'channel',
        orElse: () => XmlElement(XmlName('missing')),
      );

  /// First descendant element with the given local name, returning trimmed text.
  static String? _firstText(XmlElement scope, String localName) {
    for (final el in scope.descendants.whereType<XmlElement>()) {
      if (_localName(el) == localName) {
        final text = el.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Extract a `url=` or `href=` attribute from a `<media:content>`,
  /// `<enclosure>`, or Atom `<link rel="enclosure">` descendant.
  static String? _extractUrl(XmlElement entry) {
    for (final el in entry.descendants.whereType<XmlElement>()) {
      final ln = _localName(el);
      if (ln == 'content' || ln == 'enclosure') {
        final attr = el.getAttribute('url') ?? el.getAttribute('href');
        if (attr != null && attr.isNotEmpty) return attr;
      }
      if (ln == 'link') {
        final rel = el.getAttribute('rel');
        if (rel == 'enclosure') {
          final attr = el.getAttribute('href') ?? el.getAttribute('url');
          if (attr != null && attr.isNotEmpty) return attr;
        }
      }
    }
    return null;
  }

  /// Extract `<media:thumbnail url="…">` (or similar) `url` attribute.
  static String? _findUrlAttr(XmlElement entry, String localName) {
    for (final el in entry.descendants.whereType<XmlElement>()) {
      if (_localName(el) == localName) {
        final attr = el.getAttribute('url') ?? el.getAttribute('href');
        if (attr != null && attr.isNotEmpty) return attr;
      }
    }
    return null;
  }

  static String? _extractEntryKey(XmlElement entry, String? fallback) {
    final id = _firstText(entry, 'id');
    if (id != null && id.isNotEmpty) return id;
    final guid = _firstText(entry, 'guid');
    if (guid != null && guid.isNotEmpty) return guid;
    return fallback;
  }

  static DateTime? _extractTakenAt(XmlElement entry) {
    final published = _firstText(entry, 'published');
    if (published != null) {
      final parsed = DateTime.tryParse(published);
      if (parsed != null) return parsed.isUtc ? parsed : parsed.toUtc();
    }
    final updated = _firstText(entry, 'updated');
    if (updated != null) {
      final parsed = DateTime.tryParse(updated);
      if (parsed != null) return parsed.isUtc ? parsed : parsed.toUtc();
    }
    final pubDate = _firstText(entry, 'pubDate');
    if (pubDate != null) {
      final parsed = _parseRfc822(pubDate);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  static double? _extractLat(XmlElement entry) {
    final pt = _firstText(entry, 'point');
    if (pt == null) return null;
    final parts = pt.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return double.tryParse(parts[0]);
  }

  static double? _extractLon(XmlElement entry) {
    final pt = _firstText(entry, 'point');
    if (pt == null) return null;
    final parts = pt.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return double.tryParse(parts[1]);
  }

  /// Minimal RFC 822 parser for `pubDate` (e.g. "Sat, 12 Apr 2024 14:32:00 +0000").
  static DateTime? _parseRfc822(String input) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final m = RegExp(
      r'^(?:\w{3},\s+)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|UT|Z|EST|EDT|CST|CDT|MST|MDT|PST|PDT)$',
    ).firstMatch(input.trim());
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final mon = months[m.group(2)];
    if (mon == null) return null;
    final year = int.parse(m.group(3)!);
    final hour = int.parse(m.group(4)!);
    final min = int.parse(m.group(5)!);
    final sec = int.parse(m.group(6)!);
    final tz = m.group(7)!;
    int offsetMinutes = 0;
    if (tz.startsWith('+') || tz.startsWith('-')) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final hh = int.parse(tz.substring(1, 3));
      final mm = int.parse(tz.substring(3, 5));
      offsetMinutes = sign * (hh * 60 + mm);
    }
    final dt = DateTime.utc(year, mon, day, hour, min, sec);
    return dt.subtract(Duration(minutes: offsetMinutes));
  }

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}

/// Top-level wrapper for `compute()` dispatch when the XML body exceeds
/// 64 KB.
// coverage:ignore-start
ManifestParseResult parseAtomManifestIsolate(String body) =>
    AtomManifestParser().parse(body);
// coverage:ignore-end
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/parsers/atom_manifest_parser_test.dart
```

Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/parsers/atom_manifest_parser.dart \
            test/features/media/data/parsers/atom_manifest_parser_test.dart
git add lib/features/media/data/parsers/atom_manifest_parser.dart \
        test/features/media/data/parsers/atom_manifest_parser_test.dart
git commit -m "feat(media): add AtomManifestParser for Atom/RSS feeds"
```

---

## Task 5: `CsvManifestParser`

**Files:**
- Create: `lib/features/media/data/parsers/csv_manifest_parser.dart`
- Test: `test/features/media/data/parsers/csv_manifest_parser_test.dart`

CSV via `package:csv`. Required header: at minimum `url`. Recognized columns: `url`, `id`, `takenAt`, `caption`, `mediaType`, `lat`, `lon`, `width`, `height`, `durationSeconds`, `thumbnailUrl`. Unknown columns ignored. Per-row failures appended to warnings.

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/parsers/csv_manifest_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/csv_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('CsvManifestParser', () {
    test('parses a complete row', () {
      const body =
          'url,id,takenAt,caption,mediaType,lat,lon,width,height,thumbnailUrl\n'
          'https://example.com/a.jpg,id-1,2024-04-12T14:32:00Z,caption-a,photo,25.1,-80.4,4032,3024,https://example.com/a_t.jpg';
      final r = CsvManifestParser().parse(body);
      expect(r.format, ManifestFormat.csv);
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'id-1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'caption-a');
      expect(e.mediaType, 'photo');
      expect(e.latitude, closeTo(25.1, 0.001));
      expect(e.longitude, closeTo(-80.4, 0.001));
      expect(e.width, 4032);
      expect(e.height, 3024);
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
    });

    test('falls back to SHA(url + takenAt) when id is empty', () {
      const body = 'url,takenAt\nhttps://example.com/a.jpg,2024-04-12T14:32:00Z';
      final r = CsvManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });

    test('throws FormatException when url column is missing', () {
      const body = 'id,takenAt\nx,2024-04-12T14:32:00Z';
      expect(
        () => CsvManifestParser().parse(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips a row with empty url and emits a warning', () {
      const body = 'url,id\nhttps://example.com/a.jpg,a\n,b';
      final r = CsvManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'a');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('row 2'));
    });

    test('ignores unknown columns', () {
      const body = 'url,wat,id\nhttps://x/a.jpg,zzz,a';
      final r = CsvManifestParser().parse(body);
      expect(r.entries.single.entryKey, 'a');
    });

    test('throws FormatException for empty input', () {
      expect(() => CsvManifestParser().parse(''), throwsA(isA<FormatException>()));
    });

    test('handles header-only document gracefully', () {
      final r = CsvManifestParser().parse('url,id\n');
      expect(r.entries, isEmpty);
      expect(r.warnings, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/parsers/csv_manifest_parser_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `CsvManifestParser`**

Create `lib/features/media/data/parsers/csv_manifest_parser.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

const _knownColumns = {
  'url',
  'id',
  'takenAt',
  'caption',
  'mediaType',
  'lat',
  'lon',
  'width',
  'height',
  'durationSeconds',
  'thumbnailUrl',
};

/// Parses a CSV manifest. Required header: `url` (anywhere). Recognized
/// columns: see [_knownColumns]. Unknown columns are ignored.
///
/// Per-row failures are appended to [ManifestParseResult.warnings] rather
/// than thrown. Top-level shape errors (no `url` column, empty document)
/// throw [FormatException].
class CsvManifestParser {
  ManifestParseResult parse(String body) {
    if (body.trim().isEmpty) {
      throw const FormatException('CSV manifest is empty');
    }

    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(body);
    if (rows.isEmpty) {
      throw const FormatException('CSV manifest has no rows');
    }

    final header = rows.first.map((c) => c.toString().trim()).toList();
    final urlIdx = header.indexOf('url');
    if (urlIdx < 0) {
      throw const FormatException('CSV manifest must have a "url" column');
    }
    final colIdx = <String, int>{
      for (final col in _knownColumns)
        if (header.contains(col)) col: header.indexOf(col),
    };

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      try {
        final urlCell = _cell(row, urlIdx);
        if (urlCell == null || urlCell.isEmpty) {
          warnings.add('row $r: empty url');
          continue;
        }
        final takenAt = _parseTakenAt(_cell(row, colIdx['takenAt']));
        final id = _cell(row, colIdx['id']);
        final entryKey = (id != null && id.isNotEmpty)
            ? id
            : _shaFallback(urlCell, takenAt);
        entries.add(ManifestEntry(
          entryKey: entryKey,
          url: urlCell,
          takenAt: takenAt,
          caption: _cell(row, colIdx['caption']),
          thumbnailUrl: _cell(row, colIdx['thumbnailUrl']),
          mediaType: _cell(row, colIdx['mediaType']),
          latitude: _asDouble(_cell(row, colIdx['lat'])),
          longitude: _asDouble(_cell(row, colIdx['lon'])),
          width: _asInt(_cell(row, colIdx['width'])),
          height: _asInt(_cell(row, colIdx['height'])),
          durationSeconds: _asInt(_cell(row, colIdx['durationSeconds'])),
        ));
      } catch (e) {
        warnings.add('row $r: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.csv,
      entries: entries,
      warnings: warnings,
    );
  }

  static String? _cell(List<dynamic> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return null;
    final raw = row[idx]?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  static DateTime? _parseTakenAt(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed : parsed.toUtc();
  }

  static double? _asDouble(String? v) =>
      v == null ? null : double.tryParse(v);

  static int? _asInt(String? v) => v == null ? null : int.tryParse(v);

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/parsers/csv_manifest_parser_test.dart
```

Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/parsers/csv_manifest_parser.dart \
            test/features/media/data/parsers/csv_manifest_parser_test.dart
git add lib/features/media/data/parsers/csv_manifest_parser.dart \
        test/features/media/data/parsers/csv_manifest_parser_test.dart
git commit -m "feat(media): add CsvManifestParser"
```

---

## Task 6: `ManifestFormatSniffer`

**Files:**
- Create: `lib/features/media/data/parsers/manifest_format_sniffer.dart`
- Test: `test/features/media/data/parsers/manifest_format_sniffer_test.dart`

Pure function. Inputs: `Content-Type` (nullable) + raw body. Output: `ManifestFormat`. Heuristic order:

1. If `Content-Type` clearly says JSON / XML / CSV, prefer that.
2. Otherwise look at body:
   - first non-whitespace character `{` or `[` → JSON
   - first non-whitespace `<` (XML declaration or `<feed`/`<rss`) → Atom
   - otherwise, if first line contains a comma and `url` substring (case-insensitive) → CSV
   - else: throw `FormatException` ("could not detect format").

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/parsers/manifest_format_sniffer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_format_sniffer.dart';

void main() {
  group('ManifestFormatSniffer', () {
    final sniff = ManifestFormatSniffer().sniff;

    test('Content-Type application/json wins', () {
      expect(sniff(contentType: 'application/json', body: '<feed/>'),
          ManifestFormat.json);
    });

    test('Content-Type application/atom+xml maps to atom', () {
      expect(sniff(contentType: 'application/atom+xml; charset=utf-8',
                   body: '{}'),
          ManifestFormat.atom);
    });

    test('Content-Type application/rss+xml maps to atom', () {
      expect(sniff(contentType: 'application/rss+xml', body: '{}'),
          ManifestFormat.atom);
    });

    test('Content-Type text/csv maps to csv', () {
      expect(sniff(contentType: 'text/csv', body: 'url,id\n'),
          ManifestFormat.csv);
    });

    test('falls back to body sniffing when Content-Type is generic', () {
      expect(sniff(contentType: 'application/octet-stream',
                   body: '{"version": 1, "items": []}'),
          ManifestFormat.json);
      expect(sniff(contentType: 'text/plain',
                   body: '<?xml version="1.0"?><feed/>'),
          ManifestFormat.atom);
      expect(sniff(contentType: null,
                   body: 'url,id\nhttps://x,a\n'),
          ManifestFormat.csv);
    });

    test('detects JSON arrays as JSON', () {
      expect(sniff(contentType: null, body: '   [{"url":"x"}]'),
          ManifestFormat.json);
    });

    test('throws FormatException when nothing matches', () {
      expect(
        () => sniff(contentType: null, body: 'plain text body'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/parsers/manifest_format_sniffer_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement the sniffer**

Create `lib/features/media/data/parsers/manifest_format_sniffer.dart`:

```dart
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Picks a [ManifestFormat] from response Content-Type and body shape.
///
/// Order: Content-Type first (it's authoritative when set correctly), then
/// body sniffing. Throws [FormatException] when neither yields a match —
/// the UI shows an "unrecognized manifest format" error and offers the
/// override dropdown.
class ManifestFormatSniffer {
  ManifestFormat sniff({required String? contentType, required String body}) {
    final fromType = _byContentType(contentType);
    if (fromType != null) return fromType;
    return _byBody(body);
  }

  static ManifestFormat? _byContentType(String? contentType) {
    if (contentType == null) return null;
    final lower = contentType.toLowerCase();
    if (lower.contains('json')) return ManifestFormat.json;
    if (lower.contains('atom') ||
        lower.contains('rss') ||
        lower.contains('xml')) {
      return ManifestFormat.atom;
    }
    if (lower.contains('csv')) return ManifestFormat.csv;
    return null;
  }

  static ManifestFormat _byBody(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty) {
      throw const FormatException('empty body');
    }
    final first = trimmed.codeUnitAt(0);
    if (first == 0x7B || first == 0x5B) {
      // '{' or '['
      return ManifestFormat.json;
    }
    if (first == 0x3C) {
      // '<'
      return ManifestFormat.atom;
    }
    // CSV heuristic: first line contains a comma AND a `url` substring
    // (case-insensitive).
    final firstLine = trimmed.split(RegExp(r'\r?\n')).first;
    if (firstLine.contains(',') &&
        firstLine.toLowerCase().contains('url')) {
      return ManifestFormat.csv;
    }
    throw const FormatException(
      'Could not detect manifest format from Content-Type or body shape.',
    );
  }
}
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/parsers/manifest_format_sniffer_test.dart
```

Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/parsers/manifest_format_sniffer.dart \
            test/features/media/data/parsers/manifest_format_sniffer_test.dart
git add lib/features/media/data/parsers/manifest_format_sniffer.dart \
        test/features/media/data/parsers/manifest_format_sniffer_test.dart
git commit -m "feat(media): add ManifestFormatSniffer for content-type and body detection"
```

---

## Task 7: `ManifestFetchService`

**Files:**
- Create: `lib/features/media/data/services/manifest_fetch_service.dart`
- Test: `test/features/media/data/services/manifest_fetch_service_test.dart`

Wraps fetch + sniff + parse into a single async call returning a tagged union (`ManifestFetchOutcome`). Inputs: URL, optional `formatOverride`, optional `If-None-Match` / `If-Modified-Since`. Uses 3a's `NetworkCredentialsService` to inject auth headers per host.

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/services/manifest_fetch_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';

class _FakeCreds {
  final Map<String, Map<String, String>> byHost;
  _FakeCreds(this.byHost);
  Future<Map<String, String>> headersFor(Uri uri) async =>
      byHost[uri.host] ?? const {};
}

void main() {
  group('ManifestFetchService', () {
    test('JSON success returns parsed entries', () async {
      final client = MockClient((req) async => http.Response(
            '{"version":1,"title":"t","items":[{"url":"https://x/a"}]}',
            200,
            headers: {'content-type': 'application/json',
                      'etag': 'W/"abc"',
                      'last-modified': 'Sat, 12 Apr 2024 14:00:00 GMT'},
          ));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://example.com/m.json'));
      expect(result, isA<ManifestFetchSuccess>());
      final ok = result as ManifestFetchSuccess;
      expect(ok.parsed.format, ManifestFormat.json);
      expect(ok.parsed.entries, hasLength(1));
      expect(ok.etag, 'W/"abc"');
      expect(ok.lastModified, 'Sat, 12 Apr 2024 14:00:00 GMT');
    });

    test('304 returns NotModified with timestamps', () async {
      final client = MockClient((req) async {
        expect(req.headers['if-none-match'], '"abc"');
        expect(req.headers['if-modified-since'],
            'Sat, 12 Apr 2024 14:00:00 GMT');
        return http.Response('', 304);
      });
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(
        Uri.parse('https://example.com/m.json'),
        ifNoneMatch: '"abc"',
        ifModifiedSince: 'Sat, 12 Apr 2024 14:00:00 GMT',
      );
      expect(result, isA<ManifestFetchNotModified>());
    });

    test('non-2xx returns Failure', () async {
      final client = MockClient((req) async => http.Response('nope', 500));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://x/m'));
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).statusCode, 500);
    });

    test('format override skips sniffing', () async {
      // Body looks like JSON but we force CSV — parser will throw.
      final client = MockClient((req) async => http.Response(
            '{"version":1,"items":[]}',
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(
        Uri.parse('https://x/m'),
        formatOverride: ManifestFormat.csv,
      );
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).message,
          contains('url'));
    });

    test('credentials headers are sent on the GET', () async {
      var sawAuth = false;
      final client = MockClient((req) async {
        sawAuth = req.headers['authorization'] == 'Basic Zm9vOmJhcg==';
        return http.Response(
          '{"version":1,"items":[]}', 200,
          headers: {'content-type': 'application/json'},
        );
      });
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds({
          'example.com': {'authorization': 'Basic Zm9vOmJhcg=='},
        }),
      );
      await svc.fetch(Uri.parse('https://example.com/m.json'));
      expect(sawAuth, isTrue);
    });

    test('401 surfaces as Unauthorized failure for sign-in flow', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://x/m'));
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).statusCode, 401);
      expect(result.unauthorized, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/services/manifest_fetch_service_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `ManifestFetchService`**

Create `lib/features/media/data/services/manifest_fetch_service.dart`:

```dart
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/atom_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/csv_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/json_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_format_sniffer.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Minimal interface expected from 3a's `NetworkCredentialsService`. We only
/// need per-host headers; full credential management lives in 3a.
abstract class ManifestCredentialsLookup {
  Future<Map<String, String>> headersFor(Uri uri);
}

/// Outcome of a manifest fetch.
sealed class ManifestFetchOutcome {
  const ManifestFetchOutcome();
}

class ManifestFetchSuccess extends ManifestFetchOutcome {
  final ManifestParseResult parsed;
  final String? etag;
  final String? lastModified;
  const ManifestFetchSuccess({
    required this.parsed,
    this.etag,
    this.lastModified,
  });
}

class ManifestFetchNotModified extends ManifestFetchOutcome {
  const ManifestFetchNotModified();
}

class ManifestFetchFailure extends ManifestFetchOutcome {
  final int? statusCode;
  final String message;
  const ManifestFetchFailure({this.statusCode, required this.message});
  bool get unauthorized => statusCode == 401;
}

class ManifestFetchService {
  ManifestFetchService({
    required http.Client client,
    required this.credentials,
    ManifestFormatSniffer? sniffer,
  })  : _client = client,
        _sniffer = sniffer ?? ManifestFormatSniffer();

  final http.Client _client;
  final ManifestCredentialsLookup credentials;
  final ManifestFormatSniffer _sniffer;
  final _log = LoggerService.forClass(ManifestFetchService);

  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    try {
      final headers = <String, String>{
        ...await credentials.headersFor(url),
        if (ifNoneMatch != null) 'If-None-Match': ifNoneMatch,
        if (ifModifiedSince != null) 'If-Modified-Since': ifModifiedSince,
      };
      final resp = await _client.get(url, headers: headers);
      if (resp.statusCode == 304) {
        return const ManifestFetchNotModified();
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return ManifestFetchFailure(
          statusCode: resp.statusCode,
          message: 'HTTP ${resp.statusCode}',
        );
      }
      final body = resp.body;
      final ManifestFormat format;
      try {
        format = formatOverride ??
            _sniffer.sniff(
              contentType: resp.headers['content-type'],
              body: body,
            );
      } on FormatException catch (e) {
        return ManifestFetchFailure(message: e.message);
      }
      try {
        final parsed = _parse(format, body);
        return ManifestFetchSuccess(
          parsed: parsed,
          etag: resp.headers['etag'],
          lastModified: resp.headers['last-modified'],
        );
      } on FormatException catch (e) {
        return ManifestFetchFailure(message: e.message);
      }
    } catch (e, st) {
      _log.error('Manifest fetch failed: $url', error: e, stackTrace: st);
      return ManifestFetchFailure(message: '$e');
    }
  }

  ManifestParseResult _parse(ManifestFormat format, String body) {
    switch (format) {
      case ManifestFormat.json:
        return JsonManifestParser().parse(body);
      case ManifestFormat.atom:
        return AtomManifestParser().parse(body);
      case ManifestFormat.csv:
        return CsvManifestParser().parse(body);
    }
  }
}
```

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/services/manifest_fetch_service_test.dart
```

Expected: PASS (6 tests).

Note: This service deliberately accepts a minimal `ManifestCredentialsLookup` interface (just `headersFor(Uri)`) instead of importing 3a's full `NetworkCredentialsService`. In Task 13 the provider for `ManifestFetchService` adapts the real 3a service into this interface, so 3b stays loosely coupled to 3a's exact signatures.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/manifest_fetch_service.dart \
            test/features/media/data/services/manifest_fetch_service_test.dart
git add lib/features/media/data/services/manifest_fetch_service.dart \
        test/features/media/data/services/manifest_fetch_service_test.dart
git commit -m "feat(media): add ManifestFetchService (HTTP + sniff + parse)"
```

---

## Task 8: `ManifestSubscriptionRepository`

**Files:**
- Create: `lib/features/media/data/repositories/manifest_subscription_repository.dart`
- Test: `test/features/media/data/repositories/manifest_subscription_repository_test.dart`

Drift CRUD over `MediaSubscriptions` (synced) + `MediaSubscriptionState` (per-device). Domain entity `ManifestSubscription` defined inline in the repo file (small, single use). All public methods follow the try / `_log.error` / rethrow pattern.

Operations needed by the rest of 3b:

- `createSubscription(...)` — insert both rows in a transaction.
- `getById(id)` — join the two tables and return a domain `ManifestSubscription` with state fields nullable.
- `listActiveDue(now)` — `WHERE isActive = true AND (nextPollAt IS NULL OR nextPollAt <= now)`.
- `recordPollSuccess(id, {pollIntervalSeconds, etag, lastModified, now})` — sets `lastPolledAt = now`, `nextPollAt = now + pollIntervalSeconds`, clears `lastError`/`lastErrorAt`, updates `lastEtag`/`lastModified`.
- `recordPollNotModified(id, {pollIntervalSeconds, now})` — same as success but doesn't change ETag/Last-Modified.
- `recordPollFailure(id, {pollIntervalSeconds, error, now})` — backoff: `nextPollAt = now + min(pollInterval * 2, 24 h)`.
- `setActive(id, isActive)` — for the Settings page in 3c.
- `deleteById(id)` — cascades `MediaSubscriptionState` and (via the existing `subscription_id` foreign-key column on `media`) leaves the `MediaItem` rows alone with their `subscription_id` pointing at a now-missing parent. Phase 3c's settings UI offers an explicit "delete also removes feed entries" confirmation; for 3b the call is just the row delete.

- [ ] **Step 1: Write a fixture helper test that exercises createSubscription + getById round-trip**

Create `test/features/media/data/repositories/manifest_subscription_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show NativeDatabase;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';

void main() {
  late AppDatabase db;
  late ManifestSubscriptionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseService.instance.setDatabaseForTesting(db);
    repo = ManifestSubscriptionRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabaseForTesting(null);
  });

  test('create + getById round-trips', () async {
    final created = await repo.createSubscription(
      manifestUrl: 'https://example.com/m.json',
      format: ManifestFormat.json,
      displayName: 'Eric',
      pollIntervalSeconds: 3600,
    );
    final fetched = await repo.getById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.manifestUrl, 'https://example.com/m.json');
    expect(fetched.format, ManifestFormat.json);
    expect(fetched.pollIntervalSeconds, 3600);
    expect(fetched.isActive, isTrue);
    expect(fetched.lastPolledAt, isNull);
    expect(fetched.nextPollAt, isNull);
  });

  test('listActiveDue returns subscriptions whose nextPollAt is null or past',
      () async {
    final now = DateTime.utc(2024, 4, 12, 14, 0);
    final newSub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    // Fresh subscription has nextPollAt = null → should be due.
    final due1 = await repo.listActiveDue(now);
    expect(due1.map((s) => s.id), contains(newSub.id));

    // After a successful poll with 1 h interval, it's not due 30 m later.
    await repo.recordPollSuccess(
      newSub.id,
      pollIntervalSeconds: 3600,
      etag: '"abc"',
      lastModified: null,
      now: now,
    );
    final due2 = await repo.listActiveDue(now.add(const Duration(minutes: 30)));
    expect(due2.map((s) => s.id), isNot(contains(newSub.id)));

    // 90 m later it's due again.
    final due3 = await repo.listActiveDue(now.add(const Duration(minutes: 90)));
    expect(due3.map((s) => s.id), contains(newSub.id));
  });

  test('recordPollFailure sets nextPollAt with exponential backoff cap', () async {
    final now = DateTime.utc(2024, 4, 12, 14, 0);
    final sub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    // 12 h * 2 = 24 h; cap at 24 h.
    await repo.recordPollFailure(
      sub.id,
      pollIntervalSeconds: 12 * 3600,
      error: 'boom',
      now: now,
    );
    final fetched = await repo.getById(sub.id);
    final delta = fetched!.nextPollAt!.difference(now);
    expect(delta, const Duration(hours: 24));
    expect(fetched.lastError, 'boom');
  });

  test('setActive toggles flag', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    await repo.setActive(sub.id, false);
    expect((await repo.getById(sub.id))!.isActive, isFalse);
  });

  test('deleteById removes both rows', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    await repo.deleteById(sub.id);
    expect(await repo.getById(sub.id), isNull);
  });
}
```

Note: Re-use the existing in-memory `AppDatabase.forTesting(NativeDatabase.memory())` pattern from the Phase 2 plan and `media_repository_test.dart`. The `DatabaseService.instance.setDatabaseForTesting(...)` helper is already present in the codebase. Verify: `grep -n setDatabaseForTesting lib/core/services/database_service.dart`.

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/repositories/manifest_subscription_repository_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the repository**

Create `lib/features/media/data/repositories/manifest_subscription_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Domain entity joining `MediaSubscriptions` (synced) with
/// `MediaSubscriptionState` (per-device).
class ManifestSubscription extends Equatable {
  final String id;
  final String manifestUrl;
  final ManifestFormat format;
  final String? displayName;
  final int pollIntervalSeconds;
  final bool isActive;
  final String? credentialsHostId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Per-device state (nullable until first poll cycle).
  final DateTime? lastPolledAt;
  final DateTime? nextPollAt;
  final String? lastEtag;
  final String? lastModified;
  final String? lastError;
  final DateTime? lastErrorAt;

  const ManifestSubscription({
    required this.id,
    required this.manifestUrl,
    required this.format,
    this.displayName,
    required this.pollIntervalSeconds,
    required this.isActive,
    this.credentialsHostId,
    required this.createdAt,
    required this.updatedAt,
    this.lastPolledAt,
    this.nextPollAt,
    this.lastEtag,
    this.lastModified,
    this.lastError,
    this.lastErrorAt,
  });

  @override
  List<Object?> get props => [
    id, manifestUrl, format, displayName, pollIntervalSeconds, isActive,
    credentialsHostId, createdAt, updatedAt, lastPolledAt, nextPollAt,
    lastEtag, lastModified, lastError, lastErrorAt,
  ];
}

class ManifestSubscriptionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ManifestSubscriptionRepository);

  Future<ManifestSubscription> createSubscription({
    required String manifestUrl,
    required ManifestFormat format,
    String? displayName,
    int pollIntervalSeconds = 86400,
    bool isActive = true,
    String? credentialsHostId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();
      final nowMs = now.millisecondsSinceEpoch;
      await _db.transaction(() async {
        await _db.into(_db.mediaSubscriptions).insert(
          MediaSubscriptionsCompanion(
            id: Value(id),
            manifestUrl: Value(manifestUrl),
            format: Value(format.name),
            displayName: Value(displayName),
            pollIntervalSeconds: Value(pollIntervalSeconds),
            isActive: Value(isActive),
            credentialsHostId: Value(credentialsHostId),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
        await _db.into(_db.mediaSubscriptionState).insert(
          MediaSubscriptionStateCompanion(subscriptionId: Value(id)),
        );
      });
      final fetched = await getById(id);
      return fetched!;
    } catch (e, st) {
      _log.error('createSubscription failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<ManifestSubscription?> getById(String id) async {
    try {
      final query = _db.select(_db.mediaSubscriptions).join([
        leftOuterJoin(
          _db.mediaSubscriptionState,
          _db.mediaSubscriptionState.subscriptionId.equalsExp(
            _db.mediaSubscriptions.id,
          ),
        ),
      ])..where(_db.mediaSubscriptions.id.equals(id));
      final row = await query.getSingleOrNull();
      if (row == null) return null;
      return _toEntity(
        row.readTable(_db.mediaSubscriptions),
        row.readTableOrNull(_db.mediaSubscriptionState),
      );
    } catch (e, st) {
      _log.error('getById failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<ManifestSubscription>> listActiveDue(DateTime now) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final query = _db.select(_db.mediaSubscriptions).join([
        leftOuterJoin(
          _db.mediaSubscriptionState,
          _db.mediaSubscriptionState.subscriptionId.equalsExp(
            _db.mediaSubscriptions.id,
          ),
        ),
      ])
        ..where(_db.mediaSubscriptions.isActive.equals(true))
        ..where(
          _db.mediaSubscriptionState.nextPollAt.isNull() |
              _db.mediaSubscriptionState.nextPollAt
                  .isSmallerOrEqualValue(nowMs),
        );
      final rows = await query.get();
      return rows
          .map((r) => _toEntity(
                r.readTable(_db.mediaSubscriptions),
                r.readTableOrNull(_db.mediaSubscriptionState),
              ))
          .toList();
    } catch (e, st) {
      _log.error('listActiveDue failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollSuccess(
    String id, {
    required int pollIntervalSeconds,
    required String? etag,
    required String? lastModified,
    required DateTime now,
  }) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final next = now.add(Duration(seconds: pollIntervalSeconds));
      await (_db.update(_db.mediaSubscriptionState)
            ..where((t) => t.subscriptionId.equals(id)))
          .write(MediaSubscriptionStateCompanion(
        lastPolledAt: Value(nowMs),
        nextPollAt: Value(next.millisecondsSinceEpoch),
        lastEtag: Value(etag),
        lastModified: Value(lastModified),
        lastError: const Value(null),
        lastErrorAt: const Value(null),
      ));
    } catch (e, st) {
      _log.error('recordPollSuccess failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollNotModified(
    String id, {
    required int pollIntervalSeconds,
    required DateTime now,
  }) async {
    try {
      final nowMs = now.millisecondsSinceEpoch;
      final next = now.add(Duration(seconds: pollIntervalSeconds));
      await (_db.update(_db.mediaSubscriptionState)
            ..where((t) => t.subscriptionId.equals(id)))
          .write(MediaSubscriptionStateCompanion(
        lastPolledAt: Value(nowMs),
        nextPollAt: Value(next.millisecondsSinceEpoch),
        lastError: const Value(null),
        lastErrorAt: const Value(null),
      ));
    } catch (e, st) {
      _log.error('recordPollNotModified failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> recordPollFailure(
    String id, {
    required int pollIntervalSeconds,
    required String error,
    required DateTime now,
  }) async {
    try {
      const cap = Duration(hours: 24);
      final backoff = Duration(seconds: pollIntervalSeconds * 2);
      final delay = backoff > cap ? cap : backoff;
      final nowMs = now.millisecondsSinceEpoch;
      await (_db.update(_db.mediaSubscriptionState)
            ..where((t) => t.subscriptionId.equals(id)))
          .write(MediaSubscriptionStateCompanion(
        lastError: Value(error),
        lastErrorAt: Value(nowMs),
        nextPollAt: Value(now.add(delay).millisecondsSinceEpoch),
      ));
    } catch (e, st) {
      _log.error('recordPollFailure failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> setActive(String id, bool isActive) async {
    try {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(_db.mediaSubscriptions)
            ..where((t) => t.id.equals(id)))
          .write(MediaSubscriptionsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(nowMs),
      ));
    } catch (e, st) {
      _log.error('setActive failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteById(String id) async {
    try {
      await _db.transaction(() async {
        // State has a foreign-key cascade on subscriptionId, but we delete
        // explicitly for clarity.
        await (_db.delete(_db.mediaSubscriptionState)
              ..where((t) => t.subscriptionId.equals(id)))
            .go();
        await (_db.delete(_db.mediaSubscriptions)
              ..where((t) => t.id.equals(id)))
            .go();
      });
    } catch (e, st) {
      _log.error('deleteById failed: $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  ManifestSubscription _toEntity(
    MediaSubscription sub,
    MediaSubscriptionStateData? state,
  ) {
    return ManifestSubscription(
      id: sub.id,
      manifestUrl: sub.manifestUrl,
      format: ManifestFormat.fromString(sub.format) ?? ManifestFormat.json,
      displayName: sub.displayName,
      pollIntervalSeconds: sub.pollIntervalSeconds,
      isActive: sub.isActive,
      credentialsHostId: sub.credentialsHostId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(sub.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(sub.updatedAt, isUtc: true),
      lastPolledAt: state?.lastPolledAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(state!.lastPolledAt!, isUtc: true),
      nextPollAt: state?.nextPollAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(state!.nextPollAt!, isUtc: true),
      lastEtag: state?.lastEtag,
      lastModified: state?.lastModified,
      lastError: state?.lastError,
      lastErrorAt: state?.lastErrorAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(state!.lastErrorAt!, isUtc: true),
    );
  }
}
```

Note: `MediaSubscriptionStateData` is the Drift-generated row class for `MediaSubscriptionState`. Verify the exact class name once the build_runner has run; if Drift named it `MediaSubscriptionStateRow` instead, swap. Quick check: `grep -n "class MediaSubscriptionStateData\|class MediaSubscriptionStateRow" lib/core/database/database.g.dart`.

- [ ] **Step 4: Run to verify the tests pass**

```bash
flutter test test/features/media/data/repositories/manifest_subscription_repository_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/repositories/manifest_subscription_repository.dart \
            test/features/media/data/repositories/manifest_subscription_repository_test.dart
git add lib/features/media/data/repositories/manifest_subscription_repository.dart \
        test/features/media/data/repositories/manifest_subscription_repository_test.dart
git commit -m "feat(media): add ManifestSubscriptionRepository for synced + per-device state"
```

---

## Task 9: `ManifestEntryResolver` + Registry Wiring

**Files:**
- Create: `lib/features/media/data/resolvers/manifest_entry_resolver.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart`
- Test: `test/features/media/data/resolvers/manifest_entry_resolver_test.dart`

The resolver for `MediaSourceType.manifestEntry`. Conceptually, manifest entries are HTTP URLs — so this resolver delegates byte fetch to 3a's `NetworkUrlResolver`. The only piece that's manifest-specific: when reading metadata, prefer manifest-supplied fields (already on the `MediaItem`) and only call EXIF-over-HTTP for blanks. The 3a resolver already does that — the `manifestEntry` resolver simply forwards.

For 3b purposes, this resolver is a thin wrapper that returns `MediaSourceType.manifestEntry`. The pipeline (Task 10) reads `MediaItem` fields directly to decide whether to skip EXIF.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/manifest_entry_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/manifest_entry_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  test('reports MediaSourceType.manifestEntry', () {
    final r = ManifestEntryResolver(networkUrlResolver: _NoopNetworkUrlResolver());
    expect(r.sourceType, MediaSourceType.manifestEntry);
  });
}

class _NoopNetworkUrlResolver implements NetworkUrlResolverFacade {
  @override
  Future<dynamic> noSuchMethod(Invocation _) => Future.value();
}
```

- [ ] **Step 2: Implement the resolver and the facade interface**

Create `lib/features/media/data/resolvers/manifest_entry_resolver.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Minimal facade so 3b doesn't import 3a's concrete class. The provider
/// in `media_resolver_providers.dart` adapts 3a's `NetworkUrlResolver`
/// to this interface.
abstract class NetworkUrlResolverFacade {
  Future<MediaSourceData> resolveBytes(domain.MediaItem item);
  Future<MediaSourceData> resolveThumbnail(domain.MediaItem item, {int? maxWidth});
  Future<MediaSourceMetadata?> extractMetadata(domain.MediaItem item);
  Future<VerifyResult> verify(domain.MediaItem item);
}

/// Resolver for [MediaSourceType.manifestEntry] items.
///
/// Manifest entries are just HTTP URLs that arrived via a feed, so this
/// resolver delegates everything to the underlying [NetworkUrlResolverFacade]
/// (3a's `NetworkUrlResolver`). The only difference between a `networkUrl`
/// item and a `manifestEntry` item is provenance — and the eager fetch
/// pipeline reads that distinction directly off the `MediaItem`.
class ManifestEntryResolver implements MediaSourceResolver {
  ManifestEntryResolver({required this.networkUrlResolver});

  final NetworkUrlResolverFacade networkUrlResolver;

  @override
  MediaSourceType get sourceType => MediaSourceType.manifestEntry;

  @override
  Future<MediaSourceData> resolveBytes(domain.MediaItem item) =>
      networkUrlResolver.resolveBytes(item);

  @override
  Future<MediaSourceData> resolveThumbnail(
    domain.MediaItem item, {
    int? maxWidth,
  }) => networkUrlResolver.resolveThumbnail(item, maxWidth: maxWidth);

  @override
  Future<MediaSourceMetadata?> extractMetadata(domain.MediaItem item) =>
      networkUrlResolver.extractMetadata(item);

  @override
  Future<VerifyResult> verify(domain.MediaItem item) =>
      networkUrlResolver.verify(item);
}
```

- [ ] **Step 3: Wire the resolver into the registry**

Modify `lib/features/media/presentation/providers/media_resolver_providers.dart`. Add imports and a new provider, and extend the registry map:

```dart
import 'package:submersion/features/media/data/resolvers/manifest_entry_resolver.dart';
// (3a will already have added the NetworkUrlResolver provider; reference it
// here.)

/// Singleton [ManifestEntryResolver] (Phase 3b).
final manifestEntryResolverProvider = Provider<ManifestEntryResolver>(
  (ref) => ManifestEntryResolver(
    // 3a exposes `networkUrlResolverProvider`; adapt to the facade.
    networkUrlResolver: ref.watch(networkUrlResolverProvider)
        as NetworkUrlResolverFacade,
  ),
);
```

Add to the existing registry map:

```dart
final mediaSourceResolverRegistryProvider =
    Provider<MediaSourceResolverRegistry>((ref) {
      return MediaSourceResolverRegistry({
        MediaSourceType.platformGallery: ref.watch(
          platformGalleryResolverProvider,
        ),
        MediaSourceType.signature: ref.watch(signatureResolverProvider),
        MediaSourceType.localFile: ref.watch(localFileResolverProvider),
        MediaSourceType.networkUrl: ref.watch(networkUrlResolverProvider),
        MediaSourceType.manifestEntry: ref.watch(manifestEntryResolverProvider),
      });
    });
```

If 3a's `NetworkUrlResolver` does not yet implement `NetworkUrlResolverFacade`, add `implements NetworkUrlResolverFacade` to its class declaration (it already exposes the matching method signatures). If 3a uses different method names, update `NetworkUrlResolverFacade` accordingly during execution.

- [ ] **Step 4: Run the test**

```bash
flutter test test/features/media/data/resolvers/manifest_entry_resolver_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/resolvers/manifest_entry_resolver.dart \
            lib/features/media/presentation/providers/media_resolver_providers.dart \
            test/features/media/data/resolvers/manifest_entry_resolver_test.dart
git add lib/features/media/data/resolvers/manifest_entry_resolver.dart \
        lib/features/media/presentation/providers/media_resolver_providers.dart \
        test/features/media/data/resolvers/manifest_entry_resolver_test.dart
git commit -m "feat(media): register ManifestEntryResolver in the resolver registry"
```

---

## Task 10: Extend `network_fetch_pipeline.dart` for `manifestEntry` Source Type

**Files:**
- Modify: `lib/features/media/data/services/network_fetch_pipeline.dart` (created in Phase 3a)
- Test: `test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart`

3a's pipeline already inserts a `MediaItem` row, runs metadata extraction in the background, and updates the row + `lastVerifiedAt`. 3b adds two behaviors:

1. **Source-type plumbing** — the pipeline accepts both `MediaSourceType.networkUrl` and `MediaSourceType.manifestEntry` items.
2. **Skip-EXIF when manifest-supplied** — if the item already has `takenAt`, `width`, `height`, and either both `latitude`/`longitude` or both nullable (i.e. no manifest GPS), don't issue the range-GET. Just hit `cached_network_image` for the thumbnail prefetch and write `lastVerifiedAt = now`.

Add a public method `enqueueManifestEntries(List<MediaItem> items)` that fans out to the same internal queue as `enqueueNetworkUrls`. Tests cover the skip-EXIF branch.

- [ ] **Step 1: Read the 3a pipeline file to confirm method names**

```bash
grep -n "class NetworkFetchPipeline\|enqueueNetworkUrls\|extractMetadata\|sourceType" lib/features/media/data/services/network_fetch_pipeline.dart
```

If 3a chose different names ("`addNetworkUrls`", `enqueueAll`, etc.), substitute consistently in this task. Plan assumes:

- Class: `NetworkFetchPipeline`
- Existing method: `enqueueNetworkUrls(List<MediaItem> items)` — synchronous insert + queue
- Internal worker: pulls one item at a time, calls `extractMetadata`, updates row.

- [ ] **Step 2: Write the failing test**

Create `test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  test(
    'enqueueManifestEntries skips EXIF when item already has takenAt+width+height',
    () async {
      final calls = <String>[];
      final pipeline = NetworkFetchPipeline.forTest(
        onExtractMetadata: (item) {
          calls.add('extract:${item.id}');
          return Future.value(null);
        },
        onPrefetchThumbnail: (item) {
          calls.add('thumb:${item.id}');
          return Future.value();
        },
        onMarkVerified: (item, ts) async {
          calls.add('verified:${item.id}:${ts.toIso8601String()}');
        },
      );
      final manifestPrefilled = MediaItem(
        id: 'a',
        mediaType: MediaType.photo,
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
        width: 4032,
        height: 3024,
        sourceType: MediaSourceType.manifestEntry,
        url: 'https://x/a.jpg',
        subscriptionId: 's',
        entryKey: 'k',
        createdAt: DateTime.utc(2024, 4, 12),
        updatedAt: DateTime.utc(2024, 4, 12),
      );
      await pipeline.enqueueManifestEntries([manifestPrefilled]);
      await pipeline.flushForTest();
      expect(calls, contains('thumb:a'));
      expect(calls, contains(startsWith('verified:a:')));
      expect(calls.any((c) => c.startsWith('extract:')), isFalse);
    },
  );

  test(
    'enqueueManifestEntries calls EXIF when item is missing width/height',
    () async {
      final calls = <String>[];
      final pipeline = NetworkFetchPipeline.forTest(
        onExtractMetadata: (item) {
          calls.add('extract:${item.id}');
          return Future.value(null);
        },
        onPrefetchThumbnail: (_) async {},
        onMarkVerified: (item, ts) async {},
      );
      final partial = MediaItem(
        id: 'b',
        mediaType: MediaType.photo,
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
        // no width/height
        sourceType: MediaSourceType.manifestEntry,
        url: 'https://x/b.jpg',
        subscriptionId: 's',
        entryKey: 'k2',
        createdAt: DateTime.utc(2024, 4, 12),
        updatedAt: DateTime.utc(2024, 4, 12),
      );
      await pipeline.enqueueManifestEntries([partial]);
      await pipeline.flushForTest();
      expect(calls, contains('extract:b'));
    },
  );
}
```

- [ ] **Step 3: Implement the new method in the pipeline**

Open `lib/features/media/data/services/network_fetch_pipeline.dart`. Add at the public surface:

```dart
/// Enqueue manifest-entry items into the same pipeline as network URLs.
/// Difference: items with manifest-supplied [takenAt], [width], [height]
/// skip the metadata extraction step (no range-GET needed). Thumbnail
/// prefetch and lastVerifiedAt update still happen.
Future<void> enqueueManifestEntries(List<MediaItem> items) async {
  for (final item in items) {
    if (_isFullyPrefilled(item)) {
      _queue.add(_PipelineJob(
        item: item,
        skipMetadataExtraction: true,
      ));
    } else {
      _queue.add(_PipelineJob(
        item: item,
        skipMetadataExtraction: false,
      ));
    }
  }
  _kickWorker();
}

bool _isFullyPrefilled(MediaItem item) {
  return item.takenAt.year > 1971 // sentinel: real timestamp present
      && item.width != null
      && item.height != null;
}
```

In the existing worker function, branch:

```dart
if (job.skipMetadataExtraction) {
  await _prefetchThumbnail(job.item);
  await _markVerified(job.item, DateTime.now().toUtc());
} else {
  // existing path: extract → update row → prefetch → mark verified
}
```

If 3a's `_PipelineJob` doesn't have a `skipMetadataExtraction` field, add one (default `false` to keep 3a's behavior).

- [ ] **Step 4: Add a test seam**

Add `NetworkFetchPipeline.forTest({...})` factory + `flushForTest()` at the bottom of the file:

```dart
@visibleForTesting
NetworkFetchPipeline.forTest({
  required Future<MediaSourceMetadata?> Function(MediaItem) onExtractMetadata,
  required Future<void> Function(MediaItem) onPrefetchThumbnail,
  required Future<void> Function(MediaItem, DateTime) onMarkVerified,
})  : _extractMetadata = onExtractMetadata,
      _prefetchThumbnail = onPrefetchThumbnail,
      _markVerified = onMarkVerified;

@visibleForTesting
Future<void> flushForTest() async {
  while (_queue.isNotEmpty) {
    await _processNext();
  }
}
```

If 3a already has equivalent test seams (`forTest`, `drain`), reuse them and skip the additions; just ensure the `skipMetadataExtraction` branch is reachable from a test.

- [ ] **Step 5: Run the new test**

```bash
flutter test test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/services/network_fetch_pipeline.dart \
            test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart
git add lib/features/media/data/services/network_fetch_pipeline.dart \
        test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart
git commit -m "feat(media): extend network fetch pipeline for manifestEntry items"
```

---

## Task 11: `SubscriptionPoller` — Single-Pass Cycle (Diff + Insert + Patch + Orphan)

**Files:**
- Create: `lib/features/media/data/services/subscription_poller.dart`
- Test: `test/features/media/data/services/subscription_poller_test.dart`

The single-cycle method `pollAllDue(now)` is the heart of the poller. App-launch + periodic + Poll-now scheduling lives in Task 12. Each cycle:

1. `repo.listActiveDue(now)` → list of due subscriptions.
2. For each, error-isolated try/catch:
   - `manifestFetchService.fetch(url, ifNoneMatch: lastEtag, ifModifiedSince: lastModified)`.
   - On `NotModified`: `repo.recordPollNotModified(...)`.
   - On `Failure`: `repo.recordPollFailure(...)`.
   - On `Success`:
     - Look up existing rows: `mediaRepo.getAllBySubscription(subscriptionId)` → `Map<entryKey, MediaItem>`.
     - **New entries** (not in DB): build `MediaItem` rows with `sourceType=manifestEntry` + manifest-supplied fields → `mediaRepo.createMedia(...)` then `pipeline.enqueueManifestEntries(...)`.
     - **Removed entries** (in DB but not in fetched manifest): `mediaRepo.markOrphaned(itemId, true)`.
     - **Changed entries** (same `entryKey`, different fields): `mediaRepo.updateMedia(...)`.
     - `repo.recordPollSuccess(...)`.

`mediaRepo.getAllBySubscription`, `markOrphaned`, and `updateMedia` are pre-existing on `MediaRepository`. Verify `markOrphaned` exists (else add a thin wrapper for `update(media)..where((t) => t.id.equals(id))..write(MediaCompanion(isOrphaned: Value(true)))`).

- [ ] **Step 1: Verify the MediaRepository surface**

```bash
grep -n "getAllBySubscription\|markOrphaned\|getAllBySourceType" lib/features/media/data/repositories/media_repository.dart
```

If `getAllBySubscription` is missing, add the helper as part of this task (one Drift query, ~10 lines). Same for `markOrphaned`. Otherwise reuse.

- [ ] **Step 2: Write the failing test**

Create `test/features/media/data/services/subscription_poller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';

class _StaticFetcher extends ManifestFetchService {
  _StaticFetcher(this._outcomes)
      : super(
          client: _ThrowingClient(),
          credentials: _NoopCreds(),
        );
  final Map<String, ManifestFetchOutcome> _outcomes;
  @override
  Future<ManifestFetchOutcome> fetch(Uri url, {/* same params */}) async =>
      _outcomes[url.toString()] ?? ManifestFetchFailure(message: 'no fixture');
}

// Test fixtures + a fake repo + a fake media repo + a fake pipeline are
// declared here. (Refer to existing patterns in
// `test/features/media/data/services/trip_media_scanner_test.dart` for
// fake-repo style.)

void main() {
  // Test 1: success path inserts new entries, calls pipeline, records success.
  // Test 2: 304 path calls recordPollNotModified only.
  // Test 3: failure path calls recordPollFailure with error message.
  // Test 4: per-subscription error isolation — sub A throws, sub B still polls.
  // Test 5: removed-entry path marks orphaned.
  // Test 6: changed-entry path patches the existing row.

  test('success: new entries are inserted and queued in pipeline', () async {
    // ... full body of Test 1 here ...
  });

  // ... five additional tests in same shape ...
}
```

(The full test bodies above are intentionally outlined rather than written end-to-end — at this size they would dwarf the rest of the plan. **The implementing engineer must write all six tests with full bodies before implementing.** Use `trip_media_scanner_test.dart` as a fake-collaborator template, and mirror the assertion pattern from Task 8 (count + spot-check). Each test ~40 lines.)

- [ ] **Step 3: Implement `SubscriptionPoller.pollAllDue`**

Create `lib/features/media/data/services/subscription_poller.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class SubscriptionPoller {
  SubscriptionPoller({
    required this.subscriptions,
    required this.mediaRepo,
    required this.fetchService,
    required this.pipeline,
  });

  final ManifestSubscriptionRepository subscriptions;
  final MediaRepository mediaRepo;
  final ManifestFetchService fetchService;
  final NetworkFetchPipeline pipeline;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SubscriptionPoller);

  /// Run one polling cycle. Returns the number of subscriptions visited
  /// (success + 304 + failure all counted).
  Future<int> pollAllDue(DateTime now) async {
    final due = await subscriptions.listActiveDue(now);
    for (final sub in due) {
      try {
        await _pollOne(sub, now);
      } catch (e, st) {
        _log.error(
          'Subscription poll failed (continuing): ${sub.id}',
          error: e, stackTrace: st,
        );
        try {
          await subscriptions.recordPollFailure(
            sub.id,
            pollIntervalSeconds: sub.pollIntervalSeconds,
            error: '$e',
            now: now,
          );
        } catch (_) {/* swallow — already in error path */}
      }
    }
    return due.length;
  }

  Future<void> _pollOne(ManifestSubscription sub, DateTime now) async {
    final outcome = await fetchService.fetch(
      Uri.parse(sub.manifestUrl),
      ifNoneMatch: sub.lastEtag,
      ifModifiedSince: sub.lastModified,
      formatOverride: sub.format,
    );
    switch (outcome) {
      case ManifestFetchNotModified():
        await subscriptions.recordPollNotModified(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          now: now,
        );
      case ManifestFetchFailure():
        await subscriptions.recordPollFailure(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          error: outcome.message,
          now: now,
        );
      case ManifestFetchSuccess():
        await _applyDiff(sub, outcome.parsed, now);
        await subscriptions.recordPollSuccess(
          sub.id,
          pollIntervalSeconds: sub.pollIntervalSeconds,
          etag: outcome.etag,
          lastModified: outcome.lastModified,
          now: now,
        );
    }
  }

  Future<void> _applyDiff(
    ManifestSubscription sub,
    ManifestParseResult parsed,
    DateTime now,
  ) async {
    final existing = await mediaRepo.getAllBySubscription(sub.id);
    final byKey = {for (final m in existing) m.entryKey ?? '': m};
    final fetchedKeys = parsed.entries.map((e) => e.entryKey).toSet();

    final newItems = <MediaItem>[];
    for (final entry in parsed.entries) {
      final existingRow = byKey[entry.entryKey];
      if (existingRow == null) {
        final item = _entryToMediaItem(sub, entry, now);
        await mediaRepo.createMedia(item);
        newItems.add(item);
      } else {
        // Patch any changed fields.
        final patched = existingRow.copyWith(
          url: entry.url,
          takenAt: entry.takenAt ?? existingRow.takenAt,
          caption: entry.caption ?? existingRow.caption,
          latitude: entry.latitude ?? existingRow.latitude,
          longitude: entry.longitude ?? existingRow.longitude,
          width: entry.width ?? existingRow.width,
          height: entry.height ?? existingRow.height,
          durationSeconds: entry.durationSeconds ?? existingRow.durationSeconds,
        );
        if (patched != existingRow) {
          await mediaRepo.updateMedia(patched);
        }
      }
    }
    // Removed entries → mark orphaned.
    for (final m in existing) {
      if (!fetchedKeys.contains(m.entryKey)) {
        await mediaRepo.markOrphaned(m.id, true);
      }
    }
    if (newItems.isNotEmpty) {
      await pipeline.enqueueManifestEntries(newItems);
    }
  }

  MediaItem _entryToMediaItem(
    ManifestSubscription sub,
    ManifestEntry entry,
    DateTime now,
  ) {
    return MediaItem(
      id: _uuid.v4(),
      mediaType: entry.mediaType == 'video' ? MediaType.video : MediaType.photo,
      takenAt: entry.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      width: entry.width,
      height: entry.height,
      durationSeconds: entry.durationSeconds,
      caption: entry.caption,
      latitude: entry.latitude,
      longitude: entry.longitude,
      sourceType: MediaSourceType.manifestEntry,
      url: entry.url,
      subscriptionId: sub.id,
      entryKey: entry.entryKey,
      thumbnailPath: entry.thumbnailUrl, // pipeline will replace with cached path
      createdAt: now,
      updatedAt: now,
    );
  }
}
```

If `MediaRepository.getAllBySubscription`, `updateMedia`, or `markOrphaned` is missing, add minimal wrappers (try / `_log.error` / rethrow pattern) before running the test. Each is one Drift query, ~6 lines.

- [ ] **Step 4: Run the test**

```bash
flutter test test/features/media/data/services/subscription_poller_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/subscription_poller.dart \
            test/features/media/data/services/subscription_poller_test.dart \
            lib/features/media/data/repositories/media_repository.dart
git add lib/features/media/data/services/subscription_poller.dart \
        test/features/media/data/services/subscription_poller_test.dart \
        lib/features/media/data/repositories/media_repository.dart
git commit -m "feat(media): add SubscriptionPoller single-pass diff cycle"
```

---

## Task 12: Schedule the Poller (App-Launch Warm-up + Periodic Timer + Poll-Now)

**Files:**
- Create: `lib/features/media/data/services/subscription_poller_scheduler.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart`
- Modify: `lib/main.dart`
- Test: `test/features/media/data/services/subscription_poller_scheduler_test.dart`

The scheduler is a thin wrapper that decides **when** `SubscriptionPoller.pollAllDue` runs:

1. **App-launch warm-up.** `startAfterWarmup()` waits 30 s, then runs one cycle.
2. **Periodic timer.** After the warm-up cycle, schedule a recurring `Timer.periodic(min(pollIntervalSeconds / 4, 1 h), …)` that runs cycles. The interval source is the smallest `pollIntervalSeconds` across active subscriptions, recalculated each cycle.
3. **User-triggered.** `pollNow()` runs a cycle immediately and returns when done.

The 30 s warm-up and the periodic timer are picker-callback-equivalent (background scheduling) and get `// coverage:ignore` with justification. Unit tests cover `pollNow()` and the interval-computation helper.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/subscription_poller_scheduler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/subscription_poller_scheduler.dart';

void main() {
  group('SubscriptionPollerScheduler.computeInterval', () {
    test('returns 1 hour when smallest pollInterval is large', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([86400, 86400 * 7]),
        const Duration(hours: 1),
      );
    });

    test('returns pollInterval / 4 when smaller than 1 hour', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([60 * 60]), // 1 h
        const Duration(minutes: 15),
      );
      expect(
        SubscriptionPollerScheduler.computeInterval([5 * 60]), // 5 m
        const Duration(seconds: 75),
      );
    });

    test('returns 1 hour when no subscriptions exist', () {
      expect(
        SubscriptionPollerScheduler.computeInterval(const []),
        const Duration(hours: 1),
      );
    });

    test('returns 30 s minimum to avoid runaway loops', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([60]), // 1 m -> /4 = 15 s
        const Duration(seconds: 30),
      );
    });
  });

  test('pollNow() awaits the underlying poller', () async {
    var calls = 0;
    final scheduler = SubscriptionPollerScheduler.forTest(
      pollAllDue: (now) async {
        calls++;
        return 0;
      },
      activePollIntervals: () async => const [],
    );
    await scheduler.pollNow();
    expect(calls, 1);
  });
}
```

- [ ] **Step 2: Implement the scheduler**

Create `lib/features/media/data/services/subscription_poller_scheduler.dart`:

```dart
import 'dart:async';

import 'package:meta/meta.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';

class SubscriptionPollerScheduler {
  SubscriptionPollerScheduler({
    required SubscriptionPoller poller,
    required ManifestSubscriptionRepository subscriptions,
  })  : _pollAllDue = poller.pollAllDue,
        _activePollIntervals = (() async {
          final now = DateTime.now().toUtc();
          // listActiveDue returns due-now subs only; for interval computation
          // we want all active subs. Repos add a tiny helper for that.
          final all = await subscriptions.listAllActive();
          return all.map((s) => s.pollIntervalSeconds).toList();
        });

  @visibleForTesting
  SubscriptionPollerScheduler.forTest({
    required Future<int> Function(DateTime now) pollAllDue,
    required Future<List<int>> Function() activePollIntervals,
  })  : _pollAllDue = pollAllDue,
        _activePollIntervals = activePollIntervals;

  final Future<int> Function(DateTime now) _pollAllDue;
  final Future<List<int>> Function() _activePollIntervals;
  final _log = LoggerService.forClass(SubscriptionPollerScheduler);
  Timer? _timer;

  // coverage:ignore-start
  // App-launch warm-up + periodic scheduling are integration concerns;
  // unit-tested via `pollNow()` and `computeInterval()`.
  Future<void> startAfterWarmup({
    Duration warmup = const Duration(seconds: 30),
  }) async {
    Timer(warmup, () async {
      await pollNow();
      await _scheduleNext();
    });
  }

  Future<void> _scheduleNext() async {
    final intervals = await _activePollIntervals();
    final next = computeInterval(intervals);
    _timer?.cancel();
    _timer = Timer(next, () async {
      try {
        await _pollAllDue(DateTime.now().toUtc());
      } catch (e, st) {
        _log.error('Periodic poll cycle failed', error: e, stackTrace: st);
      }
      await _scheduleNext();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
  // coverage:ignore-end

  Future<int> pollNow() async => _pollAllDue(DateTime.now().toUtc());

  /// Smallest of `pollIntervalSeconds / 4` and 1 hour. Lower-bounded at 30 s
  /// to avoid runaway loops on misconfigured feeds.
  static Duration computeInterval(List<int> pollIntervalSeconds) {
    if (pollIntervalSeconds.isEmpty) return const Duration(hours: 1);
    final smallest = pollIntervalSeconds.reduce((a, b) => a < b ? a : b);
    final quarter = Duration(seconds: smallest ~/ 4);
    final result = quarter < const Duration(hours: 1)
        ? quarter
        : const Duration(hours: 1);
    return result < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : result;
  }
}
```

If `ManifestSubscriptionRepository.listAllActive()` is missing (it isn't in Task 8), add it (one Drift query, ~6 lines, follow the same pattern as `listActiveDue` minus the `nextPollAt` clause).

- [ ] **Step 3: Wire providers**

Add to `media_resolver_providers.dart`:

```dart
final manifestFetchServiceProvider = Provider<ManifestFetchService>((ref) {
  // Adapter: 3a's NetworkCredentialsService implements (or is wrapped to
  // implement) the ManifestCredentialsLookup interface.
  return ManifestFetchService(
    client: ref.watch(httpClientProvider), // 3a provider
    credentials: _NetworkCredentialsAdapter(
      ref.watch(networkCredentialsServiceProvider),
    ),
  );
});

final manifestSubscriptionRepositoryProvider =
    Provider<ManifestSubscriptionRepository>(
  (ref) => ManifestSubscriptionRepository(),
);

final subscriptionPollerProvider = Provider<SubscriptionPoller>((ref) {
  return SubscriptionPoller(
    subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
    mediaRepo: ref.watch(mediaRepositoryProvider),
    fetchService: ref.watch(manifestFetchServiceProvider),
    pipeline: ref.watch(networkFetchPipelineProvider), // 3a provider
  );
});

final subscriptionPollerSchedulerProvider =
    Provider<SubscriptionPollerScheduler>((ref) {
  final scheduler = SubscriptionPollerScheduler(
    poller: ref.watch(subscriptionPollerProvider),
    subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
```

The `_NetworkCredentialsAdapter` is a 5-line class that wraps 3a's service and exposes `headersFor(Uri)`. Define it in the same provider file or in a helper file beside `manifest_fetch_service.dart`.

- [ ] **Step 4: Trigger warm-up at app launch**

Modify `lib/main.dart`. Find where the `ProviderContainer` is constructed (or where `runApp(...)` is called) and add a post-frame callback that reads the scheduler provider and starts the warm-up:

```dart
// Inside runApp / main():
WidgetsBinding.instance.addPostFrameCallback((_) {
  // ignore: unused_local_variable
  final container = ProviderScope.containerOf(/* root context */);
  // 30 s warm-up before first poll cycle.
  // coverage:ignore-line — integration-only (real Timer + DB access).
  unawaited(container.read(subscriptionPollerSchedulerProvider).startAfterWarmup());
});
```

If `lib/main.dart` doesn't expose a root `BuildContext` for `ProviderScope.containerOf`, instead create a `ProviderContainer` explicitly (same pattern Phase 2 used). Verify by reading `main.dart` once before editing — the integration shape is small but project-specific.

- [ ] **Step 5: Run the test**

```bash
flutter test test/features/media/data/services/subscription_poller_scheduler_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/services/subscription_poller_scheduler.dart \
            lib/features/media/presentation/providers/media_resolver_providers.dart \
            lib/main.dart \
            test/features/media/data/services/subscription_poller_scheduler_test.dart
git add lib/features/media/data/services/subscription_poller_scheduler.dart \
        lib/features/media/presentation/providers/media_resolver_providers.dart \
        lib/main.dart \
        test/features/media/data/services/subscription_poller_scheduler_test.dart
git commit -m "feat(media): wire subscription poller scheduler with 30s warmup"
```

---

## Task 13: `ManifestModePanel` — URL Field, Fetch, Format Chip, Preview

**Files:**
- Create: `lib/features/media/presentation/providers/manifest_tab_providers.dart`
- Create: `lib/features/media/presentation/widgets/manifest_mode_panel.dart`
- Create: `lib/features/media/presentation/widgets/manifest_preview_pane.dart`
- Test: `test/features/media/presentation/providers/manifest_tab_providers_test.dart`
- Test: `test/features/media/presentation/widgets/manifest_mode_panel_test.dart`

State machine for the Manifest panel:

```
empty
  -> typing url
  -> fetching (after Fetch tap)
    -> showingPreview(success: ManifestParseResult, formatOverride: ManifestFormat?)
    -> error(message)
  -> committing (after Import tap)
    -> idle (after success snackbar)
```

The state is a sealed `ManifestTabState` discriminated union exposed by a `ManifestTabNotifier`. The panel widget renders a different layout per state. The preview pane is a separate widget that takes the parsed result + override callback.

- [ ] **Step 1: Write the failing tests for the notifier**

Create `test/features/media/presentation/providers/manifest_tab_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';

void main() {
  group('ManifestTabNotifier', () {
    test('starts empty', () {
      final c = ProviderContainer(overrides: [
        manifestFetchServiceProvider
            .overrideWithValue(_FakeFetcher.success(empty: true)),
      ]);
      addTearDown(c.dispose);
      expect(c.read(manifestTabProvider), isA<ManifestTabIdle>());
    });

    test('Fetch transitions Idle -> Fetching -> ShowingPreview on success',
        () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final c = ProviderContainer(overrides: [
        manifestFetchServiceProvider.overrideWithValue(fetcher),
      ]);
      addTearDown(c.dispose);
      final notifier = c.read(manifestTabProvider.notifier);
      final future = notifier.fetch('https://example.com/m.json');
      expect(c.read(manifestTabProvider), isA<ManifestTabFetching>());
      await future;
      final state = c.read(manifestTabProvider);
      expect(state, isA<ManifestTabShowingPreview>());
      expect((state as ManifestTabShowingPreview).result.entries, hasLength(1));
    });

    test('Fetch transitions to Error on failure', () async {
      final c = ProviderContainer(overrides: [
        manifestFetchServiceProvider.overrideWithValue(_FakeFetcher.failure()),
      ]);
      addTearDown(c.dispose);
      await c.read(manifestTabProvider.notifier).fetch('https://x/m');
      expect(c.read(manifestTabProvider), isA<ManifestTabError>());
    });

    test('changeFormatOverride re-parses with the new format', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final c = ProviderContainer(overrides: [
        manifestFetchServiceProvider.overrideWithValue(fetcher),
      ]);
      addTearDown(c.dispose);
      final notifier = c.read(manifestTabProvider.notifier);
      await notifier.fetch('https://example.com/m.json');
      await notifier.changeFormatOverride(ManifestFormat.csv);
      expect(fetcher.lastFormatOverride, ManifestFormat.csv);
    });

    test('reset returns to Idle', () async {
      final c = ProviderContainer(overrides: [
        manifestFetchServiceProvider.overrideWithValue(_FakeFetcher.failure()),
      ]);
      addTearDown(c.dispose);
      final notifier = c.read(manifestTabProvider.notifier);
      await notifier.fetch('https://x/m');
      notifier.reset();
      expect(c.read(manifestTabProvider), isA<ManifestTabIdle>());
    });
  });
}

class _FakeFetcher implements ManifestFetchService {
  _FakeFetcher.success({required this.empty});
  _FakeFetcher.failure() : empty = true, _failure = true;
  final bool empty;
  bool _failure = false;
  ManifestFormat? lastFormatOverride;

  @override
  Future<ManifestFetchOutcome> fetch(Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    lastFormatOverride = formatOverride;
    if (_failure) return const ManifestFetchFailure(message: 'boom');
    final entries = empty
        ? <ManifestEntry>[]
        : const [ManifestEntry(entryKey: 'a', url: 'https://x/a.jpg')];
    return ManifestFetchSuccess(
      parsed: ManifestParseResult(
        format: ManifestFormat.json,
        entries: entries,
      ),
    );
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
```

- [ ] **Step 2: Implement state classes + notifier**

Create `lib/features/media/presentation/providers/manifest_tab_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';

sealed class ManifestTabState {
  const ManifestTabState();
}

class ManifestTabIdle extends ManifestTabState {
  const ManifestTabIdle();
}

class ManifestTabFetching extends ManifestTabState {
  final String url;
  const ManifestTabFetching(this.url);
}

class ManifestTabShowingPreview extends ManifestTabState {
  final String url;
  final ManifestParseResult result;
  final ManifestFormat? formatOverride;
  final bool subscribe;
  final int pollIntervalSeconds;
  const ManifestTabShowingPreview({
    required this.url,
    required this.result,
    this.formatOverride,
    this.subscribe = false,
    this.pollIntervalSeconds = 86400,
  });
  ManifestTabShowingPreview copyWith({
    ManifestParseResult? result,
    ManifestFormat? formatOverride,
    bool? subscribe,
    int? pollIntervalSeconds,
  }) => ManifestTabShowingPreview(
        url: url,
        result: result ?? this.result,
        formatOverride: formatOverride ?? this.formatOverride,
        subscribe: subscribe ?? this.subscribe,
        pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      );
}

class ManifestTabError extends ManifestTabState {
  final String url;
  final String message;
  const ManifestTabError({required this.url, required this.message});
}

class ManifestTabCommitting extends ManifestTabState {
  final ManifestTabShowingPreview from;
  const ManifestTabCommitting(this.from);
}

/// Provider holding the current Manifest panel state.
final manifestTabProvider =
    StateNotifierProvider<ManifestTabNotifier, ManifestTabState>(
  (ref) => ManifestTabNotifier(
    fetchService: ref.watch(manifestFetchServiceProvider),
  ),
);

/// Provided by Task 12 — referenced from here for testability via override.
final manifestFetchServiceProvider = Provider<ManifestFetchService>(
  (ref) => throw UnimplementedError(
    'Override in tests; concrete provider lives in media_resolver_providers.dart',
  ),
);

class ManifestTabNotifier extends StateNotifier<ManifestTabState> {
  ManifestTabNotifier({required this.fetchService})
      : super(const ManifestTabIdle());

  final ManifestFetchService fetchService;

  Future<void> fetch(String urlText) async {
    final url = Uri.tryParse(urlText);
    if (url == null) {
      state = ManifestTabError(url: urlText, message: 'Invalid URL');
      return;
    }
    state = ManifestTabFetching(urlText);
    final outcome = await fetchService.fetch(url);
    switch (outcome) {
      case ManifestFetchSuccess():
        state = ManifestTabShowingPreview(
          url: urlText,
          result: outcome.parsed,
        );
      case ManifestFetchNotModified():
        state = ManifestTabError(url: urlText, message: 'Server reports unchanged');
      case ManifestFetchFailure():
        final reason = outcome.unauthorized
            ? 'Unauthorized — sign in via Settings → Network Sources'
            : outcome.message;
        state = ManifestTabError(url: urlText, message: reason);
    }
  }

  Future<void> changeFormatOverride(ManifestFormat? format) async {
    final current = state;
    if (current is! ManifestTabShowingPreview) return;
    state = ManifestTabFetching(current.url);
    final outcome = await fetchService.fetch(
      Uri.parse(current.url),
      formatOverride: format,
    );
    switch (outcome) {
      case ManifestFetchSuccess():
        state = ManifestTabShowingPreview(
          url: current.url,
          result: outcome.parsed,
          formatOverride: format,
          subscribe: current.subscribe,
          pollIntervalSeconds: current.pollIntervalSeconds,
        );
      case ManifestFetchFailure():
        state = ManifestTabError(url: current.url, message: outcome.message);
      case ManifestFetchNotModified():
        // Re-show old preview with the new override marker.
        state = current.copyWith(formatOverride: format);
    }
  }

  void setSubscribe(bool subscribe) {
    final s = state;
    if (s is ManifestTabShowingPreview) state = s.copyWith(subscribe: subscribe);
  }

  void setPollInterval(int seconds) {
    final s = state;
    if (s is ManifestTabShowingPreview) {
      state = s.copyWith(pollIntervalSeconds: seconds);
    }
  }

  void reset() => state = const ManifestTabIdle();
}
```

- [ ] **Step 3: Run notifier tests**

```bash
flutter test test/features/media/presentation/providers/manifest_tab_providers_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 4: Implement `ManifestPreviewPane`**

Create `lib/features/media/presentation/widgets/manifest_preview_pane.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Read-only preview of a parsed manifest. Shows detected format chip
/// (with override dropdown), entry count, and the first 5 entries with
/// their `entryKey`, `url`, `takenAt`, and `caption`.
class ManifestPreviewPane extends StatelessWidget {
  const ManifestPreviewPane({
    super.key,
    required this.result,
    required this.formatOverride,
    required this.onFormatOverrideChanged,
  });

  final ManifestParseResult result;
  final ManifestFormat? formatOverride;
  final ValueChanged<ManifestFormat?> onFormatOverrideChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = result.entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Format:', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            DropdownButton<ManifestFormat>(
              value: formatOverride ?? result.format,
              onChanged: onFormatOverrideChanged,
              items: ManifestFormat.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.displayName),
                      ))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${result.entries.length} entries detected',
          style: theme.textTheme.bodyMedium,
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${result.warnings.length} skipped',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final e in preview)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.caption ?? e.entryKey,
                    style: theme.textTheme.bodyMedium),
                Text(e.url,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (e.takenAt != null)
                  Text(e.takenAt!.toIso8601String(),
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Implement `ManifestModePanel` (Fetch + Preview only — Import added in Task 14)**

Create `lib/features/media/presentation/widgets/manifest_mode_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_preview_pane.dart';

class ManifestModePanel extends ConsumerStatefulWidget {
  const ManifestModePanel({super.key});

  @override
  ConsumerState<ManifestModePanel> createState() => _ManifestModePanelState();
}

class _ManifestModePanelState extends ConsumerState<ManifestModePanel> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final notifier = ref.read(manifestTabProvider.notifier);
    await notifier.fetch(_urlController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manifestTabProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Manifest URL',
              hintText: 'https://example.com/manifest.json',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: const Text('Fetch'),
            onPressed: state is ManifestTabFetching ? null : _fetch,
          ),
          const SizedBox(height: 16),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _body(ManifestTabState state) {
    switch (state) {
      case ManifestTabIdle():
        return const Text('Paste a manifest URL to begin.');
      case ManifestTabFetching():
        return const Center(child: CircularProgressIndicator());
      case ManifestTabError():
        return Text('Fetch failed: ${state.message}',
            style: TextStyle(color: Theme.of(context).colorScheme.error));
      case ManifestTabShowingPreview():
        return SingleChildScrollView(
          child: ManifestPreviewPane(
            result: state.result,
            formatOverride: state.formatOverride,
            onFormatOverrideChanged: (f) {
              ref
                  .read(manifestTabProvider.notifier)
                  .changeFormatOverride(f);
            },
          ),
        );
      case ManifestTabCommitting():
        return const Center(child: CircularProgressIndicator());
    }
  }
}
```

- [ ] **Step 6: Smoke widget test**

Create `test/features/media/presentation/widgets/manifest_mode_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_mode_panel.dart';

class _StubFetcher implements ManifestFetchService {
  @override
  Future<ManifestFetchOutcome> fetch(Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async => ManifestFetchSuccess(
        parsed: ManifestParseResult(
          format: ManifestFormat.json,
          entries: const [],
        ),
      );
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('renders URL field, Fetch button, and idle hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(_StubFetcher()),
        ],
        child: const MaterialApp(home: Scaffold(body: ManifestModePanel())),
      ),
    );
    expect(find.text('Manifest URL'), findsOneWidget);
    expect(find.text('Fetch'), findsOneWidget);
    expect(find.text('Paste a manifest URL to begin.'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run tests and commit**

```bash
flutter test test/features/media/presentation/widgets/manifest_mode_panel_test.dart \
             test/features/media/presentation/providers/manifest_tab_providers_test.dart
dart format lib/features/media/presentation/providers/manifest_tab_providers.dart \
            lib/features/media/presentation/widgets/manifest_mode_panel.dart \
            lib/features/media/presentation/widgets/manifest_preview_pane.dart \
            test/features/media/presentation/widgets/manifest_mode_panel_test.dart \
            test/features/media/presentation/providers/manifest_tab_providers_test.dart
git add lib/features/media/presentation/providers/manifest_tab_providers.dart \
        lib/features/media/presentation/widgets/manifest_mode_panel.dart \
        lib/features/media/presentation/widgets/manifest_preview_pane.dart \
        test/features/media/presentation/widgets/manifest_mode_panel_test.dart \
        test/features/media/presentation/providers/manifest_tab_providers_test.dart
git commit -m "feat(media): add ManifestModePanel with fetch + preview UI"
```

Expected: PASS.

---

## Task 14: Subscription Toggle, Poll-Interval Picker, Import Commit, Wire Into URL Tab

**Files:**
- Modify: `lib/features/media/presentation/widgets/manifest_mode_panel.dart`
- Modify: `lib/features/media/presentation/providers/manifest_tab_providers.dart` (add `commit()` method)
- Modify: `lib/features/media/presentation/widgets/url_tab.dart` (3a created with placeholder Manifest panel — replace it)
- Test: extend `test/features/media/presentation/providers/manifest_tab_providers_test.dart`

The Import flow:

- If "Subscribe" is off: skip subscription creation, build one `MediaItem` per entry, pass to the pipeline (eager fetch). Same shape as 3a's URL bulk import — no subscription_id.
- If "Subscribe" is on: create a `ManifestSubscription` row first, then build `MediaItem` rows with `subscriptionId` populated, then pipeline. The first poll cycle will not detect anything new because we just inserted everything.

Poll-interval picker: dropdown with [`1 hour`, `6 hours`, `24 hours` (default), `7 days`]. Visible only when Subscribe is on.

- [ ] **Step 1: Add `commit()` to the notifier**

Edit `lib/features/media/presentation/providers/manifest_tab_providers.dart`. Add to `ManifestTabNotifier`:

```dart
Future<void> commit({
  required Future<void> Function(ManifestTabShowingPreview) onCommit,
}) async {
  final s = state;
  if (s is! ManifestTabShowingPreview) return;
  state = ManifestTabCommitting(s);
  try {
    await onCommit(s);
    state = const ManifestTabIdle();
  } catch (e) {
    state = ManifestTabError(url: s.url, message: '$e');
  }
}
```

The `onCommit` callback is provided by the panel widget so testing can swap a fake without coupling the notifier to concrete repos.

- [ ] **Step 2: Add tests for the commit flow**

Append to `manifest_tab_providers_test.dart`:

```dart
test('commit transitions ShowingPreview -> Committing -> Idle on success',
    () async {
  final c = ProviderContainer(overrides: [
    manifestFetchServiceProvider
        .overrideWithValue(_FakeFetcher.success(empty: false)),
  ]);
  addTearDown(c.dispose);
  final notifier = c.read(manifestTabProvider.notifier);
  await notifier.fetch('https://x/m.json');
  var saw = false;
  await notifier.commit(onCommit: (preview) async {
    saw = true;
    expect(preview.result.entries, hasLength(1));
  });
  expect(saw, isTrue);
  expect(c.read(manifestTabProvider), isA<ManifestTabIdle>());
});

test('commit transitions to Error on failure', () async {
  final c = ProviderContainer(overrides: [
    manifestFetchServiceProvider
        .overrideWithValue(_FakeFetcher.success(empty: false)),
  ]);
  addTearDown(c.dispose);
  final notifier = c.read(manifestTabProvider.notifier);
  await notifier.fetch('https://x/m.json');
  await notifier.commit(onCommit: (_) async => throw 'kaboom');
  expect(c.read(manifestTabProvider), isA<ManifestTabError>());
});
```

- [ ] **Step 3: Implement subscription toggle + interval dropdown + Import button**

In `manifest_mode_panel.dart`'s `ManifestPreviewPane` body, append (extend the panel widget — not the preview pane — so it can `ref.watch` state):

```dart
// In _ManifestModePanelState._body for the ShowingPreview case:
case ManifestTabShowingPreview():
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManifestPreviewPane(
          result: state.result,
          formatOverride: state.formatOverride,
          onFormatOverrideChanged: (f) =>
              ref.read(manifestTabProvider.notifier).changeFormatOverride(f),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Subscribe to updates (poll for new entries)'),
          subtitle: const Text('Default: off'),
          value: state.subscribe,
          onChanged: (v) =>
              ref.read(manifestTabProvider.notifier).setSubscribe(v),
        ),
        if (state.subscribe)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Row(
              children: [
                const Text('Poll every'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: state.pollIntervalSeconds,
                  items: const [
                    DropdownMenuItem(value: 3600, child: Text('1 hour')),
                    DropdownMenuItem(value: 6 * 3600, child: Text('6 hours')),
                    DropdownMenuItem(value: 24 * 3600, child: Text('24 hours')),
                    DropdownMenuItem(value: 7 * 24 * 3600, child: Text('7 days')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(manifestTabProvider.notifier).setPollInterval(v);
                    }
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.cloud_upload),
          label: Text('Import ${state.result.entries.length} entries'),
          onPressed: state.result.entries.isEmpty ? null : _commit,
        ),
      ],
    ),
  );
```

Add the `_commit` method on `_ManifestModePanelState`:

```dart
Future<void> _commit() async {
  await ref.read(manifestTabProvider.notifier).commit(
    onCommit: (preview) async {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final pipeline = ref.read(networkFetchPipelineProvider);
      String? subscriptionId;
      if (preview.subscribe) {
        final created =
            await ref.read(manifestSubscriptionRepositoryProvider).createSubscription(
          manifestUrl: preview.url,
          format: preview.formatOverride ?? preview.result.format,
          pollIntervalSeconds: preview.pollIntervalSeconds,
        );
        subscriptionId = created.id;
      }
      final now = DateTime.now().toUtc();
      final items = <MediaItem>[];
      for (final e in preview.result.entries) {
        final item = MediaItem(
          id: '', // repo will assign
          mediaType: e.mediaType == 'video' ? MediaType.video : MediaType.photo,
          takenAt: e.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          width: e.width,
          height: e.height,
          durationSeconds: e.durationSeconds,
          caption: e.caption,
          latitude: e.latitude,
          longitude: e.longitude,
          sourceType: subscriptionId != null
              ? MediaSourceType.manifestEntry
              : MediaSourceType.networkUrl,
          url: e.url,
          subscriptionId: subscriptionId,
          entryKey: subscriptionId != null ? e.entryKey : null,
          thumbnailPath: e.thumbnailUrl,
          createdAt: now,
          updatedAt: now,
        );
        final created = await mediaRepo.createMedia(item);
        items.add(created);
      }
      await pipeline.enqueueManifestEntries(items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${items.length} entries')),
      );
    },
  );
}
```

Add the imports needed by this method (`media_item.dart`, `media_source_type.dart`, repo + pipeline + subscription providers).

- [ ] **Step 4: Wire `ManifestModePanel` into `url_tab.dart`**

3a's `url_tab.dart` has a segmented control with two cases. Replace its Manifest case `_PlaceholderManifestPanel()` (or whatever 3a named it) with `const ManifestModePanel()`. Add the import.

If 3a's `url_tab.dart` doesn't yet exist, this task degrades to: leave the panel rendering at the top of the URL tab body; 3a will pick it up when it lands.

- [ ] **Step 5: Run all tests in the manifest namespace**

```bash
flutter test test/features/media/data/parsers/ \
             test/features/media/data/repositories/manifest_subscription_repository_test.dart \
             test/features/media/data/services/manifest_fetch_service_test.dart \
             test/features/media/data/services/subscription_poller_test.dart \
             test/features/media/data/services/subscription_poller_scheduler_test.dart \
             test/features/media/data/services/network_fetch_pipeline_manifest_entry_test.dart \
             test/features/media/data/resolvers/manifest_entry_resolver_test.dart \
             test/features/media/presentation/providers/manifest_tab_providers_test.dart \
             test/features/media/presentation/widgets/manifest_mode_panel_test.dart
```

Expected: all PASS.

- [ ] **Step 6: Final commit**

```bash
dart format lib/features/media/presentation/widgets/manifest_mode_panel.dart \
            lib/features/media/presentation/providers/manifest_tab_providers.dart \
            lib/features/media/presentation/widgets/url_tab.dart \
            test/features/media/presentation/providers/manifest_tab_providers_test.dart
git add lib/features/media/presentation/widgets/manifest_mode_panel.dart \
        lib/features/media/presentation/providers/manifest_tab_providers.dart \
        lib/features/media/presentation/widgets/url_tab.dart \
        test/features/media/presentation/providers/manifest_tab_providers_test.dart
git commit -m "feat(media): wire Subscribe toggle, poll-interval picker, and Import commit"
```

---

## Acceptance Sweep

After all 14 tasks land, run the full media test suite:

```bash
flutter analyze
flutter test test/features/media/
```

Expected: all green.

Manual smoke test (best done on macOS; iOS / Android flows are identical apart from picker visuals):

1. Settings → Diagnostics → enable hidden picker tabs (`mediaPickerHiddenTabsProvider`).
2. Open any dive → Add photo → switch to URL tab → Manifest mode.
3. Paste a small JSON manifest URL hosted on a public test server. Tap Fetch. Verify entry count and first 5 entries appear within ~1 s for small feeds.
4. Override format dropdown to CSV; verify the panel shows an error (re-parse fails). Switch back to JSON. Verify preview returns.
5. Toggle Subscribe → verify poll-interval dropdown appears with `24 hours` selected.
6. Tap "Import N entries". Verify a snackbar reports the count.
7. Reopen the dive — the imported photos appear with shimmer placeholders, transitioning to thumbnails as the eager fetch pipeline (3a) completes.
8. Restart the app, wait 30 s. The poller should run a cycle. With the same manifest URL pre-existing, the cycle reports "Not Modified" and writes new `nextPollAt`.
9. Edit the manifest server-side: add a new entry, remove an old one, change a caption. Wait for the next poll. Verify the new entry appears in the dive's media; the removed one is marked orphaned (stays visible but greyed); the changed caption updates.

---

## Self-Review

### 1. Spec coverage

| Spec deliverable | Tasks |
|---|---|
| 1 (Manifest mode UI: URL field, subscribe checkbox default off, fetch, sniff + override, preview, poll-interval, Import) | 13 (URL field + fetch + format chip + preview), 14 (subscribe toggle + interval picker + Import) |
| 4 (Atom/RSS, JSON, CSV parsers returning `List<ManifestEntry>`) | 1 (value type), 3 (JSON), 4 (Atom/RSS), 5 (CSV) |
| 5 (Eager fetch pipeline for manifest entries: skip EXIF when manifest pre-filled metadata) | 9 (resolver), 10 (pipeline extension), 14 (commit feeds the pipeline) |
| 6 (Subscription polling: app-launch warm-up + periodic timer + Poll-now; conditional GET; diff insert/patch/orphan; backoff; cross-device dedup) | 8 (repo), 11 (cycle), 12 (scheduler) |
| Manifest format spec doc | 2 (`docs/superpowers/specs/manifest_json_v1.md`) |

### 2. 3a-vs-3b boundary

- 3b imports 3a's `NetworkUrlResolver` (via `NetworkUrlResolverFacade` adapter), `NetworkCredentialsService` (via `ManifestCredentialsLookup` adapter), and `network_fetch_pipeline.dart` (extends with `enqueueManifestEntries`). All cross-slice references use minimal interfaces so the file/class names can drift slightly between 3a and 3b without breaking 3b.
- 3b does not own: URL list mode, `cached_network_image` integration, the segmented control itself, or the URL bulk-import path.
- 3c (settings + scan) is excluded; the `ManifestSubscriptionRepository` exposes the surface 3c needs (`listAllActive`, `setActive`, `deleteById`, `recordPollFailure`/`Success`/`NotModified` for status display).

### 3. Pubspec additions

**None.** Every package is already in `pubspec.yaml`:

- `xml: ^6.5.0`
- `csv: ^6.0.0`
- `crypto: ^3.0.3`
- `http: ^1.2.2`
- `cached_network_image: ^3.4.1` (3a uses this)
- `equatable`, `riverpod`, `drift`, `uuid` — all already pulled in.

### 4. Type consistency check

- `ManifestEntry` defined in Task 1 is referenced by Tasks 3, 4, 5, 7, 11, 13, 14 — same field names throughout (`entryKey`, `url`, `takenAt`, `caption`, `thumbnailUrl`, `latitude`, `longitude`, `width`, `height`, `durationSeconds`, `mediaType`).
- `ManifestParseResult` defined in Task 1 referenced by every parser + fetch service + UI.
- `ManifestFormat` enum (atom/json/csv) consistent across parsers, sniffer, preview UI, and repo persistence.
- `ManifestFetchOutcome` sealed family (`Success` / `NotModified` / `Failure`) consistent in Tasks 7, 11, 13.
- `ManifestSubscription` domain entity consistent between Task 8 (definition), Task 11 (consumed by poller), Task 12 (consumed by scheduler).
- `MediaSourceType.manifestEntry` enum value is referenced everywhere — already exists in the codebase (verified pre-plan).
- `subscriptionId` and `entryKey` columns/fields on `MediaItem` already exist — verified pre-plan.

### 5. Schema deviations from the spec brief

The spec brief described a single subscription table with combined synced + per-device columns. The actual schema (Phase 1 v72) **splits** into two tables: `MediaSubscriptions` (synced, has `manifestUrl`, `format`, `displayName`, `pollIntervalSeconds`, `isActive`, `credentialsHostId`, timestamps) and `MediaSubscriptionState` (per-device, has `lastPolledAt`, `nextPollAt`, `lastEtag`, `lastModified`, `lastError`, `lastErrorAt`).

The plan reflects the actual schema:

- `ManifestSubscriptionRepository.createSubscription` inserts both rows in a transaction.
- `ManifestSubscription` domain entity is a join projection.
- `recordPollSuccess` / `recordPollNotModified` / `recordPollFailure` write only to `MediaSubscriptionState`.
- `setActive` writes only to `MediaSubscriptions`.

The spec brief's mention of an `autoMatchByDate` column is **not in the schema** — the plan deliberately omits it. If 3c needs that toggle, it would be a v73 migration add. Flagged as a spec deviation.

The unique partial index on `(media.subscription_id, media.entry_key)` exists at `database.dart:3562-3565` — verified before relying on it.
