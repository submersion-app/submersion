import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/section_header_title.dart';

/// A [SectionHeaderTitle] that shows [title] as plain text in every slot,
/// for tests of a page that needs a header title but not a host's real tab
/// switch.
SectionHeaderTitle plainHeaderTitle(
  String title, {
  double appBarHeight = kToolbarHeight,
  PreferredSizeWidget Function(PreferredSizeWidget bar)? appBarPin,
}) => SectionHeaderTitle(
  build: (context, slot, subtitle) => Text(title),
  appBarHeight: (context, subtitle) => appBarHeight,
  appBarPin: appBarPin,
);
