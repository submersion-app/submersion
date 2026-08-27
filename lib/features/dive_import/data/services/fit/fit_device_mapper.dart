/// Maps Garmin FIT `file_id.garmin_product` codes to human model names.
///
/// Verified from sample files: 4223=Mk3i, 4518=X50i, 3865=T2 transmitter.
/// Mk1/Mk2/Mk2s codes are from fit_tool's GarminProduct enum. fit_tool 1.0.5
/// predates the Mk3i/X50i, so those return a raw int rather than a named enum.
/// Unknown/null -> a generic name.
class FitDeviceMapper {
  const FitDeviceMapper._();

  static const Map<int, String> _models = {
    2859: 'Descent Mk1',
    3258: 'Descent Mk2 / Mk2i',
    3542: 'Descent Mk2s',
    3865: 'Descent T2 Transmitter',
    4223: 'Descent Mk3i',
    4518: 'Descent X50i',
  };

  static String modelName(int? garminProduct) {
    if (garminProduct == null) return 'Garmin Descent';
    return _models[garminProduct] ?? 'Garmin Descent';
  }
}
