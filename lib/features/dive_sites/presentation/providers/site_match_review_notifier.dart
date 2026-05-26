import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

class SiteMatchReviewState {
  final bool isLoading;
  final List<DiveMatchEntry> entries;
  final String? errorMessage;

  const SiteMatchReviewState({
    this.isLoading = true,
    this.entries = const [],
    this.errorMessage,
  });

  SiteMatchReviewState copyWith({
    bool? isLoading,
    List<DiveMatchEntry>? entries,
    String? errorMessage,
  }) => SiteMatchReviewState(
    isLoading: isLoading ?? this.isLoading,
    entries: entries ?? this.entries,
    errorMessage: errorMessage,
  );

  int get matchedCount =>
      entries.where((e) => e.status == MatchEntryStatus.autoMatched).length;
  int get reviewCount =>
      entries.where((e) => e.status == MatchEntryStatus.needsReview).length;
  int get noMatchCount =>
      entries.where((e) => e.status == MatchEntryStatus.noMatch).length;
}

class SiteMatchReviewNotifier extends StateNotifier<SiteMatchReviewState> {
  SiteMatchReviewNotifier(this._ref, this._diveIds, {bool autoInit = true})
    : super(const SiteMatchReviewState()) {
    if (autoInit) _init(); // tests pass autoInit:false and seed state directly
  }

  final Ref _ref;
  final List<String>? _diveIds; // null = backlog (all eligible)
  SiteMatchingService? _service;

  Future<void> _init() async {
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final diveRepo = _ref.read(diveRepositoryProvider);
      // Phase F (Task 17) swaps this for the persisted setting:
      //   _ref.read(settingsProvider).siteMatchSensitivity
      const sensitivity = SiteMatchSensitivity.balanced;

      final dives = await diveRepo.getDivesNeedingSiteMatch(
        diverId: diverId,
        limitToIds: _diveIds,
      );

      _service = SiteMatchingService(
        siteRepository: _ref.read(siteRepositoryProvider),
        apiService: _ref.read(diveSiteApiServiceProvider),
        diveRepository: diveRepo,
        diverId: diverId,
        thresholds: sensitivity.thresholds,
      );

      final entries = await _service!.run(dives);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, entries: entries);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Matching failed: $e',
      );
    }
  }

  Future<void> link(String diveId, String candidateId) async {
    final applied = await _service?.link(diveId, candidateId);
    if (applied == null) return;
    _replace(diveId, (e) {
      final chosen = e.candidates.firstWhere((c) => c.id == candidateId);
      return e.copyWith(
        status: MatchEntryStatus.autoMatched,
        siteId:
            applied.siteId, // real created/linked id, not bundled externalId
        siteName: applied.siteName,
        distanceMeters: chosen.distanceMeters,
        isNewlyCreated: applied.isNewlyCreated,
        candidates: const [],
      );
    });
  }

  Future<void> unlink(String diveId) async {
    await _service?.unlink(diveId);
    _replace(
      diveId,
      (e) => e.copyWith(status: MatchEntryStatus.noMatch, clearSite: true),
    );
  }

  void _replace(String diveId, DiveMatchEntry Function(DiveMatchEntry) f) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.dive.id == diveId) f(e) else e,
      ],
    );
  }
}

final siteMatchReviewProvider = StateNotifierProvider.autoDispose
    .family<SiteMatchReviewNotifier, SiteMatchReviewState, List<String>?>(
      (ref, diveIds) => SiteMatchReviewNotifier(ref, diveIds),
    );
