# Markdown Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every main notes or description field becomes Markdown: edited as raw Markdown with a five-button formatting bar and a Preview toggle, drawn formatted when read, and written as plain words, formatted PDF or raw Markdown depending on the output.

**Architecture:** One parser configuration over Dart's `markdown` package feeds three renderers (Flutter widgets, `pdf` widgets, plain words). One shared editor widget (`MarkdownNotesField`) and one shared view (`MarkdownNotesView`) replace the per-feature text fields and `Text` widgets; `FormRow.text` and `SuggestionFormRow` gain a `markdown` switch. No schema, sync or migration change: the existing text columns hold Markdown.

**Tech Stack:** Flutter, `markdown: ^7.3.1` (new direct dependency), `pdf` (existing), `url_launcher` via `openInBrowser` (existing), Riverpod-free widgets.

**Spec:** [docs/design/specs/2026-10-26-markdown-notes-design.md](../specs/2026-10-26-markdown-notes-design.md)

## Global Constraints

- Allowed Markdown: CommonMark plus GitHub extensions, EXCEPT indented code blocks, setext headings, images (drawn as a link labelled by alt text, or the address when alt is empty; never fetched) and raw HTML (shown as typed).
- Every single line break in the source draws as a line break.
- Tappable link schemes: `http`, `https`, `mailto` only. A failed open shows `context.l10n.common_link_couldNotOpen` in a SnackBar.
- Toolbar: H, B, I, bulleted list, numbered list, then one Preview toggle (eye icon plus "Preview") at the right end. No underline.
- Preview off by default; when on, the text box is replaced by the view at the same height, formatting buttons disabled; toggling off restores the cursor.
- B / I wrap with `**` / `*`; H toggles `# `; lists toggle `- ` / `1. `, `2. `...
- Shortcuts: Cmd+B / Cmd+I on macOS and iOS, Ctrl+B / Ctrl+I elsewhere.
- Plain words: marks removed; `# H` to `H`; bullets `- item`; numbered `1. item`; tasks `[ ] item` / `[x] item`; links `text (url)` or just the url when equal; images `alt (url)`; quotes drop `>`; table cells joined with ` | `.
- Appending to notes (bulk edit Append, rules append) adds a blank line (`\n\n`) before the text when the existing value is non-empty.
- Re-importable CSVs (dives, sites, equipment) write Markdown fields raw with real line breaks; trips CSV, document manifest and every Excel writer write plain words.
- UDDF, shared-library site documents, plan files, search, sync conflict dialog, dive consolidation merge: raw, unchanged.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, commits). No emojis.
- New user-facing strings get real translations in all 10 non-English ARB files; `flutter gen-l10n` runs after the translations are in.
- Paths built with `p.join`; tests that touch global state restore it.

## Review Focus

1. **An existing plain note with single line breaks** ("Saw turtle\nSaw shark") must still show two lines in the view, the PDF and the editor's at-rest preview. Pinned in Task 1 (parser) and Task 3 (view).
2. **A note containing a `javascript:` or `file:` link** must not be tappable. Pinned in Task 3.
3. **Toolbar taps inside a `FormRow.text` row** must not collapse the row (focus stays in the field), and Preview on must keep the row open. Pinned in Task 7.
4. **A very long formatted note in the detailed PDF** must break across pages instead of throwing "Widget won't fit into the page" (#2056). Pinned in Task 6.
5. **A note starting with `- `** goes through the CSV formula guard (`'-`) and must come back intact, with its line breaks, on re-import. Pinned in Task 14.

---

### Task 0: Before screenshots

Capture before any code change (build-feature step 4.1), using the `run` skill, into the scratchpad: `01-dive-detail-before.png`, `02-dive-edit-notes-before.png`, `03-site-detail-before.png`, `04-trip-overview-before.png`, each also `-dark`, and `-phone` for the detail pages. Use a dive whose notes contain a few lines.

---

### Task 1: Notes Markdown parser configuration

**Files:**
- Modify: `pubspec.yaml` (add `markdown: ^7.3.1` under dependencies, alphabetical neighbourhood)
- Create: `lib/core/text/markdown/notes_markdown.dart`
- Test: `test/core/text/markdown/notes_markdown_test.dart`

**Interfaces:**
- Produces:
  - `List<md.Node> parseNotesMarkdown(String source)` (import `package:markdown/markdown.dart' as md`)
  - `bool isTappableNotesLink(String? href)` (true only for parseable `http`, `https`, `mailto` URIs)
  - `String appendMarkdownParagraph(String existing, String text)` (`existing.isEmpty ? text : '$existing\n\n$text'`)

- [ ] **Step 1: Write failing tests** (helper `String tags(List<md.Node>)` that walks nodes and returns element tags in order, e.g. `'h1,p'`):

```dart
test('ATX headings of every level parse', () => expect(tags(parseNotesMarkdown('# A\n###### F')), 'h1,h6'));
test('setext headings stay a paragraph', () {
  final nodes = parseNotesMarkdown('Second dive\n=====');
  expect(nodes.single, isA<md.Element>().having((e) => e.tag, 'tag', 'p'));
});
test('dashes under text are a rule, not a heading', () => expect(tags(parseNotesMarkdown('Second dive\n-----')), 'p,hr'));
test('indented lines are not a code block', () => expect(tags(parseNotesMarkdown('a\n\n    indented')), 'p,p'));
test('fenced code is a code block', () => expect(tags(parseNotesMarkdown('```\nx\n```')), 'pre'));
test('raw HTML stays literal text', () {
  expect(parseNotesMarkdown('<b>hi</b>').single.textContent, '<b>hi</b>');
});
test('an image parses as img, nothing else is fetched here', () {
  final p = parseNotesMarkdown('![reef](https://x.test/a.png)').single as md.Element;
  expect((p.children!.single as md.Element).tag, 'img');
});
test('single line breaks survive inside a paragraph', () {
  expect(parseNotesMarkdown('Saw turtle\nSaw shark').single.textContent, 'Saw turtle\nSaw shark');
});
test('bare www and https addresses autolink', () { /* both produce an <a> with href */ });
test('task list, table, strikethrough, blockquote, both list kinds parse', () { /* tags */ });
test('isTappableNotesLink', () {
  expect(isTappableNotesLink('https://a.test'), isTrue);
  expect(isTappableNotesLink('http://a.test'), isTrue);
  expect(isTappableNotesLink('mailto:a@b.test'), isTrue);
  expect(isTappableNotesLink('javascript:alert(1)'), isFalse);
  expect(isTappableNotesLink('file:///etc/passwd'), isFalse);
  expect(isTappableNotesLink(null), isFalse);
});
test('appendMarkdownParagraph', () {
  expect(appendMarkdownParagraph('', 'x'), 'x');
  expect(appendMarkdownParagraph('- a', 'x'), '- a\n\nx');
});
```

- [ ] **Step 2:** `flutter pub get`, then `flutter test test/core/text/markdown/notes_markdown_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement.** Build one `md.Document` with `encodeHtml: false`, `withDefaultBlockSyntaxes: false`, `withDefaultInlineSyntaxes: false`, `extensionSet: md.ExtensionSet.none` and explicit lists. Blocks: `EmptyBlockSyntax`, `FencedCodeBlockSyntax`, `HeaderSyntax`, `BlockquoteSyntax`, `HorizontalRuleSyntax`, `TableSyntax`, `UnorderedListWithCheckboxSyntax`, `OrderedListWithCheckboxSyntax`, `LinkReferenceDefinitionSyntax`, `ParagraphSyntax`. Inlines: `EscapeSyntax`, `AutolinkExtensionSyntax`, `AutolinkSyntax`, `EmailAutolinkSyntax`, `LinkSyntax`, `ImageSyntax`, `CodeSyntax`, `EmphasisSyntax.asterisk()`, `EmphasisSyntax.underscore()`, `StrikethroughSyntax`, `LineBreakSyntax`. Check each class name against the 7.3.1 source and the inline parser's behaviour with defaults off; the tests are the contract. Normalise `\r\n` to `\n` before parsing.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): Markdown parser configuration for notes`.

---

### Task 2: Plain words

**Files:**
- Create: `lib/core/text/markdown/notes_plain_text.dart`
- Test: `test/core/text/markdown/notes_plain_text_test.dart`

**Interfaces:**
- Consumes: `parseNotesMarkdown`.
- Produces: `String markdownToPlainText(String source)` (empty in, empty out; blocks separated by one `\n`; trailing whitespace trimmed).

- [ ] **Step 1: Write failing tests**, one per Global Constraints plain-words rule, with exact outputs:

```dart
expect(markdownToPlainText('Viz was **great**, *maybe* ~~20~~ `25` m'), 'Viz was great, maybe 20 25 m');
expect(markdownToPlainText('# Descent\nViz good'), 'Descent\nViz good');
expect(markdownToPlainText('- a\n- b'), '- a\n- b');
expect(markdownToPlainText('3. a\n4. b'), '3. a\n4. b');
expect(markdownToPlainText('- [ ] fins\n- [x] mask'), '[ ] fins\n[x] mask');
expect(markdownToPlainText('[shop](https://s.test)'), 'shop (https://s.test)');
expect(markdownToPlainText('https://s.test'), 'https://s.test');
expect(markdownToPlainText('![reef](https://x.test/a.png)'), 'reef (https://x.test/a.png)');
expect(markdownToPlainText('> quoted'), 'quoted');
expect(markdownToPlainText('| a | b |\n|---|---|\n| 1 | 2 |'), 'a | b\n1 | 2');
expect(markdownToPlainText('<u>x</u>'), '<u>x</u>');
expect(markdownToPlainText('Saw turtle\nSaw shark'), 'Saw turtle\nSaw shark');
expect(markdownToPlainText(r'5 \* 3'), '5 * 3');
expect(markdownToPlainText(''), '');
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement as a recursive walk over the AST (a `md.NodeVisitor` or a switch on tag); numbered items take the list's `start` attribute.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): plain-words rendering of Markdown notes`.

---

### Task 3: MarkdownNotesView

**Files:**
- Create: `lib/shared/widgets/markdown_notes/markdown_notes_view.dart`
- Test: `test/shared/widgets/markdown_notes/markdown_notes_view_test.dart`

**Interfaces:**
- Consumes: `parseNotesMarkdown`, `isTappableNotesLink`, `openInBrowser` and `UrlLaunch` from `lib/shared/utils/browser_launch.dart`.
- Produces: `class MarkdownNotesView extends StatelessWidget { const MarkdownNotesView(this.source, {super.key, this.style, this.launch}); final String source; final TextStyle? style; final UrlLaunch? launch; }`. `style` defaults to `textTheme.bodyMedium`. Renders a `Column(crossAxisAlignment: start)` of blocks; text runs are `SelectableText.rich`.

Styling (from `Theme.of(context)`): h1 `titleMedium` w600, h2 `titleSmall` w600, h3 to h6 `style` w600; inline code and code blocks in `monospace` on `colorScheme.surfaceContainerHighest`; blockquote with a 3 px `colorScheme.outlineVariant` left bar and `onSurfaceVariant` text; links `colorScheme.primary` underlined; task checkboxes as `Icons.check_box_outlined` / `Icons.check_box_outline_blank` (not tappable); tables as `Table` with `TableBorder.all(color: outlineVariant)`; `hr` as `Divider`. Block spacing 6 px.

- [ ] **Step 1: Write failing widget tests** (pump under `testApp`):
  - `'draws bold and italic as styled spans'`: find the `TextSpan` for "great" and assert `fontWeight == FontWeight.bold`; "maybe" has `fontStyle == FontStyle.italic`.
  - `'keeps single line breaks'`: `'Saw turtle\nSaw shark'` renders text containing `'Saw turtle\nSaw shark'`.
  - `'draws bullet and numbered lists with markers'`: finds `'•'` and `'1.'`.
  - `'tapping an https link launches it'`: inject `launch` recording the Uri; tap "shop"; expect `Uri.parse('https://s.test')`.
  - `'a javascript link is plain text'`: `[x](javascript:alert(1))`, tapping "x" records nothing.
  - `'an image draws as a link, labelled by alt'`: text "reef" present, no `Image` widget in the tree.
  - `'a failed launch shows the could-not-open snackbar'`: `launch` returns false; expect `'Could not open the link'`.
  - `'renders in dark theme'`: pump with `ThemeData.dark()`; link colour equals dark `colorScheme.primary`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Link taps via `TapGestureRecognizer` (dispose them: make the view a `StatefulWidget` holding recognizers, rebuilt when `source` changes).
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): shared Markdown notes view`.

---

### Task 4: Editing operations (pure)

**Files:**
- Create: `lib/shared/widgets/markdown_notes/markdown_editing.dart`
- Test: `test/shared/widgets/markdown_notes/markdown_editing_test.dart`

**Interfaces:**
- Produces:
  - `TextEditingValue toggleInlineMark(TextEditingValue value, String mark)` (`'**'` or `'*'`)
  - `enum NotesLinePrefix { heading, bullet, numbered }`
  - `TextEditingValue toggleLinePrefix(TextEditingValue value, NotesLinePrefix prefix)`
  - `class NotesListContinuationFormatter extends TextInputFormatter`

- [ ] **Step 1: Write failing tests** (use `TextEditingValue(text:, selection:)`; `|` marks the caret in comments):
  - wrap selection: `'a big turtle'` selecting "big" + `'**'` gives `'a **big** turtle'`, selection still on "big".
  - unwrap: `'a **big** turtle'` selecting "big" + `'**'` gives `'a big turtle'`.
  - empty selection: `'ab|'` + `'*'` gives `'ab*|*'`.
  - heading on: `'Descent|'` gives `'# Descent|'`; off: `'# Descent'` gives `'Descent'`.
  - bullets over a two-line selection: `'a\nb'` gives `'- a\n- b'`; again gives `'a\nb'`.
  - numbered over three lines: `'a\nb\nc'` gives `'1. a\n2. b\n3. c'`.
  - bullet replaces numbering: `'1. a'` + bullet gives `'- a'`.
  - continuation: old `'- a|'`, new `'- a\n|'` gives `'- a\n- |'`; `'2. b|'` + Enter gives `'2. b\n3. |'`; `'- [ ] a|'` + Enter gives `'- [ ] a\n- [ ] |'`.
  - ending a list: old `'- a\n- |'`, Enter gives `'- a\n|'` (empty marker removed, no new line added).
  - plain line + Enter is untouched.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. The formatter acts only when exactly one `\n` was inserted at a collapsed caret.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): Markdown editing operations for the notes editor`.

---

### Task 5: MarkdownNotesField

**Files:**
- Create: `lib/shared/widgets/markdown_notes/markdown_notes_field.dart`, `lib/shared/widgets/markdown_notes/markdown_notes_toolbar.dart`
- Modify: `lib/l10n/arb/app_en.arb` (new group `notesEditor_*`, placed near the `common_link_*` group)
- Test: `test/shared/widgets/markdown_notes/markdown_notes_field_test.dart`

**Interfaces:**
- Consumes: Task 3 view, Task 4 operations.
- Produces:

```dart
class MarkdownNotesField extends StatefulWidget {
  const MarkdownNotesField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines = 5,
    this.minLines,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
    this.onPreviewChanged,
  });
  // controller, FocusNode?, InputDecoration?, int maxLines, int? minLines,
  // bool autofocus, FormFieldValidator<String>? validator,
  // ValueChanged<String>? onChanged, TextCapitalization,
  // ValueChanged<bool>? onPreviewChanged
}
```

The field is a `TextFormField` (so `Form.validate` works) with `inputFormatters: [NotesListContinuationFormatter()]`, wrapped in `CallbackShortcuts` for the bold/italic activators (`meta:` on macOS/iOS via `defaultTargetPlatform`, `control:` elsewhere). The toolbar sits above, inside `TextFieldTapRegion` and `ExcludeFocus`, so tapping a button never moves focus out of the field. Preview on: swaps the `TextFormField` for `MarkdownNotesView` inside a box of the field's measured height (`SizeReporter` or a `LayoutBuilder` measurement), scrollable; keeps the `TextFormField` mounted offstage (`Offstage` + `TickerMode(enabled: false)`) so validators still see it; toggling off calls `requestFocus` on the field's node and restores the previous selection.

ARB keys (English values): `notesEditor_action_heading` "Heading", `notesEditor_action_bold` "Bold", `notesEditor_action_italic` "Italic", `notesEditor_action_bulletList` "Bulleted list", `notesEditor_action_numberedList` "Numbered list", `notesEditor_action_preview` "Preview". Each with an `@` description. Run `flutter gen-l10n` (English only for now; Task 15 adds translations and regenerates).

Toolbar icons: `Icons.title`, `Icons.format_bold`, `Icons.format_italic`, `Icons.format_list_bulleted`, `Icons.format_list_numbered`; Preview is a compact `FilterChip`-style toggle with `Icons.visibility_outlined`, outlined off, filled `colorScheme.primary` on.

- [ ] **Step 1: Write failing widget tests:**
  - `'shows the five formatting buttons and Preview'` (find by tooltip text).
  - `'Bold wraps the selection'`: set selection on "big", tap Bold, expect `controller.text == 'a **big** turtle'`.
  - `'tapping a button keeps focus in the field'`: focus field, tap Italic, `expect(focusNode.hasFocus, isTrue)`.
  - `'Cmd+B or Ctrl+B bolds'`: run under `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` (restore in `addTearDown`) sending meta+B; and under linux sending control+B.
  - `'Enter continues a list'`: `tester.enterText(field, '- a')`, then `tester.enterText(field, '- a\n')` (the formatter sees the inserted newline), expect `controller.text == '- a\n- '`.
  - `'Preview shows formatting and disables the buttons'`: tap Preview; expect a `MarkdownNotesView`, no visible `EditableText`, Bold button `onPressed == null`; `onPreviewChanged` called with true.
  - `'Preview off restores the field and selection'`.
  - `'validator still runs while previewing'`: wrap in `Form`, preview on, `formKey.currentState!.validate()` returns false for a failing validator.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): shared Markdown notes editor with formatting bar and preview`.

---

### Task 6: PDF rendering

**Files:**
- Create: `lib/core/services/pdf_templates/pdf_notes_markdown.dart`
- Test: `test/core/services/pdf_templates/pdf_notes_markdown_test.dart`

**Interfaces:**
- Consumes: `parseNotesMarkdown`, `markdownToPlainText`.
- Produces:
  - `List<pw.Widget> notesMarkdownPdfBlocks(String source, {required pw.TextStyle style})`: one widget per block (so `MultiPage` can break between them); paragraphs as `pw.RichText(overflow: pw.TextOverflow.span)`; headings at `style.fontSize` + 4 / + 2 / + 0 bold; lists with `pw.Bullet`-style rows; tables as `pw.Table`; code in `pw.Font.courier()`; links coloured `PdfColors.blue800` with `pw.UrlLink` for tappable schemes.
  - `pw.Widget notesMarkdownPdfInline(String source, {required pw.TextStyle style, required int maxLines})`: blocks flattened through `markdownToPlainText`'s block layout but keeping inline bold, italic, strikethrough, code and links as spans in one `pw.RichText(maxLines: maxLines)`.

- [ ] **Step 1: Write failing tests** (build a `pw.Document` with `PdfFonts.instance.theme`, save to bytes; follow `pdf_detailed_long_text_test.dart` for the pagination harness):
  - `'a long formatted note spans pages'`: 200 bullet lines inside a `pw.MultiPage`, `doc.save()` completes and page count > 1.
  - `'block output has one widget per block'`: `'# H\n\npara\n\n- a\n- b'` gives 3 widgets.
  - `'inline output keeps the cap'`: returns a `pw.RichText` whose `maxLines == 2`.
  - `'a note with every construct renders without throwing'`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): render Markdown notes in PDF exports`.

---

### Task 7: FormRow.text and SuggestionFormRow switch

**Files:**
- Modify: `lib/shared/widgets/forms/form_row.dart` (add `this.markdown = false` to `FormRow.text`; every other constructor sets `markdown = false`)
- Modify: `lib/shared/widgets/forms/suggestion_form_row.dart` (add `this.markdown = false`; assert `!markdown || suggestions.isEmpty`)
- Test: `test/shared/widgets/forms/form_row_markdown_test.dart`, `test/shared/widgets/forms/suggestion_form_row_markdown_test.dart`

**Interfaces:**
- Consumes: `MarkdownNotesField`, `markdownToPlainText`.
- Produces: `FormRow.text(..., markdown: true)` and `SuggestionFormRow(..., markdown: true)`.

Behaviour: in `FormRow`, the editing branch renders `MarkdownNotesField(controller, focusNode: _alwaysMounted ? null : _focusNode, autofocus:, maxLines:, validator:, decoration: widget.decoration ?? _bareDecoration(context), onPreviewChanged:)` instead of `TextFormField`, laid out full width under the label (label row on top, field below) because the toolbar needs the width. While `_previewing` is true, focus loss does not end editing; a `TapRegion(onTapOutside:)` around the row ends editing and preview. The resting row shows `markdownToPlainText(text)`. `SuggestionFormRow` with `markdown: true` renders the same field (always mounted) in place of `RawAutocomplete`, keeping `caption` and `trailing`.

- [ ] **Step 1: Write failing tests:**
  - `'resting markdown row shows plain words'`: controller `'# Descent\n**great**'`, finds `'Descent\ngreat'` (or `findsOneWidget` on text containing "Descent" and no `'**'`).
  - `'tapping a markdown row opens the notes editor'`: tap row, expect `MarkdownNotesField`.
  - `'formatting taps keep the row open'`: tap Bold, row still shows `MarkdownNotesField`.
  - `'preview keeps the row open; tapping outside rests it'`.
  - `'non-markdown rows are unchanged'`: existing `FormRow.text` still builds a `TextFormField` and no toolbar.
  - `'markdown SuggestionFormRow keeps the merge caption and cycle button'`.
- [ ] **Step 2:** Run new tests plus `test/shared/widgets/forms/`. Expected: new FAIL, existing PASS.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `flutter test test/shared/widgets/forms/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): Markdown mode for FormRow and SuggestionFormRow`.

---

### Task 8: Appending adds a blank line

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`bulkAppendNotes`: SQL becomes `CASE WHEN COALESCE(notes, '') = '' THEN ? ELSE notes || char(10) || char(10) || ? END`; signature unchanged so no mock regeneration)
- Modify: `lib/features/rules/data/services/dive_rule_applier.dart` (both chunks pass `text`; `RuleChange` after-values use `appendMarkdownParagraph`)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (`appendDescription` uses `char(10) || char(10)`)
- Modify: `lib/features/rules/data/services/site_rule_applier.dart` (after-value via `appendMarkdownParagraph`)
- Test: the existing tests for these four files (find with `grep -rl "bulkAppendNotes\|appendDescription" test --include='*_test.dart'`), updated to expect `\n\n`

- [ ] **Step 1:** Change the existing expectations to the blank-line form and add `'appending to empty notes adds no separator'` for both repos.
- [ ] **Step 2:** Run those tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): append notes as a new Markdown paragraph`.

---

### Tasks 9 to 13: Adopt the shared pieces per feature

Each adoption task follows the same steps; the table names the files.

- [ ] **Step 1:** In the feature's existing widget tests (or a new `<page>_markdown_notes_test.dart` beside them), add: the detail view renders a `MarkdownNotesView` for a record with notes `'# Plan\n**Bring torch**'` (finds "Plan" and no `'**'`); the editor shows the formatting bar (find by the Bold tooltip); each truncated preview shows plain words (no `'**'`); each table extractor returns plain words.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Editors: replace the notes `TextFormField`/`TextField` with `MarkdownNotesField`, keeping its `InputDecoration` (label, hint, icon) and `maxLines`; `FormRow.text`/`SuggestionFormRow` rows get `markdown: true`. Full read views: replace `Text(x.notes)` / `SelectableText` with `MarkdownNotesView(x.notes)`, keeping each screen's empty state. Truncated previews and extractors: wrap the value in `markdownToPlainText(...)`.
- [ ] **Step 4:** Run the feature's tests and `flutter analyze`. Expected: PASS, no issues.
- [ ] **Step 5:** Commit `feat(<scope>): Markdown notes in <feature>`.

| Task | Scope | Editors | Full read views | Plain-words previews and extractors |
| --- | --- | --- | --- | --- |
| 9 | `dive-log`, `rules` | `dive_log/presentation/widgets/edit_sections/experience_section.dart` (FormRow.text `markdown: true`); bulk notes field in `dive_edit_page.dart` (the `TextField(controller: _notesController, maxLines: 4)`); rules append text field in `rules/presentation/widgets/rule_action_editor.dart` | `dive_detail_page.dart` `_buildNotesSection` | `core/constants/dive_field_extractor.dart` `DiveField.notes` |
| 10 | `dive-sites` | `identity_section.dart` (description), `life_notes_section.dart` (notes), `access_safety_section.dart` (access notes): `_row` gains `markdown` and these pass `true` with no suggestions | `site_detail_page.dart` description, notes and `_buildAccessRow` access notes | `dive_sites/domain/constants/site_field.dart` notes (feeds table and card extra fields) |
| 11 | `trips`, `buddies`, `dive-centers` | `trip_edit_page.dart`, `itinerary_day_edit_sheet.dart`, `buddy_edit_page.dart`, `dive_center_edit_page.dart` | `trip_prepare_overview.dart`, `trip_story_view.dart`, `trip_story_day_plan.dart`, `buddy_detail_page.dart`, `dive_center_detail_page.dart` `_NotesSection` | `trip_field.dart`, `buddy_field.dart`, `dive_center_field.dart`, `itinerary_day_card.dart` |
| 12 | `certifications`, `courses`, `marine-life`, `documents` | `certification_edit_page.dart`, `course_edit_page.dart`, `species_edit_page.dart`, `document_edit_page.dart` | `certification_detail_page.dart`, `course_detail_page.dart`, `species_detail_page.dart` (user species only; built-in localized text drawn through the view is harmless), `document_details_panel.dart` | `certification_field.dart`, `course_field.dart` |
| 13 | `equipment`, `site-scape`, `settings`, `shared-library` | `equipment_edit_page.dart`, `equipment_set_edit_page.dart`, the "save as set" description in `dive_edit_page.dart`, `equipment_location_edit_dialog.dart`, `site_feature_sheet.dart`, `settings/presentation/pages/notes_edit_page.dart`, `medical_info_edit_page.dart`, `library_about_section.dart` `_DetailsDialog` | `equipment_detail_page.dart`, `equipment_set_detail_page.dart`, `equipment_location_detail_page.dart`, `site_feature_info_sheet.dart`, `emergency_card_page.dart` (medical notes), `connect_shared_library_page.dart` | `equipment_field.dart`, `equipment_set_list_content.dart`, `equipment_location_list_page.dart`, `equipment_location_picker_sheet.dart`, `diver_profile_hub_page.dart` subtitle, `library_about_section.dart` subtitle |

Before each task, re-check the files against the spec's field rule (`rg -n "notes|description" <feature>/presentation`); add a missed surface, and list any field left plain in the PR description.

---

### Task 14: Exports

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart` (`_notesSection` uses `notesMarkdownPdfBlocks`), `pdf_template_padi.dart` and `pdf_template_naui.dart` (`notesMarkdownPdfInline(maxLines: 2)`), `lib/core/services/export/pdf/pdf_export_service.dart` (blocks), `lib/core/services/export/pdf/pdf_course_export_service.dart` (inline, `maxLines: 3` where capped; blocks for course notes at `:211-231`)
- Modify: `lib/core/services/export/csv/csv_dives_writer.dart:139`, `csv_sites_writer.dart:90-91,99` (description, notes, access notes), `csv_equipment_writer.dart:107`: drop `.replaceAll('\n', ' ')` for Markdown fields
- Modify: `lib/core/services/export/csv/csv_export_service.dart:180` (trips: `markdownToPlainText` then flatten), `lib/features/documents/domain/document_manifest.dart:52`, `lib/core/services/export/excel/excel_export_service.dart:317,397,399,400,472`, `lib/core/services/export/kml/kml_export_service.dart:222-224,254-255`: `markdownToPlainText` before existing flattening and escaping. Service record notes stay plain, so `maintenance_excel_export_service.dart` is untouched.
- Modify: `test/core/services/export/csv/goldens/dives_metric.csv`, `sites_metric.csv`, `equipment_metric.csv` (regenerate; the only diff is the notes cells, now quoted with real line breaks)
- Test: `test/core/services/export/csv/csv_dives_writer_test.dart`, `csv_sites_equipment_writer_test.dart`, `test/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser_test.dart`, `submersion_sites_csv_parser_test.dart`, the equipment parser test, `test/core/services/pdf_templates/pdf_detailed_long_text_test.dart`, Excel and KML export tests

- [ ] **Step 1: Write failing tests:**
  - round trip, dives: notes `'- bring torch\n- check **o-ring**'` survives `CsvDivesWriter(...).write` then `SubmersionDivesCsvParser().parse` exactly (covers the `'-` formula guard). Same for sites (description, notes, access notes) and equipment notes.
  - existing parser tests: `'Great viz saw turtles'` becomes `'Great viz\nsaw turtles'`.
  - trips CSV, Excel and KML: `'# Plan\n**torch**'` exports as `'Plan torch'` (plain words, newline flattened as before).
  - detailed PDF: a 300-line Markdown note still exports (extend `pdf_detailed_long_text_test.dart`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement; regenerate the three golden CSVs from the writer output and check `git diff` shows only notes cells changed.
- [ ] **Step 4:** Run `flutter test test/core/services/export test/core/services/pdf_templates test/features/universal_import/data/parsers/submersion_csv`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(export): Markdown notes in PDF, CSV, Excel and KML exports`.

---

### Task 15: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (the six `notesEditor_*` keys, inserted in the same group position as in `app_en.arb`), generated `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1:** Add real translations for all six keys to every ARB file.
- [ ] **Step 2:** `flutter gen-l10n`, then confirm `grep -c "notesEditor_action_preview" lib/l10n/arb/app_localizations_de.dart` is 1 and its value is not "Preview".
- [ ] **Step 3:** Run the generated-l10n staleness check the pre-push hook uses (`hooks/pre-push` names it) and the l10n tests under `test/l10n/`. Expected: PASS.
- [ ] **Step 4: Commit** `i18n(notes): translate the notes editor`.

---

### Task 16: Adoption guard

**Files:**
- Create: `test/architecture/markdown_notes_adoption_test.dart` (model: `map_style_switcher_adoption_test.dart`)

**Interfaces:**
- Consumes: the file lists in Tasks 9 to 13.

- [ ] **Step 1:** Write the test: a const map of each editor file to the token it must contain (`MarkdownNotesField` or `markdown: true`), and each full read view file to `MarkdownNotesView`; plus a scan of `lib/features/**/presentation/**` failing on `Text(<x>.notes` or `SelectableText(<x>.notes` for the entity types in the spec table, with a short allowlist for the plain fields.
- [ ] **Step 2:** Run it. Expected: PASS (adoption is done). Then temporarily revert one adoption (copy the file aside first, never `git checkout` it) and confirm it FAILS naming that file; restore the copy.
- [ ] **Step 3:** Run all of `test/architecture/` and `test/shared/`. Expected: PASS.
- [ ] **Step 4: Commit** `test(notes): guard that notes fields use the shared Markdown widgets`.

---

### Task 17: Verify and after screenshots

- [ ] `dart format .`, `flutter analyze` (no issues), then the affected test folders: `test/core/text`, `test/shared`, `test/core/services/export`, `test/core/services/pdf_templates`, `test/features/{dive_log,dive_sites,trips,buddies,dive_centers,certifications,courses,marine_life,documents,equipment,site_scape,settings,shared_library,rules,universal_import}`, `test/architecture`. Grep `test/` for every widget whose build gained `context.l10n` through the new field (consumers of the changed editors) and run those files too.
- [ ] After screenshots for the Task 0 screens, plus `05-notes-preview-after.png` (editor with Preview on) and `06-pdf-notes-after.png`, light and dark, phone and desktop widths.
