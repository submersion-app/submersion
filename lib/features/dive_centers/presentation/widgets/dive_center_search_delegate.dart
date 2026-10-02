import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Search delegate for dive centers
class DiveCenterSearchDelegate extends SearchDelegate<DiveCenter?> {
  final WidgetRef ref;

  DiveCenterSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.diveCenters_tooltip_clearSearch,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.common_action_back,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    return DebouncedSearchResults<DiveCenter>(
      query: query,
      watchProvider: (ref, q) => ref.watch(diveCenterSearchProvider(q)),
      dataBuilder: (context, centers) {
        return ListView.builder(
          itemCount: centers.length,
          itemBuilder: (context, index) {
            final center = centers[index];
            return ListTile(
              leading: Builder(
                builder: (context) {
                  final accent = resolveFeatureAccent(
                    context,
                    ref,
                    surface: AccentSurface.list,
                    featureId: 'dive-centers',
                  );
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          accent?.withValues(alpha: 0.15) ??
                          Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.store,
                      color:
                          accent ??
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                },
              ),
              title: Text(center.name),
              subtitle: center.fullLocationString != null
                  ? Text(center.fullLocationString!)
                  : null,
              trailing: center.rating != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(center.rating!.toStringAsFixed(1)),
                      ],
                    )
                  : null,
              onTap: () {
                close(context, center);
                context.push('/dive-centers/${center.id}');
              },
            );
          },
        );
      },
      emptyQueryBuilder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveCenters_search_prompt,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      emptyBuilder: (context, query) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveCenters_search_noResults(query),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      errorBuilder: (context, error) {
        return Center(
          child: Text(context.l10n.diveCenters_error_generic(error.toString())),
        );
      },
    );
  }
}
