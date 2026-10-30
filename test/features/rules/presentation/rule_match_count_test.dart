import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';

import '../rules_fixture.dart';

/// Notes each count it is asked for.
class _CountingScope extends RuleTargetScope {
  _CountingScope(this.calls);

  final List<String> calls;

  @override
  Future<int> countMatches(
    QueryNode? condition,
    RuleSubject s,
    String diverId,
  ) async {
    calls.add(condition == null ? 'every' : 'condition');
    return 0;
  }
}

void main() {
  test('the live count waits for the condition to settle', () {
    // Each keystroke that parses is a new condition: only the one the diver
    // stops on is counted, not one query per keystroke.
    fakeAsync((async) {
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          ruleTargetScopeProvider.overrideWithValue(_CountingScope(calls)),
        ],
      );
      final typing = container.listen(
        ruleMatchCountProvider((
          subject: RuleSubject.dives,
          conditionJson: encodeRuleCondition(depthOver(30)),
        )),
        (_, _) {},
      );
      async.elapse(const Duration(milliseconds: 100));
      typing.close();
      final settled = container.listen(
        ruleMatchCountProvider((subject: RuleSubject.dives, conditionJson: '')),
        (_, _) {},
      );
      async.elapse(const Duration(milliseconds: 400));
      expect(calls, ['every']);
      settled.close();
      container.dispose();
    });
  });
}
