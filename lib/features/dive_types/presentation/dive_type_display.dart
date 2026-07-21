import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display names for the built-in dive types.
///
/// Built-in types are seeded into `dive_types` as English literals (see
/// `kSeedBuiltInDiveTypesSql`) and the stored `name` is what exports and sync
/// carry, so it deliberately stays English. Rendering that column directly is
/// what left Settings / Manage / Dive Types in English under every locale
/// (issue #643); on-screen callers resolve through here instead.
///
/// Keyed on the stable slug id rather than the name, so a user who renames
/// nothing still gets translations and a renamed row cannot break the lookup.
/// Returns null for anything that is not a known built-in slug.
String? builtInDiveTypeName(AppLocalizations l10n, String id) => switch (id) {
  'recreational' => l10n.diveType_builtin_recreational,
  'technical' => l10n.diveType_builtin_technical,
  'freedive' => l10n.diveType_builtin_freedive,
  'training' => l10n.diveType_builtin_training,
  'wreck' => l10n.diveType_builtin_wreck,
  'cave' => l10n.diveType_builtin_cave,
  'ice' => l10n.diveType_builtin_ice,
  'night' => l10n.diveType_builtin_night,
  'drift' => l10n.diveType_builtin_drift,
  'deep' => l10n.diveType_builtin_deep,
  'altitude' => l10n.diveType_builtin_altitude,
  'shore' => l10n.diveType_builtin_shore,
  'boat' => l10n.diveType_builtin_boat,
  'liveaboard' => l10n.diveType_builtin_liveaboard,
  'cavern' => l10n.diveType_builtin_cavern,
  _ => null,
};

extension DiveTypeDisplay on DiveTypeEntity {
  /// Localized name for built-in types; the stored name for custom types.
  ///
  /// The [isBuiltIn] guard matters: a custom type can carry a slug that
  /// collides with a built-in one, and the diver's own label must win there.
  /// `DiveTypeRepository.createDiveType` uniquifies a colliding slug, and both
  /// the UDDF importer and the add dialog go through it, so the collision does
  /// not arise that way. It arises from the seed side instead:
  /// `kSeedBuiltInDiveTypesSql` uses `INSERT OR IGNORE`, so on a database
  /// predating the v93 backfill a diver-created row already occupying slug
  /// `wreck` suppresses the built-in seed for that slug and stays
  /// `isBuiltIn = false`.
  String localizedName(AppLocalizations l10n) =>
      isBuiltIn ? (builtInDiveTypeName(l10n, id) ?? name) : name;
}
