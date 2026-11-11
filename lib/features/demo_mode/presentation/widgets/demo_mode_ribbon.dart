import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An amber "DEMO" ribbon across the top-end corner of every screen while
/// the sample logbook is open (issue #4428). Nothing at all when demo mode is
/// off.
///
/// It replaces the full-width strip of issue #3708, which pushed every page
/// down by a row. The ribbon is painted over [child] instead, so it takes no
/// layout space, and taps pass through it to whatever sits under the corner.
/// Exiting demo mode lives under Settings > Data > Advanced.
class DemoModeRibbon extends ConsumerWidget {
  const DemoModeRibbon({super.key, required this.child});

  final Widget child;

  /// The square the ribbon is drawn in. [Banner]'s band crosses each edge
  /// from about 56.6 to 68.6 px out of the corner, and its ends overhang the
  /// edges by about 6 px; the clip trims that overhang the way a window edge
  /// does.
  static const double _extent = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(demoModeActiveProvider);
    final l10n = context.l10n;
    // The Stack is there whether or not the ribbon is, so turning demo mode
    // on or off keeps [child] where it is in the tree instead of remounting
    // the whole app under a new parent.
    return Stack(
      // The app below gets the very constraints it would without the ribbon.
      fit: StackFit.passthrough,
      children: [
        child,
        if (active)
          PositionedDirectional(
            // Below the phone status bar rather than over its icons.
            top: MediaQuery.paddingOf(context).top,
            end: 0,
            child: Semantics(
              container: true,
              label: l10n.demo_ribbon_semanticsLabel,
              child: IgnorePointer(
                child: ClipRect(
                  child: Banner(
                    message: l10n.demo_ribbon_label,
                    location: BannerLocation.topEnd,
                    color: AppColors.warning,
                    textStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 10.2,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    child: const SizedBox.square(dimension: _extent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
