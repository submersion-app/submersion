import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to 100% when nothing is stored', () async {
    final container = await _container({});
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });

  test('reads the stored value synchronously on first read', () async {
    final container = await _container({'display_zoom': 0.85});
    expect(container.read(displayZoomNotifierProvider), 0.85);
  });

  test('clamps a corrupt stored value', () async {
    final container = await _container({'display_zoom': 0.0});
    expect(container.read(displayZoomNotifierProvider), DisplayZoom.min);
  });

  test('setZoom persists the clamped value', () async {
    final container = await _container({});
    await container.read(displayZoomNotifierProvider.notifier).setZoom(9.9);

    expect(container.read(displayZoomNotifierProvider), DisplayZoom.max);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('display_zoom'), DisplayZoom.max);
  });

  // Exact equality, not moreOrLessEquals: normalize snaps every result onto
  // the ladder, and a tolerant matcher here would hide the drift that makes
  // `zoom == defaultValue` false at a displayed 100%.
  test('stepBy walks the ladder in both directions', () async {
    final container = await _container({'display_zoom': 1.0});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    await notifier.stepBy(1);
    expect(container.read(displayZoomNotifierProvider), 1.05);

    await notifier.stepBy(-1);
    await notifier.stepBy(-1);
    expect(container.read(displayZoomNotifierProvider), 0.95);
  });

  test(
    'returns exactly to the default after a clamp-floor round trip',
    () async {
      // Hold Cmd+- past the floor, then Cmd+= back to nominal 100%. Repeated
      // 0.05 arithmetic would land on 1.0000000000000002 without snapping,
      // which displays "100%" while failing `zoom == defaultValue`.
      final container = await _container({});
      final notifier = container.read(displayZoomNotifierProvider.notifier);

      for (var i = 0; i < 8; i++) {
        await notifier.stepBy(-1);
      }
      expect(container.read(displayZoomNotifierProvider), DisplayZoom.min);

      for (var i = 0; i < 6; i++) {
        await notifier.stepBy(1);
      }

      final zoom = container.read(displayZoomNotifierProvider);
      expect(zoom, DisplayZoom.defaultValue);
      expect(
        zoom == DisplayZoom.defaultValue,
        isTrue,
        reason: 'must be exactly equal so the no-op fast path engages',
      );
    },
  );

  test('previewZoom updates state without persisting', () async {
    final container = await _container({});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    notifier.previewZoom(1.2);

    expect(container.read(displayZoomNotifierProvider), 1.2);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble('display_zoom'),
      isNull,
      reason: 'a drag in progress must not hit SharedPreferences',
    );
  });

  test('setZoom persists even when preview already moved state', () async {
    // The commit at the end of a drag must not be skipped just because
    // previewZoom already advanced state to the same value.
    final container = await _container({});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    notifier.previewZoom(1.2);
    await notifier.setZoom(1.2);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('display_zoom'), 1.2);
  });

  test('setZoom skips a redundant write when storage already agrees', () async {
    final container = await _container({'display_zoom': 0.9});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    await notifier.setZoom(0.9);

    expect(container.read(displayZoomNotifierProvider), 0.9);
  });

  test('stepBy saturates at the bounds', () async {
    final container = await _container({'display_zoom': DisplayZoom.max});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    await notifier.stepBy(1);
    expect(container.read(displayZoomNotifierProvider), DisplayZoom.max);
  });

  test('reset returns to the default', () async {
    final container = await _container({'display_zoom': 0.75});
    await container.read(displayZoomNotifierProvider.notifier).reset();
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });
}
