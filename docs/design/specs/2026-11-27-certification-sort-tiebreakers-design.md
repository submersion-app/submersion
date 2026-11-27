# Certification sort tiebreakers (issue #5070)

## Why

A diver who crossed over to SSI logged several certifications on one day.
The certification list sorts by date only, so those same-day rows come out in
no particular order and are hard to find. The issue asks for date, then
agency, then name.

Today `applyCertificationSorting` compares a single key per sort (Title, Date
Issued or Agency). Dart's `List.sort` is not stable, so tied rows land in an
arbitrary order that can change between rebuilds.

## Goals

- Every certification sort orders ties by the other two visible keys.
- The order is total and deterministic: identical-looking rows never swap
  between rebuilds.

## Non-goals

- Table mode's column-header sort (shared by every entity table) is unchanged.
- No new sort fields, settings or UI controls.
- The existing key comparisons (lowercased localized title, agency
  interchange name, undated as oldest) are unchanged.

## Approaches

1. **Comparator chain in `applyCertificationSorting` (chosen).** One place
   feeds the list, the wallet and the rows inside group-by sections.
2. **Order in the SQL query.** Rejected: the title the list shows is the
   localized title computed in Dart, which SQL cannot see.
3. **Make the sort stable over the repository order.** Rejected: that keeps
   the raw-name order of the query but never orders by agency, so it does not
   give what the issue asks for.

## Design

Each sort has a reading order, its default direction (newest first for date,
A to Z for text; both are `SortDirection.descending` in this code):

| Sort | Reading order |
| --- | --- |
| Date Issued | newest first, then agency A to Z, then title A to Z |
| Agency | A to Z, then newest first, then title A to Z |
| Title | A to Z, then agency A to Z, then newest first |

Every chain ends with the certification id as a last tiebreak.

Flipping the direction reverses the whole chain (decided: option B), so Date
oldest first gives agency Z to A, then title Z to A within each day.

The title key is the localized displayed title, now computed for every sort
since it is a tiebreaker for all three.

## Left to the builder

Test layout and helper structure inside `certification_sorting_test.dart`.
