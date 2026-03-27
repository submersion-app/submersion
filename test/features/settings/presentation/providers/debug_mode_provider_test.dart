import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';

void main() {
  group('DebugModeNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('initial state is false when no preference stored', () {
      final notifier = DebugModeNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('initial state reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'debug_mode_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final notifier = DebugModeNotifier(prefs);
      expect(notifier.state, isTrue);
    });

    test('enable() sets state to true and persists', () async {
      final notifier = DebugModeNotifier(prefs);
      await notifier.enable();
      expect(notifier.state, isTrue);
      expect(prefs.getBool('debug_mode_enabled'), isTrue);
    });

    test('disable() sets state to false and persists', () async {
      final notifier = DebugModeNotifier(prefs);
      await notifier.enable();
      await notifier.disable();
      expect(notifier.state, isFalse);
      expect(prefs.getBool('debug_mode_enabled'), isFalse);
    });
  });
}
