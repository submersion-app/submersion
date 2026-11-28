import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/documents/catalog_documents.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// What an agent reads of a weight preset's entries.
void main() {
  test('an entry carries its side, null for both sides (#5028)', () {
    const left = WeightPresetEntry(
      id: 'e1',
      presetId: 'p1',
      weightType: WeightType.integrated,
      amountKg: 2,
      side: WeightSide.left,
    );
    expect(weightPresetEntryDocument(left)['side'], 'left');
    final both = weightPresetEntryDocument(
      const WeightPresetEntry(
        id: 'e2',
        presetId: 'p1',
        weightType: WeightType.belt,
        amountKg: 4,
      ),
    );
    expect(both.containsKey('side'), isTrue);
    expect(both['side'], isNull);
  });
}
