import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// The checks every tool call passes before it touches data.
///
/// Order matters: the demo logbook refuses first, then the app lock, then a
/// database that is swapped out by a restore or storage move. The database
/// handle is resolved per call and never cached.
class AgentToolGate {
  AgentToolGate({required bool Function() isLocked}) : _isLocked = isLocked;

  final bool Function() _isLocked;

  AppDatabase open() {
    try {
      DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.agentAccess);
    } on DemoModeSealedException {
      throw const AgentToolException(
        AgentToolErrorCode.demoMode,
        'The sample logbook is open. Leave demo mode to use agent tools.',
      );
    }
    if (_isLocked()) {
      throw const AgentToolException(
        AgentToolErrorCode.appLocked,
        'Submersion is locked. Unlock it to use agent tools.',
      );
    }
    final db = DatabaseService.instance.databaseOrNull;
    if (db == null) {
      throw const AgentToolException(
        AgentToolErrorCode.databaseUnavailable,
        'The logbook database is not available right now. Try again shortly.',
      );
    }
    return db;
  }
}
