# Media Library Filter and Sort Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Media Library's overflowing filter chip row with the
app-standard badged filter button plus filter sheet, and add a real sort
control offering date, file name, and file size in both directions.

**Architecture:** Three focused widgets replace `MediaLibraryFilterBar`: a
fixed-width toolbar, a draft-then-Apply bottom sheet, and a removable-chip
strip that only renders when the filter is non-empty. Underneath,
`MediaLibraryRepository.getPage` generalises its keyset pagination from a
hard-coded date key to a per-field sort spec whose SQL expression is always
coalesced to a non-null value.

**Tech Stack:** Flutter, Riverpod (`StateNotifierProvider`, `StateProvider`),
Drift ORM over SQLite, `flutter_test` widget tests, ARB localization.

**Spec:** `docs/superpowers/specs/2026-08-23-media-filter-sort-design.md`

## Global Constraints

- **Worktree:** all work happens in
  `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort`
  on branch `worktree-media-filter-sort`. Use absolute paths under that root
  for every file edit. Never edit the main checkout.
- **No em-dashes.** The character `—` (U+2014) is forbidden in all output:
  code, comments, docs, commit messages. En-dashes as prose punctuation and
  spaced hyphens are equally forbidden. Use commas, colons, semicolons, or
  two sentences.
- **No emojis** in code, comments, or documentation.
- **Formatting:** `dart format .` must produce no changes before any commit.
- **Analysis:** `flutter analyze` must be clean. Infos are fatal in CI.
- **Localization:** every new key goes into all 11 ARB files under
  `lib/l10n/arb/` with a real translation. English stubs in non-English files
  are not acceptable. Only `app_en.arb` carries the `"@key"` description
  objects; the other ten are plain key/value.
- **Hungarian is written without diacritics** in this project (`"Nev"`,
  `"Helyszinek szurese"`). Match that convention.
- **Portuguese is Brazilian** (`"arquivo"`, not `"ficheiro"`).
- **Commit trailers:** no `Co-Authored-By` line, no session URL.
- **TDD:** every task writes the failing test first and runs it to watch it
  fail before writing implementation.

---

### Task 1: Sort field enum, localized names, and the persisted sort provider

Introduces the sort vocabulary and the provider that remembers the user's
choice. Nothing consumes it yet; that is Task 3.

**Files:**
- Modify: `lib/core/constants/sort_options.dart` (append a new enum after `CourseSortField`)
- Modify: `lib/core/constants/sort_options_display.dart` (append a new extension)
- Modify: `lib/l10n/arb/app_en.arb` and the ten sibling locale files
- Create: `lib/features/media/presentation/providers/media_library_sort_provider.dart`
- Test: `test/features/media/presentation/media_library_sort_provider_test.dart`

**Interfaces:**
- Consumes: `SortState<T>` from `lib/core/models/sort_state.dart`,
  `SortDirection` from `lib/core/constants/sort_options.dart`,
  `AppSettingsRepository.getRawSetting` / `setRawSetting`.
- Produces:
  - `enum MediaSortField { dateTaken, fileName, fileSize }`
  - `extension MediaSortFieldDisplay on MediaSortField { String localizedName(AppLocalizations l10n) }`
  - `String encodeMediaSort(SortState<MediaSortField> sort)`
  - `SortState<MediaSortField>? decodeMediaSort(String raw)`
  - `const SortState<MediaSortField> kDefaultMediaSort`
  - `class MediaLibrarySortNotifier extends StateNotifier<SortState<MediaSortField>>`
    with `Future<void> setSort(MediaSortField field, SortDirection direction)`
    and `static const String settingKey = 'media_library_sort'`
  - `final mediaLibrarySortProvider = StateNotifierProvider<MediaLibrarySortNotifier, SortState<MediaSortField>>`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/media_library_sort_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _FakeSettingsRepo settings;

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
  );

  setUp(() => settings = _FakeSettingsRepo());

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  group('encode and decode', () {
    test('round-trips every field and direction', () {
      for (final field in MediaSortField.values) {
        for (final direction in SortDirection.values) {
          final sort = SortState(field: field, direction: direction);
          expect(decodeMediaSort(encodeMediaSort(sort)), sort);
        }
      }
    });

    test('returns null for malformed or unknown values', () {
      // A value written by a newer build, or a corrupted setting, must not
      // throw and take the library down with it.
      expect(decodeMediaSort(''), isNull);
      expect(decodeMediaSort('dateTaken'), isNull);
      expect(decodeMediaSort('dateTaken:sideways'), isNull);
      expect(decodeMediaSort('shutterCount:ascending'), isNull);
      expect(decodeMediaSort('a:b:c'), isNull);
    });
  });

  group('MediaLibrarySortNotifier', () {
    test('starts at date descending before anything is loaded', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      expect(container.read(mediaLibrarySortProvider), kDefaultMediaSort);
      expect(kDefaultMediaSort.field, MediaSortField.dateTaken);
      expect(kDefaultMediaSort.direction, SortDirection.descending);
    });

    test('primes from the persisted setting', () async {
      settings.values[MediaLibrarySortNotifier.settingKey] =
          'fileName:ascending';
      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(mediaLibrarySortProvider);
      await tick();

      expect(
        container.read(mediaLibrarySortProvider),
        const SortState(
          field: MediaSortField.fileName,
          direction: SortDirection.ascending,
        ),
      );
    });

    test('keeps the default when the persisted value is unreadable', () async {
      settings.values[MediaLibrarySortNotifier.settingKey] = 'garbage';
      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(mediaLibrarySortProvider);
      await tick();

      expect(container.read(mediaLibrarySortProvider), kDefaultMediaSort);
    });

    test('setSort updates state and persists it', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(mediaLibrarySortProvider.notifier)
          .setSort(MediaSortField.fileSize, SortDirection.ascending);

      expect(
        container.read(mediaLibrarySortProvider),
        const SortState(
          field: MediaSortField.fileSize,
          direction: SortDirection.ascending,
        ),
      );
      expect(
        settings.values[MediaLibrarySortNotifier.settingKey],
        'fileSize:ascending',
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_sort_provider_test.dart
```

Expected: FAIL to compile, `Error: Couldn't resolve the package
'.../media_library_sort_provider.dart'`.

- [ ] **Step 3: Add the enum**

Append to the end of `lib/core/constants/sort_options.dart`:

```dart
/// Sort fields for library media. `dateTaken` is the historical default and
/// resolves to COALESCE(taken_at, created_at) in the repository.
enum MediaSortField {
  dateTaken('Date Taken', Icons.calendar_today),
  fileName('File Name', Icons.sort_by_alpha),
  fileSize('File Size', Icons.data_usage);

  final String displayName;
  final IconData icon;
  const MediaSortField(this.displayName, this.icon);
}
```

- [ ] **Step 4: Add the localized-name extension**

Append to the end of `lib/core/constants/sort_options_display.dart`:

```dart
extension MediaSortFieldDisplay on MediaSortField {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MediaSortField.dateTaken => l10n.enum_sortField_dateTaken,
    MediaSortField.fileName => l10n.enum_sortField_fileName,
    MediaSortField.fileSize => l10n.enum_sortField_fileSize,
  };
}
```

- [ ] **Step 5: Add the three l10n keys to all 11 ARB files**

In `lib/l10n/arb/app_en.arb`, insert alphabetically among the other
`enum_sortField_*` keys (near line 5789), each with its description object:

```json
  "enum_sortField_dateTaken": "Date Taken",
  "@enum_sortField_dateTaken": {
    "description": "Sort field: the date a photo or video was captured"
  },
  "enum_sortField_fileName": "File Name",
  "@enum_sortField_fileName": {
    "description": "Sort field: the media file's name"
  },
  "enum_sortField_fileSize": "File Size",
  "@enum_sortField_fileSize": {
    "description": "Sort field: the media file's size in bytes"
  },
```

In the other ten files add the plain key/value pairs (no `@` objects):

| File | `enum_sortField_dateTaken` | `enum_sortField_fileName` | `enum_sortField_fileSize` |
| --- | --- | --- | --- |
| `app_de.arb` | `Aufnahmedatum` | `Dateiname` | `Dateigröße` |
| `app_es.arb` | `Fecha de captura` | `Nombre de archivo` | `Tamaño de archivo` |
| `app_fr.arb` | `Date de prise de vue` | `Nom du fichier` | `Taille du fichier` |
| `app_it.arb` | `Data dello scatto` | `Nome file` | `Dimensione file` |
| `app_nl.arb` | `Opnamedatum` | `Bestandsnaam` | `Bestandsgrootte` |
| `app_pt.arb` | `Data da captura` | `Nome do arquivo` | `Tamanho do arquivo` |
| `app_hu.arb` | `Keszites datuma` | `Fajlnev` | `Fajlmeret` |
| `app_zh.arb` | `拍摄日期` | `文件名` | `文件大小` |
| `app_ar.arb` | `تاريخ الالتقاط` | `اسم الملف` | `حجم الملف` |
| `app_he.arb` | `תאריך הצילום` | `שם הקובץ` | `גודל הקובץ` |

- [ ] **Step 6: Regenerate localizations**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter gen-l10n
```

Expected: no output, exit 0. If it reports an untranslated-message warning for
a locale, a key was missed above.

- [ ] **Step 7: Write the provider**

Create `lib/features/media/presentation/providers/media_library_sort_provider.dart`:

```dart
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Newest first, matching the ordering the library shipped with before a
/// sort control existed.
const SortState<MediaSortField> kDefaultMediaSort = SortState(
  field: MediaSortField.dateTaken,
  direction: SortDirection.descending,
);

/// Persisted form: `<field>:<direction>`, both enum names. Names are stable
/// across locales and devices, which is what makes the stored value portable.
String encodeMediaSort(SortState<MediaSortField> sort) =>
    '${sort.field.name}:${sort.direction.name}';

/// Decodes leniently. A value written by a newer build, or a corrupted
/// setting, yields null so the caller can fall back rather than throwing and
/// taking the library view down with it.
SortState<MediaSortField>? decodeMediaSort(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final field = MediaSortField.values
      .where((f) => f.name == parts[0])
      .firstOrNull;
  final direction = SortDirection.values
      .where((d) => d.name == parts[1])
      .firstOrNull;
  if (field == null || direction == null) return null;
  return SortState(field: field, direction: direction);
}

/// The library's active sort, persisted through the app settings key-value
/// store exactly as [MediaLibraryViewModeNotifier] persists the view mode.
///
/// Deliberately NOT part of [MediaLibraryFilter]: sort is a view preference,
/// and folding it into the filter would add a field to every serialized smart
/// album.
final mediaLibrarySortProvider =
    StateNotifierProvider<MediaLibrarySortNotifier, SortState<MediaSortField>>((
      ref,
    ) {
      return MediaLibrarySortNotifier(ref.watch(appSettingsRepositoryProvider));
    });

class MediaLibrarySortNotifier
    extends StateNotifier<SortState<MediaSortField>> {
  MediaLibrarySortNotifier(this._settings) : super(kDefaultMediaSort) {
    logFailure(_prime(), MediaLibrarySortNotifier, 'prime');
  }

  static const String settingKey = 'media_library_sort';

  final AppSettingsRepository _settings;

  Future<void> _prime() async {
    final raw = await _settings.getRawSetting(settingKey);
    if (!mounted || raw == null) return;
    final decoded = decodeMediaSort(raw);
    if (decoded != null) state = decoded;
  }

  Future<void> setSort(MediaSortField field, SortDirection direction) async {
    state = SortState(field: field, direction: direction);
    await _settings.setRawSetting(settingKey, encodeMediaSort(state));
  }
}
```

- [ ] **Step 8: Run the test to verify it passes**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_sort_provider_test.dart
```

Expected: PASS, all 6 tests.

- [ ] **Step 9: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add lib/core/constants/sort_options.dart \
        lib/core/constants/sort_options_display.dart \
        lib/l10n/arb/ \
        lib/features/media/presentation/providers/media_library_sort_provider.dart \
        test/features/media/presentation/media_library_sort_provider_test.dart
git commit -m "feat(media): add library sort field enum and persisted sort provider"
```

---

### Task 2: Generalize the repository's keyset pagination

The heart of the change. `getPage` learns to sort by any of the three fields
in either direction without breaking the keyset cursor.

**Files:**
- Modify: `lib/features/media/domain/entities/media_library_filter.dart` (widen `MediaLibraryCursor.sortKey`)
- Modify: `lib/features/media/data/repositories/media_library_repository.dart:32-160`
- Modify: `lib/core/database/performance_indexes.dart` (three new entries)
- Modify: `test/features/media/presentation/media_library_providers_test.dart` (fake's `getPage` signature)
- Test: `test/features/media/data/media_library_sort_test.dart` (new file)

**Interfaces:**
- Consumes: `MediaSortField`, `SortDirection`, `SortState` from Task 1.
- Produces: `MediaLibraryRepository.getPage({required String? diverId,
  MediaLibraryFilter filter, SortState<MediaSortField> sort, MediaLibraryCursor? after,
  int limit})`, defaulting `sort` to `kDefaultMediaSort`.
  `MediaLibraryCursor({required Object sortKey, required String id})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/media_library_sort_test.dart`. Note the
fixture deliberately contains rows with a null `originalFilename` and rows
with a null `contentSizeBytes`: without them the pagination tests pass
vacuously and the NULL-keyset defect ships.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late MediaLibraryRepository repo;

  Future<void> insertMedia(
    String id,
    DateTime takenAt, {
    String? originalFilename,
    int? contentSizeBytes,
  }) => mediaRepo.createMedia(
    MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: '/tmp/$id',
      localPath: '/tmp/$id',
      originalFilename: originalFilename,
      contentSizeBytes: contentSizeBytes,
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRepo = MediaRepository();
    repo = MediaLibraryRepository();

    // Five unlinked rows, no diver scoping needed. Two carry a null
    // filename and two a null size, so every sort key exercises its
    // COALESCE fallback and its NULL run.
    await insertMedia(
      'a',
      DateTime(2026, 6, 1),
      originalFilename: 'alpha.jpg',
      contentSizeBytes: 500,
    );
    await insertMedia(
      'b',
      DateTime(2026, 6, 2),
      originalFilename: 'bravo.jpg',
      contentSizeBytes: 100,
    );
    await insertMedia('c', DateTime(2026, 6, 3), contentSizeBytes: 300);
    await insertMedia('d', DateTime(2026, 6, 4), originalFilename: 'delta.jpg');
    await insertMedia('e', DateTime(2026, 6, 5));
  });
  tearDown(tearDownTestDatabase);

  /// Walks every page with the given sort and returns the ids in order.
  Future<List<String>> pageThrough(
    SortState<MediaSortField> sort, {
    int limit = 2,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    final ids = <String>[];
    MediaLibraryCursor? cursor;
    var guard = 0;
    while (true) {
      final page = await repo.getPage(
        diverId: null,
        filter: filter,
        sort: sort,
        after: cursor,
        limit: limit,
      );
      ids.addAll(page.entries.map((e) => e.item.id));
      cursor = page.nextCursor;
      if (cursor == null) break;
      if (++guard > 20) fail('pagination did not terminate');
    }
    return ids;
  }

  SortState<MediaSortField> sortBy(
    MediaSortField field,
    SortDirection direction,
  ) => SortState(field: field, direction: direction);

  group('date sort', () {
    test('descending is the default and is unchanged', () async {
      final page = await repo.getPage(diverId: null);
      expect(page.entries.map((e) => e.item.id), ['e', 'd', 'c', 'b', 'a']);
    });

    test('ascending reverses it', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.dateTaken, SortDirection.ascending),
        ),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });
  });

  group('file name sort', () {
    // Rows with no originalFilename fall back to file_path ('/tmp/c',
    // '/tmp/e'), which sorts before every bare 'x.jpg' name.
    test('ascending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
        ),
        ['c', 'e', 'a', 'b', 'd'],
      );
    });

    test('descending is the exact reverse', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.descending),
        ),
        ['d', 'b', 'a', 'e', 'c'],
      );
    });
  });

  group('file size sort', () {
    // 'd' and 'e' have no size and coalesce to -1, so they sort smallest.
    // Their tie is broken by id descending when the sort is descending.
    test('descending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileSize, SortDirection.descending),
        ),
        ['a', 'c', 'b', 'e', 'd'],
      );
    });

    test('ascending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileSize, SortDirection.ascending),
        ),
        ['d', 'e', 'b', 'c', 'a'],
      );
    });

    test('a tie in the sort key does not drop or repeat rows', () async {
      // Two more rows sharing a size with an existing one. A keyset whose
      // tiebreaker is wrong silently loses one of them.
      await insertMedia(
        'f',
        DateTime(2026, 6, 6),
        originalFilename: 'foxtrot.jpg',
        contentSizeBytes: 300,
      );
      await insertMedia(
        'g',
        DateTime(2026, 6, 7),
        originalFilename: 'golf.jpg',
        contentSizeBytes: 300,
      );

      final ids = await pageThrough(
        sortBy(MediaSortField.fileSize, SortDirection.descending),
      );
      expect(ids, hasLength(7));
      expect(ids.toSet(), hasLength(7));
      expect(ids.take(4), ['a', 'g', 'f', 'c']);
    });
  });

  group('date bounds are independent of the sort key', () {
    test('a date range still filters by date while sorting by size', () async {
      final filter = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 2),
        toDate: DateTime(2026, 6, 4, 23, 59, 59, 999),
      );
      final ids = await pageThrough(
        sortBy(MediaSortField.fileSize, SortDirection.descending),
        filter: filter,
      );
      // b (100), c (300), d (null) are in range; a and e are outside it.
      expect(ids, ['c', 'b', 'd']);
    });

    test('a date range still filters by date while sorting by name', () async {
      final filter = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 2),
        toDate: DateTime(2026, 6, 4, 23, 59, 59, 999),
      );
      final ids = await pageThrough(
        sortBy(MediaSortField.fileName, SortDirection.ascending),
        filter: filter,
      );
      expect(ids, ['c', 'b', 'd']);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/data/media_library_sort_test.dart
```

Expected: FAIL to compile, `No named parameter with the name 'sort'`.

- [ ] **Step 3: Widen the cursor**

In `lib/features/media/domain/entities/media_library_filter.dart`, replace the
`MediaLibraryCursor` class:

```dart
/// Keyset cursor: the last entry's value for the active sort key, plus its
/// row id as the tiebreaker.
///
/// [sortKey] is an int for the date and size fields and a String for the
/// name field. It is always non-null: the repository coalesces every sort
/// expression, because a NULL key makes the keyset predicate evaluate to
/// NULL (falsy) and silently truncates the result set.
class MediaLibraryCursor {
  const MediaLibraryCursor({required this.sortKey, required this.id});

  final Object sortKey;
  final String id;
}
```

- [ ] **Step 4: Generalize the repository**

In `lib/features/media/data/repositories/media_library_repository.dart`:

Add these imports at the top, after the existing `package:drift/drift.dart`
import:

```dart
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
```

Rename the date key getter (line 32) and add the sort machinery next to it:

```dart
  /// The library's date key: COALESCE(taken_at, created_at).
  ///
  /// This serves the fromDate/toDate FILTER BOUNDS and, when the active sort
  /// is dateTaken, the ordering. The two roles are deliberately separate:
  /// bounds must always compare dates, even when the page is ordered by name
  /// or size.
  Expression<int> get _dateKey =>
      coalesce<int>([_db.media.takenAt, _db.media.createdAt]);

  /// Filename key, falling back to file_path (NOT NULL) so the expression is
  /// total.
  Expression<String> get _nameKey =>
      coalesce<String>([_db.media.originalFilename, _db.media.filePath]);

  /// Size key. content_size_bytes is written only once the media store has
  /// hashed a row, so unhashed rows coalesce to -1 and sort as smallest.
  Expression<int> get _sizeKey =>
      coalesce<int>([_db.media.contentSizeBytes, const Constant(-1)]);
```

Replace every remaining `_sortKey` reference in `_baseWhere` (lines 71 and 79)
with `_dateKey`. Those are the date bound comparisons and their behavior does
not change.

Add these three private members after `_baseWhere`:

```dart
  /// The keyset predicate for one page boundary.
  ///
  /// `key <op> value OR (key = value AND id <op> lastId)`, where <op> follows
  /// the sort direction. The id tiebreaker is what keeps rows sharing a sort
  /// key from being dropped or repeated across a page boundary.
  Expression<bool> _afterCursor<T extends Comparable<dynamic>>(
    Expression<T> key,
    T value,
    String lastId,
    SortDirection direction,
  ) {
    final descending = direction == SortDirection.descending;
    final beyond = descending
        ? key.isSmallerThanValue(value)
        : key.isBiggerThanValue(value);
    final tie = descending
        ? _db.media.id.isSmallerThanValue(lastId)
        : _db.media.id.isBiggerThanValue(lastId);
    return beyond | (key.equals(value) & tie);
  }

  /// The cursor value for [row] under [field]. Mirrors the COALESCE in the
  /// matching key expression: if these two ever disagree, pagination skips
  /// or repeats rows at the boundary.
  Object _cursorValue(MediaData row, MediaSortField field) => switch (field) {
    MediaSortField.dateTaken => row.takenAt ?? row.createdAt,
    MediaSortField.fileName => row.originalFilename ?? row.filePath,
    MediaSortField.fileSize => row.contentSizeBytes ?? -1,
  };

  /// The ordering expression for [field]. Typed loosely because OrderingTerm
  /// accepts any expression; the typed comparisons live in [_afterCursor].
  Expression<Object> _sortExpression(MediaSortField field) => switch (field) {
    MediaSortField.dateTaken => _dateKey,
    MediaSortField.fileName => _nameKey,
    MediaSortField.fileSize => _sizeKey,
  };
```

Replace the `getPage` signature and its where/order construction (lines
100-131) with:

```dart
  /// One page of library entries for [diverId] (null = all divers), ordered
  /// by [sort] (newest first by default). Pass the previous page's
  /// [MediaLibraryPageResult.nextCursor] as [after] to continue.
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final s = _db.diveSites;

      Expression<bool> where = _baseWhere(diverId, filter);
      if (after != null) {
        where = where & switch (sort.field) {
          MediaSortField.dateTaken => _afterCursor(
            _dateKey,
            after.sortKey as int,
            after.id,
            sort.direction,
          ),
          MediaSortField.fileName => _afterCursor(
            _nameKey,
            after.sortKey as String,
            after.id,
            sort.direction,
          ),
          MediaSortField.fileSize => _afterCursor(
            _sizeKey,
            after.sortKey as int,
            after.id,
            sort.direction,
          ),
        };
      }

      final mode = sort.direction == SortDirection.descending
          ? OrderingMode.desc
          : OrderingMode.asc;

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
            ])
            ..where(where)
            ..orderBy([
              OrderingTerm(expression: _sortExpression(sort.field), mode: mode),
              OrderingTerm(expression: m.id, mode: mode),
            ])
            ..limit(limit + 1);
```

Leave the row-mapping block unchanged, and replace only the `next` cursor
construction near line 160:

```dart
      MediaLibraryCursor? next;
      if (hasMore && entries.isNotEmpty) {
        final last = visible.last.readTable(m);
        next = MediaLibraryCursor(
          sortKey: _cursorValue(last, sort.field),
          id: last.id,
        );
      }
```

Also update the class docstring's pagination sentence (line 22) to read:

```dart
/// owns exactly one job -- library queries. Pagination is keyset on the
/// active sort key plus id, so deep scroll positions stay flat-cost on large
/// libraries. Every sort key is coalesced to a non-null value; see
/// [_afterCursor]. Signature rows are always excluded;
```

- [ ] **Step 5: Add the three indexes**

In `lib/core/database/performance_indexes.dart`, add these entries to
`kPerformanceIndexes` immediately after `idx_media_local_path`:

```dart
  // Library sort keys. Expression indexes: COALESCE is deterministic, so
  // SQLite accepts it here. The date one also covers the default ordering,
  // which had no index before.
  (
    name: 'idx_media_sort_date',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_sort_date '
        'ON media(COALESCE(taken_at, created_at) DESC, id DESC)',
  ),
  (
    name: 'idx_media_sort_name',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_sort_name '
        'ON media(COALESCE(original_filename, file_path), id)',
  ),
  (
    name: 'idx_media_sort_size',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_sort_size '
        'ON media(COALESCE(content_size_bytes, -1) DESC, id DESC)',
  ),
```

- [ ] **Step 6: Fix the fake in the providers test**

`_FakeLibraryRepo` in
`test/features/media/presentation/media_library_providers_test.dart:33`
implements `MediaLibraryRepository`, so its `getPage` override no longer
matches. Add the parameter and record it (Task 3 asserts on it):

```dart
class _FakeLibraryRepo implements MediaLibraryRepository {
  int pageCalls = 0;
  MediaLibraryFilter? lastFilter;
  SortState<MediaSortField>? lastSort;
  String? lastDiverId;
  final changes = StreamController<void>.broadcast();

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    pageCalls++;
    lastFilter = filter;
    lastSort = sort;
```

Add the matching imports to that test file:

```dart
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/data/media_library_sort_test.dart \
               test/features/media/data/media_library_repository_test.dart \
               test/features/media/presentation/media_library_providers_test.dart \
               test/core/database/performance_indexes_test.dart
```

Expected: PASS. `media_library_repository_test.dart` is the regression guard
that the default ordering did not change, and `performance_indexes_test.dart`
applies every index against a fresh schema, so it fails if any new DDL
references a column that does not exist.

- [ ] **Step 8: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add lib/features/media/domain/entities/media_library_filter.dart \
        lib/features/media/data/repositories/media_library_repository.dart \
        lib/core/database/performance_indexes.dart \
        test/features/media/data/media_library_sort_test.dart \
        test/features/media/presentation/media_library_providers_test.dart
git commit -m "feat(media): sort library pages by date, name, or size"
```

---

### Task 3: Wire the sort provider into the library notifier

**Files:**
- Modify: `lib/features/media/presentation/providers/media_library_providers.dart:99-160`
- Test: `test/features/media/presentation/media_library_providers_test.dart`

**Interfaces:**
- Consumes: `mediaLibrarySortProvider` (Task 1), `getPage(sort:)` (Task 2).
- Produces: `MediaLibraryNotifier(repo, diverId, filter, sort)` positional
  constructor; `mediaLibraryNotifierProvider` now rebuilds on sort changes.

- [ ] **Step 1: Write the failing test**

Append inside the existing `main()` of
`test/features/media/presentation/media_library_providers_test.dart`, in a new
group:

```dart
  group('sort', () {
    test('passes the default sort to the repository', () async {
      container.read(mediaLibraryNotifierProvider);
      await tick();

      expect(fakeRepo.lastSort, kDefaultMediaSort);
    });

    test('changing the sort reloads page one with the new sort', () async {
      container.read(mediaLibraryNotifierProvider);
      await tick();
      final callsBefore = fakeRepo.pageCalls;

      await container
          .read(mediaLibrarySortProvider.notifier)
          .setSort(MediaSortField.fileSize, SortDirection.ascending);
      container.read(mediaLibraryNotifierProvider);
      await tick();

      expect(fakeRepo.pageCalls, greaterThan(callsBefore));
      expect(
        fakeRepo.lastSort,
        const SortState(
          field: MediaSortField.fileSize,
          direction: SortDirection.ascending,
        ),
      );
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_providers_test.dart
```

Expected: FAIL. `lastSort` is null on the first test because nothing passes a
sort yet.

- [ ] **Step 3: Wire the notifier**

In `lib/features/media/presentation/providers/media_library_providers.dart`,
add the import:

```dart
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
```

Change the provider body:

```dart
final mediaLibraryNotifierProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(mediaLibraryFilterProvider);
      final sort = ref.watch(mediaLibrarySortProvider);
      return MediaLibraryNotifier(repo, diverId, filter, sort);
    });
```

Change the notifier's constructor and fields:

```dart
class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  MediaLibraryNotifier(this._repo, this._diverId, this._filter, this._sort)
    : super(const MediaLibraryState()) {
    _changesSub = _repo.watchMediaChanges().listen((_) => loadFirstPage());
    loadFirstPage();
  }

  final MediaLibraryRepository _repo;
  final String? _diverId;
  final MediaLibraryFilter _filter;
  final SortState<MediaSortField> _sort;
```

Pass `sort: _sort` in both `getPage` calls, in `loadFirstPage`:

```dart
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        sort: _sort,
      );
```

and in `loadMore`:

```dart
      final page = await _repo.getPage(
        diverId: _diverId,
        filter: _filter,
        sort: _sort,
        after: cursor,
      );
```

Also update the provider's docstring comment above it:

```dart
/// Paged library notifier. Rebuilt whenever the filter, sort, or active diver
/// changes; refreshed (page one reload) whenever the media table changes.
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_providers_test.dart
```

Expected: PASS, including the pre-existing tests in that file.

- [ ] **Step 5: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add lib/features/media/presentation/providers/media_library_providers.dart \
        test/features/media/presentation/media_library_providers_test.dart
git commit -m "feat(media): reload the library when the sort changes"
```

---

### Task 4: The filter bottom sheet

A draft-then-Apply sheet modeled on `SiteFilterSheet`. It owns type, site,
trip, and dates, and hosts the smart-album loader.

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_filter_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the ten sibling locale files (3 keys)
- Test: `test/features/media/presentation/media_library_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `mediaLibraryFilterProvider`, `mediaSmartAlbumsProvider`,
  `mediaSmartAlbumRepositoryProvider`, `sitesProvider`, `allTripsProvider`,
  `showAppDateRangePicker`.
- Produces:
  - `class MediaLibraryFilterSheet extends ConsumerStatefulWidget`
  - `Future<void> showMediaLibraryFilterSheet(BuildContext context)`

**Critical detail:** Apply must `copyWith` onto the LIVE provider value, not
onto `MediaLibraryFilter.none`. `media_sources_section_view.dart:133` writes a
`sourceType` into this same provider when the user browses a source, and
`MediaLibraryFilter.none.copyWith(...)` would silently discard it.

- [ ] **Step 1: Add the three l10n keys to all 11 ARB files**

In `lib/l10n/arb/app_en.arb`, near the other `media_library_filter_*` keys:

```json
  "media_library_filter_title": "Filter media",
  "@media_library_filter_title": {
    "description": "Title of the media library filter sheet, and the filter button's tooltip"
  },
  "media_library_filter_apply": "Apply",
  "@media_library_filter_apply": {
    "description": "Button that applies the drafted media filter"
  },
  "media_smartAlbum_load": "Load album",
  "@media_smartAlbum_load": {
    "description": "Opens the list of saved smart albums to load one"
  },
```

In the other ten files, the plain pairs:

| File | `media_library_filter_title` | `media_library_filter_apply` | `media_smartAlbum_load` |
| --- | --- | --- | --- |
| `app_de.arb` | `Medien filtern` | `Übernehmen` | `Album laden` |
| `app_es.arb` | `Filtrar medios` | `Aplicar` | `Cargar álbum` |
| `app_fr.arb` | `Filtrer les médias` | `Appliquer` | `Charger l'album` |
| `app_it.arb` | `Filtra media` | `Applica` | `Carica album` |
| `app_nl.arb` | `Media filteren` | `Toepassen` | `Album laden` |
| `app_pt.arb` | `Filtrar mídia` | `Aplicar` | `Carregar álbum` |
| `app_hu.arb` | `Media szurese` | `Alkalmaz` | `Album betoltese` |
| `app_zh.arb` | `筛选媒体` | `应用` | `加载相册` |
| `app_ar.arb` | `تصفية الوسائط` | `تطبيق` | `تحميل الألبوم` |
| `app_he.arb` | `סנן מדיה` | `החל` | `טען אלבום` |

Then regenerate:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter gen-l10n
```

The sheet reuses these existing keys: `media_library_filter_all`,
`media_library_filter_photos`, `media_library_filter_videos`,
`media_library_filter_site`, `media_library_filter_trip`,
`media_library_filter_dates`, `diveSites_filter_clearAll`,
`enum_sortField_type`, `media_smartAlbum_albums`, `media_smartAlbum_delete`,
`media_smartAlbum_deleteFailed`.

- [ ] **Step 2: Write the failing test**

Create `test/features/media/presentation/media_library_filter_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');
  final trip = Trip(
    id: 'trip-1',
    name: 'Red Sea 2026',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 14),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => [site]),
        allTripsProvider.overrideWith((ref) async => [trip]),
      ],
    );
    addTearDown(container.dispose);
  });

  // The sheet is opened from a host button so the test exercises the real
  // modal route, which is where a sheet's own Navigator context lives.
  Widget host() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMediaLibraryFilterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('drafts a type and writes it only on Apply', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    // Nothing is committed until Apply.
    expect(container.read(mediaLibraryFilterProvider).mediaType, isNull);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.photo,
    );
  });

  testWidgets('dismissing without Apply leaves the filter untouched', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video);
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    // Tap the barrier to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.video,
    );
  });

  testWidgets('picking a site drafts it and Apply commits the id', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).siteId, 'site-1');
  });

  testWidgets('Apply preserves facets the sheet does not own', (tester) async {
    // The Sources view writes a sourceType into this same provider. Applying
    // a type filter must not silently discard it.
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(sourceType: MediaSourceType.networkUrl);
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.mediaType, MediaType.photo);
    expect(filter.sourceType, MediaSourceType.networkUrl);
  });

  testWidgets('Clear all resets the drafted facets', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(
          mediaType: MediaType.video,
          siteId: 'site-1',
        );
    await openSheet(tester);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.mediaType, isNull);
    expect(filter.siteId, isNull);
  });
}
```

Note: confirm the exact English string for `diveSites_filter_clearAll` with
`grep '"diveSites_filter_clearAll"' lib/l10n/arb/app_en.arb` and use it
verbatim in the `find.text` above.

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_filter_sheet_test.dart
```

Expected: FAIL to compile, cannot resolve
`media_library_filter_sheet.dart`.

- [ ] **Step 4: Write the sheet**

Create
`lib/features/media/presentation/widgets/media_library_filter_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Opens the library filter sheet. Returns when it closes; the sheet writes
/// [mediaLibraryFilterProvider] itself on Apply.
Future<void> showMediaLibraryFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const MediaLibraryFilterSheet(),
  );
}

/// Draft-then-Apply filter editor for the media library, following the
/// SiteFilterSheet pattern: local state previews the change and nothing
/// reaches the provider until Apply.
///
/// Owns four facets: media type, site, trip, and date range. It deliberately
/// does NOT own sourceType or health, which other console sections set
/// programmatically, and which Apply preserves.
class MediaLibraryFilterSheet extends ConsumerStatefulWidget {
  const MediaLibraryFilterSheet({super.key});

  @override
  ConsumerState<MediaLibraryFilterSheet> createState() =>
      _MediaLibraryFilterSheetState();
}

class _MediaLibraryFilterSheetState
    extends ConsumerState<MediaLibraryFilterSheet> {
  MediaType? _mediaType;
  String? _siteId;
  String? _tripId;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(mediaLibraryFilterProvider);
    _mediaType = filter.mediaType;
    _siteId = filter.siteId;
    _tripId = filter.tripId;
    _fromDate = filter.fromDate;
    _toDate = filter.toDate;
  }

  void _clearAll() {
    setState(() {
      _mediaType = null;
      _siteId = null;
      _tripId = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  /// Commits the draft ONTO THE LIVE FILTER, not onto a fresh one. The
  /// Sources section writes a sourceType into the same provider when the
  /// user browses a source; rebuilding from MediaLibraryFilter.none here
  /// would drop it and quietly widen the library.
  void _apply() {
    final notifier = ref.read(mediaLibraryFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(
      mediaType: _mediaType,
      siteId: _siteId,
      tripId: _tripId,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickFromList({
    required List<(String id, String label)> options,
    required void Function(String? id) onPicked,
    required String anyLabel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(anyLabel),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPicked(null);
              },
            ),
            for (final (id, label) in options)
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPicked(id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1),
    );
    if (range == null) return;
    setState(() {
      _fromDate = range.start;
      // Extend to end-of-day so a single-day range includes its media.
      _toDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Future<void> _loadAlbum() async {
    final albums = ref.read(mediaSmartAlbumsProvider).value ?? const [];
    if (albums.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final album in albums)
              ListTile(
                title: Text(album.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: context.l10n.media_smartAlbum_delete,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _deleteAlbum(album.id);
                  },
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _mediaType = album.filter.mediaType;
                    _siteId = album.filter.siteId;
                    _tripId = album.filter.tripId;
                    _fromDate = album.filter.fromDate;
                    _toDate = album.filter.toDate;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Awaited rather than fired and forgotten: an unawaited repository call
  /// turns a failed delete into an uncaught async error and leaves the album
  /// on screen with no explanation for why it came back.
  Future<void> _deleteAlbum(String id) async {
    try {
      await ref.read(mediaSmartAlbumRepositoryProvider).delete(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_smartAlbum_deleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final sites = ref.watch(sitesProvider).value ?? const [];
    final trips = ref.watch(allTripsProvider).value ?? const [];
    final albums = ref.watch(mediaSmartAlbumsProvider).value ?? const [];

    final siteName = _siteId == null
        ? null
        : sites.where((s) => s.id == _siteId).firstOrNull?.name;
    final tripName = _tripId == null
        ? null
        : trips.where((t) => t.id == _tripId).firstOrNull?.name;
    final anyLabel = l10n.media_library_filter_all;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          // Transparent Material so the ListTiles inside paint their ink and
          // background above this decorated container (Flutter 3.44 asserts
          // on a ListTile whose nearest decorated ancestor precedes its
          // Material).
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.media_library_filter_title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: _clearAll,
                        child: Text(l10n.diveSites_filter_clearAll),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (albums.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bookmarks_outlined),
                          title: Text(l10n.media_smartAlbum_load),
                          onTap: _loadAlbum,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.enum_sortField_type,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(anyLabel),
                            selected: _mediaType == null,
                            onSelected: (_) =>
                                setState(() => _mediaType = null),
                          ),
                          ChoiceChip(
                            label: Text(l10n.media_library_filter_photos),
                            selected: _mediaType == MediaType.photo,
                            onSelected: (_) =>
                                setState(() => _mediaType = MediaType.photo),
                          ),
                          ChoiceChip(
                            label: Text(l10n.media_library_filter_videos),
                            selected: _mediaType == MediaType.video,
                            onSelected: (_) =>
                                setState(() => _mediaType = MediaType.video),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.media_library_filter_site),
                        subtitle: Text(siteName ?? anyLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickFromList(
                          options: [for (final s in sites) (s.id, s.name)],
                          onPicked: (id) => setState(() => _siteId = id),
                          anyLabel: anyLabel,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.media_library_filter_trip),
                        subtitle: Text(tripName ?? anyLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickFromList(
                          options: [for (final t in trips) (t.id, t.name)],
                          onPicked: (id) => setState(() => _tripId = id),
                          anyLabel: anyLabel,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.media_library_filter_dates),
                        subtitle: Text(
                          _fromDate == null && _toDate == null
                              ? anyLabel
                              : formatFilterDateRange(
                                  context,
                                  _fromDate,
                                  _toDate,
                                ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDates,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _apply,
                        child: Text(l10n.media_library_filter_apply),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Add the shared date-range label helper**

Both this sheet and Task 5's chip strip render a date range, and they must not
disagree about how one reads. Create
`lib/features/media/presentation/widgets/media_library_filter_labels.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Renders a filter date range for display. Shared by the filter sheet and
/// the active-chip strip so the same range never reads two different ways.
///
/// Locale-aware by construction: DateFormat is built from the active locale
/// rather than a hard-coded pattern.
String formatFilterDateRange(
  BuildContext context,
  DateTime? from,
  DateTime? to,
) {
  final format = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  if (from != null && to != null) {
    return '${format.format(from)} - ${format.format(to)}';
  }
  return format.format(from ?? to!);
}
```

Import it in the sheet:

```dart
import 'package:submersion/features/media/presentation/widgets/media_library_filter_labels.dart';
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_filter_sheet_test.dart
```

Expected: PASS, all 5 tests.

- [ ] **Step 7: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add lib/features/media/presentation/widgets/media_library_filter_sheet.dart \
        lib/features/media/presentation/widgets/media_library_filter_labels.dart \
        lib/l10n/arb/ \
        test/features/media/presentation/media_library_filter_sheet_test.dart
git commit -m "feat(media): add the library filter bottom sheet"
```

---

### Task 5: The active filter chip strip

Renders only when the filter says something. Shows one removable chip per
active facet, plus Clear filters and Save as album.

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_active_filter_chips.dart`
- Test: `test/features/media/presentation/media_library_active_filter_chips_test.dart`

**Interfaces:**
- Consumes: `mediaLibraryFilterProvider`, `sitesProvider`, `allTripsProvider`,
  `mediaSmartAlbumRepositoryProvider`, `showMediaSmartAlbumNameDialog`.
- Produces: `class MediaLibraryActiveFilterChips extends ConsumerWidget`.
  `formatFilterDateRange` comes from Task 4's
  `media_library_filter_labels.dart`; do not redefine it here.

A `sourceType` chip is included even though the sheet does not set that facet.
`media_sources_section_view.dart:133` writes it when the user picks "browse
this source", and without a chip the library sits filtered with no visible
reason and only a bare Clear button to explain it.

- [ ] **Step 1: Write the failing test**

Create
`test/features/media/presentation/media_library_active_filter_chips_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');
  final trip = Trip(
    id: 'trip-1',
    name: 'Red Sea 2026',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 14),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => [site]),
        allTripsProvider.overrideWith((ref) async => [trip]),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host() => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MediaLibraryActiveFilterChips()),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing when the filter is empty', (tester) async {
    await pump(tester);

    expect(find.byType(Chip), findsNothing);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('shows one chip per active facet', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(
          mediaType: MediaType.photo,
          siteId: 'site-1',
          tripId: 'trip-1',
        );
    await pump(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Red Sea 2026'), findsOneWidget);
  });

  testWidgets('deleting a chip clears only its own facet', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(
          mediaType: MediaType.photo,
          siteId: 'site-1',
        );
    await pump(tester);

    // The delete icon inside the site chip.
    final siteChip = find.ancestor(
      of: find.text('Blue Hole'),
      matching: find.byType(InputChip),
    );
    await tester.tap(
      find.descendant(of: siteChip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.siteId, isNull);
    expect(filter.mediaType, MediaType.photo);
  });

  testWidgets('Clear filters empties the whole filter', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(
          mediaType: MediaType.photo,
          siteId: 'site-1',
        );
    await pump(tester);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_active_filter_chips_test.dart
```

Expected: FAIL to compile, cannot resolve
`media_library_active_filter_chips.dart`.

- [ ] **Step 3: Write the widget**

Create
`lib/features/media/presentation/widgets/media_library_active_filter_chips.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_labels.dart';
import 'package:submersion/features/media/presentation/widgets/media_smart_album_name_dialog.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The strip of removable chips below the library toolbar. Renders nothing
/// while the filter is empty, so the section is uncluttered at rest and
/// self-explanatory the moment anything is filtered.
class MediaLibraryActiveFilterChips extends ConsumerWidget {
  const MediaLibraryActiveFilterChips({super.key});

  void _update(
    WidgetRef ref,
    MediaLibraryFilter Function(MediaLibraryFilter) change,
  ) {
    final notifier = ref.read(mediaLibraryFilterProvider.notifier);
    notifier.state = change(notifier.state);
  }

  Future<void> _saveAlbum(BuildContext context, WidgetRef ref) async {
    final name = await showMediaSmartAlbumNameDialog(context);
    if (name == null) return;
    await ref
        .read(mediaSmartAlbumRepositoryProvider)
        .create(name: name, filter: ref.read(mediaLibraryFilterProvider));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.media_smartAlbum_saved)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    if (filter.isEmpty) return const SizedBox.shrink();

    final sites = ref.watch(sitesProvider).value ?? const [];
    final trips = ref.watch(allTripsProvider).value ?? const [];

    Widget chip(String label, VoidCallback onClear) {
      return InputChip(
        label: Text(label),
        deleteIcon: const Icon(Icons.clear, size: 18),
        onDeleted: onClear,
      );
    }

    final chips = <Widget>[];

    final type = filter.mediaType;
    if (type != null) {
      chips.add(
        chip(
          type == MediaType.photo
              ? l10n.media_library_filter_photos
              : l10n.media_library_filter_videos,
          () => _update(ref, (f) => f.copyWith(mediaType: null)),
        ),
      );
    }

    final siteId = filter.siteId;
    if (siteId != null) {
      final name =
          sites.where((s) => s.id == siteId).firstOrNull?.name ??
          l10n.media_library_filter_site;
      chips.add(chip(name, () => _update(ref, (f) => f.copyWith(siteId: null))));
    }

    final tripId = filter.tripId;
    if (tripId != null) {
      final name =
          trips.where((t) => t.id == tripId).firstOrNull?.name ??
          l10n.media_library_filter_trip;
      chips.add(chip(name, () => _update(ref, (f) => f.copyWith(tripId: null))));
    }

    if (filter.fromDate != null || filter.toDate != null) {
      chips.add(
        chip(
          formatFilterDateRange(context, filter.fromDate, filter.toDate),
          () => _update(ref, (f) => f.copyWith(fromDate: null, toDate: null)),
        ),
      );
    }

    // Set by the Sources section's "browse this source", not by the filter
    // sheet. Without a chip the library sits filtered with nothing on screen
    // saying why.
    final sourceType = filter.sourceType;
    if (sourceType != null) {
      chips.add(
        chip(
          sourceType.name,
          () => _update(ref, (f) => f.copyWith(sourceType: null)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          ActionChip(
            label: Text(l10n.media_library_filter_clear),
            onPressed: () =>
                ref.read(mediaLibraryFilterProvider.notifier).state =
                    MediaLibraryFilter.none,
          ),
          // Saving "everything" as an album would name nothing, so this only
          // appears once the filter says something. The whole strip is
          // already gated on that.
          ActionChip(
            avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(l10n.media_smartAlbum_save),
            onPressed: () => _saveAlbum(context, ref),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_active_filter_chips_test.dart
```

Expected: PASS, all 4 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add lib/features/media/presentation/widgets/media_library_active_filter_chips.dart \
        test/features/media/presentation/media_library_active_filter_chips_test.dart
git commit -m "feat(media): add the active filter chip strip"
```

---

### Task 6: The toolbar, the view wiring, and removing the old bar

Assembles everything, deletes `MediaLibraryFilterBar`, and rehomes the two
tests that drove it.

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_toolbar.dart`
- Delete: `lib/features/media/presentation/widgets/media_library_filter_bar.dart`
- Delete: `test/features/media/presentation/media_library_filter_bar_test.dart`
- Modify: `lib/features/media/presentation/pages/media_library_view.dart:44-83`
- Modify: `test/features/media/presentation/media_smart_album_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the ten sibling locale files (1 key)
- Test: `test/features/media/presentation/media_library_toolbar_test.dart`

**Interfaces:**
- Consumes: `showMediaLibraryFilterSheet` (Task 4),
  `MediaLibraryActiveFilterChips` (Task 5), `mediaLibrarySortProvider`
  (Task 1), `showSortBottomSheet`, `mediaLibraryViewModeProvider`.
- Produces: `class MediaLibraryToolbar extends ConsumerWidget`.

- [ ] **Step 1: Add the sort title key to all 11 ARB files**

`app_en.arb`:

```json
  "media_library_sort_title": "Sort media",
  "@media_library_sort_title": {
    "description": "Title of the media library sort sheet, and the sort button's tooltip"
  },
```

| File | `media_library_sort_title` |
| --- | --- |
| `app_de.arb` | `Medien sortieren` |
| `app_es.arb` | `Ordenar medios` |
| `app_fr.arb` | `Trier les médias` |
| `app_it.arb` | `Ordina media` |
| `app_nl.arb` | `Media sorteren` |
| `app_pt.arb` | `Ordenar mídia` |
| `app_hu.arb` | `Media rendezese` |
| `app_zh.arb` | `排序媒体` |
| `app_ar.arb` | `فرز الوسائط` |
| `app_he.arb` | `מיין מדיה` |

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter gen-l10n
```

- [ ] **Step 2: Write the failing test**

Create `test/features/media/presentation/media_library_toolbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Both the view-mode notifier and the sort notifier read and WRITE app
/// settings. Without this override they reach the real repository, and the
/// awaited setMode/setSort calls below throw because no database is open
/// under flutter test.
class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host() => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MediaLibraryToolbar()),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('the filter badge is hidden until something is filtered', (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
      isFalse,
    );

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    await tester.pumpAndSettle();

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });

  testWidgets('the sort button opens the sheet and writes the choice', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(find.text('Sort media'), findsOneWidget);
    await tester.tap(find.text('File Name'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibrarySortProvider).field,
      MediaSortField.fileName,
    );
  });

  testWidgets('the sort button is absent outside grid mode', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.sort), findsOneWidget);

    await container
        .read(mediaLibraryViewModeProvider.notifier)
        .setMode(MediaLibraryViewMode.timeline);
    await tester.pumpAndSettle();

    // The grouped modes define their own order, so offering a sort there
    // would shred the timeline into one-item day groups.
    expect(find.byIcon(Icons.sort), findsNothing);
  });

  testWidgets('the filter button opens the filter sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('Filter media'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/media_library_toolbar_test.dart
```

Expected: FAIL to compile, cannot resolve `media_library_toolbar.dart`.

- [ ] **Step 4: Write the toolbar**

Create `lib/features/media/presentation/widgets/media_library_toolbar.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// The library's control row: filter, sort, and view mode.
///
/// Every control is fixed-width, which is the point. The chip row this
/// replaced was an Expanded horizontal scroller that claimed all free width
/// and squeezed the view-mode selector beside it.
class MediaLibraryToolbar extends ConsumerWidget {
  const MediaLibraryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    final mode = ref.watch(mediaLibraryViewModeProvider);

    return Row(
      children: [
        IconButton(
          icon: Badge(
            isLabelVisible: !filter.isEmpty,
            child: const Icon(Icons.filter_list, size: 20),
          ),
          tooltip: l10n.media_library_filter_title,
          onPressed: () => showMediaLibraryFilterSheet(context),
        ),
        // Grid only: the by-dive and timeline groupers consume an
        // already-date-sorted stream, so a name or size sort would break
        // their grouping rather than reorder it.
        if (mode == MediaLibraryViewMode.grid)
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: l10n.media_library_sort_title,
            onPressed: () {
              final sort = ref.read(mediaLibrarySortProvider);
              showSortBottomSheet<MediaSortField>(
                context: context,
                title: l10n.media_library_sort_title,
                currentField: sort.field,
                currentDirection: sort.direction,
                fields: MediaSortField.values,
                getFieldDisplayName: (field) => field.localizedName(l10n),
                getFieldIcon: (field) => field.icon,
                onSortChanged: (field, direction) => ref
                    .read(mediaLibrarySortProvider.notifier)
                    .setSort(field, direction),
              );
            },
          ),
        const Spacer(),
        SegmentedButton<MediaLibraryViewMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MediaLibraryViewMode.grid,
              icon: const Icon(Icons.grid_view),
              tooltip: l10n.media_library_viewMode_grid,
            ),
            ButtonSegment(
              value: MediaLibraryViewMode.byDive,
              icon: const Icon(Icons.scuba_diving),
              tooltip: l10n.media_library_viewMode_byDive,
            ),
            ButtonSegment(
              value: MediaLibraryViewMode.timeline,
              icon: const Icon(Icons.calendar_month),
              tooltip: l10n.media_library_viewMode_timeline,
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref
              .read(mediaLibraryViewModeProvider.notifier)
              .setMode(selection.single),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Rewire the library view**

In `lib/features/media/presentation/pages/media_library_view.dart`, replace
the import of `media_library_filter_bar.dart` with:

```dart
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
```

Replace the whole `Padding`/`Row` block (lines 51-82) with:

```dart
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: MediaLibraryToolbar(),
        ),
        const MediaLibraryActiveFilterChips(),
```

Remove the now-unused `mode` local if the analyzer flags it, and update the
class docstring:

```dart
/// The Library section content: the filter and sort toolbar over the active
/// view mode. The by-dive and timeline presentations reuse the same paged
/// state.
```

Note that `_buildBody` still needs `mode`, so keep
`final mode = ref.watch(mediaLibraryViewModeProvider);` and pass it through as
it does today.

- [ ] **Step 6: Delete the old bar and its test**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  git rm lib/features/media/presentation/widgets/media_library_filter_bar.dart \
         test/features/media/presentation/media_library_filter_bar_test.dart
```

- [ ] **Step 7: Rehome the smart album test**

`test/features/media/presentation/media_smart_album_test.dart` drives the
deleted widget. Rewrite its host to mount `MediaLibraryActiveFilterChips`
instead, keeping the same three behaviors. Replace the import of
`media_library_filter_bar.dart` with
`media_library_active_filter_chips.dart`, and replace `host()` and
`containerOf` with:

```dart
  late ProviderContainer container;

  Widget host() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        mediaSmartAlbumRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryActiveFilterChips()),
      ),
    );
  }
```

The chip strip has no Photos chip to tap, so where a test previously did
`await tester.tap(find.text('Photos'))` to make the filter non-empty, set the
filter directly before pumping:

```dart
    await tester.pumpWidget(host());
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    await tester.pumpAndSettle();
```

The "save action only appears once the filter says something" test becomes:
pump with an empty filter, assert `find.text('Save as album')` is
`findsNothing`; then set the filter as above and assert `findsOneWidget`.

The album-loading test moves to the filter sheet: add an equivalent case to
`media_library_filter_sheet_test.dart` that seeds one album in the fake repo,
opens the sheet, taps `Load album`, taps the album name, taps `Apply`, and
asserts the filter matches the album's.

- [ ] **Step 8: Run every affected test**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test test/features/media/presentation/
```

Expected: PASS, no reference to `MediaLibraryFilterBar` remains. Confirm with:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  grep -rn "MediaLibraryFilterBar" lib test
```

Expected: no output.

- [ ] **Step 9: Format, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format . && flutter analyze
git add -A
git commit -m "feat(media): replace the library filter chip row with a toolbar and sheet"
```

---

### Task 7: Whole-suite verification

**Files:** none modified unless a failure surfaces.

- [ ] **Step 1: Confirm the tree you are testing**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  echo "PWD: $(pwd)" && git rev-parse --abbrev-ref HEAD && flutter analyze 2>&1 | head -3
```

`flutter analyze` prints `Analyzing media-filter-sort...`, which is the
receipt that the right tree is under test. Expected: `No issues found!`.

- [ ] **Step 2: Confirm formatting is clean**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  dart format --set-exit-if-changed . 2>&1 | tail -3
```

Expected: exit 0, no files changed.

- [ ] **Step 3: Run the full test suite**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter test 2>&1 | tail -30
```

Do NOT pipe through `grep`: a piped `flutter test` returns grep's exit status,
not the suite's. Run it twice before believing a green result, and do not run
it while another local test run is in flight; overlapping runs manufacture
lone failures that do not reproduce.

Expected: all tests pass. This repo has a set of known pre-existing flakes
(recovery-code yo-yo, security settings recovery dialog, zip temp dir,
media share helper temp bytes, weight planner twin, sync replace library).
A lone failure in one of those that passes on a re-run alone is not caused by
this work. A failure anywhere under `test/features/media/` or
`test/core/database/` is.

- [ ] **Step 4: Verify the change in the running app**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/media-filter-sort && \
  flutter run -d macos
```

Open Media, confirm: the toolbar shows two icons on the left and the view-mode
selector on the right with no crowding at any window width; the filter sheet
applies and the chips appear; the sort icon disappears when switching to
timeline; sorting by file name reorders the grid and scrolling to the bottom
loads every page without stalling.

- [ ] **Step 5: Push and open the PR**

Only after the user asks. The pre-push hook runs format, analyze, and tests
again.

## Self-Review Notes

Checked against the spec on 2026-08-23:

- Spec section "UI" maps to Tasks 4, 5, 6. Grid-only sort is Task 6 Step 4
  and its third test.
- Spec section "Sort model" maps to Tasks 1 and 3, including the deliberate
  exclusion of sort from album serialization (Task 1's provider docstring).
- Spec section "Repository" maps to Task 2, including the `_dateKey` split
  (F1), the three coalesced keys (F2), the widened cursor, and the three
  expression indexes (F4).
- Spec section "Known behavior" (size sort groups unhashed rows) is captured
  in Task 2's `_sizeKey` comment and its expected test ordering.
- Spec section "Testing" maps to the test steps in Tasks 1 through 6 plus
  Task 7. The NULL-bearing fixture the spec calls out is Task 2 Step 1.
- One item the spec did not anticipate, added here: the `sourceType` chip and
  the Apply-preserves-sourceType requirement, both forced by
  `media_sources_section_view.dart:133` writing that facet into the same
  provider. Covered by Task 4's fourth test and Task 5's widget.

Two defects found and fixed during this review:

- `formatFilterDateRange` was originally defined in Task 5 but used in
  Task 4, so implementing the tasks in order would not compile. It now lives
  in its own `media_library_filter_labels.dart`, created in Task 4 and
  imported by Task 5.
- Task 6's toolbar test had no `appSettingsRepositoryProvider` override, but
  the toolbar mounts two notifiers that read and write app settings. The
  awaited `setMode` call would have thrown against a real repository with no
  database open. A fake settings repo is now part of that test's container.
