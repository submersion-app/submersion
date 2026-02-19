// config.h for Android NDK - generated manually (no autotools)

#ifndef CONFIG_H
#define CONFIG_H

// Logging
#define ENABLE_LOGGING 1

// Android/Linux headers
#define HAVE_PTHREAD_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_PARAM_H 1

// Time functions available on Android
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_CLOCK_GETTIME 1

// Android does not have timegm in older NDK versions
// but it's available since API 12 (Bionic libc)
#define HAVE_TIMEGM 1

// No native BLE/USB backends on Android (handled via JNI)
// #undef HAVE_BLUEZ
// #undef HAVE_LIBUSB
// #undef HAVE_HIDAPI

// No serial on Android
// #undef HAVE_LINUX_SERIAL_H

#endif
