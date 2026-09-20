import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_equipment_tag_source.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

const _travelReg = EquipmentItem(
  id: '',
  diverId: _diverId,
  name: 'Travel reg',
  type: EquipmentType.regulator,
);

/// Equipment tags through a UDDF backup and a restore driven by
/// UniversalAdapter.performImport (issue #1942). The wizard keeps only the
/// payload's entity lists, so a test of the entity importer alone could pass
/// while a real restore lost the links.
void main() {
  Future<ImportPayload> parse(String xml) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(xml)));

  /// Exports [reg] with its tags the way the export providers do.
  Future<String> exportWithTags(EquipmentItem reg) async {
    final source = await loadEquipmentTagsForExport(EquipmentTagRepository(), [
      reg.id,
    ]);
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: [reg],
      tags: source.tags,
      equipmentTagIdsByItem: source.tagIdsByItem,
    );
  }

  /// The test database, started over with only the test diver in it.
  Future<void> freshDatabase(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await DiverRepository().createDiver(_diver());
    });
  }

  testWidgets('equipment-only and shared tags survive a backup and restore', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    final xml = (await tester.runAsync(() async {
      await DiverRepository().createDiver(_diver());
      final tags = TagRepository();
      final rental = await tags.getOrCreateTag(
        'Rental',
        diverId: _diverId,
        scope: TagScope.equipment,
      );
      // A dive tag the diver also uses on gear.
      await tags.getOrCreateTag('Cold water', diverId: _diverId);
      final cold = await tags.getOrCreateTag(
        'Cold water',
        diverId: _diverId,
        scope: TagScope.equipment,
      );
      final reg = await EquipmentRepository().createEquipment(_travelReg);
      await EquipmentTagRepository().replaceTags(reg.id, [rental.id, cold.id]);
      return exportWithTags(reg);
    }))!;

    await freshDatabase(tester);
    final payload = (await tester.runAsync(() => parse(xml)))!;
    final result = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(result.errorMessage, isNull);

    final restored = (await tester.runAsync(() async {
      final reg = (await EquipmentRepository().getAllEquipment(
        diverId: _diverId,
      )).single;
      return EquipmentTagRepository().getTagsForEquipment(reg.id);
    }))!;
    expect(restored.map((t) => t.name), ['Cold water', 'Rental']);
    expect(restored.first.scopes, {TagScope.dives, TagScope.equipment});
    expect(restored.last.scopes, {TagScope.equipment});
  });

  testWidgets(
    'a tag defined without appliestoequipment is widened only when an item '
    'references it',
    (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await tester.runAsync(() => DiverRepository().createDiver(_diver()));

      final exported = (await tester.runAsync(
        () => UddfFullExportService().generateAllDataXmlForTest(
          dives: const [],
          equipment: const [
            EquipmentItem(
              id: 'reg',
              name: 'Travel reg',
              type: EquipmentType.regulator,
            ),
          ],
          tags: [
            Tag(
              id: 'cold',
              name: 'Cold water',
              createdAt: _now,
              updatedAt: _now,
            ),
            Tag(id: 'night', name: 'Night', createdAt: _now, updatedAt: _now),
          ],
          equipmentTagIdsByItem: const {
            'reg': ['cold'],
          },
        ),
      ))!;
      // A file written before equipment tags existed.
      final xml = exported.replaceAll(
        RegExp(r'\s*<appliestoequipment>\w+</appliestoequipment>'),
        '',
      );
      expect(xml, isNot(contains('appliestoequipment')));

      final payload = (await tester.runAsync(() => parse(xml)))!;
      final result = await importThroughWizard(
        tester,
        payload: payload,
        diver: _diver(),
      );
      expect(result.errorMessage, isNull);

      final byName = (await tester.runAsync(() async {
        return {
          for (final t in await TagRepository().getAllTags(diverId: _diverId))
            t.name: t,
        };
      }))!;
      expect(byName['Cold water']!.scopes, {
        TagScope.dives,
        TagScope.equipment,
      });
      expect(byName['Night']!.scopes, {TagScope.dives});
    },
  );

  testWidgets(
    're-importing onto existing gear unions its tags and never removes one',
    (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);

      final xml = (await tester.runAsync(() async {
        await DiverRepository().createDiver(_diver());
        final tags = TagRepository();
        final rental = await tags.getOrCreateTag(
          'Rental',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final cold = await tags.getOrCreateTag(
          'Cold water',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final reg = await EquipmentRepository().createEquipment(_travelReg);
        await EquipmentTagRepository().replaceTags(reg.id, [
          rental.id,
          cold.id,
        ]);
        return exportWithTags(reg);
      }))!;

      // The same regulator on another device, tagged there with
      // "Needs repair" and its own "Rental".
      await freshDatabase(tester);
      final localId = (await tester.runAsync(() async {
        final tags = TagRepository();
        final repair = await tags.getOrCreateTag(
          'Needs repair',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final rental = await tags.getOrCreateTag(
          'Rental',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final reg = await EquipmentRepository().createEquipment(_travelReg);
        await EquipmentTagRepository().replaceTags(reg.id, [
          repair.id,
          rental.id,
        ]);
        return reg.id;
      }))!;

      final payload = (await tester.runAsync(() => parse(xml)))!;
      // Twice: the second run finds every tag already linked.
      for (var run = 0; run < 2; run++) {
        final result = await importThroughWizard(
          tester,
          payload: payload,
          diver: _diver(),
        );
        expect(result.errorMessage, isNull);
      }

      final (items, names, ids) = (await tester.runAsync(() async {
        final links = EquipmentTagRepository();
        return (
          await EquipmentRepository().getAllEquipment(diverId: _diverId),
          [for (final t in await links.getTagsForEquipment(localId)) t.name],
          (await links.getTagIdsByEquipment([localId]))[localId] ??
              const <String>[],
        );
      }))!;
      expect(items.map((e) => e.id), [
        localId,
      ], reason: 'the flagged duplicate links to the local item');
      expect(names, ['Cold water', 'Needs repair', 'Rental']);
      expect(ids, hasLength(3), reason: 'a repeated import adds no link');
    },
  );
}
