// config.h for iOS - generated manually (no autotools)

#ifndef CONFIG_H
#define CONFIG_H

// Logging
#define ENABLE_LOGGING 1

// iOS-specific headers (same as macOS - Apple platform)
#define HAVE_PTHREAD_H 1
#define HAVE_MACH_MACH_TIME_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_UNISTD_H 1

// Time functions available on iOS
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_TIMEGM 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_MACH_ABSOLUTE_TIME 1

// No Linux-specific features on iOS
// #undef HAVE_BLUEZ
// #undef HAVE_LIBUSB
// #undef HAVE_HIDAPI
// #undef HAVE_LINUX_SERIAL_H

// No serial/socket on iOS
// #undef HAVE_SYS_SOCKET_H
// #undef HAVE_IOKIT_SERIAL_IOSS_H

#endif
