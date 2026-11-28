import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/util/maps_link.dart';
import 'package:submersion/core/util/web_link.dart';

const _address = 'Stoney Cove, LE9 4DW';

void main() {
  group('siteDirectionsUri', () {
    test('Android opens the address in the chooser', () {
      expect(
        siteDirectionsUri(
          address: _address,
          platform: MapsPlatform.android,
        ).toString(),
        'geo:0,0?q=Stoney%20Cove%2C%20LE9%204DW',
      );
    });

    test('Android opens the pin with the site name', () {
      expect(
        siteDirectionsUri(
          latitude: 52.5763,
          longitude: -1.2905,
          label: 'Stoney Cove',
          platform: MapsPlatform.android,
        ).toString(),
        'geo:52.5763,-1.2905?q=52.5763,-1.2905(Stoney%20Cove)',
      );
    });

    test('Apple Maps for the address and for the pin', () {
      expect(
        siteDirectionsUri(
          address: _address,
          platform: MapsPlatform.apple,
        ).toString(),
        'https://maps.apple.com/?q=Stoney%20Cove%2C%20LE9%204DW',
      );
      expect(
        siteDirectionsUri(
          latitude: 52.5763,
          longitude: -1.2905,
          label: 'Stoney Cove',
          platform: MapsPlatform.apple,
        ).toString(),
        'https://maps.apple.com/?ll=52.5763,-1.2905&q=Stoney%20Cove',
      );
    });

    test('Google Maps in the browser elsewhere', () {
      expect(
        siteDirectionsUri(
          address: _address,
          platform: MapsPlatform.other,
        ).toString(),
        'https://www.google.com/maps/search/?api=1&query=Stoney%20Cove%2C%20LE9%204DW',
      );
      expect(
        siteDirectionsUri(
          latitude: 52.5763,
          longitude: -1.2905,
          platform: MapsPlatform.other,
        ).toString(),
        'https://www.google.com/maps/search/?api=1&query=52.5763,-1.2905',
      );
    });

    test('the address wins over the coordinates', () {
      expect(
        siteDirectionsUri(
          address: _address,
          latitude: 1,
          longitude: 2,
          platform: MapsPlatform.other,
        ).toString(),
        contains('Stoney%20Cove'),
      );
    });

    test('a blank address falls back to the pin', () {
      expect(
        siteDirectionsUri(
          address: '  ',
          latitude: 1.5,
          longitude: 2.5,
          platform: MapsPlatform.other,
        ).toString(),
        endsWith('query=1.5,2.5'),
      );
    });

    test('nothing to go on gives null', () {
      expect(siteDirectionsUri(platform: MapsPlatform.other), isNull);
      expect(
        siteDirectionsUri(latitude: 1, platform: MapsPlatform.other),
        isNull,
      );
    });

    test('newlines in the address become commas', () {
      expect(
        siteDirectionsUri(
          address: 'Stoney Cove\nLE9 4DW',
          platform: MapsPlatform.other,
        ).toString(),
        endsWith('query=Stoney%20Cove%2C%20LE9%204DW'),
      );
    });
  });

  test('parseWebLink is reachable from core', () {
    expect(parseWebLink('stoneycove.com').toString(), 'https://stoneycove.com');
    expect(parseWebLink('javascript:alert(1)'), isNull);
  });

  testWidgets('each platform gets its own maps app', (tester) async {
    final expected = {
      TargetPlatform.android: MapsPlatform.android,
      TargetPlatform.iOS: MapsPlatform.apple,
      TargetPlatform.macOS: MapsPlatform.apple,
      TargetPlatform.windows: MapsPlatform.other,
      TargetPlatform.linux: MapsPlatform.other,
    };
    try {
      for (final MapEntry(key: target, value: maps) in expected.entries) {
        debugDefaultTargetPlatformOverride = target;
        expect(currentMapsPlatform(), maps, reason: '$target');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
