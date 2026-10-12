import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

/// The header a [NavShortcutGroup] is listed under.
String navShortcutGroupLabel(AppLocalizations l10n, NavShortcutGroup group) {
  return switch (group) {
    NavShortcutGroup.planning => l10n.nav_planning,
    NavShortcutGroup.insights => l10n.nav_insights,
    NavShortcutGroup.views => l10n.settings_navCustomization_group_views,
    NavShortcutGroup.settingsAndTools =>
      l10n.settings_navCustomization_group_settingsAndTools,
  };
}

/// Asks the diver which page to add to the nav (#2936).
///
/// Returns the chosen `NavShortcut.id`, or null when dismissed. Shortcuts in
/// [alreadyAdded] are listed but cannot be chosen again. A dialog on wide
/// windows, a bottom sheet on phones.
Future<String?> showNavShortcutPicker(
  BuildContext context, {
  required Set<String> alreadyAdded,
}) {
  if (ResponsiveBreakpoints.isDesktop(context)) {
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: NavShortcutPicker(alreadyAdded: alreadyAdded),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * kNavSheetMaxHeightFraction,
    ),
    // Lifted by the keyboard inset so the search results stay above the
    // keyboard the search field raises.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(child: NavShortcutPicker(alreadyAdded: alreadyAdded)),
    ),
  );
}

/// The searchable, grouped list of nav shortcuts.
class NavShortcutPicker extends StatefulWidget {
  const NavShortcutPicker({super.key, required this.alreadyAdded});

  /// Shortcut ids already on the surface being edited.
  final Set<String> alreadyAdded;

  @override
  State<NavShortcutPicker> createState() => _NavShortcutPickerState();
}

class _NavShortcutPickerState extends State<NavShortcutPicker> {
  String _query = '';

  /// Whether typing can start the moment the picker opens. A desktop OS has a
  /// hardware keyboard; on a phone or tablet focusing the search would throw
  /// the on-screen keyboard over the list the diver came to browse. Decided
  /// by platform, not window width: a tablet in landscape is as wide as a
  /// desktop window.
  bool get _hasHardwareKeyboard => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };

  bool _matches(AppLocalizations l10n, NavShortcut shortcut) {
    if (_query.isEmpty) return true;
    final query = _query.toLowerCase();
    return shortcut.label(l10n).toLowerCase().contains(query) ||
        shortcut.parentLabel(l10n).toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible = kNavShortcuts.where((s) => _matches(l10n, s)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settings_navCustomization_shortcutPickerTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_action_close,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: _hasHardwareKeyboard,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.settings_navCustomization_shortcutSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.settings_navCustomization_shortcutNoMatches,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final group in NavShortcutGroup.values)
                      ..._groupTiles(context, group, visible),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _groupTiles(
    BuildContext context,
    NavShortcutGroup group,
    List<NavShortcut> visible,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inGroup = visible.where((s) => s.group == group).toList();
    if (inGroup.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          navShortcutGroupLabel(l10n, group),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      for (final shortcut in inGroup)
        _shortcutTile(context, shortcut, widget.alreadyAdded),
    ];
  }

  Widget _shortcutTile(
    BuildContext context,
    NavShortcut shortcut,
    Set<String> alreadyAdded,
  ) {
    final l10n = context.l10n;
    final added = alreadyAdded.contains(shortcut.id);
    return ListTile(
      key: ValueKey('nav-shortcut-option-${shortcut.id}'),
      enabled: !added,
      leading: Icon(shortcut.icon),
      title: Text(shortcut.label(l10n)),
      subtitle: Text(shortcut.parentLabel(l10n)),
      trailing: added
          ? Tooltip(
              message: l10n.settings_navCustomization_shortcutAlreadyAdded,
              child: const Icon(Icons.check),
            )
          : null,
      onTap: added ? null : () => Navigator.pop(context, shortcut.id),
    );
  }
}
