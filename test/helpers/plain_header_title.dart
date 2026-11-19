import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/section_header_title.dart';

/// A [SectionHeaderTitle] that shows [title] as plain text in every slot,
/// for tests of a page that needs a header title but not a host's real tab
/// switch. [titleTextInset] stands in for a switch's own label padding, and
/// [paneTitleWidth] for the width a switch reports to a pane bar.
SectionHeaderTitle plainHeaderTitle(
  String title, {
  double appBarHeight = kToolbarHeight,
  double? titleTextInset,
  double? paneTitleWidth,
  PreferredSizeWidget Function(PreferredSizeWidget bar)? appBarPin,
}) => SectionHeaderTitle(
  build: (context, slot, subtitle) => Text(title),
  appBarHeight: (context, subtitle) => appBarHeight,
  paneTitleWidth: paneTitleWidth == null ? null : (context) => paneTitleWidth,
  titleTextInset: titleTextInset == null
      ? null
      : (context, ref) => titleTextInset,
  appBarPin: appBarPin,
);
