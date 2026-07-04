import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Google Drive implementation of CloudStorageProvider
///
/// Uses the Drive API's appDataFolder for app-specific storage.
/// This folder is hidden from the user and only accessible by this app.
///
/// Authentication is delegated to a [GoogleDriveAuthenticator]:
/// google_sign_in on iOS/macOS/Android, loopback OAuth on Windows/Linux.
class GoogleDriveStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  GoogleDriveStorageProvider({GoogleDriveAuthenticator? authenticator})
    : _authenticator = authenticator ?? _defaultAuthenticator();

  static final _log = LoggerService.forClass(GoogleDriveStorageProvider);

  static GoogleDriveAuthenticator _defaultAuthenticator() =>
      (Platform.isWindows || Platform.isLinux)
      ? DesktopOAuthAuthenticator()
      : GoogleSignInAuthenticator();

  final GoogleDriveAuthenticator _authenticator;
  drive.DriveApi? _driveApi;
  String? _syncFolderId;

  @override
  String get providerName => 'Google Drive';

  @override
  String get providerId => 'googledrive';

  @override
  Future<bool> isAvailable() async {
    // Mobile and macOS OAuth config is compile-time (Info.plist / Android
    // client registration). Desktop needs the committed Desktop-app client;
    // a build without it degrades to a hidden tile instead of crashing.
    return GoogleDriveClientConfig.isSupportedOnThisPlatform;
  }

  @override
  Future<bool> isAuthenticated() async {
    if (_api != null) return true;
    if (await _authenticator.attemptSilentAuth()) {
      return _api != null;
    }
    return false;
  }

  @override
  Future<void> authenticate() async {
    await _authenticator.authenticate();
    _driveApi = null; // rebuilt lazily from the fresh auth client
    if (_api == null) {
      throw const CloudStorageException(
        'Google Sign-In did not produce an authorized client',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _authenticator.signOut();
    _driveApi = null;
    _syncFolderId = null;
  }

  @override
  Future<String?> getUserEmail() => _authenticator.userEmail;

  /// The Drive API bound to the authenticator's current client, or null
  /// when not authenticated. Rebuilt lazily so a re-auth (new client)
  /// transparently produces a new API instance.
  drive.DriveApi? get _api {
    final client = _authenticator.authClient;
    if (client == null) {
      _driveApi = null;
      return null;
    }
    return _driveApi ??= drive.DriveApi(client);
  }

  drive.DriveApi get _requireApi {
    final api = _api;
    if (api == null) {
      throw const CloudStorageException('Not authenticated with Google Drive');
    }
    return api;
  }

  /// Runs a Drive operation with a single 401 retry: access tokens expire
  /// hourly mid-session, so one silent re-auth disambiguates a stale token
  /// from a revoked grant. On a revoked grant the authenticator clears its
  /// stored state and the user is asked to sign in again.
  ///
  /// The stale-vs-revoked disambiguation is the mobile authenticator's:
  /// google_sign_in's lightweight re-auth can mint a fresh token silently.
  /// The desktop authenticator's auto-refreshing client already handles
  /// hourly expiry itself, so a 401 reaching here means a genuinely revoked
  /// refresh token -- its handleAuthFailure() clears the token store, so the
  /// retry's attemptSilentAuth() fails and the user is asked to sign in again.
  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 401) rethrow;
      _log.info('Drive API returned 401; attempting silent re-auth');
      await _authenticator.handleAuthFailure();
      _driveApi = null;
      if (!await _authenticator.attemptSilentAuth()) {
        throw CloudStorageException(
          'Google Drive sign-in expired. Please sign in again.',
          e,
        );
      }
      return await operation();
    }
  }

  /// Maps a Drive error to a CloudStorageException with an actionable
  /// message where one exists (quota); otherwise a generic wrapper.
  CloudStorageException _mapDriveError(
    String operation,
    Object e,
    StackTrace stackTrace,
  ) {
    if (e is drive.DetailedApiRequestError &&
        e.status == 403 &&
        e.errors.any((d) => d.reason == 'storageQuotaExceeded')) {
      return CloudStorageException(
        'Google Drive storage is full',
        e,
        stackTrace,
      );
    }
    return CloudStorageException('$operation failed: $e', e, stackTrace);
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    try {
      return await _run(() async {
        final targetFolder = folderId ?? await getOrCreateSyncFolder();

        // Check if file already exists
        final existingFile = await _findFile(filename, targetFolder);

        drive.File result;
        final media = drive.Media(Stream.fromIterable([data]), data.length);

        if (existingFile != null) {
          // Update existing file
          result = await _requireApi.files.update(
            drive.File(),
            existingFile.id!,
            uploadMedia: media,
          );
          _log.info('Updated file: $filename (${result.id})');
        } else {
          // Create new file
          final fileMetadata = drive.File()
            ..name = filename
            ..parents = [targetFolder];

          result = await _requireApi.files.create(
            fileMetadata,
            uploadMedia: media,
          );
          _log.info('Created file: $filename (${result.id})');
        }

        return UploadResult(fileId: result.id!, uploadTime: DateTime.now());
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to upload file: $filename',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Upload', e, stackTrace);
    }
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      return await _run(() async {
        final response = await _requireApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );

        if (response is! drive.Media) {
          throw const CloudStorageException('Invalid download response');
        }

        final chunks = <List<int>>[];
        await for (final chunk in response.stream) {
          chunks.add(chunk);
        }

        final allBytes = chunks.expand((x) => x).toList();
        _log.info('Downloaded file: $fileId (${allBytes.length} bytes)');
        return Uint8List.fromList(allBytes);
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to download file: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Download', e, stackTrace);
    }
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    try {
      return await _run(() async {
        final file =
            await _requireApi.files.get(
                  fileId,
                  $fields: 'id,name,modifiedTime,size',
                )
                as drive.File;

        return CloudFileInfo(
          id: file.id!,
          name: file.name!,
          modifiedTime: file.modifiedTime ?? DateTime.now(),
          sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
        );
      });
    } catch (e) {
      _log.warning('Failed to get file info: $fileId - $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    try {
      return await _run(() async {
        final targetFolder = folderId ?? await getOrCreateSyncFolder();

        var query = "'$targetFolder' in parents and trashed = false";
        if (namePattern != null) {
          query += " and name contains '$namePattern'";
        }

        final fileList = await _requireApi.files.list(
          spaces: 'appDataFolder',
          q: query,
          $fields: 'files(id,name,modifiedTime,size)',
        );

        return (fileList.files ?? [])
            .where((f) => f.id != null && f.name != null)
            .map(
              (f) => CloudFileInfo(
                id: f.id!,
                name: f.name!,
                modifiedTime: f.modifiedTime ?? DateTime.now(),
                sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
              ),
            )
            .toList();
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error('Failed to list files', error: e, stackTrace: stackTrace);
      throw _mapDriveError('List files', e, stackTrace);
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      await _run(() => _requireApi.files.delete(fileId));
      _log.info('Deleted file: $fileId');
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete file: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Delete', e, stackTrace);
    }
  }

  @override
  Future<bool> fileExists(String fileId) async {
    try {
      await _run(() => _requireApi.files.get(fileId, $fields: 'id'));
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    try {
      return await _run(() async {
        final folderMetadata = drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parentFolderId ?? 'appDataFolder'];

        final folder = await _requireApi.files.create(folderMetadata);
        _log.info('Created folder: $folderName (${folder.id})');
        return folder.id!;
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create folder: $folderName',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Create folder', e, stackTrace);
    }
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    // Return cached folder ID if available
    if (_syncFolderId != null) {
      return _syncFolderId!;
    }

    try {
      return await _run(() async {
        // Look for existing sync folder
        const query =
            "name = '${CloudStorageProviderMixin.syncFolderName}' "
            "and mimeType = 'application/vnd.google-apps.folder' "
            "and 'appDataFolder' in parents "
            "and trashed = false";

        final fileList = await _requireApi.files.list(
          spaces: 'appDataFolder',
          q: query,
          $fields: 'files(id,name)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          _syncFolderId = fileList.files!.first.id!;
          _log.info('Found existing sync folder: $_syncFolderId');
          return _syncFolderId!;
        }

        // Create new sync folder
        _syncFolderId = await createFolder(
          CloudStorageProviderMixin.syncFolderName,
          parentFolderId: 'appDataFolder',
        );
        return _syncFolderId!;
      });
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get/create sync folder',
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapDriveError('Get/create sync folder', e, stackTrace);
    }
  }

  /// Find a file by name in a specific folder
  Future<drive.File?> _findFile(String filename, String folderId) async {
    try {
      final query =
          "name = '$filename' "
          "and '$folderId' in parents "
          "and trashed = false";

      final fileList = await _requireApi.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id,name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
      return null;
    } on drive.DetailedApiRequestError {
      // Let auth errors reach _run's 401 handling instead of masking them
      // as "file not found" (which would create a duplicate).
      rethrow;
    } catch (e) {
      _log.warning('Failed to find file: $filename - $e');
      return null;
    }
  }
}
