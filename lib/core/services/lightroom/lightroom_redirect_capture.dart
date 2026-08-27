import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Opens an in-app browser auth session for [authorizeUrl] and completes
/// when the OS routes the custom-scheme callback ([callbackScheme]) back to
/// the app, returning the full redirected URL. Abstract so widget tests
/// inject a fake instead of driving a real platform channel.
abstract class LightroomRedirectCapture {
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  });
}

/// Production implementation backed by flutter_web_auth_2. Runs a
/// non-ephemeral session so the Adobe IMS cookie persists and a later
/// re-auth is usually a silent redirect.
class FlutterWebAuthRedirectCapture implements LightroomRedirectCapture {
  const FlutterWebAuthRedirectCapture();

  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) {
    return FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: callbackScheme,
      options: const FlutterWebAuth2Options(preferEphemeral: false),
    );
  }
}
