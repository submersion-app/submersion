import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The site's features, edited on the Features card and on the fullscreen
/// map opened from it (issue #4527, phase 2).
///
/// Written at Save, after the site, as the dive's sightings are: a loaded
/// feature dropped and still on the site is deleted, a loaded one changed
/// is updated, and one the sitting placed (an id that was not loaded) is
/// added under an id of the repository's own. A feature stored meanwhile
/// that the sitting never loaded is not touched. The order carries no
/// meaning.
final siteFeaturesList = SittingList<DiveSite, SiteFeature>(
  key: 'site.features',
  cardId: SiteDetailSectionId.features.name,
  read: (site) => SiteFeatureRepository().getFeaturesForSite(site.id),
  write: (site, loaded, current) async {
    final repository = SiteFeatureRepository();
    final loadedById = {for (final f in loaded) f.id: f};
    final currentIds = {for (final f in current) f.id};
    // Only rows still on this site: the stamp waits for the commit.
    final onSite = {
      for (final f in await repository.getFeaturesForSite(site.id)) f.id,
    };
    var changed = false;
    // Features list by creation time: the ones added here a millisecond
    // apart, in the sitting's order (a duplicate's copy keeps the
    // original's, as the form's copy did).
    final start = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    for (final feature in loaded) {
      if (!currentIds.contains(feature.id) && onSite.contains(feature.id)) {
        await repository.deleteFeature(feature.id, stampLibrary: false);
        changed = true;
      }
    }
    for (final feature in current) {
      final before = loadedById[feature.id];
      if (before == null) {
        changed = true;
        await repository.addFeature(
          siteId: site.id,
          typeName: feature.typeName,
          latitude: feature.latitude,
          longitude: feature.longitude,
          bearingDeg: feature.bearingDeg,
          depthMeters: feature.depthMeters,
          name: feature.name,
          notes: feature.notes,
          stampLibrary: false,
          createdAt: start + added++,
        );
      } else if (before != feature && onSite.contains(feature.id)) {
        await repository.updateFeature(feature, stampLibrary: false);
        changed = true;
      }
    }
    return changed;
  },
  same: (a, b) {
    final set = a.toSet();
    return set.length == b.toSet().length && set.containsAll(b);
  },
);

/// Places [feature] on the site in the sitting.
void addFeatureInSitting(EditSession<DiveSite> session, SiteFeature feature) {
  final current = siteFeaturesList.current(session);
  if (current == null) return;
  siteFeaturesList.set(session, [...current, feature]);
}

/// Replaces the feature of [feature]'s id in the sitting.
void updateFeatureInSitting(
  EditSession<DiveSite> session,
  SiteFeature feature,
) {
  final current = siteFeaturesList.current(session);
  if (current == null) return;
  siteFeaturesList.set(session, [
    for (final f in current) f.id == feature.id ? feature : f,
  ]);
}

/// Takes the feature [id] off the site in the sitting.
void removeFeatureInSitting(EditSession<DiveSite> session, String id) {
  final current = siteFeaturesList.current(session);
  if (current == null) return;
  siteFeaturesList.set(session, [
    for (final f in current)
      if (f.id != id) f,
  ]);
}

/// Opens the feature sheet over [existing], or for a new one.
typedef SiteFeatureSheetOpener =
    Future<SiteFeatureSheetResult?> Function(
      BuildContext context, {
      SiteFeature? existing,
      double? initialDepthMeters,
    });

Future<SiteFeatureSheetResult?> _openSheet(
  BuildContext context, {
  SiteFeature? existing,
  double? initialDepthMeters,
}) => showSiteFeatureSheet(
  context,
  existing: existing,
  initialDepthMeters: initialDepthMeters,
);

/// Opens the sheet for [feature] and holds what comes back in the sitting,
/// as `editSiteFeature` writes it outside one.
Future<void> editFeatureInSitting(
  BuildContext context,
  EditSession<DiveSite> session,
  SiteFeature feature, {
  SiteFeatureSheetOpener? openSheet,
}) async {
  final result = await (openSheet ?? _openSheet)(context, existing: feature);
  if (session.isDisposed) return;
  switch (result) {
    case SiteFeatureSheetSave(
      :final typeName,
      :final name,
      :final bearingDeg,
      :final depthMeters,
      :final notes,
    ):
      updateFeatureInSitting(
        session,
        feature.copyWith(
          typeName: typeName,
          name: name,
          bearingDeg: bearingDeg,
          clearBearing: bearingDeg == null,
          depthMeters: depthMeters,
          clearDepth: depthMeters == null,
          notes: notes,
        ),
      );
    case SiteFeatureSheetDelete():
      removeFeatureInSitting(session, feature.id);
    case null:
      break;
  }
}

/// Lets the Features card's editor open the site's fullscreen map armed to
/// place a feature in [session]: the map is the page's to push.
class SiteFeaturePlacementScope extends InheritedWidget {
  const SiteFeaturePlacementScope({
    super.key,
    required this.placeOnMap,
    required super.child,
  });

  final void Function(EditSession<DiveSite> session) placeOnMap;

  static void Function(EditSession<DiveSite> session)? maybeOf(
    BuildContext context,
  ) => context
      .getInheritedWidgetOfExactType<SiteFeaturePlacementScope>()
      ?.placeOnMap;

  @override
  bool updateShouldNotify(SiteFeaturePlacementScope oldWidget) => false;
}
