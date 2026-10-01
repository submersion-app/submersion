/// A sample's decompression state as libdivecomputer reports it
/// (`dc_deco_type_t`), stored in `deco_type`.
const int kDecoTypeNdl = 0;

/// A safety stop: recommended, not required. Its stop depth is no ceiling.
const int kDecoTypeSafetyStop = 1;

/// A mandatory decompression stop.
const int kDecoTypeDecoStop = 2;

/// A deep stop the computer asks for.
const int kDecoTypeDeepStop = 3;

/// The ceiling a sample's reported stop depth stands for.
///
/// Only a deco stop or a deep stop is a stop the computer requires, so only
/// those make [decoDepth] a ceiling. A safety stop is not an obligation:
/// some computers (the Deep Six Excursion) report its real depth, which
/// stored as a ceiling drew a deco stop band on a no-deco dive (#2550).
double? decoStopCeiling(int? decoType, double? decoDepth) =>
    decoType == kDecoTypeDecoStop || decoType == kDecoTypeDeepStop
    ? decoDepth
    : null;
