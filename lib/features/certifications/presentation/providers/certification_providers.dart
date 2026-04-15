import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

/// Repository provider
final certificationRepositoryProvider = Provider<CertificationRepository>((
  ref,
) {
  return CertificationRepository();
});

/// All certifications provider
final allCertificationsProvider = FutureProvider<List<Certification>>((
  ref,
) async {
  final repository = ref.watch(certificationRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllCertifications(diverId: validatedDiverId);
});

/// Certification sort state provider
final certificationSortProvider =
    StateProvider<SortState<CertificationSortField>>(
      (ref) => const SortState(
        field: CertificationSortField.dateIssued,
        direction: SortDirection.descending,
      ),
    );

/// Apply sorting to a list of certifications
List<Certification> applyCertificationSorting(
  List<Certification> certifications,
  SortState<CertificationSortField> sort,
) {
  final sorted = List<Certification>.from(certifications);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText =
        sort.field == CertificationSortField.name ||
        sort.field == CertificationSortField.agency;

    switch (sort.field) {
      case CertificationSortField.name:
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case CertificationSortField.dateIssued:
        comparison = (a.issueDate ?? DateTime(1900)).compareTo(
          b.issueDate ?? DateTime(1900),
        );
      case CertificationSortField.agency:
        comparison = a.agency.displayName.compareTo(b.agency.displayName);
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

/// Single certification provider
final certificationByIdProvider = FutureProvider.family<Certification?, String>(
  (ref, id) async {
    final repository = ref.watch(certificationRepositoryProvider);
    return repository.getCertificationById(id);
  },
);

/// Certification search provider
final certificationSearchProvider =
    FutureProvider.family<List<Certification>, String>((ref, query) async {
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
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
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      return repository.getExpiringCertifications(
        days,
        diverId: validatedDiverId,
      );
    });

/// Expired certifications provider
final expiredCertificationsProvider = FutureProvider<List<Certification>>((
  ref,
) async {
  final repository = ref.watch(certificationRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getExpiredCertifications(diverId: validatedDiverId);
});

/// Certifications by agency provider
final certificationsByAgencyProvider =
    FutureProvider.family<List<Certification>, CertificationAgency>((
      ref,
      agency,
    ) async {
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
      final certifications = await _repository.getAllCertifications(
        diverId: _validatedDiverId,
      );
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
    final certWithDiver = validatedId != null
        ? cert.copyWith(diverId: validatedId)
        : cert;
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

final certificationListNotifierProvider =
    StateNotifierProvider<
      CertificationListNotifier,
      AsyncValue<List<Certification>>
    >((ref) {
      final repository = ref.watch(certificationRepositoryProvider);
      return CertificationListNotifier(repository, ref);
    });

/// Count of expiring certifications (for badges/warnings)
final expiringCertificationCountProvider = FutureProvider<int>((ref) async {
  final expiring = await ref.watch(expiringCertificationsProvider(90).future);
  final expired = await ref.watch(expiredCertificationsProvider.future);
  return expiring.length + expired.length;
});

// ============================================================================
// Certification List View Mode
// ============================================================================

/// In-memory view mode for the certification list. Defaults to detailed.
/// Not persisted in AppSettings — resets to detailed on app restart.
final certificationListViewModeProvider = StateProvider<ListViewMode>((ref) {
  return ListViewMode.detailed;
});

// ============================================================================
// Certification Highlighted ID (for table mode detail pane)
// ============================================================================

/// Tracks the currently highlighted certification. Used by the table's
/// row highlight and by the phone-mode list to tint the last-visited
/// certification card on return from the detail page.
final highlightedCertificationIdProvider = StateProvider<String?>(
  (ref) => null,
);

// ============================================================================
// Certification Table View Config
// ============================================================================

/// Provider for the certification table view column configuration.
///
/// Persists column visibility, order, widths, and sort state per diver using
/// [ViewConfigRepository] under the key 'table_certifications'.
final certificationTableConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<CertificationField>,
      EntityTableViewConfig<CertificationField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<CertificationField>(
        defaultConfig: EntityTableViewConfig<CertificationField>(
          columns: [
            EntityTableColumnConfig(
              field: CertificationField.certName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: CertificationField.agency),
            EntityTableColumnConfig(field: CertificationField.level),
            EntityTableColumnConfig(field: CertificationField.issueDate),
            EntityTableColumnConfig(field: CertificationField.expiryDate),
            EntityTableColumnConfig(field: CertificationField.expiryStatus),
          ],
        ),
        fieldFromName: CertificationFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_certifications');
      }
      return notifier;
    });

// ============================================================================
// Certification Card View Config
// ============================================================================

/// Default card slot configuration for the detailed certification card view.
/// Certifications only support the detailed card layout (no compact variant).
final certificationDetailedCardConfigProvider =
    StateProvider<EntityCardViewConfig<CertificationField>>(
      (ref) => const EntityCardViewConfig<CertificationField>(
        slots: [
          EntityCardSlotConfig(
            slotId: 'title',
            field: CertificationField.certName,
          ),
          EntityCardSlotConfig(
            slotId: 'subtitle',
            field: CertificationField.agency,
          ),
          EntityCardSlotConfig(
            slotId: 'stat1',
            field: CertificationField.level,
          ),
          EntityCardSlotConfig(
            slotId: 'stat2',
            field: CertificationField.issueDate,
          ),
        ],
        extraFields: [],
      ),
    );
