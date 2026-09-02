/// A decimal-degree position read from a media file's own metadata.
typedef GpsFix = ({double latitude, double longitude});

/// True when the pair is a usable position: finite, inside the valid
/// ranges, and not the `(0, 0)` that cameras and phones write when the
/// receiver had no fix. Matches the guard the media repository applies when
/// it reads coordinates back.
bool isPlausibleFix(double latitude, double longitude) {
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  if (latitude == 0 && longitude == 0) return false;
  return true;
}
