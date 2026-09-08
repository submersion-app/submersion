import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The action area of [UpdateBanner].
///
/// A packaged Linux install is upgraded by the system package manager, so this
/// shows the command rather than a download button: the app knows about the
/// release before the package manager has told the user, but it is not the
/// thing that should install it. Offering the tarball there would hand the user
/// an archive that shadows the packaged copy.
///
/// Takes the resolved [upgradeCommand] rather than an install method, because
/// the command depends on the host as well as the package format: see
/// resolveUpgradeCommand in domain/linux_upgrade_command.dart. A non-null
/// command means a package manager owns this install.
///
/// Split out of [UpdateBanner] so this behavior can be tested without
/// constructing UpdateStatusNotifier, whose constructor schedules a delayed
/// check that would leak a pending timer into every widget test.
class UpdateBannerActions extends StatelessWidget {
  const UpdateBannerActions({
    super.key,
    required this.upgradeCommand,
    required this.downloadUrl,
    required this.onDownload,
    required this.onDismiss,
  });

  /// The package-manager command that upgrades this install, or null when no
  /// package manager owns it.
  final String? upgradeCommand;
  final String? downloadUrl;
  final ValueChanged<String> onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final command = upgradeCommand;
    final url = downloadUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (command != null)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SelectableText(
                context.l10n.autoUpdate_banner_packageManagerHint(command),
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else if (url != null)
          TextButton(
            onPressed: () => onDownload(url),
            child: Text(context.l10n.autoUpdate_banner_download),
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: context.l10n.common_action_dismiss,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
