import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_header_style.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('homeHeaderStyleFromName', () {
    test('nothing stored reads as compact', () {
      expect(homeHeaderStyleFromName(null), HomeHeaderStyle.compact);
    });

    test('a stored name reads back', () {
      expect(homeHeaderStyleFromName('banner'), HomeHeaderStyle.banner);
      expect(homeHeaderStyleFromName('compact'), HomeHeaderStyle.compact);
    });

    test('an unknown name reads as compact', () {
      expect(homeHeaderStyleFromName('bogus'), HomeHeaderStyle.compact);
    });
  });

  group('homeHeaderStyleFor', () {
    const settings = AppSettings(
      homeHeaderStylePhone: 'banner',
      homeHeaderStyleWide: 'compact',
    );

    test('phone width reads the phone choice', () {
      expect(
        homeHeaderStyleFor(settings, HomeWidthTier.phone),
        HomeHeaderStyle.banner,
      );
    });

    test('tablet and desktop read the wide choice', () {
      expect(
        homeHeaderStyleFor(settings, HomeWidthTier.tablet),
        HomeHeaderStyle.compact,
      );
      expect(
        homeHeaderStyleFor(settings, HomeWidthTier.desktop),
        HomeHeaderStyle.compact,
      );
    });

    test('the two choices are independent', () {
      const wideOnly = AppSettings(homeHeaderStyleWide: 'banner');
      expect(
        homeHeaderStyleFor(wideOnly, HomeWidthTier.phone),
        HomeHeaderStyle.compact,
      );
      expect(
        homeHeaderStyleFor(wideOnly, HomeWidthTier.desktop),
        HomeHeaderStyle.banner,
      );
    });
  });
}
