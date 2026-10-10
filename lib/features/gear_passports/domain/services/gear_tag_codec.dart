import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

/// Why a scanned or pasted string is not a gear tag.
enum GearTagRejectReason {
  notATag,
  missingId,
  malformedId,
  missingType,
  notGear,
}

sealed class GearTagDecodeResult {
  const GearTagDecodeResult();
}

class GearTagDecoded extends GearTagDecodeResult {
  final GearTagPayload payload;

  /// The tag's format is newer than this app knows; every known key was read.
  final bool newerFormat;
  const GearTagDecoded(this.payload, {this.newerFormat = false});
}

class GearTagRejected extends GearTagDecodeResult {
  final GearTagRejectReason reason;
  const GearTagRejected(this.reason);
}

/// The gear tag string (gear tag spec section 6): a query-string payload in
/// the fragment of `https://submersion.app/g` or the query of
/// `submersion://g`.
///
/// Total: [decode] never throws. Unknown keys are ignored, bad dates are
/// dropped, text is capped. Unlike the cylinder codec there is no bare
/// payload form: a bare query string is read as a cylinder tag.
abstract final class GearTagCodec {
  static const String httpsPrefix = 'https://submersion.app/g';
  static const String schemePrefix = 'submersion://g';

  /// Emission order. Two devices must produce the same string for one item.
  static const List<String> keyOrder = [
    'f',
    'p',
    'w',
    't',
    'n',
    'b',
    'mo',
    'sn',
    'ls',
  ];

  static const Set<String> _tagHosts = {'submersion.app', 'www.submersion.app'};

  static String? _cap(String? text, int max) => text == null || text.isEmpty
      ? null
      : PassportPayloadCodec.capCharacters(text, max);

  /// The bare query string, keys in [keyOrder], values percent-encoded.
  static String encode(GearTagPayload p) {
    final values = <String, String?>{
      'f': p.formatVersion.toString(),
      'p': p.passportId,
      'w': p.writtenOn == null
          ? null
          : PassportPayloadCodec.formatDate(p.writtenOn!),
      't': _cap(p.typeCode, GearTagPayload.maxTypeCodeLength),
      'n': _cap(p.name, GearTagPayload.maxNameLength),
      'b': _cap(p.brand, GearTagPayload.maxShortTextLength),
      'mo': _cap(p.model, GearTagPayload.maxShortTextLength),
      'sn': _cap(p.serial, GearTagPayload.maxShortTextLength),
      'ls': p.lastService == null
          ? null
          : PassportPayloadCodec.formatDate(p.lastService!),
    };
    return [
      for (final key in keyOrder)
        if (values[key] case final value? when value.isNotEmpty)
          '$key=${Uri.encodeQueryComponent(value)}',
    ].join('&');
  }

  static String httpsUrl(GearTagPayload p) => '$httpsPrefix#${encode(p)}';

  /// The payload part of [text] when it is a gear tag link in either URL
  /// form, else null. Parsed, not prefix-matched: scheme and host match in
  /// any case, `http` and a `www.` host are accepted, the path is exactly
  /// `/g`. The payload is cut from the raw text, because `Uri` repairs a
  /// stray '%' into '%25'.
  static String? extractQuery(String text) {
    final s = text.trim();
    if (!s.contains('://')) return null;
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path;
    final isWeb =
        (scheme == 'https' || scheme == 'http') &&
        _tagHosts.contains(host) &&
        (path == '/g' || path == '/g/');
    final isApp =
        scheme == 'submersion' && host == 'g' && (path.isEmpty || path == '/');
    if (!isWeb && !isApp) return null;
    final hash = s.indexOf('#');
    if (hash >= 0) return hash + 1 < s.length ? s.substring(hash + 1) : null;
    final q = s.indexOf('?');
    if (q >= 0) return q + 1 < s.length ? s.substring(q + 1) : null;
    return null;
  }

  static GearTagDecodeResult decode(String text) {
    final query = extractQuery(text);
    if (query == null) {
      return const GearTagRejected(GearTagRejectReason.notATag);
    }
    final Map<String, String> pairs;
    try {
      pairs = Uri.splitQueryString(query);
    } on FormatException {
      return const GearTagRejected(GearTagRejectReason.notATag);
    } on ArgumentError {
      // Bad percent-encoding throws ArgumentError, not FormatException.
      return const GearTagRejected(GearTagRejectReason.notATag);
    }
    final rawId = pairs['p'];
    if (rawId == null || rawId.isEmpty) {
      return const GearTagRejected(GearTagRejectReason.missingId);
    }
    final id = rawId.toLowerCase();
    if (!PassportPayloadCodec.isPassportId(id)) {
      return const GearTagRejected(GearTagRejectReason.malformedId);
    }
    final typeCode = _cap(pairs['t'], GearTagPayload.maxTypeCodeLength);
    if (typeCode == null) {
      return const GearTagRejected(GearTagRejectReason.missingType);
    }
    if (typeCode == EquipmentType.tank.name) {
      return const GearTagRejected(GearTagRejectReason.notGear);
    }
    final format =
        int.tryParse(pairs['f'] ?? '') ?? GearTagPayload.currentFormatVersion;
    return GearTagDecoded(
      GearTagPayload(
        formatVersion: format,
        passportId: id,
        typeCode: typeCode,
        writtenOn: PassportPayloadCodec.parseDate(pairs['w']),
        name: _cap(pairs['n'], GearTagPayload.maxNameLength),
        brand: _cap(pairs['b'], GearTagPayload.maxShortTextLength),
        model: _cap(pairs['mo'], GearTagPayload.maxShortTextLength),
        serial: _cap(pairs['sn'], GearTagPayload.maxShortTextLength),
        lastService: PassportPayloadCodec.parseDate(pairs['ls']),
      ),
      newerFormat: format > GearTagPayload.currentFormatVersion,
    );
  }
}
