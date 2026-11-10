import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';

void main() {
  test('every tag scope has an import key', () {
    expect(importTagScopeKeys.keys.toSet(), TagScope.values.toSet());
  });

  test('a map that says nothing is a dive tag, as before scopes existed', () {
    expect(importedTagScopes(const {}), {TagScope.dives});
  });

  test('each flag the map sets is honoured', () {
    expect(
      importedTagScopes(const {
        'appliesToDives': false,
        'appliesToEquipment': true,
      }),
      {TagScope.equipment},
    );
    expect(importedTagScopes(const {'appliesToSites': true}), {
      TagScope.dives,
      TagScope.sites,
    });
  });

  group('a brand-new tag (#4407)', () {
    test('is offered everywhere when the map says nothing of scopes', () {
      expect(importedNewTagScopes(const {}), TagScope.everywhere);
      // A UDDF file that predates scopes parses every flag as null.
      expect(
        importedNewTagScopes(const {
          'appliesToDives': null,
          'appliesToSites': null,
        }),
        TagScope.everywhere,
      );
    });

    test('keeps the scopes a map states, as a backup restores them', () {
      expect(
        importedNewTagScopes(const {
          'appliesToDives': false,
          'appliesToSites': true,
        }),
        {TagScope.sites},
      );
    });

    test('is offered everywhere when the map only steers widening', () {
      const csvTag = {
        'appliesToDives': false,
        'appliesToEquipment': true,
        importTagNewEverywhereKey: true,
      };
      expect(importedNewTagScopes(csvTag), TagScope.everywhere);
      // An existing tag of the name is still widened to equipment alone.
      expect(importedTagScopes(csvTag), {TagScope.equipment});
    });
  });

  test('a map turning every scope off is read as a dive tag', () {
    expect(
      importedTagScopes(const {
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': false,
      }),
      {TagScope.dives},
    );
  });
}
