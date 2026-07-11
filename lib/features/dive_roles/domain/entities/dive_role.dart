import 'package:equatable/equatable.dart';

/// A per-dive role (built-in or user-defined) from the dive_roles table.
/// Built-in ids are the legacy BuddyRole enum names; custom ids are UUIDs.
class DiveRole extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final bool isBuiltIn;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveRole({
    required this.id,
    this.diverId,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String buddyId = 'buddy';
  static const String diveGuideId = 'diveGuide';
  static const String instructorId = 'instructor';
  static const String studentId = 'student';
  static const String diveMasterId = 'diveMaster';
  static const String soloId = 'solo';
  static const String rearGuardId = 'rearGuard';
  static const String supportDiverId = 'supportDiver';
  static const String safetyDiverId = 'safetyDiver';

  /// Built-in ids in seed sortOrder. Must match kSeedBuiltInDiveRolesSql.
  static const List<String> builtInIds = [
    buddyId,
    diveGuideId,
    instructorId,
    studentId,
    diveMasterId,
    soloId,
    rearGuardId,
    supportDiverId,
    safetyDiverId,
  ];

  /// Placeholder for a role id with no dive_roles row (legacy or
  /// not-yet-synced data). Displays the raw slug instead of silently
  /// renaming it to Buddy.
  factory DiveRole.synthetic(String slug) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return DiveRole(id: slug, name: slug, createdAt: epoch, updatedAt: epoch);
  }

  /// The default role, used where legacy code assumed BuddyRole.buddy.
  factory DiveRole.builtInBuddy() {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return DiveRole(
      id: buddyId,
      name: 'Buddy',
      isBuiltIn: true,
      createdAt: epoch,
      updatedAt: epoch,
    );
  }

  DiveRole copyWith({
    String? id,
    String? diverId,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveRole(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    isBuiltIn,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
