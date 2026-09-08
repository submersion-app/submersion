#include <cstdio>
#include <cstring>

#include "my_application.h"

// Set from pubspec.yaml's version by linux/runner/CMakeLists.txt.
#ifndef SUBMERSION_VERSION
#define SUBMERSION_VERSION "unknown"
#endif

int main(int argc, char** argv) {
  // Answered before GTK initializes, so packaging smoke tests can assert the
  // installed version in a container with no display server.
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--version") == 0) {
      printf("submersion %s\n", SUBMERSION_VERSION);
      return 0;
    }
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
