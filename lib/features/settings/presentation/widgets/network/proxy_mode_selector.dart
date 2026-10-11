import 'package:flutter/material.dart';

import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three proxy modes as radio tiles. A choice applies at once.
class ProxyModeSelector extends StatelessWidget {
  const ProxyModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ProxyMode mode;
  final ValueChanged<ProxyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      (
        ProxyMode.system,
        l10n.settings_network_mode_system,
        l10n.settings_network_mode_system_subtitle,
      ),
      (
        ProxyMode.manual,
        l10n.settings_network_mode_manual,
        l10n.settings_network_mode_manual_subtitle,
      ),
      (
        ProxyMode.none,
        l10n.settings_network_mode_none,
        l10n.settings_network_mode_none_subtitle,
      ),
    ];
    return RadioGroup<ProxyMode>(
      groupValue: mode,
      onChanged: (value) {
        if (value != null && value != mode) onChanged(value);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, title, subtitle) in options)
            RadioListTile<ProxyMode>(
              value: value,
              title: Text(title),
              subtitle: Text(subtitle),
            ),
        ],
      ),
    );
  }
}
