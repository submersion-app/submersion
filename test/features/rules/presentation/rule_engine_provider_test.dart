import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
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
}
