import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the buddy card swap screen (issue #3728) on top of the current page,
/// so Back returns there. Sealed in demo mode, like every way data leaves the
/// logbook.
///
/// Every entry point to the swap goes through here so they cannot drift.
void openBuddySwap(BuildContext context) {
  if (demoSealGuard(context, DemoSealedFeature.share)) {
    context.push('/buddies/swap');
  }
}

/// Whether this device can run the swap at all: a browser has none of the
/// radios it runs over (issue #4121). Every swap button asks this, so they
/// appear and disappear together.
bool _swapAvailable(WidgetRef ref) =>
    ref.watch(deviceCapabilitiesProvider).nearby;

/// Opens the buddy card swap screen from the Buddies list headers. Absent in
/// a browser, which has none of the radios the swap runs over (issue #4121).
class SwapWithBuddyButton extends ConsumerWidget {
  const SwapWithBuddyButton({super.key, this.iconSize});

  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_swapAvailable(ref)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(Icons.swap_horiz, size: iconSize),
      tooltip: context.l10n.buddySwap_title,
      onPressed: () => openBuddySwap(context),
    );
  }
}

/// A labelled "Swap with a buddy" button for Quick Actions lists: the home
/// page card and the Buddies summary pane (issue #4591).
///
/// [padding] sits around the button and disappears with it, so a list that
/// spaces its buttons through it leaves no gap in a browser, where the
/// button is absent. [expand] stretches it to the available width.
class SwapWithBuddyActionButton extends ConsumerWidget {
  const SwapWithBuddyActionButton({
    super.key,
    this.padding = EdgeInsets.zero,
    this.expand = false,
  });

  final EdgeInsetsGeometry padding;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_swapAvailable(ref)) {
      return const SizedBox.shrink();
    }
    final button = OutlinedButton.icon(
      onPressed: () => openBuddySwap(context),
      icon: const Icon(Icons.swap_horiz),
      label: Text(context.l10n.buddySwap_title),
    );
    return Padding(
      padding: padding,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
