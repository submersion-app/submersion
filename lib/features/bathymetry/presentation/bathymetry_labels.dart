/// Display names for bathymetry source ids (used in provenance captions
/// and satisfying CC-BY attribution for GMRT/EMODnet).
String bathymetrySourceDisplayName(String id) => switch (id) {
  'gmrt' => 'GMRT',
  'emodnet' => 'EMODnet',
  'etopo2022' => 'ETOPO 2022',
  _ => id,
};
