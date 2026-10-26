# Detail pages: values sit beside their labels

## Intent

On a wide window, the label/value rows on detail pages pin the label to the
leading edge of the card and the value to the trailing edge. At desktop width
the two end up most of a screen apart, and the reader loses the row on the way
across. This happens both on the full-width page and in the detail pane beside
a list. The user only wants to read the details of an item, the way they would
read a spec sheet.

The fix is one layout for every label/value row in the app: the labels form a
column, and each value starts right after it. The gap between a label and its
value no longer depends on the window width.

## Goals

- At every width (phone, the pane beside a list, full-width desktop), a
  detail row reads label, a fixed gap, then the value.
- Within one card, every value starts at the same position. The label column
  is as wide as that card's widest label, so the values form a straight
  column.
- One shared row layout replaces the hand-rolled copies, so pages cannot
  drift apart again.

## Non-goals

- Restyling. Each row keeps its existing label style, value style (bold stays
  bold), colours, icons, chevrons, badges, swatches, tap targets and
  semantics. Only the value's position changes.
- Changing what rows exist, their order, or their content.
- Rows that are not label/value pairs (see "Left alone").

## Anti-goals

- Making a phone layout worse. Phones switch too, so long values must still
  wrap cleanly in the value column.
- A long localized label squeezing the values into a sliver, or overflowing
  the row at a large text size.
- A visible jump when a card first builds, such as the values moving a frame
  after the rows appear because the label width was measured late. (A row
  that arrives later, see "Late rows", is a different case.)

## The layout

For one row: `[label cell: optional leading icon, label] 16 px gap [value]`.

- **Value**: starts at the value column and is aligned to the start (left in
  LTR, mirrored in RTL). It wraps within the value column, so a wrapped line
  starts under the value's first word, not under the label.
- **Label cell**: a row's leading icon (if any) and its gap sit inside the
  label cell, before the label. So in a card where only some rows have an
  icon (the dive Tide card's "State" row), every value still starts at the
  same position. The Tide State row passes its icon to the shared row rather
  than wrapping it from outside.
- **Label column width**: the widest label cell in the card at its natural
  width, capped at 40% of the row width. A label wider than the cap wraps
  within the column. This is a hard cap measured from label cells only.
  It is stricter than `IconDetailRow`'s current per-row rule (issue #2695),
  which lets a label pass 40% when its own value is short. *Builder's call:*
  the hard cap keeps the measurement to labels, which are always text, while
  values are often widgets. The cost is that a very long translated label
  (German "Oberflächenintervall") may wrap onto a second line on a phone.
  The `IconDetailRow` test "a label that fits beside its value keeps one
  line" is rewritten to the new rule.
- **Alignment group**: the card. Different cards on one page may have
  different label column widths. Rows that are not inside a group fall back
  to their own label cell's natural width under the same cap.
- **Late rows**: some rows appear only once their data loads (dive Surface
  Interval and Training Courses, equipment "Shared with" and "Installed in").
  When such a row has the card's widest label, the value column widens once
  as it arrives. *Builder's call:* this is accepted. These come from the
  local database within the first frames, and reserving widths up front
  would mean adding loading placeholders, which is out of scope.
- **Vertical alignment**: top-aligned, so a wrapped value or label keeps the
  other on its first line. A leading icon stays centred on the first line,
  as `IconDetailRow` does today.
- **Continuation rows** with an empty label (later rows of a course list,
  unlabelled photo-info lines) leave the label cell empty, so their value
  lines up under the value above.
- **Trailing extras** (a chevron, the dive page's source attribution badge, a
  copy glyph, a host's service-status dot) follow the value directly instead
  of sitting at the far edge.
- **Line limits stay as they are** (*builder's call*, following the
  non-goal): every row keeps the value line limit and ellipsis it has today.
  Site detail rows keep `maxLines: 2`, `SharingTile` keeps 2, vessel rows
  keep one line, and the tappable rows' names keep their one-line ellipsis
  (dive trip, linked computer, course). Rows with no limit today wrap
  freely. Labels have no line limit, so a label over the cap wraps.
- **Text scale**: the column width is measured at the current text scale.

## Scope

Every label/value row that today pins its value to the trailing edge, on
these surfaces:

**Equipment detail** (`lib/features/equipment/presentation/`)

- Details card: `_buildDetailRow`, `_buildLinkRow`, `_buildColorRow`, the
  inline Dives and Trips rows in `equipment_detail_page.dart`,
  `InstalledInRow` (including its install-age line, which moves under the
  value), and `EquipmentSharingRow._row`.
- Service history: the total-cost rows in `service_history_section.dart`
  (currency label, then the bold amount).

**Dive detail** (`lib/features/dive_log/presentation/`)

- `DiveDetailRow` and the page's `_buildDetailRow` wrapper: Details,
  Environment and Tide cards, gas consumption rows and dive computer string
  rows. The Tide "State" row with its leading state icon.
- The tappable rows `_buildLinkedComputerRow`, `_buildTripRow`,
  `_buildDiveCenterRow` (its inner row must also stop overflowing on a long
  name), and `_CourseRow` in `dive_course_rows.dart`.

**Dive site detail** (`lib/features/dive_sites/presentation/`)

- `_buildDetailRow` in `site_detail_page.dart` and its wrappers
  `_buildSiteTypesRow` and `_buildStatRow`: Location card, depth-range
  "reached" stats, and the Dive Statistics rows. Includes the "Not set"
  empty state, the chevron link rows and the GPS copy row.

**Trip detail** (`lib/features/trips/presentation/`)

- `_VesselDetailRow` in `widgets/story/trip_vessel_section.dart`.

**Dive computer detail**
(`lib/features/dive_computer/presentation/pages/device_detail_page.dart`)

- `_buildInfoRow`, `_TransmittersRow` and `_LinkedGearRow`.

**Course detail**
(`lib/features/courses/presentation/pages/course_detail_page.dart`)

- `_buildDetailRow`, which already puts values beside a fixed 100 px label
  column. It moves to the shared row so its column follows the same rule.

**Shared**

- `SharingTile` in `lib/shared/widgets/shared_items/item_sharing_row.dart`
  (the "Shared with" row on site and trip detail). *Builder's call:* it is
  changed in place, so the same row on the site and trip edit pages
  (`ItemSharingField`) changes too and stays consistent with detail.
- `IconDetailRow` in `lib/shared/widgets/icon_detail_row.dart`: buddy detail
  and certification detail.
- `media_info_panel.dart`, which renders `DiveDetailRow`, so it changes with
  it.

## Left alone

- Card headers that put a count, total or action at the trailing edge
  (dive Profile header, Weight "Total", Tags, Buddies, Marine Life and Custom
  Fields counts, the signature header, service clocks, site tags, tide and
  reef headers, the photo section header).
- Stat tiles and grids (altitude, deco status, O2 metric tiles, range stats,
  data-source metrics, `TwinSummaryRows`, `TripStatStrip`, site depth and
  altitude stat columns).
- Gauge headers and footers in `CompactO2ToxicityPanel` (CNS and OTU).
- The dive Weight card's item rows and `BuoyancySection._termRow`.
- SAC segment bar rows and tissue axis captions.
- List tiles and list rows whose trailing edge is a menu, button or chevron:
  equipment Location, service clocks, observations, components, documents,
  buddy and role tiles, cylinders, safety review findings, trip overview,
  gear and cylinder rows, menus and sheets.
- Rows already laid out label-adjacent or stacked: dive custom fields,
  `_GpsCoordinateRow`, site access rows.
- Detail-style rows on tool and calculator pages (for example the full
  `O2ToxicityCard` on the CNS/OTU page, and `DecoInfoPanel` on the deco
  calculator). They are not detail pages for an item.

## Constraints

- Rows sit among other widgets in each card's `Column` (headers, dividers,
  conditional rows, rows built by other widgets such as `InstalledInRow`), so
  the card-wide label width cannot rely on the rows being direct children of
  one parent.
- The shared row must handle the variants above without forking: an optional
  leading icon, a value given as text or as a widget (link, swatch, badge,
  chevron, multi-line block), an optional tap with its existing semantics,
  optional value style and line limit.
- Platform-agnostic, RTL-correct (use start/end, never left/right).
- Existing tests that pin the old geometry change with the layout:
  `test/features/dive_log/presentation/widgets/dive_detail_row_test.dart`
  (asserts the value hugs the trailing edge) and
  `test/shared/widgets/icon_detail_row_test.dart`. Tests that find rows by
  type (`find.widgetWithText(DiveDetailRow, ...)`, `find.byType(SharingTile)`)
  should keep working, so keep those class names or update the finders.

## Left to the builder

- The mechanism for the card-wide label width (for example a group widget at
  each card that measures its rows' labels within one layout pass), as long
  as there is no visible jump and it updates when a label changes.
- Where the shared row and its group live (probably `lib/shared/widgets/`),
  and whether `DiveDetailRow`, `IconDetailRow` and the private helpers become
  thin wrappers over it or are replaced at their call sites.
- How to split the work into commits. It ships as one PR, against an issue
  opened from this design.
