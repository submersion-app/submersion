import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Provider for the signature storage service
final signatureStorageServiceProvider = Provider<SignatureStorageService>(
  (ref) => SignatureStorageService(),
);

/// Provider to get signature for a specific dive
final signatureForDiveProvider = FutureProvider.family<Signature?, String>((
  ref,
  diveId,
) async {
  final service = ref.watch(signatureStorageServiceProvider);
  return service.getSignatureForDive(diveId);
});

/// Provider to check if a dive has a signature
final diveHasSignatureProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) async {
  final service = ref.watch(signatureStorageServiceProvider);
  return service.hasSignature(diveId);
});

/// Provider to get all signatures for a course
final signaturesForCourseProvider =
    FutureProvider.family<List<Signature>, String>((ref, courseId) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.getSignaturesForCourse(courseId);
    });

/// Provider to get all buddy signatures for a dive
final buddySignaturesForDiveProvider =
    FutureProvider.family<List<Signature>, String>((ref, diveId) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.getBuddySignaturesForDive(diveId);
    });

/// Provider to get all signatures (instructor + buddy) for a dive
final allSignaturesForDiveProvider =
    FutureProvider.family<List<Signature>, String>((ref, diveId) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.getAllSignaturesForDive(diveId);
    });

/// Provider to check if a specific buddy has signed a dive
final hasBuddySignedProvider =
    FutureProvider.family<bool, ({String diveId, String buddyId})>((
      ref,
      params,
    ) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.hasBuddySigned(params.diveId, params.buddyId);
    });
