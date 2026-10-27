/// The features demo mode seals off so the sample logbook never reaches the
/// user's real data, and nothing real reaches the sample logbook.
enum DemoSealedFeature {
  sync,
  sharedLibrary,
  backup,
  restore,
  fileImport,
  diveComputerDownload,
  cloudImport,
  mediaImport,
  export,
  share,
  databaseFile,
}

/// Thrown by a sealed engine method called while demo mode is active.
class DemoModeSealedException implements Exception {
  const DemoModeSealedException(this.feature);

  final DemoSealedFeature feature;

  @override
  String toString() =>
      'DemoModeSealedException: ${feature.name} is unavailable in demo mode';
}
