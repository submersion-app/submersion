import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// The roles [ids] name, in the order given; an id with no row shows its raw
/// slug (see [DiveRole.synthetic]).
List<DiveRole> rolesForIds(Iterable<String> ids, Map<String, DiveRole> byId) =>
    [for (final id in ids) byId[id] ?? DiveRole.synthetic(id)];

extension DiveRoleListDisplay on Iterable<DiveRole> {
  /// "Divemaster, Dive Guide": each role's localized name, comma-joined, the
  /// same separator the dive's leader names use (issue #1221).
  String joinedLocalizedNames(AppLocalizations l10n) =>
      map((r) => r.localizedName(l10n)).join(', ');
}
