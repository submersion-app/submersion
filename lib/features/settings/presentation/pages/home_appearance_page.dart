import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panel_labels.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Appearance settings for Home: a layout preset to start from, the panel
/// list to show, hide and reorder (which makes the layout Custom), and the
/// status lights in the header.
///
/// The whole page is ONE CustomScrollView with the panel list as a
/// SliverReorderableList: a shrink-wrapped list nested in a scroll view
/// would disable auto-scroll-while-dragging.
///
/// When [embedded] is true, omits the Scaffold/AppBar for embedding in the
/// desktop settings detail pane.
class HomeAppearancePage extends ConsumerWidget {
  final bool embedded;

  const HomeAppearancePage({this.embedded = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenChips = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeChips),
    );
    final layout = resolveHomeLayout(
      storedOrder: ref.watch(settingsProvider.select((s) => s.homePanelOrder)),
      storedHidden: ref.watch(
        settingsProvider.select((s) => s.hiddenHomePanels),
      ),
      legacyHiddenCards: ref.watch(
        settingsProvider.select((s) => s.hiddenHomeCards),
      ),
    );
    final hiddenTiles = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeKeyNumbers),
    );
    final lane = ref.watch(homeSacLaneProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = matchingPreset(layout);

    void save(HomeLayout next) => notifier.setHomePanelLayout(
      order: next.orderNames,
      hidden: next.hiddenNames,
    );

    Future<void> pick(HomeLayoutPreset preset) async {
      if (current == preset) return;
      if (current == null) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.settings_homeLayout_replaceTitle),
            content: Text(
              l10n.settings_homeLayout_replaceMessage(
                homePresetLabel(l10n, preset),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.settings_homeCards_resetDialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.settings_homeLayout_replace),
              ),
            ],
          ),
        );
        if (replace != true) return;
      }
      save(homeLayoutForPreset(preset));
    }

    Widget sectionHeader(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    Widget sectionDescription(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    String chipName(HomeChipType type) => switch (type) {
      HomeChipType.gear => l10n.settings_homeChips_gear,
      HomeChipType.insurance => l10n.settings_homeChips_insurance,
      HomeChipType.noFly => l10n.settings_homeChips_noFly,
      HomeChipType.lastDive => l10n.settings_homeChips_lastDive,
      HomeChipType.certifications => l10n.settings_homeChips_certifications,
      HomeChipType.trip => l10n.settings_homeChips_trip,
      HomeChipType.checklist => l10n.settings_homeChips_checklist,
      HomeChipType.course => l10n.settings_homeChips_course,
      HomeChipType.uploads => l10n.settings_homeChips_uploads,
      HomeChipType.backup => l10n.settings_homeChips_backup,
      HomeChipType.sync => l10n.settings_homeChips_sync,
      HomeChipType.nearby => l10n.settings_homeChips_nearby,
      HomeChipType.dataQuality => l10n.settings_homeChips_dataQuality,
      HomeChipType.flightWindow => l10n.settings_homeChips_flightWindow,
      HomeChipType.documents => l10n.settings_homeChips_documents,
    };

    final tilesShown = KeyNumbersPanel.enabledTiles(hiddenTiles).length;

    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: sectionHeader(l10n.settings_homeLayout_sectionTitle),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LayoutBuilder(
              builder: (context, box) {
                final perRow = box.maxWidth < 360 ? 2 : 4;
                final width = (box.maxWidth - 8 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in HomeLayoutPreset.values)
                      SizedBox(
                        width: width,
                        child: HomePresetTile(
                          key: Key('homePreset_${p.name}'),
                          preset: p,
                          selected: current == p,
                          onTap: () => pick(p),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: sectionDescription(l10n.settings_homeLayout_description),
        ),
        SliverToBoxAdapter(
          child: sectionHeader(l10n.settings_homePanels_sectionTitle),
        ),
        SliverReorderableList(
          itemCount: layout.order.length,
          proxyDecorator: (child, index, animation) =>
              Material(elevation: 4, child: child),
          // onReorderItem pre-adjusts newIndex for the removed item, so no
          // manual decrement is needed (unlike the deprecated onReorder).
          onReorderItem: (oldIndex, newIndex) {
            final updated = List.of(layout.order);
            final moved = updated.removeAt(oldIndex);
            updated.insert(newIndex, moved);
            save(layout.withOrder(updated));
          },
          itemBuilder: (context, index) {
            final panel = layout.order[index];
            final visible = !layout.hidden.contains(panel);
            final keyNumbers = panel == HomePanelType.keyNumbers;
            return _PanelTile(
              key: Key('homePanelTile_${panel.name}'),
              index: index,
              name: homePanelLabel(l10n, panel, lane: lane),
              subtitle: keyNumbers
                  ? l10n.settings_homePanels_keyNumbersCount(
                      tilesShown,
                      HomeKeyNumber.values.length,
                    )
                  : homePanelSpec(panel).conditional
                  ? l10n.settings_homeCards_autoHides
                  : null,
              visible: visible,
              toggleKey: Key('homePanelToggle_${panel.name}'),
              onToggle: (enabled) =>
                  save(layout.withPanelEnabled(panel, enabled)),
              onOpen: keyNumbers
                  ? () => context.push('/settings/appearance/home/key-numbers')
                  : null,
            );
          },
        ),
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                key: const Key('homePanelsReset'),
                icon: const Icon(Icons.restore),
                label: Text(l10n.settings_homeCards_resetToDefault),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.settings_homeCards_resetDialog_title),
                      content: Text(l10n.settings_homePanels_resetMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            l10n.settings_homeCards_resetDialog_cancel,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            l10n.settings_homeCards_resetDialog_confirm,
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok ?? false) {
                    save(homeLayoutForPreset(HomeLayoutPreset.balanced));
                  }
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 24)),
        SliverToBoxAdapter(
          child: sectionHeader(l10n.settings_homeChips_sectionTitle),
        ),
        SliverToBoxAdapter(
          child: sectionDescription(l10n.settings_homeChips_description),
        ),
        SliverList.list(
          children: [
            for (final type in HomeChipType.values)
              SwitchListTile(
                key: Key('homeChipToggle_${type.name}'),
                title: Text(chipName(type)),
                value: !hiddenChips.contains(type.name),
                onChanged: (enabled) =>
                    notifier.setHomeChipEnabled(type.name, enabled),
              ),
          ],
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_homeChips_pageTitle)),
      body: content,
    );
  }
}

/// One preset in the layout picker: a thumbnail drawn from the preset's own
/// rows at desktop width, and its name.
class HomePresetTile extends StatelessWidget {
  final HomeLayoutPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const HomePresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = packHomeRows(
      homePresetPanels(preset),
      HomeWidthTier.desktop,
    ).take(4).toList();
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Column(
                    children: [
                      for (final row in rows)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              // Stretch: the bars have no child, so they
                              // take the row's height only when told to.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < row.units.length; i++)
                                  Expanded(
                                    flex: row.units[i],
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 2,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(
                                            1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  homePresetLabel(context.l10n, preset),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One reorderable row in the Panels section: drag handle, name, a hint for
/// panels that hide themselves when empty, and a visibility switch. Key
/// numbers also opens its own page of tiles.
class _PanelTile extends StatelessWidget {
  const _PanelTile({
    super.key,
    required this.index,
    required this.name,
    required this.subtitle,
    required this.visible,
    required this.toggleKey,
    required this.onToggle,
    required this.onOpen,
  });

  final int index;
  final String name;
  final String? subtitle;
  final bool visible;
  final Key toggleKey;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1.0 : 0.5,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(name),
        subtitle: subtitle == null ? null : Text(subtitle!),
        onTap: onOpen,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpen != null) const Icon(Icons.chevron_right),
            Switch(key: toggleKey, value: visible, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
