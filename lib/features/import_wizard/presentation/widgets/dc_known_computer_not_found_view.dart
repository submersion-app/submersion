import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Terminal view for a saved Bluetooth computer that a scan for its make and
/// model did not find.
///
/// The Bluetooth address is a per-device identifier that never syncs, so a
/// computer saved on another device arrives here with its Bluetooth
/// connection and no address, and the download step looks for the one
/// nearby device of the saved model instead (issue #3710). When the scan saw
/// none, or more than one, nothing tells the saved computer apart, so the
/// view asks the diver to bring it closer and try again. When the scan could
/// not run at all, [problem] says why instead.
class DcKnownComputerNotFoundView extends StatelessWidget {
  const DcKnownComputerNotFoundView({
    super.key,
    required this.computer,
    required this.onRetry,
    required this.onDone,
    this.problem,
  });

  final DiveComputer computer;

  /// Why the scan could not run (Bluetooth off, permission denied), or null
  /// when it ran and found no single device of the saved model.
  final String? problem;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final name = computer.displayName;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondaryContainer,
              ),
              child: Icon(
                Icons.bluetooth_searching,
                size: 64,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.importWizard_dc_notFoundNearby(name),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              problem ?? l10n.importWizard_dc_notFoundNearbyBody(name),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: problem == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.importWizard_dc_tryAgain),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDone,
              child: Text(l10n.universalImport_action_done),
            ),
          ],
        ),
      ),
    );
  }
}
