import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A species tag as the viewer shows it: enough to render a chip and to
/// localize the name at display time (built-ins resolve through their id).
class SpeciesTagChip extends Equatable {
  final String speciesId;
  final String storedName;
  final SpeciesCategory category;
  final bool isBuiltIn;

  const SpeciesTagChip({
    required this.speciesId,
    required this.storedName,
    required this.category,
    required this.isBuiltIn,
  });

  SpeciesTagChip copyWith({
    String? speciesId,
    String? storedName,
    SpeciesCategory? category,
    bool? isBuiltIn,
  }) {
    return SpeciesTagChip(
      speciesId: speciesId ?? this.speciesId,
      storedName: storedName ?? this.storedName,
      category: category ?? this.category,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [speciesId, storedName, category, isBuiltIn];
}
