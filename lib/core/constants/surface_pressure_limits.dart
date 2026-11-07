/// The surface pressures a dive can start from, in bar: a lake 6000 m up to a
/// record sea-level high. The libdivecomputer wrapper applies the same window
/// (`LIBDC_MIN_SURFACE_PRESSURE_BAR` and `LIBDC_MAX_SURFACE_PRESSURE_BAR` in
/// `libdc_wrapper.h`); keep the two in step (issue #4208).
const double kMinPlausibleSurfacePressureBar = 0.4;
const double kMaxPlausibleSurfacePressureBar = 1.2;

/// [bar] when some surface could read it, otherwise null. A header with no
/// reading holds zero, and an export's placeholder can hold anything, so a
/// value outside the window is no reading rather than a pressure. NaN fails
/// both comparisons and is no reading either.
double? plausibleSurfacePressureBar(double? bar) =>
    bar != null &&
        bar >= kMinPlausibleSurfacePressureBar &&
        bar <= kMaxPlausibleSurfacePressureBar
    ? bar
    : null;
