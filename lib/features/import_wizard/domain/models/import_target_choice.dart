/// Which profile a dive computer download goes to, when the computer belongs
/// to a profile other than the active one (issue #2050).
///
/// The review step shows it as a notice with a profile picker. Choosing
/// another profile applies to that download only; the computer's owner never
/// changes.
class ImportTargetChoice {
  const ImportTargetChoice({
    required this.ownerDiverId,
    required this.chosenDiverId,
  });

  /// The profile that owns the computer.
  final String ownerDiverId;

  /// The profile the dives will be added to.
  final String chosenDiverId;

  @override
  bool operator ==(Object other) =>
      other is ImportTargetChoice &&
      other.ownerDiverId == ownerDiverId &&
      other.chosenDiverId == chosenDiverId;

  @override
  int get hashCode => Object.hash(ownerDiverId, chosenDiverId);

  @override
  String toString() =>
      'ImportTargetChoice(owner: $ownerDiverId, chosen: $chosenDiverId)';
}
