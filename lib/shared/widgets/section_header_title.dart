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
/// phone, where a switch of two names and the icons do not fit one row, and
/// in the desktop pane when [paneTitleWidth] says they do not fit there
/// either. The table header is wide enough for one.
class SectionHeaderTitle {
  const SectionHeaderTitle({
    required this.build,
    required this.appBarHeight,
    this.paneTitleWidth,
    this.appBarPin,
  });

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

  /// The width the pane title needs, so the pane bar can keep it and the
  /// icons on one row when both fit. Null always gives the icons a row of
  /// their own.
  final double Function(BuildContext context)? paneTitleWidth;

  /// Wraps the phone app bar so a host that slides the list sideways can
  /// hold the bar still, as Training's tabs do. Null leaves it as it is.
  final PreferredSizeWidget Function(PreferredSizeWidget bar)? appBarPin;

  /// [bar], wrapped by [appBarPin] when there is one. A list hands this
  /// every bar its phone layout shows, the selection bar included.
  PreferredSizeWidget pinAppBar(PreferredSizeWidget bar) =>
      appBarPin?.call(bar) ?? bar;
}

/// The phone app bar's second row, holding [actions] at the trailing edge.
PreferredSizeWidget sectionHeaderActionsRow(List<Widget> actions) =>
    PreferredSize(
      preferredSize: const Size.fromHeight(kMinInteractiveDimension),
      child: Row(children: [const Spacer(), ...actions]),
    );

/// A desktop pane bar's content: [title] with [actions] beside it when
/// [titleWidth] and the actions fit the bar, or [actions] on a row under it.
class SectionHeaderRows extends StatelessWidget {
  const SectionHeaderRows({
    super.key,
    required this.title,
    required this.actions,
    this.titleWidth,
  });

  final Widget title;
  final List<Widget> actions;

  /// The width [title] needs; null always puts [actions] on their own row.
  final double? titleWidth;

  /// Room each action takes: an icon button's touch target.
  static const double _actionWidth = kMinInteractiveDimension;

  /// The gap before the title, matching every other pane bar's.
  static const double _leadingGap = 8;

  @override
  Widget build(BuildContext context) {
    final width = titleWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneRow =
            width != null &&
            _leadingGap + width + actions.length * _actionWidth <=
                constraints.maxWidth;
        return oneRow ? _oneRow() : _twoRows();
      },
    );
  }

  Widget _oneRow() => Row(
    children: [
      const SizedBox(width: _leadingGap),
      Expanded(
        child: Align(alignment: AlignmentDirectional.centerStart, child: title),
      ),
      ...actions,
    ],
  );

  Widget _twoRows() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: _leadingGap),
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
