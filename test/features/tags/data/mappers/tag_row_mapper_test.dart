import 'package:drift/drift.dart' show Expression, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;

/// The row mapper converts between the `tags` flag columns and a set of
/// scopes (issue #1942).
void main() {
  Tag row({required bool dives, required bool sites, bool equipment = false}) =>
      Tag(
        id: 't',
        name: 'T',
        createdAt: 0,
        updatedAt: 0,
        appliesToDives: dives,
        appliesToSites: sites,
        appliesToEquipment: equipment,
      );

  bool? flag(Map<String, Expression> columns, String column) =>
      (columns[column]! as Variable<bool>).value;

  test('reads each flag column into the set', () {
    expect(tagScopesOf(row(dives: true, sites: false)), {TagScope.dives});
    expect(tagScopesOf(row(dives: false, sites: true)), {TagScope.sites});
    expect(tagScopesOf(row(dives: true, sites: true)), {
      TagScope.dives,
      TagScope.sites,
    });
    expect(tagScopesOf(row(dives: false, sites: false)), isEmpty);
  });

  test('reads the equipment flag (v219)', () {
    expect(tagScopesOf(row(dives: false, sites: false, equipment: true)), {
      TagScope.equipment,
    });
    expect(
      tagScopesOf(row(dives: true, sites: true, equipment: true)),
      TagScope.values.toSet(),
    );
  });

  test('writes a value for every registry column', () {
    final columns = tagScopeColumns({TagScope.sites});
    expect(columns.keys, [for (final t in tagScopeTables) t.scopeColumn]);
    expect(flag(columns, 'applies_to_sites'), isTrue);
    expect(flag(columns, 'applies_to_dives'), isFalse);
    expect(flag(columns, 'applies_to_equipment'), isFalse);
  });

  test('columns and set round-trip for every combination of scopes', () {
    const scopes = TagScope.values;
    for (var mask = 0; mask < (1 << scopes.length); mask++) {
      final set = {
        for (var i = 0; i < scopes.length; i++)
          if ((mask & (1 << i)) != 0) scopes[i],
      };
      final columns = tagScopeColumns(set);
      final back = tagScopesOf(
        row(
          dives: flag(columns, 'applies_to_dives')!,
          sites: flag(columns, 'applies_to_sites')!,
          equipment: flag(columns, 'applies_to_equipment')!,
        ),
      );
      expect(back, set, reason: 'scope mask $mask');
    }
  });
}
