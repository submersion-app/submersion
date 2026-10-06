# Equipment "Wanted" Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Wanted` equipment status for gear the diver intends to buy, kept out of every owned-gear surface and turned into owned gear with one "Mark as purchased" tap.

**Architecture:** `EquipmentStatus.wanted` is stored by name in the existing TEXT column with `isActive=false`, following the Sold precedent, so every `isActive`-only check already treats it as out of the kit. The places that read `!isActive` as Retired get a Wanted carve-out next to the existing Sold one, and the screens that read all equipment exclude it explicitly. UI adds a header status widget (chip plus purchase button), edit-form adaptation and summary cards.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter gen-l10n (11 ARB locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-05-equipment-wanted-status-design.md`

## Global Constraints

- No schema version bump and no migration rung: the value is a new string in the existing `equipment.status` TEXT column.
- Save rule: `isActive = status not in {retired, sold, wanted}`.
- Every new user-visible string is an ARB key translated in all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh). ARB files are feature-grouped: insert each key next to the named neighbour key, never at the end.
- No em-dashes anywhere (code, comments, docs, commit messages). No emojis.
- Paths in tests built with `p.join`, never string concatenation; tests restore any global state they change.
- Imports grouped dart, flutter, packages, local. Run `dart format .` before each commit.
- Commits use `feat(equipment): ...` / `test(equipment): ...` style and carry no tool attribution.

## Review Focus

1. **Status round trip on an owned item edited to Wanted by mistake:** switching the dropdown back to Active must show the serial number, purchase date and parent unchanged, and save must not clear them. (Task 6 test.)
2. **A Wanted row written with `isActive=true`** (a hand-edited import or an older build's write): it must still stay out of the active list, `isFitted` and the default view. (Task 2 and Task 4 tests use `isActive: true` rows.)
3. **Mark as purchased on an item that already has a purchase date** (a planned date entered while on the wishlist): the date is kept, not overwritten with today. (Task 2 test.)
4. **A dropdown whose saved value is now a Wanted item** (a pre-dive template or cylinder config pointing at gear later set to Wanted): the dropdown must not throw for a value with no matching item. (Task 5 tests.)
5. **Bulk Reactivate on a mixed selection containing a Wanted item:** the action is not offered, and the repository refuses to flip a Wanted row to `isActive=true`. (Task 2 and Task 4 tests.)

---

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `lib/core/constants/enums.dart` | `EquipmentStatus` | add `wanted` after `lost` |
| `lib/features/equipment/domain/entities/equipment_item.dart` | entity | `isWanted` getter; `isFitted` excludes wanted |
| `lib/features/equipment/presentation/utils/equipment_enum_display.dart` | status labels | `wanted` arm |
| `lib/l10n/arb/app_*.arb` (11) | strings | 5 new keys |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` | queries and writes | active/retired/by-status carve-outs, reactivate guard, `markEquipmentPurchased` |
| `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart` | `_isFitted` mirror | exclude wanted |
| `lib/features/equipment/presentation/utils/equipment_departed_status.dart` | departed badge | null for wanted |
| `lib/features/equipment/data/repositories/equipment_visibility_queries.dart` | set-apply members | skip wanted |
| `lib/features/equipment/query/equipment_filter_query.dart` | list default view | exclude wanted |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | bulk actions | Reactivate not for wanted |
| `lib/features/equipment/presentation/providers/equipment_providers.dart` | providers and notifier | `diveGearTypesProvider`, `markPurchased` |
| `lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart` | dive filter types | use `diveGearTypesProvider` |
| `lib/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart` | rebreather dropdown | exclude wanted (keep current) |
| `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart` | gear dropdown | exclude wanted (keep chosen) |
| `lib/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart` | dive search gear chips | exclude wanted (keep selected) |
| `lib/features/equipment/presentation/pages/equipment_edit_page.dart` | form | status init, save rule, relabel and hide |
| `lib/features/equipment/presentation/widgets/equipment_header_status.dart` | **new**: header status chip plus Mark as purchased | create |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` | detail header | use `EquipmentHeaderStatus` |
| `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart` | summary | owned totals plus Wanted cards |

Note on `ownedEquipmentTypesProvider`: the spec lists it for exclusion, but it also feeds the Equipment filter sheet's type chips, where choosing the Wanted status chip should still let the diver narrow wanted gear by type (the same reason it already includes retired gear). So it stays as is, and the dive filter (the surface the spec means: types you can filter *dives* by) moves to a new `diveGearTypesProvider` that excludes Wanted. Task 5 updates the spec line to match.

---

### Task 1: Status value, labels and strings

**Files:**
- Modify: `lib/core/constants/enums.dart:421-436`
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart:133-139`
- Modify: `lib/features/equipment/presentation/utils/equipment_enum_display.dart:67-78`
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Test: `test/features/equipment/presentation/utils/equipment_status_display_test.dart`

**Interfaces:**
- Produces: `EquipmentStatus.wanted`; `EquipmentItem.isWanted` (`bool`); l10n getters `enum_equipmentStatus_wanted`, `equipment_edit_expectedPriceLabel`, `equipment_detail_markPurchased`, `equipment_snackbar_purchased`, and `equipment_summary_wantedValue(String currency)`.

- [ ] **Step 1: Write the failing test** (append inside `main()` of `equipment_status_display_test.dart`)

```dart
  test('wanted has its own label in English (#2025)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(EquipmentStatus.wanted.localizedName(l10n), 'Wanted');
  });
```

The existing "every locale gives every status a distinct, non-empty label" test covers the other 10 locales once the value exists.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/equipment_status_display_test.dart`
Expected: compile error, `wanted` is not a member of `EquipmentStatus`.

- [ ] **Step 3: Add the enum value** (`enums.dart`, after `lost('Lost')`, changing its `;` to `,`)

```dart
  loaned('Loaned Out'),
  lost('Lost'),

  /// Gear the diver wants to buy (#2025). Not owned yet, so it is stored
  /// with isActive=false like Sold and kept out of every owned-gear surface:
  /// the active list, pickers, sets, service clocks, statistics and totals.
  /// "Mark as purchased" turns it into active gear.
  wanted('Wanted');
```

- [ ] **Step 4: Add `isWanted` and harden `isFitted`** (`equipment_item.dart`, replace the `isFitted` getter and its doc comment)

```dart
  /// Still in service: active, and not carrying a terminal status. Older
  /// rows can be retired or sold with isActive left true, and the
  /// repository's own active-gear queries treat both statuses as gone.
  /// Wanted gear (#2025) is not owned yet, so it is never fitted either,
  /// even on a row whose isActive was left true.
  bool get isFitted =>
      isActive &&
      status != EquipmentStatus.retired &&
      status != EquipmentStatus.sold &&
      status != EquipmentStatus.wanted;

  /// On the diver's wishlist rather than in the kit (#2025).
  bool get isWanted => status == EquipmentStatus.wanted;
```

- [ ] **Step 5: Add the display arm** (`equipment_enum_display.dart`, after the `lost` arm)

```dart
    EquipmentStatus.lost => l10n.enum_equipmentStatus_lost,
    EquipmentStatus.wanted => l10n.enum_equipmentStatus_wanted,
```

- [ ] **Step 6: Add the ARB keys.** Write a throwaway script in the scratchpad (`add_wanted_arb.py`, run with `python3.14`) that, for each locale file, inserts each new line directly after the line holding its anchor key, preserving the file's own line endings, and fails loudly if an anchor is missing or a key already exists. Anchors and values:

| Key | Insert after | en | de | es | fr | it |
| --- | --- | --- | --- | --- | --- | --- |
| `enum_equipmentStatus_wanted` | `enum_equipmentStatus_spare` | Wanted | Gewünscht | Deseado | Souhaité | Desiderato |
| `equipment_edit_expectedPriceLabel` | `equipment_edit_purchasePriceLabel` | Expected Price | Erwarteter Preis | Precio previsto | Prix prévu | Prezzo previsto |
| `equipment_detail_markPurchased` | `equipment_detail_retiredChip` | Mark as purchased | Als gekauft markieren | Marcar como comprado | Marquer comme acheté | Segna come acquistato |
| `equipment_snackbar_purchased` | `equipment_snackbar_reactivated` | Moved to your active gear | In Ihre aktive Ausrüstung verschoben | Movido a tu equipo activo | Déplacé vers votre équipement actif | Spostato nell'attrezzatura attiva |
| `equipment_summary_wantedValue` | `equipment_summary_totalValue` | Wanted Value ({currency}) | Wunschwert ({currency}) | Valor deseado ({currency}) | Valeur souhaitée ({currency}) | Valore desiderato ({currency}) |

| Key | nl | pt | zh | ar | he | hu |
| --- | --- | --- | --- | --- | --- | --- |
| `enum_equipmentStatus_wanted` | Gewenst | Desejado | 想要 | مرغوب | רצוי | Kívánt |
| `equipment_edit_expectedPriceLabel` | Verwachte prijs | Preço Previsto | 预计价格 | السعر المتوقع | מחיר צפוי | Várható ár |
| `equipment_detail_markPurchased` | Markeren als gekocht | Marcar como comprado | 标记为已购买 | تحديد كمُشترى | סמן כנרכש | Megjelölés megvásároltként |
| `equipment_snackbar_purchased` | Verplaatst naar je actieve uitrusting | Movido para o seu equipamento ativo | 已移至在用装备 | تم النقل إلى معداتك النشطة | הועבר לציוד הפעיל שלך | Áthelyezve az aktív felszerelésed közé |
| `equipment_summary_wantedValue` | Gewenste waarde ({currency}) | Valor Desejado ({currency}) | 想要的价值 ({currency}) | القيمة المرغوبة ({currency}) | שווי רצוי ({currency}) | Kívánt érték ({currency}) |

In `app_en.arb` only, also insert this metadata block directly after the closing `},` of the `"@equipment_summary_totalValue"` block:

```json
  "@equipment_summary_wantedValue": {
    "placeholders": {
      "currency": {
        "type": "String"
      }
    }
  },
```

Then regenerate: `flutter gen-l10n`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/utils/equipment_status_display_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/enums.dart lib/features/equipment/domain/entities/equipment_item.dart lib/features/equipment/presentation/utils/equipment_enum_display.dart lib/l10n/ test/features/equipment/presentation/utils/equipment_status_display_test.dart
git commit -m "feat(equipment): add a Wanted equipment status and its strings"
```

---

### Task 2: Repository carve-outs and Mark as purchased

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`getActiveEquipment` ~78, `getRetiredEquipment` ~112, `getEquipmentByStatus` ~184, `reactivateEquipment` ~811; add `markEquipmentPurchased` after `reactivateEquipment`)
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart:94-97`
- Modify: `lib/features/equipment/presentation/utils/equipment_departed_status.dart`
- Test: `test/features/equipment/data/repositories/equipment_repository_test.dart` (new group at the end of `group('EquipmentRepository', ...)`)
- Test: `test/features/equipment/presentation/utils/equipment_departed_status_test.dart`

**Interfaces:**
- Consumes: `EquipmentStatus.wanted` (Task 1).
- Produces: `Future<void> EquipmentRepository.markEquipmentPurchased(String id, {DateTime? today})`. It sets `status=active` and `isActive=true`, sets `purchaseDate = today ?? DateTime.now()` (date only) when the stored date is null, stamps `updatedAt` and stages sync. It is a no-op for a row that is not Wanted.

- [ ] **Step 1: Write the failing repository tests** (append a group inside `group('EquipmentRepository', ...)`)

```dart
    group('wanted gear (#2025)', () {
      Future<EquipmentItem> wanted(String name, {bool isActive = false}) =>
          repository.createEquipment(
            createTestEquipment(
              name: name,
              status: EquipmentStatus.wanted,
              isActive: isActive,
            ),
          );

      test('is not active gear, even with isActive left true', () async {
        await repository.createEquipment(createTestEquipment(name: 'Owned'));
        await wanted('Wishlist Wing');
        await wanted('Odd Row', isActive: true);

        expect((await repository.getActiveEquipment()).map((e) => e.name), [
          'Owned',
        ]);
      });

      test('is not retired gear', () async {
        await repository.createEquipment(
          createTestEquipment(name: 'Retired Reg', isActive: false),
        );
        await wanted('Wishlist Wing');

        expect((await repository.getRetiredEquipment()).map((e) => e.name), [
          'Retired Reg',
        ]);
        expect(
          (await repository.getEquipmentByStatus(
            EquipmentStatus.retired,
          )).map((e) => e.name),
          ['Retired Reg'],
        );
      });

      test('is listed under its own status', () async {
        await repository.createEquipment(createTestEquipment(name: 'Owned'));
        await wanted('Wishlist Wing');

        expect(
          (await repository.getEquipmentByStatus(
            EquipmentStatus.wanted,
          )).map((e) => e.name),
          ['Wishlist Wing'],
        );
      });

      test('reactivate leaves a wanted row alone', () async {
        final item = await wanted('Wishlist Wing');

        await repository.reactivateEquipment(item.id);

        final stored = await repository.getEquipmentById(item.id);
        expect(stored!.status, EquipmentStatus.wanted);
        expect(stored.isActive, isFalse);
      });

      test('mark as purchased makes it active and dates it today', () async {
        final item = await wanted('Wishlist Wing');

        await repository.markEquipmentPurchased(
          item.id,
          today: DateTime(2026, 10, 5, 14, 30),
        );

        final stored = await repository.getEquipmentById(item.id);
        expect(stored!.status, EquipmentStatus.active);
        expect(stored.isActive, isTrue);
        expect(stored.purchaseDate, DateTime(2026, 10, 5));
        expect((await repository.getActiveEquipment()).map((e) => e.name), [
          'Wishlist Wing',
        ]);
      });

      test('mark as purchased keeps a date entered on the wishlist', () async {
        final item = await repository.createEquipment(
          createTestEquipment(
            name: 'Planned Reg',
            status: EquipmentStatus.wanted,
            isActive: false,
            purchaseDate: DateTime(2026, 12, 24),
            purchasePrice: 899,
          ),
        );

        await repository.markEquipmentPurchased(
          item.id,
          today: DateTime(2026, 10, 5),
        );

        final stored = await repository.getEquipmentById(item.id);
        expect(stored!.purchaseDate, DateTime(2026, 12, 24));
        expect(stored.purchasePrice, 899);
      });

      test('mark as purchased ignores gear that is not wanted', () async {
        final item = await repository.createEquipment(
          createTestEquipment(
            name: 'Sold Reg',
            status: EquipmentStatus.sold,
            isActive: false,
          ),
        );

        await repository.markEquipmentPurchased(item.id);

        final stored = await repository.getEquipmentById(item.id);
        expect(stored!.status, EquipmentStatus.sold);
        expect(stored.isActive, isFalse);
      });
    });
```

- [ ] **Step 2: Write the failing departed-status test** (append inside `main()` of `equipment_departed_status_test.dart`)

```dart
  test('wanted gear has not departed: it never joined the kit (#2025)', () {
    expect(
      departedStatusOf(item(EquipmentStatus.wanted, isActive: false)),
      isNull,
    );
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_test.dart test/features/equipment/presentation/utils/equipment_departed_status_test.dart`
Expected: FAIL, `markEquipmentPurchased` is undefined (compile error).

- [ ] **Step 4: Implement the query carve-outs**

In `getActiveEquipment`, extend the comment and the `where`:

```dart
        // status is the user-visible retirement flag; legacy rows can carry
        // status=retired with isActive still true, so filter on both (#636).
        // "Sold" is the same kind of terminal status (gear that has left
        // the kit), so it drops out of the active list the same way, and
        // "Wanted" gear has not joined the kit yet (#2025).
        ..where(
          (t) =>
              t.isActive.equals(true) &
              t.status.isNotValue(EquipmentStatus.retired.name) &
              t.status.isNotValue(EquipmentStatus.sold.name) &
              t.status.isNotValue(EquipmentStatus.wanted.name),
        )
```

In `getRetiredEquipment`:

```dart
      // Either retirement marker counts, so items retired before the two
      // fields were kept in sync are still listed (#636). Sold and Wanted
      // gear are also isActive=false but are not retired (#2025); keep
      // them out of this list so their statuses stay distinct.
      final query = _db.select(_db.equipment)
        ..where(
          (t) =>
              (t.isActive.equals(false) |
                  t.status.equals(EquipmentStatus.retired.name)) &
              t.status.isNotValue(EquipmentStatus.sold.name) &
              t.status.isNotValue(EquipmentStatus.wanted.name),
        )
```

In `getEquipmentByStatus`:

```dart
      // The Retired filter also matches legacy rows that only ever had
      // isActive flipped, so nothing becomes unreachable in the UI (#636),
      // but not sold or wanted gear, which are isActive=false yet have their
      // own status (#2025).
      final query = _db.select(_db.equipment)
        ..where(
          (t) => status == EquipmentStatus.retired
              ? (t.status.equals(status.name) | t.isActive.equals(false)) &
                    t.status.isNotValue(EquipmentStatus.sold.name) &
                    t.status.isNotValue(EquipmentStatus.wanted.name)
              : t.status.equals(status.name),
        )
```

- [ ] **Step 5: Guard reactivate.** In `reactivateEquipment`, right after `current` is read, add:

```dart
      // Wanted gear is not owned yet (#2025): reactivating would leave a
      // wishlist row flagged active. Buying it goes through
      // markEquipmentPurchased instead.
      if (current == null ||
          current.status == EquipmentStatus.wanted.name) {
        return;
      }
```

Then change `current?.status` to `current.status` in `clearsTerminalStatus`.

- [ ] **Step 6: Add `markEquipmentPurchased`** directly after `reactivateEquipment`

```dart
  /// Turns a Wanted item into owned, active gear (#2025): status active,
  /// isActive true, and the purchase date set to [today] (date only) unless
  /// one was already entered on the wishlist. Everything else is kept. A
  /// row that is not Wanted is left alone.
  Future<void> markEquipmentPurchased(String id, {DateTime? today}) async {
    try {
      final current = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (current == null || current.status != EquipmentStatus.wanted.name) {
        return;
      }
      final now = DateTime.now();
      final day = today ?? now;
      final ts = now.millisecondsSinceEpoch;
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(
          isActive: const Value(true),
          status: Value(EquipmentStatus.active.name),
          purchaseDate: current.purchaseDate == null
              ? Value(
                  DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
                )
              : const Value.absent(),
          updatedAt: Value(ts),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: ts,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark equipment as purchased: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

`equipment.purchase_date` is a nullable integer of epoch milliseconds (`equipment_tables.dart:34`), written from a local `DateTime` exactly as `createEquipment` does at ~line 321, so the local-midnight value above reads back as `DateTime(2026, 10, 5)`.

- [ ] **Step 7: Harden the passport mirror** (`cylinder_passport_repository.dart`)

```dart
  /// In service: active and neither retired, sold nor wanted, as
  /// EquipmentItem.isFitted defines it.
  static bool _isFitted(EquipmentData row) =>
      row.isActive &&
      row.status != EquipmentStatus.retired.name &&
      row.status != EquipmentStatus.sold.name &&
      row.status != EquipmentStatus.wanted.name;
```

- [ ] **Step 8: Departed status** (`equipment_departed_status.dart`, add as the first line of the body, and extend the doc comment with one sentence: "Wanted gear (#2025) is inactive but has not left the kit; it never joined it, so it gets no departed badge.")

```dart
  if (item.status == EquipmentStatus.wanted) return null;
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_test.dart test/features/equipment/presentation/utils/equipment_departed_status_test.dart test/features/cylinder_passports`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart lib/features/equipment/presentation/utils/equipment_departed_status.dart test/features/equipment/data/repositories/equipment_repository_test.dart test/features/equipment/presentation/utils/equipment_departed_status_test.dart
git commit -m "feat(equipment): keep Wanted gear out of active and retired lists, add mark as purchased"
```

---

### Task 3: Skip Wanted members when a set is applied

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_visibility_queries.dart:18-51`
- Test: `test/features/equipment/data/repositories/equipment_usable_set_members_test.dart`

**Interfaces:**
- Consumes: `EquipmentStatus.wanted`.
- Produces: `usableSetMemberIds` also drops rows whose `status` is `wanted` (signature unchanged).

- [ ] **Step 1: Write the failing test** (append inside `main()`)

```dart
  test('drops a member that is only on the wishlist (#2025)', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at, '
      "diver_id, status, is_active) VALUES ('wish', 'wish', 'bcd', 0, 0, "
      "'me', 'wanted', 0)",
    );

    final ids = await EquipmentRepository().usableSetMemberIds([
      'mine',
      'wish',
    ], 'me');
    expect(ids, ['mine']);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_usable_set_members_test.dart`
Expected: FAIL, `['mine', 'wish']` returned.

- [ ] **Step 3: Implement.** Add `_db.equipment.status` to `addColumns`, and hide wanted rows in the loop:

```dart
      final rows =
          await (_db.selectOnly(_db.equipment)
                ..addColumns([
                  _db.equipment.id,
                  _db.equipment.diverId,
                  _db.equipment.status,
                  shared,
                ])
                ..where(_db.equipment.id.isIn(chunk)))
              .get();
      for (final r in rows) {
        // Gear on the wishlist is not owned yet (#2025), so applying a set
        // never puts it on a dive, even if a member was later set to Wanted.
        final wanted =
            r.read(_db.equipment.status) == EquipmentStatus.wanted.name;
        final usable = isSetMemberUsableBy(
          ownerId: r.read(_db.equipment.diverId),
          diverId: diverId,
          sharedWithDiver: r.read(shared) ?? false,
        );
        if (wanted || !usable) hidden.add(r.read(_db.equipment.id)!);
      }
```

Add `import 'package:submersion/core/constants/enums.dart';` and update the method doc: "The members of a set, in [ids] order, that applying it gives [diverId]'s dive ([isSetMemberUsableBy]), less any member on the wishlist (#2025). Missing rows apply as they always have."

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/equipment/data/repositories/equipment_usable_set_members_test.dart test/features/equipment/data/repositories/equipment_visibility_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_visibility_queries.dart test/features/equipment/data/repositories/equipment_usable_set_members_test.dart
git commit -m "feat(equipment): skip Wanted set members when a set is applied"
```

---

### Task 4: Equipment list default view and bulk actions

**Files:**
- Modify: `lib/features/equipment/query/equipment_filter_query.dart:24-31`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:532-537`
- Test: `test/features/equipment/query/equipment_filter_query_semantics_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_list_page_test.dart` (bulk action check)

**Interfaces:**
- Consumes: `EquipmentStatus.wanted`, `EquipmentItem.isWanted`.

- [ ] **Step 1: Write the failing filter test.** In `setUp`, after `await item('mine0', 'fins', diver: null);`, add two rows:

```dart
    // Wishlist gear (#2025), including a row whose is_active was left set.
    await item('wish', 'bcd', status: 'wanted', active: false);
    await item('wish2', 'fins', status: 'wanted');
```

The existing `defaultView` constant is unchanged, so 'the default view hides retired, inactive and sold gear' now fails until the query excludes wanted. Add:

```dart
  test('the Wanted view selects only wishlist gear (#2025)', () async {
    expect(
      await selected(const EquipmentFilterState(status: EquipmentStatus.wanted)),
      {'wish', 'wish2'},
    );
  });

  test('the Retired view does not pick up wishlist gear (#2025)', () async {
    expect(
      await selected(
        const EquipmentFilterState(status: EquipmentStatus.retired),
      ),
      isNot(contains('wish')),
    );
  });
```

Update any existing assertion in this file that enumerates all rows (for example the `All Equipment still narrows by the other axes` test filters regulators, so it is unaffected; re-check `each status view selects its gear` and adjust only if it lists every row).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/query/equipment_filter_query_semantics_test.dart`
Expected: FAIL on the default view (`wish2` present) and the Retired view (`wish` present).

- [ ] **Step 3: Implement the default and retired branches**

```dart
    } else if (s == null) {
      // getActiveEquipment: legacy rows can be retired with is_active still
      // set, sold gear has left the kit, and wanted gear has not joined it
      // (#2025).
      parts
        ..add(c('active', QueryOp.eq, const BoolValue(true)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.retired.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.wanted.name)));
    } else if (s == EquipmentStatus.retired) {
      // getEquipmentByStatus(retired): legacy rows that only flipped
      // is_active, but not sold or wanted gear.
      parts
        ..add(
          OrNode([
            c('status', QueryOp.eq, e(EquipmentStatus.retired.name)),
            c('active', QueryOp.eq, const BoolValue(false)),
          ]),
        )
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.sold.name)))
        ..add(c('status', QueryOp.neq, e(EquipmentStatus.wanted.name)));
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/equipment/query/`
Expected: PASS (the census test included).

- [ ] **Step 5: Bulk Reactivate.** In `_bulkActions`, change the reactivate predicate:

```dart
        // Wanted gear is inactive too, but buying it is not reactivating it
        // (#2025): the detail page's Mark as purchased does that.
        isEnabled: (ids) =>
            everyChecked(ids, (e) => !e.isActive && !e.isWanted),
```

Add a widget test in `equipment_list_page_test.dart` alongside the existing bulk-selection tests, using that file's existing harness: select a Wanted row (status wanted, `isActive: false`) and assert the `Reactivate` action is disabled or absent (`find.text('Reactivate')` is absent from the selection bar's enabled actions). Mirror the existing test that checks Retire/Reactivate enablement; locate it with `grep -n "reactivate\|Reactivate" test/features/equipment/presentation/pages/equipment_list_page_test.dart`.

- [ ] **Step 6: Run and commit**

Run: `flutter test test/features/equipment/query/ test/features/equipment/presentation/pages/equipment_list_page_test.dart`
Expected: PASS.

```bash
git add lib/features/equipment/query/equipment_filter_query.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/query/equipment_filter_query_semantics_test.dart test/features/equipment/presentation/pages/equipment_list_page_test.dart
git commit -m "feat(equipment): hide Wanted gear from the default list and bulk reactivate"
```

---

### Task 5: Screens that read all equipment

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (after `ownedEquipmentTypesProvider`, ~line 165)
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart:35`
- Modify: `lib/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart:133-136`
- Modify: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart:152-153`
- Modify: `lib/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart:~194`
- Modify: `docs/superpowers/specs/2026-10-05-equipment-wanted-status-design.md` (the `ownedEquipmentTypesProvider` bullet)
- Test: `test/features/equipment/presentation/providers/dive_gear_types_provider_test.dart` (create)
- Test: `test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`
- Test: `test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart`
- Test: `test/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group_test.dart`

**Interfaces:**
- Consumes: `EquipmentItem.isWanted`, `allEquipmentProvider`.
- Produces: `final diveGearTypesProvider = Provider<List<EquipmentType>>` (types of every non-Wanted item, in `EquipmentType` order).

- [ ] **Step 1: Write the failing provider test** (create the file)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

void main() {
  test('dive gear types leave out a type held only by wanted gear', () async {
    final container = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith(
          (ref) async => const [
            EquipmentItem(id: 'r', name: 'Reg', type: EquipmentType.regulator),
            EquipmentItem(
              id: 'w',
              name: 'Dream wing',
              type: EquipmentType.bcd,
              status: EquipmentStatus.wanted,
              isActive: false,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(allEquipmentProvider.future);

    expect(container.read(diveGearTypesProvider), [EquipmentType.regulator]);
    // The Equipment page's own type chips still offer it: its status axis
    // can put wanted gear on screen.
    expect(
      container.read(ownedEquipmentTypesProvider),
      containsAll([EquipmentType.regulator, EquipmentType.bcd]),
    );
  });
}
```

Check the project's `ProviderContainer` import path against an existing provider test (`grep -rln "ProviderContainer(" test/features/equipment | head -1`) and match it.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/dive_gear_types_provider_test.dart`
Expected: compile error, `diveGearTypesProvider` undefined.

- [ ] **Step 3: Implement the provider and use it in the dive filter**

```dart
/// The gear categories a diver can filter dives by: [ownedEquipmentTypesProvider]
/// less any type held only by wishlist gear (#2025), which is never on a dive.
final diveGearTypesProvider = Provider<List<EquipmentType>>((ref) {
  final all = ref.watch(allEquipmentProvider).value ?? const <EquipmentItem>[];
  final present = {
    for (final e in all)
      if (!e.isWanted) e.type,
  };
  return EquipmentType.values.where(present.contains).toList();
});
```

In `dive_filter_gear_attributes_section.dart`, replace `ref.watch(ownedEquipmentTypesProvider)` with `ref.watch(diveGearTypesProvider)`, and in its test file replace the `ownedEquipmentTypesProvider.overrideWithValue(...)` override with `diveGearTypesProvider.overrideWithValue(...)`.

- [ ] **Step 4: Cylinder config rebreathers.** Write the failing test first, in `cylinder_config_edit_page_test.dart`:

```dart
  testWidgets('a wanted rebreather is not offered as the owning unit (#2025)', (
    tester,
  ) async {
    final t = now.millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'rb-wish',
            name: 'Dream CCR',
            type: 'rebreather',
            diverId: const Value('d1'),
            status: const Value('wanted'),
            isActive: const Value(false),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generic gas plan'));
    await tester.pumpAndSettle();

    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.text('Dream CCR'), findsNothing);
  });
```

Run it (expect FAIL: 'Dream CCR' found), then implement:

```dart
    // Wishlist rebreathers (#2025) are not units a configuration can belong
    // to, except the one this configuration already names.
    final rebreathers = equipment
        .where(
          (e) =>
              e.type == EquipmentType.rebreather &&
              (!e.isWanted || e.id == _equipmentId),
        )
        .toList();
```

- [ ] **Step 5: Pre-dive session dropdown.** In `start_session_sheet_test.dart`, give `pumpSheet` an optional `List<EquipmentItem>? gear` parameter used as `allEquipmentProvider.overrideWith((ref) async => gear ?? [primaryComputer, backupComputer])`. Then add:

```dart
  testWidgets('wishlist gear is not offered for an equipment item (#2025)', (
    tester,
  ) async {
    const wish = EquipmentItem(
      id: 'g3',
      name: 'Dream computer',
      type: EquipmentType.computer,
      status: EquipmentStatus.wanted,
      isActive: false,
    );
    await pumpSheet(tester, gear: [primaryComputer, backupComputer, wish]);

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer Check').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primary computer'));
    await tester.pumpAndSettle();

    expect(find.text('Backup computer'), findsWidgets);
    expect(find.text('Dream computer'), findsNothing);
  });
```

(`EquipmentType.computer` exists, `enums.dart:48`.) Run it (expect FAIL), then implement in `build`:

```dart
    final equipmentAsync = ref.watch(allEquipmentProvider);
    // Wishlist gear (#2025) is not something to check before a dive.
    final equipmentList = [
      for (final e in equipmentAsync.value ?? const <EquipmentItem>[])
        if (!e.isWanted) e,
    ];
```

Then in the per-item dropdown at ~line 230, keep a chosen item that is not in the list from breaking the dropdown: change `for (final e in equipmentList)` to iterate `[...equipmentList, if (chosen != null && !equipmentList.contains(chosen)) chosen]`, where `chosen` is `_equipmentByItemId[item.id]` (already in scope at ~line 130 as a pattern; read it locally in the builder). Check the sheet's line 90 set expansion still reads by id through `getAllEquipment` and is unaffected.

- [ ] **Step 6: Dive search gear chips.** In `refine_gas_equipment_group_test.dart`, add:

```dart
  testWidgets('wishlist gear gets no chip unless already selected (#2025)', (
    tester,
  ) async {
    const wish = EquipmentItem(
      id: 'w',
      name: 'Dream wing',
      type: EquipmentType.bcd,
      status: EquipmentStatus.wanted,
      isActive: false,
    );
    await pump(tester, gear: [hoseItem, wish]);
    expect(find.widgetWithText(FilterChip, 'Dream wing'), findsNothing);

    await pump(
      tester,
      initial: const DiveFilterState(equipmentIds: ['w']),
      gear: [hoseItem, wish],
    );
    expect(find.widgetWithText(FilterChip, 'Dream wing'), findsOneWidget);
  });
```

Run it (expect FAIL), then in the `data:` builder filter the items before rendering chips: `final offered = [for (final i in items) if (!i.isWanted || d.equipmentIds.contains(i.id)) i];` and use `offered` in place of `items` for the empty check and the chip loop (keep the variable that holds the draft as named in that file).

- [ ] **Step 7: Update the spec bullet** for `ownedEquipmentTypesProvider` to read: "The dive filter's gear type chips (`diveGearTypesProvider`, new): a type held only by Wanted items is not offered. The Equipment filter sheet's type chips (`ownedEquipmentTypesProvider`) keep every status, because its status axis can show Wanted gear."

- [ ] **Step 8: Run all touched tests and commit**

Run: `flutter test test/features/equipment/presentation/providers/dive_gear_types_provider_test.dart test/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section_test.dart test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart test/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group_test.dart`
Expected: PASS.

```bash
git add lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart lib/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart lib/features/pre_dive/presentation/widgets/start_session_sheet.dart lib/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart docs/superpowers/specs/2026-10-05-equipment-wanted-status-design.md test/features/equipment/presentation/providers/dive_gear_types_provider_test.dart test/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section_test.dart test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart test/features/pre_dive/presentation/widgets/start_session_sheet_test.dart test/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group_test.dart
git commit -m "feat(equipment): keep Wanted gear out of dive filters, pre-dive and rebreather pickers"
```

---

### Task 6: Edit form for Wanted gear

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (status init ~181, parent block ~402, serial ~533, `_buildDateSection` ~755, notification card ~572, save ~1086)
- Test: `test/features/equipment/presentation/pages/equipment_edit_wanted_test.dart` (create; harness copied from `equipment_edit_service_section_test.dart`)

**Interfaces:**
- Consumes: `EquipmentStatus.wanted`, `l10n.equipment_edit_expectedPriceLabel`.

- [ ] **Step 1: Write the failing tests** (create the file; `pumpEditor` is the same tall-viewport `ProviderScope` + `MaterialApp` + `EquipmentEditPage(equipmentId:, embedded: true)` harness as `equipment_edit_service_section_test.dart`, with `setUpTestDatabase` / `tearDownTestDatabase` and `equipmentRepositoryProvider.overrideWithValue(repository)`)

```dart
    testWidgets('a wanted item loads as Wanted, relabelled and trimmed', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Dream Reg',
          type: EquipmentType.regulator,
          status: EquipmentStatus.wanted,
          isActive: false,
          purchasePrice: 899,
        ),
      );
      await pumpEditor(tester, created.id);

      expect(find.text('Wanted'), findsOneWidget);
      expect(find.text('Expected Price'), findsOneWidget);
      expect(find.text('Purchase Price'), findsNothing);
      expect(find.text('Purchase Date'), findsNothing);
      expect(find.text('Serial Number'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('switching an owned item to Wanted and back keeps its fields', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'My Reg',
          type: EquipmentType.regulator,
          serialNumber: 'SN-42',
          purchaseDate: DateTime(2024, 3, 1),
        ),
      );
      await pumpEditor(tester, created.id);

      Future<void> pickStatus(String from, String to) async {
        await tester.tap(find.text(from));
        await tester.pumpAndSettle();
        await tester.tap(find.text(to).last);
        await tester.pumpAndSettle();
      }

      await pickStatus('Active', 'Wanted');
      expect(find.text('SN-42'), findsNothing);
      await pickStatus('Wanted', 'Active');
      expect(find.text('SN-42'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.serialNumber, 'SN-42');
      expect(saved.purchaseDate, DateTime(2024, 3, 1));
      expect(saved.isActive, isTrue);
    });

    testWidgets('saving as Wanted stores isActive=false and keeps hidden '
        'values', (tester) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'My Reg',
          type: EquipmentType.regulator,
          serialNumber: 'SN-42',
        ),
      );
      await pumpEditor(tester, created.id);

      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wanted').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.status, EquipmentStatus.wanted);
      expect(saved.isActive, isFalse);
      expect(saved.serialNumber, 'SN-42');
    });
```

Use the exact label strings from `app_en.arb` (`equipment_edit_serialNumberLabel`, `equipment_edit_purchaseDateLabel`, `equipment_edit_notificationsTitle`); look them up and adjust the literals before running.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_wanted_test.dart`
Expected: FAIL (the first test finds 'Retired' instead of 'Wanted', and the purchase labels are shown).

- [ ] **Step 3: Implement.** Add a getter on the state class:

```dart
  /// Wishlist gear (#2025): fields that only make sense for gear in hand
  /// are hidden, but their values are kept and saved unchanged.
  bool get _isWanted => _selectedStatus == EquipmentStatus.wanted;
```

Status init:

```dart
    // A legacy row can carry isActive=false with a non-terminal status.
    // Show it as Retired so the form states the item's real condition;
    // otherwise saving would silently reactivate it (#636). "Sold" and
    // "Wanted" (#2025) are inactive by design, so keep them as they are.
    _selectedStatus =
        !equipment.isActive &&
            equipment.status != EquipmentStatus.sold &&
            equipment.status != EquipmentStatus.wanted
        ? EquipmentStatus.retired
        : equipment.status;
```

Parent dropdown: change `if (_parentTypesFor(_selectedType).isNotEmpty) ...[` to `if (!_isWanted && _parentTypesFor(_selectedType).isNotEmpty) ...[`.

Serial number: wrap the serial `TextFormField` as `if (!_isWanted) TextFormField(...)`.

Notification card: change `_buildNotificationSection(context),` (and its preceding spacer if it is part of the same conditional pair) to `if (!_isWanted) _buildNotificationSection(context),`.

In `_buildDateSection`, wrap the purchase-date label, its `SizedBox(height: 8)`, the `OutlinedButton.icon` and the clear-date `TextButton` plus the `SizedBox(height: 16)` after them in `if (!_isWanted) ...[ ... ]`, and set the price label:

```dart
                          labelText: _isWanted
                              ? context.l10n.equipment_edit_expectedPriceLabel
                              : context.l10n.equipment_edit_purchasePriceLabel,
```

Save rule:

```dart
        // Retired, Sold and Wanted (#2025) are all out of the kit.
        isActive:
            _selectedStatus != EquipmentStatus.retired &&
            _selectedStatus != EquipmentStatus.sold &&
            _selectedStatus != EquipmentStatus.wanted,
```

The parent id, serial and purchase date controllers and fields are untouched, so the saved item keeps them.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_wanted_test.dart test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart test/features/equipment/presentation/pages/equipment_edit_wanted_test.dart
git commit -m "feat(equipment): adapt the edit form to Wanted gear"
```

---

### Task 7: Detail header status and Mark as purchased

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_header_status.dart`
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (`EquipmentListNotifier`, after `reactivateEquipment`)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:492-505`
- Test: `test/features/equipment/presentation/widgets/equipment_header_status_test.dart` (create)

**Interfaces:**
- Consumes: `EquipmentRepository.markEquipmentPurchased` (Task 2), `l10n.equipment_detail_markPurchased`, `l10n.equipment_snackbar_purchased`.
- Produces: `class EquipmentHeaderStatus extends ConsumerWidget { const EquipmentHeaderStatus({super.key, required this.item}); }`; `Future<void> EquipmentListNotifier.markPurchased(String id)`; top-level `EquipmentStatus? headerStatusOf(EquipmentItem item)`.

- [ ] **Step 1: Write the failing tests** (create the file)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_header_status.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

EquipmentItem _item(EquipmentStatus status, {bool isActive = true}) =>
    EquipmentItem(
      id: 'x',
      name: 'x',
      type: EquipmentType.regulator,
      status: status,
      isActive: isActive,
    );

void main() {
  group('headerStatusOf', () {
    test('active gear gets no chip', () {
      expect(headerStatusOf(_item(EquipmentStatus.active)), isNull);
    });
    test('inactive gear names its own status', () {
      for (final s in [
        EquipmentStatus.sold,
        EquipmentStatus.lost,
        EquipmentStatus.wanted,
      ]) {
        expect(headerStatusOf(_item(s, isActive: false)), s, reason: '$s');
      }
    });
    test('a legacy inactive row reads as retired', () {
      expect(
        headerStatusOf(_item(EquipmentStatus.needsService, isActive: false)),
        EquipmentStatus.retired,
      );
    });
  });

  group('EquipmentHeaderStatus', () {
    late EquipmentRepository repository;
    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });
    tearDown(tearDownTestDatabase);

    Future<void> pump(WidgetTester tester, EquipmentItem item) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentRepositoryProvider.overrideWithValue(repository),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: EquipmentHeaderStatus(item: item)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sold gear shows Sold, not Retired', (tester) async {
      await pump(tester, _item(EquipmentStatus.sold, isActive: false));
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
      expect(find.text('Mark as purchased'), findsNothing);
    });

    testWidgets('wanted gear shows its chip and buys in one tap', (
      tester,
    ) async {
      final created = await repository.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Dream Reg',
          type: EquipmentType.regulator,
          status: EquipmentStatus.wanted,
          isActive: false,
        ),
      );
      await pump(tester, created);
      expect(find.text('Wanted'), findsOneWidget);

      await tester.tap(find.text('Mark as purchased'));
      await tester.pumpAndSettle();

      final stored = await repository.getEquipmentById(created.id);
      expect(stored!.status, EquipmentStatus.active);
      expect(stored.isActive, isTrue);
      expect(stored.purchaseDate, isNotNull);
      expect(find.text('Moved to your active gear'), findsOneWidget);
    });

    testWidgets('active gear renders nothing', (tester) async {
      await pump(tester, _item(EquipmentStatus.active));
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_header_status_test.dart`
Expected: compile error, the widget file does not exist.

- [ ] **Step 3: Add the notifier method** (`EquipmentListNotifier`)

```dart
  Future<void> markPurchased(String id) async {
    await _repository.markEquipmentPurchased(id);
    await refresh();
  }
```

`refresh()` invalidates the list, active, retired, all-equipment and clock providers but not the item itself, so the method also invalidates the detail page's item:

```dart
  Future<void> markPurchased(String id) async {
    await _repository.markEquipmentPurchased(id);
    _ref.invalidate(equipmentItemProvider(id));
    await refresh();
  }
```

(This replaces the three-line version above.)

- [ ] **Step 4: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The status an inactive item's header chip names, or null for gear in the
/// kit. Sold, Lost and Wanted (#2025) keep their own label; any other
/// inactive row is a legacy retirement (#636) and reads as Retired.
EquipmentStatus? headerStatusOf(EquipmentItem item) {
  if (item.isActive) return null;
  return switch (item.status) {
    EquipmentStatus.sold ||
    EquipmentStatus.lost ||
    EquipmentStatus.wanted => item.status,
    _ => EquipmentStatus.retired,
  };
}

/// The detail header's status line: a chip naming why the item is out of
/// the kit, and for wishlist gear a button that buys it (#2025).
class EquipmentHeaderStatus extends ConsumerWidget {
  const EquipmentHeaderStatus({super.key, required this.item});

  final EquipmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = headerStatusOf(item);
    if (status == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            status == EquipmentStatus.retired
                ? l10n.equipment_detail_retiredChip
                : status.localizedName(l10n),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
        if (status == EquipmentStatus.wanted)
          FilledButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(l10n.equipment_detail_markPurchased),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final message = l10n.equipment_snackbar_purchased;
              await ref
                  .read(equipmentListNotifierProvider.notifier)
                  .markPurchased(item.id);
              messenger.showSnackBar(SnackBar(content: Text(message)));
            },
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Use it in the detail page.** Replace the `if (!equipment.isActive) Chip(...)` block in `_buildHeaderSection` with:

```dart
                      // Why the item is out of the kit, and the purchase
                      // action for wishlist gear (#2025).
                      EquipmentHeaderStatus(item: equipment),
```

and import `equipment_header_status.dart`. Remove imports the page no longer uses (`flutter analyze` will name them).

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_header_status_test.dart test/features/equipment/presentation/pages/equipment_detail_page_test.dart test/features/equipment/presentation/pages/equipment_detail_tags_test.dart`
Expected: PASS. If an existing detail test asserted the old "Retired" chip on a sold item, update it to the correct label and note that in the commit body.

- [ ] **Step 7: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_header_status.dart lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/widgets/equipment_header_status_test.dart
git commit -m "feat(equipment): name an inactive item's real status and buy Wanted gear from its page"
```

---

### Task 8: Equipment summary

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart:114-176` and the preview call at ~199
- Test: `test/features/equipment/presentation/widgets/equipment_summary_wanted_test.dart` (create; `pumpSummary` harness copied from `equipment_summary_currency_test.dart`)

**Interfaces:**
- Consumes: `EquipmentItem.isWanted`, `l10n.enum_equipmentStatus_wanted`, `l10n.equipment_summary_wantedValue(String)`.

- [ ] **Step 1: Write the failing tests**

```dart
  EquipmentItem item(
    String id,
    double? price, {
    EquipmentStatus status = EquipmentStatus.active,
    String currency = 'USD',
  }) => EquipmentItem(
    id: id,
    name: 'Item $id',
    type: EquipmentType.regulator,
    status: status,
    isActive: status != EquipmentStatus.wanted,
    purchasePrice: price,
    purchaseCurrency: currency,
  );

  testWidgets('wanted gear stays out of the owned totals (#2025)', (
    tester,
  ) async {
    await pumpSummary(tester, [
      item('a', 300),
      item('w', 900, status: EquipmentStatus.wanted),
    ]);

    // Total Items counts owned gear only.
    final total = find.ancestor(
      of: find.text('Total Items'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: total.first, matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.text('Total Value (USD)'), findsOneWidget);
    expect(find.text('\$300'), findsOneWidget);
    expect(find.text('\$1200'), findsNothing);
  });

  testWidgets('wanted gear gets its own count and value cards', (
    tester,
  ) async {
    await pumpSummary(tester, [
      item('a', 300),
      item('w1', 900, status: EquipmentStatus.wanted),
      item('w2', 100, status: EquipmentStatus.wanted, currency: 'EUR'),
    ]);

    expect(find.text('Wanted'), findsOneWidget);
    expect(find.text('Wanted Value (USD)'), findsOneWidget);
    expect(find.text('Wanted Value (EUR)'), findsOneWidget);
    expect(find.text('\$900'), findsOneWidget);
  });

  testWidgets('no wishlist, no wanted cards', (tester) async {
    await pumpSummary(tester, [item('a', 300)]);

    expect(find.text('Wanted'), findsNothing);
    expect(find.textContaining('Wanted Value'), findsNothing);
  });
```

Check how `_buildStatCard` lays out value and label (read it before running) and adjust the Total Items finder to that structure if it is not a `Column`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_summary_wanted_test.dart`
Expected: FAIL (the total counts 2, and there is no Wanted card).

- [ ] **Step 3: Implement.** At the top of the stats block in `_buildOverview`:

```dart
    // Wishlist gear (#2025) is not owned: it gets its own count and value
    // cards and stays out of the kit's totals and recent list.
    final owned = [
      for (final e in equipment)
        if (!e.isWanted) e,
    ];
    final wanted = [
      for (final e in equipment)
        if (e.isWanted) e,
    ];
    final fallbackCurrency = ref.watch(defaultCurrencyProvider);
```

Count `activeCount` over `owned`; compute `totalsByCurrency` from `owned` (with `fallbackCode: fallbackCurrency`); add

```dart
    final wantedByCurrency = sumByCurrency<dynamic>(
      wanted,
      amountOf: (item) => item.purchasePrice as double?,
      currencyOf: (item) => item.purchaseCurrency as String,
      fallbackCode: fallbackCurrency,
    );
```

Use `'${owned.length}'` for Total Items. After the total value cards, inside the same `Wrap`:

```dart
            if (wanted.isNotEmpty)
              _buildStatCard(
                context,
                icon: Icons.shopping_bag_outlined,
                value: '${wanted.length}',
                label: context.l10n.enum_equipmentStatus_wanted,
                color: Colors.purple,
              ),
            for (final entry in wantedByCurrency)
              if (entry.value > 0)
                _buildStatCard(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  value:
                      '${currencySymbol(entry.key)}${entry.value.toStringAsFixed(0)}',
                  label: context.l10n.equipment_summary_wantedValue(entry.key),
                  color: Colors.purple,
                ),
```

Change the recent-list guard and call to `owned`: `if (owned.isNotEmpty) ... _buildEquipmentListPreview(context, owned)`.

Check `_buildStatCard`'s `color:` usage: if other cards pass raw `Colors.*` (they do: blue, green, orange), purple matches the existing pattern. If the theme work in this area has moved stat cards onto `StatusColors` or the color scheme by the time this runs, follow that instead.

- [ ] **Step 4: Run all summary tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_summary_wanted_test.dart test/features/equipment/presentation/widgets/equipment_summary_currency_test.dart test/features/equipment/presentation/widgets/equipment_summary_row_severity_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_summary_widget.dart test/features/equipment/presentation/widgets/equipment_summary_wanted_test.dart
git commit -m "feat(equipment): show the wishlist apart from owned gear in the summary"
```

---

### Task 9: Whole-branch verification

- [ ] **Step 1:** `dart format .` and confirm `git status` shows no unformatted changes left behind.
- [ ] **Step 2:** `flutter analyze` (whole project; infos are fatal in CI). Expected: No issues found.
- [ ] **Step 3:** `flutter test test/architecture/` (new file under `lib/`). Expected: PASS.
- [ ] **Step 4:** Run every test directory touched: `flutter test test/features/equipment test/features/cylinder_configs test/features/pre_dive test/features/dive_log/presentation/widgets/refine test/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section_test.dart test/features/cylinder_passports`. Expected: PASS.
- [ ] **Step 5:** `grep -rn "EquipmentStatus.sold" lib | grep -v wanted` and review each hit: any remaining place that special-cases Sold as "inactive but not retired" and is not yet handled for Wanted gets the same carve-out (with a test) as a follow-up commit inside this PR.
- [ ] **Step 6:** Scan the branch diff for em-dashes: `git diff $(git merge-base origin/main HEAD)..HEAD -- . ':!*.g.dart' | LC_ALL=C grep -n $'\xe2\x80\x94'` (the UTF-8 bytes of U+2014). Expected: no output.
- [ ] **Step 7:** Commit any formatting-only changes as `style: format`.
