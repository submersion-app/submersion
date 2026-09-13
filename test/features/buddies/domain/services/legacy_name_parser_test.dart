import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

void main() {
  group('LegacyNameParser.parse', () {
    const cases = <(String?, List<String>)>[
      (null, []),
      ('   ', []),
      ('Jim Dunfield, John Ratcliffe', ['Jim Dunfield', 'John Ratcliffe']),
      ('Jim and Ann', ['Jim', 'Ann']),
      ('Jim, Ann, and Bob', ['Jim', 'Ann', 'Bob']),
      ('Hans und Grete', ['Hans', 'Grete']),
      ('Paul et Marie', ['Paul', 'Marie']),
      ('Marco e Giulia', ['Marco', 'Giulia']),
      ('Jan en Piet', ['Jan', 'Piet']),
      ('Anna és Béla', ['Anna', 'Béla']),
      ('Ann; Bob / Cy & Dee + Eve', ['Ann', 'Bob', 'Cy', 'Dee', 'Eve']),
      ('Ann\nBob', ['Ann', 'Bob']),
      ('Ann\r\nBob', ['Ann', 'Bob']),
      ('张伟，李娜、王芳', ['张伟', '李娜', '王芳']),
      ('Joe (Customer)', ['Joe (Customer)']),
      ('Ann (instructor, PADI)', ['Ann (instructor, PADI)']),
      ('Ann [DM / guide], Bob', ['Ann [DM / guide]', 'Bob']),
      ('Ann (and Bob)', ['Ann (and Bob)']),
      ('None', []),
      ('n/a', []),
      ('N/A', []),
      ('John / N/A', ['John']),
      ('Joe (N/A)', ['Joe (N/A)']),
      ('Joe (n/a), N/A, Bob', ['Joe (n/a)', 'Bob']),
      ('Dan/Ann', ['Dan', 'Ann']),
      ('keine', []),
      ('No  Buddy', []),
      ('Solo', []),
      ('--', []),
      ('Ann, 3', ['Ann']),
      ('Ann, ann, ANN ', ['Ann']),
      ('  Jim   Dunfield ', ['Jim Dunfield']),
      ('Anderson', ['Anderson']),
      ('Andy and Eve', ['Andy', 'Eve']),
      ('Nadia', ['Nadia']),
      // A capital single letter is a middle initial, not a conjunction.
      ('John E Smith', ['John E Smith']),
      ('Mary Y Chen', ['Mary Y Chen']),
      ('Ana y Luis', ['Ana', 'Luis']),
      // Word conjunctions stay case-insensitive.
      ('Jim AND Ann', ['Jim', 'Ann']),
      // The accepted cost of splitting on "y": pinned so a change is a
      // deliberate decision, not a silent one.
      ('Ortega y Gasset', ['Ortega', 'Gasset']),
    ];

    for (final (input, expected) in cases) {
      final label = input == null
          ? 'null'
          : '"${input.replaceAll('\n', r'\n').replaceAll('\r', r'\r')}"';
      test('parses $label', () {
        expect(LegacyNameParser.parse(input), expected);
      });
    }
  });

  group('legacyNameKey', () {
    test('trims, collapses whitespace and lowercases non-ASCII letters', () {
      expect(legacyNameKey('  ÉRIC   Dupont '), 'éric dupont');
    });
  });
}
