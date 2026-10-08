import 'package:flutter/widgets.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));

/// The label to show for a node: built-in species and dive types in the
/// diver's language, everything else as stored.
///
/// Species resolve by id alone: custom species carry a UUID, which never
/// matches a built-in `sp_` slug. Dive types need a guard, because a
/// diver's own type can hold a built-in slug (see `DiveTypeDisplay`): only
/// a row still carrying the built-in English name is translated.
String connectionNodeLabel(AppLocalizations l10n, NodeRef ref, String stored) =>
    switch (ref.kind) {
      ConnectionKind.species => localizedSpeciesName(l10n, ref.id, stored),
      ConnectionKind.diveType =>
        builtInDiveTypeName(_english, ref.id) == stored
            ? (builtInDiveTypeName(l10n, ref.id) ?? stored)
            : stored,
      _ => stored,
    };

/// [graph] with every node label passed through [connectionNodeLabel].
/// Returns [graph] itself when no label changes, so an English log keeps
/// its identity (the page lays out by identity).
ConnectionGraph localizeGraph(ConnectionGraph graph, AppLocalizations l10n) {
  var changed = false;
  final nodes = [
    for (final n in graph.nodes)
      () {
        final label = connectionNodeLabel(l10n, n.ref, n.label);
        if (label == n.label) return n;
        changed = true;
        return n.copyWith(label: label);
      }(),
  ];
  return changed ? graph.copyWith(nodes: nodes) : graph;
}
