// Generated from version.h.in - libdivecomputer 0.10.0
#ifndef DC_VERSION_H
#define DC_VERSION_H

#ifdef __cplusplus
extern "C" {
#endif

#define DC_VERSION "0.10.0"
#define DC_VERSION_MAJOR 0
#define DC_VERSION_MINOR 10
#define DC_VERSION_MICRO 0

#define DC_VERSION_CHECK(major,minor,micro) \
	(DC_VERSION_MAJOR > (major) || \
	(DC_VERSION_MAJOR == (major) && DC_VERSION_MINOR > (minor)) || \
	(DC_VERSION_MAJOR == (major) && DC_VERSION_MINOR == (minor) && \
		DC_VERSION_MICRO >= (micro)))

typedef struct dc_version_t {
	unsigned int major;
	unsigned int minor;
	unsigned int micro;
} dc_version_t;

const char *
dc_version (dc_version_t *version);

int
dc_version_check (unsigned int major, unsigned int minor, unsigned int micro);

#ifdef __cplusplus
}
#endif

#endif
