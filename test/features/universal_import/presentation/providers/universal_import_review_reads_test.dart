import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/existing_import_records.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Preparing the review reads what the file needs compared and nothing else
/// (issue #3855), counted in the SQL that reaches the database.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// Statements reading [table], however they spell it: drift's whole-row
  /// `FROM "table"`, its column list `"table"."id"`, or plain custom SQL.
  Iterable<String> reading(List<String> statements, String table) {
    final read = RegExp('FROM "?$table"?\\b|"$table"\\.');
    return statements.where(read.hasMatch);
  }

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    // Open it here, or the migrations land in the statements under test.
    await db.customSelect('SELECT 1').get();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  group('installing a payload', () {
    test('reads nothing: the wizard runs the check itself', () async {
      final notifier = container.read(universalImportNotifierProvider.notifier);

      final statements = await statementsOf(() async {
        await notifier.setExternalPayload(
          ImportPayload(
            entities: {
              ImportEntityType.dives: [
                {'dateTime': DateTime.utc(2024), 'sourceUuid': 'uuid-1'},
              ],
              ImportEntityType.sites: const [
                {'name': 'Blue Hole'},
              ],
              ImportEntityType.certifications: const [
                {'name': 'Open Water'},
              ],
            },
          ),
        );
        // What the capture must see, so an empty one cannot pass this test.
        await db.customSelect('SELECT 1 AS capture_works').get();
      });

      expect(
        statements.where((s) => s.contains('capture_works')),
        hasLength(1),
      );
      expect(statements, hasLength(1));
    });
  });

  group('the records a review compares', () {
    Future<List<String>> statementsFor(ImportPayload payload) => statementsOf(
      () => loadActiveDiverRecords(container, payload, 'diver-1'),
    );

    test('a file of sites and tags reads no dive or certification', () async {
      final statements = await statementsFor(
        const ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {'name': 'Blue Hole'},
            ],
            ImportEntityType.tags: [
              {'name': 'Night'},
            ],
          },
        ),
      );

      // What the file does need, so an empty capture cannot pass the rest.
      expect(reading(statements, 'dive_sites'), isNotEmpty);
      expect(reading(statements, 'tags'), isNotEmpty);

      expect(reading(statements, 'dives'), isEmpty);
      expect(reading(statements, 'dive_data_sources'), isEmpty);
      expect(reading(statements, 'certifications'), isEmpty);
      expect(reading(statements, 'dive_tanks'), isEmpty);
    });

    test('a file of dives reads the logbook once, unhydrated', () async {
      final statements = await statementsFor(
        ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'dateTime': DateTime.utc(2024), 'maxDepth': 20.0},
            ],
          },
        ),
      );

      expect(statements, hasLength(1));
      expect(reading(statements, 'dives'), hasLength(1));
    });

    test('dives with a source id read the source keys too', () async {
      final statements = await statementsFor(
        ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'dateTime': DateTime.utc(2024), 'sourceUuid': 'uuid-1'},
            ],
          },
        ),
      );

      expect(reading(statements, 'dive_data_sources'), hasLength(1));
    });
  });
}
