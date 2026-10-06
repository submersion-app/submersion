# Legacy Buddy Text Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver turn the legacy free-text `dives.buddy` and `dives.dive_master` values into linked buddy records, from one dive's Buddies card or in bulk from Settings > Data Tools, with snackbar Undo.

**Architecture:** Pure-Dart parsing (`LegacyNameParser`), matching (`BuddyNameMatcher`) and planning (`planLegacyConversion`) in `lib/features/buddies/domain/`. A `BuddyConversionRepository` owns one-transaction apply and undo, reached through delegating methods on `BuddyRepository`, and marks only `buddies` and `diveBuddies` rows pending (never the parent dive). A thin `LegacyBuddyConversionService` plans, a shared review sheet edits a plan, and a Settings page runs the batch.

**Tech Stack:** Flutter, Dart 3, Drift (SQLite), Riverpod 3 (`flutter_riverpod` 3.4, legacy `StateNotifier` API via the `core/providers/provider.dart` facade), `equatable`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-13-legacy-buddy-text-conversion-design.md`

## Global Constraints

- Never write the em-dash character (U+2014) anywhere: code, comments, tests, ARB strings, commit messages. No en-dash as prose punctuation, no `--` as prose punctuation.
- No AI-tool attribution anywhere in the repo or on GitHub: no tool or vendor names, no `Co-Authored-By` trailer, no "generated with" line, no session link.
- No emojis in code, comments or docs.
- `always_use_package_imports` and `prefer_final_locals` are enabled: every import is `package:submersion/...`, every local that is not reassigned is `final`.
- Immutability: domain objects are immutable `Equatable` classes with `copyWith`; never mutate a list you did not just create.
- Files stay under 800 lines. Do not grow `buddy_repository.dart` (1,230 lines) beyond thin delegators, and do not grow `dive_detail_page.dart` (5,747 lines) beyond wiring.
- Sync: the conversion marks `buddies` and `diveBuddies` rows pending with `SyncRepository.markRecordPending` (which also stamps the row's `hlc`) and tombstones deletions with `logDeletion`. It never calls `markRecordPending(entityType: 'dives', ...)` and never writes the `dives` row.
- `dives.buddy` and `dives.dive_master` are never written by this feature.
- Every new user-facing string is an ARB key in all 11 files (`ar de en es fr he hu it nl pt zh`), inserted by Task 8, then `flutter gen-l10n`.
- Reuse existing keys: `common_action_cancel`, `common_action_save`, `common_action_remove`, `diveLog_bulkDelete_undo`, `diveRole_builtin_diveMaster`, `buddies_label_diveCount`.
- Tests: run a single file with `flutter test <path>`; never pipe `flutter test` into `grep` (the pipe hides the exit code). Run the full suite once, in Task 12 only.
- Worktree: this task's own git worktree, branch `ericgriffin/kind-bouman-871cc8`, based on PR #1837's commit `40e41ad4129`. Codegen already ran (`bash scripts/setup.sh`). If `database.g.dart` goes missing, rerun `bash scripts/setup.sh` (a bare `dart run build_runner build` is refused by a permission rule). `$SCRATCH` below means the executing session's scratchpad directory (outside the repo, never committed).
- Stage explicit paths only (`git add <paths>`), never `git add -A` or `git add .`.

## File Map

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/features/buddies/domain/services/legacy_name_parser.dart` | Create | Split legacy text into names; `legacyNameKey` |
| `lib/features/buddies/domain/entities/legacy_buddy_conversion.dart` | Create | `MatchCandidate`, `LinkTarget`, `PlannedLink`, `ConversionPlan`, `ConversionReceipt`, `UnlinkedTextDive`, `CandidateDive` |
| `lib/features/buddies/domain/services/buddy_name_matcher.dart` | Create | `BuddyNameMatcher`, `NameMatch` |
| `lib/features/buddies/domain/services/legacy_conversion_planner.dart` | Create | `planLink`, `collapseLinks`, `planLegacyConversion`, `summarizeCandidates` |
| `lib/features/buddies/data/repositories/buddy_conversion_repository.dart` | Create | Candidate reads, transactional apply and undo |
| `lib/features/buddies/data/repositories/buddy_repository.dart` | Modify | Four delegating methods |
| `lib/features/buddies/data/services/legacy_buddy_conversion_service.dart` | Create | `planFor`, `planCandidates`, `apply`, `undo`; `LinkBuddyNamesData` |
| `lib/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart` | Create | Service provider, bulk data provider, refresh helper |
| `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart` | Modify | 31 `buddies_linkText_*` keys |
| `lib/features/buddies/presentation/widgets/legacy_name_dialog.dart` | Create | Edit or add a name |
| `lib/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart` | Create | Single-select searchable buddy list |
| `lib/features/buddies/presentation/widgets/legacy_buddy_review_row.dart` | Create | One reviewed name row |
| `lib/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart` | Create | The review sheet |
| `lib/features/buddies/presentation/legacy_buddy_conversion_actions.dart` | Create | Per-dive flow, shared apply-with-Undo |
| `lib/features/buddies/presentation/widgets/legacy_buddy_text_section.dart` | Create | Text tiles and Link button on the Buddies card |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Modify | Use the section; drop `_buildTextBuddyTile` |
| `lib/features/settings/presentation/pages/link_buddy_names_page.dart` | Create | Bulk page |
| `lib/features/settings/presentation/widgets/link_buddy_names_dive_row.dart` | Create | One dive row on the bulk page |
| `lib/core/router/app_router.dart` | Modify | `link-buddy-names` route |
| `lib/features/settings/presentation/pages/settings_page.dart` | Modify | Data Tools tile |
| `test/features/buddies/domain/services/legacy_name_parser_test.dart` | Create | Parser table tests |
| `test/features/buddies/domain/services/buddy_name_matcher_test.dart` | Create | Matcher tests |
| `test/features/buddies/domain/services/legacy_conversion_planner_test.dart` | Create | Planner tests |
| `test/features/buddies/data/repositories/buddy_conversion_repository_test.dart` | Create | Reads, apply, undo, sync, rollback |
| `test/features/buddies/data/services/legacy_buddy_conversion_service_test.dart` | Create | Service against a real DB |
| `test/features/buddies/helpers/fake_legacy_buddy_conversion_service.dart` | Create | Fake service for widget tests |
| `test/features/buddies/presentation/widgets/legacy_buddy_review_sheet_test.dart` | Create | Sheet tests |
| `test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart` | Modify | Card tests (from #1837) |
| `test/features/settings/presentation/pages/link_buddy_names_page_test.dart` | Create | Bulk page tests |

---

### Task 1: LegacyNameParser

**Files:**
- Create: `lib/features/buddies/domain/services/legacy_name_parser.dart`
- Test: `test/features/buddies/domain/services/legacy_name_parser_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract final class LegacyNameParser { static List<String> parse(String? text); }` and top-level `String legacyNameKey(String name)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

void main() {
  group('LegacyNameParser.parse', () {
    const cases = <(String?, List<String>)>[
      (null, []),
      ('   ', []),
      ('Jim Dunfield, John Ratcliffe', ['Jim Dunfield', 'John Ratcliffe']),
      ('Jim and Ann', ['Jim', 'Ann']),
      ('Jim, Ann, and Bob', ['Jim', 'Ann', 'Bob']),
      ('Hans und Grete', ['Hans', 'Grete']),
      ('Paul et Marie', ['Paul', 'Marie']),
      ('Marco e Giulia', ['Marco', 'Giulia']),
      ('Jan en Piet', ['Jan', 'Piet']),
      ('Anna és Béla', ['Anna', 'Béla']),
      ('Ann; Bob / Cy & Dee + Eve', ['Ann', 'Bob', 'Cy', 'Dee', 'Eve']),
      ('Ann\nBob', ['Ann', 'Bob']),
      ('Ann\r\nBob', ['Ann', 'Bob']),
      ('张伟，李娜、王芳', ['张伟', '李娜', '王芳']),
      ('Joe (Customer)', ['Joe (Customer)']),
      ('Ann (instructor, PADI)', ['Ann (instructor, PADI)']),
      ('Ann [DM / guide], Bob', ['Ann [DM / guide]', 'Bob']),
      ('Ann (and Bob)', ['Ann (and Bob)']),
      ('None', []),
      ('n/a', []),
      ('N/A', []),
      ('John / N/A', ['John']),
      ('Dan/Ann', ['Dan', 'Ann']),
      ('keine', []),
      ('No  Buddy', []),
      ('Solo', []),
      ('--', []),
      ('Ann, 3', ['Ann']),
      ('Ann, ann, ANN ', ['Ann']),
      ('  Jim   Dunfield ', ['Jim Dunfield']),
      ('Anderson', ['Anderson']),
      ('Andy and Eve', ['Andy', 'Eve']),
      ('Nadia', ['Nadia']),
      // The accepted cost of splitting on "y": pinned so a change is a
      // deliberate decision, not a silent one.
      ('Ortega y Gasset', ['Ortega', 'Gasset']),
    ];

    for (final (input, expected) in cases) {
      final label = input == null
          ? 'null'
          : '"${input.replaceAll('\n', r'\n').replaceAll('\r', r'\r')}"';
      test('parses $label', () {
        expect(LegacyNameParser.parse(input), expected);
      });
    }
  });

  group('legacyNameKey', () {
    test('trims, collapses whitespace and lowercases non-ASCII letters', () {
      expect(legacyNameKey('  ÉRIC   Dupont '), 'éric dupont');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/domain/services/legacy_name_parser_test.dart`
Expected: FAIL to compile, `legacy_name_parser.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
/// The comparison key for a person's name: trimmed, inner whitespace
/// collapsed, and lowercased with Dart's Unicode-aware [String.toLowerCase].
/// Matching happens in Dart on this key because SQLite's `LOWER` folds only
/// ASCII, so `ÉRIC` would never match `éric` in SQL.
String legacyNameKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Splits the legacy free-text `dives.buddy` and `dives.dive_master` values
/// into individual names so they can become buddy records (#1831).
///
/// Separators are `, ; / & +`, newlines, the full-width comma and the
/// ideographic comma, plus the standalone words in [_conjunctions]. Nothing
/// inside `(...)` or `[...]` is split, so `Joe (Customer)` stays one name.
/// Placeholders such as `None` are dropped, so a text holding only a
/// placeholder parses to no names at all, which is how the Buddies card
/// tells a real text buddy from a solo dive.
abstract final class LegacyNameParser {
  static const Set<String> _separators = {
    ',',
    ';',
    '/',
    '&',
    '+',
    '\n',
    '，',
    '、',
  };

  /// Conjunctions for the app's Latin-script locales. One splits a part only
  /// when that part has more than one word, so a lone initial survives.
  static const Set<String> _conjunctions = {
    'and',
    'und',
    'et',
    'y',
    'e',
    'en',
    'és',
  };

  static const Set<String> _placeholders = {
    'none',
    'solo',
    'n/a',
    'na',
    '-',
    '--',
    'nobody',
    'no buddy',
    'keine',
    'aucun',
    'ninguno',
    'nessuno',
    'nenhum',
    'geen',
  };

  /// `n/a` as a whole token. Replaced by a separator before splitting,
  /// because `/` is itself a separator and would otherwise leave the names
  /// `N` and `A`.
  static final RegExp _notApplicable = RegExp(
    r'(?<!\p{L})n/a(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _whitespace = RegExp(r'\s+');

  /// The distinct names in [text], in first-seen order.
  static List<String> parse(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_notApplicable, ',');
    final names = <String>[];
    final seen = <String>{};
    for (final part in _splitOnSeparators(normalized)) {
      for (final piece in _splitOnConjunctions(part)) {
        final name = piece.trim().replaceAll(_whitespace, ' ');
        final key = legacyNameKey(name);
        if (key.isEmpty ||
            _placeholders.contains(key) ||
            !_letter.hasMatch(name)) {
          continue;
        }
        if (seen.add(key)) names.add(name);
      }
    }
    return List.unmodifiable(names);
  }

  static List<String> _splitOnSeparators(String text) {
    final parts = <String>[];
    final current = StringBuffer();
    var depth = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (depth == 0 && _separators.contains(char)) {
        parts.add(current.toString());
        current.clear();
        continue;
      }
      current.write(char);
      depth = _depthAfter(depth, char);
    }
    parts.add(current.toString());
    return parts;
  }

  static List<String> _splitOnConjunctions(String part) {
    final words = part.trim().split(_whitespace);
    if (words.length < 2) return [part];
    final pieces = <String>[];
    var current = <String>[];
    var depth = 0;
    for (final word in words) {
      if (depth == 0 && _conjunctions.contains(word.toLowerCase())) {
        pieces.add(current.join(' '));
        current = <String>[];
      } else {
        current = [...current, word];
      }
      depth = _depthAfter(depth, word);
    }
    pieces.add(current.join(' '));
    return pieces;
  }

  /// Bracket depth after reading [text], starting from [depth]. A stray
  /// closing bracket never takes it below zero.
  static int _depthAfter(int depth, String text) {
    var result = depth;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == '(' || char == '[') {
        result++;
      } else if ((char == ')' || char == ']') && result > 0) {
        result--;
      }
    }
    return result;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/domain/services/legacy_name_parser_test.dart`
Expected: PASS, 35 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/domain/services/legacy_name_parser.dart test/features/buddies/domain/services/legacy_name_parser_test.dart
git commit -m "feat(buddies): parse legacy buddy text into names (#1831)"
```

---

### Task 2: Conversion entities and BuddyNameMatcher

**Files:**
- Create: `lib/features/buddies/domain/entities/legacy_buddy_conversion.dart`
- Create: `lib/features/buddies/domain/services/buddy_name_matcher.dart`
- Test: `test/features/buddies/domain/services/buddy_name_matcher_test.dart`

**Interfaces:**
- Consumes: `legacyNameKey` (Task 1).
- Produces (entities file):
  - `MatchCandidate({required String id, required String name, String? diverId, int diveCount = 0, required DateTime createdAt})`
  - `sealed class LinkTarget { String get name; }`, `ExistingBuddyTarget({required String buddyId, required String name})`, `NewBuddyTarget(String name)`
  - `PlannedLink({required LinkTarget target, required String roleId, MatchCandidate? suggestion, int tieCount = 1})` with `name`, `identity`, `copyWith({LinkTarget? target, String? roleId, MatchCandidate? suggestion, bool clearSuggestion = false, int? tieCount})`
  - `ConversionPlan({required String diveId, String? buddyText, String? diveMasterText, List<PlannedLink> links = const []})` with `isEmpty`, `copyWith({List<PlannedLink>? links})`
  - `ConversionReceipt({required String diverId, List<String> diveIds, List<String> linkIds, List<String> createdBuddyIds, List<String> claimedBuddyIds})` with `isEmpty`, `copyWith`
  - `UnlinkedTextDive({required String diveId, int? diveNumber, required DateTime dateTime, String? siteName, String? buddyText, String? diveMasterText})`
  - `CandidateDive({required ConversionPlan plan, int? diveNumber, required DateTime dateTime, String? siteName})` with `diveId`
- Produces (matcher file): `sealed class NameMatch`, `ExactMatch(MatchCandidate candidate, {required int tieCount})`, `NoMatch({MatchCandidate? suggestion})`, `BuddyNameMatcher(List<MatchCandidate> candidates, {required String diverId})` with `List<MatchCandidate> candidates`, `NameMatch match(String name)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';

MatchCandidate _c(
  String id,
  String name, {
  String? diverId = 'me',
  int dives = 0,
  int created = 0,
}) => MatchCandidate(
  id: id,
  name: name,
  diverId: diverId,
  diveCount: dives,
  createdAt: DateTime.fromMillisecondsSinceEpoch(created),
);

NameMatch _match(List<MatchCandidate> candidates, String name) =>
    BuddyNameMatcher(candidates, diverId: 'me').match(name);

void main() {
  group('exact matches', () {
    test('match case-insensitively, including non-ASCII letters', () {
      final m = _match([_c('1', 'Éric Dupont')], 'éric dupont');
      expect(
        m,
        isA<ExactMatch>()
            .having((e) => e.candidate.id, 'id', '1')
            .having((e) => e.tieCount, 'tieCount', 1),
      );
    });

    test('ignore extra whitespace', () {
      final m = _match([_c('1', 'Jim Dunfield')], '  Jim   Dunfield ');
      expect(m, isA<ExactMatch>());
    });

    test('rank the diver own record above an unowned namesake', () {
      final m =
          _match([
                _c('unowned', 'Jack Evans', diverId: null, dives: 50),
                _c('own', 'Jack Evans', created: 9),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'own');
      expect(m.tieCount, 2);
    });

    test('then the record with more linked dives', () {
      final m =
          _match([
                _c('few', 'Jack Evans', dives: 1),
                _c('many', 'Jack Evans', dives: 5),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'many');
    });

    test('then the older record', () {
      final m =
          _match([
                _c('newer', 'Jack Evans', created: 5),
                _c('older', 'Jack Evans', created: 2),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'older');
    });

    test('then the id', () {
      final m =
          _match([
                _c('b', 'Jack Evans'),
                _c('a', 'Jack Evans'),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'a');
    });

    test('win over a prefix suggestion', () {
      final m = _match([_c('leo', 'Leo'), _c('cox', 'Leo Cox')], 'Leo');
      expect(m, isA<ExactMatch>().having((e) => e.candidate.id, 'id', 'leo'));
    });
  });

  group('suggestions', () {
    test('offer a unique whole-word prefix', () {
      final m = _match([_c('cox', 'Leo Cox')], 'Leo');
      expect(
        m,
        isA<NoMatch>().having((n) => n.suggestion?.id, 'suggestion', 'cox'),
      );
    });

    test('are not offered for a partial word', () {
      expect((_match([_c('cox', 'Leo Cox')], 'Le') as NoMatch).suggestion,
          isNull);
      expect((_match([_c('l', 'Leonard')], 'Leo') as NoMatch).suggestion,
          isNull);
    });

    test('are not offered when the prefix names two people', () {
      final m = _match([_c('cox', 'Leo Cox'), _c('diaz', 'Leo Diaz')], 'Leo');
      expect((m as NoMatch).suggestion, isNull);
    });

    test('treat two records of the same name as one person', () {
      final m = _match([
        _c('a', 'Leo Cox', dives: 1),
        _c('b', 'Leo Cox', dives: 7),
      ], 'Leo');
      expect((m as NoMatch).suggestion?.id, 'b');
    });
  });

  test('a blank name never matches', () {
    final m = _match([_c('1', 'Ann')], '   ');
    expect(m, isA<NoMatch>().having((n) => n.suggestion, 'suggestion', null));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/domain/services/buddy_name_matcher_test.dart`
Expected: FAIL to compile, the entities and matcher files do not exist.

- [ ] **Step 3: Write the entities file**

`lib/features/buddies/domain/entities/legacy_buddy_conversion.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

/// A buddy a legacy name can be matched to: the active diver's own records
/// and unowned ones (#1831).
class MatchCandidate extends Equatable {
  const MatchCandidate({
    required this.id,
    required this.name,
    this.diverId,
    this.diveCount = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? diverId;

  /// Dives this buddy is linked to; ranks namesakes.
  final int diveCount;
  final DateTime createdAt;

  MatchCandidate copyWith({
    String? id,
    String? name,
    String? diverId,
    int? diveCount,
    DateTime? createdAt,
  }) => MatchCandidate(
    id: id ?? this.id,
    name: name ?? this.name,
    diverId: diverId ?? this.diverId,
    diveCount: diveCount ?? this.diveCount,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [id, name, diverId, diveCount, createdAt];
}

/// Where a planned link points: an existing buddy or one to create.
sealed class LinkTarget extends Equatable {
  const LinkTarget();

  /// The name shown for the link.
  String get name;
}

final class ExistingBuddyTarget extends LinkTarget {
  const ExistingBuddyTarget({required this.buddyId, required this.name});

  final String buddyId;
  @override
  final String name;

  ExistingBuddyTarget copyWith({String? buddyId, String? name}) =>
      ExistingBuddyTarget(
        buddyId: buddyId ?? this.buddyId,
        name: name ?? this.name,
      );

  @override
  List<Object?> get props => [buddyId, name];
}

final class NewBuddyTarget extends LinkTarget {
  const NewBuddyTarget(this.name);

  @override
  final String name;

  NewBuddyTarget copyWith({String? name}) => NewBuddyTarget(name ?? this.name);

  @override
  List<Object?> get props => [name];
}

/// One person a conversion will link to a dive, with the role to use.
class PlannedLink extends Equatable {
  const PlannedLink({
    required this.target,
    required this.roleId,
    this.suggestion,
    this.tieCount = 1,
  });

  final LinkTarget target;

  /// A `dive_roles` id.
  final String roleId;

  /// A likely existing buddy for a new name (`Leo` for `Leo Cox`), shown by
  /// the per-dive review and never applied on its own.
  final MatchCandidate? suggestion;

  /// How many buddies share an exact name match; above one the review warns.
  final int tieCount;

  String get name => target.name;

  /// Two links with the same identity write the same dive link.
  String get identity => switch (target) {
    ExistingBuddyTarget(:final buddyId) => 'id:$buddyId',
    NewBuddyTarget(:final name) => 'new:${legacyNameKey(name)}',
  };

  PlannedLink copyWith({
    LinkTarget? target,
    String? roleId,
    MatchCandidate? suggestion,
    bool clearSuggestion = false,
    int? tieCount,
  }) => PlannedLink(
    target: target ?? this.target,
    roleId: roleId ?? this.roleId,
    suggestion: clearSuggestion ? null : (suggestion ?? this.suggestion),
    tieCount: tieCount ?? this.tieCount,
  );

  @override
  List<Object?> get props => [target, roleId, suggestion, tieCount];
}

/// The links one dive's legacy text turns into.
class ConversionPlan extends Equatable {
  const ConversionPlan({
    required this.diveId,
    this.buddyText,
    this.diveMasterText,
    this.links = const [],
  });

  final String diveId;
  final String? buddyText;
  final String? diveMasterText;
  final List<PlannedLink> links;

  bool get isEmpty => links.isEmpty;

  ConversionPlan copyWith({List<PlannedLink>? links}) => ConversionPlan(
    diveId: diveId,
    buddyText: buddyText,
    diveMasterText: diveMasterText,
    links: links ?? this.links,
  );

  @override
  List<Object?> get props => [diveId, buddyText, diveMasterText, links];
}

/// Everything an applied conversion wrote, so Undo can reverse exactly that.
class ConversionReceipt extends Equatable {
  const ConversionReceipt({
    required this.diverId,
    this.diveIds = const [],
    this.linkIds = const [],
    this.createdBuddyIds = const [],
    this.claimedBuddyIds = const [],
  });

  final String diverId;

  /// Dives that received links.
  final List<String> diveIds;
  final List<String> linkIds;
  final List<String> createdBuddyIds;

  /// Unowned buddies the conversion assigned to [diverId].
  final List<String> claimedBuddyIds;

  bool get isEmpty =>
      linkIds.isEmpty && createdBuddyIds.isEmpty && claimedBuddyIds.isEmpty;

  ConversionReceipt copyWith({
    String? diverId,
    List<String>? diveIds,
    List<String>? linkIds,
    List<String>? createdBuddyIds,
    List<String>? claimedBuddyIds,
  }) => ConversionReceipt(
    diverId: diverId ?? this.diverId,
    diveIds: diveIds ?? this.diveIds,
    linkIds: linkIds ?? this.linkIds,
    createdBuddyIds: createdBuddyIds ?? this.createdBuddyIds,
    claimedBuddyIds: claimedBuddyIds ?? this.claimedBuddyIds,
  );

  @override
  List<Object?> get props => [
    diverId,
    diveIds,
    linkIds,
    createdBuddyIds,
    claimedBuddyIds,
  ];
}

/// A dive with legacy buddy text and no linked buddies, as read from the
/// database.
class UnlinkedTextDive extends Equatable {
  const UnlinkedTextDive({
    required this.diveId,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.buddyText,
    this.diveMasterText,
  });

  final String diveId;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final String? buddyText;
  final String? diveMasterText;

  UnlinkedTextDive copyWith({String? buddyText, String? diveMasterText}) =>
      UnlinkedTextDive(
        diveId: diveId,
        diveNumber: diveNumber,
        dateTime: dateTime,
        siteName: siteName,
        buddyText: buddyText ?? this.buddyText,
        diveMasterText: diveMasterText ?? this.diveMasterText,
      );

  @override
  List<Object?> get props => [
    diveId,
    diveNumber,
    dateTime,
    siteName,
    buddyText,
    diveMasterText,
  ];
}

/// A dive on the bulk page: its plan plus what identifies it to the diver.
class CandidateDive extends Equatable {
  const CandidateDive({
    required this.plan,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
  });

  final ConversionPlan plan;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;

  String get diveId => plan.diveId;

  CandidateDive copyWith({ConversionPlan? plan}) => CandidateDive(
    plan: plan ?? this.plan,
    diveNumber: diveNumber,
    dateTime: dateTime,
    siteName: siteName,
  );

  @override
  List<Object?> get props => [plan, diveNumber, dateTime, siteName];
}
```

- [ ] **Step 4: Write the matcher**

`lib/features/buddies/domain/services/buddy_name_matcher.dart`:

```dart
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

/// The result of matching one legacy name.
sealed class NameMatch {
  const NameMatch();
}

/// One or more buddies have this exact name; [candidate] is the best ranked.
final class ExactMatch extends NameMatch {
  const ExactMatch(this.candidate, {required this.tieCount});

  final MatchCandidate candidate;
  final int tieCount;
}

/// No buddy has this name. [suggestion] is set only when exactly one
/// distinct name starts with it as a whole word.
final class NoMatch extends NameMatch {
  const NoMatch({this.suggestion});

  final MatchCandidate? suggestion;
}

/// Matches legacy names against a diver's buddies (#1831).
///
/// Namesakes rank the diver's own record first, then the most linked dives,
/// then the oldest record, then the id, so the pick is deterministic.
class BuddyNameMatcher {
  BuddyNameMatcher(List<MatchCandidate> candidates, {required this.diverId})
    : candidates = List.unmodifiable(candidates) {
    final grouped = <String, List<MatchCandidate>>{};
    for (final candidate in candidates) {
      grouped.putIfAbsent(legacyNameKey(candidate.name), () => []).add(
        candidate,
      );
    }
    _byKey = {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable([...entry.value]..sort(_rank)),
    };
  }

  final String diverId;
  final List<MatchCandidate> candidates;
  late final Map<String, List<MatchCandidate>> _byKey;

  NameMatch match(String name) {
    final key = legacyNameKey(name);
    if (key.isEmpty) return const NoMatch();
    final exact = _byKey[key];
    if (exact != null) {
      return ExactMatch(exact.first, tieCount: exact.length);
    }
    final prefix = '$key ';
    final hits = [
      for (final entry in _byKey.entries)
        if (entry.key.startsWith(prefix)) entry.value.first,
    ];
    return NoMatch(suggestion: hits.length == 1 ? hits.single : null);
  }

  int _rank(MatchCandidate a, MatchCandidate b) {
    final own = _ownRank(a).compareTo(_ownRank(b));
    if (own != 0) return own;
    final dives = b.diveCount.compareTo(a.diveCount);
    if (dives != 0) return dives;
    final age = a.createdAt.compareTo(b.createdAt);
    if (age != 0) return age;
    return a.id.compareTo(b.id);
  }

  int _ownRank(MatchCandidate candidate) =>
      candidate.diverId == diverId ? 0 : 1;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/buddies/domain/services/buddy_name_matcher_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/buddies/domain/entities/legacy_buddy_conversion.dart lib/features/buddies/domain/services/buddy_name_matcher.dart test/features/buddies/domain/services/buddy_name_matcher_test.dart
git commit -m "feat(buddies): match legacy names against a diver's buddies (#1831)"
```

---

### Task 3: Conversion planner

**Files:**
- Create: `lib/features/buddies/domain/services/legacy_conversion_planner.dart`
- Test: `test/features/buddies/domain/services/legacy_conversion_planner_test.dart`

**Interfaces:**
- Consumes: `LegacyNameParser.parse`, `legacyNameKey` (Task 1); entities and `BuddyNameMatcher`, `ExactMatch`, `NoMatch` (Task 2); `DiveRole.buddyId`, `DiveRole.diveMasterId` from `package:submersion/features/dive_roles/domain/entities/dive_role.dart`.
- Produces:
  - `PlannedLink planLink(String name, String roleId, BuddyNameMatcher matcher)`
  - `List<PlannedLink> collapseLinks(Iterable<PlannedLink> links)`: first occurrence of each `identity` wins its position; a later Dive Master duplicate upgrades the kept link's role to Dive Master.
  - `ConversionPlan planLegacyConversion({required String diveId, String? buddyText, String? diveMasterText, required BuddyNameMatcher matcher})`
  - `typedef LinkSummary = ({int dives, int newBuddies, int existingBuddies});` and `LinkSummary summarizeCandidates(Iterable<CandidateDive> dives)` (distinct new names by key, distinct existing buddy ids).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

final _epoch = DateTime.utc(2026);

final _matcher = BuddyNameMatcher([
  MatchCandidate(id: 'jim', name: 'Jim Dunfield', diverId: 'me', createdAt: _epoch),
  MatchCandidate(id: 'leo', name: 'Leo Cox', diverId: 'me', createdAt: _epoch),
], diverId: 'me');

const _jim = ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield');

void main() {
  group('planLegacyConversion', () {
    test('links known names and creates the rest', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        matcher: _matcher,
      );
      expect(plan.diveId, 'd1');
      expect(plan.buddyText, 'Jim Dunfield, Ann');
      expect(plan.links, const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: NewBuddyTarget('Ann'), roleId: DiveRole.buddyId),
      ]);
    });

    test('carries a prefix suggestion on a new name', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Leo',
        matcher: _matcher,
      );
      final link = plan.links.single;
      expect(link.target, const NewBuddyTarget('Leo'));
      expect(link.suggestion?.id, 'leo');
    });

    test('dive-master text links with the Dive Master role', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        diveMasterText: 'Ana',
        matcher: _matcher,
      );
      expect(plan.links.single.roleId, DiveRole.diveMasterId);
    });

    test('a name in both texts keeps one link with the Dive Master role', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        diveMasterText: 'jim dunfield',
        matcher: _matcher,
      );
      expect(plan.links, hasLength(2));
      expect(plan.links.first.target, _jim);
      expect(plan.links.first.roleId, DiveRole.diveMasterId);
    });

    test('placeholder-only texts plan nothing', () {
      final plan = planLegacyConversion(
        diveId: 'd1',
        buddyText: 'None',
        diveMasterText: 'n/a',
        matcher: _matcher,
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('collapseLinks', () {
    test('keeps the first of two links to one buddy', () {
      final links = collapseLinks(const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: _jim, roleId: DiveRole.instructorId),
      ]);
      expect(links, const [PlannedLink(target: _jim, roleId: DiveRole.buddyId)]);
    });

    test('lets a Dive Master duplicate upgrade the kept role', () {
      final links = collapseLinks(const [
        PlannedLink(target: _jim, roleId: DiveRole.buddyId),
        PlannedLink(target: _jim, roleId: DiveRole.diveMasterId),
      ]);
      expect(links.single.roleId, DiveRole.diveMasterId);
    });
  });

  test('summarizeCandidates counts dives, new names and existing buddies', () {
    CandidateDive dive(String id, String text) => CandidateDive(
      plan: planLegacyConversion(diveId: id, buddyText: text, matcher: _matcher),
      dateTime: _epoch,
    );
    final summary = summarizeCandidates([
      dive('d1', 'Jim Dunfield, Ann'),
      dive('d2', 'ann, Bob, Jim Dunfield'),
    ]);
    expect(summary.dives, 2);
    expect(summary.newBuddies, 2);
    expect(summary.existingBuddies, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/domain/services/legacy_conversion_planner_test.dart`
Expected: FAIL to compile, `legacy_conversion_planner.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Counts shown in the bulk page's header.
typedef LinkSummary = ({int dives, int newBuddies, int existingBuddies});

/// The link one legacy [name] becomes: an existing buddy on an exact match,
/// otherwise a new one carrying any prefix suggestion.
PlannedLink planLink(String name, String roleId, BuddyNameMatcher matcher) =>
    switch (matcher.match(name)) {
      ExactMatch(:final candidate, :final tieCount) => PlannedLink(
        target: ExistingBuddyTarget(
          buddyId: candidate.id,
          name: candidate.name,
        ),
        roleId: roleId,
        tieCount: tieCount,
      ),
      NoMatch(:final suggestion) => PlannedLink(
        target: NewBuddyTarget(name.trim()),
        roleId: roleId,
        suggestion: suggestion,
      ),
    };

/// One link per person. The first occurrence keeps its position and role,
/// except that a Dive Master duplicate upgrades it: a name in both the buddy
/// and the dive-master text is the dive's dive master.
List<PlannedLink> collapseLinks(Iterable<PlannedLink> links) {
  final result = <PlannedLink>[];
  final indexByIdentity = <String, int>{};
  for (final link in links) {
    final at = indexByIdentity[link.identity];
    if (at == null) {
      indexByIdentity[link.identity] = result.length;
      result.add(link);
    } else if (link.roleId == DiveRole.diveMasterId) {
      result[at] = result[at].copyWith(roleId: DiveRole.diveMasterId);
    }
  }
  return List.unmodifiable(result);
}

/// The plan for one dive's legacy `buddy` (Buddy role) and `dive_master`
/// (Dive Master role) texts (#1831).
ConversionPlan planLegacyConversion({
  required String diveId,
  String? buddyText,
  String? diveMasterText,
  required BuddyNameMatcher matcher,
}) => ConversionPlan(
  diveId: diveId,
  buddyText: buddyText,
  diveMasterText: diveMasterText,
  links: collapseLinks([
    for (final name in LegacyNameParser.parse(buddyText))
      planLink(name, DiveRole.buddyId, matcher),
    for (final name in LegacyNameParser.parse(diveMasterText))
      planLink(name, DiveRole.diveMasterId, matcher),
  ]),
);

/// Dives, distinct new names, and distinct existing buddies across [dives].
LinkSummary summarizeCandidates(Iterable<CandidateDive> dives) {
  var count = 0;
  final newKeys = <String>{};
  final existingIds = <String>{};
  for (final dive in dives) {
    count++;
    for (final link in dive.plan.links) {
      switch (link.target) {
        case NewBuddyTarget(:final name):
          newKeys.add(legacyNameKey(name));
        case ExistingBuddyTarget(:final buddyId):
          existingIds.add(buddyId);
      }
    }
  }
  return (
    dives: count,
    newBuddies: newKeys.length,
    existingBuddies: existingIds.length,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/domain/services/legacy_conversion_planner_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/domain/services/legacy_conversion_planner.dart test/features/buddies/domain/services/legacy_conversion_planner_test.dart
git commit -m "feat(buddies): plan the links a dive's legacy text becomes (#1831)"
```

---

### Task 4: BuddyConversionRepository reads

**Files:**
- Create: `lib/features/buddies/data/repositories/buddy_conversion_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`

**Interfaces:**
- Consumes: entities (Task 2).
- Produces: `class BuddyConversionRepository` with `Future<List<MatchCandidate>> candidateBuddies(String diverId)` and `Future<List<UnlinkedTextDive>> unlinkedTextDives(String diverId)`. Tasks 5 and 6 add `apply` and `undo` to this class and to this test file.

Scoping: dives are scoped with `d.diver_id = ?` exactly as the dive list does (`getDiveSummaries`, no `IS NULL` arm), so the bulk page and the dive list agree. Buddies include `diver_id IS NULL` because an unowned buddy is still a valid match (and is claimed on link). Dates are read with `isUtc: true`, as `DiveRepository` does: dive times are UTC-flagged wall clocks.

- [ ] **Step 1: Write the failing test**

The whole file; Tasks 5 and 6 append groups inside `main()`.

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BuddyConversionRepository repo;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> insertDive(
    String id, {
    String diverId = 'me',
    String? buddy,
    String? diveMaster,
    int? number,
    int at = 1000,
    String? siteId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: at,
          createdAt: 1,
          updatedAt: 1,
          buddy: Value(buddy),
          diveMaster: Value(diveMaster),
          diveNumber: Value(number),
          siteId: Value(siteId),
        ),
      );

  Future<void> insertBuddy(
    String id,
    String name, {
    String? diverId = 'me',
    int createdAt = 1,
  }) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: Value(diverId),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  Future<void> link(String diveId, String buddyId) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: '$diveId|$buddyId',
          diveId: diveId,
          buddyId: buddyId,
          createdAt: 1,
        ),
      );

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType && r.syncStatus == 'pending') r.recordId,
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final t in await db.select(db.deletionLog).get())
      if (t.entityType == entityType) t.recordId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    repo = BuddyConversionRepository();
    await insertDiver('me');
    await insertDiver('other');
  });

  tearDown(tearDownTestDatabase);

  group('candidateBuddies', () {
    test('returns the diver own and unowned buddies with dive counts', () async {
      await insertBuddy('own', 'Ann');
      await insertBuddy('free', 'Bob', diverId: null);
      await insertBuddy('theirs', 'Cy', diverId: 'other');
      await insertDive('d1');
      await link('d1', 'own');

      final byId = {
        for (final c in await repo.candidateBuddies('me')) c.id: c,
      };

      expect(byId.keys, unorderedEquals(['own', 'free']));
      expect(byId['own']!.diveCount, 1);
      expect(byId['own']!.name, 'Ann');
      expect(byId['free']!.diverId, isNull);
      expect(byId['free']!.diveCount, 0);
    });
  });

  group('unlinkedTextDives', () {
    test('lists the diver dives with unlinked text, newest first', () async {
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Blue Hole', 1, 1)",
      );
      await insertDive('old', buddy: 'Ann', at: 1000, number: 1, siteId: 's1');
      await insertDive('new', diveMaster: 'Bob', at: 2000);
      await insertDive('blank', buddy: '   ', at: 3000);
      await insertBuddy('cy', 'Cy');
      await insertDive('linked', buddy: 'Cy', at: 4000);
      await link('linked', 'cy');
      await insertDive('theirs', diverId: 'other', buddy: 'Dee', at: 5000);

      final rows = await repo.unlinkedTextDives('me');

      expect(rows.map((r) => r.diveId), ['new', 'old']);
      expect(rows.first.diveMasterText, 'Bob');
      final old = rows.last;
      expect(old.buddyText, 'Ann');
      expect(old.diveNumber, 1);
      expect(old.siteName, 'Blue Hole');
      expect(old.dateTime, DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: FAIL to compile, `buddy_conversion_repository.dart` does not exist. (Unused-import warnings for `SyncEventBus`, `DiveRole`, `pending` and `tombstones` are expected until Tasks 5 and 6; they are not errors.)

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';

/// Reads and writes that turn legacy buddy text into buddy records (#1831).
///
/// Reached through [BuddyRepository]'s delegating methods, the same shape as
/// [BuddyMergeRepository]. Sync marks go on the `buddies` and `diveBuddies`
/// rows only, never on the parent dive: `diveBuddies` is a parent-gated
/// child that exports on its own pending mark (#1769), and restamping the
/// dive would let this device's whole dive row win last-writer-wins over a
/// newer edit made on another device.
class BuddyConversionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _sync = SyncRepository();
  final CertificationRepository _certRepo = CertificationRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(BuddyConversionRepository);

  /// The buddies a legacy name may match: [diverId]'s own and unowned ones,
  /// each with the number of dives it is linked to.
  Future<List<MatchCandidate>> candidateBuddies(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT b.id, b.name, b.diver_id, b.created_at,
        (SELECT COUNT(*) FROM dive_buddies db WHERE db.buddy_id = b.id)
          AS dive_count
      FROM buddies b
      WHERE b.diver_id = ? OR b.diver_id IS NULL
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.buddies, _db.diveBuddies},
        )
        .get();
    return [
      for (final row in rows)
        MatchCandidate(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          diverId: row.readNullable<String>('diver_id'),
          diveCount: row.read<int>('dive_count'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at'),
          ),
        ),
    ];
  }

  /// [diverId]'s dives that have legacy buddy or dive-master text and no
  /// linked buddy, newest first. Scoped with `diver_id = ?` exactly like the
  /// dive list, so both surfaces show the same dives.
  Future<List<UnlinkedTextDive>> unlinkedTextDives(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT d.id, d.dive_number, d.dive_date_time, d.buddy, d.dive_master,
        s.name AS site_name
      FROM dives d
      LEFT JOIN dive_sites s ON s.id = d.site_id
      WHERE d.diver_id = ?
        AND NOT EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
        AND (TRIM(COALESCE(d.buddy, '')) <> ''
          OR TRIM(COALESCE(d.dive_master, '')) <> '')
      ORDER BY d.dive_date_time DESC, d.id
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.dives, _db.diveBuddies, _db.diveSites},
        )
        .get();
    return [
      for (final row in rows)
        UnlinkedTextDive(
          diveId: row.read<String>('id'),
          diveNumber: row.readNullable<int>('dive_number'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          siteName: row.readNullable<String>('site_name'),
          buddyText: row.readNullable<String>('buddy'),
          diveMasterText: row.readNullable<String>('dive_master'),
        ),
    ];
  }
}
```

The `_sync`, `_certRepo`, `_uuid` and `_log` fields are used by Tasks 5 and 6; if the analyzer flags them as unused in this commit, that is expected and resolved by Task 5.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_conversion_repository.dart test/features/buddies/data/repositories/buddy_conversion_repository_test.dart
git commit -m "feat(buddies): read dives with unlinked buddy text (#1831)"
```

---

### Task 5: Transactional apply

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_conversion_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_conversion_repository_test.dart` (append)

**Interfaces:**
- Consumes: `BuddyNameMatcher`, `ExactMatch` (Task 2), `legacyNameKey` (Task 1), `candidateBuddies` (Task 4).
- Produces: `Future<ConversionReceipt> apply(List<ConversionPlan> plans, {required String diverId, required String newBuddyNote})`.

Behaviour, all inside one `_db.transaction`, then one `SyncEventBus.notifyLocalChange()` only when something was written:
1. Skip a plan with no links, a dive that no longer exists, or a dive that gained any `dive_buddies` row since planning.
2. An `ExistingBuddyTarget` whose buddy still exists is used (claimed if unowned). One that was deleted since planning falls back to its name.
3. A name (new, or fallen back) reuses a buddy created earlier in this run with the same `legacyNameKey`, else an exact match among the candidates read at the start of the transaction (claimed if unowned), else creates a buddy with `diverId` and `newBuddyNote`.
4. Two links in one dive that resolve to the same buddy write one link (the first).

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of the repository test file, after the `unlinkedTextDives` group:

```dart
  ConversionPlan plan(String diveId, List<PlannedLink> links) =>
      ConversionPlan(diveId: diveId, links: links);

  PlannedLink newLink(String name, [String roleId = DiveRole.buddyId]) =>
      PlannedLink(target: NewBuddyTarget(name), roleId: roleId);

  PlannedLink existing(
    String id,
    String name, [
    String roleId = DiveRole.buddyId,
  ]) => PlannedLink(
    target: ExistingBuddyTarget(buddyId: id, name: name),
    roleId: roleId,
  );

  Future<ConversionReceipt> run(List<ConversionPlan> plans) =>
      repo.apply(plans, diverId: 'me', newBuddyNote: 'converted');

  group('apply', () {
    test('creates new buddies and links them with their roles', () async {
      await insertDive('d1', buddy: 'Ann', diveMaster: 'Bob');

      final receipt = await run([
        plan('d1', [newLink('Ann'), newLink('Bob', DiveRole.diveMasterId)]),
      ]);

      final buddies = await db.select(db.buddies).get();
      expect(buddies.map((b) => b.name), unorderedEquals(['Ann', 'Bob']));
      expect(buddies.every((b) => b.diverId == 'me'), isTrue);
      expect(buddies.every((b) => b.notes == 'converted'), isTrue);
      final links = await db.select(db.diveBuddies).get();
      final nameById = {for (final b in buddies) b.id: b.name};
      expect({for (final l in links) nameById[l.buddyId]: l.role}, {
        'Ann': DiveRole.buddyId,
        'Bob': DiveRole.diveMasterId,
      });
      expect(receipt.diveIds, ['d1']);
      expect(receipt.linkIds, unorderedEquals(links.map((l) => l.id)));
      expect(receipt.createdBuddyIds, unorderedEquals(nameById.keys));
      expect(receipt.claimedBuddyIds, isEmpty);
    });

    test('leaves the dive text columns untouched', () async {
      await insertDive('d1', buddy: 'Ann', diveMaster: 'Bob');
      await run([
        plan('d1', [newLink('Ann'), newLink('Bob', DiveRole.diveMasterId)]),
      ]);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('d1'))).getSingle();
      expect(dive.buddy, 'Ann');
      expect(dive.diveMaster, 'Bob');
      expect(dive.updatedAt, 1);
    });

    test('links an existing buddy without creating one', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      final receipt = await run([
        plan('d1', [existing('ann', 'Ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).buddyId, 'ann');
      expect(receipt.createdBuddyIds, isEmpty);
    });

    test('creates one buddy for a new name shared by several dives', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'ann');

      final receipt = await run([
        plan('d1', [newLink('Ann')]),
        plan('d2', [newLink('ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect(await db.select(db.diveBuddies).get(), hasLength(2));
      expect(receipt.createdBuddyIds, hasLength(1));
      expect(receipt.diveIds, ['d1', 'd2']);
    });

    test('reuses a buddy created since planning', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      await run([
        plan('d1', [newLink('ann')]),
      ]);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).buddyId, 'ann');
    });

    test('falls back to the name when a planned buddy was deleted', () async {
      await insertDive('d1', buddy: 'Ann');

      final receipt = await run([
        plan('d1', [existing('gone', 'Ann')]),
      ]);

      expect(receipt.createdBuddyIds, hasLength(1));
      expect((await db.select(db.buddies).getSingle()).name, 'Ann');
    });

    test('writes one link when two rows resolve to one buddy', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('ann', 'Ann');

      await run([
        plan('d1', [existing('ann', 'Ann'), newLink('ANN')]),
      ]);

      expect(await db.select(db.diveBuddies).get(), hasLength(1));
    });

    test('skips a dive that gained links since planning', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertBuddy('cy', 'Cy');
      await link('d1', 'cy');

      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);

      expect(receipt.isEmpty, isTrue);
      expect(await db.select(db.diveBuddies).get(), hasLength(1));
      expect(await db.select(db.buddies).get(), hasLength(1));
    });

    test('skips a dive deleted since planning', () async {
      final receipt = await run([
        plan('ghost', [newLink('Ann')]),
      ]);

      expect(receipt.isEmpty, isTrue);
      expect(await db.select(db.buddies).get(), isEmpty);
    });

    test('claims an unowned buddy for the diver', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertBuddy('leo', 'Leo Cox', diverId: null);

      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, 'me');
      expect(receipt.claimedBuddyIds, ['leo']);
      expect(await pending('buddies'), {'leo'});
    });

    test('stages the buddies and links for sync, never the dive', () async {
      await insertDive('d1', buddy: 'Ann, Bob');
      await insertBuddy('bob', 'Bob');

      final receipt = await run([
        plan('d1', [newLink('Ann'), existing('bob', 'Bob')]),
      ]);

      expect(await pending('diveBuddies'), receipt.linkIds.toSet());
      expect(await pending('buddies'), receipt.createdBuddyIds.toSet());
      expect(await pending('dives'), isEmpty);
    });

    test('announces the change once', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'Bob');
      var notifications = 0;
      final sub = SyncEventBus.changes.listen((_) => notifications++);
      addTearDown(sub.cancel);

      await run([
        plan('d1', [newLink('Ann')]),
        plan('d2', [newLink('Bob')]),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });

    test('rolls everything back when a write fails', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2', buddy: 'Bob');
      await db.customStatement(
        "CREATE TRIGGER fail_d2 BEFORE INSERT ON dive_buddies "
        "WHEN NEW.dive_id = 'd2' BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );

      await expectLater(
        run([
          plan('d1', [newLink('Ann')]),
          plan('d2', [newLink('Bob')]),
        ]),
        throwsA(anything),
      );

      expect(await db.select(db.buddies).get(), isEmpty);
      expect(await db.select(db.diveBuddies).get(), isEmpty);
      expect(await db.select(db.syncRecords).get(), isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: FAIL to compile, `The method 'apply' isn't defined for the type 'BuddyConversionRepository'`.

- [ ] **Step 3: Implement `apply`**

Add these imports to `buddy_conversion_repository.dart`:

```dart
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
```

Add to the class, after `unlinkedTextDives`:

```dart
  /// Writes [plans] in one transaction and returns what it wrote. Dives that
  /// are gone or gained links since planning are skipped, so a stale preview
  /// cannot double-link. Announces the change once, after the commit.
  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) async {
    try {
      final receipt = await _db.transaction(() async {
        final run = _ApplyRun(
          matcher: BuddyNameMatcher(
            await candidateBuddies(diverId),
            diverId: diverId,
          ),
          diverId: diverId,
          newBuddyNote: newBuddyNote,
          now: DateTime.now().millisecondsSinceEpoch,
        );
        for (final plan in plans) {
          if (plan.isEmpty || !await _isUnlinkedDive(plan.diveId)) continue;
          final linked = <String>{};
          for (final link in plan.links) {
            final buddyId = await _resolve(link.target, run);
            if (!linked.add(buddyId)) continue;
            final linkId = _uuid.v4();
            await _db
                .into(_db.diveBuddies)
                .insert(
                  DiveBuddiesCompanion(
                    id: Value(linkId),
                    diveId: Value(plan.diveId),
                    buddyId: Value(buddyId),
                    role: Value(link.roleId),
                    createdAt: Value(run.now),
                  ),
                );
            await _sync.markRecordPending(
              entityType: 'diveBuddies',
              recordId: linkId,
              localUpdatedAt: run.now,
            );
            run.linkIds.add(linkId);
          }
          run.diveIds.add(plan.diveId);
        }
        return run.toReceipt();
      });
      if (!receipt.isEmpty) SyncEventBus.notifyLocalChange();
      return receipt;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link legacy buddy text',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> _isUnlinkedDive(String diveId) async {
    final row = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM dives WHERE id = ?) AS present, '
          '(SELECT COUNT(*) FROM dive_buddies WHERE dive_id = ?) AS links',
          variables: [Variable.withString(diveId), Variable.withString(diveId)],
        )
        .getSingle();
    return row.read<int>('present') == 1 && row.read<int>('links') == 0;
  }

  /// The buddy [target] writes to, creating or claiming it as needed.
  Future<String> _resolve(LinkTarget target, _ApplyRun run) async {
    if (target case ExistingBuddyTarget(:final buddyId)) {
      final row = await (_db.select(
        _db.buddies,
      )..where((t) => t.id.equals(buddyId))).getSingleOrNull();
      if (row != null) {
        await _claimIfUnowned(row.id, row.diverId, run);
        return row.id;
      }
      // Deleted since planning (a sync, another window): use the name.
    }
    final key = legacyNameKey(target.name);
    final created = run.createdByKey[key];
    if (created != null) return created;
    if (run.matcher.match(target.name) case ExactMatch(:final candidate)) {
      await _claimIfUnowned(candidate.id, candidate.diverId, run);
      return candidate.id;
    }
    final id = _uuid.v4();
    await _db
        .into(_db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            diverId: Value(run.diverId),
            name: Value(target.name.trim()),
            notes: Value(run.newBuddyNote),
            createdAt: Value(run.now),
            updatedAt: Value(run.now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'buddies',
      recordId: id,
      localUpdatedAt: run.now,
    );
    run.createdByKey[key] = id;
    run.createdIds.add(id);
    return id;
  }

  /// Gives an unowned buddy to the diver, as the UDDF importer does (#1806):
  /// `getAllBuddies(diverId:)` filters strictly on `diver_id`, so an
  /// unclaimed buddy would be linked yet missing from the diver's list.
  Future<void> _claimIfUnowned(
    String id,
    String? ownerId,
    _ApplyRun run,
  ) async {
    if (ownerId != null || run.claimedIds.contains(id)) return;
    await (_db.update(_db.buddies)..where((t) => t.id.equals(id))).write(
      BuddiesCompanion(diverId: Value(run.diverId), updatedAt: Value(run.now)),
    );
    await _sync.markRecordPending(
      entityType: 'buddies',
      recordId: id,
      localUpdatedAt: run.now,
    );
    run.claimedIds.add(id);
  }
```

Add this private class at the bottom of the file (outside `BuddyConversionRepository`). It is a scratch accumulator scoped to one transaction, never exposed:

```dart
/// What one [BuddyConversionRepository.apply] run has written so far.
class _ApplyRun {
  _ApplyRun({
    required this.matcher,
    required this.diverId,
    required this.newBuddyNote,
    required this.now,
  });

  final BuddyNameMatcher matcher;
  final String diverId;
  final String newBuddyNote;
  final int now;
  final Map<String, String> createdByKey = {};
  final List<String> createdIds = [];
  final Set<String> claimedIds = {};
  final List<String> linkIds = [];
  final List<String> diveIds = [];

  ConversionReceipt toReceipt() => ConversionReceipt(
    diverId: diverId,
    diveIds: List.unmodifiable(diveIds),
    linkIds: List.unmodifiable(linkIds),
    createdBuddyIds: List.unmodifiable(createdIds),
    claimedBuddyIds: List.unmodifiable(claimedIds),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: PASS, 15 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_conversion_repository.dart test/features/buddies/data/repositories/buddy_conversion_repository_test.dart
git commit -m "feat(buddies): link legacy buddy text in one transaction (#1831)"
```

---

### Task 6: Transactional undo

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_conversion_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_conversion_repository_test.dart` (append)

**Interfaces:**
- Consumes: `ConversionReceipt` (Task 2), `apply` (Task 5).
- Produces: `Future<void> undo(ConversionReceipt receipt)`.

Behaviour, one transaction then one notify: delete the receipt's link rows that still exist (tombstoned); delete each created buddy that now has no dive link, tombstoning its certifications first as `BuddyRepository.deleteBuddy` does (the FK cascade writes no `deletion_log`); set `diver_id` back to NULL on claimed buddies still owned by `receipt.diverId`, marking them pending. An empty receipt does nothing.

- [ ] **Step 1: Write the failing tests**

Append inside `main()`, after the `apply` group:

```dart
  group('undo', () {
    test('removes the links and the buddies the conversion created', () async {
      await insertDive('d1', buddy: 'Ann');
      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);

      await repo.undo(receipt);

      expect(await db.select(db.diveBuddies).get(), isEmpty);
      expect(await db.select(db.buddies).get(), isEmpty);
      expect(await tombstones('diveBuddies'), receipt.linkIds.toSet());
      expect(await tombstones('buddies'), receipt.createdBuddyIds.toSet());
    });

    test('keeps a created buddy that another dive linked since', () async {
      await insertDive('d1', buddy: 'Ann');
      await insertDive('d2');
      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);
      await link('d2', receipt.createdBuddyIds.single);

      await repo.undo(receipt);

      expect(await db.select(db.buddies).get(), hasLength(1));
      expect((await db.select(db.diveBuddies).getSingle()).diveId, 'd2');
    });

    test('keeps an existing buddy it only linked', () async {
      await insertDive('d1', buddy: 'Bob');
      await insertBuddy('bob', 'Bob');
      final receipt = await run([
        plan('d1', [existing('bob', 'Bob')]),
      ]);

      await repo.undo(receipt);

      expect((await db.select(db.buddies).getSingle()).id, 'bob');
      expect(await db.select(db.diveBuddies).get(), isEmpty);
    });

    test('returns a claimed buddy to unowned', () async {
      await insertDive('d1', buddy: 'Leo');
      await insertBuddy('leo', 'Leo Cox', diverId: null);
      final receipt = await run([
        plan('d1', [existing('leo', 'Leo Cox')]),
      ]);
      await db.delete(db.syncRecords).go();

      await repo.undo(receipt);

      final leo = await (db.select(
        db.buddies,
      )..where((t) => t.id.equals('leo'))).getSingle();
      expect(leo.diverId, isNull);
      expect(await pending('buddies'), {'leo'});
    });

    test('announces the change once and an empty receipt does nothing', () async {
      await insertDive('d1', buddy: 'Ann');
      final receipt = await run([
        plan('d1', [newLink('Ann')]),
      ]);
      var notifications = 0;
      final sub = SyncEventBus.changes.listen((_) => notifications++);
      addTearDown(sub.cancel);

      await repo.undo(receipt);
      await repo.undo(const ConversionReceipt(diverId: 'me'));
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: FAIL to compile, `The method 'undo' isn't defined for the type 'BuddyConversionRepository'`.

- [ ] **Step 3: Implement `undo`**

Add to the class, after `apply`:

```dart
  /// Reverses [receipt]: its links, the buddies it created that nothing else
  /// has linked since, and its ownership claims. One transaction, one notify.
  Future<void> undo(ConversionReceipt receipt) async {
    if (receipt.isEmpty) return;
    try {
      await _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (receipt.linkIds.isNotEmpty) {
          final present = await (_db.select(
            _db.diveBuddies,
          )..where((t) => t.id.isIn(receipt.linkIds))).get();
          await (_db.delete(
            _db.diveBuddies,
          )..where((t) => t.id.isIn(receipt.linkIds))).go();
          for (final row in present) {
            await _sync.logDeletion(
              entityType: 'diveBuddies',
              recordId: row.id,
            );
          }
        }
        for (final id in receipt.createdBuddyIds) {
          await _deleteIfUnlinked(id);
        }
        if (receipt.claimedBuddyIds.isNotEmpty) {
          final claimed =
              await (_db.select(_db.buddies)..where(
                    (t) =>
                        t.id.isIn(receipt.claimedBuddyIds) &
                        t.diverId.equals(receipt.diverId),
                  ))
                  .get();
          for (final row in claimed) {
            await (_db.update(
              _db.buddies,
            )..where((t) => t.id.equals(row.id))).write(
              BuddiesCompanion(
                diverId: const Value(null),
                updatedAt: Value(now),
              ),
            );
            await _sync.markRecordPending(
              entityType: 'buddies',
              recordId: row.id,
              localUpdatedAt: now,
            );
          }
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to undo a legacy buddy conversion',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes buddy [id] if it still exists and no dive links it, tombstoning
  /// its certifications first: the FK cascade deletes them but writes no
  /// deletion_log, so without a tombstone they would come back on sync.
  Future<void> _deleteIfUnlinked(String id) async {
    final stillLinked =
        await (_db.select(_db.diveBuddies)
              ..where((t) => t.buddyId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (stillLinked != null) return;
    final buddy = await (_db.select(
      _db.buddies,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (buddy == null) return;
    for (final cert in await _certRepo.getCertificationsByBuddy(id)) {
      await (_db.delete(
        _db.certifications,
      )..where((t) => t.id.equals(cert.id))).go();
      await _sync.logDeletion(entityType: 'certifications', recordId: cert.id);
    }
    await (_db.delete(_db.buddies)..where((t) => t.id.equals(id))).go();
    await _sync.logDeletion(entityType: 'buddies', recordId: id);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/buddies/data/repositories/buddy_conversion_repository_test.dart`
Expected: PASS, 20 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_conversion_repository.dart test/features/buddies/data/repositories/buddy_conversion_repository_test.dart
git commit -m "feat(buddies): undo a legacy buddy text conversion (#1831)"
```

---

### Task 7: BuddyRepository delegators, service and providers

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (imports near line 11; methods after `bulkDeleteBuddies`, near line 1151)
- Create: `lib/features/buddies/data/services/legacy_buddy_conversion_service.dart`
- Create: `lib/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart`
- Test: `test/features/buddies/data/services/legacy_buddy_conversion_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 6.
- Produces:
  - `BuddyRepository.legacyConversionCandidates(String diverId) -> Future<List<MatchCandidate>>`, `unlinkedLegacyTextDives(String diverId) -> Future<List<UnlinkedTextDive>>`, `applyLegacyConversion(List<ConversionPlan>, {required String diverId, required String newBuddyNote}) -> Future<ConversionReceipt>`, `undoLegacyConversion(ConversionReceipt) -> Future<void>`.
  - `class LinkBuddyNamesData { final String diverId; final BuddyNameMatcher matcher; final List<CandidateDive> dives; }`
  - `class LegacyBuddyConversionService` with `const LegacyBuddyConversionService(BuddyRepository repository)`, `matcherFor(String diverId)`, `planFor(Dive dive, String diverId) -> Future<(ConversionPlan, BuddyNameMatcher)>`, `planCandidates(String diverId) -> Future<LinkBuddyNamesData>`, `apply(...)`, `undo(...)`.
  - `legacyBuddyConversionServiceProvider` (`Provider<LegacyBuddyConversionService>`), `linkBuddyNamesDataProvider` (`FutureProvider<LinkBuddyNamesData?>`, null when there is no diver), `void refreshAfterLegacyBuddyConversion(ProviderContainer container)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LegacyBuddyConversionService service;

  Future<void> insertDive(String id, String buddy, {int at = 1000}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('me'),
          diveDateTime: at,
          createdAt: 1,
          updatedAt: 1,
          buddy: Value(buddy),
        ),
      );

  Future<void> insertBuddy(String id, String name) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: const Value('me'),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    service = LegacyBuddyConversionService(BuddyRepository());
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'me', name: 'me', createdAt: 1, updatedAt: 1),
        );
  });

  tearDown(tearDownTestDatabase);

  test('planCandidates plans each dive and drops placeholder-only text', () async {
    await insertBuddy('jim', 'Jim Dunfield');
    await insertDive('d1', 'Jim Dunfield, Ann', at: 2000);
    await insertDive('d2', 'None', at: 1000);

    final data = await service.planCandidates('me');

    expect(data.diverId, 'me');
    expect(data.dives.map((d) => d.diveId), ['d1']);
    expect(data.dives.single.plan.links.map((l) => l.target), const [
      ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'),
      NewBuddyTarget('Ann'),
    ]);
    expect(data.matcher.candidates.map((c) => c.id), ['jim']);
  });

  test('planFor plans one dive against the diver buddies', () async {
    await insertBuddy('jim', 'Jim Dunfield');
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026),
      buddy: 'jim dunfield',
      diveMaster: 'Ana',
    );

    final (plan, matcher) = await service.planFor(dive, 'me');

    expect(plan.diveId, 'd1');
    expect(
      plan.links.first.target,
      const ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'),
    );
    expect(plan.links.last.roleId, DiveRole.diveMasterId);
    expect(matcher.candidates.single.id, 'jim');
  });

  test('apply and undo round-trip through the buddy repository', () async {
    await insertDive('d1', 'Ann');
    final data = await service.planCandidates('me');

    final receipt = await service.apply(
      [for (final d in data.dives) d.plan],
      diverId: 'me',
      newBuddyNote: 'note',
    );
    expect(receipt.linkIds, hasLength(1));

    await service.undo(receipt);
    expect(await db.select(db.diveBuddies).get(), isEmpty);
    expect(await db.select(db.buddies).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/services/legacy_buddy_conversion_service_test.dart`
Expected: FAIL to compile, `legacy_buddy_conversion_service.dart` does not exist.

- [ ] **Step 3: Add the delegators to `BuddyRepository`**

Add imports after the existing `buddy_with_dive_count.dart` import:

```dart
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
```

Add after `bulkDeleteBuddies`:

```dart
  /// Legacy buddy text conversion (#1831). Delegates to
  /// [BuddyConversionRepository].
  Future<List<MatchCandidate>> legacyConversionCandidates(String diverId) =>
      BuddyConversionRepository().candidateBuddies(diverId);

  Future<List<UnlinkedTextDive>> unlinkedLegacyTextDives(String diverId) =>
      BuddyConversionRepository().unlinkedTextDives(diverId);

  Future<ConversionReceipt> applyLegacyConversion(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) => BuddyConversionRepository().apply(
    plans,
    diverId: diverId,
    newBuddyNote: newBuddyNote,
  );

  Future<void> undoLegacyConversion(ConversionReceipt receipt) =>
      BuddyConversionRepository().undo(receipt);
```

- [ ] **Step 4: Write the service**

`lib/features/buddies/data/services/legacy_buddy_conversion_service.dart`:

```dart
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What the bulk page shows: every dive with unlinked text, planned against
/// one matcher that the per-dive review reuses.
class LinkBuddyNamesData {
  const LinkBuddyNamesData({
    required this.diverId,
    required this.matcher,
    required this.dives,
  });

  final String diverId;
  final BuddyNameMatcher matcher;
  final List<CandidateDive> dives;
}

/// Plans legacy buddy text conversions and applies them through
/// [BuddyRepository] (#1831).
class LegacyBuddyConversionService {
  const LegacyBuddyConversionService(this._repository);

  final BuddyRepository _repository;

  Future<BuddyNameMatcher> matcherFor(String diverId) async =>
      BuddyNameMatcher(
        await _repository.legacyConversionCandidates(diverId),
        diverId: diverId,
      );

  /// The plan for [dive], with the matcher the review sheet re-matches
  /// edited names against.
  Future<(ConversionPlan, BuddyNameMatcher)> planFor(
    Dive dive,
    String diverId,
  ) async {
    final matcher = await matcherFor(diverId);
    final plan = planLegacyConversion(
      diveId: dive.id,
      buddyText: dive.buddy,
      diveMasterText: dive.diveMaster,
      matcher: matcher,
    );
    return (plan, matcher);
  }

  /// Every dive of [diverId] whose legacy text parses to at least one name.
  Future<LinkBuddyNamesData> planCandidates(String diverId) async {
    final matcher = await matcherFor(diverId);
    final rows = await _repository.unlinkedLegacyTextDives(diverId);
    final dives = <CandidateDive>[];
    for (final row in rows) {
      final plan = planLegacyConversion(
        diveId: row.diveId,
        buddyText: row.buddyText,
        diveMasterText: row.diveMasterText,
        matcher: matcher,
      );
      if (plan.isEmpty) continue;
      dives.add(
        CandidateDive(
          plan: plan,
          diveNumber: row.diveNumber,
          dateTime: row.dateTime,
          siteName: row.siteName,
        ),
      );
    }
    return LinkBuddyNamesData(
      diverId: diverId,
      matcher: matcher,
      dives: List.unmodifiable(dives),
    );
  }

  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) => _repository.applyLegacyConversion(
    plans,
    diverId: diverId,
    newBuddyNote: newBuddyNote,
  );

  Future<void> undo(ConversionReceipt receipt) =>
      _repository.undoLegacyConversion(receipt);
}
```

- [ ] **Step 5: Write the providers**

`lib/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final legacyBuddyConversionServiceProvider =
    Provider<LegacyBuddyConversionService>(
      (ref) => LegacyBuddyConversionService(ref.watch(buddyRepositoryProvider)),
    );

/// The bulk page's dives; null when there is no diver.
final linkBuddyNamesDataProvider = FutureProvider<LinkBuddyNamesData?>((
  ref,
) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return null;
  return ref.watch(legacyBuddyConversionServiceProvider).planCandidates(diverId);
});

/// Refreshes everything a conversion or its undo can change (#1831).
///
/// Explicit, because the table-change streams miss it: the paginated dive
/// list's stream does not watch `dive_buddies`, and the buddy count
/// providers tick only on `buddies` and `dives`, which a links-only
/// conversion never writes. Takes the [ProviderContainer], not a
/// `WidgetRef`, because Undo can run after the page that converted is gone.
void refreshAfterLegacyBuddyConversion(ProviderContainer container) {
  container
    ..invalidate(buddiesForDiveProvider)
    ..invalidate(buddyStatsProvider)
    ..invalidate(diveIdsForBuddyProvider)
    ..invalidate(divesForBuddyProvider)
    ..invalidate(allBuddiesProvider)
    ..invalidate(allBuddiesWithDiveCountProvider)
    ..invalidate(divesProvider)
    ..invalidate(diveListNotifierProvider)
    ..invalidate(linkBuddyNamesDataProvider);
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/buddies/data/services/legacy_buddy_conversion_service_test.dart test/features/buddies/data/repositories/buddy_repository_test.dart`
Expected: PASS (3 new tests, and the existing BuddyRepository suite unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart lib/features/buddies/data/services/legacy_buddy_conversion_service.dart lib/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart test/features/buddies/data/services/legacy_buddy_conversion_service_test.dart
git commit -m "feat(buddies): plan and apply legacy buddy text conversions (#1831)"
```

---

### Task 8: Localized strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (checked in)

**Interfaces:**
- Produces these `AppLocalizations` getters and methods, used by Tasks 9 to 11:
  `buddies_linkText_action`, `buddies_linkText_addName`, `buddies_linkText_chipWithRole(String name, String role)`, `buddies_linkText_chooseExisting`, `buddies_linkText_editName`, `buddies_linkText_error(String error)`, `buddies_linkText_linkCount(int count)`, `buddies_linkText_linkedSnackbar(int count)`, `buddies_linkText_nameLabel`, `buddies_linkText_newBuddyNote`, `buddies_linkText_noBuddiesFound`, `buddies_linkText_page_diveNumber(int number)`, `buddies_linkText_page_empty`, `buddies_linkText_page_errorLoading(String error)`, `buddies_linkText_page_linkDives(int count)`, `buddies_linkText_page_linkedSnackbar(int count)`, `buddies_linkText_page_subtitle`, `buddies_linkText_page_summaryDives(int count)`, `buddies_linkText_page_summaryExisting(int count)`, `buddies_linkText_page_summaryNew(int count)`, `buddies_linkText_page_title`, `buddies_linkText_searchHint`, `buddies_linkText_sheetTitle`, `buddies_linkText_sourceBuddy(String text)`, `buddies_linkText_sourceDiveMaster(String text)`, `buddies_linkText_statusExisting`, `buddies_linkText_statusNew`, `buddies_linkText_suggestion(String name)`, `buddies_linkText_tie(int count, String name)`, `buddies_linkText_undone`, `buddies_linkText_useSuggestion`.

Placement: `app_en.arb` is alphabetical and `buddies_linkText_*` sorts directly after `buddies_label_notSpecified` (and before `buddies_message_added`). The ten translated files are grouped by feature, not sorted, but all contain `buddies_label_notSpecified`, so the block goes directly after that anchor line in every file. English also gets `@` metadata blocks for placeholder types.

- [ ] **Step 1: Write the strings file**

Save as `$SCRATCH/link_text_strings.json` (the `@meta` key holds English placeholder metadata):

```json
{
  "@meta": {
    "buddies_linkText_chipWithRole": {"placeholders": {"name": {"type": "String"}, "role": {"type": "String"}}},
    "buddies_linkText_error": {"placeholders": {"error": {"type": "String"}}},
    "buddies_linkText_linkCount": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_linkedSnackbar": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_newBuddyNote": {"description": "Notes stored on a buddy created from a dive's legacy buddy text"},
    "buddies_linkText_page_diveNumber": {"placeholders": {"number": {"type": "int"}}},
    "buddies_linkText_page_errorLoading": {"placeholders": {"error": {"type": "String"}}},
    "buddies_linkText_page_linkDives": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_page_linkedSnackbar": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_page_summaryDives": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_page_summaryExisting": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_page_summaryNew": {"placeholders": {"count": {"type": "int"}}},
    "buddies_linkText_sourceBuddy": {"placeholders": {"text": {"type": "String"}}},
    "buddies_linkText_sourceDiveMaster": {"placeholders": {"text": {"type": "String"}}},
    "buddies_linkText_suggestion": {"placeholders": {"name": {"type": "String"}}},
    "buddies_linkText_tie": {"placeholders": {"count": {"type": "int"}, "name": {"type": "String"}}}
  },
  "en": {
    "buddies_linkText_action": "Link to buddy records",
    "buddies_linkText_addName": "Add a name",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Choose existing buddy",
    "buddies_linkText_editName": "Edit name",
    "buddies_linkText_error": "Could not link buddies: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{Link 1} other{Link {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{Linked 1 buddy} other{Linked {count} buddies}}",
    "buddies_linkText_nameLabel": "Name",
    "buddies_linkText_newBuddyNote": "Converted from dive buddy text",
    "buddies_linkText_noBuddiesFound": "No buddies found",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Every buddy name is linked to a buddy record",
    "buddies_linkText_page_errorLoading": "Could not load dives: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{Link 1 dive} other{Link {count} dives}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Linked buddies on 1 dive} other{Linked buddies on {count} dives}}",
    "buddies_linkText_page_subtitle": "Turn buddy names on imported dives into buddy records",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 dive} other{{count} dives}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 existing buddy} other{{count} existing buddies}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 new buddy} other{{count} new buddies}}",
    "buddies_linkText_page_title": "Link buddy names",
    "buddies_linkText_searchHint": "Search buddies",
    "buddies_linkText_sheetTitle": "Link buddy records",
    "buddies_linkText_sourceBuddy": "From \"{text}\"",
    "buddies_linkText_sourceDiveMaster": "Dive master \"{text}\"",
    "buddies_linkText_statusExisting": "Existing buddy",
    "buddies_linkText_statusNew": "New buddy",
    "buddies_linkText_suggestion": "Did you mean {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 buddy named {name}} other{{count} buddies named {name}}}",
    "buddies_linkText_undone": "Buddy links removed",
    "buddies_linkText_useSuggestion": "Use"
  },
  "de": {
    "buddies_linkText_action": "Mit Tauchpartner-Einträgen verknüpfen",
    "buddies_linkText_addName": "Namen hinzufügen",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Vorhandenen Tauchpartner wählen",
    "buddies_linkText_editName": "Namen bearbeiten",
    "buddies_linkText_error": "Tauchpartner konnten nicht verknüpft werden: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{1 verknüpfen} other{{count} verknüpfen}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 Tauchpartner verknüpft} other{{count} Tauchpartner verknüpft}}",
    "buddies_linkText_nameLabel": "Name",
    "buddies_linkText_newBuddyNote": "Aus dem Tauchpartner-Text eines Tauchgangs übernommen",
    "buddies_linkText_noBuddiesFound": "Keine Tauchpartner gefunden",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Alle Tauchpartner-Namen sind mit Einträgen verknüpft",
    "buddies_linkText_page_errorLoading": "Tauchgänge konnten nicht geladen werden: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{1 Tauchgang verknüpfen} other{{count} Tauchgänge verknüpfen}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Tauchpartner bei 1 Tauchgang verknüpft} other{Tauchpartner bei {count} Tauchgängen verknüpft}}",
    "buddies_linkText_page_subtitle": "Tauchpartner-Namen importierter Tauchgänge in Einträge umwandeln",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 Tauchgang} other{{count} Tauchgänge}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 vorhandener Tauchpartner} other{{count} vorhandene Tauchpartner}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 neuer Tauchpartner} other{{count} neue Tauchpartner}}",
    "buddies_linkText_page_title": "Tauchpartner-Namen verknüpfen",
    "buddies_linkText_searchHint": "Tauchpartner suchen",
    "buddies_linkText_sheetTitle": "Tauchpartner-Einträge verknüpfen",
    "buddies_linkText_sourceBuddy": "Aus „{text}“",
    "buddies_linkText_sourceDiveMaster": "Divemaster „{text}“",
    "buddies_linkText_statusExisting": "Vorhandener Tauchpartner",
    "buddies_linkText_statusNew": "Neuer Tauchpartner",
    "buddies_linkText_suggestion": "Meinst du {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 Tauchpartner namens {name}} other{{count} Tauchpartner namens {name}}}",
    "buddies_linkText_undone": "Tauchpartner-Verknüpfungen entfernt",
    "buddies_linkText_useSuggestion": "Übernehmen"
  },
  "es": {
    "buddies_linkText_action": "Vincular a fichas de compañeros",
    "buddies_linkText_addName": "Agregar un nombre",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Elegir un compañero existente",
    "buddies_linkText_editName": "Editar nombre",
    "buddies_linkText_error": "No se pudieron vincular los compañeros: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{Vincular 1} other{Vincular {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 compañero vinculado} other{{count} compañeros vinculados}}",
    "buddies_linkText_nameLabel": "Nombre",
    "buddies_linkText_newBuddyNote": "Convertido del texto de compañero de una inmersión",
    "buddies_linkText_noBuddiesFound": "No se encontraron compañeros",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Todos los nombres de compañeros están vinculados a una ficha",
    "buddies_linkText_page_errorLoading": "No se pudieron cargar las inmersiones: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{Vincular 1 inmersión} other{Vincular {count} inmersiones}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Compañeros vinculados en 1 inmersión} other{Compañeros vinculados en {count} inmersiones}}",
    "buddies_linkText_page_subtitle": "Convierte los nombres de compañeros de inmersiones importadas en fichas",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 inmersión} other{{count} inmersiones}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 compañero existente} other{{count} compañeros existentes}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 compañero nuevo} other{{count} compañeros nuevos}}",
    "buddies_linkText_page_title": "Vincular nombres de compañeros",
    "buddies_linkText_searchHint": "Buscar compañeros",
    "buddies_linkText_sheetTitle": "Vincular fichas de compañeros",
    "buddies_linkText_sourceBuddy": "De «{text}»",
    "buddies_linkText_sourceDiveMaster": "Divemaster «{text}»",
    "buddies_linkText_statusExisting": "Compañero existente",
    "buddies_linkText_statusNew": "Compañero nuevo",
    "buddies_linkText_suggestion": "¿Quisiste decir {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 compañero llamado {name}} other{{count} compañeros llamados {name}}}",
    "buddies_linkText_undone": "Vínculos de compañeros eliminados",
    "buddies_linkText_useSuggestion": "Usar"
  },
  "fr": {
    "buddies_linkText_action": "Lier à des fiches de binômes",
    "buddies_linkText_addName": "Ajouter un nom",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Choisir un binôme existant",
    "buddies_linkText_editName": "Modifier le nom",
    "buddies_linkText_error": "Impossible de lier les binômes : {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{Lier 1} other{Lier {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 binôme lié} other{{count} binômes liés}}",
    "buddies_linkText_nameLabel": "Nom",
    "buddies_linkText_newBuddyNote": "Converti depuis le texte binôme d'une plongée",
    "buddies_linkText_noBuddiesFound": "Aucun binôme trouvé",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Tous les noms de binômes sont liés à une fiche",
    "buddies_linkText_page_errorLoading": "Impossible de charger les plongées : {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{Lier 1 plongée} other{Lier {count} plongées}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Binômes liés sur 1 plongée} other{Binômes liés sur {count} plongées}}",
    "buddies_linkText_page_subtitle": "Transformer les noms de binômes des plongées importées en fiches",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 plongée} other{{count} plongées}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 binôme existant} other{{count} binômes existants}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 nouveau binôme} other{{count} nouveaux binômes}}",
    "buddies_linkText_page_title": "Lier les noms de binômes",
    "buddies_linkText_searchHint": "Rechercher des binômes",
    "buddies_linkText_sheetTitle": "Lier des fiches de binômes",
    "buddies_linkText_sourceBuddy": "Depuis « {text} »",
    "buddies_linkText_sourceDiveMaster": "Directeur de plongée « {text} »",
    "buddies_linkText_statusExisting": "Binôme existant",
    "buddies_linkText_statusNew": "Nouveau binôme",
    "buddies_linkText_suggestion": "Vouliez-vous dire {name} ?",
    "buddies_linkText_tie": "{count, plural, =1{1 binôme nommé {name}} other{{count} binômes nommés {name}}}",
    "buddies_linkText_undone": "Liens de binômes supprimés",
    "buddies_linkText_useSuggestion": "Utiliser"
  },
  "he": {
    "buddies_linkText_action": "קישור לרשומות חברי צוללים",
    "buddies_linkText_addName": "הוספת שם",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "בחירת חבר צוללים קיים",
    "buddies_linkText_editName": "עריכת שם",
    "buddies_linkText_error": "לא ניתן לקשר את חברי הצוללים: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{קישור 1} other{קישור {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{חבר צוללים אחד קושר} other{{count} חברי צוללים קושרו}}",
    "buddies_linkText_nameLabel": "שם",
    "buddies_linkText_newBuddyNote": "הומר מטקסט חבר הצוללים של צלילה",
    "buddies_linkText_noBuddiesFound": "לא נמצאו חברי צוללים",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "כל שמות חברי הצוללים מקושרים לרשומה",
    "buddies_linkText_page_errorLoading": "לא ניתן לטעון את הצלילות: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{קישור צלילה אחת} other{קישור {count} צלילות}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{חברי צוללים קושרו בצלילה אחת} other{חברי צוללים קושרו ב-{count} צלילות}}",
    "buddies_linkText_page_subtitle": "המרת שמות חברי צוללים מצלילות מיובאות לרשומות",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{צלילה אחת} other{{count} צלילות}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{חבר צוללים קיים אחד} other{{count} חברי צוללים קיימים}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{חבר צוללים חדש אחד} other{{count} חברי צוללים חדשים}}",
    "buddies_linkText_page_title": "קישור שמות חברי צוללים",
    "buddies_linkText_searchHint": "חיפוש חברי צוללים",
    "buddies_linkText_sheetTitle": "קישור רשומות חברי צוללים",
    "buddies_linkText_sourceBuddy": "מתוך \"{text}\"",
    "buddies_linkText_sourceDiveMaster": "דייבמאסטר \"{text}\"",
    "buddies_linkText_statusExisting": "חבר צוללים קיים",
    "buddies_linkText_statusNew": "חבר צוללים חדש",
    "buddies_linkText_suggestion": "האם התכוונת ל-{name}?",
    "buddies_linkText_tie": "{count, plural, =1{חבר צוללים אחד בשם {name}} other{{count} חברי צוללים בשם {name}}}",
    "buddies_linkText_undone": "קישורי חברי הצוללים הוסרו",
    "buddies_linkText_useSuggestion": "שימוש"
  },
  "hu": {
    "buddies_linkText_action": "Összekapcsolás búvártárs-rekordokkal",
    "buddies_linkText_addName": "Név hozzáadása",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Meglévő búvártárs kiválasztása",
    "buddies_linkText_editName": "Név szerkesztése",
    "buddies_linkText_error": "Nem sikerült összekapcsolni a búvártársakat: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{1 összekapcsolása} other{{count} összekapcsolása}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 búvártárs összekapcsolva} other{{count} búvártárs összekapcsolva}}",
    "buddies_linkText_nameLabel": "Név",
    "buddies_linkText_newBuddyNote": "Egy merülés búvártárs-szövegéből átalakítva",
    "buddies_linkText_noBuddiesFound": "Nem található búvártárs",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Minden búvártársnév rekordhoz van kapcsolva",
    "buddies_linkText_page_errorLoading": "Nem sikerült betölteni a merüléseket: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{1 merülés összekapcsolása} other{{count} merülés összekapcsolása}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Búvártársak összekapcsolva 1 merülésen} other{Búvártársak összekapcsolva {count} merülésen}}",
    "buddies_linkText_page_subtitle": "Importált merülések búvártársneveinek rekordokká alakítása",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 merülés} other{{count} merülés}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 meglévő búvártárs} other{{count} meglévő búvártárs}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 új búvártárs} other{{count} új búvártárs}}",
    "buddies_linkText_page_title": "Búvártársnevek összekapcsolása",
    "buddies_linkText_searchHint": "Búvártársak keresése",
    "buddies_linkText_sheetTitle": "Búvártárs-rekordok összekapcsolása",
    "buddies_linkText_sourceBuddy": "Forrás: „{text}”",
    "buddies_linkText_sourceDiveMaster": "Divemaster: „{text}”",
    "buddies_linkText_statusExisting": "Meglévő búvártárs",
    "buddies_linkText_statusNew": "Új búvártárs",
    "buddies_linkText_suggestion": "Erre gondoltál: {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 {name} nevű búvártárs} other{{count} {name} nevű búvártárs}}",
    "buddies_linkText_undone": "Búvártárs-kapcsolatok eltávolítva",
    "buddies_linkText_useSuggestion": "Használat"
  },
  "it": {
    "buddies_linkText_action": "Collega a schede compagno",
    "buddies_linkText_addName": "Aggiungi un nome",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Scegli un compagno esistente",
    "buddies_linkText_editName": "Modifica nome",
    "buddies_linkText_error": "Impossibile collegare i compagni: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{Collega 1} other{Collega {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 compagno collegato} other{{count} compagni collegati}}",
    "buddies_linkText_nameLabel": "Nome",
    "buddies_linkText_newBuddyNote": "Convertito dal testo compagno di un'immersione",
    "buddies_linkText_noBuddiesFound": "Nessun compagno trovato",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Tutti i nomi dei compagni sono collegati a una scheda",
    "buddies_linkText_page_errorLoading": "Impossibile caricare le immersioni: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{Collega 1 immersione} other{Collega {count} immersioni}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Compagni collegati su 1 immersione} other{Compagni collegati su {count} immersioni}}",
    "buddies_linkText_page_subtitle": "Trasforma i nomi dei compagni delle immersioni importate in schede",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 immersione} other{{count} immersioni}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 compagno esistente} other{{count} compagni esistenti}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 nuovo compagno} other{{count} nuovi compagni}}",
    "buddies_linkText_page_title": "Collega i nomi dei compagni",
    "buddies_linkText_searchHint": "Cerca compagni",
    "buddies_linkText_sheetTitle": "Collega schede compagno",
    "buddies_linkText_sourceBuddy": "Da «{text}»",
    "buddies_linkText_sourceDiveMaster": "Divemaster «{text}»",
    "buddies_linkText_statusExisting": "Compagno esistente",
    "buddies_linkText_statusNew": "Nuovo compagno",
    "buddies_linkText_suggestion": "Intendevi {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 compagno di nome {name}} other{{count} compagni di nome {name}}}",
    "buddies_linkText_undone": "Collegamenti ai compagni rimossi",
    "buddies_linkText_useSuggestion": "Usa"
  },
  "nl": {
    "buddies_linkText_action": "Koppelen aan buddy-records",
    "buddies_linkText_addName": "Naam toevoegen",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Bestaande buddy kiezen",
    "buddies_linkText_editName": "Naam bewerken",
    "buddies_linkText_error": "Buddies konden niet worden gekoppeld: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{1 koppelen} other{{count} koppelen}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 buddy gekoppeld} other{{count} buddies gekoppeld}}",
    "buddies_linkText_nameLabel": "Naam",
    "buddies_linkText_newBuddyNote": "Omgezet uit de buddytekst van een duik",
    "buddies_linkText_noBuddiesFound": "Geen buddies gevonden",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Elke buddynaam is aan een buddy-record gekoppeld",
    "buddies_linkText_page_errorLoading": "Duiken konden niet worden geladen: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{1 duik koppelen} other{{count} duiken koppelen}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Buddies gekoppeld bij 1 duik} other{Buddies gekoppeld bij {count} duiken}}",
    "buddies_linkText_page_subtitle": "Buddynamen van geïmporteerde duiken omzetten in buddy-records",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 duik} other{{count} duiken}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 bestaande buddy} other{{count} bestaande buddies}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 nieuwe buddy} other{{count} nieuwe buddies}}",
    "buddies_linkText_page_title": "Buddynamen koppelen",
    "buddies_linkText_searchHint": "Buddies zoeken",
    "buddies_linkText_sheetTitle": "Buddy-records koppelen",
    "buddies_linkText_sourceBuddy": "Uit “{text}”",
    "buddies_linkText_sourceDiveMaster": "Divemaster “{text}”",
    "buddies_linkText_statusExisting": "Bestaande buddy",
    "buddies_linkText_statusNew": "Nieuwe buddy",
    "buddies_linkText_suggestion": "Bedoel je {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 buddy met de naam {name}} other{{count} buddies met de naam {name}}}",
    "buddies_linkText_undone": "Buddykoppelingen verwijderd",
    "buddies_linkText_useSuggestion": "Gebruiken"
  },
  "pt": {
    "buddies_linkText_action": "Vincular a registros de companheiros",
    "buddies_linkText_addName": "Adicionar um nome",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "Escolher companheiro existente",
    "buddies_linkText_editName": "Editar nome",
    "buddies_linkText_error": "Não foi possível vincular os companheiros: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{Vincular 1} other{Vincular {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{1 companheiro vinculado} other{{count} companheiros vinculados}}",
    "buddies_linkText_nameLabel": "Nome",
    "buddies_linkText_newBuddyNote": "Convertido do texto de companheiro de um mergulho",
    "buddies_linkText_noBuddiesFound": "Nenhum companheiro encontrado",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "Todos os nomes de companheiros estão vinculados a um registro",
    "buddies_linkText_page_errorLoading": "Não foi possível carregar os mergulhos: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{Vincular 1 mergulho} other{Vincular {count} mergulhos}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{Companheiros vinculados em 1 mergulho} other{Companheiros vinculados em {count} mergulhos}}",
    "buddies_linkText_page_subtitle": "Transforme nomes de companheiros de mergulhos importados em registros",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{1 mergulho} other{{count} mergulhos}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{1 companheiro existente} other{{count} companheiros existentes}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{1 companheiro novo} other{{count} companheiros novos}}",
    "buddies_linkText_page_title": "Vincular nomes de companheiros",
    "buddies_linkText_searchHint": "Buscar companheiros",
    "buddies_linkText_sheetTitle": "Vincular registros de companheiros",
    "buddies_linkText_sourceBuddy": "De “{text}”",
    "buddies_linkText_sourceDiveMaster": "Divemaster “{text}”",
    "buddies_linkText_statusExisting": "Companheiro existente",
    "buddies_linkText_statusNew": "Companheiro novo",
    "buddies_linkText_suggestion": "Você quis dizer {name}?",
    "buddies_linkText_tie": "{count, plural, =1{1 companheiro chamado {name}} other{{count} companheiros chamados {name}}}",
    "buddies_linkText_undone": "Vínculos de companheiros removidos",
    "buddies_linkText_useSuggestion": "Usar"
  },
  "zh": {
    "buddies_linkText_action": "关联到潜伴记录",
    "buddies_linkText_addName": "添加名字",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "选择已有潜伴",
    "buddies_linkText_editName": "编辑名字",
    "buddies_linkText_error": "无法关联潜伴：{error}",
    "buddies_linkText_linkCount": "{count, plural, other{关联 {count} 个}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, other{已关联 {count} 位潜伴}}",
    "buddies_linkText_nameLabel": "名字",
    "buddies_linkText_newBuddyNote": "由潜水记录中的潜伴文本转换而来",
    "buddies_linkText_noBuddiesFound": "未找到潜伴",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "所有潜伴名字都已关联到潜伴记录",
    "buddies_linkText_page_errorLoading": "无法加载潜水记录：{error}",
    "buddies_linkText_page_linkDives": "{count, plural, other{关联 {count} 次潜水}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, other{已为 {count} 次潜水关联潜伴}}",
    "buddies_linkText_page_subtitle": "将导入潜水中的潜伴名字转换为潜伴记录",
    "buddies_linkText_page_summaryDives": "{count, plural, other{{count} 次潜水}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, other{{count} 位已有潜伴}}",
    "buddies_linkText_page_summaryNew": "{count, plural, other{{count} 位新潜伴}}",
    "buddies_linkText_page_title": "关联潜伴名字",
    "buddies_linkText_searchHint": "搜索潜伴",
    "buddies_linkText_sheetTitle": "关联潜伴记录",
    "buddies_linkText_sourceBuddy": "来自“{text}”",
    "buddies_linkText_sourceDiveMaster": "潜水长“{text}”",
    "buddies_linkText_statusExisting": "已有潜伴",
    "buddies_linkText_statusNew": "新潜伴",
    "buddies_linkText_suggestion": "您是指 {name} 吗？",
    "buddies_linkText_tie": "{count, plural, other{{count} 位名为 {name} 的潜伴}}",
    "buddies_linkText_undone": "已移除潜伴关联",
    "buddies_linkText_useSuggestion": "使用"
  },
  "ar": {
    "buddies_linkText_action": "ربط بسجلات الرفاق",
    "buddies_linkText_addName": "إضافة اسم",
    "buddies_linkText_chipWithRole": "{name} · {role}",
    "buddies_linkText_chooseExisting": "اختيار رفيق موجود",
    "buddies_linkText_editName": "تعديل الاسم",
    "buddies_linkText_error": "تعذر ربط الرفاق: {error}",
    "buddies_linkText_linkCount": "{count, plural, =1{ربط 1} other{ربط {count}}}",
    "buddies_linkText_linkedSnackbar": "{count, plural, =1{تم ربط رفيق واحد} other{تم ربط {count} رفيق}}",
    "buddies_linkText_nameLabel": "الاسم",
    "buddies_linkText_newBuddyNote": "تم التحويل من نص الرفيق في غطسة",
    "buddies_linkText_noBuddiesFound": "لم يتم العثور على رفاق",
    "buddies_linkText_page_diveNumber": "#{number}",
    "buddies_linkText_page_empty": "كل أسماء الرفاق مرتبطة بسجل رفيق",
    "buddies_linkText_page_errorLoading": "تعذر تحميل الغطسات: {error}",
    "buddies_linkText_page_linkDives": "{count, plural, =1{ربط غطسة واحدة} other{ربط {count} غطسة}}",
    "buddies_linkText_page_linkedSnackbar": "{count, plural, =1{تم ربط الرفاق في غطسة واحدة} other{تم ربط الرفاق في {count} غطسة}}",
    "buddies_linkText_page_subtitle": "تحويل أسماء الرفاق في الغطسات المستوردة إلى سجلات رفاق",
    "buddies_linkText_page_summaryDives": "{count, plural, =1{غطسة واحدة} other{{count} غطسة}}",
    "buddies_linkText_page_summaryExisting": "{count, plural, =1{رفيق موجود واحد} other{{count} رفيق موجود}}",
    "buddies_linkText_page_summaryNew": "{count, plural, =1{رفيق جديد واحد} other{{count} رفيق جديد}}",
    "buddies_linkText_page_title": "ربط أسماء الرفاق",
    "buddies_linkText_searchHint": "البحث عن رفاق",
    "buddies_linkText_sheetTitle": "ربط سجلات الرفاق",
    "buddies_linkText_sourceBuddy": "من «{text}»",
    "buddies_linkText_sourceDiveMaster": "دايف ماستر «{text}»",
    "buddies_linkText_statusExisting": "رفيق موجود",
    "buddies_linkText_statusNew": "رفيق جديد",
    "buddies_linkText_suggestion": "هل تقصد {name}؟",
    "buddies_linkText_tie": "{count, plural, =1{رفيق واحد باسم {name}} other{{count} رفيق باسم {name}}}",
    "buddies_linkText_undone": "تمت إزالة روابط الرفاق",
    "buddies_linkText_useSuggestion": "استخدام"
  }
}
```

- [ ] **Step 2: Write the insertion script**

Save as `$SCRATCH/insert_link_text_keys.py`. It inserts by line, never re-dumps a whole file, keeps each file's line endings, and refuses to run twice:

```python
"""Insert the buddies_linkText_* block after buddies_label_notSpecified in every ARB."""
import json
import pathlib
import sys

ARB_DIR = pathlib.Path("lib/l10n/arb")
ANCHOR = '"buddies_label_notSpecified"'

strings = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
meta = strings.pop("@meta")
expected_keys = set(strings["en"])

for path in sorted(ARB_DIR.glob("app_*.arb")):
    locale = path.stem.removeprefix("app_")
    values = strings[locale]
    assert set(values) == expected_keys, f"{locale}: key set differs from en"
    raw = path.read_bytes().decode("utf-8")
    assert '"buddies_linkText_action"' not in raw, f"{path.name}: already inserted"
    newline = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.split(newline)
    anchor_at = next(i for i, line in enumerate(lines) if line.lstrip().startswith(ANCHOR))
    block = []
    for key in sorted(values):
        block.append(f"  {json.dumps(key)}: {json.dumps(values[key], ensure_ascii=False)},")
        if locale == "en" and key in meta:
            body = json.dumps(meta[key], ensure_ascii=False, indent=2).replace("\n", "\n  ")
            block.extend(f"  {json.dumps('@' + key)}: {body},".split("\n"))
    lines[anchor_at + 1 : anchor_at + 1] = block
    path.write_bytes(newline.join(lines).encode("utf-8"))
    json.loads(path.read_text(encoding="utf-8"))
    print(f"{path.name}: +{len(block)} lines")
```

- [ ] **Step 3: Run it and regenerate**

```bash
LC_ALL=en_US.UTF-8 /opt/homebrew/bin/python3.14 $SCRATCH/insert_link_text_keys.py $SCRATCH/link_text_strings.json
```

Expected: 11 lines of output; `app_en.arb` gains more lines than the others (its `@` blocks), every translated file gains exactly 31.

```bash
flutter gen-l10n
```

Expected: exit 0, no "untranslated message" warnings for `buddies_linkText_*`.

- [ ] **Step 4: Verify the diff is insert-only**

```bash
git diff --numstat -- lib/l10n/arb/*.arb
```

Expected: every `.arb` row shows `0` in the removed column (a non-zero removed count means line endings or an existing line changed; revert that file with `git checkout -- <file>` and fix the script). Also scan the new lines for the em-dash character (U+2014, written as an escape so this plan never contains it):

```bash
git diff -- lib/l10n/arb/*.arb | grep -c $'\u2014'
```

Expected: `0`.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): strings for linking legacy buddy text (#1831)"
```

---

### Task 9: Review sheet

**Files:**
- Create: `lib/features/buddies/presentation/widgets/legacy_name_dialog.dart`
- Create: `lib/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart`
- Create: `lib/features/buddies/presentation/widgets/legacy_buddy_review_row.dart`
- Create: `lib/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart`
- Test: `test/features/buddies/presentation/widgets/legacy_buddy_review_sheet_test.dart`

**Interfaces:**
- Consumes: entities, `BuddyNameMatcher`, `planLink`, `collapseLinks`, `planLegacyConversion` (Tasks 2 and 3); `legacyNameKey` (Task 1); l10n keys (Task 8); `allDiveRolesProvider` (`package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart`); `DiveRoleDisplay.localizedName` (`package:submersion/features/dive_roles/presentation/dive_role_display.dart`).
- Produces:
  - `Future<String?> showLegacyNameDialog(BuildContext context, {String initial = ''})`
  - `Future<MatchCandidate?> showBuddyCandidatePicker(BuildContext context, {required List<MatchCandidate> candidates})` and widget `BuddyCandidatePickerSheet`
  - `LegacyBuddyReviewRow` (keys: role dropdown `Key('legacy-row-role-<identity>')`, menu `Key('legacy-row-menu-<identity>')`)
  - `Future<ConversionPlan?> showLegacyBuddyReviewSheet(BuildContext context, {required ConversionPlan plan, required BuddyNameMatcher matcher})` and widget `LegacyBuddyReviewSheet`. Returns the edited plan on Link, null on Cancel or dismiss.

Layout note: the row is a plain `Row`, not a `ListTile`, because a `ListTile` trailing slot is height-capped on desktop density and a dropdown plus a menu button there starves the title.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _epoch = DateTime.utc(2026);
final _l10n = lookupAppLocalizations(const Locale('en'));

final _roles = [
  DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    isBuiltIn: true,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.instructorId,
    name: 'Instructor',
    isBuiltIn: true,
    sortOrder: 2,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.diveMasterId,
    name: 'Dive Master',
    isBuiltIn: true,
    sortOrder: 4,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
];

final _matcher = BuddyNameMatcher([
  MatchCandidate(id: 'jim', name: 'Jim Dunfield', diverId: 'me', createdAt: _epoch),
  MatchCandidate(
    id: 'leo',
    name: 'Leo Cox',
    diverId: 'me',
    diveCount: 3,
    createdAt: _epoch,
  ),
], diverId: 'me');

ConversionPlan _plan() => planLegacyConversion(
  diveId: 'd1',
  buddyText: 'Jim Dunfield, Leo',
  diveMasterText: 'Ana',
  matcher: _matcher,
);

/// Opens the sheet from a button and returns the list its result lands in.
Future<List<ConversionPlan?>> _open(
  WidgetTester tester, [
  ConversionPlan? plan,
]) async {
  final results = <ConversionPlan?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [allDiveRolesProvider.overrideWith((ref) async => _roles)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showLegacyBuddyReviewSheet(
                  context,
                  plan: plan ?? _plan(),
                  matcher: _matcher,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _tapLink(WidgetTester tester, int count) async {
  await tester.tap(find.text(_l10n.buddies_linkText_linkCount(count)));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String identity, String item) async {
  await tester.tap(find.byKey(Key('legacy-row-menu-$identity')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each parsed name with its status and source', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text(_l10n.buddies_linkText_sheetTitle), findsOneWidget);
    expect(
      find.text(_l10n.buddies_linkText_sourceBuddy('Jim Dunfield, Leo')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.buddies_linkText_sourceDiveMaster('Ana')),
      findsOneWidget,
    );
    expect(find.text('Jim Dunfield'), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_statusExisting), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_statusNew), findsNWidgets(2));
    expect(
      find.text(_l10n.buddies_linkText_suggestion('Leo Cox')),
      findsOneWidget,
    );
  });

  testWidgets('Link returns the reviewed plan', (tester) async {
    final results = await _open(tester);

    await _tapLink(tester, 3);

    expect(results.single, _plan());
  });

  testWidgets('Cancel returns null', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.common_action_cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('Use applies the suggestion', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.buddies_linkText_useSuggestion));
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    final leo = results.single!.links[1];
    expect(leo.target, const ExistingBuddyTarget(buddyId: 'leo', name: 'Leo Cox'));
    expect(leo.suggestion, isNull);
  });

  testWidgets('Remove drops a row', (tester) async {
    final results = await _open(tester);

    await _menu(tester, 'new:ana', _l10n.common_action_remove);
    await _tapLink(tester, 2);

    expect(results.single!.links.map((l) => l.name), ['Jim Dunfield', 'Leo']);
  });

  testWidgets('Edit name re-matches the row', (tester) async {
    final results = await _open(tester);

    await _menu(tester, 'new:leo', _l10n.buddies_linkText_editName);
    await tester.enterText(find.byType(TextField), 'leo cox');
    await tester.tap(find.text(_l10n.common_action_save));
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    expect(
      results.single!.links[1].target,
      const ExistingBuddyTarget(buddyId: 'leo', name: 'Leo Cox'),
    );
  });

  testWidgets('Choose existing re-points a row and merges duplicates', (
    tester,
  ) async {
    final results = await _open(tester);

    await _menu(tester, 'new:ana', _l10n.buddies_linkText_chooseExisting);
    await tester.tap(
      find.descendant(
        of: find.byType(BuddyCandidatePickerSheet),
        matching: find.text('Jim Dunfield'),
      ),
    );
    await tester.pumpAndSettle();
    await _tapLink(tester, 2);

    final links = results.single!.links;
    expect(links.first.target, const ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'));
    expect(links.first.roleId, DiveRole.diveMasterId);
    expect(links.last.name, 'Leo');
  });

  testWidgets('the role dropdown changes a row role', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.byKey(const Key('legacy-row-role-id:jim')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.diveRole_builtin_instructor).last);
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    expect(results.single!.links.first.roleId, DiveRole.instructorId);
  });

  testWidgets('Add a name appends a new buddy row', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.buddies_linkText_addName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zoe');
    await tester.tap(find.text(_l10n.common_action_save));
    await tester.pumpAndSettle();
    await _tapLink(tester, 4);

    final zoe = results.single!.links.last;
    expect(zoe.target, const NewBuddyTarget('Zoe'));
    expect(zoe.roleId, DiveRole.buddyId);
  });

  testWidgets('warns when several buddies share the matched name', (
    tester,
  ) async {
    final namesakes = BuddyNameMatcher([
      MatchCandidate(id: 'a', name: 'Jack Evans', diverId: 'me', createdAt: _epoch),
      MatchCandidate(id: 'b', name: 'Jack Evans', diverId: 'me', createdAt: _epoch),
    ], diverId: 'me');
    await _open(
      tester,
      planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jack Evans',
        matcher: namesakes,
      ),
    );

    expect(
      find.text(_l10n.buddies_linkText_tie(2, 'Jack Evans')),
      findsOneWidget,
    );
  });

  testWidgets('Link is disabled once every row is removed', (tester) async {
    await _open(
      tester,
      planLegacyConversion(diveId: 'd1', buddyText: 'Ann', matcher: _matcher),
    );

    await _menu(tester, 'new:ann', _l10n.common_action_remove);

    final link = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _l10n.buddies_linkText_linkCount(0)),
    );
    expect(link.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/legacy_buddy_review_sheet_test.dart`
Expected: FAIL to compile, the widget files do not exist.

- [ ] **Step 3: Write the name dialog**

`lib/features/buddies/presentation/widgets/legacy_name_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a person's name; [initial] empty means adding a new one.
/// Returns null when cancelled.
Future<String?> showLegacyNameDialog(
  BuildContext context, {
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _LegacyNameDialog(initial: initial),
);

class _LegacyNameDialog extends StatefulWidget {
  const _LegacyNameDialog({required this.initial});

  final String initial;

  @override
  State<_LegacyNameDialog> createState() => _LegacyNameDialogState();
}

class _LegacyNameDialogState extends State<_LegacyNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.initial.isEmpty
            ? l10n.buddies_linkText_addName
            : l10n.buddies_linkText_editName,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.buddies_linkText_nameLabel),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Write the candidate picker**

`lib/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick one of [candidates]; null when dismissed.
Future<MatchCandidate?> showBuddyCandidatePicker(
  BuildContext context, {
  required List<MatchCandidate> candidates,
}) => showModalBottomSheet<MatchCandidate>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BuddyCandidatePickerSheet(candidates: candidates),
);

class BuddyCandidatePickerSheet extends StatefulWidget {
  const BuddyCandidatePickerSheet({super.key, required this.candidates});

  final List<MatchCandidate> candidates;

  @override
  State<BuddyCandidatePickerSheet> createState() =>
      _BuddyCandidatePickerSheetState();
}

class _BuddyCandidatePickerSheetState extends State<BuddyCandidatePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = legacyNameKey(_query);
    final sorted = [...widget.candidates]
      ..sort((a, b) => legacyNameKey(a.name).compareTo(legacyNameKey(b.name)));
    final shown = [
      for (final c in sorted)
        if (key.isEmpty || legacyNameKey(c.name).contains(key)) c,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.buddies_linkText_searchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.buddies_linkText_noBuddiesFound),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(shown[i].name),
                    subtitle: Text(
                      l10n.buddies_label_diveCount(shown[i].diveCount),
                    ),
                    onTap: () => Navigator.of(context).pop(shown[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the row**

`lib/features/buddies/presentation/widgets/legacy_buddy_review_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _RowAction { editName, chooseExisting, remove }

/// One name in the review sheet: its status, its role, and a menu.
class LegacyBuddyReviewRow extends StatelessWidget {
  const LegacyBuddyReviewRow({
    super.key,
    required this.link,
    required this.roles,
    required this.onRoleChanged,
    required this.onUseSuggestion,
    required this.onEditName,
    required this.onChooseExisting,
    required this.onRemove,
  });

  final PlannedLink link;
  final List<DiveRole> roles;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onUseSuggestion;
  final VoidCallback onEditName;
  final VoidCallback onChooseExisting;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isExisting = link.target is ExistingBuddyTarget;
    final suggestion = link.suggestion;
    final options = [
      ...roles,
      if (!roles.any((r) => r.id == link.roleId))
        DiveRole.synthetic(link.roleId),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              isExisting ? Icons.person : Icons.person_add_alt_1,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(link.name, style: theme.textTheme.bodyLarge),
                Text(
                  isExisting
                      ? l10n.buddies_linkText_statusExisting
                      : l10n.buddies_linkText_statusNew,
                  style: muted,
                ),
                if (isExisting && link.tieCount > 1)
                  Text(
                    l10n.buddies_linkText_tie(link.tieCount, link.name),
                    style: muted,
                  ),
                if (!isExisting && suggestion != null)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.buddies_linkText_suggestion(suggestion.name),
                          style: muted,
                        ),
                      ),
                      TextButton(
                        onPressed: onUseSuggestion,
                        child: Text(l10n.buddies_linkText_useSuggestion),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            key: Key('legacy-row-role-${link.identity}'),
            value: link.roleId,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final role in options)
                DropdownMenuItem(
                  value: role.id,
                  child: Text(role.localizedName(l10n)),
                ),
            ],
            onChanged: (roleId) {
              if (roleId != null) onRoleChanged(roleId);
            },
          ),
          PopupMenuButton<_RowAction>(
            key: Key('legacy-row-menu-${link.identity}'),
            onSelected: (action) {
              switch (action) {
                case _RowAction.editName:
                  onEditName();
                case _RowAction.chooseExisting:
                  onChooseExisting();
                case _RowAction.remove:
                  onRemove();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _RowAction.editName,
                child: Text(l10n.buddies_linkText_editName),
              ),
              PopupMenuItem(
                value: _RowAction.chooseExisting,
                child: Text(l10n.buddies_linkText_chooseExisting),
              ),
              PopupMenuItem(
                value: _RowAction.remove,
                child: Text(l10n.common_action_remove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Write the sheet**

`lib/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_row.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_name_dialog.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reviews [plan] before anything is written (#1831). Returns the edited
/// plan on Link, or null when cancelled.
Future<ConversionPlan?> showLegacyBuddyReviewSheet(
  BuildContext context, {
  required ConversionPlan plan,
  required BuddyNameMatcher matcher,
}) => showModalBottomSheet<ConversionPlan>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => LegacyBuddyReviewSheet(plan: plan, matcher: matcher),
);

class LegacyBuddyReviewSheet extends ConsumerStatefulWidget {
  const LegacyBuddyReviewSheet({
    super.key,
    required this.plan,
    required this.matcher,
  });

  final ConversionPlan plan;
  final BuddyNameMatcher matcher;

  @override
  ConsumerState<LegacyBuddyReviewSheet> createState() =>
      _LegacyBuddyReviewSheetState();
}

class _LegacyBuddyReviewSheetState
    extends ConsumerState<LegacyBuddyReviewSheet> {
  late List<PlannedLink> _links = widget.plan.links;

  void _update(List<PlannedLink> links) =>
      setState(() => _links = collapseLinks(links));

  List<PlannedLink> _replaced(int index, PlannedLink link) => [
    for (var i = 0; i < _links.length; i++) i == index ? link : _links[i],
  ];

  PlannedLink _existing(MatchCandidate buddy, String roleId) => PlannedLink(
    target: ExistingBuddyTarget(buddyId: buddy.id, name: buddy.name),
    roleId: roleId,
  );

  Future<void> _editName(int index) async {
    final name = await showLegacyNameDialog(
      context,
      initial: _links[index].name,
    );
    if (name == null || legacyNameKey(name).isEmpty) return;
    _update(
      _replaced(index, planLink(name, _links[index].roleId, widget.matcher)),
    );
  }

  Future<void> _addName() async {
    final name = await showLegacyNameDialog(context);
    if (name == null || legacyNameKey(name).isEmpty) return;
    _update([..._links, planLink(name, DiveRole.buddyId, widget.matcher)]);
  }

  Future<void> _chooseExisting(int index) async {
    final picked = await showBuddyCandidatePicker(
      context,
      candidates: widget.matcher.candidates,
    );
    if (picked == null) return;
    _update(_replaced(index, _existing(picked, _links[index].roleId)));
  }

  void _useSuggestion(int index) {
    final suggestion = _links[index].suggestion;
    if (suggestion == null) return;
    _update(_replaced(index, _existing(suggestion, _links[index].roleId)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final roles = ref.watch(allDiveRolesProvider).value ?? const <DiveRole>[];
    final buddyText = widget.plan.buddyText?.trim() ?? '';
    final diveMasterText = widget.plan.diveMasterText?.trim() ?? '';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.buddies_linkText_sheetTitle,
              style: theme.textTheme.titleLarge,
            ),
            if (buddyText.isNotEmpty)
              Text(l10n.buddies_linkText_sourceBuddy(buddyText), style: muted),
            if (diveMasterText.isNotEmpty)
              Text(
                l10n.buddies_linkText_sourceDiveMaster(diveMasterText),
                style: muted,
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _links.length,
                itemBuilder: (context, i) => LegacyBuddyReviewRow(
                  key: ValueKey(_links[i].identity),
                  link: _links[i],
                  roles: roles,
                  onRoleChanged: (roleId) =>
                      _update(_replaced(i, _links[i].copyWith(roleId: roleId))),
                  onUseSuggestion: () => _useSuggestion(i),
                  onEditName: () => _editName(i),
                  onChooseExisting: () => _chooseExisting(i),
                  onRemove: () => _update([
                    for (var j = 0; j < _links.length; j++)
                      if (j != i) _links[j],
                  ]),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _addName,
                icon: const Icon(Icons.add),
                label: Text(l10n.buddies_linkText_addName),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _links.isEmpty
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(widget.plan.copyWith(links: _links)),
                  child: Text(l10n.buddies_linkText_linkCount(_links.length)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/buddies/presentation/widgets/legacy_buddy_review_sheet_test.dart`
Expected: PASS, 11 tests. If a tap lands on an off-screen row in the default 800x600 surface, add `tester.view.physicalSize = const Size(1200, 1600); addTearDown(tester.view.reset);` at the start of `_open` rather than changing the widgets.

- [ ] **Step 8: Commit**

```bash
git add lib/features/buddies/presentation/widgets/legacy_name_dialog.dart lib/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart lib/features/buddies/presentation/widgets/legacy_buddy_review_row.dart lib/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart test/features/buddies/presentation/widgets/legacy_buddy_review_sheet_test.dart
git commit -m "feat(buddies): review sheet for linking legacy buddy text (#1831)"
```

---

### Task 10: Buddies card action

**Files:**
- Create: `test/features/buddies/helpers/fake_legacy_buddy_conversion_service.dart`
- Create: `lib/features/buddies/presentation/legacy_buddy_conversion_actions.dart`
- Create: `lib/features/buddies/presentation/widgets/legacy_buddy_text_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildBuddiesSection` near line 4603; `_buildTextBuddyTile` near line 4683)
- Test: `test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart` (from #1837)

**Interfaces:**
- Consumes: service and providers (Task 7), sheet (Task 9), `LegacyNameParser` (Task 1), l10n (Task 8), `validatedCurrentDiverIdProvider` (`package:submersion/features/divers/presentation/providers/diver_providers.dart`).
- Produces:
  - `Future<void> linkLegacyBuddiesForDive(BuildContext context, Dive dive)`
  - `Future<ConversionReceipt?> applyLegacyBuddyPlans({required ProviderContainer container, required ScaffoldMessengerState messenger, required AppLocalizations l10n, required List<ConversionPlan> plans, required String diverId, required String Function(ConversionReceipt receipt) successMessage})`
  - `LegacyBuddyTextSection({required Dive dive})` with `static bool hasContent(Dive dive)`
  - Test helper `FakeLegacyBuddyConversionService` (records `applied` and `undone`; `defaultReceipt`).

- [ ] **Step 1: Write the fake service**

`test/features/buddies/helpers/fake_legacy_buddy_conversion_service.dart`:

```dart
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Plans a fixed [plan] and records what the UI applies and undoes.
class FakeLegacyBuddyConversionService implements LegacyBuddyConversionService {
  FakeLegacyBuddyConversionService({
    ConversionPlan? plan,
    BuddyNameMatcher? matcher,
    this.receipt = defaultReceipt,
  }) : plan = plan ?? const ConversionPlan(diveId: 'd1'),
       matcher = matcher ?? BuddyNameMatcher(const [], diverId: 'me');

  static const defaultReceipt = ConversionReceipt(
    diverId: 'me',
    diveIds: ['d1'],
    linkIds: ['l1'],
    createdBuddyIds: ['b1'],
  );

  final ConversionPlan plan;
  final BuddyNameMatcher matcher;
  final ConversionReceipt receipt;
  final List<List<ConversionPlan>> applied = [];
  final List<ConversionReceipt> undone = [];

  @override
  Future<BuddyNameMatcher> matcherFor(String diverId) async => matcher;

  @override
  Future<(ConversionPlan, BuddyNameMatcher)> planFor(
    Dive dive,
    String diverId,
  ) async => (plan, matcher);

  @override
  Future<LinkBuddyNamesData> planCandidates(String diverId) async =>
      LinkBuddyNamesData(diverId: diverId, matcher: matcher, dives: const []);

  @override
  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) async {
    applied.add(plans);
    return receipt;
  }

  @override
  Future<void> undo(ConversionReceipt receipt) async => undone.add(receipt);
}
```

- [ ] **Step 2: Write the failing card tests**

In `dive_detail_text_buddy_test.dart`:

Add imports (keep the file's existing ones):

```dart
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';

import '../../../buddies/helpers/fake_legacy_buddy_conversion_service.dart';
```

Add below `_soloDive`:

```dart
final _l10n = lookupAppLocalizations(const Locale('en'));
```

Replace the `_pump` function with this version (new `textDiveMaster` and `service` parameters, a diver on the dive, and the service override):

```dart
Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs, {
  String? textBuddy,
  String? textDiveMaster,
  String? diverRoleId,
  List<BuddyWithRole> linked = const [],
  FakeLegacyBuddyConversionService? service,
}) async {
  final dive = Dive(
    id: 'd1',
    diverId: 'me',
    dateTime: DateTime(2026, 3, 15, 10, 0),
    buddy: textBuddy,
    diveMaster: textDiveMaster,
    diverRoleId: diverRoleId,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(_buddiesOnly()),
        ),
        buddiesForDiveProvider(dive.id).overrideWith((ref) async => linked),
        diveSightingsProvider(
          dive.id,
        ).overrideWith((ref) async => <Sighting>[]),
        buddySignaturesForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => <Signature>[]),
        allDiveRolesProvider.overrideWith((ref) async => <DiveRole>[]),
        legacyBuddyConversionServiceProvider.overrideWithValue(
          service ?? FakeLegacyBuddyConversionService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Append inside the existing `group('Buddies card with a free-text buddy (#1831)', ...)`, after the last test:

```dart
    testWidgets('a placeholder-only text buddy reads "Solo dive"', (
      tester,
    ) async {
      await _pump(tester, prefs, textBuddy: 'None');

      expect(find.text(_soloDive), findsOneWidget);
      expect(find.text('None'), findsNothing);
      expect(find.text(_l10n.buddies_linkText_action), findsNothing);
    });

    testWidgets('dive-master text shows with the Dive master role', (
      tester,
    ) async {
      await _pump(tester, prefs, textDiveMaster: 'Ana Ruiz');

      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.text(_l10n.diveRole_builtin_diveMaster), findsOneWidget);
      expect(find.text(_soloDive), findsNothing);
    });

    testWidgets('text buddies offer the link action; linked ones do not', (
      tester,
    ) async {
      await _pump(tester, prefs, textBuddy: 'Bob Brown');
      expect(find.text(_l10n.buddies_linkText_action), findsOneWidget);

      await _pump(
        tester,
        prefs,
        textBuddy: 'Bob Brown',
        linked: [_linkedBuddy()],
      );
      expect(find.text(_l10n.buddies_linkText_action), findsNothing);
    });

    testWidgets('linking applies the reviewed plan and offers Undo', (
      tester,
    ) async {
      final matcher = BuddyNameMatcher(const [], diverId: 'me');
      final service = FakeLegacyBuddyConversionService(
        plan: planLegacyConversion(
          diveId: 'd1',
          buddyText: 'Bob Brown',
          matcher: matcher,
        ),
        matcher: matcher,
      );
      await _pump(tester, prefs, textBuddy: 'Bob Brown', service: service);

      await tester.tap(find.text(_l10n.buddies_linkText_action));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.buddies_linkText_linkCount(1)));
      await tester.pumpAndSettle();

      expect(service.applied.single.single.diveId, 'd1');
      expect(
        find.text(_l10n.buddies_linkText_linkedSnackbar(1)),
        findsOneWidget,
      );

      await tester.tap(find.text(_l10n.diveLog_bulkDelete_undo));
      await tester.pumpAndSettle();

      expect(service.undone, [FakeLegacyBuddyConversionService.defaultReceipt]);
      // Let the snackbars' timers finish before the tree is torn down.
      await tester.pump(const Duration(seconds: 6));
    });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart`
Expected: the file compiles (the providers exist since Task 7 and the fake since Step 1); the 6 tests from #1837 PASS and the 4 new tests FAIL: `None` still renders as a tile, there is no dive-master tile, and there is no link action.

- [ ] **Step 4: Write the actions**

`lib/features/buddies/presentation/legacy_buddy_conversion_actions.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reviews and links [dive]'s legacy buddy and dive-master text (#1831).
Future<void> linkLegacyBuddiesForDive(BuildContext context, Dive dive) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final diverId =
      dive.diverId ??
      await container.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null || !context.mounted) return;
  final (ConversionPlan, BuddyNameMatcher) planned;
  try {
    planned = await container
        .read(legacyBuddyConversionServiceProvider)
        .planFor(dive, diverId);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
    );
    return;
  }
  if (!context.mounted) return;
  final (plan, matcher) = planned;
  final reviewed = await showLegacyBuddyReviewSheet(
    context,
    plan: plan,
    matcher: matcher,
  );
  if (reviewed == null || reviewed.isEmpty) return;
  await applyLegacyBuddyPlans(
    container: container,
    messenger: messenger,
    l10n: l10n,
    plans: [reviewed],
    diverId: diverId,
    successMessage: (receipt) =>
        l10n.buddies_linkText_linkedSnackbar(receipt.linkIds.length),
  );
}

/// Applies [plans], refreshes what they change, and offers Undo. Returns the
/// receipt, or null when applying failed (after showing an error).
///
/// Works through [container] rather than a `WidgetRef` so Undo still works
/// after the page that ran the conversion is gone.
Future<ConversionReceipt?> applyLegacyBuddyPlans({
  required ProviderContainer container,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required List<ConversionPlan> plans,
  required String diverId,
  required String Function(ConversionReceipt receipt) successMessage,
}) async {
  final service = container.read(legacyBuddyConversionServiceProvider);
  final ConversionReceipt receipt;
  try {
    receipt = await service.apply(
      plans,
      diverId: diverId,
      newBuddyNote: l10n.buddies_linkText_newBuddyNote,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
    );
    return null;
  }
  refreshAfterLegacyBuddyConversion(container);
  if (receipt.isEmpty) return receipt;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(successMessage(receipt)),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss and
        // allow closing without triggering Undo.
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.diveLog_bulkDelete_undo,
          onPressed: () async {
            try {
              await service.undo(receipt);
              refreshAfterLegacyBuddyConversion(container);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.buddies_linkText_undone),
                  duration: const Duration(seconds: 2),
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
              );
            }
          },
        ),
      ),
    );
  return receipt;
}
```

- [ ] **Step 5: Write the card section**

`lib/features/buddies/presentation/widgets/legacy_buddy_text_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/buddies/presentation/legacy_buddy_conversion_actions.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Buddies card's legacy text (#1831): plain tiles for a dive's
/// `buddy` and `dive_master` text and the action that links them to buddy
/// records. Shown only while the dive has no linked buddies.
class LegacyBuddyTextSection extends StatelessWidget {
  const LegacyBuddyTextSection({super.key, required this.dive});

  final Dive dive;

  /// Whether [dive] has legacy text that parses to at least one name. A
  /// text holding only a placeholder such as `None` does not count.
  static bool hasContent(Dive dive) =>
      LegacyNameParser.parse(dive.buddy).isNotEmpty ||
      LegacyNameParser.parse(dive.diveMaster).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final showBuddy = LegacyNameParser.parse(dive.buddy).isNotEmpty;
    final showDiveMaster = LegacyNameParser.parse(dive.diveMaster).isNotEmpty;
    if (!showBuddy && !showDiveMaster) return const SizedBox.shrink();

    // There is no record behind the text yet, so the tile opens nothing.
    Widget tile(String text, {String? subtitle}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.person_outline, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(text),
      subtitle: subtitle == null ? null : Text(subtitle),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBuddy) tile(dive.buddy!.trim()),
        if (showDiveMaster)
          tile(
            dive.diveMaster!.trim(),
            subtitle: l10n.diveRole_builtin_diveMaster,
          ),
        TextButton.icon(
          onPressed: () => linkLegacyBuddiesForDive(context, dive),
          icon: const Icon(Icons.link),
          label: Text(l10n.buddies_linkText_action),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Wire the section into the Buddies card**

In `dive_detail_page.dart`, add the import beside the other buddies imports (near line 42):

```dart
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_text_section.dart';
```

In `_buildBuddiesSection`, replace #1837's comment and `textBuddy` local:

```dart
        // The dive_buddies junction is authoritative once it holds anyone.
        // The legacy free-text dives.buddy column is only a fallback for a
        // dive whose buddy was never linked, such as a CSV import that did
        // not bring in buddy records, so it is not called solo (#1831).
        final textBuddy = buddies.isEmpty ? dive.buddy?.trim() ?? '' : '';
```

with:

```dart
        // The dive_buddies junction is authoritative once it holds anyone.
        // The legacy free-text dives.buddy and dives.dive_master columns are
        // only a fallback for a dive whose people were never linked, such as
        // a CSV import, so such a dive is not called solo, and the section
        // offers to link the text to buddy records (#1831). A text holding
        // only a placeholder like "None" does not count.
        final showLegacyText =
            buddies.isEmpty && LegacyBuddyTextSection.hasContent(dive);
```

Replace:

```dart
                if (textBuddy.isNotEmpty)
                  _buildTextBuddyTile(context, textBuddy)
                else if (buddies.isEmpty && dive.diverRoleId == null)
```

with:

```dart
                if (showLegacyText)
                  LegacyBuddyTextSection(dive: dive)
                else if (buddies.isEmpty && dive.diverRoleId == null)
```

Delete the whole `_buildTextBuddyTile` method together with its two-line doc comment (`/// A buddy stored only as free text on the dive (#1831). ...`). The section now owns that tile.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart`
Expected: PASS, 10 tests (6 from #1837, 4 new).

- [ ] **Step 8: Commit**

```bash
git add test/features/buddies/helpers/fake_legacy_buddy_conversion_service.dart lib/features/buddies/presentation/legacy_buddy_conversion_actions.dart lib/features/buddies/presentation/widgets/legacy_buddy_text_section.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart
git commit -m "feat(dive-log): link a dive's legacy buddy text from the Buddies card (#1831)"
```

---

### Task 11: Link buddy names page

**Files:**
- Create: `lib/features/settings/presentation/widgets/link_buddy_names_dive_row.dart`
- Create: `lib/features/settings/presentation/pages/link_buddy_names_page.dart`
- Modify: `lib/core/router/app_router.dart` (import near line 100; route after `fix-dive-times`, near line 1240)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Data Tools card, near line 2918)
- Test: `test/features/settings/presentation/pages/link_buddy_names_page_test.dart`

**Interfaces:**
- Consumes: `linkBuddyNamesDataProvider`, `legacyBuddyConversionServiceProvider` (Task 7), `LinkBuddyNamesData` (Task 7), `summarizeCandidates` (Task 3), `showLegacyBuddyReviewSheet` (Task 9), `applyLegacyBuddyPlans` (Task 10), `UnitFormatter` (`package:submersion/core/utils/unit_formatter.dart`, `formatDateTime(DateTime?, {AppLocalizations? l10n})`), `settingsProvider` (`package:submersion/features/settings/presentation/providers/settings_providers.dart`), `diveRoleMapProvider`.
- Produces: `LinkBuddyNamesPage`, `LinkBuddyNamesDiveRow({required CandidateDive dive, required bool selected, required ValueChanged<bool> onSelectedChanged, required VoidCallback onTap})`, route `/settings/link-buddy-names` named `linkBuddyNames`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/pages/link_buddy_names_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../buddies/helpers/fake_legacy_buddy_conversion_service.dart';

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _epoch = DateTime.utc(2026);
final _l10n = lookupAppLocalizations(const Locale('en'));

final _roles = [
  DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    isBuiltIn: true,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.diveMasterId,
    name: 'Dive Master',
    isBuiltIn: true,
    sortOrder: 4,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
];

final _matcher = BuddyNameMatcher([
  MatchCandidate(id: 'jim', name: 'Jim Dunfield', diverId: 'me', createdAt: _epoch),
], diverId: 'me');

LinkBuddyNamesData _data() => LinkBuddyNamesData(
  diverId: 'me',
  matcher: _matcher,
  dives: [
    CandidateDive(
      plan: planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jim Dunfield, Ann',
        matcher: _matcher,
      ),
      diveNumber: 12,
      dateTime: DateTime.utc(2026, 3, 15, 10),
      siteName: 'Blue Hole',
    ),
    CandidateDive(
      plan: planLegacyConversion(
        diveId: 'd2',
        buddyText: 'Ann',
        diveMasterText: 'Ana',
        matcher: _matcher,
      ),
      diveNumber: 13,
      dateTime: DateTime.utc(2026, 3, 16, 10),
    ),
  ],
);

String _summary(int dives, int newBuddies, int existing) => [
  _l10n.buddies_linkText_page_summaryDives(dives),
  _l10n.buddies_linkText_page_summaryNew(newBuddies),
  _l10n.buddies_linkText_page_summaryExisting(existing),
].join(' · ');

Future<void> _pump(
  WidgetTester tester,
  FakeLegacyBuddyConversionService service,
  LinkBuddyNamesData? data,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        linkBuddyNamesDataProvider.overrideWith((ref) async => data),
        legacyBuddyConversionServiceProvider.overrideWithValue(service),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(AppSettings()),
        ),
        allDiveRolesProvider.overrideWith((ref) async => _roles),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LinkBuddyNamesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each dive with its parsed names and a summary', (
    tester,
  ) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    expect(find.text(_summary(2, 2, 1)), findsOneWidget);
    expect(find.textContaining('#12 · Blue Hole · '), findsOneWidget);
    expect(find.textContaining('#13 · '), findsOneWidget);
    expect(find.text('Jim Dunfield'), findsOneWidget);
    expect(find.text('Ann'), findsNWidgets(2));
    expect(
      find.text(
        _l10n.buddies_linkText_chipWithRole(
          'Ana',
          _l10n.diveRole_builtin_diveMaster,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(_l10n.buddies_linkText_page_linkDives(2)), findsOneWidget);
  });

  testWidgets('unchecking a dive updates the summary and the button', (
    tester,
  ) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    expect(find.text(_summary(1, 1, 1)), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_page_linkDives(1)), findsOneWidget);
  });

  testWidgets('Link applies the checked dives and offers Undo', (
    tester,
  ) async {
    final service = FakeLegacyBuddyConversionService();
    await _pump(tester, service, _data());

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text(_l10n.buddies_linkText_page_linkDives(1)));
    await tester.pumpAndSettle();

    expect(service.applied.single.map((p) => p.diveId), ['d1']);
    expect(
      find.text(_l10n.buddies_linkText_page_linkedSnackbar(1)),
      findsOneWidget,
    );

    await tester.tap(find.text(_l10n.diveLog_bulkDelete_undo));
    await tester.pumpAndSettle();

    expect(service.undone, hasLength(1));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('tapping a dive opens its review sheet', (tester) async {
    await _pump(tester, FakeLegacyBuddyConversionService(), _data());

    await tester.tap(find.textContaining('#13 · '));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.buddies_linkText_sheetTitle), findsOneWidget);
  });

  testWidgets('shows the empty state when every name is linked', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLegacyBuddyConversionService(),
      LinkBuddyNamesData(diverId: 'me', matcher: _matcher, dives: const []),
    );

    expect(find.text(_l10n.buddies_linkText_page_empty), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/link_buddy_names_page_test.dart`
Expected: FAIL to compile, `link_buddy_names_page.dart` does not exist.

- [ ] **Step 3: Write the dive row**

`lib/features/settings/presentation/widgets/link_buddy_names_dive_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One dive on the Link buddy names page: what identifies it, the names it
/// would link (marked existing or new), and whether it is included.
class LinkBuddyNamesDiveRow extends ConsumerWidget {
  const LinkBuddyNamesDiveRow({
    super.key,
    required this.dive,
    required this.selected,
    required this.onSelectedChanged,
    required this.onTap,
  });

  final CandidateDive dive;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final roles =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final site = dive.siteName?.trim() ?? '';
    final title = [
      if (dive.diveNumber != null)
        l10n.buddies_linkText_page_diveNumber(dive.diveNumber!),
      if (site.isNotEmpty) site,
      units.formatDateTime(dive.dateTime, l10n: l10n),
    ].join(' · ');
    return ListTile(
      leading: Checkbox(
        value: selected,
        onChanged: (value) => onSelectedChanged(value ?? false),
      ),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final link in dive.plan.links)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  link.target is ExistingBuddyTarget
                      ? Icons.person
                      : Icons.person_add_alt_1,
                  size: 16,
                ),
                label: Text(
                  link.roleId == DiveRole.buddyId
                      ? link.name
                      : l10n.buddies_linkText_chipWithRole(
                          link.name,
                          (roles[link.roleId] ??
                                  DiveRole.synthetic(link.roleId))
                              .localizedName(l10n),
                        ),
                ),
              ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Write the page**

`lib/features/settings/presentation/pages/link_buddy_names_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/legacy_buddy_conversion_actions.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/link_buddy_names_dive_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data Tools > Link buddy names (#1831): links the legacy buddy
/// and dive-master text of every dive that has no linked buddies, after a
/// preview, with Undo.
class LinkBuddyNamesPage extends ConsumerStatefulWidget {
  const LinkBuddyNamesPage({super.key});

  @override
  ConsumerState<LinkBuddyNamesPage> createState() =>
      _LinkBuddyNamesPageState();
}

class _LinkBuddyNamesPageState extends ConsumerState<LinkBuddyNamesPage> {
  /// Dive ids the diver unchecked.
  Set<String> _excluded = const {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dataAsync = ref.watch(linkBuddyNamesDataProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddies_linkText_page_title)),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _message(l10n.buddies_linkText_page_errorLoading('$error')),
        data: (data) => data == null || data.dives.isEmpty
            ? _message(l10n.buddies_linkText_page_empty)
            : _content(data),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _content(LinkBuddyNamesData data) {
    final l10n = context.l10n;
    final selected = [
      for (final dive in data.dives)
        if (!_excluded.contains(dive.diveId)) dive,
    ];
    final summary = summarizeCandidates(selected);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              [
                l10n.buddies_linkText_page_summaryDives(summary.dives),
                l10n.buddies_linkText_page_summaryNew(summary.newBuddies),
                l10n.buddies_linkText_page_summaryExisting(
                  summary.existingBuddies,
                ),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: data.dives.length,
            itemBuilder: (context, i) {
              final dive = data.dives[i];
              return LinkBuddyNamesDiveRow(
                dive: dive,
                selected: !_excluded.contains(dive.diveId),
                onSelectedChanged: (value) => setState(
                  () => _excluded = value
                      ? {
                          for (final id in _excluded)
                            if (id != dive.diveId) id,
                        }
                      : {..._excluded, dive.diveId},
                ),
                onTap: () => _reviewOne(data, dive),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _linkSelected(data, selected),
                child: Text(
                  l10n.buddies_linkText_page_linkDives(selected.length),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reviews one dive in the per-dive sheet and links just that dive.
  Future<void> _reviewOne(LinkBuddyNamesData data, CandidateDive dive) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final reviewed = await showLegacyBuddyReviewSheet(
      context,
      plan: dive.plan,
      matcher: data.matcher,
    );
    if (reviewed == null || reviewed.isEmpty) return;
    await applyLegacyBuddyPlans(
      container: container,
      messenger: messenger,
      l10n: l10n,
      plans: [reviewed],
      diverId: data.diverId,
      successMessage: (receipt) =>
          l10n.buddies_linkText_linkedSnackbar(receipt.linkIds.length),
    );
  }

  Future<void> _linkSelected(
    LinkBuddyNamesData data,
    List<CandidateDive> selected,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    await applyLegacyBuddyPlans(
      container: container,
      messenger: messenger,
      l10n: l10n,
      plans: [for (final dive in selected) dive.plan],
      diverId: data.diverId,
      successMessage: (receipt) =>
          l10n.buddies_linkText_page_linkedSnackbar(receipt.diveIds.length),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _excluded = const {};
    });
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/pages/link_buddy_names_page_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Add the route and the Data Tools tile**

In `app_router.dart`, add beside the `fix_dive_times_page.dart` import:

```dart
import 'package:submersion/features/settings/presentation/pages/link_buddy_names_page.dart';
```

and directly after the `fix-dive-times` `GoRoute`:

```dart
              GoRoute(
                path: 'link-buddy-names',
                name: 'linkBuddyNames',
                builder: (context, state) => const LinkBuddyNamesPage(),
              ),
```

In `settings_page.dart`, inside the Data Tools `Card`, insert between the Fix dive times `ListTile` and the existing `const Divider(height: 1)` that precedes Data quality:

```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: Text(context.l10n.buddies_linkText_page_title),
                  subtitle: Text(context.l10n.buddies_linkText_page_subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/link-buddy-names'),
                ),
```

- [ ] **Step 7: Analyze the touched files**

Run: `flutter analyze lib/core/router/app_router.dart lib/features/settings lib/features/buddies`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/presentation/widgets/link_buddy_names_dive_row.dart lib/features/settings/presentation/pages/link_buddy_names_page.dart lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart test/features/settings/presentation/pages/link_buddy_names_page_test.dart
git commit -m "feat(settings): link buddy names across imported dives (#1831)"
```

---

### Task 12: Verification

**Files:** none new; formatting fixes only.

- [ ] **Step 1: Format the whole project**

```bash
dart format .
git status --short
```

Expected: only files this plan touched are listed. If formatting changed any, stage those paths explicitly and commit `style: dart format`.

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze
```

Expected: `No issues found!` (CI treats infos as fatal, so fix every info too). Do not pipe this command.

- [ ] **Step 3: Check generated localizations are current**

```bash
flutter gen-l10n
git diff --exit-code -- lib/l10n
```

Expected: exit 0, no diff.

- [ ] **Step 4: Scan the branch for forbidden text**

```bash
git diff 40e41ad4129...HEAD | grep -c $'\u2014'
git diff 40e41ad4129...HEAD | grep -ci -e 'co-authored-by' -e 'generated with' -e 'session_'
git log 40e41ad4129..HEAD --format=%B | grep -ci -e 'co-authored-by' -e 'generated with' -e 'session_'
```

Expected: `0` for each (grep exits 1 on zero matches; that is the passing case).

- [ ] **Step 5: Run the full suite once**

```bash
flutter test
```

Expected: all tests pass. Run it once, not piped, and read the exit status. On a failure in a file this plan never touched, check whether the same test fails on `40e41ad4129` before changing anything.

- [ ] **Step 6: Stop and report**

Do not push and do not open a PR. Report to the maintainer: the commit list, the test totals, and the analyze result. Pushing, the PR (base `main`, body with `Refs #1831` and "Depends on #1837"), and the post-merge `git rebase --onto origin/main 40e41ad4129` all wait for the maintainer's go-ahead.
