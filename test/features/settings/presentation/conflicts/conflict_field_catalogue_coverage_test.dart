import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';

import '../../../../helpers/test_database.dart';

/// Every column of every synced table must have a label and a value kind in
/// the conflict catalogue, or the Resolve Conflicts dialog shows a raw column
/// name to the diver (#694). Driven off the live Drift schema, so a new synced
/// column fails here until it is catalogued.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  for (final entity in SyncService.entityHasUpdatedAt.keys) {
    test('every $entity column has a conflict label', () {
      final table = SyncDataSerializer().syncTableFor(entity);
      final missing = [
        for (final column in table.$columns)
          if (!isConflictFieldCovered(entity, _camelCase(column.name)))
            '${_camelCase(column.name)} (${column.type})',
      ];
      expect(
        missing,
        isEmpty,
        reason:
            '$entity has columns with no conflict catalogue entry. Add '
            'each to lib/features/settings/presentation/conflicts/'
            'catalogue/ with a label and a FieldKind.',
      );
    });
  }
}

/// Drift's SQL name back to the JSON key `toJson` uses. No synced column
/// uses `.named(...)`, so the getter is always the camelCase of the SQL name.
String _camelCase(String columnName) {
  final parts = columnName.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
