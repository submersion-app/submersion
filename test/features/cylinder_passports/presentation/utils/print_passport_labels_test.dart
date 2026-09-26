import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/print_passport_labels.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  Future<void> seed(String id, String type, {String? serial}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id == 'tank' ? 'Faber 12' : 'Apeks',
            type: type,
            serialNumber: Value(serial),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seed('tank', 'tank', serial: 'F123');
    await seed('reg', 'regulator');
    await EquipmentRepository().saveAttributes('tank', [
      EquipmentAttribute.curated(
        equipmentId: 'tank',
        key: EquipmentAttrKeys.identifier,
        valueText: 'S12-A',
      ),
      EquipmentAttribute.curated(
        equipmentId: 'tank',
        key: EquipmentAttrKeys.volumeL,
        valueNum: 12,
      ),
      EquipmentAttribute.curated(
        equipmentId: 'tank',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
      EquipmentAttribute.curated(
        equipmentId: 'tank',
        key: EquipmentAttrKeys.tankMaterial,
        valueText: 'steel',
      ),
    ]);
  });
  tearDown(tearDownTestDatabase);

  /// Pumps a button that prints labels for [ids] and returns what reached
  /// the exporter, or null when it was never called.
  Future<List<PassportLabelData>?> printVia(
    WidgetTester tester,
    List<String> ids,
  ) async {
    List<PassportLabelData>? exported;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => printPassportLabels(
              context,
              ref,
              ids,
              export: (labels, origin) async => exported = labels,
            ),
            child: const Text('print'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('print'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return exported;
  }

  testWidgets('one label per cylinder, other gear skipped', (tester) async {
    final labels = await printVia(tester, ['reg', 'tank']);
    expect(labels, hasLength(1));
    final label = labels!.single;
    expect(label.title, 'Faber 12');
    expect(label.subtitle, 'S12-A F123');
    expect(label.specLine, '12 L, 232 bar, Steel');

    final minted = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId('tank'),
    );
    expect(minted, isNotNull);
    expect(
      label.url,
      startsWith('${PassportPayloadCodec.httpsPrefix}#f=1&p=$minted'),
    );
  });

  testWidgets('a selection with no cylinder exports nothing', (tester) async {
    expect(await printVia(tester, ['reg']), isNull);
  });

  testWidgets('labels follow the selection order', (tester) async {
    await tester.runAsync(() => seed('spare', 'tank', serial: 'S9'));
    final labels = await printVia(tester, ['spare', 'reg', 'tank']);
    expect(labels!.map((l) => l.title), ['Apeks', 'Faber 12']);
  });

  testWidgets('the share sheet anchors on the given widget', (tester) async {
    Rect? origin;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) => Center(
            child: Builder(
              builder: (buttonContext) => SizedBox(
                width: 120,
                height: 40,
                child: TextButton(
                  onPressed: () => printPassportLabels(
                    context,
                    ref,
                    ['tank'],
                    anchor: buttonContext,
                    export: (labels, at) async => origin = at,
                  ),
                  child: const Text('print'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('print'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(origin, tester.getRect(find.byType(SizedBox).last));
  });
}
