import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// A share platform that looks up [SharePlatform.instance] on every share.
///
/// `SharePlus.instance` is a `static final` that keeps whichever platform it
/// reads first, for the life of the isolate. With many test files in one
/// isolate, the first file to share would pin its own fake and every later
/// fake would be ignored. Pinning this forwarder instead lets each file install
/// its fake the usual way, through `SharePlatform.instance`.
class LateBoundSharePlatform extends SharePlatform {
  final SharePlatform _channel = MethodChannelShare();

  @override
  Future<ShareResult> share(ShareParams params) {
    final current = SharePlatform.instance;
    // Nothing installed: behave as the plugin does out of the box, so tests
    // that mock the share channel keep working.
    return (identical(current, this) ? _channel : current).share(params);
  }
}

/// Make [SharePlus.instance] capture a [LateBoundSharePlatform].
///
/// Call once per isolate, before any test shares.
void pinLateBoundSharePlatform() {
  if (SharePlatform.instance is! LateBoundSharePlatform) {
    SharePlatform.instance = LateBoundSharePlatform();
  }
  // Reading the instance is what makes SharePlus capture the forwarder.
  SharePlus.instance;
}
