import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/built_in_site_adoption.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_overlay_view.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What both Sites maps do with the built-in catalogue: draw its layers,
/// hold the record whose pin was tapped, show that record's card, and add
/// it to the diver's sites.
///
/// The phone's map page and the split pane's map are two widgets with one
/// behaviour here, so it is written once.
///
/// The selection is held by the map and not in the shared list selection,
/// which is keyed to the diver's own sites.
mixin BuiltInMapSelection<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  CatalogueSite? _selectedBuiltIn;

  /// The id of the built-in record whose pin is selected, or null.
  String? get selectedBuiltInId => _selectedBuiltIn?.id;

  /// Selects [site]'s pin, or with null clears the selection.
  void selectBuiltIn(CatalogueSite? site) {
    if (_selectedBuiltIn?.id == site?.id) return;
    setState(() => _selectedBuiltIn = site);
  }

  /// Keeps a card from outliving its pin. Call from `build`.
  ///
  /// (A record the catalogue no longer holds is cleared where its card is
  /// built, in [buildBuiltInInfoCard], which is where that is read.)
  ///
  /// The selection is cleared when the layer its record belongs to is
  /// turned off, and when the diver's sites come to hide the record's pin,
  /// by the same two rules that hide it on the map: the record becomes the
  /// diver's own (added from this map, from its page, or by a sync), or a
  /// site they made by hand sits on it.
  /// Listens, and never watches, so the map does not rebuild on a switch:
  /// a rebuild would recreate the `FlutterMap`.
  void listenForBuiltInSelectionReset() {
    ref.listen<BuiltInMapLayers>(builtInMapLayersNotifierProvider, (_, layers) {
      final selected = _selectedBuiltIn;
      if (selected != null && !layers.shows(selected.kind)) {
        selectBuiltIn(null);
      }
    });
    ref.listen(sitesWithCountsProvider, (_, next) {
      final selected = _selectedBuiltIn;
      final sites = next.value;
      if (selected == null || sites == null) return;
      final stillOffered = offerableCatalogueSites(
        [selected],
        [for (final entry in sites) entry.site],
        byPosition: true,
      );
      if (stillOffered.isEmpty) selectBuiltIn(null);
    });
  }

  /// The built-in layers of the map, beneath the diver's own markers: the
  /// reporter that tells the providers what the map shows, and the pins
  /// of the layers that are on. [onTap] runs after a pin is selected, for
  /// the map to clear its own selection and move its camera.
  List<Widget> builtInMapLayers({
    required void Function(CatalogueSite site) onTap,
  }) => [
    const BuiltInOverlayBoundsReporter(),
    Consumer(
      builder: (context, ref, _) {
        // The last sites stay up while a moved map reads the next. With
        // every layer off the list is empty.
        final builtIn = ref.watch(visibleBuiltInSitesProvider).value;
        if (builtIn == null || builtIn.isEmpty) return const SizedBox.shrink();
        return BuiltInSiteMarkerLayer(
          sites: builtIn,
          selectedCatalogueId: selectedBuiltInId,
          onTap: (site) {
            selectBuiltIn(site);
            onTap(site);
          },
        );
      },
    ),
  ];

  /// The selected record's card, or null with no selection.
  Widget? buildBuiltInInfoCard(BuildContext context) {
    final selected = _selectedBuiltIn;
    if (selected == null) return null;
    // The record as the map draws it now. Off the map (moved out of view),
    // as the catalogue holds it, so the card stays while the map moves.
    final onMap = ref
        .watch(visibleBuiltInSitesProvider)
        .value
        ?.where((s) => s.id == selected.id)
        .firstOrNull;
    final held = onMap == null
        ? ref.watch(catalogueSiteProvider(selected.id))
        : null;
    if (held != null &&
        held.hasValue &&
        !held.isLoading &&
        held.value == null) {
      // The catalogue has answered, and no longer holds the record (a new
      // catalogue dropped it): there is nothing to show or to add. Cleared
      // after this frame, since a build cannot change the selection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedBuiltIn?.id == selected.id) {
          selectBuiltIn(null);
        }
      });
      return null;
    }
    // Still being read, or the read failed: the record as it was tapped.
    final site = onMap ?? held?.value ?? selected;
    return BuiltInSiteInfoCard(
      site: site,
      actionLabel: context.l10n.diveSites_map_builtInSites_add,
      onAction: () => addBuiltInSite(site),
      onDetails: () => context.push(catalogueSitePath(site.id)),
    );
  }

  /// Adds [site] to the diver's sites and says so (`adoptBuiltInSite`).
  Future<void> addBuiltInSite(CatalogueSite site) => adoptBuiltInSite(
    context,
    ref,
    site,
    // The record is the diver's now: its pin goes, and its card with it.
    onAdopted: (_) {
      if (mounted) selectBuiltIn(null);
    },
  );
}

/// The card a Sites map shows a diver who has no site with coordinates.
///
/// Only when every built-in layer is off. With a layer on that diver sees
/// built-in pins, and a card over the middle of the map would hide them.
class SitesMapEmptyCard extends ConsumerWidget {
  const SitesMapEmptyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anyLayer = ref.watch(
      builtInMapLayersNotifierProvider.select((layers) => layers.any),
    );
    if (anyLayer) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveSites_map_empty_title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.diveSites_map_empty_description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
