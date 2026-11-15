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
/// [MediaConsoleAction] buttons on the tab row instead (#4587).
///
/// Nothing persists an ordinal: the selection lives in [MediaSectionPage]'s
/// State as a value, and the `index`/`values[i]` pair below is a round trip
/// through one TabController.
enum MediaConsoleSection { library, gear }

/// The buttons at the end of the Media section's tab row. Declaration order
/// is display order.
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
/// (#3631). Below the master-detail breakpoint that row is the app bar's
/// bottom. At master-detail widths the title and tabs sit in a
/// [PaneHeaderBar], the bar Documents' list pane shows, so the switch stays
/// at the same place and size across a switch between the two tabs. Either
/// way the first tab starts under the switch's first name, and the
/// [MediaConsoleAction] buttons close the same row, so a phone gets no extra
/// header row for them. There is no
/// sidebar at any width, so the library grid and the other views always get
/// the whole page.
class MediaConsoleScaffold extends ConsumerStatefulWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.headerTitle,
    required this.selected,
    required this.onSelect,
    required this.onAction,
    required this.child,
    this.badgeCounts = const {},
  });

  final SectionHeaderTitle headerTitle;
  final MediaConsoleSection selected;
  final ValueChanged<MediaConsoleSection> onSelect;

  /// A tap on one of the row's [MediaConsoleAction] buttons.
  final ValueChanged<MediaConsoleAction> onAction;

  final Widget child;

  /// Section id to attention count; zero or absent hides the badge.
  final Map<MediaConsoleSection, int> badgeCounts;

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

  /// The section tabs, in [colors], their first label starting under the
  /// title's first word, which starts [titleStart] in from the bar's edge,
  /// then the action buttons at the row's end. [divider] rules the whole row
  /// off from the page below, buttons included, which a divider of the tab
  /// bar's own would stop short of.
  PreferredSizeWidget _tabRow(
    BuildContext context, {
    required AppBarTabColors colors,
    required bool divider,
    required double titleStart,
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
        child: Row(
          children: [
            Expanded(child: tabBar),
            for (final action in _actions) _actionButton(l10n, colors, action),
            // An icon button pads its own glyph, so a small gap is enough.
            const SizedBox(width: 4),
          ],
        ),
      ),
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
              // The pane bar draws its own rule under the tabs.
              bottom: _tabRow(
                context,
                colors: colors,
                divider: false,
                titleStart: PaneHeaderBar.titleStart,
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
          ),
        ),
      ),
      body: widget.child,
    );
  }
}
