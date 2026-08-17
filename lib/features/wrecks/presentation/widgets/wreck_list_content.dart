import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The catalogue list: search plus one row per wreck. Selection is owned
/// by the host (the master-detail scaffold), so this widget only reports
/// taps upward.
class WreckListContent extends ConsumerStatefulWidget {
  final String? selectedId;

  /// Nullable id: the scaffold's contract allows clearing the selection.
  final void Function(String? id) onWreckSelected;
  final VoidCallback onAddWreck;

  const WreckListContent({
    super.key,
    this.selectedId,
    required this.onWreckSelected,
    required this.onAddWreck,
  });

  @override
  ConsumerState<WreckListContent> createState() => _WreckListContentState();
}

class _WreckListContentState extends ConsumerState<WreckListContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wrecksAsync = ref.watch(wrecksProvider);
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const ValueKey('wreckSearchField'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.wrecks_field_name,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: wrecksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (wrecks) {
              final filtered = _query.isEmpty
                  ? wrecks
                  : wrecks
                        .where((w) => w.name.toLowerCase().contains(_query))
                        .toList();
              if (filtered.isEmpty) return _empty(context);
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final w = filtered[i];
                  return _row(context, w, unitInMeters, depthUnit.symbol);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    Wreck wreck,
    double unitInMeters,
    String symbol,
  ) {
    final l10n = context.l10n;
    final subtitle = [
      wreckVesselTypeLabel(l10n, wreck.vesselTypeName),
      wreckMeasure(wreck.depthToDeckMeters, unitInMeters, symbol),
    ].where((s) => s.isNotEmpty).join(' • ');
    return ListTile(
      key: ValueKey('wreckRow-${wreck.id}'),
      selected: wreck.id == widget.selectedId,
      leading: const Icon(Icons.sailing),
      title: Text(wreck.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => widget.onWreckSelected(wreck.id),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sailing_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.wrecks_empty_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.wrecks_empty_body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('wreckAddButton'),
              icon: const Icon(Icons.add),
              label: Text(l10n.wrecks_add),
              onPressed: widget.onAddWreck,
            ),
          ],
        ),
      ),
    );
  }
}
