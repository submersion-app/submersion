import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Certification cert(
    String id, {
    String name = '',
    String? level,
    CertificationAgency agency = CertificationAgency.padi,
    DateTime? issueDate,
  }) => Certification(
    id: id,
    name: name,
    agency: agency.name,
    level: level,
    issueDate: issueDate,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  List<String> order(
    List<Certification> certs,
    CertificationSortField field,
    SortDirection direction,
  ) => applyCertificationSorting(
    certs,
    SortState(field: field, direction: direction),
    l10n: lookupAppLocalizations(const Locale('en')),
  ).map((c) => c.id).toList();

  List<String> titleOrder(
    List<Certification> certs,
    SortDirection direction, {
    String locale = 'en',
  }) => applyCertificationSorting(
    certs,
    SortState(field: CertificationSortField.name, direction: direction),
    l10n: lookupAppLocalizations(Locale(locale)),
  ).map((c) => c.id).toList();

  // The list shows certificationTitle (the custom name, else the
  // certification), so the title sort must order by that, not by the raw
  // stored name, which is blank for certifications saved without one and
  // "PADI : ..." for legacy rows (#3195).
  group('title sort', () {
    final certs = [
      cert('rescue', level: CertificationLevel.rescue.name),
      cert('custom', name: 'Bali OW w/ Made'),
      cert(
        'legacy',
        name: 'PADI : Advanced Open Water',
        level: CertificationLevel.advancedOpenWater.name,
      ),
      cert('ow', level: CertificationLevel.openWater.name),
    ];

    test('orders by the displayed title, A to Z', () {
      expect(titleOrder(certs, SortDirection.descending), [
        'legacy', // Advanced Open Water
        'custom', // Bali OW w/ Made
        'ow', // Open Water
        'rescue', // Rescue Diver
      ]);
    });

    // The rows render the localized title, so the order must follow it:
    // in French "Plongeur autonome" (Open Water) sorts before "Plongeur
    // autonome avancé" (Advanced Open Water), the reverse of English.
    test('orders by the title in the active locale', () {
      expect(titleOrder(certs, SortDirection.descending, locale: 'fr'), [
        'custom', // Bali OW w/ Made
        'ow', // Plongeur autonome
        'legacy', // Plongeur autonome avance
        'rescue', // Plongeur sauveteur
      ]);
    });

    test('reverses for the other direction', () {
      expect(titleOrder(certs, SortDirection.ascending), [
        'rescue',
        'ow',
        'custom',
        'legacy',
      ]);
    });
  });

  // Ties on the sorted key fall through to the other visible keys, so
  // certifications issued on one day (an agency crossover) come out in a
  // findable order instead of whatever the unstable sort left (#5070).
  // "Descending" is each field's reading order (newest first, A to Z) and
  // the other direction reverses the whole chain, tiebreakers included.
  group('tiebreakers (#5070)', () {
    const ssi = CertificationAgency.ssi;
    final day = DateTime(2019, 5, 4);
    final padiAow = cert(
      'padiAow',
      level: CertificationLevel.advancedOpenWater.name,
      issueDate: day,
    );
    final ssiNitrox = cert(
      'ssiNitrox',
      name: 'Nitrox',
      agency: ssi,
      issueDate: day,
    );
    final ssiDeep = cert('ssiDeep', name: 'Deep', agency: ssi, issueDate: day);
    final ssiOw = cert(
      'ssiOw',
      level: CertificationLevel.openWater.name,
      agency: ssi,
      issueDate: DateTime(2018),
    );
    final undatedA = cert('undatedA', name: 'Zeta', agency: ssi);
    final undatedB = cert('undatedB', name: 'Alpha', agency: ssi);
    final twinX = cert('twinX', name: 'Twin', issueDate: DateTime(2020));
    final twinY = cert('twinY', name: 'Twin', issueDate: DateTime(2020));

    // Deliberately scrambled, so nothing passes by keeping the input order.
    final shuffled = [
      ssiNitrox,
      undatedA,
      twinY,
      ssiOw,
      padiAow,
      undatedB,
      ssiDeep,
      twinX,
    ];

    const dateReadingOrder = [
      'twinX',
      'twinY',
      'padiAow', // same day: PADI before SSI
      'ssiDeep', // then title A to Z
      'ssiNitrox',
      'ssiOw',
      'undatedB', // undated sort as oldest, then by title
      'undatedA',
    ];

    test('date newest first: same day by agency then title', () {
      expect(
        order(
          shuffled,
          CertificationSortField.dateIssued,
          SortDirection.descending,
        ),
        dateReadingOrder,
      );
    });

    test('date oldest first reverses the whole chain', () {
      expect(
        order(
          shuffled,
          CertificationSortField.dateIssued,
          SortDirection.ascending,
        ),
        dateReadingOrder.reversed.toList(),
      );
    });

    test('agency A to Z: newest first then title', () {
      expect(
        order(
          shuffled,
          CertificationSortField.agency,
          SortDirection.descending,
        ),
        [
          'twinX',
          'twinY',
          'padiAow',
          'ssiDeep',
          'ssiNitrox',
          'ssiOw',
          'undatedB',
          'undatedA',
        ],
      );
    });

    test('agency Z to A reverses the whole chain', () {
      expect(
        order(shuffled, CertificationSortField.agency, SortDirection.ascending),
        [
          'undatedA',
          'undatedB',
          'ssiOw',
          'ssiNitrox',
          'ssiDeep',
          'padiAow',
          'twinY',
          'twinX',
        ],
      );
    });

    test('title A to Z: agency then newest first', () {
      final certs = [
        cert('ssi2020', name: 'Nitrox', agency: ssi, issueDate: DateTime(2020)),
        cert('padi2019', name: 'Nitrox', issueDate: DateTime(2019)),
        cert('ssi2021', name: 'Nitrox', agency: ssi, issueDate: DateTime(2021)),
      ];
      expect(
        order(certs, CertificationSortField.name, SortDirection.descending),
        ['padi2019', 'ssi2021', 'ssi2020'],
      );
    });

    // A slug-like agency id the catalog does not know falls back to its
    // slug as the name, and ties between such agencies order by that name.
    test('unknown agencies on one day order by their fallback names', () {
      Certification unknown(String id, String agency) => Certification(
        id: id,
        name: 'Nitrox',
        agency: agency,
        issueDate: day,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(
        order(
          // Ids run against the agency names, so only the agency key can
          // put acmeDiving first.
          [unknown('a', 'blueReef'), unknown('b', 'acmeDiving')],
          CertificationSortField.dateIssued,
          SortDirection.descending,
        ),
        ['b', 'a'],
      );
    });

    test('identical rows order by id whatever the input order', () {
      for (final field in CertificationSortField.values) {
        expect(order([twinY, twinX], field, SortDirection.descending), [
          'twinX',
          'twinY',
        ], reason: field.name);
      }
    });
  });
}
