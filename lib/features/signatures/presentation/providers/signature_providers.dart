import 'dart:typed_data';
import 'dart:ui';

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

/// Notifier for saving signatures
class SignatureSaveNotifier extends StateNotifier<AsyncValue<Signature?>> {
  final SignatureStorageService _service;
  final Ref _ref;

  SignatureSaveNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  /// Save a signature from stroke data
  Future<Signature?> saveFromStrokes({
    required String diveId,
    required List<List<Offset>> strokes,
    required double width,
    required double height,
    required String signerName,
    String? signerId,
    Color strokeColor = const Color(0xFF000000),
    double strokeWidth = 3.0,
    Color? backgroundColor,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Convert strokes to PNG
      final pngBytes = await SignatureStorageService.strokesToPng(
        strokes: strokes,
        width: width,
        height: height,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
      );

      // Save signature
      final signature = await _service.saveSignature(
        diveId: diveId,
        imageBytes: pngBytes,
        signerName: signerName,
        signerId: signerId,
      );

      state = AsyncValue.data(signature);

      // Invalidate related providers
      _ref.invalidate(signatureForDiveProvider(diveId));
      _ref.invalidate(diveHasSignatureProvider(diveId));

      return signature;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Save a signature from PNG bytes directly
  Future<Signature?> saveFromBytes({
    required String diveId,
    required Uint8List imageBytes,
    required String signerName,
    String? signerId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final signature = await _service.saveSignature(
        diveId: diveId,
        imageBytes: imageBytes,
        signerName: signerName,
        signerId: signerId,
      );

      state = AsyncValue.data(signature);

      // Invalidate related providers
      _ref.invalidate(signatureForDiveProvider(diveId));
      _ref.invalidate(diveHasSignatureProvider(diveId));

      return signature;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Delete a signature
  Future<void> deleteSignature(String signatureId, String diveId) async {
    state = const AsyncValue.loading();

    try {
      await _service.deleteSignature(signatureId);
      state = const AsyncValue.data(null);

      // Invalidate related providers
      _ref.invalidate(signatureForDiveProvider(diveId));
      _ref.invalidate(diveHasSignatureProvider(diveId));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Provider for the signature save notifier
final signatureSaveNotifierProvider =
    StateNotifierProvider<SignatureSaveNotifier, AsyncValue<Signature?>>(
      (ref) => SignatureSaveNotifier(
        ref.watch(signatureStorageServiceProvider),
        ref,
      ),
    );

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

/// Notifier for saving buddy signatures
class BuddySignatureSaveNotifier extends StateNotifier<AsyncValue<Signature?>> {
  final SignatureStorageService _service;
  final Ref _ref;

  BuddySignatureSaveNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  /// Save a buddy signature from stroke data
  Future<Signature?> saveFromStrokes({
    required String diveId,
    required String buddyId,
    required String buddyName,
    required String role,
    required List<List<Offset>> strokes,
    required double width,
    required double height,
    Color strokeColor = const Color(0xFF000000),
    double strokeWidth = 3.0,
    Color? backgroundColor,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Convert strokes to PNG
      final pngBytes = await SignatureStorageService.strokesToPng(
        strokes: strokes,
        width: width,
        height: height,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
      );

      // Save buddy signature
      final signature = await _service.saveBuddySignature(
        diveId: diveId,
        imageBytes: pngBytes,
        buddyId: buddyId,
        buddyName: buddyName,
        role: role,
      );

      state = AsyncValue.data(signature);

      // Invalidate related providers
      _ref.invalidate(buddySignaturesForDiveProvider(diveId));
      _ref.invalidate(allSignaturesForDiveProvider(diveId));
      _ref.invalidate(
        hasBuddySignedProvider((diveId: diveId, buddyId: buddyId)),
      );

      return signature;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }
}

/// Provider for the buddy signature save notifier
final buddySignatureSaveNotifierProvider =
    StateNotifierProvider<BuddySignatureSaveNotifier, AsyncValue<Signature?>>(
      (ref) => BuddySignatureSaveNotifier(
        ref.watch(signatureStorageServiceProvider),
        ref,
      ),
    );