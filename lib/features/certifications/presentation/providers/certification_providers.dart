import 'package:submersion/core/providers/provider.dart';

import '../../../../core/constants/enums.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/certification_repository.dart';
import '../../domain/entities/certification.dart';

/// Repository provider
final certificationRepositoryProvider =
    Provider<CertificationRepository>((ref) {
  return CertificationRepository();
});

/// All certifications provider
final allCertificationsProvider =
    FutureProvider<List<Certification>>((ref) async {
  final repository = ref.watch(certificationRepositoryProvider);
  final validatedDiverId =
      await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllCertifications(diverId: validatedDiverId);
});

/// Single certification provider
final certificationByIdProvider =
    FutureProvider.family<Certification?, String>((ref, id) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getCertificationById(id);
});

/// Certification search provider
final certificationSearchProvider =
    FutureProvider.family<List<Certification>, String>((ref, query) async {
  final validatedDiverId =
      await ref.watch(validatedCurrentDiverIdProvider.future);
  if (query.isEmpty) {
    return ref.watch(allCertificationsProvider).value ?? [];
  }
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.searchCertifications(query, diverId: validatedDiverId);
});

/// Expiring certifications provider (within 90 days by default)
final expiringCertificationsProvider =
    FutureProvider.family<List<Certification>, int>((ref, days) async {
  final repository = ref.watch(certificationRepositoryProvider);
  final validatedDiverId =
      await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getExpiringCertifications(days, diverId: validatedDiverId);
});

/// Expired certifications provider
final expiredCertificationsProvider =
    FutureProvider<List<Certification>>((ref) async {
  final repository = ref.watch(certificationRepositoryProvider);
  final validatedDiverId =
      await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getExpiredCertifications(diverId: validatedDiverId);
});

/// Certifications by agency provider
final certificationsByAgencyProvider =
    FutureProvider.family<List<Certification>, CertificationAgency>(
        (ref, agency) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getCertificationsByAgency(agency);
});

/// Certification list notifier for mutations
class CertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>> {
  final CertificationRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  CertificationListNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allCertificationsProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadCertifications();
  }

  Future<void> _loadCertifications() async {
    state = const AsyncValue.loading();
    try {
      final certifications =
          await _repository.getAllCertifications(diverId: _validatedDiverId);
      state = AsyncValue.data(certifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadCertifications();
    _ref.invalidate(allCertificationsProvider);
    _ref.invalidate(expiringCertificationsProvider(90));
    _ref.invalidate(expiredCertificationsProvider);
  }

  Future<Certification> addCertification(Certification cert) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final certWithDiver =
        validatedId != null ? cert.copyWith(diverId: validatedId) : cert;
    final newCert = await _repository.createCertification(certWithDiver);
    await refresh();
    return newCert;
  }

  Future<void> updateCertification(Certification cert) async {
    await _repository.updateCertification(cert);
    await refresh();
    _ref.invalidate(certificationByIdProvider(cert.id));
  }

  Future<void> deleteCertification(String id) async {
    await _repository.deleteCertification(id);
    await refresh();
  }
}

final certificationListNotifierProvider = StateNotifierProvider<
    CertificationListNotifier, AsyncValue<List<Certification>>>((ref) {
  final repository = ref.watch(certificationRepositoryProvider);
  return CertificationListNotifier(repository, ref);
});

/// Count of expiring certifications (for badges/warnings)
final expiringCertificationCountProvider = FutureProvider<int>((ref) async {
  final expiring = await ref.watch(expiringCertificationsProvider(90).future);
  final expired = await ref.watch(expiredCertificationsProvider.future);
  return expiring.length + expired.length;
});
