import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';

void main() {
  group('countryCodeFor', () {
    void expectCode(String? text, String? code) =>
        expect(countryCodeFor(text), code, reason: 'for "$text"');

    test('resolves names in any place-name language, folded', () {
      for (final text in ['Mexico', '  méxico ', 'MEXIQUE', 'Messico', '墨西哥']) {
        expectCode(text, 'MX');
      }
    });

    test('resolves alpha-2 and alpha-3 codes', () {
      expectCode('mx', 'MX');
      expectCode('MEX', 'MX');
    });

    test('resolves local names stored by geocoding', () {
      expectCode('República Dominicana', 'DO');
      expectCode('مصر', 'EG');
      expectCode('ދިވެހިރާއްޖެ', 'MV');
    });

    test('resolves the hand-kept aliases', () {
      for (final text in [
        'UK',
        'England',
        'Scotland',
        'Wales',
        'Northern Ireland',
      ]) {
        expectCode(text, 'GB');
      }
      expectCode('Holland', 'NL');
      for (final text in ['Bonaire', 'Sint Eustatius', 'Saba']) {
        expectCode(text, 'BQ');
      }
      expectCode('USA', 'US');
      expectCode('U.S.A.', 'US');
      expectCode('Czech Republic', 'CZ');
      expectCode('Turks and Caicos', 'TC');
    });

    test('reads "and" for "&", drops a leading "The", collapses spaces', () {
      // Geocoders and divers write these forms; English CLDR writes "&".
      expectCode('Trinidad and Tobago', 'TT');
      expectCode('Turks and Caicos Islands', 'TC');
      expectCode('Bosnia & Herzegovina', 'BA');
      expectCode('Antigua and Barbuda', 'AG');
      expectCode('Sao Tome and Principe', 'ST');
      expectCode('The Bahamas', 'BS');
      expectCode('the Netherlands', 'NL');
      expectCode('The Philippines', 'PH');
      expectCode('Costa  Rica', 'CR');
      expectCode('United States of America', 'US');
      expectCode('UAE', 'AE');
    });

    test('a name more than one country goes by gives no code', () {
      // "Congo" is as often the Democratic Republic as the Republic: no
      // flag beats the wrong one.
      expectCode('Congo', null);
      expectCode('DR Congo', 'CD');
      expectCode('Congo - Brazzaville', 'CG');
    });

    test('folds decomposed accents and wider Latin letters', () {
      // "México" typed as "e" plus a combining acute (U+0301).
      expectCode('México', 'MX');
      // Czech's own name for Czechia, typed with or without its háček.
      expectCode('Česko', 'CZ');
      expectCode('Cesko', 'CZ');
    });

    test('ignores accents either way', () {
      expectCode('Curacao', 'CW');
      expectCode('Curaçao', 'CW');
    });

    test('gives no code for blank, unassigned or partial matches', () {
      for (final text in [
        null,
        '',
        '  ',
        'EU',
        'ZZ',
        'YU',
        'Gulf of Mexico',
        'Mexico City',
        'Red Sea, Egypt',
        'Atlantis',
      ]) {
        expectCode(text, null);
      }
    });

    test('resolves every name the emergency card resolved before', () {
      // The emergency card's own table before it moved to countryCodeFor
      // (issue #4426): each of these must keep its region.
      const previous = {
        'UNITED STATES': 'US',
        'USA': 'US',
        'CANADA': 'CA',
        'MEXICO': 'MX',
        'AUSTRALIA': 'AU',
        'NEW ZEALAND': 'NZ',
        'UNITED KINGDOM': 'GB',
        'IRELAND': 'IE',
        'FRANCE': 'FR',
        'SPAIN': 'ES',
        'PORTUGAL': 'PT',
        'ITALY': 'IT',
        'MALTA': 'MT',
        'GREECE': 'GR',
        'CROATIA': 'HR',
        'GERMANY': 'DE',
        'AUSTRIA': 'AT',
        'SWITZERLAND': 'CH',
        'NETHERLANDS': 'NL',
        'BELGIUM': 'BE',
        'NORWAY': 'NO',
        'SWEDEN': 'SE',
        'DENMARK': 'DK',
        'FINLAND': 'FI',
        'POLAND': 'PL',
        'CZECHIA': 'CZ',
        'CZECH REPUBLIC': 'CZ',
        'HUNGARY': 'HU',
        'TURKEY': 'TR',
        'CYPRUS': 'CY',
        'EGYPT': 'EG',
        'ISRAEL': 'IL',
        'SOUTH AFRICA': 'ZA',
        'MOZAMBIQUE': 'MZ',
        'TANZANIA': 'TZ',
        'KENYA': 'KE',
        'SEYCHELLES': 'SC',
        'MAURITIUS': 'MU',
        'JAPAN': 'JP',
        'SOUTH KOREA': 'KR',
        'TAIWAN': 'TW',
        'INDONESIA': 'ID',
        'MALAYSIA': 'MY',
        'THAILAND': 'TH',
        'PHILIPPINES': 'PH',
        'SINGAPORE': 'SG',
        'VIETNAM': 'VN',
        'CAMBODIA': 'KH',
        'MYANMAR': 'MM',
        'MALDIVES': 'MV',
        'SRI LANKA': 'LK',
        'FIJI': 'FJ',
        'PAPUA NEW GUINEA': 'PG',
        'VANUATU': 'VU',
        'PALAU': 'PW',
        'MICRONESIA': 'FM',
        'MARSHALL ISLANDS': 'MH',
        'BAHAMAS': 'BS',
        'CAYMAN ISLANDS': 'KY',
        'TURKS AND CAICOS': 'TC',
        'BERMUDA': 'BM',
        'COSTA RICA': 'CR',
        'PANAMA': 'PA',
        'BELIZE': 'BZ',
        'HONDURAS': 'HN',
        'COLOMBIA': 'CO',
        'ECUADOR': 'EC',
        'BRAZIL': 'BR',
        'ARGENTINA': 'AR',
        'CHILE': 'CL',
        'PERU': 'PE',
        'DEUTSCHLAND': 'DE',
        'ALLEMAGNE': 'DE',
        'ALEMANIA': 'DE',
        'GERMANIA': 'DE',
        'DUITSLAND': 'DE',
        'FRANKREICH': 'FR',
        'FRANCIA': 'FR',
        'FRANKRIJK': 'FR',
        'SPANIEN': 'ES',
        'ESPAGNE': 'ES',
        'SPAGNA': 'ES',
        'SPANJE': 'ES',
        'ITALIA': 'IT',
        'ITALIEN': 'IT',
        'ITALIE': 'IT',
        'NIEDERLANDE': 'NL',
        'PAESI BASSI': 'NL',
        'NEDERLAND': 'NL',
        'GRIECHENLAND': 'GR',
        'GRECIA': 'GR',
        'GRIEKENLAND': 'GR',
        'KROATIEN': 'HR',
        'CROACIA': 'HR',
        'CROATIE': 'HR',
        'CROAZIA': 'HR',
        'EGIPTO': 'EG',
        'EGITTO': 'EG',
        'EGITO': 'EG',
        'MEXIKO': 'MX',
        'MEXIQUE': 'MX',
        'MESSICO': 'MX',
        'MALEDIVEN': 'MV',
        'MALDIVAS': 'MV',
        'MALDIVE': 'MV',
        'INDONESIEN': 'ID',
        'TAILANDIA': 'TH',
        'THAILANDIA': 'TH',
        'FILIPINAS': 'PH',
        'PHILIPPINEN': 'PH',
        'FILIPPINE': 'PH',
        'FILIPIJNEN': 'PH',
        'TURQUIE': 'TR',
        'TURCHIA': 'TR',
        'TURQUIA': 'TR',
      };
      for (final entry in previous.entries) {
        expectCode(entry.key, entry.value);
      }
    });
  });

  group('generated table', () {
    test('keys are folded the way the app folds a stored country', () {
      // The Python generator mirrors textSortKey; this catches the two
      // drifting apart. Every key must already be its own fold.
      final drifted = [
        for (final key in cldrCountryNameCodes.keys)
          if (countryLookupKey(key) != key) key,
      ];
      expect(drifted, isEmpty);
    });

    test('lookup key is textSortKey without periods', () {
      expect(countryLookupKey(' U.S.A. '), textSortKey('USA'));
    });

    test('every name maps to an assigned code', () {
      expect(
        cldrCountryNameCodes.values.toSet().difference(assignedAlpha2Codes),
        isEmpty,
      );
      expect(assignedAlpha2Codes, hasLength(249));
    });
  });
}
