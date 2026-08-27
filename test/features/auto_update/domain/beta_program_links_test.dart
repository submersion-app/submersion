import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/beta_program_links.dart';

void main() {
  group('betaEnrollUrlFor', () {
    test('offers nothing when the build has its own updater', () {
      // A build that polls GitHub Releases switches channels in Settings >
      // Updates > Update channel, so sending it to a store testing program
      // would be a dead end. This is the sideloaded Android APK (#1258): it
      // was offering the Play opt-in page for an app not listed on Play.
      expect(
        betaEnrollUrlFor(
          isIOS: false,
          isMacOS: false,
          isAndroid: true,
          autoUpdateEnabled: true,
        ),
        isNull,
      );
    });

    test('offers the Play opt-in page to a Play-channel Android build', () {
      expect(
        betaEnrollUrlFor(
          isIOS: false,
          isMacOS: false,
          isAndroid: true,
          autoUpdateEnabled: false,
        ),
        kPlayBetaOptInUrl,
      );
    });

    test('offers TestFlight to iOS and to Mac App Store builds', () {
      expect(
        betaEnrollUrlFor(
          isIOS: true,
          isMacOS: false,
          isAndroid: false,
          autoUpdateEnabled: false,
        ),
        kTestFlightBetaUrl,
      );
      expect(
        betaEnrollUrlFor(
          isIOS: false,
          isMacOS: true,
          isAndroid: false,
          autoUpdateEnabled: false,
        ),
        kTestFlightBetaUrl,
      );
    });

    test('offers nothing on platforms with no store program', () {
      // Linux and Windows store builds have no public testing programme to
      // enroll in, so there is no link to show even with updates disabled.
      expect(
        betaEnrollUrlFor(
          isIOS: false,
          isMacOS: false,
          isAndroid: false,
          autoUpdateEnabled: false,
        ),
        isNull,
      );
    });
  });
}
