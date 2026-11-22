/// A new site's sitting (issue #4527, phase 2, plan 6): its seed, a
/// duplicate's copy of another site, the cards laid out open, and what a
/// seed request or a duplicate puts on the sitting as changes.
library;

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('SiteNewSitting');

/// A new site's starting record: [id], the active diver, and the sharing
/// every new site gets, with nothing else set. A diver or default that
/// cannot be read leaves no diver and no sharing, as the form does.
Future<DiveSite> newSiteSeed(ProviderRead read, {required String id}) async {
  String? diverId;
  var shared = false;
  try {
    diverId = await read(validatedCurrentDiverIdProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'No diver for a new site',
      error: error,
      stackTrace: stackTrace,
    );
  }
  try {
    shared = await read(shareByDefaultProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'No sharing default for a new site',
      error: error,
      stackTrace: stackTrace,
    );
  }
  return DiveSite(id: id, diverId: diverId, name: '', isShared: shared);
}

/// What a duplicate copies from another site (issue #3575): the site, the
/// active diver's own types and tags, its expected species and features,
/// and the sharing its copy starts with.
typedef SiteDuplicateSource = ({
  DiveSite site,
  List<SiteTypeEntity> types,
  List<Tag> tags,
  List<SiteSpeciesEntry> species,
  List<SiteFeature> features,
  ItemSharing sharing,
});

/// Reads [siteId] for its duplicate, or null when it is gone. The copy is
/// the active diver's: it keeps the sharing of the diver's own site, with
/// everyone and with named profiles alike (issue #2151); another
/// profile's site, and a library site, are shared as a new site is.
Future<SiteDuplicateSource?> readSiteDuplicate(
  ProviderRead read,
  String siteId,
) async {
  final site = await SiteRepository().getSiteById(siteId);
  if (site == null) return null;
  final diverId = await read(validatedCurrentDiverIdProvider.future);
  bool mine(String? owner) =>
      isOwnOrUnowned(ownerId: owner, activeDiverId: diverId);
  final types = await siteTypesList.read(site);
  final tags = await siteTagsList.read(site);
  final ItemSharing sharing;
  if (!site.isLibrarySite && mine(site.diverId)) {
    sharing = ItemSharing(
      everyone: site.isShared,
      profileIds: await read(
        itemSharesRepositoryProvider,
      ).storedProfileIds(SharedItemKind.site, site.id),
    );
  } else {
    sharing = await read(shareByDefaultProvider.future)
        ? ItemSharing.all
        : ItemSharing.none;
  }
  return (
    site: site,
    types: [
      for (final t in types)
        if (mine(t.diverId)) t,
    ],
    tags: [
      for (final t in tags)
        if (mine(t.diverId)) t,
    ],
    species: await siteSpeciesList.read(site),
    features: await siteFeaturesList.read(site),
    sharing: sharing,
  );
}

/// [readSiteDuplicate] for the page that opens a duplicate of a site,
/// watched by that page, so it goes with it: a later Duplicate of the same
/// site reads the site as it is then.
final siteDuplicateSourceProvider = FutureProvider.autoDispose
    .family<SiteDuplicateSource?, String>(
      (ref, siteId) => readSiteDuplicate(ref.read, siteId),
    );

/// The starter cards: the header block, then Location, Depth and Notes
/// (spec, decision 4).
const _starterCards = [siteHeaderCardId, 'location', 'depth', 'notes'];

/// The cards a new site opens with laid out: the starter cards, then, in
/// page order, every card [seed] or [duplicate] fills, as each differs from
/// [base]. A seeded point fills Altitude with the elevation found for it.
List<String> newSiteLaidOutCards({
  required DiveSite base,
  NewSiteSeed? seed,
  SiteDuplicateSource? duplicate,
}) {
  final filled = <String>{
    if (seed?.location != null) SiteDetailSectionId.altitude.name,
  };
  if (duplicate != null) {
    for (final field in siteSittingFields) {
      if (!field.same(field.read(duplicate.site), field.read(base))) {
        filled.add(field.cardId);
      }
    }
    if (duplicate.tags.isNotEmpty) filled.add(SiteDetailSectionId.tags.name);
    if (duplicate.species.isNotEmpty) {
      filled.add(SiteDetailSectionId.marineLife.name);
    }
    if (duplicate.features.isNotEmpty) {
      filled.add(SiteDetailSectionId.features.name);
    }
  }
  return [
    ..._starterCards,
    for (final section in SiteDetailSectionId.values)
      if (filled.contains(section.name) &&
          !_starterCards.contains(section.name))
        section.name,
  ];
}

/// Puts what [seed] or [duplicate] brings on [session], each through its
/// card's own function, so each is a change with its card's dot: a seed's
/// name, a seed's point with the place names and altitude found for it,
/// and a duplicate's fields (named [duplicateName]), lists and sharing.
/// Tracked, so Save waits for it. [altitudeDelay] is the wait before the
/// altitude is looked up, as after any move.
Future<void> applyNewSitePrefill(
  EditSession<DiveSite> session, {
  NewSiteSeed? seed,
  SiteDuplicateSource? duplicate,
  String? duplicateName,
  required Future<PlaceLookup> Function(GeoPoint point) lookUpPlace,
  required Future<double?> Function(GeoPoint point) fetchElevation,
  Duration altitudeDelay = const Duration(seconds: 1),
}) {
  final work = () async {
    if (_ended(session)) return;
    final name = seed?.name;
    if (name != null && name.isNotEmpty) session.set(siteNameField, name);
    final point = seed?.location;
    if (point != null) {
      moveSiteTo(session, point);
      scheduleAltitudeAfterMove(session, fetchElevation, delay: altitudeDelay);
      final PlaceLookup place;
      try {
        place = await lookUpPlace(point);
      } catch (error, stackTrace) {
        _log.warning(
          'No place names for a new site\'s point',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
      if (_ended(session)) return;
      applyPlaceLookup(session, place, overwrite: false);
    }
    if (duplicate != null) _copy(session, duplicate, duplicateName);
  }();
  session.track(work);
  return work;
}

void _copy(
  EditSession<DiveSite> session,
  SiteDuplicateSource duplicate,
  String? name,
) {
  for (final field in siteSittingFields) {
    field.copyFrom(session, duplicate.site);
  }
  if (name != null) session.set(siteNameField, name);
  // Nothing is stored for the copy: each list starts empty, so its copy
  // is always taken and never waits on a read that might fail.
  for (final list in siteHeldLists) {
    list.loadNone(session);
  }
  siteTypesList.set(session, duplicate.types);
  siteTagsList.set(session, duplicate.tags);
  siteSpeciesList.set(session, duplicate.species);
  siteFeaturesList.set(session, duplicate.features);
  siteSharing.set(
    session,
    duplicate.sharing,
    actingDiverId: session.stored.diverId,
  );
}

bool _ended(EditSession<DiveSite> session) =>
    session.isDisposed || session.isFrozen;
