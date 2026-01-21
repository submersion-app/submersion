import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Platform channel helpers for iCloud container access and file download.
class ICloudNativeService {
  static const MethodChannel _channel = MethodChannel(
    'app.submersion/icloud_container',
  );
  static final _log = LoggerService.forClass(ICloudNativeService);

  static const String containerIdentifier = 'iCloud.app.submersion';

  /// Returns the iCloud container Documents directory, or null if unavailable.
  static Future<String?> getContainerPath() async {
    if (!Platform.isIOS && !Platform.isMacOS) return null;
    try {
      final path = await _channel.invokeMethod<String>(
        'getICloudContainerPath',
        {'identifier': containerIdentifier},
      );
      return path;
    } catch (e, stackTrace) {
      _log.warning('Failed to get iCloud container path: $e', stackTrace);
      return null;
    }
  }

  /// Ensures the iCloud file is downloaded locally before access.
  static Future<bool> downloadIfNeeded(String path) async {
    if (!Platform.isIOS && !Platform.isMacOS) return true;
    try {
      final result = await _channel.invokeMethod<bool>('downloadIfNeeded', {
        'path': path,
      });
      return result ?? false;
    } catch (e, stackTrace) {
      _log.warning('Failed to download iCloud file: $e', stackTrace);
      return false;
    }
  }

  /// Writes data to the given path using native file coordination.
  /// Throws an exception with the error details if writing fails.
  static Future<void> writeFile(String path, Uint8List data) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw Exception('writeFile only supported on iOS/macOS');
    }
    _log.info('writeFile: path=$path, size=${data.length} bytes');
    final result = await _channel.invokeMethod<bool>('writeFile', {
      'path': path,
      'data': data,
    });
    if (result != true) {
      throw Exception('Native writeFile returned false');
    }
    _log.info('writeFile: success');
  }

  /// Refreshes an iCloud folder to ensure we see the latest files from other devices.
  /// This triggers downloads for any files that exist in iCloud but aren't local.
  static Future<void> refreshFolder(String path) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      _log.info('refreshFolder: $path');
      await _channel.invokeMethod<bool>('refreshFolder', {'path': path});
      _log.info('refreshFolder: done');
    } catch (e, stackTrace) {
      _log.warning('Failed to refresh iCloud folder: $e', stackTrace);
      // Don't throw - folder refresh is best-effort
    }
  }

  /// Moves a local file into the iCloud container using native coordination.
  static Future<bool> moveFile(
    String sourcePath,
    String destinationPath,
  ) async {
    if (!Platform.isIOS && !Platform.isMacOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('moveFile', {
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
      });
      return result ?? false;
    } catch (e, stackTrace) {
      _log.warning('Failed to move iCloud file: $e', stackTrace);
      return false;
    }
  }
}
