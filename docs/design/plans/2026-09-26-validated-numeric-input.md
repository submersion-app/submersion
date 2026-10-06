# Validated Numeric Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every numeric text field in the app tells the diver when their input cannot be read, and never silently stores 0, null, or a stale value in its place (issue #1900).

**Architecture:** A shared core (`NumberRead` sealed result, `readNumber`, `numberValidator`, `invalidNumberText`) in `lib/shared/widgets/forms/number_input_validation.dart`, and a `NumberField` TextFormField wrapper for live-updating fields. Form pages block save through the validator; live fields keep the last value the diver typed. An architecture test forbids direct parser calls outside the shared layer and is the sweep's completeness check.

**Tech Stack:** Flutter, Dart 3 sealed classes and switch expressions, `intl`, `flutter gen-l10n` (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-26-validated-numeric-input-design.md`

## Global Constraints

- Worktree: every command and file path is inside `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/github-issue-1900-644bed`. Never edit or commit in the main checkout. Use absolute paths.
- Parser: smart parsing everywhere (`smartParseUserDecimal`, new `smartParseUserInt`), reached only through `readNumber`.
- Unreadable input: Form pages block save; live fields keep the last value the diver typed and show the error. Nothing unreadable is ever written as 0 or null.
- Blank input: each field keeps today's blank meaning, written as an explicit `NumberBlank()` case. Do not change any blank meaning; record questionable ones in `docs/superpowers/plans/2026-09-26-blank-input-audit.md` (created in Task 5, appended by later tasks).
- Messages: `numberInput_invalidNumber(separator)`, `numberInput_invalidWholeNumber`, `numberInput_required`. A field-specific key is deleted only when its every remaining use is the pure "unreadable" case; keys carrying a range or semantic rule stay for that rule.
- No em-dashes anywhere (code, comments, commits). No emojis. No mention of Claude or Anthropic in commits.
- Commit messages: conventional style, no attribution trailers.
- After each task: `dart format .` then `flutter analyze` (must report no issues, infos included).
- ARB edits are followed by `flutter gen-l10n`; commit the regenerated `lib/l10n/arb/app_localizations*.dart`.
- Paths in tests are built with `p.join` where a filesystem path is assembled.

## Review Focus

1. **Parent round-trip in live fields.** A parent that writes every `onChanged` value back into the widget rebuilds it with the blank default after a field is cleared; a following invalid keystroke must restore the last readable value the diver typed, not the parent's current value and not the blank default. Test: Task 6 CCR panel test "clear then garbage keeps last typed value".
2. **Wrong separator under de.** `14.8` typed under `de` must be read as 14.8 with no error (smart correction), while `1.234,5.6` shows the error. Test: Task 3 `readNumber` de group.
3. **Collapsed section on save.** The dive edit page expands collapsed sections before validating; a CCR field with an error inside a collapsed section must still block save. Test: Task 5 "unreadable max depth blocks save" plus Task 6 CCR-in-form test.
4. **Integer field given a decimal.** `12,5` in an integer field (scrubber minutes, dive number) shows `numberInput_invalidWholeNumber` and is not rounded. Test: Task 3 validator integer case, Task 4 widget integer case.
5. **Filter sheets.** Unreadable text in a filter must not clear an active filter. Test: Task 7 dive filter sheet test.

---

### Task 1: `smartParseUserInt`

**Files:**
- Modify: `lib/core/utils/number_input.dart` (after `parseUserInt`)
- Test: `test/core/utils/number_input_test.dart`

**Interfaces:**
- Produces: `int? smartParseUserInt(String text)`

- [ ] **Step 1: Write the failing test** (append a group to `test/core/utils/number_input_test.dart`, inside `main`, reusing its `setUp`/`tearDown` that pin `Intl.defaultLocale`)

```dart
  group('smartParseUserInt', () {
    test('reads a whole number', () {
      Intl.defaultLocale = 'de';
      expect(smartParseUserInt('42'), 42);
    });

    test('returns null for blank input', () {
      Intl.defaultLocale = 'de';
      expect(smartParseUserInt('  '), isNull);
    });

    test('rejects a fraction, including a corrected wrong separator', () {
      Intl.defaultLocale = 'de';
      expect(smartParseUserInt('12,5'), isNull);
      // "12.5" is corrected to 12,5 by the smart parser, still a fraction.
      expect(smartParseUserInt('12.5'), isNull);
    });

    test('accepts a corrected separator that yields a whole value', () {
      Intl.defaultLocale = 'de';
      expect(smartParseUserInt('12.0'), 12);
    });

    test('returns null for garbage', () {
      Intl.defaultLocale = 'en_US';
      expect(smartParseUserInt('abc'), isNull);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/utils/number_input_test.dart --plain-name smartParseUserInt`
Expected: compile error, `smartParseUserInt` not defined.

- [ ] **Step 3: Implement** (below `parseUserInt`)

```dart
/// [parseUserInt], with [smartParseUserDecimal]'s correction of one
/// unambiguous wrong-separator keystroke. A fraction is still rejected, not
/// rounded, for the same reason as [parseUserInt].
int? smartParseUserInt(String text) {
  final value = smartParseUserDecimal(text);
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/utils/number_input_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/number_input.dart test/core/utils/number_input_test.dart
git commit -m "feat(number-input): add smartParseUserInt (#1900)"
```

---

### Task 2: Shared l10n keys

**Files:**
- Modify: `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (add next to `numberInput_invalidValue`)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `context.l10n.numberInput_invalidNumber(String separator)`, `context.l10n.numberInput_invalidWholeNumber`, `context.l10n.numberInput_required`

`numberInput_invalidNumber` reuses the wording already translated for `gasCalculators_blender_invalidNumber` (same meaning, reviewed translations), so no new translation risk.

- [ ] **Step 1: Add to `app_en.arb`**

```json
  "numberInput_invalidNumber": "Enter a valid number (decimal separator: \"{separator}\")",
  "@numberInput_invalidNumber": {
    "placeholders": {
      "separator": {
        "type": "String"
      }
    }
  },
  "numberInput_invalidWholeNumber": "Enter a whole number",
  "numberInput_required": "Required",
```

- [ ] **Step 2: Add to the other 10 ARB files** (copy each file's existing `gasCalculators_blender_invalidNumber` value for `numberInput_invalidNumber`)

| Locale | `numberInput_invalidWholeNumber` | `numberInput_required` |
|---|---|---|
| ar | أدخل عددًا صحيحًا | مطلوب |
| de | Geben Sie eine ganze Zahl ein | Erforderlich |
| es | Introduce un número entero | Obligatorio |
| fr | Saisissez un nombre entier | Obligatoire |
| he | הזן מספר שלם | שדה חובה |
| hu | Adjon meg egy egész számot | Kötelező |
| it | Inserisci un numero intero | Obbligatorio |
| nl | Voer een geheel getal in | Verplicht |
| pt | Insira um número inteiro | Obrigatório |
| zh | 请输入整数 | 必填 |

- [ ] **Step 3: Regenerate and analyze**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): shared numeric input error strings (#1900)"
```

---

### Task 3: Shared core `number_input_validation.dart`

**Files:**
- Create: `lib/shared/widgets/forms/number_input_validation.dart`
- Test: `test/shared/widgets/forms/number_input_validation_test.dart`

**Interfaces:**
- Consumes: `smartParseUserDecimal`, `smartParseUserInt` (Task 1), l10n keys (Task 2), `localeNumberFormat()` from `lib/core/utils/locale_number_symbols.dart`
- Produces:
  - `sealed class NumberRead`, `NumberBlank()`, `NumberValue(double value)`, `NumberInvalid()` (all `const`, with `==`/`hashCode`)
  - `NumberRead readNumber(String text, {bool integer = false})`
  - `FormFieldValidator<String> numberValidator(BuildContext context, {bool integer = false, bool required = false, String? Function(double value)? check})`
  - `String? invalidNumberText(BuildContext context, String text, {bool integer = false})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('readNumber', () {
    test('blank is NumberBlank', () {
      Intl.defaultLocale = 'en_US';
      expect(readNumber('   '), const NumberBlank());
    });

    test('readable text is NumberValue', () {
      Intl.defaultLocale = 'en_US';
      expect(readNumber('14.8'), const NumberValue(14.8));
    });

    test('de corrects a lone wrong separator', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('14.8'), const NumberValue(14.8));
      expect(readNumber('14,8'), const NumberValue(14.8));
    });

    test('de flags genuinely malformed text', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('1.234,5.6'), const NumberInvalid());
      expect(readNumber('abc'), const NumberInvalid());
    });

    test('integer mode rejects a fraction rather than rounding', () {
      Intl.defaultLocale = 'de';
      expect(readNumber('12,5', integer: true), const NumberInvalid());
      expect(readNumber('12', integer: true), const NumberValue(12));
    });
  });

  group('numberValidator', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('blank is valid unless required', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(numberValidator(context)(''), isNull);
      expect(numberValidator(context, required: true)(''), 'Required');
    });

    testWidgets('unreadable text names the separator', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(
        numberValidator(context)('1.2.3'),
        'Enter a valid number (decimal separator: ".")',
      );
    });

    testWidgets('integer fields ask for a whole number', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(
        numberValidator(context, integer: true)('12.5'),
        'Enter a whole number',
      );
    });

    testWidgets('check runs only on readable values', (tester) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      final validator = numberValidator(
        context,
        check: (v) => v <= 0 ? 'must be positive' : null,
      );
      expect(validator('-1'), 'must be positive');
      expect(validator('5'), isNull);
      expect(validator(''), isNull);
      expect(validator('x'), startsWith('Enter a valid number'));
    });

    testWidgets('invalidNumberText is null for blank and readable text', (
      tester,
    ) async {
      Intl.defaultLocale = 'en_US';
      final context = await pumpContext(tester);
      expect(invalidNumberText(context, ''), isNull);
      expect(invalidNumberText(context, '3'), isNull);
      expect(invalidNumberText(context, 'x'), isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/shared/widgets/forms/number_input_validation_test.dart`
Expected: compile error, file not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/widgets.dart';

import 'package:submersion/core/utils/locale_number_symbols.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a numeric text field holds: nothing, a number, or text that cannot
/// be read in the active locale.
///
/// The parsers return null for both blank and unreadable text, and treating
/// the two alike is how a mistyped depth used to be saved as 0 (#1900).
/// Switching on this sealed type makes every caller state what blank means
/// for its field and what happens to unreadable text, and the compiler
/// rejects a switch that forgets either.
sealed class NumberRead {
  const NumberRead();
}

final class NumberBlank extends NumberRead {
  const NumberBlank();

  @override
  bool operator ==(Object other) => other is NumberBlank;

  @override
  int get hashCode => (NumberBlank).hashCode;
}

final class NumberValue extends NumberRead {
  const NumberValue(this.value);

  final double value;

  @override
  bool operator ==(Object other) => other is NumberValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NumberValue($value)';
}

final class NumberInvalid extends NumberRead {
  const NumberInvalid();

  @override
  bool operator ==(Object other) => other is NumberInvalid;

  @override
  int get hashCode => (NumberInvalid).hashCode;
}

/// Reads [text] with the smart parsers, which correct one unambiguous
/// wrong-separator keystroke (#1876). With [integer], a fractional value is
/// [NumberInvalid] rather than rounded.
NumberRead readNumber(String text, {bool integer = false}) {
  if (text.trim().isEmpty) return const NumberBlank();
  final value = integer
      ? smartParseUserInt(text)?.toDouble()
      : smartParseUserDecimal(text);
  return value == null ? const NumberInvalid() : NumberValue(value);
}

/// The message for unreadable [text], or null when [text] is blank or
/// readable. For the few places that show an error outside a form field.
String? invalidNumberText(
  BuildContext context,
  String text, {
  bool integer = false,
}) {
  if (readNumber(text, integer: integer) is! NumberInvalid) return null;
  return integer
      ? context.l10n.numberInput_invalidWholeNumber
      : context.l10n.numberInput_invalidNumber(
          localeNumberFormat().symbols.DECIMAL_SEP,
        );
}

/// A validator for any `validator:` slot (TextFormField, FormRow.text,
/// SuggestionFormRow). Blank passes unless [required]. Unreadable text gets
/// the shared message. [check] then applies a field's own rule to a readable
/// value and keeps that field's own message.
FormFieldValidator<String> numberValidator(
  BuildContext context, {
  bool integer = false,
  bool required = false,
  String? Function(double value)? check,
}) {
  return (text) {
    final read = readNumber(text ?? '', integer: integer);
    return switch (read) {
      NumberBlank() => required ? context.l10n.numberInput_required : null,
      NumberInvalid() => invalidNumberText(
        context,
        text ?? '',
        integer: integer,
      ),
      NumberValue(:final value) => check?.call(value),
    };
  };
}
```

Note: the validator captures `context` when built in `build()`, which matches how the existing field validators in this repo read `context.l10n`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/shared/widgets/forms/number_input_validation_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/forms/number_input_validation.dart test/shared/widgets/forms/number_input_validation_test.dart
git commit -m "feat(forms): shared numeric read result and validator (#1900)"
```

---

### Task 4: `NumberField` widget

**Files:**
- Create: `lib/shared/widgets/forms/number_field.dart`
- Test: `test/shared/widgets/forms/number_field_test.dart`

**Interfaces:**
- Consumes: Task 3 API.
- Produces:

```dart
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.onChanged,          // ValueChanged<NumberRead>
    this.decoration = const InputDecoration(),
    this.integer = false,
    this.allowNegative = false,
    this.required = false,
    this.check,                       // String? Function(double)?
    this.focusNode,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.style,
  });
}

/// Input filter for numeric fields: digits, '.', ',' and optionally '-'.
List<TextInputFormatter> numberInputFormatters({bool allowNegative = false});
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<List<NumberRead>> pump(
    WidgetTester tester, {
    GlobalKey<FormState>? formKey,
    bool integer = false,
  }) async {
    final reads = <NumberRead>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Form(
            key: formKey,
            child: NumberField(
              controller: controller,
              integer: integer,
              onChanged: reads.add,
            ),
          ),
        ),
      ),
    );
    return reads;
  }

  testWidgets('reports values and shows no error for readable text', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.pump();
    expect(reads.last, const NumberValue(12.5));
    expect(find.textContaining('Enter a valid number'), findsNothing);
  });

  testWidgets('shows the error and reports NumberInvalid for garbage', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '1.2.3');
    await tester.pump();
    expect(reads.last, const NumberInvalid());
    expect(
      find.text('Enter a valid number (decimal separator: ".")'),
      findsOneWidget,
    );
  });

  testWidgets('blocks Form.validate while unreadable', (tester) async {
    Intl.defaultLocale = 'en_US';
    final formKey = GlobalKey<FormState>();
    await pump(tester, formKey: formKey);
    await tester.enterText(find.byType(TextFormField), '1.2.3');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('integer field asks for a whole number', (tester) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester, integer: true);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.pump();
    expect(reads.last, const NumberInvalid());
    expect(find.text('Enter a whole number'), findsOneWidget);
  });

  testWidgets('filters out letters', (tester) async {
    Intl.defaultLocale = 'en_US';
    final reads = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '1a2');
    await tester.pump();
    expect(reads.last, const NumberValue(12));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/shared/widgets/forms/number_field_test.dart`
Expected: compile error, file not found.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Input filter for numeric fields: digits and both separators, since the
/// smart parser corrects a wrong one, plus '-' only where a value can be
/// negative (temperatures, time offsets).
List<TextInputFormatter> numberInputFormatters({bool allowNegative = false}) =>
    [
      FilteringTextInputFormatter.allow(
        RegExp(allowNegative ? r'[0-9.,\-]' : r'[0-9.,]'),
      ),
    ];

/// A numeric text field that shows why its text cannot be read, as the diver
/// types, and makes an enclosing Form refuse to validate while it cannot.
///
/// It reports every change as a [NumberRead] and remembers no value itself.
/// A live caller decides in its own switch what [NumberInvalid] does, which
/// is keep the last value the diver typed: that rule stays visible where the
/// value is stored instead of hiding inside the widget.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.integer = false,
    this.allowNegative = false,
    this.required = false,
    this.check,
    this.focusNode,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.style,
  });

  final TextEditingController controller;
  final ValueChanged<NumberRead> onChanged;
  final InputDecoration decoration;
  final bool integer;
  final bool allowNegative;
  final bool required;
  final String? Function(double value)? check;
  final FocusNode? focusNode;
  final bool enabled;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      style: style,
      textAlign: textAlign,
      textInputAction: textInputAction,
      decoration: decoration,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !integer,
        signed: allowNegative,
      ),
      inputFormatters: numberInputFormatters(allowNegative: allowNegative),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: numberValidator(
        context,
        integer: integer,
        required: required,
        check: check,
      ),
      onChanged: (text) => onChanged(readNumber(text, integer: integer)),
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/shared/widgets/forms/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/forms/number_field.dart test/shared/widgets/forms/number_field_test.dart
git commit -m "feat(forms): NumberField with inline numeric validation (#1900)"
```

---

## Migration tasks (5 to 11): shared rules

Each migration task applies these patterns. They are repeated here so a task can be read alone; each task restates the one it uses most.

**Pattern F (Form / FormRow / SuggestionFormRow, parsed on save):**

```dart
// In the field:
validator: numberValidator(context),            // add integer: / check: as the field needs
inputFormatters: numberInputFormatters(),       // replaces local _decimalFilter
// At save, after _formKey.currentState!.validate() returned true:
maxDepth: switch (readNumber(_maxDepthController.text)) {
  NumberValue(:final value) => units.depthToMeters(value),
  NumberBlank() => null,              // today's blank meaning, unchanged
  NumberInvalid() => null,            // unreachable: validate() blocked save
},
```

If a field already has a validator with its own message, keep its rule via `check:` and delete only the parse-failure branch.

**Pattern L (live `onChanged`, keep last typed value):**

```dart
// Both seeded in initState from the widget value.
double? _setpointLow;         // what the panel reports
double? _lastTypedSetpointLow; // last READABLE value the diver typed

NumberField(
  controller: _setpointLowController,
  decoration: ...,                    // unchanged
  onChanged: (read) {
    switch (read) {
      case NumberValue(:final value):
        _lastTypedSetpointLow = value;
        _setpointLow = value;
      case NumberBlank():
        _setpointLow = null;          // today's blank meaning
      case NumberInvalid():
        _setpointLow = _lastTypedSetpointLow; // keep what the diver last typed
    }
    _notifyChange();
  },
),
```

Blank does not touch `_lastTyped*`: a diver clearing a field to retype it and then mistyping gets their last readable value back, not the blank default (this is the #1917 tank He behavior, pinned by `tank_editor_test.dart`). `_notifyChange` reads the reported fields, not the controllers. Never fall back to `widget.<value>`: parents write every change straight back, so after a field is cleared the widget already holds the blank default (see `tank_editor_test.dart` "clearing a field then retyping garbage").

**Pattern B (parse on a button without a Form):** wrap the fields in `Form(key: _formKey, ...)`, use `NumberField` or `validator: numberValidator(context)`, and start the button handler with `if (!_formKey.currentState!.validate()) return;`, then read with Pattern F's switch.

**Pattern D (derived display: chips, N2 readout, warnings, info cards):**

```dart
final o2 = switch (readNumber(_o2Controller.text)) {
  NumberValue(:final value) => value,
  NumberBlank() || NumberInvalid() => 21.0,  // same fallback as before; the field shows the error
};
```

**Every migration task also:**
- Replaces every `parseUserDecimal(` / `parseUserInt(` / `smartParseUserDecimal(` in its files with `readNumber` (grep the files before committing: `grep -n "parseUser\|smartParse" <files>` must print nothing).
- Appends any questionable blank meaning to `docs/superpowers/plans/2026-09-26-blank-input-audit.md` as a row `| file:line | field | blank today | why it looks questionable |`.
- Updates existing tests that asserted the old message text ("Enter a valid number", "Enter a number", "Enter a valid amount") to the new text.
- Runs the listed test directories, `dart format .`, and `flutter analyze` before committing.

---

### Task 5: Dive edit page (Form sites)

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (save path ~5190-5330, bulk edit ~1250-1275 and ~1910-1950 including `_bulkNumberField`, weight row ~4808, runtime-to-exit ~422, altitude warning ~5625-5640)
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`, `conditions_section.dart` (delete `_decimalFilter`; add validators to the numeric `FormRow.text` rows)
- Modify: `lib/features/dive_log/presentation/formatters/visibility_display.dart` (`parseVisibilityInput` returns via `readNumber`; keep its documented null for blank)
- Create: `docs/superpowers/plans/2026-09-26-blank-input-audit.md` with header `| Site | Field | Blank today | Why questionable |` and `|---|---|---|---|`
- Test: `test/features/dive_log/presentation/pages/dive_edit_page_test.dart`

**Interfaces:**
- Consumes: `numberValidator`, `readNumber`, `numberInputFormatters`, `NumberField` (Tasks 3-4)

Patterns: F for every save-path field (depths, times, temps, swell, altitude, surface pressure, dive number, wind, humidity, weighting amount). `_bulkNumberField` becomes a `NumberField` wrapper (Pattern L into the bulk state). Weight row amount: `NumberField`, Pattern L. Derived reads (runtime to exit time, altitude warning): Pattern D. Dive number is `integer: true`; runtime/bottom time use `integer: true` only if the field is integer today (check its current formatter; `digitsOnly` means integer).

- [ ] **Step 1: Write the failing test** (in `dive_edit_page_test.dart`, reusing the file's existing pump helper for a new dive and its save-button finder; follow the nearest existing "saves" test for provider overrides)

```dart
testWidgets('unreadable max depth blocks save and shows the error (#1900)', (
  tester,
) async {
  // Arrange: pump the edit page for a new dive exactly as the existing
  // save test in this file does, and capture repository saves.
  // Act:
  await tester.enterText(find.widgetWithText(TextFormField, 'Max depth'), '1.2.3');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  // Assert:
  expect(find.textContaining('Enter a valid number'), findsWidgets);
  // the fake repository recorded no save
});
```

Adjust the label finder to the page's actual label (read `the_dive_section.dart`); keep the assertion shape.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart --plain-name "unreadable max depth"`
Expected: FAIL, save happens with max depth 0 and no error text.

- [ ] **Step 3: Migrate** the listed files with Patterns F, L, D.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/ test/features/dive_log/presentation/formatters/`
Expected: all pass.

- [ ] **Step 5: Format, analyze, grep, commit**

```bash
dart format . && flutter analyze
grep -n "parseUser\|smartParse" lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/edit_sections/*.dart lib/features/dive_log/presentation/formatters/visibility_display.dart
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/edit_sections/ lib/features/dive_log/presentation/formatters/visibility_display.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart docs/superpowers/plans/2026-09-26-blank-input-audit.md
git commit -m "fix(dive-log): block saving a dive with unreadable numbers (#1900)"
```

---

### Task 6: Tank editor, CCR and SCR panels (live sites inside the dive Form)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (start/end pressure ~329-332, volume and working pressure ~211-212, unit suffix ~198, MND ~891, O2/He ~316-319 and `_validateGasPercent` ~806)
- Modify: `lib/features/dive_log/presentation/widgets/ccr_settings_panel.dart` (`_notifyChange` ~139-154, chips/N2 ~396-423)
- Modify: `lib/features/dive_log/presentation/widgets/scr_settings_panel.dart` (~191-212, derived ~602-678)
- Test: `test/features/dive_log/presentation/widgets/tank_editor_test.dart`, create `test/features/dive_log/presentation/widgets/ccr_settings_panel_test.dart`, create `test/features/dive_log/presentation/widgets/scr_settings_panel_test.dart`

**Interfaces:**
- Consumes: `NumberField`, `readNumber`, `NumberRead` (Tasks 3-4)

Pattern L for every editable field (keep `_last*` per field; the tank editor already has `_lastValidO2/He`, extend the same approach to pressures, volume, working pressure). The O2/He validator keeps its sum-over-100 rule through `check:`; the parse-failure message becomes the shared one. Scrubber minutes are `integer: true`. Pattern D for chips, N2 and calculated loop O2.

- [ ] **Step 1: Write failing tests**

`ccr_settings_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets(
    'unreadable setpoint keeps the last typed value and shows the error',
    (tester) async {
      Intl.defaultLocale = 'en_US';
      double? lastLow;
      // Construct CcrSettingsPanel with its required arguments (read the
      // constructor) and an onChanged that records setpointLow into lastLow
      // and writes it back into the panel's widget value, as the dive edit
      // page does, so the parent round-trip is exercised.
      // ...pump inside localizedMaterialApp(home: Scaffold(body: Form(child: panel)))
      final lowField = find.byType(TextFormField).first; // pick the setpoint-low field by its label
      await tester.enterText(lowField, '0.7');
      await tester.pump();
      expect(lastLow, 0.7);
      await tester.enterText(lowField, '');
      await tester.pump();
      await tester.enterText(lowField, '0..7');
      await tester.pump();
      expect(find.textContaining('Enter a valid number'), findsOneWidget);
      expect(
        lastLow,
        0.7,
        reason:
            'garbage after a clear restores the last readable value the '
            'diver typed, not the blank default the parent round-tripped',
      );
    },
  );

  testWidgets('unreadable diluent O2 does not drop the diluent gas', (tester) async {
    // Seed a diluent of 21/35, type "2x" (filtered to "2") then "2..1":
    // the reported diluent keeps o2 == 2 then stays 2, never null.
  });
}
```

Mirror both tests for `scr_settings_panel_test.dart` (supply O2 and injection rate). In `tank_editor_test.dart`, add "unreadable start pressure keeps the last typed value" following the existing He test at ~line 366 (same `_RebuildingTankHost`).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/`
Expected: new tests FAIL (no error text; null reported).

- [ ] **Step 3: Migrate** the three widgets with Patterns L and D.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/`
Expected: all pass.

- [ ] **Step 5: Format, analyze, grep, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_log/presentation/widgets/tank_editor.dart lib/features/dive_log/presentation/widgets/ccr_settings_panel.dart lib/features/dive_log/presentation/widgets/scr_settings_panel.dart test/features/dive_log/presentation/widgets/ docs/superpowers/plans/2026-09-26-blank-input-audit.md
git commit -m "fix(dive-log): show errors for unreadable tank and rebreather numbers (#1900)"
```

---

### Task 7: Dive log filters, search and numbering

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (~169, 635, 653, 1083, 1099)
- Modify: `lib/features/dive_log/presentation/pages/dive_search_page.dart` (~546-596)
- Modify: `lib/features/dive_log/presentation/widgets/dive_numbering_dialog.dart` (~326)
- Modify: `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart` (~358)
- Test: existing tests for these files (`find test -name "dive_filter_sheet*_test.dart"` etc.)

Pattern L where `NumberInvalid()` keeps the current filter value (never clears it); `NumberBlank()` clears as today. Numbering start is `integer: true`.

- [ ] **Step 1: Failing test** in the dive filter sheet test: enter a min depth of `10`, then `1..0`; the error shows and the filter state still holds 10 (read it through the same provider the existing filter tests assert on).
- [ ] **Step 2:** run it, expect FAIL.
- [ ] **Step 3:** migrate the four files.
- [ ] **Step 4:** `flutter test test/features/dive_log/ test/features/dive_sites/`, expect pass.
- [ ] **Step 5:** format, analyze, grep, commit `fix(dive-log): keep filters when a filter number is unreadable (#1900)`.

---

### Task 8: Dive planner, planner canvas, deco calculator

**Files:**
- Modify: `lib/features/dive_planner/presentation/widgets/segment_editor.dart` (~185-246, Pattern B)
- Modify: `lib/features/dive_planner/presentation/widgets/plan_tank_list.dart` (~337-478; Pattern F, keep sum rule via `check:`, delete its local parse-failure branch)
- Modify: `lib/features/dive_planner/presentation/widgets/setup/plan_number_field.dart` (reads via `readNumber`; unreadable text sets the error state and renders `invalidNumberText` under the row; blur still reverts)
- Modify: `setup/plan_gas_section.dart` (~177, 210), `setup/plan_air_breaks_control.dart` (~76, 88), `setup/plan_environment_section.dart` (~80, 249)
- Modify: `lib/features/planner/presentation/widgets/ccr_settings_section.dart`, `contingency_settings_section.dart`, `pscr_settings_section.dart`
- Modify: `lib/features/deco_calculator/presentation/widgets/environment_inputs.dart` (~44)
- Test: `segment_editor_test.dart`, `plan_tank_list_test.dart`, `setup/plan_number_field_test.dart`, plus existing tests for the other files

- [ ] **Step 1: Failing tests**

In `segment_editor_test.dart` (reuse its pump helper):

```dart
testWidgets('unreadable segment depth blocks the segment (#1900)', (tester) async {
  // open the editor as the existing save test does
  await tester.enterText(find.widgetWithText(TextField, 'Depth'), '1..0'); // use the real label
  await tester.tap(find.text('Save')); // the editor's confirm button
  await tester.pumpAndSettle();
  expect(find.textContaining('Enter a valid number'), findsOneWidget);
  // the onSave callback was not called
});
```

In `plan_number_field_test.dart`:

```dart
testWidgets('unreadable text shows the message under the row', (tester) async {
  // pump PlanNumberField(value: 18, hintValue: 18, ...) as the file's other tests do
  await tester.enterText(find.byType(TextField), '1..8');
  await tester.pump();
  expect(find.textContaining('Enter a valid number'), findsOneWidget);
});
```

- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3:** migrate. Live planner fields use Pattern L (their "skip" today becomes "keep last typed + error"). Deco altitude: blank stays null (sea level); invalid keeps the last typed value.
- [ ] **Step 4:** `flutter test test/features/dive_planner/ test/features/planner/ test/features/deco_calculator/`, expect pass.
- [ ] **Step 5:** format, analyze, grep, commit `fix(planner): show errors for unreadable planner numbers (#1900)`.

---

### Task 9: Gas calculators, cylinders, tank presets, transmitters

**Files:**
- Modify: `lib/features/gas_calculators/presentation/widgets/blender/blender_field_parsing.dart` (rewrite `mixPercentOrKeep`/`pressureOrZero` on `readNumber`, or inline them if only one caller)
- Modify: `blender_fill_gases_card.dart` (delete `_invalidNumberText`; price, flush volume and topup O2 become `NumberField` with Pattern L)
- Modify: `blender_mix_row.dart`, `blender_billing_card.dart`, `blender_line_edit_sheet.dart`, `mix_template_menu.dart`, `mix_template_manager.dart`
- Modify: `lib/features/cylinder_configs/presentation/**/cylinder_config_item_editor.dart` (~165, 183)
- Modify: `lib/features/cylinder_passports/**/log_fill_sheet.dart` (drop local `parseDecimal`; Pattern B)
- Modify: `lib/features/tank_presets/presentation/pages/tank_preset_edit_page.dart` (keep `tankPresets_edit_valid*` only for their range rule via `check:`)
- Modify: `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart` (channel `integer: true`; `_positive` via `check:`)
- Test: `test/features/gas_calculators/`, `test/features/cylinder_configs/`, `test/features/cylinder_passports/`, `test/features/tank_presets/`, `test/features/transmitters/`

Template messages (`gasCalculators_blender_templateNeedsNumbers`) and line-sheet semantic messages stay; only their parse step moves to `readNumber`.

- [ ] **Step 1: Failing test** in `cylinder_config_item_editor_test.dart`: type `3..2` into O2; expect the shared error text and the reported O2 still the previous value.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3:** migrate; update `blender_fill_gases_card_test.dart` expectations for the new key text (the English wording is unchanged, so most should pass as is).
- [ ] **Step 4:** run the listed test dirs, expect pass.
- [ ] **Step 5:** format, analyze, grep, commit `fix(gas): shared numeric validation for blender, cylinders and presets (#1900)`.

---

### Task 10: Dive sites and equipment

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (min/max depth ~1732-1733 get `numberValidator`; altitude validator ~774 keeps its range rule via `check:`)
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart` (~145, Pattern D)
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (~797, 1049), `service_kind_list_page.dart` (~455, 585-613; interval fields gain validators, `integer: true` for days/dives), `lib/features/equipment/presentation/utils/exposure_interval_input.dart`, `widgets/service_schedule_dialogs.dart` (~339, 450-456), `widgets/service_record_dialog.dart` (~408, 581), `widgets/equipment_attribute_form_section.dart` (~163)
- Test: `site_edit_page_test.dart` and the equipment tests for these files

`equipment_edit_purchasePriceValidation` and `equipment_serviceDialog_costValidation`: if their only rule is "parses", switch to the shared validator and mark the keys for deletion in Task 12; if they also reject negatives, keep them through `check:`.

- [ ] **Step 1: Failing test** in `site_edit_page_test.dart`: enter `1..0` in max depth, tap save, expect the shared error and no save.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3:** migrate.
- [ ] **Step 4:** `flutter test test/features/dive_sites/ test/features/equipment/`, expect pass.
- [ ] **Step 5:** format, analyze, grep, commit `fix(sites,equipment): validate numeric fields before save (#1900)`.

---

### Task 11: Settings and remaining features

**Files:**
- Modify: `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart` (`_ThresholdField` uses `numberValidator`/`invalidNumberText`)
- Modify: `lib/features/settings/presentation/widgets/gtr_reserve_dialog.dart` (Pattern B; dialog does not pop while invalid) and its caller in `settings_page.dart` (~1511)
- Modify: `widgets/visibility_scale_picker.dart` (~405), `pages/body_weight_edit_page.dart` (~128-138), `pages/prior_experience_edit_page.dart` (~81-86, 228), `pages/fix_dive_times_page.dart` (~80, `allowNegative: true`)
- Modify: `lib/features/weight_planner/presentation/pages/weight_planner_page.dart`, `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart` (amount gets a validator), `lib/features/checklists/presentation/pages/checklist_template_edit_page.dart`, `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` (~774, Pattern B, `allowNegative: true`), `lib/features/pre_dive/presentation/pages/pre_dive_session_runner_page.dart`, `pre_dive_template_edit_page.dart`, `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart`, `lib/features/site_scape/**/site_feature_sheet.dart`, `lib/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart`
- Test: existing tests for each; create `test/features/settings/presentation/widgets/gtr_reserve_dialog_test.dart`

- [ ] **Step 1: Failing test** `gtr_reserve_dialog_test.dart`: open the dialog through a button that `await`s it, type `5..0`, tap OK; expect the shared error, the dialog still open, and the awaited result not yet delivered.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3:** migrate all listed files.
- [ ] **Step 4:** `flutter test test/features/settings/ test/features/weight_planner/ test/features/weight_presets/ test/features/checklists/ test/features/data_quality/ test/features/pre_dive/ test/features/dive_3d/ test/features/site_scape/ test/features/dive_centers/`, expect pass.
- [ ] **Step 5:** format, analyze, grep, commit `fix(settings): validate remaining numeric fields (#1900)`.

---

### Task 12: Delete orphaned message keys

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, regenerate `app_localizations*.dart`

- [ ] **Step 1: Find orphans**

```bash
for k in numberInput_invalidValue gasCalculators_blender_invalidNumber equipmentConditionSettings_invalid passport_logFill_invalidNumber divers_edit_priorInvalidNumber equipment_edit_purchasePriceValidation equipment_serviceDialog_costValidation; do
  printf '%s: ' "$k"; grep -rl "\.$k\b" lib test --include='*.dart' | grep -v '^lib/l10n/' | wc -l
done
```

- [ ] **Step 2:** delete every key reporting 0 (the entry and its `@` metadata) from all 11 ARB files with a python3.14 script that edits JSON text line-wise (preserve file encoding and ordering; CRLF-safe).
- [ ] **Step 3:** `flutter gen-l10n && flutter analyze`, expect no issues.
- [ ] **Step 4:** commit `chore(l10n): remove superseded numeric error strings (#1900)`.

---

### Task 13: Architecture guard

**Files:**
- Create: `test/architecture/number_parsing_single_source_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Numeric text is read through `readNumber` and nowhere else.
///
/// Calling the parsers directly is how 192 call sites came to treat blank
/// and unreadable input alike, silently saving 0 or null for a mistyped
/// depth (#1900). `readNumber` returns a sealed result every caller must
/// switch on, so the blank and invalid cases are always decided explicitly.
void main() {
  const allowed = <String, String>{
    'lib/core/utils/number_input.dart': 'defines the parsers',
    'lib/shared/widgets/forms/number_input_validation.dart':
        'the one reader, readNumber',
  };

  final calls = RegExp(
    r'\b(parseUserDecimal|parseUserInt|smartParseUserDecimal|smartParseUserInt)\s*\(',
  );

  test('only the shared layer calls the numeric parsers', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue; // doc comments are prose
        if (calls.hasMatch(line)) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'read numeric text with readNumber (lib/shared/widgets/forms/'
          'number_input_validation.dart) and switch on its NumberRead, or '
          'use NumberField / numberValidator, so unreadable input is shown '
          'to the diver instead of silently becoming 0 or null',
    );
  });

  test('every allowlisted file exists and still calls a parser', () {
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} missing');
      expect(
        calls.hasMatch(file.readAsStringSync()),
        isTrue,
        reason: '${entry.key} is allowlisted as "${entry.value}" but no '
            'longer calls a parser; remove it from the allowlist',
      );
    }
  });
}
```

- [ ] **Step 2: Run**

Run: `flutter test test/architecture/number_parsing_single_source_test.dart`
Expected: PASS. If it lists offenders, migrate each with the matching pattern (they were missed by Tasks 5-11) and rerun.

- [ ] **Step 3: Commit** `test(architecture): guard numeric parsing behind readNumber (#1900)`.

---

### Task 14: Verification, screenshots, PR

- [ ] **Step 1:** `df -h /Volumes/fltmp` (if TMPDIR is that RAM disk and it is full, clear leftover `flutter_tools.*` dirs first), then one full suite run: `flutter test > <scratchpad>/full_test.log 2>&1; echo $?`. Expected exit 0. Do not pipe into grep.
- [ ] **Step 2:** `dart format --set-exit-if-changed . && flutter analyze`, expected clean.
- [ ] **Step 3: Screenshots** via throwaway golden tests (font loaded in `setUpAll`, `--update-goldens`, never committed): dive edit max depth error, CCR setpoint error, planner row message; each in light and dark, before (on `origin/main`) and after. Save PNGs to the scratchpad and send them to the maintainer.
- [ ] **Step 4:** push and open the PR. Body: summary, `Closes #1900`, the blank-input audit table (from the audit file, which is then deleted from the branch in a final commit), a testing section, and the screenshots section listing each image. No attribution lines.
- [ ] **Step 5:** bind the PR (`get_status`, then `bind_pr` if needed) and enable CI auto-fix monitoring.
