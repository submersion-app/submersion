import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/providers/provider.dart';

/// The process-wide controller made in main() before the first request;
/// overridden there through rootProviderOverrides (#3217).
final proxyControllerProvider = Provider<ProxyController>(
  (ref) => throw UnimplementedError('ProxyController is created in main()'),
);

/// The controller's state, starting with its current value.
final proxyStateProvider = StreamProvider<ProxyControllerState>((ref) async* {
  final controller = ref.watch(proxyControllerProvider);
  yield controller.state;
  yield* controller.changes;
});

final proxyConnectionTesterProvider = Provider<ProxyConnectionTester>(
  (ref) => ProxyConnectionTester(),
);

/// Unsaved manual-proxy edits, as typed.
@immutable
class NetworkProxyDraft {
  const NetworkProxyDraft({
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final ProxyType type;
  final String host;
  final String port;
  final String username;
  final String password;

  NetworkProxyDraft copyWith({
    ProxyType? type,
    String? host,
    String? port,
    String? username,
    String? password,
  }) => NetworkProxyDraft(
    type: type ?? this.type,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
  );
}

/// Holds the draft outside the page so switching settings sections in the
/// desktop layout does not lose it; cleared on Save or a confirmed discard.
class NetworkProxyDraftNotifier extends StateNotifier<NetworkProxyDraft?> {
  NetworkProxyDraftNotifier() : super(null);

  void update(NetworkProxyDraft draft) => state = draft;
  void clear() => state = null;
}

final networkProxyDraftProvider =
    StateNotifierProvider<NetworkProxyDraftNotifier, NetworkProxyDraft?>(
      (ref) => NetworkProxyDraftNotifier(),
    );
