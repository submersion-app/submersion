import 'package:flutter_test/flutter_test.dart';

import 'global_state_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/test_global_state_restored_test.dart`.
///
/// Uses synthetic source rather than the real `test/` tree, so the accept and
/// reject shapes stay pinned as the suite changes.
void main() {
  List<GlobalStateOffence> scan(String source) =>
      scanForUnrestoredGlobals('test/x_test.dart', source);

  group('platform singletons', () {
    test('an assignment with no capture is an offence', () {
      final offences = scan('''
void main() {
  setUp(() {
    PathProviderPlatform.instance = _Fake();
  });
}
''');

      expect(offences, hasLength(1));
      expect(offences.single.rule, platformRule);
      expect(offences.single.line, 3);
      expect(offences.single.text, 'PathProviderPlatform.instance = _Fake();');
      expect(
        offences.single.toString(),
        'test/x_test.dart:3: [platform singleton] '
        'PathProviderPlatform.instance = _Fake();',
      );
    });

    test('capturing the previous value in setUp is accepted', () {
      final offences = scan('''
late PathProviderPlatform original;
setUp(() {
  original = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _Fake();
});
tearDown(() => PathProviderPlatform.instance = original);
''');

      expect(offences, isEmpty);
    });

    test('capturing inside an arrow callback is accepted', () {
      final offences = scan('''
setUp(() => original = PermissionHandlerPlatform.instance);
tearDown(() => PermissionHandlerPlatform.instance = original);
''');

      expect(offences, isEmpty);
    });

    test('capturing into a final inside the test body is accepted', () {
      final offences = scan('''
test('t', () {
  final original = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = _Fake();
  addTearDown(() => VideoPlayerPlatform.instance = original);
});
''');

      expect(offences, isEmpty);
    });

    test('a comparison is not a capture', () {
      final offences = scan('''
setUp(() => SharePlatform.instance = fake);
test('t', () => expect(fake == SharePlatform.instance, isTrue));
''');

      expect(offences.map((o) => o.rule), [platformRule]);
    });

    test('a capture that is never assigned back is an offence', () {
      final offences = scan('''
final current = SharePlatform.instance;
SharePlatform.instance = fake;
''');

      expect(offences.map((o) => o.line), [2]);
      expect(offences.single.rule, platformRule);
    });

    test('assigning back a different variable is an offence', () {
      final offences = scan('''
final original = SharePlatform.instance;
SharePlatform.instance = fake;
addTearDown(() => SharePlatform.instance = other);
''');

      expect(offences.map((o) => o.line), [2, 3]);
    });

    test('capturing one platform does not excuse another', () {
      final offences = scan('''
final original = SharePlatform.instance;
SharePlatform.instance = share;
addTearDown(() => SharePlatform.instance = original);
PathProviderPlatform.instance = paths;
''');

      expect(offences.map((o) => o.line), [4]);
    });

    test('every unrestored assignment is reported', () {
      final offences = scan('''
test('a', () => PathProviderPlatform.instance = one);
test('b', () => PathProviderPlatform.instance = two);
''');

      expect(offences.map((o) => o.line), [1, 2]);
    });

    test('an assignment in a comment is ignored', () {
      final offences = scan('''
// PathProviderPlatform.instance = _Fake();
void main() {}
''');

      expect(offences, isEmpty);
    });
  });

  group('HTTP overrides', () {
    test('an assignment with no capture is an offence', () {
      final offences = scan('HttpOverrides.global = _Overrides();\n');

      expect(offences.map((o) => o.rule), [httpRule]);
    });

    test('a capture that is never assigned back is an offence', () {
      final offences = scan('''
final previous = HttpOverrides.current;
HttpOverrides.global = _Overrides();
''');

      expect(offences.map((o) => o.rule), [httpRule]);
    });

    test(
      'capturing HttpOverrides.current and assigning it back is accepted',
      () {
        final offences = scan('''
final previous = HttpOverrides.current;
HttpOverrides.global = _Overrides();
addTearDown(() => HttpOverrides.global = previous);
''');

        expect(offences, isEmpty);
      },
    );
  });

  group('harness defaults', () {
    for (final name in harnessDefaults) {
      test('changing $name without the helper is an offence', () {
        final offences = scan('setUp(() => $name = true);\n');

        expect(offences.map((o) => o.rule), [harnessRule]);
      });

      test('changing $name and calling the helper is accepted', () {
        final offences = scan('''
setUp(() => $name = true);
tearDown(applyGlobalTestDefaults);
''');

        expect(offences, isEmpty);
      });
    }

    test('restoring by hand is still an offence', () {
      final offences = scan('''
setUp(() => QualityScanScheduler.enabled = true);
tearDown(() => QualityScanScheduler.enabled = false);
''');

      expect(offences.map((o) => o.line), [1, 2]);
    });

    test('reading a default is not an offence', () {
      final offences = scan('''
test('t', () => expect(QualityScanScheduler.enabled == false, isTrue));
''');

      expect(offences, isEmpty);
    });
  });

  group('channel mocks', () {
    const install = '''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
});
''';

    test('a handler that is never removed is an offence', () {
      final offences = scan(install);

      expect(offences, hasLength(1));
      expect(offences.single.rule, channelRule);
      expect(offences.single.line, 2);
    });

    test('calling the clearing helper is accepted', () {
      final offences = scan(
        '${install}tearDownAll(clearPathAndShareChannelMocks);\n',
      );

      expect(offences, isEmpty);
    });

    test('removing the handler by hand is accepted', () {
      final offences = scan('''
${install}tearDownAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
});
''');

      expect(offences, isEmpty);
    });

    test('a handler that answers null is not a removal', () {
      final offences = scan('''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (call) async => null,
  );
});
''');

      expect(offences.map((o) => o.rule), [channelRule]);
    });

    test('a mock on any other channel is not covered', () {
      final offences = scan('''
setUpAll(() {
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async => true,
  );
});
''');

      expect(offences, isEmpty);
    });
  });

  test('a file with Windows line endings reports clean text', () {
    final offences = scan(
      'SharePlatform.instance = fake;\r\nvoid main() {}\r\n',
    );

    expect(offences.single.text, 'SharePlatform.instance = fake;');
  });
}
