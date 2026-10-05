import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';

/// Maps imported agency and level text to ids (issue #690).
///
/// Built-ins match as before. Agency text that names no built-in matches a
/// custom agency the importing diver can see, or else becomes a new custom
/// agency for that diver, instead of collapsing to "Other" and losing the
/// text. Level text is never turned into a custom level: importers such as
/// MacDive send free-form card names as the level, which would litter the
/// catalog; unmatched level text stays in the certification's name.
class CertificationImportResolver {
  CertificationImportResolver(
    this._repo, {
    required this.diverId,
    required this.shareByDefault,
  });

  final CustomCertificationRepository _repo;
  final String diverId;
  final bool shareByDefault;

  /// Agencies matched or created during this import, by lowercased text, so
  /// the same text maps to one id within a run.
  final Map<String, String> _agencyCache = {};

  Future<String> agencyId(String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return CertificationAgency.padi.name;
    final lower = t.toLowerCase();
    for (final a in CertificationAgency.values) {
      if (a.name.toLowerCase() == lower ||
          a.displayName.toLowerCase() == lower) {
        return a.name;
      }
    }
    final cached = _agencyCache[lower];
    if (cached != null) return cached;
    final visible = (await _repo.getAllAgencies()).where(
      (a) =>
          (a.diverId == diverId || a.isShared) && a.name.toLowerCase() == lower,
    );
    if (visible.isNotEmpty) return _agencyCache[lower] = visible.first.id;
    final created = await _repo.createAgency(
      diverId: diverId,
      name: t,
      isShared: shareByDefault,
    );
    return _agencyCache[lower] = created.id;
  }

  /// The level id for [text] under [agencyId], or null when nothing matches.
  Future<String?> levelId(String agencyId, String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    for (final l in CertificationLevel.values) {
      if (l.name.toLowerCase() == lower ||
          l.displayName.toLowerCase() == lower) {
        return l.name;
      }
    }
    final builtInAgency = CertificationAgency.fromId(agencyId) != null;
    final custom = (await _repo.getAllLevels()).where(
      (l) =>
          l.agencyId == agencyId &&
          (l.diverId == diverId || l.isShared || !builtInAgency) &&
          l.name.toLowerCase() == lower,
    );
    return custom.isEmpty ? null : custom.first.id;
  }
}
