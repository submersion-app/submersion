#ifndef DIVE_CONVERTER_H_
#define DIVE_CONVERTER_H_

#include "dive_computer_api.g.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Converts a parsed dive from the C wrapper into a Pigeon ParsedDive.
ParsedDive ConvertParsedDive(const libdc_parsed_dive_t& dive);

// Maps a libdivecomputer event type to a string name.
std::string MapEventType(unsigned int type);

}  // namespace libdivecomputer_plugin

#endif  // DIVE_CONVERTER_H_
