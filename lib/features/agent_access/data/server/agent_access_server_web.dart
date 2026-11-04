import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/features/agent_access/data/server/agent_access_status.dart';
import 'package:submersion/features/agent_access/data/server/agent_server_spec.dart';

/// Browser variant of the MCP listener: a page cannot bind a port, so
/// [start] throws and the status stays "not listening".
class AgentAccessServer {
  AgentAccessServer._();

  static final AgentAccessServer instance = AgentAccessServer._();

  static const host = '127.0.0.1';
  static const path = '/mcp';

  AgentAccessStatus _status = const AgentAccessStatus(
    listening: false,
    port: 0,
  );
  final _statusController = StreamController<AgentAccessStatus>.broadcast();

  AgentAccessStatus get status => _status;
  Stream<AgentAccessStatus> get statusStream => _statusController.stream;

  /// Never bound in a browser.
  @visibleForTesting
  String? get boundHost => null;

  /// Throws [UnsupportedError]: agent access is native only.
  Future<void> start({
    required int port,
    required String Function() token,
    required AgentServerSpec Function() serverSpec,
  }) async => throw UnsupportedError('Agent access is native only');

  /// Nothing to stop; publishes the stopped status so watchers settle.
  Future<void> stop() {
    _publish(AgentAccessStatus(listening: false, port: _status.port));
    return Future.value();
  }

  /// Records why the server is not running.
  void publishError(String message) => _publish(
    AgentAccessStatus(listening: false, port: _status.port, error: message),
  );

  void _publish(AgentAccessStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }
}
