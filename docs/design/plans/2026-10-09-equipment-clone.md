# Equipment Clone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver clone a piece of equipment from its detail page into a
pre-filled New Equipment form, and copy its service clocks, set memberships and
documents when the clone is saved.

**Architecture:** A pure `cloneFormSeed` builds the form's starting item from
the source. `EquipmentEditPage` gains a `cloneFromId` that seeds the form from
it and, after the normal `addEquipment` save, calls `EquipmentCloneService`,
which copies the extras step by step on a best-effort basis. The detail page
menu gains Clone, which pushes `/equipment/new?cloneFrom=<id>`.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), go_router, flutter gen-l10n.

**Spec:** `docs/design/specs/2026-10-09-equipment-clone-design.md` (issue #3184)

## Global Constraints

- The clone's name is `<source name> (copy)`, the suffix localized; serial
  number, O2 cell slot (`cell_slot`) and child install date (`installed_date`)
  start blank; legacy `lastServiceDate` / `serviceIntervalDays` are not copied.
- Service clocks copy kind, enabled, day/dive/hour intervals, exposure
  intervals, per-item cost and currency; never `anchorDate` / `anchorSetAt`.
  A clock of the same kind already on the clone (auto-attached) is updated,
  never duplicated.
- Copied media rows get a new id, `equipment_id` = clone, `dive_id` and
  `site_id` null, every file and store field carried over.
- Shared gear: Clone shows to every viewer. Sets copy only into the active
  diver's sets (all sets with no active diver); clocks of another diver's
  custom kind are skipped; tags pre-fill only when unowned or the active
  diver's; the first location pre-fills only when it is one of the active
  diver's places.
- Extras are best effort: each step caught on its own, failures logged and
  reported; the clone row is never rolled back.
- After save, `pushReplacement('/equipment/<cloneId>')` and an "Equipment
  cloned" snackbar; a partial-copy snackbar when any step failed.
- New strings translated in all 10 locale ARBs, inserted by anchor line, and
  `flutter gen-l10n` run LAST.
- No em dashes anywhere; no emojis; imports grouped dart, flutter, packages,
  local.

## Review Focus

1. A sharee clones shared gear: no set, tag, place or custom service kind of
   the owner's profile leaks onto the clone (Task 3 and Task 4 tests).
2. Cloning a regulator whose source has a customised auto-attach clock: the
   clone ends with exactly one clock of that kind, carrying the source's
   interval (Task 3 test).
3. Cloning an item whose documents are also attached to a dive: the dive does
   not gain a second copy of the photo (Task 3 test).
4. One extras step throwing does not skip the others and is reported
   (Task 3 test).
5. Tapping Save twice quickly or editing the tags before the source's tags
   load must not lose the user's tag edits (Task 4 guards `_selectedTags`
   with an is-empty check; covered by the existing `_isLoading` save guard).

---

## File Structure

- Create `lib/features/equipment/domain/services/equipment_clone_seed.dart`:
  pure `cloneFormSeed`.
- Create `lib/features/equipment/data/services/equipment_clone_service.dart`:
  `CloneExtrasStep`, `EquipmentCloneService`.
- Create `lib/features/equipment/presentation/providers/equipment_clone_providers.dart`:
  `equipmentCloneServiceProvider`.
- Modify `lib/features/equipment/data/repositories/equipment_set_repository_impl.dart`:
  add `getSetIdsContaining`.
- Modify `lib/features/equipment/presentation/pages/equipment_edit_page.dart`:
  clone mode.
- Modify `lib/core/router/app_router.dart`: `cloneFrom` query parameter.
- Modify `lib/features/equipment/presentation/pages/equipment_detail_page.dart`:
  Clone menu entry.
- Modify `lib/l10n/arb/app_*.arb` (11 files) and the generated
  `app_localizations*.dart`.
- Tests: `test/features/equipment/domain/services/equipment_clone_seed_test.dart`,
  `test/features/equipment/data/services/equipment_clone_service_test.dart`,
  `test/features/equipment/data/repositories/equipment_set_repository_items_test.dart`
  (extend), `test/features/equipment/presentation/pages/equipment_edit_clone_test.dart`,
  `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`
  (extend).

---

### Task 1: `cloneFormSeed`

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_clone_seed.dart`
- Test: `test/features/equipment/domain/services/equipment_clone_seed_test.dart`

**Interfaces:**
- Produces: `EquipmentItem cloneFormSeed(EquipmentItem source, {required String Function(String name) copyName})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_clone_seed.dart';

void main() {
  final source = EquipmentItem(
    id: 'src',
    diverId: 'owner',
    name: 'Cell A',
    type: EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    serialNumber: 'SN-1',
    status: EquipmentStatus.active,
    purchaseDate: DateTime(2026, 3, 1),
    purchasePrice: 120,
    purchaseCurrency: 'EUR',
    lastServiceDate: DateTime(2026, 4, 1),
    serviceIntervalDays: 365,
    notes: 'spare',
    attributes: const [
      EquipmentAttribute(key: EquipmentAttrKeys.cellSlot, valueNum: 2),
      EquipmentAttribute(key: EquipmentAttrKeys.installedDate, valueNum: 1),
      EquipmentAttribute(key: EquipmentAttrKeys.size, valueText: 'M'),
      EquipmentAttribute(key: 'Batch', valueText: 'B7', isCustom: true),
      EquipmentAttribute(
        key: EquipmentAttrKeys.cellSlot,
        valueText: 'kept',
        isCustom: true,
      ),
    ],
    customReminderEnabled: true,
    customReminderDays: const [7],
    parentEquipmentId: 'rebreather',
    createdAt: DateTime(2026, 3, 1),
  );

  final seed = cloneFormSeed(source, copyName: (n) => '$n (copy)');

  test('names the clone with the copy pattern', () {
    expect(seed.name, 'Cell A (copy)');
  });

  test('starts with no id, owner, serial, creation or legacy service', () {
    expect(seed.id, '');
    expect(seed.diverId, isNull);
    expect(seed.serialNumber, isNull);
    expect(seed.createdAt, isNull);
    expect(seed.lastServiceDate, isNull);
    expect(seed.serviceIntervalDays, isNull);
  });

  test('drops the cell slot and install date, keeps every other attribute', () {
    expect(
      [for (final a in seed.attributes) (a.key, a.isCustom)],
      [
        (EquipmentAttrKeys.size, false),
        ('Batch', true),
        (EquipmentAttrKeys.cellSlot, true),
      ],
    );
  });

  test('copies the rest of the form as-is', () {
    expect(seed.type, source.type);
    expect(seed.brand, source.brand);
    expect(seed.model, source.model);
    expect(seed.status, source.status);
    expect(seed.isActive, source.isActive);
    expect(seed.purchaseDate, source.purchaseDate);
    expect(seed.purchasePrice, source.purchasePrice);
    expect(seed.purchaseCurrency, source.purchaseCurrency);
    expect(seed.notes, source.notes);
    expect(seed.customReminderEnabled, isTrue);
    expect(seed.customReminderDays, [7]);
    expect(seed.parentEquipmentId, 'rebreather');
  });
}
```

Check the `EquipmentAttribute` constructor's field names
(`lib/features/equipment/domain/entities/equipment_attribute.dart`) before
running and adjust the literals to them; the assertions stay.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/services/equipment_clone_seed_test.dart`
Expected: FAIL, `equipment_clone_seed.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Curated attributes that place one physical item, so a clone starts
/// without them: two O2 cells must not claim one slot, and a clone counts
/// its parent's dives from its own creation, not the original's install.
const _perItemAttrKeys = {
  EquipmentAttrKeys.cellSlot,
  EquipmentAttrKeys.installedDate,
};

/// The item the Clone form starts from (issue #3184): [source] with no id,
/// owner or creation time (the save assigns them), the name from [copyName],
/// no serial number, none of the frozen legacy service fields, and without
/// the per-item attributes above. Everything else on the form is kept.
EquipmentItem cloneFormSeed(
  EquipmentItem source, {
  required String Function(String name) copyName,
}) {
  return EquipmentItem(
    id: '',
    name: copyName(source.name),
    type: source.type,
    brand: source.brand,
    model: source.model,
    status: source.status,
    purchaseDate: source.purchaseDate,
    purchasePrice: source.purchasePrice,
    purchaseCurrency: source.purchaseCurrency,
    notes: source.notes,
    isActive: source.isActive,
    attributes: [
      for (final a in source.attributes)
        if (a.isCustom || !_perItemAttrKeys.contains(a.key)) a,
    ],
    customReminderEnabled: source.customReminderEnabled,
    customReminderDays: source.customReminderDays,
    parentEquipmentId: source.parentEquipmentId,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/domain/services/equipment_clone_seed_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/domain/services/equipment_clone_seed.dart test/features/equipment/domain/services/equipment_clone_seed_test.dart
git commit -m "feat(equipment): seed a clone's form from its source"
```

---

### Task 2: Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 locale ARBs; regenerate
  `lib/l10n/arb/app_localizations*.dart`.

**Interfaces:**
- Produces: `l10n.equipment_menu_clone`, `l10n.equipment_edit_appBar_cloneTitle`,
  `l10n.equipment_clone_nameCopy(String name)`, `l10n.equipment_clone_snackbar_cloned`,
  `l10n.equipment_clone_partialCopy`.

- [ ] **Step 1: Pick each locale's nouns.** Grep each locale ARB for its
  existing words for service schedule, equipment set and document
  (`grep -n '"equipment_set\|"serviceSchedule\|"equipment_documents' lib/l10n/arb/app_de.arb`
  and the like) and use them in `equipment_clone_partialCopy` instead of the
  defaults in the table below when they differ.

- [ ] **Step 2: Insert the keys by anchor line.** In `app_en.arb`, insert in
  sorted position next to the `equipment_edit_appBar_*`, `equipment_menu_*`
  and nearby keys; in each locale ARB insert after `"equipment_menu_delete"`.
  Use a python3.14 script that builds each line as
  `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, never
  json-round-trips a file, and `json.loads` every file afterwards. English
  gets `@` metadata (description; `name` placeholder of type String for the
  copy pattern); locale files get none.

| key | en | ar | de | es | fr | he | hu | it | nl | pt | zh |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| equipment_menu_clone | Clone | استنساخ | Duplizieren | Clonar | Dupliquer | שכפול | Klónozás | Duplica | Klonen | Clonar | 克隆 |
| equipment_edit_appBar_cloneTitle | Clone Equipment | استنساخ المعدات | Ausrüstung duplizieren | Clonar equipo | Dupliquer l'équipement | שכפול ציוד | Felszerelés klónozása | Duplica attrezzatura | Uitrusting klonen | Clonar Equipamento | 克隆装备 |
| equipment_clone_nameCopy | {name} (copy) | {name} (نسخة) | {name} (Kopie) | {name} (copia) | {name} (copie) | {name} (עותק) | {name} (másolat) | {name} (copia) | {name} (kopie) | {name} (cópia) | {name}（副本） |
| equipment_clone_snackbar_cloned | Equipment cloned | تم استنساخ المعدات | Ausrüstung dupliziert | Equipo clonado | Équipement dupliqué | הציוד שוכפל | Felszerelés klónozva | Attrezzatura duplicata | Uitrusting gekloond | Equipamento clonado | 装备已克隆 |

`equipment_clone_partialCopy`:
- en: Cloned, but some service schedules, sets or documents could not be copied.
- ar: تم الاستنساخ، لكن تعذّر نسخ بعض جداول الصيانة أو المجموعات أو المستندات.
- de: Dupliziert, aber einige Wartungspläne, Sets oder Dokumente konnten nicht kopiert werden.
- es: Clonado, pero no se pudieron copiar algunos programas de servicio, conjuntos o documentos.
- fr: Dupliqué, mais certains plannings d'entretien, ensembles ou documents n'ont pas pu être copiés.
- he: שוכפל, אך לא ניתן היה להעתיק חלק מלוחות הזמנים לשירות, הערכות או המסמכים.
- hu: Klónozva, de néhány szervizütemezést, készletet vagy dokumentumot nem sikerült átmásolni.
- it: Duplicata, ma non è stato possibile copiare alcuni programmi di manutenzione, set o documenti.
- nl: Gekloond, maar sommige onderhoudsschema's, sets of documenten konden niet worden gekopieerd.
- pt: Clonado, mas não foi possível copiar alguns planos de manutenção, conjuntos ou documentos.
- zh: 已克隆，但部分保养计划、装备组或文档未能复制。

- [ ] **Step 3: Generate and verify.** Run `flutter gen-l10n`; then
  `git diff --numstat -- lib/l10n/arb/*.arb` shows +5/-0 for every locale
  file (English more for metadata), and
  `grep -A1 "get equipment_menu_clone" lib/l10n/arb/app_localizations_de.dart`
  shows `Duplizieren`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(equipment): strings for cloning equipment"
```

---

### Task 3: `EquipmentCloneService`

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_set_repository_impl.dart`
- Create: `lib/features/equipment/data/services/equipment_clone_service.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_clone_providers.dart`
- Test: `test/features/equipment/data/services/equipment_clone_service_test.dart`

**Interfaces:**
- Produces:
  - `Future<List<String>> EquipmentSetRepository.getSetIdsContaining(String equipmentId, {String? diverId})`
  - `enum CloneExtrasStep { serviceClocks, sets, documents }`
  - `EquipmentCloneService({ServiceScheduleRepository? schedules, ServiceKindRepository? kinds, EquipmentSetRepository? sets, MediaRepository? media})`
  - `Future<Set<CloneExtrasStep>> copyExtras({required String sourceId, required String cloneId, required EquipmentType cloneType, required String? diverId})` (`cloneType` added in code review: clocks whose kind does not apply to the clone's saved type are not copied; the test snippets below predate it)
  - `final equipmentCloneServiceProvider = Provider<EquipmentCloneService>`

- [ ] **Step 1: Write the failing tests**

Uses the real in-memory database (`setUpTestDatabase` /
`tearDownTestDatabase` from `test/helpers/test_database.dart`) and real
repositories, as `service_schedule_batch_test.dart` does. Seed divers, sets,
kinds and media with `customStatement` inserts after reading each table's
required columns in `lib/core/database/tables/`.

```dart
void main() {
  late EquipmentRepository equipment;
  late ServiceScheduleRepository schedules;
  late EquipmentSetRepository sets;
  late MediaRepository media;
  late EquipmentCloneService service;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    schedules = ServiceScheduleRepository();
    sets = EquipmentSetRepository();
    media = MediaRepository();
    service = EquipmentCloneService();
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> make(String name, EquipmentType type, {String? diverId}) =>
      equipment.createEquipment(
        EquipmentItem(id: '', name: name, type: type, diverId: diverId),
      );

  group('service clocks', () {
    test('a customised auto-attached clock merges into the clone\'s one', () async {
      final source = await make('Reg A', EquipmentType.regulator);
      final sourceClock = (await schedules.getSchedulesForEquipment(source.id)).single;
      await schedules.updateSchedule(sourceClock.copyWith(
        intervalDays: 400,
        intervalDives: 150,
        defaultCost: 90,
        defaultCurrency: 'EUR',
        anchorDate: DateTime(2026, 1, 5),
        anchorSetAt: DateTime(2026, 1, 6),
      ));
      final clone = await make('Reg A (copy)', EquipmentType.regulator);

      expect(
        await service.copyExtras(sourceId: source.id, cloneId: clone.id, diverId: null),
        isEmpty,
      );

      final cloneClocks = await schedules.getSchedulesForEquipment(clone.id);
      expect(cloneClocks, hasLength(1));
      final c = cloneClocks.single;
      expect(c.serviceKindId, sourceClock.serviceKindId);
      expect((c.intervalDays, c.intervalDives, c.defaultCost, c.defaultCurrency),
          (400, 150, 90.0, 'EUR'));
      expect(c.anchorDate, isNull);
      expect(c.anchorSetAt, isNull);
    });

    test('a manually added clock is created on the clone', () async {
      // Fins auto-attach nothing; add a built-in kind's clock by hand.
      final source = await make('Fins', EquipmentType.fins);
      final kindId = (await ServiceKindRepository().getAllKinds()).first.id;
      await schedules.createSchedule(ServiceSchedule(
        id: '', equipmentId: source.id, serviceKindId: kindId,
        intervalDays: 30, enabled: false,
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ));
      final clone = await make('Fins (copy)', EquipmentType.fins);

      await service.copyExtras(sourceId: source.id, cloneId: clone.id, diverId: null);

      final c = (await schedules.getSchedulesForEquipment(clone.id)).single;
      expect((c.serviceKindId, c.intervalDays, c.enabled), (kindId, 30, false));
    });

    test('another diver\'s custom kind is not copied', () async {
      // Insert divers 'owner' and 'sharee', and a custom kind owned by
      // 'owner' (service_kinds row with diver_id = 'owner', is_built_in = 0,
      // auto_attach = 0) via customStatement; give the source a clock of it.
      // copyExtras(diverId: 'sharee') leaves the clone with no clock of
      // that kind; copyExtras(diverId: 'owner') on a second clone copies it.
    });
  });

  group('sets', () {
    test('joins the active diver\'s sets that hold the source, only those', () async {
      // Divers 'owner' and 'sharee'; sets s-own (diver 'sharee') and
      // s-other (diver 'owner'), both holding the source via addItemToSet.
      // copyExtras(diverId: 'sharee') -> getSetIdsContaining(clone.id) is
      // ['s-own'].
    });

    test('with no active diver, joins every set that holds the source', () async {
      // Same seed, diverId: null -> both set ids.
    });
  });

  group('documents', () {
    test('each source document gets its own row on the clone, sharing the file', () async {
      final source = await make('Drysuit', EquipmentType.drysuit);
      final clone = await make('Drysuit (copy)', EquipmentType.drysuit);
      final dive = /* insert a dive row 'd1' with customStatement */ 'd1';
      final original = await media.createMedia(MediaItem(
        id: '', equipmentId: source.id, diveId: dive,
        mediaType: MediaType.document, takenAt: DateTime(2026),
        originalFilename: 'invoice.pdf', contentHash: 'h1',
        // plus the constructor's other required fields
      ));

      await service.copyExtras(sourceId: source.id, cloneId: clone.id, diverId: null);

      final copies = await media.getMediaForEquipment(clone.id);
      expect(copies, hasLength(1));
      final copy = copies.single;
      expect(copy.id, isNot(original.id));
      expect((copy.contentHash, copy.originalFilename), ('h1', 'invoice.pdf'));
      expect(copy.diveId, isNull);
      expect(copy.siteId, isNull);
      // The original is untouched and the dive still has exactly one photo row.
      expect((await media.getMediaForEquipment(source.id)).single.id, original.id);
      expect(await media.countRowsWithHash('h1'), 2);
    });
  });

  test('a failing step is reported and does not skip the others', () async {
    final source = await make('Reg B', EquipmentType.regulator);
    final clone = await make('Reg B (copy)', EquipmentType.regulator);
    final failing = EquipmentCloneService(sets: _ThrowingSetRepository());
    // Give the source a document so the documents step has work to do.

    final failed = await failing.copyExtras(
      sourceId: source.id, cloneId: clone.id, diverId: null);

    expect(failed, {CloneExtrasStep.sets});
    expect(await media.getMediaForEquipment(clone.id), hasLength(1));
  });
}

class _ThrowingSetRepository extends EquipmentSetRepository {
  @override
  Future<List<String>> getSetIdsContaining(String equipmentId, {String? diverId}) =>
      Future.error(StateError('set read failed'));
}
```

The commented test bodies are written out in full when implementing, from the
seeds described in them; every assertion named there is required. Check
`countRowsWithHash`'s exact signature in `media_repository.dart` and the
`MediaItem` constructor's required fields before running.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/data/services/equipment_clone_service_test.dart`
Expected: FAIL, `equipment_clone_service.dart` does not exist.

- [ ] **Step 3: Add `getSetIdsContaining`** to `EquipmentSetRepository`, below
  `getEquipmentIdsInSet`:

```dart
  /// The sets holding [equipmentId], only [diverId]'s own when given (a
  /// clone joins the cloner's sets, never the owner's: issue #3184).
  Future<List<String>> getSetIdsContaining(
    String equipmentId, {
    String? diverId,
  }) async {
    final items = _db.equipmentSetItems;
    final sets = _db.equipmentSets;
    final query = _db.select(items).join([
      innerJoin(sets, sets.id.equalsExp(items.setId)),
    ])..where(items.equipmentId.equals(equipmentId));
    if (diverId != null) query.where(sets.diverId.equals(diverId));
    final rows = await query.get();
    return [for (final row in rows) row.readTable(items).setId];
  }
```

- [ ] **Step 4: Implement the service**

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// The parts of a clone copied after its row is saved (issue #3184).
enum CloneExtrasStep { serviceClocks, sets, documents }

/// Copies a cloned item's service clocks, set memberships and documents from
/// its source.
///
/// Best effort, like the auto-attached clocks in `createEquipment`: the clone
/// is already committed, so a failing step is logged and reported, never
/// rethrown (a rethrow would invite a retry that duplicates the item). Each
/// step is caught on its own, so one failing does not skip the others.
class EquipmentCloneService {
  EquipmentCloneService({
    ServiceScheduleRepository? schedules,
    ServiceKindRepository? kinds,
    EquipmentSetRepository? sets,
    MediaRepository? media,
  }) : _schedules = schedules ?? ServiceScheduleRepository(),
       _kinds = kinds ?? ServiceKindRepository(),
       _sets = sets ?? EquipmentSetRepository(),
       _media = media ?? MediaRepository();

  final ServiceScheduleRepository _schedules;
  final ServiceKindRepository _kinds;
  final EquipmentSetRepository _sets;
  final MediaRepository _media;

  static final _log = LoggerService.forClass(EquipmentCloneService);

  /// Copies the extras of [sourceId] onto [cloneId], scoped to [diverId]
  /// (the clone's owner), and returns the steps that failed.
  Future<Set<CloneExtrasStep>> copyExtras({
    required String sourceId,
    required String cloneId,
    required String? diverId,
  }) async {
    final failed = <CloneExtrasStep>{};
    Future<void> run(CloneExtrasStep step, Future<void> Function() body) async {
      try {
        await body();
      } catch (e, stackTrace) {
        _log.error(
          'Copying ${step.name} from equipment $sourceId to its clone '
          '$cloneId failed; the clone was still created',
          error: e,
          stackTrace: stackTrace,
        );
        failed.add(step);
      }
    }

    await run(
      CloneExtrasStep.serviceClocks,
      () => _copyClocks(sourceId, cloneId, diverId),
    );
    await run(
      CloneExtrasStep.sets,
      () => _copySets(sourceId, cloneId, diverId),
    );
    await run(CloneExtrasStep.documents, () => _copyMedia(sourceId, cloneId));
    return failed;
  }

  /// The source's clocks without their baseline, so the clone counts from
  /// its own purchase or creation. A kind the clone already has (an
  /// auto-attached clock) takes the source's settings instead of a second
  /// clock; another diver's custom kind is skipped, as auto-attach does.
  Future<void> _copyClocks(
    String sourceId,
    String cloneId,
    String? diverId,
  ) async {
    final source = await _schedules.getSchedulesForEquipment(sourceId);
    if (source.isEmpty) return;
    final kinds = {for (final k in await _kinds.getAllKinds()) k.id: k};
    final onClone = {
      for (final s in await _schedules.getSchedulesForEquipment(cloneId))
        s.serviceKindId: s,
    };
    for (final schedule in source) {
      final kind = kinds[schedule.serviceKindId];
      if (kind == null) continue;
      if (!kind.isBuiltIn && kind.diverId != null && kind.diverId != diverId) {
        continue;
      }
      final existing = onClone[schedule.serviceKindId];
      if (existing != null) {
        await _schedules.updateSchedule(_withSettingsOf(existing, schedule));
      } else {
        final now = DateTime.now();
        onClone[schedule.serviceKindId] = await _schedules.createSchedule(
          _withSettingsOf(
            ServiceSchedule(
              id: '',
              equipmentId: cloneId,
              serviceKindId: schedule.serviceKindId,
              createdAt: now,
              updatedAt: now,
            ),
            schedule,
          ),
        );
      }
    }
  }

  /// [target] carrying [source]'s settings and no baseline.
  static ServiceSchedule _withSettingsOf(
    ServiceSchedule target,
    ServiceSchedule source,
  ) => target.copyWith(
    intervalDays: source.intervalDays,
    intervalDives: source.intervalDives,
    intervalHours: source.intervalHours,
    exposureIntervals: source.exposureIntervals,
    defaultCost: source.defaultCost,
    defaultCurrency: source.defaultCurrency,
    anchorDate: null,
    anchorSetAt: null,
    enabled: source.enabled,
  );

  Future<void> _copySets(
    String sourceId,
    String cloneId,
    String? diverId,
  ) async {
    for (final setId in await _sets.getSetIdsContaining(
      sourceId,
      diverId: diverId,
    )) {
      await _sets.addItemToSet(setId, cloneId);
    }
  }

  /// A new row per document or photo, on the clone only (no dive or site
  /// link, so a dive photo is not shown twice). The stored file is shared:
  /// the media store is content-addressed and keeps it while any row holds
  /// its hash.
  Future<void> _copyMedia(String sourceId, String cloneId) async {
    for (final item in await _media.getMediaForEquipment(sourceId)) {
      await _media.createMedia(
        item.copyWith(id: '', equipmentId: cloneId, diveId: null, siteId: null),
      );
    }
  }
}
```

- [ ] **Step 5: Add the provider** in
  `lib/features/equipment/presentation/providers/equipment_clone_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Copies a clone's clocks, sets and documents (issue #3184).
final equipmentCloneServiceProvider = Provider<EquipmentCloneService>((ref) {
  return EquipmentCloneService(
    schedules: ref.watch(serviceScheduleRepositoryProvider),
    sets: ref.watch(equipmentSetRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
  );
});
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/data/services/equipment_clone_service_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_set_repository_impl.dart lib/features/equipment/data/services/equipment_clone_service.dart lib/features/equipment/presentation/providers/equipment_clone_providers.dart test/features/equipment/data/services/equipment_clone_service_test.dart
git commit -m "feat(equipment): copy a clone's clocks, sets and documents"
```

---

### Task 4: Clone mode on the edit page

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `newEquipment` route)
- Test: `test/features/equipment/presentation/pages/equipment_edit_clone_test.dart`

**Interfaces:**
- Consumes: `cloneFormSeed` (Task 1), the Task 2 strings,
  `equipmentCloneServiceProvider` / `CloneExtrasStep` (Task 3).
- Produces: `EquipmentEditPage({String? cloneFromId, ...})`; route
  `/equipment/new?cloneFrom=<id>`.

- [ ] **Step 1: Write the failing widget tests.** Pattern:
  `equipment_edit_tags_test.dart` (real in-memory DB, `getBaseOverrides`,
  `equipmentRepositoryProvider.overrideWithValue`). Pump a `GoRouter` with
  `/start` (a button that pushes `/equipment/new?cloneFrom=<id>`),
  `/equipment/new` building `EquipmentEditPage(cloneFromId: state.uri.queryParameters['cloneFrom'])`,
  and `/equipment/:id` building `Text('DETAIL ${state.pathParameters['id']}')`.
  Tests:
  1. The form opens titled "Clone Equipment" with name "Reg A (copy)", brand
     and model filled, serial field empty.
  2. The source's tag `t1` shows as a `TagChip` on the form.
  3. Tapping Save creates a second item (repository `getAllEquipment` has two,
     the new one named "Reg A (copy)" with no serial), the page is replaced
     by `DETAIL <newId>`, and "Equipment cloned" shows.
  4. With `equipmentCloneServiceProvider` overridden by a fake whose
     `copyExtras` returns `{CloneExtrasStep.documents}`, Save also shows
     "Cloned, but some service schedules, sets or documents could not be
     copied."
  5. A source tag owned by another diver (tag row with `diver_id` 'owner',
     active diver overridden to 'sharee' through
     `validatedCurrentDiverIdProvider`) does not show on the form.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_clone_test.dart`
Expected: FAIL, `cloneFromId` is not a parameter.

- [ ] **Step 3: Route.** In `app_router.dart`'s `newEquipment` route:

```dart
                builder: (context, state) => EquipmentEditPage(
                  initialParentId: state.uri.queryParameters['parent'],
                  cloneFromId: state.uri.queryParameters['cloneFrom'],
                ),
```

- [ ] **Step 4: Page parameter.** Add to `EquipmentEditPage`:

```dart
  /// For a new item: the item it is cloned from (issue #3184). The form
  /// starts from [cloneFormSeed] of it, and the save also copies its
  /// clocks, sets and documents.
  final String? cloneFromId;

  bool get isCloning => equipmentId == null && cloneFromId != null;
```

- [ ] **Step 5: Seeding.** Split `_initializeFromEquipment` into the guard
  plus a `_seedForm(EquipmentItem equipment)` holding its current body (all
  controller and field assignments), so the clone path reuses it:

```dart
  void _initializeFromEquipment(EquipmentItem equipment) {
    if (_isInitialized) return;
    _isInitialized = true;
    _seedForm(equipment);
    _loadTags(equipment.id);
  }

  void _initializeFromClone(EquipmentItem source) {
    if (_isInitialized) return;
    _isInitialized = true;
    _seedForm(
      cloneFormSeed(source, copyName: context.l10n.equipment_clone_nameCopy),
    );
    _loadCloneSelections(source.id);
  }

  /// The source's tags and place as the clone's starting picks, only those
  /// that are the active diver's own: cloning shared gear (#2046) must not
  /// bring the owner's tags or places onto the sharee's item. A pick the
  /// diver made while these loaded is kept.
  Future<void> _loadCloneSelections(String sourceId) async {
    // Called from build: yield before the first provider read.
    await null;
    if (!mounted) return;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final tags = await ref.read(tagsForEquipmentProvider(sourceId).future);
      final own = [
        for (final t in tags)
          if (diverId == null || t.diverId == null || t.diverId == diverId) t,
      ];
      if (mounted && _selectedTags.isEmpty && own.isNotEmpty) {
        setState(() => _selectedTags = own);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Could not load the tags of equipment $sourceId to clone',
        error: e,
        stackTrace: stackTrace,
      );
    }
    try {
      final place = (await ref.read(
        currentEquipmentLocationsProvider.future,
      ))[sourceId];
      if (place == null) return;
      final mine = await ref.read(equipmentLocationsProvider.future);
      if (mounted &&
          _initialLocation == null &&
          mine.any((l) => l.id == place.id)) {
        setState(() => _initialLocation = place);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Could not load the location of equipment $sourceId to clone',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
```

- [ ] **Step 6: Build.** In `build`, load the item for editing OR cloning
  through the existing `.when` block: replace `if (widget.isEditing) {` and
  `equipmentItemProvider(widget.equipmentId!)` with
  `final loadId = widget.equipmentId ?? widget.cloneFromId; if (loadId != null) {`
  and `equipmentItemProvider(loadId)`, and its `data:` success branch with:

```dart
          if (widget.isEditing) {
            _initializeFromEquipment(equipment);
            return _buildForm(context, equipment);
          }
          _initializeFromClone(equipment);
          return _buildForm(context, null);
```

  The not-found and error branches stay as they are.

- [ ] **Step 7: Title.** Where the app bar title picks edit or new, add the
  clone case: `widget.isEditing ? editTitle : widget.isCloning ? context.l10n.equipment_edit_appBar_cloneTitle : newTitle`.

- [ ] **Step 8: Save.** In `_saveEquipment`'s create branch, after the
  initial location is recorded, copy the extras when cloning:

```dart
        if (widget.isCloning) {
          failedCloneSteps = await ref
              .read(equipmentCloneServiceProvider)
              .copyExtras(
                sourceId: widget.cloneFromId!,
                cloneId: savedId,
                diverId: diverId,
              );
        }
```

  with `var failedCloneSteps = const <CloneExtrasStep>{};` declared beside
  `locationSaved`. In the non-embedded success path, a clone replaces the form
  with its own detail page and says so:

```dart
        } else if (widget.isCloning) {
          context.pushReplacement('/equipment/$savedId');
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.equipment_clone_snackbar_cloned)),
          );
        } else {
          // existing pop + added/updated snackbar
        }
```

  Read the l10n strings into locals before the navigation, as the existing
  `locationFailed` local does. After the `locationSaved` snackbar:

```dart
        if (failedCloneSteps.isNotEmpty) {
          messenger.showSnackBar(SnackBar(content: Text(partialCopy)));
        }
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_clone_test.dart test/features/equipment/presentation/pages/equipment_edit_tags_test.dart test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart test/features/equipment/presentation/pages/equipment_edit_wanted_test.dart`
Expected: PASS (the existing edit tests guard the `build` and seeding split).

- [ ] **Step 10: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/equipment/presentation/pages/equipment_edit_page.dart test/features/equipment/presentation/pages/equipment_edit_clone_test.dart
git commit -m "feat(equipment): clone mode on the equipment form"
```

---

### Task 5: Clone in the detail page menu

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`

- [ ] **Step 1: Update the failing tests.** In the existing loop "the
  $layout overflow menu of $state item offers only Connections and Delete",
  rename it to "offers Connections, Clone and Delete", expect
  `find.text('Clone')` once and `PopupMenuItem<String>` three times. Add a
  test in the "Open in Connections" group's router style: route
  `/equipment/new` builds `Text('NEW ${state.uri.query}')`; tapping the menu
  then Clone shows `NEW cloneFrom=equip-1`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_page_test.dart`
Expected: FAIL, no "Clone" item.

- [ ] **Step 3: Implement.** In `_buildMenuItems`, after
  `openInConnectionsMenuItem(context)` (shown to every viewer, like it):

```dart
      PopupMenuItem(
        value: 'clone',
        child: ListTile(
          leading: const Icon(Icons.copy),
          title: Text(context.l10n.equipment_menu_clone),
          contentPadding: EdgeInsets.zero,
        ),
      ),
```

  and in `_handleMenuAction`:

```dart
      case 'clone':
        context.push('/equipment/new?cloneFrom=$equipmentId');
```

  Update `_buildMenuItems`' doc comment to say Clone is for every viewer too
  (the clone is the viewer's own item).

- [ ] **Step 4: Run to verify they pass**, plus the other detail page tests:

Run: `flutter test test/features/equipment/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/pages/equipment_detail_page_test.dart
git commit -m "feat(equipment): offer Clone on the equipment detail page"
```

---

### Task 6: Whole-branch checks and screenshots

- [ ] **Step 1:** `dart format .` and `flutter analyze` (no issues, infos
  included).
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/` and
  `flutter test test/features/equipment/` (one run each, logs to the
  scratchpad).
- [ ] **Step 3:** After screenshots with the throwaway golden harness: the
  detail menu with Clone (light, dark) and the Clone Equipment form (light,
  dark, phone width). Delete the harness and its `goldens/` dir.
- [ ] **Step 4:** Commit any formatting fixes as
  `chore(equipment): format`.
