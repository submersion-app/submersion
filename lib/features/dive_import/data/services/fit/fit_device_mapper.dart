/// Maps FIT `file_id` identity fields to human model names: Garmin
/// `garmin_product` codes, Suunto product codes and `product_name`.
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

  /// Suunto `file_id.product` codes. 73=Nautic S was verified from a Suunto
  /// app export (#3045).
  static const Map<int, String> _suuntoModels = {73: 'Nautic S'};

  /// `file_id.manufacturer` codes whose `product` is a `garmin_product`:
  /// Garmin, Dynastream, Dynastream OEM and Tacx, the codes fit_tool reads
  /// the `garminProduct` subfield for.
  static const Set<int> _garminFamily = {1, 13, 15, 89};

  static const int _suunto = 23;

  /// The computer model a FIT file's `file_id` names (#3045).
  ///
  /// A Garmin-family file keeps the product table, which holds verified
  /// names, and otherwise plain "Garmin". It ignores `product_name`: the
  /// Garmin cloud import matches a serial against the stored model, so
  /// renaming a device it already registered as "Garmin" would split it
  /// into a second record. A file with no manufacturer at all keeps that
  /// same Garmin lookup.
  ///
  /// A Suunto file uses `product_name`, then its product code, then plain
  /// "Suunto". Any other manufacturer has only `product_name` to go on and
  /// is left without a model when that is absent, so the importer leaves
  /// the dive unattributed rather than naming it a Garmin.
  ///
  /// [manufacturerName] is stripped from the front of `product_name`, so
  /// "Suunto Nautic S" becomes "Nautic S" beside manufacturer "Suunto".
  static String? modelFor({
    required int? manufacturer,
    String? manufacturerName,
    int? product,
    String? productName,
  }) {
    if (manufacturer == null || _garminFamily.contains(manufacturer)) {
      return _models[product] ?? 'Garmin';
    }
    final named = _modelFromProductName(productName, manufacturerName);
    if (manufacturer == _suunto) {
      return named ?? _suuntoModels[product] ?? 'Suunto';
    }
    return named;
  }

  /// [productName] trimmed and without a leading [manufacturerName] word;
  /// null when nothing is left.
  static String? _modelFromProductName(
    String? productName,
    String? manufacturerName,
  ) {
    var name = productName?.trim() ?? '';
    if (manufacturerName != null && manufacturerName.isNotEmpty) {
      final prefix = RegExp(
        '^${RegExp.escape(manufacturerName)}(\\s+|\$)',
        caseSensitive: false,
      );
      name = name.replaceFirst(prefix, '').trim();
    }
    return name.isEmpty ? null : name;
  }
}
