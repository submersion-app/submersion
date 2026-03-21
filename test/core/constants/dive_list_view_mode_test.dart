import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';

void main() {
  group('DiveListViewMode', () {
    test('has three values', () {
      expect(DiveListViewMode.values.length, 3);
    });

    test('fromName returns correct value for each name', () {
      expect(DiveListViewMode.fromName('detailed'), DiveListViewMode.detailed);
      expect(DiveListViewMode.fromName('compact'), DiveListViewMode.compact);
      expect(DiveListViewMode.fromName('dense'), DiveListViewMode.dense);
    });

    test('fromName returns detailed for unknown name', () {
      expect(DiveListViewMode.fromName('unknown'), DiveListViewMode.detailed);
      expect(DiveListViewMode.fromName(''), DiveListViewMode.detailed);
    });

    test('name returns correct string for serialization', () {
      expect(DiveListViewMode.detailed.name, 'detailed');
      expect(DiveListViewMode.compact.name, 'compact');
      expect(DiveListViewMode.dense.name, 'dense');
    });
  });
}
