import 'package:flutter_test/flutter_test.dart';
// FlutterWebAuth2Platform lives in the platform-interface package (declared as
// an explicit dev_dependency); swap in a fake instance so the test never opens
// a real browser session.
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';

/// Fake platform so [FlutterWebAuthRedirectCapture.capture] completes without
/// driving a real in-app browser auth session. [MockPlatformInterfaceMixin]
/// lets us assign it to [FlutterWebAuth2Platform.instance] past the normal
/// construction-token check.
class _FakeWebAuthPlatform extends FlutterWebAuth2Platform
    with MockPlatformInterfaceMixin {
  _FakeWebAuthPlatform(this._result);

  final String _result;
  String? capturedUrl;
  String? capturedScheme;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    capturedUrl = url;
    capturedScheme = callbackUrlScheme;
    return _result;
  }
}

void main() {
  // FlutterWebAuth2.authenticate touches WidgetsBinding.instance for its
  // resume observer, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture forwards the authorize url and callback scheme to '
      'FlutterWebAuth2 and returns the captured redirect url', () async {
    // Restore the real platform instance afterward so the fake never leaks
    // into later tests sharing this isolate.
    final previous = FlutterWebAuth2Platform.instance;
    addTearDown(() => FlutterWebAuth2Platform.instance = previous);

    final fake = _FakeWebAuthPlatform('adobe+scheme://adobeid/cid?code=xyz');
    FlutterWebAuth2Platform.instance = fake;

    const capture = FlutterWebAuthRedirectCapture();
    final result = await capture.capture(
      authorizeUrl: Uri.parse(
        'https://ims-na1.adobelogin.com/ims/authorize/v2?client_id=cid',
      ),
      callbackScheme: 'adobe+scheme',
    );

    expect(result, 'adobe+scheme://adobeid/cid?code=xyz');
    expect(
      fake.capturedUrl,
      'https://ims-na1.adobelogin.com/ims/authorize/v2?client_id=cid',
    );
    expect(fake.capturedScheme, 'adobe+scheme');
  });
}
