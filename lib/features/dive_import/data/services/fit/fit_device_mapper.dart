/// Maps Garmin FIT `file_id.garmin_product` codes to human model names.
///
/// 4223=Mk3i, 4518=X50i and 3865=T2 transmitter were verified from sample
/// files. The rest come from the `garmin_product` enum in Garmin's FIT SDK
/// profile. Dive mode is not limited to the Descent line: Fenix, Epix, Enduro
/// and Tactix watches log dives too, so an unrecognised product is named
/// plainly "Garmin" rather than guessed to be a Descent (#1605).
class FitDeviceMapper {
  const FitDeviceMapper._();

  static const Map<int, String> _models = {
    // Descent dive computers.
    2859: 'Descent Mk1',
    3258: 'Descent Mk2 / Mk2i',
    3542: 'Descent Mk2s',
    3702: 'Descent Mk2 / Mk2i',
    3930: 'Descent Mk2s',
    3865: 'Descent T2 Transmitter',
    4005: 'Descent G1',
    4132: 'Descent G1',
    4222: 'Descent Mk3',
    4223: 'Descent Mk3i',
    4518: 'Descent X50i',
    4588: 'Descent G2',
    // Fenix 7.
    3905: 'Fenix 7S',
    3906: 'Fenix 7',
    3907: 'Fenix 7X',
    3908: 'Fenix 7S',
    3909: 'Fenix 7',
    3910: 'Fenix 7X',
    4374: 'Fenix 7S Pro Solar',
    4375: 'Fenix 7 Pro Solar',
    4376: 'Fenix 7X Pro Solar',
    4595: 'Fenix 7 Pro Solar',
    // Fenix 8.
    4532: 'Fenix 8 Solar',
    4533: 'Fenix 8 Solar',
    4534: 'Fenix 8',
    4536: 'Fenix 8',
    4631: 'Fenix 8 Pro',
    // Epix.
    3943: 'Epix (Gen 2)',
    3944: 'Epix (Gen 2)',
    4312: 'Epix Pro (Gen 2)',
    4313: 'Epix Pro (Gen 2)',
    4314: 'Epix Pro (Gen 2)',
    // Enduro and Tactix.
    4341: 'Enduro 2',
    4575: 'Enduro 3',
    4135: 'Tactix 7',
    4775: 'Tactix 8',
    4776: 'Tactix 8',
  };

  static String modelName(int? garminProduct) {
    if (garminProduct == null) return 'Garmin';
    return _models[garminProduct] ?? 'Garmin';
  }
}
