import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_sml_normalizer.dart';

/// The UTF-8 byte order mark as decoded text (U+FEFF). Written as an escape
/// because the literal character is invisible in source.
const _log = LoggerService('SuuntoJsonFileReader');

const _bom = '\u{FEFF}';

/// One file picked, shared or dropped for the Suunto JSON import.
class SuuntoJsonFile {
  const SuuntoJsonFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Why a picked file was not imported, for the file step to explain.
enum SuuntoFileRejection {
  /// The bytes do not decode as JSON.
  notJson,

  /// JSON, but neither the app's DeviceLog shape nor a cloud sml export.
  notSuuntoExport,

  /// A Suunto export of an activity that is not a dive.
  notADive,
}

/// A picked file, read: either a [dive] or the [rejection] that skipped it.
class SuuntoFileReadResult {
  const SuuntoFileReadResult.dive(this.file, SuuntoParsedDive this.dive)
    : rejection = null;

  const SuuntoFileReadResult.rejected(
    this.file,
    SuuntoFileRejection this.rejection,
  ) : dive = null;

  final SuuntoJsonFile file;
  final SuuntoParsedDive? dive;
  final SuuntoFileRejection? rejection;
}

/// Reads a Suunto app "export as JSON" file (the `DeviceLog` shape) or a
/// saved cloud `sml` export into a dive, the same way the Suunto Cloud
/// import does once it has downloaded one (issue #1445).
SuuntoFileReadResult readSuuntoJsonFile(SuuntoJsonFile file) {
  final Object? decoded;
  try {
    var text = utf8.decode(file.bytes);
    if (text.startsWith(_bom)) text = text.substring(1);
    decoded = jsonDecode(text);
  } on FormatException {
    return SuuntoFileReadResult.rejected(file, SuuntoFileRejection.notJson);
  }
  if (decoded is! Map<String, dynamic>) {
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  }
  try {
    final export = SuuntoSmlNormalizer.parse(decoded);
    return SuuntoFileReadResult.dive(
      file,
      SuuntoDiveParser.parse(header: export.header, samples: export.samples),
    );
  } on SuuntoNotADiveException {
    return SuuntoFileReadResult.rejected(file, SuuntoFileRejection.notADive);
  } on SuuntoApiException {
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  } on TypeError {
    // Keys that match a Suunto export, values of the wrong shape.
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  } catch (e, st) {
    // Anything else the parser trips on (an out-of-range number decoded
    // as Infinity, say) skips this one file rather than escaping and
    // losing the rest of the diver's pick.
    _log.warning(
      'Could not read ${file.name} as a Suunto export',
      error: e,
      stackTrace: st,
    );
    return SuuntoFileReadResult.rejected(
      file,
      SuuntoFileRejection.notSuuntoExport,
    );
  }
}
