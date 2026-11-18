import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// What a [RecordCardHeader] needs to know about the card it titles while
/// the record is unlocked.
@immutable
class RecordCardFrameData {
  const RecordCardFrameData({
    required this.isOpen,
    required this.isChanged,
    required this.onOpen,
    required this.onDone,
  });

  /// Whether the card's editor is showing in place of its read layout.
  final bool isOpen;

  /// Whether the card has changes not yet saved.
  final bool isChanged;

  final VoidCallback onOpen;
  final VoidCallback onDone;
}

/// Set by a `RecordCardFrame` around its card. [data] is null while the
/// record is locked, so the scope can stay in the tree in every state and
/// unlocking never remounts the card beneath it.
class RecordCardFrameScope extends InheritedWidget {
  const RecordCardFrameScope({
    super.key,
    required this.data,
    required super.child,
  });

  final RecordCardFrameData? data;

  static RecordCardFrameData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecordCardFrameScope>()?.data;

  @override
  bool updateShouldNotify(RecordCardFrameScope oldWidget) =>
      data?.isOpen != oldWidget.data?.isOpen ||
      data?.isChanged != oldWidget.data?.isChanged ||
      (data == null) != (oldWidget.data == null);
}

/// The dot that marks a card with changes not yet saved.
class RecordChangedDot extends StatelessWidget {
  const RecordChangedDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.recordEdit_unsavedChanges,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: StatusColors.of(context).warn.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The title row of a card on a record page: one size for every card.
///
/// Locked, it draws the title and [trailing] and nothing else. Unlocked, it
/// also draws the pencil that opens the card (the whole row is the tap
/// target), the dot that marks unsaved changes, and "Done" while the card is
/// open. Unlocking must not change the row's height.
class RecordCardHeader extends StatelessWidget {
  const RecordCardHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;

  /// Drawn before the title in every state, such as a card's icon.
  final Widget? leading;

  /// What the card shows at the right while reading, such as a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frame = RecordCardFrameScope.maybeOf(context);
    final titleText = Text(title, style: theme.textTheme.titleMedium);
    final leading = this.leading;
    final trailing = this.trailing;
    final beforeTitle = <Widget>[
      if (leading != null) ...[leading, const SizedBox(width: 8)],
    ];

    if (frame == null) {
      // The title takes the room there is and wraps within it, so what
      // follows sits at the row's right edge and a long title cannot
      // overflow the card.
      return Row(
        children: [
          ...beforeTitle,
          Expanded(child: titleText),
          ?trailing,
        ],
      );
    }

    final l10n = context.l10n;
    // The title and its dot take all the room the row has left, so what
    // follows them sits at the row's right edge.
    final titleAndDot = <Widget>[
      ...beforeTitle,
      Expanded(
        child: Row(
          children: [
            Flexible(child: titleText),
            const SizedBox(width: 8),
            // The dot's place is kept while there is none, so that its
            // arrival on the first keystroke cannot wrap the title and
            // push the open editor down a line.
            SizedBox.square(
              dimension: 8,
              child: frame.isChanged ? const RecordChangedDot() : null,
            ),
          ],
        ),
      ),
    ];

    if (frame.isOpen) {
      return Row(
        children: [
          ...titleAndDot,
          TextButton(
            onPressed: frame.onDone,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(l10n.common_action_done),
          ),
        ],
      );
    }

    // An InkWell gives the row a tap action but no role, and the row is
    // the card's only way in: it is announced as the button it is. A node
    // of its own, or the Card around it would merge the card's whole body
    // into this button.
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: frame.onOpen,
        child: Row(
          children: [
            ...titleAndDot,
            ?trailing,
            const SizedBox(width: 8),
            RecordPencilIcon(cardTitle: title),
          ],
        ),
      ),
    );
  }
}
