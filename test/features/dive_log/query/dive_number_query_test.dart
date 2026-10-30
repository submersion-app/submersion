import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/query/dive_number_query.dart';

void main() {
  group('bareDiveNumber', () {
    test('a lone whole number is a dive number', () {
      expect(bareDiveNumber(TextNode(['500'])), 500);
      expect(bareDiveNumber(TextNode(['7'])), 7);
    });

    test('a leading # is allowed', () {
      expect(bareDiveNumber(TextNode(['#500'])), 500);
    });

    test('Arabic-Indic and full-width digits count too', () {
      expect(bareDiveNumber(TextNode(['٥٠٠'])), 500);
      expect(bareDiveNumber(TextNode(['۵۰۰'])), 500);
      expect(bareDiveNumber(TextNode(['#５００'])), 500);
    });

    test('anything else is not', () {
      expect(bareDiveNumber(null), isNull);
      expect(bareDiveNumber(TextNode(['manta'])), isNull);
      expect(bareDiveNumber(TextNode(['5.5'])), isNull);
      expect(bareDiveNumber(TextNode(['-3'])), isNull);
      expect(bareDiveNumber(TextNode(['#'])), isNull);
      expect(bareDiveNumber(TextNode(['##5'])), isNull);
      expect(bareDiveNumber(TextNode(['500', 'bar'])), isNull);
      expect(
        bareDiveNumber(
          AndNode([
            TextNode(['500']),
            TextNode(['bar']),
          ]),
        ),
        isNull,
      );
      expect(
        bareDiveNumber(diveNumberQuery(500)),
        isNull,
        reason: 'the explicit field is a filter, not a typed number',
      );
    });

    test('a number too large to be a dive number is not one', () {
      expect(bareDiveNumber(TextNode(['99999999999999999999999'])), isNull);
    });
  });

  test('diveNumberQuery asks for that dive number exactly', () {
    expect(
      diveNumberQuery(500),
      ConditionNode(
        FieldPath(['diveNumber']),
        QueryOp.eq,
        const NumberValue(500, null),
      ),
    );
  });
}
