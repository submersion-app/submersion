import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the buddy card swap screen (issue #3728) from the Buddies list
/// headers. Sealed in demo mode, like every way data leaves the logbook.
class SwapWithBuddyButton extends StatelessWidget {
  const SwapWithBuddyButton({super.key, this.iconSize});

  final double? iconSize;

  @override
  Widget build(BuildContext context) {
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
