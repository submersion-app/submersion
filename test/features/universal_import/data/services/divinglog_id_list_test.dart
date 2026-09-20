import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_id_list.dart';

void main() {
  group('parseDivingLogIdList', () {
    test('reads a comma separated list', () {
      expect(parseDivingLogIdList('3,15,16'), [3, 15, 16]);
    });

    test('reads a single id', () {
      expect(parseDivingLogIdList('1'), [1]);
    });

    test('returns empty for null, empty and whitespace', () {
      expect(parseDivingLogIdList(null), isEmpty);
      expect(parseDivingLogIdList(''), isEmpty);
      expect(parseDivingLogIdList('   '), isEmpty);
    });

    test('tolerates spaces and trailing separators', () {
      expect(parseDivingLogIdList(' 8 , 9 ,'), [8, 9]);
    });

    test('drops entries that are not numbers', () {
      expect(parseDivingLogIdList('4,,x,5'), [4, 5]);
    });

    test('keeps order and does not deduplicate', () {
      expect(parseDivingLogIdList('5,1,5'), [5, 1, 5]);
    });
  });
}
