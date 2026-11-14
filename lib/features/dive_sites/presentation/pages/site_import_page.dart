import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_search_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_import_site_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// Page for searching and importing dive sites from online sources.
class SiteImportPage extends ConsumerStatefulWidget {
  const SiteImportPage({super.key});

  @override
  ConsumerState<SiteImportPage> createState() => _SiteImportPageState();
}

class _SiteImportPageState extends ConsumerState<SiteImportPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(externalSiteSearchProvider.notifier).search(query);
    }
  }

  Future<void> _importSite(CatalogueSite site) async {
    final notifier = ref.read(externalSiteSearchProvider.notifier);
    // Read now: importing a site from the search is creating it by hand
    // (#3513), and it gets its rules even if the diver leaves meanwhile.
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    final adoption = await notifier.importSite(site);
    final importedSite = adoption?.site;

    if (mounted) {
      if (importedSite != null) {
        // The notifier marks the site as the diver's; no page state needed.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveSites_import_snackbar_imported(site.name),
            ),
            persist: false,
            action: SnackBarAction(
              label: context.l10n.diveSites_import_snackbar_viewAction,
              onPressed: () {
                context.push('/sites/${importedSite.id}');
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveSites_import_snackbar_failed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
    // Only a site this import created: one the diver already had may have
    // been edited since, and the rules would undo that.
    if (adoption != null && adoption.created) {
      await rulesAfterCreate(
        subject: RuleSubject.sites,
        ids: [adoption.site.id],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(externalSiteSearchProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diveSites_import_appBar_title)),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: context.l10n.diveSites_import_search_hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip:
                            context.l10n.diveSites_import_search_clearTooltip,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(externalSiteSearchProvider.notifier).clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
          ),

          // Quick search chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickSearchChip(
                    label: context.l10n.diveSites_import_quickSearch_caribbean,
                    onTap: () {
                      _searchController.text = 'Caribbean';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: context.l10n.diveSites_import_quickSearch_redSea,
                    onTap: () {
                      _searchController.text = 'Red Sea';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: context.l10n.diveSites_import_quickSearch_thailand,
                    onTap: () {
                      _searchController.text = 'Thailand';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: context.l10n.diveSites_import_quickSearch_indonesia,
                    onTap: () {
                      _searchController.text = 'Indonesia';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: context.l10n.diveSites_import_quickSearch_maldives,
                    onTap: () {
                      _searchController.text = 'Maldives';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label:
                        context.l10n.diveSites_import_quickSearch_philippines,
                    onTap: () {
                      _searchController.text = 'Philippines';
                      _onSearch();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results or placeholder
          Expanded(child: _buildContent(searchState, theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildContent(
    ExternalSiteSearchState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final units = ref.watch(unitFormatterProvider);

    // Error state
    if (state.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveSites_import_error_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ??
                    context.l10n.diveSites_import_error_unknown,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _onSearch,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.diveSites_import_error_retry),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state (no search yet)
    if (state.query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.travel_explore,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.diveSites_import_empty_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.diveSites_import_empty_description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveSites_import_empty_hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No results
    if (!state.hasResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveSites_import_noResults_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.diveSites_import_noResults_description(
                  state.query,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Results list with local sites first, then external sites
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Local sites section (from user's database)
        if (state.hasLocalResults) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.folder, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_import_section_mySites(
                    state.localSites.length,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...state.localSites.map((site) => _LocalSiteCard(site: site)),
          const SizedBox(height: 16),
        ],

        // External sites section (from bundled database / API)
        if (state.hasExternalResults) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.public, size: 20, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_import_section_importFromDatabase(
                    state.sites.length,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          // The list stops at a fixed number of sites: say so, or a site
          // whose name sorts late looks as if the catalogue lacks it.
          if (state.isTruncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.l10n.diveSites_import_section_truncated(
                  state.sites.length,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...state.sites.map((site) {
            // Already one of the diver's sites, in this session or any
            // earlier one: the link says so.
            final isImported = state.linkedCatalogueIds.contains(site.id);
            return CatalogueImportSiteCard(
              site: site,
              isImported: isImported,
              units: units,
              onImport: () => _importSite(site),
            );
          }),
        ],
      ],
    );
  }
}

class _QuickSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ActionChip(label: Text(label), onPressed: onTap),
    );
  }
}

/// Card for displaying a local site from the user's database.
class _LocalSiteCard extends StatelessWidget {
  final DiveSite site;

  const _LocalSiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Semantics(
        button: true,
        label: context.l10n.diveSites_import_semantics_viewSavedSite(site.name),
        child: InkWell(
          onTap: () => context.push('/sites/${site.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location icon with checkmark
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.place, color: colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),

                // Site info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildLocationText() ??
                            context
                                .l10n
                                .diveSites_import_localSite_locationNotSet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (site.maxDepth != null || site.location != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (site.maxDepth != null) ...[
                              Icon(
                                Icons.arrow_downward,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${site.maxDepth!.toStringAsFixed(0)}m',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (site.location != null) ...[
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.diveSites_import_label_gps,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Already saved indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 16, color: colorScheme.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.diveSites_import_badge_saved,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _buildLocationText() {
    final parts = <String>[];
    if (site.region != null && site.region!.isNotEmpty) {
      parts.add(site.region!);
    }
    if (site.country != null && site.country!.isNotEmpty) {
      parts.add(site.country!);
    }
    return parts.isNotEmpty ? parts.join(', ') : null;
  }
}
