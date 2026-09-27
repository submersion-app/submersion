import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/connection_labels.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds an entity of any kind by name and centres the view on it.
class EntitySearchField extends ConsumerStatefulWidget {
  const EntitySearchField({super.key});

  @override
  ConsumerState<EntitySearchField> createState() => _EntitySearchFieldState();
}

class _EntitySearchFieldState extends ConsumerState<EntitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final hits = _query.isEmpty
        ? null
        : ref.watch(connectionsSearchProvider(_query));
    // The SQL search matches stored names, which stay English for built-in
    // species and dive types; fold in the ones whose translated name matches.
    final translated = _query.isEmpty ? '' : _translatedMatches(l10n, _query);
    final extra = translated.isEmpty
        ? null
        : ref.watch(connectionsNodesByWireProvider(translated));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('entity-search'),
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.connections_around_searchHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (hits != null)
          if (hits.isLoading || (extra?.isLoading ?? false))
            const LinearProgressIndicator()
          else if (_merge(hits.value, extra?.value) case final nodes)
            nodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l10n.connections_around_noResults),
                  )
                : Column(
                    children: [
                      for (final n in nodes)
                        ListTile(
                          key: ValueKey('search-hit-${n.ref.wire}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: colors.colorFor(n.ref.kind),
                          ),
                          title: Text(
                            connectionNodeLabel(l10n, n.ref, n.label),
                          ),
                          subtitle: Text(
                            '${kindLabel(l10n, n.ref.kind)}, '
                            '${l10n.connections_selection_dives(n.diveCount)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            ref
                                .read(connectionsViewProvider.notifier)
                                .update((s) => s.centreOn(n.ref));
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                  ),
      ],
    );
  }

  /// Wires of built-in species and dive types whose translated name contains
  /// [query] but whose stored name does not (those the SQL search already
  /// finds), sorted and comma-joined so the provider key is stable.
  String _translatedMatches(AppLocalizations l10n, String query) {
    final q = query.toLowerCase();
    bool hit(String translated, String stored) =>
        translated.toLowerCase().contains(q) &&
        !stored.toLowerCase().contains(q);
    final species = ref.watch(allSpeciesProvider).value ?? const [];
    final types = ref.watch(diveTypesProvider).value ?? const [];
    final wires = <String>[
      for (final s in species)
        if (s.isBuiltIn && hit(s.localizedCommonName(l10n), s.commonName))
          NodeRef(ConnectionKind.species, s.id).wire,
      for (final d in types)
        if (d.isBuiltIn && hit(d.localizedName(l10n), d.name))
          NodeRef(ConnectionKind.diveType, d.id).wire,
    ]..sort();
    return wires.take(20).join(',');
  }

  /// Search hits and translated-name hits, without duplicates, busiest
  /// first.
  static List<ConnectionNode> _merge(
    List<ConnectionNode>? hits,
    List<ConnectionNode>? extra,
  ) {
    final byRef = <NodeRef, ConnectionNode>{
      for (final n in [...?hits, ...?extra]) n.ref: n,
    };
    return byRef.values.toList()..sort((a, b) {
      final byDives = b.diveCount.compareTo(a.diveCount);
      return byDives != 0 ? byDives : a.label.compareTo(b.label);
    });
  }
}
