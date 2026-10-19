import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The banner shown over a viewer while "Pick white" waits for a tap (issue
/// #3520). A [Positioned], so it goes straight into the viewer's [Stack];
/// it ignores pointers so the tap reaches the photo underneath.
class PickWhiteHint extends StatelessWidget {
  const PickWhiteHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.l10n.media_color_pickWhiteHint,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
