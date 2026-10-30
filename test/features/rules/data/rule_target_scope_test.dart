import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  final scope = RuleTargetScope();

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'other']);
    await seedRuleDive(db, 'shallow', maxDepth: 12);
    await seedRuleDive(db, 'deep', maxDepth: 35);
    await seedRuleDive(db, 'plan', maxDepth: 40, planned: true);
    await seedRuleDive(db, 'theirs', diver: 'other', maxDepth: 45);
    await seedRuleSite(db, 'mine', country: 'Egypt');
    await seedRuleSite(db, 'lib', country: 'Egypt', libraryId: 'L');
    await seedRuleSite(
      db,
      'shared',
      owner: 'other',
      country: 'Egypt',
      shared: true,
    );
  });
  tearDown(tearDownTestDatabase);

  test('depth > 18 matches only my logged deep dive', () async {
    final all = {'shallow', 'deep', 'plan', 'theirs'};
    expect(await scope.matches(depthOver(18), RuleSubject.dives, 'me', all), {
      'deep',
    });
  });

  test('an empty condition matches every eligible target', () async {
    expect(await scope.allEligibleIds(RuleSubject.dives, 'me'), {
      'shallow',
      'deep',
    });
    expect(
      await scope.matches(null, RuleSubject.dives, 'me', {
        'shallow',
        'plan',
        'theirs',
      }),
      {'shallow'},
    );
  });

  test(
    'library sites and another profile\'s shared site never match',
    () async {
      final country = ConditionNode(
        FieldPath(['country']),
        QueryOp.eq,
        const StringValue('Egypt'),
      );
      expect(
        await scope.matches(country, RuleSubject.sites, 'me', {
          'mine',
          'lib',
          'shared',
        }),
        {'mine'},
      );
      expect(await scope.allEligibleIds(RuleSubject.sites, 'me'), {'mine'});
    },
  );

  test('1,200 target ids are matched in chunks', () async {
    final ids = <String>{};
    for (var i = 0; i < 1200; i++) {
      final id = 'bulk$i';
      ids.add(id);
      await seedRuleDive(db, id, maxDepth: i.isEven ? 30 : 10);
    }
    final hit = await scope.matches(
      depthOver(18),
      RuleSubject.dives,
      'me',
      ids,
    );
    expect(hit.length, 600);
    expect(kRuleIdChunk, 500);
  });

  test('countMatches counts the diver\'s eligible matches', () async {
    expect(await scope.countMatches(depthOver(18), RuleSubject.dives, 'me'), 1);
    expect(await scope.countMatches(null, RuleSubject.dives, 'me'), 2);
  });
}
