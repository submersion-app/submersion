import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

void main() {
  Map<String, String> sample(QueryErrorCode c) => {
    for (final a in c.argNames) a: '<$a>',
  };

  test('the English ARB renders exactly the engine English for every code', () {
    final en = l10nForLocaleTag('en');
    for (final c in QueryErrorCode.values) {
      final e = QueryError(c, args: sample(c));
      expect(describeQueryError(en, e), e.message, reason: c.name);
    }
  });

  test('every locale renders every code with every arg', () {
    for (final tag in [
      'ar',
      'de',
      'es',
      'fr',
      'he',
      'hu',
      'it',
      'nl',
      'pt',
      'zh',
    ]) {
      final l10n = l10nForLocaleTag(tag);
      for (final c in QueryErrorCode.values) {
        final text = describeQueryError(l10n, QueryError(c, args: sample(c)));
        for (final a in c.argNames) {
          expect(text, contains('<$a>'), reason: '$tag ${c.name} drops {$a}');
        }
      }
    }
  });
}
