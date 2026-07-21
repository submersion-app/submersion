import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Follow-up coverage for issue #643. The first pass localized only the sites
/// that render a loaded DiveTypeEntity, leaving the id-only surfaces (dive
/// detail, and the Dive Type list/table column) in English. This resolver is
/// the shared path for all of them.
void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    de = lookupAppLocalizations(const Locale('de'));
  });

  DiveTypeEntity entity(String id, String name, {required bool isBuiltIn}) =>
      DiveTypeEntity(
        id: id,
        diverId: isBuiltIn ? null : 'diver-1',
        name: name,
        isBuiltIn: isBuiltIn,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  test('localizes a built-in slug with no entity map available', () {
    expect(diveTypeLabel(en, 'wreck'), 'Wreck');
    expect(diveTypeLabel(de, 'wreck'), isNot('Wreck'));
    expect(diveTypeLabel(de, 'wreck'), isNotEmpty);
  });

  test('a custom row occupying a built-in slug keeps the diver label', () {
    // Reachable because kSeedBuiltInDiveTypesSql uses INSERT OR IGNORE: on a
    // database that predates the v93 backfill, a diver-created 'wreck' row
    // suppresses the built-in seed for that slug and stays isBuiltIn = false.
    final byId = {'wreck': entity('wreck', 'Hausriff-Wrack', isBuiltIn: false)};
    expect(
      diveTypeLabel(de, 'wreck', typesById: byId),
      'Hausriff-Wrack',
      reason: 'the entity guard must win over the built-in translation',
    );
  });

  test('a genuine built-in entity still localizes', () {
    final byId = {'wreck': entity('wreck', 'Wreck', isBuiltIn: true)};
    expect(diveTypeLabel(de, 'wreck', typesById: byId), isNot('Wreck'));
  });

  test('an id with no entity and no built-in key falls back to the slug', () {
    expect(diveTypeLabel(de, 'deep_wreck'), 'Deep wreck');
  });

  test('an empty id keeps the legacy Recreational fallback', () {
    expect(diveTypeLabel(en, ''), 'Recreational');
  });

  test('diveTypeLabels joins in order', () {
    expect(diveTypeLabels(en, ['wreck', 'night']), 'Wreck, Night');
    expect(diveTypeLabels(en, const <String>[]), '');
  });
}
