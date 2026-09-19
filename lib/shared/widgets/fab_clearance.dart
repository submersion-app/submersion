import 'package:flutter/widgets.dart';

/// Padding for a scrolling list that sits under a floating action button, so
/// its last row can scroll clear of the button (issue #2029).
///
/// Without it the last row stops at the bottom edge of the viewport, right
/// under the FAB, and a tap on the row's trailing action lands on the FAB.
/// 88 is the 56 of a standard or extended FAB, the Scaffold's 16 margin below
/// it, and 16 more so the row does not sit flush against the button.
const EdgeInsets kFabListPadding = EdgeInsets.only(bottom: 88);
