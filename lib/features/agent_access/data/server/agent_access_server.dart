import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mcp_dart/mcp_dart.dart';

import 'package:submersion/features/agent_access/data/server/request_authenticator.dart';

/// What the settings page shows about the server.
class AgentAccessStatus {
  const AgentAccessStatus({
    required this.listening,
    required this.port,
    this.error,
    this.portInUse = false,
    this.lastRequestAt,
  });

  final bool listening;
  final int port;

  /// Why the server is not listening, in English, for logs and as a last
  /// resort on the settings page.
  final String? error;

  /// True when [error] is a bind failure on [port], which the settings page
  /// can say in the diver's language.
  final bool portInUse;
  final DateTime? lastRequestAt;

  String get url => 'http://127.0.0.1:$port/mcp';

  AgentAccessStatus copyWith({
    bool? listening,
    int? port,
    String? error,
    bool? portInUse,
    DateTime? lastRequestAt,
  }) => AgentAccessStatus(
    listening: listening ?? this.listening,
    port: port ?? this.port,
    error: error ?? this.error,
    portInUse: portInUse ?? this.portInUse,
    lastRequestAt: lastRequestAt ?? this.lastRequestAt,
  );
}

/// The one MCP listener in the process.
///
/// A process-wide holder rather than a provider-owned object because a
/// provider's dispose cannot await the HTTP server closing, and `restartApp`
/// rebuilds the scope at once: [start] awaits any in-flight [stop] so the
/// new server never collides with the old one on the port.
class AgentAccessServer {
  AgentAccessServer._();

  static final AgentAccessServer instance = AgentAccessServer._();

  static const host = '127.0.0.1';
  static const path = '/mcp';

  StreamableMcpServer? _server;
  Future<void>? _pendingStop;
  AgentAccessStatus _status = const AgentAccessStatus(
    listening: false,
    port: 0,
  );
  final _statusController = StreamController<AgentAccessStatus>.broadcast();

  AgentAccessStatus get status => _status;
  Stream<AgentAccessStatus> get statusStream => _statusController.stream;

  /// The address the running listener was bound with, for tests.
  @visibleForTesting
  String? get boundHost => _server?.host;

  /// Binds [port] on loopback. Port 0 picks a free port (tests). A bind
  /// failure leaves the server stopped with [AgentAccessStatus.error] set
  /// and does not throw.
  Future<void> start({
    required int port,
    required String Function() token,
    required McpServer Function() serverFactory,
  }) async {
    final pending = _pendingStop;
    if (pending != null) await pending;
    if (_server != null) await stop();

    final effectivePort = port == 0 ? await _freePort() : port;
    final authenticator = RequestAuthenticator(token);
    final server = StreamableMcpServer(
      serverFactory: (_) => serverFactory(),
      host: host,
      port: effectivePort,
      path: path,
      // Typed dynamic because the package's non-IO stub declares it so; on
      // desktop it is always a dart:io HttpRequest.
      authenticationHandler: (dynamic request) {
        final header = (request as HttpRequest).headers.value(
          HttpHeaders.authorizationHeader,
        );
        if (!authenticator.accepts(header)) {
          return const StreamableMcpAuthenticationResult.unauthorized(
            errorDescription: 'Missing or invalid bearer token.',
          );
        }
        // Only an accepted request counts as "the agent got through".
        _touch();
        return const StreamableMcpAuthenticationResult.allow();
      },
      enableDnsRebindingProtection: true,
      allowedHosts: const {'localhost', '127.0.0.1', '::1'},
      allowedOrigins: {
        'http://localhost:$effectivePort',
        'http://127.0.0.1:$effectivePort',
        'http://[::1]:$effectivePort',
      },
      enableJsonResponse: true,
    );
    try {
      await server.start();
    } on SocketException catch (e) {
      unawaited(server.stop().catchError((_) {}));
      _publish(
        AgentAccessStatus(
          listening: false,
          port: effectivePort,
          error: 'Port $effectivePort is already in use (${e.message}).',
          portInUse: true,
        ),
      );
      return;
    } catch (_) {
      // Anything else is reported by the caller; release what was bound so
      // the next start on this port does not collide with a ghost listener.
      unawaited(server.stop().catchError((_) {}));
      rethrow;
    }
    _server = server;
    _publish(AgentAccessStatus(listening: true, port: server.boundPort));
  }

  Future<void> stop() {
    final pending = _pendingStop;
    if (pending != null) return pending;
    final server = _server;
    if (server == null) {
      _publish(AgentAccessStatus(listening: false, port: _status.port));
      return Future.value();
    }
    _server = null;
    final stopping = _pendingStop = server.stop().whenComplete(() {
      _pendingStop = null;
      _publish(AgentAccessStatus(listening: false, port: _status.port));
    });
    return stopping;
  }

  /// Records why the server is not running when the failure happened
  /// outside [start] (reading the token, resolving the app version).
  void publishError(String message) => _publish(
    AgentAccessStatus(listening: false, port: _status.port, error: message),
  );

  /// Records an accepted request. The settings page watches the stream, so
  /// a busy agent must not rebuild it on every call: the time is always
  /// updated, but listeners hear about it at most once a second.
  void _touch() {
    final now = DateTime.now();
    final previous = _status.lastRequestAt;
    final next = _status.copyWith(lastRequestAt: now);
    if (previous != null && now.difference(previous) < _touchInterval) {
      _status = next;
      return;
    }
    _publish(next);
  }

  static const _touchInterval = Duration(seconds: 1);

  void _publish(AgentAccessStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  static Future<int> _freePort() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    return port;
  }
}
