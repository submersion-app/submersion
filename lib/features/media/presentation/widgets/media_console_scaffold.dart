import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/shared/widgets/master_detail/pane_header_bar.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

/// The Media section's internal destinations, in the order they are shown.
/// Both layouts render whatever the enum contains, so growth is
/// enum-plus-registry only.
///
/// Declaration order IS display order, which is why `sources` sits mid-enum
/// rather than at the end. Nothing persists an ordinal: the selection lives
/// in [MediaSectionPage]'s State as a value, and the `index`/`values[i]`
/// pair below is a round trip through one TabController. A value may
/// therefore be inserted wherever it belongs in the list.
enum MediaConsoleSection { library, sources, transfers, importMedia }

/// The Media section's page chrome: [headerTitle] over the section's tabs,
/// over [child] at the full width of the page.
///
/// The tabs always sit on their own row under the title, never beside it,
/// so they never share a row with the Photos/Videos and Documents switch
/// (#3631). Below the master-detail breakpoint that row is the app bar's
/// bottom. At master-detail widths the title and tabs sit in a
/// [PaneHeaderBar], the bar Documents' list pane shows, so the switch stays
/// at the same place and size across a switch between the two tabs. There is no sidebar at any width, so the library grid and the other
/// views always get the whole page.
class MediaConsoleScaffold extends StatefulWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.headerTitle,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.badgeCounts = const {},
  });

  final SectionHeaderTitle headerTitle;
  final MediaConsoleSection selected;
  final ValueChanged<MediaConsoleSection> onSelect;
  final Widget child;

  /// Section id to attention count; zero or absent hides the badge.
  final Map<MediaConsoleSection, int> badgeCounts;

  @override
  State<MediaConsoleScaffold> createState() => _MediaConsoleScaffoldState();
}

class _MediaConsoleScaffoldState extends State<MediaConsoleScaffold>
    with SingleTickerProviderStateMixin {
  // Owned, not a DefaultTabController: that reads its initial index once, so
  // a section change made outside the strip (Sources' "Browse source" jumps
  // to Library) left the indicator on the old tab. One controller also
  // carries the selection across a resize between the phone and desktop
  // layouts.
  late final TabController _controller = TabController(
    length: MediaConsoleSection.values.length,
    initialIndex: widget.selected.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(MediaConsoleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected.index != _controller.index) {
      _controller.animateTo(widget.selected.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, MediaConsoleSection section) {
    return switch (section) {
      MediaConsoleSection.library => l10n.media_console_library,
      MediaConsoleSection.sources => l10n.media_console_sources,
      MediaConsoleSection.transfers => l10n.media_console_transfers,
      MediaConsoleSection.importMedia => l10n.media_console_import,
    };
  }

  Widget _withBadge(MediaConsoleSection section, Widget inner) {
    final count = widget.badgeCounts[section] ?? 0;
    if (count == 0) return inner;
    return Badge.count(count: count, child: inner);
  }

  /// The section tabs, in [colors]. [divider] rules them off from the page
  /// below. [padding] lines the first label up with the switch's first name
  /// above it.
  TabBar _tabBar(
    BuildContext context, {
    required AppBarTabColors colors,
    required bool divider,
    EdgeInsetsGeometry? padding,
  }) {
    final labelStyle =
        Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    return TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: padding,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelColor: colors.selected,
      unselectedLabelColor: colors.unselected,
      indicatorColor: colors.selected,
      overlayColor: colors.overlay,
      dividerColor: divider ? null : Colors.transparent,
      onTap: (i) => widget.onSelect(MediaConsoleSection.values[i]),
      tabs: [
        for (final section in MediaConsoleSection.values)
          Tab(child: _withBadge(section, Text(_label(context.l10n, section)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerTitle = widget.headerTitle;
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      final colors = AppBarTabColors.on(
        theme,
        background: theme.colorScheme.surface,
        foreground: theme.colorScheme.onSurface,
      );
      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaneHeaderBar(
              title: headerTitle.build(context, SectionHeaderSlot.pane, null),
              titleWidth: headerTitle.paneTitleWidth?.call(context),
              // The pane bar draws its own rule under the tabs. The switch's
              // first name sits 8px further in than a tab label does (the
              // bar's 16px inset plus the switch's 8px label padding, against
              // a tab's 16px), so the strip starts 8px in to line up.
              bottom: _tabBar(
                context,
                colors: colors,
                divider: false,
                padding: const EdgeInsetsDirectional.only(start: 8),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    final colors = AppBarTabColors.of(theme);
    return Scaffold(
      appBar: headerTitle.pinAppBar(
        AppBar(
          // 8 here plus the switch's own 8px label padding puts the first
          // name at 16px, the line the section tabs under it start on.
          titleSpacing: 8,
          title: headerTitle.build(context, SectionHeaderSlot.appBar, null),
          toolbarHeight: headerTitle.appBarHeight(context, null),
          // A divider is only needed where the bar is the page's colour; on
          // a coloured bar it draws a stray rule along the bar's edge.
          bottom: _tabBar(
            context,
            colors: colors,
            divider: colors.barMatchesPage,
          ),
        ),
      ),
      body: widget.child,
    );
  }
}
