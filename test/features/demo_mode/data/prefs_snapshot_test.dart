import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('prefs_snapshot');
    file = File(p.join(dir.path, 'prefs_snapshot.json'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'restore brings back every key with its exact type and drops keys added since',
    () async {
      SharedPreferences.setMockInitialValues({
        'b': true,
        'i': 3,
        'd': 1.5,
        's': 'x',
        'l': ['a', 'b'],
        'current_diver_id': 'real',
      });
      final prefs = await SharedPreferences.getInstance();

      await PrefsSnapshot.capture(prefs, file);
      await prefs.setString('current_diver_id', 'demo-diver');
      await prefs.setBool('sync_auto_enabled', true);
      await prefs.remove('i');
      await prefs.setBool('b', false);
      await PrefsSnapshot.restore(prefs, file);

      expect(prefs.getString('current_diver_id'), 'real');
      expect(prefs.containsKey('sync_auto_enabled'), isFalse);
      expect(prefs.getBool('b'), isTrue);
      expect(prefs.getInt('i'), 3);
      expect(prefs.getDouble('d'), 1.5);
      expect(prefs.getString('s'), 'x');
      expect(prefs.getStringList('l'), ['a', 'b']);
    },
  );

  test('an empty snapshot restores to no preferences at all', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await PrefsSnapshot.capture(prefs, file);
    await prefs.setString('current_diver_id', 'demo-diver');
    await PrefsSnapshot.restore(prefs, file);

    expect(prefs.getKeys(), isEmpty);
  });

  test('restore throws StateError when the snapshot is missing', () async {
    SharedPreferences.setMockInitialValues({'keep': 'me'});
    final prefs = await SharedPreferences.getInstance();

    await expectLater(
      PrefsSnapshot.restore(prefs, file),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString('keep'), 'me');
  });

  test(
    'restore throws StateError and changes nothing for a corrupt snapshot',
    () async {
      SharedPreferences.setMockInitialValues({'keep': 'me'});
      final prefs = await SharedPreferences.getInstance();
      file.writeAsStringSync('{"version": 1, "values": {"k": {"t": "?"}}}');

      await expectLater(
        PrefsSnapshot.restore(prefs, file),
        throwsA(isA<StateError>()),
      );
      expect(prefs.getString('keep'), 'me');
    },
  );
}
