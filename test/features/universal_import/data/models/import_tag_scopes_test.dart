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
