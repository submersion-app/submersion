#ifndef DIVE_CONVERTER_H_
#define DIVE_CONVERTER_H_

#include <flutter_linux/flutter_linux.h>
#include "dive_computer_api.g.h"
#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Converts a parsed dive from the C wrapper into a Pigeon GObject ParsedDive.
LibdivecomputerPluginParsedDive* convert_parsed_dive(
    const libdc_parsed_dive_t* dive);

// Maps a libdivecomputer event type to a string name.
// Returns a pointer to a static string (caller must not free).
const char* map_event_type(unsigned int type);

G_END_DECLS

#endif  // DIVE_CONVERTER_H_
