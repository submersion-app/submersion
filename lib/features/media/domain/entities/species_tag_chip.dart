import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A species tag as the viewer shows it: enough to render a chip and to
/// localize the name at display time (built-ins resolve through their id).
class SpeciesTagChip extends Equatable {
  final String speciesId;
  final String storedName;
  final SpeciesCategory category;
  final bool isBuiltIn;

  /// The app applied the tag and the diver has not confirmed it yet (issue
  /// #4727): drawn apart from the diver's own tags.
  final bool unconfirmed;

  const SpeciesTagChip({
    required this.speciesId,
    required this.storedName,
    required this.category,
    required this.isBuiltIn,
    this.unconfirmed = false,
  });

  SpeciesTagChip copyWith({
    String? speciesId,
    String? storedName,
    SpeciesCategory? category,
    bool? isBuiltIn,
    bool? unconfirmed,
  }) {
    return SpeciesTagChip(
      speciesId: speciesId ?? this.speciesId,
      storedName: storedName ?? this.storedName,
      category: category ?? this.category,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      unconfirmed: unconfirmed ?? this.unconfirmed,
    );
  }

  @override
  List<Object?> get props => [
    speciesId,
    storedName,
    category,
    isBuiltIn,
    unconfirmed,
  ];
}
