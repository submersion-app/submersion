import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the buddy card swap screen (issue #3728) from the Buddies list
/// headers. Sealed in demo mode, like every way data leaves the logbook, and
/// absent in a browser, which has none of the radios the swap runs over
/// (issue #4121).
class SwapWithBuddyButton extends ConsumerWidget {
  const SwapWithBuddyButton({super.key, this.iconSize});

  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(deviceCapabilitiesProvider).nearby) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(Icons.swap_horiz, size: iconSize),
      tooltip: context.l10n.buddySwap_title,
      onPressed: () {
        if (demoSealGuard(context, DemoSealedFeature.share)) {
          context.push('/buddies/swap');
        }
      },
    );
  }
}
