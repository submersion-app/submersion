import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What the bulk page shows: every dive with unlinked text, planned against
/// one matcher that the per-dive review reuses.
class LinkBuddyNamesData {
  const LinkBuddyNamesData({
    required this.diverId,
    required this.matcher,
    required this.dives,
  });

  final String diverId;
  final BuddyNameMatcher matcher;
  final List<CandidateDive> dives;
}

/// Plans legacy buddy text conversions and applies them through
/// [BuddyRepository] (#1831).
class LegacyBuddyConversionService {
  const LegacyBuddyConversionService(this._repository);

  final BuddyRepository _repository;

  Future<BuddyNameMatcher> matcherFor(String diverId) async => BuddyNameMatcher(
    await _repository.legacyConversionCandidates(diverId),
    diverId: diverId,
  );

  /// The plan for [dive], with the matcher the review sheet re-matches
  /// edited names against.
  Future<(ConversionPlan, BuddyNameMatcher)> planFor(
    Dive dive,
    String diverId,
  ) async {
    final matcher = await matcherFor(diverId);
    final plan = planLegacyConversion(
      diveId: dive.id,
      buddyText: dive.buddy,
      diveMasterText: dive.diveMaster,
      matcher: matcher,
    );
    return (plan, matcher);
  }

  /// Every dive of [diverId] whose legacy text parses to at least one name.
  Future<LinkBuddyNamesData> planCandidates(String diverId) async {
    final matcher = await matcherFor(diverId);
    final rows = await _repository.unlinkedLegacyTextDives(diverId);
    final dives = <CandidateDive>[];
    for (final row in rows) {
      final plan = planLegacyConversion(
        diveId: row.diveId,
        buddyText: row.buddyText,
        diveMasterText: row.diveMasterText,
        matcher: matcher,
      );
      if (plan.isEmpty) continue;
      dives.add(
        CandidateDive(
          plan: plan,
          diveNumber: row.diveNumber,
          dateTime: row.dateTime,
          siteName: row.siteName,
        ),
      );
    }
    return LinkBuddyNamesData(
      diverId: diverId,
      matcher: matcher,
      dives: List.unmodifiable(dives),
    );
  }

  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) => _repository.applyLegacyConversion(
    plans,
    diverId: diverId,
    newBuddyNote: newBuddyNote,
  );

  Future<void> undo(ConversionReceipt receipt) =>
      _repository.undoLegacyConversion(receipt);
}
