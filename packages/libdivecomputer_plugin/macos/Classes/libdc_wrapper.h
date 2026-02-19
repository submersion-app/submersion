// Thin C wrapper around libdivecomputer functions.
// Keeps libdivecomputer headers as an implementation detail, not part
// of the plugin framework's public interface.

#ifndef LIBDC_WRAPPER_H
#define LIBDC_WRAPPER_H

// Get the libdivecomputer version string.
// Returns a statically allocated string (do not free).
const char *libdc_get_version(void);

#endif
