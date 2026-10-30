import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_message_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Terminal view for a download from a same-model stand-in that reported
/// another serial than the saved computer's.
///
/// With no address to tell units apart, the download step takes the one
/// nearby device of the saved make and model (issue #3710). When that turns
/// out to be another unit, such as a buddy's, its dives are not imported
/// into this log, and the view says which serial answered so the diver can
/// put the other computer away and download again.
class DcAnotherUnitView extends StatelessWidget {
  const DcAnotherUnitView({
    super.key,
    required this.computer,
    required this.reportedSerial,
    required this.onDone,
  });

  final DiveComputer computer;
  final String reportedSerial;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = computer.displayName;
    return DcMessageLayout(
      icon: Icons.devices_other,
      title: l10n.importWizard_dc_anotherUnit(name),
      body: l10n.importWizard_dc_anotherUnitBody(
        name,
        computer.model ?? name,
        reportedSerial,
        computer.serialNumber ?? '',
      ),
      bodyIsError: true,
      onDone: onDone,
    );
  }
}
