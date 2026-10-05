import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';

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
    return _agencyCache[lower] = (await _createAgency(t)).id;
  }

  /// A shared agency must not duplicate another diver's private one, so
  /// when the name is held that way the import keeps the agency private.
  Future<CustomCertificationAgency> _createAgency(String name) async {
    if (shareByDefault) {
      try {
        return await _repo.createAgency(
          diverId: diverId,
          name: name,
          isShared: true,
        );
      } on CertificationNameTakenException {
        // Held privately by another diver; fall through.
      }
    }
    return _repo.createAgency(diverId: diverId, name: name, isShared: false);
  }

  /// The level id for [text] under [agencyId], or null when nothing matches.
  Future<String?> levelId(String agencyId, String? text) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    bool matches(CertificationLevel l) =>
        l.name.toLowerCase() == lower || l.displayName.toLowerCase() == lower;
    // The agency's own levels first, built-in then custom: display names
    // repeat across agencies ("Advanced Diver" is both BSAC and ACUC), and a
    // custom level may share a name with another agency's built-in.
    final builtIn = CertificationAgency.fromId(agencyId);
    if (builtIn != null) {
      for (final l in CertificationLevelCatalog.levelsFor(builtIn)) {
        if (matches(l)) return l.name;
      }
    }
    final custom = (await _repo.getAllLevels()).where(
      (l) =>
          l.agencyId == agencyId &&
          (l.diverId == diverId || l.isShared || builtIn == null) &&
          l.name.toLowerCase() == lower,
    );
    if (custom.isNotEmpty) return custom.first.id;
    for (final l in CertificationLevel.values) {
      if (matches(l)) return l.name;
    }
    return null;
  }
}
