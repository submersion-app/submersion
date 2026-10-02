import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/save_map_dialog.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Kinds, links and the minimum for a custom whole map, and Save as map.
class MapEditor extends ConsumerStatefulWidget {
  const MapEditor({super.key});

  @override
  ConsumerState<MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends ConsumerState<MapEditor> {
  /// The minimum while its slider is being dragged.
  double? _dragMinimum;

  /// Opens the editor whenever the view becomes a custom map, wherever the
  /// edit came from; `initiallyExpanded` alone covers only the first build.
  final _tile = ExpansibleController();

  @override
  void dispose() {
    _tile.dispose();
    super.dispose();
  }

  void _edit(MapSpec Function(MapSpec) change) => ref
      .read(connectionsViewProvider.notifier)
      .update((s) => s.editMap(change(s.mapSpec)));

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = await showSaveMapDialog(
      context,
      title: l10n.connections_savedMap_saveTitle,
    );
    if (name == null || !mounted) return;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null || !mounted) return;
      final spec = ref.read(connectionsViewProvider).mapSpec;
      final created = await ref
          .read(connectionMapRepositoryProvider)
          .create(diverId: diverId, name: name, spec: spec);
      if (!mounted) return;
      await ref
          .read(connectionsViewProvider.notifier)
          .update((s) => s.applySavedMap(created.id, spec));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    ref.listen<bool>(
      connectionsViewProvider.select(
        (s) => s.presetId == null && s.savedMapId == null,
      ),
      (wasCustom, isCustom) {
        if (isCustom && wasCustom != true) _tile.expand();
      },
    );
    final view = ref.watch(connectionsViewProvider);
    final spec = view.mapSpec;
    final colors = ConnectionKindColors.of(context);
    final minimum = _dragMinimum ?? spec.minSharedDives.toDouble();
    return ExpansionTile(
      controller: _tile,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: view.presetId == null && view.savedMapId == null,
      title: Text(
        l10n.connections_editor_title,
        style: theme.textTheme.labelLarge,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_editor_kinds, style: theme.textTheme.labelMedium),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final k in ConnectionKind.values)
              FilterChip(
                key: ValueKey('kind-chip-${k.name}'),
                avatar: CircleAvatar(
                  backgroundColor: colors.colorFor(k),
                  radius: 5,
                ),
                label: Text(kindLabel(l10n, k)),
                selected: spec.kinds.contains(k),
                onSelected: (on) =>
                    _edit((s) => on ? s.withKind(k) : s.withoutKind(k)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.connections_editor_links, style: theme.textTheme.labelMedium),
        for (final link in spec.possibleLinks)
          CheckboxListTile(
            key: ValueKey('link-${link.wire}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: spec.links.contains(link),
            title: Text(
              l10n.connections_editor_link(
                kindLabel(l10n, link.a),
                kindLabel(l10n, link.b),
              ),
            ),
            onChanged: (_) => _edit((s) => s.toggleLink(link)),
          ),
        const SizedBox(height: 8),
        Text(l10n.connections_editor_minShared(minimum.round())),
        Slider(
          key: const ValueKey('min-shared-slider'),
          min: MapSpec.minMinimum.toDouble(),
          max: MapSpec.maxMinimum.toDouble(),
          divisions: MapSpec.maxMinimum - MapSpec.minMinimum,
          value: minimum,
          label: '${minimum.round()}',
          onChanged: (v) => setState(() => _dragMinimum = v),
          onChangeEnd: (v) {
            setState(() => _dragMinimum = null);
            _edit((s) => s.withMinimum(v.round()));
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('save-as-map'),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(l10n.connections_editor_saveAsMap),
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
