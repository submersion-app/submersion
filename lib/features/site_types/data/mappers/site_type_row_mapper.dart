import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// Maps a `site_types` row to its domain entity.
SiteTypeEntity mapSiteTypeRow(SiteType row) {
  return SiteTypeEntity(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    isBuiltIn: row.isBuiltIn,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
