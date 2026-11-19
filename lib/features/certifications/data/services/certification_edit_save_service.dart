import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// Writes a certification page's editing sitting (issue #4527, phase 3):
/// its changed values, its card images and every held write, in one
/// transaction and one History entry labelled with the cards it changed.
class CertificationEditSaveService {
  CertificationEditSaveService(this._certifications);

  final CertificationRepository _certifications;

  /// Saves [apply] onto certification [certificationId] as stored now, so a
  /// value changed underneath on a card the diver never touched is kept.
  /// The update also refreshes its course's representative and writes its
  /// card images, inside the sitting. [alsoWrite] makes the held writes
  /// (currency logged, preferences set) after the row; with
  /// [alsoWriteIsAChange] they are written even when the row is unchanged.
  /// Returns the certification before and after, or null when nothing
  /// changed. Throws [StateError] when it no longer exists.
  Future<({Certification before, Certification after})?> save({
    required String certificationId,
    required Certification Function(Certification stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<Certification>(
    table: 'certifications',
    recordId: certificationId,
    changedCardIds: changedCardIds,
    read: () => _certifications.getCertificationById(certificationId),
    apply: apply,
    // The sitting tells sync once, after its commit.
    write: (_, merged) =>
        _certifications.updateCertification(merged, notify: false),
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );
}

final certificationEditSaveServiceProvider =
    Provider<CertificationEditSaveService>(
      (ref) => CertificationEditSaveService(
        ref.watch(certificationRepositoryProvider),
      ),
    );
