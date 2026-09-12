# Dives-only UDDF participants, roles and gear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dives-only UDDF export carry every linked participant with their exact role, and the gear used on each dive, in the full export's shapes, behind two share-sheet checkboxes that default on and a trimmed, share-safe detail level.

**Architecture:** Extract the full export's per-dive participant and gear writers into two small static writer classes that both export paths call. A `UddfDivesExtras` bundle, fetched through a provider like `uddfSourceFetchProvider`, feeds the dives-only service the per-dive participants and assembly rows. The dives-only service then writes a `<diver>` section, gated per-dive elements, and one `buildApplicationData` call for every private section.

**Tech Stack:** Flutter, Dart 3, `package:xml` `XmlBuilder`, Riverpod `Provider`, Drift-backed repositories, `flutter_test`, ARB l10n via `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-12-dives-only-uddf-participants-gear-design.md`

## Global Constraints

- Branch `ericgriffin/dives-only-uddf-participants-gear`, stacked on PR #1788's head; it has no upstream and must never push to `ericgriffin/github-issue-1737-3d32e2`.
- Never use the em-dash character (U+2014) or an en-dash as punctuation in any file, comment, commit message or PR text.
- No commit, PR, comment or file may credit an AI tool or its vendor in any form; no `Co-Authored-By` trailers, no generated-with lines, no session links.
- Stage explicit paths only (`git add <path>`), never `git add -A` or `git add .`.
- TDD: every new test is run and watched failing before its implementation.
- The full export's output must not change, except that `parentref` is no longer written for a parent item that is not in the file.
- Trimmed means: people carry `<personal>` first and last name plus `<certification>` level and agency only (no email, phone, notes); the owner element carries no `<personal>`; gear items carry no `purchasedate`, `purchaseprice` or `purchasecurrency`.
- `UddfExportOptions.includeParticipants` and `includeGear` default to `true`.
- All private sections go into one top-level `<applicationdata><submersion version="1.0">` wrapper.
- New ARB keys go into all 11 files (`ar de en es fr he hu it nl pt zh`), inserted directly above `"transfer_export_includeRawData"`.
- Run `dart format .` and whole-project `flutter analyze` before the final commit. No bare `git stash`.
- Avoid a bare `build` token in shell commands (a read-deny rule refuses it); none of the commands below need one.

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/core/services/export/uddf/uddf_participant_writers.dart` | Static writers for `<buddy>` declarations and the per-dive `<divemaster>`, buddy `<link>`s and inline `<buddy>` elements |
| Create `lib/core/services/export/uddf/uddf_gear_writers.dart` | Static writers for the owner's `<equipment><divecomputer>` block and per-dive `<equipmentused>`, plus `computerIds` |
| Create `lib/core/services/export/uddf/uddf_dives_extras.dart` | `UddfDivesExtras` value object, `UddfDivesExtrasFetch` typedef, `uddfDivesExtrasFetchProvider`, `resolveDivesExtras` |
| Modify `lib/core/services/export/uddf/uddf_export_builders.dart` | `buildDiveElement` calls the writers; `buildApplicationData` gains `omitPurchaseDetails` and the `parentref` rule |
| Modify `lib/core/services/export/uddf/uddf_full_export_service.dart` | `<diver>` block calls the writers |
| Modify `lib/core/services/export/uddf/uddf_export_service.dart` | Dives-only participants and gear |
| Modify `lib/core/services/export/models/uddf_export_options.dart` | Two new flags |
| Modify `lib/core/services/export/export_service.dart` | `extras` pass-through |
| Modify `lib/shared/widgets/export_destination_sheet.dart` | Two checkboxes, `ExportChoice` carries `UddfExportOptions` |
| Modify `lib/features/transfer/presentation/pages/transfer_page.dart` | Read `choice.options` |
| Modify `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Offer the checkboxes, fetch and pass extras |
| Modify `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Same |
| Modify `lib/features/buddies/presentation/pages/buddy_detail_page.dart` | Same |
| Modify 11 `lib/l10n/arb/app_*.arb` and regenerate `lib/l10n/arb/app_localizations*.dart` | Four new keys |

---

### Task 1: Participant writers, and the full export routed through them

**Files:**
- Create: `lib/core/services/export/uddf/uddf_participant_writers.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (the `regularBuddies`/`guidesAndDivemasters` locals near line 113, the `<divemaster>` block at the comment "Export guides/divemasters/instructors in the divemaster field", the link loop at "Link to buddy records in diver section", the inline block at "Export regular buddies in the buddy field for compatibility")
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (the `// Export buddies` loop inside `<diver>`)
- Test: `test/core/services/export/uddf/uddf_participant_writers_test.dart`
- Throwaway (never committed): `test/core/services/export/uddf/_snapshot_full_export_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class UddfParticipantWriters`
  - `static List<BuddyWithRole> leaders(List<BuddyWithRole> rows)`
  - `static List<BuddyWithRole> plainBuddies(List<BuddyWithRole> rows)`
  - `static void writeBuddyDeclarations(XmlBuilder builder, Iterable<Buddy> people, {bool trimmed = false})`
  - `static void writeLeaders(XmlBuilder builder, Dive dive, List<BuddyWithRole> rows)`
  - `static void writeLinks(XmlBuilder builder, List<BuddyWithRole> rows)`
  - `static void writeInlineBuddies(XmlBuilder builder, Dive dive, List<BuddyWithRole> rows)`

- [ ] **Step 1: Capture a baseline of the full export**

Create `test/core/services/export/uddf/_snapshot_full_export_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// Throwaway: writes the full export for a fixed fixture, minus the
/// <generator> timestamp, to SNAPSHOT_OUT. Deleted in Task 2, never staged.
void main() {
  test('snapshot', () async {
    final epoch = DateTime(2024, 1, 1);
    Buddy person(String id, String name) => Buddy(
      id: id,
      name: name,
      email: '$id@example.test',
      phone: '555-0100',
      notes: 'note $id',
      certificationLevel: CertificationLevel.rescue,
      certificationAgency: CertificationAgency.padi,
      createdAt: epoch,
      updatedAt: epoch,
    );
    DiveRole role(String id) =>
        DiveRole(id: id, name: id, createdAt: epoch, updatedAt: epoch);
    final guide = person('g', 'Nicol Sorin');
    final plain = person('p', 'Joe Bloggs');
    final solo = person('s', 'Solo Sam');
    const reg = EquipmentItem(
      id: 'reg',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    final dives = [
      Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diveComputerModel: 'Perdix AI',
        diveComputerSerial: 'SN1',
        gear: looseGear([reg]),
      ),
      Dive(
        id: 'd2',
        dateTime: DateTime(2026, 3, 1, 14),
        diveMaster: 'Legacy Master',
        buddy: 'Legacy Buddy',
      ),
    ];
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: dives,
      owner: Diver(
        id: 'me',
        name: 'Ada Lovelace',
        createdAt: epoch,
        updatedAt: epoch,
      ),
      buddies: [guide, plain, solo],
      diveBuddies: {
        'd1': [
          BuddyWithRole(buddy: guide, role: role(DiveRole.diveGuideId)),
          BuddyWithRole(buddy: plain, role: role(DiveRole.buddyId)),
          BuddyWithRole(buddy: solo, role: role(DiveRole.soloId)),
        ],
      },
      equipment: [reg],
    );
    File(const String.fromEnvironment('SNAPSHOT_OUT')).writeAsStringSync(
      xml.replaceAll(RegExp(r'<generator>[\s\S]*?</generator>'), ''),
    );
  });
}
```

Run (with `SCRATCH` set to the session scratchpad directory):

```bash
flutter test test/core/services/export/uddf/_snapshot_full_export_test.dart --dart-define=SNAPSHOT_OUT=$SCRATCH/full_before.xml
```

Expected: PASS, and `$SCRATCH/full_before.xml` exists and contains `buddy_g`, `Legacy Master` and `dc_Perdix_AI_SN1`.

- [ ] **Step 2: Write the failing writer tests**

Create `test/core/services/export/uddf/uddf_participant_writers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

final _epoch = DateTime(2024, 1, 1);

Buddy _buddy(String id, String name) => Buddy(
  id: id,
  name: name,
  email: '$id@example.test',
  phone: '555-0100',
  notes: 'private note',
  certificationLevel: CertificationLevel.rescue,
  certificationAgency: CertificationAgency.padi,
  createdAt: _epoch,
  updatedAt: _epoch,
);

BuddyWithRole _row(Buddy buddy, String roleId) => BuddyWithRole(
  buddy: buddy,
  role: DiveRole(id: roleId, name: roleId, createdAt: _epoch, updatedAt: _epoch),
);

XmlElement _write(void Function(XmlBuilder builder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().rootElement;
}

final _guide = _buddy('g', 'Nicol Sorin');
final _master = _buddy('m', 'Ana Reyes');
final _plain = _buddy('p', 'Joe Bloggs');
final _solo = _buddy('s', 'Solo Sam');
final _rows = [
  _row(_guide, DiveRole.diveGuideId),
  _row(_plain, DiveRole.buddyId),
  _row(_master, DiveRole.diveMasterId),
  _row(_solo, DiveRole.soloId),
];
final _dive = Dive(id: 'd1', dateTime: DateTime(2026, 3, 1));

void main() {
  group('writeBuddyDeclarations', () {
    test('writes contact details and notes by default', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeBuddyDeclarations(b, [_guide]),
      );
      final buddy = root.findElements('buddy').single;
      expect(buddy.getAttribute('id'), 'buddy_g');
      expect(buddy.findAllElements('firstname').single.innerText, 'Nicol');
      expect(buddy.findAllElements('lastname').single.innerText, 'Sorin');
      expect(buddy.findAllElements('email').single.innerText, 'g@example.test');
      expect(buddy.findAllElements('phone').single.innerText, '555-0100');
      expect(buddy.findElements('notes').single.innerText, 'private note');
      expect(buddy.findAllElements('level').single.innerText, 'rescue');
      expect(buddy.findAllElements('agency').single.innerText, 'padi');
    });

    test('trimmed keeps name and certification only', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeBuddyDeclarations(b, [
          _guide,
        ], trimmed: true),
      );
      final buddy = root.findElements('buddy').single;
      expect(buddy.findAllElements('firstname').single.innerText, 'Nicol');
      expect(buddy.findAllElements('lastname').single.innerText, 'Sorin');
      expect(buddy.findAllElements('level').single.innerText, 'rescue');
      expect(buddy.findAllElements('agency').single.innerText, 'padi');
      expect(buddy.findAllElements('email'), isEmpty);
      expect(buddy.findAllElements('phone'), isEmpty);
      expect(buddy.findAllElements('notes'), isEmpty);
    });
  });

  group('writeLeaders', () {
    test('joins every leader name in row order', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(b, _dive, _rows),
      );
      expect(
        root.findElements('divemaster').single.innerText,
        'Nicol Sorin, Ana Reyes',
      );
    });

    test('falls back to the legacy text when no leader is linked', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(
          b,
          _dive.copyWith(diveMaster: 'Legacy Master'),
          [_row(_plain, DiveRole.buddyId)],
        ),
      );
      expect(root.findElements('divemaster').single.innerText, 'Legacy Master');
    });

    test('writes nothing with neither', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(b, _dive, const []),
      );
      expect(root.findElements('divemaster'), isEmpty);
    });
  });

  test('writeLinks links every row, leaders and solo included', () {
    final root = _write((b) => UddfParticipantWriters.writeLinks(b, _rows));
    expect(root.findElements('link').map((e) => e.getAttribute('ref')), [
      'buddy_g',
      'buddy_p',
      'buddy_m',
      'buddy_s',
    ]);
  });

  group('writeInlineBuddies', () {
    test('writes plain buddies only, skipping leaders and solo', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(b, _dive, _rows),
      );
      final names = root
          .findElements('buddy')
          .map((e) => e.findAllElements('firstname').single.innerText);
      expect(names, ['Joe']);
      expect(root.findAllElements('lastname').single.innerText, 'Bloggs');
    });

    test('falls back to the legacy text when there is no plain buddy', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(
          b,
          _dive.copyWith(buddy: 'Legacy Buddy'),
          [_row(_guide, DiveRole.diveGuideId)],
        ),
      );
      expect(
        root.findElements('buddy').single.findAllElements('firstname').single
            .innerText,
        'Legacy Buddy',
      );
    });

    test('writes nothing with neither', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(b, _dive, const []),
      );
      expect(root.findElements('buddy'), isEmpty);
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_participant_writers_test.dart`
Expected: FAIL to compile, `uddf_participant_writers.dart` does not exist.

- [ ] **Step 4: Write the writers**

Create `lib/core/services/export/uddf/uddf_participant_writers.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Participant elements shared by the full backup and the dives-only
/// export, so the two paths write people the same way.
///
/// A participant is one `dive_buddies` row: a person and their role on the
/// dive. Leaders ([DiveRole.leaderIds]) go into the `<divemaster>` text,
/// every other role except solo is written inline as a plain `<buddy>`,
/// and every row is linked to its `<buddy id>` declaration. The exact role
/// rides in the private `<buddyroles>` block that
/// `UddfExportBuilders.buildApplicationData` writes.
abstract final class UddfParticipantWriters {
  /// The rows whose role leads the dive, in row order.
  static List<BuddyWithRole> leaders(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (DiveRole.leaderIds.contains(row.role.id)) row,
  ];

  /// The rows written inline as plain buddies: neither a leader nor solo.
  static List<BuddyWithRole> plainBuddies(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (!DiveRole.leaderIds.contains(row.role.id) &&
          row.role.id != DiveRole.soloId)
        row,
  ];

  /// One `<buddy id="buddy_<id>">` per person in [people].
  ///
  /// [trimmed] leaves out email, phone and notes, for a file meant to be
  /// shared with other people rather than restored by its owner.
  static void writeBuddyDeclarations(
    XmlBuilder builder,
    Iterable<Buddy> people, {
    bool trimmed = false,
  }) {
    for (final buddy in people) {
      builder.element(
        'buddy',
        attributes: {'id': 'buddy_${buddy.id}'},
        nest: () {
          builder.element(
            'personal',
            nest: () {
              _writeName(builder, buddy.name);
              if (!trimmed && buddy.email != null && buddy.email!.isNotEmpty) {
                builder.element('email', nest: buddy.email);
              }
              if (!trimmed && buddy.phone != null && buddy.phone!.isNotEmpty) {
                builder.element('phone', nest: buddy.phone);
              }
            },
          );
          if (buddy.certificationLevel != null ||
              buddy.certificationAgency != null) {
            builder.element(
              'certification',
              nest: () {
                if (buddy.certificationLevel != null) {
                  builder.element(
                    'level',
                    nest: buddy.certificationLevel!.name,
                  );
                }
                if (buddy.certificationAgency != null) {
                  builder.element(
                    'agency',
                    nest: buddy.certificationAgency!.name,
                  );
                }
              },
            );
          }
          if (!trimmed && buddy.notes.isNotEmpty) {
            builder.element('notes', nest: buddy.notes);
          }
        },
      );
    }
  }

  /// The dive's `<divemaster>`: its leaders' names joined with ", ", or the
  /// legacy free-text field when no leader is linked.
  static void writeLeaders(
    XmlBuilder builder,
    Dive dive,
    List<BuddyWithRole> rows,
  ) {
    final leading = leaders(rows);
    if (leading.isNotEmpty) {
      builder.element(
        'divemaster',
        nest: leading.map((row) => row.buddy.name).join(', '),
      );
    } else if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) {
      builder.element('divemaster', nest: dive.diveMaster);
    }
  }

  /// One `<link ref="buddy_<id>">` per row, leaders and solo included, so
  /// every participant resolves to its declaration on import.
  static void writeLinks(XmlBuilder builder, List<BuddyWithRole> rows) {
    for (final row in rows) {
      builder.element('link', attributes: {'ref': 'buddy_${row.buddy.id}'});
    }
  }

  /// An inline `<buddy><personal>` per plain buddy, for readers that do not
  /// follow links, or the legacy free-text field when there is none.
  static void writeInlineBuddies(
    XmlBuilder builder,
    Dive dive,
    List<BuddyWithRole> rows,
  ) {
    final plain = plainBuddies(rows);
    if (plain.isNotEmpty) {
      for (final row in plain) {
        builder.element(
          'buddy',
          nest: () {
            builder.element(
              'personal',
              nest: () => _writeName(builder, row.buddy.name),
            );
          },
        );
      }
    } else if (dive.buddy != null && dive.buddy!.isNotEmpty) {
      builder.element(
        'buddy',
        nest: () {
          builder.element(
            'personal',
            nest: () {
              builder.element('firstname', nest: dive.buddy);
            },
          );
        },
      );
    }
  }

  static void _writeName(XmlBuilder builder, String name) {
    final parts = name.split(' ');
    builder.element('firstname', nest: parts.first);
    if (parts.length > 1) {
      builder.element('lastname', nest: parts.sublist(1).join(' '));
    }
  }
}
```

- [ ] **Step 5: Run the writer tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/uddf_participant_writers_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 6: Route `buildDiveElement` through the writers**

In `lib/core/services/export/uddf/uddf_export_builders.dart`:

1. Add the import, in the existing alphabetical block of `package:submersion/core/services/...` imports:

```dart
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
```

2. Delete the block that starts `// Separate buddies by role for UDDF export.` and ends with the `guidesAndDivemasters` local (both locals, `regularBuddies` and `guidesAndDivemasters`, go).

3. Replace the block starting at `// Export guides/divemasters/instructors in the divemaster field` (the `if (guidesAndDivemasters.isNotEmpty) { ... } else if (dive.diveMaster != null ...) { ... }`) with:

```dart
            UddfParticipantWriters.writeLeaders(builder, dive, diveBuddyList);
```

4. Replace the block starting at `// Link to buddy records in diver section` (the `for (final buddyWithRole in diveBuddyList) { ... }` loop) with:

```dart
            // Link to buddy records in diver section
            UddfParticipantWriters.writeLinks(builder, diveBuddyList);
```

5. Replace the block starting at `// Export regular buddies in the buddy field for compatibility` (the `if (regularBuddies.isNotEmpty) { ... } else if (dive.buddy != null ...) { ... }`) with:

```dart
            // Export regular buddies in the buddy field for compatibility
            UddfParticipantWriters.writeInlineBuddies(
              builder,
              dive,
              diveBuddyList,
            );
```

- [ ] **Step 7: Route the full export's buddy declarations through the writer**

In `lib/core/services/export/uddf/uddf_full_export_service.dart`, add the import:

```dart
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
```

Replace the block under `// Export buddies` (from `if (buddies != null) {` through its closing brace, the whole `for (final buddy in buddies) { builder.element('buddy', ...) }` loop) with:

```dart
              // Export buddies
              if (buddies != null) {
                UddfParticipantWriters.writeBuddyDeclarations(builder, buddies);
              }
```

- [ ] **Step 8: Verify the full export is unchanged**

```bash
flutter test test/core/services/export/uddf/_snapshot_full_export_test.dart --dart-define=SNAPSHOT_OUT=$SCRATCH/full_after1.xml
diff $SCRATCH/full_before.xml $SCRATCH/full_after1.xml && echo IDENTICAL
```

Expected: `IDENTICAL`. Any difference is a refactor bug; fix the writer, not the baseline.

- [ ] **Step 9: Run the existing UDDF suites**

Run: `flutter test test/core/services/export/uddf/ test/core/services/export_service_test.dart`
Expected: PASS, with no test changed.

- [ ] **Step 10: Commit**

```bash
dart format lib/core/services/export/uddf test/core/services/export/uddf
git add lib/core/services/export/uddf/uddf_participant_writers.dart lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_full_export_service.dart test/core/services/export/uddf/uddf_participant_writers_test.dart
git commit -m "refactor(uddf): share the participant writers between export paths"
```

Do not stage `_snapshot_full_export_test.dart`.

---

### Task 2: Gear writers, and the full export routed through them

**Files:**
- Create: `lib/core/services/export/uddf/uddf_gear_writers.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (the block at `// Equipment used on this dive (including dive computer)`)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (the `declaredComputerIds` local and the `uniqueComputers` block inside `<owner>`)
- Test: `test/core/services/export/uddf/uddf_gear_writers_test.dart`

**Interfaces:**
- Consumes: `UddfExportBuilders.computerRefId(String model, String? serial)` (existing).
- Produces:
  - `abstract final class UddfGearWriters`
  - `static Set<String> computerIds(Iterable<Dive> dives)`
  - `static Set<String> writeOwnerComputers(XmlBuilder builder, Iterable<Dive> dives)` (writes the `<equipment>` block only; returns the ids it declared)
  - `static void writeEquipmentUsed(XmlBuilder builder, Dive dive)`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/uddf/uddf_gear_writers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

XmlElement _write(void Function(XmlBuilder builder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().rootElement;
}

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);
const _bcd = EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd);

Dive _dive(String id, {String? model, String? serial, List<EquipmentItem> gear = const []}) =>
    Dive(
      id: id,
      dateTime: DateTime(2026, 3, 1),
      diveComputerModel: model,
      diveComputerSerial: serial,
      gear: looseGear(gear),
    );

void main() {
  test('computerIds is one id per distinct computer, first seen first', () {
    expect(
      UddfGearWriters.computerIds([
        _dive('a', model: 'Perdix AI', serial: 'SN1'),
        _dive('b'),
        _dive('c', model: 'Teric', serial: null),
        _dive('d', model: 'Perdix AI', serial: 'SN1'),
      ]),
      {'dc_Perdix_AI_SN1', 'dc_Teric_unknown'},
    );
  });

  test('writeOwnerComputers declares each computer and returns the ids', () {
    late Set<String> declared;
    final root = _write(
      (b) => declared = UddfGearWriters.writeOwnerComputers(b, [
        _dive('a', model: 'Perdix AI', serial: 'SN1'),
        _dive('b', model: 'Teric'),
      ]),
    );
    final computers = root
        .findElements('equipment')
        .single
        .findElements('divecomputer')
        .toList();
    expect(computers.map((e) => e.getAttribute('id')), [
      'dc_Perdix_AI_SN1',
      'dc_Teric_unknown',
    ]);
    expect(computers.first.findElements('model').single.innerText, 'Perdix AI');
    expect(
      computers.first.findElements('serialnumber').single.innerText,
      'SN1',
    );
    expect(computers.last.findElements('serialnumber'), isEmpty);
    expect(declared, {'dc_Perdix_AI_SN1', 'dc_Teric_unknown'});
  });

  test('writeOwnerComputers writes nothing without a computer', () {
    late Set<String> declared;
    final root = _write(
      (b) => declared = UddfGearWriters.writeOwnerComputers(b, [_dive('a')]),
    );
    expect(root.childElements, isEmpty);
    expect(declared, isEmpty);
  });

  test('writeEquipmentUsed refs each item, then links the computer', () {
    final root = _write(
      (b) => UddfGearWriters.writeEquipmentUsed(
        b,
        _dive('a', model: 'Perdix AI', serial: 'SN1', gear: [_reg, _bcd]),
      ),
    );
    final used = root.findElements('equipmentused').single;
    expect(used.findElements('equipmentref').map((e) => e.innerText), [
      'equip_reg',
      'equip_bcd',
    ]);
    expect(used.findElements('link').single.getAttribute('ref'),
        'dc_Perdix_AI_SN1');
  });

  test('writeEquipmentUsed writes nothing with no gear and no computer', () {
    final root = _write(
      (b) => UddfGearWriters.writeEquipmentUsed(b, _dive('a')),
    );
    expect(root.childElements, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_gear_writers_test.dart`
Expected: FAIL to compile, `uddf_gear_writers.dart` does not exist.

- [ ] **Step 3: Write the writers**

Create `lib/core/services/export/uddf/uddf_gear_writers.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Gear elements shared by the full backup and the dives-only export.
///
/// Items themselves are declared in the private
/// `<applicationdata><submersion><equipment>` block; the only standard
/// declarations are the dive computers, which live under the owner.
abstract final class UddfGearWriters {
  /// The `<divecomputer>` id of each distinct computer on [dives], first
  /// seen first. A dive with no computer model contributes nothing.
  static Set<String> computerIds(Iterable<Dive> dives) => {
    for (final dive in dives)
      if (dive.diveComputerModel case final model? when model.isNotEmpty)
        UddfExportBuilders.computerRefId(model, dive.diveComputerSerial),
  };

  /// The owner's `<equipment>` block declaring each computer on [dives],
  /// and the ids it declared. Writes nothing and returns an empty set when
  /// no dive names a computer. The caller writes the `<owner>` around it,
  /// so a backup can carry the owner's details and a shared file need not.
  static Set<String> writeOwnerComputers(
    XmlBuilder builder,
    Iterable<Dive> dives,
  ) {
    final computers = <String, ({String model, String serial})>{};
    for (final dive in dives) {
      final model = dive.diveComputerModel;
      if (model == null || model.isEmpty) continue;
      computers[UddfExportBuilders.computerRefId(
        model,
        dive.diveComputerSerial,
      )] = (
        model: model,
        serial: dive.diveComputerSerial ?? '',
      );
    }
    if (computers.isEmpty) return const {};
    builder.element(
      'equipment',
      nest: () {
        for (final entry in computers.entries) {
          builder.element(
            'divecomputer',
            attributes: {'id': entry.key},
            nest: () {
              builder.element('model', nest: entry.value.model);
              if (entry.value.serial.isNotEmpty) {
                builder.element('serialnumber', nest: entry.value.serial);
              }
            },
          );
        }
      },
    );
    return computers.keys.toSet();
  }

  /// The dive's `<equipmentused>`: one `<equipmentref>` per gear row, then
  /// a link to its dive computer. Nothing when it has neither.
  static void writeEquipmentUsed(XmlBuilder builder, Dive dive) {
    final model = dive.diveComputerModel;
    final computerRef = model != null && model.isNotEmpty
        ? UddfExportBuilders.computerRefId(model, dive.diveComputerSerial)
        : null;
    if (dive.equipment.isEmpty && computerRef == null) return;
    builder.element(
      'equipmentused',
      nest: () {
        for (final item in dive.equipment) {
          builder.element('equipmentref', nest: 'equip_${item.id}');
        }
        if (computerRef != null) {
          builder.element('link', attributes: {'ref': computerRef});
        }
      },
    );
  }
}
```

- [ ] **Step 4: Run the writer tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/uddf_gear_writers_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Route `buildDiveElement` through `writeEquipmentUsed`**

In `lib/core/services/export/uddf/uddf_export_builders.dart`, add the import:

```dart
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
```

Replace the whole block starting `// Equipment used on this dive (including dive computer)` (the `if (dive.equipment.isNotEmpty || ...) { builder.element('equipmentused', ...) }`) with:

```dart
            // Equipment used on this dive (including dive computer)
            UddfGearWriters.writeEquipmentUsed(builder, dive);
```

The two files import each other; Dart allows that, and both are static-only.

- [ ] **Step 6: Route the full export's computer declarations through `writeOwnerComputers`**

In `lib/core/services/export/uddf/uddf_full_export_service.dart`, add the import:

```dart
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
```

Replace the `declaredComputerIds` block (the comment starting `// Which computers this document will actually declare as` and the `final declaredComputerIds = <String>{ ... };` below it) with:

```dart
    // Which computers this document actually declares as
    // <divecomputer id=...>, filled in by the owner block below from the
    // same writer that declares them, so the two cannot disagree. Stays
    // empty without an owner, since the declarations live under it. A dump
    // may only link to an id in here.
    var declaredComputerIds = const <String>{};
```

Inside the `<owner>` element, replace everything from `// Export dive computers used in equipment section` through the closing brace of `if (uniqueComputers.isNotEmpty) { ... }` with:

```dart
                    // Export dive computers used in equipment section
                    declaredComputerIds = UddfGearWriters.writeOwnerComputers(
                      builder,
                      dives,
                    );
```

Leave the `// Certifications will be added in applicationdata section` comment and the later `buildDiveComputerControl(... declaredComputerIds: declaredComputerIds)` call as they are.

- [ ] **Step 7: Verify the full export is unchanged**

```bash
flutter test test/core/services/export/uddf/_snapshot_full_export_test.dart --dart-define=SNAPSHOT_OUT=$SCRATCH/full_after2.xml
diff $SCRATCH/full_before.xml $SCRATCH/full_after2.xml && echo IDENTICAL
```

Expected: `IDENTICAL`.

- [ ] **Step 8: Run the existing UDDF suites, then delete the snapshot test**

Run: `flutter test test/core/services/export/uddf/ test/core/services/export_service_test.dart`
Expected: PASS.

```bash
rm test/core/services/export/uddf/_snapshot_full_export_test.dart
git status --porcelain | grep _snapshot || echo "snapshot gone"
```

Expected: `snapshot gone`.

- [ ] **Step 9: Commit**

```bash
dart format lib/core/services/export/uddf test/core/services/export/uddf
git add lib/core/services/export/uddf/uddf_gear_writers.dart lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_full_export_service.dart test/core/services/export/uddf/uddf_gear_writers_test.dart
git commit -m "refactor(uddf): share the gear writers between export paths"
```

---

### Task 3: Share-safe equipment items in `buildApplicationData`

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData` signature, the item writer's purchase fields and `parentref`)
- Test: `test/core/services/export/uddf/uddf_application_data_items_test.dart`

**Interfaces:**
- Produces: `UddfExportBuilders.buildApplicationData(..., bool omitPurchaseDetails = false)`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/uddf/uddf_application_data_items_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

final _first = EquipmentItem(
  id: 'first',
  name: 'First',
  type: EquipmentType.firstStage,
  serialNumber: 'FS-1',
  purchaseDate: DateTime(2025, 5, 1),
  purchasePrice: 450,
  purchaseCurrency: 'EUR',
  parentEquipmentId: 'reg',
);
const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);

XmlElement _item(
  List<EquipmentItem> equipment,
  String id, {
  bool omitPurchaseDetails = false,
}) {
  final builder = XmlBuilder();
  builder.element(
    'uddf',
    nest: () => UddfExportBuilders.buildApplicationData(
      builder,
      equipment: equipment,
      omitPurchaseDetails: omitPurchaseDetails,
    ),
  );
  return builder
      .buildDocument()
      .findAllElements('item')
      .singleWhere((e) => e.getAttribute('id') == 'equip_$id');
}

void main() {
  test('a backup keeps the purchase details', () {
    final item = _item([_reg, _first], 'first');
    expect(item.findElements('purchasedate'), hasLength(1));
    expect(item.findElements('purchaseprice').single.innerText, '450.0');
    expect(item.findElements('purchasecurrency').single.innerText, 'EUR');
  });

  test('omitPurchaseDetails drops them and keeps everything else', () {
    final item = _item([_reg, _first], 'first', omitPurchaseDetails: true);
    expect(item.findElements('purchasedate'), isEmpty);
    expect(item.findElements('purchaseprice'), isEmpty);
    expect(item.findElements('purchasecurrency'), isEmpty);
    expect(item.findElements('name').single.innerText, 'First');
    expect(item.findElements('serialnumber').single.innerText, 'FS-1');
  });

  test('parentref is written when the parent is in the file', () {
    final item = _item([_reg, _first], 'first');
    expect(item.findElements('parentref').single.innerText, 'equip_reg');
  });

  test('parentref is dropped when the parent is not in the file', () {
    final item = _item([_first], 'first');
    expect(item.findElements('parentref'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_application_data_items_test.dart`
Expected: FAIL to compile, no named parameter `omitPurchaseDetails`.

- [ ] **Step 3: Implement**

In `buildApplicationData`'s parameter list, after `Map<String, List<BuddyWithRole>>? diveBuddies,` add:

```dart
    // A file shared with other people carries no purchase date, price or
    // currency on its items; a backup keeps them.
    bool omitPurchaseDetails = false,
```

Directly after the `observationsByItem` loop (before `builder.element('applicationdata', ...)`), add:

```dart
    // An item's parent is referenced only when it is declared here too, so
    // a file carrying some items never points at one it left out.
    final itemIds = {for (final i in equipment ?? const <EquipmentItem>[]) i.id};
```

In the item writer, change `if (item.purchaseDate != null) {` to:

```dart
                        if (!omitPurchaseDetails && item.purchaseDate != null) {
```

and `if (item.purchasePrice != null) {` to:

```dart
                        if (!omitPurchaseDetails &&
                            item.purchasePrice != null) {
```

and `if (item.parentEquipmentId != null) {` (the `parentref` block) to:

```dart
                        if (item.parentEquipmentId case final parent?
                            when itemIds.contains(parent)) {
```

with its body using `parent`:

```dart
                          builder.element(
                            'parentref',
                            nest: 'equip_$parent',
                          );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/uddf_application_data_items_test.dart test/core/services/export/uddf/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/export/uddf test/core/services/export/uddf
git add lib/core/services/export/uddf/uddf_export_builders.dart test/core/services/export/uddf/uddf_application_data_items_test.dart
git commit -m "feat(uddf): write share-safe equipment items without purchase details"
```

---

### Task 4: Export options, the extras bundle and its fetch provider

**Files:**
- Modify: `lib/core/services/export/models/uddf_export_options.dart`
- Create: `lib/core/services/export/uddf/uddf_dives_extras.dart`
- Test: `test/core/services/export/models/uddf_export_options_test.dart`
- Test: `test/core/services/export/uddf/uddf_dives_extras_test.dart`

**Interfaces:**
- Produces:
  - `UddfExportOptions({bool includeRawData = true, bool includeParticipants = true, bool includeGear = true})`, `copyWith({bool? includeRawData, bool? includeParticipants, bool? includeGear})`
  - `class UddfDivesExtras { final Map<String, List<BuddyWithRole>> diveBuddies; final List<EquipmentComponent> components; const UddfDivesExtras({...}); const UddfDivesExtras.empty(); }`
  - `typedef UddfDivesExtrasFetch = Future<UddfDivesExtras> Function(List<String> diveIds, UddfExportOptions options);`
  - `final uddfDivesExtrasFetchProvider = Provider<UddfDivesExtrasFetch>(...)`
  - `Future<UddfDivesExtras> resolveDivesExtras(BuddyRepository buddies, EquipmentComponentRepository components, List<String> diveIds, UddfExportOptions options)`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/models/uddf_export_options_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';

void main() {
  test('everything is included by default', () {
    const options = UddfExportOptions();
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isTrue);
    expect(options.includeGear, isTrue);
  });

  test('copyWith changes only what it is given', () {
    final options = const UddfExportOptions().copyWith(
      includeParticipants: false,
    );
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isFalse);
    expect(options.includeGear, isTrue);
    expect(options.copyWith(includeGear: false).includeParticipants, isFalse);
  });
}
```

Create `test/core/services/export/uddf/uddf_dives_extras_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

final _epoch = DateTime(2024, 1, 1);
final _row = BuddyWithRole(
  buddy: Buddy(id: 'b1', name: 'Joe', createdAt: _epoch, updatedAt: _epoch),
  role: DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
);
final _component = EquipmentComponent(
  id: 'c1',
  parentEquipmentId: 'reg',
  componentEquipmentId: 'first',
  createdAt: _epoch,
  updatedAt: _epoch,
);

class _Buddies extends Fake implements BuddyRepository {
  final calls = <List<String>>[];

  @override
  Future<Map<String, List<BuddyWithRole>>> getBuddiesForDives(
    List<String> diveIds,
  ) async {
    calls.add(diveIds);
    return {
      'd1': [_row],
    };
  }
}

class _Components extends Fake implements EquipmentComponentRepository {
  var calls = 0;

  @override
  Future<List<EquipmentComponent>> getAllComponents() async {
    calls++;
    return [_component];
  }
}

void main() {
  test('fetches participants and components by default', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(buddies, components, [
      'd1',
    ], const UddfExportOptions());
    expect(buddies.calls, [
      ['d1'],
    ]);
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
  });

  test('queries nothing a checkbox left out', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(
      buddies,
      components,
      ['d1'],
      const UddfExportOptions(includeParticipants: false, includeGear: false),
    );
    expect(buddies.calls, isEmpty);
    expect(components.calls, 0);
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });

  test('the provider reads both repositories', () async {
    final container = ProviderContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(_Buddies()),
        equipmentComponentRepositoryProvider.overrideWithValue(_Components()),
      ],
    );
    addTearDown(container.dispose);
    final extras = await container.read(uddfDivesExtrasFetchProvider)([
      'd1',
    ], const UddfExportOptions());
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
  });

  test('empty holds nothing', () {
    const extras = UddfDivesExtras.empty();
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/export/models/uddf_export_options_test.dart test/core/services/export/uddf/uddf_dives_extras_test.dart`
Expected: FAIL to compile, no getter `includeParticipants` and `uddf_dives_extras.dart` does not exist.

- [ ] **Step 3: Implement the options**

Replace the body of `lib/core/services/export/models/uddf_export_options.dart` below the class doc comment with:

```dart
class UddfExportOptions {
  /// Whether to carry each dive's raw dive computer bytes.
  ///
  /// Defaults to true, matching what every export UI shows: the checkbox is
  /// pre-checked in both the full backup and the dives only share paths, and
  /// the code level default is kept in step with it rather than diverging.
  /// A caller that omits options therefore gets a complete export.
  final bool includeRawData;

  /// Whether the dives only export carries each dive's participants and
  /// their roles (issue #1796). The full backup always carries them and
  /// ignores this.
  final bool includeParticipants;

  /// Whether the dives only export carries the gear and dive computer used
  /// on each dive (issue #1718). The full backup always carries them and
  /// ignores this.
  final bool includeGear;

  const UddfExportOptions({
    this.includeRawData = true,
    this.includeParticipants = true,
    this.includeGear = true,
  });

  UddfExportOptions copyWith({
    bool? includeRawData,
    bool? includeParticipants,
    bool? includeGear,
  }) => UddfExportOptions(
    includeRawData: includeRawData ?? this.includeRawData,
    includeParticipants: includeParticipants ?? this.includeParticipants,
    includeGear: includeGear ?? this.includeGear,
  );
}
```

- [ ] **Step 4: Implement the extras bundle**

Create `lib/core/services/export/uddf/uddf_dives_extras.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

/// What a dives only UDDF export needs beyond the dives themselves.
///
/// The dives already carry their gear; participants and assembly rows are
/// not hydrated on them, so they travel here.
class UddfDivesExtras {
  /// Each exported dive's participants with their roles, by dive id.
  final Map<String, List<BuddyWithRole>> diveBuddies;

  /// Assembly template rows. The export keeps those whose parent and
  /// component are both on an exported dive.
  final List<EquipmentComponent> components;

  const UddfDivesExtras({
    this.diveBuddies = const {},
    this.components = const [],
  });

  const UddfDivesExtras.empty() : this();
}

/// Fetches the [UddfDivesExtras] a dives only export needs for [diveIds].
typedef UddfDivesExtrasFetch =
    Future<UddfDivesExtras> Function(
      List<String> diveIds,
      UddfExportOptions options,
    );

/// The fetch every dives only export action uses.
///
/// A provider for the same reason as `uddfSourceFetchProvider`: the export
/// actions live in widgets whose tests have no database, and overriding
/// this is how such a test opts out.
final uddfDivesExtrasFetchProvider = Provider<UddfDivesExtrasFetch>((ref) {
  return (diveIds, options) => resolveDivesExtras(
    ref.read(buddyRepositoryProvider),
    ref.read(equipmentComponentRepositoryProvider),
    diveIds,
    options,
  );
});

/// Loads the extras for [diveIds], skipping any query whose checkbox in
/// [options] is off: a share without participants or gear must not pay for
/// reads it will not use.
Future<UddfDivesExtras> resolveDivesExtras(
  BuddyRepository buddies,
  EquipmentComponentRepository components,
  List<String> diveIds,
  UddfExportOptions options,
) async => UddfDivesExtras(
  diveBuddies: options.includeParticipants
      ? await buddies.getBuddiesForDives(diveIds)
      : const {},
  components: options.includeGear
      ? await components.getAllComponents()
      : const [],
);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/services/export/models/uddf_export_options_test.dart test/core/services/export/uddf/uddf_dives_extras_test.dart test/features/settings/presentation/providers/uddf_export_options_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/export test/core/services/export
git add lib/core/services/export/models/uddf_export_options.dart lib/core/services/export/uddf/uddf_dives_extras.dart test/core/services/export/models/uddf_export_options_test.dart test/core/services/export/uddf/uddf_dives_extras_test.dart
git commit -m "feat(uddf): participant and gear export options and the dives extras fetch"
```

---

### Task 5: Dives-only export carries participants and roles

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart`
- Test: `test/core/services/export/uddf/uddf_dives_export_participants_test.dart`

**Interfaces:**
- Consumes: `UddfParticipantWriters` (Task 1), `UddfDivesExtras` and `UddfExportOptions.includeParticipants` (Task 4), `UddfExportBuilders.buildApplicationData(diveBuddies:, customDiveRoles:, dataSources:, dataSourceDumps:)`.
- Produces: `UddfExportService.generateDivesUddfContent(List<Dive> dives, {..., UddfDivesExtras extras = const UddfDivesExtras.empty(), UddfExportOptions options})`, and the same `extras` parameter on `exportDivesToUddf` and `saveDivesToUddfFile`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/uddf/uddf_dives_export_participants_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

final _epoch = DateTime(2024, 1, 1);

Buddy _buddy(String id, String name) => Buddy(
  id: id,
  name: name,
  email: '$id@example.test',
  phone: '555-0100',
  notes: 'private note',
  certificationLevel: CertificationLevel.rescue,
  certificationAgency: CertificationAgency.padi,
  createdAt: _epoch,
  updatedAt: _epoch,
);

DiveRole _builtIn(String id) =>
    DiveRole(id: id, name: id, isBuiltIn: true, createdAt: _epoch, updatedAt: _epoch);

final _photographer = DiveRole(
  id: 'role-photo',
  name: 'Photographer',
  createdAt: _epoch,
  updatedAt: _epoch,
);

final _guide = _buddy('g', 'Nicol Sorin');
final _plain = _buddy('p', 'Joe Bloggs');
final _photo = _buddy('ph', 'Pat Kim');
final _stranger = _buddy('x', 'Not Exported');

final _d1 = Dive(
  id: 'd1',
  dateTime: DateTime(2026, 3, 1, 9),
  diveMaster: 'Legacy Master',
  buddy: 'Legacy Buddy',
);
final _d2 = Dive(
  id: 'd2',
  dateTime: DateTime(2026, 3, 1, 14),
  diveMaster: 'Legacy Master',
  buddy: 'Legacy Buddy',
);

final _extras = UddfDivesExtras(
  diveBuddies: {
    'd1': [
      BuddyWithRole(buddy: _guide, role: _builtIn(DiveRole.diveGuideId)),
      BuddyWithRole(buddy: _plain, role: _builtIn(DiveRole.buddyId)),
      BuddyWithRole(buddy: _photo, role: _photographer),
    ],
    // A dive that is not exported must declare nobody.
    'other': [BuddyWithRole(buddy: _stranger, role: _builtIn(DiveRole.buddyId))],
  },
);

Future<XmlDocument> _export({
  UddfExportOptions options = const UddfExportOptions(),
}) async => XmlDocument.parse(
  await UddfExportService().generateDivesUddfContent(
    [_d1, _d2],
    extras: _extras,
    options: options,
  ),
);

XmlElement _before(XmlDocument doc, String diveId) => doc
    .findAllElements('dive')
    .singleWhere((e) => e.getAttribute('id') == 'dive_$diveId')
    .findElements('informationbeforedive')
    .single;

XmlElement _after(XmlDocument doc, String diveId) => doc
    .findAllElements('dive')
    .singleWhere((e) => e.getAttribute('id') == 'dive_$diveId')
    .findElements('informationafterdive')
    .single;

void main() {
  test('declares each exported participant once, trimmed', () async {
    final doc = await _export();
    final diver = doc.rootElement.findElements('diver').single;
    final buddies = diver.findElements('buddy').toList();
    expect(buddies.map((e) => e.getAttribute('id')), [
      'buddy_g',
      'buddy_p',
      'buddy_ph',
    ]);
    expect(diver.findAllElements('email'), isEmpty);
    expect(diver.findAllElements('phone'), isEmpty);
    expect(diver.findAllElements('notes'), isEmpty);
    expect(buddies.first.findAllElements('level').single.innerText, 'rescue');
    expect(diver.findElements('owner'), isEmpty);
  });

  test('links every participant and names the leader', () async {
    final doc = await _export();
    final before = _before(doc, 'd1');
    expect(
      before
          .findElements('link')
          .map((e) => e.getAttribute('ref'))
          .where((r) => r!.startsWith('buddy_')),
      ['buddy_g', 'buddy_p', 'buddy_ph'],
    );
    expect(before.findElements('divemaster').single.innerText, 'Nicol Sorin');
  });

  test('writes plain buddies inline, not the legacy text', () async {
    final doc = await _export();
    final names = _after(doc, 'd1')
        .findElements('buddy')
        .map((e) => e.findAllElements('firstname').single.innerText)
        .toList();
    expect(names, ['Joe', 'Pat']);
  });

  test('a dive with no linked people keeps its legacy text', () async {
    final doc = await _export();
    expect(
      _before(doc, 'd2').findElements('divemaster').single.innerText,
      'Legacy Master',
    );
    expect(
      _after(doc, 'd2').findAllElements('firstname').single.innerText,
      'Legacy Buddy',
    );
  });

  test('records exact roles and the custom role in one private block', () async {
    final doc = await _export();
    final topLevel = doc.rootElement.childElements
        .where((e) => e.name.local == 'applicationdata')
        .toList();
    expect(topLevel, hasLength(1));
    final submersion = topLevel.single.findElements('submersion').single;
    final rows = submersion
        .findElements('buddyroles')
        .single
        .findElements('dive')
        .single;
    expect(rows.getAttribute('ref'), 'dive_d1');
    expect(
      {
        for (final b in rows.findElements('buddy'))
          b.getAttribute('ref'): b.getAttribute('role'),
      },
      {'buddy_g': DiveRole.diveGuideId, 'buddy_ph': 'role-photo'},
    );
    final roles = submersion.findElements('diveroles').single;
    expect(
      roles.findElements('diverole').map((e) => e.getAttribute('id')),
      ['role-photo'],
    );
  });

  test('leaving participants out writes none of it, legacy text included',
      () async {
    final doc = await _export(
      options: const UddfExportOptions(includeParticipants: false),
    );
    expect(doc.findAllElements('diver'), isEmpty);
    expect(doc.findAllElements('divemaster'), isEmpty);
    expect(doc.findAllElements('buddy'), isEmpty);
    expect(doc.findAllElements('buddyroles'), isEmpty);
    expect(doc.findAllElements('diveroles'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_dives_export_participants_test.dart`
Expected: FAIL to compile, no named parameter `extras`.

- [ ] **Step 3: Add the `extras` parameter and derive the participants**

In `lib/core/services/export/uddf/uddf_export_service.dart`, add imports:

```dart
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
```

Add `UddfDivesExtras extras = const UddfDivesExtras.empty(),` to the named parameters of `generateDivesUddfContent`, `exportDivesToUddf` and `saveDivesToUddfFile` (after `dataSources`), and pass `extras: extras,` from the two delivery methods into `generateDivesUddfContent`.

In `generateDivesUddfContent`, directly after the `encodedById` map and before `final builder = XmlBuilder();`, add:

```dart
    // Participants (issue #1796): only the people on the exported dives,
    // in dive order, and nobody at all when the user left them out of a
    // shared file.
    final diveBuddies = <String, List<BuddyWithRole>>{
      if (options.includeParticipants)
        for (final dive in dives)
          if (extras.diveBuddies[dive.id] case final rows?
              when rows.isNotEmpty)
            dive.id: rows,
    };
    final people = <String, Buddy>{
      for (final rows in diveBuddies.values)
        for (final row in rows) row.buddy.id: row.buddy,
    }.values.toList(growable: false);
    // A <buddyroles> row naming a custom role is dropped on import unless
    // the file also defines that role.
    final customRoles = <String, DiveRole>{
      for (final rows in diveBuddies.values)
        for (final row in rows)
          if (!DiveRole.builtInIds.contains(row.role.id)) row.role.id: row.role,
    }.values.toList(growable: false);
```

- [ ] **Step 4: Write the `<diver>` section**

Directly after the `generator` element (before `// Dive sites`), add:

```dart
        // Diver section: the participants' declarations, trimmed because
        // this file is shared with other people.
        if (people.isNotEmpty) {
          builder.element(
            'diver',
            nest: () {
              UddfParticipantWriters.writeBuddyDeclarations(
                builder,
                people,
                trimmed: true,
              );
            },
          );
        }
```

- [ ] **Step 5: Gate the per-dive participant elements**

Replace the `<divemaster>` block (`if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) { builder.element('divemaster', nest: dive.diveMaster); }`) with:

```dart
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeLeaders(
                                builder,
                                dive,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
```

At the end of the `informationbeforedive` nest, after the `// Entry method` block, add:

```dart
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeLinks(
                                builder,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
```

Replace the inline legacy buddy block in `informationafterdive` (`if (dive.buddy != null && dive.buddy!.isNotEmpty) { builder.element('buddy', ...) }`) with:

```dart
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeInlineBuddies(
                                builder,
                                dive,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
```

- [ ] **Step 6: One private block through `buildApplicationData`**

Replace the whole hand-written block that starts with the comment `// This path has no top level <applicationdata><submersion> block of` and ends with the closing brace of `if (sources.isNotEmpty) { ... }` with:

```dart
        // Every private section in one top level <applicationdata>
        // <submersion>, as the full export writes it: the importer reads
        // only the first top level block for everything except data
        // sources. The per dive inline <applicationdata> for custom fields
        // is a different element in a different position and is untouched.
        UddfExportBuilders.buildApplicationData(
          builder,
          diveBuddies: diveBuddies,
          customDiveRoles: customRoles,
          dataSources: sources,
          dataSourceDumps: encodedById,
        );
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/uddf_dives_export_participants_test.dart test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart test/core/services/export_service_test.dart`
Expected: PASS. `uddf_dives_export_raw_data_test.dart` still passes here: gear is not written until Task 6.

- [ ] **Step 8: Commit**

```bash
dart format lib/core/services/export test/core/services/export
git add lib/core/services/export/uddf/uddf_export_service.dart test/core/services/export/uddf/uddf_dives_export_participants_test.dart
git commit -m "feat(uddf): carry participants and roles in the dives-only export"
```

---

### Task 6: Dives-only export carries gear and dive computers

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart`
- Modify: `test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart` (the first test)
- Test: `test/core/services/export/uddf/uddf_dives_export_gear_test.dart`

**Interfaces:**
- Consumes: `UddfGearWriters` (Task 2), `buildApplicationData(equipment:, omitPurchaseDetails:, components:, gearLinkDives:)` (Task 3), `UddfExportOptions.includeGear` and `UddfDivesExtras.components` (Task 4), the `people`, `diveBuddies` and `customRoles` locals (Task 5).

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/uddf/uddf_dives_export_gear_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

final _epoch = DateTime(2024, 1, 1);

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);
final _first = EquipmentItem(
  id: 'first',
  name: 'First',
  type: EquipmentType.firstStage,
  purchasePrice: 450,
  purchaseDate: DateTime(2025, 5, 1),
  parentEquipmentId: 'reg',
);
const _fins = EquipmentItem(id: 'fins', name: 'Fins', type: EquipmentType.fins);

final _dive = Dive(
  id: 'd1',
  dateTime: DateTime(2026, 3, 1, 9),
  diveComputerModel: 'Perdix AI',
  diveComputerSerial: 'SN1',
  gear: [
    const GearLink(item: _reg),
    GearLink(item: _first, viaEquipmentId: 'reg'),
  ],
);
final _other = Dive(
  id: 'd2',
  dateTime: DateTime(2026, 3, 1, 14),
  gear: looseGear([_fins]),
);

final _extras = UddfDivesExtras(
  components: [
    EquipmentComponent(
      id: 'c1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'first',
      role: 'First stage',
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
    // Its parent is not on an exported dive, so it must not be written.
    EquipmentComponent(
      id: 'c2',
      parentEquipmentId: 'not-exported',
      componentEquipmentId: 'fins',
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
  ],
);

final _source = DiveSourceExport(
  id: 'src-a',
  diveId: 'd1',
  ordinal: 0,
  isPrimary: true,
  importedAt: DateTime(2026, 3, 1, 18),
  createdAt: DateTime(2026, 3, 1, 18),
  rawData: Uint8List.fromList([1, 2, 3, 4]),
  computerModel: 'Perdix AI',
  computerSerial: 'SN1',
);

Future<XmlDocument> _export({
  UddfExportOptions options = const UddfExportOptions(),
}) async => XmlDocument.parse(
  await UddfExportService().generateDivesUddfContent(
    [_dive, _other],
    extras: _extras,
    dataSources: [_source],
    options: options,
  ),
);

XmlElement _submersion(XmlDocument doc) => doc.rootElement.childElements
    .singleWhere((e) => e.name.local == 'applicationdata')
    .findElements('submersion')
    .single;

void main() {
  test('declares the computer under an id-only owner', () async {
    final doc = await _export();
    final owner = doc.rootElement
        .findElements('diver')
        .single
        .findElements('owner')
        .single;
    expect(owner.getAttribute('id'), 'owner');
    expect(owner.findElements('personal'), isEmpty);
    expect(
      owner.findAllElements('divecomputer').single.getAttribute('id'),
      'dc_Perdix_AI_SN1',
    );
  });

  test('the dump links to the declared computer', () async {
    final doc = await _export();
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_d1',
      'dc_Perdix_AI_SN1',
    ]);
  });

  test('each dive lists its gear and computer', () async {
    final doc = await _export();
    final used = doc
        .findAllElements('dive')
        .singleWhere((e) => e.getAttribute('id') == 'dive_d1')
        .findAllElements('equipmentused')
        .single;
    expect(used.findElements('equipmentref').map((e) => e.innerText), [
      'equip_reg',
      'equip_first',
    ]);
    expect(used.findElements('link').single.getAttribute('ref'),
        'dc_Perdix_AI_SN1');
  });

  test('items are declared once, without purchase details', () async {
    final submersion = _submersion(await _export());
    final items = submersion
        .findElements('equipment')
        .single
        .findElements('item')
        .toList();
    expect(items.map((e) => e.getAttribute('id')), [
      'equip_reg',
      'equip_first',
      'equip_fins',
    ]);
    expect(submersion.findAllElements('purchaseprice'), isEmpty);
    expect(submersion.findAllElements('purchasedate'), isEmpty);
    expect(
      items[1].findElements('parentref').single.innerText,
      'equip_reg',
    );
  });

  test('components and gear links cover exported items only', () async {
    final submersion = _submersion(await _export());
    final components = submersion
        .findElements('components')
        .single
        .findElements('component')
        .toList();
    expect(components, hasLength(1));
    expect(components.single.getAttribute('parent'), 'equip_reg');
    final links = submersion.findElements('gearlinks').single;
    expect(
      links.findElements('dive').single.getAttribute('ref'),
      'dive_d1',
    );
    expect(
      links.findAllElements('link').single.getAttribute('via'),
      'equip_reg',
    );
  });

  test('every private section shares the one wrapper', () async {
    final doc = await _export();
    expect(
      doc.rootElement.childElements.where(
        (e) => e.name.local == 'applicationdata',
      ),
      hasLength(1),
    );
    expect(_submersion(doc).findElements('datasources'), hasLength(1));
    expect(
      doc.rootElement.childElements.last.name.local,
      'divecomputercontrol',
    );
  });

  test('leaving gear out writes none of it', () async {
    final doc = await _export(
      options: const UddfExportOptions(includeGear: false),
    );
    expect(doc.findAllElements('owner'), isEmpty);
    expect(doc.findAllElements('divecomputer'), isEmpty);
    expect(doc.findAllElements('equipmentused'), isEmpty);
    expect(doc.findAllElements('item'), isEmpty);
    expect(doc.findAllElements('components'), isEmpty);
    expect(doc.findAllElements('gearlinks'), isEmpty);
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_d1',
    ]);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_dives_export_gear_test.dart`
Expected: FAIL on assertions (no `owner`, no `equipmentused`, no `item`).

- [ ] **Step 3: Derive the gear**

In `lib/core/services/export/uddf/uddf_export_service.dart`, add imports:

```dart
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
```

After the `customRoles` local from Task 5, add:

```dart
    // Gear (issue #1718): each distinct item on the exported dives, the
    // assembly rows between two of them, and the dives' computers. None of
    // it when the user left gear out.
    final items = <String, EquipmentItem>{
      if (options.includeGear)
        for (final dive in dives)
          for (final link in dive.gear) link.item.id: link.item,
    }.values.toList(growable: false);
    final itemIds = {for (final item in items) item.id};
    final components = [
      for (final c in extras.components)
        if (itemIds.contains(c.parentEquipmentId) &&
            itemIds.contains(c.componentEquipmentId))
          c,
    ];
    final computerIds = options.includeGear
        ? UddfGearWriters.computerIds(dives)
        : const <String>{};
```

- [ ] **Step 4: Owner and computers in the `<diver>` section**

Replace the Task 5 `<diver>` block with:

```dart
        // Diver section: an id-only owner hosting the computer declarations,
        // then the participants. Both trimmed, because this file is shared
        // with other people.
        if (computerIds.isNotEmpty || people.isNotEmpty) {
          builder.element(
            'diver',
            nest: () {
              if (computerIds.isNotEmpty) {
                builder.element(
                  'owner',
                  attributes: {'id': 'owner'},
                  nest: () {
                    UddfGearWriters.writeOwnerComputers(builder, dives);
                  },
                );
              }
              UddfParticipantWriters.writeBuddyDeclarations(
                builder,
                people,
                trimmed: true,
              );
            },
          );
        }
```

- [ ] **Step 5: Per-dive `<equipmentused>`**

At the end of the `informationbeforedive` nest, after the `writeLinks` block from Task 5, add:

```dart
                            if (options.includeGear) {
                              UddfGearWriters.writeEquipmentUsed(builder, dive);
                            }
```

- [ ] **Step 6: Items, components and gear links in the private block, and the declared computers**

Extend the `buildApplicationData` call from Task 5 to:

```dart
        UddfExportBuilders.buildApplicationData(
          builder,
          equipment: items,
          omitPurchaseDetails: true,
          components: components,
          gearLinkDives: options.includeGear ? dives : null,
          diveBuddies: diveBuddies,
          customDiveRoles: customRoles,
          dataSources: sources,
          dataSourceDumps: encodedById,
        );
```

Replace the comment and call at the end (`// Last section, per the UDDF specification. The empty declared set is ...` and `buildDiveComputerControl(... declaredComputerIds: const {})`) with:

```dart
        // Last section, per the UDDF specification. A dump links only to a
        // computer the owner block above declared, which it does only when
        // gear is included.
        UddfExportBuilders.buildDiveComputerControl(
          builder,
          sources,
          encodedById,
          declaredComputerIds: computerIds,
        );
```

- [ ] **Step 7: Update the raw data test that pinned the old behavior**

In `test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart`, replace the first test (`'emits the dive link but no computer link'`) with these two:

```dart
  test('links the dump to the computer the export declares', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
    );
    final doc = XmlDocument.parse(xml);

    expect(
      doc.findAllElements('divecomputer').single.getAttribute('id'),
      'dc_Perdix_AI_SN123',
    );
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_dive-1',
      'dc_Perdix_AI_SN123',
    ]);
  });

  test('without gear it declares no computer, so links only the dive',
      () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
      options: const UddfExportOptions(includeGear: false),
    );
    final doc = XmlDocument.parse(xml);

    // No <divecomputer> is declared, so any computer ref would dangle under
    // IDREF validation.
    expect(doc.findAllElements('divecomputer'), isEmpty);
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_dive-1',
    ]);
  });
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/ test/core/services/export_service_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format lib/core/services/export test/core/services/export
git add lib/core/services/export/uddf/uddf_export_service.dart test/core/services/export/uddf/uddf_dives_export_gear_test.dart test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart
git commit -m "feat(uddf): carry gear and dive computers in the dives-only export"
```

---

### Task 7: Round trip through the real importer

**Files:**
- Test: `test/core/services/export/uddf/uddf_dives_export_round_trip_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 4 to 6; `buildRepositories` and `createTestDiver` from `uddf_raw_data_round_trip_test.dart`; `resolveDivesExtras` from Task 4 with real repositories.

- [ ] **Step 1: Write the round trip test**

Create `test/core/services/export/uddf/uddf_dives_export_round_trip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Issues #1718 and #1796: a dives-only UDDF shared from one device and
/// imported on a clean one brings back every participant with their exact
/// role, and the gear and computer used on the dive.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// Seeds one dive with every role and an assembly applied from a set,
  /// then exports it the way the dive detail page does.
  Future<String> seedAndExport(UddfExportOptions options) async {
    final diverId = await createTestDiver();
    final custom = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: diverId,
    );
    final buddies = BuddyRepository();
    final now = DateTime.now();
    Future<Buddy> person(String name) => buddies.createBuddy(
      Buddy(id: '', name: name, createdAt: now, updatedAt: now),
    );
    final guide = await person('Nicol Sorin');
    final master = await person('Ana Reyes');
    final instructor = await person('Tom Lee');
    final student = await person('Sam Park');
    final photographer = await person('Pat Kim');
    final plain = await person('Joe Bloggs');

    final equipment = EquipmentRepository();
    final reg = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final first = await equipment.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'First',
        type: EquipmentType.firstStage,
      ),
    );
    await EquipmentComponentRepository().addComponent(
      parentId: reg.id,
      componentId: first.id,
      role: 'First stage',
    );
    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 'winter',
        diverId: diverId,
        name: 'Winter',
        equipmentIds: [reg.id],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diveComputerModel: 'Perdix AI',
        diveComputerSerial: 'SN1',
        gear: gearLinksFor(
          [reg, first],
          [
            GearProvenance(equipmentId: reg.id, viaSetId: 'winter'),
            GearProvenance(equipmentId: first.id, viaEquipmentId: reg.id),
          ],
        ),
      ),
    );
    await buddies.addBuddyToDive('d1', guide.id, DiveRole.diveGuideId);
    await buddies.addBuddyToDive('d1', master.id, DiveRole.diveMasterId);
    await buddies.addBuddyToDive('d1', instructor.id, DiveRole.instructorId);
    await buddies.addBuddyToDive('d1', student.id, DiveRole.studentId);
    await buddies.addBuddyToDive('d1', photographer.id, custom.id);
    await buddies.addBuddyToDive('d1', plain.id, DiveRole.buddyId);

    final selected = await dives.getDivesByIds(['d1']);
    return UddfExportService().generateDivesUddfContent(
      selected,
      extras: await resolveDivesExtras(
        buddies,
        EquipmentComponentRepository(),
        ['d1'],
        options,
      ),
      options: options,
    );
  }

  /// Imports [xml] into a clean database, as another device would.
  Future<domain.Dive> importOnCleanDatabase(String xml) async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    return (await DiveRepository().getAllDives()).single;
  }

  test('every role, the assembly and the computer come back', () async {
    final xml = await seedAndExport(const UddfExportOptions());
    final restored = await importOnCleanDatabase(xml);

    final roles = {
      for (final b in await BuddyRepository().getBuddiesForDive(restored.id))
        b.buddy.name: b.role.id,
    };
    final photographerRole = roles['Pat Kim'];
    expect(roles, {
      'Nicol Sorin': DiveRole.diveGuideId,
      'Ana Reyes': DiveRole.diveMasterId,
      'Tom Lee': DiveRole.instructorId,
      'Sam Park': DiveRole.studentId,
      'Pat Kim': photographerRole,
      'Joe Bloggs': DiveRole.buddyId,
    });
    expect(
      (await DiveRoleRepository().getDiveRoleById(photographerRole!))?.name,
      'Photographer',
    );
    expect(
      (await BuddyRepository().getAllBuddies()).map((b) => b.name),
      hasLength(6),
      reason: 'no person is created twice',
    );
    expect(restored.diveMaster, anyOf(isNull, isEmpty));

    final gear = {for (final g in restored.gear) g.item.name: g};
    expect(gear.keys, containsAll(['Reg', 'First']));
    final regId = gear['Reg']!.item.id;
    expect(gear['First']!.viaEquipmentId, regId);
    expect(
      gear['Reg']!.viaSetId,
      isNull,
      reason: 'sets are not shared, so a set-applied row lands loose',
    );
    final components = await EquipmentComponentRepository().getAllComponents();
    expect(components.single.parentEquipmentId, regId);
    expect(components.single.role, 'First stage');
    expect(restored.diveComputerModel, 'Perdix AI');
    expect(restored.diveComputerSerial, 'SN1');
  });

  test('with both checkboxes off, no person and no gear arrive', () async {
    final xml = await seedAndExport(
      const UddfExportOptions(includeParticipants: false, includeGear: false),
    );
    final restored = await importOnCleanDatabase(xml);

    expect(await BuddyRepository().getAllBuddies(), isEmpty);
    expect(restored.gear, isEmpty);
    expect(await EquipmentRepository().getAllEquipment(), isEmpty);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/services/export/uddf/uddf_dives_export_round_trip_test.dart`
Expected: PASS. If an assertion fails, it is a real import gap: diagnose with the superpowers:systematic-debugging skill, fix the smallest thing, and report it; do not weaken the assertion. The two assertions most likely to need attention are `diveComputerModel` (read through the `<equipmentused>` computer link) and the buddy count (a declared person must not also be created from the inline `<buddy>` text).

- [ ] **Step 3: Prove the test can fail**

Temporarily change the first test's `seedAndExport(const UddfExportOptions())` to `seedAndExport(const UddfExportOptions(includeParticipants: false))`, run it, and confirm it fails on the `roles` expectation. Restore the line, run again, and confirm PASS.

- [ ] **Step 4: Commit**

```bash
dart format test/core/services/export/uddf
git add test/core/services/export/uddf/uddf_dives_export_round_trip_test.dart
git commit -m "test(uddf): round trip the dives-only export through a clean import"
```

If Step 2 needed a fix in `lib/`, stage that file too and describe the fix in the commit body.

---

### Task 8: Share-sheet checkboxes and strings

**Files:**
- Modify: `lib/shared/widgets/export_destination_sheet.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart` (`_showExportOptions`)
- Modify: 11 files `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/shared/widgets/export_destination_sheet_test.dart`

**Interfaces:**
- Consumes: `UddfExportOptions` (Task 4).
- Produces:
  - `typedef ExportChoice = ({ExportDestination destination, UddfExportOptions options});`
  - `showExportDestinationSheetWithOptions(BuildContext context, {required String title, bool showRawDataToggle = false, bool showDiveContentToggles = false, UddfExportOptions initialOptions = const UddfExportOptions()})`
  - l10n getters `transfer_export_includeParticipants`, `transfer_export_includeParticipantsSubtitle`, `transfer_export_includeGear`, `transfer_export_includeGearSubtitle`.

- [ ] **Step 1: Add the strings**

In each of the 11 ARB files, insert the four lines directly above the existing `"transfer_export_includeRawData"` line (the neighbouring key is the anchor in every file, since only `app_en.arb` is alphabetical). Keep each file's line endings; check with `git diff --numstat` afterwards that only 4 lines were added per file.

`app_en.arb`:

```json
  "transfer_export_includeGear": "Include gear",
  "transfer_export_includeGearSubtitle": "Adds the equipment and dive computer used on each dive. Purchase details are left out.",
  "transfer_export_includeParticipants": "Include dive participants",
  "transfer_export_includeParticipantsSubtitle": "Adds buddies, guides and their roles on each dive, by name and certification. Contact details are left out.",
```

`app_de.arb`:

```json
  "transfer_export_includeGear": "Ausrüstung einschließen",
  "transfer_export_includeGearSubtitle": "Fügt die bei jedem Tauchgang verwendete Ausrüstung und den Tauchcomputer hinzu. Kaufdetails werden weggelassen.",
  "transfer_export_includeParticipants": "Tauchgangsteilnehmer einschließen",
  "transfer_export_includeParticipantsSubtitle": "Fügt Tauchpartner, Guides und ihre Rollen bei jedem Tauchgang hinzu, mit Name und Brevet. Kontaktdaten werden weggelassen.",
```

`app_es.arb`:

```json
  "transfer_export_includeGear": "Incluir equipo",
  "transfer_export_includeGearSubtitle": "Añade el equipo y el ordenador de buceo usados en cada inmersión. Los datos de compra se omiten.",
  "transfer_export_includeParticipants": "Incluir participantes",
  "transfer_export_includeParticipantsSubtitle": "Añade compañeros, guías y sus funciones en cada inmersión, con nombre y certificación. Los datos de contacto se omiten.",
```

`app_fr.arb`:

```json
  "transfer_export_includeGear": "Inclure l'équipement",
  "transfer_export_includeGearSubtitle": "Ajoute l'équipement et l'ordinateur de plongée utilisés à chaque plongée. Les détails d'achat sont omis.",
  "transfer_export_includeParticipants": "Inclure les participants",
  "transfer_export_includeParticipantsSubtitle": "Ajoute les binômes, les guides et leurs rôles à chaque plongée, avec nom et certification. Les coordonnées sont omises.",
```

`app_it.arb`:

```json
  "transfer_export_includeGear": "Includi l'attrezzatura",
  "transfer_export_includeGearSubtitle": "Aggiunge l'attrezzatura e il computer subacqueo usati in ogni immersione. I dettagli di acquisto sono esclusi.",
  "transfer_export_includeParticipants": "Includi i partecipanti",
  "transfer_export_includeParticipantsSubtitle": "Aggiunge compagni, guide e i loro ruoli in ogni immersione, con nome e brevetto. I recapiti sono esclusi.",
```

`app_nl.arb`:

```json
  "transfer_export_includeGear": "Uitrusting opnemen",
  "transfer_export_includeGearSubtitle": "Voegt de uitrusting en duikcomputer toe die bij elke duik zijn gebruikt. Aankoopgegevens worden weggelaten.",
  "transfer_export_includeParticipants": "Deelnemers opnemen",
  "transfer_export_includeParticipantsSubtitle": "Voegt buddies, gidsen en hun rollen bij elke duik toe, met naam en brevet. Contactgegevens worden weggelaten.",
```

`app_pt.arb`:

```json
  "transfer_export_includeGear": "Incluir equipamento",
  "transfer_export_includeGearSubtitle": "Adiciona o equipamento e o computador de mergulho usados em cada mergulho. Os dados de compra ficam de fora.",
  "transfer_export_includeParticipants": "Incluir participantes",
  "transfer_export_includeParticipantsSubtitle": "Adiciona companheiros, guias e as suas funções em cada mergulho, com nome e certificação. Os dados de contacto ficam de fora.",
```

`app_hu.arb`:

```json
  "transfer_export_includeGear": "Felszerelés belefoglalása",
  "transfer_export_includeGearSubtitle": "Hozzáadja az egyes merülésekhez használt felszerelést és merülőkomputert. A vásárlási adatok kimaradnak.",
  "transfer_export_includeParticipants": "Résztvevők belefoglalása",
  "transfer_export_includeParticipantsSubtitle": "Hozzáadja a társakat, a vezetőket és szerepüket minden merülésnél, névvel és minősítéssel. Az elérhetőségek kimaradnak.",
```

`app_ar.arb`:

```json
  "transfer_export_includeGear": "تضمين المعدات",
  "transfer_export_includeGearSubtitle": "يضيف المعدات وكمبيوتر الغوص المستخدمة في كل غطسة. تُستبعد تفاصيل الشراء.",
  "transfer_export_includeParticipants": "تضمين المشاركين في الغطس",
  "transfer_export_includeParticipantsSubtitle": "يضيف الرفاق والمرشدين وأدوارهم في كل غطسة، بالاسم والشهادة. تُستبعد بيانات الاتصال.",
```

`app_he.arb`:

```json
  "transfer_export_includeGear": "כלול ציוד",
  "transfer_export_includeGearSubtitle": "מוסיף את הציוד ואת מחשב הצלילה ששימשו בכל צלילה. פרטי הרכישה אינם נכללים.",
  "transfer_export_includeParticipants": "כלול משתתפי צלילה",
  "transfer_export_includeParticipantsSubtitle": "מוסיף שותפים, מדריכים ואת תפקידיהם בכל צלילה, לפי שם והסמכה. פרטי הקשר אינם נכללים.",
```

`app_zh.arb`:

```json
  "transfer_export_includeGear": "包含装备",
  "transfer_export_includeGearSubtitle": "添加每次潜水使用的装备和潜水电脑。不包含购买信息。",
  "transfer_export_includeParticipants": "包含潜水参与者",
  "transfer_export_includeParticipantsSubtitle": "添加每次潜水的潜伴、导潜及其角色，仅含姓名和证书。不包含联系方式。",
```

Then regenerate:

```bash
flutter gen-l10n
git diff --numstat lib/l10n/arb/*.arb
```

Expected: `4	0` for each of the 11 ARB files.

- [ ] **Step 2: Update the sheet tests (failing first)**

In `test/shared/widgets/export_destination_sheet_test.dart`:

1. Give `_pumpOptionsHost` a `bool showDiveContentToggles = false` parameter and pass `showDiveContentToggles: showDiveContentToggles,` to `showExportDestinationSheetWithOptions`.
2. Replace every `(result()! as ExportChoice).includeRawData` with `(result()! as ExportChoice).options.includeRawData`.
3. Append these tests inside `main()`:

```dart
  testWidgets('the dive content toggles appear only on request', (
    tester,
  ) async {
    await _pumpOptionsHost(tester);

    expect(find.text('Include dive participants'), findsNothing);
    expect(find.text('Include gear'), findsNothing);
  });

  testWidgets('the dive content toggles start checked', (tester) async {
    final result = await _pumpOptionsHost(
      tester,
      showDiveContentToggles: true,
    );

    expect(find.text('Include dive participants'), findsOneWidget);
    expect(find.text('Include gear'), findsOneWidget);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((t) => t.value),
      [true, true, true],
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final options = (result()! as ExportChoice).options;
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isTrue);
    expect(options.includeGear, isTrue);
  });

  testWidgets('unticking participants and gear carries into the options', (
    tester,
  ) async {
    final result = await _pumpOptionsHost(
      tester,
      showDiveContentToggles: true,
    );

    await tester.tap(find.text('Include dive participants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    final choice = result()! as ExportChoice;
    expect(choice.destination, ExportDestination.saveToFile);
    expect(choice.options.includeRawData, isTrue);
    expect(choice.options.includeParticipants, isFalse);
    expect(choice.options.includeGear, isFalse);
  });
```

Run: `flutter test test/shared/widgets/export_destination_sheet_test.dart`
Expected: FAIL to compile (`showDiveContentToggles` and `.options` do not exist).

- [ ] **Step 3: Implement the sheet**

In `lib/shared/widgets/export_destination_sheet.dart`, add the import:

```dart
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
```

Replace everything from `/// What the user chose in an export destination sheet.` to the end of the file with:

```dart
/// What the user chose in an export destination sheet: where to deliver the
/// file, and the UDDF content checkboxes as options.
typedef ExportChoice = ({
  ExportDestination destination,
  UddfExportOptions options,
});

/// The destination sheet, plus the UDDF content checkboxes.
///
/// [showRawDataToggle] is false for every export that has no raw bytes to
/// carry, which is every format except UDDF. [showDiveContentToggles] adds
/// the participants and gear checkboxes, which only the dives only UDDF
/// export honours; the full backup always carries both. Every checkbox
/// starts from [initialOptions], whose defaults are all on, so the code
/// level default and what the user sees never diverge.
Future<ExportChoice?> showExportDestinationSheetWithOptions(
  BuildContext context, {
  required String title,
  bool showRawDataToggle = false,
  bool showDiveContentToggles = false,
  UddfExportOptions initialOptions = const UddfExportOptions(),
}) {
  var options = initialOptions;

  return showModalBottomSheet<ExportChoice>(
    context: context,
    // Up to three checkboxes above the two destinations outgrow the default
    // cap of 9/16 of the screen height on a phone, so the sheet sizes to its
    // content and scrolls when even that does not fit.
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (builderContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              if (showRawDataToggle) ...[
                CheckboxListTile(
                  value: options.includeRawData,
                  onChanged: (value) => setSheetState(
                    () => options = options.copyWith(includeRawData: value),
                  ),
                  title: Text(sheetContext.l10n.transfer_export_includeRawData),
                  subtitle: Text(
                    sheetContext.l10n.transfer_export_includeRawDataSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (!showDiveContentToggles) const Divider(height: 1),
              ],
              if (showDiveContentToggles) ...[
                CheckboxListTile(
                  value: options.includeParticipants,
                  onChanged: (value) => setSheetState(
                    () => options = options.copyWith(
                      includeParticipants: value,
                    ),
                  ),
                  title: Text(
                    sheetContext.l10n.transfer_export_includeParticipants,
                  ),
                  subtitle: Text(
                    sheetContext
                        .l10n
                        .transfer_export_includeParticipantsSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: options.includeGear,
                  onChanged: (value) => setSheetState(
                    () => options = options.copyWith(includeGear: value),
                  ),
                  title: Text(sheetContext.l10n.transfer_export_includeGear),
                  subtitle: Text(
                    sheetContext.l10n.transfer_export_includeGearSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(sheetContext.l10n.transfer_export_optionSaveTitle),
                subtitle: Text(
                  sheetContext.l10n.transfer_export_optionSaveSubtitle,
                ),
                onTap: () => Navigator.pop(sheetContext, (
                  destination: ExportDestination.saveToFile,
                  options: options,
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(sheetContext.l10n.transfer_export_optionShareTitle),
                subtitle: Text(
                  sheetContext.l10n.transfer_export_optionShareSubtitle,
                ),
                onTap: () => Navigator.pop(sheetContext, (
                  destination: ExportDestination.share,
                  options: options,
                )),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Update the transfer page**

In `lib/features/transfer/presentation/pages/transfer_page.dart` `_showExportOptions`, replace:

```dart
    final options = UddfExportOptions(includeRawData: choice.includeRawData);
```

with:

```dart
    final options = choice.options;
```

If `UddfExportOptions` is now unused in that file, remove its import.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/export_destination_sheet_test.dart test/features/transfer/`
Expected: PASS. The three callers still reference `choice.includeRawData` and do not compile yet; Task 9 fixes them, so do not run their tests here.

- [ ] **Step 6: Commit**

```bash
dart format lib/shared lib/features/transfer test/shared
git add lib/shared/widgets/export_destination_sheet.dart lib/features/transfer/presentation/pages/transfer_page.dart test/shared/widgets/export_destination_sheet_test.dart lib/l10n/arb/
git commit -m "feat(export): participants and gear checkboxes on the UDDF share sheet"
```

`git add lib/l10n/arb/` stages the 11 ARB files and the regenerated `app_localizations*.dart` files, and nothing else lives there.

---

### Task 9: Wire the three dives-only callers

**Files:**
- Modify: `lib/core/services/export/export_service.dart` (`exportDivesToUddf`, `saveDivesToUddfFile`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (UDDF tile near line 5563, `_handleSingleDiveExport` near line 5639)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (sheet call near line 757, UDDF branch near line 884)
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (`_shareDivesWithBuddy`)
- Modify tests: `test/features/dive_log/presentation/pages/dive_detail_export_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_export_navigator_test.dart`, `test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart`, `test/features/buddies/presentation/pages/buddy_detail_export_test.dart`

**Interfaces:**
- Consumes: `uddfDivesExtrasFetchProvider`, `UddfDivesExtras` (Task 4), `UddfExportService` `extras` (Task 5), `ExportChoice.options` and `showDiveContentToggles` (Task 8).
- Produces: `ExportService.exportDivesToUddf(..., UddfDivesExtras extras = const UddfDivesExtras.empty(), ...)` and the same on `saveDivesToUddfFile`.

- [ ] **Step 1: Update the test fakes and overrides, and write the failing pass-through tests**

In each of the four test files:

1. Add imports:

```dart
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
```

2. In every `exportDivesToUddf` and `saveDivesToUddfFile` override on a fake `ExportService` (two fakes in `dive_detail_export_navigator_test.dart`), add the parameter `UddfDivesExtras extras = const UddfDivesExtras.empty(),` after `dataSources`.

3. Next to every `uddfSourceFetchProvider.overrideWithValue(...)` (two places in `dive_list_bulk_export_test.dart`), add:

```dart
          uddfDivesExtrasFetchProvider.overrideWithValue(
            (diveIds, options) async => const UddfDivesExtras.empty(),
          ),
```

Then add the pass-through test to `test/features/dive_log/presentation/pages/dive_detail_export_test.dart`:

1. In `_RecordingExportService`, add fields `UddfDivesExtras? uddfExtras;` and `UddfExportOptions? uddfOptions;`, and in both UDDF overrides record them: `uddfExtras = extras; uddfOptions = options;`. Add `import 'package:submersion/core/services/export/models/uddf_export_options.dart';` if the file does not already import it.
2. In `main()`, add above `setUp`:

```dart
  final extrasSentinel = UddfDivesExtras(
    diveBuddies: {'dive-1': const []},
  );
  final extrasCalls = <(List<String>, UddfExportOptions)>[];
```

and in `setUp` add `extrasCalls.clear();`.
3. Change the Step 3 override in this file to record and return the sentinel:

```dart
          uddfDivesExtrasFetchProvider.overrideWithValue((diveIds, options) async {
            extrasCalls.add((diveIds, options));
            return extrasSentinel;
          }),
```

4. Append the test:

```dart
  testWidgets('UDDF export fetches extras and honours the checkboxes', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('UDDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(exportService.calls, ['save:uddf']);
    expect(extrasCalls.single.$1, ['dive-1']);
    expect(extrasCalls.single.$2.includeGear, isFalse);
    expect(identical(exportService.uddfExtras, extrasSentinel), isTrue);
    expect(exportService.uddfOptions?.includeParticipants, isTrue);
    expect(exportService.uddfOptions?.includeGear, isFalse);
  });

  testWidgets('CSV export offers no dive content checkboxes', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Include gear'), findsNothing);
    expect(find.text('Include dive participants'), findsNothing);
  });
```

Add the same recording to `test/features/buddies/presentation/pages/buddy_detail_export_test.dart` (fields on its `_RecordingExportService`, recorded in both overrides; `extrasSentinel` and `extrasCalls` in `main()`; the recording override in `pumpAndOpenShareDives`), and append:

```dart
  testWidgets('share dives fetches extras and honours the checkboxes', (
    tester,
  ) async {
    await pumpAndOpenShareDives(tester);

    await tester.tap(find.text('Include dive participants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(exportService.calls, ['share:uddf']);
    expect(extrasCalls.single.$1, ['dive-1']);
    expect(identical(exportService.uddfExtras, extrasSentinel), isTrue);
    expect(exportService.uddfOptions?.includeParticipants, isFalse);
  });
```

And in `test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart` (recording fields on its fake, the recording override in `pumpAndOpenExportSheet` only), append:

```dart
  testWidgets('bulk UDDF export fetches extras for the selected dives', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'UDDF', 'Save to File');

    expect(extrasCalls.single.$1.toSet(), {'d1', 'd2'});
    expect(identical(exportService.uddfExtras, extrasSentinel), isTrue);
  });
```

with `extrasSentinel` built from `'d1'` instead of `'dive-1'`.

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_export_test.dart test/features/buddies/presentation/pages/buddy_detail_export_test.dart test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart test/features/dive_log/presentation/pages/dive_detail_export_navigator_test.dart`
Expected: FAIL to compile (callers still read `choice.includeRawData`; `ExportService` has no `extras`).

- [ ] **Step 2: `ExportService` pass-through**

In `lib/core/services/export/export_service.dart`, add the import:

```dart
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
```

In both `exportDivesToUddf` and `saveDivesToUddfFile`, add `UddfDivesExtras extras = const UddfDivesExtras.empty(),` after `dataSources`, and pass `extras: extras,` to the `_uddf` call.

- [ ] **Step 3: Dive detail page**

In `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, add the import:

```dart
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
```

In `_handleSingleDiveExport`, add the parameter `bool offerDiveContent = false,` after `offerRawData`, pass `showDiveContentToggles: offerDiveContent,` to `showExportDestinationSheetWithOptions`, and replace `final options = UddfExportOptions(includeRawData: choice.includeRawData);` with `final options = choice.options;`.

In the UDDF `ListTile`'s `_handleSingleDiveExport(...)` call, add `offerDiveContent: true,` after `offerRawData: true,` and add to both the `exportDivesToUddf(...)` and `saveDivesToUddfFile(...)` calls:

```dart
                        extras: await ref.read(uddfDivesExtrasFetchProvider)([
                          dive.id,
                        ], options),
```

- [ ] **Step 4: Dive list bulk export**

In `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, add the same import. In the `showExportDestinationSheetWithOptions` call, add `showDiveContentToggles: format == _BulkExportFormat.uddf,`. Replace:

```dart
    final uddfOptions = UddfExportOptions(
      includeRawData: choice.includeRawData,
    );
```

with:

```dart
    final uddfOptions = choice.options;
```

In the `_BulkExportFormat.uddf` branch, add to both calls:

```dart
                  extras: await ref.read(uddfDivesExtrasFetchProvider)(
                    selectedDives.map((d) => d.id).toList(growable: false),
                    uddfOptions,
                  ),
```

- [ ] **Step 5: Buddy detail page**

In `lib/features/buddies/presentation/pages/buddy_detail_page.dart`, add the same import. In `_shareDivesWithBuddy`, add `showDiveContentToggles: true,` to the sheet call and replace `final options = UddfExportOptions(includeRawData: choice.includeRawData);` with `final options = choice.options;`. Next to the `dataSources` fetch, add:

```dart
      final extras = await ref.read(uddfDivesExtrasFetchProvider)(
        dives.map((d) => d.id).toList(growable: false),
        options,
      );
```

and pass `extras: extras,` to both `exportDivesToUddf` and `saveDivesToUddfFile`.

In all three files, remove the `UddfExportOptions` import only if the analyzer reports it unused.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_export_test.dart test/features/buddies/presentation/pages/buddy_detail_export_test.dart test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart test/features/dive_log/presentation/pages/dive_detail_export_navigator_test.dart test/shared/ test/features/transfer/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/services/export lib/features/dive_log lib/features/buddies test/features
git add lib/core/services/export/export_service.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/buddies/presentation/pages/buddy_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_export_test.dart test/features/dive_log/presentation/pages/dive_detail_export_navigator_test.dart test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart test/features/buddies/presentation/pages/buddy_detail_export_test.dart
git commit -m "feat(export): send participants and gear from the dives-only share actions"
```

---

### Task 10: Final verification and the stacked PR

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `dart format` reports `0 changed` (or only files this branch touched, which are then committed), and `flutter analyze` reports `No issues found!`. Do not pipe `flutter analyze` into another command; the pipe hides its exit status.

- [ ] **Step 2: One run of the affected suites**

```bash
flutter test test/core/services/export/ test/core/services/export_service_test.dart test/features/dive_log/ test/features/buddies/ test/features/transfer/ test/shared/ test/features/settings/presentation/providers/ test/features/dive_import/ test/features/universal_import/ test/features/import_wizard/
```

Expected: all pass. Run it once; do not overlap it with another local test run. If a failure is in a file this branch never touched, check whether `main` or #1788's branch is red before blaming this branch.

- [ ] **Step 3: Scan everything written for forbidden text**

```bash
git diff origin/ericgriffin/github-issue-1737-3d32e2 --name-only
git diff origin/ericgriffin/github-issue-1737-3d32e2 | grep -nP '\x{2014}' || echo "no em-dashes"
git log origin/ericgriffin/github-issue-1737-3d32e2..HEAD --format=%B | grep -niE 'co-authored-by|generated with|session_' || echo "clean messages"
```

Expected: `no em-dashes` and `clean messages`; no `_snapshot_full_export_test.dart` in the file list.

- [ ] **Step 4: Confirm with the user, then push and open the PR**

Show the user the PR title and body below and wait for an explicit yes. Then:

```bash
git push -u origin ericgriffin/dives-only-uddf-participants-gear
gh pr create --base ericgriffin/github-issue-1737-3d32e2 --title "feat(uddf): carry participants, roles and gear in the dives-only export" --body-file $SCRATCH/pr_body.md
```

`$SCRATCH/pr_body.md`:

```markdown
## Summary

Fixes #1718. Fixes #1796.

The dives-only UDDF export (share or save from a dive, the dive list selection, or a buddy page) dropped every linked participant and role, and carried no gear. It now writes both, in the same shapes the full backup uses, so the existing import path restores them.

Stacked on #1788, which adds `<buddyroles>` and `DiveRole.leaderIds`. This PR gets no CI until #1788 merges and it is retargeted to `main`.

## Changes

- **Shared writers:** participant and gear elements moved out of the full export into `UddfParticipantWriters` and `UddfGearWriters`, which both export paths call. The full export's output is unchanged apart from `parentref`, now written only when the parent item is in the file.
- **Participants:** each person on an exported dive is declared under `<diver>` (name and certification only), linked from the dive, with leaders in `<divemaster>` and plain buddies inline. Exact roles and the custom roles they use ride in `<buddyroles>` and `<diveroles>`.
- **Gear:** an id-only `<owner>` declares the dives' computers, each dive lists `<equipmentused>`, and the private block carries the items (without purchase details), the assembly rows between exported items, and `<gearlinks>`. Equipment sets are not shared, so a set-applied row imports as loose gear.
- **One private block:** every private section, data sources included, now shares one top-level `<applicationdata><submersion>`, which is the only one the importer reads for them.
- **Share sheet:** "Include dive participants" and "Include gear" checkboxes (default on) on the three dives-only paths, in all 11 locales. With one off, that category is left out entirely, legacy free text included.

## Test Plan

- [x] Writer unit tests for both writer classes; the full export was diffed against a pre-refactor snapshot and is identical.
- [x] Dives-only XML shape tests for participants and gear, including both checkboxes off.
- [x] DB-backed round trip: export selected dives, import on a clean database, every role (guide, divemaster, instructor, student, custom, plain buddy), the assembly and the computer come back; with both checkboxes off nothing arrives.
- [x] Share sheet and all three callers: checkboxes offered only for UDDF, choices reach the export, extras fetched for the right dives.
- [x] `flutter analyze` passes (whole project); affected suites pass locally.
- [ ] Manual testing on a device: not run.
```

Report the PR URL to the user, and note that CI will not run until #1788 merges and the PR is retargeted to `main`.
