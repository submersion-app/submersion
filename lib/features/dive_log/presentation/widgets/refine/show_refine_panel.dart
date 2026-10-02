import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Width of the Refine panel when it opens beside the list.
const kRefinePanelSideWidth = 440.0;

/// Opens the Refine panel for [filterProvider] (#2773): a bottom sheet on
/// narrow layouts, a right-side panel from the master-detail breakpoint up
/// so the list stays in view beside it.
Future<void> showRefinePanel(
  BuildContext context, {
  required StateProvider<DiveFilterState> filterProvider,
  VoidCallback? onApplied,
  @visibleForTesting Widget Function()? builder,
}) {
  // Shrinks above the soft keyboard so the pinned Show button stays usable
  // while a field has focus (bottom sheets do not pad for it themselves).
  Widget panel() => Builder(
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child:
          builder?.call() ??
          RefinePanel(filterProvider: filterProvider, onApplied: onApplied),
    ),
  );
  if (!ResponsiveBreakpoints.isMasterDetail(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: panel()),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        elevation: 8,
        child: SizedBox(
          width: kRefinePanelSideWidth,
          height: double.infinity,
          child: SafeArea(child: panel()),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      // Enters from the edge it rests on: the left in RTL.
      textDirection: Directionality.of(context),
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
