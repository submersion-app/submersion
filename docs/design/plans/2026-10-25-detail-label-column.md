# Detail Label Column Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every label/value row on item detail pages shows its value right
beside its label, with the values in one card lined up on a shared label
column, at every window width.

**Architecture:** A shared `DetailRow` widget renders `[label cell] 16 px
[value]` through a two-slot render object (`RenderDetailRow`). Each card wraps
its rows in a `DetailRowGroup`, which owns a `DetailLabelColumn` (a
`ChangeNotifier` holding the widest label cell). Rows measure their own label
cell with a `TextPainter` during build and report it from their render object;
the render object reads the group's width at layout time and relayouts when it
changes. Measurement happens in build and use happens in layout, so every row
of a card is measured before any is laid out and the first frame is already
aligned. Existing row helpers become thin wrappers or call sites switch to
`DetailRow`.

**Tech Stack:** Flutter 3.47 (`SlottedMultiChildRenderObjectWidget`,
`SlottedContainerRenderObjectMixin`), flutter_test.

**Spec:** `docs/design/specs/2026-10-25-detail-label-column-design.md`
(issue #3678)

## Global Constraints

- Gap between label column and value: 16 logical px.
- Label column width = widest label cell in the group at natural width,
  capped at 40% of the row width (hard cap, labels only). A label over the cap
  wraps; labels have no line limit.
- The label cell holds the optional leading icon, its gap, then the label.
- Value starts at the value column, `TextAlign.start`, wraps inside the value
  column. Use start/end, never left/right (RTL mirrors).
- Rows keep their existing styles, colours, icons, chevrons, badges, value
  line limits, tap targets and semantics. Only positions change.
- Rows outside any group use their own label cell width under the same cap.
- No em-dashes anywhere (code, comments, commits). Match surrounding comment
  density. `dart format .` before each commit.
- Commit messages: `feat(<scope>): ...`, no attribution trailers.

## Review Focus

1. A long localized label at a large text size on a phone (300 px card,
   `textScaler` 2.0): no overflow, the label wraps inside 40%, the value
   keeps 60% minus 16. Pinned in Task 1.
2. A row that appears after the first frame with the card's widest label
   (provider-backed rows): every other row's value moves in the same frame
   the new row first lays out, with no extra pump. Pinned in Task 1.
3. A row removed or whose label text changes (locale switch, status change):
   the column shrinks or grows without a stale width. Pinned in Task 1.
4. Tappable rows (InkWell around the whole row, links inside the value):
   taps still land, and the row's existing `Semantics(button:, label:)` is
   unchanged. Pinned in Task 1 (hit test) and in each page task (tap opens).
5. RTL: label at the right edge, value immediately to its left. Pinned in
   Task 1.

---

### Task 1: Shared `DetailRow`, `DetailRowGroup` and `RenderDetailRow`

**Files:**
- Create: `lib/shared/widgets/detail_row/detail_row.dart`
- Create: `lib/shared/widgets/detail_row/detail_row_group.dart`
- Create: `lib/shared/widgets/detail_row/render_detail_row.dart`
- Test: `test/shared/widgets/detail_row/detail_row_test.dart`

**Interfaces:**
- Produces:
  - `class DetailLabelColumn extends ChangeNotifier` with
    `double get width` (max reported, 0 when empty),
    `void report(Object owner, double width)`,
    `void remove(Object owner)`. Notifies only when `width` changes.
  - `class DetailRowGroup extends StatefulWidget { const DetailRowGroup({super.key, required Widget child}); static DetailLabelColumn? maybeOf(BuildContext context); }`
    The state owns and disposes one `DetailLabelColumn`, exposed through a
    private `InheritedWidget`. Nested groups: nearest wins.
  - `class DetailRow extends StatelessWidget` with
    `const DetailRow({super.key, required String label, required Widget value, TextStyle? labelStyle, IconData? icon, double iconSize = 20, double iconGap = 12, Color? iconColor, EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 8)})`
    and `DetailRow.text({Key? key, required String label, required String value, TextStyle? valueStyle, int? maxLines, TextOverflow? overflow, ...same optional label/icon/padding params})`
    which builds `value` as `Text(value, style: valueStyle, maxLines:, overflow:)`.
    Statics: `static const double gap = 16; static const double maxLabelShare = 0.4;`
    Default `labelStyle`: `bodyMedium` with `colorScheme.onSurfaceVariant`.
    Default `iconColor`: `colorScheme.primary`.
  - `RenderDetailRow` (library-private to `detail_row/` is fine) with slots
    `label`, `value` and properties `DetailLabelColumn? column`,
    `double ownLabelWidth`, `TextDirection textDirection`.

- [ ] **Step 1: Write the failing tests** in
  `test/shared/widgets/detail_row/detail_row_test.dart`. Use the default test
  font (Ahem: every glyph is `fontSize` square, so a 14 px label of n
  characters is 14n wide). Pump inside `MaterialApp` +
  `Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: W, child: ...)))`.
  Tests and assertions:
  - `value starts 16 px after its label when ungrouped`: W = 1000, label
    'Brand' (5 chars, 70 px); `getTopLeft(find.text('Apeks')).dx == 70 + 16`.
  - `values in one group share a column`: W = 1000, rows 'Status'/'Active'
    and 'Serial number'/'AX1' in a `DetailRowGroup`; both values'
    `dx == 13 * 14 + 16`.
  - `label column is capped at 40% and the label wraps`: W = 300, label of
    12 chars (168 px), value 'x'; value `dx == 120 + 16`; label text height
    `> 14` (wrapped onto two lines); `tester.takeException()` is null.
  - `an icon row and a plain row align`: group with
    `DetailRow.text(label: 'State', icon: Icons.waves, value: 'Rising')` and
    `DetailRow.text(label: 'Height', value: '1.2 m')`; both values share
    `dx == 20 + 12 + 5 * 14 + 16` ('State' and 'Height' are 5 and 6 chars,
    so the icon row is widest at 102).
  - `empty label continuation row aligns under the value above`: group with
    'Training courses'/'Open Water' and ''/'Nitrox'; both values share dx.
  - `long value wraps inside the value column`: W = 400, label 'Notes',
    value of 60 chars; value `dx == 70 + 16`, value width `<= 400 - 86`,
    value height `> 14`.
  - `a row added later widens the column in the same frame`: a
    `StatefulBuilder` toggles in a third row 'Surface interval'; after
    `setState` and ONE `tester.pump()`, the first row's value
    `dx == 16 * 14 + 16`.
  - `removing the widest row and changing a label shrink and grow the column`:
    remove the widest row, one pump, values move left to the next widest;
    then change a label to a longer one, one pump, values move right.
  - `RTL mirrors the layout`: `Directionality(textDirection: rtl)`, W = 1000,
    'Brand'/'Apeks'; label's `getTopRight.dx == 1000`; value's
    `getTopRight.dx == 1000 - 70 - 16`.
  - `text scale widens the column`: `MediaQuery(textScaler: TextScaler.linear(2))`,
    'Brand'/'Apeks' ungrouped; value `dx == 140 + 16`.
  - `narrow width with large text does not overflow`: W = 200, text scale 2,
    label 'Oberflaechenintervall', value 'Long value text here'; no exception.
  - `taps inside the value land`: value is `InkWell(onTap: () => tapped = true, child: Text('link'))`;
    `tester.tap(find.text('link'))`; `tapped` is true.
  - `values top-align with the first label line`: in a wrapped-label row the
    value's `dy` equals the label's `dy`.

- [ ] **Step 2: Run the tests to verify they fail**

  Run: `flutter test test/shared/widgets/detail_row/detail_row_test.dart`
  Expected: compile failure (`DetailRow` not defined).

- [ ] **Step 3: Implement `DetailLabelColumn` and `DetailRowGroup`** in
  `detail_row_group.dart`.

- [ ] **Step 4: Implement `RenderDetailRow`** in `render_detail_row.dart` with
  `SlottedMultiChildRenderObjectWidget` / `SlottedContainerRenderObjectMixin`.
  - `attach`: `column?.addListener(markNeedsLayout)` and
    `column?.report(this, ownLabelWidth)`. `detach`: remove the listener and
    `column?.remove(this)`. Setters for `column` and `ownLabelWidth` move the
    listener / re-report and `markNeedsLayout`.
  - Layout (also used for `computeDryLayout` with `getDryLayout`):

    ```
    width   = constraints.maxWidth   // if infinite: natural + gap + value max intrinsic
    natural = max(ownLabelWidth, column?.width ?? 0)
    col     = min(natural, width * DetailRow.maxLabelShare)
    label.layout(BoxConstraints(maxWidth: col), parentUsesSize: true)
    value.layout(BoxConstraints(maxWidth: max(0, width - col - gap)), parentUsesSize: true)
    size    = constraints.constrain(Size(width, max(label.h, value.h)))
    LTR: label at (0, 0), value at (col + gap, 0)
    RTL: label at (width - label.w, 0), value at (width - col - gap - value.w, 0)
    ```
  - Paint children, default hit testing (value first, then label),
    `computeDistanceToActualBaseline` from the label. Intrinsics: min width
    = label min + gap + value min; max width = natural + gap + value max;
    heights at a given width from the same column split.

- [ ] **Step 5: Implement `DetailRow`** in `detail_row.dart`.
  - Build-time measurement, same as `IconDetailRow` today: resolve
    `DefaultTextStyle.of(context).style.merge(labelStyle)`, lay out a
    `TextPainter` with `MediaQuery.textScalerOf(context)` and
    `Directionality.of(context)`, dispose it. `ownLabelWidth` = text width,
    plus `iconSize + iconGap` when `icon != null`. An empty label with no
    icon measures 0.
  - Vertical alignment from `IconDetailRow`: `firstLine = max(lineHeight, iconSize)`
    when there is an icon, `textTop = (firstLine - lineHeight) / 2`, label
    and value padded down by `textTop`, icon centred in a `firstLine` box.
  - Label cell widget: `Row(mainAxisSize: min, crossAxisAlignment: start)`
    of the icon box, `SizedBox(width: iconGap)`, `Flexible(Text(label))`.
  - Wrap the render widget in `Padding(padding)`. Add no `Semantics`.

- [ ] **Step 6: Run the tests to verify they pass**

  Run: `flutter test test/shared/widgets/detail_row/detail_row_test.dart`
  Expected: all pass.

- [ ] **Step 7: Run the architecture guards** (new files under `lib/`)

  Run: `flutter test test/architecture/`
  Expected: all pass.

- [ ] **Step 8: Commit** `feat(shared): label-column DetailRow and DetailRowGroup`

### Task 2: `DiveDetailRow`, `IconDetailRow` and `SharingTile` on `DetailRow`

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail_row.dart`
- Modify: `lib/shared/widgets/icon_detail_row.dart`
- Modify: `lib/shared/widgets/shared_items/item_sharing_row.dart` (`SharingTile`)
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart`
  (wrap each section's rows in a `DetailRowGroup`)
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`,
  `lib/features/certifications/presentation/pages/certification_detail_page.dart`
  (wrap each card's row column in a `DetailRowGroup`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail_row_test.dart`,
  `test/shared/widgets/icon_detail_row_test.dart`,
  `test/shared/widgets/shared_items/item_sharing_row_test.dart`

**Interfaces:**
- Consumes: `DetailRow`, `DetailRow.text`, `DetailRowGroup` (Task 1).
- Produces: unchanged public constructors of `DiveDetailRow`,
  `IconDetailRow` and `SharingTile`, so `find.byType`/`widgetWithText`
  finders keep working.

- [ ] **Step 1: Rewrite the geometry tests to the new rule.**
  - `dive_detail_row_test.dart:74-91`: replace "value hugs the trailing
    edge" with `value starts 16 px after the label` (W = 1000, value `dx`
    = label right + 16) and keep the wrap and badge tests; add
    `attribution badge follows the value` (badge `dx` = value right + 6).
  - `icon_detail_row_test.dart`: replace "a label that fits beside its value
    keeps one line" with the hard-cap rule (300 px row, 168 px label wraps,
    value `dx` = 120 + 16 within the row); keep icon centring and the single
    `'label: value'` semantics node; add `value is bold and start-aligned`.
  - `item_sharing_row_test.dart`: `summary starts beside "Shared with"`
    (summary `dx` = icon 20 + 12 + label width + 16 + 16 horizontal padding)
    and `chevron follows the summary`.

- [ ] **Step 2: Run them to verify they fail**

  Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail_row_test.dart test/shared/widgets/icon_detail_row_test.dart test/shared/widgets/shared_items/item_sharing_row_test.dart`
  Expected: the rewritten geometry tests fail.

- [ ] **Step 3: Re-implement the three widgets over `DetailRow`.**
  - `DiveDetailRow`: `DetailRow(label:, value: Row(mainAxisSize: min, [Flexible(Text(value, bodyMedium)), if sourceName: SizedBox(6), FieldAttributionBadge]))`.
  - `IconDetailRow`: keep `Semantics(label: '$label: $value', excludeSemantics: true)`;
    `DetailRow.text(icon:, iconSize: 20, iconGap: 12, labelStyle: bodyMedium (onSurface), valueStyle: bold + valueColor, padding: vertical 6)`.
    Delete its `LayoutBuilder` and painter code.
  - `SharingTile`: keep the `InkWell` and `Padding(h16, v12)`; inside,
    `DetailRow(icon: Icons.people_outline, iconColor: onSurfaceVariant, label: sharedWith, padding: EdgeInsets.zero, value: Row(min, [Flexible(Text(summary, maxLines: 2, overflow: ellipsis)), if onTap: SizedBox(4), chevron 18 primary]))`.
  - Wrap the media panel sections and the buddy/certification cards' row
    columns in `DetailRowGroup`.

- [ ] **Step 4: Run the widget tests plus the page tests that find these
  widgets**

  Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail_row_test.dart test/shared/widgets/ test/features/dive_log/presentation/pages/ test/features/media/ test/features/buddies/ test/features/certifications/ test/features/dive_sites/presentation/pages/site_edit_page_test.dart`
  Expected: all pass.

- [ ] **Step 5: Commit** `feat(shared): detail rows, icon rows and sharing tile use the label column`

### Task 3: Equipment detail

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
  (`_buildDetailsSection` 541-811, `_buildLinkRow` 886, `_buildColorRow` 931,
  `_buildDetailRow` 970)
- Modify: `lib/features/equipment/presentation/widgets/installed_in_row.dart`,
  `equipment_sharing_row.dart`, `service_history_section.dart` (totals 175-200)
- Test: `test/features/equipment/presentation/pages/equipment_detail_label_column_test.dart`
  (new; copy the harness from `equipment_detail_page_test.dart`),
  `test/features/equipment/presentation/widgets/service_history_section_test.dart`

**Interfaces:**
- Consumes: `DetailRow`, `DetailRow.text`, `DetailRowGroup`.

- [ ] **Step 1: Write the failing tests.**
  - `equipment_detail_label_column_test.dart`, page pumped at
    `physicalSize` 1400x1000 (dpr 1) with an item that has brand, model,
    serial, a purchase date and a dive count > 0:
    - `Details values share one column beside the labels`: values for
      Status, Brand, Model, Serial number and Purchase date all have the
      same `dx`, and that `dx < 1400 * 0.5`.
    - `Dives row keeps its link and chevron beside the count`: the
      `Icons.chevron_right` inside the Dives row has `dx` = count text right
      + 4; tapping the count still calls `openDiveList` (assert the route
      the existing test asserts).
    - `Installed in and Shared with values align with Brand` (reuse the
      fixtures from `equipment_detail_installed_in_test.dart` and
      `equipment_detail_sharing_test.dart`).
  - `service_history_section_test.dart`: `total cost amount sits beside its
    label`: amount `dx` = label right + 16.

- [ ] **Step 2: Run to verify they fail**

  Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_label_column_test.dart test/features/equipment/presentation/widgets/service_history_section_test.dart`

- [ ] **Step 3: Implement.**
  - Wrap the Details card's `Column` in `DetailRowGroup`.
  - `_buildDetailRow` becomes `DetailRow.text(label:, value:, valueStyle: bodyMedium)`.
  - `_buildLinkRow` and `_buildColorRow`: `DetailRow` with the existing link
    `InkWell` / swatch `Row(min)` as `value`.
  - The inline Dives and Trips rows: extract one private
    `_buildCountLinkRow(context, {required String label, required String semanticsLabel, required String countText, required int count, required VoidCallback onTap})`
    keeping `Semantics(button: count > 0)`, `InkWell` and the coloured count
    + chevron as the value. This removes the two duplicated 60-line blocks.
  - `InstalledInRow`: `DetailRow(label:, value: Column(crossAxisAlignment: start, [Row(min, [Flexible(host label), dot, chevron]), if age: Text(age, bodySmall)]))`
    so the install age sits under the value, start-aligned.
  - `EquipmentSharingRow._row`: `DetailRow(label:, value: Row(min, [Flexible(value), if chevron: SizedBox(4), chevron]))`.
  - Service history totals: wrap the totals `Column` in `DetailRowGroup`;
    each row `DetailRow.text(label: totalCostLabel, value: amount, valueStyle: titleMedium bold, padding: EdgeInsets.zero, maxLines: 1, overflow: ellipsis)`.

- [ ] **Step 4: Run all equipment tests**

  Run: `flutter test test/features/equipment/`
  Expected: all pass.

- [ ] **Step 5: Commit** `feat(equipment): detail values sit beside their labels`

### Task 4: Dive detail

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
  (Details card from :3232, Environment :3474, Tide :3956 with the State row
  :4080, `_buildLinkedComputerRow` :4377, `_buildTripRow` :4444,
  `_buildDiveCenterRow` :4507)
- Modify: `lib/features/dive_log/presentation/widgets/dive_course_rows.dart`
  (`_CourseRow`)
- Test: `test/features/dive_log/presentation/pages/dive_detail_label_column_test.dart`
  (new; harness from `dive_detail_page_test.dart`),
  `test/features/dive_log/presentation/pages/dive_detail_course_row_test.dart`

**Interfaces:**
- Consumes: `DetailRow`, `DetailRowGroup`; `DiveDetailRow` from Task 2.

- [ ] **Step 1: Write the failing tests** (page at 1400x1000):
  - `Details values share one column`: Dive Type, Visibility, Avg Depth and
    the Trip row's trip name share one `dx < 700`.
  - `Tide State icon sits in the label column`: Tide card with a record;
    State, Height and Rate values share one `dx`; the state icon's `dx` is
    the card's content left.
  - `a long dive centre name does not overflow`: 80-char centre name at
    400 px wide; no exception; chevron visible.
  - `dive_detail_course_row_test.dart`: `later course rows align under the
    first`: two courses; both names share one `dx`; second row has no label.

- [ ] **Step 2: Run to verify they fail**

  Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_label_column_test.dart test/features/dive_log/presentation/pages/dive_detail_course_row_test.dart`

- [ ] **Step 3: Implement.**
  - Wrap the Details, Environment and Tide cards' row columns in
    `DetailRowGroup`.
  - Tide State: replace the outer `Row[Icon, Expanded(...)]` with
    `DetailRow.text(icon: stateIcon, iconColor: stateColor, iconSize: 20, iconGap: 8, ...)`.
  - Linked computer and trip rows: keep `Semantics` and `InkWell`; inside,
    `DetailRow(label:, value: Row(min, [Flexible(Column(crossAxisAlignment: start, [name (ellipsis), subtitle (bodySmall, ellipsis)])), SizedBox(4), ExcludeSemantics(chevron 16)]))`.
  - Dive centre row: same shape with a single `Flexible(Text(name, overflow: ellipsis))`.
  - `_CourseRow`: same shape; `label` is `''` when `!showLabel`.

- [ ] **Step 4: Run all dive_log presentation tests**

  Run: `flutter test test/features/dive_log/presentation/`
  Expected: all pass.

- [ ] **Step 5: Commit** `feat(dive-log): dive detail values sit beside their labels`

### Task 5: Dive site detail

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
  (`_buildDetailRow` :1293, Location card :1189-1237, depth stats
  :1525/:1535, Dive Statistics :1691-1718)
- Test: `test/features/dive_sites/presentation/pages/site_detail_label_column_test.dart`
  (new; harness from `site_detail_page_test.dart`),
  `site_detail_statistics_links_test.dart`, `site_detail_density_test.dart`

**Interfaces:**
- Consumes: `DetailRow`, `DetailRowGroup`.

- [ ] **Step 1: Write the failing tests** (1400x1000):
  - `Location values share one column beside the labels`: Country, Region
    and GPS values share one `dx < 700`.
  - `empty value still shows Not set in the value column` (italic, same `dx`).
  - `GPS copy glyph and statistics chevron follow the value`: glyph `dx` =
    value right + 4; tapping a statistics row still opens its dive (as
    `site_detail_statistics_links_test.dart` asserts).

- [ ] **Step 2: Run to verify they fail**

- [ ] **Step 3: Implement.** `_buildDetailRow` keeps its signature,
  `Semantics` and `InkWell`; content becomes
  `DetailRow(icon:, iconSize: 18, iconGap: 12, iconColor: onSurfaceVariant, labelStyle: bodySmall onSurfaceVariant, padding: vertical 6, value: Row(min, [Flexible(Text(value, maxLines: 2, ellipsis, empty styling)), if onTap: SizedBox(4), glyph]))`.
  Wrap the Location card, the depth-range stats and the Dive Statistics
  columns in `DetailRowGroup`.

- [ ] **Step 4: Run** `flutter test test/features/dive_sites/` (all pass).

- [ ] **Step 5: Commit** `feat(dive-sites): site detail values sit beside their labels`

### Task 6: Trip vessel, dive computer detail and course detail

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_vessel_section.dart`
  (`_VesselDetailRow` :96, and wrap the section's rows in `DetailRowGroup`)
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart`
  (`_buildInfoRow` :291, `_TransmittersRow` :954, `_LinkedGearRow` :1009;
  group the info card column)
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart`
  (`_buildDetailRow` :394; group the Details and Instructor cards)
- Test: `test/features/trips/presentation/widgets/story/trip_vessel_section_test.dart`,
  `test/features/dive_computer/presentation/pages/device_detail_page_test.dart`,
  a new `test/features/courses/presentation/pages/course_detail_label_column_test.dart`
  (harness from `course_detail_page_connections_test.dart`)

**Interfaces:**
- Consumes: `DetailRow`, `DetailRow.text`, `DetailRowGroup`.

- [ ] **Step 1: Write the failing tests** (1400 wide):
  - Vessel: `vessel values share one column beside the labels` (Operator and
    Cabin values share `dx < 700`; values stay one line with ellipsis).
  - Device: `info values share one column` (Name, Manufacturer, Model);
    `linked gear and transmitters keep their chevron beside the value`
    (reuse fixtures from `device_detail_page_gear_twin_test.dart` and
    `device_detail_page_transmitters_test.dart`).
  - Course: `a label longer than 100 px no longer wraps at 100` (a 9-char
    label, 126 px, stays one line; values share one `dx` = 16 + 8 + 126 + 16);
    the `'label: value'` semantics node is unchanged.

- [ ] **Step 2: Run to verify they fail**

- [ ] **Step 3: Implement.**
  - `_VesselDetailRow`: `DetailRow.text(icon:, iconSize: 20, iconGap: 12, labelStyle: bodyMedium, valueStyle: bodyMedium bold, maxLines: 1, overflow: ellipsis, padding: vertical 4)`.
  - Device `_buildInfoRow`: `DetailRow.text(padding: vertical 4)`.
    `_TransmittersRow` and `_LinkedGearRow`: keep `InkWell`; inside,
    `DetailRow(padding: vertical 4, value: Row(min, [Flexible(text), (dot), chevron]))`.
  - Course `_buildDetailRow`: keep `Semantics(label: '$label: $value')`
    and the icon's `ExcludeSemantics`; `DetailRow.text(icon:, iconSize: 16, iconGap: 8, iconColor: onSurfaceVariant, padding: vertical 4)`.

- [ ] **Step 4: Run** `flutter test test/features/trips/ test/features/dive_computer/presentation/ test/features/courses/` (all pass).

- [ ] **Step 5: Commit** `feat(shared): vessel, dive computer and course detail values sit beside their labels`

### Task 7: Whole-branch verification

- [ ] **Step 1:** `dart format .` then `flutter analyze` (no issues).
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/` (all pass).
- [ ] **Step 3:** `flutter test test/features/equipment/ test/features/dive_log/ test/features/dive_sites/ test/features/trips/ test/features/dive_computer/ test/features/courses/ test/features/buddies/ test/features/certifications/ test/features/media/`
  (all pass; log to the scratchpad and check `grep -c "\[E\]"` is 0).
- [ ] **Step 4:** `grep -rn "spaceBetween" ` over the files this plan touched:
  every remaining hit is a header, stat tile or list row the spec leaves
  alone.
