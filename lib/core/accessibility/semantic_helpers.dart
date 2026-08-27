import 'package:flutter/material.dart';

/// Extension methods for adding common semantic annotations to widgets.
extension SemanticWidgetExtensions on Widget {
  /// Wraps this widget with [Semantics] marking it as a button.
  Widget semanticButton({required String label}) =>
      Semantics(button: true, label: label, child: this);

  /// Wraps this widget with [Semantics] providing a label for screen readers.
  Widget semanticLabel(String label) => Semantics(label: label, child: this);

  /// Wraps this widget with [ExcludeSemantics] to hide it from screen readers.
  ///
  /// Use for purely decorative elements like dividers, background images,
  /// or ornamental icons that provide no information.
  Widget excludeFromSemantics() => ExcludeSemantics(child: this);
}

/// Builds a concise summary label for a chart widget.
///
/// Screen readers cannot interpret visual chart data, so this provides
/// a textual alternative describing the chart's key information.
///
/// Not localized: the glue (" chart. ") and the [chartType] word callers
/// pass are both English, so the announcement stays English under every
/// locale. New callers must not use it -- give the chart its own ARB key
/// that spells the whole sentence out, the way the statistics pages now do
/// (for example `statistics_timePatterns_dayOfWeek_semanticLabel`). The
/// remaining callers are the deco/tissue panels, whose long English
/// descriptions need the same treatment (issue #1042 follow-up).
String chartSummaryLabel({
  required String chartType,
  required String description,
}) {
  return '$chartType chart. $description';
}

/// Builds a descriptive label for a list item.
///
/// Combines title, optional subtitle, and optional status into a single
/// string suitable for screen reader announcement.
String listItemLabel({
  required String title,
  String? subtitle,
  String? status,
}) {
  final parts = [title];
  if (subtitle != null && subtitle.isNotEmpty) parts.add(subtitle);
  if (status != null && status.isNotEmpty) parts.add(status);
  return parts.join(', ');
}

/// Builds a descriptive label for a stat value.
String statLabel({required String name, required String value, String? unit}) {
  if (unit != null) {
    return '$name: $value $unit';
  }
  return '$name: $value';
}
