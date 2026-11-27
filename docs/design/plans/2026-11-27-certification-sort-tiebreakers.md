# Certification Sort Tiebreakers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every certification sort orders ties by the other visible keys, in a total, deterministic order (issue #5070).

**Architecture:** `applyCertificationSorting` builds one comparator chain per sort field in reading order, ends it with the id, and negates the whole result for `SortDirection.ascending`. The list, the wallet and group-by sections already call it, so nothing else changes.

**Tech Stack:** Dart, flutter_test.

**Spec:** `docs/design/specs/2026-11-27-certification-sort-tiebreakers-design.md`

## Global Constraints

- Reading order is `SortDirection.descending` for all three fields (newest first; A to Z for text).
- Date Issued: date newest first, agency A to Z, title A to Z, id.
- Agency: agency A to Z, date newest first, title A to Z, id.
- Title: title A to Z, agency A to Z, date newest first, id.
- Ascending reverses the whole chain, tiebreakers included (option B).
- Key comparisons unchanged: lowercased `certificationTitleL10n`, agency `interchangeName`, null `issueDate` as `DateTime(1900)`.
- Table mode (`sortTableEntities`) is not touched.

## Review Focus

- Undated certifications tied with each other: fall through to agency and title, not left arbitrary.
- Custom-titled certs with a blank stored name: tiebreak on the displayed title, not the raw `name`.
- Two certifications identical on date, agency and title: order by id, stable across calls with shuffled input.
- Unknown or custom agency strings: compare by the catalog's `interchangeName` like the Agency sort.
- Ascending Date sort: agency and title come out Z to A within a day.

---

### Task 1: Tiebreaker chain in `applyCertificationSorting`

**Files:**
- Modify: `lib/features/certifications/presentation/providers/certification_providers.dart:135-187`
- Test: `test/features/certifications/presentation/providers/certification_sorting_test.dart`

**Interfaces:**
- Consumes: existing `applyCertificationSorting(List<Certification>, SortState<CertificationSortField>, {required AppLocalizations l10n, CertificationCatalog? catalog})`.
- Produces: same signature, new ordering.

- [ ] **Step 1: Write the failing tests** in a new `group('tiebreakers (#5070)')`, extending the `cert` helper with `agency` and `issueDate` parameters. Fixture (all `en`):
  - `padiAow`: PADI, AOW level, 2019-05-04
  - `ssiNitrox`: SSI, custom name "Nitrox", 2019-05-04
  - `ssiDeep`: SSI, custom name "Deep", 2019-05-04
  - `ssiOw`: SSI, OW level, 2018-01-01
  - `undatedA`, `undatedB`: SSI, custom names "Zeta" and "Alpha", no date
  - `twinX`, `twinY`: PADI, custom name "Twin", 2020-01-01 (identical but id)

  Tests (input passed shuffled, ids asserted):
  - `date newest first: same day by agency then title`: twinX, twinY, padiAow, ssiDeep, ssiNitrox, ssiOw, undatedB (Alpha), undatedA (Zeta).
  - `date oldest first reverses the whole chain`: the exact reverse of the above.
  - `agency A to Z: newest first then title`: PADI block twinX, twinY, padiAow; SSI block ssiDeep, ssiNitrox, ssiOw, Alpha, Zeta.
  - `title A to Z: agency then newest first` with two certs both titled "Nitrox" (PADI 2019, SSI 2020, SSI 2021): PADI first, then SSI 2021, then SSI 2020.
  - `identical rows order by id regardless of input order`: twinY then twinX in input still yields twinX before twinY.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/certifications/presentation/providers/certification_sorting_test.dart`
Expected: the new tiebreaker tests FAIL; existing title tests PASS.

- [ ] **Step 3: Implement the chain.** Compute `titles` for every sort (not only Title). Define three key comparators in reading order (`byDate` = newest first, `byAgency`, `byTitle`), pick the field's ordered list, fold until non-zero, then `a.id.compareTo(b.id)`; negate when `sort.direction == SortDirection.ascending`. Drop the `invertForText` branch, which the reading-order rule replaces.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/certifications/presentation/providers/certification_sorting_test.dart`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/certifications/presentation/providers/certification_providers.dart test/features/certifications/presentation/providers/certification_sorting_test.dart
flutter analyze
git add lib/features/certifications/presentation/providers/certification_providers.dart test/features/certifications/presentation/providers/certification_sorting_test.dart
git commit -m "feat(certifications): order certification sort ties by the other keys"
```
