import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// The tank catalog's choice key for a material (spec 6.2 `m`).
String tankMaterialChoiceKey(TankMaterial material) => switch (material) {
  TankMaterial.aluminum => 'aluminum',
  TankMaterial.steel => 'steel',
  TankMaterial.carbonFiber => 'carbon_composite',
};

/// The tank catalog's choice key for a valve (spec 6.2 `vt`).
String valveChoiceKey(PassportValve valve) => switch (valve) {
  PassportValve.din => 'din',
  PassportValve.yoke => 'yoke',
  PassportValve.convertible => 'convertible',
};
