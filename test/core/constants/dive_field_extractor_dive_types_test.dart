import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations de;

  setUpAll(() {
    de = lookupAppLocalizations(const Locale('de'));
  });

  Dive diveWith(List<String> ids) =>
      Dive(id: 'd', dateTime: DateTime(2026, 1, 1), diveTypeIds: ids);

  DiveSummary summaryWith(List<String> ids) => DiveSummary(
    id: 'd',
    dateTime: DateTime(2026, 1, 1),
    sortTimestamp: 0,
    diveTypeIds: ids,
  );

  group('without a resolver (locale-independent consumers)', () {
    // This is the export contract: CSV/Excel/UDDF and anything else wanting a
    // stable value must keep the English slug capitalization.
    test('extractFromDive joins all dive-type names', () {
      expect(
        DiveField.diveTypeName.extractFromDive(diveWith(['shore', 'wreck'])),
        'Shore, Wreck',
      );
    });

    test('extractFromSummary joins all dive-type names', () {
      expect(
        DiveField.diveTypeName.extractFromSummary(
          summaryWith(['night', 'deep_wreck']),
        ),
        'Night, Deep wreck',
      );
    });
  });

  group('with a resolver (on-screen consumers, issue #643)', () {
    String label(String id) => diveTypeLabel(de, id);

    test('extractFromDive localizes every built-in slug', () {
      final value = DiveField.diveTypeName.extractFromDive(
        diveWith(['shore', 'wreck']),
        diveTypeLabel: label,
      );
      expect(value, isNot('Shore, Wreck'));
      expect(
        value,
        '${diveTypeLabel(de, 'shore')}, ${diveTypeLabel(de, 'wreck')}',
      );
    });

    test(
      'extractFromSummary localizes and keeps the unknown-slug fallback',
      () {
        final value = DiveField.diveTypeName.extractFromSummary(
          summaryWith(['night', 'deep_wreck']),
          diveTypeLabel: label,
        );
        // 'night' is built in and translates; 'deep_wreck' is not, so it keeps
        // the slug capitalization on both paths.
        expect(value, '${diveTypeLabel(de, 'night')}, Deep wreck');
        expect(value, isNot(startsWith('Night')));
      },
    );

    test('a custom type on a built-in slug keeps the diver label', () {
      final byId = {
        'wreck': DiveTypeEntity(
          id: 'wreck',
          diverId: 'diver-1',
          name: 'Hausriff-Wrack',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      };
      final value = DiveField.diveTypeName.extractFromDive(
        diveWith(['wreck']),
        diveTypeLabel: (id) => diveTypeLabel(de, id, typesById: byId),
      );
      expect(value, 'Hausriff-Wrack');
    });

    test('the resolver is not applied to unrelated fields', () {
      // Guards the threading: only diveTypeName consults the resolver.
      final dive = Dive(
        id: 'd',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['wreck'],
        maxDepth: 30,
      );
      expect(
        DiveField.maxDepth.extractFromDive(dive, diveTypeLabel: label),
        30,
      );
    });
  });
}
