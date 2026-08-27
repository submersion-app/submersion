import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';

void main() {
  group('UpdateChannel', () {
    test('has all 5 enum values', () {
      expect(UpdateChannel.values, hasLength(5));
      expect(UpdateChannel.values, contains(UpdateChannel.github));
      expect(UpdateChannel.values, contains(UpdateChannel.appstore));
      expect(UpdateChannel.values, contains(UpdateChannel.playstore));
      expect(UpdateChannel.values, contains(UpdateChannel.msstore));
      expect(UpdateChannel.values, contains(UpdateChannel.snapstore));
    });
  });

  group('UpdateChannelConfig', () {
    group('isStoreChannel', () {
      test('returns false for github', () {
        expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.github), false);
      });

      test('returns true for appstore', () {
        expect(
          UpdateChannelConfig.isStoreChannel(UpdateChannel.appstore),
          true,
        );
      });

      test('returns true for playstore', () {
        expect(
          UpdateChannelConfig.isStoreChannel(UpdateChannel.playstore),
          true,
        );
      });

      test('returns true for msstore', () {
        expect(UpdateChannelConfig.isStoreChannel(UpdateChannel.msstore), true);
      });

      test('returns true for snapstore', () {
        expect(
          UpdateChannelConfig.isStoreChannel(UpdateChannel.snapstore),
          true,
        );
      });
    });

    test('current defaults to github when no environment override', () {
      // String.fromEnvironment defaults to 'github' in the implementation.
      // In test context, no compile-time define is set, so we expect github.
      expect(UpdateChannelConfig.current, UpdateChannel.github);
    });

    test('isAutoUpdateEnabled is true when channel is github', () {
      // Default channel is github, which is not a store channel
      expect(UpdateChannelConfig.isAutoUpdateEnabled, true);
    });

    // The host platform under flutter test is never iOS, so the getter above
    // can only ever exercise one branch. These cases drive the pure form
    // directly to cover the platform/channel matrix (#1258).
    group('isAutoUpdateEnabledFor', () {
      test('is false on iOS even on the github channel', () {
        // iOS ships only through the App Store and TestFlight, both of which
        // deliver updates themselves. No dart-define can turn this on.
        expect(
          UpdateChannelConfig.isAutoUpdateEnabledFor(
            isIOS: true,
            channel: UpdateChannel.github,
          ),
          false,
        );
      });

      test('is true off iOS on the github channel', () {
        // This is the Android sideloaded APK, which build-all.yml builds with
        // UPDATE_CHANNEL=github, alongside Linux and the direct desktop
        // builds. Re-adding a Platform.isAndroid guard here fails this test.
        expect(
          UpdateChannelConfig.isAutoUpdateEnabledFor(
            isIOS: false,
            channel: UpdateChannel.github,
          ),
          true,
        );
      });

      test('is false off iOS on the playstore channel', () {
        // The Play bundle is built with UPDATE_CHANNEL=playstore, so the
        // switch-over when Play lands is a build flag, not a code change.
        expect(
          UpdateChannelConfig.isAutoUpdateEnabledFor(
            isIOS: false,
            channel: UpdateChannel.playstore,
          ),
          false,
        );
      });

      test('is false off iOS on every other store channel', () {
        for (final channel in [
          UpdateChannel.appstore,
          UpdateChannel.msstore,
          UpdateChannel.snapstore,
        ]) {
          expect(
            UpdateChannelConfig.isAutoUpdateEnabledFor(
              isIOS: false,
              channel: channel,
            ),
            false,
            reason: '$channel is a store channel',
          );
        }
      });
    });
  });
}
