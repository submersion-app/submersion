import 'package:equatable/equatable.dart';

import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';

/// A buddy a legacy name can be matched to: the active diver's own records
/// and unowned ones (#1831).
class MatchCandidate extends Equatable {
  const MatchCandidate({
    required this.id,
    required this.name,
    this.diverId,
    this.diveCount = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? diverId;

  /// Dives this buddy is linked to; ranks namesakes.
  final int diveCount;
  final DateTime createdAt;

  MatchCandidate copyWith({
    String? id,
    String? name,
    String? diverId,
    int? diveCount,
    DateTime? createdAt,
  }) => MatchCandidate(
    id: id ?? this.id,
    name: name ?? this.name,
    diverId: diverId ?? this.diverId,
    diveCount: diveCount ?? this.diveCount,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [id, name, diverId, diveCount, createdAt];
}

/// Where a planned link points: an existing buddy or one to create.
sealed class LinkTarget extends Equatable {
  const LinkTarget();

  /// The name shown for the link.
  String get name;
}

final class ExistingBuddyTarget extends LinkTarget {
  const ExistingBuddyTarget({required this.buddyId, required this.name});

  final String buddyId;
  @override
  final String name;

  ExistingBuddyTarget copyWith({String? buddyId, String? name}) =>
      ExistingBuddyTarget(
        buddyId: buddyId ?? this.buddyId,
        name: name ?? this.name,
      );

  @override
  List<Object?> get props => [buddyId, name];
}

final class NewBuddyTarget extends LinkTarget {
  const NewBuddyTarget(this.name);

  @override
  final String name;

  NewBuddyTarget copyWith({String? name}) => NewBuddyTarget(name ?? this.name);

  @override
  List<Object?> get props => [name];
}

/// One person a conversion will link to a dive, with the role to use.
class PlannedLink extends Equatable {
  const PlannedLink({
    required this.target,
    required this.roleId,
    this.suggestion,
    this.tieCount = 1,
  });

  final LinkTarget target;

  /// A `dive_roles` id.
  final String roleId;

  /// A likely existing buddy for a new name (`Leo` for `Leo Cox`), shown by
  /// the per-dive review and never applied on its own.
  final MatchCandidate? suggestion;

  /// How many buddies share an exact name match; above one the review warns.
  final int tieCount;

  String get name => target.name;

  /// Two links with the same identity write the same dive link.
  String get identity => switch (target) {
    ExistingBuddyTarget(:final buddyId) => 'id:$buddyId',
    NewBuddyTarget(:final name) => 'new:${legacyNameKey(name)}',
  };

  PlannedLink copyWith({
    LinkTarget? target,
    String? roleId,
    MatchCandidate? suggestion,
    bool clearSuggestion = false,
    int? tieCount,
  }) => PlannedLink(
    target: target ?? this.target,
    roleId: roleId ?? this.roleId,
    suggestion: clearSuggestion ? null : (suggestion ?? this.suggestion),
    tieCount: tieCount ?? this.tieCount,
  );

  @override
  List<Object?> get props => [target, roleId, suggestion, tieCount];
}

/// The links one dive's legacy text turns into.
class ConversionPlan extends Equatable {
  const ConversionPlan({
    required this.diveId,
    this.buddyText,
    this.diveMasterText,
    this.links = const [],
  });

  final String diveId;
  final String? buddyText;
  final String? diveMasterText;
  final List<PlannedLink> links;

  bool get isEmpty => links.isEmpty;

  ConversionPlan copyWith({List<PlannedLink>? links}) => ConversionPlan(
    diveId: diveId,
    buddyText: buddyText,
    diveMasterText: diveMasterText,
    links: links ?? this.links,
  );

  @override
  List<Object?> get props => [diveId, buddyText, diveMasterText, links];
}

/// Everything an applied conversion wrote, so Undo can reverse exactly that.
class ConversionReceipt extends Equatable {
  const ConversionReceipt({
    required this.diverId,
    this.diveIds = const [],
    this.linkIds = const [],
    this.createdBuddyIds = const [],
    this.claimedBuddyIds = const [],
  });

  final String diverId;

  /// Dives that received links.
  final List<String> diveIds;
  final List<String> linkIds;
  final List<String> createdBuddyIds;

  /// Unowned buddies the conversion assigned to [diverId].
  final List<String> claimedBuddyIds;

  bool get isEmpty =>
      linkIds.isEmpty && createdBuddyIds.isEmpty && claimedBuddyIds.isEmpty;

  ConversionReceipt copyWith({
    String? diverId,
    List<String>? diveIds,
    List<String>? linkIds,
    List<String>? createdBuddyIds,
    List<String>? claimedBuddyIds,
  }) => ConversionReceipt(
    diverId: diverId ?? this.diverId,
    diveIds: diveIds ?? this.diveIds,
    linkIds: linkIds ?? this.linkIds,
    createdBuddyIds: createdBuddyIds ?? this.createdBuddyIds,
    claimedBuddyIds: claimedBuddyIds ?? this.claimedBuddyIds,
  );

  @override
  List<Object?> get props => [
    diverId,
    diveIds,
    linkIds,
    createdBuddyIds,
    claimedBuddyIds,
  ];
}

/// A dive with legacy buddy text and no linked buddies, as read from the
/// database.
class UnlinkedTextDive extends Equatable {
  const UnlinkedTextDive({
    required this.diveId,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.buddyText,
    this.diveMasterText,
  });

  final String diveId;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final String? buddyText;
  final String? diveMasterText;

  UnlinkedTextDive copyWith({String? buddyText, String? diveMasterText}) =>
      UnlinkedTextDive(
        diveId: diveId,
        diveNumber: diveNumber,
        dateTime: dateTime,
        siteName: siteName,
        buddyText: buddyText ?? this.buddyText,
        diveMasterText: diveMasterText ?? this.diveMasterText,
      );

  @override
  List<Object?> get props => [
    diveId,
    diveNumber,
    dateTime,
    siteName,
    buddyText,
    diveMasterText,
  ];
}

/// A dive on the bulk page: its plan plus what identifies it to the diver.
class CandidateDive extends Equatable {
  const CandidateDive({
    required this.plan,
    this.diveNumber,
    required this.dateTime,
    this.siteName,
  });

  final ConversionPlan plan;
  final int? diveNumber;
  final DateTime dateTime;
  final String? siteName;

  String get diveId => plan.diveId;

  CandidateDive copyWith({ConversionPlan? plan}) => CandidateDive(
    plan: plan ?? this.plan,
    diveNumber: diveNumber,
    dateTime: dateTime,
    siteName: siteName,
  );

  @override
  List<Object?> get props => [plan, diveNumber, dateTime, siteName];
}
