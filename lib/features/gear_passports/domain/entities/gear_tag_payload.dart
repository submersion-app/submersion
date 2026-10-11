import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// What a gear tag says about an item (gear tag spec section 6.2).
///
/// A snapshot written when the label was printed or the NFC tag written.
/// Only [passportId] identifies the item; the rest is what the diver's
/// record looked like on [writtenOn]. [typeCode] is kept as written so a
/// type added by a newer app still opens.
class GearTagPayload extends Equatable {
  static const int currentFormatVersion = 1;
  static const int maxNameLength = 40;
  static const int maxShortTextLength = 24;

  /// Type codes are enum names; the cap only stops a hostile tag from
  /// carrying an essay in a field the page prints.
  static const int maxTypeCodeLength = 32;

  final int formatVersion;
  final String passportId;
  final String typeCode;
  final DateTime? writtenOn;
  final String? name;
  final String? brand;
  final String? model;
  final String? serial;
  final DateTime? lastService;

  const GearTagPayload({
    this.formatVersion = currentFormatVersion,
    required this.passportId,
    required this.typeCode,
    this.writtenOn,
    this.name,
    this.brand,
    this.model,
    this.serial,
    this.lastService,
  });

  /// The type [typeCode] names, or null for one this app does not know.
  EquipmentType? get type => EquipmentType.values.asNameMap()[typeCode];

  GearTagPayload copyWith({
    int? formatVersion,
    String? passportId,
    String? typeCode,
    DateTime? writtenOn,
    bool clearWrittenOn = false,
    String? name,
    bool clearName = false,
    String? brand,
    bool clearBrand = false,
    String? model,
    bool clearModel = false,
    String? serial,
    bool clearSerial = false,
    DateTime? lastService,
    bool clearLastService = false,
  }) => GearTagPayload(
    formatVersion: formatVersion ?? this.formatVersion,
    passportId: passportId ?? this.passportId,
    typeCode: typeCode ?? this.typeCode,
    writtenOn: clearWrittenOn ? null : (writtenOn ?? this.writtenOn),
    name: clearName ? null : (name ?? this.name),
    brand: clearBrand ? null : (brand ?? this.brand),
    model: clearModel ? null : (model ?? this.model),
    serial: clearSerial ? null : (serial ?? this.serial),
    lastService: clearLastService ? null : (lastService ?? this.lastService),
  );

  @override
  List<Object?> get props => [
    formatVersion,
    passportId,
    typeCode,
    writtenOn,
    name,
    brand,
    model,
    serial,
    lastService,
  ];
}
