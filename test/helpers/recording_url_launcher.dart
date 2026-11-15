import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// A url_launcher platform that opens nothing and remembers what it was
/// asked to open.
class RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  /// Every address handed over, in order.
  final List<String> launched = <String>[];

  /// How each was asked to open, alongside [launched].
  final List<PreferredLaunchMode> modes = <PreferredLaunchMode>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return true;
  }
}

/// Installs a [RecordingUrlLauncher] for the running test and puts the
/// platform's own back when the test ends: the instance is process-wide,
/// and other files run in this isolate.
RecordingUrlLauncher useRecordingUrlLauncher() {
  final original = UrlLauncherPlatform.instance;
  addTearDown(() => UrlLauncherPlatform.instance = original);
  final launcher = RecordingUrlLauncher();
  UrlLauncherPlatform.instance = launcher;
  return launcher;
}
