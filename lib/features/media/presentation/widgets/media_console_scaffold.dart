import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/shared/widgets/master_detail/pane_header_bar.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

/// The Media section's tabs, in the order they are shown: the places to
/// browse. Import, Transfers and Sources are actions, so they are
/// [MediaConsoleAction] buttons in the header instead (#4587).
///
/// Nothing persists an ordinal: the selection lives in [MediaSectionPage]'s
/// State as a value, and the `index`/`values[i]` pair below is a round trip
/// through one TabController.
enum MediaConsoleSection { library, gear }

/// The buttons at the end of a Media header row: the tab row on a phone, the
/// switch's row at desktop widths (#4777). Declaration order is display
/// order.
enum MediaConsoleAction { importMedia, transfers, sources }

/// The buttons a device with [caps] offers: a browser can neither import
/// files nor watch folders, so it has only Transfers (issue #4121).
List<MediaConsoleAction> mediaConsoleActionsFor(DeviceCapabilities caps) =>
    caps.mediaAttach
    ? MediaConsoleAction.values
    : const [MediaConsoleAction.transfers];

/// The Media section's page chrome: [headerTitle] over the section's tabs
/// and action buttons, over [child] at the full width of the page.
///
/// The tabs always sit on their own row under the title, never beside it,
/// so they never share a row with the Photos/Videos and Documents switch
/// (#3631), and the first tab starts under the switch's first name.
///
/// Below the master-detail breakpoint the tab row is the app bar's bottom,
/// and the [MediaConsoleAction] buttons close it, so a phone gets no extra
/// header row for them (#4587).
///
/// At master-detail widths the title and tabs sit in a [PaneHeaderBar], the
/// bar Documents' list pane shows, so the switch stays at the same place and
/// size across a switch between the two tabs. There the buttons close the
/// switch's row, as Documents' own do, and [tabRowTrailing] fills the tab
/// row after the tabs, so the header is two rows with no empty band at its
/// top right (#4777).
///
/// There is no sidebar at any width, so the library grid and the other views
/// always get the whole page.
class MediaConsoleScaffold extends ConsumerStatefulWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.headerTitle,
    required this.selected,
    required this.onSelect,
    required this.onAction,
    required this.child,
    this.badgeCounts = const {},
    this.tabRowTrailing,
  });

  /// Whether a [MediaConsoleScaffold] built in [context] uses its
  /// master-detail [PaneHeaderBar] layout, the one that shows
  /// [tabRowTrailing]. A page whose trailing widget stands in for a row of
  /// its body asks this to leave that row out; the scaffold asks it too, so
  /// the two can never disagree.
  static bool hostsTabRowTrailing(BuildContext context) =>
      ResponsiveBreakpoints.isMasterDetail(context);

  final SectionHeaderTitle headerTitle;
  final MediaConsoleSection selected;
  final ValueChanged<MediaConsoleSection> onSelect;

  /// A tap on one of the row's [MediaConsoleAction] buttons.
  final ValueChanged<MediaConsoleAction> onAction;

  final Widget child;

  /// Section id to attention count; zero or absent hides the badge.
  final Map<MediaConsoleSection, int> badgeCounts;

  /// Shown after the tabs, to the end of the tab row, where
  /// [hostsTabRowTrailing] holds: the selected section's own toolbar, which
  /// would otherwise take a row of the page under the header (#4777). Null
  /// leaves the rest of the row empty.
  final Widget? tabRowTrailing;

  @override
  ConsumerState<MediaConsoleScaffold> createState() =>
      _MediaConsoleScaffoldState();
}

class _MediaConsoleScaffoldState extends ConsumerState<MediaConsoleScaffold>
    with SingleTickerProviderStateMixin {
  // Owned, not a DefaultTabController: that reads its initial index once, so
  // a section change made outside the strip (browsing a source on the
  // Sources page selects the Library) left the indicator on the old tab. One
  // controller also carries the selection across a resize between the phone
  // and desktop layouts.
  static const List<MediaConsoleSection> _sections = MediaConsoleSection.values;

  late final List<MediaConsoleAction> _actions = mediaConsoleActionsFor(
    ref.read(deviceCapabilitiesProvider),
  );

  late final TabController _controller = TabController(
    length: _sections.length,
    initialIndex: math.max(0, _sections.indexOf(widget.selected)),
    vsync: this,
  );

  @override
  void didUpdateWidget(MediaConsoleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _sections.indexOf(widget.selected);
    if (index >= 0 && index != _controller.index) {
      _controller.animateTo(index);
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
      MediaConsoleSection.gear => l10n.media_gearGallery_tab,
    };
  }

  /// One action button, in the unselected tab colour so it reads wherever
  /// the tab labels do (a stock icon would vanish on a coloured bar).
  Widget _actionButton(
    AppLocalizations l10n,
    AppBarTabColors colors,
    MediaConsoleAction action,
  ) {
    final (icon, tooltip) = switch (action) {
      MediaConsoleAction.importMedia => (
        Icons.add_photo_alternate_outlined,
        l10n.media_console_import,
      ),
      MediaConsoleAction.transfers => (
        Icons.swap_vert,
        l10n.media_console_transfers,
      ),
      MediaConsoleAction.sources => (
        Icons.source_outlined,
        l10n.media_console_sources,
      ),
    };
    return IconButton(
      key: ValueKey('media_console_action_${action.name}'),
      icon: Icon(icon),
      tooltip: tooltip,
      color: colors.unselected,
      onPressed: () => widget.onAction(action),
    );
  }

  Widget _withBadge(MediaConsoleSection section, Widget inner) {
    final count = widget.badgeCounts[section] ?? 0;
    if (count == 0) return inner;
    return Badge.count(count: count, child: inner);
  }

  List<Widget> _actionButtons(AppLocalizations l10n, AppBarTabColors colors) =>
      [for (final action in _actions) _actionButton(l10n, colors, action)];

  /// The section tabs, in [colors], their first label starting under the
  /// title's first word, which starts [titleStart] in from the bar's edge,
  /// then [trailing] at the row's end. [divider] rules the whole row off
  /// from the page below, [trailing] included, which a divider of the tab
  /// bar's own would stop short of.
  ///
  /// With [shrinkTabs] the tabs take only their labels' width, up to half
  /// the row, and [trailing] has the rest to lay out as it needs; without,
  /// the tabs take whatever [trailing] leaves.
  PreferredSizeWidget _tabRow(
    BuildContext context, {
    required AppBarTabColors colors,
    required bool divider,
    required double titleStart,
    required List<Widget> trailing,
    bool shrinkTabs = false,
  }) {
    final textStart =
        titleStart +
        (widget.headerTitle.titleTextInset?.call(context, ref) ?? 0);
    final labelStyle =
        Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    final l10n = context.l10n;
    final tabBar = TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsetsDirectional.only(
        start: math.max(0, textStart - kTabLabelPadding.left),
      ),
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelColor: colors.selected,
      unselectedLabelColor: colors.unselected,
      indicatorColor: colors.selected,
      overlayColor: colors.overlay,
      dividerColor: Colors.transparent,
      // The row draws any rule itself. A zero height also lets the
      // scrollable strip shrink to its tabs instead of filling its width,
      // which [shrinkTabs] relies on.
      dividerHeight: 0,
      onTap: (i) => widget.onSelect(_sections[i]),
      tabs: [
        for (final section in _sections)
          Tab(child: _withBadge(section, Text(_label(l10n, section)))),
      ],
    );
    return PreferredSize(
      preferredSize: tabBar.preferredSize,
      child: DecoratedBox(
        key: const ValueKey('media_console_tab_row'),
        decoration: BoxDecoration(
          border: divider
              ? Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                )
              : null,
        ),
        child: shrinkTabs
            ? LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    // A scrollable strip needs a bounded width.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth / 2,
                      ),
                      child: tabBar,
                    ),
                    ...trailing,
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(child: tabBar),
                  ...trailing,
                ],
              ),
      ),
    );
  }

  /// The pane bar's tab row: the tabs, then
  /// [MediaConsoleScaffold.tabRowTrailing] to the row's end.
  PreferredSizeWidget _paneTabRow(
    BuildContext context,
    AppBarTabColors colors,
  ) {
    final trailing = widget.tabRowTrailing;
    return _tabRow(
      context,
      colors: colors,
      divider: false,
      titleStart: PaneHeaderBar.titleStart,
      shrinkTabs: trailing != null,
      trailing: [
        if (trailing != null) ...[
          const SizedBox(width: 16),
          Expanded(child: trailing),
          // In line with the pane bar's own 8px end padding on the row
          // above, so the trailing widget's last control sits under the
          // last button.
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerTitle = widget.headerTitle;
    if (MediaConsoleScaffold.hostsTabRowTrailing(context)) {
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
              actions: _actionButtons(context.l10n, colors),
              // The pane bar draws its own rule under the tabs.
              bottom: _paneTabRow(context, colors),
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
          titleSpacing: SectionTitleToggle.appBarTitleSpacing,
          title: headerTitle.build(context, SectionHeaderSlot.appBar, null),
          toolbarHeight: headerTitle.appBarHeight(context, null),
          // A divider is only needed where the bar is the page's colour; on
          // a coloured bar it draws a stray rule along the bar's edge.
          bottom: _tabRow(
            context,
            colors: colors,
            divider: colors.barMatchesPage,
            titleStart: SectionTitleToggle.appBarTitleSpacing,
            trailing: [
              ..._actionButtons(context.l10n, colors),
              // An icon button pads its own glyph, so a small gap is enough.
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
      body: widget.child,
    );
  }
}
