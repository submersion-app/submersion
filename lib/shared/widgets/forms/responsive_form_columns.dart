import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Lays a form's section list out responsively and scrollably.
///
/// - Narrow / medium widths: a single column, centered at a readable measure.
/// - Wide widths (>= [twoColumnBreakpoint]): two side-by-side columns that
///   fill the pane, capped at [maxTwoColumnWidth] so columns stay readable on
///   very large monitors.
///
/// Reading order is newspaper-style: the first [splitIndex] sections fill the
/// left column and the remainder fill the right, so the form still reads
/// top-to-bottom down each column. [splitIndex] defaults to an even split by
/// count; pages pass an explicit value to balance tall vs short groups.
class ResponsiveFormColumns extends StatelessWidget {
  const ResponsiveFormColumns({
    super.key,
    required this.children,
    this.splitIndex,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
  });

  /// The form's section widgets, in reading order, without inter-section
  /// spacing (this widget inserts [FormStyle.sectionGap] between them).
  final List<Widget> children;

  /// Index at which the right column starts in two-column mode.
  final int? splitIndex;
  final EdgeInsets padding;

  /// At/above this width the form splits into two columns.
  static const double twoColumnBreakpoint = 1040;

  /// Centered reading width for the single-column layout.
  static const double singleColumnMaxWidth = 760;

  /// The two-column block never grows past this.
  static const double maxTwoColumnWidth = 1200;

  static const double _columnGap = 24;

  List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i < items.length - 1) {
        out.add(const SizedBox(height: FormStyle.sectionGap));
      }
    }
    return out;
  }

  Widget _column(List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _spaced(items),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= twoColumnBreakpoint && children.length > 1;
        final Widget content;
        if (twoColumns) {
          final split = (splitIndex ?? (children.length / 2).ceil()).clamp(
            1,
            children.length - 1,
          );
          content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxTwoColumnWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _column(children.sublist(0, split))),
                const SizedBox(width: _columnGap),
                Expanded(child: _column(children.sublist(split))),
              ],
            ),
          );
        } else {
          content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: singleColumnMaxWidth),
            child: _column(children),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Center(child: content),
        );
      },
    );
  }
}
