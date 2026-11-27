import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';

/// Where the firmware catalogue is published (issue #5104): the latest
/// release of `submersion-app/firmware-catalogue`. A development build points
/// it elsewhere with `--dart-define=FIRMWARE_CATALOGUE_URL=...`.
const String kFirmwareCatalogueUrl = String.fromEnvironment(
  'FIRMWARE_CATALOGUE_URL',
  defaultValue:
      'https://github.com/submersion-app/firmware-catalogue/releases/latest/download/firmware-catalogue.json',
);

/// What one fetch of the catalogue found.
sealed class FirmwareFetchResult {
  const FirmwareFetchResult();
}

/// A good file, with its text so it can be kept as it came.
final class FirmwareFetched extends FirmwareFetchResult {
  final FirmwareCatalogue catalogue;
  final String raw;
  const FirmwareFetched(this.catalogue, this.raw);
}

/// No release exists yet (404).
final class FirmwareNotPublished extends FirmwareFetchResult {
  const FirmwareNotPublished();
}

/// Offline, a server error, a timeout, or a file this build cannot read.
final class FirmwareFetchFailed extends FirmwareFetchResult {
  final String reason;
  const FirmwareFetchFailed(this.reason);
}

/// Fetches the published catalogue: a plain GET of a public file, with no
/// query string and nothing about the diver.
class FirmwareCatalogueClient {
  FirmwareCatalogueClient({
    http.Client? client,
    Uri? url,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _url = url ?? Uri.parse(kFirmwareCatalogueUrl);

  final http.Client _client;
  final Uri _url;
  final Duration timeout;

  Future<FirmwareFetchResult> fetch() async {
    final http.Response response;
    try {
      response = await _client.get(_url).timeout(timeout);
    } on TimeoutException {
      return const FirmwareFetchFailed('timeout');
    } catch (e) {
      return FirmwareFetchFailed('network: $e');
    }
    if (response.statusCode == 404) return const FirmwareNotPublished();
    if (response.statusCode != 200) {
      return FirmwareFetchFailed('http ${response.statusCode}');
    }
    final catalogue = FirmwareCatalogue.parse(response.body);
    if (catalogue == null) return const FirmwareFetchFailed('unreadable');
    return FirmwareFetched(catalogue, response.body);
  }
}
