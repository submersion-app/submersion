cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "submersion_vision")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "submersion_vision_plugin")

# The Windows part of the marine life engine reads video frames for the ONNX
# engine (piece 3). The models run in Dart through ONNX Runtime, which the
# package's build hook ships from Windows ML's package, with DirectML and
# Windows ML's catalogue of hardware engines.
list(APPEND PLUGIN_SOURCES
  "submersion_vision_plugin.cpp"
  "submersion_vision_plugin.h"
  "frame_reader.cpp"
  "frame_reader.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/submersion_vision/submersion_vision_plugin_c_api.h"
  "submersion_vision_plugin_c_api.cpp"
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
# Media Foundation's source reader, as the transcoder's colour encode uses it.
target_link_libraries(${PLUGIN_NAME} PRIVATE mfplat.lib mfreadwrite.lib mfuuid.lib)

set(submersion_vision_bundled_libraries
  ""
  PARENT_SCOPE
)
