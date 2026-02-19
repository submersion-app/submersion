// config.h for macOS - generated manually (no autotools)

#ifndef CONFIG_H
#define CONFIG_H

// Logging
#define ENABLE_LOGGING 1

// macOS-specific headers
#define HAVE_PTHREAD_H 1
#define HAVE_MACH_MACH_TIME_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_SOCKET_H 1

// IOKit serial support on macOS
#define HAVE_IOKIT_SERIAL_IOSS_H 1

// Time functions available on macOS
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_TIMEGM 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_MACH_ABSOLUTE_TIME 1

// No Linux-specific features on macOS
// #undef HAVE_BLUEZ
// #undef HAVE_LIBUSB
// #undef HAVE_HIDAPI
// #undef HAVE_LINUX_SERIAL_H

#endif
