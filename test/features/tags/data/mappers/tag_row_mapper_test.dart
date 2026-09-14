import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;

/// The row mapper converts between the `tags` flag columns and a set of
/// scopes (issue #1942).
void main() {
  Tag row({required bool dives, required bool sites}) => Tag(
    id: 't',
    name: 'T',
    createdAt: 0,
    updatedAt: 0,
    appliesToDives: dives,
    appliesToSites: sites,
  );

  test('reads each flag column into the set', () {
    expect(tagScopesOf(row(dives: true, sites: false)), {TagScope.dives});
    expect(tagScopesOf(row(dives: false, sites: true)), {TagScope.sites});
    expect(tagScopesOf(row(dives: true, sites: true)), {
      TagScope.dives,
      TagScope.sites,
    });
    expect(tagScopesOf(row(dives: false, sites: false)), isEmpty);
  });

  test('writes a value for every registry column', () {
    final columns = tagScopeColumns({TagScope.sites});
    expect(columns.keys, [for (final t in tagScopeTables) t.scopeColumn]);
    expect((columns['applies_to_sites']! as Variable<bool>).value, isTrue);
    expect((columns['applies_to_dives']! as Variable<bool>).value, isFalse);
  });
}
