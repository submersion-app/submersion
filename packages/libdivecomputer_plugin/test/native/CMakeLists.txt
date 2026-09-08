cmake_minimum_required(VERSION 3.18)
project(libdc_wrapper_tests LANGUAGES C)

set(WRAPPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/Classes")
set(LIBDC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/libdivecomputer")
set(CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/config")

# Test the wrapper struct definitions and sentinel conventions.
add_executable(test_dive_converter
    test_dive_converter.c
)
target_include_directories(test_dive_converter PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

add_executable(test_serial_callbacks
    test_serial_callbacks.c
)
target_include_directories(test_serial_callbacks PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

add_executable(test_descriptor_matcher
    test_descriptor_matcher.c
)
target_include_directories(test_descriptor_matcher PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

# Integration test: links the real libdivecomputer descriptor table so it
# exercises libdc_descriptor_match end-to-end (BLE name -> descriptor). The
# minimal source set below is everything the matcher transitively needs from
# libdivecomputer.
add_executable(test_descriptor_match_integration
    test_descriptor_match_integration.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${LIBDC_DIR}/src/descriptor.c
    ${LIBDC_DIR}/src/iterator.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/platform.c
    ${LIBDC_DIR}/src/version.c
)
target_include_directories(test_descriptor_match_integration PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

# Integration test: the USB HID descriptor queries (issue #1271). Links the
# real descriptor table so dc_descriptor_filter's vendor/product id lists are
# the ones under test, not a copy of them. Same minimal source set as the
# matcher integration test above.
add_executable(test_usbhid_descriptor_match
    test_usbhid_descriptor_match.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${LIBDC_DIR}/src/descriptor.c
    ${LIBDC_DIR}/src/iterator.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/platform.c
    ${LIBDC_DIR}/src/version.c
)
target_include_directories(test_usbhid_descriptor_match PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

# Regression test for issue #280: hw_ostc3_read must accumulate the bytes each
# read actually returns, not assume every dc_iostream_read filled the full
# request (false for the one-notification-per-read BLE transport). The test
# #includes hw_ostc3.c to reach the static read helper, so it links that
# driver's transitive leaf dependencies + the private headers under src/.
# device.c is deliberately NOT linked: its dc_device_open switch-dispatches to
# ~40 driver *_device_open functions and would pull in the whole library; the
# few device-private symbols hw_ostc3.c references from functions this test
# never calls are stubbed in test_hw_ostc3_read.c instead.
add_executable(test_hw_ostc3_read
    test_hw_ostc3_read.c
    ${LIBDC_DIR}/src/iostream.c
    ${LIBDC_DIR}/src/custom.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/context.c
    ${LIBDC_DIR}/src/buffer.c
    ${LIBDC_DIR}/src/aes.c
    ${LIBDC_DIR}/src/packet.c
    ${LIBDC_DIR}/src/common.c
    ${LIBDC_DIR}/src/platform.c
    # ringbuffer.c: hw_ostc3.c gained a ringbuffer_distance() dependency in the
    # upstream frog/ostc3 integration merged for Perdix 3 V2 support.
    ${LIBDC_DIR}/src/ringbuffer.c
)
target_include_directories(test_hw_ostc3_read PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)

# Regression test for issue #480: shearwater_petrel_device_foreach must
# deliver dives oldest first (so the newest-fingerprint resume point works
# after a partial BLE download), preserve manifest records behind deleted
# (0x5A23) entries, and keep exact progress accounting. The test #includes
# shearwater_petrel.c to reach the static foreach and mocks the whole
# shearwater_common transport layer, so only leaf dependencies are linked.
add_executable(test_shearwater_petrel_foreach
    test_shearwater_petrel_foreach.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/buffer.c
    ${LIBDC_DIR}/src/context.c
    ${LIBDC_DIR}/src/common.c
    ${LIBDC_DIR}/src/platform.c
)
target_include_directories(test_shearwater_petrel_foreach PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)

# Regression test for issue #766: shearwater_common_download must decode a
# NAK'd init request (a well-formed device refusal) as DC_STATUS_UNSUPPORTED
# instead of the generic DC_STATUS_PROTOCOL, so the petrel foreach loop can
# skip refused records rather than aborting the whole pass. The test #includes
# shearwater_common.c to drive the real SLIP framing over a mock BLE iostream,
# so only leaf dependencies are linked.
add_executable(test_shearwater_common_download
    test_shearwater_common_download.c
    ${LIBDC_DIR}/src/iostream.c
    ${LIBDC_DIR}/src/custom.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/buffer.c
    ${LIBDC_DIR}/src/context.c
    ${LIBDC_DIR}/src/common.c
    ${LIBDC_DIR}/src/platform.c
    # datetime.c: the #included shearwater_common.c also carries the timesync
    # helpers, which call dc_datetime_mktime.
    ${LIBDC_DIR}/src/datetime.c
)
target_include_directories(test_shearwater_common_download PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)

# Regression test for issue #285: the Scubapro G2 HUD download over BLE. The
# uwatec_smart driver keeps `transferred - 1` bytes of every read as payload
# and cannot re-frame a read carrying several notifications (G2 firmware 1.4+
# no longer puts a length in the first byte), so the transport's
# one-notification-per-read guarantee is load-bearing. The test replays the
# HUD's real handshake through the #included driver over a scripted BLE
# iostream: packet-preserving reads complete the download, coalesced reads
# fail with PROTOCOL (the macOS -8), and a lost notification times out after
# the last packet (the Android -7). Leaf dependencies only; device.c symbols
# are stubbed in the test for the same reason as test_hw_ostc3_read.
add_executable(test_uwatec_smart_ble_download
    test_uwatec_smart_ble_download.c
    ${LIBDC_DIR}/src/iostream.c
    ${LIBDC_DIR}/src/custom.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/buffer.c
    ${LIBDC_DIR}/src/context.c
    ${LIBDC_DIR}/src/common.c
    ${LIBDC_DIR}/src/platform.c
    # datetime.c: the dump stamps the clock event with dc_datetime_now.
    ${LIBDC_DIR}/src/datetime.c
    # checksum.c: the #included driver's IrDA path (not exercised) links it.
    ${LIBDC_DIR}/src/checksum.c
)
target_include_directories(test_uwatec_smart_ble_download PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)

# test_parse_raw_dive requires the full libdivecomputer + wrapper linked in.
# Use the Windows config on Windows, macOS config otherwise.
if(WIN32)
    set(PLATFORM_CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../windows/config")
else()
    set(PLATFORM_CONFIG_DIR "${CONFIG_DIR}")
endif()

# Collect libdivecomputer sources needed for parsing (exclude platform I/O
# files that don't compile cross-platform). CONFIGURE_DEPENDS re-runs the glob
# on every build so the target stays in sync when the submodule adds/removes
# sources, without a manual CMake cache wipe.
file(GLOB LIBDC_ALL_SOURCES CONFIGURE_DEPENDS "${LIBDC_DIR}/src/*.c")
list(FILTER LIBDC_ALL_SOURCES EXCLUDE REGEX "serial_posix\\.c$")
if(NOT WIN32)
    list(FILTER LIBDC_ALL_SOURCES EXCLUDE REGEX "serial_win32\\.c$")
endif()

add_executable(test_parse_raw_dive
    test_parse_raw_dive.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_parse_raw_dive PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_parse_raw_dive PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_parse_raw_dive PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_parse_raw_dive PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# The event-name table is shared by every platform binding, so it is tested
# against the libdivecomputer enum symbols here rather than per platform.
add_executable(test_event_type_names
    test_event_type_names.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_event_type_names PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_event_type_names PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_event_type_names PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_event_type_names PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# Regression test for issue #810: the Shearwater parser must report the raw O2
# cell output even when the logged calibration value cannot be trusted. Exercises
# the parser through the public API only, so it needs the full library but not
# the wrapper.
add_executable(test_shearwater_o2_millivolt
    test_shearwater_o2_millivolt.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_shearwater_o2_millivolt PRIVATE
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_shearwater_o2_millivolt PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_shearwater_o2_millivolt PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_shearwater_o2_millivolt PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# Regression test for issue #1223: a sample carrying two transmitter pressures
# must keep both. Goes through the wrapper, since the loss was in its per-sample
# accumulator rather than in libdivecomputer.
add_executable(test_multi_transmitter_pressure
    test_multi_transmitter_pressure.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_multi_transmitter_pressure PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_multi_transmitter_pressure PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_multi_transmitter_pressure PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_multi_transmitter_pressure PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# The transmitter serial libdivecomputer's Shearwater parser decodes from the
# opening records must reach the wrapper's tank summary, so the app can tell
# two computers paired to one transmitter apart from two cylinders.
add_executable(test_tank_transmitter_serial
    test_tank_transmitter_serial.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_tank_transmitter_serial PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_tank_transmitter_serial PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_tank_transmitter_serial PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_tank_transmitter_serial PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# Regression test for issue #1481: since APOS5 firmware 5.2.11 the Ratio iX3M 2
# packs tank data into the high bits of the sample record type, and the parser
# skipped every record whose type was not literally 0, so dives imported as
# 0 m / 0 min. Goes through the wrapper so the whole parse path is covered.
add_executable(test_ratio_ix3m2_record_type
    test_ratio_ix3m2_record_type.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_ratio_ix3m2_record_type PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_ratio_ix3m2_record_type PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_ratio_ix3m2_record_type PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_ratio_ix3m2_record_type PRIVATE SetupAPI.lib ws2_32.lib)
endif()

# PR #342: the Cressi Leonardo logs a deco obligation in bit 11 of each sample
# word and grades its ascent rate 0-3, of which only level 3 sounds the alarm.
# Goes through the wrapper, because what the parser may leave unreported
# depends on the wrapper carrying deco state forward across samples.
add_executable(test_cressi_leonardo_deco
    test_cressi_leonardo_deco.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_cressi_leonardo_deco PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_cressi_leonardo_deco PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_cressi_leonardo_deco PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_cressi_leonardo_deco PRIVATE SetupAPI.lib ws2_32.lib)
endif()

enable_testing()
add_test(NAME test_dive_converter COMMAND test_dive_converter)
add_test(NAME test_serial_callbacks COMMAND test_serial_callbacks)
add_test(NAME test_descriptor_matcher COMMAND test_descriptor_matcher)
add_test(NAME test_descriptor_match_integration COMMAND test_descriptor_match_integration)
add_test(NAME test_usbhid_descriptor_match COMMAND test_usbhid_descriptor_match)
add_test(NAME test_hw_ostc3_read COMMAND test_hw_ostc3_read)
add_test(NAME test_shearwater_petrel_foreach COMMAND test_shearwater_petrel_foreach)
add_test(NAME test_shearwater_common_download COMMAND test_shearwater_common_download)
add_test(NAME test_uwatec_smart_ble_download COMMAND test_uwatec_smart_ble_download)
add_test(NAME test_event_type_names COMMAND test_event_type_names)
add_test(NAME test_parse_raw_dive COMMAND test_parse_raw_dive
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
add_test(NAME test_multi_transmitter_pressure COMMAND test_multi_transmitter_pressure
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
add_test(NAME test_shearwater_o2_millivolt COMMAND test_shearwater_o2_millivolt
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
add_test(NAME test_tank_transmitter_serial COMMAND test_tank_transmitter_serial
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
add_test(NAME test_ratio_ix3m2_record_type COMMAND test_ratio_ix3m2_record_type)
add_test(NAME test_cressi_leonardo_deco COMMAND test_cressi_leonardo_deco)
