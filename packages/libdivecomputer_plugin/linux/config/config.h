// config.h for Linux - generated manually (no autotools)

#ifndef CONFIG_H
#define CONFIG_H

// Logging
#define ENABLE_LOGGING 1

// Linux headers
#define HAVE_PTHREAD_H 1
#define HAVE_UNISTD_H 1
#define HAVE_STRINGS_H 1
#include <strings.h>
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_LINUX_SERIAL_H 1

// Time functions
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_TIMEGM 1
#define HAVE_CLOCK_GETTIME 1

// Linux-specific backends (optional - enabled if available)
// These require the system libraries to be installed.
// BlueZ for Bluetooth, libusb for USB HID.
// #define HAVE_BLUEZ 1
// #define HAVE_LIBUSB 1
// #define HAVE_HIDAPI 1

#endif
