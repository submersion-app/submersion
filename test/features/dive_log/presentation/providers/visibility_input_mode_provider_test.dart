import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';

void main() {
  test('starts at Precise when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = VisibilityInputModeNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, VisibilityInputMode.precise);
  });

  test('remembers the last mode saved with', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await VisibilityInputModeNotifier(
      prefs,
    ).remember(VisibilityInputMode.range);
    expect(VisibilityInputModeNotifier(prefs).state, VisibilityInputMode.range);
  });

  test('an unknown stored value falls back to Precise', () async {
    SharedPreferences.setMockInitialValues({
      'dive_edit_visibility_input_mode': 'guess',
    });
    final notifier = VisibilityInputModeNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, VisibilityInputMode.precise);
  });
}
