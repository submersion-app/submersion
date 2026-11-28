import 'package:flutter/foundation.dart';

/// Which maps app a directions link is built for.
enum MapsPlatform {
  /// A `geo:` link: Android offers the diver's own choice of navigation app.
  android,

  /// Apple Maps, on iOS and macOS.
  apple,

  /// Google Maps in the browser: Windows, Linux and the web app.
  other,
}

MapsPlatform currentMapsPlatform() {
  if (kIsWeb) return MapsPlatform.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => MapsPlatform.android,
    TargetPlatform.iOS || TargetPlatform.macOS => MapsPlatform.apple,
    _ => MapsPlatform.other,
  };
}

/// A link that opens a maps app at a dive site (issue #5073): at its street
/// [address] when it has one, else at its pin. Null when there is neither a
/// non-blank address nor both coordinates.
///
/// [label] names the pin where the maps app can show one.
Uri? siteDirectionsUri({
  String? address,
  double? latitude,
  double? longitude,
  String? label,
  required MapsPlatform platform,
}) {
  final place = address
      ?.split(RegExp(r'\s*\n\s*'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(', ');
  if (place != null && place.isNotEmpty) {
    final q = Uri.encodeComponent(place);
    return Uri.parse(switch (platform) {
      MapsPlatform.android => 'geo:0,0?q=$q',
      MapsPlatform.apple => 'https://maps.apple.com/?q=$q',
      MapsPlatform.other =>
        'https://www.google.com/maps/search/?api=1&query=$q',
    });
  }
  if (latitude == null || longitude == null) return null;
  final ll = '$latitude,$longitude';
  final name = label?.trim() ?? '';
  final encodedName = Uri.encodeComponent(name);
  return Uri.parse(switch (platform) {
    MapsPlatform.android =>
      name.isEmpty ? 'geo:$ll?q=$ll' : 'geo:$ll?q=$ll($encodedName)',
    MapsPlatform.apple =>
      name.isEmpty
          ? 'https://maps.apple.com/?ll=$ll'
          : 'https://maps.apple.com/?ll=$ll&q=$encodedName',
    MapsPlatform.other => 'https://www.google.com/maps/search/?api=1&query=$ll',
  });
}
