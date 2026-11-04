import 'package:flutter/material.dart';

import 'package:submersion/features/transfer/presentation/widgets/computers_section_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Transfer's Dive Computers section on a page of its own, which the Dive
/// Computers nav shortcut opens (#4210).
///
/// The alias route has no parent, so the app bar shows no back arrow, as on
/// every other shortcut page. The section keeps its passive auto-connect
/// scan: it subscribes to the router-wide observer, which sees this route
/// as it sees Transfer's.
class TransferComputersPage extends StatelessWidget {
  const TransferComputersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transfer_section_computersTitle)),
      body: const ComputersSectionContent(),
    );
  }
}
