# Buddy Professional Roles Fold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the `buddy_roles` table and derive buddy professional status (instructor/divemaster/dive guide) from buddy-owned `certifications` rows, migrating existing credential rows into certifications.

**Architecture:** UI layers are rewired to certifications first (while the table still exists, so every commit compiles), then the data layer is deleted, then one coupled commit performs the v147 migration + Drift table removal + sync deregistration. Spec: `docs/superpowers/specs/2026-08-08-buddy-professional-roles-fold-design.md`.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_test.

## Global Constraints

- All commands run from the worktree root: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/buddy-roles-fold`. Never touch the main checkout.
- `dart format lib/ test/` must produce no diff before every commit.
- `flutter analyze` (whole project) must be clean — infos are fatal in CI.
- TDD: write/adjust the test first where a behavior changes; deletions delete their tests in the same commit.
- Commit messages: plain summary line, NO Co-Authored-By line, NO session URL.
- Scoped `flutter test <dir>` per task (widget/DB tests can be slow; use generous `--timeout 120s` if needed); the full suite runs once in Task 9.
- l10n: any .arb change applies to ALL 11 locale files (`app_en.arb, app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`); non-English text is translated, not copied English. Regenerate with `flutter gen-l10n` run from the worktree root.
- Schema version: originally claimed **v145** (main was at 144 on 2026-08-08); renumbered to **v147** during merge-conflict resolution on 2026-08-09 after PR #908 reserved 145 and v146 landed on main first.

---

### Task 1: Domain — `diveGuide` level + `isInstructorLevel`

**Files:**
- Modify: `lib/core/constants/enums.dart` (CertificationLevel enum, lines ~166-222)
- Modify: `lib/core/constants/certification_levels.dart` (`_genericLadder`, `_ssiLadder`, `_nauiSdiLadder`, `_raidLadder`)
- Test: `test/core/constants/certification_level_instructor_test.dart` (new)

**Interfaces:**
- Produces: `CertificationLevel.diveGuide` enum value; `bool get isInstructorLevel` on `CertificationLevel`. Later tasks call `cert.level?.isInstructorLevel ?? false`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('isInstructorLevel is true for exactly the instructor grades', () {
    const instructorLevels = {
      CertificationLevel.instructor,
      CertificationLevel.masterInstructor,
      CertificationLevel.courseDirector,
      CertificationLevel.cmas1StarInstructor,
      CertificationLevel.cmas2StarInstructor,
      CertificationLevel.cmas3StarInstructor,
      CertificationLevel.bsacOpenWaterInstructor,
      CertificationLevel.bsacAdvancedInstructor,
      CertificationLevel.bsacNationalInstructor,
    };
    for (final level in CertificationLevel.values) {
      expect(
        level.isInstructorLevel,
        instructorLevels.contains(level),
        reason: '${level.name} isInstructorLevel mismatch',
      );
    }
    // Assistant instructors cannot independently certify.
    expect(CertificationLevel.assistantInstructor.isInstructorLevel, isFalse);
    expect(
      CertificationLevel.cmas3StarDiverAssistantInstructor.isInstructorLevel,
      isFalse,
    );
  });

  test('diveGuide sits directly below diveMaster on every ladder that has '
      'diveMaster', () {
    for (final agency in [
      CertificationAgency.padi, // generic ladder
      CertificationAgency.ssi,
      CertificationAgency.naui,
      CertificationAgency.sdi,
      CertificationAgency.raid,
      null, // generic fallback
    ]) {
      final ladder = CertificationLevelCatalog.ladderFor(agency);
      final guideIdx = ladder.indexOf(CertificationLevel.diveGuide);
      final dmIdx = ladder.indexOf(CertificationLevel.diveMaster);
      expect(dmIdx, greaterThan(-1));
      expect(guideIdx, dmIdx - 1,
          reason: 'diveGuide must rank immediately below diveMaster '
              'for agency $agency');
    }
    // Ladders without diveMaster must NOT gain diveGuide.
    expect(
      CertificationLevelCatalog.ladderFor(CertificationAgency.gue),
      isNot(contains(CertificationLevel.diveGuide)),
    );
    expect(
      CertificationLevelCatalog.ladderFor(CertificationAgency.bsac),
      isNot(contains(CertificationLevel.diveGuide)),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/certification_level_instructor_test.dart`
Expected: FAIL — `diveGuide` / `isInstructorLevel` undefined.

- [ ] **Step 3: Implement**

In `enums.dart`, insert into `CertificationLevel` immediately before `diveMaster('Divemaster'),`:

```dart
  diveGuide('Dive Guide'),
```

At the bottom of the enum (after the `displayName` field/const constructor), add:

```dart
  /// Grades that can independently certify students — drives the
  /// instructor picker (spec 2026-08-08 buddy-professional-roles-fold).
  /// Assistant-instructor grades are deliberately excluded.
  bool get isInstructorLevel => switch (this) {
    CertificationLevel.instructor ||
    CertificationLevel.masterInstructor ||
    CertificationLevel.courseDirector ||
    CertificationLevel.cmas1StarInstructor ||
    CertificationLevel.cmas2StarInstructor ||
    CertificationLevel.cmas3StarInstructor ||
    CertificationLevel.bsacOpenWaterInstructor ||
    CertificationLevel.bsacAdvancedInstructor ||
    CertificationLevel.bsacNationalInstructor => true,
    _ => false,
  };
```

In `certification_levels.dart`, insert `CertificationLevel.diveGuide,` immediately before `CertificationLevel.diveMaster,` in `_genericLadder`, `_ssiLadder`, `_nauiSdiLadder`, and `_raidLadder` (the four ladders containing diveMaster). Do NOT touch `specialties`, `_techLadder`, `_gueLadder`, `_bsacLadder`, `_cmasLadder`.

- [ ] **Step 4: Check for exhaustive switches and level l10n**

Run: `grep -rn "enum_certificationLevel" lib/l10n/arb/app_en.arb`
- If keys exist: add `enum_certificationLevel_diveGuide` ("Dive Guide", translated) to ALL 11 .arb files and run `flutter gen-l10n`.
- If no keys: levels display via `displayName`; nothing to add.

Run: `flutter analyze`
Expected: clean. Any non-exhaustive-switch error over `CertificationLevel` must be fixed by adding a `diveGuide` case consistent with the surrounding cases (report what you found in the commit body).

- [ ] **Step 5: Run tests, then existing catalog/primary-cert tests**

Run: `flutter test test/core/constants/ test/features/certifications/`
Expected: PASS (primaryCertification tests must not regress — diveGuide ranks below diveMaster by ladder index).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add diveGuide certification level and isInstructorLevel helper"
```

---

### Task 2: `allBuddyCertificationsProvider`

**Files:**
- Modify: `lib/features/certifications/presentation/providers/certification_providers.dart`
- Test: `test/features/certifications/presentation/providers/all_buddy_certifications_provider_test.dart` (new)

**Interfaces:**
- Consumes: `CertificationRepository.getCertificationsForBuddies(List<String>)` → `Future<Map<String, List<Certification>>>` (exists, `certification_repository.dart:112`); `allBuddiesProvider` (buddy_providers.dart); `invalidateSelfWhen` extension; `repository.watchCertificationsChanges()`.
- Produces: `final allBuddyCertificationsProvider = FutureProvider<Map<String, List<Certification>>>` — Tasks 3 and 5 watch it and tests override it.

- [ ] **Step 1: Write the failing test**

Model on `test/features/buddies/data/repositories/buddy_role_repository_test.dart`'s provider read-through group (uses `setUpTestDatabase()` from `test/helpers/test_database.dart`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('allBuddyCertificationsProvider maps buddy ids to their certs', () async {
    final now = DateTime.now();
    final buddy = await BuddyRepository().createBuddy(Buddy(
      id: '', name: 'Alice', createdAt: now, updatedAt: now));
    await CertificationRepository().createCertification(Certification(
      id: '',
      buddyId: buddy.id,
      name: 'Instructor',
      agency: CertificationAgency.padi,
      level: CertificationLevel.instructor,
      cardNumber: '12345',
      createdAt: now,
      updatedAt: now,
    ));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final map = await container.read(allBuddyCertificationsProvider.future);
    expect(map[buddy.id], hasLength(1));
    expect(map[buddy.id]!.single.level, CertificationLevel.instructor);
  });
}
```

(If `createBuddy` has a different signature, mirror how `buddy_role_repository_test.dart` created buddies before deletion — read that file first.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/presentation/providers/all_buddy_certifications_provider_test.dart`
Expected: FAIL — provider undefined.

- [ ] **Step 3: Implement**

In `certification_providers.dart`, next to `buddyCertificationsProvider` (line ~42), following its exact idiom (imports for `allBuddiesProvider` may need adding):

```dart
/// Certifications for every buddy, keyed by buddy id — the picker-annotation
/// replacement for the removed allBuddyRolesProvider. Single batched query
/// (no N+1); self-invalidates on any certifications change (local or sync).
final allBuddyCertificationsProvider =
    FutureProvider<Map<String, List<Certification>>>((ref) async {
      final repository = ref.watch(certificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchCertificationsChanges());
      final buddies = await ref.watch(allBuddiesProvider.future);
      return repository.getCertificationsForBuddies(
        buddies.map((b) => b.id).toList(),
      );
    });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/certifications/presentation/providers/all_buddy_certifications_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add allBuddyCertificationsProvider for batch buddy cert lookup"
```

---

### Task 3: Rewrite `InstructorPickerField` to derive from certifications

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/instructor_picker_field.dart` (full rewrite of internals)
- Modify: `lib/features/courses/presentation/pages/course_edit_page.dart:215-231`
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart:554-572`
- Test: rewrite `test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
- Test: update `test/features/courses/presentation/pages/course_edit_instructor_test.dart`, `test/features/certifications/presentation/pages/certification_edit_instructor_test.dart`, `test/features/certifications/presentation/pages/certification_name_auto_generation_test.dart:389-408`

**Interfaces:**
- Consumes: `allBuddyCertificationsProvider` (Task 2), `CertificationLevel.isInstructorLevel` (Task 1), `primaryCertification(List<Certification>)` from `package:submersion/features/certifications/domain/certification_primary.dart`.
- Produces: `InstructorPickerField({required String? instructorId, required void Function(Buddy? buddy, Certification? instructorCert) onSelected})`. Consumers read `instructorCert?.cardNumber`.

- [ ] **Step 1: Rewrite the widget test first**

Keep the four existing behaviors, re-expressed with certs. Preserve the existing file's `testApp` harness and `allBuddiesProvider` override; replace the `allBuddyRolesProvider` override with `allBuddyCertificationsProvider`:

```dart
final instructorCert = Certification(
  id: 'cert-1',
  buddyId: 'buddy-1',
  name: 'Instructor',
  agency: CertificationAgency.padi,
  level: CertificationLevel.instructor,
  cardNumber: '12345',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);
// overrides:
allBuddyCertificationsProvider.overrideWith(
  (ref) async => {'buddy-1': [instructorCert]},
),
```

Tests:
1. `instructor-level buddies listed first with cert annotation` — expect the dropdown item text `'Alice Instructor (PADI Instructor #12345)'` and that Alice appears before the un-certified buddy.
2. `Master Instructor qualifies` — a buddy whose only cert is `CertificationLevel.masterInstructor` is grouped first (this is the behavior gap the fold fixes).
3. `selecting an instructor-level buddy fires onSelected(buddy, cert)` — assert the callback receives the exact `Certification` (`cardNumber == '12345'`).
4. `selecting a non-instructor buddy fires onSelected(buddy, null)`; `None fires onSelected(null, null)`.
5. `divemaster-only buddy is NOT grouped first` (picker rule: instructor-level only).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
Expected: FAIL (compile error — new signature not implemented yet).

- [ ] **Step 3: Rewrite the widget**

Replace the credential lookup with (keeping the dropdown structure, `ValueKey(validValue)`, l10n labels `buddies_instructorPicker_label`/`_none` untouched):

```dart
class InstructorPickerField extends ConsumerWidget {
  final String? instructorId;
  final void Function(Buddy? buddy, Certification? instructorCert) onSelected;
  ...
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(allBuddiesProvider);
    final certsAsync = ref.watch(allBuddyCertificationsProvider);
    final buddies = buddiesAsync.value ?? const <Buddy>[];
    final certsByBuddy =
        certsAsync.value ?? const <String, List<Certification>>{};
    if (buddies.isEmpty) return const SizedBox.shrink();

    Certification? instructorCert(String buddyId) {
      final qualifying = (certsByBuddy[buddyId] ?? const <Certification>[])
          .where((c) => c.level?.isInstructorLevel ?? false)
          .toList();
      return primaryCertification(qualifying);
    }
    ...
  }
}

/// "PADI Instructor #12345" — agency, level, and card number when present.
String _instructorCertLabel(Certification cert) {
  final number = cert.cardNumber;
  return [
    cert.agency.displayName,
    cert.level!.displayName,
    if (number != null && number.isNotEmpty) '#$number',
  ].join(' ');
}
```

The grouped-first partition, dropdown items, and `onChanged` mirror the old file with `credential` → `cert` and label `'${buddy.name} (${_instructorCertLabel(cert)})'`.

- [ ] **Step 4: Update the two consumers**

Both callbacks change only the parameter name/type and the number source. `course_edit_page.dart:217`:

```dart
onSelected: (buddy, instructorCert) {
  setState(() {
    _instructorId = buddy?.id;
    if (buddy != null) {
      // Snapshot the picked buddy fully: overwrite both name and
      // number so switching to a buddy without a card number clears
      // a stale one rather than leaving the previous value behind.
      _instructorNameController.text = buddy.name;
      _instructorNumberController.text = instructorCert?.cardNumber ?? '';
    }
  });
},
```

`certification_edit_page.dart:556` identically (keeping its `_hasChanges = true;` and the "Clearing to None keeps the text fields untouched." comment).

- [ ] **Step 5: Update consumer tests**

In `course_edit_instructor_test.dart`, `certification_edit_instructor_test.dart`: replace `BuddyRoleCredential` fixtures + `allBuddyRolesProvider` overrides with `Certification` fixtures + `allBuddyCertificationsProvider` overrides (instructor cert with `cardNumber` for the credentialed buddy). Keep every behavioral assertion (fills name+number, switching clears number, saving persists instructorId, pre-select on load). In `certification_name_auto_generation_test.dart:389-408`: replace the override the same way (or drop the override if the test passes without it).

- [ ] **Step 6: Run the affected tests**

Run: `flutter test test/features/buddies/presentation/widgets/instructor_picker_field_test.dart test/features/courses/presentation/pages/course_edit_instructor_test.dart test/features/certifications/presentation/pages/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Derive instructor picker from buddy certifications"
```

---

### Task 4: BuddyPicker — drop credential plumbing, derive role-sheet hints from certs

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- Test: rewrite `test/features/buddies/presentation/widgets/buddy_picker_roles_test.dart`

**Interfaces:**
- Consumes: `allBuddyCertificationsProvider` (Task 2), `isInstructorLevel` (Task 1), `DiveRole.instructorId` / `diveMasterId` / `diveGuideId` string constants (`dive_role.dart:24-44`).
- Produces: no API change — `BuddyPicker` public surface is unchanged.

- [ ] **Step 1: Rewrite the test first**

In `buddy_picker_roles_test.dart` replace `allBuddyRolesProvider` overrides (lines 78/108/155) with `allBuddyCertificationsProvider` overrides:
1. `subtitle shows the primary cert level only` — buddy with an instructor cert shows subtitle `'Instructor'` once (via `buddy.certificationLevel`, already cert-derived by `_withPrimaryCerts`), with NO ` | ` doubled label. Note: the subtitle comes from the hydrated `Buddy`, so the fixture buddy passed to `allBuddiesProvider` must carry `certificationLevel: CertificationLevel.instructor`.
2. `role sheet lists Instructor first with a credential icon for a buddy holding an instructor cert` (mirror old test at :96, fixture = cert not credential).
3. `role sheet keeps default order for a buddy with no professional certs` (mirror old :145).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_picker_roles_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `buddy_picker.dart`:
- Replace the watch at lines 333-335 with `final certsByBuddy = ref.watch(allBuddyCertificationsProvider).value ?? const <String, List<Certification>>{};` and thread it through `_buildBuddyListView` in place of `rolesByBuddy` (lines 469-473, 482-486, 505).
- Subtitle (lines 539-547) collapses to the cert level only:

```dart
subtitle: buddy.certificationLevel == null
    ? null
    : Text(buddy.certificationLevel!.displayName),
```

- `_showRoleSelectorForBuddy` (lines 602-618): change the third parameter to `List<Certification> certs` and derive the hint set:

```dart
/// Dive-role ids this buddy plausibly acts as professionally, derived from
/// their certification levels; floats those roles to the top of the sheet
/// and badges them (replaces the buddy_roles credential lookup).
Set<String> _professionalRoleIds(List<Certification> certs) {
  final ids = <String>{};
  for (final cert in certs) {
    final level = cert.level;
    if (level == null) continue;
    if (level.isInstructorLevel) ids.add(DiveRole.instructorId);
    if (level == CertificationLevel.diveMaster) ids.add(DiveRole.diveMasterId);
    if (level == CertificationLevel.diveGuide) ids.add(DiveRole.diveGuideId);
  }
  return ids;
}
```

and pass `credentialRoleIds: _professionalRoleIds(certs)` to `showDiveRoleSelector` (the sheet's API is untouched; `dive_role_selector_sheet_test.dart` stays as-is).
- Remove the now-unused `BuddyRoleCredential` import.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/buddies/presentation/widgets/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Drive buddy picker role hints from certifications"
```

---

### Task 5: Remove the professional-roles UI (edit page, detail page, merge controller)

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart`
- Delete: `test/features/buddies/presentation/pages/buddy_edit_roles_test.dart`, `test/features/buddies/presentation/pages/buddy_detail_roles_test.dart`, `test/features/buddies/presentation/widgets/buddy_roles_editor_test.dart`
- Modify: `test/features/buddies/presentation/pages/buddy_merge_form_controller_test.dart` (delete the `mergeRoleCredentials` group at :24)

**Interfaces:**
- Consumes: nothing new.
- Produces: buddy edit/detail pages with no professional-roles surface. `BuddyRolesEditor` and `mergeRoleCredentials` have zero callers after this task (deleted in Task 6).

- [ ] **Step 1: buddy_edit_page.dart**

Remove, per the seam map:
- imports of `buddy_role_credential.dart` (line 11) and `buddy_roles_editor.dart` (line 15)
- fields `_roles` (line 71) and `_mergeRolesSeeded` (lines 73-76) and the stale "name/notes/roles" wording in the comment at line 66
- the roles fetch in `_loadBuddy()` (lines 133-135 and the `_roles = roles;` at 147)
- `_loadMergeRoles()` (lines 167-196) and its `initState` call (line 103), plus the `mergeRoleCredentials(...)` call site (line 182)
- the render block (lines 507-523: header text + `BuddyRolesEditor` + spacing)
- the merge-branch persist block (lines 784-793) and the normal-branch `setRolesForBuddy` call (lines 813-815)

- [ ] **Step 2: buddy_detail_page.dart**

Delete `_buildRolesSection` (lines 521-557), its call site in the build tree, and the now-unused `buddyRolesProvider` / `BuddyRoleCredential` imports.

- [ ] **Step 3: buddy_merge_form_controller.dart**

Delete `mergeRoleCredentials` (lines 7-26) and the imports it used (lines 3 and 5) if nothing else in the file needs them.

- [ ] **Step 4: Delete/trim tests**

```bash
git rm test/features/buddies/presentation/pages/buddy_edit_roles_test.dart \
       test/features/buddies/presentation/pages/buddy_detail_roles_test.dart \
       test/features/buddies/presentation/widgets/buddy_roles_editor_test.dart
```

In `buddy_merge_form_controller_test.dart`: remove the `mergeRoleCredentials` group and any `BuddyRoleCredential`/`BuddyRole` imports.

- [ ] **Step 5: Verify**

Run: `flutter analyze && flutter test test/features/buddies/`
Expected: clean analyze; buddy tests pass (remaining buddy edit/detail/merge tests unaffected).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Remove professional-roles UI from buddy pages"
```

---

### Task 6: Delete the buddy-roles data layer and merge plumbing

**Files:**
- Delete: `lib/features/buddies/data/repositories/buddy_role_repository.dart`, `lib/features/buddies/domain/entities/buddy_role_credential.dart`, `lib/features/buddies/presentation/widgets/buddy_roles_editor.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (delegations lines 76-99, imports :13-:14, `BuddyRoleSnapshot` in the export block :21-27)
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart`
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart` (remove `buddyRolesProvider` and `allBuddyRolesProvider`, lines 144-162)
- Delete: `test/features/buddies/data/repositories/buddy_role_repository_test.dart`, `test/features/buddies/domain/entities/buddy_role_credential_test.dart`
- Modify: `test/features/buddies/data/repositories/buddy_merge_test.dart` (remove buddy_roles assertions at :276, :347, :359, :561, :575, :585)

**Interfaces:**
- Consumes: nothing.
- Produces: no `BuddyRole*` symbol outside `enums.dart` remains in `lib/`. The `buddy_roles` Drift table still exists (dropped in Task 7) but has zero readers/writers outside migration code.

- [ ] **Step 1: Delete the three lib files and the two test files**

```bash
git rm lib/features/buddies/data/repositories/buddy_role_repository.dart \
       lib/features/buddies/domain/entities/buddy_role_credential.dart \
       lib/features/buddies/presentation/widgets/buddy_roles_editor.dart \
       test/features/buddies/data/repositories/buddy_role_repository_test.dart \
       test/features/buddies/domain/entities/buddy_role_credential_test.dart
```

- [ ] **Step 2: buddy_repository.dart**

Remove the four delegation methods (`watchBuddyRolesChanges`, `getRolesForBuddy`, `getAllRoles`, `setRolesForBuddy`, lines 76-99), the two imports (:13, :14), and `BuddyRoleSnapshot` from the `show` list of the merge-repository export (:21-27). Keep `unanimousBuddyRolesForDives` (lines 47-66) — it reads the `dive_buddies` junction (per-dive roles), not buddy_roles.

- [ ] **Step 3: buddy_merge_repository.dart**

Remove:
- `BuddyRoleSnapshot` class (lines 28-48)
- `deletedBuddyRoles` field + ctor param in `BuddyMergeSnapshot` (lines 79, 88)
- local accumulator (:219), the credential move/union block (:328-378), result assembly entry (:479)
- undo restore step 5 (:571-595); renumber the following step's comment (`// 6.` → `// 5.`) or adjust numbering consistently
Keep `_roleRank` (:112-119) — it ranks `dive_buddies` role strings.

- [ ] **Step 4: buddy_providers.dart**

Remove `buddyRolesProvider` and `allBuddyRolesProvider` (lines 144-162) and the `BuddyRoleCredential` import.

- [ ] **Step 5: buddy_merge_test.dart**

Remove the buddy_roles seeding/assertions at the six listed sites; the surviving merge tests (dive_buddies relink, cert instructor repoint, owner-cert union, undo) must still pass unchanged.

- [ ] **Step 6: Verify**

Run: `flutter analyze && flutter test test/features/buddies/`
Expected: clean; merge tests green.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Delete buddy_roles data layer and merge plumbing"
```

---

### Task 7: Migration v147 — convert rows, drop table, deregister from sync

This task is compile-coupled (serializer references `_db.buddyRoles`): migration helper, Drift table removal, codegen, and sync deregistration land in ONE commit.

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/data/repositories/sync_repository.dart:34`
- Modify: `lib/core/services/sync/sync_service.dart:1068,1811,1927`
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (all sites: 233, 307, 382, 458, 698, 1202-1205, 1615-1619, 1981-1985, 2309-2314, 2907-2913, 3482-3483, 3716-3717, 3983-3986, 4496-4503)
- Test: `test/core/database/migration_v147_fold_buddy_roles_test.dart` (new)
- Test: rewrite `test/core/database/migration_v99_buddy_roles_test.dart` → keep ONLY its `certifications.instructor_id` assertions (rename file to `migration_v99_instructor_id_test.dart`)
- Delete: `test/core/services/sync/sync_buddy_roles_test.dart`
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart:23`, `test/core/services/sync/sync_serializer_upsert_test.dart:102`
- Modify (comments only): `test/core/services/sync/sync_media_stores_test.dart:15`, `test/core/services/sync/sync_media_enrichment_test.dart:17`

**Interfaces:**
- Consumes: `CertificationLevel.diveGuide` (Task 1) as the `'diveGuide'` level string.
- Produces: schema v147; no `buddyRoles`/`buddy_roles` reference anywhere in `lib/` after this task.

- [ ] **Step 1: Re-verify the version number**

Run: `grep -n "currentSchemaVersion = " lib/core/database/database.dart`
Expected: `144`. If not, renumber v147 → next free version in every step below and in the spec.

- [ ] **Step 2: Write the failing migration test**

`test/core/database/migration_v147_fold_buddy_roles_test.dart`, modeled on `migration_v110_drop_buddy_cert_columns_test.dart` (seed an old-version DB by hand-written DDL with `PRAGMA user_version = 146`, construct `AppDatabase(nativeDb)` to run onUpgrade, assert). Seed `buddies` (`b1`,`b2`,`b3`), `certifications` (empty plus the dedupe fixtures below), and `buddy_roles`:

| fixture | buddy_roles row | pre-existing cert | expected outcome |
|---|---|---|---|
| plain convert | `('r1','b1','instructor','111','padi','note',1000,2000)` | none | cert `buddyrolecert-r1`: buddy_id b1, level `instructor`, agency `padi`, card `111`, name `Instructor`, notes `note`, created 1000, updated 2000 |
| dedupe skip | `('r2','b2','diveMaster','222','ssi','',...)` | `('c-dm','b2',...,'ssi','diveMaster', card '999')` | NO new row; `c-dm.card_number` stays `999` |
| dedupe backfill | `('r3','b2','instructor','333','ssi','',...)` | `('c-in','b2',...,'ssi','instructor', card NULL)` | NO new row; `c-in.card_number` backfilled to `333` |
| diveGuide + null agency | `('r4','b3','diveGuide',NULL,NULL,'',...)` | none | cert `buddyrolecert-r4`: level `diveGuide`, agency `other`, card NULL, name `Dive Guide` |
| unknown role | `('r5','b3','mermaid','444','padi','',...)` | none | no cert row created |

Assertions after open: the five outcomes; `SELECT name FROM sqlite_master WHERE name='buddy_roles'` is empty; converted rows have `diver_id IS NULL`; version-ladder pair:

```dart
test('version ladder includes 147', () {
  expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(147));
  expect(AppDatabase.migrationVersions, contains(147));
});
```

Plus the v144-style no-op shape: a fixture DB without a `buddy_roles` table (fresh higher-version DB) opens without error.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/database/migration_v147_fold_buddy_roles_test.dart`
Expected: FAIL (no v147 in ladder).

- [ ] **Step 4: Implement the migration in database.dart**

(a) `currentSchemaVersion` 146 → 147; append `147` to `migrationVersions`.

(b) Add the helper next to `_migrateBuddyInlineCertifications` (line ~3994), same doc style:

```dart
  /// Fold buddy professional credentials (buddy_roles, issue #395) into
  /// buddy-owned certifications rows, then drop the table (v147; spec
  /// 2026-08-08-buddy-professional-roles-fold). Invoked from onUpgrade ONLY,
  /// never beforeOpen -- re-running on every open would resurrect
  /// user-deleted certs. Ids are deterministic (`buddyrolecert-<rowId>`):
  /// synced replicas share buddy_roles row ids, so independent per-device
  /// migrations converge on identical cert rows instead of duplicating.
  Future<void> _migrateBuddyRolesToCertifications() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='buddy_roles'",
    ).get();
    if (tables.isEmpty) return;

    const levelForRole = {
      'instructor': 'instructor',
      'diveMaster': 'diveMaster',
      'diveGuide': 'diveGuide',
    };
    const nameForRole = {
      'instructor': 'Instructor',
      'diveMaster': 'Divemaster',
      'diveGuide': 'Dive Guide',
    };

    // JOIN buddies so an orphaned credential row (FK-off test databases)
    // can never fail the certifications FK on insert.
    final rows = await customSelect(
      'SELECT br.id, br.buddy_id, br.role, br.credential_number, br.agency, '
      'br.notes, br.created_at, br.updated_at '
      'FROM buddy_roles br JOIN buddies b ON b.id = br.buddy_id',
    ).get();
    for (final r in rows) {
      final role = r.read<String>('role');
      final level = levelForRole[role];
      if (level == null) continue; // unknown role: feature is gone, drop it
      final buddyId = r.read<String>('buddy_id');
      final agency = r.read<String?>('agency') ?? 'other';
      final cardNumber = r.read<String?>('credential_number');

      final existing = await customSelect(
        'SELECT id, card_number FROM certifications '
        'WHERE buddy_id = ? AND agency = ? AND level = ?',
        variables: [
          Variable<String>(buddyId),
          Variable<String>(agency),
          Variable<String>(level),
        ],
      ).get();
      if (existing.isNotEmpty) {
        // Same fact already recorded as a certification. Backfill the card
        // number when the cert lacks one -- the common "entered both halves"
        // case -- otherwise leave the richer cert row alone.
        final target = existing.first;
        final existingNumber = target.read<String?>('card_number');
        if ((existingNumber == null || existingNumber.isEmpty) &&
            cardNumber != null &&
            cardNumber.isNotEmpty) {
          await customStatement(
            'UPDATE certifications SET card_number = ? WHERE id = ?',
            [cardNumber, target.read<String>('id')],
          );
        }
        continue;
      }

      await customStatement(
        'INSERT INTO certifications '
        '(id, buddy_id, diver_id, name, agency, level, card_number, notes, '
        'created_at, updated_at) '
        'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO NOTHING',
        [
          'buddyrolecert-${r.read<String>('id')}',
          buddyId,
          nameForRole[role]!,
          agency,
          level,
          cardNumber,
          r.read<String>('notes'),
          r.read<int>('created_at'),
          r.read<int>('updated_at'),
        ],
      );
    }
    await customStatement('DROP TABLE IF EXISTS buddy_roles');
  }
```

(c) onUpgrade block, after the `if (from < 144)` block, following house style:

```dart
        if (from < 147) {
          // Fold buddy professional credentials into certifications and drop
          // buddy_roles (spec 2026-08-08). Conversion + drop in one step; the
          // sqlite_master guard makes a fresh v147 db a no-op.
          await _migrateBuddyRolesToCertifications();
        }
        if (from < 147) await reportProgress();
```

(d) Remove the table: delete `class BuddyRoles` (lines 1753-1775), `BuddyRoles,` from `@DriftDatabase(tables: [...])` (:2881), `'buddy_roles'` from `_hlcTables` (:4263), `await m.createTable(buddyRoles);` in the v99 onUpgrade block (:7049), and `await createMigrator().createTable(buddyRoles);` in the beforeOpen backstop (:7613 — **mandatory**, or every open recreates the dropped table). Leave a one-line comment in the v99 block noting buddy_roles was created here historically and dropped in v147 (the version ladder must still make sense to readers).

**Amended during execution per review finding:** the plan text above said `_migrateBuddyRolesToCertifications` is invoked from `onUpgrade` ONLY, "never beforeOpen." A review finding overrode this: the helper's own `DROP TABLE` makes its `sqlite_master` guard a strict no-op once `buddy_roles` is gone, so (unlike #553's inline-cert copy) it CANNOT resurrect a user-deleted cert, and it must also run as a guarded `beforeOpen` backstop (v106-style) to protect a DB whose `user_version` advanced past 147 without running the v147 block. See the design spec's "Data migration" section for the amended rationale.

(e) Regenerate Drift code:

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Deregister from sync**

- `sync_repository.dart:34`: delete `'buddyRoles': (table: 'buddy_roles', pk: 'id'),` from `_hlcTargets` (**mandatory** — `_maxRowHlc()` builds a SQL UNION over every entry and fails at prepare time against a dropped table).
- `sync_service.dart`: delete the mergeOrder tuple (:1068), the `'buddyRoles': true,` entry in `entityHasUpdatedAt` (:1811), and the parentRefs entry (:1927).
- `sync_data_serializer.dart`: delete the `SyncData` field/ctor/toJson/fromJson lines (233, 307, 382, 458), the `_baseTables` entry (698), the `_buildSyncData` export (1202-1205) and `_exportBuddyRoles` (4496-4503), and the `case 'buddyRoles':` blocks in `fetchRecord` (1615), `fetchRecords` (1981), `upsertRecord` (2309), `upsertRecords` (2907), `recordIdsFor` (3482), `_syncTableFor` (3716), `deleteRecord` (3983).
- Do NOT add an inbound shim and do NOT touch `deletion_log` rows: legacy `buddyRoles` payload sections are silently dropped at `SyncData.fromJson`/`wantRows` (verified fail-soft); convergence happens when the old peer upgrades and runs the same deterministic migration. Legacy `deletion_log` rows with `entity_type='buddyRoles'` stay — they are inert here but still tell not-yet-upgraded peers to delete.

- [ ] **Step 6: Update sync/migration tests**

- `git rm test/core/services/sync/sync_buddy_roles_test.dart`
- `sync_parent_refs_completeness_test.dart:23`: delete `'buddy_roles': 'buddyRoles',`
- `sync_serializer_upsert_test.dart:102`: delete the `(type: 'buddyRoles', ...)` tuple
- `migration_v99_buddy_roles_test.dart`: rename to `migration_v99_instructor_id_test.dart` (`git mv`), keep only the `certifications.instructor_id` assertions (creation on upgrade + backstop heal), delete every buddy_roles table assertion; update the file's doc comment.
- Add to `migration_v147_fold_buddy_roles_test.dart` (or a small sibling sync test) the spec-required legacy-payload test:

```dart
test('legacy buddyRoles payload section is silently ignored', () {
  // Old-schema peers still publish buddyRoles arrays; SyncData.fromJson has
  // no such field anymore, so the section must drop without error.
  final data = SyncData.fromJson({
    'buddyRoles': [
      {'id': 'r1', 'buddyId': 'b1', 'role': 'instructor'},
    ],
  });
  expect(data.toJson().containsKey('buddyRoles'), isFalse);
});
```
- Fix the two stale comments citing buddy_roles as the "carries its own hlc" exemplar (`sync_media_stores_test.dart:15`, `sync_media_enrichment_test.dart:17`) — cite `certifications` instead.

- [ ] **Step 7: Run the affected suites**

Run: `flutter test test/core/database/ test/core/services/sync/`
Expected: PASS, including `sync_base_streaming_parity_test.dart` ("entityHasUpdatedAt covers exactly the SyncData entities" — passes because the key left BOTH sides) and `sync_data_serializer_record_ids_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "Migrate buddy_roles into certifications and drop the table (v147)"
```

---

### Task 8: Delete the BuddyRole enum + l10n cleanup

**Files:**
- Modify: `lib/core/constants/enums.dart` (delete `BuddyRole`, lines 102-113)
- Modify: `lib/core/database/database.dart:1994-1997` (DiveRoles table comment), `lib/features/dive_roles/domain/entities/dive_role.dart:4,55` (comments)
- Modify: all 11 `lib/l10n/arb/app_*.arb` files
- Modify: `test/features/buddies/presentation/providers/buddy_merge_providers_test.dart:307`

**Interfaces:**
- Consumes: nothing.
- Produces: `BuddyRole` no longer exists; `grep -rn "BuddyRole" lib/ test/` returns zero code hits.

- [ ] **Step 1: Fix the last fixture**

`buddy_merge_providers_test.dart:307`: `role: Value(BuddyRole.buddy.name)` → `role: Value(DiveRole.buddyId)` (import `dive_role.dart` if needed).

- [ ] **Step 2: Delete the enum and reword comments**

Delete `enum BuddyRole {...}` from `enums.dart`. Reword the three comments that referenced it to say "legacy per-dive role enum names" without naming the deleted symbol as if it still existed, e.g. in `database.dart:1994-1997`: "Built-in ids are the historical per-dive role names (buddy, diveGuide, instructor, student, diveMaster, solo) so existing dive_buddies.role strings resolve without data migration". Same spirit at `dive_role.dart:4` and `:55`.

- [ ] **Step 3: l10n cleanup**

- Remove from ALL 11 .arb files the 8 orphaned keys: `buddies_section_professionalRoles`, `buddies_roles_addRole`, `buddies_roles_role`, `buddies_roles_agency`, `buddies_roles_credentialNumber`, `buddies_roles_removeTooltip`, `buddies_roles_emptyHint`, `buddies_detail_section_professionalRoles`. KEEP `buddies_instructorPicker_label` / `buddies_instructorPicker_none`.
- `enum_buddyRole_*` keys (6 keys): run `grep -rn "enum_buddyRole" lib/ --include="*.dart" | grep -v l10n/arb` — if the only references are the generated localization files, remove all 6 keys from all 11 .arb files; if live code (e.g. dive-role display fallback) uses them, KEEP them and note it in the commit body.
- Run: `flutter gen-l10n` (from the worktree root — never the main checkout).

- [ ] **Step 4: Verify no stragglers**

Run: `grep -rn "BuddyRole\|buddy_roles\|buddyRoles" lib/ test/ --include="*.dart" | grep -v "unanimousBuddyRoles\|_buddyRoleById\|_existingBuddyRoleIds"`
Expected: zero hits (the three excluded names are dive_buddies per-dive role code that legitimately keeps "BuddyRole" in local identifiers; if desired rename them in a separate cleanup, NOT here).

- [ ] **Step 5: Analyze + affected tests**

Run: `flutter analyze && flutter test test/features/buddies/ test/features/dive_roles/`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Delete BuddyRole enum and orphaned professional-roles l10n keys"
```

---

### Task 9: Full verification

- [ ] **Step 1: Format**

Run: `dart format lib/ test/`
Expected: no files changed (fix and amend the relevant commit if any).

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` — run WITHOUT piping through head/grep (piping masks failures).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all green. Known flaky suites (backup, media upload/store, recovery-code, OCR) may need one retry — rerun the individual failing file before assuming this change broke it; only failures that reproduce in isolation count.

- [ ] **Step 4: Spec/plan sync check**

Confirm the spec's v147 claim still matches `currentSchemaVersion`; update the spec if Task 7 renumbered.

- [ ] **Step 5: Commit any residue and stop**

The branch is ready for PR (opened by the finishing workflow, not this plan).
