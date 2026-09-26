import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';

void main() {
  Map<String, String> sample(QueryErrorCode c) => {
    for (final a in c.argNames) a: '<$a>',
  };

  test('every code has English text that uses every arg and no other', () {
    for (final c in QueryErrorCode.values) {
      final text = englishQueryMessage(c, sample(c));
      expect(text, isNotEmpty, reason: c.name);
      for (final a in c.argNames) {
        expect(text, contains('<$a>'), reason: '${c.name} drops {$a}');
      }
      expect(text, isNot(contains('{')), reason: '${c.name} left a brace');
    }
  });

  test('message is the English text of the code and args', () {
    const e = QueryError(
      QueryErrorCode.noUnitAllowed,
      args: {'field': 'rating'},
    );
    expect(e.message, 'rating takes no unit');
  });

  test('equality follows code, args and position, not suggestions', () {
    const a = QueryError(
      QueryErrorCode.unknownField,
      args: {'name': 'dpeth'},
      offset: 0,
      length: 5,
      suggestions: ['depth'],
    );
    const b = QueryError(
      QueryErrorCode.unknownField,
      args: {'name': 'dpeth'},
      offset: 0,
      length: 5,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        QueryError(
          QueryErrorCode.unknownField,
          args: const {'name': 'dpeth'},
          path: FieldPath(['dpeth']),
        ),
      ),
    );
    expect(
      a,
      isNot(
        const QueryError(
          QueryErrorCode.unknownField,
          args: {'name': 'depht'},
          offset: 0,
          length: 5,
        ),
      ),
    );
  });
}
