import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_message_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why a search for a saved computer by make and model could not run.
enum DcSearchProblem {
  /// Bluetooth is off, or this device has none.
  bluetoothOff,

  /// The scan did not start for another reason, such as a denied
  /// permission.
  couldNotScan,
}

/// Terminal view for a saved Bluetooth computer that a scan for its make and
/// model did not find.
///
/// The Bluetooth address is a per-device identifier that never syncs, so a
/// computer saved on another device arrives here with its Bluetooth
/// connection and no address, and the download step looks for the one
/// nearby device of the saved model instead (issue #3710). When the scan saw
/// none, or more than one, nothing tells the saved computer apart, so the
/// view asks the diver to bring it closer and try again. When the scan could
/// not run at all, [problem] says why instead, in the diver's language
/// rather than the scanner's English error text.
class DcKnownComputerNotFoundView extends StatelessWidget {
  const DcKnownComputerNotFoundView({
    super.key,
    required this.computer,
    required this.onRetry,
    required this.onDone,
    this.problem,
  });

  final DiveComputer computer;

  /// Why the scan could not run, or null when it ran and found no single
  /// device of the saved model.
  final DcSearchProblem? problem;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = computer.displayName;
    final body = switch (problem) {
      null => l10n.importWizard_dc_notFoundNearbyBody(name),
      DcSearchProblem.bluetoothOff => l10n.importWizard_dc_bluetoothOffBody,
      DcSearchProblem.couldNotScan => l10n.importWizard_dc_couldNotScanBody,
    };

    return DcMessageLayout(
      icon: Icons.bluetooth_searching,
      title: l10n.importWizard_dc_notFoundNearby(name),
      body: body,
      bodyIsError: problem != null,
      actionIcon: Icons.refresh,
      actionLabel: l10n.importWizard_dc_tryAgain,
      onAction: onRetry,
      onDone: onDone,
    );
  }
}
