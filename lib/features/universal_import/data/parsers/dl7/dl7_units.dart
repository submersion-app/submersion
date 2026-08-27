/// Unit declarations from a DL7 ZRH record header, with SI conversions.
///
/// ZRH fields (tag at index 0): 4 depth unit (MSWG/MFWG metric,
/// FSWG/FFWG feet), 6 temperature (C/F), 7 tank pressure (BAR/PSI/PSIA),
/// 8 tank volume (L/CF). Matching is case-insensitive and prefix-based
/// because real exporters vary the spelling (MSWG vs MFWG, BAR vs bar).
class Dl7Units {
  static const feetToMeters = 0.3048;
  static const psiToBar = 0.0689476;
  static const cubicFeetToLiters = 28.3168;

  final bool depthIsFeet;
  final bool tempIsFahrenheit;
  final bool pressureIsPsi;
  final bool volumeIsCubicFeet;

  const Dl7Units({
    this.depthIsFeet = false,
    this.tempIsFahrenheit = false,
    this.pressureIsPsi = false,
    this.volumeIsCubicFeet = false,
  });

  factory Dl7Units.fromZrh(List<String> zrhFields) {
    String field(int index) =>
        index < zrhFields.length ? zrhFields[index].trim().toUpperCase() : '';
    return Dl7Units(
      depthIsFeet: field(4).startsWith('F'),
      tempIsFahrenheit: field(6) == 'F',
      pressureIsPsi: field(7).startsWith('PSI'),
      volumeIsCubicFeet: field(8) == 'CF',
    );
  }

  double depthToMeters(double value) =>
      depthIsFeet ? value * feetToMeters : value;

  double tempToCelsius(double value) =>
      tempIsFahrenheit ? (value - 32) * 5 / 9 : value;

  double pressureToBar(double value) =>
      pressureIsPsi ? value * psiToBar : value;
}
