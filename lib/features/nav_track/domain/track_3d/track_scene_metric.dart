/// Metrics an underwater track's 3D ribbon can be colored by.
///
/// A parallel enum to `dive_3d`'s `SceneMetric` rather than an extension
/// of it: that enum's exhaustive switches live across several dive-only
/// files, and a track has none of `ascentRate`/`ppO2`/`cns`/
/// `tankPressure`/`tts` -- adding four dead cases to every one of those
/// switches would be the wrong trade for reusing one enum. Every track
/// metric is continuous, so all of them color through
/// `MetricPalette.rampColorsFor`, the dive scene's own ramp.
enum TrackSceneMetric { depth, temperature, speed, batteryVoltage }
