import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Media section's internal destinations, in the order they are shown.
/// Both layouts render whatever the enum contains, so growth is
/// enum-plus-registry only.
///
/// Declaration order IS display order, which is why `sources` sits mid-enum
/// rather than at the end. Nothing persists an ordinal: the selection lives
/// in [MediaSectionPage]'s State as a value, and the `index`/`values[i]`
/// pair below is a round trip through one TabBar within a single build. A
/// value may therefore be inserted wherever it belongs in the list.
enum MediaConsoleSection { library, sources, transfers, importMedia }

/// Internal navigation for the Media section: a left sidebar on wide
/// layouts, top tabs on narrow ones. Mirrors MainScaffold's rail/bar split
/// one level down. The 720px threshold keeps the sidebar off widths where
/// the app shell already spends horizontal space on its own rail.
class MediaConsoleScaffold extends StatelessWidget {
  const MediaConsoleScaffold({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.child,
    this.badgeCounts = const {},
  });

  final MediaConsoleSection selected;
  final ValueChanged<MediaConsoleSection> onSelect;
  final Widget child;

  /// Section id to attention count; zero or absent hides the badge.
  final Map<MediaConsoleSection, int> badgeCounts;

  static const double _sidebarBreakpoint = 720;

  String _label(AppLocalizations l10n, MediaConsoleSection section) {
    return switch (section) {
      MediaConsoleSection.library => l10n.media_console_library,
      MediaConsoleSection.sources => l10n.media_console_sources,
      MediaConsoleSection.transfers => l10n.media_console_transfers,
      MediaConsoleSection.importMedia => l10n.media_console_import,
    };
  }

  IconData _icon(MediaConsoleSection section) {
    return switch (section) {
      MediaConsoleSection.library => Icons.photo_library_outlined,
      MediaConsoleSection.sources => Icons.source_outlined,
      MediaConsoleSection.transfers => Icons.swap_vert,
      MediaConsoleSection.importMedia => Icons.add_photo_alternate_outlined,
    };
  }

  Widget _withBadge(MediaConsoleSection section, Widget inner) {
    final count = badgeCounts[section] ?? 0;
    if (count == 0) return inner;
    return Badge.count(count: count, child: inner);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _sidebarBreakpoint;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 200,
                child: ListView(
                  children: [
                    for (final section in MediaConsoleSection.values)
                      ListTile(
                        selected: section == selected,
                        leading: _withBadge(section, Icon(_icon(section))),
                        title: Text(_label(context.l10n, section)),
                        onTap: () => onSelect(section),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: child),
            ],
          );
        }
        return Column(
          children: [
            Material(
              child: DefaultTabController(
                length: MediaConsoleSection.values.length,
                initialIndex: selected.index,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: (i) => onSelect(MediaConsoleSection.values[i]),
                  tabs: [
                    for (final section in MediaConsoleSection.values)
                      Tab(
                        child: _withBadge(
                          section,
                          Text(_label(context.l10n, section)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
