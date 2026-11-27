import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';

/// Tells the profile pop-out which dive the main window shows (issue #5078).
///
/// Wraps the dive detail page wherever it appears: the dive list's detail
/// pane, or a dive opened from a trip, a site or search. A new dive, with no
/// id yet, leaves the last dive in place.
class ShownDiveReporter extends ConsumerStatefulWidget {
  const ShownDiveReporter({
    super.key,
    required this.diveId,
    required this.child,
  });

  final String diveId;
  final Widget child;

  @override
  ConsumerState<ShownDiveReporter> createState() => _ShownDiveReporterState();
}

class _ShownDiveReporterState extends ConsumerState<ShownDiveReporter> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(ShownDiveReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diveId != widget.diveId) _report();
  }

  /// After the frame: a provider must not change while widgets build.
  void _report() {
    final id = widget.diveId;
    if (id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mainWindowDiveIdProvider.notifier).state = id;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
