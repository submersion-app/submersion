import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// Weight names (issue #956) survive a full UDDF backup and restore.
void main() {
  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
  );
  const weights = [
    DiveWeight(
      id: 'w1',
      diveId: 'dive-a',
      weightType: WeightType.trimWeights,
      amountKg: 2,
      label: 'Top pocket',
    ),
    DiveWeight(
      id: 'w2',
      diveId: 'dive-a',
      weightType: WeightType.belt,
      amountKg: 4,
    ),
  ];

  Future<String> backup() => UddfFullExportService().generateAllDataXmlForTest(
    dives: [dive],
    diveWeights: {'dive-a': weights},
  );

  test('a named weight comes back with its name', () async {
    final dives = (await UddfFullImportService().importAllDataFromUddf(
      await backup(),
    )).dives;
    final restored = (dives.single['weights'] as List)
        .cast<Map<String, dynamic>>();
    expect(restored.map((w) => w['label']).toList(), ['Top pocket', '']);
  });

  test('an unnamed weight writes no label element', () async {
    expect('<label>'.allMatches(await backup()).length, 1);
  });
}
