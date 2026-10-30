# Several entry and exit methods per dive site

Issue: #2054. Release: v1.8.3.

## Intent

A dive site can often be reached more than one way: from a boat or from the
shore, by giant stride or by back roll. Today a site holds a single entry
method and a single exit method, so a diver reading the site page learns only
one of the ways in and out. The site page should tell a diver the various
methods of entering and exiting the site.

The issue also reports that two French labels read as entry only ("Mise à l'eau
depuis le bateau", "Mise à l'eau du bord") although the same labels name exit
methods too.

## Goals

- A site records any number of entry methods and any number of exit methods,
  chosen from the existing `EntryMethod` list.
- The site page shows all of them.
- The labels for `boat` and `shore` read correctly as entry or exit, in
  every language.

## Non-goals

- Dives stay single-valued. A dive records the one way the diver got in and out
  that day (the reporter: multi-select is "not needed for the dives
  themselves").
- No new entry methods, no new "access" concept separate from entry method.
- No one-tap chips on the dive form offering the site's methods. Possible later
  if asked for.

## Anti-goals

- The app must never guess which of several site methods a diver used. A dive
  must not acquire an entry or exit method it was never given.
- A site that has exactly one method must behave exactly as it does today, in
  every screen, export and query.

## Behaviour

### Site edit page

The Entry method and Exit method rows in the Access and Safety section become
multi-select over `EntryMethod.values`. Exit left empty keeps today's meaning,
"same as entry". Order shown is enum declaration order, independent of the
order the user ticked them (builder's call, so the stored value is canonical).

### Site detail page and site list

The Access section shows each list as a localized comma list
("Shore, Boat"). Exit is shown only when it differs from entry, compared as
sets. The site list's Entry Type and Exit Method columns show the same list,
using the names they use today (`displayName`), joined by ", ".

### Assigning a site to a dive

`entryExitAfterSiteAssign` (dive form) and the dive-side snap
(`dive_site_snap.dart`) treat a site's entry as "the site's method" only when
the site lists exactly one entry method; with zero or several it contributes
nothing, and the dive's current entry is kept. The same rule applies to exit:
an explicit site exit applies only when the site lists exactly one exit
method. The existing sticky-exit and "exit follows entry only when entry
changed" rules are otherwise unchanged, with one addition: when the site lists
two or more exit methods, a still-linked exit does not follow the new entry
either, and the dive keeps its current exit. Otherwise a site with entry Boat
and exits Ladder and Shore would give the dive exit Boat, which the site says
is not a way out (builder's call, from the anti-goal).

### Effective entry method fallback

`Dive.effectiveEntryMethod` falls back to the site's entry method only when
the site has exactly one. Every SQL fallback that reads `dive_sites.entry_method`
or `dive_sites.exit_method` (Insights conditions, Insights focus factors, and
any other `COALESCE` over the site column) must fall back only for a
single-method site, so a multi-method site's dives count as "not recorded"
rather than as a combined bucket.

### "Most logged" suggestion (#1104)

Unchanged: a site with no entry methods offers the pairing most often logged
there, which fills a one-item entry list and, when present, a one-item exit
list. The user can add more afterwards.

### Rules (#3513)

Site rule actions set a site column. Setting entry or exit method to a value
replaces the list with that single value. No "add to list" action.

### Duplicate-site merge

The site edit page's merge candidates for entry and exit offer each source
site's whole list as one candidate, as they offer the single value today. No
union of lists (builder's call; matches how other fields merge).

## Storage, sync and interchange

- **Storage:** the existing nullable `dive_sites.entry_method` and
  `dive_sites.exit_method` text columns hold the method names joined by a
  comma, in enum order, no spaces (`shore,boat`). Empty list is stored as
  null. A single method is stored exactly as today (`shore`), so existing
  rows need no migration and there is no schema bump.
- **Parsing:** unknown names in the list are dropped; an empty result reads as
  no methods. Shared helpers encode and decode the list so every reader and
  writer agrees.
- **Older app versions:** an older version reads a joined value as "not set"
  (its name lookup returns null; it does not crash). If a user edits and saves
  that site on an older version, the list is lost. Accepted; call it out in
  the v1.8.3 release notes.
- **Sync and the shared club library** (`site_document_bridge.dart`) carry the
  joined string unchanged.
- **Exports:** CSV, Excel and KML keep the English `displayName` they write
  today, so a single-method site exports exactly as before. CSV joins a list
  with the repo's existing cell-list codec (`joinCsvList`, "; ", the format
  already used for site types and tags). Excel and KML join with ", ". Excel
  writes only entry today; it stays that way.
- **Imports:** the Submersion CSV sites parser splits the cell with
  `splitCsvList` and matches each item by `displayName` as today; a single
  value imports exactly as before.
- **UDDF:** out of scope. UDDF carries no site-level entry or exit method
  today (only per-dive `entrytype`/`exittype`, which stay single), and adding
  site elements would change UDDF output for every site.
- **Sync conflict labels:** the conflict labeler for site entry and exit
  (`entryMethodLabeler`, shared with dives through `dive_log_fields.dart`)
  must render a joined value as a comma list for sites.

## Domain model

`DiveSite.entryMethod` / `exitMethod` (`EntryMethod?`) become
`entryMethods` / `exitMethods` (`List<EntryMethod>`, empty by default, never
null), with `copyWith` and equality updated. Every consumer listed under
Behaviour moves to the list. A convenience getter returning the single method
when the list has exactly one is the builder's call.

## Boat and Shore labels

The same labels name both entry and exit methods, so they must not say
"entry". The user chose to fix this in every locale, not only French.

- `app_fr.arb`: `enum_entryMethod_boat` becomes "Bateau",
  `enum_entryMethod_shore` becomes "Bord". The reporter wrote "Boat";
  "Bateau" is our reading, since the paired label is French.
- `app_en.arb`: "Boat" and "Shore".
- Every other ARB file: the neutral word for boat and for shore in that
  language, dropping the entry wording (for example German "Boot" and "Ufer").
  These translations are the builder's, so the PR asks for a native check.
- `EntryMethod.displayName` ("Shore Entry", "Boat Entry") is unchanged. It is
  the English vocabulary of CSV, Excel and KML exports and of CSV import
  matching, so changing it would break re-import of files already exported
  (builder's call).

## Testing

TDD per the repo. At minimum: encode/decode round trip and unknown-name
handling; site-assign autofill for zero, one and several methods on entry and
exit; `effectiveEntryMethod`; the Insights SQL fallback with a multi-method
site; CSV round trip of a list and of a single value; the edit
section's multi-select; the detail page's comma list and set-based exit
comparison.

## Left to the builder

Widget choice for the multi-select row (reuse an existing picker pattern if
one fits), helper names and locations, and the exact list of files touched.
