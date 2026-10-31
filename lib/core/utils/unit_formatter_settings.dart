import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';

/// The settings a [UnitFormatter] can hand out, to itself or to whoever holds
/// one (issue #3818).
///
/// `unitFormatterProvider` keeps one formatter until one of these changes, so
/// it would go stale for anything read through it that is not listed here. A
/// formatter is typed to this view rather than to `AppSettings` so that such a
/// read does not compile. Add the field here and to
/// [unitFormatterSettingsKey], or watch it with
/// `settingsProvider.select`.
abstract interface class UnitFormatterSettings {
  DepthUnit get depthUnit;
  TemperatureUnit get temperatureUnit;
  PressureUnit get pressureUnit;
  VolumeUnit get volumeUnit;
  WeightUnit get weightUnit;
  AltitudeUnit get altitudeUnit;
  DistanceUnit get distanceUnit;
  CoordinateFormat get coordinateFormat;
  TimeFormat get timeFormat;
  DateFormatPreference get dateFormat;

  /// Not read by the formatter, whose digits and month names follow
  /// `Intl.defaultLocale`. `lib/app.dart` sets that from this value, and a
  /// widget that only formats has no other reason to rebuild when it changes.
  String get locale;

  GasModel get gasModel;
  GasConsumptionDisplay get gasConsumptionDisplay;
  String get defaultCurrency;
  double get defaultStartPressure;
  int get gfHigh;
  double get endLimit;
  bool get o2Narcotic;
  double get ppO2MaxWorking;
  double get ppO2MaxDeco;
  bool get ppO2DecoBandsEnabled;
  double get ppO2DecoBand1;
  double get ppO2DecoBand2;
  double get ppO2DecoBand3;
  bool get maxO2DepthEnabled;
  double get maxO2DepthMeters;
  double get ccrDiluentModPpO2;
}

/// A value equal for two settings exactly when a formatter built from either
/// reads the same. A record, for its field-by-field equality.
Object unitFormatterSettingsKey(UnitFormatterSettings s) => (
  s.depthUnit,
  s.temperatureUnit,
  s.pressureUnit,
  s.volumeUnit,
  s.weightUnit,
  s.altitudeUnit,
  s.distanceUnit,
  s.coordinateFormat,
  s.timeFormat,
  s.dateFormat,
  s.locale,
  s.gasModel,
  s.gasConsumptionDisplay,
  s.defaultCurrency,
  s.defaultStartPressure,
  s.gfHigh,
  s.endLimit,
  s.o2Narcotic,
  s.ppO2MaxWorking,
  s.ppO2MaxDeco,
  s.ppO2DecoBandsEnabled,
  s.ppO2DecoBand1,
  s.ppO2DecoBand2,
  s.ppO2DecoBand3,
  s.maxO2DepthEnabled,
  s.maxO2DepthMeters,
  s.ccrDiluentModPpO2,
);
