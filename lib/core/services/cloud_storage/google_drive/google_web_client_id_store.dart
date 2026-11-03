import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The Google client id a browser signs in with (issue #4121).
///
/// A web page cannot use the desktop or Android clients compiled into the
/// app: it needs a client of type "Web application" whose authorised
/// JavaScript origin is the site's address. Submersion's own site carries
/// one (`GoogleDriveClientConfig.builtInWebClientId`); anywhere else the
/// user pastes one from their own Google Cloud project, once. It lives with
/// the other sign-in details, so "remember on this device" keeps it and
/// Forget this device removes it.
class GoogleWebClientIdStore {
  GoogleWebClientIdStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  /// The secure storage key.
  static const String key = 'google_web_client_id';

  /// What every Google OAuth client id looks like: a project number, a
  /// dash, a lowercase token, and Google's suffix.
  static final RegExp _shape = RegExp(
    r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$',
  );

  final FallbackSecureStorage _storage;

  /// [raw] trimmed, or null when it is not a client id: a space or a
  /// missing suffix would otherwise fail later with an opaque sign-in error.
  static String? normalize(String raw) {
    final trimmed = raw.trim();
    return _shape.hasMatch(trimmed) ? trimmed : null;
  }

  Future<String?> read() => _storage.read(key: key);

  Future<void> write(String clientId) =>
      _storage.write(key: key, value: clientId);

  Future<void> clear() => _storage.delete(key: key);
}
