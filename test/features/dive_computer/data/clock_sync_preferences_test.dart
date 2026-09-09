import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ClockSyncPreferences> makePrefs(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    return ClockSyncPreferences(await SharedPreferences.getInstance());
  }

  test('load reads an empty store as the defaults', () async {
    final prefs = await makePrefs({});
    expect(prefs.load(), const ClockSyncSettings());
  });

  test('load reads the global switch and per-computer keys', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_enabled': true,
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_override.c2': 'never',
      'dive_computer_clock_sync_support.c1': 'supported',
      'dive_computer_clock_sync_support.c3': 'unsupported',
      'unrelated_key': 'ignored',
    });
    final settings = prefs.load();
    expect(settings.globalEnabled, isTrue);
    expect(settings.overrideFor('c1'), ClockSyncOverride.always);
    expect(settings.overrideFor('c2'), ClockSyncOverride.never);
    expect(settings.supportFor('c1'), ClockSyncSupport.supported);
    expect(settings.supportFor('c3'), ClockSyncSupport.unsupported);
    expect(settings.overrides.length, 2);
    expect(settings.support.length, 2);
  });

  test('load ignores a value it does not recognise', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'sometimes',
      'dive_computer_clock_sync_support.c1': 'maybe',
    });
    final settings = prefs.load();
    expect(settings.overrideFor('c1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
  });

  test('writes round-trip through load', () async {
    final prefs = await makePrefs({});
    await prefs.writeGlobal(true);
    await prefs.writeOverride('c1', ClockSyncOverride.never);
    await prefs.writeSupport('c1', ClockSyncSupport.supported);
    final settings = prefs.load();
    expect(settings.globalEnabled, isTrue);
    expect(settings.overrideFor('c1'), ClockSyncOverride.never);
    expect(settings.supportFor('c1'), ClockSyncSupport.supported);
  });

  test('inherit and unknown remove their keys', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_support.c1': 'supported',
    });
    await prefs.writeOverride('c1', ClockSyncOverride.inherit);
    await prefs.writeSupport('c1', ClockSyncSupport.unknown);
    final raw = await SharedPreferences.getInstance();
    expect(raw.containsKey('dive_computer_clock_sync_override.c1'), isFalse);
    expect(raw.containsKey('dive_computer_clock_sync_support.c1'), isFalse);
  });

  test('forget removes both keys for one computer only', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_support.c1': 'supported',
      'dive_computer_clock_sync_override.c2': 'never',
    });
    await prefs.forget('c1');
    final settings = prefs.load();
    expect(settings.overrideFor('c1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
    expect(settings.overrideFor('c2'), ClockSyncOverride.never);
  });
}
