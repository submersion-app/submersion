import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';

/// The store of the Google client id a browser signs in with (issue
/// #4121); tests hand it an in-memory keychain.
final googleWebClientIdStoreProvider = Provider<GoogleWebClientIdStore>(
  (ref) => GoogleWebClientIdStore(),
);

/// Submersion's own web client id where this site is one it is authorised
/// for, else null ([GoogleDriveClientConfig.builtInWebClientId]); tests
/// override it.
final googleBuiltInWebClientIdProvider = Provider<String?>(
  (ref) => GoogleDriveClientConfig.builtInWebClientId,
);
