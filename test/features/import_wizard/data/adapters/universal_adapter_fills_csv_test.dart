import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    show ImportFormat;
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../core/services/export/csv/csv_test_fixtures.dart';
import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// A Submersion fills CSV through UniversalAdapter the way the wizard runs
/// it: a Fills group in the bundle, the id-keeping importer, the passport
/// link, and the summary count (cylinder passports phase 5).
void main() {
  testWidgets('a fills CSV imports as a Fills group and links by passport id', (
    tester,
  ) async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.runAsync(() async {
      await DiverRepository().createDiver(_diver());
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tank-1',
              name: 'AL80',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(_diverId),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'tank-1',
        passportId: 'pp-al80',
        diverId: _diverId,
      );
    });

    final bytes = Uint8List.fromList(
      utf8.encode(CsvFillsWriter(CsvExportUnits.metric).write(goldenFills())),
    );
    final detected = const FormatDetector().detect(bytes).format;
    expect(detected, ImportFormat.submersionFillsCsv);
    final payload = await parserForFormat(detected).parse(bytes);

    final result = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(result.errorMessage, isNull);
    expect(result.importedCounts[ImportEntityType.fills], 2);

    await tester.runAsync(() async {
      final fills = CylinderFillRepository();
      final linked = (await fills.getById(goldenFills().first.id))!;
      expect(linked.equipmentId, 'tank-1');
      expect(linked.diverId, _diverId);
      final unlinked = (await fills.getById(goldenFills()[1].id))!;
      expect(unlinked.equipmentId, isNull);
      expect(unlinked.passportId, 'pp-foreign');
    });

    // The same file again: the review shows the rows, the import adds none.
    final again = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(again.errorMessage, isNull);
    expect(again.importedCounts[ImportEntityType.fills], isNull);
    await tester.runAsync(() async {
      expect(
        await CylinderFillRepository().getAllVisibleTo(_diverId),
        hasLength(2),
      );
    });
  });
}
