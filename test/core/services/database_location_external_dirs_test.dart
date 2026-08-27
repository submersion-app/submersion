import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'externalVolumeChooser setter stores the chooser without error',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = DatabaseLocationService(
        await SharedPreferences.getInstance(),
      );
      service.externalVolumeChooser = (options) async => options.first;
      // Setter is write-only; exercising it is the assertion (no throw).
    },
  );

  group('classifyExternalDirs', () {
    test(
      'classifies the emulated volume as internal and others as removable',
      () {
        final opts = classifyExternalDirs([
          '/storage/emulated/0/Android/data/app.submersion/files',
          '/storage/1A2B-3C4D/Android/data/app.submersion/files',
        ]);
        expect(opts[0].isInternal, isTrue);
        expect(opts[1].isInternal, isFalse);
        expect(opts[1].path, contains('1A2B-3C4D'));
      },
    );

    test('a single volume is classified as internal', () {
      final opts = classifyExternalDirs([
        '/storage/emulated/0/Android/data/app.submersion/files',
      ]);
      expect(opts.single.isInternal, isTrue);
    });
  });

  group('resolveAndroidDbDir', () {
    test('chooser pick creates and returns <chosen>/Submersion', () async {
      final tmp = await Directory.systemTemp.createTemp('radd_pick_');
      addTearDown(() => tmp.delete(recursive: true));
      final opts = classifyExternalDirs([
        p.join(tmp.path, 'internal'),
        p.join(tmp.path, 'sd'),
      ]);

      final dir = await resolveAndroidDbDir(opts, (o) async => o[1]);

      expect(dir, p.join(tmp.path, 'sd', 'Submersion'));
      expect(Directory(dir!).existsSync(), isTrue);
    });

    test('dismissed chooser returns null and creates nothing', () async {
      final opts = classifyExternalDirs([
        '/storage/emulated/0/x',
        '/storage/SD/x',
      ]);
      expect(await resolveAndroidDbDir(opts, (o) async => null), isNull);
    });

    test('no chooser defaults to the internal (first) volume', () async {
      final tmp = await Directory.systemTemp.createTemp('radd_default_');
      addTearDown(() => tmp.delete(recursive: true));
      final opts = classifyExternalDirs([
        p.join(tmp.path, 'internal'),
        p.join(tmp.path, 'sd'),
      ]);

      final dir = await resolveAndroidDbDir(opts, null);

      expect(dir, p.join(tmp.path, 'internal', 'Submersion'));
      expect(Directory(dir!).existsSync(), isTrue);
    });
  });
}
