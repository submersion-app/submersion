# Sync Conflict Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (execution method chosen: inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Resolve Conflicts dialog shows every field two versions of a synced record disagree on, both values in the diver's units and language, and what each choice keeps or discards.

**Architecture:** A pure comparison model (`buildConflictComparison`) turns a `SyncConflict` into differences and unchanged fields, using a field catalogue that gives every synced column a localized label and a value kind. New widgets render the comparison (table or stacked blocks, word-level diff for long text, consequence line), and the existing dialog is rewired onto them. No sync engine, schema or resolution change.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart`), Drift (`TableInfo.$columns` for the coverage guard), gen-l10n ARB files (11 locales), `package:collection` for deep equality.

**Spec:** `docs/design/specs/2026-10-05-sync-conflict-comparison-design.md`

## Global Constraints

- Never write the em-dash character (U+2014) or an en-dash used as punctuation, in code, comments, ARB values, commits or the PR.
- No mention of any AI tool in code, commits or the PR.
- Every measurement renders through `UnitFormatter` (`lib/core/utils/unit_formatter.dart`), built from `ref.watch(settingsProvider)`.
- Every new user-facing string is translated into all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh.
- ARB plurals use `one{...}` with `{count}` inside, never `=1{1 ...}`; Arabic plurals give `zero`, `one`, `two`, `few`, `many` and `other`.
- ARB keys are inserted textually by anchor with the script from Task 4; never JSON round-trip an ARB file.
- `flutter gen-l10n` is re-run after the final translations land (Task 14), and the generated German file is spot-checked for a translated value.
- Lib files stay under 800 lines; split the catalogue by domain.
- Tests that change process-wide state (`Intl.defaultLocale`, surface size, view size) restore it in `addTearDown` or `tearDownAll`.
- Paths in tests and scripts are built with `p.join`, never by concatenating `/`.
- Resolution semantics in `SyncService.resolveConflict` are not changed.
- Before every commit: `dart format .`, `flutter analyze` (zero issues, infos included), the affected tests, and `flutter test test/architecture/` whenever a file under `lib/` was added.

## Review Focus

1. **Two devices that publish the same display name, or a remote row last written by this device** (restore, re-adopt): the column headers and chips would read "Keep Pixel 8" twice. Expected: both fall back to "This device" / "Other device" so the choice stays unambiguous. Pinned in Task 5.
2. **The same number decoded as `int` on one side and `double` on the other** (remote JSON `26`, local row `26.0`): must not count as a difference. Pinned in Task 6.
3. **A long text that differs only in spacing or line breaks:** a difference exists (keeping one side changes the stored text) but the word diff highlights nothing. Expected: the field still shows, with the note "Only spacing or line breaks differ." Pinned in Task 7.
4. **An enum value this build does not know** (written by a newer peer): must print as stored, never throw or show blank. Pinned in Task 3.
5. **A value whose runtime type does not match its catalogue kind** (a depth that arrives as a `String` from an old peer, a bool stored as `0`/`1`): must render something readable, never throw. Pinned in Task 2.

---

## File Structure

New, under `lib/features/settings/presentation/conflicts/`:

| File | Responsibility |
| --- | --- |
| `word_diff.dart` | Tokenizer and LCS marking of words only on one side |
| `conflict_field.dart` | `FieldKind`, `ConflictField`, `ConflictEnumLabeler` |
| `conflict_field_format.dart` | `formatConflictValue` by kind |
| `conflict_enum_labels.dart` | `enumLabeler` helper and the labelers for every enum-valued column |
| `catalogue/conflict_field_catalogue.dart` | lookup, bookkeeping set, coverage check, merges the domain maps |
| `catalogue/dive_log_fields.dart` | dive log entities |
| `catalogue/site_trip_fields.dart` | sites, trips, centres, tracks, species, tags |
| `catalogue/equipment_fields.dart` | equipment, cylinders, computers, service |
| `catalogue/people_planning_fields.dart` | divers, buddies, certifications, courses, plans, pre-dive |
| `catalogue/settings_media_fields.dart` | diver settings, media, presets, queries, settings |
| `conflict_device_labels.dart` | device names for both sides |
| `conflict_finding_message.dart` | quality finding sentence (moved from `conflict_data_preview.dart`) |
| `conflict_comparison.dart` | model and `buildConflictComparison` |
| `widgets/conflict_difference_list.dart` | table (wide) or blocks (narrow) |
| `widgets/conflict_text_diff.dart` | highlighted long text |
| `widgets/conflict_comparison_view.dart` | modified lines, differences, unchanged expansion, banners |
| `widgets/conflict_choice_consequence.dart` | the line under the chips |

Modified: `lib/features/settings/presentation/widgets/conflict_resolution_dialog.dart`, `lib/features/settings/presentation/providers/sync_providers.dart` (one provider), `lib/l10n/arb/app_*.arb` and generated `app_localizations*.dart`.

Removed: `lib/features/settings/presentation/widgets/conflict_data_preview.dart`, `test/features/settings/presentation/widgets/conflict_scalar_format_test.dart` (absorbed by Task 2).

Tests mirror the lib paths under `test/features/settings/presentation/conflicts/`.

Shell notes for this repo: the Bash tool runs zsh (quote globs, no word splitting in `for f in $X`), system `python3` is 3.9; use `python3.14`. Never pipe `flutter test` into `grep` when its exit code matters.

---

### Task 0: Before screenshots

**Files:**
- Create (throwaway, never committed): `test/zz_shots/conflict_dialog_shots_test.dart`
- Output: scratchpad `shots/NN-conflict-dialog-before[-dark][-phone].png`

- [ ] **Step 1: Resolve the SDK font paths**

Run: `flutter --version --machine | python3.14 -c "import json,sys; print(json.load(sys.stdin)['flutterRoot'])"`
Expected: an absolute path; `<root>/bin/cache/artifacts/material_fonts/` holds `Roboto-Regular.ttf`, `Roboto-Medium.ttf`, `Roboto-Bold.ttf`, `MaterialIcons-Regular.otf`.

- [ ] **Step 2: Write the throwaway golden harness**

Keep a copy at scratchpad `shots/conflict_dialog_shots_test.dart` so Task 15 can reuse it. Replace `FLUTTER_ROOT` with the path from Step 1.

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../helpers/mock_providers.dart';

const _fonts = 'FLUTTER_ROOT/bin/cache/artifacts/material_fonts';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(p.join(_fonts, f)).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

SyncConflict _diveConflict() {
  final now = DateTime.now();
  Map<String, dynamic> dive(Map<String, dynamic> extra) => {
    'id': 'dive-142',
    'diveNumber': 142,
    'name': 'Blue Hole',
    'diveDateTime': DateTime(2026, 9, 12, 9, 40).millisecondsSinceEpoch,
    'maxDepth': 31.4,
    'avgDepth': 18.2,
    'bottomTime': 2820,
    'runtime': 3300,
    'entryMethod': 'boat',
    'waterType': 'salt',
    'rating': 4,
    ...extra,
  };
  return SyncConflict(
    entityType: 'dives',
    recordId: 'dive-142',
    localData: dive({
      'waterTemp': 26.0,
      'visibility': 'good',
      'notes': 'Saw a turtle near the wall on the way back.',
      'hlc': '${now.millisecondsSinceEpoch}:0:local-device',
    }),
    remoteData: dive({
      'waterTemp': 27.0,
      'visibility': 'excellent',
      'notes': 'Saw two turtles near the wall and a ray on the way back.',
      'hlc': '${now.millisecondsSinceEpoch}:0:remote-device',
    }),
    localModified: now.subtract(const Duration(hours: 2)),
    remoteModified: now.subtract(const Duration(hours: 5)),
  );
}

void main() {
  setUpAll(() async {
    await _load('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  for (final dark in [false, true]) {
    for (final phone in [false, true]) {
      final name = [
        'conflict-dialog',
        if (dark) 'dark',
        if (phone) 'phone',
      ].join('-');
      testWidgets(name, (tester) async {
        final size = phone ? const Size(390, 844) : const Size(1280, 860);
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = size * 2;
        addTearDown(tester.view.reset);
        final base = await getBaseOverrides();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
              conflictsProvider.overrideWith((ref) async => [_diveConflict()]),
              // AFTER-ONLY OVERRIDES GO HERE (Task 15).
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'Roboto',
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: ConflictResolutionDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(p.join('goldens', '$name.png')),
        );
      });
    }
  }
}
```

- [ ] **Step 3: Capture**

Run: `flutter test test/zz_shots/conflict_dialog_shots_test.dart --update-goldens`
Expected: PASS, four PNGs under `test/zz_shots/goldens/`.

- [ ] **Step 4: Move the PNGs and delete the harness from the repo**

Copy them to scratchpad `shots/` as `01-conflict-dialog-before.png`, `02-conflict-dialog-before-dark.png`, `03-conflict-dialog-before-phone.png`, `04-conflict-dialog-before-dark-phone.png`, then `rm -r test/zz_shots`. Read one PNG to confirm real glyphs (no Ahem boxes). `git status --porcelain` must be empty.

---

### Task 1: Word diff

**Files:**
- Create: `lib/features/settings/presentation/conflicts/word_diff.dart`
- Test: `test/features/settings/presentation/conflicts/word_diff_test.dart`

**Interfaces:**
- Produces: `class DiffSpan { final String text; final bool unique; }`, `class WordDiff { final List<DiffSpan> local; final List<DiffSpan> remote; bool get hasUniqueWords; }`, `WordDiff? diffWords(String local, String remote)` (null when over `kWordDiffTokenLimit`), `List<String> tokenizeForDiff(String text)`, `const kWordDiffTokenLimit = 2000`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';

String joined(List<DiffSpan> spans) => spans.map((s) => s.text).join();
List<String> unique(List<DiffSpan> spans) => [
  for (final s in spans)
    if (s.unique) s.text.trim(),
];

void main() {
  group('tokenizeForDiff', () {
    test('splits words, whitespace and punctuation and loses nothing', () {
      const text = 'Saw a turtle, near the wall.';
      final tokens = tokenizeForDiff(text);
      expect(tokens.join(), text);
      expect(tokens, contains('turtle'));
      expect(tokens, contains(','));
    });

    test('makes each CJK character its own token', () {
      expect(tokenizeForDiff('看到海龟'), ['看', '到', '海', '龟']);
    });

    test('keeps RTL words whole', () {
      expect(tokenizeForDiff('رأيت سلحفاة'), ['رأيت', ' ', 'سلحفاة']);
    });
  });

  group('diffWords', () {
    test('marks the words only on each side', () {
      final diff = diffWords(
        'Saw a turtle near the wall.',
        'Saw two turtles near the wall and a ray.',
      )!;
      expect(joined(diff.local), 'Saw a turtle near the wall.');
      expect(
        joined(diff.remote),
        'Saw two turtles near the wall and a ray.',
      );
      expect(unique(diff.local), ['a turtle']);
      expect(unique(diff.remote), ['two turtles', 'and a ray']);
    });

    test('marks nothing for identical text', () {
      final diff = diffWords('Same text.', 'Same text.')!;
      expect(diff.hasUniqueWords, isFalse);
    });

    test('marks nothing when only whitespace differs', () {
      final diff = diffWords('One two\nthree', 'One  two three')!;
      expect(diff.hasUniqueWords, isFalse);
    });

    test('an empty side marks the whole other side', () {
      final diff = diffWords('', 'Only here')!;
      expect(diff.local, isEmpty);
      expect(unique(diff.remote), ['Only here']);
    });

    test('marks single CJK characters', () {
      final diff = diffWords('看到海龟', '看到两只海龟')!;
      expect(unique(diff.remote), ['两只']);
      expect(diff.local.every((s) => !s.unique), isTrue);
    });

    test('gives up past the token limit', () {
      final big = List.filled(kWordDiffTokenLimit, 'w').join(' ');
      expect(diffWords(big, '$big extra'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/word_diff_test.dart`
Expected: FAIL, `word_diff.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Word tokens the two texts may hold between them before the diff is
/// skipped. The LCS table is words(local) x words(remote) cells; at this
/// limit the worst case is 1000 x 1000 16-bit cells (2 MB).
const kWordDiffTokenLimit = 2000;

/// A run of one side's text. [unique] marks words that are not in the other
/// side. There is no common ancestor, so this means "only on this side",
/// never "added" or "removed".
@immutable
class DiffSpan {
  const DiffSpan(this.text, {required this.unique});

  final String text;
  final bool unique;

  @override
  bool operator ==(Object other) =>
      other is DiffSpan && other.text == text && other.unique == unique;

  @override
  int get hashCode => Object.hash(text, unique);

  @override
  String toString() => unique ? '[$text]' : text;
}

@immutable
class WordDiff {
  const WordDiff({required this.local, required this.remote});

  final List<DiffSpan> local;
  final List<DiffSpan> remote;

  /// False when the texts hold the same words and differ only in spacing.
  bool get hasUniqueWords =>
      local.any((s) => s.unique) || remote.any((s) => s.unique);
}

// CJK scripts are written without spaces, so each character is a word.
final _tokenPattern = RegExp(
  r"[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]"
  r"|\s+"
  r"|[\p{L}\p{N}\p{M}_']+"
  r"|[^\s\p{L}\p{N}\p{M}_']",
  unicode: true,
);

/// Splits [text] into words, whitespace runs and single punctuation marks.
/// Joining the result gives [text] back.
List<String> tokenizeForDiff(String text) => [
  for (final m in _tokenPattern.allMatches(text)) m[0]!,
];

bool _isSpace(String token) => token.trim().isEmpty;

/// Marks the words of each text that the other does not contain, using the
/// longest common subsequence of their word tokens. Whitespace is never
/// marked itself; a space between two marked words joins their highlight.
/// Returns null when the texts hold more than [kWordDiffTokenLimit] words.
WordDiff? diffWords(String local, String remote) {
  final a = tokenizeForDiff(local);
  final b = tokenizeForDiff(remote);
  final aw = [for (var i = 0; i < a.length; i++) if (!_isSpace(a[i])) i];
  final bw = [for (var i = 0; i < b.length; i++) if (!_isSpace(b[i])) i];
  if (aw.length + bw.length > kWordDiffTokenLimit) return null;

  final n = aw.length;
  final m = bw.length;
  final width = m + 1;
  final table = Uint16List((n + 1) * width);
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      table[i * width + j] = a[aw[i]] == b[bw[j]]
          ? table[(i + 1) * width + j + 1] + 1
          : (table[(i + 1) * width + j] >= table[i * width + j + 1]
                ? table[(i + 1) * width + j]
                : table[i * width + j + 1]);
    }
  }

  final aCommon = <int>{};
  final bCommon = <int>{};
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[aw[i]] == b[bw[j]]) {
      aCommon.add(aw[i]);
      bCommon.add(bw[j]);
      i++;
      j++;
    } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return WordDiff(local: _spans(a, aCommon), remote: _spans(b, bCommon));
}

List<DiffSpan> _spans(List<String> tokens, Set<int> common) {
  bool uniqueAt(int k) => !_isSpace(tokens[k]) && !common.contains(k);

  // A whitespace token is unique only when the words on both sides of it are.
  final flags = List<bool>.generate(tokens.length, (k) {
    if (!_isSpace(tokens[k])) return uniqueAt(k);
    return k > 0 &&
        k < tokens.length - 1 &&
        uniqueAt(k - 1) &&
        uniqueAt(k + 1);
  });

  final spans = <DiffSpan>[];
  final buffer = StringBuffer();
  bool? current;
  for (var k = 0; k < tokens.length; k++) {
    if (current != null && flags[k] != current) {
      spans.add(DiffSpan(buffer.toString(), unique: current));
      buffer.clear();
    }
    current = flags[k];
    buffer.write(tokens[k]);
  }
  if (current != null) spans.add(DiffSpan(buffer.toString(), unique: current));
  return List.unmodifiable(spans);
}
```

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/word_diff_test.dart`
Expected: PASS (all 9). If the CJK test marks `两只` as two spans, the whitespace-join rule is not the cause (CJK has no spaces): join adjacent unique tokens in `_spans` by checking `flags[k] != current` only, which the code above already does; re-read the expectation before changing code.

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts/word_diff.dart test/features/settings/presentation/conflicts/word_diff_test.dart
git commit -m "feat(settings): word-level diff for conflicting text"
```

---

### Task 2: Field model and value formatter

**Files:**
- Create: `lib/features/settings/presentation/conflicts/conflict_field.dart`
- Create: `lib/features/settings/presentation/conflicts/conflict_field_format.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_field_format_test.dart`
- Delete (later, Task 8): `test/features/settings/presentation/widgets/conflict_scalar_format_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` (3 keys), generated `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces:
  - `enum FieldKind { depth, distance, geoDistance, pressure, temperature, weight, volume, speed, windSpeed, altitude, heightCm, ascentRate, latitude, longitude, percent, fraction, partialPressure, durationSeconds, durationMinutes, durationHours, dateTime, date, boolean, number, shortText, longText, enumValue, reference, opaque, unknown }`
  - `typedef ConflictEnumLabeler = String? Function(AppLocalizations l10n, String stored);`
  - `class ConflictField { const ConflictField(this.label, this.kind, {this.enumLabel}); final String Function(AppLocalizations) label; final FieldKind kind; final ConflictEnumLabeler? enumLabel; }`
  - `String formatConflictValue({required AppLocalizations l10n, required UnitFormatter units, required ConflictField field, required Object? value})`
  - `String formatConflictSeconds(int seconds)`
- l10n keys added here: `settings_conflict_notSet` "Not set", `settings_conflict_changed` "Changed", `settings_conflict_same` "Same".

- [ ] **Step 1: Write the ARB insertion script (used by every later task that adds keys)**

Save at scratchpad `arb_insert.py`. It reads a JSON file `{"key": "value", "@key": {...}}` and a locale, inserts each key in `app_en.arb` before the first top-level key that sorts after it, and in a locale file after the anchor line `"settings_conflict_title"`, then proves the file still parses.

```python
import json, re, sys, pathlib

ARB_DIR = pathlib.Path('lib/l10n/arb')
KEY_LINE = re.compile(r'^  "([^"@][^"]*)":')

def line_for(key, value):
    return '  %s: %s,\n' % (json.dumps(key), json.dumps(value, ensure_ascii=False, separators=(', ', ': ')))

def insert_en(path, entries):
    lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
    keys = [k for k in entries if not k.startswith('@')]
    for key in sorted(keys):
        if any(l.startswith('  "%s":' % key) for l in lines):
            sys.exit('duplicate key %s' % key)
        block = [line_for(key, entries[key])]
        if '@' + key in entries:
            block.append(line_for('@' + key, entries['@' + key]))
        at = next(i for i, l in enumerate(lines) if (m := KEY_LINE.match(l)) and m.group(1) > key)
        lines[at:at] = block
    path.write_text(''.join(lines), encoding='utf-8')

def insert_locale(path, entries):
    lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
    at = next(i for i, l in enumerate(lines) if l.startswith('  "settings_conflict_title":'))
    assert lines[at].rstrip().endswith(','), 'anchor is the last key'
    block = []
    for key, value in entries.items():
        if key.startswith('@'):
            continue
        if any(l.startswith('  "%s":' % key) for l in lines):
            sys.exit('duplicate key %s in %s' % (key, path))
        block.append(line_for(key, value))
    lines[at + 1:at + 1] = block
    path.write_text(''.join(lines), encoding='utf-8')

if __name__ == '__main__':
    locale, entries_path = sys.argv[1], sys.argv[2]
    entries = json.loads(pathlib.Path(entries_path).read_text(encoding='utf-8'))
    path = ARB_DIR / ('app_%s.arb' % locale)
    (insert_en if locale == 'en' else insert_locale)(path, entries)
    json.loads(path.read_text(encoding='utf-8'))
    print('OK %s +%d' % (path, len([k for k in entries if not k.startswith('@')])))
```

Check the en sort assumption once before relying on it:
Run: `python3.14 -c "import re,json;ks=[m.group(1) for l in open('lib/l10n/arb/app_en.arb',encoding='utf-8') if (m:=re.match(r'^  \"([^\"@][^\"]*)\":',l))];print(ks==sorted(ks))"`
Expected: `True`. If `False`, change `insert_en` to insert after the anchor like the locales and note it in the commit.

- [ ] **Step 2: Add the three keys**

Write scratchpad `keys_task2.json`:

```json
{
  "settings_conflict_notSet": "Not set",
  "settings_conflict_changed": "Changed",
  "settings_conflict_same": "Same"
}
```

Run: `python3.14 <scratchpad>/arb_insert.py en <scratchpad>/keys_task2.json && flutter gen-l10n`
Expected: `OK lib/l10n/arb/app_en.arb +3`; gen-l10n reports untranslated messages (fine until Task 14).

- [ ] **Step 3: Write the failing tests**

Port every case from `test/features/settings/presentation/widgets/conflict_scalar_format_test.dart` (metric and imperial depth, pressure, temperature, durations including sub-minute and negative, yes/no, pre-1973 dates, `Intl.defaultLocale` pinned and restored) onto `formatConflictValue`, and add the cases below.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  String? savedLocale;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await initializeDateFormatting('en');
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDownAll(() => Intl.defaultLocale = savedLocale);

  ConflictField field(FieldKind kind, {ConflictEnumLabeler? enumLabel}) =>
      ConflictField((_) => 'x', kind, enumLabel: enumLabel);

  String fmt(UnitFormatter units, FieldKind kind, Object? value,
          {ConflictEnumLabeler? enumLabel}) =>
      formatConflictValue(
        l10n: l10n,
        units: units,
        field: field(kind, enumLabel: enumLabel),
        value: value,
      );

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      temperatureUnit: TemperatureUnit.fahrenheit,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );

  test('null is Not set for every kind', () {
    for (final kind in FieldKind.values) {
      expect(fmt(metric, kind, null), 'Not set', reason: kind.name);
    }
  });

  test('measurements follow the diver units', () {
    expect(fmt(metric, FieldKind.depth, 30.48), metric.formatDepth(30.48));
    expect(fmt(imperial, FieldKind.depth, 30.48), imperial.formatDepth(30.48));
    expect(fmt(imperial, FieldKind.weight, 4.0), imperial.formatWeight(4.0));
    expect(fmt(imperial, FieldKind.volume, 12.0), imperial.formatVolume(12.0));
    expect(fmt(imperial, FieldKind.temperature, 26.0),
        imperial.formatTemperature(26.0));
    expect(fmt(metric, FieldKind.speed, 1.2), metric.formatSpeed(1.2));
    expect(fmt(metric, FieldKind.windSpeed, 5.0), metric.formatWindSpeed(5.0));
    expect(fmt(metric, FieldKind.altitude, 300.0), metric.formatAltitude(300.0));
    expect(fmt(metric, FieldKind.heightCm, 180.0), metric.formatHeight(180.0));
    expect(fmt(metric, FieldKind.ascentRate, 9.0), metric.formatDepthRate(9.0));
    expect(fmt(metric, FieldKind.distance, 850.0), metric.formatDistance(850.0));
    expect(fmt(imperial, FieldKind.geoDistance, 2500.0),
        imperial.formatGeoDistance(2500.0));
  });

  test('ratios, coordinates and partial pressure', () {
    expect(fmt(metric, FieldKind.percent, 32.0), '32%');
    expect(fmt(metric, FieldKind.fraction, 0.25), '25%');
    expect(fmt(metric, FieldKind.partialPressure, 1.4), '1.40 bar');
    expect(fmt(metric, FieldKind.latitude, 25.5), metric.formatLatitude(25.5));
  });

  test('durations in other stored units', () {
    expect(fmt(metric, FieldKind.durationMinutes, 90), '1h 30m');
    expect(fmt(metric, FieldKind.durationHours, 1.5), '1h 30m');
  });

  test('enum values go through the labeler, unknown values print as stored',
      () {
    String? labeler(AppLocalizations l, String s) => s == 'boat' ? 'Boat' : null;
    expect(fmt(metric, FieldKind.enumValue, 'boat', enumLabel: labeler), 'Boat');
    expect(fmt(metric, FieldKind.enumValue, 'jetpack', enumLabel: labeler),
        'jetpack');
  });

  test('opaque payloads never print raw', () {
    expect(fmt(metric, FieldKind.opaque, '{"a":1}'), 'Changed');
  });

  test('a value of the wrong type renders instead of throwing', () {
    expect(fmt(metric, FieldKind.depth, '30'), '30');
    expect(fmt(metric, FieldKind.boolean, 1), 'Yes');
    expect(fmt(metric, FieldKind.boolean, 0), 'No');
    expect(fmt(metric, FieldKind.dateTime, 'not a date'), 'not a date');
    expect(fmt(metric, FieldKind.durationSeconds, 'abc'), 'abc');
  });

  test('a dateTime accepts epoch millis and ISO strings', () {
    final when = DateTime(2026, 3, 28, 10);
    final expected = metric.formatDateTime(when, l10n: l10n);
    expect(fmt(metric, FieldKind.dateTime, when.millisecondsSinceEpoch),
        expected);
    expect(fmt(metric, FieldKind.dateTime, when.toIso8601String()), expected);
  });

  test('unknown kind formats by runtime type', () {
    expect(fmt(metric, FieldKind.unknown, true), 'Yes');
    expect(fmt(metric, FieldKind.unknown, 12), '12');
  });
}
```

If `AppSettings` names its volume or weight unit fields differently, read `lib/features/settings/presentation/providers/settings_providers.dart` and use the real names; do not drop the imperial assertions.

- [ ] **Step 4: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_field_format_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 5: Implement `conflict_field.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How a synced column's stored value is shown. Units are always the stored
/// (metric) ones: depth in metres, pressure in bar, temperature in Celsius,
/// weight in kg, volume in litres, speed in m/s.
enum FieldKind {
  depth,

  /// Short horizontal metres in the depth unit (visibility, surface drift).
  distance,

  /// Metres that may run to kilometres (track totals), auto-scaled.
  geoDistance,
  pressure,
  temperature,
  weight,
  volume,
  speed,
  windSpeed,
  altitude,
  heightCm,
  ascentRate,
  latitude,
  longitude,
  percent,
  fraction,
  partialPressure,
  durationSeconds,
  durationMinutes,
  durationHours,
  dateTime,
  date,
  boolean,
  number,
  shortText,
  longText,
  enumValue,
  reference,
  opaque,

  /// Not in the catalogue; formatted by the value's runtime type.
  unknown,
}

/// The stored value's localized label, or null for a value this build does
/// not know (a newer peer wrote it).
typedef ConflictEnumLabeler =
    String? Function(AppLocalizations l10n, String stored);

/// What the conflict dialog knows about one column.
@immutable
class ConflictField {
  const ConflictField(this.label, this.kind, {this.enumLabel});

  final String Function(AppLocalizations l10n) label;
  final FieldKind kind;

  /// Required for [FieldKind.enumValue], ignored otherwise.
  final ConflictEnumLabeler? enumLabel;
}
```

- [ ] **Step 6: Implement `conflict_field_format.dart`**

```dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Renders [value] the way the app renders it elsewhere. Never throws: a
/// value of an unexpected type (an older peer, a hand-edited row) prints as
/// stored, because a dialog that crashes leaves the conflict unresolvable.
String formatConflictValue({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required ConflictField field,
  required Object? value,
}) {
  if (value == null) return l10n.settings_conflict_notSet;
  final number = value is num ? value.toDouble() : null;

  switch (field.kind) {
    case FieldKind.opaque:
      return l10n.settings_conflict_changed;
    case FieldKind.boolean:
      if (value is bool) return _yesNo(l10n, value);
      if (value is num) return _yesNo(l10n, value != 0);
      return value.toString();
    case FieldKind.enumValue:
      if (value is String) return field.enumLabel?.call(l10n, value) ?? value;
      return value.toString();
    case FieldKind.dateTime:
    case FieldKind.date:
      final moment = _moment(value);
      if (moment == null) return value.toString();
      return field.kind == FieldKind.date
          ? units.formatDate(moment)
          : units.formatDateTime(moment, l10n: l10n);
    case FieldKind.unknown:
      if (value is bool) return _yesNo(l10n, value);
      return value.toString();
    case FieldKind.number:
    case FieldKind.shortText:
    case FieldKind.longText:
    case FieldKind.reference:
      return value.toString();
    default:
      break;
  }

  if (number == null) return value.toString();
  return switch (field.kind) {
    FieldKind.depth => units.formatDepth(number),
    FieldKind.distance => units.formatDistance(number),
    FieldKind.geoDistance => units.formatGeoDistance(number),
    FieldKind.pressure => units.formatPressure(number),
    FieldKind.temperature => units.formatTemperature(number),
    FieldKind.weight => units.formatWeight(number),
    FieldKind.volume => units.formatVolume(number),
    FieldKind.speed => units.formatSpeed(number),
    FieldKind.windSpeed => units.formatWindSpeed(number),
    FieldKind.altitude => units.formatAltitude(number),
    FieldKind.heightCm => units.formatHeight(number),
    FieldKind.ascentRate => units.formatDepthRate(number),
    FieldKind.latitude => units.formatLatitude(number),
    FieldKind.longitude => units.formatLongitude(number),
    FieldKind.percent => '${_trim(number)}%',
    FieldKind.fraction => '${_trim(number * 100)}%',
    FieldKind.partialPressure => '${number.toStringAsFixed(2)} bar',
    FieldKind.durationSeconds => formatConflictSeconds(number.round()),
    FieldKind.durationMinutes => formatConflictSeconds((number * 60).round()),
    FieldKind.durationHours => formatConflictSeconds((number * 3600).round()),
    _ => value.toString(),
  };
}

String _yesNo(AppLocalizations l10n, bool value) =>
    value ? l10n.common_action_yes : l10n.common_action_no;

DateTime? _moment(Object value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is DateTime) return value;
  return null;
}

/// 32.0 -> "32", 32.5 -> "32.5".
String _trim(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// A stored count of seconds as "1h 5m" or "45min". Under a minute keeps its
/// seconds, so two versions differing by a few seconds still read differently;
/// a negative value shows itself rather than wrapping.
String formatConflictSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}min';
}
```

- [ ] **Step 7: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_field_format_test.dart`
Expected: PASS. A failing ISO-string date case means `toLocal()` shifted the hour: compare with `metric.formatDateTime(when, l10n: l10n)` where `when` is local, as written.

- [ ] **Step 8: Format, analyze, architecture, commit**

```bash
dart format lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts lib/l10n/arb
git commit -m "feat(settings): format conflict values by field kind"
```

---

### Task 3: Enum value labelers

**Files:**
- Create: `lib/features/settings/presentation/conflicts/conflict_enum_labels.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_enum_labels_test.dart`

**Interfaces:**
- Consumes: `ConflictEnumLabeler` (Task 2).
- Produces: `ConflictEnumLabeler enumLabeler<T extends Enum>(List<T> values, String Function(AppLocalizations l10n, T value) label, {String Function(T value)? storedAs})`; top-level labelers named `<enumCamel>Labeler`, starting with `entryMethodLabeler`, `visibilityLabeler`, `waterTypeLabeler`, `currentDirectionLabeler`, `currentStrengthLabeler`, `cloudCoverLabeler`, `precipitationLabeler`. Tasks 9 to 13 add the rest.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('labels a stored enum name with the app label', () {
    expect(entryMethodLabeler(l10n, 'boat'), l10n.enum_entryMethod_boat);
    expect(visibilityLabeler(l10n, 'good'), l10n.enum_visibility_good);
  });

  test('returns null for a value this build does not know', () {
    expect(entryMethodLabeler(l10n, 'jetpack'), isNull);
    expect(entryMethodLabeler(l10n, ''), isNull);
  });

  test('storedAs maps an enum stored by code rather than by name', () {
    final labeler = enumLabeler<_Mode>(
      _Mode.values,
      (l, m) => m.name.toUpperCase(),
      storedAs: (m) => m.code,
    );
    expect(labeler(l10n, 'oc'), 'OPEN');
    expect(labeler(l10n, 'open'), isNull);
  });
}

enum _Mode {
  open('oc');

  const _Mode(this.code);
  final String code;
}
```

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_enum_labels_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement**

Verify each stored form first: the value a repository writes for the column. For `entryMethod` read the dive repository's insert/update (`grep -rn "entryMethod:" lib/features/dive_log/data`) and confirm it writes `.name`. If a column is written with a code (`DiveMode.code`), pass `storedAs`.

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Builds a labeler for an enum stored by name (or by [storedAs]). An unknown
/// stored value yields null so the formatter prints it as stored.
ConflictEnumLabeler enumLabeler<T extends Enum>(
  List<T> values,
  String Function(AppLocalizations l10n, T value) label, {
  String Function(T value)? storedAs,
}) {
  final byStored = {for (final v in values) (storedAs?.call(v) ?? v.name): v};
  return (l10n, stored) {
    final value = byStored[stored];
    return value == null ? null : label(l10n, value);
  };
}

final ConflictEnumLabeler entryMethodLabeler = enumLabeler(
  EntryMethod.values,
  (l, v) => v.localizedName(l),
);
```

Add `visibilityLabeler`, `waterTypeLabeler`, `currentDirectionLabeler`, `currentStrengthLabeler`, `cloudCoverLabeler` and `precipitationLabeler` the same way, using the extension each enum already has (open `environment_enum_display.dart` and `visibility_display.dart` for the exact method names; `Visibility` may use a different method than `localizedName`).

- [ ] **Step 4: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_enum_labels_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, architecture, commit**

```bash
dart format lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
git commit -m "feat(settings): label stored enum values in conflicts"
```

---

### Task 4: Catalogue lookup and coverage guard

**Files:**
- Create: `lib/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_field_catalogue_test.dart`

**Interfaces:**
- Consumes: `ConflictField`, `FieldKind` (Task 2); `ConflictReferenceResolver.targetTypeFor` (existing, `lib/core/services/sync/conflict_reference.dart`); `humanizeEntityType` (existing, `conflict_reference_labels.dart`).
- Produces:
  - `const conflictBookkeepingColumns = {'id', 'hlc', 'deviceId', 'originDeviceId', 'syncedAt', 'createdAt', 'updatedAt'};`
  - `ConflictField conflictFieldFor(String entityType, String column)` (falls back to a humanized label and `FieldKind.unknown`)
  - `bool isConflictFieldCovered(String entityType, String column)` (bookkeeping, a known foreign key, a catalogue entry or an override)
  - The catalogue is `final Map<String, ConflictField> conflictFieldCatalogue` merged from the domain maps, and `final Map<String, ConflictField> conflictFieldOverrides` keyed `'<entityType>.<column>'`. Each domain file exports `final Map<String, ConflictField> <domain>Fields` and `final Map<String, ConflictField> <domain>Overrides`.

- [ ] **Step 1: Write the failing lookup test**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('an unknown column falls back to a humanized label', () {
    final field = conflictFieldFor('dives', 'someFutureColumn');
    expect(field.label(l10n), 'Some Future Column');
    expect(field.kind, FieldKind.unknown);
  });

  test('bookkeeping and foreign keys are covered without an entry', () {
    expect(isConflictFieldCovered('dives', 'hlc'), isTrue);
    expect(isConflictFieldCovered('dives', 'siteId'), isTrue);
    expect(isConflictFieldCovered('dives', 'someFutureColumn'), isFalse);
  });
}
```

- [ ] **Step 2: Write the coverage guard**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';

import '../../../../helpers/test_database.dart';

/// Entities whose catalogue lands in a later task of the #694 plan. Emptied
/// task by task; Task 13 deletes it.
const _pending = <String>{
  // Every key of SyncService.entityHasUpdatedAt, pasted from Step 3's output.
};

/// Every column of every synced table must have a label and a value kind in
/// the conflict catalogue, or the Resolve Conflicts dialog shows a raw column
/// name to the diver (#694). Driven off the live Drift schema, so a new synced
/// column fails here until it is catalogued.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  for (final entity in SyncService.entityHasUpdatedAt.keys) {
    test(
      'every $entity column has a conflict label',
      () {
        final table = SyncDataSerializer().syncTableFor(entity);
        final missing = [
          for (final column in table.$columns)
            if (!isConflictFieldCovered(entity, _camelCase(column.name)))
              '${_camelCase(column.name)} (${column.type.name})',
        ];
        expect(
          missing,
          isEmpty,
          reason:
              '$entity has columns with no conflict catalogue entry. Add '
              'each to lib/features/settings/presentation/conflicts/'
              'catalogue/ with a label and a FieldKind.',
        );
      },
      skip: _pending.contains(entity)
          ? 'catalogued in a later task of the #694 plan'
          : false,
    );
  }
}

/// Drift's SQL name back to the JSON key `toJson` uses. No synced column
/// uses `.named(...)`, so the getter is always the camelCase of the SQL name.
String _camelCase(String columnName) {
  final parts = columnName.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
```

- [ ] **Step 3: Fill `_pending`**

Run: `python3.14 -c "import re;src=open('lib/core/services/sync/sync_service.dart',encoding='utf-8').read();blk=src[src.index('entityHasUpdatedAt = {'):];blk=blk[:blk.index('};')];print(',\n'.join(\"  '%s'\" % k for k in re.findall(r\"'(\w+)':\",blk)))"`
Expected: 101 lines. Paste them into `_pending`.

- [ ] **Step 4: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/`
Expected: FAIL, the catalogue file is missing.

- [ ] **Step 5: Implement the lookup**

```dart
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';

/// Sync bookkeeping on nearly every record. Never compared, never listed.
const conflictBookkeepingColumns = <String>{
  'id',
  'hlc',
  'deviceId',
  'originDeviceId',
  'syncedAt',
  'createdAt',
  'updatedAt',
};

/// One entry per column name, for names that mean the same thing on every
/// entity. Domain maps are merged in Tasks 9 to 13; a name in two domain maps
/// must agree, which the merge asserts.
final Map<String, ConflictField> conflictFieldCatalogue = _merge([]);

/// Entity-specific meanings, keyed `'<entityType>.<column>'`. Checked before
/// [conflictFieldCatalogue].
final Map<String, ConflictField> conflictFieldOverrides = _merge([]);

Map<String, ConflictField> _merge(List<Map<String, ConflictField>> maps) {
  final out = <String, ConflictField>{};
  for (final map in maps) {
    for (final entry in map.entries) {
      assert(
        !out.containsKey(entry.key),
        '${entry.key} is catalogued twice; keep one entry or use an override',
      );
      out[entry.key] = entry.value;
    }
  }
  return Map.unmodifiable(out);
}

ConflictField conflictFieldFor(String entityType, String column) =>
    conflictFieldOverrides['$entityType.$column'] ??
    conflictFieldCatalogue[column] ??
    ConflictField((_) => humanizeEntityType(column), FieldKind.unknown);

bool isConflictFieldCovered(String entityType, String column) =>
    conflictBookkeepingColumns.contains(column) ||
    ConflictReferenceResolver.targetTypeFor(entityType, column) != null ||
    conflictFieldOverrides.containsKey('$entityType.$column') ||
    conflictFieldCatalogue.containsKey(column);
```

- [ ] **Step 6: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/`
Expected: PASS, with 101 skipped guard cases.

- [ ] **Step 7: Format, analyze, architecture, commit**

```bash
dart format lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
git commit -m "feat(settings): conflict field catalogue lookup and coverage guard"
```

---

### Task 5: Device labels

**Files:**
- Create: `lib/features/settings/presentation/conflicts/conflict_device_labels.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (add `conflictLocalDeviceProvider` next to `peerDeviceNamesProvider`)
- Modify: `lib/l10n/arb/app_en.arb` (2 keys) and generated files
- Test: `test/features/settings/presentation/conflicts/conflict_device_labels_test.dart`

**Interfaces:**
- Produces:
  - `class ConflictDeviceLabels { const ConflictDeviceLabels({required this.local, required this.remote}); final String local; final String remote; }`
  - `ConflictDeviceLabels conflictDeviceLabels({required AppLocalizations l10n, required String? localName, required String? localDeviceId, required Map<String, String> peerNames, required Map<String, dynamic> remoteData})`
  - `final conflictLocalDeviceProvider = FutureProvider<({String? id, String? name})>`
- l10n: `settings_conflict_thisDevice` "This device", `settings_conflict_otherDevice` "Other device".

- [ ] **Step 1: Add the keys**

Scratchpad `keys_task5.json`:

```json
{
  "settings_conflict_thisDevice": "This device",
  "settings_conflict_otherDevice": "Other device"
}
```

Run: `python3.14 <scratchpad>/arb_insert.py en <scratchpad>/keys_task5.json && flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ConflictDeviceLabels labels({
    String? localName = 'Pixel 8',
    String? localId = 'local-id',
    Map<String, String> peers = const {'peer-id': 'Windows PC'},
    String? hlc = '1786556582600:0:peer-id',
  }) => conflictDeviceLabels(
    l10n: l10n,
    localName: localName,
    localDeviceId: localId,
    peerNames: peers,
    remoteData: {if (hlc != null) 'hlc': hlc},
  );

  test('names both devices', () {
    final l = labels();
    expect(l.local, 'Pixel 8');
    expect(l.remote, 'Windows PC');
  });

  test('an unknown peer is the other device', () {
    expect(labels(peers: const {}).remote, 'Other device');
  });

  test('a missing local name is this device', () {
    expect(labels(localName: null).local, 'This device');
    expect(labels(localName: '  ').local, 'This device');
  });

  test('an unparseable or missing hlc is the other device', () {
    expect(labels(hlc: 'garbage').remote, 'Other device');
    expect(labels(hlc: null).remote, 'Other device');
  });

  test('a remote row last written by this device does not borrow a name', () {
    final l = labels(hlc: '1786556582600:0:local-id', peers: const {
      'local-id': 'Pixel 8',
    });
    expect(l.local, 'This device');
    expect(l.remote, 'Other device');
  });

  test('two devices with the same name fall back to generic labels', () {
    final l = labels(peers: const {'peer-id': 'pixel 8 '});
    expect(l.local, 'This device');
    expect(l.remote, 'Other device');
  });
}
```

- [ ] **Step 3: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_device_labels_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 4: Implement**

```dart
import 'package:flutter/foundation.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

@immutable
class ConflictDeviceLabels {
  const ConflictDeviceLabels({required this.local, required this.remote});

  final String local;
  final String remote;
}

/// Names the two sides of a conflict by device. The remote side is named by
/// the device that last wrote the remote row (the nodeId in its hlc), looked
/// up in the names peers publish on their manifests.
///
/// The labels exist to tell the sides apart, so whenever they could read the
/// same (one name for both, or the remote row written by this device) both
/// fall back to the generic pair.
ConflictDeviceLabels conflictDeviceLabels({
  required AppLocalizations l10n,
  required String? localName,
  required String? localDeviceId,
  required Map<String, String> peerNames,
  required Map<String, dynamic> remoteData,
}) {
  final generic = ConflictDeviceLabels(
    local: l10n.settings_conflict_thisDevice,
    remote: l10n.settings_conflict_otherDevice,
  );
  final writer = _writerOf(remoteData);
  if (writer != null && writer == localDeviceId) return generic;

  final local = localName?.trim();
  final remote = writer == null ? null : peerNames[writer]?.trim();
  final localLabel = (local == null || local.isEmpty) ? generic.local : local;
  final remoteLabel = (remote == null || remote.isEmpty)
      ? generic.remote
      : remote;
  if (localLabel.toLowerCase() == remoteLabel.toLowerCase()) return generic;
  return ConflictDeviceLabels(local: localLabel, remote: remoteLabel);
}

String? _writerOf(Map<String, dynamic> data) {
  final hlc = data['hlc'];
  if (hlc is! String) return null;
  try {
    return Hlc.parse(hlc).nodeId;
  } on FormatException {
    return null;
  }
}
```

In `sync_providers.dart`, below `peerDeviceNamesProvider` (add imports for `SyncDeviceMetadata` and `SyncRepository` if missing):

```dart
/// This device's id and display name, for labelling the local side of a
/// sync conflict. Same resolver the manifests use, so a peer sees this
/// device under the same name.
final conflictLocalDeviceProvider = FutureProvider<({String? id, String? name})>(
  (ref) async {
    final identity = await SyncDeviceMetadata(SyncRepository()).resolve();
    return (id: identity.id, name: identity.name);
  },
);
```

If `Hlc.parse` throws something other than `FormatException` for `'garbage'` (for example a `RangeError`), catch that type too and keep the test.

- [ ] **Step 5: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_device_labels_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, architecture, commit**

```bash
dart format lib test
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts lib/features/settings/presentation/providers/sync_providers.dart test/features/settings/presentation/conflicts lib/l10n/arb
git commit -m "feat(settings): name the devices on each side of a conflict"
```

---

### Task 6: Comparison model

**Files:**
- Create: `lib/features/settings/presentation/conflicts/conflict_finding_message.dart` (move `_findingMessage` and its imports from `conflict_data_preview.dart`, renamed `conflictFindingMessage`, unchanged otherwise)
- Create: `lib/features/settings/presentation/conflicts/conflict_comparison.dart`
- Test: `test/features/settings/presentation/conflicts/conflict_comparison_test.dart`

**Interfaces:**
- Consumes: `conflictFieldFor`, `conflictBookkeepingColumns` (Task 4); `formatConflictValue` (Task 2); `ConflictReferenceResolver.targetTypeFor`, `conflictReferenceLabel`, `conflictReferenceValue` (existing).
- Produces:

```dart
enum ConflictComparisonState { differing, remoteDeleted, localDeleted, sameContent }

class FieldDifference {
  final String key;
  final String label;
  final FieldKind kind;
  final Object? localValue;
  final Object? remoteValue;
  final String localDisplay;
  final String remoteDisplay;
}

class ShownField { final String key; final String label; final String display; }

class ConflictComparison {
  final ConflictComparisonState state;
  final List<FieldDifference> differences; // differing only
  final List<ShownField> unchanged;        // differing and sameContent
  final List<ShownField> survivingValues;  // remoteDeleted (local values) and localDeleted (remote values)
}

ConflictComparison buildConflictComparison({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required SyncConflict conflict,
});

QualityFindingMessage? conflictFindingMessage(AppLocalizations l10n, UnitFormatter units, Map<String, dynamic> data);
```

- [ ] **Step 1: Write the failing tests**

Use `conflictFieldFor`'s fallback for columns not yet catalogued; these tests rely only on behaviour, with labels compared through `conflictFieldFor(...).label(l10n)`.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  const units = UnitFormatter(AppSettings());
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  SyncConflict conflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote, {
    String entityType = 'dives',
    List<ConflictReference> localRefs = const [],
    List<ConflictReference> remoteRefs = const [],
  }) => SyncConflict(
    entityType: entityType,
    recordId: 'r1',
    localData: local,
    remoteData: remote,
    localModified: DateTime(2026),
    remoteModified: DateTime(2026),
    localReferences: localRefs,
    remoteReferences: remoteRefs,
  );

  ConflictComparison compare(SyncConflict c) =>
      buildConflictComparison(l10n: l10n, units: units, conflict: c);

  test('lists every differing field, no cap', () {
    final local = {for (var i = 0; i < 12; i++) 'field$i': i};
    final remote = {for (var i = 0; i < 12; i++) 'field$i': i + 100};
    final result = compare(conflict(local, remote));
    expect(result.state, ConflictComparisonState.differing);
    expect(result.differences, hasLength(12));
  });

  test('bookkeeping never counts as a difference', () {
    final result = compare(conflict(
      {'id': 'r1', 'name': 'A', 'hlc': '1:0:a', 'updatedAt': 1},
      {'id': 'r1', 'name': 'A', 'hlc': '2:0:b', 'updatedAt': 2},
    ));
    expect(result.state, ConflictComparisonState.sameContent);
    expect(result.unchanged.map((f) => f.key), ['name']);
  });

  test('a key the remote omits is not a difference', () {
    final result = compare(conflict(
      {'name': 'A', 'notes': 'kept locally'},
      {'name': 'B'},
    ));
    expect(result.differences.map((d) => d.key), ['name']);
    expect(result.unchanged.map((f) => f.key), ['notes']);
  });

  test('an explicit null is a difference shown as Not set', () {
    final result = compare(conflict({'notes': 'x'}, {'notes': null}));
    expect(result.differences.single.remoteDisplay, 'Not set');
  });

  test('a key only the remote has is ignored', () {
    final result = compare(conflict({'name': 'A'}, {'name': 'A', 'future': 1}));
    expect(result.state, ConflictComparisonState.sameContent);
    expect(result.unchanged.map((f) => f.key), ['name']);
  });

  test('int and double of the same value are equal', () {
    final result = compare(conflict({'waterTemp': 26.0}, {'waterTemp': 26}));
    expect(result.state, ConflictComparisonState.sameContent);
  });

  test('a remote deletion shows the local values that would go', () {
    final result = compare(conflict(
      {'name': 'Blue Hole', 'maxDepth': 30.0},
      {'id': 'r1', '_deleted': true, 'deletedAt': 5},
    ));
    expect(result.state, ConflictComparisonState.remoteDeleted);
    expect(result.differences, isEmpty);
    expect(result.survivingValues.map((f) => f.key), ['name', 'maxDepth']);
  });

  test('a local deletion shows the remote values', () {
    final result = compare(conflict({}, {'name': 'Blue Hole'}));
    expect(result.state, ConflictComparisonState.localDeleted);
    expect(result.survivingValues.single.display, 'Blue Hole');
  });

  test('preferred fields lead, the rest follow by label', () {
    final result = compare(conflict(
      {'zeta': 1, 'notes': 'a', 'alpha': 1, 'name': 'A'},
      {'zeta': 2, 'notes': 'b', 'alpha': 2, 'name': 'B'},
    ));
    expect(result.differences.map((d) => d.key), [
      'name',
      'notes',
      'alpha',
      'zeta',
    ]);
  });

  test('a foreign key is compared by id and shown by name', () {
    const localSite = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's1',
      name: 'Blue Hole',
    );
    const remoteSite = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's2',
      name: 'Shark Point',
    );
    final result = compare(conflict(
      {'siteId': 's1'},
      {'siteId': 's2'},
      localRefs: [localSite],
      remoteRefs: [remoteSite],
    ));
    final diff = result.differences.single;
    expect(diff.label, l10n.settings_conflict_ref_diveSite);
    expect(diff.localDisplay, 'Blue Hole');
    expect(diff.remoteDisplay, 'Shark Point');
  });

  test('a foreign key set on one side only reads Not set on the other', () {
    const site = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's1',
      name: 'Blue Hole',
    );
    final result = compare(conflict(
      {'siteId': 's1'},
      {'siteId': null},
      localRefs: [site],
    ));
    expect(result.differences.single.remoteDisplay, 'Not set');
  });
}
```

Also port the quality-finding cases from `test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart` lines 261 to 480 as comparison tests: a readable finding yields a difference labelled `l10n.settings_conflict_ref_finding` whose displays are the two messages and hides `detectorId`, `detectorVersion`, `params`, `category`; an unreadable finding (bad category, missing column, malformed params) keeps those columns as plain differences.

- [ ] **Step 2: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_comparison_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Move the finding helper**

Create `conflict_finding_message.dart` with the body of `_findingMessage` from `lib/features/settings/presentation/widgets/conflict_data_preview.dart:333-375` (its imports: `dart:convert`, logger, `QualityFinding`, `buildFindingMessage`, `qualityUnitFormattersFor`), renamed to the public `conflictFindingMessage`, with a logger `LoggerService.forClass(ConflictComparison)` replaced by `LoggerService.forName('ConflictFindingMessage')` if `forClass` needs a type that is not imported (check `LoggerService` for the available constructor).

- [ ] **Step 4: Implement the comparison**

```dart
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_finding_message.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

enum ConflictComparisonState { differing, remoteDeleted, localDeleted, sameContent }

@immutable
class FieldDifference {
  const FieldDifference({
    required this.key,
    required this.label,
    required this.kind,
    required this.localValue,
    required this.remoteValue,
    required this.localDisplay,
    required this.remoteDisplay,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final Object? localValue;
  final Object? remoteValue;
  final String localDisplay;
  final String remoteDisplay;
}

@immutable
class ShownField {
  const ShownField({required this.key, required this.label, required this.display});

  final String key;
  final String label;
  final String display;
}

@immutable
class ConflictComparison {
  const ConflictComparison({
    required this.state,
    this.differences = const [],
    this.unchanged = const [],
    this.survivingValues = const [],
  });

  final ConflictComparisonState state;
  final List<FieldDifference> differences;
  final List<ShownField> unchanged;
  final List<ShownField> survivingValues;
}

/// Fields a diver recognizes a record by, so they lead the list.
const _preferredOrder = <String>[
  'name',
  'title',
  'diveNumber',
  'diveDateTime',
  'date',
  'location',
  'maxDepth',
  'runtime',
  'bottomTime',
  'duration',
  'notes',
  'description',
];

/// Raw finding columns the finding sentence replaces.
const _findingColumns = {'detectorId', 'detectorVersion', 'params', 'category'};

const _equality = DeepCollectionEquality();

bool _same(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  return _equality.equals(a, b);
}

ConflictComparison buildConflictComparison({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required SyncConflict conflict,
}) {
  final entity = conflict.entityType;
  final local = conflict.localData;
  final remote = conflict.remoteData;
  final localRefs = {for (final r in conflict.localReferences) r.field: r};
  final remoteRefs = {for (final r in conflict.remoteReferences) r.field: r};

  String labelFor(String key) {
    final target = ConflictReferenceResolver.targetTypeFor(entity, key);
    if (target == null) return conflictFieldFor(entity, key).label(l10n);
    final reference = localRefs[key] ?? remoteRefs[key] ??
        ConflictReference(field: key, targetType: target, recordId: '');
    return conflictReferenceLabel(l10n, reference);
  }

  String display(String key, Object? value, Map<String, ConflictReference> refs) {
    if (value == null) return l10n.settings_conflict_notSet;
    final reference = refs[key];
    if (reference != null) return conflictReferenceValue(l10n, units, reference);
    return formatConflictValue(
      l10n: l10n,
      units: units,
      field: conflictFieldFor(entity, key),
      value: value,
    );
  }

  List<ShownField> shown(Map<String, dynamic> data, Map<String, ConflictReference> refs) =>
      _sorted([
        for (final entry in data.entries)
          if (_compared(entry.key) && entry.value != null)
            ShownField(
              key: entry.key,
              label: labelFor(entry.key),
              display: display(entry.key, entry.value, refs),
            ),
      ], (f) => f.key, (f) => f.label);

  if (remote['_deleted'] == true) {
    return ConflictComparison(
      state: ConflictComparisonState.remoteDeleted,
      survivingValues: shown(local, localRefs),
    );
  }
  if (local.isEmpty) {
    return ConflictComparison(
      state: ConflictComparisonState.localDeleted,
      survivingValues: shown(remote, remoteRefs),
    );
  }

  final differences = <FieldDifference>[];
  final unchanged = <ShownField>[];

  final hidden = <String>{};
  if (entity == 'qualityFindings') {
    final localMessage = conflictFindingMessage(l10n, units, local);
    final remoteMessage = conflictFindingMessage(l10n, units, remote);
    if (localMessage != null && remoteMessage != null) {
      hidden.addAll(_findingColumns);
      final l = '${localMessage.title}: ${localMessage.detail}';
      final r = '${remoteMessage.title}: ${remoteMessage.detail}';
      if (l != r) {
        differences.add(FieldDifference(
          key: '_finding',
          label: l10n.settings_conflict_ref_finding,
          kind: FieldKind.shortText,
          localValue: l,
          remoteValue: r,
          localDisplay: l,
          remoteDisplay: r,
        ));
      }
    }
  }

  for (final entry in local.entries) {
    final key = entry.key;
    if (!_compared(key) || hidden.contains(key)) continue;
    // A key the remote map omits keeps its local value under every choice.
    if (!remote.containsKey(key) || _same(entry.value, remote[key])) {
      if (entry.value != null) {
        unchanged.add(ShownField(
          key: key,
          label: labelFor(key),
          display: display(key, entry.value, localRefs),
        ));
      }
      continue;
    }
    differences.add(FieldDifference(
      key: key,
      label: labelFor(key),
      kind: conflictFieldFor(entity, key).kind,
      localValue: entry.value,
      remoteValue: remote[key],
      localDisplay: display(key, entry.value, localRefs),
      remoteDisplay: display(key, remote[key], remoteRefs),
    ));
  }

  final sortedDifferences = _sorted(differences, (d) => d.key, (d) => d.label);
  return ConflictComparison(
    state: sortedDifferences.isEmpty
        ? ConflictComparisonState.sameContent
        : ConflictComparisonState.differing,
    differences: sortedDifferences,
    unchanged: _sorted(unchanged, (f) => f.key, (f) => f.label),
  );
}

bool _compared(String key) =>
    !conflictBookkeepingColumns.contains(key) && !key.startsWith('_') &&
    key != 'deletedAt';

List<T> _sorted<T>(List<T> items, String Function(T) key, String Function(T) label) {
  int rank(T item) {
    final i = _preferredOrder.indexOf(key(item));
    return i < 0 ? _preferredOrder.length : i;
  }

  // The finding sentence, keyed '_finding', always leads.
  int lead(T item) => key(item) == '_finding' ? -1 : rank(item);
  return List.unmodifiable(
    [...items]..sort((a, b) {
      final byRank = lead(a).compareTo(lead(b));
      return byRank != 0 ? byRank : label(a).compareTo(label(b));
    }),
  );
}
```

Note: `_compared` excludes `deletedAt` because only a remote tombstone carries it; no synced table has a `deleted_at` column (checked against the live Drift schema on 2026-10-05). If one is ever added, exclude it only in the deletion states.

- [ ] **Step 5: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_comparison_test.dart`
Expected: PASS. If the ordering test fails on `alpha` versus `zeta`, check that fallback labels humanize to `Alpha` and `Zeta`.

- [ ] **Step 6: Format, analyze, architecture, commit**

```bash
dart format lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts
git commit -m "feat(settings): compare the two versions of a conflicting record"
```

---

### Task 7: Comparison widgets

**Files:**
- Create: `lib/features/settings/presentation/conflicts/widgets/conflict_text_diff.dart`
- Create: `lib/features/settings/presentation/conflicts/widgets/conflict_difference_list.dart`
- Create: `lib/features/settings/presentation/conflicts/widgets/conflict_comparison_view.dart`
- Modify: `lib/l10n/arb/app_en.arb` and generated files
- Test: `test/features/settings/presentation/conflicts/widgets/conflict_comparison_view_test.dart`

**Interfaces:**
- Consumes: `ConflictComparison`, `FieldDifference`, `ShownField` (Task 6); `diffWords`, `WordDiff` (Task 1); `ConflictDeviceLabels` (Task 5).
- Produces:
  - `ConflictTextDiff({required List<DiffSpan> spans, required Color highlight, required Color onHighlight})`
  - `ConflictDifferenceList({required List<FieldDifference> differences, required ConflictDeviceLabels devices})`; switches to stacked blocks below `kConflictTableMinWidth = 480` of its own width
  - `ConflictComparisonView({required ConflictComparison comparison, required ConflictDeviceLabels devices, required String localModified, required String remoteModified})`
- l10n keys (scratchpad `keys_task7.json`):

```json
{
  "settings_conflict_modifiedBy": "{device} · modified {time}",
  "@settings_conflict_modifiedBy": {"placeholders": {"device": {"type": "String"}, "time": {"type": "String"}}},
  "settings_conflict_whatDiffers": "What differs ({count})",
  "@settings_conflict_whatDiffers": {"placeholders": {"count": {"type": "int"}}},
  "settings_conflict_sameFields": "{count, plural, one{{count} field is the same} other{{count} fields are the same}}",
  "@settings_conflict_sameFields": {"placeholders": {"count": {"type": "int"}}},
  "settings_conflict_fieldHeader": "Field",
  "settings_conflict_textDiffHint": "Highlighted words appear only in that version.",
  "settings_conflict_whitespaceOnly": "Only spacing or line breaks differ.",
  "settings_conflict_remoteDeleted": "{device} deleted this record.",
  "@settings_conflict_remoteDeleted": {"placeholders": {"device": {"type": "String"}}},
  "settings_conflict_localDeleted": "{device} deleted this record.",
  "@settings_conflict_localDeleted": {"placeholders": {"device": {"type": "String"}}},
  "settings_conflict_sameContent": "Both versions have the same content; only the time they were saved differs. Either choice keeps everything.",
  "settings_conflict_deletedValues": "The record as {device} has it:",
  "@settings_conflict_deletedValues": {"placeholders": {"device": {"type": "String"}}}
}
```

The `·` is U+00B7 MIDDLE DOT; write it into the JSON file through the script, not with a backslash escape in an editor tool.

- [ ] **Step 1: Add the keys**

Run: `python3.14 <scratchpad>/arb_insert.py en <scratchpad>/keys_task7.json && flutter gen-l10n`

- [ ] **Step 2: Write the failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_comparison_view.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_text_diff.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _devices = ConflictDeviceLabels(local: 'Pixel 8', remote: 'Windows PC');

FieldDifference _diff(String key, Object local, Object remote,
        {FieldKind kind = FieldKind.shortText}) =>
    FieldDifference(
      key: key,
      label: key,
      kind: kind,
      localValue: local,
      remoteValue: remote,
      localDisplay: '$local',
      remoteDisplay: '$remote',
    );

Future<void> _pump(WidgetTester tester, ConflictComparison c, {double width = 700}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ConflictComparisonView(
          comparison: c,
          devices: _devices,
          localModified: '2 hours ago',
          remoteModified: '5 hours ago',
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final differing = ConflictComparison(
    state: ConflictComparisonState.differing,
    differences: [_diff('Water temp', '26 C', '27 C')],
    unchanged: const [
      ShownField(key: 'name', label: 'Name', display: 'Blue Hole'),
      ShownField(key: 'maxDepth', label: 'Max depth', display: '31.4m'),
    ],
  );

  testWidgets('wide layout shows a table with device headers', (tester) async {
    await _pump(tester, differing);
    expect(find.text('What differs (1)'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Pixel 8'), findsWidgets);
    expect(find.text('Windows PC'), findsWidgets);
    expect(find.text('26 C'), findsOneWidget);
    expect(find.text('27 C'), findsOneWidget);
  });

  testWidgets('narrow layout stacks each field', (tester) async {
    await _pump(tester, differing, width: 360);
    expect(find.byType(Table), findsNothing);
    expect(find.text('26 C'), findsOneWidget);
  });

  testWidgets('unchanged fields are collapsed until expanded', (tester) async {
    await _pump(tester, differing);
    expect(find.text('2 fields are the same'), findsOneWidget);
    expect(find.text('Blue Hole'), findsNothing);
    await tester.tap(find.text('2 fields are the same'));
    await tester.pumpAndSettle();
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('long text is highlighted word by word', (tester) async {
    await _pump(tester, ConflictComparison(
      state: ConflictComparisonState.differing,
      differences: [
        _diff('Notes', 'Saw a turtle.', 'Saw two turtles.', kind: FieldKind.longText),
      ],
    ));
    expect(find.byType(ConflictTextDiff), findsNWidgets(2));
    expect(find.text('Highlighted words appear only in that version.'), findsOneWidget);
  });

  testWidgets('whitespace-only text differences say so', (tester) async {
    await _pump(tester, ConflictComparison(
      state: ConflictComparisonState.differing,
      differences: [
        _diff('Notes', 'One two', 'One  two', kind: FieldKind.longText),
      ],
    ));
    expect(find.text('Only spacing or line breaks differ.'), findsOneWidget);
  });

  testWidgets('a remote deletion is a banner over the local values', (tester) async {
    await _pump(tester, const ConflictComparison(
      state: ConflictComparisonState.remoteDeleted,
      survivingValues: [ShownField(key: 'name', label: 'Name', display: 'Blue Hole')],
    ));
    expect(find.text('Windows PC deleted this record.'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.textContaining('What differs'), findsNothing);
  });

  testWidgets('same content says nothing is lost', (tester) async {
    await _pump(tester, const ConflictComparison(state: ConflictComparisonState.sameContent));
    expect(find.textContaining('Either choice keeps everything'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/widgets/`
Expected: FAIL, missing files.

- [ ] **Step 4: Implement `conflict_text_diff.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';

/// One side's text with the words only on that side highlighted. The
/// highlight is a background and bold weight together, so it does not rely on
/// colour alone.
class ConflictTextDiff extends StatelessWidget {
  const ConflictTextDiff({
    super.key,
    required this.spans,
    required this.highlight,
    required this.onHighlight,
  });

  final List<DiffSpan> spans;
  final Color highlight;
  final Color onHighlight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: span.unique
                  ? TextStyle(
                      backgroundColor: highlight,
                      color: onHighlight,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `conflict_difference_list.dart`**

Colours: local side `colorScheme.primaryContainer` / `onPrimaryContainer`; remote side `colorScheme.tertiaryContainer` / `onTertiaryContainer`. A cell renders `ConflictTextDiff` when `kind == FieldKind.longText` and both values are `String` and `diffWords` returns non-null; otherwise `Text(display)`.

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_text_diff.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Below this width the three-column table cannot fit two values side by
/// side, so each field becomes a stacked block.
const kConflictTableMinWidth = 480.0;

class ConflictDifferenceList extends StatelessWidget {
  const ConflictDifferenceList({
    super.key,
    required this.differences,
    required this.devices,
  });

  final List<FieldDifference> differences;
  final ConflictDeviceLabels devices;

  @override
  Widget build(BuildContext context) {
    final hasTextDiff = differences.any(_isTextDiff);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (constraints.maxWidth >= kConflictTableMinWidth)
            _table(context)
          else
            for (final d in differences) _block(context, d),
          if (hasTextDiff)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.settings_conflict_textDiffHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    Widget cell(Widget child) =>
        Padding(padding: const EdgeInsets.all(6), child: child);
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(flex: 1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      children: [
        TableRow(children: [
          cell(Text(context.l10n.settings_conflict_fieldHeader, style: header)),
          cell(Text(devices.local, style: header)),
          cell(Text(devices.remote, style: header)),
        ]),
        for (final d in differences)
          TableRow(children: [
            cell(Text(d.label, style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ))),
            cell(_value(context, d, local: true)),
            cell(_value(context, d, local: false)),
          ]),
      ],
    );
  }

  Widget _block(BuildContext context, FieldDifference d) {
    final theme = Theme.of(context);
    Widget line(String device, Widget value) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$device: ', style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          Expanded(child: value),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.label, style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          line(devices.local, _value(context, d, local: true)),
          line(devices.remote, _value(context, d, local: false)),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, FieldDifference d, {required bool local}) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (!_isTextDiff(d)) {
      return Text(local ? d.localDisplay : d.remoteDisplay, style: style);
    }
    final diff = diffWords(d.localValue! as String, d.remoteValue! as String);
    if (diff == null) {
      return Text(local ? d.localDisplay : d.remoteDisplay, style: style);
    }
    final scheme = Theme.of(context).colorScheme;
    final text = ConflictTextDiff(
      spans: local ? diff.local : diff.remote,
      highlight: local ? scheme.primaryContainer : scheme.tertiaryContainer,
      onHighlight: local ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
    );
    if (diff.hasUniqueWords || !local) return text;
    // Shown once, under the local side's text.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        Text(
          context.l10n.settings_conflict_whitespaceOnly,
          style: style?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

bool _isTextDiff(FieldDifference d) =>
    d.kind == FieldKind.longText &&
    d.localValue is String &&
    d.remoteValue is String;
```

The hint test (`settings_conflict_textDiffHint`) expects the hint whenever a long-text diff is shown; keep it unconditional for `_isTextDiff` rows.

- [ ] **Step 6: Implement `conflict_comparison_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_difference_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The body of one conflict: who changed it when, what differs, what is the
/// same, or the banner for a deletion or a content-identical pair.
class ConflictComparisonView extends StatelessWidget {
  const ConflictComparisonView({
    super.key,
    required this.comparison,
    required this.devices,
    required this.localModified,
    required this.remoteModified,
  });

  final ConflictComparison comparison;
  final ConflictDeviceLabels devices;
  final String localModified;
  final String remoteModified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = comparison;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modified(context, Icons.phone_android, devices.local, localModified),
        _modified(context, Icons.cloud, devices.remote, remoteModified),
        const SizedBox(height: 12),
        switch (c.state) {
          ConflictComparisonState.differing => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settings_conflict_whatDiffers(c.differences.length),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ConflictDifferenceList(differences: c.differences, devices: devices),
            ],
          ),
          ConflictComparisonState.sameContent =>
            _banner(context, Icons.check_circle_outline, l10n.settings_conflict_sameContent),
          ConflictComparisonState.remoteDeleted => _deleted(
            context,
            l10n.settings_conflict_remoteDeleted(devices.remote),
            devices.local,
          ),
          ConflictComparisonState.localDeleted => _deleted(
            context,
            l10n.settings_conflict_localDeleted(devices.local),
            devices.remote,
          ),
        },
        if (c.unchanged.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              l10n.settings_conflict_sameFields(c.unchanged.length),
              style: theme.textTheme.bodyMedium,
            ),
            children: [for (final f in c.unchanged) _fieldRow(context, f)],
          ),
      ],
    );
  }

  Widget _modified(BuildContext context, IconData icon, String device, String time) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.settings_conflict_modifiedBy(device, time),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: scheme.onSecondaryContainer)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleted(BuildContext context, String message, String survivor) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(context, Icons.delete_outline, message),
          const SizedBox(height: 8),
          Text(
            context.l10n.settings_conflict_deletedValues(survivor),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final f in comparison.survivingValues) _fieldRow(context, f),
        ],
      );

  Widget _fieldRow(BuildContext context, ShownField f) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(f.label, style: style?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(f.display, style: style)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run, expect pass**

Run: `flutter test test/features/settings/presentation/conflicts/widgets/`
Expected: PASS. If the "unchanged collapsed" test finds `Blue Hole` before expanding, `ExpansionTile` is keeping children mounted; pass `maintainState: false` (the default) and check nothing else renders the same text.

- [ ] **Step 8: Format, analyze, architecture, commit**

```bash
dart format lib test
flutter analyze
flutter test test/architecture/
git add lib/features/settings/presentation/conflicts test/features/settings/presentation/conflicts lib/l10n/arb
git commit -m "feat(settings): render a conflict as a field-by-field comparison"
```

---

### Task 8: Dialog rewire, consequence line and Keep both visibility

**Files:**
- Create: `lib/features/settings/presentation/conflicts/widgets/conflict_choice_consequence.dart`
- Modify: `lib/features/settings/presentation/widgets/conflict_resolution_dialog.dart`
- Delete: `lib/features/settings/presentation/widgets/conflict_data_preview.dart`, `test/features/settings/presentation/widgets/conflict_scalar_format_test.dart`
- Modify: `test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart`, `test/features/settings/presentation/widgets/conflict_resolution_dialog_list_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` and generated files

**Interfaces:**
- Consumes: everything from Tasks 5 to 7; `conflictLocalDeviceProvider`, `peerDeviceNamesProvider` (existing).
- Produces:
  - `bool canKeepBoth(SyncConflict conflict)`
  - `String conflictConsequence({required AppLocalizations l10n, required ConflictComparison comparison, required ConflictDeviceLabels devices, required ConflictResolution? choice})`
  - `ConflictChoiceConsequence({required String text})`
- l10n keys (scratchpad `keys_task8.json`):

```json
{
  "settings_conflict_keepDevice": "Keep {device}",
  "@settings_conflict_keepDevice": {"placeholders": {"device": {"type": "String"}}},
  "settings_conflict_chooseVersion": "Choose which version to keep.",
  "settings_conflict_consequence_keep": "Keeps {kept}'s version. {discarded}'s values for {fields} are discarded.",
  "@settings_conflict_consequence_keep": {"placeholders": {"kept": {"type": "String"}, "discarded": {"type": "String"}, "fields": {"type": "String"}}},
  "settings_conflict_consequence_keepBoth": "Keeps {local}'s version and adds {remote}'s version as a separate copy.",
  "@settings_conflict_consequence_keepBoth": {"placeholders": {"local": {"type": "String"}, "remote": {"type": "String"}}},
  "settings_conflict_consequence_keepRecord": "Keeps the record, with {device}'s values.",
  "@settings_conflict_consequence_keepRecord": {"placeholders": {"device": {"type": "String"}}},
  "settings_conflict_consequence_deleteHere": "Deletes the record on this device too.",
  "settings_conflict_consequence_staysDeleted": "The record stays deleted on this device.",
  "settings_conflict_consequence_nothingLost": "Both versions match, so nothing is lost."
}
```

- [ ] **Step 1: Add the keys**

Run: `python3.14 <scratchpad>/arb_insert.py en <scratchpad>/keys_task8.json && flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

Add `test/features/settings/presentation/conflicts/widgets/conflict_choice_consequence_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_choice_consequence.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  const devices = ConflictDeviceLabels(local: 'Pixel 8', remote: 'Windows PC');

  FieldDifference d(String label) => FieldDifference(
    key: label, label: label, kind: FieldKind.shortText,
    localValue: 'a', remoteValue: 'b', localDisplay: 'a', remoteDisplay: 'b',
  );

  final differing = ConflictComparison(
    state: ConflictComparisonState.differing,
    differences: [d('Water temp'), d('Notes')],
  );

  String text(ConflictComparison c, ConflictResolution? choice) =>
      conflictConsequence(l10n: l10n, comparison: c, devices: devices, choice: choice);

  test('nothing chosen asks for a choice', () {
    expect(text(differing, null), 'Choose which version to keep.');
  });

  test('keep local names what the other device loses', () {
    expect(
      text(differing, ConflictResolution.keepLocal),
      "Keeps Pixel 8's version. Windows PC's values for Water temp, Notes are discarded.",
    );
  });

  test('keep remote is the mirror', () {
    expect(
      text(differing, ConflictResolution.keepRemote),
      "Keeps Windows PC's version. Pixel 8's values for Water temp, Notes are discarded.",
    );
  });

  test('keep both adds a copy', () {
    expect(text(differing, ConflictResolution.keepBoth), contains('separate copy'));
  });

  test('same content loses nothing under any choice', () {
    const same = ConflictComparison(state: ConflictComparisonState.sameContent);
    for (final choice in ConflictResolution.values) {
      expect(text(same, choice), 'Both versions match, so nothing is lost.');
    }
  });

  test('deletion states name the deletion', () {
    const remoteDeleted = ConflictComparison(state: ConflictComparisonState.remoteDeleted);
    const localDeleted = ConflictComparison(state: ConflictComparisonState.localDeleted);
    expect(text(remoteDeleted, ConflictResolution.keepLocal), "Keeps the record, with Pixel 8's values.");
    expect(text(remoteDeleted, ConflictResolution.keepRemote), 'Deletes the record on this device too.');
    expect(text(localDeleted, ConflictResolution.keepLocal), 'The record stays deleted on this device.');
    expect(text(localDeleted, ConflictResolution.keepRemote), "Keeps the record, with Windows PC's values.");
  });

  group('canKeepBoth', () {
    SyncConflict c(Map<String, dynamic> local, Map<String, dynamic> remote, {String type = 'dives'}) =>
        SyncConflict(entityType: type, recordId: 'r', localData: local, remoteData: remote,
            localModified: DateTime(2026), remoteModified: DateTime(2026));

    test('a normal record with an id can be copied', () {
      expect(canKeepBoth(c({'id': 'r'}, {'id': 'r'})), isTrue);
    });
    test('not when the remote side is a deletion', () {
      expect(canKeepBoth(c({'id': 'r'}, {'id': 'r', '_deleted': true})), isFalse);
    });
    test('not when the local side is gone', () {
      expect(canKeepBoth(c({}, {'id': 'r'})), isFalse);
    });
    test('not for a junction row with no id', () {
      expect(canKeepBoth(c({'diveId': 'd', 'tagId': 't'}, {'diveId': 'd', 'tagId': 't'}, type: 'diveTags')), isFalse);
    });
    test('not for settings', () {
      expect(canKeepBoth(c({'id': 'r'}, {'id': 'r'}, type: 'settings')), isFalse);
    });
  });
}
```

Rewrite `conflict_resolution_dialog_test.dart` around the new behaviour, keeping its `pumpDialog` helper and adding overrides `peerDeviceNamesProvider.overrideWith((ref) => Stream.value(const {'peer-id': 'Windows PC'}))` and `conflictLocalDeviceProvider.overrideWith((ref) async => (id: 'local-id', name: 'Pixel 8'))`. Keep (adapted) the existing cases: names the tag and dive instead of ids, never shows a raw uuid or epoch millis, says so when a referenced record is gone, short id for a nameless record, header title, entity icon, depth in the diver's unit, dates an epoch column, names a conflict from the remote side when local is gone, renders a quality finding as its message. Drop "shows nothing at all for a side with no data" (replaced by the local-deletion banner) and the three "falls back to raw columns" cases (now in `conflict_comparison_test.dart`). Add:

```dart
  testWidgets('chips name the devices and Keep both is offered', (tester) async {
    await pumpDialog(tester, diveConflict);
    expect(find.text('Keep Pixel 8'), findsOneWidget);
    expect(find.text('Keep Windows PC'), findsOneWidget);
    expect(find.text('Keep Both'), findsOneWidget);
    expect(find.text('Choose which version to keep.'), findsOneWidget);
  });

  testWidgets('picking a version states what it discards', (tester) async {
    await pumpDialog(tester, diveConflict);
    await tester.tap(find.text('Keep Pixel 8'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Windows PC's values for"), findsOneWidget);
  });

  testWidgets('Keep both is hidden for a junction row', (tester) async {
    await pumpDialog(tester, diveTagConflict);
    expect(find.text('Keep Both'), findsNothing);
  });

  testWidgets('a phone-width window gets a full-screen dialog', (tester) async {
    await pumpDialog(tester, diveConflict, size: const Size(390, 844));
    expect(find.byWidgetPredicate((w) => w is Dialog && w.insetPadding == EdgeInsets.zero), findsOneWidget);
  });
```

`diveConflict` is a dive conflict whose remote `hlc` is `'1786556582600:0:peer-id'` and which differs in `waterTemp` and `notes`; `diveTagConflict` is the existing junction fixture in that file. Give `pumpDialog` an optional `size` parameter (default `Size(600, 1200)`). `Dialog.fullscreen` sets `insetPadding` to `EdgeInsets.zero`; if the Flutter version builds it differently, assert on `find.byType(Dialog)` covering the screen via `tester.getSize(...)` instead.

- [ ] **Step 3: Run, expect failure**

Run: `flutter test test/features/settings/presentation/conflicts/widgets/conflict_choice_consequence_test.dart test/features/settings/presentation/widgets/`
Expected: FAIL.

- [ ] **Step 4: Implement `conflict_choice_consequence.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether "Keep both" can really make a copy. `SyncService.resolveConflict`
/// copies the remote row under a new id only for a non-deleted record with
/// its own `id`, outside `settings`; anywhere else it keeps the local row, so
/// offering it would promise a copy that is never made.
bool canKeepBoth(SyncConflict conflict) =>
    conflict.entityType != 'settings' &&
    conflict.remoteData['_deleted'] != true &&
    conflict.localData.isNotEmpty &&
    conflict.remoteData['id'] != null;

/// What the selected choice keeps and discards, in one sentence.
String conflictConsequence({
  required AppLocalizations l10n,
  required ConflictComparison comparison,
  required ConflictDeviceLabels devices,
  required ConflictResolution? choice,
}) {
  if (choice == null) return l10n.settings_conflict_chooseVersion;
  final keepLocal = choice != ConflictResolution.keepRemote;
  switch (comparison.state) {
    case ConflictComparisonState.sameContent:
      return l10n.settings_conflict_consequence_nothingLost;
    case ConflictComparisonState.remoteDeleted:
      return keepLocal
          ? l10n.settings_conflict_consequence_keepRecord(devices.local)
          : l10n.settings_conflict_consequence_deleteHere;
    case ConflictComparisonState.localDeleted:
      return keepLocal
          ? l10n.settings_conflict_consequence_staysDeleted
          : l10n.settings_conflict_consequence_keepRecord(devices.remote);
    case ConflictComparisonState.differing:
      if (choice == ConflictResolution.keepBoth) {
        return l10n.settings_conflict_consequence_keepBoth(devices.local, devices.remote);
      }
      final fields = comparison.differences.map((d) => d.label).join(', ');
      return keepLocal
          ? l10n.settings_conflict_consequence_keep(devices.local, devices.remote, fields)
          : l10n.settings_conflict_consequence_keep(devices.remote, devices.local, fields);
  }
}

class ConflictChoiceConsequence extends StatelessWidget {
  const ConflictChoiceConsequence({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
```

Check the generated parameter order of `settings_conflict_consequence_keep` in `lib/l10n/arb/app_localizations.dart` (generated methods follow the `@placeholders` map order: `kept`, `discarded`, `fields`); the test asserts the rendered text, which catches a swap.

- [ ] **Step 5: Rewire the dialog**

In `conflict_resolution_dialog.dart`:

1. `build`: wrap by width.

```dart
  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(conflictsProvider);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final body = conflictsAsync.when(
      data: (conflicts) => _buildContent(context, conflicts, narrow: narrow),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(context.l10n.settings_conflict_errorLoading(error.toString())),
        ),
      ),
    );
    if (narrow) return Dialog.fullscreen(child: SafeArea(child: body));
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: body,
      ),
    );
  }
```

2. Pass `narrow` to `_buildHeader` and drop the top radius when narrow.
3. In `_buildContent`, compute once per build:

```dart
    final units = UnitFormatter(ref.watch(settingsProvider));
    final comparison = buildConflictComparison(
      l10n: context.l10n,
      units: units,
      conflict: conflict,
    );
    final localDevice = ref.watch(conflictLocalDeviceProvider).value;
    final devices = conflictDeviceLabels(
      l10n: context.l10n,
      localName: localDevice?.name,
      localDeviceId: localDevice?.id,
      peerNames: ref.watch(peerDeviceNamesProvider).value ?? const {},
      remoteData: conflict.remoteData,
    );
```

4. Replace `_buildConflictDetails`'s two version cards with the record card (unchanged) followed by `ConflictComparisonView(comparison: comparison, devices: devices, localModified: _formatDateTime(conflict.localModified), remoteModified: _formatDateTime(conflict.remoteModified))`.
5. `_buildResolutionOptions(context, conflict, comparison, devices)`: chip labels `l10n.settings_conflict_keepDevice(devices.local)` and `(devices.remote)`; the Keep both chip only `if (canKeepBoth(conflict))`; below the `Wrap`, `ConflictChoiceConsequence(text: conflictConsequence(l10n: context.l10n, comparison: comparison, devices: devices, choice: selected))`. Replace the header text `settings_conflict_chooseResolution` with nothing (the consequence line asks for the choice).
6. Delete the imports of `conflict_data_preview.dart`; delete that file and `conflict_scalar_format_test.dart`.

- [ ] **Step 6: Run, expect pass**

Run: `flutter test test/features/settings/presentation/`
Expected: PASS, including `cloud_sync_page_test.dart` (it opens the dialog; if it fails for a missing provider override, add the two device overrides there).

- [ ] **Step 7: Format, analyze, architecture, commit**

```bash
dart format lib test
flutter analyze
flutter test test/architecture/
git add -A lib/features/settings test/features/settings lib/l10n/arb
git status --porcelain
git commit -m "feat(settings): explain what each conflict choice keeps and discards"
```

`git status --porcelain` must show nothing outside those paths before the commit (stage explicit paths if it does).

---

### Tasks 9 to 13: Catalogue population

These five tasks share one procedure; each covers a list of entities. Every column of every listed entity gets either a catalogue entry (column name shared across entities with one meaning) or an override (`'<entityType>.<column>'`).

**Procedure (repeat inside each task):**

1. Remove the task's entities from `_pending` in the coverage guard. Run `flutter test test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart` and copy the failure reasons: each lists `column (DriftSqlType)` for one entity.
2. For each listed column, pick its kind with the table below, reading the table definition in `lib/core/database/tables/` (its doc comment states the unit) whenever the name alone is not decisive.

| Signal | Kind |
| --- | --- |
| stored metres of depth (`maxDepth`, `avgDepth`, `depth`, `*Depth`, `depthM`, `depthMeters`, `firstDepth`, `lastStopDepth`) | `depth` |
| short horizontal metres (`visibilityMeters`, `radiusMeters`, `distanceM` of a leg, drift) | `distance` |
| metres that can reach kilometres (`totalDistance` of a track) | `geoDistance` |
| equivalent narcotic depth (`bestMixEndMeters`) | `depth` |
| bar (`*Pressure`, `pressureBar`, `workingPressureBar`), excluding `surfacePressure`-style barometric columns | `pressure` |
| barometric (`surfacePressure`) | `number` with an override label; there is no barometric kind |
| Celsius (`*Temp`, `temperature*`) | `temperature` |
| kg (`*Kg`, `weightAmount`, `amountKg`) | `weight` |
| litres (`volume`, `volumeL`, `volumeLiters`, `defaultTankVolume`, `loopVolume`) | `volume` |
| m/s (`*SpeedMps`, `avgSpeed`, `maxSpeed`) | `speed` |
| wind m/s (`windSpeed`) | `windSpeed` |
| altitude metres (`altitude`) | `altitude` |
| centimetres (`heightCm`) | `heightCm` |
| m/min rates (`*AscentRate`, `*DescentRate`, `ascentRate*`) | `ascentRate` |
| `latitude`, `*Latitude` / `longitude`, `*Longitude` | `latitude` / `longitude` |
| 0 to 100 (`*Percent`, `o2Percent`, `hePercent`, `gasO2`, `diluentO2`, `analyzedO2`) | `percent` |
| 0 to 1 (`*Fraction`) | `fraction` |
| ppO2 bar (`ppO2*`, `*PpO2`, `loopO2*`) | `partialPressure` |
| seconds (`*Seconds`, `bottomTime`, `runtime`, `duration`) | `durationSeconds` |
| minutes (`*Minutes`, excluding `tzOffsetMinutes`) | `durationMinutes` |
| hours (`*Hours`) | `durationHours` |
| `DriftSqlType.dateTime`, or an int column whose doc says epoch millis (`*At`, `*Date`, `*DateTime`, `*Time`) | `dateTime`, or `date` when the doc says the time of day is meaningless |
| `DriftSqlType.bool` | `boolean` |
| `DriftSqlType.blob`, or a string holding JSON (`params`, `*Json`, `*Sections`, serialized lists) | `opaque` |
| free text a diver writes (`notes`, `description`, `comments`, `instructions`, `*Notes`) | `longText` |
| string written from an enum (see step 3) | `enumValue` |
| other strings | `shortText` |
| other numbers (counts, ratings, costs, ids that are not foreign keys, `tzOffsetMinutes`) | `number` |

3. **Enum columns.** For each string column, find its writer: `grep -rn "<camelColumn>:" lib/features/*/data lib/core/data` (the companion constructor). If the value written is `someEnum.name` or `someEnum.code` (or the reader parses it with `values.byName`, `fromName`, `fromString`, `fromCode`, `parse`), the column is an enum:
   - If the enum already has a localized label (an extension with `localizedName(l10n)` or `localizedDisplayName(l10n)`, or a switch over `l10n.enum_<enumCamel>_*`), add a labeler in `conflict_enum_labels.dart` that reuses it: `final ConflictEnumLabeler <enumCamel>Labeler = enumLabeler(<Enum>.values, (l, v) => v.localizedName(l));` with `storedAs:` when it is written by code.
   - If not, add keys `enum_<enumCamel>_<value>` for every value to the task's keys file (English, sentence case), and a labeler that switches over them exhaustively so a new enum value is a compile error:

     ```dart
     final ConflictEnumLabeler tripTypeLabeler = enumLabeler(
       TripType.values,
       (l, v) => switch (v) {
         TripType.shore => l.enum_tripType_shore,
         TripType.liveaboard => l.enum_tripType_liveaboard,
       },
     );
     ```

     (Use the real values of the enum; the two above are illustrative of the shape only, and the switch must list every value.)
4. **Labels.** Reuse an existing translated field label when its meaning matches: `DiveField`, `SiteField`, `EquipmentField`, `TripField`, `BuddyField`, `DiveCenterField`, `CourseField`, `CertificationField` all expose `localizedDisplayName(l10n)`; for those use `(l) => DiveField.waterTemp.localizedDisplayName(l)`. Otherwise add `settings_conflict_field_<column>` to the task's keys file (sentence case, no unit in the label, since the value carries it). A name whose meaning differs by entity (`type`, `status`, `kind`, `category`, `source`, `name` where it is not a display name, `value`) gets an override per entity with its own key `settings_conflict_field_<entityType>_<column>`.
5. Insert the keys: `python3.14 <scratchpad>/arb_insert.py en <scratchpad>/keys_task<N>.json && flutter gen-l10n`.
6. Write the domain file, `final Map<String, ConflictField> <domain>Fields = { 'waterTemp': ConflictField((l) => DiveField.waterTemp.localizedDisplayName(l), FieldKind.temperature), ... };` and `<domain>Overrides`, then add both maps to the `_merge([...])` calls in `conflict_field_catalogue.dart`. A column name already in an earlier domain's map is not repeated; if its meaning here differs, it becomes an override instead.
7. Add the domain's formatting tests to `test/features/settings/presentation/conflicts/conflict_field_catalogue_test.dart` (the specific cases are listed in each task).
8. Run the guard and the catalogue test; both pass for this task's entities. Run `flutter test test/features/settings/presentation/` and `flutter analyze`.
9. `dart format .`, `flutter test test/architecture/`, commit `feat(settings): catalogue <domain> fields for conflict comparison` with the ARB and generated files.

Keep each domain file under 800 lines; if one grows past that, split it (for example `dive_log_fields.dart` and `dive_profile_fields.dart`) and merge both.

### Task 9: Dive log fields

**Entities:** dives, diveTanks, diveWeights, diveEquipment, diveTags, diveDiveTypes, diveBuddies, diveProfileEvents, gasSwitches, diveCustomFields, diveDataSources, importedFiles, diveProfileSeries, tankPressureSeries, diveSafetyReviews, diveSafetyFindings, qualityFindings, sightings, incidents, emergencyChambers, diveTypes, diveRoles.

**Files:** Create `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart`; modify `conflict_field_catalogue.dart`, `conflict_enum_labels.dart`, the coverage guard, `conflict_field_catalogue_test.dart`, `app_en.arb`, generated files.

**Tests to add (Step 7):**

```dart
  test('dive fields reuse the dive field labels and units', () {
    const imperial = UnitFormatter(AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
    ));
    final temp = conflictFieldFor('dives', 'waterTemp');
    expect(temp.label(l10n), DiveField.waterTemp.localizedDisplayName(l10n));
    expect(
      formatConflictValue(l10n: l10n, units: imperial, field: temp, value: 26.0),
      imperial.formatTemperature(26.0),
    );
    expect(conflictFieldFor('dives', 'maxDepth').kind, FieldKind.depth);
    expect(conflictFieldFor('dives', 'visibilityMeters').kind, FieldKind.distance);
    expect(conflictFieldFor('dives', 'notes').kind, FieldKind.longText);
  });

  test('dive enum columns render localized values', () {
    final entry = conflictFieldFor('dives', 'entryMethod');
    expect(
      formatConflictValue(l10n: l10n, units: const UnitFormatter(AppSettings()), field: entry, value: 'boat'),
      l10n.enum_entryMethod_boat,
    );
  });
```

### Task 10: Site, trip, centre, track, species and tag fields

**Entities:** diveSites, siteTypes, siteSpecies, siteSiteTypes, siteTags, siteHides, siteFeatures, tideRecords, trips, liveaboardDetails, itineraryDays, tripDayWeather, tripCylinders, tripCylinderEvents, tripEquipment, tripHides, checklistTemplates, checklistTemplateItems, tripChecklistItems, diveCenters, diveCenterGearNotes, gpsTracks, navTracks, species, tags.

**Files:** Create `catalogue/site_trip_fields.dart`; same modifications as Task 9.

**Tests to add:**

```dart
  test('site and trip fields', () {
    expect(conflictFieldFor('diveSites', 'latitude').kind, FieldKind.latitude);
    expect(conflictFieldFor('diveSites', 'difficulty').kind, FieldKind.enumValue);
    expect(conflictFieldFor('tideRecords', 'tideState').kind, FieldKind.enumValue);
    expect(conflictFieldFor('trips', 'tripType').kind, FieldKind.enumValue);
    expect(conflictFieldFor('navTracks', 'totalDistance').kind, FieldKind.geoDistance);
  });
```

### Task 11: Equipment, cylinder, computer and service fields

**Entities:** equipment, equipmentSets, equipmentSetItems, equipmentSetGeofences, cylinderConfigs, cylinderConfigItems, equipmentAttributes, equipmentComponents, equipmentTags, equipmentShares, equipmentOwnershipEvents, equipmentObservations, equipmentFindings, tankPresets, weightPresets, weightPresetEntries, diveComputers, transmitters, cylinderFills, serviceRecords, serviceKinds, serviceSchedules, divePlanEquipment.

**Files:** Create `catalogue/equipment_fields.dart`; same modifications as Task 9.

**Tests to add:**

```dart
  test('equipment fields', () {
    expect(conflictFieldFor('equipment', 'status').kind, FieldKind.enumValue);
    expect(conflictFieldFor('equipmentOwnershipEvents', 'kind').kind, FieldKind.enumValue);
    expect(conflictFieldFor('cylinderFills', 'source').kind, FieldKind.enumValue);
    expect(conflictFieldFor('tankPresets', 'workingPressureBar').kind, FieldKind.pressure);
    expect(conflictFieldFor('equipment', 'status').enumLabel, isNotNull);
  });
```

### Task 12: People, planning and pre-dive fields

**Entities:** divers, diverWeightEntries, buddies, certifications, courses, courseRequirements, courseRequirementDives, divePlans, divePlanTanks, divePlanSegments, divePlanMissions, divePlanMissionLegs, divePlanMissionMembers, preDiveChecklistTemplates, preDiveChecklistTemplateItems, preDiveSessions, preDiveSessionItems.

**Files:** Create `catalogue/people_planning_fields.dart`; same modifications as Task 9.

**Tests to add:**

```dart
  test('people and planning fields', () {
    expect(conflictFieldFor('diverWeightEntries', 'heightCm').kind, FieldKind.heightCm);
    expect(conflictFieldFor('certifications', 'level').kind, FieldKind.enumValue);
    expect(conflictFieldFor('certifications', 'agency').kind, FieldKind.enumValue);
    expect(conflictFieldFor('preDiveSessions', 'status').kind, FieldKind.enumValue);
    expect(conflictFieldFor('courseRequirements', 'kind').kind, FieldKind.enumValue);
  });
```

### Task 13: Diver settings, media and remaining fields

**Entities:** diverSettings, mediaSmartAlbums, connectionMaps, savedQueries, csvPresets, viewConfigs, fieldPresets, settings, media, mediaEnrichment, mediaStores, connectedAccounts, mediaSubscriptions, mediaSpecies.

**Files:** Create `catalogue/settings_media_fields.dart`; same modifications as Task 9; and delete `_pending` (and the `skip:` argument) from the coverage guard, since it is now empty.

**Notes:** `diverSettings` columns mirror the Settings screens; prefer the labels those screens already use (search `app_en.arb` for the screen's wording and reuse the key through its getter rather than adding a duplicate). Unit-choice columns (`depthUnit`, `temperatureUnit`, ...) are `enumValue` over the unit enums in `lib/core/constants/units.dart`. `settings` is a key/value table: label `key` "Setting" and `value` "Value" through overrides `settings.key` and `settings.value`.

**Tests to add:**

```dart
  test('diver settings render unit choices as words', () {
    final depthUnit = conflictFieldFor('diverSettings', 'depthUnit');
    expect(depthUnit.kind, FieldKind.enumValue);
    expect(
      formatConflictValue(l10n: l10n, units: const UnitFormatter(AppSettings()), field: depthUnit, value: 'feet'),
      isNot('feet'),
    );
  });

  test('no synced entity is left out of the coverage guard', () {
    // Guards against reintroducing a skip list.
    final guard = File(p.join('test', 'features', 'settings', 'presentation',
        'conflicts', 'conflict_field_catalogue_coverage_test.dart'))
        .readAsStringSync();
    expect(guard, isNot(contains('_pending')));
  });
```

(Import `dart:io` and `package:path/path.dart' as p` in that test file for the second case. If `depthUnit` is stored by symbol rather than name, use the real stored value from the settings repository.)

After Task 13: run the whole conflicts folder and the guard with no skips.
Run: `flutter test test/features/settings/presentation/conflicts/`
Expected: PASS, 0 skipped.

---

### Task 14: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`, all generated `lib/l10n/arb/app_localizations*.dart`
- Possibly modify: `lib/l10n/arb/app_*.arb` to remove keys orphaned by Task 8

- [ ] **Step 1: List the keys this branch added**

Run: `git diff origin/main...HEAD -U0 -- lib/l10n/arb/app_en.arb | grep -E '^\+  "[^@]' | sed -E 's/^\+  "([^"]+)".*/\1/' > <scratchpad>/i18n/new_keys.txt; wc -l < <scratchpad>/i18n/new_keys.txt`
Expected: the count of every key added in Tasks 2 to 13. Also write their English values to `<scratchpad>/i18n/en.json` with a python3.14 one-liner that reads `app_en.arb` and keeps those keys.

- [ ] **Step 2: Remove orphaned keys**

For each of `settings_conflict_keepLocal`, `settings_conflict_keepRemote`, `settings_conflict_localVersion`, `settings_conflict_remoteVersion`, `settings_conflict_noDataAvailable`, `settings_conflict_modified`, `settings_conflict_chooseResolution`: `grep -rn "<key>" lib test --include='*.dart' | grep -v l10n/arb`. A key with no remaining use is deleted from all 11 ARB files (delete its line, and its `@` line where present) with a python3.14 script that removes exact lines and asserts `json.loads` after. Keep any key still referenced.

- [ ] **Step 3: Translate, one locale at a time**

For each locale in ar, de, es, fr, he, hu, it, nl, pt, zh, write `<scratchpad>/i18n/<locale>.json` holding every key in `new_keys.txt` (no `@` entries), then run `python3.14 <scratchpad>/arb_insert.py <locale> <scratchpad>/i18n/<locale>.json`. Rules:
- Match the locale's existing terms: open the locale's `settings_conflict_*`, `enum_diveField_*` and `settings_syncDevices_*` values first and reuse their nouns (record, device, version, dive).
- Keep ICU placeholders verbatim (`{device}`, `{count}`, `{kept}`).
- Plurals: `one{...}` and `other{...}` everywhere; Arabic adds `zero`, `two`, `few`, `many`; Hebrew adds `two`; Chinese uses `other` only.
- The English possessive "{kept}'s version" is restructured per language (de "Behält die Version von {kept}", fr "Conserve la version de {kept}").
- Use proper accents; do not strip diacritics.
- Never write an em-dash.

After each locale: `python3.14 -c "import json;json.load(open('lib/l10n/arb/app_<locale>.arb',encoding='utf-8'))"`.

- [ ] **Step 4: Regenerate and verify**

```bash
flutter gen-l10n
git diff --numstat -- lib/l10n/arb/*.arb
grep -A1 "get settings_conflict_thisDevice" lib/l10n/arb/app_localizations_de.dart
```

Expected: gen-l10n reports no untranslated messages for this branch's keys; every locale ARB row in numstat adds the same number of lines (explain any row that differs); the German getter returns a German string, not "This device".

- [ ] **Step 5: l10n guards**

Run: `flutter test test/l10n/`
Expected: PASS (parity, Arabic plural categories, zero counts, diacritics, duplicates).

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/l10n/arb
git commit -m "i18n(settings): translate conflict comparison strings"
```

---

### Task 15: Final verification and after screenshots

- [ ] **Step 1: Full checks**

```bash
dart format .
git status --porcelain
flutter analyze
flutter test test/architecture/
flutter test test/features/settings/ test/l10n/ test/core/services/sync/
```

Expected: no format changes left, zero analyzer issues, all PASS. Read the exit status, never through a pipe.

- [ ] **Step 2: After screenshots**

Copy the scratchpad harness from Task 0 back to `test/zz_shots/`, add at the marked line:

```dart
              peerDeviceNamesProvider.overrideWith(
                (ref) => Stream.value(const {'remote-device': 'Windows PC'}),
              ),
              conflictLocalDeviceProvider.overrideWith(
                (ref) async => (id: 'local-device', name: 'Pixel 8'),
              ),
```

Run: `flutter test test/zz_shots/conflict_dialog_shots_test.dart --update-goldens`
Copy to scratchpad `shots/` as `05-conflict-dialog-after.png`, `06-conflict-dialog-after-dark.png`, `07-conflict-dialog-after-phone.png`, `08-conflict-dialog-after-dark-phone.png`. Also capture the dialog with "Keep Pixel 8" tapped (`09-conflict-dialog-after-choice.png`) and a remote-deletion conflict (`10-conflict-dialog-after-deleted.png`) by adding two more `testWidgets` to the harness. Read each PNG to check: no overflow stripes, the highlight readable in both themes, device names in headers and chips. Then `rm -r test/zz_shots` and confirm `git status --porcelain` is empty.

- [ ] **Step 3: Send screenshots**

Send all ten PNGs with one `SendUserFile` call (`display: attach`), caption: they go in the PR's Screenshots section.
