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

  /// The unit this item's number is read and typed in (issue #4534), as an
  /// `AttributeUnit` name (`psi`, `pounds`, `dual`, ...). Null follows the
  /// diver's settings. [valueNum] stays canonical metric either way.
  final String? valueUnit;
  final int sortOrder;

  const EquipmentAttribute({
    required this.id,
    required this.equipmentId,
    required this.key,
    this.isCustom = false,
    this.valueText,
    this.valueNum,
    this.valueUnit,
    this.sortOrder = 0,
  });

  factory EquipmentAttribute.curated({
    required String equipmentId,
    required String key,
    String? valueText,
    double? valueNum,
    String? valueUnit,
  }) => EquipmentAttribute(
    id: curatedId(equipmentId, key),
    equipmentId: equipmentId,
    key: key,
    valueText: valueText,
    valueNum: valueNum,
    valueUnit: valueUnit,
  );

  /// Deterministic id for curated rows: identical on every device, so
  /// independently created/migrated rows converge under sync.
  static String curatedId(String equipmentId, String key) =>
      'attr_${equipmentId}_$key';

  bool get hasValue =>
      (valueText != null && valueText!.trim().isNotEmpty) || valueNum != null;

  /// Worth a row: a value, or a unit picked before the value was typed. The
  /// detail page shows only [hasValue] rows; a save keeps both.
  bool get hasContent => hasValue || valueUnit != null;

  EquipmentAttribute copyWith({
    String? id,
    String? equipmentId,
    String? key,
    bool? isCustom,
    String? valueText,
    double? valueNum,
    String? valueUnit,
    int? sortOrder,
    bool clearValueText = false,
    bool clearValueNum = false,
    bool clearValueUnit = false,
  }) => EquipmentAttribute(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    key: key ?? this.key,
    isCustom: isCustom ?? this.isCustom,
    valueText: clearValueText ? null : (valueText ?? this.valueText),
    valueNum: clearValueNum ? null : (valueNum ?? this.valueNum),
    valueUnit: clearValueUnit ? null : (valueUnit ?? this.valueUnit),
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
    valueUnit,
    sortOrder,
  ];
}
