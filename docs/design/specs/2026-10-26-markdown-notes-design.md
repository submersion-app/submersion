# Markdown formatting in notes

Issue: #3683. Mockup: [assets/2026-10-26-markdown-notes-mockup.html](assets/2026-10-26-markdown-notes-mockup.html).

## Intent

Divers write long notes: what they saw, how a dive went, what to fix before the
next trip. Today every notes field is a single block of plain text, so an
eventful dive reads as a wall of words and details get lost. This change lets a
diver give notes a little structure (headings, bold, italic, lists, links) using
Markdown, with a small formatting bar for people who don't know Markdown.

The issue proposed a Quill rich text editor storing Delta JSON in a new column.
The maintainer replaced that with Markdown: **the notes text itself is
Markdown**. While editing, the diver sees and types the Markdown marks; when
reading, the notes are drawn formatted. A Preview toggle in the editor shows the
formatted result without leaving the editor.

## Goals

- Every Markdown field (list below) is edited with one shared notes editor and
  drawn with one shared notes view, so all of them behave identically.
- The editor is a plain multi-line text field showing the raw Markdown, with a
  formatting bar of five buttons and a single Preview toggle.
- Read views draw the formatting. Links are tappable.
- Places that cannot show formatting get readable plain words, never stray
  `**` or `#` marks. Places that move data between systems keep the raw
  Markdown so formatting survives a round trip.
- Notes keep working everywhere they work today: search, sync, import, export.

## Non-goals

- Underline. Markdown has no standard mark for it; the maintainer chose to drop
  it rather than use `<u>` or `++`.
- A WYSIWYG editor. The marks stay visible while editing, by decision.
- Images, raw HTML, indented code blocks and underline-style (setext) headings.
  See "Supported Markdown".
- New database columns, migrations, sync changes, or a stored "is Markdown"
  flag. The existing text columns hold the Markdown.
- Converting or cleaning existing notes. They are drawn as Markdown as they are.
- Formatting in short fields (see "Plain fields").

## Anti-goals

- A note that loads anything from the network when displayed.
- Existing notes changing appearance in ways their author never typed: an
  indented line turning into a code box, a dashed separator turning the line
  above into a heading, single line breaks collapsing so lines run together.
- A busy editor. Five buttons and one toggle, no settings.

## Decisions made with the maintainer

1. **Storage:** each field's existing text column holds Markdown. No new column,
   no flag, no migration.
2. **Editing shows the marks; reading shows the formatting.**
3. **Toolbar:** H (heading), B (bold), I (italic), bulleted list, numbered list.
   No underline.
4. **Preview:** one toggle button (eye icon plus the word "Preview") at the
   right end of the formatting bar. Off by default; outlined when off, filled
   with the accent colour when on. When on, the text box is replaced by the
   formatted view at the same size and the formatting buttons are disabled.
   Tapping it again returns to typing with the cursor where it was. Saving works
   in either state.
5. **Existing and imported notes are drawn as Markdown** from the day this ships.
   The maintainer accepts that a note which already contains Markdown-looking
   marks (`- ` lines, `*word*`, `# ` lines) will now show them formatted.
6. **Links:** tappable. Bare web addresses become links automatically, and
   `[text](url)` works.
7. **Supported Markdown:** everything in CommonMark plus GitHub-flavoured
   extensions, except four constructs that stay as the literal text typed:
   indented code blocks, setext (underline-style) headings, images and raw HTML.
   An image written as `![alt](url)` is drawn as a tappable link labelled with
   its alt text (or the address when alt is empty); the image is never fetched.
8. **Scope:** every multi-line notes or description field that a diver writes
   and that is shown in full somewhere, across all features (not only dives).
   Single-line and short log-entry fields stay plain text.
9. **Outputs:** formatted in PDF exports; plain words in Excel, the table-view
   columns, truncated previews and the CSVs Submersion cannot re-import; raw
   Markdown in UDDF and other data-interchange outputs.
10. **Re-importable CSVs keep raw Markdown with real line breaks.** Submersion's
    own dives, sites and equipment CSVs are read back by the importer
    (`SubmersionCsvKind` in `submersion_csv_signatures.dart`, parsed by
    `submersion_csv_table.dart`), and the codec promises every typed value
    survives the round trip (#1814). Their Markdown fields are written raw, and
    the writers stop flattening line breaks to spaces (the cell is quoted, which
    is valid CSV and shows as a multi-line cell in spreadsheets). The importer
    restores the line breaks. This also fixes the line-break loss those
    round trips have today. Spreadsheet readers see the Markdown marks; Excel
    remains the clean, readable export.

## Supported Markdown

Drawn formatted:

| Construct | Syntax | Notes |
| --- | --- | --- |
| Headings, all six levels | `# ` to `###### ` | ATX form only |
| Bold, italic, bold italic | `**b**`, `*i*`, `_i_`, `***bi***` | |
| Strikethrough | `~~s~~` | |
| Inline code | `` `x` `` | monospace |
| Fenced code block | ```` ``` ```` | monospace block, no syntax highlighting |
| Block quote | `> ` | |
| Horizontal rule | `---`, `***`, `___` on their own line | with setext disabled, a `---` line under text draws as a rule below that text, not a heading |
| Bulleted list | `- `, `* `, `+ ` | nested by indentation |
| Numbered list | `1. ` | starts at the first number given |
| Task list | `- [ ] `, `- [x] ` | checkboxes drawn read-only |
| Table | GitHub pipe tables | |
| Link | `[text](url)`, `<url>`, bare `https://...` and `www....` | |
| Backslash escape | `\*` | shows a literal mark |

Kept as literal text: indented code blocks, setext headings, images (drawn as a
link instead, see above), raw HTML (tags show as typed).

**Line breaks:** every single line break in the source is drawn as a line break
(GitHub-comment behaviour), not joined into the paragraph as strict CommonMark
does. Without this, every existing multi-line note would collapse onto fewer
lines, which is the main way old notes could change appearance unintentionally.

**Links:** only `http`, `https` and `mailto` links are tappable; they open in the
system browser or mail app. Any other scheme draws as plain text. A link that
cannot be opened shows the app's usual "couldn't open" feedback.

## Markdown fields

The rule: the main notes or description of a record, edited in a multi-line
field and shown in full on a detail view. From the inventory of the codebase on
2026-10-26:

| Entity | Field(s) | Editor today | Full read view today |
| --- | --- | --- | --- |
| Dive | `notes` | `dive_log/.../edit_sections/experience_section.dart` (FormRow.text); bulk edit dialog in `dive_edit_page.dart` (Set/Append); rules "append notes" action in `rules/.../rule_action_editor.dart` | `dive_detail_page.dart` `_buildNotesSection` |
| Dive site | `description`, `notes`, `accessNotes` | `dive_sites/.../edit_sections/identity_section.dart`, `life_notes_section.dart`, `access_safety_section.dart` (SuggestionFormRow); rules "append site description" | `site_detail_page.dart` |
| Trip | `notes` | `trip_edit_page.dart` | `trip_prepare_overview.dart`, `trip_story_view.dart` |
| Trip itinerary day | `notes` | `itinerary_day_edit_sheet.dart` (bottom sheet) | `trip_story_day_plan.dart` |
| Buddy | `notes` | `buddy_edit_page.dart` | `buddy_detail_page.dart` |
| Equipment | `notes` | `equipment_edit_page.dart` | `equipment_detail_page.dart` |
| Equipment set | `description` | `equipment_set_edit_page.dart`; "save as set" dialog in `dive_edit_page.dart` | `equipment_set_detail_page.dart` |
| Equipment location | `notes` | `equipment_location_edit_dialog.dart` (dialog) | `equipment_location_detail_page.dart` |
| Dive center | `notes` | `dive_center_edit_page.dart` | `dive_center_detail_page.dart` `_NotesSection` |
| Certification | `notes` | `certification_edit_page.dart` | `certification_detail_page.dart` |
| Course | `notes` | `course_edit_page.dart` | `course_detail_page.dart` |
| Species | `description` | `species_edit_page.dart` | `species_detail_page.dart` (built-in species show localized plain text, which draws unchanged) |
| Document | `notes` | `document_edit_page.dart` | `document_details_panel.dart` |
| Site feature (site scape) | `notes` | `site_feature_sheet.dart` (sheet) | `site_feature_info_sheet.dart` |
| Diver | `notes`, `medicalNotes` | `settings/.../notes_edit_page.dart`, `medical_info_edit_page.dart` | notes: the edit page itself (Preview covers it); medical: `emergency_card_page.dart` |
| Shared site library | `description` | `library_about_section.dart` `_DetailsDialog` | `connect_shared_library_page.dart`, `library_about_section.dart` |

The builder re-checks this list against the code; a field that turns out to fit
the rule and is missing here is added, one that does not fit is left plain and
noted in the PR.

### Plain fields (unchanged)

Stay plain text editors and plain text views: dive weather description; sighting
notes; service record notes; rental gear notes; certification currency event
notes; equipment location move notes; checklist and pre-dive template
descriptions and item notes; tank preset description; cylinder fill, trip
cylinder and trip cylinder event notes; equipment observation notes; shared site
suggestion notes; backup notes; incident narrative, contributing factors and
lessons learned; emergency chamber notes; media captions; and every import-only
field with no editor.

## Where each Markdown field is shown, and how

| Surface | Treatment |
| --- | --- |
| Full read views (table above) | Shared notes view, formatted, text selectable, links tappable |
| Editor Preview | Same shared notes view |
| Truncated previews: list-tile subtitles, card extra fields (`entity_card_extra_fields.dart`), itinerary day card, diver hub subtitle, `FormRow` at-rest preview, equipment set list subtitle, library about subtitle | Plain words (marks removed), then truncated as today |
| Table-view columns (`entity_table_view.dart` via each `*_field.dart` extractor and `dive_field_extractor.dart`) | Plain words |
| PDF: `pdf_template_detailed.dart`, `pdf_template_padi.dart`, `pdf_template_naui.dart`, `export/pdf/pdf_export_service.dart`, `export/pdf/pdf_course_export_service.dart` | Formatted, using the PDF library's text styles, bullets and tables. Templates that cap notes at two lines keep the cap. |
| Re-importable CSVs: dives (`csv_dives_writer.dart`), sites (`csv_sites_writer.dart`), equipment (`csv_equipment_writer.dart`) | Raw Markdown with real line breaks (decision 10); the Submersion CSV importer must round-trip them, with tests |
| Other CSVs (trips in `csv_export_service.dart`, document manifest) and every Excel writer (dives, sites, equipment, maintenance) | Plain words; existing newline flattening stays |
| KML export (site description, access notes) | Plain words, escaped as today |
| UDDF export, shared-library site documents, plan files | Raw Markdown, unchanged |
| Search and saved queries | Unchanged: they match the stored text, so "turtle" still finds `**turtle**` |
| Sync conflict dialog, dive consolidation merge | Raw Markdown (the diver is comparing stored values) |

**Plain words** means: marks removed, structure kept readable. Bold, italic,
strikethrough and code marks drop; `# Heading` becomes `Heading`; bullets become
`- item`; numbered items stay `1. item`; task items become `[ ] item` /
`[x] item`; links become `text (url)`, or just the address when text and address
match; images become `alt (url)` like a link; quotes drop the `>`; table rows
become cells separated by ` | `; literal constructs (HTML, indented code) stay
as typed.

## The editor

One shared widget used by every Markdown field's editor, in pages, dialogs and
bottom sheets, and composed with `FormRow.text` and `SuggestionFormRow` where
those are used today (the site sections keep their merge caption and cycle
button).

- **Formatting bar** above the text box: H, B, I, bulleted list, numbered list,
  then the Preview toggle at the right end. Each has a localized tooltip and
  accessibility label.
- **B / I** wrap the selection in `**` / `*`. With no selection, they insert the
  pair with the cursor between. On a selection already wrapped, they unwrap.
- **H** toggles `# ` at the start of the current line (or each selected line).
- **Bulleted / numbered list** toggle `- ` / `1. `, `2. `... at the start of the
  current line or each selected line.
- **List continuation:** pressing Enter at the end of a list item starts the
  next item (`- ` or the next number). Enter on an empty item removes the marker
  and ends the list.
- **Keyboard shortcuts:** Cmd+B / Cmd+I on macOS and iOS hardware keyboards,
  Ctrl+B / Ctrl+I elsewhere.
- **Preview** as decided above.
- The text box keeps its current size per field (its existing `maxLines`), so
  layouts do not shift. Preview uses the same height and scrolls if longer.

## The notes view

One shared read-only widget. Styles come from the app theme so it is correct in
light and dark mode. Headings use the theme's title sizes, scaled down so a
level-1 heading never dwarfs the card title it sits under. An empty note keeps
each screen's current empty state.

## Builder's calls (made in this design, open to correction)

- **Library:** depend on Dart's `markdown` package directly and write the
  Flutter, PDF and plain-words renderers over its syntax tree, rather than use
  `flutter_markdown_plus` or `gpt_markdown`. Reasons: the parser can be built
  with exactly the allowed block and inline syntaxes
  (`withDefaultBlockSyntaxes: false`), one parse feeds all three outputs so they
  agree, and `flutter_markdown` itself is discontinued. `url_launcher` and `pdf`
  are already dependencies.
- **Where it lives:** shared, reusable pieces under `lib/shared/` (or
  `lib/core/` for the non-widget parts), never inside one feature.
- **Task-list checkboxes** are not tappable in the read view.
- **Heading button** inserts a level-1 heading.
- **Bulk edit "Append"** and the rules "append" action insert a blank line
  before the appended Markdown, so it starts a new paragraph instead of joining
  the last paragraph or list item.
- **Line-capped PDF templates** (PADI and NAUI at two lines, the course export
  at three) draw inline styling only (bold, italic, strikethrough, code, links)
  in one rich text with the existing cap; block structure is flattened to
  plain-words lines first. The uncapped templates draw full block formatting and
  must still break across pages (#2056).
- **Translations:** new strings (button tooltips, "Preview") go into all
  eleven ARB files with real translations, generated last.

## Left to the builder

- Exact component names, file layout and how the editor composes with
  `FormRow.text` and `SuggestionFormRow`.
- Spacing, sizes and icons, within the existing theme.
- How to keep the field list honest over time (for example a guard test that
  each Markdown field's read and edit surfaces use the shared widgets).
- Order of work and how the PR's commits are grouped.

## Testing expectations

TDD per the repo. At minimum: parser configuration (each supported construct,
each literal construct, line-break behaviour, link scheme filtering), plain
words for every construct, the notes view (rendering, link taps, dark mode),
the editor (each button with and without selection, toggling off, list
continuation, shortcuts, Preview on and off), PDF output for formatted notes,
and each export path's treatment. Screenshot before and after for the dive,
site and trip detail pages and the dive editor, light and dark, phone and
desktop widths.
