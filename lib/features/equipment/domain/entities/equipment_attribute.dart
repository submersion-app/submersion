import 'package:equatable/equatable.dart';

/// One attribute value on an equipment item. Curated attributes (isCustom =
/// false) have keys defined in EquipmentAttributeCatalog and deterministic
/// ids; custom fields carry the user's label in [key] and a random UUID id.
class EquipmentAttribute extends Equatable {
  final String id;
  final String equipmentId;
  final String key;
  final bool isCustom;
  final String? valueText;
  final double? valueNum;
  final int sortOrder;

  const EquipmentAttribute({
    required this.id,
    required this.equipmentId,
    required this.key,
    this.isCustom = false,
    this.valueText,
    this.valueNum,
    this.sortOrder = 0,
  });

  factory EquipmentAttribute.curated({
    required String equipmentId,
    required String key,
    String? valueText,
    double? valueNum,
  }) => EquipmentAttribute(
    id: curatedId(equipmentId, key),
    equipmentId: equipmentId,
    key: key,
    valueText: valueText,
    valueNum: valueNum,
  );

  /// Deterministic id for curated rows: identical on every device, so
  /// independently created/migrated rows converge under sync.
  static String curatedId(String equipmentId, String key) =>
      'attr_${equipmentId}_$key';

  bool get hasValue =>
      (valueText != null && valueText!.trim().isNotEmpty) || valueNum != null;

  EquipmentAttribute copyWith({
    String? id,
    String? equipmentId,
    String? key,
    bool? isCustom,
    String? valueText,
    double? valueNum,
    int? sortOrder,
    bool clearValueText = false,
    bool clearValueNum = false,
  }) => EquipmentAttribute(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    key: key ?? this.key,
    isCustom: isCustom ?? this.isCustom,
    valueText: clearValueText ? null : (valueText ?? this.valueText),
    valueNum: clearValueNum ? null : (valueNum ?? this.valueNum),
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    key,
    isCustom,
    valueText,
    valueNum,
    sortOrder,
  ];
}
