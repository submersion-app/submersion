/// Unit conversions at the libdivecomputer boundary.
///
/// The plugin hands Pigeon samples through with libdc's own units. Most of
/// them already match what the app stores; this file holds the ones that do
/// not, so every path from a libdc sample into the app (download, raw-log
/// import, reparse) converts in exactly one place.
library;

/// libdc's `DC_SAMPLE_RBT` (remaining bottom time, or gas time remaining on
/// an air-integrated Shearwater) is reported in minutes. Profile points store
/// it in seconds, like `tts` and `ndl` and like the Subsurface and UDDF
/// importers already do.
int? libdcRbtToSeconds(int? minutes) => minutes == null ? null : minutes * 60;
