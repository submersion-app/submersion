import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #643: Settings / Manage / Dive Types listed the
/// built-in types in English under every locale, because the built-in names are
/// seeded into the database as English literals and were rendered raw.
void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    de = lookupAppLocalizations(const Locale('de'));
  });

  DiveTypeEntity builtIn(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// The slugs seeded by [kSeedBuiltInDiveTypesSql], read from the seed itself
  /// so adding a built-in type without a localization key fails this test.
  Set<String> seededBuiltInIds() {
    final matches = RegExp(
      r"SELECT\s+'([a-z_]+)'",
    ).allMatches(kSeedBuiltInDiveTypesSql);
    return {for (final m in matches) m.group(1)!};
  }

  test('seed exposes the expected built-in slugs', () {
    // Guards the regex above: if the seed's shape changes, the exhaustiveness
    // test below would silently pass on an empty set.
    expect(seededBuiltInIds(), hasLength(15));
    expect(seededBuiltInIds(), contains('recreational'));
  });

  test('every seeded built-in slug has a localized name', () {
    for (final id in seededBuiltInIds()) {
      expect(
        builtInDiveTypeName(en, id),
        isNotNull,
        reason: 'missing English localization for built-in dive type "$id"',
      );
      expect(
        builtInDiveTypeName(de, id),
        isNotNull,
        reason: 'missing German localization for built-in dive type "$id"',
      );
    }
  });

  test('German built-in names differ from the seeded English literals', () {
    // The actual bug: German users saw "Recreational", "Wreck", "Night".
    expect(builtInDiveTypeName(de, 'recreational'), isNot('Recreational'));
    expect(builtInDiveTypeName(de, 'wreck'), isNot('Wreck'));
    expect(builtInDiveTypeName(de, 'night'), isNot('Night'));
  });

  test('built-in entities resolve through the localization table', () {
    final type = builtIn('wreck', 'Wreck');
    expect(type.localizedName(en), 'Wreck');
    expect(type.localizedName(de), isNot('Wreck'));
    expect(type.localizedName(de), isNotEmpty);
  });

  test('custom types keep their stored name verbatim', () {
    final custom = DiveTypeEntity(
      id: 'muck',
      diverId: 'diver-1',
      name: 'Muck',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(custom.localizedName(en), 'Muck');
    expect(custom.localizedName(de), 'Muck');
  });

  test(
    'a custom type whose slug collides with a built-in is not translated',
    () {
      final custom = DiveTypeEntity(
        id: 'wreck',
        diverId: 'diver-1',
        name: 'Wreck (my label)',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(custom.localizedName(de), 'Wreck (my label)');
    },
  );

  test('an unknown built-in slug falls back to the stored name', () {
    final unknown = builtIn('sidemount', 'Sidemount');
    expect(unknown.localizedName(de), 'Sidemount');
    expect(builtInDiveTypeName(de, 'sidemount'), isNull);
  });
}
