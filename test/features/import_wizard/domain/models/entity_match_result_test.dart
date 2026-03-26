import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';

void main() {
  group('EntityMatchResult', () {
    test('constructs with required fields', () {
      const result = EntityMatchResult(
        existingId: 'site-123',
        existingName: 'Blue Hole',
        existingFields: {'Location': '27.4N, 33.9E', 'Max Depth': '130m'},
        incomingFields: {'Location': '27.5N, 33.9E', 'Max Depth': '125m'},
      );

      expect(result.existingId, 'site-123');
      expect(result.existingName, 'Blue Hole');
      expect(result.existingFields, hasLength(2));
      expect(result.incomingFields, hasLength(2));
    });

    test('existingFields values match expected entries', () {
      const result = EntityMatchResult(
        existingId: 'buddy-1',
        existingName: 'John Doe',
        existingFields: {'Email': 'john@example.com', 'Cert Level': 'OW'},
        incomingFields: {'Email': 'john@example.com', 'Cert Level': 'AOW'},
      );

      expect(result.existingFields['Email'], 'john@example.com');
      expect(result.existingFields['Cert Level'], 'OW');
      expect(result.incomingFields['Cert Level'], 'AOW');
    });

    test('supports nullable field values', () {
      const result = EntityMatchResult(
        existingId: 'site-1',
        existingName: 'Wreck Site',
        existingFields: {'Location': '25.0N, -80.1W', 'Notes': null},
        incomingFields: {'Location': null, 'Notes': 'Good vis'},
      );

      expect(result.existingFields['Notes'], isNull);
      expect(result.incomingFields['Location'], isNull);
      expect(result.incomingFields['Notes'], 'Good vis');
    });

    test('works with empty field maps', () {
      const result = EntityMatchResult(
        existingId: 'gear-1',
        existingName: 'BCD',
        existingFields: {},
        incomingFields: {},
      );

      expect(result.existingFields, isEmpty);
      expect(result.incomingFields, isEmpty);
    });

    test('is const-constructible', () {
      const result = EntityMatchResult(
        existingId: 'id',
        existingName: 'name',
        existingFields: {},
        incomingFields: {},
      );

      expect(result, isNotNull);
    });
  });
}
