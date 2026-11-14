import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

/// The title row of a card on a record page: one size for every card.
///
/// Locked, it draws the title and [trailing] and nothing else. Unlocked, it
/// also draws the pencil that opens the card (the whole row is the tap
/// target), the dot that marks unsaved changes, and "Done" while the card is
/// open. Unlocking must not change the row's height.
class RecordCardHeader extends StatelessWidget {
  const RecordCardHeader({super.key, required this.title, this.trailing});

  final String title;

  /// What the card shows at the right while reading, such as a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frame = RecordCardFrameScope.maybeOf(context);
    final titleText = Text(title, style: theme.textTheme.titleMedium);
    final trailing = this.trailing;

    if (frame == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [titleText, ?trailing],
      );
    }

    final l10n = context.l10n;
    final leading = <Widget>[
      Flexible(child: titleText),
      if (frame.isChanged) ...[
        const SizedBox(width: 8),
        Semantics(
          label: l10n.recordEdit_unsavedChanges,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: StatusColors.of(context).warn.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
      const Spacer(),
    ];

    if (frame.isOpen) {
      return Row(
        children: [
          ...leading,
          TextButton(
            onPressed: frame.onDone,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(l10n.common_action_done),
          ),
        ],
      );
    }

    return InkWell(
      onTap: frame.onOpen,
      child: Row(
        children: [
          ...leading,
          ?trailing,
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.recordEdit_editCardTooltip(title),
            child: Icon(
              Icons.edit_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
