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

enable_testing()
add_test(NAME test_dive_converter COMMAND test_dive_converter)
add_test(NAME test_serial_callbacks COMMAND test_serial_callbacks)
