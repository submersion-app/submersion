/// Map dive-mode strings emitted by the libdivecomputer plugin
/// ("freedive"/"gauge"/"open_circuit"/"ccr"/"scr") to the app's [DiveMode]
/// codes. Gauge maps to 'gauge'; freedive is intentionally deferred to 'oc'
/// (freedive is a separate axis handled elsewhere).
String mapLibdcDiveModeCode(String? mode) {
  switch (mode) {
    case 'open_circuit':
      return 'oc';
    case 'ccr':
      return 'ccr';
    case 'scr':
      return 'scr';
    case 'gauge':
      return 'gauge';
    // Freedive is a distinct libdivecomputer mode, intentionally deferred to
    // 'oc' for now (a separate axis; there is already a diveType.freedive).
    // Explicit so the intent survives any change to the default branch.
    case 'freedive':
      return 'oc';
    default:
      return 'oc';
  }
}
