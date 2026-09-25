import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// Why a scanned or pasted string is not a cylinder tag.
enum PassportRejectReason { notATag, missingId, malformedId }

sealed class PassportDecodeResult {
  const PassportDecodeResult();
}

class PassportDecoded extends PassportDecodeResult {
  final CylinderPassportPayload payload;

  /// The tag's format version is newer than this app knows. Every known key
  /// was read; the caller may say so.
  final bool newerFormat;
  const PassportDecoded(this.payload, {this.newerFormat = false});
}

class PassportRejected extends PassportDecodeResult {
  final PassportRejectReason reason;
  const PassportRejected(this.reason);
}

/// The tag string (spec section 6): one query-string payload carried as the
/// fragment of the https form or the query of the custom scheme.
///
/// Total: [decode] never throws on a tag. Unknown keys are ignored so a
/// future format still opens; out-of-range numbers and bad dates are dropped
/// rather than trusted.
abstract final class PassportPayloadCodec {
  static const String httpsPrefix = 'https://submersion.app/c';
  static const String schemePrefix = 'submersion://c';

  /// Emission order. Two devices must produce the same string for the same
  /// cylinder.
  static const List<String> keyOrder = [
    'f',
    'p',
    'w',
    'n',
    'sn',
    'v',
    'wp',
    'm',
    'vt',
    'h',
    'vi',
    'oc',
  ];

  static const double minVolumeL = 0.5;
  static const double maxVolumeL = 50;
  static const int minPressureBar = 50;
  static const int maxPressureBar = 400;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// A local calendar date, or null for anything that is not `YYYY-MM-DD`
  /// naming a real day.
  static DateTime? parseDate(String? text) {
    if (text == null) return null;
    final m = _date.firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, mo, d);
    if (date.month != mo || date.day != d) return null;
    return date;
  }

  static String _materialCode(TankMaterial m) => switch (m) {
    TankMaterial.aluminum => 'al',
    TankMaterial.steel => 'st',
    TankMaterial.carbonFiber => 'cf',
  };

  static TankMaterial? _material(String? code) => switch (code) {
    'al' => TankMaterial.aluminum,
    'st' => TankMaterial.steel,
    'cf' => TankMaterial.carbonFiber,
    _ => null,
  };

  static String _volume(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  /// The bare query string, keys in [keyOrder], values percent-encoded.
  static String encode(CylinderPassportPayload p) {
    final name = p.name;
    final values = <String, String?>{
      'f': p.formatVersion.toString(),
      'p': p.passportId,
      'w': p.writtenOn == null ? null : formatDate(p.writtenOn!),
      'n': name == null
          ? null
          : (name.length > CylinderPassportPayload.maxNameLength
                ? name.substring(0, CylinderPassportPayload.maxNameLength)
                : name),
      'sn': p.serial,
      'v': p.volumeL == null ? null : _volume(p.volumeL!),
      'wp': p.workingPressureBar?.toString(),
      'm': p.material == null ? null : _materialCode(p.material!),
      'vt': p.valve?.code,
      'h': p.lastHydro == null ? null : formatDate(p.lastHydro!),
      'vi': p.lastVip == null ? null : formatDate(p.lastVip!),
      'oc': p.o2Clean ? '1' : null,
    };
    return [
      for (final key in keyOrder)
        if (values[key] case final value? when value.isNotEmpty)
          '$key=${Uri.encodeQueryComponent(value)}',
    ].join('&');
  }

  static String httpsUrl(CylinderPassportPayload p) =>
      '$httpsPrefix#${encode(p)}';

  /// The payload part of [text], or null when [text] is not a tag in either
  /// URL form and not a bare query string.
  static String? extractQuery(String text) {
    final s = text.trim();
    String? rest;
    if (s.startsWith(httpsPrefix)) {
      rest = s.substring(httpsPrefix.length);
    } else if (s.startsWith(schemePrefix)) {
      rest = s.substring(schemePrefix.length);
    }
    if (rest != null) {
      if (rest.startsWith('/')) rest = rest.substring(1);
      final hash = rest.indexOf('#');
      if (hash >= 0) return rest.substring(hash + 1);
      final q = rest.indexOf('?');
      if (q >= 0) return rest.substring(q + 1);
      return rest.isEmpty ? null : rest;
    }
    // A bare payload: the first pair must be a known key.
    final firstKey = s.split('&').first.split('=').first;
    if (s.contains('=') && keyOrder.contains(firstKey)) return s;
    return null;
  }

  static PassportDecodeResult decode(String text) {
    final query = extractQuery(text);
    if (query == null) {
      return const PassportRejected(PassportRejectReason.notATag);
    }
    final Map<String, String> pairs;
    try {
      pairs = Uri.splitQueryString(query);
    } on FormatException {
      return const PassportRejected(PassportRejectReason.notATag);
    }
    final rawId = pairs['p'];
    if (rawId == null || rawId.isEmpty) {
      return const PassportRejected(PassportRejectReason.missingId);
    }
    final id = rawId.toLowerCase();
    if (!_uuid.hasMatch(id)) {
      return const PassportRejected(PassportRejectReason.malformedId);
    }
    final format =
        int.tryParse(pairs['f'] ?? '') ??
        CylinderPassportPayload.currentFormatVersion;

    final volume = double.tryParse(pairs['v'] ?? '');
    final pressure = int.tryParse(pairs['wp'] ?? '');
    final name = pairs['n'];

    final payload = CylinderPassportPayload(
      formatVersion: format,
      passportId: id,
      writtenOn: parseDate(pairs['w']),
      name: name == null || name.isEmpty
          ? null
          : (name.length > CylinderPassportPayload.maxNameLength
                ? name.substring(0, CylinderPassportPayload.maxNameLength)
                : name),
      serial: (pairs['sn'] ?? '').isEmpty ? null : pairs['sn'],
      volumeL: volume != null && volume >= minVolumeL && volume <= maxVolumeL
          ? volume
          : null,
      workingPressureBar:
          pressure != null &&
              pressure >= minPressureBar &&
              pressure <= maxPressureBar
          ? pressure
          : null,
      material: _material(pairs['m']),
      valve: PassportValve.fromCode(pairs['vt']),
      lastHydro: parseDate(pairs['h']),
      lastVip: parseDate(pairs['vi']),
      o2Clean: pairs['oc'] == '1',
    );
    return PassportDecoded(
      payload,
      newerFormat: format > CylinderPassportPayload.currentFormatVersion,
    );
  }
}
