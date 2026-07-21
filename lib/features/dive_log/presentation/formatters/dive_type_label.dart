import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Resolves a dive-type slug to the label shown on screen (issue #643).
///
/// Sites that already hold a [DiveTypeEntity] can call `localizedName` directly;
/// this is for the id-only surfaces -- the dive detail row and the Dive Type
/// list/table column -- which only ever see [Dive.diveTypeIds].
///
/// Three tiers, in order:
///
/// 1. A loaded entity for the id. This is the only tier that honors the
///    `isBuiltIn` guard, so pass [typesById] wherever the list is cheaply
///    available: it is what keeps a custom type sitting on a built-in slug
///    showing the diver's own name rather than the built-in translation.
/// 2. The built-in localization table, for ids whose row was not loaded.
/// 3. [Dive.diveTypeDisplayName] slug capitalization, preserving the pre-l10n
///    fallback (including its empty-id default) for ids that resolve to no row.
///
/// Tier 1 matters because `kSeedBuiltInDiveTypesSql` seeds with `INSERT OR
/// IGNORE`: on a database predating the v93 backfill, a diver-created row on
/// slug `wreck` suppresses the built-in seed for that slug and stays
/// `isBuiltIn = false`, so the id alone cannot tell the two apart.
String diveTypeLabel(
  AppLocalizations l10n,
  String id, {
  Map<String, DiveTypeEntity>? typesById,
}) =>
    typesById?[id]?.localizedName(l10n) ??
    builtInDiveTypeName(l10n, id) ??
    Dive.diveTypeDisplayName(id);

/// Comma-joined [diveTypeLabel] for a dive's full set of types, in the order
/// the ids are stored (the representative type is first).
String diveTypeLabels(
  AppLocalizations l10n,
  Iterable<String> ids, {
  Map<String, DiveTypeEntity>? typesById,
}) => ids.map((id) => diveTypeLabel(l10n, id, typesById: typesById)).join(', ');
