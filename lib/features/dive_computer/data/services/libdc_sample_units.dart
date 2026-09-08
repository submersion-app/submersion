/// Units and constants at the libdivecomputer boundary.
///
/// The plugin hands Pigeon samples through with libdc's own units. Most of
/// them already match what the app stores; this file holds the ones that do
/// not, so every path from a libdc sample into the app (download, raw-log
/// import, reparse) converts in exactly one place.
library;

/// libdc's `SAMPLE_FLAGS_END`: an event carrying it closes the state the
/// matching `SAMPLE_FLAGS_BEGIN` (1) opened, rather than being a second
/// occurrence of it. Both ends of a decompression stop arrive as the same
/// `SAMPLE_EVENT_DECOSTOP`, so this flag is the only thing that separates
/// them.
const int kLibdcSampleFlagsEnd = 2;

/// libdc's `DC_SAMPLE_RBT` (remaining bottom time, or gas time remaining on
/// an air-integrated Shearwater) is reported in minutes. Profile points store
/// it in seconds, like `tts` and `ndl` and like the Subsurface and UDDF
/// importers already do.
int? libdcRbtToSeconds(int? minutes) => minutes == null ? null : minutes * 60;
