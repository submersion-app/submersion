import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';

void main() {
  late Directory support;
  late DemoPaths paths;

  setUp(() {
    support = Directory.systemTemp.createTempSync('bg_demo');
    paths = DemoPaths(support.path);
  });

  tearDown(() => support.deleteSync(recursive: true));

  test('background work runs when demo mode has never been used', () async {
    expect(backgroundWorkBlockedByDemoMode(paths), isFalse);
  });

  test(
    'every background task stands down while a demo directory exists',
    () async {
      Directory(paths.root).createSync(recursive: true);

      expect(backgroundWorkBlockedByDemoMode(paths), isTrue);
    },
  );

  test(
    'the dispatcher checks demo mode before it locates or opens a database',
    () {
      final source = File(
        'lib/core/services/background_service.dart',
      ).readAsStringSync();
      final dispatcher = source.substring(
        source.indexOf('void callbackDispatcher()'),
      );

      final check = dispatcher.indexOf('backgroundWorkBlockedByDemoMode(');
      expect(check, isNonNegative);
      expect(
        check,
        lessThan(dispatcher.indexOf('prepareHeadlessDatabaseLocation(')),
      );
      expect(check, lessThan(dispatcher.indexOf('openHeadlessDatabase(')));
    },
  );
}
