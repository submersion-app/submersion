import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'plist_test_helpers.dart';

/// Guards the iOS UIScene lifecycle wiring (issue #4695). iOS 27 kills an app
/// linked against its SDK at launch unless it adopts scenes, and no test that
/// runs Dart code would notice the manifest going missing or the plugin
/// registration moving back to launch, so these are file assertions.

const _info = 'ios/Runner/Info.plist';
final _runnerDir = p.join('ios', 'Runner');
final _appDelegate = p.join(_runnerDir, 'AppDelegate.swift');

/// The body of the first Swift function in [source] whose declaration
/// contains [signature], from its opening brace to the matching closing one.
String swiftFunctionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No function declaration contains "$signature"');
  }
  final open = source.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') depth--;
    if (depth == 0) return source.substring(open, i + 1);
  }
  throw StateError('Unbalanced braces after "$signature"');
}

/// The custom method-channel handlers in ios/Runner, by class name. Each
/// lives in a `<Name>Handler.swift` file named after its class.
List<String> runnerHandlerNames() =>
    Directory(_runnerDir)
        .listSync()
        .map((entry) => p.basename(entry.path))
        .where((name) => name.endsWith('Handler.swift'))
        .map((name) => p.basenameWithoutExtension(name))
        .toList()
      ..sort();

void main() {
  group('Info.plist scene manifest', () {
    test('declares one window scene served by FlutterSceneDelegate', () {
      final manifest = plistValue(_info, 'UIApplicationSceneManifest');
      expect(manifest, isNotNull, reason: 'iOS 27 requires a scene manifest');

      expect(
        dictValue(manifest!, 'UIApplicationSupportsMultipleScenes')?.name.local,
        'false',
      );

      final configurations = dictValue(manifest, 'UISceneConfigurations');
      final roles = dictValue(
        configurations!,
        'UIWindowSceneSessionRoleApplication',
      );
      final scenes = roles!.findElements('dict').toList();
      expect(scenes, hasLength(1));

      final scene = scenes.single;
      String? value(String key) => dictValue(scene, key)?.innerText.trim();
      expect(value('UISceneClassName'), 'UIWindowScene');
      expect(value('UISceneDelegateClassName'), 'FlutterSceneDelegate');
      expect(value('UISceneConfigurationName'), 'flutter');
      // The storyboard whose FlutterViewController creates the implicit
      // engine that AppDelegate registers plugins on.
      expect(value('UISceneStoryboardFile'), 'Main');
    });
  });

  group('AppDelegate', () {
    late String source;
    late String launch;
    late String engine;

    setUpAll(() {
      source = File(_appDelegate).readAsStringSync();
      launch = swiftFunctionBody(source, 'didFinishLaunchingWithOptions');
      engine = swiftFunctionBody(
        source,
        'func didInitializeImplicitFlutterEngine',
      );
    });

    test('is the implicit engine delegate', () {
      expect(
        source,
        matches(
          RegExp(
            r'class AppDelegate:\s*FlutterAppDelegate,\s*'
            r'FlutterImplicitEngineDelegate\b',
          ),
        ),
      );
    });

    test('registers plugins on the implicit engine, not at launch', () {
      expect(
        engine,
        contains('GeneratedPluginRegistrant.register(with: registry)'),
      );
      // At launch the scene has not connected, so there is no engine yet.
      // The Workmanager callback registers plugins on its own background
      // engine later, which is why the launch body may still name the
      // registrant inside that closure.
      expect(launch, isNot(contains('register(with: self)')));
      expect(launch, isNot(contains('registrar(forPlugin:')));
    });

    test('creates every channel handler on the implicit engine', () {
      final handlers = runnerHandlerNames();
      expect(handlers, hasLength(9));
      for (final handler in handlers) {
        expect(
          engine,
          contains('registry.registrar(forPlugin: "$handler")'),
          reason: '$handler must get its messenger from the implicit engine',
        );
      }
    });

    test('registers Workmanager launch handlers before launch finishes', () {
      // BGTaskScheduler only delivers a task to a relaunched app whose
      // handler was registered during didFinishLaunching. With scenes the
      // plugin itself registers too late to do it.
      expect(launch, contains('WorkmanagerPlugin.registerLaunchHandlers()'));
      expect(launch, contains('WorkmanagerPlugin.setPluginRegistrantCallback'));
    });
  });
}
