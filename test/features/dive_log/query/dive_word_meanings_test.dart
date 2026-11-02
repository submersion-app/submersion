import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/query_plain_words.dart';
import 'package:submersion/features/dive_log/query/dive_word_meanings.dart';

void main() {
  group('years', () {
    test('a four digit year in range', () {
      expect(diveYearTerms('2018'), ['2018']);
      expect(diveYearTerms('1900'), ['1900']);
      expect(diveYearTerms('2200'), ['2200']);
    });

    test('other number scripts read as the same year', () {
      expect(diveYearTerms('٢٠١٨'), ['2018']);
    });

    test('anything else is no year', () {
      expect(diveYearTerms('1899'), isEmpty);
      expect(diveYearTerms('2201'), isEmpty);
      expect(diveYearTerms('500'), isEmpty);
      expect(diveYearTerms('#2018'), isEmpty);
      expect(diveYearTerms('ressel'), isEmpty);
    });
  });

  group('months', () {
    test('a full name, in any case, zero padded', () {
      expect(diveMonthTerms('october'), ['10']);
      expect(diveMonthTerms('OCTOBER'), ['10']);
      expect(diveMonthTerms('march'), ['03']);
    });

    test('in any app language', () {
      expect(diveMonthTerms('octobre'), ['10']);
      expect(diveMonthTerms('oktober'), ['10']);
      expect(diveMonthTerms('octubre'), ['10']);
    });

    test('a short form is no month', () {
      expect(diveMonthTerms('oct'), isEmpty);
      expect(diveMonthTerms('jan'), isEmpty);
    });
  });

  group('weekdays', () {
    test('use sqlite numbering, Sunday first', () {
      expect(diveWeekdayTerms('sunday'), ['0']);
      expect(diveWeekdayTerms('Saturday'), ['6']);
    });

    test('in any app language', () {
      expect(diveWeekdayTerms('samedi'), ['6']);
      expect(diveWeekdayTerms('samstag'), ['6']);
    });

    test('a short form is no weekday', () {
      expect(diveWeekdayTerms('sat'), isEmpty);
      expect(diveWeekdayTerms('sun'), isEmpty);
    });
  });

  group('settings', () {
    test('dive mode reads its listed words and whole labels', () {
      expect(diveModeTerms('ccr'), ['ccr']);
      expect(diveModeTerms('oc'), ['oc']);
      expect(diveModeTerms('gauge'), ['gauge']);
      expect(diveModeTerms('rebreather'), unorderedEquals(['ccr', 'scr']));
      expect(diveModeTerms('open circuit'), ['oc']);
      expect(diveModeTerms('Closed Circuit Rebreather'), ['ccr']);
    });

    test('a word from a longer label is no dive mode', () {
      expect(diveModeTerms('open'), isEmpty);
      expect(diveModeTerms('closed'), isEmpty);
      expect(diveModeTerms('circuit'), isEmpty);
    });

    test('entry reads labels, and never Other', () {
      expect(diveEntryTerms('shore'), ['shore']);
      expect(diveEntryTerms('boat'), ['boat']);
      expect(diveEntryTerms('back roll'), ['backRoll']);
      expect(diveEntryTerms('jetty'), ['jetty']);
      expect(diveEntryTerms('dock'), ['jetty']);
      expect(diveEntryTerms('other'), isEmpty);
      expect(diveEntryTerms('roll'), isEmpty);
    });

    test('water reads labels and its listed words', () {
      expect(diveWaterTerms('salt'), ['salt']);
      expect(diveWaterTerms('saltwater'), ['salt']);
      expect(diveWaterTerms('salt water'), ['salt']);
      expect(diveWaterTerms('freshwater'), ['fresh']);
      expect(diveWaterTerms('brackish'), ['brackish']);
      expect(diveWaterTerms('water'), isEmpty);
    });

    test('favourite in either spelling', () {
      expect(diveFavouriteTerms('favourite'), ['1']);
      expect(diveFavouriteTerms('FAVORITE'), ['1']);
      expect(diveFavouriteTerms('favorites'), ['1']);
      expect(diveFavouriteTerms('favour'), isEmpty);
    });

    test('favourite in any app language', () {
      expect(diveFavouriteTerms('favori'), ['1']);
      expect(diveFavouriteTerms('favorit'), ['1']);
    });
  });

  group('gas', () {
    test('the three mix names', () {
      expect(diveGasTerms('air'), ['air']);
      expect(diveGasTerms('nitrox'), ['nitrox']);
      expect(diveGasTerms('Trimix'), ['trimix']);
      expect(diveGasTerms('heliox'), isEmpty);
    });

    test('eanNN names the oxygen percent', () {
      expect(diveEanTerms('ean32'), ['32']);
      expect(diveEanTerms('EAN36'), ['36']);
      expect(diveEanTerms('ean'), isEmpty);
      expect(diveEanTerms('ean320'), isEmpty);
    });
  });

  group('multi-word labels', () {
    test('a whole label is one phrase', () {
      expect(diveLabelPhrase(['salt', 'water']), isTrue);
      expect(diveLabelPhrase(['back', 'roll']), isTrue);
      expect(diveLabelPhrase(['open', 'circuit']), isTrue);
    });

    test('every label fits the phrase the parser reads', () {
      expect(diveLabelPhrases, isNotEmpty);
      for (final phrase in diveLabelPhrases) {
        expect(
          phrase.split(' ').length,
          lessThanOrEqualTo(kLongestLabelPhrase),
          reason: phrase,
        );
      }
    });

    test('other words are not', () {
      expect(diveLabelPhrase(['open', 'water']), isFalse);
      expect(diveLabelPhrase(['salt', 'pier']), isFalse);
    });
  });
}
