import 'package:flutter/material.dart';

import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How many register records the opened section lists: the nearest ones.
/// Past that the diver is told to search.
const sitePickerRegisterListLimit = 200;

/// The site picker's section for register records: the catalogue's charted
/// wrecks and reef deployments around the dive.
///
/// There are many times more of these than dive sites (hundreds within
/// reach of some harbours), so they are kept out of "More sites near" and
/// shown as a count until the diver opens them. Only the count is read
/// until then.
///
/// Owned by the picker's built-in mixin, which tells it when the anchor or
/// the catalogue changes and asks it for its rows.
class SitePickerRegisterSection {
  SitePickerRegisterSection({
    required SiteCatalogue Function() catalogue,
    required void Function(VoidCallback) setState,
    required bool Function() isMounted,
    required GeoPoint? Function() currentAnchor,
    required double radiusMeters,
  }) : _catalogue = catalogue,
       _setState = setState,
       _isMounted = isMounted,
       _currentAnchor = currentAnchor,
       _radiusMeters = radiusMeters;

  final SiteCatalogue Function() _catalogue;
  final void Function(VoidCallback) _setState;
  final bool Function() _isMounted;
  final GeoPoint? Function() _currentAnchor;
  final double _radiusMeters;

  int _count = 0;
  bool _open = false;
  List<CatalogueSite> _sites = const [];

  /// Whether the diver opened the section and it read records to show
  /// (rows, or the note that all of them are already the diver's).
  bool get isOpen => _open && _sites.isNotEmpty;

  /// Counts the register records around [anchor], and reads them again if
  /// the section is open. Call when the anchor or the catalogue changes.
  Future<void> load(GeoPoint anchor) async {
    final catalogue = _catalogue();
    final count = await catalogue.countNear(
      anchor,
      radiusMeters: _radiusMeters,
      kind: CatalogueKind.register,
    );
    final sites = _open
        ? await _read(catalogue, anchor)
        : const <CatalogueSite>[];
    if (!_isMounted() || anchor != _currentAnchor()) return;
    _setState(() {
      _count = count;
      _sites = sites;
    });
  }

  Future<List<CatalogueSite>> _read(SiteCatalogue catalogue, GeoPoint anchor) =>
      catalogue.near(
        anchor,
        radiusMeters: _radiusMeters,
        limit: sitePickerRegisterListLimit,
        kind: CatalogueKind.register,
      );

  Future<void> _openSection(GeoPoint anchor) async {
    final sites = await _read(_catalogue(), anchor);
    if (!_isMounted() || anchor != _currentAnchor()) return;
    _setState(() {
      _open = true;
      _sites = sites;
    });
  }

  /// The section as list rows: its label, then one row with the count, or
  /// the records once it is opened. Empty when no register record is in
  /// reach of [anchor].
  ///
  /// The count is of every record in reach; the rows leave out the ones
  /// the diver adopted and the ones a site of theirs already sits on.
  List<Widget Function()> rows(
    BuildContext context, {
    required List<DiveSite> userSites,
    required GeoPoint? anchor,
    required bool anchorIsInferred,
    required String? placeLabel,
    required String Function(double meters) formatDistance,
    required bool busy,
    required void Function(CatalogueSite site) onTap,
    required void Function(CatalogueSite site) onDetails,
  }) {
    if (anchor == null || _count == 0) return const [];
    final l10n = context.l10n;
    final place = anchorIsInferred ? placeLabel : null;
    final label = place != null
        ? l10n.diveSites_picker_register_nearPlace(place)
        : l10n.diveSites_picker_register_nearby;

    if (!_open) {
      return [
        () => SiteSectionLabel(label),
        () => ListTile(
          leading: const SizedBox(width: 40),
          title: Text(l10n.diveSites_picker_register_show(_count)),
          textColor: Theme.of(context).colorScheme.primary,
          onTap: busy ? null : () => _openSection(anchor),
        ),
      ];
    }

    var offered = offerableCatalogueSites(_sites, userSites, byPosition: true);
    if (anchorIsInferred) {
      // The records arrive nearest first; an inferred area goes by name,
      // as the dive site section above does.
      offered = [...offered]
        ..sort((a, b) => compareTextForSort(a.name, b.name));
    }
    if (offered.isEmpty) {
      // Every record read is one the diver adopted or already has a site
      // on: the count promised rows, so say where they went. Past the cap
      // only the nearest were read, and the rest may not be the diver's.
      final capped = _count > sitePickerRegisterListLimit;
      return [
        () => SiteSectionLabel(label),
        () => Padding(
          padding: const EdgeInsets.fromLTRB(72, 8, 16, 16),
          child: Text(
            capped
                ? l10n.diveSites_picker_register_nearestYours(
                    sitePickerRegisterListLimit,
                  )
                : l10n.diveSites_picker_register_allYours,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    return [
      () => SiteSectionLabel(label),
      for (final site in offered)
        () => CatalogueSiteTile(
          site: site,
          distanceText: !anchorIsInferred && site.location != null
              ? formatDistance(distanceMeters(anchor, site.location!))
              : null,
          onTap: busy ? null : () => onTap(site),
          onDetails: busy ? null : () => onDetails(site),
        ),
      if (_count > sitePickerRegisterListLimit)
        () => Padding(
          padding: const EdgeInsets.fromLTRB(72, 8, 16, 16),
          child: Text(
            l10n.diveSites_picker_register_capped(sitePickerRegisterListLimit),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }
}
