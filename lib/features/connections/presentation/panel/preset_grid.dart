import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/save_map_dialog.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String presetLabel(AppLocalizations l10n, String id) => switch (id) {
  'circle' => l10n.connections_preset_circle,
  'where' => l10n.connections_preset_where,
  'trips' => l10n.connections_preset_trips,
  'life' => l10n.connections_preset_life,
  'gear' => l10n.connections_preset_gear,
  'centers' => l10n.connections_preset_centers,
  'travel' => l10n.connections_preset_travel,
  'reef' => l10n.connections_preset_reef,
  'gearRoad' => l10n.connections_preset_gearRoad,
  _ => id,
};

class PresetGrid extends ConsumerWidget {
  const PresetGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(connectionsViewProvider);
    final saved = ref.watch(savedConnectionMapsProvider).value ?? const [];
    final notifier = ref.read(connectionsViewProvider.notifier);
    final cards = <Widget>[
      for (final p in ConnectionPresets.all)
        _MapCard(
          key: ValueKey('preset-${p.id}'),
          label: presetLabel(l10n, p.id),
          kinds: p.spec.kinds,
          selected: view.presetId == p.id,
          edited: view.editedFromPresetId == p.id,
          onTap: () => notifier.update((s) => s.applyPreset(p)),
        ),
      for (final m in saved)
        _MapCard(
          key: ValueKey('saved-map-${m.id}'),
          label: m.name,
          kinds: m.spec.kinds,
          selected: view.savedMapId == m.id,
          edited: false,
          saved: true,
          onTap: () => notifier.update((s) => s.applySavedMap(m.id, m.spec)),
          menu: _SavedMapMenu(map: m),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connections_presets_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 6) / 2;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in cards) SizedBox(width: width, child: c),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    super.key,
    required this.label,
    required this.kinds,
    required this.selected,
    required this.edited,
    required this.onTap,
    this.saved = false,
    this.menu,
  });

  final String label;
  final Set<ConnectionKind> kinds;
  final bool selected;
  final bool edited;
  final bool saved;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final k in sorted)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsetsDirectional.only(end: 3),
                            decoration: BoxDecoration(
                              color: colors.colorFor(k),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (saved)
                          Icon(
                            Icons.bookmark,
                            size: 12,
                            semanticLabel:
                                context.l10n.connections_savedMap_badge,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (edited)
                      Text(
                        context.l10n.connections_preset_edited,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              ?menu,
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMapMenu extends ConsumerWidget {
  const _SavedMapMenu({required this.map});

  final SavedConnectionMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (value) async {
        final repo = ref.read(connectionMapRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);
        try {
          switch (value) {
            case 'rename':
              final name = await showSaveMapDialog(
                context,
                title: l10n.connections_savedMap_rename,
                initialName: map.name,
              );
              if (name != null) await repo.rename(map.id, name);
            case 'update':
              final spec = ref.read(connectionsViewProvider).mapSpec;
              await repo.updateSpec(map.id, spec);
              // The map now holds what is on screen, so its card is the
              // current view again.
              await ref
                  .read(connectionsViewProvider.notifier)
                  .update((s) => s.applySavedMap(map.id, spec));
            case 'delete':
              await repo.delete(map.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.connections_savedMap_deleted(map.name)),
                  action: SnackBarAction(
                    label: l10n.connections_savedMap_undo,
                    onPressed: () => repo.restore(map),
                  ),
                ),
              );
          }
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.common_error_tryAgain)),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Text(l10n.connections_savedMap_rename),
        ),
        PopupMenuItem(
          value: 'update',
          child: Text(l10n.connections_savedMap_update),
        ),
        PopupMenuItem(value: 'delete', child: Text(l10n.common_action_delete)),
      ],
    );
  }
}
