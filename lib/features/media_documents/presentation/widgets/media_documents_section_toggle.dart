import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';
import 'package:submersion/shared/widgets/tab_pinned_app_bar.dart';
import 'package:submersion/shared/widgets/title_with_subtitle.dart';

/// The Media / Documents switch, as the header's own title (#3631).
///
/// A [SectionTitleToggle] driven by the Media and Documents page's
/// [TabController]. Each tab's header leads it with that tab's own accent
/// icon.
class MediaDocumentsSectionToggle extends StatelessWidget {
  const MediaDocumentsSectionToggle({
    super.key,
    required this.controller,
    required this.tab,
    this.tabHeight = SectionTitleToggle.defaultTabHeight,
    this.onAppBar = false,
  });

  final TabController controller;

  /// The tab whose header this switch titles; it picks the accent icon.
  final MediaDocumentsTab tab;

  final double tabHeight;

  /// See [SectionTitleToggle.onAppBar].
  final bool onAppBar;

  static List<String> labels(BuildContext context) => [
    context.l10n.nav_media,
    context.l10n.nav_documents,
  ];

  @override
  Widget build(BuildContext context) => SectionTitleToggle(
    controller: controller,
    featureId: tab.featureId,
    labels: labels(context),
    tabHeight: tabHeight,
    onAppBar: onAppBar,
    tabBarKey: const ValueKey('media_documents_section_toggle'),
  );
}

/// The desktop pane bar's title style, as every list pane's compact bar uses.
TextStyle _paneTitleStyle(BuildContext context) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
    );

/// The [SectionHeaderTitle] a Media/Documents tab shows: the switch, with
/// the tab's own entry count under it. On phone, where the tabs slide, it
/// holds the tab's app bar still so only the body under it moves.
SectionHeaderTitle mediaDocumentsHeaderTitle({
  required TabController controller,
  required MediaDocumentsTab tab,
}) => SectionHeaderTitle(
  build: (context, slot, subtitle) => _MediaDocumentsHeader(
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
        labels: MediaDocumentsSectionToggle.labels(context),
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
  paneTitleWidth: (context) => SectionTitleToggle.naturalWidth(
    context,
    _paneTitleStyle(context),
    labels: MediaDocumentsSectionToggle.labels(context),
    withAccentIcon: true,
  ),
  // Media's own tab strip (#3631) decides whether it fits beside this
  // switch in the SAME app bar slot, so it needs this switch's width in
  // the style it actually renders there -- the toolbar style, not the
  // smaller pane style paneTitleWidth above measures.
  appBarTitleWidth: (context) => SectionTitleToggle.naturalWidth(
    context,
    SectionTitleToggle.toolbarTitleStyle(context),
    labels: MediaDocumentsSectionToggle.labels(context),
    withAccentIcon: true,
  ),
  appBarPin: (bar) => TabPinnedAppBar(
    animation: controller.animation!,
    index: tab.index,
    child: bar,
  ),
);

class _MediaDocumentsHeader extends ConsumerWidget {
  const _MediaDocumentsHeader({
    required this.controller,
    required this.tab,
    required this.slot,
    required this.subtitle,
  });

  final TabController controller;
  final MediaDocumentsTab tab;
  final SectionHeaderSlot slot;
  final SubtitleText? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inToolbar = slot != SectionHeaderSlot.pane;
    final toggle = MediaDocumentsSectionToggle(
      controller: controller,
      tab: tab,
      tabHeight: inToolbar
          ? SectionTitleToggle.compactTabHeight
          : SectionTitleToggle.defaultTabHeight,
      onAppBar: inToolbar,
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
