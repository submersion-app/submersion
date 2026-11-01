import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const metric = 'metric-diver';
  const feet = 'feet-diver';

  setUp(() async {
    db = await setUpTestDatabase();
    const t = 1700000000000;
    for (final (id, isDefault) in [(metric, true), (feet, false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              isDefault: Value(isDefault),
            ),
          );
    }
    await DiverSettingsRepository().createSettingsForDiver(
      feet,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
  });
  tearDown(tearDownTestDatabase);

  DiverContextLoader loader({String? active = metric}) => DiverContextLoader(
    db: () => db,
    divers: DiverRepository(),
    settings: DiverSettingsRepository(),
    localeTag: 'en',
    activeDiverId: () async => active,
  );

  group('DiverContextLoader.resolveDiverId', () {
    test('falls back to the active diver', () async {
      expect(await loader().resolveDiverId(null), metric);
    });

    test('falls back to the default diver when no diver is active', () async {
      expect(await loader(active: null).resolveDiverId(null), metric);
    });

    test('keeps a known explicit id', () async {
      expect(await loader().resolveDiverId(feet), feet);
    });

    test('rejects an unknown id with unknown_diver', () async {
      await expectLater(
        loader().resolveDiverId('nobody'),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.code,
            'code',
            AgentToolErrorCode.unknownDiver,
          ),
        ),
      );
    });
  });

  group('DiverContextLoader.load', () {
    test('builds prefs from the named divers settings', () async {
      final ctx = await loader().load(diverId: feet);
      expect(ctx.diverId, feet);
      expect(ctx.prefs.depth, DepthUnit.feet);
      expect(ctx.settings.depthUnit, DepthUnit.feet);
      expect(ctx.formatter.settings.depthUnit, DepthUnit.feet);
    });

    test('a diver without a settings row gets the defaults', () async {
      final ctx = await loader().load();
      expect(ctx.diverId, metric);
      expect(ctx.prefs.depth, DepthUnit.meters);
    });

    test('builds an empty name index when the diver has no names', () async {
      final ctx = await loader().load();
      expect(ctx.names.candidates(QuerySubject.sites, 'x'), isEmpty);
    });
  });
}
