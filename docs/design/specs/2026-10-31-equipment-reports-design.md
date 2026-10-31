# Equipment Reports

Target release: v1.8.4. Mockups:
[2026-10-31-equipment-reports-mockup.html](assets/2026-10-31-equipment-reports-mockup.html).

## Why

The app already records what a diver owns, what they paid, what service cost
and how much each item has been dived, but the only ways to get that back out
are the gear CSV and the Maintenance log spreadsheet. Four questions have no
answer today:

- **Insurance or customs:** what do I own, with serial numbers and what I paid?
- **Readiness:** what needs servicing, and is the gear for this trip ready?
- **Cost:** what has this hobby cost me, and which gear earns its keep?
- **Usage:** what do I actually use, and what has sat idle?

The diver chose all four. The split is by purpose: things you hand to someone
are documents on Transfer > Export, next to the other exports. Things you browse
are numbers on Insights > Equipment, next to the existing gear rankings.

## Goals

- Add two PDF exports on Transfer > Export: Equipment inventory and Service
  report, each with a short options sheet.
- Add two sections on Insights > Equipment: Cost of ownership and Idle gear.
- Extend Most used gear with hours and the full list.
- Add purchase price and currency to the gear CSV, in both directions.

## Non-goals

- No schema change. Every figure comes from data already stored.
- No currency conversion, and no adding across currencies, anywhere.
- No current value, depreciation or resale proceeds. The app records what was
  paid and nothing else, and the inventory says so on the page.
- No new Reports page or new navigation.
- No scheduled or automatic reports.
- No forecast of usage into a trip. Dive-count dues show what is left today.

## Anti-goals

These would make the feature a failure even if it worked:

- A single total that adds dollars to euros.
- A printed price or cost when the diver turned that switch off.
- A report that quietly drops gear with no price, instead of saying how many.
- Wishlist gear counted as owned or as money spent.
- Sections on Insights > Equipment that disagree on how many dives an item has
  done, apart from the Exposure difference explained under Constraints.
- Gear in regular use reading "Never dived" or "no dives yet".

## Who counts as "yours"

Reports use four gear sets. Each is a named predicate in one place, so the
reports and their tests cannot drift apart.

| Set | Contains | Used by |
| --- | --- | --- |
| **Owned now** | Owned by the active diver (or ownerless), `isFitted`, status not `lost` | Inventory |
| **Serviceable** | Owned now, plus gear shared with the active diver | Service report "All gear" |
| **Ever owned** | Owned by the active diver (or ownerless), status not `wanted` | Cost of ownership |
| **Idle candidates** | Owned now, minus status `spare`, top-level items only | Idle gear |

`isFitted` already means active and not retired, sold or wanted. So Owned now
holds active, spare, needs service, in service and loaned gear.

Shared gear stays out of the inventory and Cost of ownership, because another
profile owns and paid for it. It stays in the Service report, because the diver
takes it diving, and its service costs print there when Show costs is on, as
they already show on its item page.

## Equipment inventory PDF

Tile on Transfer > Export, with the Maintenance log tile. Tapping it opens the
options sheet, then the existing Share or Save choice.

**Options**

| Option | Values | Default |
| --- | --- | --- |
| Group by | Gear type, Location | Gear type |
| Location | All locations, or one place | All locations |
| Show prices | On, Off | On |

**Page**

- Header: "Equipment inventory", diver name, print date.
- Summary strip: item count, then one total per currency (hidden with prices
  off).
- One block per group, with a subtotal per currency on the group heading.
  Location groups end with "No location set". Gear type groups use the type's
  display name, in the enum's order.
- Columns: Item, Serial, Bought, Paid. The Item cell shows the name, with brand
  and model on a second line when set.
- Footer: "Prices are what was paid, not current value. N items have no price."
- The table runs across as many pages as it needs, with the column headings
  repeated.

**Rules**

- Components print indented under their parent, in the parent's group, with
  their own serial, date and price. A part counts in the item count and its own
  price counts in the totals. The parent's Paid is its own price only.
- A part whose parent is not in the report prints as a top-level row.
- The Location filter and location grouping read each top-level item's current
  place. Parts follow their parent.
- With prices off, the Paid column, subtotals, summary totals and the footer
  sentence all disappear. Serial and Bought stay.
- Totals use `sumByCurrency`, so a blank currency falls back to the default
  currency as it does on the gear summary.
- If the chosen location holds no gear, the sheet shows the existing "nothing to
  export" error rather than a blank PDF.

## Service report PDF

Tile on Transfer > Export, next to the inventory, with the same flow.

**Options**

| Option | Values | Default |
| --- | --- | --- |
| Gear | All gear, Packed for a trip, One item | All gear |
| Service history | On, Off | On |
| Show costs | On, Off | On |

Choosing Packed for a trip adds a trip picker, newest trip first. Choosing One
item adds an item picker over Ever owned plus shared gear, because selling a
retired regulator is a main reason to print its history.

One item on an assembly includes its installed parts, at any depth, each as its
own entry. Service is often recorded on the first stage rather than the reg set,
so without its parts the report could wrongly say nothing was ever done.

**Page one: the due list (always)**

- Header: "Service report", diver name, print date, and the trip or item name
  when one was chosen.
- Summary strip: overdue, due soon and up to date, counted in clocks so the
  numbers match the rows.
- Table: Item, Service, Due, Status. Overdue first, then due soon, then by due
  date.
- Only overdue and due soon clocks are listed. One item lists all clocks of the
  item and its parts, including those up to date. With nothing due, the table is
  replaced by "Everything is up to date."
- Footer: "N items have no service schedule." when that count is above zero. It
  counts top-level items only, so hoses and other parts do not inflate it.

The Due column uses the existing trigger text (`formatServiceTriggerLines`), so
it reads the same as the item page, for example "12 dives left".

**History pages (when on)**

- One block per item: name and serial on the heading, dive count on the right.
- Table: Date, Work, Shop, Cost, newest first.
- The dive count is the item page's count, from `getDiveCountForEquipment`, so
  the two read the same.
- Items with no service records are left out of this part. If nothing chosen
  has any records, it prints a single "No service recorded" line, so the page is
  never empty.
- Show costs off removes the Cost column.

**Trip behaviour**

- Gear is the trip's gear from `tripGearIdsProvider` through `gearOnTrip`:
  packed, on the cylinder board, or installed in either. `gearOnTrip` is given
  all of the diver's visible gear except wishlist items, not just active gear.
  Otherwise a past trip would lose gear retired since then, and a part of a
  retired assembly would drop out.
- A clock is listed when it is overdue or due soon today, or when its due date
  falls before the trip ends. That is everything `tripServiceAlertsProvider`
  warns about, plus usage clocks that are merely due soon, because the report
  answers "is everything I am taking ready?". A clock listed only because of the
  trip end reads Due soon.
- Usage clocks are judged as of today, never forecast into the trip.
- A trip with no gear shows the existing "nothing to export" error.

Clock evaluation reuses `evaluateServiceClocksForIds`, which already handles
retired and spare gear, keeps every clock, and reads in chunks.

## Cost of ownership (Insights > Equipment)

New section after Most used gear. It always covers all dives and all time. Its
subtitle reads "Purchase plus service, across all your dives", following the
pattern of the condition findings section, whose subtitle changes when the
Insights filter is on.

**Contents, top to bottom**

1. Currency picker, shown only when more than one currency exists. It drives the
   whole section. Default is the currency with the largest total.
2. Headlines: Spent in total, and Per dive.
3. Spending by year: one bar per calendar year from the first to the last year
   with spending, so an empty year in the middle still shows.
4. Ranked list with a picker: Per dive (default), Per hour, Total.

**Definitions, per currency**

- **Item cost** is its purchase price plus the sum of its service record costs.
  A service record with no cost adds nothing.
- **Spent in total** is the sum of item costs over Ever owned, so sold and
  retired gear counts. That money was spent.
- **Headline Per dive** is Spent in total divided by the diver's dives that
  count toward statistics. With several currencies it is a per-currency figure,
  not a blend.
- **Rows** are top-level items. A part's cost rolls into its parent's row, so a
  reg set's row includes its first stage's price and service. A part whose
  parent is not in Ever owned keeps its own row. Rolling up changes rows only:
  Spent in total is the same either way.
- **Row Per dive and Per hour** use the top-level item's dives and hours, under
  the rules in Constraints.
- **Year** is the purchase date's year for the price, and the service date's
  year for a service cost.
- A price with no purchase date counts in the totals and the list but not in the
  bars. The bars note "N purchases have no date" when it applies.

**Ranked rows**

- Value on the right, cost and usage on the subtitle: "$1,565 over 340 dives".
- Highest cost per dive or hour first. Gear with no dives sorts last and reads
  "no dives yet", with its total on the subtitle.
- Gear with no price and no service cost is not listed. A note below the list
  says how many items that left out.
- An item priced in one currency and serviced in another appears under each
  currency with that currency's share only. It is never converted.

The section shows the top 10 with a "Show all" control, as Most used gear does.
With no costs recorded at all, it shows a short empty message.

## Idle gear (Insights > Equipment)

New section after Cost of ownership. Subtitle: "Gear you own and have not dived
lately". Like cost, it ignores the Insights filter and says so, because idle
means idle across everything.

- Picker: Over 6 months, Over 1 year (default), Over 2 years. The choice lasts
  for the session, like the exposure ranking's unit.
- A dived item is listed when its last dive is older than the period. The row
  shows the time since, such as "2 yrs 4 mo".
- A never-dived item is listed when its purchase date, or its created date if
  there is no purchase date, is older than the period. It reads "Never dived".
  Gear bought last week is not idle.
- Longest idle first, never-dived after those.
- Parts are not listed. They follow their parent.
- A dive left out of statistics still counts as use here, because the gear was
  in the water. Planned dives do not count.
- With nothing idle, it shows a short positive empty message.

## Most used gear

- Each row gains total hours on the subtitle: "340 dives, 412 hours".
- A "Show all" control expands past the top 10.
- It keeps following the Insights filter, which is what makes "usage by year or
  by trip" work: set the filter's date range or trip.
- Hours use the first positive of `runtime` and `bottom_time` per dive, the same
  rule as the exposure samples, so bottom time never replaces runtime.

## Gear CSV

Append `Purchase Price` and `Purchase Currency` as the last two columns, after
`Location`, so a reader taking older columns by offset is unaffected.
`submersion_equipment_csv_parser.dart` reads both back as `purchasePrice` and
`purchaseCurrency`, so a Submersion export round-trips. The price is written
with a plain decimal point. An old file without the columns imports as before.

## Constraints

- **Gear links:** new queries read `diveGearUsageSql`, the canonical list of
  every way an item is on a dive, including the transmitter serial link.
  `getMostUsedGear` moves onto it too, so a transmitter's count there can rise
  to the true number. It returns duplicate pairs by design, so count distinct
  dives per item and sum hours over distinct pairs.
- **Which dives count:** the setting's own help text says an excluded dive is
  left out of "every statistic, including your dive count". So Cost of ownership
  and Most used gear apply `DiveStatsScope`, and Idle gear (no planned dives,
  excluded dives kept) carries a `stats-scope-exempt` marker saying why.
- **Exposure may differ:** the Exposure ranking on the same page measures wear,
  so it keeps counting excluded dives and a part's inherited dives. Its hours
  can legitimately differ from Most used gear. This change leaves it alone.
- **Units:** hours are the only measure and need no unit setting. Dates use the
  diver's date format. Money uses `formatMoney`.
- **PDF fonts:** both services follow `PassportLabelPdfExportService`, with an
  injectable theme loader and `PdfLocalization`, so non-Latin and right-to-left
  locales print correctly.
- **Text:** every new string goes into all 11 locale ARB files, translated.
- **Providers:** any provider calling a repository needs a direct
  `invalidateSelfWhen`, per `test/architecture/provider_change_tick_test.dart`.
- **Insights errors:** a section that fails shows its own error, never the empty
  message.
- **Insights isolate:** figures are computed in queries where that is practical.
  The dive database runs on a background isolate, so reading every sample to
  add a total is the slow path. Cost and idle need totals only, not samples.

## Decided by the designer, not the diver

The diver chose the placement, the shape of each report, one PR, and these three
details: parts roll into their parent in the cost list, One item brings its
installed parts, and shared gear's service costs print. The rest are the
designer's calls, open to change in review:

- Inventory holds gear owned now. Retired, sold, lost and wishlist gear are out,
  and shared gear belongs to its owner's inventory.
- Spent in total includes sold and retired gear. Wishlist gear is excluded.
- Cost and Idle ignore the Insights filter. Most used gear follows it.
- The currency picker drives the whole cost section, instead of stacking a block
  per currency.
- Idle gear periods, and the rule that newly bought gear is not idle.
- Excluded dives count as use for Idle gear but not for cost or Most used gear.
- Transmitters get their true dive count, which can differ from the item page.
- A trip's due list is wider than the trip page's alerts.
- The inventory's Item cell adds brand and model, which an insurer will want.
- The gear CSV gains purchase price and currency in both directions.

## Left to the builder

- The exact SQL, and whether cost and idle share one repository method.
- Whether the options sheets share a widget. They probably should.
- The chart widget for spending bars, from `stat_charts.dart` or similar.
- File layout, within the 800-line limit and the existing `export/pdf/` and
  `insights/` folders.

## Testing

- Pure builders turn gear, records and options into a report model, so the
  rules above are tested without a PDF: grouping, the gear sets, per-currency
  totals, price hiding, trip dues, idle thresholds, sorting.
- Each PDF service is tested for producing bytes on the empty and full cases,
  and for leaving prices out with Show prices off.
- Repository tests prove gear linked only through a tank, a tank regulator pair
  or a transmitter serial counts toward dives and hours, once per dive, and that
  excluded and planned dives follow the rules under Constraints.
- A CSV round-trip test covers the new columns and the old file shape.
- Widget tests cover the options sheets and the Insights sections, including the
  error and empty states.
