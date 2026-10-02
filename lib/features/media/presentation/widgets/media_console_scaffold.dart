import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

/// The Media section's page chrome: an app bar titled [title] carrying the
/// section's tabs, over [child] at the full width of the page.
///
/// The tabs sit inline beside the title whenever the title and the whole
/// strip fit in the bar (see [appBarTabsFitInline]), saving the row a tab bar
/// would otherwise take; when they do not, they drop to the bar's bottom, the
/// phone layout. There is no sidebar at any width, so the library grid and
/// the other views always get the whole page.
class MediaConsoleScaffold extends StatefulWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.title,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.badgeCounts = const {},
  });

  final String title;
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
  // carries the selection across a switch between inline and stacked tabs.
  late final TabController _controller = TabController(
    length: MediaConsoleSection.values.length,
    initialIndex: widget.selected.index,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    // The inline decision measures text, so it is only as good as the fonts
    // loaded at the time. Tropical and Console load Nunito asynchronously;
    // re-measure when it lands, since a LayoutBuilder re-runs only on new
    // constraints, not when its text relayouts.
    PaintingBinding.instance.systemFonts.addListener(_remeasure);
  }

  void _remeasure() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MediaConsoleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected.index != _controller.index) {
      _controller.animateTo(widget.selected.index);
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_remeasure);
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

  TabBar _tabBar({
    required List<String> labels,
    required TextStyle labelStyle,
    required AppBarTabColors colors,
    required bool inline,
  }) {
    return TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelColor: colors.selected,
      unselectedLabelColor: colors.unselected,
      indicatorColor: colors.selected,
      overlayColor: colors.overlay,
      // Inline, a divider would underline the tabs alone, stopping short of
      // the title. Stacked, it is only needed where the bar is the page's
      // colour; on a coloured bar it draws a stray rule along the bar's edge.
      dividerColor: inline || !colors.barMatchesPage
          ? Colors.transparent
          : null,
      onTap: (i) => widget.onSelect(MediaConsoleSection.values[i]),
      tabs: [
        for (final (i, section) in MediaConsoleSection.values.indexed)
          Tab(child: _withBadge(section, Text(labels[i]))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [
      for (final section in MediaConsoleSection.values)
        _label(context.l10n, section),
    ];
    // Handed to the TabBar AND to the fit measurement, so both agree.
    final labelStyle = theme.textTheme.titleSmall ?? const TextStyle();
    final colors = AppBarTabColors.of(theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = appBarTabsFitInline(
          context,
          barWidth: constraints.maxWidth,
          title: widget.title,
          labels: labels,
          labelStyle: labelStyle,
        );
        final tabs = _tabBar(
          labels: labels,
          labelStyle: labelStyle,
          colors: colors,
          inline: inline,
        );
        return Scaffold(
          appBar: AppBar(
            // Inline tabs start right after the title, so it must not be
            // centred (the iOS default).
            centerTitle: inline ? false : null,
            title: inline
                ? Row(
                    children: [
                      Text(widget.title),
                      const SizedBox(width: kAppBarInlineTabGap),
                      // Flexible so a measurement a pixel short degrades to
                      // a scrolling strip instead of an overflow.
                      Flexible(child: tabs),
                    ],
                  )
                : Text(widget.title),
            bottom: inline ? null : tabs,
          ),
          body: widget.child,
        );
      },
    );
  }
}
