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
)
target_include_directories(test_hw_ostc3_read PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)

enable_testing()
add_test(NAME test_dive_converter COMMAND test_dive_converter)
add_test(NAME test_serial_callbacks COMMAND test_serial_callbacks)
add_test(NAME test_descriptor_matcher COMMAND test_descriptor_matcher)
add_test(NAME test_descriptor_match_integration COMMAND test_descriptor_match_integration)
add_test(NAME test_hw_ostc3_read COMMAND test_hw_ostc3_read)
