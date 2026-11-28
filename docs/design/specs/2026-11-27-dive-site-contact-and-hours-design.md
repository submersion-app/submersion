# Dive site contact details and opening hours

Source: discussion #4408 ("Additional data for dive sites"). Also resolves
issue #2022 ("Add URL to dive sites"). Release v1.8.7.

## Intent

Inland and privately run dive sites (quarries, lakes, caves, club piers) have
a gate, an owner and opening times. A diver driving there wants one tap from
the site page to their navigation app, one tap to call the slot-booking line
or open the website, and a quick answer to "is it open when I get there?".
Today a site has country, region, city and GPS, but no street address, no
contact details and no hours, and tapping the coordinates only copies them.

## Goals

- A site can hold a free-text street address, a phone number, an email
  address and a website, shown in a Contact card with tap-to-navigate,
  tap-to-call, tap-to-email and tap-to-open, and long-press to copy.
- A site can hold opening hours: one or more weekly schedules with optional
  yearly seasons, several time ranges per day, a 24/7 state and a free-text
  note, shown in an Opening hours card with an "open now" line.
- Every site with GPS but no address also gets a directions action.
- The new data survives sync, backup, shared site libraries, CSV and UDDF
  round trips, site merges and agent access, like every other site field.

## Non-goals

- Opening hours for dive centers (#4667). The value type is built so they can
  adopt it later; this PR does not touch dive centers.
- Public-holiday calendars, one-off closures with real dates, or per-gas fill
  hours. The note covers these.
- An "open/closed" chip on site list tiles, or filtering sites by hours.
- Several websites per site (#2022 floated it). One website; extra links can
  go in notes or the description.
- Geocoding the address into coordinates, or the coordinates into an address.

## Anti-goals

- A site with no hours must look exactly as it does today: no empty card, no
  "Closed" label, no "Hours unknown" noise.
- "Open now" must never be evaluated in the phone's time zone when the site
  has GPS: a diver in London planning a Florida cave must see Florida time.
- The schedule must never be partly merged across devices (half one edit,
  half another).

## Decisions made with the maintainer

| Question | Decision |
| --- | --- |
| Scope | Contact card plus structured per-day hours |
| What hours express | Split ranges in a day, seasons, a free-text note, 24/7 |
| Seasons | Several schedules, each with an optional yearly (day and month) range that may wrap the year end; no range means all year |
| Open now | Yes, on the site detail page only, in the site's time zone |
| Address | One free-text multi-line field; city/region/country unchanged |
| Layout | Two cards: Contact, then Opening hours |
| Directions | Address when set, else GPS pin |
| Storage | Approach A: four text columns plus one JSON column |
| Catalogue website | Copied into `website` when a catalogue site is adopted, and offered by the catalogue gap-fill like other details; the header credit-line link stays as the source's link |
| Search | The site search box matches address, phone, email and website too |

## Approaches considered

- **A. Columns plus JSON hours (chosen).** `address`, `phone`, `email`,
  `website` as nullable text columns on `dive_sites`; `opening_hours` as one
  nullable text column holding JSON, decoded into an immutable `OpeningHours`
  value type in `lib/core`. One column each for sync and export, and a
  schedule resolves as a whole value under last-writer-wins.
- **B. Child table for schedules.** Queryable, but every schedule and range
  becomes a synced child row needing child-sync ordering, held references and
  merge rules, for data always read and written as one block. Rejected.
- **C. One JSON blob for all of it.** Hides phone and website from search,
  CSV, the table editor and agent access. Rejected.

## Data model

### Columns (`dive_sites`, new schema rung)

| Column | Type | Notes |
| --- | --- | --- |
| `address` | text, nullable | Free text, may contain newlines |
| `phone` | text, nullable | As typed; trimmed |
| `email` | text, nullable | Trimmed |
| `website` | text, nullable | Stored as typed (trimmed); a scheme is added only when opening |
| `opening_hours` | text, nullable | JSON (below); null means "no hours recorded" |

Empty or whitespace-only input is stored as null. The rung adds columns only;
it rewrites no existing data.

### `OpeningHours` (lib/core, pure Dart, immutable, Equatable, copyWith)

```
OpeningHours
  alwaysOpen: bool            // 24/7; schedules ignored for display when true
  schedules: List<OpeningSchedule>
  note: String?               // free text

OpeningSchedule
  name: String?               // "Summer"
  season: YearlyDateRange?    // null = all year
  days: Map<Weekday, DayHours>  // all seven present after decode

YearlyDateRange
  start: MonthDay             // month 1-12, day 1-31 valid for that month (29 Feb allowed)
  end: MonthDay               // inclusive; end before start wraps the year end

DayHours
  closed                      // no ranges
  open24h
  ranges: List<TimeRange>     // sorted, non-overlapping

TimeRange
  opensAt: int                // minutes after local midnight, 0..1439
  closesAt: int               // 1..1440, strictly after opensAt (1440 = midnight)
```

JSON shape, versioned so later fields can be added without a rung:

```json
{
  "v": 1,
  "alwaysOpen": false,
  "note": "Book slots by phone. Closed 25 Dec.",
  "schedules": [
    {
      "name": "Summer",
      "season": {"start": "04-01", "end": "10-31"},
      "days": {
        "mon": [[540, 1020]], "tue": [[540, 1020]], "wed": [[540, 1020]],
        "thu": [[540, 1020]], "fri": [[540, 1020]],
        "sat": [[480, 720], [780, 1020]], "sun": [[480, 720], [780, 1020]]
      }
    },
    {
      "name": "Winter",
      "season": {"start": "11-01", "end": "03-31"},
      "days": {"sat": [[540, 960]], "sun": [[540, 960]]}
    }
  ]
}
```

A missing day key means closed; `"24h"` as a day value means open all day.
Decoding is tolerant: unknown keys are ignored, a malformed day or range is
dropped and logged, and a value that is not a JSON object decodes to null (the
site then shows no hours rather than crashing). An `OpeningHours` with
`alwaysOpen == false`, no schedules and no note encodes to null.

### Which schedule applies on a date

1. Collect the schedules whose season contains the date (no season contains
   every date).
2. If several match, the one with the shortest season wins (all-year counts
   as 366 days); ties go to the earlier schedule in the list. A summer season
   inside an all-year schedule therefore overrides it without the diver
   cutting the year into pieces.
3. If none match, the site is closed for the season that day.

### Open now

`OpeningHours.statusAt(DateTime wallClock)` returns one of:

- `open(closesAt: TimeOfDayOnDate?)`: open now; closing time today, or null
  when open 24 hours or always open.
- `closed(nextOpen: DateTime?)`: closed now; the next opening found by
  scanning forward up to 366 days; null when it never opens.
- `unknown`: the hours have no schedules and are not always open (note only).

A range that closes at 1440 joins a range that opens at 0 the next day, so a
site open "Fri 18:00-24:00, Sat 00:00-02:00" reads as open across midnight.

The wall clock comes from `SiteTimeZone.wallClockFromInstant(now, lat, lng)`
when the site has GPS, else the device's local time. The status line is
recomputed when the page builds; it does not tick live.

## Directions

One helper builds the platform map URL:

- Android: `geo:0,0?q=<encoded address>` or `geo:<lat>,<lng>?q=<lat>,<lng>(<site name>)`.
  Android shows the diver's chooser, so their favourite navigation app opens.
- iOS and macOS: `https://maps.apple.com/?q=<address>` or
  `https://maps.apple.com/?ll=<lat>,<lng>&q=<site name>`.
- Windows, Linux, web: `https://www.google.com/maps/search/?api=1&query=<address or lat,lng>`.

The address wins when set; otherwise the GPS pin is used. If neither is set,
there is no directions action. A launch that returns false or throws shows a
"Could not open maps" snackbar.

## Site detail page

### Contact card

Placed after the Location card. Rows, each shown only when set:

- Address (multi-line), with a directions icon button; tap opens maps,
  long-press copies.
- Phone: tap opens `tel:`, long-press copies.
- Email: tap opens `mailto:`, long-press copies.
- Website: shown without the scheme; tap opens it in the external browser
  (adding `https://` when no scheme), long-press copies. Only `http` and
  `https` are ever launched.

When none of the four is set, the card is hidden. The Location card's GPS row
gains a directions icon button when the site has coordinates but no address,
so navigation is reachable without the Contact card.

The card follows the page's existing pattern: `RecordCardHeader` with the
pencil while the page is unlocked, and an empty-state title when editing.

### Opening hours card

Placed directly after the Contact card, hidden when the site has no hours.

1. Status line: "Open now, closes 17:00", "Open 24 hours", "Closed, opens
   Sat 10:00", "Closed for the season, opens 1 Apr", or nothing for a
   note-only record. Green for open, secondary text colour for closed.
2. Always open: a single "Open 24/7" row.
3. Otherwise each schedule: its name and season ("Summer, 1 Apr to 31 Oct";
   no heading line for a lone all-year schedule with no name), then the week.
   Consecutive days with identical hours collapse into one row ("Mon to Fri
   09:00 to 17:00"); the first day of the week follows the locale. The
   schedule that applies today is listed first and today's row is bold.
4. The note, in secondary text, as plain text (not Markdown).

Times use the diver's 12/24-hour setting through `formatMinutesOfDay`; day
and month names come from the locale.

## Editing

The site editor gains two sections, matching the two cards:

- **Contact:** Address (multi-line), Phone (phone keyboard), Email (email
  keyboard, validated as `something@something.something` when not empty),
  Website (URL keyboard, validated as parsing to an http or https URL once a
  missing scheme is added).
- **Opening hours:**
  - An "Open 24/7" switch; while on, the schedule editor is hidden but kept.
  - A list of schedules, each with a name field, a "Seasonal" switch that
    shows from and to day/month pickers, and seven weekday rows. Each row has
    a closed/24h/hours selector and, for hours, one or more time ranges with
    add and remove buttons.
  - A "Copy these hours to..." action on a day row, opening a picker of the
    other six days (with "select all"), because most real schedules repeat.
    No fixed notion of weekday or weekend, so Friday/Saturday weekends
    (Arabic, Hebrew locales) need nothing special. (Builder's call, settled
    during review.)
  - Add-schedule and delete-schedule buttons; a new schedule starts closed
    every day.
  - A note field.
  - Validation: a range whose close is not after its open, or ranges that
    overlap within a day, show an inline error and block saving.

The editing UI follows the existing edit-section and card-editor pattern
(`lib/features/dive_sites/presentation/widgets/edit_sections/`,
`presentation/editing/`).

## Where the fields reach

| Surface | Change |
| --- | --- |
| Database | Rung adding five columns; table definition in `tables/site_tables.dart` |
| Entity and mapper | `DiveSite` fields, `copyWith`, `props`; row mapper both ways |
| Repository | Save and update carry the fields |
| Sync | Serializer and record overlay carry the five columns |
| Shared site library | Site document carries them |
| CSV | Writer columns (newlines flattened in address); Submersion CSV parser reads them; hours as the JSON string |
| UDDF | Export and import in Submersion's own extension elements, like `parkinginfo`; hours as JSON text |
| Merge page | Address, phone, email, website and hours offered as pickable fields; hours picked as a whole |
| Agent access | Read documents include them; site writes accept the four text fields and the hours JSON, validated |
| Table editor | Columns for address, phone, email and website; hours not shown |
| Duplicate site | Copies all five |
| Search | `searchSites` also matches address, phone, email and website (case-insensitive substring, like the existing place fields) |
| Catalogue adopt | A site adopted from a catalogue record takes the record's `website` |
| Catalogue gap-fill | Website joins the fillable fields (`CatalogueGapField`), filled only when the site's own website is empty, like the other details |
| Sync conflicts | The five fields appear in the site conflict field list, following `parkingInfo`; hours shown as a summary line and chosen as a whole |
| Rules | Not added |
| Localization | All new strings in every locale's ARB |

## Range of divers

- A diver with no inland sites never sees either card.
- A site with ten schedules and three ranges a day must stay readable at
  phone width; the collapsed day rows wrap rather than truncate.
- Long addresses and long URLs wrap; a very long note wraps.
- RTL locales (Arabic, Hebrew) mirror the rows.

## Left to the builder

- Exact widget and file split, within the 800-line limit (`site_detail_page.dart`
  is already over it, so new cards go in their own widget files).
- Icon choices, and the exact copy of each string.
- Whether the hours editor opens inline or as a full-screen sheet on phones.
- Test layout, following TDD.
