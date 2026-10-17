import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';
import 'package:submersion/shared/widgets/title_with_subtitle.dart';

/// The Certifications / Courses switch, as the header's own title (#3437).
///
/// A [SectionTitleToggle] driven by the Training page's [TabController]. Each
/// tab's header leads it with that tab's own accent icon.
class TrainingSectionToggle extends StatelessWidget {
  const TrainingSectionToggle({
    super.key,
    required this.controller,
    required this.tab,
    this.tabHeight = SectionTitleToggle.defaultTabHeight,
  });

  final TabController controller;

  /// The tab whose header this switch titles; it picks the accent icon.
  final TrainingTab tab;

  final double tabHeight;

  static List<String> labels(BuildContext context) => [
    context.l10n.nav_certifications,
    context.l10n.nav_courses,
  ];

  @override
  Widget build(BuildContext context) => SectionTitleToggle(
    controller: controller,
    featureId: tab.featureId,
    labels: labels(context),
    tabHeight: tabHeight,
    tabBarKey: const ValueKey('training_section_toggle'),
  );
}

/// The desktop pane bar's title style, as every list pane's compact bar uses.
TextStyle _paneTitleStyle(BuildContext context) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
    );

/// The [SectionHeaderTitle] a Training tab's list shows: the switch, with the
/// list's own entry count under it.
SectionHeaderTitle trainingHeaderTitle({
  required TabController controller,
  required TrainingTab tab,
}) => SectionHeaderTitle(
  build: (context, slot, subtitle) => _TrainingHeader(
    controller: controller,
    tab: tab,
    slot: slot,
    subtitle: subtitle,
  ),
  appBarHeight: (context, subtitle) {
    final style = SectionTitleToggle.toolbarTitleStyle(context);
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: SectionTitleToggle.appBarTitleMaxTextScale);
    final toggle = SectionTitleToggle.heightFor(
      SectionTitleToggle.fittedTabHeight(
        context,
        style,
        labels: TrainingSectionToggle.labels(context),
        minHeight: SectionTitleToggle.compactTabHeight,
        textScaler: scaler,
      ),
    );
    final count = subtitle == null
        ? 0.0
        : TitleWithSubtitle.subtitleLineHeight(
            context,
            text: subtitle.full,
            textScaler: scaler,
          );
    return math.max(kToolbarHeight, toggle + count);
  },
  // Counts the accent icon whether or not it shows: the pane bar only needs
  // to know whether the names and its icons fit one row, and erring wide
  // costs a second row, never a clipped name.
  paneTitleWidth: (context) => SectionTitleToggle.naturalWidth(
    context,
    _paneTitleStyle(context),
    labels: TrainingSectionToggle.labels(context),
    withAccentIcon: true,
  ),
);

class _TrainingHeader extends ConsumerWidget {
  const _TrainingHeader({
    required this.controller,
    required this.tab,
    required this.slot,
    required this.subtitle,
  });

  final TabController controller;
  final TrainingTab tab;
  final SectionHeaderSlot slot;
  final SubtitleText? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The phone app bar and the table header are both standard toolbars,
    // which clip a title taller than they are, so both take the compact
    // switch and the 18px names that leave the count line room under it.
    final inToolbar = slot != SectionHeaderSlot.pane;
    final toggle = TrainingSectionToggle(
      controller: controller,
      tab: tab,
      tabHeight: inToolbar
          ? SectionTitleToggle.compactTabHeight
          : SectionTitleToggle.defaultTabHeight,
    );
    final style = inToolbar
        ? SectionTitleToggle.toolbarTitleStyle(context)
        : _paneTitleStyle(context);
    return TitleWithSubtitle(
      title: DefaultTextStyle.merge(style: style, child: toggle),
      subtitle: subtitle,
      subtitleIndent: SectionTitleToggle.textInset(
        withAccentIcon: SectionTitleToggle.showsAccentIcon(
          context,
          ref,
          featureId: tab.featureId,
        ),
      ),
    );
  }
}
