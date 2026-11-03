import 'package:flutter/foundation.dart' show immutable;

/// What this device can do, answered once so every screen asks the same
/// question the same way.
///
/// The native value reflects the operating system, as the checks it
/// replaces did; the browser value (`DeviceCapabilities.web`) encodes the
/// design's table of what a page cannot offer: no hardware, no background
/// work, no local files, no encryption at rest. UI code reads it through
/// `deviceCapabilitiesProvider` and never asks the platform directly.
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.diveComputerDownload,
    required this.nfc,
    required this.nearby,
    required this.healthImport,
    required this.devicePhotoLibrary,
    required this.mediaAttach,
    required this.biometricLock,
    required this.databaseEncryption,
    required this.backgroundTasks,
    required this.offlineMapTiles,
    required this.backupRestore,
    required this.sqliteImport,
    required this.demoMode,
    required this.agentAccess,
    required this.autoUpdate,
    required this.ocrImport,
    required this.customDatabaseFolder,
    required this.revealInFileManager,
    required this.cloudICloud,
    required this.cloudGit,
    required this.cloudGoogleDrive,
    required this.isBrowser,
  });

  /// Bluetooth, USB and serial downloads from dive computers.
  final bool diveComputerDownload;

  /// NFC tags on cylinders and gear.
  final bool nfc;

  /// Nearby device-to-device transfer.
  final bool nearby;

  /// Apple Health and Health Connect imports.
  final bool healthImport;

  /// The device's own photo library as a media source.
  final bool devicePhotoLibrary;

  /// Linking new media to dives, sites and species.
  final bool mediaAttach;

  /// Biometric unlock of the app lock.
  final bool biometricLock;

  /// Encryption of the database at rest.
  final bool databaseEncryption;

  /// Background sync and other work while the app is not in front.
  final bool backgroundTasks;

  /// Downloaded map tiles for offline use.
  final bool offlineMapTiles;

  /// Restoring a backup file into this device.
  final bool backupRestore;

  /// Imports that read another app's SQLite database directly.
  final bool sqliteImport;

  /// The sample logbook.
  final bool demoMode;

  /// The local MCP server for agents.
  final bool agentAccess;

  /// The in-app updater.
  final bool autoUpdate;

  /// Scanning paper logs with the camera.
  final bool ocrImport;

  /// Choosing where the database file lives.
  final bool customDatabaseFolder;

  /// Showing a file in Finder, Explorer or the file manager.
  final bool revealInFileManager;

  /// The iCloud sync store.
  final bool cloudICloud;

  /// The Git sync store.
  final bool cloudGit;

  /// The Google Drive sync store.
  final bool cloudGoogleDrive;

  /// Running as a web page.
  final bool isBrowser;

  /// This value with the named capabilities changed; a test simulating one
  /// device feature on another platform's build starts from the real value.
  DeviceCapabilities copyWith({
    bool? diveComputerDownload,
    bool? nfc,
    bool? nearby,
    bool? healthImport,
    bool? devicePhotoLibrary,
    bool? mediaAttach,
    bool? biometricLock,
    bool? databaseEncryption,
    bool? backgroundTasks,
    bool? offlineMapTiles,
    bool? backupRestore,
    bool? sqliteImport,
    bool? demoMode,
    bool? agentAccess,
    bool? autoUpdate,
    bool? ocrImport,
    bool? customDatabaseFolder,
    bool? revealInFileManager,
    bool? cloudICloud,
    bool? cloudGit,
    bool? cloudGoogleDrive,
    bool? isBrowser,
  }) => DeviceCapabilities(
    diveComputerDownload: diveComputerDownload ?? this.diveComputerDownload,
    nfc: nfc ?? this.nfc,
    nearby: nearby ?? this.nearby,
    healthImport: healthImport ?? this.healthImport,
    devicePhotoLibrary: devicePhotoLibrary ?? this.devicePhotoLibrary,
    mediaAttach: mediaAttach ?? this.mediaAttach,
    biometricLock: biometricLock ?? this.biometricLock,
    databaseEncryption: databaseEncryption ?? this.databaseEncryption,
    backgroundTasks: backgroundTasks ?? this.backgroundTasks,
    offlineMapTiles: offlineMapTiles ?? this.offlineMapTiles,
    backupRestore: backupRestore ?? this.backupRestore,
    sqliteImport: sqliteImport ?? this.sqliteImport,
    demoMode: demoMode ?? this.demoMode,
    agentAccess: agentAccess ?? this.agentAccess,
    autoUpdate: autoUpdate ?? this.autoUpdate,
    ocrImport: ocrImport ?? this.ocrImport,
    customDatabaseFolder: customDatabaseFolder ?? this.customDatabaseFolder,
    revealInFileManager: revealInFileManager ?? this.revealInFileManager,
    cloudICloud: cloudICloud ?? this.cloudICloud,
    cloudGit: cloudGit ?? this.cloudGit,
    cloudGoogleDrive: cloudGoogleDrive ?? this.cloudGoogleDrive,
    isBrowser: isBrowser ?? this.isBrowser,
  );

  /// The browser: a page with a database and a network connection, and
  /// nothing the hardware, the filesystem or the operating system provide.
  static const DeviceCapabilities web = DeviceCapabilities(
    diveComputerDownload: false,
    nfc: false,
    nearby: false,
    healthImport: false,
    devicePhotoLibrary: false,
    mediaAttach: false,
    biometricLock: false,
    databaseEncryption: false,
    backgroundTasks: false,
    offlineMapTiles: false,
    // The picker reads a backup into memory (issue #4121).
    backupRestore: true,
    sqliteImport: false,
    demoMode: false,
    agentAccess: false,
    autoUpdate: false,
    ocrImport: false,
    customDatabaseFolder: false,
    revealInFileManager: false,
    cloudICloud: false,
    cloudGit: false,
    cloudGoogleDrive: true,
    isBrowser: true,
  );
}
