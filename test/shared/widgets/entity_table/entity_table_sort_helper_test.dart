import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import 'entity_table_test_harness.dart';

/// The table's row order as a pure function (#3422), so an editor can move
/// between cells in the order the diver sees.
void main() {
  const a = TestEntity('a', 'Charlie', 3);
  const b = TestEntity('b', 'Alpha', 1);
  const c = TestEntity('c', 'Bravo', 2);

  test('sorts by the config field in both directions and leaves an unsorted '
      'config alone', () {
    final adapter = TestAdapter();
    const units = UnitFormatter(AppSettings());
    List<String> ids(EntityTableViewConfig<TestField> config) => [
      for (final e in sortTableEntities([a, b, c], adapter, config, units))
        e.id,
    ];

    expect(ids(testTableConfig), ['a', 'b', 'c']);
    expect(ids(testTableConfig.copyWith(sortField: TestField.entityCount)), [
      'b',
      'c',
      'a',
    ]);
    expect(
      ids(
        testTableConfig.copyWith(
          sortField: TestField.entityName,
          sortAscending: false,
        ),
      ),
      ['a', 'c', 'b'],
    );
  });
}
