import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// `/dive-computers/:computerId`, kept for deep links and old back stacks:
/// a dive computer's page is its Equipment item's (issue #3676), so this
/// replaces itself with that page. A builder rather than a route redirect,
/// because the lookup is async and the `download` child route under it must
/// still open the wizard.
class DiveComputerItemRedirect extends ConsumerStatefulWidget {
  const DiveComputerItemRedirect({super.key, required this.computerId});

  final String computerId;

  @override
  ConsumerState<DiveComputerItemRedirect> createState() =>
      _DiveComputerItemRedirectState();
}

class _DiveComputerItemRedirectState
    extends ConsumerState<DiveComputerItemRedirect> {
  /// Set once the forward is scheduled, so a rebuild never queues another.
  bool _forwarding = false;

  @override
  Widget build(BuildContext context) {
    final computer = ref.watch(diveComputerByIdProvider(widget.computerId));
    final itemId = computer.valueOrNull?.equipmentId;
    if (itemId != null && !_forwarding) {
      _forwarding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.replace('/equipment/$itemId');
      });
    }
    // A computer with no item yet (the heal gives it one on the next open),
    // or a lookup that failed, is as unreachable as a missing one: say so
    // rather than spin.
    final notFound = (computer.hasValue || computer.hasError) && itemId == null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diveComputer_title)),
      body: Center(
        child: notFound
            ? Text(context.l10n.diveComputer_error_notFound)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
