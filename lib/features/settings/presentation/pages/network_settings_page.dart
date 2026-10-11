import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_manual_form.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_mode_selector.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_status_line.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_test_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Network: how the app's own internet traffic reaches the
/// network (#3217). No Scaffold: SettingsSectionDetailPage and the desktop
/// pane supply the app bar.
class NetworkSettingsPage extends ConsumerStatefulWidget {
  const NetworkSettingsPage({super.key});

  @override
  ConsumerState<NetworkSettingsPage> createState() =>
      _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends ConsumerState<NetworkSettingsPage> {
  static const _log = LoggerService('ProxySettings');

  @override
  void initState() {
    super.initState();
    // The OS proxy can change while the app runs (a new Wi-Fi network, a
    // VPN); opening the page asks again so the status line is current.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(proxyControllerProvider);
      if (controller.state.settings.mode == ProxyMode.system) {
        unawaited(controller.refresh());
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.forms_discard_title),
        content: Text(l10n.forms_discard_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.forms_discard_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.forms_discard_discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  /// Applies a mode at once; a failed write keeps the old mode and says so,
  /// as the manual form's Save does.
  Future<void> _changeMode(
    ProxyController controller,
    ProxySettings settings,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.settings_network_manual_saveFailed;
    try {
      await controller.saveSettings(settings);
    } catch (e, st) {
      _log.error('Could not save the proxy mode', error: e, stackTrace: st);
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = ref.watch(proxyControllerProvider);
    final state = ref.watch(proxyStateProvider).valueOrNull ?? controller.state;
    final draft = ref.watch(networkProxyDraftProvider);
    final mode = state.settings.mode;

    return PopScope(
      // The draft only matters while its form is on screen.
      canPop: draft == null || mode != ProxyMode.manual,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !context.mounted) return;
        ref.read(networkProxyDraftProvider.notifier).clear();
        Navigator.of(context).pop();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.settings_network_mode_header,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ProxyModeSelector(
            mode: mode,
            onChanged: (value) => unawaited(
              _changeMode(controller, state.settings.copyWith(mode: value)),
            ),
          ),
          const Divider(),
          if (mode == ProxyMode.system)
            ProxyStatusLine(
              state: state,
              onRefresh: () => unawaited(controller.refresh()),
            ),
          if (mode == ProxyMode.manual) ProxyManualForm(controller: controller),
          ProxyTestSection(controller: controller),
        ],
      ),
    );
  }
}
