import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_type_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';

/// The `dives` columns a site link rewrites besides `site_id`: the water type
/// and entry/exit methods [site] carries, under the snap rules the dive form's
/// site picker applies (issue #3196). [dive] is the row as it stands; [site]
/// is null when the link is cleared, which keeps every value.
///
/// A column is written only when its value changes, so a stored string this
/// build does not recognise is never rewritten by a link that leaves it be.
DivesCompanion siteSnapColumns(Dive dive, domain.DiveSite? site) {
  final waterType = _parse(WaterType.values, dive.waterType);
  final entry = _parse(EntryMethod.values, dive.entryMethod);
  final exit = _parse(EntryMethod.values, dive.exitMethod);

  final snappedWater = waterTypeAfterSiteAssign(waterType, site);
  final snapped = entryExitAfterSiteAssign(
    currentEntry: entry,
    currentExit: exit,
    currentLinked: exit == null || exit == entry,
    site: site,
  );

  return DivesCompanion(
    waterType: _changed(waterType, snappedWater),
    entryMethod: _changed(entry, snapped.entry),
    exitMethod: _changed(exit, snapped.exit),
  );
}

/// The ids of the dive types [siteId]'s site types stand for, from the
/// built-in types plus [diverId]'s own (see [diveTypeIdsForSiteTypes]).
Future<List<String>> diveTypeIdsForSite(String siteId, String? diverId) async {
  final siteTypes = await SiteClassificationRepository().getTypesForSite(
    siteId,
  );
  if (siteTypes.isEmpty) return const [];
  return diveTypeIdsForSiteTypes(
    siteTypes: siteTypes,
    diveTypes: await DiveTypeRepository().getAllDiveTypes(diverId: diverId),
  );
}

T? _parse<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : values.asNameMap()[name];

Value<String?> _changed<T extends Enum>(T? before, T? after) =>
    before == after ? const Value.absent() : Value(after?.name);
