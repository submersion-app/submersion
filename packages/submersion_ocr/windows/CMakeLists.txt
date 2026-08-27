# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "submersion_ocr")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "submersion_ocr_plugin")

list(APPEND PLUGIN_SOURCES
  "submersion_ocr_plugin.cpp"
  "submersion_ocr_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/submersion_ocr/submersion_ocr_plugin_c_api.h"
  "submersion_ocr_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# C++/WinRT projection for Windows.Media.Ocr.
target_link_libraries(${PLUGIN_NAME} PRIVATE WindowsApp.lib)

set(submersion_ocr_bundled_libraries
  ""
  PARENT_SCOPE
)
