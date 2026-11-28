import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// The side a weight is carried on (issue #5028) survives a full UDDF
/// backup and restore; a weight on both sides writes no side element.
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
      weightType: WeightType.integrated,
      amountKg: 2,
      side: WeightSide.left,
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

  test('a sided weight comes back with its side', () async {
    final dives = (await UddfFullImportService().importAllDataFromUddf(
      await backup(),
    )).dives;
    final restored = (dives.single['weights'] as List)
        .cast<Map<String, dynamic>>();
    expect(restored.map((w) => w['side']).toList(), ['left', null]);
  });

  test('a weight on both sides writes no side element', () async {
    expect('<side>'.allMatches(await backup()).length, 1);
  });
}
