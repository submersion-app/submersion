import 'package:flutter/material.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the operating system reported, shown in System mode, with a button
/// to ask again.
class ProxyStatusLine extends StatelessWidget {
  const ProxyStatusLine({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final ProxyControllerState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final system = state.system;
    final isProblem = system is SystemProxyUnavailable && !state.detecting;
    return ListTile(
      leading: state.detecting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isProblem ? Icons.warning_amber_rounded : Icons.info_outline,
              color: isProblem ? colorScheme.error : colorScheme.primary,
            ),
      title: Text(
        statusText(l10n, state),
        style: isProblem ? TextStyle(color: colorScheme.error) : null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: l10n.settings_network_status_refresh,
        onPressed: state.detecting ? null : onRefresh,
      ),
    );
  }

  /// The line for [state]; public for the page's tests and reuse.
  static String statusText(AppLocalizations l10n, ProxyControllerState state) {
    final system = state.system;
    if (state.detecting && system == null) {
      return l10n.settings_network_status_detecting;
    }
    return switch (system) {
      null || SystemProxyNone() => l10n.settings_network_status_none,
      SystemProxyFixed(viaPac: true) => l10n.settings_network_status_fixedPac(
        state.effective.endpoint,
      ),
      SystemProxyFixed(type: ProxyType.socks5) =>
        l10n.settings_network_status_fixedSocks(state.effective.endpoint),
      SystemProxyFixed() => l10n.settings_network_status_fixed(
        state.effective.endpoint,
      ),
      SystemProxyUnavailable(:final reason) => switch (reason) {
        SystemProxyUnavailableReason.pacUnsupported =>
          l10n.settings_network_status_pacUnsupported,
        SystemProxyUnavailableReason.pacFailed =>
          l10n.settings_network_status_pacFailed,
        SystemProxyUnavailableReason.platformError =>
          l10n.settings_network_status_error,
      },
    };
  }
}
