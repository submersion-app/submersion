import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/section_header_title.dart';

/// The title bar over a desktop list pane, where the list has no app bar of
/// its own: [title] with [actions] beside it when [titleWidth] and the
/// actions fit, or on a row under it (see [SectionHeaderRows]), and an
/// optional [bottom] row under them, on the scheme's surface with a rule
/// below.
///
/// Two tabs of one host that both show their switch in a [PaneHeaderBar]
/// (Media's Photos/Videos and Documents, #3631) keep the switch at the same
/// place and size across a switch.
class PaneHeaderBar extends StatelessWidget {
  const PaneHeaderBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.titleWidth,
    this.bottom,
  });

  /// How far in from the bar's leading edge [title] starts: the bar's own
  /// padding plus [SectionHeaderRows]' gap before the title.
  static const double titleStart = 16;

  final Widget title;
  final List<Widget> actions;

  /// The width [title] needs; null always puts [actions] on their own row.
  final double? titleWidth;

  /// A row under the title row at the bar's full width, such as a tab strip.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = this.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SectionHeaderRows(
              title: title,
              titleWidth: titleWidth,
              actions: actions,
            ),
          ),
          ?bottom,
        ],
      ),
    );
  }
}
