import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Valve fitting, as the tag spells it.
enum PassportValve {
  din('din'),
  yoke('yoke'),
  convertible('conv');

  final String code;
  const PassportValve(this.code);

  static PassportValve? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// What a cylinder's tag says about it (spec section 6.2).
///
/// A snapshot written when the label was printed or the NFC tag written.
/// Only [passportId] identifies the cylinder; every other field is what the
/// diver's record looked like on [writtenOn], so the passport compares them
/// with the live row and reports a stale tag. All values are metric.
class CylinderPassportPayload extends Equatable {
  static const int currentFormatVersion = 1;
  static const int maxNameLength = 40;

  /// Stamped serials are short; the cap keeps a label's QR inside its
  /// designed density whatever the equipment editor accepted.
  static const int maxSerialLength = 24;

  final int formatVersion;
  final String passportId;
  final DateTime? writtenOn;
  final String? name;
  final String? serial;
  final double? volumeL;
  final int? workingPressureBar;
  final TankMaterial? material;
  final PassportValve? valve;
  final DateTime? lastHydro;
  final DateTime? lastVip;
  final bool o2Clean;

  const CylinderPassportPayload({
    this.formatVersion = currentFormatVersion,
    required this.passportId,
    this.writtenOn,
    this.name,
    this.serial,
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.valve,
    this.lastHydro,
    this.lastVip,
    this.o2Clean = false,
  });

  CylinderPassportPayload copyWith({
    int? formatVersion,
    String? passportId,
    DateTime? writtenOn,
    bool clearWrittenOn = false,
    String? name,
    bool clearName = false,
    String? serial,
    bool clearSerial = false,
    double? volumeL,
    bool clearVolumeL = false,
    int? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? material,
    bool clearMaterial = false,
    PassportValve? valve,
    bool clearValve = false,
    DateTime? lastHydro,
    bool clearLastHydro = false,
    DateTime? lastVip,
    bool clearLastVip = false,
    bool? o2Clean,
  }) => CylinderPassportPayload(
    formatVersion: formatVersion ?? this.formatVersion,
    passportId: passportId ?? this.passportId,
    writtenOn: clearWrittenOn ? null : (writtenOn ?? this.writtenOn),
    name: clearName ? null : (name ?? this.name),
    serial: clearSerial ? null : (serial ?? this.serial),
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    material: clearMaterial ? null : (material ?? this.material),
    valve: clearValve ? null : (valve ?? this.valve),
    lastHydro: clearLastHydro ? null : (lastHydro ?? this.lastHydro),
    lastVip: clearLastVip ? null : (lastVip ?? this.lastVip),
    o2Clean: o2Clean ?? this.o2Clean,
  );

  @override
  List<Object?> get props => [
    formatVersion,
    passportId,
    writtenOn,
    name,
    serial,
    volumeL,
    workingPressureBar,
    material,
    valve,
    lastHydro,
    lastVip,
    o2Clean,
  ];
}
