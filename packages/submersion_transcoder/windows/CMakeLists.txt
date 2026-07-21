cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "submersion_transcoder")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "submersion_transcoder_plugin")

list(APPEND PLUGIN_SOURCES
  "submersion_transcoder_plugin.cpp"
  "submersion_transcoder_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/submersion_transcoder/submersion_transcoder_plugin_c_api.h"
  "submersion_transcoder_plugin_c_api.cpp"
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
# C++/WinRT projection for Windows.Media.Transcoding.
target_link_libraries(${PLUGIN_NAME} PRIVATE WindowsApp.lib)

set(submersion_transcoder_bundled_libraries
  ""
  PARENT_SCOPE
)
