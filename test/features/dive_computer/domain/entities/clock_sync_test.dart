import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

void main() {
  group('ClockSyncStatus.fromWireName', () {
    test('parses the four wire names', () {
      expect(ClockSyncStatus.fromWireName('synced'), ClockSyncStatus.synced);
      expect(
        ClockSyncStatus.fromWireName('unsupported'),
        ClockSyncStatus.unsupported,
      );
      expect(ClockSyncStatus.fromWireName('failed'), ClockSyncStatus.failed);
      expect(
        ClockSyncStatus.fromWireName('not_requested'),
        ClockSyncStatus.notRequested,
      );
    });

    test('null and unknown names read as not requested', () {
      expect(ClockSyncStatus.fromWireName(null), ClockSyncStatus.notRequested);
      expect(
        ClockSyncStatus.fromWireName('something-new'),
        ClockSyncStatus.notRequested,
      );
    });
  });

  group('ClockSyncSettings.resolve', () {
    test('defaults to off everywhere', () {
      const settings = ClockSyncSettings();
      expect(settings.globalEnabled, isFalse);
      expect(settings.resolve('c1'), isFalse);
      expect(settings.resolve(null), isFalse);
    });

    test('an unsaved device follows the global switch only', () {
      final settings = const ClockSyncSettings().withGlobalEnabled(true);
      expect(settings.resolve(null), isTrue);
    });

    test('inherit follows the global switch', () {
      final on = const ClockSyncSettings().withGlobalEnabled(true);
      expect(on.overrideFor('c1'), ClockSyncOverride.inherit);
      expect(on.resolve('c1'), isTrue);
      expect(on.withGlobalEnabled(false).resolve('c1'), isFalse);
    });

    test('always wins over a global off', () {
      final settings = const ClockSyncSettings().withOverride(
        'c1',
        ClockSyncOverride.always,
      );
      expect(settings.resolve('c1'), isTrue);
      expect(settings.resolve('c2'), isFalse);
    });

    test('never wins over a global on', () {
      final settings = const ClockSyncSettings()
          .withGlobalEnabled(true)
          .withOverride('c1', ClockSyncOverride.never);
      expect(settings.resolve('c1'), isFalse);
      expect(settings.resolve('c2'), isTrue);
    });

    test('setting inherit removes the stored override', () {
      final settings = const ClockSyncSettings()
          .withOverride('c1', ClockSyncOverride.always)
          .withOverride('c1', ClockSyncOverride.inherit);
      expect(settings.overrides, isEmpty);
    });

    test('a recorded unsupported model still resolves from the switches', () {
      // The flag is still sent; the device answers unsupported again, which
      // is what makes "Check again" trivially correct.
      final settings = const ClockSyncSettings()
          .withGlobalEnabled(true)
          .withSupport('c1', ClockSyncSupport.unsupported);
      expect(settings.resolve('c1'), isTrue);
    });
  });

  group('ClockSyncSettings support', () {
    test('unknown by default and removable', () {
      const settings = ClockSyncSettings();
      expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
      final known = settings.withSupport('c1', ClockSyncSupport.supported);
      expect(known.supportFor('c1'), ClockSyncSupport.supported);
      expect(
        known.withSupport('c1', ClockSyncSupport.unknown).support,
        isEmpty,
      );
    });

    test('synced records supported, unsupported records unsupported', () {
      const settings = ClockSyncSettings();
      expect(
        settings
            .withSupportFromStatus('c1', ClockSyncStatus.synced)
            .supportFor('c1'),
        ClockSyncSupport.supported,
      );
      expect(
        settings
            .withSupportFromStatus('c1', ClockSyncStatus.unsupported)
            .supportFor('c1'),
        ClockSyncSupport.unsupported,
      );
    });

    test('failed and not requested change nothing', () {
      final known = const ClockSyncSettings().withSupport(
        'c1',
        ClockSyncSupport.supported,
      );
      expect(
        identical(
          known.withSupportFromStatus('c1', ClockSyncStatus.failed),
          known,
        ),
        isTrue,
      );
      expect(
        identical(
          known.withSupportFromStatus('c1', ClockSyncStatus.notRequested),
          known,
        ),
        isTrue,
      );
    });
  });

  group('ClockSyncSettings.without', () {
    test('drops both per-computer entries and leaves others alone', () {
      final settings = const ClockSyncSettings()
          .withOverride('c1', ClockSyncOverride.never)
          .withSupport('c1', ClockSyncSupport.supported)
          .withOverride('c2', ClockSyncOverride.always);
      final after = settings.without('c1');
      expect(after.overrideFor('c1'), ClockSyncOverride.inherit);
      expect(after.supportFor('c1'), ClockSyncSupport.unknown);
      expect(after.overrideFor('c2'), ClockSyncOverride.always);
    });
  });

  test('value equality', () {
    expect(
      const ClockSyncSettings().withGlobalEnabled(true),
      const ClockSyncSettings(globalEnabled: true),
    );
  });
}
