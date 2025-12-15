import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../data/repositories/certification_repository.dart';
import '../../domain/entities/certification.dart';

/// Repository provider
final certificationRepositoryProvider = Provider<CertificationRepository>((ref) {
  return CertificationRepository();
});

/// All certifications provider
final allCertificationsProvider =
    FutureProvider<List<Certification>>((ref) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getAllCertifications();
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
  if (query.isEmpty) {
    return ref.watch(allCertificationsProvider).value ?? [];
  }
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.searchCertifications(query);
});

/// Expiring certifications provider (within 90 days by default)
final expiringCertificationsProvider =
    FutureProvider.family<List<Certification>, int>((ref, days) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getExpiringCertifications(days);
});

/// Expired certifications provider
final expiredCertificationsProvider =
    FutureProvider<List<Certification>>((ref) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getExpiredCertifications();
});

/// Certifications by agency provider
final certificationsByAgencyProvider = FutureProvider.family<
    List<Certification>, CertificationAgency>((ref, agency) async {
  final repository = ref.watch(certificationRepositoryProvider);
  return repository.getCertificationsByAgency(agency);
});

/// Certification list notifier for mutations
class CertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>> {
  final CertificationRepository _repository;
  final Ref _ref;

  CertificationListNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _loadCertifications();
  }

  Future<void> _loadCertifications() async {
    state = const AsyncValue.loading();
    try {
      final certifications = await _repository.getAllCertifications();
      state = AsyncValue.data(certifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadCertifications();
    _ref.invalidate(allCertificationsProvider);
    _ref.invalidate(expiringCertificationsProvider(90));
    _ref.invalidate(expiredCertificationsProvider);
  }

  Future<Certification> addCertification(Certification cert) async {
    final newCert = await _repository.createCertification(cert);
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
