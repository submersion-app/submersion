#ifndef DIVE_COMPUTER_HOST_API_IMPL_H_
#define DIVE_COMPUTER_HOST_API_IMPL_H_

#include <flutter_linux/flutter_linux.h>
#include "dive_computer_api.g.h"

G_BEGIN_DECLS

// Registers the HostApi VTable handlers with the given binary messenger.
void dive_computer_host_api_impl_register(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // DIVE_COMPUTER_HOST_API_IMPL_H_
