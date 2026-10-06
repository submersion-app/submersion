# Diver Figure Phase 2: Item Colour, Set Edit Figure, and Dive Figure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver give any item an optional colour that tints its artwork, show the live figure on the set edit page while items are ticked, and draw the figure in the dive detail equipment card behind a diver-wide switch that is off by default.

**Architecture:** Colour is a new catalog attribute kind stored as `#RRGGBB` text, so it needs no schema change; the figure composer already reads it. The set page's selection, memo, and figure wiring move into three small shared pieces (a selection mixin, a model memo, and a `GearFigure` widget) that the set page, the set edit page, and a new dive widget all use. The dive switch is a new `diver_settings` column in its own schema rung.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod, Drift. No new dependencies.

**Spec:** `docs/design/specs/2026-09-25-diver-figure-design.md`, sections 9 (item colour), 10 (set edit page), 11 (dive detail page), 12 and 13 (strings and tests). Tracking issue #2326; this is the last phase, so its PR says `Closes #2326`.

## Global Constraints

- Every new string lands in all eleven locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. Run `flutter gen-l10n` after ARB edits and stage the regenerated `lib/l10n/arb/app_localizations*.dart`; they are tracked.
- Colour values are stored uppercase as `#RRGGBB` in `valueText`. Anything else is not a colour: the figure falls back to the type default and no UI shows it as one.
- The swatch palette is `TagColors.predefined` (`lib/features/tags/domain/entities/tag.dart`), shared, never copied.
- Code under `lib/features/equipment/figure/domain/` and `lib/features/equipment/domain/` imports nothing from `package:flutter` or `dart:ui`.
- A setting default is for fresh databases only: the new column defaults to off and no migration rewrites a stored row.
- Off means unchanged: with a set's figure switch off, the set edit page is exactly as it is today; with the dive switch off, the dive page is exactly as it is today (no figure, no badges).
- Numbers on the figure and badges on rows always agree: both come from one composed `FigureModel`.
- Schema rung: 237 was the lowest version above main's 233 that no open PR claimed on 2026-09-26. Task 1 re-checks it; every "237" below means the number Task 1 settles on.
- Paths in tests are built with `p.join(...)`, never string concatenation with `/`.
- No em-dashes anywhere. No emojis. `dart format .` before every commit. Commit messages carry no attribution lines and end with `Part of #2326`.
- Stage explicit paths, never `git add -A`. Never rebase or force-push.

## Review Focus

1. **An older CSV with a custom field named "color"** (`color=Red`). It must come back as the diver's own custom field, not be dropped and not become a colour. Test in Task 4.
2. **A stored colour that is valid hex but not in the palette** (a CSV import or a peer wrote `#123456`). The figure uses it, the field and the detail row show its swatch with the code as its name, and the sheet shows no swatch selected. Tests in Tasks 2, 3, and 5.
3. **A set edit page where a ticked member is retired** (so it has no checkbox row). It is not drawn, and the numbers on the figure and the rows stay 1..n with no gap. Test in Task 7.
4. **A dive whose tank item is linked by two dive tanks** (a multi-computer dive), or whose linked tank item is not in the dive's gear. The first tank by `order` gives the role; an item not in the gear is not drawn. Tests in Task 10.
5. **A dive with the switch on but no gear, and a diver on an older app syncing settings.** No figure and no crash with no gear; a payload without `showDiveFigure` lands as off. Tests in Tasks 8 and 12.

---

## File Structure

New:

```
lib/features/equipment/domain/constants/equipment_colors.dart                  normalizeEquipmentColor (pure Dart)
lib/features/equipment/presentation/utils/equipment_color_names.dart           equipmentColorName (l10n)
lib/features/equipment/presentation/widgets/equipment_color_sheet.dart         the swatch sheet and showEquipmentColorSheet
lib/features/equipment/presentation/widgets/equipment_color_field.dart         the form field that opens the sheet
lib/features/equipment/figure/presentation/figure_selection.dart               FigureSelection mixin (select, flash, row keys)
lib/features/equipment/figure/presentation/figure_model_memo.dart              FigureModelMemo
lib/features/equipment/figure/presentation/gear_figure.dart                    GearFigure (DiverFigure with the app's strings)
lib/features/dive_log/presentation/widgets/dive_gear_with_figure.dart          figure plus gear tree for the dive card
test/... one test file per new unit, plus test/core/database/migration_v237_show_dive_figure_test.dart
```

Modified:

```
lib/features/equipment/domain/constants/equipment_attribute_catalog.dart       kind, group, key, appearance list
lib/features/equipment/figure/domain/figure_composer.dart                      parseFigureColor uses normalizeEquipmentColor
lib/features/equipment/figure/domain/figure_inputs.dart                        figureInputsForDive, tankRolesByItem
lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart   color case
lib/features/equipment/presentation/utils/equipment_attribute_units.dart       color case
lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart        attrLabel_color
lib/core/services/export/csv/codec/csv_attribute_codec.dart                    color case
lib/features/equipment/presentation/pages/equipment_edit_page.dart             appearance block
lib/features/equipment/presentation/pages/equipment_detail_page.dart           colour row
lib/features/equipment/presentation/pages/equipment_set_detail_page.dart       uses the shared figure pieces
lib/features/equipment/presentation/pages/equipment_set_edit_page.dart         live figure, badges
lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart            optional badges and row keys
lib/features/dive_log/presentation/pages/dive_detail_page.dart                 equipment card uses DiveGearWithFigure
lib/core/database/database.dart                                                show_dive_figure column and rung
lib/features/settings/data/repositories/diver_settings_repository.dart         column mapping
lib/features/settings/presentation/providers/settings_providers.dart           AppSettings.showDiveFigure, setter
lib/features/settings/presentation/pages/section_appearance_page.dart          the switch
lib/l10n/arb/app_*.arb (11) and generated app_localizations*.dart
test fakes that implement SettingsNotifier (4 files)
```

---

### Task 1: Worktree setup and branch sync

**Files:**
- Modify (merge only): whatever `origin/main` brings in.

**Interfaces:**
- Consumes: nothing.
- Produces: a branch containing PR #2372 and current `origin/main`, codegen done, baseline green, and the schema version to use.

- [ ] **Step 1: Initialise the worktree**

The worktree is `.claude/worktrees/diver-figure-colour-and-dives` on branch `ericgriffin/diver-figure-colour-and-dives`, cut from PR #2372's head. From that directory:

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: all three exit 0.

- [ ] **Step 2: Merge the latest PR #2372 and main**

```bash
git fetch origin main ericgriffin/equipment-visual-representation-db57a6
git merge --no-edit origin/ericgriffin/equipment-visual-representation-db57a6
git merge --no-edit origin/main
```

If `lib/core/database/database.dart` or a `test/core/database/migration_v2*_test.dart` conflicts, keep both sides: every rung, its ladder entry, and its backstop stay. Then:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

Expected: `No issues found!`. If analyze fails in files this branch never touched, main is red; stop and report rather than fixing main's code here.

- [ ] **Step 3: Re-check the free schema version**

```bash
git grep -n "static const int currentSchemaVersion" origin/main -- lib/core/database/database.dart
```

Then list the rungs every open PR adds, in bash (the Bash tool is zsh, so wrap the loop):

```bash
bash -c 'for n in $(gh api "repos/submersion-app/submersion/pulls?state=open&per_page=100" --jq ".[].number"); do
  gh api "repos/submersion-app/submersion/pulls/$n/files?per_page=100" \
    --jq ".[] | select(.filename==\"lib/core/database/database.dart\") | .patch" \
    | grep -oE "^\+.*from < [0-9]+" | grep -oE "[0-9]+$" | sort -u | sed "s/^/#$n /"
done'
```

Pick the lowest number above main's `currentSchemaVersion` that no PR lists. If it is not 237, use it wherever this plan says 237, including the migration test's file name.

- [ ] **Step 4: Baseline**

```bash
flutter test test/features/equipment test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart test/features/settings
```

Expected: all pass. A failure here existed before this plan; note it and stop.

- [ ] **Step 5: Commit**

The merges already recorded their commits. Nothing else to commit. Push is not part of this task.

---

### Task 2: Colour codes and their names

**Files:**
- Create: `lib/features/equipment/domain/constants/equipment_colors.dart`
- Create: `lib/features/equipment/presentation/utils/equipment_color_names.dart`
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart:11-19`
- Modify: `lib/l10n/arb/app_*.arb` (11) and the generated `app_localizations*.dart`
- Test: `test/features/equipment/domain/equipment_colors_test.dart`
- Test: `test/features/equipment/presentation/equipment_color_names_test.dart`

**Interfaces:**
- Consumes: `TagColors.predefined` (`List<String>`, 20 uppercase `#RRGGBB`).
- Produces:
  - `String? normalizeEquipmentColor(String? value)`: trimmed uppercase `#RRGGBB`, or null.
  - `String equipmentColorName(AppLocalizations l10n, String hex)`: the palette colour's localized name, or the uppercase code for any other valid colour.
  - l10n getters `equipment_color_red` through `equipment_color_slate` (20), `equipment_color_none`, `equipment_color_sheetTitle`, `attrLabel_color`.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/domain/equipment_colors_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';

void main() {
  test('a colour code comes back trimmed and uppercase', () {
    expect(normalizeEquipmentColor('#ef4444'), '#EF4444');
    expect(normalizeEquipmentColor('  #3b82F6 '), '#3B82F6');
  });

  test('anything that is not #RRGGBB is not a colour', () {
    for (final value in [
      null,
      '',
      'red',
      '#12G',
      '#1234567',
      '#-00001',
      'EF4444',
      '#fff',
    ]) {
      expect(normalizeEquipmentColor(value), isNull, reason: '$value');
    }
  });
}
```

`test/features/equipment/presentation/equipment_color_names_test.dart`:

```dart
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('every palette colour has its own name', () {
    final names = [
      for (final hex in TagColors.predefined) equipmentColorName(l10n, hex),
    ];
    expect(names.toSet(), hasLength(TagColors.predefined.length));
    for (final (i, name) in names.indexed) {
      expect(name, isNot(startsWith('#')), reason: TagColors.predefined[i]);
    }
  });

  test('every locale names every palette colour', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final names = lookupAppLocalizations(locale);
      final all = {
        for (final hex in TagColors.predefined) equipmentColorName(names, hex),
      };
      expect(all, hasLength(TagColors.predefined.length), reason: '$locale');
    }
  });

  test('palette lookups ignore case', () {
    expect(equipmentColorName(l10n, '#ef4444'), 'Red');
  });

  test('a colour outside the palette is named by its code', () {
    expect(equipmentColorName(l10n, '#123abc'), '#123ABC');
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/domain/equipment_colors_test.dart test/features/equipment/presentation/equipment_color_names_test.dart`
Expected: FAIL, the two libraries do not exist.

- [ ] **Step 3: Add the domain helper and use it in the composer**

`lib/features/equipment/domain/constants/equipment_colors.dart`:

```dart
/// An item's colour is stored as `#RRGGBB` in the `color` attribute's
/// `valueText` (issue #2326). Values reach it from the colour sheet, CSV
/// import, and sync, so every reader goes through this one check.
final RegExp _colorCode = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// [value] trimmed and uppercased when it is a `#RRGGBB` code, else null.
/// The pattern is checked before any parse, because `int.tryParse` accepts
/// a sign and would turn `#-00001` into a colour.
String? normalizeEquipmentColor(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || !_colorCode.hasMatch(trimmed)) return null;
  return trimmed.toUpperCase();
}
```

In `lib/features/equipment/figure/domain/figure_composer.dart`, delete the `_hexColor` field and replace `parseFigureColor` (lines 11-19) with:

```dart
/// `#RRGGBB` to ARGB, or null for anything else.
int? parseFigureColor(String? hex) {
  final code = normalizeEquipmentColor(hex);
  if (code == null) return null;
  return 0xFF000000 | int.parse(code.substring(1), radix: 16);
}
```

and add `import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';`.

- [ ] **Step 4: Add the strings**

Insert the keys in every locale with a throwaway script. Save it as `add_colour_strings.py` in your scratch directory (not in the repo) and run it from the worktree root with `python3.14`:

```python
import json, pathlib

ARB = pathlib.Path("lib/l10n/arb")
ANCHOR = "equipment_setEdit_figureSwitch_title"
LABEL_ANCHOR = "attrLabel_product_url"

KEYS = ["red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal",
        "cyan", "sky", "blue", "indigo", "violet", "purple", "fuchsia", "pink",
        "rose", "stone", "zinc", "slate"]

NAMES = {
 "en": ["Red","Orange","Amber","Yellow","Lime","Green","Emerald","Teal","Cyan","Sky","Blue","Indigo","Violet","Purple","Fuchsia","Pink","Rose","Stone","Zinc","Slate"],
 "de": ["Rot","Orange","Bernstein","Gelb","Limette","Grün","Smaragd","Petrol","Cyan","Himmelblau","Blau","Indigo","Violett","Lila","Fuchsia","Rosa","Rosé","Stein","Zink","Schiefer"],
 "es": ["Rojo","Naranja","Ámbar","Amarillo","Lima","Verde","Esmeralda","Verde azulado","Cian","Celeste","Azul","Índigo","Violeta","Morado","Fucsia","Rosa","Rosa intenso","Piedra","Zinc","Pizarra"],
 "fr": ["Rouge","Orange","Ambre","Jaune","Citron vert","Vert","Émeraude","Sarcelle","Cyan","Bleu ciel","Bleu","Indigo","Violet","Pourpre","Fuchsia","Rose","Rose vif","Pierre","Zinc","Ardoise"],
 "it": ["Rosso","Arancione","Ambra","Giallo","Lime","Verde","Smeraldo","Verde acqua","Ciano","Azzurro","Blu","Indaco","Viola","Porpora","Fucsia","Rosa","Rosa acceso","Pietra","Zinco","Ardesia"],
 "nl": ["Rood","Oranje","Amber","Geel","Limoen","Groen","Smaragd","Blauwgroen","Cyaan","Hemelsblauw","Blauw","Indigo","Violet","Paars","Fuchsia","Roze","Rozerood","Steen","Zink","Leisteen"],
 "pt": ["Vermelho","Laranja","Âmbar","Amarelo","Lima","Verde","Esmeralda","Verde-azulado","Ciano","Azul-celeste","Azul","Índigo","Violeta","Roxo","Fúcsia","Rosa","Rosa-choque","Pedra","Zinco","Ardósia"],
 "hu": ["Piros","Narancs","Borostyán","Sárga","Zöldcitrom","Zöld","Smaragd","Kékeszöld","Cián","Égkék","Kék","Indigó","Ibolya","Lila","Fukszia","Rózsaszín","Rózsa","Kő","Cink","Pala"],
 "ar": ["أحمر","برتقالي","كهرماني","أصفر","ليموني","أخضر","زمردي","أزرق مخضر","سماوي","أزرق فاتح","أزرق","نيلي","بنفسجي","أرجواني","فوشيا","وردي","وردي داكن","حجري","زنكي","رمادي أردوازي"],
 "he": ["אדום","כתום","ענבר","צהוב","ליים","ירוק","אזמרגד","כחול-ירקרק","ציאן","תכלת","כחול","אינדיגו","סגול","ארגמן","פוקסיה","ורוד","ורד","אבן","אבץ","צפחה"],
 "zh": ["红色","橙色","琥珀色","黄色","青柠色","绿色","翡翠绿","蓝绿色","青色","天蓝色","蓝色","靛蓝色","紫罗兰色","紫色","品红色","粉色","玫瑰红","岩石灰","锌灰色","石板灰"],
}
# (none, sheet title, attribute label)
EXTRA = {
 "en": ("None", "Choose a color", "Color"),
 "de": ("Keine", "Farbe wählen", "Farbe"),
 "es": ("Ninguno", "Elige un color", "Color"),
 "fr": ("Aucune", "Choisir une couleur", "Couleur"),
 "it": ("Nessuno", "Scegli un colore", "Colore"),
 "nl": ("Geen", "Kies een kleur", "Kleur"),
 "pt": ("Nenhuma", "Escolha uma cor", "Cor"),
 "hu": ("Nincs", "Szín választása", "Szín"),
 "ar": ("بلا", "اختر لونًا", "اللون"),
 "he": ("ללא", "בחירת צבע", "צבע"),
 "zh": ("无", "选择颜色", "颜色"),
}

def insert_after(lines, anchor, entries):
    idx = next(i for i, l in enumerate(lines) if l.startswith(f'  "{anchor}":'))
    new = [f'  {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)},\n' for k, v in entries]
    return lines[: idx + 1] + new + lines[idx + 1 :]

for locale, names in NAMES.items():
    path = ARB / f"app_{locale}.arb"
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    none, title, label = EXTRA[locale]
    entries = [(f"equipment_color_{k}", n) for k, n in zip(KEYS, names)]
    entries += [("equipment_color_none", none), ("equipment_color_sheetTitle", title)]
    lines = insert_after(lines, ANCHOR, entries)
    lines = insert_after(lines, LABEL_ANCHOR, [("attrLabel_color", label)])
    path.write_text("".join(lines), encoding="utf-8")
    print(locale, "ok")
```

Then `flutter gen-l10n`. Expected: exit 0.

- [ ] **Step 5: Add the name helper**

`lib/features/equipment/presentation/utils/equipment_color_names.dart`:

```dart
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know an item colour by: the
/// palette colour's localized name, or the code itself for a colour from
/// outside the palette (an import or a peer can write any `#RRGGBB`).
String equipmentColorName(AppLocalizations l10n, String hex) {
  final code = normalizeEquipmentColor(hex) ?? hex;
  return switch (code) {
    '#EF4444' => l10n.equipment_color_red,
    '#F97316' => l10n.equipment_color_orange,
    '#F59E0B' => l10n.equipment_color_amber,
    '#EAB308' => l10n.equipment_color_yellow,
    '#84CC16' => l10n.equipment_color_lime,
    '#22C55E' => l10n.equipment_color_green,
    '#10B981' => l10n.equipment_color_emerald,
    '#14B8A6' => l10n.equipment_color_teal,
    '#06B6D4' => l10n.equipment_color_cyan,
    '#0EA5E9' => l10n.equipment_color_sky,
    '#3B82F6' => l10n.equipment_color_blue,
    '#6366F1' => l10n.equipment_color_indigo,
    '#8B5CF6' => l10n.equipment_color_violet,
    '#A855F7' => l10n.equipment_color_purple,
    '#D946EF' => l10n.equipment_color_fuchsia,
    '#EC4899' => l10n.equipment_color_pink,
    '#F43F5E' => l10n.equipment_color_rose,
    '#78716C' => l10n.equipment_color_stone,
    '#71717A' => l10n.equipment_color_zinc,
    '#64748B' => l10n.equipment_color_slate,
    _ => code,
  };
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/domain/equipment_colors_test.dart test/features/equipment/presentation/equipment_color_names_test.dart test/features/equipment/figure/domain/figure_composer_test.dart test/l10n/arb_parity_test.dart`
Expected: PASS. The composer's existing colour tests still pass through the new helper.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/constants/equipment_colors.dart lib/features/equipment/presentation/utils/equipment_color_names.dart lib/features/equipment/figure/domain/figure_composer.dart lib/l10n/arb test/features/equipment/domain/equipment_colors_test.dart test/features/equipment/presentation/equipment_color_names_test.dart
git commit -m "feat(equipment): colour codes and their names in every locale" -m "Part of #2326"
```

---

### Task 3: The colour sheet and field

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_color_sheet.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_color_field.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_color_field_test.dart`

**Interfaces:**
- Consumes: `normalizeEquipmentColor`, `equipmentColorName`, `TagColors.predefined`, `TagColors.fromHex`, l10n `equipment_color_none`, `equipment_color_sheetTitle`, `common_placeholder_noValue` ("--").
- Produces:
  - `typedef EquipmentColorChoice = ({String? hex});` (a null `hex` means "None").
  - `Future<EquipmentColorChoice?> showEquipmentColorSheet(BuildContext context, {String? selected})`: null when dismissed.
  - `EquipmentColorField({Key? key, required String label, required String? hex, required ValueChanged<String> onChanged, required VoidCallback onCleared})`.
  - Keys used by later tests: `ValueKey('color-swatch-none')`, `ValueKey('color-swatch-<HEX>')`, `ValueKey('color-field-swatch')`.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Opens the sheet, runs [act] against it, and returns what it completed
/// with.
Future<EquipmentColorChoice?> _open(
  WidgetTester tester, {
  String? selected,
  required Future<void> Function() act,
}) async {
  EquipmentColorChoice? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showEquipmentColorSheet(
                context,
                selected: selected,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  return result;
}

Future<void> _dismiss(WidgetTester tester) => tester.tapAt(const Offset(5, 5));

void main() {
  testWidgets('offers None and every palette colour, by name', (tester) async {
    await _open(
      tester,
      act: () async {
        expect(find.text('Choose a color'), findsOneWidget);
        expect(find.bySemanticsLabel('None'), findsOneWidget);
        expect(find.bySemanticsLabel('Red'), findsOneWidget);
        expect(find.bySemanticsLabel('Slate'), findsOneWidget);
        for (final hex in TagColors.predefined) {
          expect(find.byKey(ValueKey('color-swatch-$hex')), findsOneWidget);
        }
        await _dismiss(tester);
      },
    );
  });

  testWidgets('a tap returns that colour', (tester) async {
    final result = await _open(
      tester,
      act: () => tester.tap(find.byKey(const ValueKey('color-swatch-#3B82F6'))),
    );
    expect(result, (hex: '#3B82F6'));
  });

  testWidgets('None returns a choice with no colour', (tester) async {
    final result = await _open(
      tester,
      selected: '#3B82F6',
      act: () => tester.tap(find.byKey(const ValueKey('color-swatch-none'))),
    );
    expect(result, (hex: null));
  });

  testWidgets('dismissing returns nothing', (tester) async {
    final result = await _open(tester, act: () => _dismiss(tester));
    expect(result, isNull);
  });

  testWidgets('the stored colour is the one marked selected', (tester) async {
    await _open(
      tester,
      selected: '#ef4444',
      act: () async {
        bool selected(String key) => tester
            .getSemantics(find.byKey(ValueKey(key)))
            .hasFlag(SemanticsFlag.isSelected);
        expect(selected('color-swatch-#EF4444'), isTrue);
        expect(selected('color-swatch-#3B82F6'), isFalse);
        expect(selected('color-swatch-none'), isFalse);
        await _dismiss(tester);
      },
    );
  });

  testWidgets('a colour from outside the palette selects nothing', (
    tester,
  ) async {
    await _open(
      tester,
      selected: '#123456',
      act: () async {
        for (final key in [
          'color-swatch-none',
          for (final hex in TagColors.predefined) 'color-swatch-$hex',
        ]) {
          expect(
            tester
                .getSemantics(find.byKey(ValueKey(key)))
                .hasFlag(SemanticsFlag.isSelected),
            isFalse,
            reason: key,
          );
        }
        await _dismiss(tester);
      },
    );
  });

  testWidgets('every swatch is at least 48 by 48', (tester) async {
    await _open(
      tester,
      act: () async {
        for (final key in ['color-swatch-none', 'color-swatch-#EF4444']) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        await _dismiss(tester);
      },
    );
  });
}
```

`test/features/equipment/presentation/widgets/equipment_color_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _field({
  String? hex,
  ValueChanged<String>? onChanged,
  VoidCallback? onCleared,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: EquipmentColorField(
      label: 'Color',
      hex: hex,
      onChanged: onChanged ?? (_) {},
      onCleared: onCleared ?? () {},
    ),
  ),
);

void main() {
  testWidgets('unset shows the placeholder and no clear button', (
    tester,
  ) async {
    await tester.pumpWidget(_field());
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('a value that is not a colour reads as unset', (tester) async {
    await tester.pumpWidget(_field(hex: 'Red'));
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('a palette colour shows its name and swatch', (tester) async {
    await tester.pumpWidget(_field(hex: '#EF4444'));
    expect(find.text('Red'), findsOneWidget);
    expect(find.byKey(const ValueKey('color-field-swatch')), findsOneWidget);
  });

  testWidgets('a colour outside the palette shows its code', (tester) async {
    await tester.pumpWidget(_field(hex: '#123456'));
    expect(find.text('#123456'), findsOneWidget);
  });

  testWidgets('picking a colour reports it', (tester) async {
    String? picked;
    await tester.pumpWidget(_field(onChanged: (hex) => picked = hex));
    await tester.tap(find.byType(EquipmentColorField));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#22C55E')));
    await tester.pumpAndSettle();
    expect(picked, '#22C55E');
  });

  testWidgets('None in the sheet clears', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-none')));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
  });

  testWidgets('the clear button clears without opening the sheet', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Choose a color'), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart test/features/equipment/presentation/widgets/equipment_color_field_test.dart`
Expected: FAIL, the widget libraries do not exist.

- [ ] **Step 3: Write the sheet**

`lib/features/equipment/presentation/widgets/equipment_color_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver picked: a colour code, or a null [hex] for "None".
typedef EquipmentColorChoice = ({String? hex});

/// Opens the item colour sheet (spec section 9). Completes with the choice,
/// or null when the sheet is dismissed without one.
Future<EquipmentColorChoice?> showEquipmentColorSheet(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<EquipmentColorChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        EquipmentColorSheet(selected: normalizeEquipmentColor(selected)),
  );
}

/// "None" and the tag palette as round swatches. It shares the palette with
/// the tag colour picker but not its widget, which previews a tag chip.
class EquipmentColorSheet extends StatelessWidget {
  const EquipmentColorSheet({super.key, this.selected});

  /// The stored colour, already normalised; null when unset.
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.equipment_color_sheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _Swatch(
                key: const ValueKey('color-swatch-none'),
                color: null,
                label: l10n.equipment_color_none,
                selected: selected == null,
                onTap: () => Navigator.of(context).pop((hex: null)),
              ),
              for (final hex in TagColors.predefined)
                _Swatch(
                  key: ValueKey('color-swatch-$hex'),
                  color: TagColors.fromHex(hex),
                  label: equipmentColorName(l10n, hex),
                  selected: selected == hex,
                  onTap: () => Navigator.of(context).pop((hex: hex)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Null draws the "None" swatch: an outlined circle with a slash.
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: color == null
                    ? Icon(Icons.block, size: 20, color: scheme.onSurfaceVariant)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

The `selected` passed in is already normalised, so a code from outside the palette matches no swatch and `None` is only selected when nothing is stored. The `None` swatch's selected flag must also be false for an outside-palette colour: `selected == null` is false there, as the test requires.

- [ ] **Step 4: Write the field**

`lib/features/equipment/presentation/widgets/equipment_color_field.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item form's colour row: the swatch and name of [hex], or a
/// placeholder, opening the colour sheet on tap. Laid out like the form's
/// date field, with a clear button once a colour is set.
class EquipmentColorField extends StatelessWidget {
  const EquipmentColorField({
    super.key,
    required this.label,
    required this.hex,
    required this.onChanged,
    required this.onCleared,
  });

  final String label;

  /// The stored value; anything that is not a colour code reads as unset.
  final String? hex;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final code = normalizeEquipmentColor(hex);
    return InkWell(
      onTap: () async {
        final choice = await showEquipmentColorSheet(context, selected: code);
        if (choice == null) return;
        switch (choice.hex) {
          case final picked?:
            onChanged(picked);
          case null:
            onCleared();
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: code == null
              ? const Icon(Icons.palette_outlined)
              : IconButton(icon: const Icon(Icons.clear), onPressed: onCleared),
        ),
        child: code == null
            ? Text(context.l10n.common_placeholder_noValue)
            : Row(
                children: [
                  Container(
                    key: const ValueKey('color-field-swatch'),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: TagColors.fromHex(code),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(equipmentColorName(context.l10n, code))),
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart test/features/equipment/presentation/widgets/equipment_color_field_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/widgets/equipment_color_sheet.dart lib/features/equipment/presentation/widgets/equipment_color_field.dart test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart test/features/equipment/presentation/widgets/equipment_color_field_test.dart
git commit -m "feat(equipment): a colour sheet and form field for items" -m "Part of #2326"
```

---

### Task 4: The colour attribute in the catalog, form, formatter, and CSV

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (kind doc and enum at 3-14, group enum 21-36, `EquipmentAttrKeys` 63-77, lists after `purchase` near 175, `attributesFor` and `_byKey` near 723-738)
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart:9`
- Modify: `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart` (the `switch (def.kind)`)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_units.dart` (`formatAttributeValue`)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (`attributeLabel`)
- Modify: `lib/core/services/export/csv/codec/csv_attribute_codec.dart` (`_readCurated`)
- Test: `test/features/equipment/domain/equipment_appearance_attributes_test.dart` (new)
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart` (7 exact key lists)
- Test: `test/features/equipment/domain/equipment_type_assembly_parts_test.dart:68-84`
- Test: `test/features/equipment/presentation/equipment_attribute_units_test.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart`
- Test: `test/core/services/export/csv/codec/csv_attribute_codec_test.dart`

**Interfaces:**
- Consumes: `normalizeEquipmentColor`, `equipmentColorName`, `EquipmentColorField`.
- Produces: `AttributeKind.color`, `AttributeGroup.appearance`, `EquipmentAttrKeys.color == 'color'`, `EquipmentAttributeCatalog.appearance`; `attributesFor(type)` ends with the appearance list for every type except `o2Cell`, `battery`, `other`; `defFor('color')` is non-null.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/domain/equipment_appearance_attributes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';

void main() {
  const excluded = {
    EquipmentType.o2Cell,
    EquipmentType.battery,
    EquipmentType.other,
  };

  test('every type but cells, batteries and other has a colour', () {
    for (final type in EquipmentType.values) {
      final keys = EquipmentAttributeCatalog.attributesFor(
        type,
      ).map((d) => d.key);
      expect(
        keys.contains(EquipmentAttrKeys.color),
        !excluded.contains(type),
        reason: type.name,
      );
    }
  });

  test('the colour is its own kind in its own group', () {
    final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.color)!;
    expect(def.kind, AttributeKind.color);
    expect(def.group, AttributeGroup.appearance);
    expect(def.choiceKeys, isEmpty);
  });

  test('the figure reads the same key', () {
    expect(kFigureColorAttribute, EquipmentAttrKeys.color);
  });
}
```

In `test/core/services/export/csv/codec/csv_attribute_codec_test.dart`, add inside `main()`:

```dart
  group('color', () {
    test('a colour code reads back as the item colour, uppercase', () {
      expect(parseAttributePair('color=#ef4444'), (
        key: 'color',
        isCustom: false,
        valueText: '#EF4444',
        valueNum: null,
      ));
    });

    test('an older file\'s custom "color" field stays a custom field', () {
      expect(parseAttributePair('color=Red'), (
        key: 'color',
        isCustom: true,
        valueText: 'Red',
        valueNum: null,
      ));
    });
  });
```

In `test/features/equipment/presentation/equipment_attribute_units_test.dart` (which already defines `l10n` and `units` at the top of `main()`), add:

```dart
  group('color', () {
    final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.color);
    EquipmentAttribute withValue(String value) => EquipmentAttribute.curated(
      equipmentId: 'e',
      key: 'color',
    ).copyWith(valueText: value);

    test('a palette colour shows its name', () {
      expect(formatAttributeValue(withValue('#EF4444'), def, units, l10n), 'Red');
    });

    test('anything else shows nothing', () {
      expect(formatAttributeValue(withValue('Red'), def, units, l10n), '');
    });
  });
```

In `test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart`, give `pumpSection` an optional `AttributeGroup group = AttributeGroup.spec` parameter passed through to `EquipmentAttributeFormSection(group: group, ...)`, import `equipment_attribute_catalog.dart`, and add:

```dart
  testWidgets('the appearance group renders the colour field and reports a pick', (
    tester,
  ) async {
    EquipmentAttribute? changed;
    await pumpSection(
      tester,
      type: EquipmentType.fins,
      group: AttributeGroup.appearance,
      values: const {},
      onChanged: (a) => changed = a,
    );
    expect(find.byKey(const ValueKey('attr-field-color')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attr-field-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#F97316')));
    await tester.pumpAndSettle();
    expect(changed?.key, 'color');
    expect(changed?.valueText, '#F97316');
  });

  testWidgets('the spec group does not render the colour', (tester) async {
    await pumpSection(
      tester,
      type: EquipmentType.fins,
      values: const {},
      onChanged: (_) {},
    );
    expect(find.byKey(const ValueKey('attr-field-color')), findsNothing);
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/domain/equipment_appearance_attributes_test.dart test/core/services/export/csv/codec/csv_attribute_codec_test.dart`
Expected: FAIL to compile: `EquipmentAttrKeys.color` and `AttributeKind.color` do not exist.

- [ ] **Step 3: Add the kind, group, key and list**

In `equipment_attribute_catalog.dart`:

1. In the storage-contract doc above `enum AttributeKind`, add after the `url` lines:

```dart
/// - color:     valueText holds `#RRGGBB`, uppercase; `normalizeEquipmentColor`
///              decides whether a stored value is a colour
```

and make the enum `enum AttributeKind { text, number, thickness, choice, flag, date, url, color }`.

2. In `enum AttributeGroup`, after `purchase`:

```dart
  /// How the item looks: its colour, which tints its artwork on the diver
  /// figure (issue #2326). Rendered as its own block of the edit form and
  /// as its own row on the detail page.
  appearance,
```

3. Add `static const color = 'color';` to `EquipmentAttrKeys`.

4. After the `purchase` list:

```dart
  /// The item's look (issue #2326), present for every type except the
  /// consumables that live inside another item and `other`, which has no
  /// artwork to tint.
  static const List<EquipmentAttributeDef> appearance = [
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.color,
      kind: AttributeKind.color,
      group: AttributeGroup.appearance,
    ),
  ];

  static const Set<EquipmentType> _noAppearance = {
    EquipmentType.o2Cell,
    EquipmentType.battery,
    EquipmentType.other,
  };
```

5. `attributesFor` and `_byKey`:

```dart
  /// Curated attributes for [type]: type-specific first, then universal,
  /// then the purchase record, then the item's appearance. Consumers that
  /// render one block at a time filter on [EquipmentAttributeDef.group].
  static List<EquipmentAttributeDef> attributesFor(EquipmentType type) => [
    ...(_byType[type] ?? const []),
    ...universal,
    ...purchase,
    if (!_noAppearance.contains(type)) ...appearance,
  ];

  static final Map<String, EquipmentAttributeDef> _byKey = {
    for (final defs in _byType.values)
      for (final def in defs) def.key: def,
    for (final def in universal) def.key: def,
    for (final def in purchase) def.key: def,
    for (final def in appearance) def.key: def,
  };
```

6. In `figure_composer.dart`, line 9 becomes:

```dart
/// The attribute key an item's own colour lives under.
const String kFigureColorAttribute = EquipmentAttrKeys.color;
```

with `import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';`. The catalog imports only `core/constants/enums.dart`, so the figure domain stays free of Flutter.

- [ ] **Step 4: Handle the kind everywhere it is switched on**

`equipment_attribute_form_section.dart`, add to `switch (def.kind)` and import `equipment_color_field.dart`:

```dart
      case AttributeKind.color:
        return EquipmentColorField(
          key: fieldKey,
          label: label,
          hex: current?.valueText,
          onChanged: (hex) =>
              onChanged(_base(def.key).copyWith(valueText: hex)),
          onCleared: () => onCleared(def.key),
        );
```

`equipment_attribute_units.dart`, add to `formatAttributeValue`'s switch and import `equipment_colors.dart` and `equipment_color_names.dart`:

```dart
    case AttributeKind.color:
      final code = normalizeEquipmentColor(attr.valueText);
      return code == null ? '' : equipmentColorName(l10n, code);
```

`equipment_attribute_l10n.dart`, in `attributeLabel` beside the purchase keys:

```dart
    'color' => l10n.attrLabel_color,
```

`csv_attribute_codec.dart`, add to `_readCurated` and import `package:submersion/features/equipment/domain/constants/equipment_colors.dart`:

```dart
    case AttributeKind.color:
      final code = normalizeEquipmentColor(value);
      // A file written before items had a colour can carry the diver's own
      // custom field named "color", unprefixed. A value that is not a colour
      // code is that field, so it comes back as one instead of being lost.
      return code == null
          ? (key: def.key, isCustom: true, valueText: value, valueNum: null)
          : (key: def.key, isCustom: false, valueText: code, valueNum: null);
```

- [ ] **Step 5: Update the exact-list tests**

In `test/features/equipment/domain/equipment_attribute_catalog_test.dart`, each of the seven lists that ends `'sku', 'retailer', 'product_url'` (the dpv, rashGuard, snorkel, tool, instrument, compass, and rebreather tests) gains `'color'` after `'product_url'`. In `test/features/equipment/domain/equipment_type_assembly_parts_test.dart`, add `...EquipmentAttributeCatalog.appearance` to the `shared` set built from `universal` and `purchase` (lines 71-73).

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment test/core/services/export/csv` and `flutter analyze`
Expected: PASS and `No issues found!` (an unhandled `AttributeKind.color` anywhere else shows here as a non-exhaustive switch).

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/figure/domain/figure_composer.dart lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart lib/features/equipment/presentation/utils/equipment_attribute_units.dart lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart lib/core/services/export/csv/codec/csv_attribute_codec.dart test/features/equipment/domain test/features/equipment/presentation/equipment_attribute_units_test.dart test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart test/core/services/export/csv/codec/csv_attribute_codec_test.dart
git commit -m "feat(equipment): an optional colour attribute on every item" -m "Part of #2326"
```

---

### Task 5: Colour on the item edit and detail pages

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart:486-500`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:644-668`, and add `_buildColorRow` beside `_buildDetailRow` (827)
- Test: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart` (the group that defines `pumpItem`, near line 905)
- Test: `test/features/equipment/presentation/equipment_edit_colour_test.dart` (new)

**Interfaces:**
- Consumes: `AttributeGroup.appearance`, `EquipmentAttrKeys.color`, `normalizeEquipmentColor`, `equipmentColorName`, `EquipmentItem.attrText(key)`, `TagColors.fromHex`.
- Produces: an appearance block on the edit form; a "Color" row with `ValueKey('detail-color-swatch')` on the detail page.

- [ ] **Step 1: Write the failing tests**

In `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`, inside the group that defines `pumpItem(tester, item, ...)`, add (importing `equipment_attribute.dart` if the file does not already):

```dart
    EquipmentItem fins({String? color}) => EquipmentItem(
      id: 'fins-color',
      name: 'Jet Fins',
      type: EquipmentType.fins,
      attributes: [
        if (color != null)
          EquipmentAttribute.curated(
            equipmentId: 'fins-color',
            key: 'color',
          ).copyWith(valueText: color),
      ],
    );

    testWidgets('shows a set colour by name with a swatch', (tester) async {
      await pumpItem(tester, fins(color: '#EF4444'));
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-color-swatch')), findsOneWidget);
    });

    testWidgets('shows no colour row for a value that is not a colour', (
      tester,
    ) async {
      await pumpItem(tester, fins(color: 'Red'));
      expect(find.byKey(const ValueKey('detail-color-swatch')), findsNothing);
      expect(find.text('Red'), findsNothing);
    });
```

If `EquipmentItem`'s constructor needs more required fields in this file's other fixtures, copy them from the nearest fixture in the same group.

`test/features/equipment/presentation/equipment_edit_colour_test.dart`, on the harness of `equipment_edit_advanced_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fins show their stored colour in the form', (tester) async {
    final created = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Jet Fins',
        type: EquipmentType.fins,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'color',
          ).copyWith(valueText: '#EF4444'),
        ],
      ),
    );
    await pumpEditor(tester, created.id);
    final field = find.byKey(const ValueKey('attr-field-color'));
    await tester.ensureVisible(field);
    expect(field, findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets('a battery has no colour field', (tester) async {
    final created = await repository.createEquipment(
      EquipmentItem(id: '', name: 'Cell pack', type: EquipmentType.battery),
    );
    await pumpEditor(tester, created.id);
    expect(find.byKey(const ValueKey('attr-field-color')), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_page_test.dart test/features/equipment/presentation/equipment_edit_colour_test.dart`
Expected: FAIL: no colour row, and no colour field on the edit page.

- [ ] **Step 3: Mount the appearance block on the edit page**

In `equipment_edit_page.dart`, directly after the spec `EquipmentAttributeFormSection(...)` (ends at line 500) and before the serial `TextFormField`:

```dart
          // The item's colour, which tints its artwork on the diver figure
          // (issue #2326). Renders nothing for the types that have none.
          EquipmentAttributeFormSection(
            key: ValueKey('appearance-${_selectedType.name}'),
            type: _selectedType,
            group: AttributeGroup.appearance,
            values: _attrValues,
            units: UnitFormatter(ref.watch(settingsProvider)),
            onChanged: (attr) => setState(() {
              _attrValues[attr.key] = attr;
              _hasChanges = true;
            }),
            onCleared: (key) => setState(() {
              _attrValues.remove(key);
              _hasChanges = true;
            }),
          ),
```

Import `equipment_attribute_catalog.dart` if the page does not already. The save loop (lines 1063-1071) keeps every `attributesFor(_selectedType)` key that has a value, so the colour saves with no further change.

- [ ] **Step 4: Add the detail row**

In `equipment_detail_page.dart`, directly after the spec-rows `for` loop (ends near line 663) and before the custom-attributes loop:

```dart
            // The item's colour (issue #2326): its own row with a swatch,
            // only when the stored value is a colour code.
            if (normalizeEquipmentColor(
                  equipment.attrText(EquipmentAttrKeys.color),
                )
                case final code?)
              _buildColorRow(context, code),
```

and beside `_buildDetailRow`:

```dart
  Widget _buildColorRow(BuildContext context, String code) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            attributeLabel(context.l10n, EquipmentAttrKeys.color),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('detail-color-swatch'),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: TagColors.fromHex(code),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                equipmentColorName(context.l10n, code),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
```

importing `equipment_colors.dart`, `equipment_color_names.dart`, and `package:submersion/features/tags/domain/entities/tag.dart`. The spec loop filters `AttributeGroup.spec`, so the colour never also shows as a raw row.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/presentation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/pages/equipment_detail_page_test.dart test/features/equipment/presentation/equipment_edit_colour_test.dart
git commit -m "feat(equipment): pick and show an item's colour" -m "Part of #2326"
```

---

### Task 6: Shared figure pieces, and the set page on them

**Files:**
- Create: `lib/features/equipment/figure/presentation/figure_selection.dart`
- Create: `lib/features/equipment/figure/presentation/figure_model_memo.dart`
- Create: `lib/features/equipment/figure/presentation/gear_figure.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` (state fields 44-64, `dispose` 68-72, `_select` 78-99, the figure card 308-337, `_composedFigure` 434-457, `_buildEquipmentTile` 461-497)
- Test: `test/features/equipment/figure/presentation/figure_model_memo_test.dart`
- Test: `test/features/equipment/figure/presentation/gear_figure_test.dart`

**Interfaces:**
- Consumes: `DiverFigure`, `FigureModel`, `PlacedItem`, `FigureView`, l10n `equipment_figure_summary/frontCount/backCount/itemLabel/trayTitle`, `EquipmentType.localizedName`.
- Produces:
  - `mixin FigureSelection<T extends StatefulWidget> on State<T>`: `String? get selectedFigureItemId`, `int get figureSelectionSerial`, `GlobalKey figureKey`, `GlobalKey figureRowKey(String id)`, `void selectFigureItem(String id, {bool revealFigure = false})`.
  - `class FigureModelMemo { FigureModel of(Object key, FigureModel Function() compose); }`.
  - `GearFigure({Key? key, required FigureModel model, required String title, String? selectedItemId, int selectionSerial = 0, ValueChanged<PlacedItem>? onItemTap})`.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/figure/presentation/figure_model_memo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';

void main() {
  test('an equal key reuses the model; a new one composes again', () {
    final memo = FigureModelMemo();
    var composed = 0;
    final list = <Object>[];
    FigureModel compose() {
      composed++;
      return composeFigure(const []);
    }

    final first = memo.of((list, 'a'), compose);
    final again = memo.of((list, 'a'), compose);
    expect(identical(first, again), isTrue);
    expect(composed, 1);
    memo.of((list, 'b'), compose);
    expect(composed, 2);
    memo.of((<Object>[], 'b'), compose);
    expect(composed, 3, reason: 'a new list is a new key');
  });
}
```

(Import `figure_model.dart` for the `FigureModel` return type.)

`test/features/equipment/figure/presentation/gear_figure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('names the picture and each item in the app language', (
    tester,
  ) async {
    final model = composeFigure(const [
      FigureItemInput(id: 'b', type: EquipmentType.bcd, name: 'Hollis SMS75'),
      FigureItemInput(id: 't', type: EquipmentType.tool, name: 'Wrench'),
    ]);
    PlacedItem? tapped;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GearFigure(
              model: model,
              title: 'Reef set',
              onItemTap: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 2 items'), findsOneWidget);
    expect(find.bySemanticsLabel('1, BCD, Hollis SMS75'), findsOneWidget);
    expect(find.text('Also carried'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('figure-label-b')));
    expect(tapped?.item.id, 'b');
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/figure/presentation/figure_model_memo_test.dart test/features/equipment/figure/presentation/gear_figure_test.dart`
Expected: FAIL, the libraries do not exist.

- [ ] **Step 3: Write the three pieces**

`lib/features/equipment/figure/presentation/figure_model_memo.dart`:

```dart
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// Keeps the last composed figure while its inputs are unchanged, so a
/// rebuild for a highlight flash reuses the same model object (and with it
/// the label layout the widget caches against it).
///
/// The key is whatever the caller's inputs compare by: a record of the item
/// list (compared by identity), the arrangement, and the locale, for
/// example.
class FigureModelMemo {
  Object? _key;
  FigureModel? _model;

  FigureModel of(Object key, FigureModel Function() compose) {
    final cached = _model;
    if (cached != null && key == _key) return cached;
    _key = key;
    return _model = compose();
  }
}
```

`lib/features/equipment/figure/presentation/figure_selection.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Selection shared by every page that shows the figure beside a list of
/// its items (spec 8.4): a tap highlights the item on the figure and in the
/// list for a moment, and scrolls the other one into view.
mixin FigureSelection<T extends StatefulWidget> on State<T> {
  String? _selectedId;
  int _serial = 0;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _rowKeys = {};

  /// Goes on the figure's card, so a badge tap can scroll it into view.
  final GlobalKey figureKey = GlobalKey();

  /// The highlighted item, cleared after a moment so the highlight reads as
  /// a flash rather than a selection mode.
  String? get selectedFigureItemId => _selectedId;

  /// Bumped on every selection, for `DiverFigure.selectionSerial`.
  int get figureSelectionSerial => _serial;

  /// The key for [id]'s row, so a figure tap can scroll the row into view.
  GlobalKey figureRowKey(String id) =>
      _rowKeys.putIfAbsent(id, GlobalKey.new);

  /// Highlights [id]. A tap on the figure brings the item's row into view;
  /// a tap on a row's badge ([revealFigure]) brings the figure into view
  /// instead, which matters on a long list whose figure has scrolled away.
  void selectFigureItem(String id, {bool revealFigure = false}) {
    _flashTimer?.cancel();
    setState(() {
      _selectedId = id;
      _serial++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _selectedId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = revealFigure
          ? figureKey.currentContext
          : _rowKeys[id]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }
}
```

`lib/features/equipment/figure/presentation/gear_figure.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [DiverFigure] with the app's strings: the summary named by [title], each
/// label read as "3, BCD, Hollis SMS75", the switch counts, and the tray
/// heading. The set page, the set edit page, and the dive card all use it.
class GearFigure extends StatelessWidget {
  const GearFigure({
    super.key,
    required this.model,
    required this.title,
    this.selectedItemId,
    this.selectionSerial = 0,
    this.onItemTap,
  });

  final FigureModel model;

  /// What the picture is of, for its screen-reader summary.
  final String title;
  final String? selectedItemId;
  final int selectionSerial;
  final ValueChanged<PlacedItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DiverFigure(
      model: model,
      semanticsLabel: l10n.equipment_figure_summary(title, model.itemCount),
      labelText: (placed) => placed.item.name,
      sideLabel: (view, count) => view == FigureView.front
          ? l10n.equipment_figure_frontCount(count)
          : l10n.equipment_figure_backCount(count),
      selectedItemId: selectedItemId,
      selectionSerial: selectionSerial,
      onItemTap: onItemTap,
      itemSemantics: (placed) => l10n.equipment_figure_itemLabel(
        placed.number,
        placed.item.type.localizedName(l10n),
        placed.item.name,
      ),
      trayTitle: l10n.equipment_figure_trayTitle,
    );
  }
}
```

- [ ] **Step 4: Move the set page onto them**

In `equipment_set_detail_page.dart`:

1. The state class becomes `class _EquipmentSetDetailPageState extends ConsumerState<EquipmentSetDetailPage> with FigureSelection<EquipmentSetDetailPage>`.
2. Delete the fields `_selectedId`, `_flashTimer`, `_rowKeys`, `_figureKey`, `_selectionSerial`, `_model`, `_modelItems`, `_modelComponents`, `_modelArrangement`, `_modelLocale`; delete `dispose()` (the mixin cancels the timer; keep it only if it disposes something else); delete `_select`. Add `final _memo = FigureModelMemo();`.
3. Replace `_composedFigure(...)` with:

```dart
  /// The composed figure, reused while its inputs are unchanged.
  FigureModel _composedFigure(
    List<EquipmentItem> ordered, {
    required List<EquipmentItem>? items,
    required ComponentsIndex components,
    required EquipmentArrangement arrangement,
    required Locale locale,
  }) => _memo.of(
    (items, components, arrangement, locale),
    () => composeFigure(figureInputsFromItems(ordered, components: components)),
  );
```

4. Replace the `DiverFigure(...)` in the figure `Card` with:

```dart
                  child: GearFigure(
                    model: model,
                    title: set.name,
                    selectedItemId: selectedFigureItemId,
                    selectionSerial: figureSelectionSerial,
                    onItemTap: (placed) => selectFigureItem(placed.item.id),
                  ),
```

and the card's `key: _figureKey` with `key: figureKey`.
5. In `_buildEquipmentTile`: `_selectedId` becomes `selectedFigureItemId`; `_rowKeys.putIfAbsent(item.id, GlobalKey.new)` becomes `figureRowKey(item.id)`; `_select(item.id, revealFigure: true)` becomes `selectFigureItem(item.id, revealFigure: true)`.
6. Remove imports this leaves unused (`dart:async`, `figure_view.dart`, `diver_figure.dart` if nothing else uses them) and add `figure_selection.dart`, `figure_model_memo.dart`, `gear_figure.dart`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/figure test/features/equipment/presentation/pages`
Expected: PASS, including every existing set page figure test unchanged: this task changes no behaviour.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/equipment/figure/presentation/figure_selection.dart lib/features/equipment/figure/presentation/figure_model_memo.dart lib/features/equipment/figure/presentation/gear_figure.dart lib/features/equipment/presentation/pages/equipment_set_detail_page.dart test/features/equipment/figure/presentation/figure_model_memo_test.dart test/features/equipment/figure/presentation/gear_figure_test.dart
git commit -m "refactor(equipment): share the figure's selection, memo and strings" -m "Part of #2326"
```

---

### Task 7: The live figure on the set edit page

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` (state class 37-48; the form's `ListView` at 153; the `data:` builder 285-368; `_buildEquipmentCheckbox` 406-445)
- Modify: `lib/l10n/arb/app_*.arb` (the `equipment_setEdit_figureSwitch_subtitle` value in 11 files) and generated `app_localizations*.dart`
- Test: `test/features/equipment/presentation/pages/equipment_set_edit_figure_test.dart` (new)

**Interfaces:**
- Consumes: `FigureSelection`, `FigureModelMemo`, `GearFigure` (Task 6); `composeFigure`, `figureInputsFromItems`; `equipmentComponentsIndexProvider`, `ComponentsIndex`; `FigureNumberBadge`, `figureHighlightFor`.
- Produces: with the form's switch on and at least one ticked item that has a checkbox row, a `GearFigure` card above the item groups (keyed `figureKey`), a `FigureNumberBadge` on each ticked row, and figure taps that scroll to and flash the row.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/presentation/pages/equipment_set_edit_figure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const mask = EquipmentItem(id: 'mask', name: 'Cressi', type: EquipmentType.mask);
  const bcd = EquipmentItem(id: 'bcd', name: 'Hollis SMS75', type: EquipmentType.bcd);
  const fins = EquipmentItem(id: 'fins', name: 'Jets', type: EquipmentType.fins);
  const retired = EquipmentItem(id: 'old', name: 'Old light', type: EquipmentType.light);

  EquipmentSet setWith({required bool showFigure}) => EquipmentSet(
    id: 'set-1',
    name: 'Reef set',
    // 'old' is a member but retired, so it has no checkbox row.
    equipmentIds: const ['mask', 'bcd', 'old'],
    items: const [mask, bcd, retired],
    showFigure: showFigure,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpPage(WidgetTester tester, {required bool showFigure}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider('set-1').overrideWith(
            (ref) async => setWith(showFigure: showFigure),
          ),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [mask, bcd, fins],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [mask, bcd, fins, retired],
          ),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWithValue(
            const AsyncValue.data(ComponentsIndex.empty),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EquipmentSetEditPage(setId: 'set-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rowOf(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(CheckboxListTile),
  );

  testWidgets('with the switch off the page has no figure and no badges', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: false);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);
  });

  testWidgets('with it on the ticked items with a row are drawn and numbered', (
    tester,
  ) async {
    await pumpPage(tester, showFigure: true);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 2 items'), findsOneWidget);
    // Two ticked rows, two badges, numbered 1..2 with no gap for the
    // retired member.
    final numbers = tester
        .widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge))
        .map((b) => b.number)
        .toList();
    expect(numbers..sort(), [1, 2]);
    expect(find.byKey(const ValueKey('figure-label-old')), findsNothing);
  });

  testWidgets('ticking an item redraws the figure at once', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(rowOf('Jets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('figure-label-fins')), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
    await tester.tap(rowOf('Cressi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('figure-label-mask')), findsNothing);
  });

  testWidgets('the switch shows and hides the figure', (tester) async {
    await pumpPage(tester, showFigure: false);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show diver figure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show diver figure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsNothing);
  });

  testWidgets('a tap on a name flashes that item\'s row', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(find.byKey(const ValueKey('figure-label-bcd')));
    await tester.pump();
    final badge = tester.widget<FigureNumberBadge>(
      find.descendant(of: rowOf('Hollis SMS75'), matching: find.byType(FigureNumberBadge)),
    );
    expect(badge.selected, isTrue);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('no ticked items means no figure', (tester) async {
    await pumpPage(tester, showFigure: true);
    await tester.tap(rowOf('Cressi'));
    await tester.tap(rowOf('Hollis SMS75'));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_edit_figure_test.dart`
Expected: FAIL: no `DiverFigure` on the edit page (the switch-off test passes already).

- [ ] **Step 3: Make every row reachable by a scroll**

The form's `ListView` builds only the rows near the screen, so a figure tap on an item far down would find no row to scroll to. In `_buildForm`, replace

```dart
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
```

with

```dart
        // A scroll view rather than a ListView, so every row is built and a
        // tap on the figure can scroll to any of them (issue #2326).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
```

and close the extra `Column(` with one more `)` after the list's closing `]`. Run the existing edit page tests before going on:

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_edit_page_test.dart test/features/equipment/presentation/equipment_set_arrangement_test.dart`
Expected: PASS.

- [ ] **Step 4: Compose the figure and number the rows**

1. The state class becomes `class _EquipmentSetEditPageState extends ConsumerState<EquipmentSetEditPage> with FigureSelection<EquipmentSetEditPage>`, with a new field `final _memo = FigureModelMemo();`.

2. In the `data:` builder, after `labels` is computed, replace `return Column(children: groups.map(...).toList());` with:

```dart
                // The live figure (issue #2326): the ticked items that have
                // a row here, in the order the page lists them, so its
                // numbers run down the rows. A retired member has no row, so
                // it is not drawn. Parts wait for the components index, as
                // on the set page.
                final ordered = [
                  for (final group in groups)
                    for (final item in group.items)
                      if (_selectedEquipmentIds.contains(item.id)) item,
                ];
                final componentsAsync = ref.watch(
                  equipmentComponentsIndexProvider,
                );
                final components = componentsAsync.hasError
                    ? ComponentsIndex.empty
                    : componentsAsync.value;
                final model =
                    _showFigure && components != null && ordered.isNotEmpty
                    ? _memo.of(
                        (
                          equipment,
                          [for (final item in ordered) item.id].join('|'),
                          components,
                          ref.watch(equipmentArrangementProvider),
                          Localizations.localeOf(context),
                        ),
                        () => composeFigure(
                          figureInputsFromItems(
                            ordered,
                            components: components,
                          ),
                        ),
                      )
                    : null;
                final numberById = model == null
                    ? const <String, int>{}
                    : {for (final p in model.numbered) p.item.id: p.number};
                final name = _nameController.text.trim();

                return Column(
                  children: [
                    if (model != null) ...[
                      Card(
                        key: figureKey,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: GearFigure(
                            model: model,
                            title: name.isEmpty
                                ? context.l10n.equipment_setEdit_appBar_newTitle
                                : name,
                            selectedItemId: selectedFigureItemId,
                            selectionSerial: figureSelectionSerial,
                            onItemTap: (placed) =>
                                selectFigureItem(placed.item.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final group in groups)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group.type != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: EquipmentGroupHeader(type: group.type!),
                              ),
                            for (final item in group.items)
                              _buildEquipmentCheckbox(
                                context,
                                item,
                                labels,
                                numberById[item.id],
                              ),
                          ],
                        ),
                      ),
                  ],
                );
```

3. `_buildEquipmentCheckbox` gains the number:

```dart
  /// One row of the picker. [number] is the item's figure number while the
  /// figure shows; it leads the row as a badge that brings the figure into
  /// view.
  Widget _buildEquipmentCheckbox(
    BuildContext context,
    EquipmentItem item,
    Map<String, EquipmentRowLabel> labels,
    int? number,
  ) {
    final isSelected = _selectedEquipmentIds.contains(item.id);
    final scheme = Theme.of(context).colorScheme;
    final flashing = number != null && item.id == selectedFigureItemId;
    final highlight = flashing ? figureHighlightFor(scheme) : null;
    final icon = Icon(
      equipmentTypeIcon(item.type),
      color: highlight?.onFill ?? scheme.onSurfaceVariant,
    );

    return KeyedSubtree(
      key: figureRowKey(item.id),
      child: ListTileTheme.merge(
        textColor: highlight?.onFill,
        iconColor: highlight?.onFill,
        child: CheckboxListTile(
          tileColor: highlight?.fill,
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedEquipmentIds.add(item.id);
              } else {
                _selectedEquipmentIds.remove(item.id);
              }
            });
          },
          title: Text(item.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              switch (labels[item.id]?.subtitle) {
                final detail? => Text(detail),
                null => const SizedBox.shrink(),
              },
              ServiceStatusIndicatorFor(
                equipmentId: item.id,
                density: ServiceIndicatorDensity.compact,
              ),
            ],
          ),
          secondary: number == null
              ? icon
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FigureNumberBadge(
                      number: number,
                      selected: flashing,
                      onTap: () =>
                          selectFigureItem(item.id, revealFigure: true),
                    ),
                    const SizedBox(width: 8),
                    icon,
                  ],
                ),
          controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }
```

4. Imports to add: `figure_selection.dart`, `figure_model_memo.dart`, `gear_figure.dart`, `figure_number_badge.dart`, `figure_palette_theme.dart`, `package:submersion/features/equipment/figure/domain/figure_composer.dart`, `package:submersion/features/equipment/figure/domain/figure_inputs.dart`, `equipment_component_providers.dart`.

- [ ] **Step 5: Reword the switch's subtitle**

The switch no longer only draws on the set page. With the Task 2 script's `insert_after` swapped for a replace, set `equipment_setEdit_figureSwitch_subtitle` in each file:

| Locale | Value |
| --- | --- |
| en | `Draw this set's gear on a diver` |
| de | `Die Ausrüstung dieses Sets an einem Taucher zeigen` |
| es | `Mostrar el equipo de este conjunto sobre un buceador` |
| fr | `Représenter l’équipement de ce jeu sur un plongeur` |
| it | `Mostra l’attrezzatura di questo set su un subacqueo` |
| nl | `De uitrusting van deze set op een duiker tonen` |
| pt | `Mostrar o equipamento deste conjunto num mergulhador` |
| hu | `A készlet felszerelésének megjelenítése egy búváron` |
| ar | `عرض معدات هذه المجموعة على غوّاص` |
| he | `הצגת הציוד של הערכה על צוללן` |
| zh | `在潜水员图上显示此套装的装备` |

The replace is one line per file: find the line starting `  "equipment_setEdit_figureSwitch_subtitle":` and write `  "equipment_setEdit_figureSwitch_subtitle": <json-encoded value>,`. Then `flutter gen-l10n`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/presentation`
Expected: PASS. If `equipment_set_edit_page_test.dart` asserts the old subtitle text, update that expectation to the new English value.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/pages/equipment_set_edit_page.dart lib/l10n/arb test/features/equipment/presentation/pages/equipment_set_edit_figure_test.dart
git commit -m "feat(equipment): the live diver figure on the set edit page" -m "Part of #2326"
```

---

### Task 8: The dive figure switch: column, settings, sync

**Files:**
- Modify: `lib/core/database/database.dart` (the `DiverSettings` table near `showDataSourceBadges` at 2440; `currentSchemaVersion`; `migrationVersions`; a new helper beside the v229 helper; the onUpgrade ladder; `beforeOpen`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (create 222, update 422, map 652)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field near 490, constructor near 682, copyWith near 862 and 1042, setter near 2224)
- Modify: `test/helpers/mock_providers.dart` (near 593), `test/features/settings/presentation/pages/settings_page_test.dart` (near 587), `test/features/settings/presentation/pages/settings_page_shared_data_test.dart` (near 665), `test/features/insights/presentation/pages/records_page_test.dart` (near 550)
- Modify: the previous newest migration test's exact version assertion (Step 5)
- Test: `test/core/database/migration_v237_show_dive_figure_test.dart` (new)
- Test: `test/features/settings/data/repositories/diver_settings_repository_show_dive_figure_test.dart` (new)
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart`
- Test: `test/core/services/sync/sync_diver_settings_fallback_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `AppSettings.showDiveFigure` (bool, default false), `SettingsNotifier.setShowDiveFigure(bool)`, column `diver_settings.show_dive_figure INTEGER NOT NULL DEFAULT 0`, `AppDatabase.currentSchemaVersion == 237`.

- [ ] **Step 1: Write the failing tests**

`test/core/database/migration_v237_show_dive_figure_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v237 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 237);
    expect(AppDatabase.migrationVersions, contains(237));
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the switch, off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'show_dive_figure',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), contains('0'));
  });

  test('a database stranded before v237 gains the column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('show_dive_figure'));
  });
}
```

`test/features/settings/data/repositories/diver_settings_repository_show_dive_figure_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the dive figure is off by default and copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.showDiveFigure, isFalse);
    expect(settings.copyWith(showDiveFigure: true).showDiveFigure, isTrue);
  });

  group('DiverSettingsRepository dive figure persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start with the dive figure off', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showDiveFigure, isFalse);
    });

    test('turning it on round-trips', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showDiveFigure: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showDiveFigure, isTrue);
    });
  });
}
```

In `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, beside the `setShowDataSourceBadges toggles value` test:

```dart
    test('setShowDiveFigure toggles value', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      expect(container.read(settingsProvider).showDiveFigure, isFalse);
      await container.read(settingsProvider.notifier).setShowDiveFigure(true);
      expect(container.read(settingsProvider).showDiveFigure, isTrue);
    });
```

In `test/core/services/sync/sync_diver_settings_fallback_test.dart`, after the pre-v231 test:

```dart
  test(
    'applies a pre-v237 diver_settings payload missing the dive figure switch',
    () async {
      // No hand-written seed covers it (issue #2326): the Drift column
      // default fills it through _withSchemaDefaults, so it lands off.
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds-236',
              diverId: 'diver-1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds-236');
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('showDiveFigure');
      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-236'))).go();

      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-236'))).getSingle();
      expect(row.showDiveFigure, isFalse);
    },
  );
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/database/migration_v237_show_dive_figure_test.dart test/features/settings/data/repositories/diver_settings_repository_show_dive_figure_test.dart`
Expected: FAIL to compile: `showDiveFigure` does not exist.

- [ ] **Step 3: Add the column and its rung**

In `database.dart`:

1. In `DiverSettings`, after `showDataSourceBadges`:

```dart
  // v237: the diver figure in the dive detail equipment card (issue #2326),
  // off by default for every diver.
  BoolColumn get showDiveFigure =>
      boolean().withDefault(const Constant(false))();
```

2. `static const int currentSchemaVersion = 237;`

3. At the end of `migrationVersions`:

```dart
    // v237: diver_settings.show_dive_figure, the diver-wide switch for the
    // figure in the dive detail equipment card (issue #2326). Additive,
    // default off, no backfill, so the floor stays at 224.
    237,
```

4. Beside `_assertEquipmentSetShowFigureColumn`:

```dart
  /// v237: diver_settings.show_dive_figure (issue #2326). Additive, not
  /// null, default 0, so the dive figure starts off for every diver, new
  /// and existing. Idempotent, so it is safe to call from both onUpgrade
  /// and the beforeOpen backstop.
  Future<void> _assertShowDiveFigureColumn() => _addColumnIfMissing(
    'diver_settings',
    'show_dive_figure',
    'INTEGER NOT NULL DEFAULT 0',
  );
```

5. At the end of `onUpgrade`'s rungs:

```dart
        // v237: diver_settings.show_dive_figure (issue #2326). Column-only
        // rung, default off, no backfill.
        if (from < 237) {
          await _assertShowDiveFigureColumn();
        }
        if (from < 237) await reportProgress();
```

6. In `beforeOpen`, beside the v229 backstop:

```dart
        // v237 backstop: the dive figure switch.
        await _assertShowDiveFigureColumn();
```

Then `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Thread the setting through**

`settings_providers.dart`:

```dart
  /// Draw the dive's gear on the diver figure in the dive detail equipment
  /// card (issue #2326). Off by default.
  final bool showDiveFigure;
```

beside `showDataSourceBadges`; `this.showDiveFigure = false,` in the constructor; `bool? showDiveFigure,` in `copyWith`'s parameters and `showDiveFigure: showDiveFigure ?? this.showDiveFigure,` in its body; and beside `setShowDataSourceBadges`:

```dart
  Future<void> setShowDiveFigure(bool value) async {
    state = state.copyWith(showDiveFigure: value);
    await _saveSettings();
  }
```

`diver_settings_repository.dart`: `showDiveFigure: Value(s.showDiveFigure),` in `createSettingsForDiver`'s companion beside `showDataSourceBadges`; `showDiveFigure: Value(settings.showDiveFigure),` in `updateSettingsForDiver`'s; `showDiveFigure: row.showDiveFigure,` in `_mapRowToAppSettings`.

The four fakes that implement `SettingsNotifier` without `noSuchMethod` each gain, beside their `setShowDataSourceBadges` override:

```dart
  @override
  Future<void> setShowDiveFigure(bool value) async =>
      state = state.copyWith(showDiveFigure: value);
```

(`test/helpers/mock_providers.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`, `test/features/insights/presentation/pages/records_page_test.dart`; match each file's existing override style.)

No sync seed is needed: `_withSchemaDefaults` fills a missing not-null column that has a constant default, as the v231 fallback test shows.

- [ ] **Step 5: Relax the previous newest rung's exact assertion**

```bash
git grep -n "expect(AppDatabase.currentSchemaVersion, [0-9]" -- test/core/database
```

Every hit other than the new v237 test changes to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(N));` with its own N. If that test also pins `migrationStepCount(N - 1), 1`, keep it: it still holds.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/database test/core/services/sync/sync_diver_settings_fallback_test.dart test/features/settings test/features/insights/presentation/pages/records_page_test.dart` and `flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core/database/database.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/features/settings/presentation/providers/settings_providers.dart test/helpers/mock_providers.dart test/features/settings test/features/insights/presentation/pages/records_page_test.dart test/core/database test/core/services/sync/sync_diver_settings_fallback_test.dart
git commit -m "feat(settings): a diver-wide switch for the dive figure, off by default" -m "Part of #2326"
```

---

### Task 9: The switch in Settings

**Files:**
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (`_buildDiveDetailsSettings`, 604-619)
- Modify: `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart`
- Test: `test/features/settings/presentation/pages/section_appearance_page_test.dart`

**Interfaces:**
- Consumes: `AppSettings.showDiveFigure`, `SettingsNotifier.setShowDiveFigure`.
- Produces: a `SwitchListTile` titled `settings_appearance_showDiveFigure` under Settings > Appearance > Dives > Dive Details; l10n `settings_appearance_showDiveFigure`, `settings_appearance_showDiveFigure_subtitle`, `diveLog_detail_gearFigureName`.

- [ ] **Step 1: Write the failing test**

In `section_appearance_page_test.dart`, in the Dives group:

```dart
    testWidgets('the dive figure switch is under Dive Details, off, and saves', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = MockSettingsNotifier();

      await tester.pumpWidget(
        _buildTestWidget(
          'dives',
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        SwitchListTile,
        'Show diver figure on dives',
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(notifier.state.showDiveFigure, isTrue);
    });
```

The harness lists its own `settingsProvider` override first and then `overrides`; Riverpod rejects two overrides of one provider, so if this test fails with that error, give `_buildTestWidget` an optional `MockSettingsNotifier? notifier` parameter used as `settingsProvider.overrideWith((ref) => notifier ?? MockSettingsNotifier())` and pass `notifier: notifier` instead.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart`
Expected: FAIL, no such switch.

- [ ] **Step 3: Add the strings**

With the Task 2 script's `insert_after` (anchor `settings_appearance_showDataSourceBadges_subtitle`), add to each locale:

| Locale | `settings_appearance_showDiveFigure` | `settings_appearance_showDiveFigure_subtitle` | `diveLog_detail_gearFigureName` |
| --- | --- | --- | --- |
| en | Show diver figure on dives | Draw each dive's gear on a diver in its equipment card | Gear on this dive |
| de | Taucherfigur bei Tauchgängen zeigen | Die Ausrüstung jedes Tauchgangs in seiner Ausrüstungskarte an einem Taucher zeigen | Ausrüstung dieses Tauchgangs |
| es | Mostrar la figura del buceador en las inmersiones | Mostrar el equipo de cada inmersión sobre un buceador en su tarjeta de equipo | Equipo de esta inmersión |
| fr | Afficher la silhouette du plongeur sur les plongées | Représenter l’équipement de chaque plongée sur un plongeur dans sa carte Équipement | Équipement de cette plongée |
| it | Mostra la figura del subacqueo nelle immersioni | Mostra l’attrezzatura di ogni immersione su un subacqueo nella scheda Attrezzatura | Attrezzatura di questa immersione |
| nl | Duikerfiguur bij duiken tonen | De uitrusting van elke duik op een duiker tonen in de uitrustingskaart | Uitrusting van deze duik |
| pt | Mostrar a figura do mergulhador nos mergulhos | Mostrar o equipamento de cada mergulho num mergulhador no cartão de equipamento | Equipamento deste mergulho |
| hu | Búváralak megjelenítése a merüléseknél | Minden merülés felszerelésének megjelenítése egy búváron a felszerelés kártyán | A merülés felszerelése |
| ar | إظهار شكل الغوّاص في الغطسات | عرض معدات كل غطسة على غوّاص في بطاقة المعدات | معدات هذه الغطسة |
| he | הצגת דמות הצוללן בצלילות | הצגת הציוד של כל צלילה על צוללן בכרטיס הציוד | הציוד בצלילה זו |
| zh | 在潜水记录中显示潜水员图 | 在装备卡片中将每次潜水的装备显示在潜水员图上 | 本次潜水的装备 |

Then `flutter gen-l10n`.

- [ ] **Step 4: Add the switch**

In `_buildDiveDetailsSettings`, after the section-order `ListTile`:

```dart
      // The diver figure in the equipment card (issue #2326), off by
      // default so the dive page is unchanged until the diver opts in.
      SwitchListTile(
        secondary: const Icon(Icons.accessibility_new),
        title: Text(context.l10n.settings_appearance_showDiveFigure),
        subtitle: Text(
          context.l10n.settings_appearance_showDiveFigure_subtitle,
        ),
        value: ref.watch(settingsProvider.select((s) => s.showDiveFigure)),
        onChanged: (value) =>
            ref.read(settingsProvider.notifier).setShowDiveFigure(value),
      ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart test/l10n`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/pages/section_appearance_page.dart lib/l10n/arb test/features/settings/presentation/pages/section_appearance_page_test.dart
git commit -m "feat(settings): the dive figure switch under dive details" -m "Part of #2326"
```

---

### Task 10: Composer inputs for a dive

**Files:**
- Modify: `lib/features/equipment/figure/domain/figure_inputs.dart` (extract `figureAttributesOf`)
- Create: `lib/features/dive_log/domain/services/dive_figure_inputs.dart`
- Test: `test/features/dive_log/domain/services/dive_figure_inputs_test.dart`

**Interfaces:**
- Consumes: `GearTree.build`, `arrangeEquipment`, `EquipmentGroup`, `EquipmentArrangement`, `DiveTank` (`equipmentId`, `role`, `order`), `FigureItemInput`.
- Produces:
  - `Map<String, String?> figureAttributesOf(EquipmentItem item)` (in `figure_inputs.dart`): the item's catalog attributes by key.
  - `List<EquipmentGroup> arrangedDiveGear(List<GearLink> links, EquipmentArrangement arrangement, {required String Function(EquipmentType) typeLabel})`: the top-level rows in the tree's order.
  - `Map<String, TankRole> tankRolesByItem(List<DiveTank> tanks)`: first tank by `order` wins.
  - `List<FigureItemInput> figureInputsForDive(List<EquipmentItem> topLevel, Map<String, TankRole> tankRoles)`: every row numbered (none is a child), tanks carrying their role.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_log/domain/services/dive_figure_inputs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_figure_inputs.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

void main() {
  const reg = EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator);
  const hose = EquipmentItem(id: 'hose', name: 'Hose', type: EquipmentType.hose);
  const left = EquipmentItem(id: 'left', name: 'Left tank', type: EquipmentType.tank);
  const stage = EquipmentItem(id: 'stage', name: 'Stage', type: EquipmentType.tank);
  final flat = EquipmentArrangement.defaults.copyWith(groupByType: false);
  String label(EquipmentType t) => t.name;

  test('only top-level rows, in the arranged order', () {
    final links = gearLinksFor(const [reg, hose, left], const [
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
    ]);
    final ordered = [
      for (final g in arrangedDiveGear(links, flat, typeLabel: label)) ...g.items,
    ];
    expect(ordered.map((i) => i.id), isNot(contains('hose')));
    expect(ordered.map((i) => i.id).toSet(), {'reg', 'left'});
  });

  test('the first linked tank by order gives the role', () {
    final roles = tankRolesByItem(const [
      DiveTank(id: 't2', order: 1, equipmentId: 'left', role: TankRole.backGas),
      DiveTank(id: 't1', order: 0, equipmentId: 'left', role: TankRole.sidemountLeft),
      DiveTank(id: 't3', order: 2, role: TankRole.stage),
      DiveTank(id: 't4', order: 3, equipmentId: 'stage', role: TankRole.stage),
    ]);
    expect(roles, {'left': TankRole.sidemountLeft, 'stage': TankRole.stage});
  });

  test('roles place tanks, and every row is numbered', () {
    final model = composeFigure(
      figureInputsForDive(const [reg, left, stage], const {
        'left': TankRole.sidemountLeft,
        'stage': TankRole.stage,
        'ghost': TankRole.deco,
      }),
    );
    expect(model.itemCount, 3);
    expect(model.byId('left')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('stage')!.zone, anyOf(FigureZone.stageLeft, FigureZone.stageRight));
    expect(model.byId('ghost'), isNull, reason: 'a tank not in the gear is not drawn');
  });

  test('a top-level row with a parent link is still numbered on a dive', () {
    // The tree promotes an orphaned part to the top level; the figure must
    // number it too, or its badge and label would disagree.
    const orphan = EquipmentItem(
      id: 'orphan',
      name: 'Second stage',
      type: EquipmentType.secondStage,
      parentEquipmentId: 'missing',
    );
    final model = composeFigure(figureInputsForDive(const [orphan], const {}));
    expect(model.itemCount, 1);
  });
}
```

If `EquipmentItem`'s constructor names the parent link differently than `parentEquipmentId`, use its real name (`figureInputsFromItems` reads it as `item.parentEquipmentId`).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/domain/services/dive_figure_inputs_test.dart`
Expected: FAIL, the library does not exist.

- [ ] **Step 3: Extract the attribute map**

In `figure_inputs.dart`, add and use it inside `figureInputsFromItems`:

```dart
/// An item's catalog attribute values by key: choice keys and its colour.
/// Custom attributes are dropped; the figure reads only catalog keys.
Map<String, String?> figureAttributesOf(EquipmentItem item) => {
  for (final a in item.attributes)
    if (!a.isCustom) a.key: a.valueText,
};
```

- [ ] **Step 4: Write the dive helpers**

`lib/features/dive_log/domain/services/dive_figure_inputs.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// A dive's top-level gear rows as the gear tree shows them: parts sit
/// inside their assembly's row, and the rows follow the diver's
/// arrangement. The tree and the dive figure both read this, so the
/// figure's numbers run down the tree's rows.
List<EquipmentGroup> arrangedDiveGear(
  List<GearLink> links,
  EquipmentArrangement arrangement, {
  required String Function(EquipmentType) typeLabel,
}) => arrangeEquipment(
  [for (final node in GearTree.build(links)) node.link.item],
  arrangement,
  typeLabel: typeLabel,
);

/// The dive-tank role of each gear item a dive tank is linked to
/// (`dive_tanks.equipment_id`). On a dive logged from several computers two
/// tanks can name the same item; the first by `order` wins.
Map<String, TankRole> tankRolesByItem(List<DiveTank> tanks) {
  final sorted = [...tanks]..sort((a, b) => a.order.compareTo(b.order));
  final roles = <String, TankRole>{};
  for (final tank in sorted) {
    final id = tank.equipmentId;
    if (id != null) roles.putIfAbsent(id, () => tank.role);
  }
  return roles;
}

/// Composer inputs for a dive's [topLevel] rows, in that order. Every row is
/// numbered, even one the tree promoted from an orphaned part, so each row's
/// badge has a label; a tank carries its dive role from [tankRoles].
List<FigureItemInput> figureInputsForDive(
  List<EquipmentItem> topLevel,
  Map<String, TankRole> tankRoles,
) => [
  for (final item in topLevel)
    FigureItemInput(
      id: item.id,
      type: item.type,
      name: item.name,
      attributes: figureAttributesOf(item),
      tankRole: tankRoles[item.id],
    ),
];
```

(`DiveTank` is defined in `dive.dart`; `dive_log/domain/services` may import Flutter-dependent code, unlike the figure's domain.)

- [ ] **Step 5: Use the shared order in the tree**

In `dive_gear_tree_view.dart`, replace the `arrangeEquipment([for (final n in roots) n.link.item], arrangement, typeLabel: ...)` call in `build` with `arrangedDiveGear(widget.links, arrangement, typeLabel: (type) => type.localizedName(l10n))`, importing `dive_figure_inputs.dart`. Keep `roots` and `rootsById` for `_rows`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/domain/services/dive_figure_inputs_test.dart test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart test/features/equipment/figure`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment/figure/domain/figure_inputs.dart lib/features/dive_log/domain/services/dive_figure_inputs.dart lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart test/features/dive_log/domain/services/dive_figure_inputs_test.dart
git commit -m "feat(dive-log): composer inputs for a dive's gear, with tank roles" -m "Part of #2326"
```

---

### Task 11: Number badges on the dive gear tree

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart` (fields 41-66, `_rows` 138-253)
- Test: `test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`

**Interfaces:**
- Consumes: `FigureNumberBadge`, `figureHighlightFor`.
- Produces: optional `DiveGearTreeView` parameters `Map<String, int> figureNumbers = const {}`, `String? selectedItemId`, `void Function(String itemId)? onNumberTap`, `Key? Function(String itemId)? rowKey`. A top-level row with a number gets a leading badge; a part never does; with none of them passed the tree is unchanged.

- [ ] **Step 1: Write the failing tests**

In `dive_gear_tree_view_test.dart`, give `build` the parameters `Map<String, int> figureNumbers = const {}`, `String? selectedItemId`, `void Function(String)? onNumberTap`, and pass them to `DiveGearTreeView`. Import `figure_number_badge.dart`. Then add:

```dart
  testWidgets('without figure numbers there are no badges', (tester) async {
    await tester.pumpWidget(build(arrangement: flat));
    await tester.pumpAndSettle();
    expect(find.byType(FigureNumberBadge), findsNothing);
  });

  testWidgets('top-level rows carry their figure number; parts do not', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        arrangement: flat,
        figureNumbers: const {'mask': 1, 'reg': 2, 'fins': 3, 'hose': 9},
      ),
    );
    await tester.pumpAndSettle();
    final numbers = tester
        .widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge))
        .map((b) => b.number)
        .toSet();
    expect(numbers, {1, 2, 3});
  });

  testWidgets('a badge tap reports its item, and the selected badge shows', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      build(
        arrangement: flat,
        figureNumbers: const {'mask': 1, 'reg': 2, 'fins': 3},
        selectedItemId: 'fins',
        onNumberTap: (id) => tapped = id,
      ),
    );
    await tester.pumpAndSettle();
    final badges = tester.widgetList<FigureNumberBadge>(
      find.byType(FigureNumberBadge),
    );
    expect(badges.singleWhere((b) => b.selected).number, 3);
    await tester.tap(
      find.byWidgetPredicate((w) => w is FigureNumberBadge && w.number == 1),
    );
    expect(tapped, 'mask');
  });
```

(The file's `links` put the hose under the reg, so the hose is a part; that is why its number 9 never shows.)

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart`
Expected: FAIL to compile, the parameters do not exist.

- [ ] **Step 3: Add the parameters and the badge**

Fields and constructor:

```dart
  /// The diver figure's number for each item on it (issue #2326). A
  /// top-level row whose item has one leads with its badge; parts never
  /// do. Empty, the default, when the figure is not shown.
  final Map<String, int> figureNumbers;

  /// The item flashing on the figure, highlighted here too.
  final String? selectedItemId;

  /// A badge tap, which brings the figure into view.
  final void Function(String itemId)? onNumberTap;

  /// A key for a top-level row, so a tap on the figure can scroll to it.
  final Key? Function(String itemId)? rowKey;
```

with `this.figureNumbers = const {}, this.selectedItemId, this.onNumberTap, this.rowKey,` in the constructor.

In `_rows`, before `return [`:

```dart
    final number = depth == 0 ? widget.figureNumbers[item.id] : null;
    final flashing = number != null && item.id == widget.selectedItemId;
    final highlight = flashing ? figureHighlightFor(theme.colorScheme) : null;
    final avatar = CircleAvatar(
      backgroundColor: theme.colorScheme.tertiaryContainer,
      child: Icon(
        equipmentTypeIcon(item.type),
        color: theme.colorScheme.onTertiaryContainer,
        size: 20,
      ),
    );
```

and in the first `Padding`/`ListTile`:

```dart
      Padding(
        key: depth == 0 ? widget.rowKey?.call(item.id) : null,
        padding: EdgeInsets.only(left: 24.0 * depth),
        child: ListTile(
          key: ValueKey('gear-row-${item.id}'),
          contentPadding: EdgeInsets.zero,
          tileColor: highlight?.fill,
          textColor: highlight?.onFill,
          iconColor: highlight?.onFill,
          leading: number == null
              ? avatar
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FigureNumberBadge(
                      number: number,
                      selected: flashing,
                      onTap: widget.onNumberTap == null
                          ? null
                          : () => widget.onNumberTap!(item.id),
                    ),
                    const SizedBox(width: 8),
                    avatar,
                  ],
                ),
```

keeping the rest of the `ListTile` as it is. Import `figure_number_badge.dart` and `figure_palette_theme.dart`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_log/presentation/widgets test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart test/features/dive_log/presentation/pages/dive_detail_equipment_arrangement_test.dart`
Expected: PASS, the dive edit page's tree included (it passes none of the new parameters).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/dive_gear_tree_view.dart test/features/dive_log/presentation/widgets/dive_gear_tree_view_test.dart
git commit -m "feat(dive-log): figure number badges on the dive gear tree" -m "Part of #2326"
```

---

### Task 12: The figure in the dive equipment card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_gear_with_figure.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4800-4848` (`_buildEquipmentSection`'s `contentBuilder`)
- Test: `test/features/dive_log/presentation/widgets/dive_gear_with_figure_test.dart` (new)
- Test: `test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart`

**Interfaces:**
- Consumes: `arrangedDiveGear`, `tankRolesByItem`, `figureInputsForDive` (Task 10); the tree's new parameters (Task 11); `FigureSelection`, `FigureModelMemo`, `GearFigure` (Task 6); `AppSettings.showDiveFigure` (Task 8); l10n `diveLog_detail_gearFigureName` (Task 9).
- Produces: `DiveGearWithFigure({Key? key, required Dive dive, required bool showFigure, required bool showServiceStatus, void Function(EquipmentItem)? onTap, Widget Function(EquipmentItem)? rowTrailing})`: the tree alone when `showFigure` is false or the dive has no gear, otherwise the figure above the badged tree.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_log/presentation/widgets/dive_gear_with_figure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_with_figure.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const mask = EquipmentItem(id: 'mask', name: 'Cressi', type: EquipmentType.mask);
  const tank = EquipmentItem(id: 'tank', name: 'Left AL80', type: EquipmentType.tank);
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 7,
    dateTime: DateTime(2026, 3, 28, 10),
    notes: '',
    gear: looseGear(const [mask, tank]),
    tanks: const [
      DiveTank(id: 't1', equipmentId: 'tank', role: TankRole.sidemountLeft),
    ],
  );

  Future<void> pump(WidgetTester tester, {required bool showFigure, Dive? of}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentSetsProvider.overrideWith((ref) async => const []),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
          activeComponentIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiveGearWithFigure(
                dive: of ?? dive,
                showFigure: showFigure,
                showServiceStatus: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off, it is the tree alone', (tester) async {
    await pump(tester, showFigure: false);
    expect(find.byType(DiveGearTreeView), findsOneWidget);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);
  });

  testWidgets('on, the figure sits above the tree and the numbers match', (
    tester,
  ) async {
    await pump(tester, showFigure: true);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.bySemanticsLabel('Gear on this dive, 2 items'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(DiverFigure)).dy,
      lessThan(tester.getTopLeft(find.byType(DiveGearTreeView)).dy),
    );
    final badgeNumbers = tester
        .widgetList<FigureNumberBadge>(
          find.descendant(
            of: find.byType(DiveGearTreeView),
            matching: find.byType(FigureNumberBadge),
          ),
        )
        .map((b) => b.number)
        .toSet();
    expect(badgeNumbers, {1, 2});
  });

  testWidgets('a linked tank is drawn where its role puts it', (tester) async {
    await pump(tester, showFigure: true);
    // A sidemount tank labels on the back view; the wide layout shows both.
    expect(find.byKey(const ValueKey('figure-label-tank')), findsOneWidget);
  });

  testWidgets('a tap on a name flashes that row', (tester) async {
    await pump(tester, showFigure: true);
    await tester.tap(find.byKey(const ValueKey('figure-label-mask')));
    await tester.pump();
    final selected = tester
        .widgetList<FigureNumberBadge>(
          find.descendant(
            of: find.byType(DiveGearTreeView),
            matching: find.byType(FigureNumberBadge),
          ),
        )
        .where((b) => b.selected);
    expect(selected.single.number, 1);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('on, a dive with no gear shows no figure and does not throw', (
    tester,
  ) async {
    await pump(
      tester,
      showFigure: true,
      of: Dive(id: 'empty', dateTime: DateTime(2026), notes: '', gear: const []),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DiverFigure), findsNothing);
  });
}
```

If `Dive`'s constructor requires more fields than `dive_detail_gear_tree_test.dart` passes, copy that file's construction.

In `test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart`, add a page-level test that the switch reaches the card. Give `buildDetail` an optional `bool showDiveFigure = false` and build the overrides with `...await getBaseOverrides(settingsNotifier: MockSettingsNotifier(AppSettings(showDiveFigure: showDiveFigure)))` in place of `...base` (import `settings_providers.dart` and the figure widget), then:

```dart
  testWidgets('the diver-wide switch puts the figure in the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await buildDetail(showDiveFigure: true));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsOneWidget);
  });

  testWidgets('with the switch off the card has no figure', (tester) async {
    await open(tester);
    expect(find.byType(DiverFigure), findsNothing);
  });
```

If `getBaseOverrides` names its parameter differently, read its signature in `test/helpers/mock_providers.dart` and use that.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_gear_with_figure_test.dart`
Expected: FAIL, the widget does not exist.

- [ ] **Step 3: Write the widget**

`lib/features/dive_log/presentation/widgets/dive_gear_with_figure.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_figure_inputs.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_selection.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive detail equipment card's content: the gear tree, and above it
/// the diver figure when [showFigure] is on (spec section 11). The figure
/// is drawn from the tree's top-level rows in the tree's order, so its
/// numbers run down the rows, and a tap on either side flashes the other.
class DiveGearWithFigure extends ConsumerStatefulWidget {
  const DiveGearWithFigure({
    super.key,
    required this.dive,
    required this.showFigure,
    required this.showServiceStatus,
    this.onTap,
    this.rowTrailing,
  });

  final Dive dive;

  /// The diver-wide switch (`AppSettings.showDiveFigure`).
  final bool showFigure;
  final bool showServiceStatus;
  final void Function(EquipmentItem item)? onTap;
  final Widget Function(EquipmentItem item)? rowTrailing;

  @override
  ConsumerState<DiveGearWithFigure> createState() => _DiveGearWithFigureState();
}

class _DiveGearWithFigureState extends ConsumerState<DiveGearWithFigure>
    with FigureSelection<DiveGearWithFigure> {
  final _memo = FigureModelMemo();

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final arrangement = ref.watch(equipmentArrangementProvider);
    final locale = Localizations.localeOf(context);
    final model = widget.showFigure && dive.gear.isNotEmpty
        ? _memo.of(
            (dive.gear, dive.tanks, arrangement, locale),
            () => composeFigure(
              figureInputsForDive(
                [
                  for (final group in arrangedDiveGear(
                    dive.gear,
                    arrangement,
                    typeLabel: (type) => type.localizedName(context.l10n),
                  ))
                    ...group.items,
                ],
                tankRolesByItem(dive.tanks),
              ),
            ),
          )
        : null;
    final tree = DiveGearTreeView(
      links: dive.gear,
      showServiceStatus: widget.showServiceStatus,
      onTap: widget.onTap,
      rowTrailing: widget.rowTrailing,
      figureNumbers: model == null
          ? const {}
          : {for (final p in model.numbered) p.item.id: p.number},
      selectedItemId: selectedFigureItemId,
      onNumberTap: model == null
          ? null
          : (id) => selectFigureItem(id, revealFigure: true),
      rowKey: model == null ? null : figureRowKey,
    );
    if (model == null) return tree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: figureKey,
          child: GearFigure(
            model: model,
            title: context.l10n.diveLog_detail_gearFigureName,
            selectedItemId: selectedFigureItemId,
            selectionSerial: figureSelectionSerial,
            onItemTap: (placed) => selectFigureItem(placed.item.id),
          ),
        ),
        const SizedBox(height: 16),
        tree,
      ],
    );
  }
}
```

Note the record key: `dive.gear` and `dive.tanks` compare by identity, so a refreshed dive (a new object from the provider) recomposes, while a highlight flash reuses the model.

- [ ] **Step 4: Use it in the dive card**

In `dive_detail_page.dart`'s `_buildEquipmentSection`, the `contentBuilder` becomes:

```dart
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // The tree, and the diver figure above it when the diver has turned
        // it on (issue #2326).
        child: DiveGearWithFigure(
          dive: dive,
          showFigure: ref.watch(
            settingsProvider.select((s) => s.showDiveFigure),
          ),
          showServiceStatus: diveGearShowsLiveServiceStatus(
            dive,
            DateTime.now(),
          ),
          onTap: (item) => context.push('/equipment/${item.id}'),
          // The check-in chip for each row (condition phase 3a).
          rowTrailing: (item) =>
              ObservationStatusChip(equipment: item, dive: dive),
        ),
      ),
```

importing `dive_gear_with_figure.dart`. Remove the `dive_gear_tree_view.dart` import only if nothing else in the page uses it.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/dive_log`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/dive_gear_with_figure.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/dive_gear_with_figure_test.dart test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart
git commit -m "feat(dive-log): the diver figure in the dive equipment card" -m "Part of #2326"
```

---

### Task 13: Verification

**Files:**
- None new. Screenshots go to the scratch directory, not the repo.

**Interfaces:**
- Consumes: everything above.
- Produces: a branch ready for review, and the screenshot files for the PR description.

- [ ] **Step 1: Whole-project checks**

```bash
dart format .
flutter analyze
flutter gen-l10n && git status --porcelain lib/l10n
flutter test test/architecture
```

Expected: format changes nothing; `No issues found!`; no l10n drift; architecture guards pass.

- [ ] **Step 2: The affected suites**

```bash
flutter test test/features/equipment test/features/dive_log test/features/settings test/core/database test/core/services/sync test/core/services/export/csv test/l10n test/features/insights
```

Expected: all pass. Run it once; do not start a second test run while one is going.

- [ ] **Step 3: Screenshots**

The PR changes screens, so its description needs before and after images (light and dark, phone and desktop where layout changes). Capture them with a throwaway golden test (`matchesGoldenFile` and `--update-goldens`, loading a real font in `setUpAll`), written to the scratch directory and deleted afterwards:

1. Item edit form, fins, colour unset and set (Red); the colour sheet open.
2. Item detail page with the colour row.
3. Set page figure with a coloured item (after), against the same set before colouring.
4. Set edit page with the figure on (after; before is the page without it).
5. Dive detail equipment card with the switch on (after) and off (before), at 390 and 1200 wide.
6. Settings > Appearance > Dives with the new switch.

- [ ] **Step 4: Spec check**

Read spec sections 9 to 11 against the branch: every bullet has code and a test. Record anything missing as a follow-up rather than silently skipping it.

- [ ] **Step 5: Report**

Nothing is pushed by this plan. Report the commits, test counts, and screenshot paths.
