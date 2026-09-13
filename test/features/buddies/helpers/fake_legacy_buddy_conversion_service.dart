import 'dart:async';

import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Plans a fixed [plan] and records what the UI applies and undoes.
class FakeLegacyBuddyConversionService implements LegacyBuddyConversionService {
  FakeLegacyBuddyConversionService({
    ConversionPlan? plan,
    BuddyNameMatcher? matcher,
    this.receipt = defaultReceipt,
  }) : plan = plan ?? const ConversionPlan(diveId: 'd1'),
       matcher = matcher ?? BuddyNameMatcher(const [], diverId: 'me');

  static const defaultReceipt = ConversionReceipt(
    diverId: 'me',
    diveIds: ['d1'],
    linkIds: ['l1'],
    createdBuddyIds: ['b1'],
  );

  final ConversionPlan plan;
  final BuddyNameMatcher matcher;
  final ConversionReceipt receipt;
  final List<List<ConversionPlan>> applied = [];
  final List<ConversionReceipt> undone = [];
  int planForCalls = 0;
  int planCandidatesCalls = 0;

  /// When set, [planFor] waits for it, holding a review "in flight".
  Completer<void>? planForGate;

  @override
  Future<BuddyNameMatcher> matcherFor(String diverId) async => matcher;

  @override
  Future<(ConversionPlan, BuddyNameMatcher)> planFor(
    Dive dive,
    String diverId,
  ) async {
    planForCalls++;
    await planForGate?.future;
    return (plan, matcher);
  }

  @override
  Future<LinkBuddyNamesData> planCandidates(String diverId) async {
    planCandidatesCalls++;
    return LinkBuddyNamesData(
      diverId: diverId,
      matcher: matcher,
      dives: const [],
    );
  }

  @override
  Future<ConversionReceipt> apply(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) async {
    applied.add(plans);
    return receipt;
  }

  @override
  Future<void> undo(ConversionReceipt receipt) async => undone.add(receipt);
}
