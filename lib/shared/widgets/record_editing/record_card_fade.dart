import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Why a card has nothing to edit.
enum RecordCardFadeReason {
  /// Worked out from other values of the record.
  calculated,

  /// Brought in from a device or a service.
  imported,

  /// A shared site library's, which a reader's sitting does not change
  /// (issue #4527, phase 2).
  library,
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
    return _EdgeWord(
      word: unlocked ? _reasonWord(context, reason) : null,
      child: Opacity(opacity: unlocked ? _fadedOpacity : 1, child: child),
    );
  }
}

String _reasonWord(BuildContext context, RecordCardFadeReason reason) {
  final l10n = context.l10n;
  return switch (reason) {
    RecordCardFadeReason.calculated => l10n.recordEdit_calculated,
    RecordCardFadeReason.imported => l10n.recordEdit_imported,
    RecordCardFadeReason.library => l10n.recordEdit_library,
  };
}

/// A card that can be edited with something to say while its record is
/// unlocked, such as "Only you" on a library reader's private card (issue
/// #4527, phase 2): [label] set on its top edge as [RecordCardFade] sets
/// its word, with no fade. With no [RecordEditScope], or locked, or with
/// no [label], [child] and nothing else, in the same shape: a page may
/// give every card one, so a word that comes or goes (a role that changes
/// mid-sitting) never rebuilds the card under it.
class RecordCardEdgeLabel<T> extends StatelessWidget {
  const RecordCardEdgeLabel({
    super.key,
    required this.label,
    required this.child,
  });

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = RecordEditScope.maybeOf<T>(context);
    if (controller == null) return child;
    return _EdgeWord(word: controller.isUnlocked ? label : null, child: child);
  }
}

/// [child] with [word] straddling its top edge near the right, half in the
/// gap above the card and half in its top padding; with no [word], [child]
/// in the same shape. The word takes no taps.
class _EdgeWord extends StatelessWidget {
  const _EdgeWord({required this.word, required this.child});

  final String? word;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final word = this.word;
    return Stack(
      fit: StackFit.passthrough,
      // The word straddles the card's top edge.
      clipBehavior: Clip.none,
      children: [
        child,
        if (word != null)
          Positioned(
            top: 0,
            right: 16,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: _ReasonLabel(text: word),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReasonLabel extends StatelessWidget {
  const _ReasonLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
