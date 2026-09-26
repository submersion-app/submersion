# Cylinder Passports 1a: Passport Core Implementation Plan (PR 1 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tank equipment item can carry a passport id, log fills, and show a passport page (spec, buoyancy, service clocks, current fill with MOD and END, fill history, QR label) that reads every fact from the system that owns it.

**Architecture:** The passport id is an equipment attribute (no rung). Fills are a new top-level synced table `cylinder_fills` keyed by passport id, registered exactly like `transmitters`. The tag string is a versioned query payload built by a total codec; the same string feeds an on-screen QR painter and a PDF label. The passport page composes existing providers (item, service clocks, service records) with two new ones (passport id, fills) and a handful of pure metric functions.

**Tech Stack:** Flutter, Riverpod (hand-written providers), Drift with `build_runner`, `flutter gen-l10n` ARB localisation, `pdf` for the label, the transitive `qr` package for the on-screen code, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`, sections 5, 6, 8, 10.1, 10.2, 10.6 to 10.8, 14 (tag page), 15, 16 and the "1a Passport core" row of section 17. This plan covers PR 1a only. Scanning, routes for incoming links, the foreign passport and the tank editor Scan are PR 1b (#2335); NFC is PR 2; signed records are PR 3; the Trip card is PR 4; CSV is PR 5.

## Global Constraints

- Schema rung: `currentSchemaVersion` goes from 226 to 227. Before Task 6, run `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="`; if main has moved past 226, take the next free number and use it everywhere this plan says 227.
- `minimumCompatibleSchemaVersion` stays 224. This rung is additive.
- No backfill: no existing row changes in the migration.
- The stored attribute key is `passport_id`. The tag URL forms are exactly `https://submersion.app/c#<payload>` (written) and `submersion://c?<payload>` (accepted). Payload keys and their order: `f, p, w, n, sn, v, wp, m, vt, h, vi, oc`. Small-tag drop order: `n, sn, vi, h, oc, vt, m, wp, v`. Never drop `f`, `p`, `w`.
- The `cylinder_fills.source` column holds one of `manual`, `qr`, `nfc`, `file`, `link`, `issued`. Only `manual` is written in this PR.
- Every value with a unit is displayed through `UnitFormatter` (`formatVolume`, `formatPressure`, `formatWeight`, `formatDepth`, `formatTemperature`, `formatDate`). Never a hard-coded `DateFormat` in presentation code (`test/architecture/preference_aware_date_format_test.dart`).
- The service status sentence is composed only by `ServiceStatusIndicator`. The passport never calls `l10n.equipment_service_overdue`.
- New user-visible strings are translated in all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. Non-English ARB files are feature-grouped, not alphabetical: insert beside the anchor key each task names, never append.
- Never use em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens as punctuation, in code, comments, tests, ARB strings, commit messages or the PR body. The PDF's Helvetica has no glyph for U+2014 either.
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file. No `Co-Authored-By` trailer.
- No emojis in code, comments or docs. Immutability: never mutate a list or map passed in.
- TDD: write the failing test first, watch it fail, then implement.
- Run `dart format .` on the whole project before each commit. Run `flutter analyze` on its own, never piped (a pipe hides the exit status); infos are fatal in CI.
- Run specific test files per task; the full suite runs once, in Task 18. Never overlap two local `flutter test` runs.
- The Bash tool's working directory can reset; run every command from the worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/smart-cylinder-passports-60ca56` and stage explicit paths (`git add <path>`), never `git add -A` or `git add -u`.
- If the harness refuses a command because it contains the bare word `build` (a deny rule), write the command into `scratch_codegen.sh` in the session scratchpad directory and run that script instead.
- The PR body must contain `Closes #2334` and `Refs #2333`.

## Review Focus

Inputs the spec implies but no obvious test exercises, most likely to bite first. Each has its test pinned to the owning task.

1. A tag pasted with surrounding whitespace, a trailing slash after `/c`, or upper-case UUID hex: must still resolve (Task 3, "decode tolerates").
2. A name containing `&`, `#`, `=` or non-ASCII characters: must round-trip byte-exact through the payload, and must not break the query parser (Task 3, "round trips a hostile name").
3. Volume typed as `11,1` in a decimal-comma locale in the fill sheet: O2 and He are numbers too; the sheet parses with `,` accepted as a decimal point and rejects letters (Task 12, "accepts a decimal comma").
4. A fill logged with O2 40.5 while the O2 clean clock is absent: the warning must fire at the diver's threshold (`highO2Fraction` default 0.40 read as a fraction, so 40.5% > 40%), and must not fire at exactly 40.0 (Task 10, "boundary of the high-O2 threshold").
5. Deleting the cylinder then re-creating it and linking the old tag: fills must reappear on the new row with no duplicate rows (Task 8, "relink after delete keeps every fill once").

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (modify) | `AttributeGroup.system`, `EquipmentAttrKeys.passportId`, the tank catalog def |
| `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (modify) | label arm for `passport_id` |
| `lib/core/database/performance_indexes.dart` (modify) | `idx_equipment_attributes_key_text`, `idx_cylinder_fills_passport`, `idx_cylinder_fills_equipment` |
| `lib/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart` (create) | `CylinderPassportPayload`, `PassportValve` |
| `lib/features/cylinder_passports/domain/services/passport_payload_codec.dart` (create) | `PassportPayloadCodec`, `PassportDecodeResult` and friends |
| `lib/features/cylinder_passports/domain/services/ndef_fit.dart` (create) | `NdefFit`: NDEF size arithmetic and the drop order |
| `lib/features/cylinder_passports/domain/entities/cylinder_fill.dart` (create) | `CylinderFill`, `FillSource` |
| `lib/features/cylinder_passports/domain/services/passport_metrics.dart` (create) | pure spec metrics and gas limits |
| `lib/features/cylinder_passports/domain/services/passport_rules.dart` (create) | O2 clean warning, tag staleness, payload from an item |
| `lib/core/database/database.dart` (modify) | `CylinderFills` table, v227 rung, backstop, lists |
| `lib/core/data/repositories/sync_repository.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/services/sync/sync_data_serializer.dart` (modify) | sync registration |
| `lib/features/divers/data/repositories/diver_owned_rows.dart` (modify) | diver delete clears fills |
| `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` (create) | fills CRUD, relink, unlink |
| `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart` (create) | passport id read, mint, assign, lookup |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (modify, ~line 587) | unlink fills on equipment delete |
| `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart` (create) | repositories, `passportIdProvider`, `fillsForEquipmentProvider`, `newestFillProvider` |
| `lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart` (create) | manual fill entry |
| `lib/features/cylinder_passports/presentation/pages/passport_page.dart` (create) | the page shell and header |
| `lib/features/cylinder_passports/presentation/widgets/passport_spec_card.dart`, `passport_service_card.dart`, `passport_o2_warning_banner.dart`, `passport_current_fill_card.dart`, `passport_fill_history_card.dart`, `passport_tag_card.dart`, `passport_qr_view.dart`, `link_existing_tag_dialog.dart`, `passport_entry_card.dart` (create) | one card each |
| `lib/core/services/export/pdf/passport_label_pdf_export_service.dart` (create) | the label sheet PDF |
| `lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart` (create) | builds payloads for items and shares the PDF |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (modify) | "Print labels" bulk action |
| `lib/core/router/app_router.dart` (modify, ~line 622) | `passport` route under `equipmentDetail` |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (modify, ~line 200) | `PassportEntryCard` for tanks |
| `lib/l10n/arb/app_*.arb` (modify, 11 files) | new strings |
| `docs/import-formats/cylinder-passport-tag.md`, `docs/_sidebar.md` (create, modify) | the tag format page |
| `pubspec.yaml` (modify) | `qr: ^3.0.2` promoted from transitive to direct |

---

### Task 1: Worktree setup and a clean baseline

**Files:** none changed.

- [ ] **Step 1: Initialise the worktree**

Run, from the worktree root:

```bash
git submodule update --init --recursive && flutter pub get
```

Expected: both finish without error. (They already ran once for this worktree; re-running is harmless.)

- [ ] **Step 2: Run Drift codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: ends with `Succeeded after ...`. If the harness refuses the command, put it in `scratch_codegen.sh` in the scratchpad directory and run `bash <that path>` from the worktree root.

- [ ] **Step 3: Confirm the baseline analyses clean**

Run: `flutter analyze`
Expected: `No issues found!`. Hundreds of errors mean codegen did not run (step 2).

- [ ] **Step 4: Confirm the spec commit is present**

Run: `git log --oneline -1`
Expected: `fd16ae925b8 docs: smart cylinder passports design spec` (or a later commit on this branch). No commit for this task.

---

### Task 2: The `passport_id` attribute and its index

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (the `AttributeGroup` enum at lines 16 to 30, `EquipmentAttrKeys` at 56 to 93, the `EquipmentType.tank` list at 269 to 295)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (the `attributeLabel` switch)
- Modify: `lib/core/database/performance_indexes.dart` (after the `idx_equipment_attributes_key_num` entry at line 185)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart` (append), `test/features/equipment/presentation/equipment_attribute_l10n_test.dart` (existing, must stay green), `test/core/database/performance_indexes_test.dart` (existing, must stay green)

**Interfaces:**
- Produces: `AttributeGroup.system`; `EquipmentAttrKeys.passportId == 'passport_id'`; the tank catalog contains `EquipmentAttributeDef(key: 'passport_id', kind: AttributeKind.text, group: AttributeGroup.system)`; index `idx_equipment_attributes_key_text ON equipment_attributes(attr_key, value_text)`.

Why a group and not a hidden flag: the edit form mounts one `EquipmentAttributeFormSection` per group (`spec` at edit page line 487, `purchase` at 841), so a third group is rendered nowhere without any new conditional, and the save at edit page lines 1063 to 1072 keeps every key in `attributesFor(type)`, so the id survives an edit-page save.

- [ ] **Step 1: Write the failing catalog test**

Append to `test/features/equipment/domain/equipment_attribute_catalog_test.dart`, inside `main()`:

```dart
  group('passport id (issue #2334)', () {
    test('is a system attribute on tanks only', () {
      final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.passportId);
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.text);
      expect(def.group, AttributeGroup.system);
      expect(
        EquipmentAttributeCatalog.attributesFor(EquipmentType.tank),
        contains(def),
      );
      expect(
        EquipmentAttributeCatalog.attributesFor(EquipmentType.regulator)
            .map((d) => d.key),
        isNot(contains(EquipmentAttrKeys.passportId)),
      );
    });

    test('no spec or purchase consumer sees a system attribute', () {
      for (final type in EquipmentType.values) {
        final visible = EquipmentAttributeCatalog.attributesFor(type).where(
          (d) => d.group != AttributeGroup.system,
        );
        expect(
          visible.map((d) => d.key),
          isNot(contains(EquipmentAttrKeys.passportId)),
        );
      }
    });
  });
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: compile error, `passportId` and `system` are undefined.

- [ ] **Step 3: Add the group, the key and the def**

In `equipment_attribute_catalog.dart`, extend the enum:

```dart
enum AttributeGroup {
  /// What the item physically is: size, thickness, lift, buoyancy. The
  /// default, rendered with the type-specific fields.
  spec,

  /// Where the item came from: the receipt trail an insurer asks for after
  /// lost luggage, theft or fire (issue #1517). Rendered with purchase date
  /// and price.
  purchase,

  /// Written by the app, never by a form: identifiers a feature owns, such
  /// as a cylinder's passport id (issue #2334). No form section renders this
  /// group, and the detail page's spec rows skip it, but the edit page save
  /// keeps it because it is in the type's catalog.
  system,
}
```

In `EquipmentAttrKeys`, after the `identifier` constant:

```dart
  // The physical tag identity of a cylinder (issue #2334): a UUID minted
  // once, printed as a QR label and written to an NFC tag. System group,
  // so no form ever shows it as a text field.
  static const passportId = 'passport_id';
```

In the `EquipmentType.tank` list, after the `last_hydro_test` def:

```dart
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.passportId,
        kind: AttributeKind.text,
        group: AttributeGroup.system,
      ),
```

- [ ] **Step 4: Add the label in all 11 ARB files**

Every catalog key needs an `attrLabel_<key>` string (the coverage test in `equipment_attribute_l10n_test.dart` fails otherwise). Insert one line directly after each file's `"attrLabel_last_hydro_test"` line (the files are not alphabetical, so anchor on that key):

```
app_en.arb   "attrLabel_passport_id": "Passport id",
app_ar.arb   "attrLabel_passport_id": "معرّف جواز الأسطوانة",
app_de.arb   "attrLabel_passport_id": "Pass-ID",
app_es.arb   "attrLabel_passport_id": "ID de pasaporte",
app_fr.arb   "attrLabel_passport_id": "Identifiant de passeport",
app_he.arb   "attrLabel_passport_id": "מזהה דרכון",
app_hu.arb   "attrLabel_passport_id": "Útlevél-azonosító",
app_it.arb   "attrLabel_passport_id": "ID passaporto",
app_nl.arb   "attrLabel_passport_id": "Paspoort-id",
app_pt.arb   "attrLabel_passport_id": "ID do passaporte",
app_zh.arb   "attrLabel_passport_id": "护照标识",
```

Then in `equipment_attribute_l10n.dart`, add an arm to `attributeLabel` next to `'last_hydro_test'`:

```dart
    'passport_id' => l10n.attrLabel_passport_id,
```

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 5: Add the lookup index**

In `performance_indexes.dart`, after the `idx_equipment_attributes_key_num` entry:

```dart
  // Passport id lookup (issue #2334): a scanned tag resolves to the one
  // cylinder holding that value under attr_key = 'passport_id'.
  (
    name: 'idx_equipment_attributes_key_text',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_text '
        'ON equipment_attributes(attr_key, value_text)',
  ),
```

- [ ] **Step 6: Run the three test files**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/presentation/equipment_attribute_l10n_test.dart test/core/database/performance_indexes_test.dart`
Expected: all pass.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart lib/core/database/performance_indexes.dart lib/l10n/arb/ test/features/equipment/domain/equipment_attribute_catalog_test.dart
git commit -m "feat(equipment): passport_id system attribute on cylinders

Refs #2334"
```

---

### Task 3: The tag payload and its codec

**Files:**
- Create: `lib/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart`
- Create: `lib/features/cylinder_passports/domain/services/passport_payload_codec.dart`
- Test: `test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart`

**Interfaces:**
- Produces:
  - `enum PassportValve { din, yoke, convertible }` with `String get code` (`din`, `yoke`, `conv`) and `static PassportValve? fromCode(String?)`.
  - `class CylinderPassportPayload extends Equatable` with `const` constructor `({int formatVersion = 1, required String passportId, DateTime? writtenOn, String? name, String? serial, double? volumeL, int? workingPressureBar, TankMaterial? material, PassportValve? valve, DateTime? lastHydro, DateTime? lastVip, bool o2Clean = false})`, a `copyWith` with `clearX` flags for every nullable field, `static const currentFormatVersion = 1`, `static const maxNameLength = 40`.
  - `sealed class PassportDecodeResult`; `class PassportDecoded extends PassportDecodeResult { final CylinderPassportPayload payload; final bool newerFormat; }`; `class PassportRejected extends PassportDecodeResult { final PassportRejectReason reason; }`; `enum PassportRejectReason { notATag, missingId, malformedId }`.
  - `abstract final class PassportPayloadCodec` with `static const httpsPrefix = 'https://submersion.app/c'`, `static const schemePrefix = 'submersion://c'`, `static String encode(CylinderPassportPayload)` (bare query string), `static String httpsUrl(CylinderPassportPayload)`, `static PassportDecodeResult decode(String text)`, `static String formatDate(DateTime)` (`YYYY-MM-DD`), `static DateTime? parseDate(String?)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Steel 12 L',
    serial: 'AB12345',
    volumeL: 12,
    workingPressureBar: 232,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  group('encode', () {
    test('emits keys in the fixed order with metric values', () {
      expect(
        PassportPayloadCodec.encode(full),
        'f=1&p=$id&w=2026-09-25&n=Steel+12+L&sn=AB12345&v=12&wp=232'
        '&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1',
      );
    });

    test('omits absent optional keys and keeps one decimal of volume', () {
      final p = CylinderPassportPayload(
        passportId: id,
        writtenOn: DateTime(2026, 9, 25),
        volumeL: 11.1,
      );
      expect(PassportPayloadCodec.encode(p), 'f=1&p=$id&w=2026-09-25&v=11.1');
    });

    test('the https form carries the payload in the fragment', () {
      expect(
        PassportPayloadCodec.httpsUrl(full),
        startsWith('https://submersion.app/c#f=1&p=$id'),
      );
    });

    test('a full payload stays under 160 characters', () {
      expect(PassportPayloadCodec.httpsUrl(full).length, lessThan(160));
    });

    test('truncates a long name to 40 characters', () {
      final p = CylinderPassportPayload(passportId: id, name: 'x' * 50);
      final back = PassportPayloadCodec.decode(PassportPayloadCodec.encode(p));
      expect((back as PassportDecoded).payload.name, 'x' * 40);
    });
  });

  group('decode', () {
    test('round trips the full payload from the https form', () {
      final result = PassportPayloadCodec.decode(
        PassportPayloadCodec.httpsUrl(full),
      );
      expect(result, isA<PassportDecoded>());
      final decoded = result as PassportDecoded;
      expect(decoded.payload, full);
      expect(decoded.newerFormat, isFalse);
    });

    test('accepts the custom scheme with the payload in the query', () {
      final result = PassportPayloadCodec.decode(
        'submersion://c?${PassportPayloadCodec.encode(full)}',
      );
      expect((result as PassportDecoded).payload, full);
    });

    test('accepts a bare query string', () {
      final result = PassportPayloadCodec.decode('f=1&p=$id');
      expect((result as PassportDecoded).payload.passportId, id);
    });

    test('decode tolerates whitespace, a trailing slash and upper-case hex', () {
      final upper = id.toUpperCase();
      final result = PassportPayloadCodec.decode(
        '  https://submersion.app/c/#f=1&p=$upper \n',
      );
      expect((result as PassportDecoded).payload.passportId, id);
    });

    test('round trips a hostile name', () {
      const name = 'Bill & Ted #2 = Ärger';
      final p = CylinderPassportPayload(passportId: id, name: name);
      final back = PassportPayloadCodec.decode(PassportPayloadCodec.httpsUrl(p));
      expect((back as PassportDecoded).payload.name, name);
    });

    test('ignores unknown keys and flags a newer format', () {
      final result = PassportPayloadCodec.decode('f=2&p=$id&zz=9');
      final decoded = result as PassportDecoded;
      expect(decoded.newerFormat, isTrue);
      expect(decoded.payload.passportId, id);
    });

    test('a missing f reads as format 1', () {
      final result = PassportPayloadCodec.decode('p=$id');
      expect((result as PassportDecoded).payload.formatVersion, 1);
    });

    test('rejects text that is not a tag', () {
      final result = PassportPayloadCodec.decode('https://example.com/x');
      expect((result as PassportRejected).reason, PassportRejectReason.notATag);
    });

    test('rejects a missing or malformed id', () {
      expect(
        (PassportPayloadCodec.decode('f=1&w=2026-01-01') as PassportRejected)
            .reason,
        PassportRejectReason.missingId,
      );
      expect(
        (PassportPayloadCodec.decode('f=1&p=not-a-uuid') as PassportRejected)
            .reason,
        PassportRejectReason.malformedId,
      );
    });

    test('drops out-of-range numbers and bad dates instead of trusting them', () {
      final result = PassportPayloadCodec.decode(
        'f=1&p=$id&v=99&wp=20&h=2024-13-40&m=xx&vt=zz',
      );
      final payload = (result as PassportDecoded).payload;
      expect(payload.volumeL, isNull);
      expect(payload.workingPressureBar, isNull);
      expect(payload.lastHydro, isNull);
      expect(payload.material, isNull);
      expect(payload.valve, isNull);
    });

    test('keeps in-range boundaries', () {
      final result = PassportPayloadCodec.decode('f=1&p=$id&v=0.5&wp=400');
      final payload = (result as PassportDecoded).payload;
      expect(payload.volumeL, 0.5);
      expect(payload.workingPressureBar, 400);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart`
Expected: compile errors, the files do not exist.

- [ ] **Step 3: Create the entity**

Create `lib/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Valve fitting, as the tag spells it.
enum PassportValve {
  din('din'),
  yoke('yoke'),
  convertible('conv');

  final String code;
  const PassportValve(this.code);

  static PassportValve? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// What a cylinder's tag says about it (spec section 6.2).
///
/// A snapshot written when the label was printed or the NFC tag written.
/// Only [passportId] identifies the cylinder; every other field is what the
/// diver's record looked like on [writtenOn], so the passport compares them
/// with the live row and reports a stale tag. All values are metric.
class CylinderPassportPayload extends Equatable {
  static const int currentFormatVersion = 1;
  static const int maxNameLength = 40;

  final int formatVersion;
  final String passportId;
  final DateTime? writtenOn;
  final String? name;
  final String? serial;
  final double? volumeL;
  final int? workingPressureBar;
  final TankMaterial? material;
  final PassportValve? valve;
  final DateTime? lastHydro;
  final DateTime? lastVip;
  final bool o2Clean;

  const CylinderPassportPayload({
    this.formatVersion = currentFormatVersion,
    required this.passportId,
    this.writtenOn,
    this.name,
    this.serial,
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.valve,
    this.lastHydro,
    this.lastVip,
    this.o2Clean = false,
  });

  CylinderPassportPayload copyWith({
    int? formatVersion,
    String? passportId,
    DateTime? writtenOn,
    bool clearWrittenOn = false,
    String? name,
    bool clearName = false,
    String? serial,
    bool clearSerial = false,
    double? volumeL,
    bool clearVolumeL = false,
    int? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? material,
    bool clearMaterial = false,
    PassportValve? valve,
    bool clearValve = false,
    DateTime? lastHydro,
    bool clearLastHydro = false,
    DateTime? lastVip,
    bool clearLastVip = false,
    bool? o2Clean,
  }) => CylinderPassportPayload(
    formatVersion: formatVersion ?? this.formatVersion,
    passportId: passportId ?? this.passportId,
    writtenOn: clearWrittenOn ? null : (writtenOn ?? this.writtenOn),
    name: clearName ? null : (name ?? this.name),
    serial: clearSerial ? null : (serial ?? this.serial),
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    material: clearMaterial ? null : (material ?? this.material),
    valve: clearValve ? null : (valve ?? this.valve),
    lastHydro: clearLastHydro ? null : (lastHydro ?? this.lastHydro),
    lastVip: clearLastVip ? null : (lastVip ?? this.lastVip),
    o2Clean: o2Clean ?? this.o2Clean,
  );

  @override
  List<Object?> get props => [
    formatVersion,
    passportId,
    writtenOn,
    name,
    serial,
    volumeL,
    workingPressureBar,
    material,
    valve,
    lastHydro,
    lastVip,
    o2Clean,
  ];
}
```

- [ ] **Step 4: Create the codec**

Create `lib/features/cylinder_passports/domain/services/passport_payload_codec.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// Why a scanned or pasted string is not a cylinder tag.
enum PassportRejectReason { notATag, missingId, malformedId }

sealed class PassportDecodeResult {
  const PassportDecodeResult();
}

class PassportDecoded extends PassportDecodeResult {
  final CylinderPassportPayload payload;

  /// The tag's format version is newer than this app knows. Every known key
  /// was read; the caller may say so.
  final bool newerFormat;
  const PassportDecoded(this.payload, {this.newerFormat = false});
}

class PassportRejected extends PassportDecodeResult {
  final PassportRejectReason reason;
  const PassportRejected(this.reason);
}

/// The tag string (spec section 6): one query-string payload carried as the
/// fragment of the https form or the query of the custom scheme.
///
/// Total: [decode] never throws on a tag. Unknown keys are ignored so a
/// future format still opens; out-of-range numbers and bad dates are dropped
/// rather than trusted.
abstract final class PassportPayloadCodec {
  static const String httpsPrefix = 'https://submersion.app/c';
  static const String schemePrefix = 'submersion://c';

  /// Emission order. Two devices must produce the same string for the same
  /// cylinder.
  static const List<String> keyOrder = [
    'f',
    'p',
    'w',
    'n',
    'sn',
    'v',
    'wp',
    'm',
    'vt',
    'h',
    'vi',
    'oc',
  ];

  static const double minVolumeL = 0.5;
  static const double maxVolumeL = 50;
  static const int minPressureBar = 50;
  static const int maxPressureBar = 400;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// A local calendar date, or null for anything that is not `YYYY-MM-DD`
  /// naming a real day.
  static DateTime? parseDate(String? text) {
    if (text == null) return null;
    final m = _date.firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, mo, d);
    if (date.month != mo || date.day != d) return null;
    return date;
  }

  static String _materialCode(TankMaterial m) => switch (m) {
    TankMaterial.aluminum => 'al',
    TankMaterial.steel => 'st',
    TankMaterial.carbonFiber => 'cf',
  };

  static TankMaterial? _material(String? code) => switch (code) {
    'al' => TankMaterial.aluminum,
    'st' => TankMaterial.steel,
    'cf' => TankMaterial.carbonFiber,
    _ => null,
  };

  static String _volume(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  /// The bare query string, keys in [keyOrder], values percent-encoded.
  static String encode(CylinderPassportPayload p) {
    final name = p.name;
    final values = <String, String?>{
      'f': p.formatVersion.toString(),
      'p': p.passportId,
      'w': p.writtenOn == null ? null : formatDate(p.writtenOn!),
      'n': name == null
          ? null
          : (name.length > CylinderPassportPayload.maxNameLength
                ? name.substring(0, CylinderPassportPayload.maxNameLength)
                : name),
      'sn': p.serial,
      'v': p.volumeL == null ? null : _volume(p.volumeL!),
      'wp': p.workingPressureBar?.toString(),
      'm': p.material == null ? null : _materialCode(p.material!),
      'vt': p.valve?.code,
      'h': p.lastHydro == null ? null : formatDate(p.lastHydro!),
      'vi': p.lastVip == null ? null : formatDate(p.lastVip!),
      'oc': p.o2Clean ? '1' : null,
    };
    return [
      for (final key in keyOrder)
        if (values[key] case final value? when value.isNotEmpty)
          '$key=${Uri.encodeQueryComponent(value)}',
    ].join('&');
  }

  static String httpsUrl(CylinderPassportPayload p) => '$httpsPrefix#${encode(p)}';

  /// The payload part of [text], or null when [text] is not a tag in either
  /// URL form and not a bare query string.
  static String? extractQuery(String text) {
    var s = text.trim();
    String? rest;
    if (s.startsWith(httpsPrefix)) {
      rest = s.substring(httpsPrefix.length);
    } else if (s.startsWith(schemePrefix)) {
      rest = s.substring(schemePrefix.length);
    }
    if (rest != null) {
      if (rest.startsWith('/')) rest = rest.substring(1);
      final hash = rest.indexOf('#');
      if (hash >= 0) return rest.substring(hash + 1);
      final q = rest.indexOf('?');
      if (q >= 0) return rest.substring(q + 1);
      return rest.isEmpty ? null : rest;
    }
    // A bare payload: the first pair must be a known key.
    final firstKey = s.split('&').first.split('=').first;
    if (s.contains('=') && keyOrder.contains(firstKey)) return s;
    return null;
  }

  static PassportDecodeResult decode(String text) {
    final query = extractQuery(text);
    if (query == null) {
      return const PassportRejected(PassportRejectReason.notATag);
    }
    final Map<String, String> pairs;
    try {
      pairs = Uri.splitQueryString(query);
    } on FormatException {
      return const PassportRejected(PassportRejectReason.notATag);
    }
    final rawId = pairs['p'];
    if (rawId == null || rawId.isEmpty) {
      return const PassportRejected(PassportRejectReason.missingId);
    }
    final id = rawId.toLowerCase();
    if (!_uuid.hasMatch(id)) {
      return const PassportRejected(PassportRejectReason.malformedId);
    }
    final format =
        int.tryParse(pairs['f'] ?? '') ??
        CylinderPassportPayload.currentFormatVersion;

    final volume = double.tryParse(pairs['v'] ?? '');
    final pressure = int.tryParse(pairs['wp'] ?? '');
    final name = pairs['n'];

    final payload = CylinderPassportPayload(
      formatVersion: format,
      passportId: id,
      writtenOn: parseDate(pairs['w']),
      name: name == null || name.isEmpty
          ? null
          : (name.length > CylinderPassportPayload.maxNameLength
                ? name.substring(0, CylinderPassportPayload.maxNameLength)
                : name),
      serial: (pairs['sn'] ?? '').isEmpty ? null : pairs['sn'],
      volumeL: volume != null && volume >= minVolumeL && volume <= maxVolumeL
          ? volume
          : null,
      workingPressureBar:
          pressure != null &&
              pressure >= minPressureBar &&
              pressure <= maxPressureBar
          ? pressure
          : null,
      material: _material(pairs['m']),
      valve: PassportValve.fromCode(pairs['vt']),
      lastHydro: parseDate(pairs['h']),
      lastVip: parseDate(pairs['vi']),
      o2Clean: pairs['oc'] == '1',
    );
    return PassportDecoded(
      payload,
      newerFormat: format > CylinderPassportPayload.currentFormatVersion,
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart`
Expected: all pass. If "emits keys in the fixed order" fails on `+` versus `%20`, keep `Uri.encodeQueryComponent` (it emits `+` for a space, and `Uri.splitQueryString` reads `+` back as a space); fix the expectation only if the implementation differs from the one above.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart lib/features/cylinder_passports/domain/services/passport_payload_codec.dart test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart
git commit -m "feat(passports): tag payload entity and codec

Refs #2334"
```

---

### Task 4: NDEF size arithmetic and the small-tag drop order

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/ndef_fit.dart`
- Test: `test/features/cylinder_passports/domain/services/ndef_fit_test.dart`

**Interfaces:**
- Consumes: `CylinderPassportPayload`, `PassportPayloadCodec.httpsUrl`.
- Produces: `abstract final class NdefFit` with `static const List<String> dropOrder = ['n','sn','vi','h','oc','vt','m','wp','v']`, `static const int ntag213Bytes = 144`, `ntag215Bytes = 504`, `ntag216Bytes = 888`, `static int uriRecordMessageBytes(String url)`, `static CylinderPassportPayload drop(CylinderPassportPayload p, String key)`, `static CylinderPassportPayload? fit(CylinderPassportPayload p, int capacityBytes)` (null when even `f`, `p`, `w` do not fit). PR 2 (NFC) consumes `fit`.

Size model, documented in the file: a Type 2 tag stores the NDEF message inside a TLV block: 2 bytes of TLV header when the message is under 255 bytes (4 otherwise) and a 1-byte terminator. One short URI record costs 4 bytes of header when its payload is at most 255 bytes (7 otherwise) plus the payload: 1 prefix byte for `https://` and the rest of the URL.

- [ ] **Step 1: Write the failing tests**

Create `test/features/cylinder_passports/domain/services/ndef_fit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Steel 12 L',
    serial: 'AB12345',
    volumeL: 12,
    workingPressureBar: 232,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  test('a short https URL costs header, prefix byte and the rest', () {
    // 'https://submersion.app/c#f=1' is 28 chars; minus 'https://' is 20,
    // plus the prefix byte is 21 of payload; record header 4; TLV 2 + 1.
    expect(NdefFit.uriRecordMessageBytes('https://submersion.app/c#f=1'), 28);
  });

  test('a payload over 255 bytes pays the long record and TLV headers', () {
    final url = 'https://submersion.app/c#${'x' * 260}';
    // payload 1 + 16 + 260 = 277; header 7; TLV 4 + 1.
    expect(NdefFit.uriRecordMessageBytes(url), 289);
  });

  test('the full payload fits NTAG215 and NTAG216 but not NTAG213', () {
    expect(NdefFit.fit(full, NdefFit.ntag216Bytes), full);
    expect(NdefFit.fit(full, NdefFit.ntag215Bytes), full);
    final small = NdefFit.fit(full, NdefFit.ntag213Bytes);
    expect(small, isNotNull);
    expect(small, isNot(full));
    expect(small!.passportId, id);
    expect(small.writtenOn, full.writtenOn);
    expect(
      NdefFit.uriRecordMessageBytes(PassportPayloadCodec.httpsUrl(small)),
      lessThanOrEqualTo(NdefFit.ntag213Bytes),
    );
  });

  test('drops keys in the fixed order, name first, volume last', () {
    var p = full;
    final seen = <String>[];
    for (final key in NdefFit.dropOrder) {
      final next = NdefFit.drop(p, key);
      expect(next, isNot(p), reason: 'dropping $key changed nothing');
      seen.add(key);
      p = next;
    }
    expect(seen, NdefFit.dropOrder);
    expect(p.name, isNull);
    expect(p.volumeL, isNull);
    expect(p.passportId, id);
  });

  test('fit keeps the earliest surviving suffix of the order', () {
    // Enough room for everything but the name and serial.
    final withoutName = NdefFit.drop(NdefFit.drop(full, 'n'), 'sn');
    final budget = NdefFit.uriRecordMessageBytes(
      PassportPayloadCodec.httpsUrl(withoutName),
    );
    expect(NdefFit.fit(full, budget), withoutName);
  });

  test('returns null when even the identity does not fit', () {
    expect(NdefFit.fit(full, 40), isNull);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/domain/services/ndef_fit_test.dart`
Expected: compile error, `NdefFit` undefined.

- [ ] **Step 3: Implement**

Create `lib/features/cylinder_passports/domain/services/ndef_fit.dart`:

```dart
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// Fits a tag payload into an NFC tag's user memory (spec section 6.4).
///
/// Size model for a Type 2 tag (NTAG21x): the NDEF message sits in a TLV
/// block, 2 bytes of header under 255 bytes of message and 4 above, plus a
/// 1-byte terminator. One short URI record costs 4 bytes of header when its
/// payload is at most 255 bytes and 7 above, plus the payload: one prefix
/// byte standing for `https://` and the rest of the URL as UTF-8.
abstract final class NdefFit {
  static const int ntag213Bytes = 144;
  static const int ntag215Bytes = 504;
  static const int ntag216Bytes = 888;

  /// Optional keys, dropped first to last until the record fits. `f`, `p`
  /// and `w` are never dropped.
  static const List<String> dropOrder = [
    'n',
    'sn',
    'vi',
    'h',
    'oc',
    'vt',
    'm',
    'wp',
    'v',
  ];

  static const String _httpsPrefix = 'https://';

  /// Bytes an NDEF message holding one URI record of [url] takes on the tag.
  static int uriRecordMessageBytes(String url) {
    final body = url.startsWith(_httpsPrefix)
        ? url.substring(_httpsPrefix.length)
        : url;
    final payload = 1 + body.codeUnits.length;
    final record = (payload <= 255 ? 4 : 7) + payload;
    final tlv = record < 255 ? 2 : 4;
    return tlv + record + 1;
  }

  static CylinderPassportPayload drop(CylinderPassportPayload p, String key) =>
      switch (key) {
        'n' => p.copyWith(clearName: true),
        'sn' => p.copyWith(clearSerial: true),
        'vi' => p.copyWith(clearLastVip: true),
        'h' => p.copyWith(clearLastHydro: true),
        'oc' => p.copyWith(o2Clean: false),
        'vt' => p.copyWith(clearValve: true),
        'm' => p.copyWith(clearMaterial: true),
        'wp' => p.copyWith(clearWorkingPressureBar: true),
        'v' => p.copyWith(clearVolumeL: true),
        _ => p,
      };

  /// The largest payload, in drop order, whose https URL fits
  /// [capacityBytes]; null when the identity alone does not.
  static CylinderPassportPayload? fit(
    CylinderPassportPayload p,
    int capacityBytes,
  ) {
    var current = p;
    var i = 0;
    while (true) {
      final bytes = uriRecordMessageBytes(PassportPayloadCodec.httpsUrl(current));
      if (bytes <= capacityBytes) return current;
      if (i >= dropOrder.length) return null;
      current = drop(current, dropOrder[i]);
      i++;
    }
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/cylinder_passports/domain/services/ndef_fit_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/ndef_fit.dart test/features/cylinder_passports/domain/services/ndef_fit_test.dart
git commit -m "feat(passports): NDEF size model and the small-tag drop order

Refs #2334"
```

---

### Task 5: The `CylinderFill` entity

**Files:**
- Create: `lib/features/cylinder_passports/domain/entities/cylinder_fill.dart`
- Test: `test/features/cylinder_passports/domain/entities/cylinder_fill_test.dart`

**Interfaces:**
- Produces: `enum FillSource { manual, qr, nfc, file, link, issued }` with `static FillSource fromName(String?)` (unknown falls back to `manual`); `class CylinderFill extends Equatable` with `const` constructor `({required String id, String? diverId, required String passportId, String? equipmentId, required DateTime filledAt, required double o2Percent, double hePercent = 0, double? pressureBar, double? temperatureC, String? analyzer, String? stationName, String? stationKey, String? signedRecord, FillSource source = FillSource.manual, String notes = '', required DateTime createdAt, required DateTime updatedAt})`, `GasMix get gasMix`, `bool get isSigned`, a `copyWith` with clear flags, `props` excluding `createdAt` and `updatedAt`.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/domain/entities/cylinder_fill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

void main() {
  final now = DateTime(2026, 9, 25, 14, 3);
  final fill = CylinderFill(
    id: 'fill-1',
    passportId: 'p-1',
    equipmentId: 'eq-1',
    filledAt: now,
    o2Percent: 32,
    pressureBar: 220,
    stationName: 'Blue Water Fills',
    createdAt: now,
    updatedAt: now,
  );

  test('exposes the mix as a GasMix', () {
    expect(fill.gasMix.name, 'EAN32');
    expect(fill.isSigned, isFalse);
  });

  test('copyWith clears nullable fields on request', () {
    final cleared = fill.copyWith(clearEquipmentId: true, clearPressureBar: true);
    expect(cleared.equipmentId, isNull);
    expect(cleared.pressureBar, isNull);
    expect(cleared.stationName, 'Blue Water Fills');
  });

  test('equality ignores timestamps', () {
    final later = fill.copyWith(updatedAt: now.add(const Duration(hours: 1)));
    expect(later, fill);
  });

  test('an unknown source name reads as manual', () {
    expect(FillSource.fromName('teleport'), FillSource.manual);
    expect(FillSource.fromName('issued'), FillSource.issued);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/domain/entities/cylinder_fill_test.dart`
Expected: compile error.

- [ ] **Step 3: Create the entity**

Create `lib/features/cylinder_passports/domain/entities/cylinder_fill.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// How a fill record reached this database (spec section 10.2).
enum FillSource {
  manual,
  qr,
  nfc,
  file,
  link,
  issued;

  static FillSource fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return FillSource.manual;
  }
}

/// One fill of one physical cylinder, keyed by its passport id rather than
/// its equipment row so the history survives a deleted and re-created item
/// and can belong to a cylinder the diver does not own.
///
/// When [signedRecord] is present the analysis fields are copies of the
/// verified payload; the token is the truth. Verification is never stored
/// (spec section 10.2).
class CylinderFill extends Equatable {
  final String id;
  final String? diverId;
  final String passportId;
  final String? equipmentId;
  final DateTime filledAt;
  final double o2Percent;
  final double hePercent;
  final double? pressureBar;
  final double? temperatureC;
  final String? analyzer;
  final String? stationName;
  final String? stationKey;
  final String? signedRecord;
  final FillSource source;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderFill({
    required this.id,
    this.diverId,
    required this.passportId,
    this.equipmentId,
    required this.filledAt,
    required this.o2Percent,
    this.hePercent = 0,
    this.pressureBar,
    this.temperatureC,
    this.analyzer,
    this.stationName,
    this.stationKey,
    this.signedRecord,
    this.source = FillSource.manual,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  GasMix get gasMix => GasMix(o2: o2Percent, he: hePercent);

  bool get isSigned => signedRecord != null && signedRecord!.isNotEmpty;

  CylinderFill copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? passportId,
    String? equipmentId,
    bool clearEquipmentId = false,
    DateTime? filledAt,
    double? o2Percent,
    double? hePercent,
    double? pressureBar,
    bool clearPressureBar = false,
    double? temperatureC,
    bool clearTemperatureC = false,
    String? analyzer,
    bool clearAnalyzer = false,
    String? stationName,
    bool clearStationName = false,
    String? stationKey,
    bool clearStationKey = false,
    String? signedRecord,
    bool clearSignedRecord = false,
    FillSource? source,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderFill(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    passportId: passportId ?? this.passportId,
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    filledAt: filledAt ?? this.filledAt,
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    pressureBar: clearPressureBar ? null : (pressureBar ?? this.pressureBar),
    temperatureC: clearTemperatureC
        ? null
        : (temperatureC ?? this.temperatureC),
    analyzer: clearAnalyzer ? null : (analyzer ?? this.analyzer),
    stationName: clearStationName ? null : (stationName ?? this.stationName),
    stationKey: clearStationKey ? null : (stationKey ?? this.stationKey),
    signedRecord: clearSignedRecord
        ? null
        : (signedRecord ?? this.signedRecord),
    source: source ?? this.source,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors Transmitter.
  @override
  List<Object?> get props => [
    id,
    diverId,
    passportId,
    equipmentId,
    filledAt,
    o2Percent,
    hePercent,
    pressureBar,
    temperatureC,
    analyzer,
    stationName,
    stationKey,
    signedRecord,
    source,
    notes,
  ];
}
```

- [ ] **Step 4: Run the test, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/domain/entities/cylinder_fill_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/entities/cylinder_fill.dart test/features/cylinder_passports/domain/entities/cylinder_fill_test.dart
git commit -m "feat(passports): CylinderFill entity

Refs #2334"
```

---

### Task 6: Schema rung v227, the `cylinder_fills` table

**Files:**
- Modify: `lib/core/database/database.dart` (table after `Transmitters` at ~line 3222; `@DriftDatabase` tables list end at ~line 4283; `currentSchemaVersion` at ~4298; `migrationVersions` end at ~4954; assert helper beside `_assertDiveCenterGearNotesSchema` at ~8509; `onUpgrade` tail at ~12546; `beforeOpen` backstop beside the v226 one at ~13043)
- Modify: `lib/core/database/performance_indexes.dart` (append two entries)
- Modify: `lib/features/divers/data/repositories/diver_owned_rows.dart` (after the `transmitters` entry at line 48)
- Modify: `test/core/database/migration_v226_media_cloud_asset_id_test.dart` (lines 48 to 55, relax)
- Modify: `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart` (seeder map at ~line 197 and `_clearedByDelete` at ~line 711)
- Create: `test/core/database/migration_v227_cylinder_fills_test.dart`

**Interfaces:**
- Produces: Drift table `CylinderFills` (`@DataClassName('CylinderFillRow')`, generated companion `CylinderFillsCompanion`, accessor `db.cylinderFills`) with columns `id, diver_id, passport_id, equipment_id, filled_at, o2_percent, he_percent, pressure_bar, temperature_c, analyzer, station_name, station_key, signed_record, source, notes, created_at, updated_at, hlc`; `AppDatabase.currentSchemaVersion == 227`; `_assertCylinderFillsSchema()`.

- [ ] **Step 1: Check the rung number against main**

Run: `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="`
Expected: `226`. If higher, substitute the next free number for every `227` below.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v227_cylinder_fills_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v227: cylinder fill history, the cylinder_fills table
/// (issue #2334).
void main() {
  /// A v226 database with the two parents the new table references and no
  /// cylinder_fills.
  NativeDatabase setupDb({int userVersion = 226, bool withEquipment = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        if (withEquipment) {
          rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        }
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v227 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 227);
    expect(AppDatabase.migrationVersions, contains(227));
    expect(AppDatabase.migrationStepCount(226), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds the cylinder_fills table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'cylinder_fills'),
      containsAll(<String>[
        'id',
        'diver_id',
        'passport_id',
        'equipment_id',
        'filled_at',
        'o2_percent',
        'he_percent',
        'pressure_bar',
        'temperature_c',
        'analyzer',
        'station_name',
        'station_key',
        'signed_record',
        'source',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('a deleted cylinder clears the link instead of failing on it', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final ddl = await ddlOf(db, 'table', 'cylinder_fills');
    expect(ddl, contains('REFERENCES equipment (id) ON DELETE SET NULL'));
  });

  test('creates both lookup indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(
      await indexNames(db),
      containsAll(<String>[
        'idx_cylinder_fills_passport',
        'idx_cylinder_fills_equipment',
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'cylinder_fills'),
      await tableInfo(fresh, 'cylinder_fills'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'cylinder_fills'),
      await ddlOf(fresh, 'table', 'cylinder_fills'),
    );
  });

  test('a database stamped v227 without the table heals in beforeOpen', () async {
    final db = AppDatabase(setupDb(userVersion: 227));
    addTearDown(db.close);

    expect(await columnsOf(db, 'cylinder_fills'), contains('passport_id'));
  });

  test('a fixture without equipment skips the table', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'cylinder_fills'), isEmpty);
  });
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/core/database/migration_v227_cylinder_fills_test.dart`
Expected: the version test fails (226 is not 227) and the table tests fail.

- [ ] **Step 4: Add the table**

In `database.dart`, directly after the `Transmitters` class (after its closing brace at ~line 3222):

```dart
/// Cylinder fill history (issue #2334, v227). One row per fill of one
/// physical cylinder, keyed by the cylinder's passport id (an equipment
/// attribute, not a foreign key) so the history survives a deleted and
/// re-created item and can belong to a cylinder the diver does not own.
/// [equipmentId] is a convenience link resolved from the passport id at write
/// time and re-resolved by "Link an existing tag". Synced entity with its own
/// hlc, registered like [Transmitters].
@DataClassName('CylinderFillRow')
class CylinderFills extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get passportId => text()();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get filledAt => integer()();
  RealColumn get o2Percent => real()();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  RealColumn get pressureBar => real().nullable()();
  RealColumn get temperatureC => real().nullable()();
  TextColumn get analyzer => text().nullable()();
  TextColumn get stationName => text().nullable()();
  // base64url Ed25519 public key from a signed record (PR 3); null for a
  // manual fill.
  TextColumn get stationKey => text().nullable()();
  // The JWS token verbatim (PR 3); the truth for every analysis column.
  TextColumn get signedRecord => text().nullable()();
  // FillSource.name: manual, qr, nfc, file, link, issued.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add `CylinderFills,` to the `@DriftDatabase(tables: [...])` list after `DiveCenterGearNotes,` with the comment `// Cylinder fill history (v227, issue #2334)`.

- [ ] **Step 5: Bump the version and the ladder**

Change `static const int currentSchemaVersion = 226;` to `227`. Append to `migrationVersions` after `226,`:

```dart
    // v227: cylinder_fills, the fill history keyed by passport id (issue
    // #2334). Table-only rung, no backfill, floor stays at 224.
    227,
```

- [ ] **Step 6: Add the assert helper, the rung and the backstop**

Beside `_assertDiveCenterGearNotesSchema` add:

```dart
  /// Idempotent creation of the v227 `cylinder_fills` table and its two
  /// lookup indexes (issue #2334). Called from the v227 rung and the
  /// beforeOpen backstop. Skipped on a partial migration-test fixture that
  /// lacks either parent table.
  Future<void> _assertCylinderFillsSchema() async {
    for (final parent in const ['divers', 'equipment']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await createMigrator().createTable(cylinderFills);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_passport '
      'ON cylinder_fills(passport_id, filled_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_equipment '
      'ON cylinder_fills(equipment_id)',
    );
  }
```

In `onUpgrade`, after the `if (from < 226) await reportProgress();` line:

```dart
        // v227: cylinder fill history (issue #2334). Table-only rung, no
        // backfill.
        if (from < 227) {
          await _assertCylinderFillsSchema();
        }
        if (from < 227) await reportProgress();
```

In `beforeOpen`, after the v226 backstop:

```dart
        // v227 backstop: the cylinder_fills table (parallel-branch
        // version-collision self-heal; createTable is idempotent).
        await _assertCylinderFillsSchema();
```

- [ ] **Step 7: Register the indexes in `performance_indexes.dart`**

Append two entries to `kPerformanceIndexes` (before the closing `];`):

```dart
  // Cylinder fill history (v227, issue #2334): newest fill per passport, and
  // the fills of one gear row.
  (
    name: 'idx_cylinder_fills_passport',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_passport '
        'ON cylinder_fills(passport_id, filled_at)',
  ),
  (
    name: 'idx_cylinder_fills_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_equipment '
        'ON cylinder_fills(equipment_id)',
  ),
```

- [ ] **Step 8: Diver delete clears fills**

In `lib/features/divers/data/repositories/diver_owned_rows.dart`, after the `transmitters` entry (line 48 to 53), add:

```dart
  (
    table: 'cylinder_fills',
    entityType: 'cylinderFills',
    hasBuiltIns: false,
    children: [],
  ),
```

In `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`, add a seeder next to `'a transmitter'`:

```dart
    'a cylinder fill': () async {
      await db
          .into(db.cylinderFills)
          .insert(
            CylinderFillsCompanion.insert(
              id: 'fill-a',
              passportId: 'pp-a',
              filledAt: stale,
              o2Percent: 32,
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('cylinder_fills', 'cylinderFills', 'fill-a')];
    },
```

and add `'cylinder_fills',` to `const _clearedByDelete = {...}`.

- [ ] **Step 9: Relax the v226 test**

In `test/core/database/migration_v226_media_cloud_asset_id_test.dart` lines 48 to 55, change the exact assertions to:

```dart
  test('v226 is at or below the current schema version and in the ladder', () {
    // Relaxed once v227 (cylinder fills) landed on top; the newest rung owns
    // the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(226));
    expect(AppDatabase.migrationVersions, contains(226));
    expect(AppDatabase.migrationStepCount(225), greaterThanOrEqualTo(1));
  });
```

- [ ] **Step 10: Codegen and run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs` (scratch script if refused)
Expected: `Succeeded`.

Run: `flutter test test/core/database/migration_v227_cylinder_fills_test.dart test/core/database/migration_v226_media_cloud_asset_id_test.dart test/core/database/performance_indexes_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`
Expected: all pass. The sync guard tests (`sync_hlc_target_registration_test`, `sync_parent_refs_completeness_test`) will now be red until Task 7; do not run them yet.

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/database/performance_indexes.dart lib/features/divers/data/repositories/diver_owned_rows.dart test/core/database/migration_v227_cylinder_fills_test.dart test/core/database/migration_v226_media_cloud_asset_id_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart
git commit -m "feat(db): v227 cylinder_fills table

Refs #2334"
```

If `database.g.dart` is gitignored, `git add` reports it and you drop it from the list.

---

### Task 7: Sync registration for `cylinderFills`

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`, after the `transmitters` entry)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~line 1428, `entityHasUpdatedAt` ~2359, `parentRefs` ~2484)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (field ~313, ctor ~409, `toJson` ~500, `fromJson` ~594, `_baseTables` ~1014, `_buildSyncData` ~2020, exporter ~7257, `fetchRecord` ~2634, `fetchRecords` ~3025, `upsertRecord` ~3983, `upsertRecords` ~5038, `recordIdsFor` ~5471, `_syncTableFor` ~5848, `deleteRecord` ~6282)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` ~line 49, `deletableParents` ~134), `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (`targets` ~line 94)

**Interfaces:**
- Produces: entity type string `'cylinderFills'` everywhere; `SyncData.cylinderFills`; `SyncDataSerializer._exportCylinderFills(String? hlcSince)`.

Every insertion goes directly after the `transmitters` line of the same list or switch. The order in `_baseTables` must match `toJson`, so put `cylinderFills` after `transmitters` in both.

- [ ] **Step 1: Run the guard tests to see them fail**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart`
Expected: `sync_hlc_target_registration_test` fails: `cylinder_fills` has an hlc column and no target.

- [ ] **Step 2: Register the HLC target**

In `sync_repository.dart`, after `'transmitters': (table: 'transmitters', pk: 'id'),`:

```dart
    'cylinderFills': (table: 'cylinder_fills', pk: 'id'),
```

- [ ] **Step 3: Register in `sync_service.dart`**

`mergeOrder`, after the transmitters record:

```dart
          (
            type: 'cylinderFills',
            records: data.cylinderFills,
            hasUpdatedAt: true,
          ),
```

`entityHasUpdatedAt`, after `'transmitters': true,`:

```dart
    'cylinderFills': true,
```

`parentRefs`, after the transmitters entry:

```dart
    // The gear link is nullable: a fill outlives a deleted cylinder (set
    // null) and a fill of a rental cylinder never had one.
    'cylinderFills': [
      (field: 'equipmentId', parent: 'equipment', nullable: true),
    ],
```

- [ ] **Step 4: Register in `sync_data_serializer.dart`**

Field, after `final List<Map<String, dynamic>> transmitters;`:

```dart
  final List<Map<String, dynamic>> cylinderFills;
```

Constructor, after `this.transmitters = const [],`:

```dart
    this.cylinderFills = const [],
```

`toJson`, after `'transmitters': transmitters,`:

```dart
      'cylinderFills': cylinderFills,
```

`fromJson`, after the transmitters line:

```dart
        cylinderFills: _parseList(json['cylinderFills']),
```

`_baseTables`, after the transmitters descriptor:

```dart
      (key: 'cylinderFills', table: _db.cylinderFills, blob: false, full: null),
```

`_buildSyncData`, after the transmitters export:

```dart
        cylinderFills: await _safeExport(
          'cylinderFills',
          () => _exportCylinderFills(hlcSince),
        ),
```

Exporter, after `_exportTransmitters`:

```dart
  Future<List<Map<String, dynamic>>> _exportCylinderFills(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.cylinderFills);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

`fetchRecord`, after the transmitters case:

```dart
      case 'cylinderFills':
        final row = await (_db.select(
          _db.cylinderFills,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`fetchRecords`:

```dart
      case 'cylinderFills':
        final rows = await (_db.select(
          _db.cylinderFills,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

`upsertRecord`:

```dart
      case 'cylinderFills':
        await _db
            .into(_db.cylinderFills)
            .insertOnConflictUpdate(
              CylinderFillRow.fromJson(data).toCompanion(false),
            );
        return;
```

`upsertRecords`:

```dart
      case 'cylinderFills':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.cylinderFills,
            records
                .map((r) => CylinderFillRow.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```

`recordIdsFor`:

```dart
      case 'cylinderFills':
        return plain(_db.cylinderFills, _db.cylinderFills.id);
```

`_syncTableFor`:

```dart
      case 'cylinderFills':
        return _db.cylinderFills;
```

`deleteRecord`:

```dart
      case 'cylinderFills':
        await (_db.delete(
          _db.cylinderFills,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 5: Update the hand-kept test maps**

`sync_parent_refs_completeness_test.dart`: add `'cylinderFills': 'cylinder_fills',` after the transmitters line in both `syncedTables` and `deletableParents`.

`sync_data_serializer_batch_coverage_test.dart`: add `(type: 'cylinderFills', table: db.cylinderFills.actualTableName),` after the `diveComputers` target.

- [ ] **Step 6: Run the guard tests**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_adopt_streaming_parity_test.dart`
Expected: all pass.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_service.dart lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart
git commit -m "feat(sync): register cylinderFills as a clocked entity

Refs #2334"
```

---

### Task 8: The fill and passport repositories

**Files:**
- Create: `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart`
- Create: `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (after the `TransmitterRepository().unlinkFromDeletedEquipment(id);` line at ~587)
- Modify: `test/architecture/repository_tick_stream_test.dart` (both maps)
- Test: `test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`, `test/features/cylinder_passports/data/repositories/cylinder_passport_repository_test.dart`

**Interfaces:**
- Consumes: `CylinderFill`, `FillSource`, `EquipmentAttrKeys.passportId`, `EquipmentRepository.getAttributesForEquipment` and `saveAttributes`, `SyncRepository.markRecordPending` and `logDeletion`.
- Produces:
  - `class CylinderFillRepository` with `Stream<void> watchFillsChanges()`, `Future<CylinderFill> create(CylinderFill fill)` (mints an id when `fill.id` is empty), `Future<void> update(CylinderFill fill)`, `Future<void> delete(String id)`, `Future<CylinderFill?> getById(String id)`, `Future<List<CylinderFill>> getForPassport(String passportId)` (newest first), `Future<CylinderFill?> newestForPassport(String passportId)`, `Future<List<CylinderFill>> getForEquipment(String equipmentId)`, `Future<int> relinkToEquipment({required String passportId, required String equipmentId})`, `Future<void> unlinkFromDeletedEquipment(String equipmentId)`.
  - `class CylinderPassportRepository` with `Future<String?> getPassportId(String equipmentId)`, `Future<String?> findEquipmentIdByPassportId(String passportId, {String? diverId})`, `Future<void> assignPassportId({required String equipmentId, required String passportId, String? diverId})` (throws `PassportIdInUse` when another visible cylinder holds it; relinks fills), `Future<String> ensurePassportId(String equipmentId, {String? diverId})` (returns the existing id or mints and assigns one).
  - `class PassportIdInUse implements Exception { final String equipmentId; }`.

- [ ] **Step 1: Write the failing fill repository test**

Create `test/features/cylinder_passports/data/repositories/cylinder_fill_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderFillRepository repo;
  final t0 = DateTime(2026, 9, 1, 10);

  Future<void> seedEquipment(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  CylinderFill fill(String id, DateTime at, {String? equipmentId = 'eq-1'}) =>
      CylinderFill(
        id: id,
        diverId: 'd1',
        passportId: 'pp-1',
        equipmentId: equipmentId,
        filledAt: at,
        o2Percent: 32,
        pressureBar: 220,
        createdAt: at,
        updatedAt: at,
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderFillRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: t, updatedAt: t),
        );
    await seedEquipment('eq-1');
  });

  tearDown(tearDownTestDatabase);

  test('create mints an id and reads back newest first', () async {
    await repo.create(fill('', t0));
    await repo.create(fill('', t0.add(const Duration(days: 2))));
    await repo.create(fill('', t0.add(const Duration(days: 1))));

    final fills = await repo.getForPassport('pp-1');
    expect(fills.map((f) => f.filledAt.day), [3, 2, 1]);
    expect(fills.every((f) => f.id.isNotEmpty), isTrue);
    expect((await repo.newestForPassport('pp-1'))!.filledAt.day, 3);
    expect(await repo.newestForPassport('pp-none'), isNull);
  });

  test('getForEquipment reads through the gear link', () async {
    await repo.create(fill('a', t0));
    await repo.create(fill('b', t0, equipmentId: null));
    expect((await repo.getForEquipment('eq-1')).map((f) => f.id), ['a']);
  });

  test('update and delete round trip', () async {
    final created = await repo.create(fill('a', t0));
    await repo.update(created.copyWith(o2Percent: 36, notes: 'checked'));
    final read = await repo.getById('a');
    expect(read!.o2Percent, 36);
    expect(read.notes, 'checked');
    await repo.delete('a');
    expect(await repo.getById('a'), isNull);
  });

  test('a fill is marked pending for sync on create', () async {
    await repo.create(fill('a', t0));
    final pending = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_pending_records "
          "WHERE entity_type = 'cylinderFills' AND record_id = 'a'",
        )
        .getSingle();
    expect(pending.read<int>('n'), 1);
  });

  test('relink after delete keeps every fill once', () async {
    await repo.create(fill('a', t0));
    await repo.create(fill('b', t0.add(const Duration(days: 1))));
    await EquipmentRepository().deleteEquipment('eq-1');

    var fills = await repo.getForPassport('pp-1');
    expect(fills.length, 2);
    expect(fills.every((f) => f.equipmentId == null), isTrue);

    await seedEquipment('eq-2');
    final count = await repo.relinkToEquipment(
      passportId: 'pp-1',
      equipmentId: 'eq-2',
    );
    expect(count, 2);
    fills = await repo.getForPassport('pp-1');
    expect(fills.length, 2);
    expect(fills.every((f) => f.equipmentId == 'eq-2'), isTrue);
    expect((await repo.getForEquipment('eq-2')).length, 2);
  });
}
```

If the pending-records table is not named `sync_pending_records`, find the real name with `grep -n "class SyncPending" lib/core/database/database.dart` and its `actualTableName`, and fix the SQL in the test.

- [ ] **Step 2: Write the failing passport repository test**

Create `test/features/cylinder_passports/data/repositories/cylinder_passport_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderPassportRepository repo;
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  Future<void> seedEquipment(String eq, {String diver = 'd1'}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: eq,
            name: eq,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: Value(diver),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderPassportRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final d in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(id: d, name: d, createdAt: t, updatedAt: t),
          );
    }
    await seedEquipment('eq-1');
    await seedEquipment('eq-2');
    await seedEquipment('eq-other', diver: 'd2');
  });

  tearDown(tearDownTestDatabase);

  test('assign, read and look up by passport id', () async {
    expect(await repo.getPassportId('eq-1'), isNull);
    await repo.assignPassportId(equipmentId: 'eq-1', passportId: id, diverId: 'd1');
    expect(await repo.getPassportId('eq-1'), id);
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), 'eq-1');
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd2'), isNull);
    expect(await repo.findEquipmentIdByPassportId(id), 'eq-1');
  });

  test('ensurePassportId mints once and is stable', () async {
    final first = await repo.ensurePassportId('eq-1', diverId: 'd1');
    final second = await repo.ensurePassportId('eq-1', diverId: 'd1');
    expect(first, second);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(first),
      isTrue,
    );
  });

  test('refuses an id another visible cylinder holds', () async {
    await repo.assignPassportId(equipmentId: 'eq-1', passportId: id, diverId: 'd1');
    expect(
      () => repo.assignPassportId(
        equipmentId: 'eq-2',
        passportId: id,
        diverId: 'd1',
      ),
      throwsA(isA<PassportIdInUse>().having((e) => e.equipmentId, 'holder', 'eq-1')),
    );
    // Re-assigning the same id to the same item is a no-op, not a conflict.
    await repo.assignPassportId(equipmentId: 'eq-1', passportId: id, diverId: 'd1');
  });

  test('assigning relinks orphaned fills under that id', () async {
    final fills = CylinderFillRepository();
    final t = DateTime(2026, 9, 1);
    await fills.create(
      CylinderFill(
        id: 'a',
        passportId: id,
        filledAt: t,
        o2Percent: 21,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.assignPassportId(equipmentId: 'eq-2', passportId: id, diverId: 'd1');
    expect((await fills.getById('a'))!.equipmentId, 'eq-2');
  });
}
```

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/features/cylinder_passports/data/repositories/`
Expected: compile errors.

- [ ] **Step 4: Create the fill repository**

Create `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Fill history of physical cylinders (spec section 10.2), keyed by passport
/// id. Registered for sync like the transmitter registry: every write marks
/// the row pending, every delete logs a tombstone.
class CylinderFillRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'cylinderFills';

  Stream<void> watchFillsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.cylinderFills));

  Future<CylinderFill> create(CylinderFill fill) async {
    final withId = fill.id.isEmpty ? fill.copyWith(id: _uuid.v4()) : fill;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.cylinderFills)
        .insert(_companion(withId, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: withId.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return withId.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> update(CylinderFill fill) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.id.equals(fill.id))).write(_companion(fill, now: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: fill.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.cylinderFills)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<CylinderFill?> getById(String id) async {
    final row = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Newest first.
  Future<List<CylinderFill>> getForPassport(String passportId) async {
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.passportId.equals(passportId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<CylinderFill?> newestForPassport(String passportId) async {
    final row =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.passportId.equals(passportId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Newest first, through the gear link only.
  Future<List<CylinderFill>> getForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  /// Points every fill of [passportId] at [equipmentId] and stages each for
  /// sync. Returns how many rows changed.
  Future<int> relinkToEquipment({
    required String passportId,
    required String equipmentId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.passportId.equals(passportId))).get();
    final stale = rows.where((r) => r.equipmentId != equipmentId).toList();
    if (stale.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(_db.cylinderFills)
            ..where((t) => t.id.isIn(stale.map((r) => r.id).toList())))
          .write(
            CylinderFillsCompanion(
              equipmentId: Value(equipmentId),
              updatedAt: Value(now),
            ),
          );
    });
    for (final row in stale) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
    return stale.length;
  }

  /// Clears the gear link on the fills of a cylinder being deleted and
  /// stages each row, so peers receive the cleared link rather than relying
  /// on SQLite's set-null. Mirrors TransmitterRepository.
  Future<void> unlinkFromDeletedEquipment(String equipmentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    if (rows.isEmpty) return;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).write(
      CylinderFillsCompanion(
        equipmentId: const Value(null),
        updatedAt: Value(now),
      ),
    );
    for (final row in rows) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }

  CylinderFill _fromRow(CylinderFillRow r) => CylinderFill(
    id: r.id,
    diverId: r.diverId,
    passportId: r.passportId,
    equipmentId: r.equipmentId,
    filledAt: DateTime.fromMillisecondsSinceEpoch(r.filledAt),
    o2Percent: r.o2Percent,
    hePercent: r.hePercent,
    pressureBar: r.pressureBar,
    temperatureC: r.temperatureC,
    analyzer: r.analyzer,
    stationName: r.stationName,
    stationKey: r.stationKey,
    signedRecord: r.signedRecord,
    source: FillSource.fromName(r.source),
    notes: r.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );

  CylinderFillsCompanion _companion(
    CylinderFill f, {
    required int now,
    int? createdAt,
  }) => CylinderFillsCompanion(
    id: Value(f.id),
    diverId: Value(f.diverId),
    passportId: Value(f.passportId),
    equipmentId: Value(f.equipmentId),
    filledAt: Value(f.filledAt.millisecondsSinceEpoch),
    o2Percent: Value(f.o2Percent),
    hePercent: Value(f.hePercent),
    pressureBar: Value(f.pressureBar),
    temperatureC: Value(f.temperatureC),
    analyzer: Value(f.analyzer),
    stationName: Value(f.stationName),
    stationKey: Value(f.stationKey),
    signedRecord: Value(f.signedRecord),
    source: Value(f.source.name),
    notes: Value(f.notes),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    updatedAt: Value(now),
  );
}
```

- [ ] **Step 5: Create the passport repository**

Create `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Another cylinder the diver can see already carries this passport id.
class PassportIdInUse implements Exception {
  final String equipmentId;
  const PassportIdInUse(this.equipmentId);

  @override
  String toString() => 'PassportIdInUse($equipmentId)';
}

/// The passport id of a cylinder: the `passport_id` equipment attribute
/// (spec section 6.5). Reads and writes go through the equipment
/// repository's attribute path so the row ids, tombstones and pending marks
/// match every other curated attribute.
class CylinderPassportRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final EquipmentRepository _equipment = EquipmentRepository();
  final CylinderFillRepository _fills = CylinderFillRepository();
  final _uuid = const Uuid();

  Future<String?> getPassportId(String equipmentId) async {
    final row =
        await (_db.select(_db.equipmentAttributes)..where(
              (t) =>
                  t.equipmentId.equals(equipmentId) &
                  t.attrKey.equals(EquipmentAttrKeys.passportId) &
                  t.isCustom.equals(false),
            ))
            .getSingleOrNull();
    final value = row?.valueText?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The one cylinder holding [passportId], limited to [diverId]'s own gear
  /// when given. The sharing program's visibility clause replaces the
  /// diver_id test when it lands.
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) async {
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final query = _db.select(attrs).join([
      innerJoin(eq, eq.id.equalsExp(attrs.equipmentId)),
    ])..where(
      attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
          attrs.isCustom.equals(false) &
          attrs.valueText.equals(passportId),
    );
    if (diverId != null) query.where(eq.diverId.equals(diverId));
    final rows = await query.get();
    if (rows.isEmpty) return null;
    return rows.first.readTable(eq).id;
  }

  /// Writes [passportId] onto [equipmentId] and relinks the fills stored
  /// under it. Throws [PassportIdInUse] when a different visible cylinder
  /// already holds the id.
  Future<void> assignPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) async {
    final holder = await findEquipmentIdByPassportId(
      passportId,
      diverId: diverId,
    );
    if (holder != null && holder != equipmentId) {
      throw PassportIdInUse(holder);
    }
    if (holder != equipmentId) {
      final existing = await _equipment.getAttributesForEquipment(equipmentId);
      final desired = [
        for (final a in existing)
          if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
        EquipmentAttribute.curated(
          equipmentId: equipmentId,
          key: EquipmentAttrKeys.passportId,
          valueText: passportId,
        ),
      ];
      await _equipment.saveAttributes(equipmentId, desired);
    }
    await _fills.relinkToEquipment(
      passportId: passportId,
      equipmentId: equipmentId,
    );
  }

  /// The cylinder's passport id, minted on first use.
  Future<String> ensurePassportId(String equipmentId, {String? diverId}) async {
    final existing = await getPassportId(equipmentId);
    if (existing != null) return existing;
    final minted = _uuid.v4();
    await assignPassportId(
      equipmentId: equipmentId,
      passportId: minted,
      diverId: diverId,
    );
    return minted;
  }
}
```

- [ ] **Step 6: Unlink on equipment delete**

In `equipment_repository_impl.dart`, directly after `await TransmitterRepository().unlinkFromDeletedEquipment(id);` add:

```dart
        // Fill history keeps its passport id and drops the gear link, staged
        // for sync; "Link an existing tag" restores it on a new row.
        await CylinderFillRepository().unlinkFromDeletedEquipment(id);
```

with the import `package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` in the file's local-import group.

- [ ] **Step 7: Register the tick stream in the architecture test**

In `test/architecture/repository_tick_stream_test.dart`, add to the firing group an entry shaped like the `DiveComputerRepository.watchComputersChanges` one, where the write inserts:

```dart
          CylinderFillsCompanion.insert(
            id: 'fill-tick',
            passportId: 'pp-tick',
            filledAt: 0,
            o2Percent: 21,
            createdAt: 0,
            updatedAt: 0,
          ),
```

into `db.cylinderFills`, and to the `ticks` map in the silence group:

```dart
      'CylinderFillRepository.watchFillsChanges':
          CylinderFillRepository().watchFillsChanges,
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/cylinder_passports/data/repositories/ test/architecture/repository_tick_stream_test.dart test/features/equipment/data/repositories/`
Expected: all pass.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/data/repositories/ lib/features/equipment/data/repositories/equipment_repository_impl.dart test/architecture/repository_tick_stream_test.dart test/features/cylinder_passports/data/repositories/
git commit -m "feat(passports): fill and passport id repositories

Refs #2334"
```

---

### Task 9: Providers

**Files:**
- Create: `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (the `_tickGroup('equipment', [...])` list at ~line 522)
- Test: `test/features/cylinder_passports/presentation/providers/cylinder_passport_providers_test.dart`

**Interfaces:**
- Produces: `cylinderFillRepositoryProvider` (`Provider<CylinderFillRepository>`), `cylinderPassportRepositoryProvider` (`Provider<CylinderPassportRepository>`), `passportIdProvider` (`FutureProvider.family<String?, String>` by equipment id), `fillsForEquipmentProvider` (`FutureProvider.family<List<CylinderFill>, String>`, newest first, through the passport id when one exists and the gear link otherwise), `newestFillProvider` (`FutureProvider.family<CylinderFill?, String>`).

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/presentation/providers/cylinder_passport_providers_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: t, updatedAt: t),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-1',
            name: 'Steel 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('fills follow the passport id and refresh on a write', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final pid = await CylinderPassportRepository().ensurePassportId('eq-1');

    expect(await container.read(fillsForEquipmentProvider('eq-1').future), isEmpty);
    expect(await container.read(newestFillProvider('eq-1').future), isNull);

    final t = DateTime(2026, 9, 1);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: pid,
        equipmentId: 'eq-1',
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final fills = await container.read(fillsForEquipmentProvider('eq-1').future);
    expect(fills.map((f) => f.o2Percent), [32]);
    expect((await container.read(newestFillProvider('eq-1').future))!.o2Percent, 32);
    expect(await container.read(passportIdProvider('eq-1').future), pid);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/presentation/providers/cylinder_passport_providers_test.dart`
Expected: compile error.

- [ ] **Step 3: Create the providers**

Create `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final cylinderFillRepositoryProvider = Provider<CylinderFillRepository>(
  (ref) => CylinderFillRepository(),
);

final cylinderPassportRepositoryProvider =
    Provider<CylinderPassportRepository>(
      (ref) => CylinderPassportRepository(),
    );

/// The cylinder's passport id, or null until the passport page mints one.
/// Self-invalidates on attribute writes, which is where the id lives.
final passportIdProvider = FutureProvider.family<String?, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(cylinderPassportRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(equipmentRepositoryProvider).watchAttributeChanges(),
  );
  return repository.getPassportId(equipmentId);
});

/// Every fill of the cylinder, newest first: by passport id when it has one
/// (so fills logged before a re-created row still show), by gear link
/// otherwise.
final fillsForEquipmentProvider =
    FutureProvider.family<List<CylinderFill>, String>((ref, equipmentId) async {
      final repository = ref.watch(cylinderFillRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchFillsChanges());
      final passportId = await ref.watch(passportIdProvider(equipmentId).future);
      if (passportId == null) return repository.getForEquipment(equipmentId);
      return repository.getForPassport(passportId);
    });

final newestFillProvider = FutureProvider.family<CylinderFill?, String>((
  ref,
  equipmentId,
) async {
  final fills = await ref.watch(fillsForEquipmentProvider(equipmentId).future);
  return fills.isEmpty ? null : fills.first;
});
```

- [ ] **Step 4: Add the smoke-test entries**

In `test/architecture/provider_tick_build_smoke_test.dart`, inside `_tickGroup('equipment', [...])`, add:

```dart
    (
      name: 'passportIdProvider',
      read: (c) => c.read(passportIdProvider('missing').future),
    ),
    (
      name: 'fillsForEquipmentProvider',
      read: (c) => c.read(fillsForEquipmentProvider('missing').future),
    ),
```

with the import of `cylinder_passport_providers.dart`.

- [ ] **Step 5: Run the tests and the two architecture guards**

Run: `flutter test test/features/cylinder_passports/presentation/providers/ test/architecture/provider_change_tick_test.dart test/architecture/provider_tick_build_smoke_test.dart`
Expected: all pass. If `provider_change_tick_test` flags `newestFillProvider`, it is because the scanner wants a tick beside a repository call; `newestFillProvider` calls no repository, so the fix is to make sure it does not import a repository symbol, not to add a tick.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart test/features/cylinder_passports/presentation/providers/ test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(passports): passport id and fill providers

Refs #2334"
```

---

### Task 10: Pure metrics and rules

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/passport_metrics.dart`
- Create: `lib/features/cylinder_passports/domain/services/passport_rules.dart`
- Test: `test/features/cylinder_passports/domain/services/passport_metrics_test.dart`, `test/features/cylinder_passports/domain/services/passport_rules_test.dart`

**Interfaces:**
- Consumes: `gasVolume` (`lib/core/utils/gas_compressibility.dart`), `GasModel`, `BuoyancyPhysics.tankTermKg`, `GasDensity.mixDensityKgPerLBar` (`lib/core/buoyancy/gas_density.dart`), `TankPresets.matchBySpecs`, `GasMix.mod` and `end`, `ServiceClockStatus`, `EquipmentItem`, `CylinderPassportPayload`.
- Produces:
  - `class PassportSpecMetrics extends Equatable { final double? freeGasLiters; final double? emptyBuoyancyKg; final double? fullBuoyancyKg; static PassportSpecMetrics compute({double? volumeL, double? workingPressureBar, TankMaterial? material, double o2Percent = 21, double hePercent = 0, required GasModel gasModel}) }`
  - `class PassportGasLimits extends Equatable { final double modWorkingM; final double modDecoM; final double? endAtWorkingModM; static PassportGasLimits compute({required GasMix mix, required double ppO2Working, required double ppO2Deco, required bool o2Narcotic}) }`
  - `enum O2CleanWarning { none, untracked, overdue }`; `O2CleanWarning o2CleanWarning({required double? newestO2Percent, required ServiceClockStatus? o2CleanClock, required double highO2Fraction})`
  - `bool tagIsStale({required CylinderPassportPayload tag, DateTime? hydroAnchor, DateTime? vipAnchor, double? volumeL, int? workingPressureBar, TankMaterial? material})`
  - `CylinderPassportPayload payloadForItem({required EquipmentItem item, required String passportId, required DateTime writtenOn, DateTime? hydroAnchor, DateTime? vipAnchor, required bool o2Clean})`

- [ ] **Step 1: Write the failing metrics test**

Create `test/features/cylinder_passports/domain/services/passport_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('PassportSpecMetrics', () {
    test('ideal gas: 12 L at 232 bar is 2784 L', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        gasModel: GasModel.ideal,
      );
      expect(m.freeGasLiters, closeTo(2784, 1e-9));
    });

    test('real gas matches the shared gasVolume function', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
        gasModel: GasModel.real,
      );
      expect(
        m.freeGasLiters,
        gasVolume(
          tankSizeLiters: 11.1,
          pressureBar: 207,
          o2Percent: 21,
          model: GasModel.real,
        ),
      );
    });

    test('full buoyancy is empty buoyancy minus the gas mass', () {
      // Air: 12 L x 232 bar x 0.001225 kg per L bar = 3.4104 kg.
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        gasModel: GasModel.ideal,
      );
      expect(m.emptyBuoyancyKg, isNotNull);
      expect(m.emptyBuoyancyKg! - m.fullBuoyancyKg!, closeTo(3.4104, 1e-6));
      expect(
        m.emptyBuoyancyKg,
        BuoyancyPhysics.tankTermKg(
          volumeL: 12,
          workingPressureBar: 232,
          material: TankMaterial.steel,
          reserveBar: 0,
        ),
      );
    });

    test('without a volume nothing is derived', () {
      final m = PassportSpecMetrics.compute(gasModel: GasModel.real);
      expect(m.freeGasLiters, isNull);
      expect(m.emptyBuoyancyKg, isNull);
      expect(m.fullBuoyancyKg, isNull);
    });

    test('without a pressure buoyancy is empty only', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        material: TankMaterial.steel,
        gasModel: GasModel.real,
      );
      expect(m.freeGasLiters, isNull);
      expect(m.emptyBuoyancyKg, isNotNull);
      expect(m.fullBuoyancyKg, isNull);
    });
  });

  group('PassportGasLimits', () {
    test('EAN32: MOD 33.75 m at 1.4 and 40 m at 1.6, no END', () {
      final l = PassportGasLimits.compute(
        mix: const GasMix(o2: 32),
        ppO2Working: 1.4,
        ppO2Deco: 1.6,
        o2Narcotic: true,
      );
      expect(l.modWorkingM, closeTo(33.75, 1e-9));
      expect(l.modDecoM, closeTo(40.0, 1e-9));
      expect(l.endAtWorkingModM, isNull);
    });

    test('Tx18/45: END at the working MOD', () {
      // MOD = (1.4 / 0.18 - 1) x 10 = 67.777 m, ambient 7.7777 bar.
      // END (O2 narcotic) = ((7.7777 x 0.55) - 1) x 10 = 32.777 m.
      final l = PassportGasLimits.compute(
        mix: const GasMix(o2: 18, he: 45),
        ppO2Working: 1.4,
        ppO2Deco: 1.6,
        o2Narcotic: true,
      );
      expect(l.modWorkingM, closeTo(67.7777, 1e-3));
      expect(l.endAtWorkingModM, closeTo(32.7777, 1e-3));
    });
  });
}
```

- [ ] **Step 2: Write the failing rules test**

Create `test/features/cylinder_passports/domain/services/passport_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  ServiceClockStatus clock(ServiceClockSeverity severity) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's',
      equipmentId: 'eq',
      serviceKindId: 'o2-clean',
      createdAt: now,
      updatedAt: now,
    ),
    kind: ServiceKind(
      id: 'o2-clean',
      name: 'O2 clean',
      createdAt: now,
      updatedAt: now,
    ),
    anchor: DateTime(2026, 1, 1),
    severity: severity,
    now: now,
  );

  group('o2CleanWarning', () {
    test('boundary of the high-O2 threshold', () {
      expect(
        o2CleanWarning(
          newestO2Percent: 40.0,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
      expect(
        o2CleanWarning(
          newestO2Percent: 40.5,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.untracked,
      );
    });

    test('overdue clock warns, current clock does not', () {
      expect(
        o2CleanWarning(
          newestO2Percent: 50,
          o2CleanClock: clock(ServiceClockSeverity.overdue),
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.overdue,
      );
      expect(
        o2CleanWarning(
          newestO2Percent: 50,
          o2CleanClock: clock(ServiceClockSeverity.dueSoon),
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
    });

    test('no fill, no warning', () {
      expect(
        o2CleanWarning(
          newestO2Percent: null,
          o2CleanClock: null,
          highO2Fraction: 0.40,
        ),
        O2CleanWarning.none,
      );
    });
  });

  group('tagIsStale', () {
    final tag = CylinderPassportPayload(
      passportId: 'p',
      writtenOn: DateTime(2026, 1, 10),
      volumeL: 12,
      workingPressureBar: 232,
      material: TankMaterial.steel,
    );

    test('a service anchored after the write date is stale', () {
      expect(
        tagIsStale(tag: tag, hydroAnchor: DateTime(2026, 3, 1)),
        isTrue,
      );
      expect(
        tagIsStale(tag: tag, vipAnchor: DateTime(2025, 12, 1)),
        isFalse,
      );
    });

    test('a spec that differs is stale, within tolerance is not', () {
      expect(tagIsStale(tag: tag, volumeL: 12.04), isFalse);
      expect(tagIsStale(tag: tag, volumeL: 15), isTrue);
      expect(tagIsStale(tag: tag, workingPressureBar: 300), isTrue);
      expect(tagIsStale(tag: tag, material: TankMaterial.aluminum), isTrue);
    });

    test('unknown facts on either side never make it stale', () {
      expect(tagIsStale(tag: tag), isFalse);
      expect(
        tagIsStale(
          tag: const CylinderPassportPayload(passportId: 'p'),
          hydroAnchor: DateTime(2026, 3, 1),
          volumeL: 15,
        ),
        isFalse,
      );
    });
  });

  group('payloadForItem', () {
    test('copies the spec, prefers the identifier as the name', () {
      const item = EquipmentItem(
        id: 'eq',
        name: 'Faber 12',
        type: EquipmentType.tank,
        serialNumber: 'F123',
        attributes: [
          EquipmentAttribute(
            id: 'a1',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.identifier,
            valueText: 'S12-A',
          ),
          EquipmentAttribute(
            id: 'a2',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 12,
          ),
          EquipmentAttribute(
            id: 'a3',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.workingPressureBar,
            valueNum: 232,
          ),
          EquipmentAttribute(
            id: 'a4',
            equipmentId: 'eq',
            key: EquipmentAttrKeys.tankMaterial,
            valueText: 'steel',
          ),
          EquipmentAttribute(
            id: 'a5',
            equipmentId: 'eq',
            key: 'valve_type',
            valueText: 'convertible',
          ),
        ],
      );
      final p = payloadForItem(
        item: item,
        passportId: 'p',
        writtenOn: now,
        hydroAnchor: DateTime(2024, 6, 14),
        o2Clean: true,
      );
      expect(p.name, 'S12-A');
      expect(p.serial, 'F123');
      expect(p.volumeL, 12);
      expect(p.workingPressureBar, 232);
      expect(p.material, TankMaterial.steel);
      expect(p.valve, PassportValve.convertible);
      expect(p.lastHydro, DateTime(2024, 6, 14));
      expect(p.lastVip, isNull);
      expect(p.o2Clean, isTrue);
      expect(p.writtenOn, now);
    });
  });
}
```

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_metrics_test.dart test/features/cylinder_passports/domain/services/passport_rules_test.dart`
Expected: compile errors.

- [ ] **Step 4: Create the metrics**

Create `lib/features/cylinder_passports/domain/services/passport_metrics.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Derived spec figures for the passport's Cylinder card (spec section 8).
/// Every input is metric; the caller formats for display.
class PassportSpecMetrics extends Equatable {
  /// Litres at 1 bar held at working pressure under the diver's gas model.
  final double? freeGasLiters;

  /// Buoyancy with no gas inside, from the tank physics catalog or the
  /// per-material estimate. Positive floats.
  final double? emptyBuoyancyKg;

  /// [emptyBuoyancyKg] minus the mass of the gas at working pressure.
  final double? fullBuoyancyKg;

  const PassportSpecMetrics({
    this.freeGasLiters,
    this.emptyBuoyancyKg,
    this.fullBuoyancyKg,
  });

  static PassportSpecMetrics compute({
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    double o2Percent = 21,
    double hePercent = 0,
    required GasModel gasModel,
  }) {
    if (volumeL == null) return const PassportSpecMetrics();
    final preset = workingPressureBar == null
        ? null
        : TankPresets.matchBySpecs(volumeL, workingPressureBar);
    final empty = BuoyancyPhysics.tankTermKg(
      presetName: preset?.name,
      volumeL: volumeL,
      workingPressureBar: workingPressureBar,
      material: material,
      reserveBar: 0,
    );
    if (workingPressureBar == null) {
      return PassportSpecMetrics(emptyBuoyancyKg: empty);
    }
    final gasMass =
        volumeL *
        workingPressureBar *
        GasDensity.mixDensityKgPerLBar(o2Percent: o2Percent, hePercent: hePercent);
    return PassportSpecMetrics(
      freeGasLiters: gasVolume(
        tankSizeLiters: volumeL,
        pressureBar: workingPressureBar,
        o2Percent: o2Percent,
        hePercent: hePercent,
        model: gasModel,
      ),
      emptyBuoyancyKg: empty,
      fullBuoyancyKg: empty - gasMass,
    );
  }

  @override
  List<Object?> get props => [freeGasLiters, emptyBuoyancyKg, fullBuoyancyKg];
}

/// Depth limits of the current mix at the diver's own ppO2 limits.
class PassportGasLimits extends Equatable {
  final double modWorkingM;
  final double modDecoM;

  /// Equivalent narcotic depth at [modWorkingM]; null for a mix without
  /// helium, where it would equal the depth itself.
  final double? endAtWorkingModM;

  const PassportGasLimits({
    required this.modWorkingM,
    required this.modDecoM,
    this.endAtWorkingModM,
  });

  static PassportGasLimits compute({
    required GasMix mix,
    required double ppO2Working,
    required double ppO2Deco,
    required bool o2Narcotic,
  }) {
    final modWorking = mix.mod(ppO2: ppO2Working);
    return PassportGasLimits(
      modWorkingM: modWorking,
      modDecoM: mix.mod(ppO2: ppO2Deco),
      endAtWorkingModM: mix.he > 0
          ? mix.end(modWorking, o2Narcotic: o2Narcotic)
          : null,
    );
  }

  @override
  List<Object?> get props => [modWorkingM, modDecoM, endAtWorkingModM];
}
```

If `TankPreset` exposes the preset key under another getter than `name`, use that getter (check `lib/core/constants/tank_presets.dart` around `byName`).

- [ ] **Step 5: Create the rules**

Create `lib/features/cylinder_passports/domain/services/passport_rules.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// Why the passport warns about oxygen cleanliness (spec section 8).
enum O2CleanWarning { none, untracked, overdue }

/// Warns when the newest fill is richer than the diver's high-O2 threshold
/// (the same one the exposure clocks use) and the cylinder either has no O2
/// clean clock or that clock is overdue.
O2CleanWarning o2CleanWarning({
  required double? newestO2Percent,
  required ServiceClockStatus? o2CleanClock,
  required double highO2Fraction,
}) {
  if (newestO2Percent == null) return O2CleanWarning.none;
  if (newestO2Percent / 100 <= highO2Fraction) return O2CleanWarning.none;
  if (o2CleanClock == null) return O2CleanWarning.untracked;
  if (o2CleanClock.severity == ServiceClockSeverity.overdue) {
    return O2CleanWarning.overdue;
  }
  return O2CleanWarning.none;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when the row has moved on since the tag was written: a hydro or
/// VIP anchored after the write date, or a spec value that differs
/// (spec section 6.6). Unknown facts on either side never count.
bool tagIsStale({
  required CylinderPassportPayload tag,
  DateTime? hydroAnchor,
  DateTime? vipAnchor,
  double? volumeL,
  int? workingPressureBar,
  TankMaterial? material,
}) {
  final written = tag.writtenOn;
  if (written != null) {
    for (final anchor in [hydroAnchor, vipAnchor]) {
      if (anchor != null && _dateOnly(anchor).isAfter(_dateOnly(written))) {
        return true;
      }
    }
  }
  if (tag.volumeL != null &&
      volumeL != null &&
      (tag.volumeL! - volumeL).abs() > 0.05) {
    return true;
  }
  if (tag.workingPressureBar != null &&
      workingPressureBar != null &&
      tag.workingPressureBar != workingPressureBar) {
    return true;
  }
  if (tag.material != null && material != null && tag.material != material) {
    return true;
  }
  return false;
}

PassportValve? _valveOf(EquipmentItem item) => switch (item.attrText(
  'valve_type',
)) {
  'din' => PassportValve.din,
  'yoke' => PassportValve.yoke,
  'convertible' => PassportValve.convertible,
  _ => null,
};

/// The payload a label or tag for [item] should carry right now.
/// [hydroAnchor] and [vipAnchor] are the clocks' anchors (last service or
/// baseline), which is what the tag means by "last hydro" and "last VIP".
CylinderPassportPayload payloadForItem({
  required EquipmentItem item,
  required String passportId,
  required DateTime writtenOn,
  DateTime? hydroAnchor,
  DateTime? vipAnchor,
  required bool o2Clean,
}) {
  final identifier = item.identifier;
  return CylinderPassportPayload(
    passportId: passportId,
    writtenOn: writtenOn,
    name: identifier != null && identifier.trim().isNotEmpty
        ? identifier.trim()
        : item.name,
    serial: (item.serialNumber ?? '').trim().isEmpty ? null : item.serialNumber,
    volumeL: item.volumeL,
    workingPressureBar: item.workingPressureBar?.round(),
    material: item.tankMaterial,
    valve: _valveOf(item),
    lastHydro: hydroAnchor,
    lastVip: vipAnchor,
    o2Clean: o2Clean,
  );
}
```

- [ ] **Step 6: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/domain/services/`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/passport_metrics.dart lib/features/cylinder_passports/domain/services/passport_rules.dart test/features/cylinder_passports/domain/services/passport_metrics_test.dart test/features/cylinder_passports/domain/services/passport_rules_test.dart
git commit -m "feat(passports): spec metrics, gas limits and the passport rules

Refs #2334"
```

---

### Task 11: Localized strings

**Files:**
- Modify: all 11 of `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_en.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Test: `test/l10n/arb_parity_test.dart`, `test/l10n/plural_singular_interpolates_argument_test.dart` (existing, must stay green)

**Interfaces:**
- Produces: the `context.l10n.passport_*` getters listed below. Later tasks call them by these exact names.

Anchor: in every file, insert the block directly after the `"equipment_bulkTags_applied"` entry (in `app_en.arb`, after its `"@equipment_bulkTags_applied"` metadata block). Non-English files carry no `@` blocks.

- [ ] **Step 1: English**

Insert into `app_en.arb`:

```json
  "passport_title": "Cylinder passport",
  "passport_open": "Open passport",
  "passport_entry_noFill": "No fill logged",
  "passport_entry_lastFill": "{mix} at {pressure}, {date}",
  "@passport_entry_lastFill": {
    "placeholders": {
      "mix": {"type": "String"},
      "pressure": {"type": "String"},
      "date": {"type": "String"}
    }
  },
  "passport_spec_title": "Cylinder",
  "passport_spec_freeGas": "Free gas at {pressure}",
  "@passport_spec_freeGas": {
    "placeholders": {
      "pressure": {"type": "String"}
    }
  },
  "passport_spec_buoyancyEmpty": "Buoyancy when empty",
  "passport_spec_buoyancyFull": "Buoyancy when full",
  "passport_service_title": "Service",
  "passport_service_notTracked": "Not tracked",
  "passport_service_trackO2Clean": "Track O2 cleaning",
  "passport_service_lastDone": "Last {date}",
  "@passport_service_lastDone": {
    "placeholders": {
      "date": {"type": "String"}
    }
  },
  "passport_o2Warning_untracked": "The last fill is {o2} O2 and this cylinder is not tracked as O2 clean.",
  "@passport_o2Warning_untracked": {
    "placeholders": {
      "o2": {"type": "String"}
    }
  },
  "passport_o2Warning_overdue": "The last fill is {o2} O2 and this cylinder's O2 cleaning is overdue.",
  "@passport_o2Warning_overdue": {
    "placeholders": {
      "o2": {"type": "String"}
    }
  },
  "passport_fill_title": "Current fill",
  "passport_fill_none": "No fill logged yet",
  "passport_fill_log": "Log a fill",
  "passport_fill_mod": "MOD {depth} at ppO2 {ppo2}",
  "@passport_fill_mod": {
    "placeholders": {
      "depth": {"type": "String"},
      "ppo2": {"type": "String"}
    }
  },
  "passport_fill_end": "END {depth} at the working MOD",
  "@passport_fill_end": {
    "placeholders": {
      "depth": {"type": "String"}
    }
  },
  "passport_fill_station": "Filled by {station}",
  "@passport_fill_station": {
    "placeholders": {
      "station": {"type": "String"}
    }
  },
  "passport_fill_analyzer": "Analyzed with {analyzer}",
  "@passport_fill_analyzer": {
    "placeholders": {
      "analyzer": {"type": "String"}
    }
  },
  "passport_fill_unsigned": "Unsigned",
  "passport_history_title": "Fill history",
  "passport_history_sinceHydro": "{count, plural, =0{No fills since the last hydro} =1{{count} fill since the last hydro} other{{count} fills since the last hydro}}",
  "@passport_history_sinceHydro": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "passport_history_delete": "Delete fill",
  "passport_history_deleteConfirm": "Delete this fill record?",
  "passport_tag_title": "Tag",
  "passport_tag_written": "Written {date}",
  "@passport_tag_written": {
    "placeholders": {
      "date": {"type": "String"}
    }
  },
  "passport_tag_stale": "The tag was written before the latest service or spec change. Reprint it.",
  "passport_tag_printLabel": "Print label",
  "passport_tag_printLabels": "Print labels",
  "passport_tag_linkExisting": "Link an existing tag",
  "passport_tag_linkPrompt": "Paste the link from the tag",
  "passport_tag_linkInvalid": "That is not a cylinder tag",
  "passport_tag_linkInUse": "That tag already belongs to {name}",
  "@passport_tag_linkInUse": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "passport_tag_linked": "Tag linked",
  "passport_logFill_date": "Filled on",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Fill pressure",
  "passport_logFill_temperature": "Gas temperature",
  "passport_logFill_station": "Fill station",
  "passport_logFill_analyzer": "Analyzer",
  "passport_logFill_notes": "Notes",
  "passport_logFill_invalidMix": "O2 and He must each be 0 to 100 and total 100 or less",
  "passport_logFill_invalidNumber": "Enter a number",
```

The plural's `=1` branch interpolates `{count}` on purpose: an ARB `=1{...}` branch is the CLDR "one" category, which French and Portuguese also use for zero, so a literal digit would print "1" for zero there.

- [ ] **Step 2: German (`app_de.arb`)**

```json
  "passport_title": "Flaschenpass",
  "passport_open": "Pass öffnen",
  "passport_entry_noFill": "Keine Füllung erfasst",
  "passport_entry_lastFill": "{mix} mit {pressure}, {date}",
  "passport_spec_title": "Flasche",
  "passport_spec_freeGas": "Freies Gas bei {pressure}",
  "passport_spec_buoyancyEmpty": "Auftrieb leer",
  "passport_spec_buoyancyFull": "Auftrieb voll",
  "passport_service_title": "Wartung",
  "passport_service_notTracked": "Nicht erfasst",
  "passport_service_trackO2Clean": "O2-Reinigung erfassen",
  "passport_service_lastDone": "Zuletzt {date}",
  "passport_o2Warning_untracked": "Die letzte Füllung hat {o2} O2, und diese Flasche wird nicht als O2-rein geführt.",
  "passport_o2Warning_overdue": "Die letzte Füllung hat {o2} O2, und die O2-Reinigung dieser Flasche ist überfällig.",
  "passport_fill_title": "Aktuelle Füllung",
  "passport_fill_none": "Noch keine Füllung erfasst",
  "passport_fill_log": "Füllung erfassen",
  "passport_fill_mod": "MOD {depth} bei ppO2 {ppo2}",
  "passport_fill_end": "END {depth} an der Arbeits-MOD",
  "passport_fill_station": "Gefüllt von {station}",
  "passport_fill_analyzer": "Analysiert mit {analyzer}",
  "passport_fill_unsigned": "Unsigniert",
  "passport_history_title": "Füllhistorie",
  "passport_history_sinceHydro": "{count, plural, =0{Keine Füllungen seit der letzten Druckprüfung} =1{{count} Füllung seit der letzten Druckprüfung} other{{count} Füllungen seit der letzten Druckprüfung}}",
  "passport_history_delete": "Füllung löschen",
  "passport_history_deleteConfirm": "Diesen Fülleintrag löschen?",
  "passport_tag_title": "Tag",
  "passport_tag_written": "Geschrieben {date}",
  "passport_tag_stale": "Der Tag wurde vor der letzten Wartung oder Spezifikationsänderung geschrieben. Neu drucken.",
  "passport_tag_printLabel": "Etikett drucken",
  "passport_tag_printLabels": "Etiketten drucken",
  "passport_tag_linkExisting": "Vorhandenen Tag verknüpfen",
  "passport_tag_linkPrompt": "Link vom Tag einfügen",
  "passport_tag_linkInvalid": "Das ist kein Flaschen-Tag",
  "passport_tag_linkInUse": "Dieser Tag gehört bereits zu {name}",
  "passport_tag_linked": "Tag verknüpft",
  "passport_logFill_date": "Gefüllt am",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Fülldruck",
  "passport_logFill_temperature": "Gastemperatur",
  "passport_logFill_station": "Füllstation",
  "passport_logFill_analyzer": "Analysegerät",
  "passport_logFill_notes": "Notizen",
  "passport_logFill_invalidMix": "O2 und He müssen jeweils 0 bis 100 sein und zusammen höchstens 100 ergeben",
  "passport_logFill_invalidNumber": "Zahl eingeben",
```

- [ ] **Step 3: Spanish (`app_es.arb`)**

```json
  "passport_title": "Pasaporte de la botella",
  "passport_open": "Abrir pasaporte",
  "passport_entry_noFill": "Ninguna carga registrada",
  "passport_entry_lastFill": "{mix} a {pressure}, {date}",
  "passport_spec_title": "Botella",
  "passport_spec_freeGas": "Gas libre a {pressure}",
  "passport_spec_buoyancyEmpty": "Flotabilidad vacía",
  "passport_spec_buoyancyFull": "Flotabilidad llena",
  "passport_service_title": "Mantenimiento",
  "passport_service_notTracked": "Sin seguimiento",
  "passport_service_trackO2Clean": "Seguir la limpieza de O2",
  "passport_service_lastDone": "Última {date}",
  "passport_o2Warning_untracked": "La última carga es {o2} de O2 y esta botella no tiene seguimiento de limpieza de O2.",
  "passport_o2Warning_overdue": "La última carga es {o2} de O2 y la limpieza de O2 de esta botella está vencida.",
  "passport_fill_title": "Carga actual",
  "passport_fill_none": "Aún no hay cargas registradas",
  "passport_fill_log": "Registrar una carga",
  "passport_fill_mod": "MOD {depth} a ppO2 {ppo2}",
  "passport_fill_end": "END {depth} en la MOD de trabajo",
  "passport_fill_station": "Cargada por {station}",
  "passport_fill_analyzer": "Analizada con {analyzer}",
  "passport_fill_unsigned": "Sin firmar",
  "passport_history_title": "Historial de cargas",
  "passport_history_sinceHydro": "{count, plural, =0{Ninguna carga desde la última prueba hidrostática} =1{{count} carga desde la última prueba hidrostática} other{{count} cargas desde la última prueba hidrostática}}",
  "passport_history_delete": "Eliminar carga",
  "passport_history_deleteConfirm": "¿Eliminar este registro de carga?",
  "passport_tag_title": "Etiqueta",
  "passport_tag_written": "Escrita el {date}",
  "passport_tag_stale": "La etiqueta se escribió antes del último mantenimiento o cambio de especificación. Vuelve a imprimirla.",
  "passport_tag_printLabel": "Imprimir etiqueta",
  "passport_tag_printLabels": "Imprimir etiquetas",
  "passport_tag_linkExisting": "Vincular una etiqueta existente",
  "passport_tag_linkPrompt": "Pega el enlace de la etiqueta",
  "passport_tag_linkInvalid": "Eso no es una etiqueta de botella",
  "passport_tag_linkInUse": "Esa etiqueta ya pertenece a {name}",
  "passport_tag_linked": "Etiqueta vinculada",
  "passport_logFill_date": "Cargada el",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Presión de carga",
  "passport_logFill_temperature": "Temperatura del gas",
  "passport_logFill_station": "Estación de carga",
  "passport_logFill_analyzer": "Analizador",
  "passport_logFill_notes": "Notas",
  "passport_logFill_invalidMix": "O2 y He deben estar entre 0 y 100 y sumar 100 o menos",
  "passport_logFill_invalidNumber": "Introduce un número",
```

- [ ] **Step 4: French (`app_fr.arb`)**

```json
  "passport_title": "Passeport de la bouteille",
  "passport_open": "Ouvrir le passeport",
  "passport_entry_noFill": "Aucun gonflage enregistré",
  "passport_entry_lastFill": "{mix} à {pressure}, {date}",
  "passport_spec_title": "Bouteille",
  "passport_spec_freeGas": "Gaz libre à {pressure}",
  "passport_spec_buoyancyEmpty": "Flottabilité à vide",
  "passport_spec_buoyancyFull": "Flottabilité pleine",
  "passport_service_title": "Entretien",
  "passport_service_notTracked": "Non suivi",
  "passport_service_trackO2Clean": "Suivre le nettoyage O2",
  "passport_service_lastDone": "Dernier {date}",
  "passport_o2Warning_untracked": "Le dernier gonflage est à {o2} d'O2 et cette bouteille n'est pas suivie comme compatible O2.",
  "passport_o2Warning_overdue": "Le dernier gonflage est à {o2} d'O2 et le nettoyage O2 de cette bouteille est en retard.",
  "passport_fill_title": "Gonflage actuel",
  "passport_fill_none": "Aucun gonflage enregistré pour l'instant",
  "passport_fill_log": "Enregistrer un gonflage",
  "passport_fill_mod": "PMU {depth} à ppO2 {ppo2}",
  "passport_fill_end": "PEN {depth} à la PMU de travail",
  "passport_fill_station": "Gonflée par {station}",
  "passport_fill_analyzer": "Analysée avec {analyzer}",
  "passport_fill_unsigned": "Non signé",
  "passport_history_title": "Historique des gonflages",
  "passport_history_sinceHydro": "{count, plural, =0{Aucun gonflage depuis la dernière requalification} =1{{count} gonflage depuis la dernière requalification} other{{count} gonflages depuis la dernière requalification}}",
  "passport_history_delete": "Supprimer le gonflage",
  "passport_history_deleteConfirm": "Supprimer cet enregistrement de gonflage ?",
  "passport_tag_title": "Étiquette",
  "passport_tag_written": "Écrite le {date}",
  "passport_tag_stale": "L'étiquette a été écrite avant le dernier entretien ou changement de caractéristiques. Réimprimez-la.",
  "passport_tag_printLabel": "Imprimer l'étiquette",
  "passport_tag_printLabels": "Imprimer les étiquettes",
  "passport_tag_linkExisting": "Lier une étiquette existante",
  "passport_tag_linkPrompt": "Collez le lien de l'étiquette",
  "passport_tag_linkInvalid": "Ce n'est pas une étiquette de bouteille",
  "passport_tag_linkInUse": "Cette étiquette appartient déjà à {name}",
  "passport_tag_linked": "Étiquette liée",
  "passport_logFill_date": "Gonflée le",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Pression de gonflage",
  "passport_logFill_temperature": "Température du gaz",
  "passport_logFill_station": "Station de gonflage",
  "passport_logFill_analyzer": "Analyseur",
  "passport_logFill_notes": "Notes",
  "passport_logFill_invalidMix": "O2 et He doivent être compris entre 0 et 100 et totaliser 100 au plus",
  "passport_logFill_invalidNumber": "Saisissez un nombre",
```

- [ ] **Step 5: Italian (`app_it.arb`)**

```json
  "passport_title": "Passaporto della bombola",
  "passport_open": "Apri passaporto",
  "passport_entry_noFill": "Nessuna ricarica registrata",
  "passport_entry_lastFill": "{mix} a {pressure}, {date}",
  "passport_spec_title": "Bombola",
  "passport_spec_freeGas": "Gas libero a {pressure}",
  "passport_spec_buoyancyEmpty": "Assetto a vuoto",
  "passport_spec_buoyancyFull": "Assetto a pieno",
  "passport_service_title": "Manutenzione",
  "passport_service_notTracked": "Non tracciato",
  "passport_service_trackO2Clean": "Traccia la pulizia O2",
  "passport_service_lastDone": "Ultima {date}",
  "passport_o2Warning_untracked": "L'ultima ricarica è al {o2} di O2 e questa bombola non è tracciata come pulita per O2.",
  "passport_o2Warning_overdue": "L'ultima ricarica è al {o2} di O2 e la pulizia O2 di questa bombola è scaduta.",
  "passport_fill_title": "Ricarica attuale",
  "passport_fill_none": "Nessuna ricarica registrata finora",
  "passport_fill_log": "Registra una ricarica",
  "passport_fill_mod": "MOD {depth} a ppO2 {ppo2}",
  "passport_fill_end": "END {depth} alla MOD di lavoro",
  "passport_fill_station": "Ricaricata da {station}",
  "passport_fill_analyzer": "Analizzata con {analyzer}",
  "passport_fill_unsigned": "Non firmata",
  "passport_history_title": "Storico ricariche",
  "passport_history_sinceHydro": "{count, plural, =0{Nessuna ricarica dall'ultimo collaudo} =1{{count} ricarica dall'ultimo collaudo} other{{count} ricariche dall'ultimo collaudo}}",
  "passport_history_delete": "Elimina ricarica",
  "passport_history_deleteConfirm": "Eliminare questa ricarica?",
  "passport_tag_title": "Tag",
  "passport_tag_written": "Scritto il {date}",
  "passport_tag_stale": "Il tag è stato scritto prima dell'ultima manutenzione o modifica delle specifiche. Ristampalo.",
  "passport_tag_printLabel": "Stampa etichetta",
  "passport_tag_printLabels": "Stampa etichette",
  "passport_tag_linkExisting": "Collega un tag esistente",
  "passport_tag_linkPrompt": "Incolla il link del tag",
  "passport_tag_linkInvalid": "Non è un tag di bombola",
  "passport_tag_linkInUse": "Questo tag appartiene già a {name}",
  "passport_tag_linked": "Tag collegato",
  "passport_logFill_date": "Ricaricata il",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Pressione di ricarica",
  "passport_logFill_temperature": "Temperatura del gas",
  "passport_logFill_station": "Stazione di ricarica",
  "passport_logFill_analyzer": "Analizzatore",
  "passport_logFill_notes": "Note",
  "passport_logFill_invalidMix": "O2 ed He devono essere tra 0 e 100 e sommare al massimo 100",
  "passport_logFill_invalidNumber": "Inserisci un numero",
```

- [ ] **Step 6: Dutch (`app_nl.arb`)**

```json
  "passport_title": "Flessenpaspoort",
  "passport_open": "Paspoort openen",
  "passport_entry_noFill": "Geen vulling gelogd",
  "passport_entry_lastFill": "{mix} op {pressure}, {date}",
  "passport_spec_title": "Fles",
  "passport_spec_freeGas": "Vrij gas bij {pressure}",
  "passport_spec_buoyancyEmpty": "Drijfvermogen leeg",
  "passport_spec_buoyancyFull": "Drijfvermogen vol",
  "passport_service_title": "Onderhoud",
  "passport_service_notTracked": "Niet bijgehouden",
  "passport_service_trackO2Clean": "O2-reiniging bijhouden",
  "passport_service_lastDone": "Laatste {date}",
  "passport_o2Warning_untracked": "De laatste vulling is {o2} O2 en deze fles wordt niet als O2-schoon bijgehouden.",
  "passport_o2Warning_overdue": "De laatste vulling is {o2} O2 en de O2-reiniging van deze fles is over tijd.",
  "passport_fill_title": "Huidige vulling",
  "passport_fill_none": "Nog geen vulling gelogd",
  "passport_fill_log": "Vulling loggen",
  "passport_fill_mod": "MOD {depth} bij ppO2 {ppo2}",
  "passport_fill_end": "END {depth} op de werk-MOD",
  "passport_fill_station": "Gevuld door {station}",
  "passport_fill_analyzer": "Geanalyseerd met {analyzer}",
  "passport_fill_unsigned": "Niet ondertekend",
  "passport_history_title": "Vulgeschiedenis",
  "passport_history_sinceHydro": "{count, plural, =0{Geen vullingen sinds de laatste hydrotest} =1{{count} vulling sinds de laatste hydrotest} other{{count} vullingen sinds de laatste hydrotest}}",
  "passport_history_delete": "Vulling verwijderen",
  "passport_history_deleteConfirm": "Deze vulling verwijderen?",
  "passport_tag_title": "Tag",
  "passport_tag_written": "Geschreven {date}",
  "passport_tag_stale": "De tag is geschreven vóór het laatste onderhoud of de laatste specificatiewijziging. Druk hem opnieuw af.",
  "passport_tag_printLabel": "Label afdrukken",
  "passport_tag_printLabels": "Labels afdrukken",
  "passport_tag_linkExisting": "Bestaande tag koppelen",
  "passport_tag_linkPrompt": "Plak de link van de tag",
  "passport_tag_linkInvalid": "Dat is geen flessentag",
  "passport_tag_linkInUse": "Die tag hoort al bij {name}",
  "passport_tag_linked": "Tag gekoppeld",
  "passport_logFill_date": "Gevuld op",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Vuldruk",
  "passport_logFill_temperature": "Gastemperatuur",
  "passport_logFill_station": "Vulstation",
  "passport_logFill_analyzer": "Analyser",
  "passport_logFill_notes": "Notities",
  "passport_logFill_invalidMix": "O2 en He moeten elk tussen 0 en 100 liggen en samen hoogstens 100 zijn",
  "passport_logFill_invalidNumber": "Voer een getal in",
```

- [ ] **Step 7: Portuguese (`app_pt.arb`)**

```json
  "passport_title": "Passaporte do cilindro",
  "passport_open": "Abrir passaporte",
  "passport_entry_noFill": "Nenhuma carga registrada",
  "passport_entry_lastFill": "{mix} a {pressure}, {date}",
  "passport_spec_title": "Cilindro",
  "passport_spec_freeGas": "Gás livre a {pressure}",
  "passport_spec_buoyancyEmpty": "Flutuabilidade vazio",
  "passport_spec_buoyancyFull": "Flutuabilidade cheio",
  "passport_service_title": "Manutenção",
  "passport_service_notTracked": "Sem acompanhamento",
  "passport_service_trackO2Clean": "Acompanhar limpeza de O2",
  "passport_service_lastDone": "Última {date}",
  "passport_o2Warning_untracked": "A última carga tem {o2} de O2 e este cilindro não é acompanhado como limpo para O2.",
  "passport_o2Warning_overdue": "A última carga tem {o2} de O2 e a limpeza de O2 deste cilindro está atrasada.",
  "passport_fill_title": "Carga atual",
  "passport_fill_none": "Nenhuma carga registrada ainda",
  "passport_fill_log": "Registrar uma carga",
  "passport_fill_mod": "MOD {depth} a ppO2 {ppo2}",
  "passport_fill_end": "END {depth} na MOD de trabalho",
  "passport_fill_station": "Carregado por {station}",
  "passport_fill_analyzer": "Analisado com {analyzer}",
  "passport_fill_unsigned": "Sem assinatura",
  "passport_history_title": "Histórico de cargas",
  "passport_history_sinceHydro": "{count, plural, =0{Nenhuma carga desde o último teste hidrostático} =1{{count} carga desde o último teste hidrostático} other{{count} cargas desde o último teste hidrostático}}",
  "passport_history_delete": "Excluir carga",
  "passport_history_deleteConfirm": "Excluir este registro de carga?",
  "passport_tag_title": "Etiqueta",
  "passport_tag_written": "Escrita em {date}",
  "passport_tag_stale": "A etiqueta foi escrita antes da última manutenção ou alteração de especificação. Reimprima-a.",
  "passport_tag_printLabel": "Imprimir etiqueta",
  "passport_tag_printLabels": "Imprimir etiquetas",
  "passport_tag_linkExisting": "Vincular uma etiqueta existente",
  "passport_tag_linkPrompt": "Cole o link da etiqueta",
  "passport_tag_linkInvalid": "Isso não é uma etiqueta de cilindro",
  "passport_tag_linkInUse": "Essa etiqueta já pertence a {name}",
  "passport_tag_linked": "Etiqueta vinculada",
  "passport_logFill_date": "Carregado em",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Pressão de carga",
  "passport_logFill_temperature": "Temperatura do gás",
  "passport_logFill_station": "Estação de carga",
  "passport_logFill_analyzer": "Analisador",
  "passport_logFill_notes": "Notas",
  "passport_logFill_invalidMix": "O2 e He devem estar entre 0 e 100 e somar no máximo 100",
  "passport_logFill_invalidNumber": "Digite um número",
```

- [ ] **Step 8: Hungarian (`app_hu.arb`)**

```json
  "passport_title": "Palackútlevél",
  "passport_open": "Útlevél megnyitása",
  "passport_entry_noFill": "Nincs rögzített töltés",
  "passport_entry_lastFill": "{mix}, {pressure}, {date}",
  "passport_spec_title": "Palack",
  "passport_spec_freeGas": "Szabad gáz {pressure} nyomáson",
  "passport_spec_buoyancyEmpty": "Felhajtóerő üresen",
  "passport_spec_buoyancyFull": "Felhajtóerő telve",
  "passport_service_title": "Szervizelés",
  "passport_service_notTracked": "Nem követett",
  "passport_service_trackO2Clean": "O2-tisztítás követése",
  "passport_service_lastDone": "Utoljára: {date}",
  "passport_o2Warning_untracked": "Az utolsó töltés {o2} O2, és ez a palack nincs O2-tisztaként nyilvántartva.",
  "passport_o2Warning_overdue": "Az utolsó töltés {o2} O2, és a palack O2-tisztítása lejárt.",
  "passport_fill_title": "Jelenlegi töltés",
  "passport_fill_none": "Még nincs rögzített töltés",
  "passport_fill_log": "Töltés rögzítése",
  "passport_fill_mod": "MOD {depth} {ppo2} ppO2-nél",
  "passport_fill_end": "END {depth} a munka-MOD-on",
  "passport_fill_station": "Töltötte: {station}",
  "passport_fill_analyzer": "Elemezve: {analyzer}",
  "passport_fill_unsigned": "Aláíratlan",
  "passport_history_title": "Töltési előzmények",
  "passport_history_sinceHydro": "{count, plural, =0{Nincs töltés a legutóbbi nyomáspróba óta} =1{{count} töltés a legutóbbi nyomáspróba óta} other{{count} töltés a legutóbbi nyomáspróba óta}}",
  "passport_history_delete": "Töltés törlése",
  "passport_history_deleteConfirm": "Törli ezt a töltési bejegyzést?",
  "passport_tag_title": "Címke",
  "passport_tag_written": "Írva: {date}",
  "passport_tag_stale": "A címke a legutóbbi szervizelés vagy adatváltozás előtt készült. Nyomtassa ki újra.",
  "passport_tag_printLabel": "Címke nyomtatása",
  "passport_tag_printLabels": "Címkék nyomtatása",
  "passport_tag_linkExisting": "Meglévő címke összekapcsolása",
  "passport_tag_linkPrompt": "Illessze be a címke hivatkozását",
  "passport_tag_linkInvalid": "Ez nem palackcímke",
  "passport_tag_linkInUse": "Ez a címke már ehhez tartozik: {name}",
  "passport_tag_linked": "Címke összekapcsolva",
  "passport_logFill_date": "Töltés dátuma",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "Töltési nyomás",
  "passport_logFill_temperature": "Gázhőmérséklet",
  "passport_logFill_station": "Töltőállomás",
  "passport_logFill_analyzer": "Elemző",
  "passport_logFill_notes": "Jegyzetek",
  "passport_logFill_invalidMix": "Az O2 és a He értéke 0 és 100 közé essen, összegük legfeljebb 100 lehet",
  "passport_logFill_invalidNumber": "Adjon meg egy számot",
```

- [ ] **Step 9: Arabic (`app_ar.arb`)**

```json
  "passport_title": "جواز الأسطوانة",
  "passport_open": "افتح الجواز",
  "passport_entry_noFill": "لم تُسجَّل أي تعبئة",
  "passport_entry_lastFill": "{mix} عند {pressure}، {date}",
  "passport_spec_title": "الأسطوانة",
  "passport_spec_freeGas": "الغاز الحر عند {pressure}",
  "passport_spec_buoyancyEmpty": "الطفو وهي فارغة",
  "passport_spec_buoyancyFull": "الطفو وهي ممتلئة",
  "passport_service_title": "الصيانة",
  "passport_service_notTracked": "غير متابَع",
  "passport_service_trackO2Clean": "متابعة تنظيف الأكسجين",
  "passport_service_lastDone": "آخر مرة {date}",
  "passport_o2Warning_untracked": "آخر تعبئة تحوي {o2} أكسجين، وهذه الأسطوانة غير متابَعة كنظيفة للأكسجين.",
  "passport_o2Warning_overdue": "آخر تعبئة تحوي {o2} أكسجين، وتنظيف الأكسجين لهذه الأسطوانة متأخر.",
  "passport_fill_title": "التعبئة الحالية",
  "passport_fill_none": "لم تُسجَّل أي تعبئة بعد",
  "passport_fill_log": "تسجيل تعبئة",
  "passport_fill_mod": "MOD {depth} عند ppO2 {ppo2}",
  "passport_fill_end": "END {depth} عند MOD العمل",
  "passport_fill_station": "عبّأها {station}",
  "passport_fill_analyzer": "حُلِّلت بجهاز {analyzer}",
  "passport_fill_unsigned": "غير موقَّعة",
  "passport_history_title": "سجل التعبئة",
  "passport_history_sinceHydro": "{count, plural, =0{لا تعبئات منذ آخر اختبار هيدروستاتيكي} =1{{count} تعبئة منذ آخر اختبار هيدروستاتيكي} other{{count} تعبئات منذ آخر اختبار هيدروستاتيكي}}",
  "passport_history_delete": "حذف التعبئة",
  "passport_history_deleteConfirm": "هل تريد حذف سجل التعبئة هذا؟",
  "passport_tag_title": "البطاقة",
  "passport_tag_written": "كُتبت في {date}",
  "passport_tag_stale": "كُتبت البطاقة قبل آخر صيانة أو تغيير في المواصفات. أعد طباعتها.",
  "passport_tag_printLabel": "طباعة الملصق",
  "passport_tag_printLabels": "طباعة الملصقات",
  "passport_tag_linkExisting": "ربط بطاقة موجودة",
  "passport_tag_linkPrompt": "الصق الرابط من البطاقة",
  "passport_tag_linkInvalid": "هذه ليست بطاقة أسطوانة",
  "passport_tag_linkInUse": "هذه البطاقة تعود بالفعل إلى {name}",
  "passport_tag_linked": "تم ربط البطاقة",
  "passport_logFill_date": "تاريخ التعبئة",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "ضغط التعبئة",
  "passport_logFill_temperature": "درجة حرارة الغاز",
  "passport_logFill_station": "محطة التعبئة",
  "passport_logFill_analyzer": "جهاز التحليل",
  "passport_logFill_notes": "ملاحظات",
  "passport_logFill_invalidMix": "يجب أن يكون كل من O2 وHe بين 0 و100 وألا يتجاوز مجموعهما 100",
  "passport_logFill_invalidNumber": "أدخل رقمًا",
```

- [ ] **Step 10: Hebrew (`app_he.arb`)**

```json
  "passport_title": "דרכון המיכל",
  "passport_open": "פתיחת הדרכון",
  "passport_entry_noFill": "לא נרשם מילוי",
  "passport_entry_lastFill": "{mix} ב-{pressure}, {date}",
  "passport_spec_title": "מיכל",
  "passport_spec_freeGas": "גז חופשי ב-{pressure}",
  "passport_spec_buoyancyEmpty": "ציפה כשריק",
  "passport_spec_buoyancyFull": "ציפה כשמלא",
  "passport_service_title": "טיפולים",
  "passport_service_notTracked": "לא במעקב",
  "passport_service_trackO2Clean": "מעקב אחר ניקוי O2",
  "passport_service_lastDone": "לאחרונה {date}",
  "passport_o2Warning_untracked": "המילוי האחרון הוא {o2} O2 והמיכל הזה אינו במעקב כנקי ל-O2.",
  "passport_o2Warning_overdue": "המילוי האחרון הוא {o2} O2 וניקוי ה-O2 של המיכל הזה באיחור.",
  "passport_fill_title": "מילוי נוכחי",
  "passport_fill_none": "עדיין לא נרשם מילוי",
  "passport_fill_log": "רישום מילוי",
  "passport_fill_mod": "MOD {depth} ב-ppO2 {ppo2}",
  "passport_fill_end": "END {depth} ב-MOD העבודה",
  "passport_fill_station": "מולא על ידי {station}",
  "passport_fill_analyzer": "נותח באמצעות {analyzer}",
  "passport_fill_unsigned": "לא חתום",
  "passport_history_title": "היסטוריית מילויים",
  "passport_history_sinceHydro": "{count, plural, =0{אין מילויים מאז מבחן הלחץ האחרון} =1{{count} מילוי מאז מבחן הלחץ האחרון} other{{count} מילויים מאז מבחן הלחץ האחרון}}",
  "passport_history_delete": "מחיקת מילוי",
  "passport_history_deleteConfirm": "למחוק את רשומת המילוי הזו?",
  "passport_tag_title": "תג",
  "passport_tag_written": "נכתב {date}",
  "passport_tag_stale": "התג נכתב לפני הטיפול או שינוי המפרט האחרון. יש להדפיסו מחדש.",
  "passport_tag_printLabel": "הדפסת תווית",
  "passport_tag_printLabels": "הדפסת תוויות",
  "passport_tag_linkExisting": "קישור תג קיים",
  "passport_tag_linkPrompt": "הדביקו את הקישור מהתג",
  "passport_tag_linkInvalid": "זה אינו תג מיכל",
  "passport_tag_linkInUse": "התג הזה כבר שייך ל-{name}",
  "passport_tag_linked": "התג קושר",
  "passport_logFill_date": "מולא בתאריך",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "לחץ מילוי",
  "passport_logFill_temperature": "טמפרטורת הגז",
  "passport_logFill_station": "תחנת מילוי",
  "passport_logFill_analyzer": "מנתח",
  "passport_logFill_notes": "הערות",
  "passport_logFill_invalidMix": "O2 ו-He חייבים להיות בין 0 ל-100 וסכומם עד 100",
  "passport_logFill_invalidNumber": "יש להזין מספר",
```

- [ ] **Step 11: Chinese (`app_zh.arb`)**

```json
  "passport_title": "气瓶护照",
  "passport_open": "打开护照",
  "passport_entry_noFill": "尚无充气记录",
  "passport_entry_lastFill": "{mix}，{pressure}，{date}",
  "passport_spec_title": "气瓶",
  "passport_spec_freeGas": "{pressure} 下的自由气体量",
  "passport_spec_buoyancyEmpty": "空瓶浮力",
  "passport_spec_buoyancyFull": "满瓶浮力",
  "passport_service_title": "保养",
  "passport_service_notTracked": "未跟踪",
  "passport_service_trackO2Clean": "跟踪氧清洁",
  "passport_service_lastDone": "上次 {date}",
  "passport_o2Warning_untracked": "最近一次充气为 {o2} 氧气，而该气瓶未作为氧清洁气瓶跟踪。",
  "passport_o2Warning_overdue": "最近一次充气为 {o2} 氧气，而该气瓶的氧清洁已过期。",
  "passport_fill_title": "当前充气",
  "passport_fill_none": "尚未记录充气",
  "passport_fill_log": "记录充气",
  "passport_fill_mod": "ppO2 {ppo2} 时 MOD {depth}",
  "passport_fill_end": "工作 MOD 处 END {depth}",
  "passport_fill_station": "由 {station} 充气",
  "passport_fill_analyzer": "使用 {analyzer} 分析",
  "passport_fill_unsigned": "未签名",
  "passport_history_title": "充气历史",
  "passport_history_sinceHydro": "{count, plural, =0{上次水压测试以来无充气} =1{上次水压测试以来 {count} 次充气} other{上次水压测试以来 {count} 次充气}}",
  "passport_history_delete": "删除充气记录",
  "passport_history_deleteConfirm": "删除此充气记录？",
  "passport_tag_title": "标签",
  "passport_tag_written": "写入于 {date}",
  "passport_tag_stale": "该标签写入于最近一次保养或规格变更之前。请重新打印。",
  "passport_tag_printLabel": "打印标签",
  "passport_tag_printLabels": "打印标签",
  "passport_tag_linkExisting": "关联现有标签",
  "passport_tag_linkPrompt": "粘贴标签上的链接",
  "passport_tag_linkInvalid": "这不是气瓶标签",
  "passport_tag_linkInUse": "该标签已属于 {name}",
  "passport_tag_linked": "标签已关联",
  "passport_logFill_date": "充气日期",
  "passport_logFill_o2": "O2 (%)",
  "passport_logFill_he": "He (%)",
  "passport_logFill_pressure": "充气压力",
  "passport_logFill_temperature": "气体温度",
  "passport_logFill_station": "充气站",
  "passport_logFill_analyzer": "分析仪",
  "passport_logFill_notes": "备注",
  "passport_logFill_invalidMix": "O2 和 He 须各在 0 到 100 之间，且总和不超过 100",
  "passport_logFill_invalidNumber": "请输入数字",
```

- [ ] **Step 12: Regenerate and run the l10n guards**

Run: `flutter gen-l10n`
Expected: no errors.

Run: `flutter test test/l10n/`
Expected: all pass (parity across the 10 locales, no duplicate keys, plural interpolation, diacritics).

- [ ] **Step 13: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/l10n/
git commit -m "feat(l10n): cylinder passport strings in all locales

Refs #2334"
```

---

### Task 12: The manual fill sheet

**Files:**
- Create: `lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`

**Interfaces:**
- Consumes: `CylinderFill`, `cylinderFillRepositoryProvider`, `settingsProvider`, `UnitFormatter` (`pressureSymbol`, `temperatureSymbol`, `pressureToBar`, `convertPressure`, `formatDate`), `validatedCurrentDiverIdProvider`, `context.l10n.forms_cancel` and `forms_save`.
- Produces: `Future<CylinderFill?> showLogFillSheet(BuildContext context, {required String passportId, required String equipmentId})` which opens a modal bottom sheet and resolves with the saved fill or null; `double? parseDecimal(String text)` (accepts `,` as a decimal separator, returns null for anything that is not a number) exported from the same file; `class LogFillSheet extends ConsumerStatefulWidget` for tests.

Behaviour: fields for date (tap opens `showDatePicker`, default now), O2 percent (default 21), He percent (default 0), fill pressure in the diver's unit, gas temperature in the diver's unit, station name, analyzer, notes. Save validates: O2 and He each parse and lie in 0 to 100, and O2 + He is at most 100, else the field shows `passport_logFill_invalidMix`; an unparseable pressure or temperature shows `passport_logFill_invalidNumber`. On save it converts pressure to bar and temperature to Celsius with `UnitFormatter` and calls `create` with source `manual` and the current diver id.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  group('parseDecimal', () {
    test('accepts a decimal comma', () {
      expect(parseDecimal('11,1'), 11.1);
      expect(parseDecimal('32'), 32);
      expect(parseDecimal(' 32.5 '), 32.5);
    });

    test('rejects letters and blanks', () {
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal(''), isNull);
    });
  });

  Future<void> pump(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const LogFillSheet(passportId: 'pp-1', equipmentId: 'eq-1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every field with the diver units', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    expect(find.text(l10n.passport_logFill_o2), findsOneWidget);
    expect(find.text(l10n.passport_logFill_he), findsOneWidget);
    expect(find.text(l10n.passport_logFill_pressure), findsOneWidget);
    expect(find.text(l10n.passport_logFill_temperature), findsOneWidget);
    expect(find.text(l10n.passport_logFill_station), findsOneWidget);
    expect(find.text(l10n.passport_logFill_analyzer), findsOneWidget);
    expect(find.text(l10n.forms_save), findsOneWidget);
  });

  testWidgets('refuses a mix over 100 percent', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_o2')), '60');
    await tester.enterText(find.byKey(const Key('logFill_he')), '50');
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidMix), findsOneWidget);
  });

  testWidgets('refuses letters in a number field', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_pressure')), 'abc');
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidNumber), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`
Expected: compile error.

- [ ] **Step 3: Create the sheet**

Create `lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A number typed by a diver: a decimal comma is a decimal point, blanks and
/// letters are not numbers.
double? parseDecimal(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Opens the manual fill sheet. Resolves with the saved fill, or null when
/// the diver backed out.
Future<CylinderFill?> showLogFillSheet(
  BuildContext context, {
  required String passportId,
  required String equipmentId,
}) => showModalBottomSheet<CylinderFill>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LogFillSheet(passportId: passportId, equipmentId: equipmentId),
  ),
);

class LogFillSheet extends ConsumerStatefulWidget {
  const LogFillSheet({
    super.key,
    required this.passportId,
    required this.equipmentId,
  });

  final String passportId;
  final String equipmentId;

  @override
  ConsumerState<LogFillSheet> createState() => _LogFillSheetState();
}

class _LogFillSheetState extends ConsumerState<LogFillSheet> {
  DateTime _filledAt = DateTime.now();
  final _o2 = TextEditingController(text: '21');
  final _he = TextEditingController(text: '0');
  final _pressure = TextEditingController();
  final _temperature = TextEditingController();
  final _station = TextEditingController();
  final _analyzer = TextEditingController();
  final _notes = TextEditingController();
  String? _mixError;
  String? _pressureError;
  String? _temperatureError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _o2,
      _he,
      _pressure,
      _temperature,
      _station,
      _analyzer,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filledAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _filledAt.hour,
        _filledAt.minute,
      );
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final o2 = parseDecimal(_o2.text);
    final he = parseDecimal(_he.text);
    final pressureText = _pressure.text.trim();
    final temperatureText = _temperature.text.trim();
    final pressure = pressureText.isEmpty ? null : parseDecimal(pressureText);
    final temperature = temperatureText.isEmpty
        ? null
        : parseDecimal(temperatureText);

    final mixInvalid =
        o2 == null ||
        he == null ||
        o2 < 0 ||
        o2 > 100 ||
        he < 0 ||
        he > 100 ||
        o2 + he > 100;
    setState(() {
      _mixError = mixInvalid ? l10n.passport_logFill_invalidMix : null;
      _pressureError = pressureText.isNotEmpty && pressure == null
          ? l10n.passport_logFill_invalidNumber
          : null;
      _temperatureError = temperatureText.isNotEmpty && temperature == null
          ? l10n.passport_logFill_invalidNumber
          : null;
    });
    if (_mixError != null ||
        _pressureError != null ||
        _temperatureError != null) {
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final fill = CylinderFill(
      id: '',
      diverId: diverId,
      passportId: widget.passportId,
      equipmentId: widget.equipmentId,
      filledAt: _filledAt,
      o2Percent: o2!,
      hePercent: he!,
      pressureBar: pressure == null ? null : units.pressureToBar(pressure),
      temperatureC: temperature == null
          ? null
          : units.temperatureToCelsius(temperature),
      analyzer: _analyzer.text.trim().isEmpty ? null : _analyzer.text.trim(),
      stationName: _station.text.trim().isEmpty ? null : _station.text.trim(),
      source: FillSource.manual,
      notes: _notes.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final saved = await ref.read(cylinderFillRepositoryProvider).create(fill);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.passport_fill_log, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.passport_logFill_date),
            subtitle: Text(units.formatDate(_filledAt)),
            onTap: _pickDate,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('logFill_o2'),
                  controller: _o2,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_o2,
                    errorText: _mixError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('logFill_he'),
                  controller: _he,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.passport_logFill_he),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('logFill_pressure'),
                  controller: _pressure,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_pressure,
                    suffixText: units.pressureSymbol,
                    errorText: _pressureError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('logFill_temperature'),
                  controller: _temperature,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_temperature,
                    suffixText: units.temperatureSymbol,
                    errorText: _temperatureError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _station,
            decoration: InputDecoration(labelText: l10n.passport_logFill_station),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _analyzer,
            decoration: InputDecoration(labelText: l10n.passport_logFill_analyzer),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.passport_logFill_notes),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.forms_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.forms_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

`UnitFormatter` has `pressureToBar`; if it has no `temperatureToCelsius`, add one beside `convertTemperature` in `lib/core/utils/unit_formatter.dart` that inverts the display conversion (`(f - 32) * 5 / 9` for Fahrenheit, identity for Celsius), with a unit test in `test/core/utils/unit_formatter_test.dart` (or the existing formatter test file) asserting `212` Fahrenheit becomes `100`.

- [ ] **Step 4: Run the test, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart lib/core/utils/unit_formatter.dart test/core/utils/
git commit -m "feat(passports): manual fill sheet

Refs #2334"
```

---

### Task 13: The passport page and its cards

**Files:**
- Create: `lib/features/cylinder_passports/presentation/pages/passport_page.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_spec_card.dart`, `passport_service_card.dart`, `passport_o2_warning_banner.dart`, `passport_current_fill_card.dart`, `passport_fill_history_card.dart`
- Test: `test/features/cylinder_passports/presentation/pages/passport_page_test.dart`

**Interfaces:**
- Consumes: `equipmentItemProvider`, `serviceClockStatusesProvider`, `equipmentRollupClockProvider`, `RollupClock`, `ServiceStatusIndicator`, `formatServiceTriggerText`, `serviceScheduleRepositoryProvider` (`createSchedule`), `invalidateServiceClockProviders` (from `service_schedule_dialogs.dart`), `passportIdProvider`, `fillsForEquipmentProvider`, `newestFillProvider`, `cylinderPassportRepositoryProvider.ensurePassportId`, `cylinderFillRepositoryProvider.delete`, `PassportSpecMetrics`, `PassportGasLimits`, `o2CleanWarning`, `settingsProvider` (`ppO2MaxWorking`, `ppO2MaxDeco`, `o2Narcotic`, `gasModel`), `exposureThresholdsProvider` (in `lib/features/equipment/presentation/providers/exposure_thresholds_provider.dart`; read `highO2Fraction` from its value), `showLogFillSheet`, `StatusColors`, `attributeLabel`, `attributeChoiceLabel`.
- Produces: `class PassportPage extends ConsumerStatefulWidget { final String equipmentId; }`; the five cards, each a `ConsumerWidget` taking `equipmentId` and, where useful, the `EquipmentItem`. Task 14 adds `PassportTagCard` to the page column; Task 16 routes to the page.

The page mints the passport id in `initState` (`ensurePassportId`, then `ref.invalidate(passportIdProvider(id))`) so every card can rely on one existing.

- [ ] **Step 1: Write the failing page test**

Create `test/features/cylinder_passports/presentation/pages/passport_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late String? savedIntlLocale;
  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 25);
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
    brand: 'Faber',
    serialNumber: 'F123',
    attributes: [
      EquipmentAttribute(
        id: 'a2',
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: 12,
      ),
      EquipmentAttribute(
        id: 'a3',
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
      EquipmentAttribute(
        id: 'a4',
        equipmentId: id,
        key: EquipmentAttrKeys.tankMaterial,
        valueText: 'steel',
      ),
    ],
  );

  ServiceClockStatus clock(String kindId, ServiceClockSeverity severity) =>
      ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-$kindId',
          equipmentId: id,
          serviceKindId: kindId,
          createdAt: now,
          updatedAt: now,
        ),
        kind: ServiceKind(
          id: kindId,
          name: kindId,
          createdAt: now,
          updatedAt: now,
        ),
        anchor: DateTime(2025, 1, 1),
        dueDate: DateTime(2027, 1, 1),
        severity: severity,
        now: now,
      );

  CylinderFill fill(double o2) => CylinderFill(
    id: 'f-$o2',
    passportId: pid,
    equipmentId: id,
    filledAt: DateTime(2026, 9, 20),
    o2Percent: o2,
    pressureBar: 220,
    stationName: 'Blue Water Fills',
    createdAt: now,
    updatedAt: now,
  );

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    List<CylinderFill> fills = const [],
    List<ServiceClockStatus> clocks = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(id).overrideWith((ref) async => tank),
          passportIdProvider(id).overrideWith((ref) async => pid),
          fillsForEquipmentProvider(id).overrideWith((ref) async => fills),
          newestFillProvider(id).overrideWith(
            (ref) async => fills.isEmpty ? null : fills.first,
          ),
          serviceClockStatusesProvider(id).overrideWith((ref) async => clocks),
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PassportPage(equipmentId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportPage)));
  }

  testWidgets('shows the spec and derived figures', (tester) async {
    final l10n = await pump(tester);
    expect(find.text('Faber 12'), findsWidgets);
    expect(find.text(l10n.passport_spec_title), findsOneWidget);
    expect(find.text('12 L'), findsOneWidget);
    expect(find.text('232 bar'), findsOneWidget);
    expect(find.text(l10n.passport_spec_buoyancyEmpty), findsOneWidget);
    expect(find.text(l10n.passport_spec_buoyancyFull), findsOneWidget);
    expect(find.textContaining(l10n.passport_spec_freeGas('232 bar')), findsOneWidget);
  });

  testWidgets('with no fill shows the empty state and the log button', (tester) async {
    final l10n = await pump(tester);
    expect(find.text(l10n.passport_fill_none), findsOneWidget);
    expect(find.text(l10n.passport_fill_log), findsOneWidget);
    expect(find.text(l10n.passport_history_sinceHydro(0)), findsOneWidget);
  });

  testWidgets('shows the current fill with MOD at both limits', (tester) async {
    final l10n = await pump(tester, fills: [fill(32)]);
    expect(find.text('EAN32'), findsWidgets);
    expect(find.text(l10n.passport_fill_station('Blue Water Fills')), findsOneWidget);
    expect(find.text(l10n.passport_fill_unsigned), findsWidgets);
    // EAN32: 33.75 m at 1.4, 40.0 m at 1.6.
    expect(find.text(l10n.passport_fill_mod('33.8m', '1.4')), findsOneWidget);
    expect(find.text(l10n.passport_fill_mod('40.0m', '1.6')), findsOneWidget);
  });

  testWidgets('warns when a rich fill meets an untracked O2 clean clock', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill(50)],
      clocks: [clock('hydro', ServiceClockSeverity.ok)],
    );
    expect(find.text(l10n.passport_o2Warning_untracked('50%')), findsOneWidget);
    expect(find.text(l10n.passport_service_trackO2Clean), findsOneWidget);
  });

  testWidgets('no warning when the O2 clean clock is current', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill(50)],
      clocks: [clock('o2-clean', ServiceClockSeverity.ok)],
    );
    expect(find.text(l10n.passport_o2Warning_untracked('50%')), findsNothing);
    expect(find.text(l10n.passport_service_trackO2Clean), findsNothing);
  });

  testWidgets('lists service clocks with their last date', (tester) async {
    final l10n = await pump(
      tester,
      clocks: [clock('hydro', ServiceClockSeverity.overdue)],
    );
    expect(find.text('hydro'), findsWidgets);
    expect(find.textContaining(l10n.passport_service_lastDone('')), findsWidgets);
  });
}
```

The two `passport_fill_mod` expectations assume the base mock settings use metric depth with one decimal (`formatDepth` yields `33.8m`); if `MockSettingsNotifier` defaults differ, print the rendered text once and pin the test to the formatter's real output, never to a hand-typed string with different units.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/presentation/pages/passport_page_test.dart`
Expected: compile error.

- [ ] **Step 3: Create the spec card**

Create `lib/features/cylinder_passports/presentation/widgets/passport_spec_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Volume, working pressure, material and valve from the attributes; free
/// gas and buoyancy derived through the diver's gas model and the tank
/// physics (spec section 8, Cylinder card).
class PassportSpecCard extends ConsumerWidget {
  const PassportSpecCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final newest = ref.watch(newestFillProvider(equipment.id)).value;
    final metrics = PassportSpecMetrics.compute(
      volumeL: equipment.volumeL,
      workingPressureBar: equipment.workingPressureBar,
      material: equipment.tankMaterial,
      o2Percent: newest?.o2Percent ?? 21,
      hePercent: newest?.hePercent ?? 0,
      gasModel: settings.gasModel,
    );
    final valve = equipment.attrText('valve_type');
    final rows = <(String, String)>[
      if (equipment.volumeL != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.volumeL),
          units.formatVolume(equipment.volumeL),
        ),
      if (equipment.workingPressureBar != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.workingPressureBar),
          units.formatPressure(equipment.workingPressureBar),
        ),
      if (equipment.tankMaterial != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.tankMaterial),
          attributeChoiceLabel(
            l10n,
            EquipmentAttrKeys.tankMaterial,
            equipment.attrText(EquipmentAttrKeys.tankMaterial) ?? '',
          ),
        ),
      if (valve != null)
        (
          attributeLabel(l10n, 'valve_type'),
          attributeChoiceLabel(l10n, 'valve_type', valve),
        ),
      if (metrics.freeGasLiters != null)
        (
          l10n.passport_spec_freeGas(
            units.formatPressure(equipment.workingPressureBar),
          ),
          units.formatVolume(metrics.freeGasLiters),
        ),
      if (metrics.emptyBuoyancyKg != null)
        (
          l10n.passport_spec_buoyancyEmpty,
          units.formatWeight(metrics.emptyBuoyancyKg),
        ),
      if (metrics.fullBuoyancyKg != null)
        (
          l10n.passport_spec_buoyancyFull,
          units.formatWeight(metrics.fullBuoyancyKg),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_spec_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create the service card and the warning banner**

Create `lib/features/cylinder_passports/presentation/widgets/passport_service_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three cylinder clocks the passport cares about, in this order.
const List<String> kPassportServiceKinds = ['hydro', 'vip', 'o2-clean'];

/// Hydro, VIP and O2 clean read from the service clocks, never from the
/// catalog date attributes, so the passport cannot contradict the reminders
/// (spec section 8, Service card).
class PassportServiceCard extends ConsumerWidget {
  const PassportServiceCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  Future<void> _trackO2Clean(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    await ref
        .read(serviceScheduleRepositoryProvider)
        .createSchedule(
          ServiceSchedule(
            id: '',
            equipmentId: equipment.id,
            serviceKindId: 'o2-clean',
            createdAt: now,
            updatedAt: now,
          ),
        );
    invalidateServiceClockProviders(ref, equipment.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final byKind = {for (final c in clocks) c.kind.id: c};
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_service_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final kindId in kPassportServiceKinds)
              if (byKind[kindId] case final status?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(status.kind.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.passport_service_lastDone(
                          units.formatDate(status.anchor),
                        ),
                      ),
                      Text(
                        formatServiceTriggerText(
                          context,
                          units: units,
                          now: now,
                          dueDate: status.dueDate,
                          usageByUnit: status.usageByUnit,
                        ),
                      ),
                    ],
                  ),
                  trailing: ServiceStatusIndicator(
                    clock: (
                      ownerId: equipment.id,
                      ownerName: equipment.name,
                      status: status,
                    ),
                    subjectId: equipment.id,
                    density: ServiceIndicatorDensity.dot,
                  ),
                )
              else if (kindId == 'o2-clean')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(kindId),
                  subtitle: Text(l10n.passport_service_notTracked),
                  trailing: TextButton(
                    onPressed: () => _trackO2Clean(context, ref),
                    child: Text(l10n.passport_service_trackO2Clean),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
```

For the untracked row title, prefer the built-in kind's display name over the raw id: read `ref.watch(serviceKindsProvider).value` and use the name of the kind whose id is `o2-clean` when present, falling back to the id.

Create `lib/features/cylinder_passports/presentation/widgets/passport_o2_warning_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Rich fill in a cylinder with no current O2 clean clock (spec section 8).
/// Renders nothing when there is nothing to say.
class PassportO2WarningBanner extends ConsumerWidget {
  const PassportO2WarningBanner({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newest = ref.watch(newestFillProvider(equipmentId)).value;
    final clocks = ref.watch(serviceClockStatusesProvider(equipmentId)).value;
    final thresholds = ref.watch(exposureThresholdsProvider);
    final o2Clock = clocks?.where((c) => c.kind.id == 'o2-clean').firstOrNull;
    final warning = o2CleanWarning(
      newestO2Percent: newest?.o2Percent,
      o2CleanClock: o2Clock,
      highO2Fraction: thresholds.highO2Fraction,
    );
    if (warning == O2CleanWarning.none) return const SizedBox.shrink();
    final l10n = context.l10n;
    final o2 = '${newest!.o2Percent.round()}%';
    final swatch = StatusColors.of(context).alert;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: swatch.container,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: swatch.onContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  warning == O2CleanWarning.untracked
                      ? l10n.passport_o2Warning_untracked(o2)
                      : l10n.passport_o2Warning_overdue(o2),
                  style: TextStyle(color: swatch.onContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

If `exposureThresholdsProvider` is async (`AsyncValue`), read `.value?.highO2Fraction ?? ExposureThresholds.defaults.highO2Fraction` instead; check the provider's type in `exposure_thresholds_provider.dart` first.

- [ ] **Step 5: Create the current fill and history cards**

Create `lib/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest fill: mix, pressure, station, and the depth limits at the
/// diver's own ppO2 limits (spec section 8, Current fill card).
class PassportCurrentFillCard extends ConsumerWidget {
  const PassportCurrentFillCard({
    super.key,
    required this.equipmentId,
    required this.passportId,
  });

  final String equipmentId;
  final String? passportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final newest = ref.watch(newestFillProvider(equipmentId)).value;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passport_fill_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (newest == null)
              Text(l10n.passport_fill_none)
            else
              _FillSummary(fill: newest, units: units, settings: settings),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: passportId == null
                    ? null
                    : () => showLogFillSheet(
                        context,
                        passportId: passportId!,
                        equipmentId: equipmentId,
                      ),
                icon: const Icon(Icons.add),
                label: Text(l10n.passport_fill_log),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillSummary extends StatelessWidget {
  const _FillSummary({
    required this.fill,
    required this.units,
    required this.settings,
  });

  final CylinderFill fill;
  final UnitFormatter units;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final limits = PassportGasLimits.compute(
      mix: fill.gasMix,
      ppO2Working: settings.ppO2MaxWorking,
      ppO2Deco: settings.ppO2MaxDeco,
      o2Narcotic: settings.o2Narcotic,
    );
    String ppo2(double v) => v.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(fill.gasMix.name, style: theme.textTheme.headlineSmall),
            const SizedBox(width: 12),
            if (fill.pressureBar != null)
              Text(units.formatPressure(fill.pressureBar)),
            const Spacer(),
            FillSourceBadge(fill: fill),
          ],
        ),
        Text(units.formatDate(fill.filledAt)),
        if (fill.stationName != null)
          Text(l10n.passport_fill_station(fill.stationName!)),
        if (fill.analyzer != null)
          Text(l10n.passport_fill_analyzer(fill.analyzer!)),
        const SizedBox(height: 8),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modWorkingM),
            ppo2(settings.ppO2MaxWorking),
          ),
        ),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modDecoM),
            ppo2(settings.ppO2MaxDeco),
          ),
        ),
        if (limits.endAtWorkingModM != null)
          Text(l10n.passport_fill_end(units.formatDepth(limits.endAtWorkingModM))),
      ],
    );
  }
}

/// Unsigned for a manual fill. PR 3 replaces this with the verification
/// badge; keeping the widget name lets that PR swap the body only.
class FillSourceBadge extends StatelessWidget {
  const FillSourceBadge({super.key, required this.fill});

  final CylinderFill fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.passport_fill_unsigned,
      child: Chip(
        label: Text(context.l10n.passport_fill_unsigned),
        avatar: const Icon(Icons.edit_note, size: 18),
        labelStyle: theme.textTheme.labelSmall,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
```

Create `lib/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every fill, newest first, with the count since the last hydro
/// (spec section 8, Fill history card).
class PassportFillHistoryCard extends ConsumerWidget {
  const PassportFillHistoryCard({super.key, required this.equipmentId});

  final String equipmentId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CylinderFill fill,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.passport_history_delete),
        content: Text(l10n.passport_history_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.forms_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.passport_history_delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(cylinderFillRepositoryProvider).delete(fill.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final fills =
        ref.watch(fillsForEquipmentProvider(equipmentId)).value ??
        const <CylinderFill>[];
    final clocks = ref.watch(serviceClockStatusesProvider(equipmentId)).value;
    final hydroAnchor = clocks
        ?.where((c) => c.kind.id == 'hydro')
        .firstOrNull
        ?.anchor;
    final sinceHydro = hydroAnchor == null
        ? fills.length
        : fills.where((f) => !f.filledAt.isBefore(hydroAnchor)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_history_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(l10n.passport_history_sinceHydro(sinceHydro)),
            const SizedBox(height: 8),
            for (final fill in fills)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(fill.gasMix.name),
                subtitle: Text(
                  [
                    units.formatDate(fill.filledAt),
                    if (fill.pressureBar != null)
                      units.formatPressure(fill.pressureBar),
                    if (fill.stationName != null) fill.stationName!,
                  ].join(', '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FillSourceBadge(fill: fill),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.passport_history_delete,
                      onPressed: () => _confirmDelete(context, ref, fill),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create the page**

Create `lib/features/cylinder_passports/presentation/pages/passport_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_o2_warning_banner.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_service_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_spec_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder's passport (spec section 8): every card names its source of
/// truth, and every value with a unit goes through the unit formatter.
class PassportPage extends ConsumerStatefulWidget {
  const PassportPage({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  ConsumerState<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends ConsumerState<PassportPage> {
  @override
  void initState() {
    super.initState();
    // The passport id is minted the first time the passport is opened, so
    // every card below can rely on one existing.
    Future<void>.microtask(() async {
      final existing = await ref.read(
        passportIdProvider(widget.equipmentId).future,
      );
      if (existing != null || !mounted) return;
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      await ref
          .read(cylinderPassportRepositoryProvider)
          .ensurePassportId(widget.equipmentId, diverId: diverId);
      if (mounted) ref.invalidate(passportIdProvider(widget.equipmentId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));
    final passportId = ref.watch(passportIdProvider(widget.equipmentId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passport_title)),
      body: equipmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (equipment) {
          if (equipment == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassportHeader(equipment: equipment),
                const SizedBox(height: 16),
                PassportO2WarningBanner(equipmentId: equipment.id),
                PassportSpecCard(equipment: equipment),
                const SizedBox(height: 16),
                PassportServiceCard(equipment: equipment),
                const SizedBox(height: 16),
                PassportCurrentFillCard(
                  equipmentId: equipment.id,
                  passportId: passportId,
                ),
                const SizedBox(height: 16),
                PassportFillHistoryCard(equipmentId: equipment.id),
                // Task 14 appends PassportTagCard here.
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassportHeader extends StatelessWidget {
  const _PassportHeader({required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (equipment.brand?.isNotEmpty ?? false) equipment.brand!,
      if (equipment.model?.isNotEmpty ?? false) equipment.model!,
      if (equipment.serialNumber?.isNotEmpty ?? false) equipment.serialNumber!,
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipment.name, style: theme.textTheme.headlineMedium),
        if (equipment.identifier != null)
          Text(equipment.identifier!, style: theme.textTheme.titleMedium),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
```

- [ ] **Step 7: Run the page test and the architecture guards**

Run: `flutter test test/features/cylinder_passports/presentation/pages/passport_page_test.dart test/architecture/preference_aware_date_format_test.dart test/architecture/service_status_wording_single_source_test.dart`
Expected: all pass.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/pages/passport_page.dart lib/features/cylinder_passports/presentation/widgets/ test/features/cylinder_passports/presentation/pages/passport_page_test.dart
git commit -m "feat(passports): the passport page with spec, service, fill and history cards

Refs #2334"
```

---

### Task 14: The tag card, the QR view and linking an existing tag

**Files:**
- Modify: `pubspec.yaml` (promote `qr: ^3.0.2` from transitive to a direct dependency, in the `dependencies` block near `pdf`)
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_qr_view.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart`
- Modify: `lib/features/cylinder_passports/presentation/pages/passport_page.dart` (add `scannedTag` parameter, append the card)
- Test: `test/features/cylinder_passports/presentation/widgets/passport_qr_view_test.dart`, `test/features/cylinder_passports/presentation/widgets/passport_tag_card_test.dart`

**Interfaces:**
- Consumes: `PassportPayloadCodec`, `payloadForItem`, `tagIsStale`, `cylinderPassportRepositoryProvider` (`assignPassportId`, `PassportIdInUse`), `equipmentRepositoryProvider.getEquipmentById`, `serviceClockStatusesProvider`, `passportIdProvider`, `fillsForEquipmentProvider`.
- Produces:
  - `class PassportQrView extends StatelessWidget { final String data; final double size; }` painting the code with `package:qr` at error correction M, dark modules in `onSurface`, light background, wrapped in `Semantics(label: data)`.
  - `Future<CylinderPassportPayload?> showLinkExistingTagDialog(BuildContext context, {required String equipmentId, String? diverId})`: resolves with the linked tag's payload, or null.
  - `class PassportTagCard extends ConsumerWidget { final EquipmentItem equipment; final CylinderPassportPayload? scannedTag; final Future<void> Function()? onPrintLabel; }` (Task 15 wires `onPrintLabel`).
  - `PassportPage({required String equipmentId, CylinderPassportPayload? scannedTag})`; PR 1b passes `scannedTag` from the resolver.
  - `CylinderPassportPayload? currentPayloadFor(EquipmentItem item, {required String passportId, required List<ServiceClockStatus> clocks, required DateTime now})` in `passport_tag_card.dart`: the payload a fresh label should carry, using the hydro and VIP clock anchors and the O2 clean clock's severity.

- [ ] **Step 1: Write the failing QR view test**

Create `test/features/cylinder_passports/presentation/widgets/passport_qr_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';

void main() {
  const url =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-25';

  testWidgets('paints one module per QR cell and labels itself', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PassportQrView(data: url, size: 200))),
      ),
    );
    final code = QrCode.fromData(data: url, errorCorrectLevel: QrErrorCorrectLevel.M);
    final painter = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(PassportQrView), matching: find.byType(CustomPaint)),
    );
    expect((painter.painter as QrModulesPainter).moduleCount, code.moduleCount);
    expect(find.bySemanticsLabel(url), findsOneWidget);
  });

  test('a full 150-character payload is a version 7 or smaller code', () {
    final code = QrCode.fromData(
      data: '$url&n=Steel+12+L&sn=AB12345&v=12&wp=232&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1',
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    expect(code.typeNumber, lessThanOrEqualTo(7));
  });
}
```

- [ ] **Step 2: Promote `qr` and create the view**

In `pubspec.yaml`, in `dependencies`, next to `pdf: ^3.11.1`, add `qr: ^3.0.2` with the comment `# on-screen cylinder passport QR; the pdf label uses pw.BarcodeWidget`. Run `flutter pub get`; the lockfile must not change versions (3.0.2 is already resolved).

Create `lib/features/cylinder_passports/presentation/widgets/passport_qr_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// The tag string as an on-screen QR code (spec section 8, Tag card).
/// Error correction M matches the printed label so both scan alike.
class PassportQrView extends StatelessWidget {
  const PassportQrView({super.key, required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: data,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: QrModulesPainter(image: image, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class QrModulesPainter extends CustomPainter {
  QrModulesPainter({required this.image, required this.color});

  final QrImage image;
  final Color color;

  int get moduleCount => image.moduleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cell = size.shortestSide / image.moduleCount;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(QrModulesPainter old) =>
      old.image != image || old.color != color;
}
```

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_qr_view_test.dart`
Expected: all pass.

- [ ] **Step 3: Write the failing tag card test**

Create `test/features/cylinder_passports/presentation/widgets/passport_tag_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 25);
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute(id: 'a2', equipmentId: id, key: EquipmentAttrKeys.volumeL, valueNum: 12),
      EquipmentAttribute(
        id: 'a3',
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
    ],
  );

  ServiceClockStatus hydro(DateTime anchor) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's',
      equipmentId: id,
      serviceKindId: 'hydro',
      createdAt: now,
      updatedAt: now,
    ),
    kind: ServiceKind(id: 'hydro', name: 'Hydro', createdAt: now, updatedAt: now),
    anchor: anchor,
    severity: ServiceClockSeverity.ok,
    now: now,
  );

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    CylinderPassportPayload? scanned,
    List<ServiceClockStatus> clocks = const [],
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportIdProvider(id).overrideWith((ref) async => pid),
          serviceClockStatusesProvider(id).overrideWith((ref) async => clocks),
        ],
        child: SingleChildScrollView(
          child: PassportTagCard(equipment: tank, scannedTag: scanned),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportTagCard)));
  }

  test('currentPayloadFor takes dates from the clock anchors', () {
    final payload = currentPayloadFor(
      tank,
      passportId: pid,
      clocks: [hydro(DateTime(2024, 6, 14))],
      now: now,
    );
    expect(payload!.lastHydro, DateTime(2024, 6, 14));
    expect(payload.lastVip, isNull);
    expect(payload.o2Clean, isFalse);
    expect(payload.writtenOn, now);
    expect(payload.volumeL, 12);
  });

  testWidgets('shows the QR of the current payload and the actions', (tester) async {
    final l10n = await pump(tester);
    expect(find.byType(PassportQrView), findsOneWidget);
    expect(find.text(l10n.passport_tag_printLabel), findsOneWidget);
    expect(find.text(l10n.passport_tag_linkExisting), findsOneWidget);
    expect(find.text(l10n.passport_tag_stale), findsNothing);
  });

  testWidgets('a scanned tag older than the hydro is called stale', (tester) async {
    final l10n = await pump(
      tester,
      scanned: CylinderPassportPayload(passportId: pid, writtenOn: DateTime(2024, 1, 1)),
      clocks: [hydro(DateTime(2024, 6, 14))],
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
    expect(find.text(l10n.passport_tag_written('Jan 1, 2024')), findsOneWidget);
  });
}
```

The written-date expectation assumes the mock settings' date format renders `Jan 1, 2024`; if the formatter's default differs, pin the test to `UnitFormatter(MockSettingsNotifier().state).formatDate(DateTime(2024, 1, 1))` rather than to a typed string.

- [ ] **Step 4: Create the link dialog**

Create `lib/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Paste a tag's link to give this cylinder that tag's passport id, so labels
/// already on the metal keep working after a row was re-created (spec
/// section 6.5). Resolves with the tag's payload once linked, or null.
Future<CylinderPassportPayload?> showLinkExistingTagDialog(
  BuildContext context, {
  required String equipmentId,
  String? diverId,
}) => showDialog<CylinderPassportPayload>(
  context: context,
  builder: (context) =>
      _LinkExistingTagDialog(equipmentId: equipmentId, diverId: diverId),
);

class _LinkExistingTagDialog extends ConsumerStatefulWidget {
  const _LinkExistingTagDialog({required this.equipmentId, this.diverId});

  final String equipmentId;
  final String? diverId;

  @override
  ConsumerState<_LinkExistingTagDialog> createState() =>
      _LinkExistingTagDialogState();
}

class _LinkExistingTagDialogState extends ConsumerState<_LinkExistingTagDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final l10n = context.l10n;
    final result = PassportPayloadCodec.decode(_controller.text);
    if (result is! PassportDecoded) {
      setState(() => _error = l10n.passport_tag_linkInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(cylinderPassportRepositoryProvider)
          .assignPassportId(
            equipmentId: widget.equipmentId,
            passportId: result.payload.passportId,
            diverId: widget.diverId,
          );
    } on PassportIdInUse catch (e) {
      final holder = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(e.equipmentId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.passport_tag_linkInUse(holder?.name ?? e.equipmentId);
      });
      return;
    }
    ref.invalidate(passportIdProvider(widget.equipmentId));
    ref.invalidate(fillsForEquipmentProvider(widget.equipmentId));
    if (!mounted) return;
    Navigator.of(context).pop(result.payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.passport_tag_linkExisting),
      content: TextField(
        key: const Key('linkTag_input'),
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l10n.passport_tag_linkPrompt,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.forms_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _link,
          child: Text(l10n.passport_tag_linkExisting),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Create the tag card**

Create `lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The payload a label written right now should carry: the row's spec, the
/// hydro and VIP clock anchors as the "last" dates, and O2 clean when that
/// clock exists and is not overdue. Null until the passport id exists.
CylinderPassportPayload? currentPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required DateTime now,
}) {
  if (passportId == null) return null;
  ServiceClockStatus? clock(String kindId) =>
      clocks.where((c) => c.kind.id == kindId).firstOrNull;
  final o2 = clock('o2-clean');
  return payloadForItem(
    item: item,
    passportId: passportId,
    writtenOn: DateTime(now.year, now.month, now.day),
    hydroAnchor: clock('hydro')?.anchor,
    vipAnchor: clock('vip')?.anchor,
    o2Clean: o2 != null && o2.severity != ServiceClockSeverity.overdue,
  );
}

/// QR of the current tag string, print and link actions, and the stale-tag
/// hint when a scanned tag predates the row (spec section 8, Tag card).
class PassportTagCard extends ConsumerWidget {
  const PassportTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
  });

  final EquipmentItem equipment;

  /// The tag that opened this passport, when it was opened by a scan or a
  /// link; drives the stale hint.
  final CylinderPassportPayload? scannedTag;

  /// Wired by the label printer; null disables the button.
  final Future<void> Function()? onPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final payload = currentPayloadFor(
      equipment,
      passportId: passportId,
      clocks: clocks,
      now: DateTime.now(),
    );
    ServiceClockStatus? clock(String kindId) =>
        clocks.where((c) => c.kind.id == kindId).firstOrNull;
    final scanned = scannedTag;
    final stale =
        scanned != null &&
        tagIsStale(
          tag: scanned,
          hydroAnchor: clock('hydro')?.anchor,
          vipAnchor: clock('vip')?.anchor,
          volumeL: equipment.volumeL,
          workingPressureBar: equipment.workingPressureBar?.round(),
          material: equipment.tankMaterial,
        );
    final warn = StatusColors.of(context).warn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passport_tag_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (payload != null)
              Center(
                child: PassportQrView(
                  data: PassportPayloadCodec.httpsUrl(payload),
                  size: 200,
                ),
              ),
            if (scanned?.writtenOn case final written?) ...[
              const SizedBox(height: 8),
              Text(l10n.passport_tag_written(units.formatDate(written))),
            ],
            if (stale) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warn.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: warn.onContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passport_tag_stale,
                        style: TextStyle(color: warn.onContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: payload == null ? null : onPrintLabel,
                  icon: const Icon(Icons.print),
                  label: Text(l10n.passport_tag_printLabel),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final diverId = await ref.read(
                      validatedCurrentDiverIdProvider.future,
                    );
                    if (!context.mounted) return;
                    final linked = await showLinkExistingTagDialog(
                      context,
                      equipmentId: equipment.id,
                      diverId: diverId,
                    );
                    if (linked != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passport_tag_linked)),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: Text(l10n.passport_tag_linkExisting),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Append the card to the page**

In `passport_page.dart`: add `final CylinderPassportPayload? scannedTag;` to `PassportPage` with constructor parameter `this.scannedTag`, import `cylinder_passport_payload.dart` and `passport_tag_card.dart`, and replace the `// Task 14 appends PassportTagCard here.` comment with:

```dart
                const SizedBox(height: 16),
                PassportTagCard(
                  equipment: equipment,
                  scannedTag: widget.scannedTag,
                  // Task 15 wires onPrintLabel.
                ),
```

- [ ] **Step 7: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/presentation/`
Expected: all pass.

```bash
dart format . && flutter analyze
git add pubspec.yaml pubspec.lock lib/features/cylinder_passports/presentation/ test/features/cylinder_passports/presentation/widgets/
git commit -m "feat(passports): tag card with QR view and link an existing tag

Refs #2334"
```

---

### Task 15: The printable label

**Files:**
- Create: `lib/core/services/export/pdf/passport_label_pdf_export_service.dart`
- Create: `lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_bulkActions`, ~line 525)
- Modify: `lib/features/cylinder_passports/presentation/pages/passport_page.dart` (wire `onPrintLabel`)
- Test: `test/core/services/export/pdf/passport_label_pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `saveAndShareFileBytes` (`lib/core/services/export/shared/file_export_utils.dart`), `pdfVisibleText` and `pdfPageCount` (`test/helpers/pdf_text.dart`), `currentPayloadFor`, `PassportPayloadCodec.httpsUrl`, `cylinderPassportRepositoryProvider.ensurePassportId`, `equipmentRepositoryProvider.getEquipmentById`, `serviceClockStatusesProvider`, `BulkAction`, `BulkActionOutcome`.
- Produces:
  - `class PassportLabelData { final String title; final String? subtitle; final String? specLine; final String url; }`
  - `class PassportLabelPdfExportService { Future<List<int>> generateBytes(List<PassportLabelData> labels); Future<String> exportToPdf(List<PassportLabelData> labels, {Rect? sharePositionOrigin}); }`
  - `Future<void> printPassportLabels(BuildContext context, WidgetRef ref, List<String> equipmentIds)`.

Layout: A4, 10 mm margins, a `pw.Wrap` of 62 mm by 32 mm label boxes with a 1 mm border: a 26 mm QR on the left (`pw.BarcodeWidget`, `pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium)`), then title (bold), subtitle, spec line and `submersion.app` in small type. Text uses the Roboto font loaded the way `pdf_fonts.dart` loads it, falling back to Helvetica when the font cannot load, so names outside Latin-1 still print.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/pdf/passport_label_pdf_export_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';

import '../../../../helpers/pdf_text.dart';

void main() {
  const url = 'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  test('one label carries the title, subtitle and spec', () async {
    final bytes = await PassportLabelPdfExportService().generateBytes([
      const PassportLabelData(
        title: 'Faber 12',
        subtitle: 'S12-A',
        specLine: '12 L, 232 bar, steel',
        url: url,
      ),
    ]);
    final text = pdfVisibleText(bytes);
    expect(text, contains('Faber 12'));
    expect(text, contains('S12-A'));
    expect(text, contains('12 L, 232 bar, steel'));
    expect(pdfPageCount(bytes), 1);
  });

  test('ten labels fit on one A4 sheet', () async {
    final bytes = await PassportLabelPdfExportService().generateBytes([
      for (var i = 0; i < 10; i++)
        PassportLabelData(title: 'Tank $i', url: '$url&n=Tank+$i'),
    ]);
    expect(pdfPageCount(bytes), 1);
  });

  test('an empty list still produces a document', () async {
    final bytes = await PassportLabelPdfExportService().generateBytes(const []);
    expect(pdfPageCount(bytes), 1);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/core/services/export/pdf/passport_label_pdf_export_service_test.dart`
Expected: compile error.

- [ ] **Step 3: Create the service**

Create `lib/core/services/export/pdf/passport_label_pdf_export_service.dart`:

```dart
import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';

/// One printable cylinder label (spec section 8, Tag card).
class PassportLabelData {
  const PassportLabelData({
    required this.title,
    this.subtitle,
    this.specLine,
    required this.url,
  });

  final String title;
  final String? subtitle;
  final String? specLine;
  final String url;
}

/// Renders cylinder passport labels, 62 x 32 mm each, ten to an A4 sheet.
/// The QR uses error correction M like the on-screen code.
class PassportLabelPdfExportService {
  static final _fileNameDate = DateFormat('yyyy-MM-dd');
  static const double _labelW = 62 * PdfPageFormat.mm;
  static const double _labelH = 32 * PdfPageFormat.mm;
  static const double _qr = 26 * PdfPageFormat.mm;

  /// Builds the PDF bytes without touching the filesystem.
  Future<List<int>> generateBytes(List<PassportLabelData> labels) async {
    final theme = await _theme();
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (context) => [
          pw.Wrap(
            spacing: 3 * PdfPageFormat.mm,
            runSpacing: 3 * PdfPageFormat.mm,
            children: [for (final label in labels) _label(label)],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _label(PassportLabelData label) => pw.Container(
    width: _labelW,
    height: _labelH,
    padding: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5, color: PdfColors.grey700),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(
            errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
          ),
          data: label.url,
          width: _qr,
          height: _qr,
          drawText: false,
        ),
        pw.SizedBox(width: 2 * PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                label.title,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                maxLines: 2,
              ),
              if (label.subtitle != null)
                pw.Text(label.subtitle!, style: const pw.TextStyle(fontSize: 8)),
              if (label.specLine != null)
                pw.Text(label.specLine!, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Text(
                'submersion.app',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Roboto when it can be loaded (names outside Latin-1 need it), the
  /// built-in Helvetica otherwise, as pdf_fonts.dart does.
  Future<pw.ThemeData?> _theme() async {
    try {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      return null;
    }
  }

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet. Returns the saved path.
  Future<String> exportToPdf(
    List<PassportLabelData> labels, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await generateBytes(labels);
    return saveAndShareFileBytes(
      bytes,
      'submersion_cylinder_labels_${_fileNameDate.format(DateTime.now())}.pdf',
      'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
```

If `PdfGoogleFonts` cannot be reached in the test environment the catch keeps the test green; if `pw.BarcodeQRCorrectionLevel` is named differently in the resolved `pdf` version, use the medium level that `pw.Barcode.qrCode`'s signature exposes.

- [ ] **Step 4: Create the print helper**

Create `lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Builds one label per cylinder among [equipmentIds] (other types are
/// skipped), minting passport ids where missing, and opens the share sheet
/// with the PDF. Shares nothing when no cylinder was selected.
Future<void> printPassportLabels(
  BuildContext context,
  WidgetRef ref,
  List<String> equipmentIds,
) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final equipmentRepo = ref.read(equipmentRepositoryProvider);
  final passportRepo = ref.read(cylinderPassportRepositoryProvider);
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final now = DateTime.now();
  final labels = <PassportLabelData>[];
  for (final id in equipmentIds) {
    final item = await equipmentRepo.getEquipmentById(id);
    if (item == null || item.type != EquipmentType.tank) continue;
    final passportId = await passportRepo.ensurePassportId(id, diverId: diverId);
    final clocks = await ref.read(serviceClockStatusesProvider(id).future);
    final payload = currentPayloadFor(
      item,
      passportId: passportId,
      clocks: clocks,
      now: now,
    );
    if (payload == null) continue;
    final material = item.attrText(EquipmentAttrKeys.tankMaterial);
    labels.add(
      PassportLabelData(
        title: item.name,
        subtitle: [
          if (item.identifier != null) item.identifier!,
          if (item.serialNumber?.isNotEmpty ?? false) item.serialNumber!,
        ].join(' '),
        specLine: [
          if (item.volumeL != null) units.formatVolume(item.volumeL),
          if (item.workingPressureBar != null)
            units.formatPressure(item.workingPressureBar),
          if (material != null)
            attributeChoiceLabel(l10n, EquipmentAttrKeys.tankMaterial, material),
        ].join(', '),
        url: PassportPayloadCodec.httpsUrl(payload),
      ),
    );
  }
  if (labels.isEmpty || !context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await PassportLabelPdfExportService().exportToPdf(
    labels,
    sharePositionOrigin: box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size,
  );
}
```

- [ ] **Step 5: Wire the passport page and the bulk action**

In `passport_page.dart`, replace the `// Task 15 wires onPrintLabel.` comment with:

```dart
                  onPrintLabel: () =>
                      printPassportLabels(context, ref, [equipment.id]),
```

and import `print_passport_labels.dart`.

In `equipment_list_content.dart`, inside `_bulkActions`, after the `editTags` action add:

```dart
      BulkAction(
        id: 'printLabels',
        icon: Icons.qr_code_2,
        label: context.l10n.passport_tag_printLabels,
        isEnabled: (ids) =>
            everyChecked(ids, (e) => e.type == EquipmentType.tank),
        onInvoke: () async {
          final ids = _selectedIds.toList();
          _selection.exit();
          await printPassportLabels(context, ref, ids);
          return BulkActionOutcome.completed;
        },
      ),
```

with the import of `print_passport_labels.dart`. Match the exact `onInvoke` return type the other actions use; `_applyRetirement` is the model.

- [ ] **Step 6: Run the tests, format, analyze, commit**

Run: `flutter test test/core/services/export/pdf/passport_label_pdf_export_service_test.dart test/features/equipment/presentation/ test/features/cylinder_passports/`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/core/services/export/pdf/passport_label_pdf_export_service.dart lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart lib/features/cylinder_passports/presentation/pages/passport_page.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/core/services/export/pdf/passport_label_pdf_export_service_test.dart
git commit -m "feat(passports): printable QR labels, single and bulk

Refs #2334"
```

---

### Task 16: The route and the entry card on the tank detail page

**Files:**
- Modify: `lib/core/router/app_router.dart` (the `equipmentDetail` route's `routes:` list at ~line 622)
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_entry_card.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (card list, after `_buildDetailsSection`, ~line 200)
- Test: `test/core/router/app_router_test.dart` (append one test), `test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart`

**Interfaces:**
- Consumes: `PassportPage`, `PassportQrView`, `currentPayloadFor`, `newestFillProvider`, `passportIdProvider`, `serviceClockStatusesProvider`, `UnitFormatter.formatDate` and `formatPressure`.
- Produces: route name `equipmentPassport` at path `/equipment/:equipmentId/passport`, built as `PassportPage(equipmentId: ..., scannedTag: state.extra as CylinderPassportPayload?)`; `class PassportEntryCard extends ConsumerWidget { final EquipmentItem equipment; }` that navigates with `context.push('/equipment/${equipment.id}/passport')`.

- [ ] **Step 1: Write the failing router test**

Append to the `'app_router route configuration'` group in `test/core/router/app_router_test.dart`:

```dart
    test('the cylinder passport nests under equipment detail', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('equipmentPassport'));
      final paths = _orderedRoutePaths(router.configuration.routes);
      expect(paths, contains('/equipment/:equipmentId/passport'));
    });
```

If `_orderedRoutePaths` joins paths differently (check its output for `editEquipment`, which should read `/equipment/:equipmentId/edit`), match that shape.

- [ ] **Step 2: Write the failing detail-card test**

Create `test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_entry_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late String? savedIntlLocale;
  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  Future<AppLocalizations> pump(WidgetTester tester, EquipmentItem item) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 3000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/${item.id}',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) => EquipmentDetailPage(equipmentId: item.id),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(item.id).overrideWith((ref) async => item),
          equipmentDiveCountProvider(item.id).overrideWith((ref) async => 0),
          passportIdProvider(item.id).overrideWith((ref) async => null),
          newestFillProvider(item.id).overrideWith((ref) async => null),
          serviceClockStatusesProvider(item.id).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(EquipmentDetailPage)));
  }

  testWidgets('a cylinder shows the passport entry card', (tester) async {
    final l10n = await pump(
      tester,
      const EquipmentItem(id: 'tank', name: 'Faber 12', type: EquipmentType.tank),
    );
    expect(find.byType(PassportEntryCard), findsOneWidget);
    expect(find.text(l10n.passport_open), findsOneWidget);
    expect(find.text(l10n.passport_entry_noFill), findsOneWidget);
  });

  testWidgets('a regulator does not', (tester) async {
    await pump(
      tester,
      const EquipmentItem(id: 'reg', name: 'Apeks', type: EquipmentType.regulator),
    );
    expect(find.byType(PassportEntryCard), findsNothing);
  });
}
```

Copy any further provider overrides the existing `equipment_detail_tags_test.dart` needs (tags, documents, components) so the page builds; the list there is the current minimum.

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/core/router/app_router_test.dart test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart`
Expected: the new router test fails (no such route); the card test fails to compile.

- [ ] **Step 4: Add the route**

In `app_router.dart`, inside the `equipmentDetail` route's `routes: [...]`, after the `editEquipment` route:

```dart
                  GoRoute(
                    path: 'passport',
                    name: 'equipmentPassport',
                    builder: (context, state) => PassportPage(
                      equipmentId: state.pathParameters['equipmentId']!,
                      scannedTag: state.extra as CylinderPassportPayload?,
                    ),
                  ),
```

with imports for `passport_page.dart` and `cylinder_passport_payload.dart`.

- [ ] **Step 5: Create the entry card**

Create `lib/features/cylinder_passports/presentation/widgets/passport_entry_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tank detail page's doorway to the passport: a QR thumbnail once the
/// cylinder has a passport id, the newest mix, and Open passport.
class PassportEntryCard extends ConsumerWidget {
  const PassportEntryCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final newest = ref.watch(newestFillProvider(equipment.id)).value;
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final payload = currentPayloadFor(
      equipment,
      passportId: passportId,
      clocks: clocks,
      now: DateTime.now(),
    );
    return Card(
      child: InkWell(
        onTap: () => context.push('/equipment/${equipment.id}/passport'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (payload != null)
                PassportQrView(
                  data: PassportPayloadCodec.httpsUrl(payload),
                  size: 72,
                )
              else
                const Icon(Icons.qr_code_2, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.passport_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      newest == null
                          ? l10n.passport_entry_noFill
                          : l10n.passport_entry_lastFill(
                              newest.gasMix.name,
                              units.formatPressure(newest.pressureBar),
                              units.formatDate(newest.filledAt),
                            ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.push('/equipment/${equipment.id}/passport'),
                child: Text(l10n.passport_open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Add the card to the detail page**

In `equipment_detail_page.dart`, in the card list right after `_buildDetailsSection(context, ref, equipment, units),` and its `SizedBox`, insert:

```dart
            if (equipment.type == EquipmentType.tank) ...[
              PassportEntryCard(equipment: equipment),
              const SizedBox(height: 24),
            ],
```

with the import of `passport_entry_card.dart`.

- [ ] **Step 7: Run the tests, format, analyze, commit**

Run: `flutter test test/core/router/ test/features/equipment/presentation/pages/`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/core/router/app_router.dart lib/features/cylinder_passports/presentation/widgets/passport_entry_card.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/core/router/app_router_test.dart test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart
git commit -m "feat(passports): passport route and the tank detail entry card

Refs #2334"
```

---

### Task 17: The tag format page

**Files:**
- Create: `docs/import-formats/cylinder-passport-tag.md`
- Modify: `docs/_sidebar.md` (add a link under the section that lists `guide/import-export.md`, or a new `**Formats**` section if none fits)

**Interfaces:** none; this documents Tasks 3 and 4 for third parties.

- [ ] **Step 1: Write the page**

Create `docs/import-formats/cylinder-passport-tag.md`:

```markdown
# Cylinder Passport Tag Format

**Status:** Version 1, shipped with Submersion 1.9.
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`, section 6.

A cylinder passport tag is one short string, printed as a QR code or written
to an NFC tag as an NDEF URI record. Scanning it in Submersion opens that
cylinder's passport. Anyone may print or write these tags; the format is
public so shops and analyzer makers can produce them.

## URL forms

The written form is always

    https://submersion.app/c#<payload>

Submersion also accepts `submersion://c?<payload>`, and the payload in either
the fragment or the query of both forms. Write the https form: it opens the
app directly when installed, and a browser fallback otherwise. The payload
sits in the fragment so a browser never sends it to the server.

## Payload

A query string of short keys in this order, values percent-encoded, all
metric. Only `f` and `p` are required.

| Key | Meaning | Example |
| --- | --- | --- |
| `f` | format version | `1` |
| `p` | passport id, UUID v4, lower case | `8f3a5c1e-1b2c-4d5e-8f90-1234567890ab` |
| `w` | date the tag was written, `YYYY-MM-DD` | `2026-09-25` |
| `n` | name or identifier, at most 40 characters | `Steel%2012%20L` |
| `sn` | stamped serial | `AB12345` |
| `v` | volume, litres, up to one decimal, 0.5 to 50 | `12` |
| `wp` | working pressure, bar, integer, 50 to 400 | `232` |
| `m` | material: `al`, `st`, `cf` | `st` |
| `vt` | valve: `din`, `yoke`, `conv` | `din` |
| `h` | last hydrostatic test, `YYYY-MM-DD` | `2024-06-14` |
| `vi` | last visual inspection, `YYYY-MM-DD` | `2026-03-02` |
| `oc` | `1` when oxygen clean at write time | `1` |

Example:

    https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-25&n=Steel+12+L&sn=AB12345&v=12&wp=232&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1

The gas mix is never on the tag. It changes every fill and travels in a fill
record instead.

## Reading rules

- Unknown keys are ignored, so a future format still opens in an older app.
- `f` greater than 1 opens with a "newer format" note.
- A missing or malformed `p` rejects the tag.
- Out-of-range numbers and unparseable dates are dropped, not trusted.
- Everything on the tag except `p` is a snapshot from `w`; Submersion compares
  it with the live record and reports a stale tag.

## NFC layout

The NDEF message holds, in order: the identity URI record above; when room
allows, the newest signed fill record as a second URI record
(`https://submersion.app/f#<token>`, documented separately); when room still
allows, an Android Application Record for `app.submersion`. Readers process
URI records in order and ignore records they do not know.

When a tag is too small, optional keys are dropped in this fixed order until
the record fits: `n`, `sn`, `vi`, `h`, `oc`, `vt`, `m`, `wp`, `v`. `f`, `p`
and `w` are never dropped. A 144-byte NTAG213 holds identity only; NTAG215
(504 bytes) and NTAG216 (888 bytes) hold everything, and NTAG216 has room
for the fill record too.

## Printing

Error correction M. A full payload is about 150 characters, a version 7
code, which scans well at 25 mm.
```

- [ ] **Step 2: Add it to the sidebar**

In `docs/_sidebar.md`, under the section holding `guide/import-export.md`, add:

```markdown
  * [Cylinder Passport Tags](import-formats/cylinder-passport-tag.md)
```

- [ ] **Step 3: Scan and commit**

Run: `grep -nP "\x{2014}|\x{2013}" docs/import-formats/cylinder-passport-tag.md`
Expected: no output.

```bash
git add docs/import-formats/cylinder-passport-tag.md docs/_sidebar.md
git commit -m "docs: cylinder passport tag format

Refs #2334"
```

---

### Task 18: Whole-project verification and the PR

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: `No issues found!` and no formatting diff (`git status --short` shows nothing unexpected).

- [ ] **Step 2: Check generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'`
Expected: no output (CI fails on drift here).

- [ ] **Step 3: Run the architecture guards and the l10n guards**

Run: `flutter test test/architecture/ test/l10n/`
Expected: all pass.

- [ ] **Step 4: Run the full suite once**

Run: `flutter test`
Expected: all pass (25 to 30 minutes; the run is I/O bound, do not start a second one). Never pipe the command; read the exit status directly. If a failure lands in a file this branch never touched, check `origin/main` before blaming the branch.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin ericgriffin/smart-cylinder-passports-60ca56
```

Open the PR against `main` with the title `Cylinder passports 1a: passport id, fill history and the passport page` and this body (no attribution lines of any kind):

```
## Summary

Phase 1a of the smart cylinder passports program (spec:
docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md).

- `passport_id` becomes a system attribute on cylinders, with a lookup index.
- The tag payload codec (`https://submersion.app/c#...`) and the NDEF size
  model with the small-tag drop order.
- `cylinder_fills` (schema v227), registered for sync like `transmitters`,
  with repositories, providers and manual fill logging.
- The passport page: spec with free gas and buoyancy, hydro, VIP and O2 clean
  from the service clocks, the O2 warning, current fill with MOD and END, fill
  history, and the tag card with an on-screen QR, printable labels (single
  and bulk) and Link an existing tag.
- Entry card on the tank detail page and the `/equipment/:id/passport` route.
- `docs/import-formats/cylinder-passport-tag.md`.

Scanning, incoming links and the foreign passport are #2335; NFC is #2336;
signed records and station mode are #2337.

## Testing

Codec and NDEF round trips, repository tests on an in-memory database,
migration ladder test for v227, sync registration guards, provider tick
guards, widget tests for the fill sheet, the passport page in every state,
the tag card and the detail entry card, and the label PDF text. Full suite
green locally.

Closes #2334
Refs #2333
```

- [ ] **Step 6: Bind the PR for CI monitoring**

Call the desktop app's PR tools (`get_status`, then `bind_pr` if the PR is not reported) so CI results reach the session. Do not poll CI by hand.
