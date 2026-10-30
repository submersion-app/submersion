import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

/// Where the list of published sample logbooks lives: an asset on this
/// repository's `demo-data` release, which is never the "latest" release.
const kDemoManifestUrl =
    'https://github.com/submersion-app/submersion/releases/download/demo-data/demo-manifest.json';

/// Fetches the manifest and picks the sample logbook this app can open.
class DemoManifestClient {
  DemoManifestClient({
    http.Client? client,
    Uri? url,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _url = url ?? Uri.parse(kDemoManifestUrl);

  final http.Client _client;
  final Uri _url;
  final Duration timeout;

  /// The newest package built at a schema no newer than [appSchemaVersion].
  ///
  /// Returns null for anything that goes wrong (offline, timeout, an error
  /// status, a malformed manifest, or no compatible package): the caller
  /// hides demo mode's entry points rather than offering something that
  /// cannot work.
  Future<DemoPackage?> fetchBest(int appSchemaVersion) async {
    try {
      final response = await _client.get(_url).timeout(timeout);
      if (response.statusCode != 200) return null;
      return DemoManifest.tryParse(response.body)?.bestFor(appSchemaVersion);
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } on Exception {
      return null;
    }
  }
}
