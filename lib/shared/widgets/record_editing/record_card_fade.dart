import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Why a card has nothing to edit.
enum RecordCardFadeReason {
  /// Worked out from other values of the record.
  calculated,

  /// Brought in from a device or a service.
  imported,
}

/// How far a card with nothing to edit fades while its record is unlocked.
const double _fadedOpacity = 0.55;

/// A card with nothing to edit.
///
/// With no [RecordEditScope] it is [child] and nothing else. Locked, [child]
/// is shown as it is. Unlocked,
/// [child] is drawn faded with [reason]'s word set on its top edge near the
/// right, half in the gap above the card and half in its top padding: over
/// no header action and no value, and its size does not change, so the
/// page does not move. Reading interactions inside it keep working: the
/// word takes no taps.
class RecordCardFade<T> extends StatelessWidget {
  const RecordCardFade({super.key, required this.reason, required this.child});

  final RecordCardFadeReason reason;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = RecordEditScope.maybeOf<T>(context);
    // A page that offers no editing draws the card exactly as before.
    if (controller == null) return child;
    final unlocked = controller.isUnlocked;
    // One shape locked or unlocked, so unlocking never remounts the card,
    // and the card is laid out under the constraints it was given.
    return Stack(
      fit: StackFit.passthrough,
      // The word straddles the card's top edge.
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: unlocked ? _fadedOpacity : 1, child: child),
        if (unlocked)
          Positioned(
            top: 0,
            right: 16,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: _ReasonLabel(reason: reason),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReasonLabel extends StatelessWidget {
  const _ReasonLabel({required this.reason});

  final RecordCardFadeReason reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final text = switch (reason) {
      RecordCardFadeReason.calculated => l10n.recordEdit_calculated,
      RecordCardFadeReason.imported => l10n.recordEdit_imported,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
