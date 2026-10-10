import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';

import '../../../../helpers/fake_window_fullscreen_platform.dart';

void main() {
  group('ViewerFullscreenModeNotifier', () {
    test('defaults to full window when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(
        ViewerFullscreenModeNotifier(prefs).state,
        ViewerFullscreenMode.fullWindow,
      );
    });

    test('reads a stored choice back on the first frame', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.viewerFullscreenMode: 'fullscreen',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        ViewerFullscreenModeNotifier(prefs).state,
        ViewerFullscreenMode.fullscreen,
      );
    });

    test('an unknown stored value falls back to full window', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.viewerFullscreenMode: 'kiosk',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        ViewerFullscreenModeNotifier(prefs).state,
        ViewerFullscreenMode.fullWindow,
      );
    });

    test('setMode updates the state and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ViewerFullscreenModeNotifier(prefs);

      await notifier.setMode(ViewerFullscreenMode.fullscreen);

      expect(notifier.state, ViewerFullscreenMode.fullscreen);
      expect(prefs.getString(SettingsKeys.viewerFullscreenMode), 'fullscreen');
    });

    test('the unstored default changes state without storage', () async {
      final notifier = ViewerFullscreenModeNotifier.unstored(
        ViewerFullscreenMode.fullWindow,
      );

      await notifier.setMode(ViewerFullscreenMode.fullscreen);

      expect(notifier.state, ViewerFullscreenMode.fullscreen);
    });
  });

  group('viewerWindowFullscreenProvider', () {
    late FakeWindowFullscreenPlatform platform;

    ProviderContainer makeContainer(ViewerFullscreenMode mode) {
      platform = FakeWindowFullscreenPlatform();
      final container = ProviderContainer(
        overrides: [
          windowFullscreenPlatformProvider.overrideWithValue(platform),
          viewerFullscreenModeProvider.overrideWith(
            (ref) => ViewerFullscreenModeNotifier.unstored(mode),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('full window mode never touches the OS window', () async {
      final container = makeContainer(ViewerFullscreenMode.fullWindow);
      final viewer = container.read(viewerWindowFullscreenProvider);
      final owner = Object();

      await viewer.enter(owner);
      await viewer.exit(owner);

      expect(platform.setCalls, isEmpty);
    });

    test('fullscreen mode takes the OS window fullscreen and back', () async {
      final container = makeContainer(ViewerFullscreenMode.fullscreen);
      final viewer = container.read(viewerWindowFullscreenProvider);
      final owner = Object();

      await viewer.enter(owner);
      expect(platform.fullScreen, isTrue);

      await viewer.exit(owner);
      expect(platform.setCalls, [true, false]);
    });

    test(
      'switching to full window while held still restores on exit',
      () async {
        final container = makeContainer(ViewerFullscreenMode.fullscreen);
        final viewer = container.read(viewerWindowFullscreenProvider);
        final owner = Object();

        await viewer.enter(owner);
        await container
            .read(viewerFullscreenModeProvider.notifier)
            .setMode(ViewerFullscreenMode.fullWindow);
        await viewer.exit(owner);

        expect(platform.fullScreen, isFalse);
      },
    );
  });
}
