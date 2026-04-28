import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

sealed class NetworkBytesResult {
  const NetworkBytesResult();
}

class NetworkBytesOk extends NetworkBytesResult {
  const NetworkBytesOk({
    required this.bytes,
    required this.contentType,
    required this.finalUrl,
  });
  final Uint8List bytes;
  final String? contentType;
  final String finalUrl;
}

class NetworkBytesUnauthenticated extends NetworkBytesResult {
  const NetworkBytesUnauthenticated();
}

class NetworkBytesError extends NetworkBytesResult {
  const NetworkBytesError(this.message);
  final String message;
}

class NetworkUrlResolver {
  NetworkUrlResolver({
    required http.Client client,
    required NetworkCredentialsService credentials,
    int maxRedirects = 5,
  }) : _client = client,
       _credentials = credentials,
       _maxRedirects = maxRedirects;

  final http.Client _client;
  final NetworkCredentialsService _credentials;
  final int _maxRedirects;

  Future<NetworkBytesResult> fetch(
    Uri uri, {
    Map<String, String>? extraHeaders,
  }) async {
    var current = uri;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final headers = <String, String>{
        ...?extraHeaders,
        ...?await _credentials.headersFor(current),
      };
      final http.Response response;
      try {
        response = await _client.get(current, headers: headers);
      } catch (e) {
        return NetworkBytesError('transport: $e');
      }
      final code = response.statusCode;
      if (code == 401) return const NetworkBytesUnauthenticated();
      if (code >= 300 && code < 400) {
        final loc = response.headers['location'];
        if (loc == null) return NetworkBytesError('$code without Location');
        current = current.resolve(loc);
        continue;
      }
      if (code >= 200 && code < 300) {
        return NetworkBytesOk(
          bytes: response.bodyBytes,
          contentType: response.headers['content-type'],
          finalUrl: current.toString(),
        );
      }
      return NetworkBytesError('HTTP $code');
    }
    return const NetworkBytesError('Too many redirects');
  }
}
