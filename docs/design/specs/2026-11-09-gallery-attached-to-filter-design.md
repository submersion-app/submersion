# Gallery: filter and group by what a picture is attached to

Issue: #4224

## Intent

The media library mixes two kinds of picture: ones from the diver's own
dives, and ones attached to a dive site (a site map, a rules board, a
reference shot taken by someone else). A diver working through their dive
photos, for example to tag people and species, wants the site pictures out
of the way. The reporter put it as "easily identify/hide pics from dives
(the one I mainly want to edit) versus the ones from sites".

The library can already tell the two apart: the By dive view gives a
picture attached to a site but to no dive its own site group (#4149), and
since #4305 every site group sorts after every dive group. What is missing
is a way to hide one kind, and a visible boundary between them.

## Goals

1. **An "Attached to" filter** in the library filter sheet, with four
   choices: **Dive**, **Site**, **Equipment**, **Unlinked**. Picking "Dive"
   hides the site pictures in every view.
2. **Section headings in By dive** where the kind of group changes, so the
   run of site groups (and equipment groups, and Unlinked) after the dives
   is labelled.

## Non-goals

- No new grouping mode (no "By site" view).
- No toolbar toggle; the filter lives in the existing sheet.
- No built-in smart albums. A diver can save the filter as an album.
- No change to which group a picture goes in, or to the group order.
- No headings in the Grid, Timeline or Map views.

## Anti-goals

- A dive photo must never be treated as a site picture because its dive
  has a site. "Site" means attached to a site directly and to no dive.
- An album saved with the new filter must not break, or throw in, a build
  that predates it.

## Behaviour

### What each choice matches

Every media row has at most one dive, one site and one equipment link of
its own (`media.dive_id`, `media.site_id`, `media.equipment_id`). The
choices follow the same precedence `groupByDive` and the By dive SQL group
key already use, so a row matches exactly one choice:

| Choice | Matches a row whose |
| --- | --- |
| Dive | `dive_id` is set |
| Site | `dive_id` is null and `site_id` is set |
| Equipment | `dive_id` and `site_id` are null and `equipment_id` is set |
| Unlinked | `dive_id`, `site_id` and `equipment_id` are all null |

### The filter

- Several choices can be picked at once; a row matches if it matches any
  picked choice. Picking none means no constraint (the default).
- It combines with every other filter with AND, as the others do. For
  example Site plus a Site filter of "Blue Hole" shows only Blue Hole's own
  site pictures (the existing site filter matches a row through its dive's
  site or its own site link, and the new facet then keeps only the latter).
- It applies in every view that reads the library filter: Grid, By dive,
  Timeline and Map.
- In the filter sheet it is a new **Attached to** section directly under
  **Type**, drawn as `FilterChip`s (Dive, Site, Equipment, Unlinked), like
  the Tags section. **Clear all** clears it.
- In the active filter strip above the grid it shows as one removable chip,
  "Attached to: Dive" (several picks joined with the locale's list
  separator, for example "Attached to: Site, Equipment"). Removing the chip
  clears the whole facet.
- It counts toward `isEmpty`, `==` and `hashCode`, and is kept by
  `copyWith`.

### Smart albums

- The facet is serialized as `attachedTo`, a sorted list of choice names
  (`dive`, `site`, `equipment`, `unlinked`), and left out of the JSON when
  empty, so every album saved before this keeps exactly the JSON it had.
- Decoding is lenient, like the other fields: unknown names are dropped,
  and a non-list value decodes to no constraint.
- An album saved before August 2026 with the retired `"health":
  "unlinked"` value keeps decoding to no constraint, as it has since that
  value was removed (3e3c51bdf76). It is not mapped to the new Unlinked
  choice: those albums have shown everything for months, and silently
  narrowing them now would change what an existing album shows (decided
  by the maintainer). A test pins this.
- A build that predates the facet ignores the key, so an album saved with
  only this facet opens there unfiltered. That is the accepted cost; the
  same is true of every facet added since albums shipped.
- The agent access (MCP) smart album read and write go through `toJson`
  and `fromJson` (the album document's `_albumFilter` copies every
  `toJson` key), so the facet reaches them with no change there; a test
  pins it.

### By dive section headings

- The By dive list draws a section heading above the first group of each
  kind after the dives:
  - **Site pictures** above the first site group,
  - **Equipment pictures** above the first equipment group,
  - **Unlinked** above the Unlinked group, which replaces that group's own
    plain header (it was already the single, pinned last group).
- A section heading looks different from the group headers under it, as
  in the approved mockup: accent-coloured text with a leading icon and a
  thin accent rule beneath, so "Site pictures" cannot be mistaken for the
  "Blue Hole" group header right below it. (Builder's call, from the
  mockup: a new `MediaGroupHeaderKind` for sections, measured by
  `MediaGroupHeaderMeasurer` like the others.)
- Dive groups get no heading; they come first.
- A heading is drawn by comparing each group's kind with the previous
  group's, so it appears once per section, also as later pages load more
  of a section. The SQL order (dive, site, equipment, unlinked since #4305)
  keeps each kind in one run.
- With the filter set to Site only, the list starts with the Site pictures
  heading. With Dive only, no heading appears.

### Text

- New strings go through the ARB files with translations in every locale
  (ar, de, en, es, fr, he, hu, it, nl, pt, zh): the section title, the four
  choice labels, the chip prefix, and the two new headings. The existing
  Unlinked label is reused for its heading.

## Constraints

- No schema change, no migration, no sync change: albums store the filter
  as JSON already.
- The SQL clause is built in `MediaLibraryRepository` alongside the other
  facets, with no new join (it reads only the media row's own columns).
- Files stay under the 800-line guard; the filter sheet is at 586 lines.

## Left to the builder

- Widget structure for the heading (a new small widget or an extension of
  `MediaGroupHeader`), within the section style above.
- The exact icon on each heading.
- The enum's name and where it lives (next to `MediaHealthFilter` in
  `media_library_filter.dart` is the natural place).
