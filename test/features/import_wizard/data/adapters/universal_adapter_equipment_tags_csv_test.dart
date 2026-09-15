import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    show ImportFormat;
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// Equipment tags through a Submersion equipment CSV export and a re-import
/// driven by UniversalAdapter.performImport (issue #1942).
void main() {
  // Skip links a flagged duplicate tag; import-as-new still reuses a tag of
  // the same name (#1032). Both must widen the dive tag, never duplicate it.
  for (final action in [DuplicateAction.skip, DuplicateAction.importAsNew]) {
    testWidgets(
      'tags survive an export and re-import (duplicate tag: ${action.name})',
      (tester) async {
        await setUpTestDatabase();
        addTearDown(tearDownTestDatabase);

        final csv = (await tester.runAsync(() async {
          await DiverRepository().createDiver(_diver());
          final tags = TagRepository();
          final travel = await tags.getOrCreateTag(
            'Travel',
            diverId: _diverId,
            scope: TagScope.equipment,
          );
          // The name holds the list delimiter itself.
          final salt = await tags.getOrCreateTag(
            'Salt; fresh',
            diverId: _diverId,
            scope: TagScope.equipment,
          );
          final equipment = EquipmentRepository();
          final reg = await equipment.createEquipment(
            const EquipmentItem(
              id: '',
              diverId: _diverId,
              name: 'Travel reg',
              type: EquipmentType.regulator,
            ),
          );
          await equipment.createEquipment(
            const EquipmentItem(
              id: '',
              diverId: _diverId,
              name: 'Fins',
              type: EquipmentType.fins,
            ),
          );
          await EquipmentTagRepository().replaceTags(reg.id, [
            travel.id,
            salt.id,
          ]);
          final byItem = await EquipmentTagRepository().getTagsByEquipment();
          return CsvExportService().generateEquipmentCsvContent(
            await equipment.getAllEquipment(diverId: _diverId),
            tagNames: {
              for (final MapEntry(:key, :value) in byItem.entries)
                key: [for (final t in value) t.name],
            },
          );
        }))!;
        expect(csv, contains(r'Salt\; fresh; Travel'));

        // Another device, where "Travel" is already a dive tag.
        final travelId = (await tester.runAsync(() async {
          await tearDownTestDatabase();
          await setUpTestDatabase();
          await DiverRepository().createDiver(_diver());
          return (await TagRepository().getOrCreateTag(
            'Travel',
            diverId: _diverId,
          )).id;
        }))!;

        final bytes = Uint8List.fromList(utf8.encode(csv));
        expect(
          const FormatDetector().detect(bytes).format,
          ImportFormat.submersionEquipmentCsv,
        );
        final payload = (await tester.runAsync(
          () =>
              parserForFormat(ImportFormat.submersionEquipmentCsv).parse(bytes),
        ))!;
        final result = await importThroughWizard(
          tester,
          payload: payload,
          diver: _diver(),
          duplicateAction: action,
        );
        expect(result.errorMessage, isNull);

        final (tags, tagsByItem, items) = (await tester.runAsync(
          () async => (
            await TagRepository().getAllTags(diverId: _diverId),
            await EquipmentTagRepository().getTagsByEquipment(),
            await EquipmentRepository().getAllEquipment(diverId: _diverId),
          ),
        ))!;
        final travel = [
          for (final t in tags)
            if (t.name.toLowerCase() == 'travel') t,
        ];
        expect(travel.map((t) => t.id), [
          travelId,
        ], reason: 'the dive tag is widened, not duplicated');
        expect(travel.single.scopes, {TagScope.dives, TagScope.equipment});
        final salt = tags.singleWhere((t) => t.name == 'Salt; fresh');
        expect(salt.scopes, {TagScope.equipment});

        final reg = items.singleWhere((e) => e.name == 'Travel reg');
        final fins = items.singleWhere((e) => e.name == 'Fins');
        expect(tagsByItem[reg.id]!.map((t) => t.name), [
          'Salt; fresh',
          'Travel',
        ]);
        expect(
          tagsByItem[fins.id] ?? const <Tag>[],
          isEmpty,
          reason: 'a blank cell adds nothing',
        );
      },
    );
  }
}
