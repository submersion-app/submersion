import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// Remove the mock handlers from the path provider and share channels.
///
/// Flutter keeps a mock handler until it is replaced, so one left behind
/// answers for every test file that runs later in the same isolate, usually
/// with a directory the file that installed it has already deleted.
void clearPathAndShareChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pathProviderChannel, null);
  messenger.setMockMethodCallHandler(_shareChannel, null);
}
