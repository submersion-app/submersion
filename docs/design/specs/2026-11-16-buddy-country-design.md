# Buddy country (issue #4457)

## Intent

Divers often know little more about a buddy than a first name and where the
buddy is from. A country field on the buddy, like the one on dive sites but
with no region, records that. The flag beside it makes it easy to scan.

## Goals

- Record a buddy's country on the edit page, and show it on the detail page.
- Offer country as a field you can choose for the buddy list rows and as a
  sortable column in the table view.
- Store it the same way sites do: the text as the diver wrote it, plus the
  ISO 3166-1 alpha-2 code read from that text, so a flag can be drawn.

## Non-goals

- No region field (the issue asks for none).
- No country on the diver's own profile, and none on buddy cards. A swapped
  card cannot carry a country until the profile has one, which is a separate
  change.
- No flag on list rows by default. The list looks as it does today until the
  diver adds the country field.

## Anti-goals

- Adding a buddy must not get harder. The field is optional and free text,
  like the site country field.
- A hand edit must never leave the old country's flag beside the new text.

## Approaches

1. **One text column, flag worked out when shown.** Least storage. Buddies
   are never geocoded, so the code would always follow the text.
2. **Text plus code, like sites (chosen).** `buddies.country` and
   `buddies.country_code`, saved by the same rules sites use. This keeps the
   buddy data shaped like site data, so anything that reads site country
   codes (flags, agent access, future country features) reads buddies the
   same way.
3. **Code only, picked from a list.** Clean, localized names, but the diver
   cannot type "Scotland" or "Bonaire" as on a site, and the field would work
   differently from the site and dive centre fields.

Approach 2 was chosen.

## Decided

- Placement: edit page, detail page, an optional list-row field and a
  sortable table column. No default flag on rows (option A).
- Storage: text plus code (approach 2).

## The design

- **Schema v372 (renumbered from v371, which main took for #4413):** two
  nullable `TEXT` columns on `buddies`, `country` and
  `country_code`, added in a rung and re-asserted in `beforeOpen`. No
  backfill: no buddy has a country yet. Nullable columns, so the
  compatibility floor does not move and an older peer simply omits them.
- **Entity:** `Buddy.country` and `Buddy.countryCode`, in the constructor,
  `copyWith` (with clearing) and `props`.
- **Code on save:** the buddy repository passes every write through the same
  rule as sites (`reconciledCountryCode`): a changed country text whose code
  did not change with it is read afresh with `countryCodeFor`; unchanged text
  written without a code keeps the stored one; a new buddy gets a code from
  its text. The rule moves to `lib/core/geography/` taking plain
  country/code pairs, so sites and buddies share one copy.
- **Edit page:** a Country field after the contact fields, with suggestions:
  countries already used on buddies and sites first, then the ISO list (the
  site field's `suggestedCountries` shape).
- **Detail page:** the country row with its flag, when set. Flags follow the
  existing "show country flags" setting.
- **List and table:** `BuddyField.country`, sortable, available in every
  row layout's slots and as a table column. As on sites, a standard or
  compact row whose subtitle slot shows the country draws the flag beside
  it; stat slots and table cells show the text.
- **Merge:** the buddy merge page offers each buddy's country as a choice,
  and the chosen country brings its code.
- **Search and query:** the buddy text search matches country, and the query
  language gets a `country` field for buddies.
- **Sync:** the columns ride the buddy row like any other column. No data is
  rewritten, so `changeLogRewrittenColumns` is untouched.
- **Conflict resolution:** the people catalogue lists country, so a sync
  conflict on it can be chosen field by field.
- **UDDF:** export writes `address/country` on each buddy (left out of a
  trimmed export, like email and phone); import reads it back and derives the
  code.
- **Agent access:** buddy documents report country, buddy writes accept it,
  and the generated SQL column notes describe both columns.

## Left to the builder

- Exact placement of the field and row within each page's existing sections.
- Localized labels for the new strings, in every ARB file.
- Whether the shared code rule needs a thin site-specific wrapper to keep
  `reconciledCountryCode(DiveSite)` call sites unchanged.
