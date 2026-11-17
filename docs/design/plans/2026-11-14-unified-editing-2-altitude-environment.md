# Unified Editing, Plan 2: Altitude and Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive page's Altitude and Environment cards editable in place, and add the shared pieces every plain-field card needs: clearing a value, refusing unreadable input, number rows bound to the sitting, writes held for another record, and framing for cards that sit side by side (issue #4527).

**Architecture:** Plan 1 gave the page an `EditSession<Dive>` and a `RecordEditController<Dive>`. This plan adds field bindings that keep a text controller in step with one session field, has the controller track cards with unreadable input and refuse to close or save them, lets a sitting hold a write to another record until Save runs it inside the same transaction, and registers two more cards in `diveEditCards`. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "Saving, cancelling, leaving", "What is held, and what is not" and the Cards table. Plan 1 is `docs/design/plans/2026-11-14-unified-editing-1-skeleton.md`; its shared pieces are in `lib/shared/widgets/record_editing/`.

## Why this is not the whole of "plan 2"

Plan 2 was to cover the header block, Details, Environment and Altitude. Reading the edit page showed that is three plans:

- **Plan 2 (this one):** the groundwork above, and the two cards with only plain values, enum pickers and the weather fetch.
- **Plan 3: Details.** Ten kinds of field, four with picker sheets, three that can create another record, and a trap when clearing a trip (a loaded dive carries both `trip` and `tripId`, and the writer prefers `tripId`).
- **Plan 4: the header block.** Entry, exit and runtime are linked, with estimated exits that must never be saved; picking a site sets values on all three other cards, so those cards come first.

The sequence after that is unchanged, so phase 1 is now eleven plans.

## Not in this plan

- The Details card and the header block, and so: water temperature, visibility, water type, the site and everything it sets.
- What the Altitude mismatch note does on a locked page: it still links to the old edit page until the switch-over.
- Rules that check values against each other. Today's form has none: the only thing that can stop a save is a number that does not parse (`_formKey.currentState!.validate()` at `dive_edit_page.dart:6506`). `EditCard` therefore gains no `validate` function yet.
- The embedded list pane, whole-record operations, calculated cards fading back.

## Calls made in this plan, for Eric to check

1. **Opening the Altitude card with no altitude looks one up.** Today's form does this when it loads (`_maybeAutoFillAltitude`, `dive_edit_page.dart:5691`), over the network, silently. Here it happens when the card is opened, and the value it finds marks the card as changed, so the diver sees it and Cancel undoes it.
2. **The site's altitude is written with the sitting, not at once.** Today the lookup writes the altitude back to the site immediately. The spec says a write to another record is held. If the sitting is cancelled, the site is left as it was.
3. **A card with unreadable input cannot be closed.** "Done" and Save both refuse, scroll to the card, and the field shows its own message. Cancel still works.
4. **A weather fetch that fails says "unavailable"** (`diveLog_edit_fetchWeatherUnavailable`) where today's form shows a hard-coded English sentence with the exception text.
5. **Surface pressure is edited on the Altitude card only.** Both read cards show it; the design names Altitude as the place it is edited. The open Environment card keeps showing it as a plain row that cannot be typed in, so nothing the card showed disappears when it opens.
6. **The pressure row's hint is the pressure worked out from the altitude,** which is what the read card shows when none is stored. Today's form always hints 1013.
7. **The altitude group banner is one widget for the read card and the editor, and its range becomes translated.** The read card prints `rangeDescription`, which is English in every language (`dive_detail_altitude_section.dart:209`); the shared banner uses `localizedRange`. This is the one change a locked page shows with the switch off, and only outside English.
8. **On an unlocked page the mismatch note opens the Altitude card.** Locked, it does what it does today.
9. **Surface pressure is typed in the unit the read card shows it in:** mbar for a metric diver, inHg for an imperial one (`UnitFormatter.surfacePressureSymbol`). Today's form asks every diver for mbar.
10. **The entry method row hints the site's method.** The read card shows the site's entry method when the dive has none of its own (`Dive.effectiveEntryMethod`). The picker holds the dive's own value, as today's form does, and shows the site's as its hint.

## Global Constraints

- With `kUnlockEditing` false the dive page builds and behaves exactly as today. The two read cards change only in which widget draws their title, and in call 7 above.
- A card does not move on the page while its editor is open, whatever is typed into it.
- Every value shown or typed follows the active diver's units (`unitFormatterProvider`), and a value is typed in the unit its read card shows. The session holds canonical values: metres, Celsius, bar, metres per second.
- A value the diver did not change is never written. Opening a card and leaving its fields alone must leave the sitting clean, in every unit setting.
- Emptying a field clears the stored value.
- Typed numbers are read only through `readNumber` (`lib/shared/widgets/forms/number_input_validation.dart:66`); the architecture guard forbids `tryParse` in presentation code.
- Dates and times are formatted only through `UnitFormatter`.
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 783: new page code goes in `dive_detail_page_editing.dart`.
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`.
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`. Build `DiveRepository()` in `setUp`, never once for the file: it keeps the database it was built with.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **A unit round trip is not a change.** In imperial units, an altitude stored as 1,234.5 m shows as a rounded number of feet. Opening the card, focusing each field and closing it must leave the sitting clean. Pinned in Task 4 and Task 10.
2. **Emptying a field clears it in storage.** Clearing the altitude and saving stores null, not the old value. Pinned in Task 1 and Task 10.
3. **Unreadable input does not outlive the sitting.** After typing `1.2.3`, Cancel locks the page; the next sitting starts with no card marked invalid. Pinned in Task 3.
4. **The weather fetch is slow, fails, or returns after the card has gone.** Nothing is set after the card closes or the page locks, and the busy state clears. Pinned in Task 8.
5. **A held write follows the sitting.** If Save fails, the site keeps its old altitude and the dive write is rolled back. If the sitting is cancelled, nothing is written. Pinned in Task 5.
6. **The first value typed into an empty card.** Details and Environment share a row only when Environment has something to show, and the Altitude card exists only above sea level. Typing the first value changes both answers while the editor is open. The editor must keep its focus, caret and text. Pinned in Task 9 and Task 10.

## Preparation

- [ ] Work in a worktree of its own, on a branch cut from plan 1's branch `ericgriffin/unified-editing-pattern-1819d7`, or from `main` if pull request #4536 has merged. Initialise it per the development guide's "Git Worktrees" section, then `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `flutter analyze` on the whole repository is clean before any change.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `field_text_binding.dart` | `FieldTextBinding<T, V>`: a text controller in step with one session field |
| `record_number_row.dart` | `RecordNumberRow<T>`: a number row bound to a `double?` field |

New, dive (`lib/features/dive_log/presentation/widgets/dive_detail/editing/`):

| File | Responsibility |
| --- | --- |
| `dive_altitude_fields.dart` | The Altitude card's fields and `fillAltitudeIfEmpty` |
| `dive_environment_fields.dart` | The Environment card's fields, `setEntryMethod`, `applyFetchedWeather` |
| `dive_altitude_card_editor.dart` | Altitude editor |
| `dive_environment_card_editor.dart` | Environment editor |
| `dive_card_presence.dart` | `diveCardIsShown`: whether the page is showing a card |

Modified: `dive.dart`, `edit_session.dart`, `record_edit_controller.dart`, `record_card_header.dart`, `record_card_frame.dart`, `dive_edit_save_service.dart`, `dive_edit_cards.dart`, `dive_detail_section_list.dart`, `dive_detail_section_gates.dart`, `dive_detail_altitude_section.dart`, `dive_detail_environment_section.dart`, `dive_detail_page_editing.dart`, the 11 ARB files.

---

### Task 1: `Dive.copyWith` can clear the values these cards edit

`copyWith` keeps the old value when passed null (`airTemp: airTemp ?? this.airTemp`). Seven fields already have a `clear…` flag (`clearName`, `clearExitTime` and others, `dive.dart:839-932`). An editor that writes one field at a time needs the same for each nullable field it owns.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart:834-1060` (`copyWith`)
- Test: `test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart`

**Interfaces:**
- Produces: seventeen `bool` parameters on `Dive.copyWith`, each defaulting to false: `clearAirTemp`, `clearCurrentDirection`, `clearCurrentStrength`, `clearSwellHeight`, `clearSurfaceConditions`, `clearEntryMethod`, `clearExitMethod`, `clearAltitude`, `clearSurfacePressure`, `clearWindSpeed`, `clearWindDirection`, `clearCloudCover`, `clearPrecipitation`, `clearHumidity`, `clearWeatherDescription`, `clearWeatherSource`, `clearWeatherFetchedAt`. Each follows the existing form: `altitude: clearAltitude ? null : (altitude ?? this.altitude)`.

- [ ] **Step 1: Write the failing test**

One table drives all seventeen, so a flag added without its body fails:

```dart
final full = Dive(
  id: 'd', dateTime: DateTime(2024),
  airTemp: 21, currentDirection: CurrentDirection.north, currentStrength: CurrentStrength.light,
  swellHeight: 1.5, surfaceConditions: 'Calm', entryMethod: EntryMethod.shore, exitMethod: EntryMethod.boat,
  altitude: 1200, surfacePressure: 0.87, windSpeed: 4, windDirection: CurrentDirection.east,
  cloudCover: CloudCover.values.first, precipitation: Precipitation.values.first, humidity: 60,
  weatherDescription: 'Clear', weatherSource: WeatherSource.openMeteo, weatherFetchedAt: DateTime(2024, 1, 2),
);
final cases = <String, (Dive Function(Dive), Object? Function(Dive))>{
  'airTemp': ((d) => d.copyWith(clearAirTemp: true), (d) => d.airTemp),
  // ... one line per flag
};
for (final entry in cases.entries) {
  test('clear ${entry.key} sets it to null and nothing else', () {
    final (clear, read) = entry.value;
    expect(read(full), isNotNull);
    final cleared = clear(full);
    expect(read(cleared), isNull);
    // Every other value in the table is untouched.
    for (final other in cases.entries.where((e) => e.key != entry.key)) {
      expect(other.value.$2(cleared), other.value.$2(full), reason: other.key);
    }
  });
}
test('a clear flag wins over a value passed with it', () {
  expect(full.copyWith(altitude: 5, clearAltitude: true).altitude, isNull);
});
test('copyWith with no flags keeps every value', () {
  expect(full.copyWith(), full);
});
```

Use whichever enum values exist; the test needs a non-null value, not a particular one.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart`
Expected: FAIL to compile, the flags do not exist.

- [ ] **Step 3: Add the seventeen flags and their bodies**

- [ ] **Step 4: Run it and confirm it passes**

Run: the same command, then `flutter test test/features/dive_log/domain/`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart
git commit -m "feat(dive-log): let copyWith clear a dive's conditions and altitude values"
```

---

### Task 2: A closed card redraws when a rule changes it

Plan 1's controller notifies when the set of changed cards moves, so the page does not rebuild on every keystroke. A rule that changes a card which is closed and already marked changed (the weather fetch filling a surface pressure, later a site choice) would therefore not redraw it.

**Files:**
- Modify: `lib/shared/widgets/record_editing/edit_session.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart` (`_onSessionChanged`, `openCard`, `closeCard`)
- Test: `test/shared/widgets/record_editing/edit_session_test.dart`, `test/shared/widgets/record_editing/record_edit_controller_test.dart`

**Interfaces:**
- Produces: `int EditSession.revisionOf(String cardId)`: starts at 0, and goes up by one each time `set` changes or clears a pending value of a field that card owns. The controller notifies when the changed-card set moves, as now, and also when the revision of a card that is not open has moved since listeners were last told.

- [ ] **Step 1: Write the failing tests**

```dart
// edit_session_test.dart
test('revisionOf counts changes to a card and ignores no-ops', () {
  final s = EditSession(const _Rec(notes: 'a'));
  expect(s.revisionOf('notes'), 0);
  s.set(_notes, 'b'); s.set(_notes, 'b'); s.set(_notes, 'c');
  expect(s.revisionOf('notes'), 2);
  expect(s.revisionOf('details'), 0);
});

// record_edit_controller_test.dart: add `_depth`, an EditField over the `depth` that
// _Rec already has, with cardId 'details'.
test('a change to a closed card that is already changed notifies', () {
  final c = _controller()..unlock(const _Rec())..openCard('notes');
  c.session!.set(_depth, 5);          // 'details' becomes changed: told
  var told = 0; c.addListener(() => told++);
  c.session!.set(_depth, 6);          // closed, changed again
  expect(told, 1);
});
test('further typing in an open card still does not notify', () {
  final c = _controller()..unlock(const _Rec())..openCard('notes');
  c.session!.set(_notes, 'b');
  var told = 0; c.addListener(() => told++);
  c.session!.set(_notes, 'bc'); c.session!.set(_notes, 'bcd');
  expect(told, 0);
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: the first two FAIL (the first does not compile). The third passes today; it is there so the change does not start notifying on every keystroke.

- [ ] **Step 3: Implement**

The controller keeps the revision it last told listeners about for each card. Opening or closing a card resets that card's remembered revision to the current one, so an editor's own typing while open is never replayed as a change when it closes.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: PASS, including every plan 1 test.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/edit_session.dart lib/shared/widgets/record_editing/record_edit_controller.dart test/shared/widgets/record_editing/
git commit -m "feat(shared): redraw a closed card when something else changes it"
```

---

### Task 3: A card with unreadable input cannot be closed or saved

The design says Save validates the working copy, so a closed card is still checked, and that the first failing card opens, scrolls into view and shows its error. There are two ways a card can fail:

- **Text that is not a value** (`1.2.3`). It never reaches the working copy, so no function of the working copy can see it. This task handles it: the card holding it cannot be closed, so it is always the open one, and Save refuses and scrolls to it. What the diver sees is what the design describes.
- **A value that breaks a rule** (an exit before the entry). That is a function of the working copy and is checked on closed cards too. No card in this plan has such a rule; it arrives with the first card that does, as `EditCard.validate`.

The mark lives on the controller, not the session, because it describes what is in a text field and the session knows nothing about widgets.

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart`
- Modify: `lib/shared/widgets/record_editing/record_card_frame.dart` (becomes a `StatefulWidget`)
- Modify: the 11 ARB files and generated l10n
- Test: `test/shared/widgets/record_editing/record_edit_controller_test.dart`, `test/shared/widgets/record_editing/record_card_frame_test.dart`

**Interfaces:**
- Produces, on `RecordEditController<T>`:

```dart
/// Cards holding input that cannot be read as a value.
Set<String> get invalidCardIds;
void setFieldInvalid(String cardId, String fieldId, {required bool invalid});
/// The card last asked to scroll into view, with a serial that goes up on
/// every request so the same card can be asked twice.
({String cardId, int serial})? get revealRequest;
/// True when the last save was refused for unreadable input. Cleared by the
/// next save and by lock.
bool get refusedForInvalidInput;
```

  `closeCard` leaves an invalid card open and asks for it to be revealed. `save` returns false without calling `onSave` while any card is invalid, sets `refusedForInvalidInput`, and asks for the first invalid card (in the order they became invalid) to be revealed. `lock` forgets all of it.

- New string, after the other `recordEdit_` keys: `recordEdit_fixInvalid` = `Some values can't be read. Fix them before saving.` Description: "Message shown when Save is refused because a field holds text that is not a valid value."

- [ ] **Step 1: Add the string to all 11 ARB files and regenerate**

Run: `flutter gen-l10n`, then `flutter test test/l10n/`
Expected: PASS.

- [ ] **Step 2: Write the failing tests**

```dart
test('an invalid card cannot be closed', () {
  final c = _controller()..unlock(const _Rec())..openCard('notes');
  c.setFieldInvalid('notes', 'notes', invalid: true);
  c.closeCard('notes');
  expect(c.openCardIds, {'notes'});
  expect(c.revealRequest!.cardId, 'notes');
});
test('save is refused while a card is invalid', () async {
  var calls = 0;
  final c = _controller(onSave: (_) async => calls++)..unlock(const _Rec())..openCard('notes');
  c.session!.set(_notes, 'b');
  c.setFieldInvalid('notes', 'notes', invalid: true);
  expect(await c.save(), isFalse);
  expect(calls, 0);
  expect(c.refusedForInvalidInput, isTrue);
  expect(c.saveError, isNull);
  expect(c.isUnlocked, isTrue);
});
test('a card is valid again once every field of it is', () {
  // two fields invalid, clear one: still invalid; clear the other: valid, closes.
});
test('lock forgets invalid input', () {
  // setFieldInvalid, lock, unlock: invalidCardIds empty, refusedForInvalidInput false.
});
test('asking twice for the same card gives a new serial', ...);

// record_card_frame_test.dart: the frame sits below the fold of a 300 px high scroll view.
testWidgets('a reveal request scrolls the card into view', (tester) async {
  // controller.openCard('notes'); pump; card top is below 300.
  // controller.setFieldInvalid('notes','notes', invalid: true); await controller.save(); pumpAndSettle.
  // tester.getRect(find.byKey(ValueKey('editor'))).top is inside the viewport.
});
```

- [ ] **Step 3: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/`
Expected: the new tests FAIL.

- [ ] **Step 4: Implement**

`RecordCardFrame` remembers the last serial it acted on. When the controller's `revealRequest` names its card with a newer serial, it calls `Scrollable.ensureVisible(context, alignment: 0.1, duration: const Duration(milliseconds: 200))` after the frame.

- [ ] **Step 5: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/ test/l10n/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/arb lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): refuse to close or save a card with unreadable input"
```

---

### Task 4: Field bindings and the number row

**Files:**
- Create: `lib/shared/widgets/record_editing/field_text_binding.dart`
- Create: `lib/shared/widgets/record_editing/record_number_row.dart`
- Test: `test/shared/widgets/record_editing/field_text_binding_test.dart`
- Test: `test/shared/widgets/record_editing/record_number_row_test.dart`

**Interfaces:**
- Consumes: `EditSession`, `EditField`, `RecordEditScope` (plan 1, Task 3 above); `readNumber`, `numberValidator`, `numberInputFormatters` (`lib/shared/widgets/forms/`); `formatFixedForInput` (`lib/core/utils/number_input.dart:181`); `FormRow.text`.
- Produces:

```dart
/// What a field's text reads as.
sealed class FieldInput<V> { const FieldInput(); }
final class FieldValue<V> extends FieldInput<V> { const FieldValue(this.value); final V value; }
final class FieldUnreadable<V> extends FieldInput<V> { const FieldUnreadable(); }

/// Keeps a text controller in step with one field of a session.
class FieldTextBinding<T, V> {
  FieldTextBinding({
    required this.session,
    required this.field,
    required this.format,          // V -> the text to show
    required this.parse,           // text -> FieldInput<V>
    this.onUnreadableChanged,      // told when the text becomes, or stops being, unreadable
  });
  final EditSession<T> session;
  final EditField<T, V> field;
  final String Function(V value) format;
  final FieldInput<V> Function(String text) parse;
  final ValueChanged<bool>? onUnreadableChanged;
  TextEditingController get controller;
  void dispose();
}

class RecordNumberRow<T> extends StatefulWidget {
  const RecordNumberRow({
    super.key,
    required this.session,
    required this.field,           // EditField<T, double?>, in canonical units
    required this.label,
    this.suffixText,
    this.placeholder,
    this.fractionDigits = 0,
    this.toDisplay,                // canonical -> shown; null means the same
    this.fromDisplay,              // shown -> canonical
    this.integer = false,
    this.allowNegative = true,
  });
}
```

The binding's two rules:
- **The diver edits the text.** If it reads as a value, `session.set(field, value)` and report readable; if not, report unreadable and leave the session alone. A change of selection alone, or text the binding set itself, is not an edit.
- **The session changes.** If the current text is unreadable, leave it: the diver is fixing it. Otherwise, if the value the text reads as is not `field.same` as the session's value, replace the text with `format(session.valueOf(field))`.

- [ ] **Step 1: Write the failing tests**

```dart
// field_text_binding_test.dart, with _Rec { double? altitude } and a field owned by 'altitude'.
// format: metres -> feet with 0 decimals; parse: feet -> metres via readNumber.
test('starts with the formatted value and does not dirty the session', () {
  final s = EditSession(const _Rec(altitude: 1234.5));
  final b = binding(s);
  expect(b.controller.text, '4050');
  expect(s.isDirty, isFalse);
});
test('moving the caret is not an edit', () {
  final b = binding(s); b.controller.selection = const TextSelection.collapsed(offset: 1);
  expect(s.isDirty, isFalse);
});
test('typing a readable value sets the field in canonical units', () {
  b.controller.text = '100';
  expect(s.valueOf(altitude), closeTo(30.48, 0.001));
});
test('emptying the text sets the field to null', () {
  b.controller.text = '';
  expect(s.valueOf(altitude), isNull);
  expect(s.isDirty, isTrue);
});
test('unreadable text leaves the session alone and is reported once', () {
  final seen = <bool>[];
  b.controller.text = '1.2.3';
  expect(s.isDirty, isFalse); expect(seen, [true]);
  b.controller.text = '12'; expect(seen, [true, false]);
});
test('typing the shown value back clears the change', ...);
// text '4050' again after '100': field.same decides. The field's `equals` must treat two
// values that format the same as equal, or this round trip is a change: see Step 3.
test('an untouched field follows a rebase; edited text is kept', ...);
test('text mid-edit that reads the same as the session is left alone', () {
  b.controller.text = '100.'; // reads as 100, same value: the trailing dot survives
  s.set(other, 'x');          // any session change
  expect(b.controller.text, '100.');
});
test('dispose stops following the session', ...);

// record_number_row_test.dart, pumped under RecordEditScope with a real controller.
testWidgets('typing unreadable text marks the card invalid and shows the message', ...);
// enterText '1.2.3' -> controller.invalidCardIds == {'altitude'}; numberInput_invalidNumber text shown.
testWidgets('fixing it clears the mark', ...);
testWidgets('a negative number is refused when allowNegative is false', ...);
testWidgets('the row is disposed with unreadable text: the mark is cleared', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/field_text_binding_test.dart test/shared/widgets/record_editing/record_number_row_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`RecordNumberRow` builds `FormRow.text(label:, controller: binding.controller, suffixText:, placeholder:, keyboardType: TextInputType.numberWithOptions(decimal: !integer, signed: allowNegative), inputFormatters: numberInputFormatters(), inputValidator: numberValidator(context, integer: integer, allowNegative: allowNegative))`. Its `parse` switches on `readNumber(text, integer:, allowNegative:)`: `NumberBlank` is `FieldValue(null)`, `NumberValue` is `FieldValue(fromDisplay(value))`, `NumberInvalid` is `FieldUnreadable()`. Its `format` is `formatFixedForInput(toDisplay(value), fractionDigits)`, and the empty string for null. It reports unreadable text to `RecordEditScope.maybeOf<T>(context)?.setFieldInvalid(field.cardId, field.id, invalid: ...)`, and clears its mark in `dispose`.

Number fields compare by what the diver sees, so that a stored 1,234.5 m and the 1,234.44 m that "4050 ft" reads back as are the same value. `RecordNumberRow` does not rely on `field.equals` for this: it wraps the field it is given in one whose `equals` is "both null, or both format to the same text", and binds to that.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/` then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): bind text and number rows to a field of the sitting"
```

---

### Task 5: A sitting can hold a write to another record

**Files:**
- Modify: `lib/shared/widgets/record_editing/edit_session.dart`
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting`)
- Test: `test/shared/widgets/record_editing/edit_session_test.dart`
- Test: `test/features/dive_log/data/services/dive_edit_save_service_test.dart`

**Interfaces:**
- Produces:

```dart
// EditSession
/// Holds [write] to run when the sitting is saved. A second call with the
/// same [key] replaces the first. Held writes do not make the session dirty.
void holdWrite(String key, Future<void> Function() write);
bool get hasHeldWrites;
/// Runs every held write, in the order they were first held.
Future<void> runHeldWrites();

// DiveEditSaveService.save gains
Future<void> Function()? alsoWrite,   // run inside the transaction, after the dive is written
```

`alsoWrite` is not called when `apply` changed nothing.

- [ ] **Step 1: Write the failing tests**

```dart
// edit_session_test.dart
test('held writes run in order, once each, and a key replaces', ...);
test('a held write does not make the session dirty', ...);

// dive_edit_save_service_test.dart
test('alsoWrite runs in the same transaction as the dive', () async {
  await service.save(diveId: 'dive', apply: (d) => d.copyWith(notes: 'Current'),
      changedCardIds: ['notes'],
      alsoWrite: () => db.customStatement("UPDATE divers SET name = 'changed' WHERE id = 'me'"));
  // both the dive and the diver row changed
});
test('a failing alsoWrite rolls the dive write back', () async {
  await expectLater(
    service.save(diveId: 'dive', apply: (d) => d.copyWith(notes: 'Current'),
        changedCardIds: ['notes'], alsoWrite: () async => throw StateError('no')),
    throwsStateError);
  expect((await stored()).notes, 'Calm');
  expect(await logEvents(db), isEmpty);
});
test('alsoWrite is not called when nothing changed', ...);
```

The second test is the rollback test plan 1 left for the first plan that writes after `updateDive`.

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/edit_session_test.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement, and pass `alsoWrite: session.runHeldWrites` from `_saveSitting`**

After a save whose session had held writes, `_saveSitting` also calls `ref.read(siteListNotifierProvider.notifier).refresh()` (`site_providers.dart:579`), read before the first `await` like the other two.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/edit_session.dart lib/features/dive_log/data/services/dive_edit_save_service.dart lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart test/shared/widgets/record_editing/edit_session_test.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart
git commit -m "feat(dive-log): hold a write to another record until the sitting is saved"
```

---

### Task 6: The strip asks the page what it shows

The Add strip decides a card is absent from `EditCard.isEmpty` alone. The Environment card also shows when there is satellite data for the dive, which only a provider knows (`watchHasEnvironmentData`, `dive_detail_section_gates.dart:42`), so the strip would offer a card the page is already showing.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_addStripEntries`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence_test.dart`

**Interfaces:**
- Produces:

```dart
/// Whether the dive page shows [id]'s card for [dive], apart from the
/// diver having hidden it.
bool diveCardIsShown(WidgetRef ref, DiveDetailSectionId id, Dive dive);
```

  `environment` is `watchHasEnvironmentData(ref, dive)`, whether or not it has a card yet. Any other section with a card is `!card.isEmpty(dive)`. A section with no card is true.

- [ ] **Step 1: Write the failing tests**

In a `ProviderScope` with a `Consumer`, to get a `WidgetRef`:

```dart
testWidgets('notes is always shown; tags follows the dive', ...);
testWidgets('environment follows what the dive has logged', ...);
// a dive with airTemp: true. A dive with nothing logged and no site: false.
testWidgets('environment is shown for satellite conditions alone', ...);
// Override the providers watchSatelliteWaterConditions reads, the way
// test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart does.
testWidgets('a section with no card is shown', ...);   // DiveDetailSectionId.profile
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence_test.dart`
Expected: FAIL to compile, `diveCardIsShown` does not exist.

- [ ] **Step 3: Implement, and use it in `_addStripEntries`**

`card.isEmpty(working)` becomes `!diveCardIsShown(ref, section.id, working)`.

- [ ] **Step 4: Run and confirm**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "feat(dive-log): let the dive page say which cards it is showing"
```

---

### Task 7: The Altitude card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart`
- Modify: `lib/shared/widgets/record_editing/record_card_header.dart` (optional `leading`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart`: the mismatch note's `onTap` (line 29), the title row (106-122), the group banner (173-221)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_test.dart`
- Test: `test/shared/widgets/record_editing/record_card_frame_test.dart`

**Interfaces:**
- Consumes: `RecordNumberRow` (Task 4), `EditSession.holdWrite` (Task 5), the clear flags (Task 1); `RecordCardFrameScope.maybeOf(context)` and its `onOpen` (plan 1); `AltitudeResolver` (`lib/features/weather/domain/services/altitude_resolver.dart:23`), `elevationServiceProvider` (`weather_providers.dart:23`), `siteRepositoryProvider` (`site_providers.dart:212`), `SiteRepository.updateSiteAltitude(String siteId, double altitudeMeters)`; `AltitudeCalculator.calculateBarometricPressure` (`lib/core/deco/altitude_calculator.dart:155`); `UnitFormatter.convertSurfacePressure`, `surfacePressureToBar`, `surfacePressureSymbol`.
- Produces:

```dart
// dive_altitude_fields.dart
final EditField<Dive, double?> diveAltitudeField;         // id 'altitude', metres
final EditField<Dive, double?> diveSurfacePressureField;  // id 'surfacePressure', bar
/// Looks the altitude up when the sitting has none, sets it, and holds the
/// site write the lookup asks for. Does nothing when an altitude is set.
Future<void> fillAltitudeIfEmpty(
  EditSession<Dive> session, {
  required AltitudeResolver resolver,
  required Future<void> Function(String siteId, double altitudeMeters) writeSiteAltitude,
});

// record_card_header.dart: RecordCardHeader gains
final Widget? leading;   // drawn before the title, in every state

// dive_detail_altitude_section.dart
/// The coloured banner naming an altitude group. Draws nothing at sea level.
class AltitudeGroupBanner extends StatelessWidget {
  const AltitudeGroupBanner({super.key, required this.group});
  final AltitudeGroup group;
}
```

  Both fields have `cardId: DiveDetailSectionId.altitude.name`. Their `write` uses the clear flag for null: `(d, v) => d.copyWith(altitude: v, clearAltitude: v == null)`.

  `diveEditCards[altitude]`: title `l10n.diveLog_detail_section_altitudeDive`; `isEmpty: (d) => d.altitude == null || d.altitude! <= 0`; editor `DiveAltitudeCardEditor`.

- [ ] **Step 1: Write the failing tests**

```dart
test('the altitude card is left out at or below sea level', ...);
test('writing null clears the value', () {
  expect(diveAltitudeField.write(dive.copyWith(altitude: 900), null).altitude, isNull);
});

group('fillAltitudeIfEmpty', () {
  // A fake ElevationService returns a number or null and counts its calls.
  test('does nothing when an altitude is already set', ...);          // no lookup
  test('sets the altitude from the dive GPS and holds no site write', ...);
  test('uses the site altitude without a lookup', ...);
  test('a site coordinate lookup sets it and holds the site write', () async {
    // session.hasHeldWrites true; await session.runHeldWrites() -> writeSiteAltitude('site-1', 512).
  });
  test('a diver who typed a value while the lookup ran keeps it', () async {
    // start the fill with a gated elevation service, session.set(diveAltitudeField, 10),
    // release the gate: the value is still 10, nothing held.
  });
  test('a failed lookup changes nothing', ...);
});

testWidgets('metric: altitude in metres, pressure in mbar', ...);
// 1200 m, 0.87 bar: rows show '1200' with 'm' and '870' with 'mbar'.
testWidgets('imperial: altitude in feet, pressure in inHg', ...);
// the same dive: '3937' with 'ft' and '25.69' with 'inHg'.
testWidgets('opening the editor on a high dive leaves the sitting clean', ...);   // both unit systems
testWidgets('with no pressure stored, the row hints the pressure for the altitude', ...);
// altitude 2000 m: the hint is formatFixedForInput(units.convertSurfacePressure(
//   AltitudeCalculator.calculateBarometricPressure(2000)), 0). Typing 0 m: the hint is '1013'.
testWidgets('typing an altitude shows its group banner', ...);
// enter 2500 (metres): one AltitudeGroupBanner whose group is fromAltitude(2500).
testWidgets('at sea level there is no banner', ...);

// The read card.
testWidgets('the read card title is the shared header, with its info button', ...);
// DiveAltitudeSection alone: Icons.terrain, the title in titleMedium, HeaderInfoButton, no pencil.
testWidgets('the banner range is translated', ...);
// pump DiveAltitudeSection under Locale('de'), altitude 500 m:
// lookupAppLocalizations(const Locale('de')).enum_altitudeGroup_group1_range is found.
testWidgets('unlocked, the mismatch note opens the Altitude card', ...);
// RecordEditScope(unlocked controller) > RecordCardFrame(card: diveEditCards[altitude]!) >
// DiveAltitudeMismatchNote. Tap: controller.openCardIds contains 'altitude'.
testWidgets('locked, the mismatch note goes to the edit page as before', ...);

// record_card_frame_test.dart
testWidgets('a header leading widget shows locked, unlocked and open', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`DiveAltitudeCardEditor` is a `ConsumerStatefulWidget`, built inside a `ListenableBuilder` on the session. Rows:

1. `RecordNumberRow(field: diveAltitudeField, label: l10n.diveLog_edit_label_altitude, suffixText: units.altitudeSymbol, toDisplay: units.convertAltitude, fromDisplay: units.altitudeToMeters, fractionDigits: 0)`.
2. `AltitudeGroupBanner(group: AltitudeGroup.fromAltitude(session.valueOf(diveAltitudeField)))`.
3. `RecordNumberRow(field: diveSurfacePressureField, label: l10n.diveLog_edit_label_surfacePressure, suffixText: units.surfacePressureSymbol, toDisplay: units.convertSurfacePressure, fromDisplay: units.surfacePressureToBar, fractionDigits: <0 for mbar, 2 for inHg, as formatSurfacePressure uses>, allowNegative: false, placeholder: <the calculated pressure for the session's altitude, or for 0 m when it has none, formatted the same way>)`.

In `initState`, after the first frame, it calls `fillAltitudeIfEmpty` with `AltitudeResolver(elevationService: ref.read(elevationServiceProvider))` and `ref.read(siteRepositoryProvider).updateSiteAltitude`. The fill reads `session.working` for `entryLocation`, `exitLocation` and `site`, and checks again after the lookup that the altitude is still null before setting it.

`AltitudeGroupBanner` is the read card's banner moved out of `DiveAltitudeSection.build` with the three colour and icon helpers it uses. One change: the range line is `group.localizedRange(context.l10n)`.

`DiveAltitudeSection`'s title row becomes `RecordCardHeader(leading: <the terrain icon and its gap>, title: ..., trailing: <the HeaderInfoButton>)`.

`DiveAltitudeMismatchNote.onTap`: `RecordCardFrameScope.maybeOf(context)?.onOpen ?? () => context.push('/dives/${dive.id}/edit')`.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/shared/widgets/record_editing/ test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail lib/shared/widgets/record_editing/record_card_header.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_test.dart test/shared/widgets/record_editing/record_card_frame_test.dart
git commit -m "feat(dive-log): edit the Altitude card in place"
```

---

### Task 8: The Environment card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart:47` (make `_hasLoggedEnvironmentData` public as `hasLoggedEnvironmentData`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart:58-61` (title)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 4 and 7; `EnumPickerRow` (`lib/shared/widgets/forms/enum_picker_row.dart`); `SuggestedTextRow` (`edit_sections/suggested_text_row.dart`); `FormOverline`, `FormOverlineAction` (`lib/shared/widgets/forms/form_overline.dart`); `weatherServiceProvider` (`weather_providers.dart:17`), `WeatherService.fetchWeather({latitude, longitude, date, entryTime})`, `WeatherData`.
- Produces:

```dart
// dive_environment_fields.dart: fifteen fields, all cardId 'environment', all canonical units.
final EditField<Dive, double?> diveAirTempField;                  // 'airTemp', Celsius
final EditField<Dive, double?> diveWindSpeedField;                // 'windSpeed', m/s
final EditField<Dive, CurrentDirection?> diveWindDirectionField;  // 'windDirection'
final EditField<Dive, CloudCover?> diveCloudCoverField;           // 'cloudCover'
final EditField<Dive, Precipitation?> divePrecipitationField;     // 'precipitation'
final EditField<Dive, double?> diveHumidityField;                 // 'humidity', 0 to 100
final EditField<Dive, String?> diveWeatherDescriptionField;       // 'weatherDescription'
final EditField<Dive, WeatherSource?> diveWeatherSourceField;     // 'weatherSource'
final EditField<Dive, DateTime?> diveWeatherFetchedAtField;       // 'weatherFetchedAt'
final EditField<Dive, CurrentDirection?> diveCurrentDirectionField;
final EditField<Dive, CurrentStrength?> diveCurrentStrengthField;
final EditField<Dive, double?> diveSwellHeightField;              // metres
final EditField<Dive, String?> diveSurfaceConditionsField;        // trimmed, null when blank
final EditField<Dive, EntryMethod?> diveEntryMethodField;
final EditField<Dive, EntryMethod?> diveExitMethodField;

/// Sets the entry method. The exit method follows it while the two are
/// linked: the exit is unset, or equal to the entry it is replacing.
void setEntryMethod(EditSession<Dive> session, EntryMethod? value);

/// Writes a fetched forecast into the sitting, as the dive form does.
void applyFetchedWeather(EditSession<Dive> session, WeatherData data, {required DateTime now});
```

  `applyFetchedWeather` rules, from `_fetchWeather` (`dive_edit_page.dart:5731-5860`):
  - Overwrites, when the fetched value is not null: wind speed, wind direction, cloud cover, precipitation, humidity. Overwrites the description only when the fetched one is not empty.
  - Fills only when the sitting has none: air temperature, and surface pressure (`diveSurfacePressureField`, the Altitude card's).
  - Sets `diveWeatherSourceField` to `WeatherSource.openMeteo` and `diveWeatherFetchedAtField` to `now`.
  - Touches nothing else.

  `diveEditCards[environment]`: title `l10n.diveLog_detail_section_environment`; `isEmpty: (d) => !hasLoggedEnvironmentData(d)`; editor `DiveEnvironmentCardEditor`.

- [ ] **Step 1: Write the failing tests**

```dart
test('every field clears with null', () {
  // table over the fifteen fields: write(full, null) reads back null.
});
test('surface conditions are trimmed, and blank is null', ...);

group('setEntryMethod', () {
  test('an unset exit follows the entry', ...);
  test('an exit equal to the old entry follows the new one', ...);
  test('an exit the diver set differently is kept', ...);
  test('clearing the entry clears a linked exit', ...);
});

group('applyFetchedWeather', () {
  test('overwrites the five weather values that came back, and the description', ...);
  test('leaves a value alone when the forecast has none for it', ...);
  test('an empty description does not replace a typed one', ...);
  test('fills air temperature and surface pressure only when empty', ...);
  test('stamps the source and the time', ...);
  test('marks the Altitude card changed when it filled the pressure', () {
    expect(session.changedCardIds, containsAll(['environment', 'altitude']));
  });
});

// Editor, pumped under ProviderScope with weatherServiceProvider overridden by a fake that
// returns a WeatherData, null, or throws, optionally behind a Completer.
testWidgets('rows show in the order of the read card', ...);
// Weather overline, air temp, surface pressure, wind speed, wind direction, cloud cover,
// precipitation, humidity, description; dive conditions overline, current direction,
// current strength, swell height, surface conditions, entry method, exit method.
// Compare dy of each label.
testWidgets('a stored surface pressure shows as a row that cannot be typed in', ...);
// 0.87 bar: units.formatSurfacePressure(0.87) is found, and no TextField holds it.
testWidgets('with no surface pressure there is no such row', ...);
testWidgets('the entry row hints the site method when the dive has none', ...);
// site.soleEntryMethod is shore, dive.entryMethod null: the shore name shows as the hint,
// and session.valueOf(diveEntryMethodField) is still null.
testWidgets('Fetch is disabled for a dive whose site has no coordinates', ...);
testWidgets('Fetch asks first when weather values are already set', ...);
// the dialog text is diveLog_edit_fetchWeatherConfirm; declining calls nothing.
testWidgets('a successful fetch fills the rows and says so', ...);
// diveLog_edit_weatherFetched shown; wind speed row shows the converted value.
testWidgets('no forecast says it is unavailable and changes nothing', ...);
testWidgets('a fetch that throws says it is unavailable', ...);
testWidgets('a fetch that returns after the editor has gone sets nothing', (tester) async {
  // tap Fetch with a gated fake; replace the editor with SizedBox; release the gate; pump.
  expect(session.isDirty, isFalse);
  expect(tester.takeException(), isNull);
});
testWidgets('Fetch shows busy while it runs and not after', ...);
testWidgets('the read card title is the shared header', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`DiveEnvironmentCardEditor` is a `ConsumerStatefulWidget` built inside a `ListenableBuilder` on the session. In order:

- `FormOverline(label: l10n.diveLog_detail_subsection_weather, actions: [FormOverlineAction(label: l10n.diveLog_edit_button_fetchWeather, busy: _fetching, onPressed: <null unless session.working.site?.hasCoordinates is true>)])`
- Air temperature: `RecordNumberRow`, `diveLog_edit_label_airTemp`, `units.temperatureSymbol`, `units.convertTemperature` / `units.temperatureToCelsius`, 0 decimals.
- Surface pressure, only when the sitting has one: `DiveDetailRow(label: l10n.diveLog_detail_label_surfacePressure, value: units.formatSurfacePressure(...))`, as the read card draws it (`dive_detail_environment_section.dart:76-80`).
- Wind speed: `diveLog_edit_label_windSpeed`, `units.windSpeedSymbol`, `units.convertWindSpeed` / `units.windSpeedToMs`, 1 decimal, `allowNegative: false`.
- Wind direction, cloud cover, precipitation: `EnumPickerRow`, labels `diveLog_edit_label_windDirection`, `_cloudCover`, `_precipitation`, `displayName: (v) => v.localizedName(l10n)`, `onChanged: (v) => session.set(field, v)`.
- Humidity: `diveLog_edit_label_humidity`, suffix `%`, 0 decimals, `allowNegative: false`.
- Description: `FormRow.text(label: l10n.diveLog_edit_label_weatherDescription, maxLines: 2)` on a `FieldTextBinding` whose `parse` gives null for empty text.
- `FormOverline(label: l10n.diveLog_detail_subsection_diveConditions)`
- Current direction, current strength: `EnumPickerRow`, labels `diveLog_edit_label_currentDirection`, `_currentStrength`.
- Swell height: `diveLog_edit_label_swellHeight`, `units.depthSymbol`, `units.convertDepth` / `units.depthToMeters`, 1 decimal, `allowNegative: false`.
- Surface conditions: `SuggestedTextRow(label: l10n.diveLog_edit_label_surfaceConditions, controller: <binding.controller>, field: DiveTextSuggestionField.surfaceConditions, capitalization: TextCapitalization.sentences)`.
- Entry method: `EnumPickerRow`, `diveLog_edit_label_entryMethod`, `placeholder: session.working.site?.soleEntryMethod?.localizedName(l10n)`, `onChanged: (v) => setEntryMethod(session, v)`. Exit method: `EnumPickerRow`, `diveLog_edit_label_exitMethod`, plain `session.set`.

The fetch: when wind speed, humidity, description, wind direction, cloud cover or precipitation is set, ask with an `AlertDialog` whose title and body are `diveLog_edit_fetchWeatherConfirm`, as the form does (`dive_edit_page.dart:5735-5762`). Call `fetchWeather` with the site's latitude and longitude, `date: working.dateTime`, `entryTime: working.effectiveEntryTime`. Check `mounted` after every `await`. On a result, `applyFetchedWeather(session, data, now: DateTime.now())`, then `fillAltitudeIfEmpty` as the Altitude editor calls it, then the snackbar `diveLog_edit_weatherFetched`. On null or a throw, the snackbar `diveLog_edit_fetchWeatherUnavailable`. `_fetching` is cleared in `finally`.

The editor will pass 400 lines. Put the weather rows and the dive-conditions rows in two private widgets in the same file, and split the file if it passes 600.

`DiveEnvironmentSection`'s title `Text` becomes `RecordCardHeader(title: ...)`.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail test/features/dive_log/presentation/widgets/dive_detail
git commit -m "feat(dive-log): edit the Environment card in place, with the weather fetch"
```

---

### Task 9: Paired cards are framed, and a card stays put while it is open

Cards that sit side by side are built in `_buildPairCards` (`dive_detail_section_list.dart:460`) and never pass through `_framed`, so on a wide screen the Environment card has no pencil. And the Details and Environment pair is built only when `watchHasEnvironmentData` is true (`dive_detail_section_list.dart:486`): an empty Environment card opened from the strip would start full width, then jump beside Details on the first value typed, and its editor would be rebuilt with its focus and text lost.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (`build` line 141, `_buildPairCards`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart`

**Interfaces:**
- Consumes: `_framed` (plan 1), the Environment and Altitude cards (Tasks 7 and 8).
- Produces: no new names. The rule for later plans: a pair is built when both of its cards are shown, counting a card as shown while it is open.

- [ ] **Step 1: Write the failing tests**

At 1200 px wide, so pairs sit in a row. `tester.view` is restored with `addTearDown`.

```dart
testWidgets('locked: the pair draws no pencil', ...);
testWidgets('unlocked: a paired card gains a pencil and opens in its slot', (tester) async {
  // visible: details, environment; the dive has airTemp. Unlocked.
  // find.byTooltip('Edit Environment') one. Tap it: the editor is found, and the Details
  // card is still beside it (same dy, smaller dx).
});
testWidgets('an empty Environment card opened from the strip sits beside Details at once', ...);
// a dive with nothing logged; controller.addCard('environment'): the editor is beside Details.
testWidgets('typing its first value does not rebuild the editor', (tester) async {
  // as above. Keep tester.state(find.byType(DiveEnvironmentCardEditor)); enterText into
  // air temperature; pump. The State is identical and the field still has focus.
});
testWidgets('closed again with nothing in it, Details is full width', ...);
testWidgets('typing the first altitude does not rebuild the Altitude editor', ...);
// the single-card path: addCard('altitude') on a sea-level dive, enterText '120'.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart`
Expected: the pencil, strip and first-value tests FAIL. If the Altitude one passes already, keep it: it pins the single path.

- [ ] **Step 3: Implement**

`_buildPairCards` takes `open` from `build`, and passes each side through `_framed(pair.left, first, open)` and `_framed(pair.right, second, open)` before building `_PairCards`. `_framed` returns its input unchanged for a section with no card, so pairs without editors are untouched.

The Details and Environment pair is built when `watchHasEnvironmentData(ref, dive) || open.contains(DiveDetailSectionId.environment.name)`. While Environment is open with nothing to show, its side is the empty body `_framed` already gives an absent card.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart
git commit -m "feat(dive-log): frame paired cards and keep an open card where it is"
```

---

### Task 10: The page, end to end

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveAndReport`)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
- Test: `test/features/dive_log/data/services/dive_edit_save_service_test.dart`

**Interfaces:**
- Consumes: everything above. Produces no new names.

- [ ] **Step 1: Write the failing tests**

```dart
// dive_detail_page_unlock_test.dart; pumpPage's `visible` now also lists altitude and environment.
testWidgets('a sea-level dive with nothing logged offers Altitude and Environment', ...);
testWidgets('a dive showing satellite conditions is not offered Environment', ...);
testWidgets('unreadable input: Done and Save both refuse, and say why', (tester) async {
  // unlock; add Altitude from the strip; enterText '1.2.3' in the altitude row.
  // Tap Done: the editor is still open. Tap Save: the fake service was not called,
  // l10n.recordEdit_fixInvalid is shown, the page is still unlocked.
  // enterText '120'; Save: the fake got merged.altitude close to 120 and cards ['altitude'].
});
testWidgets('unreadable input is forgotten after Cancel', ...);
// '1.2.3', Cancel: Discard is not asked (the session is clean). Unlock again and add
// Altitude: Save is disabled and no message shows.
testWidgets('opening and closing a card in imperial units leaves the sitting clean', ...);
// imperial settings; stored altitude 1234.5 m and pressure 0.87 bar; unlock; open Altitude;
// tap each field; Done. Save is disabled.
testWidgets('emptying the altitude and saving stores no altitude', ...);
// merged.altitude isNull.
testWidgets('the entry method carries the exit method with it', ...);
testWidgets('a fetched pressure shows on the closed Altitude card', ...);
// altitude 900 m, no pressure; open Environment; Fetch returns 0.9 bar: the Altitude read
// card shows units.formatSurfacePressure(0.9) and carries the changed dot.

// dive_edit_save_service_test.dart
test('a cleared altitude is stored as null', () async {
  await dives.updateDive((await stored()).copyWith(altitude: 900));
  await service.save(diveId: 'dive',
      apply: (d) => diveAltitudeField.write(d, null), changedCardIds: ['altitude']);
  expect((await stored()).altitude, isNull);
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: the unreadable-input message test FAILs. Any other new test that passes at once is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Implement**

In `_saveAndReport`: when `editController.save()` returned false and `editController.refusedForInvalidInput` is true, show `l10n.recordEdit_fixInvalid`; otherwise the existing `recordEdit_saveFailed` branch.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Format, analyse, run the guards and the page tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/`
Run: every `test/features/dive_log/presentation/pages/dive_detail*_test.dart` file, and `test/features/dive_log/presentation/widgets/dive_detail/`.
Expected: PASS.
Run: `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: 800 or fewer.

- [ ] **Step 6: Look at it**

Render the page in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): the Altitude card open with a group banner, the Environment card open with a surface pressure row, Environment open beside Details at 1200 px wide, and a field with unreadable input. Light and dark. Check each picture by eye, fix what is wrong with a test first, and keep the pictures for the pull request. Take the Altitude read card before any change as well, for the before and after of the header.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart
git commit -m "feat(dive-log): refuse unreadable input on the dive page and say why"
```

---

## Pull request

One, `Refs #4527`, stacked on plan 1's pull request #4536 until that merges. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the pictures from Task 10 Step 6, with a line saying the unlocked page is unreachable without the build switch. Pushing and opening it waits for Eric.

---

## After the review

The plan was built as written, then reviewed as a whole branch. Review comments on plan 1's pull request (#4536) landed at the same time and were merged in. This is what differs from the task text above, for whoever writes plans 3 and 4.

### Names that changed

| Above | Now |
| --- | --- |
| `revealRequest` is `({cardId, serial})`; a frame ignores a request made before it mounted | `({cardId, fieldId, serial})`, answered once and then withdrawn with `revealHandled(serial)`. With no field, the card's frame answers (a card added from the strip, which `addCard` now asks for). With a field, that field's `RecordNumberRow` scrolls itself in (a refused Done or Save) |
| `RecordNumberRow` wraps its field in one that compares by formatted text | No wrapper. Typing the number the row already shows is no change; any other number is stored as typed. New `trimZeros` |
| `setEntryMethod(session, value)` | `setEntryMethod(session, value, exitFollows:)`, with `exitFollowsEntry(dive)` for the starting state. The editor remembers when the diver has edited the exit directly |
| Fifteen Environment fields, seventeen clear flags | Sixteen and eighteen: `diveWeatherCodeField`, `clearWeatherCode` |
| `EnumPickerRow(placeholder:)` for the site's entry method | `EnumPickerRow(hint:)`: shown on the resting row only, never as the name of the clear option |

### Added

- **A sitting is frozen while it is saved.** `EditSession.freeze()`, `thaw()`, `isFrozen`. `set` and `holdWrite` do nothing then, and `openCard`, `closeCard` and `addCard` are refused. `RecordEditLeaveGuard` takes no pointer or keyboard input and ignores Back until the save ends. Anything that writes to a sitting after an `await` checks `isDisposed` and `isFrozen` first.
- **A sitting belongs to one dive.** `lock()` is refused while a save is running; the save ends the sitting itself. A sitting starts from the dive the page is showing, which just after a save is ahead of the one last read. If the page is handed another dive, the sitting ends and the copy of a dive just saved is dropped, and a save is always made for the dive its sitting was opened on.
- **`EditField.alsoShownOn`.** Other cards that show a value without owning it. They are redrawn as it is typed. Surface pressure names Environment.
- **`RecordEditController.layoutRecord`.** The working record as it was when the first card opened; null when none is open. The section list and the Add strip decide which cards are present from it, so a card never appears above an open editor. Cards come and go when the last editor closes. `_sectionContent` and `_buildPairCards` take it as `presence`.
- **`EditCard.leading`**, drawn by the open card's header, so a card's icon does not vanish when it opens.
- **`UnitFormatter.surfacePressureDecimals`**, `fillAltitudeIfEmpty(stillWanted:)`, `EditSession.isDisposed`, `revisedCardIds`.
- **The unsaved-changes dot keeps its place** in an open card's header while there is none.

Added when #4536 merged and main was brought in, from its last review and from applying the same two rules to this plan's own code:

- **A stored record that arrives during a save is kept.** `storedChanged` holds it while the sitting is frozen; a save that fails rebases onto it. A page passes on only the sitting's own dive, and a sitting whose dive is no longer the page's is ended when its save fails.
- **After the write, a refresh that fails is not a failed save.** The dive list and the site list are each read again in a `try` of their own, and a failure is logged. A later plan that adds another refresh after `service.save` returns guards it the same way.
- **`replaceTextKeepingCaret`** (`text_keeping_caret.dart`), used by `FieldTextBinding` and the Notes editor. An editor that shows a value of the sitting in a text field uses it; assigning `text` throws the caret out of a field the diver is in.
- A disposed `EditSession` ignores `set` and `rebase`. The row of an open card in the folding layout does not save a fold. The closed header row is announced as a button.

Changed by the review of this plan's own pull request (#4550):

- **One question decides where a card is.** `diveCardIsOnPage(ref, id, layout:, working:)` in `dive_card_presence.dart` is asked by the section list, the pair and the Add strip: a card is on the page only when the held layout and the dive as it is now both have something for it. A card emptied and closed while another editor is open used to be in neither place. `diveCardIsShown` now reads the card's own `isEmpty`, adding satellite conditions for Environment, and `watchHasEnvironmentData` is gone. A new card needs its `isEmpty` and nothing else.
- **`RecordNumberRow`: the number that stands for a value is one the row put on show itself.** It was any number that read the same as the sitting's value, so 100.4 typed and then cut back to 100 stayed 100.4. A number the diver typed stands for itself.
- **`EditSession.firstTime(key)`.** True once in a sitting. The altitude lookup asks it, so reopening the card does not bring back an altitude the diver took out; fetching the weather still asks again.
- **`RevealAnswering`** (`reveal_answering.dart`), a mixin the card frame and the number row both use to answer `revealRequest`. A field type that scrolls itself in uses it too.
- A number row reads its text again on a rebuild only when its unit or decimals changed. The weather description is trimmed and compared trimmed, as surface conditions are. Whether the exit follows the entry is settled in `initState`. The fetch's confirmation asks its question once. A pair frames a stacked card only when it has one.

### Calls, as they turned out

- Call 7 changes nothing on screen: every language's altitude range text is the same as the English one. The shared banner uses `localizedRange` all the same.
- A fetch stores the forecast's weather code and clears an old one. The plan said to leave it as the dive form does; the read card describes the weather from that code, so an old one could contradict the rows beside it.
- Air temperature shows one decimal when it has one, as its read card does. At no decimals 21.4 could not be rounded to 21 by typing 21.

### Left open

- Decided 2026-11-14: words the diver types on fetched weather make the weather manual (`weatherDescriptionEdited`, told by `FieldTextBinding.onEdited`), so the read card shows them and no longer says Open-Meteo for that dive. The other fetched values stay. Clearing the words, or typing the stored ones back, restores the source: with no words stored the card describes the forecast whatever the source. Today's form still ignores a typed description.
- A cloud cover or precipitation the diver picks drops the forecast's weather code (`weatherSkyEdited`), which the read card would otherwise describe the sky from; setting both back restores it. The same rule as a fetch with no code: a code must not contradict the rows beside it. The source stays Open-Meteo.
- In an open card the form rows sit about 14 px in from the card's title.
- A held write cannot be withdrawn, and overwrites: the site gets the looked-up altitude even if the site gained one meanwhile. The altitude write checks, as it runs, that the dive still has the looked-up altitude, so one the diver typed over or cleared is not written. Plan 4 (picking a site) needs a way to release one.
- Resizing across the 700 px pair width while a paired card is open rebuilds its editor: values are kept, focus is not.
- The group banner shows the last readable altitude's group while the altitude text is unreadable.
- The read-only pressure row on the Environment card does not lead to the Altitude card. A changed card that has gone back to the strip carries no dot.
- `session.set(field, 10)` with a whole-number literal on a decimal field compiles and fails at run time. Tests spell `10.0`.

### Cleared later (PR #4670)

- A held site altitude is written only while the site still has none (`SiteRepository.fillSiteAltitudeIfEmpty`), so one it gained meanwhile is kept. Releasing a held write (`releaseWrite`) had already landed.
- The group banner shows no group while the altitude text cannot be read.
- The Environment card's read-only surface pressure row leads to the Altitude card.
- A changed card back on the Add strip carries its dot.
- Still open, each needing a decision: the form rows' inset from the card title, the editor rebuilt (focus lost) across the 700 px pair width, and `session.set(field, 10)` on a decimal field.
