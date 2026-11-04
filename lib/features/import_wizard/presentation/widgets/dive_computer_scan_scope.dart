import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Stops the dive computer scan as a dive computer import closes.
///
/// The scan runs on through the connect, past the steps that start it,
/// because Android connects only while it runs (issue #3369), so none of
/// those steps can stop it as they go (issue #4088). Only a manual flow's
/// scan stops here: the auto-connect scan the Dive Computers section may
/// already have restarted underneath keeps running (issue #3361).
class DiveComputerScanScope extends ConsumerStatefulWidget {
  const DiveComputerScanScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DiveComputerScanScope> createState() =>
      _DiveComputerScanScopeState();
}

class _DiveComputerScanScopeState extends ConsumerState<DiveComputerScanScope> {
  /// Cached because [ref] is unsafe in [dispose].
  late final DiscoveryNotifier _discovery;

  @override
  void initState() {
    super.initState();
    _discovery = ref.read(discoveryNotifierProvider.notifier);
  }

  @override
  void dispose() {
    logFailure(
      _discovery.stopScan(),
      DiveComputerScanScope,
      'stop the dive computer scan',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
