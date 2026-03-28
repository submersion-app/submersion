/// Parsed result from a Shearwater Cloud log_data filename.
class ShearwaterFilenameInfo {
  final String? model;
  final String? serial;
  final int? diveNumber;

  const ShearwaterFilenameInfo({this.model, this.serial, this.diveNumber});
}

/// Parses Shearwater Cloud log_data filenames to extract model, serial, and dive number.
///
/// Filename format: "ModelName[HexSerial]#DiveNum YYYY-M-D H-M-S.swlogzp"
class ShearwaterFilenameParser {
  static final _pattern = RegExp(r'^(.+?)\[([A-Fa-f0-9]+)\]#(\d+)\s');

  static const _knownModels = {
    'Teric': ('Shearwater', 'Teric'),
    'Perdix': ('Shearwater', 'Perdix'),
    'Perdix 2': ('Shearwater', 'Perdix 2'),
    'Perdix AI': ('Shearwater', 'Perdix AI'),
    'Peregrine': ('Shearwater', 'Peregrine'),
    'Petrel': ('Shearwater', 'Petrel'),
    'Petrel 2': ('Shearwater', 'Petrel 2'),
    'Petrel 3': ('Shearwater', 'Petrel 3'),
    'Tern': ('Shearwater', 'Tern'),
    'NERD': ('Shearwater', 'NERD'),
    'NERD 2': ('Shearwater', 'NERD 2'),
  };

  static ShearwaterFilenameInfo parse(String filename) {
    final match = _pattern.firstMatch(filename);
    if (match == null) {
      return const ShearwaterFilenameInfo();
    }
    return ShearwaterFilenameInfo(
      model: match.group(1),
      serial: match.group(2),
      diveNumber: int.tryParse(match.group(3) ?? ''),
    );
  }

  static (String, String)? vendorProduct(String model) {
    return _knownModels[model];
  }
}
