import 'package:flutter/material.dart';

import 'package:submersion/shared/models/subtitle_text.dart';

/// Where a list's header title is being shown.
enum SectionHeaderSlot {
  /// The phone layout's app bar.
  appBar,

  /// The compact bar over a desktop master-detail list pane.
  pane,

  /// The table-mode header.
  table,
}

/// What a list header shows in place of its own plain title, such as a
/// section switch that names two lists (Training's Certifications | Courses,
/// issue #3437).
///
/// A header given one moves its action icons to a row under the title on
/// phone and in the desktop pane, where a switch of two names and the icons
/// do not fit one row. The table header is wide enough for one.
class SectionHeaderTitle {
  const SectionHeaderTitle({required this.build, required this.appBarHeight});

  /// The title for [slot]; [subtitle] is the list's own entry count, or null
  /// where the slot shows none.
  final Widget Function(
    BuildContext context,
    SectionHeaderSlot slot,
    SubtitleText? subtitle,
  )
  build;

  /// The phone app bar's toolbar height for the title [build] gives there.
  final double Function(BuildContext context, SubtitleText? subtitle)
  appBarHeight;
}

/// The phone app bar's second row, holding [actions] at the trailing edge.
PreferredSizeWidget sectionHeaderActionsRow(List<Widget> actions) =>
    PreferredSize(
      preferredSize: const Size.fromHeight(kMinInteractiveDimension),
      child: Row(children: [const Spacer(), ...actions]),
    );

/// A desktop pane bar's content with [title] on its own row and [actions] on
/// a row under it, at the trailing edge.
class SectionHeaderRows extends StatelessWidget {
  const SectionHeaderRows({
    super.key,
    required this.title,
    required this.actions,
  });

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: title,
          ),
        ),
        Row(children: [const Spacer(), ...actions]),
      ],
    );
  }
}
