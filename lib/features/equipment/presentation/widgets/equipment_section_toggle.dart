import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

/// The Equipment / Sets choice, rendered as the header's own title.
///
/// A [SectionTitleToggle] with Equipment's two names and accent; see there for
/// how it looks and behaves (issue #2256). The statics keep the names this
/// page's layout code has always measured with.
class EquipmentSectionToggle extends StatelessWidget {
  const EquipmentSectionToggle({
    super.key,
    required this.controller,
    this.tabHeight = defaultTabHeight,
    this.onAppBar = false,
  });

  final TabController controller;

  /// See [SectionTitleToggle.tabHeight].
  final double tabHeight;

  /// See [SectionTitleToggle.onAppBar].
  final bool onAppBar;

  static const String _featureId = 'equipment';

  static const double defaultTabHeight = SectionTitleToggle.defaultTabHeight;
  static const double compactTabHeight = SectionTitleToggle.compactTabHeight;
  static const double indicatorWeight = SectionTitleToggle.indicatorWeight;
  static const double labelPadding = SectionTitleToggle.labelPadding;
  static const double subtitleGap = SectionTitleToggle.subtitleGap;

  static double heightFor(double tabHeight) =>
      SectionTitleToggle.heightFor(tabHeight);

  static double textInset({required bool withAccentIcon}) =>
      SectionTitleToggle.textInset(withAccentIcon: withAccentIcon);

  static bool showsAccentIcon(BuildContext context, WidgetRef ref) =>
      SectionTitleToggle.showsAccentIcon(context, ref, featureId: _featureId);

  static double naturalWidth(
    BuildContext context,
    TextStyle style, {
    required bool withAccentIcon,
  }) => SectionTitleToggle.naturalWidth(
    context,
    style,
    labels: _names(context),
    withAccentIcon: withAccentIcon,
  );

  static double fittedTabHeight(
    BuildContext context,
    TextStyle style, {
    required double minHeight,
    TextScaler? textScaler,
  }) => SectionTitleToggle.fittedTabHeight(
    context,
    style,
    labels: _names(context),
    minHeight: minHeight,
    textScaler: textScaler,
  );

  static List<String> _names(BuildContext context) => [
    context.l10n.equipment_tab_equipment,
    context.l10n.equipment_tab_sets,
  ];

  @override
  Widget build(BuildContext context) => SectionTitleToggle(
    controller: controller,
    featureId: _featureId,
    labels: _names(context),
    tabHeight: tabHeight,
    onAppBar: onAppBar,
    tabBarKey: const ValueKey('equipment_section_toggle'),
  );
}
