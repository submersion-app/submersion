/// Available map tile styles.
enum MapStyle {
  openStreetMap,
  openTopoMap,
  esriSatellite;

  /// Parse from stored string, defaulting to openStreetMap.
  static MapStyle fromName(String name) {
    return MapStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MapStyle.openStreetMap,
    );
  }
}
