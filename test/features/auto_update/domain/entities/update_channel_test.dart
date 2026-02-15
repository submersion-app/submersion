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
  });
}
