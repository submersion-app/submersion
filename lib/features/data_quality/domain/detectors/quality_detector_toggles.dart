/// Process-wide mirror of the disabled-detector set. The fire-and-forget
/// scan scheduler has no Riverpod ref, so the scan service reads toggles from
/// here. Toggles gate DETECTION only -- existing findings are never
/// mass-deleted (a disabled detector simply drops out of a scan's ran set).
abstract final class QualityDetectorToggles {
  static Set<String> disabled = <String>{};
}
