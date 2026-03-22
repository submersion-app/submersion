import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';

void main() {
  group('ListViewMode', () {
    test('has three values', () {
      expect(ListViewMode.values.length, 3);
    });

    test('fromName returns correct value for each name', () {
      expect(ListViewMode.fromName('detailed'), ListViewMode.detailed);
      expect(ListViewMode.fromName('compact'), ListViewMode.compact);
      expect(ListViewMode.fromName('dense'), ListViewMode.dense);
    });

    test('fromName returns detailed for unknown name', () {
      expect(ListViewMode.fromName('unknown'), ListViewMode.detailed);
      expect(ListViewMode.fromName(''), ListViewMode.detailed);
    });

    test('name returns correct string for serialization', () {
      expect(ListViewMode.detailed.name, 'detailed');
      expect(ListViewMode.compact.name, 'compact');
      expect(ListViewMode.dense.name, 'dense');
    });
  });
}
