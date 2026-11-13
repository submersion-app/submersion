import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

/// A multi-diver import runs each profile's rules: their conditions must
/// resolve against that profile's names, not the active one's (#3513).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'other']);
    await seedRuleSite(db, 's9', owner: 'other', name: 'Other Reef');
    await seedRuleDive(db, 'o1', diver: 'other', siteId: 's9');
    await RuleRepository().create(
      diverId: 'other',
      subject: RuleSubject.dives,
      name: 'At Other Reef',
      triggers: const {RuleTrigger.afterImport},
      condition: ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s9', 'Other Reef'),
      ),
      actions: const [AppendDiveNotesAction('reef')],
    );
  });
  tearDown(tearDownTestDatabase);

  test('another profile\'s rule resolves against its own names', () async {
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        // The active profile's index knows nothing of the other's site.
        queryNameIndexProvider.overrideWith((ref) async => NameIndex(const [])),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(ruleEngineProvider)
        .run(
          const RuleRunRequest(
            diverId: 'other',
            trigger: RuleRunTrigger.imported,
            targets: {
              RuleSubject.dives: {'o1'},
            },
          ),
        );
    expect(result.skippedRuleNames, isEmpty);
    expect(result.changedTargetCount, 1);
  });

  test(
    'a serviceDue rule run straight after a schedule write sees it',
    () async {
      // A live filter's keeper holds the service writer, which follows its
      // inputs on change ticks; a rule run right after a write must not read
      // the verdicts from before it.
      final ms = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'mine',
              name: 'mine',
              type: 'regulator',
              diverId: const Value('me'),
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await seedRuleDive(db, 'm1');
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'm1', equipmentId: 'mine'),
          );
      await RuleRepository().create(
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Overdue gear',
        triggers: const {RuleTrigger.afterImport},
        condition: ConditionNode(
          FieldPath(['gear', 'serviceDue']),
          QueryOp.eq,
          const EnumValue('overdue'),
        ),
        actions: const [AppendDiveNotesAction('service the reg')],
      );
      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()).cast(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          queryNameIndexProvider.overrideWith(
            (ref) async => NameIndex(const []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final keeper = container.listen(
        equipmentServiceStatusCacheProvider,
        (_, _) {},
      );
      addTearDown(keeper.close);
      await container.read(equipmentServiceStatusCacheProvider.future);

      // The clock runs out now, with no wait for the change tick.
      await db
          .into(db.serviceSchedules)
          .insert(
            ServiceSchedulesCompanion.insert(
              id: 'sch-mine',
              equipmentId: 'mine',
              serviceKindId: 'regulator-service',
              intervalDays: const Value(30),
              anchorDate: Value(
                DateTime.now()
                    .subtract(const Duration(days: 400))
                    .millisecondsSinceEpoch,
              ),
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      final result = await container
          .read(ruleEngineProvider)
          .run(
            const RuleRunRequest(
              diverId: 'me',
              trigger: RuleRunTrigger.imported,
              targets: {
                RuleSubject.dives: {'m1'},
              },
            ),
          );
      expect(result.changedTargetCount, 1);
    },
  );

  test('another profile\'s serviceDue rule reads that profile\'s gear '
      'verdicts, not the active profile\'s cache (#4461)', () async {
    // The service cache holds the active profile's verdicts only; a
    // multi-diver import runs 'other''s rules against 'other''s gear.
    final ms = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'reg',
            type: 'regulator',
            diverId: const Value('other'),
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await db
        .into(db.serviceSchedules)
        .insert(
          ServiceSchedulesCompanion.insert(
            id: 'sch-reg',
            equipmentId: 'reg',
            serviceKindId: 'regulator-service',
            intervalDays: const Value(30),
            anchorDate: Value(
              DateTime.now()
                  .subtract(const Duration(days: 400))
                  .millisecondsSinceEpoch,
            ),
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await seedRuleDive(db, 'o2', diver: 'other');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'o2', equipmentId: 'reg'),
        );
    final dives = appQueryRegistry.entityFor(QuerySubject.dives);
    final overdue =
        (QueryParser(
                  appQueryRegistry,
                  dives,
                  ParseContext(
                    prefs: kMetricPrefs,
                    now: DateTime.now(),
                    names: const MapNameResolver({}),
                  ),
                ).parse('gear.serviceDue = overdue')
                as ParseOk)
            .node!;
    await RuleRepository().create(
      diverId: 'other',
      subject: RuleSubject.dives,
      name: 'Overdue gear',
      triggers: const {RuleTrigger.afterImport},
      condition: overdue,
      actions: const [AppendDiveNotesAction('service the reg')],
    );

    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex(const [])),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(ruleEngineProvider)
        .run(
          const RuleRunRequest(
            diverId: 'other',
            trigger: RuleRunTrigger.imported,
            targets: {
              RuleSubject.dives: {'o2'},
            },
          ),
        );
    expect(result.changedTargetCount, 1);
  });
}
