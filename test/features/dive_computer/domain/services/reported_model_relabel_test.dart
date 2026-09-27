import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/reported_model_relabel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

DiveComputer _computer({String name = 'Cressi Cartesio'}) {
  final now = DateTime(2026, 9, 26);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: name,
    manufacturer: 'Cressi',
    model: 'Cartesio',
    connectionType: 'bluetooth',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('relabelToReportedProduct (issue #422)', () {
    test('replaces the model and the default name', () {
      final relabeled = relabelToReportedProduct(_computer(), 'Donatello');
      expect(relabeled.model, 'Donatello');
      expect(relabeled.name, 'Cressi Donatello');
    });

    test('keeps a name the user chose', () {
      final relabeled = relabelToReportedProduct(
        _computer(name: 'My Cressi'),
        'Donatello',
      );
      expect(relabeled.model, 'Donatello');
      expect(relabeled.name, 'My Cressi');
    });

    test('treats surrounding whitespace in the default name as default', () {
      final relabeled = relabelToReportedProduct(
        _computer(name: ' Cressi Cartesio '),
        'Donatello',
      );
      expect(relabeled.name, 'Cressi Donatello');
    });

    test('is a no-op for null, blank or unchanged products', () {
      final computer = _computer();
      expect(
        identical(relabelToReportedProduct(computer, null), computer),
        isTrue,
      );
      expect(
        identical(relabelToReportedProduct(computer, '  '), computer),
        isTrue,
      );
      expect(
        identical(relabelToReportedProduct(computer, 'Cartesio'), computer),
        isTrue,
      );
    });
  });
}
