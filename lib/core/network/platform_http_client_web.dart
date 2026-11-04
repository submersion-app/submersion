// dart:io compiles in a browser as a library whose members throw; only the
// callback's type is named here, so the facade's two variants share one
// signature.
import 'dart:io' show BadCertificateCallback;

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// A client over the page's fetch.
///
/// The browser owns the connect timeout, the proxy and certificate trust, so
/// the three arguments are accepted for the shared signature and ignored.
http.Client createPlatformHttpClient({
  Duration? connectionTimeout = const Duration(seconds: 15),
  bool omitDefaultUserAgent = false,
  BadCertificateCallback? onBadCertificate,
}) => BrowserClient();
