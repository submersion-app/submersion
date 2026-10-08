# Site Attachment Categories and Large View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver categorize site attachments, show them grouped under category headings with maps and PDFs rendered full width, and rename them.

**Architecture:** Two nullable columns on `media` (`site_category`, `display_size`) carry the category key and an optional size override; they ride the existing `media` row sync. A pure layout function turns a site's attachments into ordered groups of large and tile items, which `SiteMediaSection` renders. A new narrow-writer `SiteAttachmentRepository` handles the edit sheet and the bulk category action; a size-keyed page-1 render in `PdfThumbnailService` feeds the large PDF card.

**Tech Stack:** Flutter 3.47, Riverpod 3, Drift (SQLite), pdfrx, flutter_test, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-05-site-attachment-categories-large-view-design.md`

## Global Constraints

- Issue #1039; release v1.8.2.
- Category keys, exactly: `siteMap`, `parking`, `access`, `anchorage`, `underwater`, `general`, in that display order; Uncategorized (null) renders last.
- Size keys, exactly: `large`, `tile`. Null override follows the category default; `underwater` defaults to tile, every other category to large; uncategorized defaults to tile.
- Unknown stored keys parse to null. No `default:` arm may map an unknown key to a real value.
- Schema rung v261 (re-read `AppDatabase.currentSchemaVersion` first; if main has moved past 260, take the next free number and adjust every literal below).
- Rename edits `originalFilename` only: stem editable, extension fixed. Forbidden characters `/ \ : * ? " < > |` and control characters. Blank stem rejected unless the item had no name.
- The edit sheet is a modal bottom sheet at every width, wrapped in `SheetMessengerScope`.
- No em dashes, en dashes as punctuation, or `--` as prose punctuation anywhere, code comments included. No emojis. No mention of AI tools in any committed text.
- Paths built with `p.join`, never string concatenation.
- New user-facing strings go into all 11 ARBs with real translations; run `flutter gen-l10n` only after every ARB has them.
- `dart format .` before each commit.

## Review Focus

1. An attachment with no stored filename (some gallery rows): the diver must still be able to set its category and size; a blank name field leaves the name unset instead of blocking Save. Test in Task 2 (`attachmentNameError`) and Task 9 (sheet saves with a blank name).
2. An attachment unlinked (or deleted on another device) while its edit sheet is open: Save must fail with the error snackbar, not queue a sync record for a row that no longer exists. Test in Task 4.
3. An image with unknown or zero `width`/`height`: the large card must fall back to 4:3, never divide by zero or collapse. Test in Task 10.
4. A PDF whose page render fails (corrupt file, pdfium unavailable): the large card must fall back to the full-width document row with icon and name, not an empty box or a spinner forever. Test in Task 10.
5. A very long filename on a phone-width large card: the title must ellipsize with no overflow error. Test in Task 10.

---

## File map

Create:
- `lib/features/media/domain/entities/site_attachment_category.dart`: the two enums and their key parsing.
- `lib/features/media/domain/value_objects/attachment_filename.dart`: stem/extension split, compose, validation.
- `lib/features/media/domain/value_objects/attachment_details_edit.dart`: `FieldChange`, `AttachmentDetailsEdit`, diff and name-error helpers.
- `lib/features/media/domain/services/site_attachment_layout.dart`: grouping of a site's attachments.
- `lib/features/media/data/repositories/site_attachment_repository.dart`: the two narrow writers.
- `lib/features/media/presentation/helpers/site_attachment_labels.dart`: localized labels for the enums.
- `lib/features/media/presentation/providers/pdf_preview_providers.dart`: large PDF render provider and size bucketing.
- `lib/features/media/presentation/widgets/attachment_details_sheet.dart`: the Edit details sheet.
- `lib/features/media/presentation/widgets/site_category_picker.dart`: the bulk Set category picker.
- `lib/features/media/presentation/widgets/site_attachment_large_card.dart`: full-width card per kind.
- `lib/features/media/presentation/widgets/site_attachment_groups.dart`: headings, large cards and per-group tile grids.
- Tests mirroring each under `test/`.

Modify:
- `lib/core/database/tables/media_tables.dart`, `lib/core/database/migrations/helpers/media_migrations.dart`, `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/before_open.dart`, `lib/core/database/database.dart`.
- `lib/features/media/domain/entities/media_item.dart`, `lib/features/media/data/repositories/media_row_mapper.dart`, `lib/features/media/data/repositories/media_repository.dart` (`createMedia`, `updateMedia`).
- `lib/features/media/data/services/pdf_page_renderer.dart`, `lib/features/media/data/services/pdf_thumbnail_service.dart`.
- `lib/features/media/presentation/providers/site_media_providers.dart`.
- `lib/features/media/presentation/widgets/site_media_section.dart`.
- `lib/features/media/presentation/pages/site_media_viewer_page.dart`, `lib/features/media/presentation/pages/document_viewer_page.dart`, `lib/features/media/presentation/helpers/document_open_helper.dart`, `lib/features/dive_sites/presentation/pages/site_detail_page.dart`.
- `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart`.
- `test/core/database/migration_v260_tank_shared_computers_test.dart` (relax the newest-rung tripwire).

---

### Task 1: Category and size enums, filename value object

**Files:**
- Create: `lib/features/media/domain/entities/site_attachment_category.dart`
- Create: `lib/features/media/domain/value_objects/attachment_filename.dart`
- Test: `test/features/media/domain/entities/site_attachment_category_test.dart`
- Test: `test/features/media/domain/value_objects/attachment_filename_test.dart`

**Interfaces:**
- Produces: `enum SiteAttachmentCategory { siteMap, parking, access, anchorage, underwater, general }` with `String storageKey`, `AttachmentDisplaySize defaultDisplaySize`, `static SiteAttachmentCategory? fromStorageKey(String?)`.
- Produces: `enum AttachmentDisplaySize { large, tile }` with `String storageKey`, `static AttachmentDisplaySize? fromStorageKey(String?)`.
- Produces: `class AttachmentFilename { String stem; String extension; factory AttachmentFilename.split(String? name); String compose(String newStem); static AttachmentNameError? validate(String stem); }` and `enum AttachmentNameError { blank, forbiddenCharacter }`.

- [ ] **Step 1: Write the failing enum test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

void main() {
  group('SiteAttachmentCategory', () {
    test('is declared in display order', () {
      expect(SiteAttachmentCategory.values.map((c) => c.storageKey), [
        'siteMap',
        'parking',
        'access',
        'anchorage',
        'underwater',
        'general',
      ]);
    });

    test('underwater defaults to tile, every other category to large', () {
      for (final c in SiteAttachmentCategory.values) {
        expect(
          c.defaultDisplaySize,
          c == SiteAttachmentCategory.underwater
              ? AttachmentDisplaySize.tile
              : AttachmentDisplaySize.large,
          reason: c.storageKey,
        );
      }
    });

    test('parses every key it writes', () {
      for (final c in SiteAttachmentCategory.values) {
        expect(SiteAttachmentCategory.fromStorageKey(c.storageKey), c);
      }
    });

    test('an unknown or absent key is uncategorized, never a real value', () {
      expect(SiteAttachmentCategory.fromStorageKey(null), isNull);
      expect(SiteAttachmentCategory.fromStorageKey(''), isNull);
      expect(SiteAttachmentCategory.fromStorageKey('boatRamp'), isNull);
      expect(SiteAttachmentCategory.fromStorageKey('SITEMAP'), isNull);
    });
  });

  group('AttachmentDisplaySize', () {
    test('round-trips its keys and rejects unknown ones', () {
      expect(AttachmentDisplaySize.fromStorageKey('large'),
          AttachmentDisplaySize.large);
      expect(AttachmentDisplaySize.fromStorageKey('tile'),
          AttachmentDisplaySize.tile);
      expect(AttachmentDisplaySize.fromStorageKey('huge'), isNull);
      expect(AttachmentDisplaySize.fromStorageKey(null), isNull);
    });
  });
}
```

- [ ] **Step 2: Write the failing filename test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

void main() {
  group('AttachmentFilename.split', () {
    test('splits on the last dot and keeps the extension case', () {
      final f = AttachmentFilename.split('Bonaire.Map.PDF');
      expect(f.stem, 'Bonaire.Map');
      expect(f.extension, 'PDF');
    });

    test('a name with no dot is all stem', () {
      final f = AttachmentFilename.split('README');
      expect(f.stem, 'README');
      expect(f.extension, '');
    });

    test('a trailing dot is part of the stem, as documentExtension reads it',
        () {
      final f = AttachmentFilename.split('map.');
      expect(f.stem, 'map.');
      expect(f.extension, '');
    });

    test('a leading-dot name has an empty stem', () {
      final f = AttachmentFilename.split('.gpx');
      expect(f.stem, '');
      expect(f.extension, 'gpx');
    });

    test('null is empty', () {
      final f = AttachmentFilename.split(null);
      expect(f.stem, '');
      expect(f.extension, '');
    });
  });

  group('compose', () {
    test('re-attaches the fixed extension and trims the stem', () {
      expect(AttachmentFilename.split('a.pdf').compose('  Reef map '),
          'Reef map.pdf');
    });

    test('no extension composes to the bare stem', () {
      expect(AttachmentFilename.split('notes').compose('Notes v2'),
          'Notes v2');
    });
  });

  group('validate', () {
    test('accepts an ordinary name', () {
      expect(AttachmentFilename.validate('North wall map'), isNull);
    });

    test('rejects blank and whitespace-only stems', () {
      expect(AttachmentFilename.validate(''), AttachmentNameError.blank);
      expect(AttachmentFilename.validate('   '), AttachmentNameError.blank);
    });

    test('rejects every forbidden character', () {
      for (final ch in ['/', r'\', ':', '*', '?', '"', '<', '>', '|']) {
        expect(
          AttachmentFilename.validate('map${ch}1'),
          AttachmentNameError.forbiddenCharacter,
          reason: ch,
        );
      }
    });

    test('rejects control characters', () {
      expect(
        AttachmentFilename.validate('map${String.fromCharCode(9)}1'),
        AttachmentNameError.forbiddenCharacter,
      );
    });
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/media/domain/entities/site_attachment_category_test.dart test/features/media/domain/value_objects/attachment_filename_test.dart`
Expected: FAIL, the imported files do not exist.

- [ ] **Step 4: Implement the enums**

`lib/features/media/domain/entities/site_attachment_category.dart`:

```dart
/// How large a site attachment renders on the site page (issue #1039).
enum AttachmentDisplaySize {
  large('large'),
  tile('tile');

  const AttachmentDisplaySize(this.storageKey);

  /// Value stored in `media.display_size`.
  final String storageKey;

  /// The size stored as [key], or null for an absent or unknown key.
  static AttachmentDisplaySize? fromStorageKey(String? key) {
    for (final size in values) {
      if (size.storageKey == key) return size;
    }
    return null;
  }
}

/// Where a site attachment belongs on the site page (issue #1039).
///
/// Declared in display order: the site page lists groups in this order,
/// with uncategorized attachments last.
enum SiteAttachmentCategory {
  siteMap('siteMap', AttachmentDisplaySize.large),
  parking('parking', AttachmentDisplaySize.large),
  access('access', AttachmentDisplaySize.large),
  anchorage('anchorage', AttachmentDisplaySize.large),
  underwater('underwater', AttachmentDisplaySize.tile),
  general('general', AttachmentDisplaySize.large);

  const SiteAttachmentCategory(this.storageKey, this.defaultDisplaySize);

  /// Value stored in `media.site_category`. Stable across languages, so two
  /// devices group the same attachment identically after sync.
  final String storageKey;

  /// Size used when the attachment carries no override.
  final AttachmentDisplaySize defaultDisplaySize;

  /// The category stored as [key], or null for an absent or unknown key.
  ///
  /// A key this version does not know (one a newer app synced in) reads as
  /// uncategorized rather than as some other category.
  static SiteAttachmentCategory? fromStorageKey(String? key) {
    for (final category in values) {
      if (category.storageKey == key) return category;
    }
    return null;
  }
}
```

- [ ] **Step 5: Implement the filename value object**

`lib/features/media/domain/value_objects/attachment_filename.dart`:

```dart
/// Why a proposed attachment name was refused.
enum AttachmentNameError { blank, forbiddenCharacter }

/// An attachment's filename split for renaming (issue #1039): the stem the
/// diver edits and the extension that stays fixed.
///
/// The extension is fixed because the app reads a document's kind from it
/// ([MediaItem.isPdf], the share MIME type), so a rename must not be able to
/// turn a PDF into an unopenable file. The split matches
/// [MediaItem.documentExtension]: on the last dot, with a trailing dot
/// counting as part of the stem.
class AttachmentFilename {
  const AttachmentFilename({required this.stem, required this.extension});

  factory AttachmentFilename.split(String? name) {
    if (name == null) return const AttachmentFilename(stem: '', extension: '');
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return AttachmentFilename(stem: name, extension: '');
    }
    return AttachmentFilename(
      stem: name.substring(0, dot),
      extension: name.substring(dot + 1),
    );
  }

  /// The editable part.
  final String stem;

  /// The fixed part, without the dot and in its original case; '' when the
  /// name has none.
  final String extension;

  /// [newStem], trimmed, with this name's extension re-attached.
  String compose(String newStem) {
    final trimmed = newStem.trim();
    return extension.isEmpty ? trimmed : '$trimmed.$extension';
  }

  /// Characters no common filesystem accepts in a name. The name becomes a
  /// temp file when the attachment is shared, on whatever device it has
  /// synced to, so the strictest platform (Windows) sets the list.
  static final _forbidden = RegExp(r'[/\\:*?"<>|]');

  /// Why [stem] cannot be saved, or null when it can.
  static AttachmentNameError? validate(String stem) {
    final trimmed = stem.trim();
    if (trimmed.isEmpty) return AttachmentNameError.blank;
    if (_forbidden.hasMatch(trimmed) ||
        trimmed.codeUnits.any((unit) => unit < 0x20)) {
      return AttachmentNameError.forbiddenCharacter;
    }
    return null;
  }
}
```

- [ ] **Step 6: Run both tests to verify they pass**

Run: `flutter test test/features/media/domain/entities/site_attachment_category_test.dart test/features/media/domain/value_objects/attachment_filename_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media/domain test/features/media/domain
git add lib/features/media/domain/entities/site_attachment_category.dart lib/features/media/domain/value_objects/attachment_filename.dart test/features/media/domain/entities/site_attachment_category_test.dart test/features/media/domain/value_objects/attachment_filename_test.dart
git commit -m "feat(media): add site attachment category, size and filename types"
```

---

### Task 2: MediaItem fields and the edit value object

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart` (fields near line 131, constructor near 179, `copyWith` near 286 and 423, `props` near 477)
- Create: `lib/features/media/domain/value_objects/attachment_details_edit.dart`
- Test: `test/features/media/domain/entities/media_item_site_attachment_test.dart`
- Test: `test/features/media/domain/value_objects/attachment_details_edit_test.dart`

**Interfaces:**
- Consumes: Task 1 enums and `AttachmentFilename`.
- Produces: `MediaItem.siteCategory` (`SiteAttachmentCategory?`), `MediaItem.displaySizeOverride` (`AttachmentDisplaySize?`), `MediaItem.effectiveDisplaySize` (`AttachmentDisplaySize`), `copyWith(siteCategory:, displaySizeOverride:)`.
- Produces: `final class FieldChange<T> { final T value; }`; `class AttachmentDetailsEdit { FieldChange<String?>? filename; FieldChange<SiteAttachmentCategory?>? category; FieldChange<AttachmentDisplaySize?>? displaySize; bool get isEmpty; MediaItem applyTo(MediaItem); }`; `AttachmentDetailsEdit diffAttachmentDetails(MediaItem item, {required String stem, required SiteAttachmentCategory? category, required AttachmentDisplaySize? displaySize})`; `AttachmentNameError? attachmentNameError(MediaItem item, String stem)`.

- [ ] **Step 1: Write the failing MediaItem test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

void main() {
  final base = MediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('effectiveDisplaySize', () {
    test('uncategorized with no override is a tile', () {
      expect(base.effectiveDisplaySize, AttachmentDisplaySize.tile);
    });

    test('follows the category default when there is no override', () {
      expect(
        base.copyWith(siteCategory: SiteAttachmentCategory.siteMap)
            .effectiveDisplaySize,
        AttachmentDisplaySize.large,
      );
      expect(
        base.copyWith(siteCategory: SiteAttachmentCategory.underwater)
            .effectiveDisplaySize,
        AttachmentDisplaySize.tile,
      );
    });

    test('an override wins in both directions', () {
      expect(
        base
            .copyWith(
              siteCategory: SiteAttachmentCategory.siteMap,
              displaySizeOverride: AttachmentDisplaySize.tile,
            )
            .effectiveDisplaySize,
        AttachmentDisplaySize.tile,
      );
      expect(
        base
            .copyWith(displaySizeOverride: AttachmentDisplaySize.large)
            .effectiveDisplaySize,
        AttachmentDisplaySize.large,
      );
    });
  });

  test('copyWith can clear both fields back to null', () {
    final set = base.copyWith(
      siteCategory: SiteAttachmentCategory.parking,
      displaySizeOverride: AttachmentDisplaySize.large,
    );
    final cleared = set.copyWith(siteCategory: null, displaySizeOverride: null);
    expect(cleared.siteCategory, isNull);
    expect(cleared.displaySizeOverride, isNull);
  });

  test('copyWith without the fields keeps them', () {
    final set = base.copyWith(siteCategory: SiteAttachmentCategory.access);
    expect(set.copyWith(caption: 'x').siteCategory,
        SiteAttachmentCategory.access);
  });

  test('both fields take part in equality', () {
    expect(base.copyWith(siteCategory: SiteAttachmentCategory.general),
        isNot(base));
    expect(base.copyWith(displaySizeOverride: AttachmentDisplaySize.tile),
        isNot(base));
  });
}
```

- [ ] **Step 2: Write the failing edit test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

void main() {
  MediaItem item({String? name = 'map.pdf'}) => MediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: name,
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('diffAttachmentDetails', () {
    test('nothing changed is an empty edit', () {
      final edit = diffAttachmentDetails(
        item(),
        stem: 'map',
        category: null,
        displaySize: null,
      );
      expect(edit.isEmpty, isTrue);
    });

    test('a new stem becomes a filename change with the extension kept', () {
      final edit = diffAttachmentDetails(
        item(),
        stem: ' Reef map ',
        category: null,
        displaySize: null,
      );
      expect(edit.filename!.value, 'Reef map.pdf');
      expect(edit.category, isNull);
      expect(edit.displaySize, isNull);
    });

    test('category and size changes are carried, including a clear', () {
      final categorized = item().copyWith(
        siteCategory: SiteAttachmentCategory.parking,
        displaySizeOverride: AttachmentDisplaySize.tile,
      );
      final edit = diffAttachmentDetails(
        categorized,
        stem: 'map',
        category: SiteAttachmentCategory.siteMap,
        displaySize: null,
      );
      expect(edit.filename, isNull);
      expect(edit.category!.value, SiteAttachmentCategory.siteMap);
      expect(edit.displaySize, isNotNull);
      expect(edit.displaySize!.value, isNull);
    });

    test('a nameless item left blank keeps no name', () {
      final edit = diffAttachmentDetails(
        item(name: null),
        stem: '',
        category: SiteAttachmentCategory.general,
        displaySize: null,
      );
      expect(edit.filename, isNull);
      expect(edit.category!.value, SiteAttachmentCategory.general);
    });

    test('a nameless item given a name gets that name', () {
      final edit = diffAttachmentDetails(
        item(name: null),
        stem: 'Entry steps',
        category: null,
        displaySize: null,
      );
      expect(edit.filename!.value, 'Entry steps');
    });
  });

  group('attachmentNameError', () {
    test('a named item may not be blanked', () {
      expect(attachmentNameError(item(), '  '), AttachmentNameError.blank);
    });

    test('a nameless item may stay blank', () {
      expect(attachmentNameError(item(name: null), ''), isNull);
      expect(attachmentNameError(item(name: '  '), ''), isNull);
    });

    test('forbidden characters are refused either way', () {
      expect(attachmentNameError(item(name: null), 'a/b'),
          AttachmentNameError.forbiddenCharacter);
    });
  });

  test('applyTo writes only the carried fields', () {
    final before = item().copyWith(
      siteCategory: SiteAttachmentCategory.access,
    );
    final after = const AttachmentDetailsEdit(
      displaySize: FieldChange(AttachmentDisplaySize.large),
    ).applyTo(before);
    expect(after.siteCategory, SiteAttachmentCategory.access);
    expect(after.displaySizeOverride, AttachmentDisplaySize.large);
    expect(after.originalFilename, 'map.pdf');
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/media/domain/entities/media_item_site_attachment_test.dart test/features/media/domain/value_objects/attachment_details_edit_test.dart`
Expected: FAIL, `siteCategory` is not a `copyWith` parameter and the edit file is missing.

- [ ] **Step 4: Add the fields to MediaItem**

In `media_item.dart`, import `site_attachment_category.dart`. After `final int? manualElapsedSeconds;` add:

```dart
  /// Where this attachment belongs on its site's page (issue #1039). Null is
  /// uncategorized. Only site attachments are categorized today, but the
  /// column is generic.
  final SiteAttachmentCategory? siteCategory;

  /// The diver's size choice for this attachment, or null to follow
  /// [siteCategory]'s default (issue #1039).
  final AttachmentDisplaySize? displaySizeOverride;
```

Constructor, after `this.manualElapsedSeconds,`:

```dart
    this.siteCategory,
    this.displaySizeOverride,
```

Getter, after `isPdf`:

```dart
  /// How large this attachment renders on the site page: the override when
  /// set, else the category default, else a tile.
  AttachmentDisplaySize get effectiveDisplaySize =>
      displaySizeOverride ??
      siteCategory?.defaultDisplaySize ??
      AttachmentDisplaySize.tile;
```

`copyWith` parameters, after `Object? manualElapsedSeconds = _undefined,`:

```dart
    Object? siteCategory = _undefined,
    Object? displaySizeOverride = _undefined,
```

`copyWith` body, after the `manualElapsedSeconds:` argument:

```dart
      siteCategory: siteCategory == _undefined
          ? this.siteCategory
          : siteCategory as SiteAttachmentCategory?,
      displaySizeOverride: displaySizeOverride == _undefined
          ? this.displaySizeOverride
          : displaySizeOverride as AttachmentDisplaySize?,
```

`props`, after `manualElapsedSeconds,`:

```dart
    siteCategory,
    displaySizeOverride,
```

- [ ] **Step 5: Implement the edit value object**

`lib/features/media/domain/value_objects/attachment_details_edit.dart`:

```dart
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

/// One field of an [AttachmentDetailsEdit]: write [value], which may itself
/// be null to clear the field.
final class FieldChange<T> {
  const FieldChange(this.value);

  final T value;
}

/// The fields an Edit details save changes (issue #1039). A null member is
/// left untouched, so a save writes only what the diver changed.
class AttachmentDetailsEdit {
  const AttachmentDetailsEdit({this.filename, this.category, this.displaySize});

  final FieldChange<String?>? filename;
  final FieldChange<SiteAttachmentCategory?>? category;
  final FieldChange<AttachmentDisplaySize?>? displaySize;

  bool get isEmpty =>
      filename == null && category == null && displaySize == null;

  /// [item] with this edit applied, for showing the saved state before the
  /// list reloads.
  MediaItem applyTo(MediaItem item) => item.copyWith(
    originalFilename: filename == null
        ? item.originalFilename
        : filename!.value,
    siteCategory: category == null ? item.siteCategory : category!.value,
    displaySizeOverride: displaySize == null
        ? item.displaySizeOverride
        : displaySize!.value,
  );
}

bool _hasName(MediaItem item) =>
    (item.originalFilename ?? '').trim().isNotEmpty;

/// Why [stem] cannot be saved as [item]'s new name, or null when it can.
///
/// A blank field is fine for an item that never had a name (some gallery
/// rows store none): it simply stays unnamed, so the diver can still
/// categorize it.
AttachmentNameError? attachmentNameError(MediaItem item, String stem) {
  if (!_hasName(item) && stem.trim().isEmpty) return null;
  return AttachmentFilename.validate(stem);
}

/// The edit that takes [item] to the sheet's current values.
AttachmentDetailsEdit diffAttachmentDetails(
  MediaItem item, {
  required String stem,
  required SiteAttachmentCategory? category,
  required AttachmentDisplaySize? displaySize,
}) {
  FieldChange<String?>? filename;
  if (_hasName(item) || stem.trim().isNotEmpty) {
    final composed = AttachmentFilename.split(
      item.originalFilename,
    ).compose(stem);
    if (composed != item.originalFilename) filename = FieldChange(composed);
  }
  return AttachmentDetailsEdit(
    filename: filename,
    category: category == item.siteCategory ? null : FieldChange(category),
    displaySize: displaySize == item.displaySizeOverride
        ? null
        : FieldChange(displaySize),
  );
}
```

- [ ] **Step 6: Run both tests to verify they pass**

Run: `flutter test test/features/media/domain/entities/media_item_site_attachment_test.dart test/features/media/domain/value_objects/attachment_details_edit_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media/domain test/features/media/domain
git add lib/features/media/domain test/features/media/domain
git commit -m "feat(media): carry site category and size override on media items"
```

---

### Task 3: Schema v261

**Files:**
- Modify: `lib/core/database/tables/media_tables.dart` (after `manualElapsedSeconds`, near line 97)
- Modify: `lib/core/database/migrations/helpers/media_migrations.dart` (after `_assertMediaManualElapsedColumn`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v260 block)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v164 media backstop, near line 395)
- Modify: `lib/core/database/database.dart:235` and the `migrationVersions` list end (near line 1084)
- Modify: `test/core/database/migration_v260_tank_shared_computers_test.dart:8-14`
- Test: `test/core/database/migration_v261_media_site_attachment_test.dart`

**Interfaces:**
- Produces: Drift columns `Media.siteCategory` (`site_category TEXT NULL`) and `Media.displaySize` (`display_size TEXT NULL`); generated `MediaData.siteCategory`, `MediaData.displaySize`, `MediaCompanion.siteCategory`, `MediaCompanion.displaySize` (all `String?`).

- [ ] **Step 1: Write the failing migration test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v261: media.site_category and media.display_size, a site
/// attachment's category and size override (issue #1039).
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE media (id TEXT NOT NULL PRIMARY KEY, '
        "file_path TEXT NOT NULL DEFAULT '', original_filename TEXT)",
      );
      rawDb.execute(
        "INSERT INTO media (id, original_filename) VALUES ('m1', 'map.pdf')",
      );
    },
  );

  test('v261 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(AppDatabase.migrationStepCount(260), 1);
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v260 adds both columns as null and keeps the row',
      () async {
    final db = AppDatabase(dbAt(260));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT original_filename, site_category, display_size FROM media',
        )
        .getSingle();
    expect(row.read<String>('original_filename'), 'map.pdf');
    expect(row.read<String?>('site_category'), isNull);
    expect(row.read<String?>('display_size'), isNull);
  });

  test('beforeOpen heals a database already at v261 that lacks them',
      () async {
    final db = AppDatabase(dbAt(261));
    addTearDown(db.close);
    final names = (await db.customSelect("PRAGMA table_info('media')").get())
        .map((c) => c.read<String>('name'))
        .toSet();
    expect(names, containsAll(['site_category', 'display_size']));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v261_media_site_attachment_test.dart`
Expected: FAIL, current version is 260 and `site_category` does not exist.

- [ ] **Step 3: Add the table columns**

In `media_tables.dart`, after the `manualElapsedSeconds` getter:

```dart
  /// Site attachment category key (issue #1039), one of
  /// SiteAttachmentCategory's storage keys; null is uncategorized.
  TextColumn get siteCategory => text().nullable()();

  /// 'large' or 'tile' (issue #1039); null follows the category default.
  TextColumn get displaySize => text().nullable()();
```

- [ ] **Step 4: Add the idempotent helper**

In `media_migrations.dart`, after `_assertMediaManualElapsedColumn`:

```dart
  /// v261: media.site_category and media.display_size (issue #1039).
  /// Idempotent; called from the rung and the beforeOpen backstop. Both are
  /// nullable with no default, so every existing row reads back as an
  /// uncategorized attachment at its default size, a tile, which is how it
  /// already renders.
  Future<void> _assertMediaSiteAttachmentColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('site_category')) {
      await customStatement('ALTER TABLE media ADD COLUMN site_category TEXT');
    }
    if (!names.contains('display_size')) {
      await customStatement('ALTER TABLE media ADD COLUMN display_size TEXT');
    }
  }
```

- [ ] **Step 5: Add the rung, the backstop and the version**

In `rungs_v231_onward.dart`, after `if (from < 260) await reportProgress();`:

```dart
    // v261: media.site_category and media.display_size (issue #1039).
    // Columns only, no backfill: null is an uncategorized tile, which is how
    // every existing attachment already renders. Re-asserted in beforeOpen.
    if (from < 261) {
      await _assertMediaSiteAttachmentColumns();
    }
    if (from < 261) await reportProgress();
```

In `before_open.dart`, after `await _assertMediaManualElapsedColumn();`:

```dart
    // v261 backstop: re-assert media.site_category and media.display_size
    // (issue #1039). The media row mapper reads both on every hydration.
    await _assertMediaSiteAttachmentColumns();
```

In `database.dart`: `static const int currentSchemaVersion = 261;` and append `261,` after `260,` in `migrationVersions`.

- [ ] **Step 6: Relax the previous newest-rung tripwire**

In `migration_v260_tank_shared_computers_test.dart`, replace the first test with:

```dart
  test('v260 is at or below the current schema version and in the ladder', () {
    // Relaxed once v261 (media site attachment columns, #1039) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(260));
    expect(AppDatabase.migrationVersions, contains(260));
    expect(
      AppDatabase.migrationStepCount(259),
      AppDatabase.migrationStepCount(260) + 1,
    );
  });
```

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs` (if a bare word in the command is refused, put the command in a scratchpad script and run the script).
Expected: completes; `grep -n "siteCategory" lib/core/database/*.g.dart` finds the generated column.

- [ ] **Step 8: Find stale "ladder finished" literals**

Run: `grep -rln "user_version = 260\|, 260)\|== 260" test`
For each hit outside `migration_v260_*`, if the literal means "the ladder ran to completion", replace it with `AppDatabase.currentSchemaVersion`. Leave assertions about v260 specifically.

- [ ] **Step 9: Run the migration tests**

Run: `flutter test test/core/database/migration_v261_media_site_attachment_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/core/database/migration_v259_tank_usage_duration_test.dart test/core/database/migration_v164_media_manual_elapsed_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database
git commit -m "feat(media): add site category and display size columns (schema v261)"
```

---

### Task 4: Row mapping, whole-row writes, and the narrow writers

**Files:**
- Modify: `lib/features/media/data/repositories/media_row_mapper.dart` (after `manualElapsedSeconds:`)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`createMedia` and `updateMedia` companions, after `manualElapsedSeconds:`)
- Create: `lib/features/media/data/repositories/site_attachment_repository.dart`
- Test: `test/features/media/data/repositories/site_attachment_repository_test.dart`
- Test: `test/features/media/two_device/site_attachment_sync_test.dart`

**Interfaces:**
- Consumes: Task 2 `AttachmentDetailsEdit`, Task 3 columns.
- Produces: `class SiteAttachmentRepository { Future<void> setAttachmentDetails(String id, AttachmentDetailsEdit edit); Future<void> setSiteCategory(List<String> ids, SiteAttachmentCategory? category); }`.

- [ ] **Step 1: Write the failing repository test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1039: a site attachment's category, size and name are user edits
/// on the media row, written narrowly so a stale snapshot cannot clobber
/// any other column.
void main() {
  late AppDatabase db;
  late MediaRepository media;
  late SiteAttachmentRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    media = MediaRepository();
    repository = SiteAttachmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  MediaItem item({String name = 'map.pdf', String? caption}) {
    final now = DateTime.utc(2026, 1, 1, 10);
    return MediaItem(
      id: '',
      filePath: '/docs/$name',
      originalFilename: name,
      mediaType: MediaType.document,
      caption: caption,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> clearPending(String id) => (db.delete(
    db.syncRecords,
  )..where((t) => t.recordId.equals(id))).go();

  Future<List<String>> statuses(String id) async =>
      (await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(id))).get())
          .map((r) => r.syncStatus)
          .toList();

  test('createMedia and updateMedia round-trip both fields', () async {
    final created = await media.createMedia(
      item().copyWith(
        siteCategory: SiteAttachmentCategory.siteMap,
        displaySizeOverride: AttachmentDisplaySize.tile,
      ),
    );
    var fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, SiteAttachmentCategory.siteMap);
    expect(fetched.displaySizeOverride, AttachmentDisplaySize.tile);

    await media.updateMedia(
      fetched.copyWith(
        siteCategory: SiteAttachmentCategory.parking,
        displaySizeOverride: null,
      ),
    );
    fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, SiteAttachmentCategory.parking);
    expect(fetched.displaySizeOverride, isNull);
  });

  test('an unknown stored key hydrates as uncategorized', () async {
    final created = await media.createMedia(item());
    await db.customStatement(
      "UPDATE media SET site_category = 'boatRamp', display_size = 'huge' "
      "WHERE id = '${created.id}'",
    );
    final fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, isNull);
    expect(fetched.displaySizeOverride, isNull);
  });

  group('setAttachmentDetails', () {
    test('writes only the carried fields and marks the row pending',
        () async {
      final created = await media.createMedia(item(caption: 'keep me'));
      await clearPending(created.id);

      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(
          filename: FieldChange('North wall.pdf'),
          category: FieldChange(SiteAttachmentCategory.access),
        ),
      );

      final fetched = (await media.getMediaById(created.id))!;
      expect(fetched.originalFilename, 'North wall.pdf');
      expect(fetched.siteCategory, SiteAttachmentCategory.access);
      expect(fetched.displaySizeOverride, isNull);
      expect(fetched.caption, 'keep me');
      expect(await statuses(created.id), ['pending']);
    });

    test('a FieldChange of null clears the field', () async {
      final created = await media.createMedia(
        item().copyWith(displaySizeOverride: AttachmentDisplaySize.large),
      );
      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(displaySize: FieldChange(null)),
      );
      expect(
        (await media.getMediaById(created.id))!.displaySizeOverride,
        isNull,
      );
    });

    test('an empty edit writes nothing and queues nothing', () async {
      final created = await media.createMedia(item());
      await clearPending(created.id);
      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(),
      );
      expect(await statuses(created.id), isEmpty);
    });

    test('a row that no longer exists throws and queues nothing', () async {
      await expectLater(
        repository.setAttachmentDetails(
          'gone',
          const AttachmentDetailsEdit(
            category: FieldChange(SiteAttachmentCategory.general),
          ),
        ),
        throwsStateError,
      );
      expect(await statuses('gone'), isEmpty);
    });
  });

  group('setSiteCategory', () {
    test('sets every id, leaves overrides and names, marks each pending',
        () async {
      final a = await media.createMedia(
        item(name: 'a.jpg').copyWith(
          displaySizeOverride: AttachmentDisplaySize.large,
        ),
      );
      final b = await media.createMedia(item(name: 'b.jpg'));
      await clearPending(a.id);
      await clearPending(b.id);

      await repository.setSiteCategory(
        [a.id, b.id],
        SiteAttachmentCategory.underwater,
      );

      final fa = (await media.getMediaById(a.id))!;
      final fb = (await media.getMediaById(b.id))!;
      expect(fa.siteCategory, SiteAttachmentCategory.underwater);
      expect(fb.siteCategory, SiteAttachmentCategory.underwater);
      expect(fa.displaySizeOverride, AttachmentDisplaySize.large);
      expect(fa.originalFilename, 'a.jpg');
      expect(await statuses(a.id), ['pending']);
      expect(await statuses(b.id), ['pending']);
    });

    test('null uncategorizes', () async {
      final a = await media.createMedia(
        item().copyWith(siteCategory: SiteAttachmentCategory.parking),
      );
      await repository.setSiteCategory([a.id], null);
      expect((await media.getMediaById(a.id))!.siteCategory, isNull);
    });

    test('an empty id list is a no-op', () async {
      await repository.setSiteCategory(const [], SiteAttachmentCategory.general);
    });
  });
}
```

- [ ] **Step 2: Write the failing two-device sync test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

import '../../../helpers/two_device_media_harness.dart';

/// Issue #1039: category, size override and a rename travel with the media
/// row to the other device.
void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(512, (i) => (i * 7) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test('an edit on A arrives on B', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive, name: 'map.jpg');
    await h.a.sync();
    await h.b.sync();

    await h.a.activate();
    await SiteAttachmentRepository().setAttachmentDetails(
      id,
      const AttachmentDetailsEdit(
        filename: FieldChange('Reef map.jpg'),
        category: FieldChange(SiteAttachmentCategory.siteMap),
        displaySize: FieldChange(AttachmentDisplaySize.tile),
      ),
    );
    await h.a.sync();
    await h.b.sync();

    final onB = (await h.b.media(id))!;
    expect(onB.originalFilename, 'Reef map.jpg');
    expect(onB.siteCategory, SiteAttachmentCategory.siteMap);
    expect(onB.displaySizeOverride, AttachmentDisplaySize.tile);
  });
}
```

If `activate()` is private in the harness, add a public `Future<void> run(Future<void> Function() body)` helper to `HarnessDevice` that calls `activate()` then `body()`, and use it here.

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/media/data/repositories/site_attachment_repository_test.dart test/features/media/two_device/site_attachment_sync_test.dart`
Expected: FAIL, `SiteAttachmentRepository` does not exist.

- [ ] **Step 4: Map the columns and carry them on whole-row writes**

`media_row_mapper.dart`, import `site_attachment_category.dart`, and after `manualElapsedSeconds: row.manualElapsedSeconds,`:

```dart
    siteCategory: SiteAttachmentCategory.fromStorageKey(row.siteCategory),
    displaySizeOverride: AttachmentDisplaySize.fromStorageKey(row.displaySize),
```

`media_repository.dart`, in both the `createMedia` and `updateMedia` companions after `manualElapsedSeconds: Value(item.manualElapsedSeconds),`:

```dart
              siteCategory: Value(item.siteCategory?.storageKey),
              displaySize: Value(item.displaySizeOverride?.storageKey),
```

(match each block's indentation).

- [ ] **Step 5: Implement the narrow writers**

`lib/features/media/data/repositories/site_attachment_repository.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

/// Writes a site attachment's user-editable details (issue #1039): its
/// name, category and size override.
///
/// Narrow writers, like [MediaRepository.setManualElapsedSeconds]: each
/// writes only its own columns plus updatedAt and takes the row clock, so a
/// stale snapshot cannot roll back an upload stamp or a verification verdict
/// that landed in between. Kept out of MediaRepository, which is already far
/// past the file-size ceiling.
class SiteAttachmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(SiteAttachmentRepository);

  /// Applies [edit] to media row [id].
  ///
  /// Throws [StateError] when the row no longer exists (unlinked, or
  /// deleted by a sync, while the sheet was open), so the caller reports a
  /// failure instead of a sync record being queued for a missing row.
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    if (edit.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final written =
            await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
              MediaCompanion(
                originalFilename: edit.filename == null
                    ? const Value.absent()
                    : Value(edit.filename!.value),
                siteCategory: edit.category == null
                    ? const Value.absent()
                    : Value(edit.category!.value?.storageKey),
                displaySize: edit.displaySize == null
                    ? const Value.absent()
                    : Value(edit.displaySize!.value?.storageKey),
                updatedAt: Value(now),
              ),
            );
        if (written == 0) {
          throw StateError('Media $id no longer exists');
        }
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Set attachment details for media $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set attachment details for media: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Puts every row in [ids] into [category] (null uncategorizes), leaving
  /// each row's size override and name alone. One transaction, so a bulk
  /// assignment never lands half-done.
  Future<void> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    if (ids.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        await (_db.update(_db.media)..where((t) => t.id.isIn(ids))).write(
          MediaCompanion(
            siteCategory: Value(category?.storageKey),
            updatedAt: Value(now),
          ),
        );
        for (final id in ids) {
          await _syncRepository.markRecordPending(
            entityType: 'media',
            recordId: id,
            localUpdatedAt: now,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Set site category ${category?.storageKey} on ${ids.length}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set site category on ${ids.length} media',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

Site selections are small (one site's attachments), so a single `isIn` stays far under SQLite's bound-variable ceiling.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/media/data/repositories/site_attachment_repository_test.dart test/features/media/two_device/site_attachment_sync_test.dart test/features/media/data/repositories/media_repository_manual_elapsed_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media/data test/features/media test/helpers
git add lib/features/media/data test/features/media/data/repositories/site_attachment_repository_test.dart test/features/media/two_device/site_attachment_sync_test.dart test/helpers/two_device_media_harness.dart
git commit -m "feat(media): persist and sync site attachment details"
```

---

### Task 5: Notifier wiring

**Files:**
- Modify: `lib/features/media/presentation/providers/site_media_providers.dart`
- Test: `test/features/media/presentation/providers/site_media_list_notifier_details_test.dart`

**Interfaces:**
- Consumes: Task 4 `SiteAttachmentRepository`.
- Produces: `final siteAttachmentRepositoryProvider = Provider<SiteAttachmentRepository>`; `SiteMediaListNotifier.setAttachmentDetails(String id, AttachmentDetailsEdit edit)`; `SiteMediaListNotifier.setSiteCategory(List<String> ids, SiteAttachmentCategory? category)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';

class _StubMediaRepository extends MediaRepository {
  int loads = 0;

  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async {
    loads++;
    return const <MediaItem>[];
  }
}

class _RecordingSiteAttachmentRepository extends SiteAttachmentRepository {
  final details = <(String, AttachmentDetailsEdit)>[];
  final categories = <(List<String>, SiteAttachmentCategory?)>[];

  @override
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async => details.add((id, edit));

  @override
  Future<void> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async => categories.add((ids, category));
}

void main() {
  late _StubMediaRepository media;
  late _RecordingSiteAttachmentRepository attachments;
  late ProviderContainer container;

  setUp(() {
    media = _StubMediaRepository();
    attachments = _RecordingSiteAttachmentRepository();
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(media),
        siteAttachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);
  });

  test('setAttachmentDetails delegates, then reloads', () async {
    final notifier = container.read(
      siteMediaListNotifierProvider('s1').notifier,
    );
    final loadsBefore = media.loads;
    const edit = AttachmentDetailsEdit(
      category: FieldChange(SiteAttachmentCategory.parking),
    );
    await notifier.setAttachmentDetails('m1', edit);
    expect(attachments.details.single.$1, 'm1');
    expect(attachments.details.single.$2, same(edit));
    expect(media.loads, greaterThan(loadsBefore));
  });

  test('setSiteCategory delegates, then reloads', () async {
    final notifier = container.read(
      siteMediaListNotifierProvider('s1').notifier,
    );
    final loadsBefore = media.loads;
    await notifier.setSiteCategory(['a', 'b'], null);
    expect(attachments.categories.single.$1, ['a', 'b']);
    expect(attachments.categories.single.$2, isNull);
    expect(media.loads, greaterThan(loadsBefore));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/presentation/providers/site_media_list_notifier_details_test.dart`
Expected: FAIL, `siteAttachmentRepositoryProvider` is undefined.

- [ ] **Step 3: Implement**

In `site_media_providers.dart`, import `site_attachment_repository.dart`, `site_attachment_category.dart` and `attachment_details_edit.dart`, then add above `SiteMediaListNotifier`:

```dart
/// Narrow writers for a site attachment's name, category and size
/// (issue #1039).
final siteAttachmentRepositoryProvider = Provider<SiteAttachmentRepository>(
  (ref) => SiteAttachmentRepository(),
);
```

Inside `SiteMediaListNotifier`, after `updateMedia`:

```dart
  /// Saves an Edit details sheet: only the fields [edit] carries.
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    await _ref
        .read(siteAttachmentRepositoryProvider)
        .setAttachmentDetails(id, edit);
    await refresh();
    _ref.invalidate(mediaByIdProvider(id));
  }

  /// Puts every attachment in [ids] into [category]; null uncategorizes.
  Future<void> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    await _ref
        .read(siteAttachmentRepositoryProvider)
        .setSiteCategory(ids, category);
    await refresh();
  }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/media/presentation/providers/site_media_list_notifier_details_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/providers test/features/media/presentation/providers
git add lib/features/media/presentation/providers/site_media_providers.dart test/features/media/presentation/providers/site_media_list_notifier_details_test.dart
git commit -m "feat(media): expose attachment detail edits on the site media notifier"
```

---

### Task 6: Attachment layout

**Files:**
- Create: `lib/features/media/domain/services/site_attachment_layout.dart`
- Test: `test/features/media/domain/services/site_attachment_layout_test.dart`

**Interfaces:**
- Consumes: Task 2 `MediaItem.siteCategory`, `effectiveDisplaySize`.
- Produces: `class SiteAttachmentGroup { SiteAttachmentCategory? category; List<MediaItem> large; List<MediaItem> tiles; }`; `class SiteAttachmentLayout { List<SiteAttachmentGroup> groups; bool showHeadings; }`; `SiteAttachmentLayout layoutSiteAttachments(List<MediaItem> attachments)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';

void main() {
  MediaItem m(
    String id,
    int minute, {
    SiteAttachmentCategory? category,
    AttachmentDisplaySize? size,
  }) => MediaItem(
    id: id,
    siteId: 's1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 1, 1, 10, minute),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    siteCategory: category,
    displaySizeOverride: size,
  );

  test('nothing attached is no groups and no headings', () {
    final layout = layoutSiteAttachments(const []);
    expect(layout.groups, isEmpty);
    expect(layout.showHeadings, isFalse);
  });

  test('all uncategorized is one headless group of tiles, as before', () {
    final layout = layoutSiteAttachments([m('b', 2), m('a', 1)]);
    expect(layout.showHeadings, isFalse);
    expect(layout.groups.single.category, isNull);
    expect(layout.groups.single.large, isEmpty);
    expect(layout.groups.single.tiles.map((i) => i.id), ['a', 'b']);
  });

  test('groups follow category order with uncategorized last', () {
    final layout = layoutSiteAttachments([
      m('u', 1),
      m('g', 2, category: SiteAttachmentCategory.general),
      m('w', 3, category: SiteAttachmentCategory.underwater),
      m('s', 4, category: SiteAttachmentCategory.siteMap),
    ]);
    expect(layout.showHeadings, isTrue);
    expect(layout.groups.map((g) => g.category), [
      SiteAttachmentCategory.siteMap,
      SiteAttachmentCategory.underwater,
      SiteAttachmentCategory.general,
      null,
    ]);
  });

  test('within a group large and tile items split, each in time order', () {
    final layout = layoutSiteAttachments([
      m('t2', 4, category: SiteAttachmentCategory.siteMap,
          size: AttachmentDisplaySize.tile),
      m('l2', 3, category: SiteAttachmentCategory.siteMap),
      m('t1', 2, category: SiteAttachmentCategory.siteMap,
          size: AttachmentDisplaySize.tile),
      m('l1', 1, category: SiteAttachmentCategory.siteMap),
    ]);
    final group = layout.groups.single;
    expect(group.large.map((i) => i.id), ['l1', 'l2']);
    expect(group.tiles.map((i) => i.id), ['t1', 't2']);
  });

  test('an uncategorized item can be forced large', () {
    final layout = layoutSiteAttachments([
      m('a', 1, size: AttachmentDisplaySize.large),
    ]);
    expect(layout.groups.single.large.map((i) => i.id), ['a']);
  });

  test('equal capture times tie-break on id, so order is stable', () {
    final layout = layoutSiteAttachments([m('b', 1), m('a', 1)]);
    expect(layout.groups.single.tiles.map((i) => i.id), ['a', 'b']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/domain/services/site_attachment_layout_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

`lib/features/media/domain/services/site_attachment_layout.dart`:

```dart
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

/// One category's attachments on the site page (issue #1039).
class SiteAttachmentGroup {
  const SiteAttachmentGroup({
    required this.category,
    required this.large,
    required this.tiles,
  });

  /// Null for the uncategorized group.
  final SiteAttachmentCategory? category;

  /// Full-width items, in capture order.
  final List<MediaItem> large;

  /// Grid items, in capture order.
  final List<MediaItem> tiles;
}

/// A site's attachments arranged for display.
class SiteAttachmentLayout {
  const SiteAttachmentLayout({
    required this.groups,
    required this.showHeadings,
  });

  /// Non-empty groups in category order, uncategorized last.
  final List<SiteAttachmentGroup> groups;

  /// False when nothing is categorized, so a site nobody has categorized
  /// looks as it did before categories existed.
  final bool showHeadings;
}

int _byCaptureThenId(MediaItem a, MediaItem b) {
  final byTime = a.takenAt.compareTo(b.takenAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Arranges [attachments] into category groups, each split into large items
/// and tiles by [MediaItem.effectiveDisplaySize].
SiteAttachmentLayout layoutSiteAttachments(List<MediaItem> attachments) {
  final order = <SiteAttachmentCategory?>[
    ...SiteAttachmentCategory.values,
    null,
  ];
  final groups = <SiteAttachmentGroup>[];
  for (final category in order) {
    final members =
        attachments.where((m) => m.siteCategory == category).toList()
          ..sort(_byCaptureThenId);
    if (members.isEmpty) continue;
    groups.add(
      SiteAttachmentGroup(
        category: category,
        large: [
          for (final m in members)
            if (m.effectiveDisplaySize == AttachmentDisplaySize.large) m,
        ],
        tiles: [
          for (final m in members)
            if (m.effectiveDisplaySize == AttachmentDisplaySize.tile) m,
        ],
      ),
    );
  }
  return SiteAttachmentLayout(
    groups: groups,
    showHeadings: groups.any((g) => g.category != null),
  );
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/media/domain/services/site_attachment_layout_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain test/features/media/domain
git add lib/features/media/domain/services/site_attachment_layout.dart test/features/media/domain/services/site_attachment_layout_test.dart
git commit -m "feat(media): arrange site attachments into category groups"
```

---

### Task 7: Large PDF page render

**Files:**
- Modify: `lib/features/media/data/services/pdf_page_renderer.dart`
- Modify: `lib/features/media/data/services/pdf_thumbnail_service.dart`
- Create: `lib/features/media/presentation/providers/pdf_preview_providers.dart`
- Test: `test/features/media/data/services/pdf_thumbnail_service_preview_test.dart`
- Test: `test/features/media/presentation/providers/pdf_preview_providers_test.dart`

**Interfaces:**
- Produces: `class PdfPagePreview { final Uint8List jpeg; final int? pageCount; }`; `typedef PdfPreviewRenderer = Future<PdfPagePreview?> Function({File? file, Uint8List? bytes, int maxDimension, int quality})`; `PdfPageRenderer.renderFirstPagePreview` (same parameters).
- Produces: `PdfThumbnailService({..., PdfPreviewRenderer? previewRenderer})`; `Future<PdfPagePreview?> previewFor(MediaItem item, {required int maxDimension, required Future<Uint8List?> Function() bytes})`; `static String previewCacheKeyFor(MediaItem item, int maxDimension)`.
- Produces: `typedef PdfPreviewRequest = ({MediaItem item, int maxDimension})`; `final pdfLargePreviewProvider` (`FutureProvider.autoDispose.family<PdfPagePreview?, PdfPreviewRequest>`); `int pdfPreviewBucket(double logicalWidth, double devicePixelRatio)`.

- [ ] **Step 1: Write the failing service test**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/data/services/pdf_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_preview_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  MediaItem pdf({String name = 'map.pdf'}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.document,
    originalFilename: name,
    contentHash: 'abc',
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final jpeg = Uint8List.fromList([1, 2, 3]);

  PdfThumbnailService service({
    required List<int> sizes,
    PdfPagePreview? result,
    bool throws = false,
  }) => PdfThumbnailService(
    cacheDir: () async => Directory(p.join(tmp.path, 'cache')),
    previewRenderer: ({file, bytes, maxDimension = 0, quality = 0}) async {
      sizes.add(maxDimension);
      if (throws) throw Exception('render failed');
      return result;
    },
  );

  test('renders at the requested size with the page count', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 3),
    );
    final preview = await svc.previewFor(
      pdf(),
      maxDimension: 1536,
      bytes: () async => Uint8List(1),
    );
    expect(sizes, [1536]);
    expect(preview!.jpeg, jpeg);
    expect(preview.pageCount, 3);
  });

  test('a warm cache answers without reading or rendering', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 2),
    );
    await svc.previewFor(pdf(), maxDimension: 1024, bytes: () async => Uint8List(1));
    var reads = 0;
    final again = await svc.previewFor(
      pdf(),
      maxDimension: 1024,
      bytes: () async {
        reads++;
        return Uint8List(1);
      },
    );
    expect(reads, 0);
    expect(sizes, [1024]);
    expect(again!.pageCount, 2);
  });

  test('each size is cached separately', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 1),
    );
    await svc.previewFor(pdf(), maxDimension: 1024, bytes: () async => Uint8List(1));
    await svc.previewFor(pdf(), maxDimension: 2048, bytes: () async => Uint8List(1));
    expect(sizes, [1024, 2048]);
    expect(
      PdfThumbnailService.previewCacheKeyFor(pdf(), 1024),
      isNot(PdfThumbnailService.previewCacheKeyFor(pdf(), 2048)),
    );
  });

  test('a non-PDF, missing bytes, or a failed render is null', () async {
    final sizes = <int>[];
    final ok = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 1),
    );
    expect(
      await ok.previewFor(pdf(name: 'notes.txt'), maxDimension: 1024,
          bytes: () async => Uint8List(1)),
      isNull,
    );
    expect(
      await ok.previewFor(pdf(), maxDimension: 1024, bytes: () async => null),
      isNull,
    );
    final failing = service(sizes: sizes, throws: true);
    expect(
      await failing.previewFor(pdf(), maxDimension: 1024,
          bytes: () async => Uint8List(1)),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Write the failing bucket test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';

void main() {
  test('rounds the physical width up to a cache bucket, capped at 2048', () {
    expect(pdfPreviewBucket(360, 2), 1024);
    expect(pdfPreviewBucket(600, 2), 1536);
    expect(pdfPreviewBucket(700, 2), 2048);
    expect(pdfPreviewBucket(1400, 3), 2048);
    expect(pdfPreviewBucket(0, 1), 1024);
  });
}
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/media/data/services/pdf_thumbnail_service_preview_test.dart test/features/media/presentation/providers/pdf_preview_providers_test.dart`
Expected: FAIL, `PdfPagePreview` and `pdfPreviewBucket` are undefined.

- [ ] **Step 4: Extend the renderer**

In `pdf_page_renderer.dart`, after the `PdfThumbRenderer` typedef add:

```dart
/// A page-1 render with the document's page count, for the large site card.
class PdfPagePreview {
  const PdfPagePreview({required this.jpeg, required this.pageCount});

  final Uint8List jpeg;

  /// Null when it is unknown (a cache entry written without one).
  final int? pageCount;
}

/// Signature of the large-preview seam. Matches
/// [PdfPageRenderer.renderFirstPagePreview].
typedef PdfPreviewRenderer =
    Future<PdfPagePreview?> Function({
      File? file,
      Uint8List? bytes,
      int maxDimension,
      int quality,
    });
```

Rename the body of `renderFirstPageJpeg` into `renderFirstPagePreview` (same parameters, returns `PdfPagePreview?`), building the result as `PdfPagePreview(jpeg: Uint8List.fromList(img.encodeJpg(image, quality: quality)), pageCount: document.pages.length)`. Then make the old entry point delegate:

```dart
  static Future<Uint8List?> renderFirstPageJpeg({
    File? file,
    Uint8List? bytes,
    int maxDimension = 512,
    int quality = 80,
  }) async => (await renderFirstPagePreview(
    file: file,
    bytes: bytes,
    maxDimension: maxDimension,
    quality: quality,
  ))?.jpeg;
```

- [ ] **Step 5: Add `previewFor` to the service**

In `pdf_thumbnail_service.dart`, extend the constructor:

```dart
  PdfThumbnailService({
    required Future<Directory> Function() cacheDir,
    PdfThumbRenderer? renderer,
    PdfPreviewRenderer? previewRenderer,
    Duration renderBudget = const Duration(seconds: 15),
  }) : _cacheDir = cacheDir,
       _renderer = renderer ?? PdfPageRenderer.renderFirstPageJpeg,
       _previewRenderer =
           previewRenderer ?? PdfPageRenderer.renderFirstPagePreview,
       _renderBudget = renderBudget;

  final PdfPreviewRenderer _previewRenderer;
```

Add after `thumbFor`:

```dart
  /// Page 1 of [item] rendered with its longest side at [maxDimension], plus
  /// the page count, for the full-width site card (issue #1039); null when
  /// one cannot be produced.
  ///
  /// Same cache-first contract as [thumbFor], keyed per size, with the page
  /// count in a sidecar file. [bytes] is read only on a cache miss.
  Future<PdfPagePreview?> previewFor(
    MediaItem item, {
    required int maxDimension,
    required Future<Uint8List?> Function() bytes,
  }) async {
    if (!item.isPdf) return null;

    final dir = await _resolveCacheDir();
    final key = previewCacheKeyFor(item, maxDimension);
    final jpegFile = dir == null ? null : File(p.join(dir.path, '$key.jpg'));
    final pagesFile = dir == null
        ? null
        : File(p.join(dir.path, '$key.pages'));
    if (jpegFile != null && await jpegFile.exists()) {
      try {
        final jpeg = await jpegFile.readAsBytes();
        final pages = pagesFile != null && await pagesFile.exists()
            ? int.tryParse((await pagesFile.readAsString()).trim())
            : null;
        return PdfPagePreview(jpeg: jpeg, pageCount: pages);
      }
      // coverage:ignore-start
      // As in thumbFor: only a permission or I/O error, which flutter_test's
      // tmpdir fixtures cannot produce. Falls through to a fresh render.
      on FileSystemException {
        // Regenerate below.
      }
      // coverage:ignore-end
    }

    final PdfPagePreview? preview;
    try {
      final source = await bytes();
      if (source == null) return null;
      preview = await _previewRenderer(
        bytes: source,
        maxDimension: maxDimension,
        quality: _jpegQuality,
      ).timeout(_renderBudget);
    } on Object {
      return null;
    }
    if (preview == null) return null;

    if (dir != null && jpegFile != null && pagesFile != null) {
      try {
        await dir.create(recursive: true);
        await jpegFile.writeAsBytes(preview.jpeg, flush: true);
        final pages = preview.pageCount;
        if (pages != null) await pagesFile.writeAsString('$pages', flush: true);
      } on FileSystemException {
        // Caching is best-effort.
      }
    }
    return preview;
  }

  /// Cache key for [item]'s large render at [maxDimension]; distinct from
  /// [cacheKeyFor] so the tile and the large render never collide.
  @visibleForTesting
  static String previewCacheKeyFor(MediaItem item, int maxDimension) {
    final signature =
        item.contentHash ??
        '${item.id}|${item.updatedAt.millisecondsSinceEpoch}';
    return sha1
        .convert(utf8.encode('$signature|preview|$maxDimension'))
        .toString();
  }
```

- [ ] **Step 6: Add the provider and the bucket**

`lib/features/media/presentation/providers/pdf_preview_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// What a large PDF card asks for: the item and the render size bucket.
typedef PdfPreviewRequest = ({MediaItem item, int maxDimension});

const _buckets = [1024, 1536, 2048];

/// The render size for a card [logicalWidth] wide: the physical width
/// rounded up to a bucket, capped at the largest. Bucketing keeps a window
/// resize from re-rendering the document at every intermediate width.
int pdfPreviewBucket(double logicalWidth, double devicePixelRatio) {
  final physical = logicalWidth * devicePixelRatio;
  for (final bucket in _buckets) {
    if (physical <= bucket) return bucket;
  }
  return _buckets.last;
}

/// Page 1 of a PDF attachment at card width, with its page count
/// (issue #1039). Null when the PDF cannot be read or rendered here.
final pdfLargePreviewProvider = FutureProvider.autoDispose
    .family<PdfPagePreview?, PdfPreviewRequest>((ref, request) async {
      final service = ref.watch(pdfThumbnailServiceProvider);
      return service.previewFor(
        request.item,
        maxDimension: request.maxDimension,
        bytes: () async =>
            (await ref.read(mediaBytesProvider(request.item).future)).bytes,
      );
    });
```

If `core/providers/provider.dart` does not re-export `FutureProvider.autoDispose`, import `package:flutter_riverpod/flutter_riverpod.dart` instead, matching how neighbouring provider files do it.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/media/data/services/pdf_thumbnail_service_preview_test.dart test/features/media/presentation/providers/pdf_preview_providers_test.dart test/features/media/data/services/`
Expected: PASS (the PDFIUM-gated renderer tests skip as before).

- [ ] **Step 8: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/data/services/pdf_page_renderer.dart lib/features/media/data/services/pdf_thumbnail_service.dart lib/features/media/presentation/providers/pdf_preview_providers.dart test/features/media/data/services/pdf_thumbnail_service_preview_test.dart test/features/media/presentation/providers/pdf_preview_providers_test.dart
git commit -m "feat(media): render a large first-page PDF preview with page count"
```

---

### Task 8: Strings in all 11 locales, and label helpers

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11), generated `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/media/presentation/helpers/site_attachment_labels.dart`
- Test: `test/features/media/presentation/helpers/site_attachment_labels_test.dart`

**Interfaces:**
- Produces: l10n getters listed below; `extension SiteAttachmentCategoryLabel on SiteAttachmentCategory? { String label(AppLocalizations l10n) }`; `extension AttachmentDisplaySizeLabel on AttachmentDisplaySize { String label(AppLocalizations l10n) }`.

English keys (insert into `app_en.arb` in alphabetical position; `@` metadata in English only):

| Key | English | Placeholders |
| --- | --- | --- |
| `media_siteAttachment_categoryAccess` | Access and entry | |
| `media_siteAttachment_categoryAnchorage` | Anchorage and mooring | |
| `media_siteAttachment_categoryGeneral` | General | |
| `media_siteAttachment_categoryLabel` | Category | |
| `media_siteAttachment_categoryNone` | Uncategorized | |
| `media_siteAttachment_categoryParking` | Parking | |
| `media_siteAttachment_categorySiteMap` | Site map | |
| `media_siteAttachment_categoryUnderwater` | Underwater | |
| `media_siteAttachment_detailsTitle` | Attachment details | |
| `media_siteAttachment_editDetails` | Edit details | |
| `media_siteAttachment_groupHeading` | {category} ({count}) | category String, count int |
| `media_siteAttachment_moreOptions` | More options | |
| `media_siteAttachment_nameForbidden` | A name can't contain / \ : * ? " < > \| | |
| `media_siteAttachment_nameLabel` | Name | |
| `media_siteAttachment_nameRequired` | Enter a name | |
| `media_siteAttachment_pageCount` | {count, plural, one{{count} page} other{{count} pages}} | count int |
| `media_siteAttachment_saveError` | Couldn't save: {error} | error Object |
| `media_siteAttachment_setCategory` | Set category | |
| `media_siteAttachment_setCategoryError` | Failed to set category: {error} | error Object |
| `media_siteAttachment_setCategorySuccess` | {count, plural, one{Updated {count} item} other{Updated {count} items}} | count int |
| `media_siteAttachment_sizeDefault` | Default ({size}) | size String |
| `media_siteAttachment_sizeLabel` | Display size | |
| `media_siteAttachment_sizeLarge` | Large | |
| `media_siteAttachment_sizeTile` | Tile | |

- [ ] **Step 1: Write the failing label test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every category, uncategorized and size has an English label',
      () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      [
        for (final c in SiteAttachmentCategory.values) c.label(l10n),
        (null as SiteAttachmentCategory?).label(l10n),
      ],
      [
        'Site map',
        'Parking',
        'Access and entry',
        'Anchorage and mooring',
        'Underwater',
        'General',
        'Uncategorized',
      ],
    );
    expect(AttachmentDisplaySize.large.label(l10n), 'Large');
    expect(AttachmentDisplaySize.tile.label(l10n), 'Tile');
  });

  test('every locale translates the category labels', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(
        SiteAttachmentCategory.siteMap.label(l10n),
        isNot(SiteAttachmentCategory.siteMap.label(en)),
        reason: locale.languageCode,
      );
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/presentation/helpers/site_attachment_labels_test.dart`
Expected: FAIL, helper file missing.

- [ ] **Step 3: Write the translations file**

Write `<scratchpad>/l10n_1039.json` as `{"<key>": {"en": "...", "ar": "...", "de": "...", "es": "...", "fr": "...", "he": "...", "hu": "...", "it": "...", "nl": "...", "pt": "...", "zh": "..."}}` for all 24 keys above. Keep ICU placeholders and plural syntax verbatim (`{count}`, `{category}`, `{size}`, `{error}`, `one{...} other{...}`; ar may add `zero`, `two`, `few`, `many` branches, each using `{count}`, never a hardcoded digit). Match neighbouring terms in each ARB's `media_siteMediaSection_*` block (the word for "site", "media", "document") and that block's accent convention.

- [ ] **Step 4: Insert the keys surgically and regenerate**

Write and run `<scratchpad>/insert_l10n_1039.py`:

```python
import json, re, pathlib, sys

data = json.load(open(sys.argv[1], encoding='utf-8'))
meta = {
    'media_siteAttachment_groupHeading': {'description': 'Site media group heading', 'placeholders': {'category': {'type': 'String'}, 'count': {'type': 'int'}}},
    'media_siteAttachment_pageCount': {'description': 'Page count badge on a large PDF card', 'placeholders': {'count': {'type': 'int'}}},
    'media_siteAttachment_saveError': {'description': 'Edit details save failure', 'placeholders': {'error': {'type': 'Object'}}},
    'media_siteAttachment_setCategoryError': {'description': 'Bulk set category failure', 'placeholders': {'error': {'type': 'Object'}}},
    'media_siteAttachment_setCategorySuccess': {'description': 'Bulk set category success', 'placeholders': {'count': {'type': 'int'}}},
    'media_siteAttachment_sizeDefault': {'description': 'Size segment that follows the category default', 'placeholders': {'size': {'type': 'String'}}},
}
anchor = '"media_siteMediaSection_addDocument"'
for path in sorted(pathlib.Path('lib/l10n/arb').glob('app_*.arb')):
    locale = path.stem.split('_', 1)[1]
    src = path.read_text(encoding='utf-8')
    json.loads(src)
    lines = src.split('\n')
    idx = next(i for i, l in enumerate(lines) if l.lstrip().startswith(anchor))
    new = []
    for key in sorted(data):
        new.append('  %s: %s,' % (json.dumps(key), json.dumps(data[key][locale], ensure_ascii=False)))
        if locale == 'en' and key in meta:
            new.append('  %s: %s,' % (json.dumps('@' + key), json.dumps(meta[key], ensure_ascii=False)))
    lines[idx:idx] = new
    out = '\n'.join(lines)
    json.loads(out)
    path.write_text(out, encoding='utf-8')
    print(path.name, len(new))
```

Run: `grep -c '"media_siteMediaSection_addDocument"' lib/l10n/arb/app_*.arb` first; every file must report 1 (pick another shared `media_siteMediaSection_*` key if not). Then `python3.14 <scratchpad>/insert_l10n_1039.py <scratchpad>/l10n_1039.json`, then `flutter gen-l10n`.
Expected: `git diff --numstat -- lib/l10n/arb/*.arb` shows 0 deletions per file, 24 additions per locale file and 30 in `app_en.arb`; `grep -A1 "get media_siteAttachment_categorySiteMap" lib/l10n/arb/app_localizations_de.dart` shows German, not English.

- [ ] **Step 5: Implement the label helpers**

`lib/features/media/presentation/helpers/site_attachment_labels.dart`:

```dart
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized names for site attachment categories; null is Uncategorized.
extension SiteAttachmentCategoryLabel on SiteAttachmentCategory? {
  String label(AppLocalizations l10n) => switch (this) {
    SiteAttachmentCategory.siteMap => l10n.media_siteAttachment_categorySiteMap,
    SiteAttachmentCategory.parking => l10n.media_siteAttachment_categoryParking,
    SiteAttachmentCategory.access => l10n.media_siteAttachment_categoryAccess,
    SiteAttachmentCategory.anchorage =>
      l10n.media_siteAttachment_categoryAnchorage,
    SiteAttachmentCategory.underwater =>
      l10n.media_siteAttachment_categoryUnderwater,
    SiteAttachmentCategory.general => l10n.media_siteAttachment_categoryGeneral,
    null => l10n.media_siteAttachment_categoryNone,
  };
}

/// Localized names for attachment display sizes.
extension AttachmentDisplaySizeLabel on AttachmentDisplaySize {
  String label(AppLocalizations l10n) => switch (this) {
    AttachmentDisplaySize.large => l10n.media_siteAttachment_sizeLarge,
    AttachmentDisplaySize.tile => l10n.media_siteAttachment_sizeTile,
  };
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/media/presentation/helpers/site_attachment_labels_test.dart test/l10n`
Expected: PASS (including any ARB parity and plural guards under `test/l10n`).

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/l10n lib/features/media/presentation/helpers/site_attachment_labels.dart test/features/media/presentation/helpers/site_attachment_labels_test.dart
git commit -m "i18n(media): add site attachment category and edit strings"
```

---

### Task 9: Edit details sheet and the category picker

**Files:**
- Create: `lib/features/media/presentation/widgets/attachment_details_sheet.dart`
- Create: `lib/features/media/presentation/widgets/site_category_picker.dart`
- Test: `test/features/media/presentation/widgets/attachment_details_sheet_test.dart`
- Test: `test/features/media/presentation/widgets/site_category_picker_test.dart`

**Interfaces:**
- Consumes: Task 2 `diffAttachmentDetails`, `attachmentNameError`, `AttachmentFilename`; Task 5 notifier; Task 8 labels.
- Produces: `Future<MediaItem?> showAttachmentDetailsSheet(BuildContext context, {required MediaItem item, required String siteId})` (the saved item, or null when cancelled); `class AttachmentDetailsSheet extends ConsumerStatefulWidget`; `Future<({SiteAttachmentCategory? category})?> showSiteCategoryPicker(BuildContext context)` (null when dismissed).

- [ ] **Step 1: Write the failing sheet test**

The test hosts a button that opens the sheet and overrides `siteMediaListNotifierProvider('s1')` with a recording notifier (pattern from `site_media_section_test.dart`).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_sheet.dart';

import '../support/media_widget_harness.dart';

class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async => const [];
}

class _RecordingNotifier extends SiteMediaListNotifier {
  _RecordingNotifier(Ref ref, this.saves, {this.failWith})
    : super(_StubMediaRepository(), ref, 's1');

  final List<(String, AttachmentDetailsEdit)> saves;
  final Object? failWith;

  @override
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    saves.add((id, edit));
    if (failWith != null) throw failWith!;
  }
}

void main() {
  late List<(String, AttachmentDetailsEdit)> saves;
  MediaItem? result;

  setUp(() {
    saves = [];
    result = null;
  });

  Future<void> open(
    WidgetTester tester,
    MediaItem item, {
    Object? failWith,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          siteMediaListNotifierProvider('s1').overrideWith(
            (ref) => _RecordingNotifier(ref, saves, failWith: failWith),
          ),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAttachmentDetailsSheet(
                context,
                item: item,
                siteId: 's1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final pdf = testMediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: 'scan_0042.pdf',
  );

  testWidgets('shows the stem with the extension as a fixed suffix',
      (tester) async {
    await open(tester, pdf);
    expect(find.text('Attachment details'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'scan_0042'), findsOneWidget);
    expect(find.text('.pdf'), findsOneWidget);
  });

  testWidgets('saves only what changed and returns the saved item',
      (tester) async {
    await open(tester, pdf);
    await tester.enterText(find.byType(TextField), 'North wall');
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site map').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (id, edit) = saves.single;
    expect(id, 'm1');
    expect(edit.filename!.value, 'North wall.pdf');
    expect(edit.category!.value, SiteAttachmentCategory.siteMap);
    expect(edit.displaySize, isNull);
    expect(result!.originalFilename, 'North wall.pdf');
    expect(find.text('Attachment details'), findsNothing);
  });

  testWidgets('the default size segment follows the chosen category',
      (tester) async {
    await open(tester, pdf);
    expect(find.text('Default (Tile)'), findsOneWidget);
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parking').last);
    await tester.pumpAndSettle();
    expect(find.text('Default (Large)'), findsOneWidget);
  });

  testWidgets('a blank or forbidden name disables Save with a message',
      (tester) async {
    await open(tester, pdf);
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'a/b');
    await tester.pump();
    expect(find.textContaining("can't contain"), findsOneWidget);
  });

  testWidgets('an item with no name can be categorized with the name blank',
      (tester) async {
    await open(
      tester,
      testMediaItem(id: 'm2', siteId: 's1', originalFilename: null),
    );
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves.single.$2.filename, isNull);
    expect(saves.single.$2.category!.value, SiteAttachmentCategory.general);
  });

  testWidgets('a failed save keeps the sheet open and says why',
      (tester) async {
    await open(tester, pdf, failWith: StateError('gone'));
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(find.text('Attachment details'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('Cancel writes nothing', (tester) async {
    await open(tester, pdf);
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saves, isEmpty);
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Write the failing picker test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/widgets/site_category_picker.dart';

import '../support/media_widget_harness.dart';

void main() {
  Future<({SiteAttachmentCategory? category})?> pick(
    WidgetTester tester,
    String? choose,
  ) async {
    ({SiteAttachmentCategory? category})? result;
    var done = false;
    await tester.pumpWidget(
      await mediaTestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSiteCategoryPicker(context);
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Set category'), findsOneWidget);
    if (choose == null) {
      await tester.tapAt(const Offset(5, 5));
    } else {
      await tester.tap(find.text(choose));
    }
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return result;
  }

  testWidgets('choosing a category returns it', (tester) async {
    expect((await pick(tester, 'Anchorage and mooring'))!.category,
        SiteAttachmentCategory.anchorage);
  });

  testWidgets('Uncategorized is a choice distinct from dismissing',
      (tester) async {
    final chosen = await pick(tester, 'Uncategorized');
    expect(chosen, isNotNull);
    expect(chosen!.category, isNull);
  });

  testWidgets('dismissing returns null', (tester) async {
    expect(await pick(tester, null), isNull);
  });
}
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/attachment_details_sheet_test.dart test/features/media/presentation/widgets/site_category_picker_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 4: Implement the picker**

`lib/features/media/presentation/widgets/site_category_picker.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks which category to put the selected attachments in (issue #1039).
///
/// The result wraps the category so that choosing Uncategorized (a null
/// category) is distinguishable from dismissing the picker (a null result).
Future<({SiteAttachmentCategory? category})?> showSiteCategoryPicker(
  BuildContext context,
) => showModalBottomSheet<({SiteAttachmentCategory? category})>(
  context: context,
  useSafeArea: true,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              l10n.media_siteAttachment_setCategory,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final category in <SiteAttachmentCategory?>[
            ...SiteAttachmentCategory.values,
            null,
          ])
            ListTile(
              title: Text(category.label(l10n)),
              onTap: () =>
                  Navigator.of(sheetContext).pop((category: category)),
            ),
        ],
      ),
    );
  },
);
```

- [ ] **Step 5: Implement the sheet**

`lib/features/media/presentation/widgets/attachment_details_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// Opens Edit details for site attachment [item] (issue #1039). Resolves to
/// the saved item, or null when the diver cancels.
Future<MediaItem?> showAttachmentDetailsSheet(
  BuildContext context, {
  required MediaItem item,
  required String siteId,
}) => showModalBottomSheet<MediaItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SheetMessengerScope(
    child: AttachmentDetailsSheet(item: item, siteId: siteId),
  ),
);

/// The three-way size choice; [followCategory] stores a null override.
enum _SizeChoice { followCategory, large, tile }

/// Name, category and size for one site attachment.
class AttachmentDetailsSheet extends ConsumerStatefulWidget {
  const AttachmentDetailsSheet({
    super.key,
    required this.item,
    required this.siteId,
  });

  final MediaItem item;
  final String siteId;

  @override
  ConsumerState<AttachmentDetailsSheet> createState() =>
      _AttachmentDetailsSheetState();
}

class _AttachmentDetailsSheetState
    extends ConsumerState<AttachmentDetailsSheet> {
  late final AttachmentFilename _name = AttachmentFilename.split(
    widget.item.originalFilename,
  );
  late final TextEditingController _stem = TextEditingController(
    text: _name.stem,
  );
  late SiteAttachmentCategory? _category = widget.item.siteCategory;
  late _SizeChoice _size = switch (widget.item.displaySizeOverride) {
    null => _SizeChoice.followCategory,
    AttachmentDisplaySize.large => _SizeChoice.large,
    AttachmentDisplaySize.tile => _SizeChoice.tile,
  };
  bool _saving = false;

  @override
  void dispose() {
    _stem.dispose();
    super.dispose();
  }

  AttachmentDisplaySize? get _override => switch (_size) {
    _SizeChoice.followCategory => null,
    _SizeChoice.large => AttachmentDisplaySize.large,
    _SizeChoice.tile => AttachmentDisplaySize.tile,
  };

  String? _nameError(BuildContext context) =>
      switch (attachmentNameError(widget.item, _stem.text)) {
        null => null,
        AttachmentNameError.blank =>
          context.l10n.media_siteAttachment_nameRequired,
        AttachmentNameError.forbiddenCharacter =>
          context.l10n.media_siteAttachment_nameForbidden,
      };

  Future<void> _save() async {
    final edit = diffAttachmentDetails(
      widget.item,
      stem: _stem.text,
      category: _category,
      displaySize: _override,
    );
    final navigator = Navigator.of(context);
    if (edit.isEmpty) {
      navigator.pop(widget.item);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(siteMediaListNotifierProvider(widget.siteId).notifier)
          .setAttachmentDetails(widget.item.id, edit);
      navigator.pop(edit.applyTo(widget.item));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.media_siteAttachment_saveError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nameError = _nameError(context);
    final defaultSize =
        _category?.defaultDisplaySize ?? AttachmentDisplaySize.tile;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.media_siteAttachment_detailsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stem,
            autofocus: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.media_siteAttachment_nameLabel,
              suffixText: _name.extension.isEmpty ? null : '.${_name.extension}',
              errorText: nameError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SiteAttachmentCategory?>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: l10n.media_siteAttachment_categoryLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final category in <SiteAttachmentCategory?>[
                null,
                ...SiteAttachmentCategory.values,
              ])
                DropdownMenuItem(
                  value: category,
                  child: Text(category.label(l10n)),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.media_siteAttachment_sizeLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_SizeChoice>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _SizeChoice.followCategory,
                label: Text(
                  l10n.media_siteAttachment_sizeDefault(defaultSize.label(l10n)),
                ),
              ),
              ButtonSegment(
                value: _SizeChoice.large,
                label: Text(AttachmentDisplaySize.large.label(l10n)),
              ),
              ButtonSegment(
                value: _SizeChoice.tile,
                label: Text(AttachmentDisplaySize.tile.label(l10n)),
              ),
            ],
            selected: {_size},
            onSelectionChanged: (s) => setState(() => _size = s.single),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving || nameError != null ? null : _save,
                child: Text(l10n.common_action_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

Because the sheet body sits inside `SheetMessengerScope`'s `Scaffold`, `ScaffoldMessenger.of(context)` here resolves to the sheet's own messenger, so the error snackbar shows above the sheet.

- [ ] **Step 6: Run both to verify they pass**

Run: `flutter test test/features/media/presentation/widgets/attachment_details_sheet_test.dart test/features/media/presentation/widgets/site_category_picker_test.dart`
Expected: PASS. If the dropdown's menu renders the selected label twice, keep using `.last` on the menu entry as the test does.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation/widgets/attachment_details_sheet.dart lib/features/media/presentation/widgets/site_category_picker.dart test/features/media/presentation/widgets/attachment_details_sheet_test.dart test/features/media/presentation/widgets/site_category_picker_test.dart
git commit -m "feat(media): add the attachment details sheet and category picker"
```

---

### Task 10: Large attachment card

**Files:**
- Create: `lib/features/media/presentation/widgets/site_attachment_large_card.dart`
- Test: `test/features/media/presentation/widgets/site_attachment_large_card_test.dart`

**Interfaces:**
- Consumes: Task 7 `pdfLargePreviewProvider`, `pdfPreviewBucket`; Task 8 strings; existing `MediaItemView`.
- Produces: `class SiteAttachmentLargeCard extends ConsumerWidget { const SiteAttachmentLargeCard({required MediaItem item, required bool isSelectionMode, required bool isSelected, required VoidCallback onTap, VoidCallback? onEditDetails}); }` and `double largeCardAspectRatio(MediaItem item)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';

import '../support/media_widget_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    MediaItem item, {
    PdfPagePreview? preview,
    bool selectionMode = false,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          pdfLargePreviewProvider.overrideWith((ref, req) async => preview),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: SiteAttachmentLargeCard(
              item: item,
              isSelectionMode: selectionMode,
              isSelected: selected,
              onTap: onTap ?? () {},
              onEditDetails: onEdit,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('largeCardAspectRatio', () {
    test('uses the stored dimensions', () {
      expect(largeCardAspectRatio(testMediaItem().copyWith(width: 1600, height: 900)),
          closeTo(16 / 9, 1e-9));
    });

    test('falls back to 4:3 for unknown or zero dimensions', () {
      expect(largeCardAspectRatio(testMediaItem()), 4 / 3);
      expect(largeCardAspectRatio(testMediaItem().copyWith(width: 0, height: 900)), 4 / 3);
      expect(largeCardAspectRatio(testMediaItem().copyWith(width: 1600, height: 0)), 4 / 3);
    });
  });

  testWidgets('an image renders full width at its aspect ratio',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(originalFilename: 'entry.png').copyWith(width: 1600, height: 800),
    );
    final view = tester.getSize(find.byType(MediaItemView));
    expect(view.width / view.height, closeTo(2, 0.01));
    expect(find.text('entry.png'), findsOneWidget);
  });

  testWidgets('an image with no dimensions still has a 4:3 body',
      (tester) async {
    await pump(tester, testMediaItem(originalFilename: 'entry.png'));
    final view = tester.getSize(find.byType(MediaItemView));
    expect(view.height, greaterThan(0));
    expect(view.width / view.height, closeTo(4 / 3, 0.01));
  });

  testWidgets('a PDF shows its first page and page count', (tester) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: onePixelPng(), pageCount: 4),
    );
    expect(find.text('4 pages'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('a PDF that cannot render falls back to the document row',
      (tester) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: null,
    );
    expect(find.text('map.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a non-PDF document is a full-width row with its extension',
      (tester) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'route.gpx'),
    );
    expect(find.text('route.gpx'), findsOneWidget);
    expect(find.text('GPX'), findsOneWidget);
  });

  testWidgets('a long name ellipsizes at phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(
        mediaType: MediaType.document,
        originalFilename: '${'very long site map name ' * 8}.gpx',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap calls onTap; the menu offers Edit details',
      (tester) async {
    var taps = 0;
    var edits = 0;
    await pump(
      tester,
      testMediaItem(originalFilename: 'entry.png'),
      onTap: () => taps++,
      onEdit: () => edits++,
    );
    await tester.tap(find.byType(MediaItemView));
    expect(taps, 1);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(edits, 1);
  });

  testWidgets('in selection mode a checkbox replaces the menu',
      (tester) async {
    await pump(
      tester,
      testMediaItem(originalFilename: 'entry.png'),
      selectionMode: true,
      selected: true,
      onEdit: () {},
    );
    expect(find.byTooltip('More options'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/site_attachment_large_card_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

`lib/features/media/presentation/widgets/site_attachment_large_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width over height for [item]'s large body: its stored dimensions, or 4:3
/// when they are unknown or degenerate.
double largeCardAspectRatio(MediaItem item) {
  final w = item.width ?? 0;
  final h = item.height ?? 0;
  return w > 0 && h > 0 ? w / h : 4 / 3;
}

/// A site attachment shown at full card width (issue #1039): an image or
/// video at its own aspect ratio, a PDF's first page, or a document row.
class SiteAttachmentLargeCard extends ConsumerWidget {
  const SiteAttachmentLargeCard({
    super.key,
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onEditDetails,
  });

  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEditDetails;

  /// A tall portrait may not swallow the page: the body stops at this share
  /// of the screen height and letterboxes inside it.
  static const double _maxHeightFraction = 0.7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              item: item,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onToggle: onTap,
              onEditDetails: onEditDetails,
            ),
            if (!item.isDocument || item.isPdf) _body(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final maxHeight =
          MediaQuery.sizeOf(context).height * _maxHeightFraction;
      if (item.isPdf) {
        final request = (
          item: item,
          maxDimension: pdfPreviewBucket(
            width,
            MediaQuery.devicePixelRatioOf(context),
          ),
        );
        return ref
            .watch(pdfLargePreviewProvider(request))
            .when(
              data: (preview) => preview == null
                  ? const SizedBox.shrink()
                  : _PdfPage(preview: preview, maxHeight: maxHeight),
              loading: () => SizedBox(
                height: width * 0.6,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            );
      }
      final naturalHeight = width / largeCardAspectRatio(item);
      final height = naturalHeight > maxHeight ? maxHeight : naturalHeight;
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaItemView(
              item: item,
              fit: BoxFit.contain,
              thumbnail: item.isVideo,
              targetSize: Size(width, height),
            ),
            if (item.isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 56,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PdfPage extends StatelessWidget {
  const _PdfPage({required this.preview, required this.maxHeight});

  final PdfPagePreview preview;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final pages = preview.pageCount;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Stack(
        children: [
          Center(
            child: Image.memory(
              preview.jpeg,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
          if (pages != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(context.l10n.media_siteAttachment_pageCount(pages)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggle,
    required this.onEditDetails,
  });

  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback? onEditDetails;

  IconData get _icon {
    if (item.isPdf) return Icons.picture_as_pdf;
    if (item.isDocument) return Icons.description_outlined;
    if (item.isVideo) return Icons.videocam_outlined;
    return Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final extension = item.documentExtension;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.originalFilename ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          if (item.isDocument && !item.isPdf && extension.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(extension.toUpperCase(), style: textTheme.labelMedium),
          ],
          if (isSelectionMode)
            Checkbox(value: isSelected, onChanged: (_) => onToggle())
          else if (onEditDetails != null)
            PopupMenuButton<String>(
              tooltip: l10n.media_siteAttachment_moreOptions,
              onSelected: (_) => onEditDetails!(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.media_siteAttachment_editDetails),
                ),
              ],
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}
```

A PDF whose render failed (`preview == null` or an error) leaves only the header row, which is the document row the spec asks for.

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/site_attachment_large_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation/widgets/site_attachment_large_card.dart test/features/media/presentation/widgets/site_attachment_large_card_test.dart
git commit -m "feat(media): add the full-width site attachment card"
```

---

### Task 11: Grouped site media section with bulk actions

**Files:**
- Create: `lib/features/media/presentation/widgets/site_attachment_groups.dart`
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart` (replace the attachments `DragSelectGridView` branch; add bulk actions)
- Test: `test/features/media/presentation/widgets/site_attachment_groups_test.dart`
- Modify test: `test/features/media/presentation/widgets/site_media_section_test.dart` (add cases; existing ones must still pass)

**Interfaces:**
- Consumes: Task 6 `layoutSiteAttachments`; Task 9 sheet and picker; Task 10 card; Task 5 notifier.
- Produces: `class SiteAttachmentGroups extends StatelessWidget { const SiteAttachmentGroups({required SiteAttachmentLayout layout, required SelectionController selection, required bool isSelectionMode, required AppSettings settings, required void Function(MediaItem) onOpen, required void Function(MediaItem) onEditDetails}); }`.

- [ ] **Step 1: Write the failing groups test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_groups.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../support/media_widget_harness.dart';

void main() {
  late SelectionController selection;
  final opened = <String>[];

  setUp(() {
    selection = SelectionController();
    addTearDown(selection.dispose);
    opened.clear();
  });

  MediaItem m(String id, int minute,
          {SiteAttachmentCategory? category, String? name}) =>
      testMediaItem(
        id: id,
        siteId: 's1',
        originalFilename: name ?? '$id.png',
        takenAt: DateTime(2026, 3, 1, 9, minute),
      ).copyWith(siteCategory: category);

  Future<void> pump(WidgetTester tester, List<MediaItem> items,
      {bool selectionMode = false}) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          pdfLargePreviewProvider.overrideWith((ref, req) async => null),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: SiteAttachmentGroups(
              layout: layoutSiteAttachments(items),
              selection: selection,
              isSelectionMode: selectionMode,
              settings: const AppSettings(),
              onOpen: (item) => opened.add(item.id),
              onEditDetails: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uncategorized-only shows tiles and no headings',
      (tester) async {
    await pump(tester, [m('a', 1), m('b', 2)]);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byType(SiteAttachmentLargeCard), findsNothing);
    expect(find.textContaining('Uncategorized'), findsNothing);
  });

  testWidgets('headings follow category order with counts', (tester) async {
    await pump(tester, [
      m('u', 1),
      m('w', 2, category: SiteAttachmentCategory.underwater),
      m('s', 3, category: SiteAttachmentCategory.siteMap),
    ]);
    final siteMap = tester.getTopLeft(find.text('Site map (1)')).dy;
    final underwater = tester.getTopLeft(find.text('Underwater (1)')).dy;
    final none = tester.getTopLeft(find.text('Uncategorized (1)')).dy;
    expect(siteMap, lessThan(underwater));
    expect(underwater, lessThan(none));
  });

  testWidgets('a site map renders large, underwater as a tile',
      (tester) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    expect(find.byType(SiteAttachmentLargeCard), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsOneWidget);
  });

  testWidgets('tapping a large card outside selection opens it',
      (tester) async {
    await pump(tester, [m('s', 1, category: SiteAttachmentCategory.siteMap)]);
    await tester.tap(find.byType(SiteAttachmentLargeCard));
    expect(opened, ['s']);
  });

  testWidgets('selection can span a large card and a tile', (tester) async {
    selection.enterExplicit();
    await pump(
      tester,
      [
        m('s', 1, category: SiteAttachmentCategory.siteMap),
        m('w', 2, category: SiteAttachmentCategory.underwater),
      ],
      selectionMode: true,
    );
    await tester.tap(find.byType(SiteAttachmentLargeCard));
    await tester.pump();
    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.pump();
    expect(selection.value.checkedIds, {'s', 'w'});
    expect(opened, isEmpty);
  });
}
```

If `AppSettings` has required constructor parameters, take it from `getBaseOverrides()` the way `MediaThumbnailTile` tests do, or read `settingsProvider` inside a `Consumer`.

- [ ] **Step 2: Add the failing section tests**

Append to `site_media_section_test.dart` inside `main()` (reusing its `host`, `photoA`, `photoB`). Extend `_RecordingSiteMediaNotifier` with:

```dart
  final List<(List<String>, SiteAttachmentCategory?)> categoryCalls = [];

  @override
  Future<void> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    categoryCalls.add((List<String>.of(ids), category));
    if (failWith != null) throw failWith!;
  }
```

and add the tests:

```dart
  testWidgets('categorized attachments render under headings',
      (tester) async {
    await tester.pumpWidget(
      await host(
        attachments: [
          photoA.copyWith(siteCategory: SiteAttachmentCategory.parking),
          photoB,
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Parking (1)'), findsOneWidget);
    expect(find.text('Uncategorized (1)'), findsOneWidget);
  });

  testWidgets('Set category applies the choice to every checked item',
      (tester) async {
    final deleteCalls = <List<String>>[];
    late _RecordingSiteMediaNotifier notifier;
    await tester.pumpWidget(
      await host(
        attachments: [photoA, photoB],
        extraOverrides: [
          siteMediaListNotifierProvider('site-1').overrideWith(
            (ref) => notifier = _RecordingSiteMediaNotifier(
              ref,
              deleteCalls: deleteCalls,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Set category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Underwater'));
    await tester.pumpAndSettle();
    expect(notifier.categoryCalls.single.$1.toSet(), {'m1', 'm2'});
    expect(notifier.categoryCalls.single.$2, SiteAttachmentCategory.underwater);
    expect(find.text('Updated 2 items'), findsOneWidget);
  });

  testWidgets('Edit details is offered only for a single checked item',
      (tester) async {
    await tester.pumpWidget(await host(attachments: [photoA, photoB]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit details'), findsOneWidget);
    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Edit details'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
```

`SelectionAppBar` may render actions in an overflow menu at narrow widths, or disable rather than hide an action outside its count range. Before relying on `byTooltip`, read how `SelectionAppBar` renders `BulkAction`s in `lib/shared/selection/selection_app_bar.dart` and match the finder to it (tooltip on an `IconButton`, or a `PopupMenuItem` text). The assertion that must hold: with two checked, Edit details cannot be invoked.

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/site_attachment_groups_test.dart test/features/media/presentation/widgets/site_media_section_test.dart`
Expected: FAIL, `SiteAttachmentGroups` missing and no headings or Set category in the section.

- [ ] **Step 4: Implement `SiteAttachmentGroups`**

`lib/features/media/presentation/widgets/site_attachment_groups.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// A site's attachments in category groups (issue #1039): a heading per
/// group when anything is categorized, the group's large cards, then its
/// tiles in a grid.
///
/// Every grid and card reports to the one id-based [selection], so a
/// selection can span groups.
class SiteAttachmentGroups extends StatelessWidget {
  const SiteAttachmentGroups({
    super.key,
    required this.layout,
    required this.selection,
    required this.isSelectionMode,
    required this.settings,
    required this.onOpen,
    required this.onEditDetails,
  });

  final SiteAttachmentLayout layout;
  final SelectionController selection;
  final bool isSelectionMode;
  final AppSettings settings;
  final void Function(MediaItem) onOpen;
  final void Function(MediaItem) onEditDetails;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final group in layout.groups) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      if (layout.showHeadings) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.media_siteAttachment_groupHeading(
                group.category.label(context.l10n),
                group.large.length + group.tiles.length,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      for (final item in group.large) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SiteAttachmentLargeCard(
              key: ValueKey('large-${item.id}'),
              item: item,
              isSelectionMode: isSelectionMode,
              isSelected: selection.value.isChecked(item.id),
              onTap: isSelectionMode
                  ? () => selection.toggle(item.id)
                  : () => onOpen(item),
              onEditDetails: () => onEditDetails(item),
            ),
          ),
        );
      }
      if (group.tiles.isNotEmpty) {
        children.add(_tileGrid(context, group));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tileGrid(BuildContext context, SiteAttachmentGroup group) {
    final tiles = group.tiles;
    final groupIds = {for (final t in tiles) t.id};
    return DragSelectGridView<MediaItem>(
      key: ValueKey('tiles-${group.category?.storageKey ?? 'none'}'),
      items: tiles,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      startInSelectionMode: isSelectionMode,
      initialSelection: {
        for (var i = 0; i < tiles.length; i++)
          if (selection.value.isChecked(tiles[i].id)) i,
      },
      // The controller owns the mode; see SiteMediaSection for why the grid
      // must not exit it on its own.
      exitOnEmptySelection: false,
      onSelectionChanged: (indices) {
        // The grid reports its whole selection, but only for its own group,
        // so keep every other group's checks and replace this group's.
        final picked = [
          for (final i in indices)
            if (i >= 0 && i < tiles.length) tiles[i].id,
        ];
        selection.replaceChecked([
          for (final id in selection.value.checkedIds)
            if (!groupIds.contains(id)) id,
          ...picked,
        ]);
      },
      onSelectionModeChanged: (_) {},
      onItemTap: (index) => onOpen(tiles[index]),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, item, isSelected) => MediaThumbnailTile(
        item: item,
        settings: settings,
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        semanticsLabel: context.l10n.media_diveMediaSection_thumbnailLabel,
      ),
    );
  }
}
```

- [ ] **Step 5: Wire it into `SiteMediaSection`**

In `site_media_section.dart`:

1. Import `site_attachment_layout.dart`, `site_attachment_groups.dart`, `attachment_details_sheet.dart`, `site_category_picker.dart`.
2. Delete `_indicesFor` and `_idsFor` (the group grids now do this).
3. In the `mediaAsync.when(data:)` branch, keep the empty state and replace the `DragSelectGridView` with:

```dart
                return SiteAttachmentGroups(
                  layout: layoutSiteAttachments(media),
                  selection: _selection,
                  isSelectionMode: _isSelectionMode,
                  settings: settings,
                  onOpen: (item) =>
                      _openItem(context, item, SiteViewerScope.attachments),
                  onEditDetails: (item) => showAttachmentDetailsSheet(
                    context,
                    item: item,
                    siteId: widget.siteId,
                  ),
                );
```

4. In the `SelectionAppBar` `actions:` list, after the unlink action:

```dart
                        BulkAction(
                          id: 'setCategory',
                          icon: Icons.label_outline,
                          label: context.l10n.media_siteAttachment_setCategory,
                          onInvoke: () => _setCategoryForSelected(context),
                        ),
                        BulkAction(
                          id: 'editDetails',
                          icon: Icons.edit_outlined,
                          label: context.l10n.media_siteAttachment_editDetails,
                          maxCount: 1,
                          onInvoke: () => _editSelected(context, media),
                        ),
```

5. Add the two handlers to the state class:

```dart
  Future<BulkActionOutcome> _setCategoryForSelected(
    BuildContext context,
  ) async {
    final ids = _selection.value.checkedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;
    final choice = await showSiteCategoryPicker(context);
    if (choice == null || !context.mounted) return BulkActionOutcome.cancelled;
    try {
      await ref
          .read(siteMediaListNotifierProvider(widget.siteId).notifier)
          .setSiteCategory(ids, choice.category);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_siteAttachment_setCategorySuccess(ids.length),
            ),
          ),
        );
      }
      return BulkActionOutcome.completed;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.media_siteAttachment_setCategoryError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return BulkActionOutcome.failed;
    }
  }

  Future<BulkActionOutcome> _editSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final ids = _selection.value.checkedIds;
    if (ids.length != 1) return BulkActionOutcome.cancelled;
    final item = media.where((m) => m.id == ids.single).firstOrNull;
    if (item == null) return BulkActionOutcome.cancelled;
    final saved = await showAttachmentDetailsSheet(
      context,
      item: item,
      siteId: widget.siteId,
    );
    return saved == null
        ? BulkActionOutcome.cancelled
        : BulkActionOutcome.completed;
  }
```

- [ ] **Step 6: Run the section and groups tests**

Run: `flutter test test/features/media/presentation/widgets/site_attachment_groups_test.dart test/features/media/presentation/widgets/site_media_section_test.dart`
Expected: PASS, including every pre-existing section test (empty state, add menu, unlink flow, dive photos group). An uncategorized-only site has no headings, so old finders still match.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation/widgets/site_attachment_groups.dart lib/features/media/presentation/widgets/site_media_section.dart test/features/media/presentation/widgets/site_attachment_groups_test.dart test/features/media/presentation/widgets/site_media_section_test.dart
git commit -m "feat(media): group site attachments by category with large cards"
```

---

### Task 12: Edit details from the viewers

**Files:**
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart` (`_TopOverlay` gains an optional edit button; build passes it for the attachments scope)
- Modify: `lib/features/media/presentation/pages/document_viewer_page.dart` (optional `editableSiteId`, live title)
- Modify: `lib/features/media/presentation/helpers/document_open_helper.dart` (`open` forwards `editableSiteId`)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:352` (pass the site id)
- Modify tests: `test/features/media/presentation/pages/site_media_viewer_page_test.dart`, `test/features/media/presentation/pages/document_viewer_page_test.dart`

**Interfaces:**
- Consumes: Task 9 `showAttachmentDetailsSheet`.
- Produces: `DocumentViewerPage({required MediaItem item, String? editableSiteId})`; `DocumentOpenHelper.open(BuildContext, WidgetRef, MediaItem, {String? editableSiteId})`.

- [ ] **Step 1: Write the failing viewer tests**

Append to `site_media_viewer_page_test.dart` inside `main()`, after `pumpViewer`:

```dart
  testWidgets('the attachments viewer offers Edit details', (tester) async {
    await pumpViewer(tester);
    expect(find.byTooltip('Edit details'), findsOneWidget);
  });

  testWidgets('the dive photos viewer does not', (tester) async {
    await pumpViewer(
      tester,
      scope: SiteViewerScope.divePhotos,
      extraOverrides: [
        flatMediaFromDivesAtSiteProvider(
          'site-1',
        ).overrideWith((ref) async => [first, second]),
      ],
    );
    expect(find.byTooltip('Edit details'), findsNothing);
  });
```

Append to `document_viewer_page_test.dart`. Add imports for `media_repository.dart`, `site_media_providers.dart` and `attachment_details_edit.dart` at the top, then add above `main()`:

```dart
class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async => const [];
}

class _SavingNotifier extends SiteMediaListNotifier {
  _SavingNotifier(Ref ref) : super(_StubMediaRepository(), ref, 'site-1');

  @override
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {}
}

Widget _editableHost(MediaItem item, {String? editableSiteId}) => ProviderScope(
  overrides: [
    mediaBytesProvider(item).overrideWith(
      (ref) async =>
          const ResolvedAssetResult(status: ResolutionStatus.unavailable),
    ),
    siteMediaListNotifierProvider(
      'site-1',
    ).overrideWith((ref) => _SavingNotifier(ref)),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DocumentViewerPage(item: item, editableSiteId: editableSiteId),
  ),
);
```

and inside `main()`:

```dart
  testWidgets('Edit details shows only with an editable site id', (
    tester,
  ) async {
    final doc = _doc(originalFilename: 'reef-map.pdf');
    await tester.pumpWidget(_editableHost(doc));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit details'), findsNothing);

    await tester.pumpWidget(_editableHost(doc, editableSiteId: 'site-1'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit details'), findsOneWidget);
  });

  testWidgets('a rename from the sheet updates the title', (tester) async {
    await tester.pumpWidget(
      _editableHost(
        _doc(originalFilename: 'reef-map.pdf'),
        editableSiteId: 'site-1',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reef map');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Reef map.pdf'), findsOneWidget);
    expect(find.text('reef-map.pdf'), findsNothing);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/media/presentation/pages/site_media_viewer_page_test.dart test/features/media/presentation/pages/document_viewer_page_test.dart`
Expected: FAIL, no Edit details button and no `editableSiteId` parameter.

- [ ] **Step 3: Add the button to the site viewer**

In `_TopOverlay`, add a field `final VoidCallback? onEditDetails;` (constructor `this.onEditDetails`), and before the share `Builder`:

```dart
                if (onEditDetails != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    tooltip: context.l10n.media_siteAttachment_editDetails,
                    onPressed: onEditDetails,
                  ),
```

In the page build, pass:

```dart
                    onEditDetails: widget.scope == SiteViewerScope.attachments
                        ? () => showAttachmentDetailsSheet(
                            context,
                            item: currentItem,
                            siteId: widget.siteId,
                          )
                        : null,
```

The viewer keeps its capture-time order: re-sorting by group would move the open photo under the diver's finger when its category changed.

- [ ] **Step 4: Add the button to the document viewer**

In `DocumentViewerPage` add `final String? editableSiteId;` and `this.editableSiteId` to the constructor. In the state add:

```dart
  /// The name shown in the app bar, updated by a rename here. The bytes
  /// stay keyed on the original item, so a rename does not reload the PDF.
  late String? _title = widget.item.originalFilename;
```

Use `_title ?? context.l10n.media_documentViewer_title` for the app bar title, and before the share `Builder` in `actions:`:

```dart
          if (widget.editableSiteId != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.l10n.media_siteAttachment_editDetails,
              onPressed: () async {
                final saved = await showAttachmentDetailsSheet(
                  context,
                  item: widget.item.copyWith(originalFilename: _title),
                  siteId: widget.editableSiteId!,
                );
                if (saved != null && mounted) {
                  setState(() => _title = saved.originalFilename);
                }
              },
            ),
```

- [ ] **Step 5: Forward the id**

`DocumentOpenHelper.open` gains `{String? editableSiteId}` and builds `DocumentViewerPage(item: item, editableSiteId: editableSiteId)`. In `site_detail_page.dart`:

```dart
            onOpenDocument: (item) => DocumentOpenHelper.open(
              context,
              ref,
              item,
              editableSiteId: site.id,
            ),
```

Dive and equipment callers stay unchanged, so their PDF viewer shows no Edit details.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/media/presentation/pages/ test/features/dive_sites/presentation/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/media/presentation/pages/site_media_viewer_page.dart lib/features/media/presentation/pages/document_viewer_page.dart lib/features/media/presentation/helpers/document_open_helper.dart lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/media/presentation/pages/site_media_viewer_page_test.dart test/features/media/presentation/pages/document_viewer_page_test.dart
git commit -m "feat(media): open Edit details from the site photo and PDF viewers"
```

---

### Task 13: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `flutter analyze`
Expected: no changes to commit from format (or commit them as `style: format`), and analyze reports no issues, infos included.

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture/`
Expected: PASS. New files under `lib/` must satisfy the guards (provider change ticks, date picker adoption, global state restore, and so on); fix any it names.

- [ ] **Step 3: Affected suites**

Run: `flutter test test/features/media test/core/database test/core/services/sync test/features/dive_sites test/l10n`
Expected: PASS with no new skips.

- [ ] **Step 4: Em dash and attribution scan**

Run: `git diff origin/main...HEAD | python3.14 -c "import sys; d=(chr(0x2014), chr(0x2013)); [print(l, end='') for l in sys.stdin if l.startswith('+') and any(c in l for c in d)]"` and `git log origin/main..HEAD --format=%B | grep -in "claude\|anthropic"`
Expected: no output from either.

- [ ] **Step 5: Commit any fixes**

```bash
git add -u lib test
git commit -m "fix(media): address verification findings"
```

Skip the commit when nothing changed.
