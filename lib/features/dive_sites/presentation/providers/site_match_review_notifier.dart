import 'package:equatable/equatable.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class SiteMatchReviewState {
  final bool isLoading;
  final String? errorMessage;
  final List<MatchProposal> proposals;
  final String? focusedDiveId;
  final Map<String, String> selections; // diveId -> chosen candidateId
  final bool isApplying;

  const SiteMatchReviewState({
    this.isLoading = true,
    this.errorMessage,
    this.proposals = const [],
    this.focusedDiveId,
    this.selections = const {},
    this.isApplying = false,
  });

  SiteMatchReviewState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<MatchProposal>? proposals,
    String? focusedDiveId,
    Map<String, String>? selections,
    bool? isApplying,
  }) => SiteMatchReviewState(
    isLoading: isLoading ?? this.isLoading,
    // Preserve a set (fatal) error unless a new one is passed; transient
    // state changes (focus/select/apply) must not silently clear it.
    errorMessage: errorMessage ?? this.errorMessage,
    proposals: proposals ?? this.proposals,
    focusedDiveId: focusedDiveId ?? this.focusedDiveId,
    selections: selections ?? this.selections,
    isApplying: isApplying ?? this.isApplying,
  );

  int get selectedCount => selections.length;

  /// Any proposal with candidates (clear or review) that has no selection yet.
  /// A clear match whose seeded selection was toggled off still needs review,
  /// so this counts the full unselected-but-matchable set, not just review-tier
  /// proposals. Together with [selectedCount] and [noMatchCount] this partitions
  /// every proposal exactly once.
  int get reviewCount => proposals
      .where(
        (p) =>
            p.status != ProposalStatus.none &&
            !selections.containsKey(p.dive.id),
      )
      .length;
  int get noMatchCount =>
      proposals.where((p) => p.status == ProposalStatus.none).length;

  MatchProposal? get focusedProposal {
    for (final p in proposals) {
      if (p.dive.id == focusedDiveId) return p;
    }
    return null;
  }
}

class SiteMatchReviewNotifier extends StateNotifier<SiteMatchReviewState> {
  SiteMatchReviewNotifier(this._ref, this._diveIds, {bool autoInit = true})
    : super(const SiteMatchReviewState()) {
    if (autoInit) _init();
  }

  final Ref _ref;
  final List<String>? _diveIds;
  SiteMatchingService? _service;

  Future<void> _init() async {
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final diveRepo = _ref.read(diveRepositoryProvider);
      final sensitivity = _ref.read(settingsProvider).siteMatchSensitivity;

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

      final proposals = await _service!.computeProposals(dives);
      if (!mounted) return;

      // Seed selections from clear matches; focus the first review (else first).
      final selections = <String, String>{};
      for (final p in proposals) {
        if (p.status == ProposalStatus.clear &&
            p.recommendedCandidateId != null) {
          selections[p.dive.id] = p.recommendedCandidateId!;
        }
      }
      String? focus;
      if (proposals.isNotEmpty) {
        final firstReview = proposals
            .where((p) => p.status == ProposalStatus.review)
            .map((p) => p.dive.id);
        focus = firstReview.isNotEmpty
            ? firstReview.first
            : proposals.first.dive.id;
      }

      state = state.copyWith(
        isLoading: false,
        proposals: proposals,
        selections: selections,
        focusedDiveId: focus,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Matching failed: $e',
      );
    }
  }

  void focusDive(String diveId) =>
      state = state.copyWith(focusedDiveId: diveId);

  /// Toggles the selected candidate for a dive (tap again to deselect).
  void select(String diveId, String candidateId) {
    final next = Map<String, String>.from(state.selections);
    if (next[diveId] == candidateId) {
      next.remove(diveId);
    } else {
      next[diveId] = candidateId;
    }
    state = state.copyWith(selections: next);
  }

  /// Applies all selections in one transaction. Returns the result, or null if
  /// there is nothing to apply or the apply fails. Apply failures are transient:
  /// [errorMessage] is left unset (it is fatal-only) and the page surfaces the
  /// null result with a snackbar, keeping the review screen up for retry.
  Future<ApplyResult?> confirm() async {
    final service = _service;
    // Nothing to apply: not initialised yet, or no site chosen. The confirm
    // button is disabled when nothing is selected, but guard here too so we
    // never open an empty transaction (keeps the doc's contract honest).
    if (service == null || state.selections.isEmpty) return null;
    state = state.copyWith(isApplying: true);
    try {
      final confirmed = [
        for (final e in state.selections.entries)
          ConfirmedMatch(e.key, e.value),
      ];
      final result = await service.applyConfirmed(confirmed);
      // The writes bypass DiveListNotifier (the only thing that reloads the
      // dives list), so without this the list keeps showing the pre-match
      // "unknown site" rows. Refresh the affected views before returning.
      if (mounted) await _refreshAfterApply(confirmed, result);
      if (mounted) state = state.copyWith(isApplying: false);
      return result;
    } catch (e) {
      // Apply failures are transient: the page surfaces them with a snackbar
      // (confirm returns null) and keeps the review screen so the user can
      // retry. Don't set the fatal errorMessage, which replaces the whole UI.
      if (mounted) state = state.copyWith(isApplying: false);
      return null;
    }
  }

  /// Refreshes the views invalidated by [applyConfirmed]'s direct writes:
  /// the dives list (drops stale "unknown site" rows), dive statistics, the
  /// per-dive detail cache for each linked dive, and the sites list when
  /// bundled sites were materialised.
  Future<void> _refreshAfterApply(
    List<ConfirmedMatch> confirmed,
    ApplyResult result,
  ) async {
    await _ref.read(diveListNotifierProvider.notifier).refresh();
    _ref.invalidate(diveStatisticsProvider);
    for (final c in confirmed) {
      _ref.invalidate(diveProvider(c.diveId));
    }
    if (result.sitesCreated > 0) {
      await _ref.read(siteListNotifierProvider.notifier).refresh();
    }
  }
}

final siteMatchReviewProvider = StateNotifierProvider.autoDispose
    .family<SiteMatchReviewNotifier, SiteMatchReviewState, List<String>?>(
      (ref, diveIds) => SiteMatchReviewNotifier(ref, diveIds),
    );

/// Value-equality key for [eligibleImportedDivesProvider] so the autoDispose
/// family caches by the id set's contents (deep `==`), not list identity.
class ImportedDiveIds extends Equatable {
  const ImportedDiveIds(this.ids);
  final List<String> ids;
  @override
  List<Object?> get props => [ids];
}

/// Of the given imported dive ids, which are eligible for site matching
/// (have GPS and no assigned site). Used to decide whether to surface the
/// post-download "match" button and what count to show.
final eligibleImportedDivesProvider = FutureProvider.autoDispose
    .family<List<String>, ImportedDiveIds>((ref, arg) async {
      if (arg.ids.isEmpty) return const [];
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final dives = await ref
          .read(diveRepositoryProvider)
          .getDivesNeedingSiteMatch(diverId: diverId, limitToIds: arg.ids);
      return dives.map((d) => d.id).toList();
    });
