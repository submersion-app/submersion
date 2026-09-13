import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// What a dives only UDDF export needs beyond the dives themselves.
///
/// The dives already carry their gear; participants and assembly rows are
/// not hydrated on them, so they travel here.
class UddfDivesExtras {
  /// Each exported dive's participants with their roles, by dive id.
  final Map<String, List<BuddyWithRole>> diveBuddies;

  /// Assembly template rows between gear on the exported dives. The export
  /// filters them again against the items it declares.
  final List<EquipmentComponent> components;

  /// Site type slugs and tag ids per exported site (issue #1765).
  final Map<String, List<String>> siteTypeIdsBySite;
  final Map<String, List<String>> siteTagIdsBySite;

  /// The definitions those references need: the custom site types and the
  /// tags the exported sites carry. Built-in types go by slug alone.
  final List<SiteTypeEntity> customSiteTypes;
  final List<Tag> siteTags;

  const UddfDivesExtras({
    this.diveBuddies = const {},
    this.components = const [],
    this.siteTypeIdsBySite = const {},
    this.siteTagIdsBySite = const {},
    this.customSiteTypes = const [],
    this.siteTags = const [],
  });

  const UddfDivesExtras.empty() : this();
}

/// Fetches the [UddfDivesExtras] a dives only export needs for [diveIds].
typedef UddfDivesExtrasFetch =
    Future<UddfDivesExtras> Function(
      List<String> diveIds,
      UddfExportOptions options,
    );

/// The fetch every dives only export action uses.
///
/// A provider for the same reason as `uddfSourceFetchProvider`: the export
/// actions live in widgets whose tests have no database, and overriding
/// this is how such a test opts out.
final uddfDivesExtrasFetchProvider = Provider<UddfDivesExtrasFetch>((ref) {
  return (diveIds, options) => resolveDivesExtras(
    ref.read(buddyRepositoryProvider),
    ref.read(equipmentComponentRepositoryProvider),
    diveIds,
    options,
    classification: ref.read(siteClassificationRepositoryProvider),
    siteTypes: ref.read(siteTypeRepositoryProvider),
  );
});

/// Loads the extras for [diveIds], skipping any query whose checkbox in
/// [options] is off: a share without participants or gear must not pay for
/// reads it will not use.
///
/// Site types and tags (issue #1765) are not behind a checkbox: they describe
/// the exported sites, which always travel. They load only when
/// [classification] is given.
Future<UddfDivesExtras> resolveDivesExtras(
  BuddyRepository buddies,
  EquipmentComponentRepository components,
  List<String> diveIds,
  UddfExportOptions options, {
  SiteClassificationRepository? classification,
  SiteTypeRepository? siteTypes,
}) async {
  // The lean list-view load leaves certifications out, and every <buddy>
  // declaration carries one, so this path reads them too.
  final diveBuddies = options.includeParticipants
      ? await buddies.getBuddiesForDivesWithCertifications(diveIds)
      : const <String, List<BuddyWithRole>>{};
  final gear = options.includeGear
      ? await components.getComponentsForDives(diveIds)
      : const <EquipmentComponent>[];
  if (classification == null) {
    return UddfDivesExtras(diveBuddies: diveBuddies, components: gear);
  }

  final siteIds = await classification.getSiteIdsForDives(diveIds);
  final typeIdsBySite = await classification.getTypeIdsBySite(siteIds);
  final tagIdsBySite = await classification.getTagIdsBySite(siteIds);
  final tagsBySite = await classification.getTagsBySite();
  final siteTags = <String, Tag>{
    for (final siteId in siteIds)
      for (final tag in tagsBySite[siteId] ?? const <Tag>[]) tag.id: tag,
  };
  final customSiteTypes = <SiteTypeEntity>[];
  for (final typeId in {for (final ids in typeIdsBySite.values) ...ids}) {
    final type = await siteTypes?.getSiteTypeById(typeId);
    if (type != null && !type.isBuiltIn) customSiteTypes.add(type);
  }

  return UddfDivesExtras(
    diveBuddies: diveBuddies,
    components: gear,
    siteTypeIdsBySite: typeIdsBySite,
    siteTagIdsBySite: tagIdsBySite,
    customSiteTypes: customSiteTypes,
    siteTags: siteTags.values.toList(),
  );
}
