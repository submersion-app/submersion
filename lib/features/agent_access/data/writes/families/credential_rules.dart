import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';

/// What picking buddy [instructorId] as an instructor writes, as the
/// instructor picker does on a card or a course: their name and the card
/// number of their highest instructor card, or none.
Future<Map<String, Object?>> instructorCopy(
  RecordRepositories r,
  Object? instructorId,
) async {
  if (instructorId is! String) return const {};
  final buddy = await r.buddies.getBuddyById(instructorId);
  if (buddy == null) return const {};
  final teaching = [
    for (final c in await r.certifications.getCertificationMetadataByBuddy(
      instructorId,
    ))
      if (CertificationLevel.fromId(c.level)?.isInstructorLevel ?? false) c,
  ];
  return {
    'instructor_name': buddy.name,
    'instructor_number': primaryCertification(teaching)?.cardNumber,
  };
}

/// Why [agency], and [level] when named, cannot be used by [ownerId], or
/// null: the agency is built in or a custom one the profile sees, and the
/// level one the agency offers.
Future<PlanBlock?> credentialProblem(
  RecordRepositories r,
  String agency,
  String? level,
  String? ownerId,
) async {
  final custom = r.customCertifications;
  final catalog = CertificationCatalog(
    agencies: await custom.getAllAgencies(),
    levels: await custom.getAllLevels(),
    viewerDiverId: ownerId,
  );
  if (!catalog.agencies.any((a) => a.id == agency)) {
    return PlanBlock(
      BlockReason.invalidValue,
      'agency: $agency is not an agency this profile can use.',
    );
  }
  if (level != null && !catalog.levelsFor(agency).any((l) => l.id == level)) {
    return PlanBlock(
      BlockReason.invalidValue,
      'level: $level is not one of ${catalog.agency(agency).name}\'s levels.',
    );
  }
  return null;
}
