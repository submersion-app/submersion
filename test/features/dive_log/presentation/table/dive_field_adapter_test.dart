import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';

void main() {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 4, 1),
    maxDepth: 23.4,
  );

  test('surface interval reads the computed map', () {
    final adapter = DiveFieldAdapter(
      surfaceIntervals: const {'d1': Duration(minutes: 75)},
    );
    expect(
      adapter.extractValue(DiveField.surfaceInterval, dive),
      const Duration(minutes: 75),
    );
  });

  test('a dive missing from the map shows its stored interval', () {
    final stored = dive.copyWith(surfaceInterval: const Duration(minutes: 9));
    expect(
      DiveFieldAdapter().extractValue(DiveField.surfaceInterval, stored),
      const Duration(minutes: 9),
    );
  });

  test('other fields delegate to extractFromDive', () {
    expect(DiveFieldAdapter().extractValue(DiveField.maxDepth, dive), 23.4);
  });

  test('table config converts without changing columns, widths or sort', () {
    final config = TableViewConfig(
      columns: [
        TableColumnConfig(
          field: DiveField.diveNumber,
          isPinned: true,
          width: 70,
        ),
        TableColumnConfig(field: DiveField.maxDepth, width: 91),
      ],
      sortField: DiveField.maxDepth,
      sortAscending: false,
    );
    expect(config.toEntityConfig().toJson(), config.toJson());
  });
}
