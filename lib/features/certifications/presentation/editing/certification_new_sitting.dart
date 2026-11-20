import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

/// A new certification's sitting (issue #4527, phase 3, plan 11): its seed
/// and the cards laid out open.

/// A new certification's starting record under [id]: the active diver's,
/// of PADI with no level, as the form starts one, and no buddy's. A diver
/// that cannot be read leaves none, for Save to take the one active then.
Future<Certification> newCertificationSeed(
  RecordSeedRead read, {
  required String id,
}) async {
  final diverId = await newRecordDiverId(read, record: 'certification');
  return Certification.empty().copyWith(id: id, diverId: diverId);
}

/// The cards a new certification opens with: Details, Dates and the card
/// photos.
final List<String> newCertificationLaidOut = List.unmodifiable([
  CertificationCardId.details.name,
  CertificationCardId.dates.name,
  CertificationCardId.cardPhotos.name,
]);
