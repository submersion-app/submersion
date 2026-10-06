# Certification Level Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the certification "Level" dropdown to "Certification", group its options into Progression / Specialties, make the Name field optional, and stop every surface from rendering the agency+level string twice.

**Architecture:** No schema change and no data migration. A new pure-Dart helper (`certification_title.dart`) decides whether a stored `Certification.name` carries information beyond agency + level; every display surface routes through it, so certs already stored as `"PADI : Open Water"` stop duplicating without a single row being rewritten. The edit form loses its auto-name generator entirely.

**Tech Stack:** Flutter 3.x / Material 3, Drift, Riverpod, `flutter_localizations` + ARB, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-09-certification-level-dropdown-design.md`

## Global Constraints

- No change to `Certifications` table columns, `schemaVersion`, or the Drift migration ladder. `name` stays non-nullable `text()`; "no name" is the empty string, never NULL.
- No renaming of the `CertificationLevel` Dart type, the `level` column, or any enum value name — they are persisted as enum-name text and round-trip through UDDF import/export and the sync field maps.
- No bulk data rewrite. Stored names change only when a user saves that specific cert.
- Every new l10n key is added to all **11** locales in the same commit: `ar de en es fr he hu it nl pt zh`. No English placeholders in non-English ARB files.
- ARB keys are stored in **alphabetical order** within each file. Insert new keys at their sorted position.
- All Dart must pass `dart format .` with no changes, and `flutter analyze` with zero issues (infos are fatal in CI).
- Run all commands from the worktree root: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/cert-level-dropdown`.

## File Structure

**Create**
- `lib/features/certifications/domain/certification_title.dart` — the sole authority on what title/subtitle a certification displays and whether its stored name is redundant.
- `test/features/certifications/domain/certification_title_test.dart`

**Modify**
- `lib/core/constants/certification_levels.dart` — add `specialtiesFor`; express `levelsFor` in terms of it.
- `lib/core/constants/enums.dart` — doc comment on `CertificationLevel` only.
- `lib/features/certifications/presentation/pages/certification_edit_page.dart` — the main change.
- `lib/features/certifications/presentation/pages/certification_detail_page.dart` — collapse the duplicated rows.
- `lib/features/certifications/domain/constants/certification_field.dart` — column label.
- Seven display surfaces + two PDF templates (Task 6).
- `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`

**Rename**
- `test/.../certification_name_auto_generation_test.dart` → `certification_edit_name_field_test.dart` (the file is named after behaviour this plan deletes).

---

### Task 1: Certification title helper

**Files:**
- Create: `lib/features/certifications/domain/certification_title.dart`
- Test: `test/features/certifications/domain/certification_title_test.dart`

**Interfaces:**
- Consumes: `Certification` (`lib/features/certifications/domain/entities/certification.dart`), `CertificationAgency` / `CertificationLevel` (`lib/core/constants/enums.dart`).
- Produces — every later task depends on exactly these five top-level functions:
  - `String derivedCertificationTitle(CertificationAgency agency, CertificationLevel? level)`
  - `bool hasDerivedName(Certification cert)`
  - `String? customNameOrNull(Certification cert)`
  - `String certificationTitle(Certification cert)`
  - `String? certificationSubtitle(Certification cert)`

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/domain/certification_title_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

Certification cert({
  required String name,
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level = CertificationLevel.openWater,
}) {
  final now = DateTime(2026);
  return Certification(
    id: 'c1',
    name: name,
    agency: agency,
    level: level,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('derivedCertificationTitle', () {
    test('joins agency and level with a single space', () {
      expect(
        derivedCertificationTitle(
          CertificationAgency.padi,
          CertificationLevel.openWater,
        ),
        'PADI Open Water',
      );
    });

    test('returns the agency alone when level is null', () {
      expect(
        derivedCertificationTitle(CertificationAgency.ssi, null),
        'SSI',
      );
    });
  });

  group('hasDerivedName', () {
    test('recognises the legacy spaced-colon format', () {
      expect(hasDerivedName(cert(name: 'PADI : Open Water')), isTrue);
    });

    test('recognises the tight-colon format', () {
      expect(hasDerivedName(cert(name: 'PADI: Open Water')), isTrue);
    });

    test('recognises the new space-joined format', () {
      expect(hasDerivedName(cert(name: 'PADI Open Water')), isTrue);
    });

    test('recognises the bare level name', () {
      expect(hasDerivedName(cert(name: 'Open Water')), isTrue);
    });

    test('recognises the bare agency name', () {
      expect(hasDerivedName(cert(name: 'PADI')), isTrue);
    });

    test('ignores case and collapses whitespace', () {
      expect(hasDerivedName(cert(name: '  padi   :   OPEN WATER ')), isTrue);
    });

    test('treats an empty name as derived', () {
      expect(hasDerivedName(cert(name: '')), isTrue);
      expect(hasDerivedName(cert(name: '   ')), isTrue);
    });

    test('keeps a genuinely custom name', () {
      expect(hasDerivedName(cert(name: 'Bali OW w/ Made')), isFalse);
    });

    test('does not match another agency derivation', () {
      expect(hasDerivedName(cert(name: 'SSI Open Water')), isFalse);
    });

    test('with a null level, only the agency name is derived', () {
      expect(hasDerivedName(cert(name: 'PADI', level: null)), isTrue);
      expect(hasDerivedName(cert(name: 'Open Water', level: null)), isFalse);
    });
  });

  group('customNameOrNull', () {
    test('is null for a derived name', () {
      expect(customNameOrNull(cert(name: 'PADI : Open Water')), isNull);
    });

    test('is the trimmed custom name otherwise', () {
      expect(customNameOrNull(cert(name: '  Bali OW  ')), 'Bali OW');
    });
  });

  group('certificationTitle', () {
    test('derives when the stored name adds nothing', () {
      expect(certificationTitle(cert(name: 'PADI : Open Water')),
          'PADI Open Water');
    });

    test('prefers a custom name', () {
      expect(certificationTitle(cert(name: 'Bali OW w/ Made')),
          'Bali OW w/ Made');
    });

    test('is never empty', () {
      expect(certificationTitle(cert(name: '', level: null)), isNotEmpty);
    });
  });

  group('certificationSubtitle', () {
    test('is null when the title already contains the level', () {
      expect(certificationSubtitle(cert(name: 'PADI : Open Water')), isNull);
    });

    test('is the level when the title is a custom name', () {
      expect(certificationSubtitle(cert(name: 'Bali OW w/ Made')),
          'Open Water');
    });

    test('is null when a custom name has no level', () {
      expect(certificationSubtitle(cert(name: 'Bali OW', level: null)), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/domain/certification_title_test.dart`
Expected: FAIL — `Error: Error when reading '.../certification_title.dart': No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/certifications/domain/certification_title.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// What a certification is called on screen, and whether its stored
/// [Certification.name] adds anything to the structured fields.
///
/// Until 2026-08 the edit form auto-filled `name` from agency + level
/// ("PADI : Open Water"), so most stored names merely repeat what `agency`
/// and `level` already say, and surfaces rendered the same string twice.
/// Rather than rewrite those rows, the display layer recognises a derived
/// name and suppresses it. That is why [hasDerivedName] must keep matching
/// the legacy spaced-colon format for as long as such rows can exist.

/// "PADI Open Water", or the agency alone when [level] is null.
String derivedCertificationTitle(
  CertificationAgency agency,
  CertificationLevel? level,
) {
  final agencyName = agency.displayName;
  if (level == null) return agencyName;
  return '$agencyName ${level.displayName}';
}

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when [cert]'s stored name carries no information beyond agency and
/// level -- including an empty name.
bool hasDerivedName(Certification cert) {
  final stored = _normalized(cert.name);
  if (stored.isEmpty) return true;

  final agencyName = cert.agency.displayName;
  final level = cert.level;
  final candidates = <String>[
    agencyName,
    if (level != null) ...[
      '$agencyName ${level.displayName}',
      '$agencyName: ${level.displayName}',
      '$agencyName : ${level.displayName}',
      level.displayName,
    ],
  ];
  return candidates.map(_normalized).contains(stored);
}

/// The stored name when it says something the structured fields do not,
/// otherwise null.
String? customNameOrNull(Certification cert) =>
    hasDerivedName(cert) ? null : cert.name.trim();

/// The title to show for [cert] anywhere one is needed. Never empty.
String certificationTitle(Certification cert) =>
    customNameOrNull(cert) ?? derivedCertificationTitle(cert.agency, cert.level);

/// The secondary line beneath [certificationTitle]: the level, but only when
/// the title is a custom name. When the title is derived it already contains
/// the level, and showing it again is the duplication this module exists to
/// remove.
String? certificationSubtitle(Certification cert) =>
    customNameOrNull(cert) == null ? null : cert.level?.displayName;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/certifications/domain/certification_title_test.dart`
Expected: PASS, 20 tests, 0 failures.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/certifications/domain/certification_title.dart test/features/certifications/domain/certification_title_test.dart
flutter analyze lib/features/certifications/domain/certification_title.dart test/features/certifications/domain/certification_title_test.dart
git add lib/features/certifications/domain/certification_title.dart test/features/certifications/domain/certification_title_test.dart
git commit -m "Add certification title helper that suppresses derived names"
```

---

### Task 2: Expose the ladder/specialty split in the catalog

**Files:**
- Modify: `lib/core/constants/certification_levels.dart:137-153`
- Test: `test/core/constants/certification_levels_test.dart`

**Interfaces:**
- Consumes: existing `CertificationLevelCatalog.ladderFor` and `specialties`.
- Produces: `static List<CertificationLevel> specialtiesFor(CertificationAgency? agency)` — the cross-agency specialties minus anything already on that agency's ladder. Task 4 uses it to build the grouped dropdown.
- `ladderFor` and `levelsFor` keep their exact current signatures and behaviour.

- [ ] **Step 1: Write the failing test**

Append inside `void main() { ... }` in `test/core/constants/certification_levels_test.dart`:

```dart
  group('CertificationLevelCatalog.specialtiesFor', () {
    test('excludes specialties already on the agency ladder', () {
      // The tech ladder (TDI/IANTD/PSAI) contains nitrox, cavern and cave.
      final specialties = CertificationLevelCatalog.specialtiesFor(
        CertificationAgency.tdi,
      );
      expect(specialties, isNot(contains(CertificationLevel.nitrox)));
      expect(specialties, isNot(contains(CertificationLevel.cave)));
      expect(specialties, contains(CertificationLevel.wreck));
    });

    test('returns the full specialty set for a ladder with no overlap', () {
      expect(
        CertificationLevelCatalog.specialtiesFor(CertificationAgency.padi),
        CertificationLevelCatalog.specialties,
      );
    });

    for (final agency in [...CertificationAgency.values, null]) {
      test('ladder + specialties + other reproduces levelsFor (${agency?.name ?? 'null'})', () {
        expect(
          [
            ...CertificationLevelCatalog.ladderFor(agency),
            ...CertificationLevelCatalog.specialtiesFor(agency),
            CertificationLevel.other,
          ],
          CertificationLevelCatalog.levelsFor(agency),
        );
      });
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/certification_levels_test.dart`
Expected: FAIL — "The method 'specialtiesFor' isn't defined for the type 'CertificationLevelCatalog'".

- [ ] **Step 3: Write minimal implementation**

In `lib/core/constants/certification_levels.dart`, replace the `levelsFor` method (currently lines 132-153) with:

```dart
  /// Specialties offered for [agency] that are not already on its ladder.
  /// Used to render the dropdown's "Specialties" group without repeating a
  /// level that the ladder already lists.
  static List<CertificationLevel> specialtiesFor(CertificationAgency? agency) {
    final ladder = ladderFor(agency);
    return specialties.where((s) => !ladder.contains(s)).toList();
  }

  /// Full dropdown list for an agency: ladder, then specialties not already
  /// on the ladder, then [CertificationLevel.other] last. When [ensure] is
  /// provided and missing from the list (a stored value from another
  /// agency's catalog), it is inserted before `other` so existing data
  /// always renders.
  static List<CertificationLevel> levelsFor(
    CertificationAgency? agency, {
    CertificationLevel? ensure,
  }) {
    final result = [...ladderFor(agency), ...specialtiesFor(agency)];
    if (ensure != null &&
        ensure != CertificationLevel.other &&
        !result.contains(ensure)) {
      result.add(ensure);
    }
    result.add(CertificationLevel.other);
    return result;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/certification_levels_test.dart`
Expected: PASS — the pre-existing `levelsFor` tests still pass (behaviour is unchanged), plus the new group.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/constants/certification_levels.dart test/core/constants/certification_levels_test.dart
flutter analyze lib/core/constants/certification_levels.dart test/core/constants/certification_levels_test.dart
git add lib/core/constants/certification_levels.dart test/core/constants/certification_levels_test.dart
git commit -m "Expose specialtiesFor on the certification level catalog"
```

---

### Task 3: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale files.

**Interfaces:**
- Produces — Task 4 and Task 5 call exactly these getters on `context.l10n`:
  `certifications_edit_label_certification`, `certifications_edit_certification_notSpecified`, `certifications_edit_label_nameOnCard`, `certifications_edit_helper_nameOnCard`, `certifications_edit_group_progression`, `certifications_edit_group_specialties`, `certifications_edit_validation_certificationOrNameRequired`, `certifications_detail_label_certification`.

- [ ] **Step 1: Add the eight new keys to every locale**

Insert each key at its **alphabetical** position in each file. Values per locale:

| Key | en | de | es | fr | it |
| --- | --- | --- | --- | --- | --- |
| `certifications_detail_label_certification` | Certification | Zertifizierung | Certificación | Certification | Certificazione |
| `certifications_edit_certification_notSpecified` | Not specified | Nicht angegeben | No especificado | Non spécifié | Non specificato |
| `certifications_edit_group_progression` | Progression | Ausbildungsstufen | Progresión | Progression | Progressione |
| `certifications_edit_group_specialties` | Specialties | Spezialkurse | Especialidades | Spécialités | Specialità |
| `certifications_edit_helper_nameOnCard` | Optional | Optional | Opcional | Facultatif | Facoltativo |
| `certifications_edit_label_certification` | Certification | Zertifizierung | Certificación | Certification | Certificazione |
| `certifications_edit_label_nameOnCard` | Name on card | Name auf der Karte | Nombre en la tarjeta | Nom sur la carte | Nome sulla tessera |
| `certifications_edit_validation_certificationOrNameRequired` | Choose a certification or enter a name | Wählen Sie eine Zertifizierung oder geben Sie einen Namen ein | Elige una certificación o introduce un nombre | Choisissez une certification ou saisissez un nom | Scegli una certificazione o inserisci un nome |

| Key | nl | pt | hu | zh | ar | he |
| --- | --- | --- | --- | --- | --- | --- |
| `certifications_detail_label_certification` | Certificering | Certificação | Képesítés | 证书 | الشهادة | הסמכה |
| `certifications_edit_certification_notSpecified` | Niet opgegeven | Não especificado | Nincs megadva | 未指定 | غير محدد | לא צוין |
| `certifications_edit_group_progression` | Opleidingslijn | Progressão | Fokozatok | 进阶等级 | التدرج | התקדמות |
| `certifications_edit_group_specialties` | Specialisaties | Especialidades | Specialitások | 专长课程 | التخصصات | התמחויות |
| `certifications_edit_helper_nameOnCard` | Optioneel | Opcional | Nem kötelező | 可选 | اختياري | אופציונלי |
| `certifications_edit_label_certification` | Certificering | Certificação | Képesítés | 证书 | الشهادة | הסמכה |
| `certifications_edit_label_nameOnCard` | Naam op de kaart | Nome no cartão | Név a kártyán | 卡片上的名称 | الاسم على البطاقة | השם על הכרטיס |
| `certifications_edit_validation_certificationOrNameRequired` | Kies een certificering of voer een naam in | Escolha uma certificação ou insira um nome | Válasszon képesítést, vagy adjon meg egy nevet | 请选择证书或输入名称 | اختر شهادة أو أدخل اسمًا | יש לבחור הסמכה או להזין שם |

Add **no** `@`-description entries: `app_en.arb` has none for the neighbouring certification keys (verified — `grep '@certifications_edit_label_level' lib/l10n/arb/app_en.arb` returns nothing), so adding them here would be inconsistent.

- [ ] **Step 2: Remove the six superseded keys from every locale**

Delete from all 11 files:
`certifications_edit_label_level`, `certifications_edit_level_notSpecified`, `certifications_detail_label_level`, `certifications_edit_validation_nameRequired`, `certifications_edit_label_certificationName`, `certifications_edit_hint_certificationName`
(plus any matching `@`-description entries).

- [ ] **Step 3: Regenerate and verify the old getters are gone**

```bash
flutter gen-l10n
grep -rn "certifications_edit_label_level\|certifications_edit_level_notSpecified\|certifications_detail_label_level\|certifications_edit_validation_nameRequired\|certifications_edit_label_certificationName\|certifications_edit_hint_certificationName" lib/l10n/arb/*.arb
```
Expected: `flutter gen-l10n` succeeds; the grep prints nothing.

- [ ] **Step 4: Confirm the build now fails only at the call sites**

Run: `flutter analyze lib/features/certifications`
Expected: errors reporting the removed getters are undefined in `certification_edit_page.dart` and `certification_detail_page.dart`. This is the expected intermediate state — Tasks 4 and 5 fix it. **Do not commit yet.** Commit at the end of Task 5, when the tree compiles again.

---

### Task 4: Edit form — rename, reorder, group, optional name

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart`
- Modify: `lib/core/constants/enums.dart:167`
- Rename + rewrite: `test/features/certifications/presentation/pages/certification_name_auto_generation_test.dart` → `certification_edit_name_field_test.dart`
- Test: `test/features/certifications/presentation/pages/certification_edit_agency_level_test.dart` (extend)

**Interfaces:**
- Consumes: `derivedCertificationTitle`, `hasDerivedName` (Task 1); `CertificationLevelCatalog.ladderFor`, `.specialtiesFor` (Task 2); the l10n getters from Task 3.
- Produces: no new public API. The dropdown stays typed `DropdownButtonFormField<CertificationLevel>` so existing finders keep working.

**Two mechanics that will silently break if you get them wrong — read before coding:**

1. **The "Not specified" item must stay first.** Group headers are `DropdownMenuItem(enabled: false)` with a **null value**, so when `_level == null` several items share `value: null`. Flutter's `DropdownButton` assert is skipped when `value == null`, but `_updateSelectedIndex` picks the *first* item whose value matches — so "Not specified" must precede every header or the closed dropdown will display a header instead.
2. **Do not add an "Other" group header.** A header reading "Other" directly above an item reading "Other" is both silly on screen and ambiguous for `find.text('Other')` in tests. `CertificationLevel.other` trails the Specialties group with no header of its own.

- [ ] **Step 1: Delete the auto-name machinery**

In `certification_edit_page.dart` remove, in full:
- the `_isNameManuallyEdited` field (line ~77)
- `_onNameChanged()` (lines ~108-118)
- `_updateNameIfDefault()` (lines ~120-127)
- `_generateDefaultName()` (lines ~129-134)
- the `_nameController.addListener(_onNameChanged);` line in `initState`
- the `_nameController.removeListener(_onNameChanged);` line in `dispose`
- the three `_updateNameIfDefault();` calls (in `initState`'s else branch, the agency `onChanged`, and the level `onChanged`)
- the two `_isNameManuallyEdited = cert.name.isNotEmpty;` assignments in `_prefillFrom` and `_loadCertification`

- [ ] **Step 2: Prefill an empty name when the stored one is derived**

Add to the imports:

```dart
import 'package:submersion/features/certifications/domain/certification_title.dart';
```

In `_prefillFrom`, replace `_nameController.text = cert.name;` with:

```dart
    // A name that merely repeats agency + level is shown as blank, so the
    // field's hint offers the derivation instead of duplicating it.
    _nameController.text = hasDerivedName(cert) ? '' : cert.name;
```

Make the identical replacement in `_loadCertification`.

- [ ] **Step 3: Add the grouped item builder**

Add this method to `_CertificationEditPageState`:

```dart
  /// Items for the certification dropdown, grouped into the agency's
  /// progression ladder and the cross-agency specialties.
  ///
  /// Headers are disabled items with a null value. "Not specified" must stay
  /// first: DropdownButton resolves a null selection to the first null-valued
  /// item, and a header rendering as the selected label would be a bug.
  List<DropdownMenuItem<CertificationLevel>> _certificationItems(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final ladder = CertificationLevelCatalog.ladderFor(_agency);
    final specialties = CertificationLevelCatalog.specialtiesFor(_agency);

    // A stored value from another agency's catalog still has to render.
    final level = _level;
    final extra =
        (level != null &&
            level != CertificationLevel.other &&
            !ladder.contains(level) &&
            !specialties.contains(level))
        ? level
        : null;

    DropdownMenuItem<CertificationLevel> header(String text) =>
        DropdownMenuItem<CertificationLevel>(
          enabled: false,
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    DropdownMenuItem<CertificationLevel> item(CertificationLevel value) =>
        DropdownMenuItem<CertificationLevel>(
          value: value,
          child: Text(value.displayName),
        );

    return [
      DropdownMenuItem<CertificationLevel>(
        value: null,
        child: Text(
          context.l10n.certifications_edit_certification_notSpecified,
        ),
      ),
      header(context.l10n.certifications_edit_group_progression),
      ...ladder.map(item),
      header(context.l10n.certifications_edit_group_specialties),
      ...specialties.map(item),
      if (extra != null) item(extra),
      item(CertificationLevel.other),
    ];
  }
```

- [ ] **Step 4: Reorder the fields and rewire the two widgets**

Move the name `TextFormField` (currently the first child, lines ~397-417) to sit **after** the level dropdown, and replace it with:

```dart
                  // Name on card: optional. Blank means "use the derived
                  // title", which the hint shows live.
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.certifications_edit_label_nameOnCard,
                      prefixIcon: const Icon(Icons.card_membership),
                      hintText: derivedCertificationTitle(_agency, _level),
                      helperText:
                          context.l10n.certifications_edit_helper_nameOnCard,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if ((value == null || value.trim().isEmpty) &&
                          _level == null) {
                        return context
                            .l10n
                            .certifications_edit_validation_certificationOrNameRequired;
                      }
                      return null;
                    },
                  ),
```

Replace the level dropdown's `decoration` and `items` (lines ~461-481) with:

```dart
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.certifications_edit_label_certification,
                      prefixIcon: const Icon(Icons.workspace_premium),
                    ),
                    items: _certificationItems(context),
```

Leave the `key: ValueKey('level-${_agency.name}-${_level?.name}')`, `initialValue: _level` and `onChanged` exactly as they are, minus the deleted `_updateNameIfDefault()` call. The resulting order is Agency → Certification → Name on card → Card number.

- [ ] **Step 5: Document the retained enum name**

In `lib/core/constants/enums.dart`, immediately above `enum CertificationLevel {`, add:

```dart
/// A certification a diver holds. Presented in the UI as "Certification" --
/// the values are course and rating names (Open Water, Nitrox, Tech 1), not
/// a level scale, and the UI groups them into progression vs specialties via
/// [CertificationLevelCatalog].
///
/// The type keeps the historical `Level` name deliberately: values are
/// persisted as enum-name text and round-trip through UDDF import/export and
/// the sync field maps, so renaming buys nothing a user can see.
```

- [ ] **Step 6: Rename the stale test file and rewrite its dead group**

```bash
git mv test/features/certifications/presentation/pages/certification_name_auto_generation_test.dart \
       test/features/certifications/presentation/pages/certification_edit_name_field_test.dart
```

In the renamed file, **delete the entire `group('Auto-generation logic', ...)` block** (lines 85-239) and replace it with:

```dart
  group('Name on card field', () {
    testWidgets('is blank for a new certification', (tester) async {
      await pumpEditPage(tester);

      final nameField = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(nameField).controller?.text, '');
    });

    testWidgets('is never auto-filled when a certification is picked', (
      tester,
    ) async {
      await pumpEditPage(tester);

      await tester.tap(find.byIcon(Icons.workspace_premium).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Water').last);
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(nameField).controller?.text, '');
    });

    testWidgets('a manually entered name survives an agency change', (
      tester,
    ) async {
      await pumpEditPage(tester);

      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'My Special Cert');
      await tester.pumpAndSettle();

      await tester.tap(find.text('PADI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSI').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'My Special Cert',
      );
    });

    testWidgets('shows blank when editing a cert with a derived name', (
      tester,
    ) async {
      final now = DateTime(2024);
      await repository.createCertification(
        Certification(
          id: 'derived-1',
          name: 'PADI : Open Water',
          agency: CertificationAgency.padi,
          level: CertificationLevel.openWater,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await pumpEditPage(tester, certificationId: 'derived-1');

      final nameField = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(nameField).controller?.text, '');
    });
  });

  group('Validation', () {
    testWidgets('rejects a save with neither certification nor name', (
      tester,
    ) async {
      await pumpEditPage(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a certification or enter a name'),
        findsOneWidget,
      );
    });

    testWidgets('accepts a save with a certification and no name', (
      tester,
    ) async {
      await pumpEditPage(tester);

      await tester.tap(find.byIcon(Icons.workspace_premium).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Water').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a certification or enter a name'),
        findsNothing,
      );
    });

    testWidgets('accepts a save with a name and no certification', (
      tester,
    ) async {
      await pumpEditPage(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Custom Card');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a certification or enter a name'),
        findsNothing,
      );
    });
  });
```

Then in the surviving `group('Form interactions and coverage', ...)`:
- **delete** the `testWidgets('validation error when name is empty on save', ...)` test (lines 242-254) — it is replaced by the Validation group above.
- leave every other test unchanged. `find.byType(TextFormField).first` still resolves to the name field after the reorder, because `DropdownButtonFormField` extends `FormField`, not `TextFormField`.

- [ ] **Step 7: Add grouping tests to the agency/level test file**

Append inside `void main()` in `certification_edit_agency_level_test.dart`:

```dart
  testWidgets('certification dropdown shows group headers', (tester) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets('group headers are not selectable', (tester) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();

    // The menu is still open and nothing was selected.
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets('closed dropdown shows Not specified, not a group header', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Not specified'), findsOneWidget);
    expect(find.text('Progression'), findsNothing);
  });
```

- [ ] **Step 8: Run the edit-page tests**

```bash
flutter test test/features/certifications/presentation/pages/
```
Expected: PASS. If `certification_edit_page_staging_test.dart` or `certification_edit_instructor_test.dart` fail on a name assertion, fix the assertion to match the new blank-name behaviour — do not restore auto-fill.

- [ ] **Step 9: Format, analyze, commit** (with Task 5 — see below)

The tree still will not compile until Task 5 removes the last use of `certifications_detail_label_level`. Proceed straight to Task 5 and commit both together.

---

### Task 5: Detail page and table column label

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_detail_page.dart:484-497`
- Modify: `lib/features/certifications/domain/constants/certification_field.dart:29,43,71,85`
- Test: `test/features/certifications/presentation/pages/certification_detail_page_test.dart`
- Test: `test/features/certifications/domain/constants/certification_field_test.dart`

**Interfaces:**
- Consumes: `customNameOrNull` (Task 1), `certifications_detail_label_certification` (Task 3).
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

The file's existing `pumpDetail` helper is **not** reusable here: it is declared inside a nested group (line 158) and hardcodes `certificationId: 'cert-2'`. Add a new top-level group at the end of `void main()` with its own harness, following the same override pattern that helper uses:

```dart
  group('duplicate-name suppression', () {
    Future<void> pumpCert(WidgetTester tester, Certification cert) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            certificationByIdProvider(cert.id).overrideWith((ref) async => cert),
            courseForCertificationProvider(
              cert.id,
            ).overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CertificationDetailPage(
              certificationId: cert.id,
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Certification make(String id, String name) => Certification(
      id: id,
      name: name,
      agency: CertificationAgency.padi,
      level: CertificationLevel.openWater,
      notes: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    testWidgets('a derived name renders one identifying row, not two', (
      tester,
    ) async {
      await pumpCert(tester, make('d1', 'PADI : Open Water'));

      expect(find.text('Certification'), findsOneWidget);
      expect(find.text('Open Water'), findsOneWidget);
      expect(find.text('PADI : Open Water'), findsNothing);
    });

    testWidgets('a custom name renders both rows', (tester) async {
      await pumpCert(tester, make('d2', 'Bali OW w/ Made'));

      expect(find.text('Bali OW w/ Made'), findsOneWidget);
      expect(find.text('Open Water'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/presentation/pages/certification_detail_page_test.dart`
Expected: FAIL — compile error on the removed `certifications_detail_label_level` getter.

- [ ] **Step 3: Write minimal implementation**

Add to the detail page imports:

```dart
import 'package:submersion/features/certifications/domain/certification_title.dart';
```

Replace the `Type` and `Level` `_InfoRow`s (lines 484-497) with:

```dart
            // Only shown when the stored name says something the agency and
            // certification rows do not already say.
            if (customNameOrNull(certification) != null)
              _InfoRow(
                icon: Icons.card_membership,
                label: context.l10n.certifications_detail_label_type,
                value: customNameOrNull(certification)!,
              ),
            _InfoRow(
              icon: Icons.business,
              label: context.l10n.certifications_detail_label_agency,
              value: certification.agency.displayName,
            ),
            if (certification.level != null)
              _InfoRow(
                icon: Icons.workspace_premium,
                label: context.l10n.certifications_detail_label_certification,
                value: certification.level!.displayName,
              ),
```

Note the agency row moves above the certification row but keeps its own content; the `Type` row is now conditional and second-guessed by `customNameOrNull`.

- [ ] **Step 4: Rename the table column label**

In `certification_field.dart`, change the two `CertificationField.level => 'Level',` entries (lines 29 and 43) to `CertificationField.level => 'Certification',`. Leave the icon, widths, visibility and group entries alone.

- [ ] **Step 5: Run tests to verify they pass**

```bash
flutter test test/features/certifications/
```
Expected: PASS. If `certification_field_test.dart` asserts the string `'Level'`, update that expectation to `'Certification'`.

- [ ] **Step 6: Format, analyze, commit Tasks 3-5 together**

```bash
dart format .
flutter analyze lib test
git add -A
git commit -m "Rename certification Level field to Certification and group its options

The dropdown listed course and rating names, not levels, and the edit form
auto-filled Name from agency + level so the detail page rendered the same
string twice. Name is now optional (Name on card), the dropdown is grouped
into Progression and Specialties, and a name that merely repeats the
structured fields is suppressed at render time."
```

---

### Task 6: Remaining display surfaces

**Files:**
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart:540,549`
- Modify: `lib/features/certifications/presentation/widgets/certification_picker.dart:39,189,190,206`
- Modify: `lib/features/certifications/presentation/widgets/certification_summary_widget.dart:223`
- Modify: `lib/features/certifications/presentation/widgets/certification_wallet_card.dart:281`
- Modify: `lib/features/certifications/presentation/widgets/certification_share_sheet.dart:60,109,145`
- Modify: `lib/features/certifications/presentation/widgets/certification_ecard.dart:148-170`
- Modify: `lib/features/certifications/presentation/services/certification_card_renderer.dart:78-101,374-396`
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart:476`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart:509`
- Modify: `lib/core/services/pdf_templates/pdf_shared_components.dart:330,348-359`
- Modify: `lib/core/services/pdf_templates/pdf_template_professional.dart:280`
- Test: `test/features/certifications/presentation/widgets/certification_list_content_test.dart`

**Interfaces:**
- Consumes: `certificationTitle`, `certificationSubtitle` (Task 1).
- Produces: no new API.

This task is mechanical but **not optional**: the list, picker, summary and wallet card render `cert.name` alone as their title, so once Name may be empty they would render blank rows.

- [ ] **Step 1: Write the failing test**

Append a new group inside `void main()` in `certification_list_content_test.dart`, using that file's existing top-level `_makeCert`, `_buildOverrides` and `testApp` helpers:

```dart
  group('title derivation', () {
    testWidgets('a cert with no stored name still shows a title', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [
          _makeCert(id: 'n1', name: '', level: CertificationLevel.openWater),
        ],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('PADI Open Water'), findsOneWidget);
    });

    testWidgets('a derived stored name is not shown verbatim', (tester) async {
      final overrides = await _buildOverrides(
        certs: [
          _makeCert(
            id: 'n2',
            name: 'PADI : Open Water',
            level: CertificationLevel.openWater,
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('PADI : Open Water'), findsNothing);
      expect(find.text('PADI Open Water'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart`
Expected: FAIL — the first test finds no `'PADI Open Water'` (an empty title renders empty); the second finds the doubled-agency label.

- [ ] **Step 3: Replace bare `cert.name` with the helper**

Add `import 'package:submersion/features/certifications/domain/certification_title.dart';` to each file below, then:

| File:line | Before | After |
| --- | --- | --- |
| `certification_list_content.dart:540` | `'${certification.agency.displayName} ${certification.name}$issueDateLabel$statusLabel'` | `'${certificationTitle(certification)}$issueDateLabel$statusLabel'` |
| `certification_list_content.dart:549` | `Text(certification.name)` | `Text(certificationTitle(certification))` |
| `certification_picker.dart:39` | `selectedCertification?.name` | `selectedCertification == null ? null : certificationTitle(selectedCertification)` |
| `certification_picker.dart:189,190` | `'${cert.agency.displayName} ${cert.name}...'` | `'${certificationTitle(cert)}...'` (drop the now-duplicated agency prefix) |
| `certification_picker.dart:206` | `Text(cert.name)` | `Text(certificationTitle(cert))` |
| `certification_summary_widget.dart:223` | `Text(cert.name)` | `Text(certificationTitle(cert))` |
| `certification_wallet_card.dart:281` | `certification.name` | `certificationTitle(certification)` |
| `certification_share_sheet.dart:60` | `widget.certification.name` | `certificationTitle(widget.certification)` |
| `certification_share_sheet.dart:109,145` | `_sanitizeFilename(widget.certification.name)` | `_sanitizeFilename(certificationTitle(widget.certification))` |
| `buddy_edit_page.dart:476` | `Text(cert.level?.displayName ?? cert.name)` | `Text(certificationTitle(cert))` |
| `buddy_detail_page.dart:509` | `Text(cert.level?.displayName ?? cert.name)` | `Text(certificationTitle(cert))` |
| `pdf_template_professional.dart:280` | `'${cert.agency.displayName} - ${cert.name}'` | `certificationTitle(cert)` |

At `certification_picker.dart:39`, keep whatever `??` fallback already follows the expression.

- [ ] **Step 4: Collapse the title/subtitle pairs**

Three surfaces draw the name large with the level beneath. In each, the title becomes `certificationTitle` and the subtitle's `if (certification.level != null)` guard becomes a null-check on `certificationSubtitle`, so the level line disappears exactly when the title already contains it.

`certification_ecard.dart` (lines ~148-170):

```dart
                Text(
                  certificationTitle(certification),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Only when the title above is a custom name -- otherwise it
                // already contains the certification.
                if (certificationSubtitle(certification) != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    certificationSubtitle(certification)!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
```

`certification_card_renderer.dart` — apply the same shape at both sites. At the first (lines ~78-101) pass `text: certificationTitle(certification)` to `_drawText`, and change the level block's guard to:

```dart
      final subtitle = certificationSubtitle(certification);
      if (subtitle != null) {
        _drawText(
          canvas: canvas,
          text: subtitle,
          x: 32,
          y: height * 0.35 + 44,
          fontSize: 20,
          fontWeight: FontWeight.normal,
          color: const ui.Color(0xCCFFFFFF),
          maxWidth: width - 64,
        );
      }
```

At the second site (lines ~374-396) do the same with `_drawCenteredText`, keeping its existing `y: 450`, `fontSize: 28` and colour arguments.

`pdf_shared_components.dart` — line 330 becomes `certificationTitle(cert)`; the `if (cert.level != null)` at line 348 becomes a null-check on a local `certificationSubtitle(cert)`, with line 359 drawing that local.

The share-sheet filename uses matter: an empty stored name would otherwise produce an empty filename for the exported card image.

- [ ] **Step 5: Fix two pre-existing expectations that the helper legitimately changes**

`certification_list_content_test.dart`, in `testWidgets('renders with multiple certification levels', ...)` (lines ~268-300), builds certs whose stored name equals their level's display name. Two of the four are now recognised as derived and render the agency-prefixed title:

| Cert | Stored name | Level display name | New title |
| --- | --- | --- | --- |
| `ml1` | `Open Water` | `Open Water` | `PADI Open Water` — **changes** |
| `ml2` | `Advanced` | `Advanced Open Water` | `Advanced` — unchanged |
| `ml3` | `Rescue` | `Rescue Diver` | `Rescue` — unchanged |
| `ml4` | `Divemaster` | `Divemaster` | `PADI Divemaster` — **changes** |

Update only those two expectations:

```dart
      expect(find.text('PADI Open Water'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Rescue'), findsOneWidget);
      expect(find.text('PADI Divemaster'), findsOneWidget);
```

This is the intended behaviour, not a regression: a name that merely repeats the level is exactly what this change suppresses. If any other test fails with a similar agency-prefixed title, apply the same reasoning before assuming a bug.

- [ ] **Step 6: Run the full certification and buddy suites**

```bash
flutter test test/features/certifications/ test/features/buddies/
```
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze lib test
git add -A
git commit -m "Route certification display surfaces through the title helper

The list, picker, summary and wallet card rendered cert.name alone, which is
now blank for certs without a custom name. The e-card, card renderer and PDF
templates drew the name and the level as separate lines, duplicating the
agency+level string."
```

---

### Task 7: Whole-project verification

**Files:** none modified unless a failure demands it.

- [ ] **Step 1: Confirm no stale references remain**

```bash
grep -rn "_generateDefaultName\|_isNameManuallyEdited\|_updateNameIfDefault\|certifications_edit_label_level\|certifications_detail_label_level" lib test
```
Expected: no output.

- [ ] **Step 2: Format the whole project**

Run: `dart format .`
Expected: "0 changed". If anything changed, commit it.

- [ ] **Step 3: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Do not pipe the output — a pipe masks the exit code.

- [ ] **Step 4: Run the whole test suite**

Run: `flutter test`
Expected: all tests pass. Investigate any failure; do not skip or delete a failing test to make this step green.

- [ ] **Step 5: Launch the app and look at the form**

Run: `flutter run -d macos`
Confirm by eye, on the certification edit page: field order is Agency → Certification → Name on card → Card number; the dropdown shows Progression and Specialties headers that cannot be tapped; the Name on card hint tracks the agency and certification you pick; and an existing cert's detail page shows a single `Certification: <value>` row rather than a `Type` row repeating it.

- [ ] **Step 6: Commit anything the verification changed**

```bash
git status --short
```
If clean, nothing to do. Otherwise `git add -A && git commit -m "Fix formatting and analyzer findings"`.
