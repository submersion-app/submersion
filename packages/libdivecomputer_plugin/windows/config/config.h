// config.h for Windows - generated manually (no autotools)

#ifndef CONFIG_H
#define CONFIG_H

// Logging
#define ENABLE_LOGGING 1

// Windows headers
#define HAVE_WINDOWS_H 1

// Time functions (MSVC-specific variants)
#define HAVE_LOCALTIME_S 1
#define HAVE_GMTIME_S 1
#define HAVE__MKGMTIME 1

// Windows-specific backends (optional - enabled if available)
// These require the system libraries to be installed.
// #define HAVE_LIBUSB 1
// #define HAVE_HIDAPI 1

#endif
