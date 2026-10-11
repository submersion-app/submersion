import 'package:flutter/material.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import '../../../helpers/test_app.dart';

/// Shared fixtures for the EntityTableView interaction tests (#2984):
/// a two-field entity, its adapter and a table builder.
class TestEntity {
  final String id;
  final String name;
  final int count;

  const TestEntity(this.id, this.name, this.count);
}

class TestField implements EntityField {
  static const entityName = TestField._('entityName', 'Name', 'Name', false);
  static const entityCount = TestField._('entityCount', 'Count', 'Cnt', true);
  static const List<TestField> values = [entityName, entityCount];

  @override
  final String name;
  @override
  final String displayName;
  @override
  final String shortLabel;
  @override
  final bool isRightAligned;

  const TestField._(
    this.name,
    this.displayName,
    this.shortLabel,
    this.isRightAligned,
  );

  @override
  IconData? get icon => null;
  @override
  double get defaultWidth => 120;
  @override
  double get minWidth => 60;
  @override
  bool get sortable => true;
  @override
  String get categoryName => 'basic';

  @override
  String localizedDisplayName(AppLocalizations l10n) => displayName;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;

  @override
  bool operator ==(Object other) => other is TestField && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

class TestAdapter extends EntityFieldAdapter<TestEntity, TestField> {
  @override
  List<TestField> get allFields => TestField.values;

  @override
  Map<String, List<TestField>> get fieldsByCategory => {
    'basic': TestField.values,
  };

  @override
  dynamic extractValue(TestField field, TestEntity entity) =>
      field == TestField.entityName ? entity.name : entity.count;

  @override
  String formatValue(TestField field, dynamic value, UnitFormatter units) =>
      value == null ? '--' : value.toString();

  @override
  TestField fieldFromName(String name) =>
      TestField.values.firstWhere((f) => f.name == name);
}

final testTableConfig = EntityTableViewConfig<TestField>(
  columns: [
    EntityTableColumnConfig(field: TestField.entityName, isPinned: true),
    EntityTableColumnConfig(field: TestField.entityCount),
  ],
);

final testSingleColumnConfig = EntityTableViewConfig<TestField>(
  columns: [
    EntityTableColumnConfig(field: TestField.entityName, isPinned: true),
  ],
);

const _units = UnitFormatter(AppSettings());
final _adapter = TestAdapter();

Widget buildTestTable({
  required List<TestEntity> entities,
  EntityTableViewConfig<TestField>? config,
  void Function(String)? onEntityTap,
  void Function(TestField)? onSortFieldChanged,
  void Function(TestField, double)? onResizeColumn,
  void Function(TestField)? onHideColumn,
  EntityTableHeaderMenuBuilder<TestField>? headerMenuBuilder,
  EntityTableCellMenuBuilder<TestEntity, TestField>? cellMenuBuilder,
  bool Function(TestField)? isColumnFiltered,
  bool Function(TestEntity, TestField)? hasCellMenu,
  Locale? locale,
}) {
  return testApp(
    locale: locale,
    child: EntityTableView<TestEntity, TestField>(
      entities: entities,
      idExtractor: (e) => e.id,
      adapter: _adapter,
      config: config ?? testTableConfig,
      units: _units,
      onSortFieldChanged: onSortFieldChanged ?? (_) {},
      onResizeColumn: onResizeColumn ?? (_, _) {},
      onEntityTap: onEntityTap ?? (_) {},
      onHideColumn: onHideColumn,
      headerMenuBuilder: headerMenuBuilder,
      cellMenuBuilder: cellMenuBuilder,
      isColumnFiltered: isColumnFiltered,
      hasCellMenu: hasCellMenu,
    ),
  );
}
