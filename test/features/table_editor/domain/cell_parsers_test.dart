import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/cell_parsers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Cell text becomes a stored value through the diver's number format and
/// units (#3422), never through double.parse.
void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Object? valueOf(CellParseResult r) => (r as CellParsed).value;
  TableDraftFlag flagOf(CellParseResult r) => (r as CellRejected).flag;

  group('numbers', () {
    test('decimal comma weight parses to kg for a metric diver', () {
      Intl.defaultLocale = 'de';
      final r = parseNumberCell('6,5', toStored: (v) => v);
      expect(valueOf(r), 6.5);
    });

    test('imperial weight converts to kg', () {
      Intl.defaultLocale = 'en_US';
      const units = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));
      final r = parseNumberCell('13', toStored: units.weightToKg);
      expect(valueOf(r), closeTo(5.897, 0.01));
    });

    test('blank clears, unparsable is rejected as unparsable', () {
      Intl.defaultLocale = 'en_US';
      expect(valueOf(parseNumberCell('  ', toStored: (v) => v)), isNull);
      expect(
        flagOf(parseNumberCell('six', toStored: (v) => v)),
        TableDraftFlag.unparsable,
      );
    });

    test('a number outside min or max is rejected', () {
      Intl.defaultLocale = 'en_US';
      expect(
        flagOf(parseNumberCell('120', toStored: (v) => v, max: 100)),
        TableDraftFlag.unparsable,
      );
      expect(
        valueOf(parseNumberCell('100', toStored: (v) => v, max: 100)),
        100,
      );
    });

    test('integers reject fractions and respect bounds', () {
      Intl.defaultLocale = 'en_US';
      expect(valueOf(parseIntegerCell('4', min: 0, max: 5)), 4);
      expect(flagOf(parseIntegerCell('4.5')), TableDraftFlag.unparsable);
      expect(flagOf(parseIntegerCell('7', max: 5)), TableDraftFlag.unparsable);
      expect(valueOf(parseIntegerCell('')), isNull);
    });

    test('degrees outside the limit are rejected', () {
      Intl.defaultLocale = 'en_US';
      expect(valueOf(parseDegreesCell('-33.9', limit: 90)), -33.9);
      expect(
        flagOf(parseDegreesCell('91', limit: 90)),
        TableDraftFlag.unparsable,
      );
      expect(valueOf(parseDegreesCell('', limit: 90)), isNull);
    });
  });

  group('choices', () {
    const options = [
      ChoiceOption('salt', 'Salt Water'),
      ChoiceOption('fresh', 'Fresh Water'),
    ];

    test('choice matches label case-insensitively and rejects unknown', () {
      expect(valueOf(parseChoiceCell('salt water', options)), 'salt');
      expect(valueOf(parseChoiceCell('FRESH', options)), 'fresh');
      expect(valueOf(parseChoiceCell('', options)), isNull);
      expect(
        flagOf(parseChoiceCell('Brine', options)),
        TableDraftFlag.unknownValue,
      );
    });

    test(
      'multi choice splits on comma or semicolon and rejects one unknown',
      () {
        expect(valueOf(parseMultiChoiceCell('Salt Water; fresh', options)), [
          'salt',
          'fresh',
        ]);
        expect(valueOf(parseMultiChoiceCell('salt, fresh', options)), [
          'salt',
          'fresh',
        ]);
        expect(
          flagOf(parseMultiChoiceCell('salt, brine', options)),
          TableDraftFlag.unknownValue,
        );
        expect(valueOf(parseMultiChoiceCell('', options)), <String>[]);
      },
    );
  });

  group('toggles and text', () {
    final en = AppLocalizationsEn();

    test('toggle accepts localized yes and no', () {
      expect(valueOf(parseToggleCell(en.attr_flagYes, en)), isTrue);
      expect(valueOf(parseToggleCell(en.attr_flagNo, en)), isFalse);
      expect(valueOf(parseToggleCell('TRUE', en)), isTrue);
      expect(valueOf(parseToggleCell('0', en)), isFalse);
      expect(valueOf(parseToggleCell('', en)), isFalse);
      expect(flagOf(parseToggleCell('maybe', en)), TableDraftFlag.unparsable);
    });

    test('text trims and treats blank as empty', () {
      expect(valueOf(parseTextCell('  hello ')), 'hello');
      expect(valueOf(parseTextCell('   ')), isNull);
    });
  });

  test('a label two records share is refused, and the id still picks one', () {
    const options = [
      ChoiceOption('s1', 'House Reef'),
      ChoiceOption('s2', 'House Reef'),
    ];

    expect(parseChoiceCell('House Reef', options), isA<CellRejected>());
    expect((parseChoiceCell('s2', options) as CellParsed).value, 's2');
  });

  test('a repeated entry in a list cell counts once', () {
    const options = [ChoiceOption('shore', 'Shore')];

    expect(
      (parseMultiChoiceCell('Shore, shore', options) as CellParsed).value,
      ['shore'],
    );
  });
}
