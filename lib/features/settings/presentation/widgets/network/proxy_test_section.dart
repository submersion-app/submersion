import 'package:flutter/material.dart';

import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_manual_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Test connection: one request through the settings on screen, unsaved
/// manual edits included, then a plain-language result.
class ProxyTestSection extends ConsumerStatefulWidget {
  const ProxyTestSection({super.key, required this.controller});

  final ProxyController controller;

  @override
  ConsumerState<ProxyTestSection> createState() => _ProxyTestSectionState();
}

class _ProxyTestSectionState extends ConsumerState<ProxyTestSection> {
  var _running = false;
  ProxyTestOutcome? _outcome;
  ProxyMode? _testedMode;

  /// The snapshot for what the page shows: the saved settings, overlaid with
  /// the manual draft when the mode is manual.
  EffectiveProxy _snapshotUnderTest() {
    final state = widget.controller.state;
    final draft = ref.read(networkProxyDraftProvider);
    var settings = state.settings;
    var password = widget.controller.manualPassword;
    if (settings.mode == ProxyMode.manual && draft != null) {
      // Read the way Save reads it, so Test checks what Save would store.
      final parsed = parseProxyHostInput(draft.host);
      final port = readProxyPort(draft.port) ?? parsed.port;
      settings = settings.copyWith(
        type: draft.type,
        host: parsed.host,
        port: port,
        clearPort: port == null,
        username: draft.username,
      );
      password = draft.password;
    }
    return EffectiveProxy.resolve(
      settings: settings,
      system: state.system,
      password: password,
    );
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _outcome = null;
    });
    final mode = widget.controller.state.settings.mode;
    final outcome = await ref
        .read(proxyConnectionTesterProvider)
        .run(_snapshotUnderTest());
    if (!mounted) return;
    setState(() {
      _running = false;
      _outcome = outcome;
      _testedMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final outcome = _outcome;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(
              _running
                  ? l10n.settings_network_test_running
                  : l10n.settings_network_test_button,
            ),
          ),
          if (outcome != null) ...[
            const SizedBox(height: 12),
            Text(
              outcomeText(l10n, outcome, mode: _testedMode),
              style: TextStyle(
                color: outcome is ProxyTestSuccess
                    ? colorScheme.primary
                    : colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The message for a test [outcome]; [mode] picks the system-mode hint for a
/// rejected login, since there the user has no credentials field to fix.
String outcomeText(
  AppLocalizations l10n,
  ProxyTestOutcome outcome, {
  ProxyMode? mode,
}) => switch (outcome) {
  ProxyTestSuccess(:final elapsed, :final via) =>
    via.isDirect
        ? l10n.settings_network_test_successDirect(elapsed.inMilliseconds)
        : l10n.settings_network_test_successProxy(
            via.endpoint,
            via.kind == ProxyKind.socks5
                ? l10n.settings_network_manual_typeSocks
                : l10n.settings_network_manual_typeHttp,
            elapsed.inMilliseconds,
          ),
  ProxyTestUnreachable(:final endpoint) =>
    l10n.settings_network_test_unreachable(endpoint),
  ProxyTestAuthRejected() =>
    mode == ProxyMode.system
        ? l10n.settings_network_test_authRequiredSystem
        : l10n.settings_network_test_authRejected,
  ProxyTestTlsFailure() => l10n.settings_network_test_tls,
  ProxyTestTimeout() => l10n.settings_network_test_timeout,
  ProxyTestFailed(:final detail) => l10n.settings_network_test_failed(detail),
};
