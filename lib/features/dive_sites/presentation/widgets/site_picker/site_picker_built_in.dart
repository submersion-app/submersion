import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('SitePickerBuiltIn');

/// Built-in sites within this distance of the anchor are offered without
/// typing, in meters. The same radius the picker's own Nearby section uses.
const sitePickerNearbyRadiusMeters = 50000.0;

/// How many built-in rows show before "Show all".
const _collapsedRows = 5;

/// How many built-in matches a search lists.
const _searchLimit = 50;

/// A search starts this long after the last keystroke.
const _searchDebounce = Duration(milliseconds: 250);

/// A search needs at least this many characters.
const _minSearchLength = 2;

/// The site picker's built-in sites: the catalogue's sites near the dive,
/// offered without typing, and its matches for what the diver typed.
///
/// Kept apart from [SitePickerSheet]'s own state so the sheet stays a
/// readable size. Everything here does nothing unless the sheet was opened
/// with `showBuiltIn`.
mixin SitePickerBuiltIn on ConsumerState<SitePickerSheet> {
  List<CatalogueSite> _nearby = const [];
  List<CatalogueSite> _matches = const [];

  /// The text [_matches] answers; a result for older text is dropped.
  String _matchesQuery = '';
  bool _showAll = false;
  bool _adopting = false;
  bool _adoptFailed = false;
  Timer? _debounce;
  ProviderSubscription<int>? _revision;

  /// The point "near here" is measured from, or null when none is known.
  GeoPoint? get builtInAnchor;

  /// Whether [builtInAnchor] was inferred from another dive rather than
  /// measured: such a list goes by name, with no distances.
  bool get builtInAnchorIsInferred;

  /// The place the anchor names ("Bonaire"), when it names one.
  String? get builtInPlaceLabel;

  /// The trimmed text in the search field.
  String get builtInQuery;

  /// Formats a distance in meters for a row.
  String formatBuiltInDistance(double meters);

  bool get _enabled => widget.showBuiltIn;

  /// Call from `initState`.
  void initBuiltIn() {
    if (!_enabled) return;
    // The catalogue is imported after the first frame of an app run: a
    // picker opened before that fills in when the import lands.
    _revision = ref.listenManual(siteCatalogueRevisionProvider, (_, _) {
      unawaited(loadBuiltInNearby());
      _search(builtInQuery);
    });
    unawaited(loadBuiltInNearby());
  }

  /// Call from `dispose`.
  void disposeBuiltIn() {
    _debounce?.cancel();
    _revision?.close();
  }

  /// Reads the built-in sites around the anchor. Call again when the
  /// anchor changes (a device fix arriving).
  Future<void> loadBuiltInNearby() async {
    final anchor = builtInAnchor;
    if (!_enabled || anchor == null) return;
    final sites = await ref
        .read(siteCatalogueProvider)
        .near(anchor, radiusMeters: sitePickerNearbyRadiusMeters);
    if (!mounted || anchor != builtInAnchor) return;
    setState(() => _nearby = sites);
  }

  /// Call when the search text changes.
  void onBuiltInQueryChanged() {
    if (!_enabled) return;
    _debounce?.cancel();
    final query = builtInQuery;
    if (query.length < _minSearchLength) {
      if (_matches.isNotEmpty || _matchesQuery.isNotEmpty) {
        setState(() {
          _matches = const [];
          _matchesQuery = '';
        });
      }
      return;
    }
    _debounce = Timer(_searchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!_enabled || query.length < _minSearchLength) return;
    final sites = await ref
        .read(siteCatalogueProvider)
        .search(query, areaFirst: builtInAnchor, limit: _searchLimit);
    // The diver typed on while this was out: a newer search is coming.
    if (!mounted || query != builtInQuery) return;
    setState(() {
      _matches = sites;
      _matchesQuery = query;
    });
  }

  /// The built-in sites worth offering now: matches for the search text
  /// when there is one, else the sites around the anchor.
  ///
  /// A search skips the position rule, so a site looked up by name can
  /// always be reached; the by-area list applies it.
  List<CatalogueSite> offeredBuiltIn(List<DiveSite> userSites) {
    if (!_enabled) return const [];
    if (builtInQuery.isNotEmpty) {
      if (_matchesQuery != builtInQuery) return const [];
      return offerableCatalogueSites(_matches, userSites, byPosition: false);
    }
    final offered = offerableCatalogueSites(
      _nearby,
      userSites,
      byPosition: true,
    );
    if (builtInAnchorIsInferred) {
      // [_nearby] arrives nearest first; an inferred area goes by name.
      return [...offered]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return offered;
  }

  /// The built-in section as list rows: its label, its sites, and "Show
  /// all" when there are more than fit. Empty when nothing is offered.
  List<Widget Function()> builtInRows(List<DiveSite> userSites) {
    final offered = offeredBuiltIn(userSites);
    if (offered.isEmpty) return const [];

    final l10n = context.l10n;
    final searching = builtInQuery.isNotEmpty;
    final place = builtInAnchorIsInferred ? builtInPlaceLabel : null;
    final label = searching
        ? l10n.diveSites_picker_builtIn_search
        : place != null
        ? l10n.diveSites_picker_builtIn_nearPlace(place)
        : l10n.diveSites_picker_builtIn_nearby;

    // A search already narrowed the list; only the by-area list collapses.
    final collapsed =
        !searching && !_showAll && offered.length > _collapsedRows;
    final shown = collapsed ? offered.take(_collapsedRows) : offered;
    final anchor = builtInAnchor;
    final showDistance = !builtInAnchorIsInferred && anchor != null;

    return [
      () => SiteSectionLabel(label),
      if (_adoptFailed)
        () => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            l10n.diveSites_picker_builtIn_adoptError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      for (final site in shown)
        () => CatalogueSiteTile(
          site: site,
          distanceText: showDistance && site.location != null
              ? formatBuiltInDistance(distanceMeters(anchor, site.location!))
              : null,
          onTap: _adopting ? null : () => unawaited(_adopt(site, userSites)),
          onDetails: () => unawaited(
            showCatalogueSiteDetails(
              context,
              site: site,
              actionLabel: l10n.diveSites_picker_builtIn_useSite,
              onAction: () => _adopt(site, userSites),
            ),
          ),
        ),
      if (collapsed)
        () => ListTile(
          leading: const SizedBox(width: 40),
          title: Text(l10n.diveSites_picker_builtIn_showAll(offered.length)),
          textColor: Theme.of(context).colorScheme.primary,
          onTap: () => setState(() => _showAll = true),
        ),
    ];
  }

  /// Whether the built-in section shows sites around an anchor now, so the
  /// header can say what the list is sorted by.
  bool hasBuiltInNearby(List<DiveSite> userSites) =>
      builtInQuery.isEmpty && offeredBuiltIn(userSites).isNotEmpty;

  /// Adopts [site] and hands the diver's new site to the picker's caller,
  /// exactly as tapping one of their own sites does.
  Future<void> _adopt(CatalogueSite site, List<DiveSite> userSites) async {
    if (_adopting) return;
    setState(() {
      _adopting = true;
      _adoptFailed = false;
    });
    // Read now: adopting a built-in site is creating a site by hand
    // (#3513), and it gets its rules even if the sheet closes meanwhile.
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    final adopt = ref.read(catalogueSiteAdopterProvider);
    final repository = ref.read(siteRepositoryProvider);
    // A site the diver already had is handed back as it is: nothing was
    // created, so no rules run.
    final alreadyTheirs = linkedCatalogueIds(userSites).contains(site.id);
    try {
      final adopted = await adopt(site);
      if (!alreadyTheirs) {
        // Before the dive form takes the site, so it gets the site's
        // values as the rules left them.
        await rulesAfterCreate(subject: RuleSubject.sites, ids: [adopted.id]);
      }
      var result = adopted;
      try {
        result = await repository.getSiteById(adopted.id) ?? adopted;
      } catch (error, stackTrace) {
        // The site exists; only this fresher read failed.
        _log.warning(
          'Could not re-read adopted site ${adopted.id}',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) return;
      setState(() => _adopting = false);
      widget.onSiteSelected(result);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not adopt catalogue site ${site.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      // Said inside the sheet: a snackbar would sit behind it.
      setState(() {
        _adopting = false;
        _adoptFailed = true;
      });
    }
  }
}
