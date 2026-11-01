import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

Matcher _throwsCode(AgentToolErrorCode code) =>
    throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

void main() {
  setUp(setUpTestDatabase);
  tearDown(() async {
    if (DatabaseService.instance.databaseOrNull != null) {
      await tearDownTestDatabase();
    }
    applyGlobalTestDefaults();
  });

  group('AgentToolGate', () {
    test('gate refuses while demo mode is active', () {
      DemoModeGate.instance.debugActive = true;
      final gate = AgentToolGate(isLocked: () => false);
      expect(gate.open, _throwsCode(AgentToolErrorCode.demoMode));
    });

    test('gate refuses while the app is locked', () {
      final gate = AgentToolGate(isLocked: () => true);
      expect(gate.open, _throwsCode(AgentToolErrorCode.appLocked));
    });

    test('demo mode wins over the app lock', () {
      DemoModeGate.instance.debugActive = true;
      final gate = AgentToolGate(isLocked: () => true);
      expect(gate.open, _throwsCode(AgentToolErrorCode.demoMode));
    });

    test(
      'gate returns database_unavailable while databaseOrNull is null',
      () async {
        await tearDownTestDatabase();
        expect(DatabaseService.instance.databaseOrNull, isNull);
        final gate = AgentToolGate(isLocked: () => false);
        expect(gate.open, _throwsCode(AgentToolErrorCode.databaseUnavailable));
      },
    );

    test('gate returns the live database otherwise', () {
      final gate = AgentToolGate(isLocked: () => false);
      expect(gate.open(), same(DatabaseService.instance.database));
    });
  });

  group('AgentToolException', () {
    test('toJson carries wire code and message', () {
      const e = AgentToolException(AgentToolErrorCode.tooManyIds, 'max 50');
      expect(e.toJson(), {
        'error': 'too_many_ids',
        'message': 'max 50',
        'details': null,
      });
    });

    test('every code has a snake_case wire name', () {
      final wire = AgentToolErrorCode.values.map((c) => c.wire).toList();
      expect(wire, [
        'demo_mode',
        'app_locked',
        'database_unavailable',
        'invalid_argument',
        'parse_error',
        'unknown_diver',
        'not_found',
        'too_many_ids',
        'internal',
      ]);
    });
  });
}
