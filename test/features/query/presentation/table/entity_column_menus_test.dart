import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/presentation/table/entity_column_menus.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Header and cell filter menus for an entity with no menus of its own
/// (#3422): sites and dive centers in the table editor.
void main() {
  final l10n = AppLocalizationsEn();

  test('header menu offers empty and set for the coordinates field', () {
    QueryNode? applied;
    final items = entityColumnHeaderMenuItems(
      l10n: l10n,
      root: siteQueryEntity,
      fieldKey: 'coordinates',
      columnLabel: 'Latitude',
      query: null,
      onChanged: (q) => applied = q,
    );

    expect(items.map((i) => i.label), [
      l10n.tableMode_cell_noValue('Latitude'),
      l10n.tableMode_cell_anyValue('Latitude'),
      l10n.tableMode_menu_resetFilter,
    ]);
    expect(items.last.enabled, isFalse);

    items.first.onSelected();
    expect(
      applied,
      ConditionNode(FieldPath(const ['coordinates']), QueryOp.isEmpty, null),
    );
  });

  test('reset is enabled when the column is filtered and clears its rules', () {
    final rule = ConditionNode(
      FieldPath(const ['coordinates']),
      QueryOp.isEmpty,
      null,
    );
    QueryNode? applied = rule;
    final items = entityColumnHeaderMenuItems(
      l10n: l10n,
      root: siteQueryEntity,
      fieldKey: 'coordinates',
      columnLabel: 'Latitude',
      query: rule,
      onChanged: (q) => applied = q,
    );

    expect(items.last.enabled, isTrue);
    items.last.onSelected();
    expect(applied, isNull);
  });

  test('an unknown field key has no menu', () {
    expect(
      entityColumnHeaderMenuItems(
        l10n: l10n,
        root: siteQueryEntity,
        fieldKey: 'nope',
        columnLabel: 'x',
        query: null,
        onChanged: (_) {},
      ),
      isEmpty,
    );
  });

  test('cell menu offers Only and Exclude for a text field with eq', () {
    QueryNode? applied;
    final items = entityColumnCellMenuItems(
      l10n: l10n,
      root: siteQueryEntity,
      fieldKey: 'country',
      value: 'Mexico',
      valueLabel: 'Mexico',
      query: null,
      onChanged: (q) => applied = q,
    );

    expect(items.map((i) => i.label), [
      l10n.tableMode_cell_only('Mexico'),
      l10n.tableMode_cell_exclude('Mexico'),
    ]);
    items.first.onSelected();
    expect(
      applied,
      ConditionNode(
        FieldPath(const ['country']),
        QueryOp.eq,
        const StringValue('Mexico'),
      ),
    );
    items.last.onSelected();
    expect((applied! as ConditionNode).op, QueryOp.neq);
  });

  test('cell menu offers nothing for a null value', () {
    expect(
      entityColumnCellMenuItems(
        l10n: l10n,
        root: siteQueryEntity,
        fieldKey: 'country',
        value: null,
        valueLabel: '',
        query: null,
        onChanged: (_) {},
      ),
      isEmpty,
    );
  });

  test('a bool field gets a BoolValue', () {
    QueryNode? applied;
    entityColumnCellMenuItems(
      l10n: l10n,
      root: siteQueryEntity,
      fieldKey: 'coordinates',
      value: true,
      valueLabel: 'Yes',
      query: null,
      onChanged: (q) => applied = q,
    ).first.onSelected();

    expect((applied! as ConditionNode).value, const BoolValue(true));
  });
}
