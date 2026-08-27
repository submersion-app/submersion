import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/back_navigation.dart';

void main() {
  String? up(String location) => resolveUpLocation(Uri.parse(location));

  group('resolveUpLocation', () {
    group('app root exits', () {
      test('returns null on the dashboard so system back exits the app', () {
        expect(up('/dashboard'), isNull);
      });

      test('returns null on the dashboard with incidental query params', () {
        expect(up('/dashboard?view=map'), isNull);
      });
    });

    group('top-level tabs fall back to the dashboard', () {
      for (final tab in const [
        '/dives',
        '/sites',
        '/equipment',
        '/settings',
        '/statistics',
        '/trips',
        '/planning',
        '/certifications',
      ]) {
        test('$tab goes up to the dashboard', () {
          expect(up(tab), '/dashboard');
        });
      }
    });

    group('nested paths drop their last segment', () {
      test('dive detail goes up to the dive list', () {
        expect(up('/dives/42'), '/dives');
      });

      test('dive edit goes up to the dive detail', () {
        expect(up('/dives/42/edit'), '/dives/42');
      });

      test('settings sub-page goes up to settings', () {
        expect(up('/settings/language'), '/settings');
      });

      test('deeply nested settings page drops one level at a time', () {
        expect(
          up('/settings/diver-profile/insurance'),
          '/settings/diver-profile',
        );
      });

      test('trailing slashes do not produce an empty segment', () {
        expect(up('/dives/42/'), '/dives');
      });
    });

    group('master-detail query params unwind before the path', () {
      test('edit mode unwinds to the selected detail', () {
        expect(up('/dives?selected=42&mode=edit'), '/dives?selected=42');
      });

      test('selected detail unwinds to the bare list', () {
        expect(up('/dives?selected=42'), '/dives');
      });

      test('new mode unwinds to the bare list', () {
        expect(up('/buddies?mode=new'), '/buddies');
      });

      test('settings section detail unwinds to settings', () {
        expect(up('/settings?selected=data'), '/settings');
      });

      test('unrelated query params are preserved when unwinding mode', () {
        expect(
          up('/dives?selected=42&mode=edit&view=map'),
          '/dives?selected=42&view=map',
        );
      });

      test('unrelated query params survive unwinding selected', () {
        expect(up('/dives?selected=42&view=map'), '/dives?view=map');
      });

      test('a nested path with selected unwinds the param first', () {
        expect(up('/dives/42?selected=7'), '/dives/42');
      });

      test('dashboard with a selected param unwinds instead of exiting', () {
        expect(up('/dashboard?selected=42'), '/dashboard');
      });
    });

    group('malformed input degrades to the dashboard', () {
      test('empty path falls back to the dashboard', () {
        expect(up(''), '/dashboard');
      });

      test('bare slash falls back to the dashboard', () {
        expect(up('/'), '/dashboard');
      });
    });
  });
}
