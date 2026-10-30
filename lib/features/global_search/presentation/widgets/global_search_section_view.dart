import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One record type's matches: a heading with the total, the first rows, and
/// a way to the rest.
class GlobalSearchSectionView extends ConsumerStatefulWidget {
  const GlobalSearchSectionView({
    super.key,
    required this.section,
    required this.onOpen,
    this.onSeeAll,
  });

  final GlobalSearchSection section;
  final ValueChanged<GlobalSearchHit> onOpen;

  /// Opens the list. Null for a type with no list, which holds every match
  /// already and expands in place.
  final VoidCallback? onSeeAll;

  @override
  ConsumerState<GlobalSearchSectionView> createState() =>
      _GlobalSearchSectionViewState();
}

class _GlobalSearchSectionViewState
    extends ConsumerState<GlobalSearchSectionView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final catalog = ref.watch(certificationCatalogSyncProvider);
    final hits = _expanded
        ? section.hits
        : section.hits.take(kGlobalSearchPreviewLimit);
    final hasMore = section.total > kGlobalSearchPreviewLimit && !_expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    globalSearchKindIcon(section.kind),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    globalSearchKindLabel(l10n, section.kind),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${section.total}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final hit in hits)
          _HitTile(
            key: ValueKey('global-search-hit-${hit.kind.name}-${hit.id}'),
            hit: hit,
            units: units,
            catalog: catalog,
            onTap: () => widget.onOpen(hit),
          ),
        if (hasMore)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: TextButton(
                key: ValueKey('global-search-more-${section.kind.name}'),
                onPressed:
                    widget.onSeeAll ?? () => setState(() => _expanded = true),
                child: Text(l10n.globalSearch_seeAll(section.total)),
              ),
            ),
          ),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({
    super.key,
    required this.hit,
    required this.units,
    required this.catalog,
    required this.onTap,
  });

  final GlobalSearchHit hit;
  final UnitFormatter units;
  final CertificationCatalog catalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = globalSearchHitSubtitle(
      hit,
      l10n,
      units,
      catalog: catalog,
    );
    return ListTile(
      dense: true,
      title: Text(
        globalSearchHitTitle(hit, l10n, units),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
