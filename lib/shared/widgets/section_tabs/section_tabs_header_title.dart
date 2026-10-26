import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';
import 'package:submersion/shared/widgets/tab_pinned_app_bar.dart';
import 'package:submersion/shared/widgets/title_with_subtitle.dart';

/// The desktop pane bar's title style, as every list pane's compact bar uses.
TextStyle _paneTitleStyle(BuildContext context) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
    );

/// The [SectionHeaderTitle] a [SectionTabsHost] tab shows: the switch
/// between the host's tabs, named by [labels], with the tab's own entry
/// count under it. On phone, where the tabs slide, it holds the tab's app
/// bar still so only the body under it moves (#3465).
///
/// [toggleKey] keys the switch's [TabBar], so tests can find it.
SectionHeaderTitle sectionTabsHeaderTitle({
  required TabController controller,
  required SectionTab tab,
  required List<String> Function(BuildContext context) labels,
  required Key toggleKey,
}) => SectionHeaderTitle(
  build: (context, slot, subtitle) => _SectionTabsHeader(
    controller: controller,
    tab: tab,
    labels: labels(context),
    toggleKey: toggleKey,
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
        labels: labels(context),
        minHeight: SectionTitleToggle.compactTabHeight,
        textScaler: scaler,
      ),
    );
    final count = subtitle == null
        ? 0.0
        : SectionTitleToggle.subtitleGap +
              TitleWithSubtitle.subtitleLineHeight(
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
    labels: labels(context),
    withAccentIcon: true,
  ),
  titleTextInset: (context, ref) => SectionTitleToggle.textInset(
    withAccentIcon: SectionTitleToggle.showsAccentIcon(
      context,
      ref,
      featureId: tab.featureId,
    ),
  ),
  appBarPin: (bar) => TabPinnedAppBar(
    animation: controller.animation!,
    index: tab.index,
    child: bar,
  ),
);

class _SectionTabsHeader extends ConsumerWidget {
  const _SectionTabsHeader({
    required this.controller,
    required this.tab,
    required this.labels,
    required this.toggleKey,
    required this.slot,
    required this.subtitle,
  });

  final TabController controller;
  final SectionTab tab;
  final List<String> labels;
  final Key toggleKey;
  final SectionHeaderSlot slot;
  final SubtitleText? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The phone app bar and the table header are both standard toolbars,
    // which clip a title taller than they are, so both take the compact
    // switch and the 18px names that leave the count line room under it.
    final inToolbar = slot != SectionHeaderSlot.pane;
    // Each tab's header leads the switch with that tab's own accent icon.
    final toggle = SectionTitleToggle(
      controller: controller,
      featureId: tab.featureId,
      labels: labels,
      tabHeight: inToolbar
          ? SectionTitleToggle.compactTabHeight
          : SectionTitleToggle.defaultTabHeight,
      onAppBar: inToolbar,
      tabBarKey: toggleKey,
    );
    final style = inToolbar
        ? SectionTitleToggle.toolbarTitleStyle(context)
        : _paneTitleStyle(context);
    return TitleWithSubtitle(
      title: DefaultTextStyle.merge(style: style, child: toggle),
      subtitle: subtitle,
      subtitleGap: SectionTitleToggle.subtitleGap,
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
