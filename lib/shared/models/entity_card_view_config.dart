import 'package:equatable/equatable.dart';

import 'package:submersion/shared/constants/entity_field.dart';

/// Configuration for a single named slot in a card view.
///
/// This is the generic version of [CardSlotConfig] from the Dives feature,
/// parameterized over any [EntityField] implementation instead of being
/// hard-coded to [DiveField].
class EntityCardSlotConfig<F extends EntityField> extends Equatable {
  final String slotId;
  final F field;

  const EntityCardSlotConfig({required this.slotId, required this.field});

  EntityCardSlotConfig<F> copyWith({String? slotId, F? field}) {
    return EntityCardSlotConfig(
      slotId: slotId ?? this.slotId,
      field: field ?? this.field,
    );
  }

  Map<String, dynamic> toJson() {
    return {'slotId': slotId, 'field': field.name};
  }

  static EntityCardSlotConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    return EntityCardSlotConfig<F>(
      slotId: json['slotId'] as String,
      field: fieldFromName(json['field'] as String),
    );
  }

  @override
  List<Object?> get props => [slotId, field];
}

/// Configuration for a card-based list view (compact or detailed).
///
/// This is the generic version of [CardViewConfig] from the Dives feature,
/// parameterized over any [EntityField] implementation. It holds the slot
/// assignments that determine which fields appear in which card positions,
/// plus optional extra fields for detailed views.
class EntityCardViewConfig<F extends EntityField> extends Equatable {
  final List<EntityCardSlotConfig<F>> slots;
  final List<F> extraFields;

  const EntityCardViewConfig({
    required this.slots,
    this.extraFields = const [],
  });

  EntityCardViewConfig<F> copyWith({
    List<EntityCardSlotConfig<F>>? slots,
    List<F>? extraFields,
  }) {
    return EntityCardViewConfig(
      slots: slots ?? this.slots,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slots': slots.map((s) => s.toJson()).toList(),
      'extraFields': extraFields.map((f) => f.name).toList(),
    };
  }

  static EntityCardViewConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    return EntityCardViewConfig<F>(
      slots: (json['slots'] as List<dynamic>)
          .map(
            (s) => EntityCardSlotConfig.fromJson<F>(
              s as Map<String, dynamic>,
              fieldFromName,
            ),
          )
          .toList(),
      extraFields:
          (json['extraFields'] as List<dynamic>?)
              ?.map((f) => fieldFromName(f as String))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [slots, extraFields];
}
