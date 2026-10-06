import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_import/data/services/import_weight_mapper.dart';

void main() {
  test('maps a parsed weight, name included', () {
    final weight = weightFromImportData(
      {
        'amount': 2.0,
        'type': WeightType.trimWeights,
        'notes': 'n',
        'label': '  Top pocket ',
      },
      id: 'w1',
      diveId: 'd1',
    );
    expect(weight.id, 'w1');
    expect(weight.diveId, 'd1');
    expect(weight.weightType, WeightType.trimWeights);
    expect(weight.amountKg, 2.0);
    expect(weight.notes, 'n');
    expect(weight.label, 'Top pocket');
  });

  test('missing keys fall back as before', () {
    final weight = weightFromImportData(const {}, id: 'w1', diveId: 'd1');
    expect(weight.weightType, WeightType.integrated);
    expect(weight.amountKg, 0.0);
    expect(weight.notes, '');
    expect(weight.label, '');
  });
}
