import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../logger_service.dart';
import 'cloud_storage_provider.dart';

/// Google Drive implementation of CloudStorageProvider
///
/// Uses the Drive API's appDataFolder for app-specific storage.
/// This folder is hidden from the user and only accessible by this app.
class GoogleDriveStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(GoogleDriveStorageProvider);

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope, // Access to app-specific folder
    ],
  );

  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;
  String? _syncFolderId;

  @override
  String get providerName => 'Google Drive';

  @override
  String get providerId => 'googledrive';

  @override
  Future<bool> isAvailable() async {
    // Google Drive is available on all platforms Flutter supports
    return true;
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      // Try silent sign in first
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _initDriveApi();
        return true;
      }
      return false;
    } catch (e) {
      _log.warning('Silent sign-in failed: $e');
      return false;
    }
  }

  @override
  Future<void> authenticate() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) {
        throw const CloudStorageException('Sign-in was cancelled');
      }
      await _initDriveApi();
      _log.info('Authenticated with Google Drive as ${_currentUser!.email}');
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', e, stackTrace);
      throw CloudStorageException('Google Sign-In failed: $e', e, stackTrace);
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _syncFolderId = null;
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<String?> getUserEmail() async {
    return _currentUser?.email;
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw const CloudStorageException('Failed to get authenticated client');
    }
    _driveApi = drive.DriveApi(httpClient);
  }

  drive.DriveApi get _api {
    final api = _driveApi;
    if (api == null) {
      throw const CloudStorageException('Not authenticated with Google Drive');
    }
    return api;
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    try {
      final targetFolder = folderId ?? await getOrCreateSyncFolder();

      // Check if file already exists
      final existingFile = await _findFile(filename, targetFolder);

      drive.File result;
      final media = drive.Media(
        Stream.fromIterable([data]),
        data.length,
      );

      if (existingFile != null) {
        // Update existing file
        result = await _api.files.update(
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

        result = await _api.files.create(
          fileMetadata,
          uploadMedia: media,
        );
        _log.info('Created file: $filename (${result.id})');
      }

      return UploadResult(
        fileId: result.id!,
        uploadTime: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to upload file: $filename', e, stackTrace);
      throw CloudStorageException('Upload failed: $e', e, stackTrace);
    }
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      final response = await _api.files.get(
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
    } catch (e, stackTrace) {
      _log.error('Failed to download file: $fileId', e, stackTrace);
      throw CloudStorageException('Download failed: $e', e, stackTrace);
    }
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    try {
      final file = await _api.files.get(
        fileId,
        $fields: 'id,name,modifiedTime,size',
      ) as drive.File;

      return CloudFileInfo(
        id: file.id!,
        name: file.name!,
        modifiedTime: file.modifiedTime ?? DateTime.now(),
        sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
      );
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
      final targetFolder = folderId ?? await getOrCreateSyncFolder();

      var query = "'$targetFolder' in parents and trashed = false";
      if (namePattern != null) {
        query += " and name contains '$namePattern'";
      }

      final fileList = await _api.files.list(
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
    } catch (e, stackTrace) {
      _log.error('Failed to list files', e, stackTrace);
      throw CloudStorageException('List files failed: $e', e, stackTrace);
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      await _api.files.delete(fileId);
      _log.info('Deleted file: $fileId');
    } catch (e, stackTrace) {
      _log.error('Failed to delete file: $fileId', e, stackTrace);
      throw CloudStorageException('Delete failed: $e', e, stackTrace);
    }
  }

  @override
  Future<bool> fileExists(String fileId) async {
    try {
      await _api.files.get(fileId, $fields: 'id');
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
      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentFolderId ?? 'appDataFolder'];

      final folder = await _api.files.create(folderMetadata);
      _log.info('Created folder: $folderName (${folder.id})');
      return folder.id!;
    } catch (e, stackTrace) {
      _log.error('Failed to create folder: $folderName', e, stackTrace);
      throw CloudStorageException('Create folder failed: $e', e, stackTrace);
    }
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    // Return cached folder ID if available
    if (_syncFolderId != null) {
      return _syncFolderId!;
    }

    try {
      // Look for existing sync folder
      const query = "name = '${CloudStorageProviderMixin.syncFolderName}' "
          "and mimeType = 'application/vnd.google-apps.folder' "
          "and 'appDataFolder' in parents "
          "and trashed = false";

      final fileList = await _api.files.list(
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
    } catch (e, stackTrace) {
      _log.error('Failed to get/create sync folder', e, stackTrace);
      throw CloudStorageException(
        'Get/create sync folder failed: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Find a file by name in a specific folder
  Future<drive.File?> _findFile(String filename, String folderId) async {
    try {
      final query = "name = '$filename' "
          "and '$folderId' in parents "
          "and trashed = false";

      final fileList = await _api.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id,name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
      return null;
    } catch (e) {
      _log.warning('Failed to find file: $filename - $e');
      return null;
    }
  }
}
