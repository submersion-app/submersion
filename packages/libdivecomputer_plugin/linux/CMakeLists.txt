cmake_minimum_required(VERSION 3.18)
set(PROJECT_NAME "libdivecomputer_plugin")
project(${PROJECT_NAME} LANGUAGES CXX C)

set(PLUGIN_NAME "libdivecomputer_plugin_plugin")
set(LIBDC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libdivecomputer")
set(WRAPPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../macos/Classes")
set(CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/config")

# libdivecomputer source files. On Linux we include serial_posix.c, socket.c,
# bluetooth.c for native serial and Bluetooth support.
set(LIBDC_SOURCES
    ${LIBDC_DIR}/src/version.c
    ${LIBDC_DIR}/src/descriptor.c
    ${LIBDC_DIR}/src/iostream.c
    ${LIBDC_DIR}/src/iterator.c
    ${LIBDC_DIR}/src/common.c
    ${LIBDC_DIR}/src/context.c
    ${LIBDC_DIR}/src/device.c
    ${LIBDC_DIR}/src/parser.c
    ${LIBDC_DIR}/src/datetime.c
    ${LIBDC_DIR}/src/timer.c
    ${LIBDC_DIR}/src/suunto_common.c
    ${LIBDC_DIR}/src/suunto_common2.c
    ${LIBDC_DIR}/src/suunto_solution.c
    ${LIBDC_DIR}/src/suunto_solution_parser.c
    ${LIBDC_DIR}/src/suunto_eon.c
    ${LIBDC_DIR}/src/suunto_eon_parser.c
    ${LIBDC_DIR}/src/suunto_vyper.c
    ${LIBDC_DIR}/src/suunto_vyper_parser.c
    ${LIBDC_DIR}/src/suunto_vyper2.c
    ${LIBDC_DIR}/src/suunto_d9.c
    ${LIBDC_DIR}/src/suunto_d9_parser.c
    ${LIBDC_DIR}/src/suunto_eonsteel.c
    ${LIBDC_DIR}/src/suunto_eonsteel_parser.c
    ${LIBDC_DIR}/src/reefnet_sensus.c
    ${LIBDC_DIR}/src/reefnet_sensus_parser.c
    ${LIBDC_DIR}/src/reefnet_sensuspro.c
    ${LIBDC_DIR}/src/reefnet_sensuspro_parser.c
    ${LIBDC_DIR}/src/reefnet_sensusultra.c
    ${LIBDC_DIR}/src/reefnet_sensusultra_parser.c
    ${LIBDC_DIR}/src/uwatec_aladin.c
    ${LIBDC_DIR}/src/uwatec_memomouse.c
    ${LIBDC_DIR}/src/uwatec_memomouse_parser.c
    ${LIBDC_DIR}/src/uwatec_smart.c
    ${LIBDC_DIR}/src/uwatec_smart_parser.c
    ${LIBDC_DIR}/src/oceanic_common.c
    ${LIBDC_DIR}/src/oceanic_atom2.c
    ${LIBDC_DIR}/src/oceanic_atom2_parser.c
    ${LIBDC_DIR}/src/oceanic_veo250.c
    ${LIBDC_DIR}/src/oceanic_veo250_parser.c
    ${LIBDC_DIR}/src/oceanic_vtpro.c
    ${LIBDC_DIR}/src/oceanic_vtpro_parser.c
    ${LIBDC_DIR}/src/pelagic_i330r.c
    ${LIBDC_DIR}/src/mares_common.c
    ${LIBDC_DIR}/src/mares_nemo.c
    ${LIBDC_DIR}/src/mares_nemo_parser.c
    ${LIBDC_DIR}/src/mares_puck.c
    ${LIBDC_DIR}/src/mares_darwin.c
    ${LIBDC_DIR}/src/mares_darwin_parser.c
    ${LIBDC_DIR}/src/mares_iconhd.c
    ${LIBDC_DIR}/src/mares_iconhd_parser.c
    ${LIBDC_DIR}/src/ihex.c
    ${LIBDC_DIR}/src/hw_ostc.c
    ${LIBDC_DIR}/src/hw_ostc_parser.c
    ${LIBDC_DIR}/src/hw_frog.c
    ${LIBDC_DIR}/src/hw_ostc3.c
    ${LIBDC_DIR}/src/aes.c
    ${LIBDC_DIR}/src/cressi_edy.c
    ${LIBDC_DIR}/src/cressi_edy_parser.c
    ${LIBDC_DIR}/src/cressi_leonardo.c
    ${LIBDC_DIR}/src/cressi_leonardo_parser.c
    ${LIBDC_DIR}/src/cressi_goa.c
    ${LIBDC_DIR}/src/cressi_goa_parser.c
    ${LIBDC_DIR}/src/zeagle_n2ition3.c
    ${LIBDC_DIR}/src/atomics_cobalt.c
    ${LIBDC_DIR}/src/atomics_cobalt_parser.c
    ${LIBDC_DIR}/src/shearwater_common.c
    ${LIBDC_DIR}/src/shearwater_predator.c
    ${LIBDC_DIR}/src/shearwater_predator_parser.c
    ${LIBDC_DIR}/src/shearwater_petrel.c
    ${LIBDC_DIR}/src/diverite_nitekq.c
    ${LIBDC_DIR}/src/diverite_nitekq_parser.c
    ${LIBDC_DIR}/src/citizen_aqualand.c
    ${LIBDC_DIR}/src/citizen_aqualand_parser.c
    ${LIBDC_DIR}/src/divesystem_idive.c
    ${LIBDC_DIR}/src/divesystem_idive_parser.c
    ${LIBDC_DIR}/src/platform.c
    ${LIBDC_DIR}/src/ringbuffer.c
    ${LIBDC_DIR}/src/rbstream.c
    ${LIBDC_DIR}/src/checksum.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/buffer.c
    ${LIBDC_DIR}/src/cochran_commander.c
    ${LIBDC_DIR}/src/cochran_commander_parser.c
    ${LIBDC_DIR}/src/tecdiving_divecomputereu.c
    ${LIBDC_DIR}/src/tecdiving_divecomputereu_parser.c
    ${LIBDC_DIR}/src/mclean_extreme.c
    ${LIBDC_DIR}/src/mclean_extreme_parser.c
    ${LIBDC_DIR}/src/liquivision_lynx.c
    ${LIBDC_DIR}/src/liquivision_lynx_parser.c
    ${LIBDC_DIR}/src/sporasub_sp2.c
    ${LIBDC_DIR}/src/sporasub_sp2_parser.c
    ${LIBDC_DIR}/src/deepsix_excursion.c
    ${LIBDC_DIR}/src/deepsix_excursion_parser.c
    ${LIBDC_DIR}/src/seac_screen_common.c
    ${LIBDC_DIR}/src/seac_screen.c
    ${LIBDC_DIR}/src/seac_screen_parser.c
    ${LIBDC_DIR}/src/deepblu_cosmiq.c
    ${LIBDC_DIR}/src/deepblu_cosmiq_parser.c
    ${LIBDC_DIR}/src/oceans_s1_common.c
    ${LIBDC_DIR}/src/oceans_s1.c
    ${LIBDC_DIR}/src/oceans_s1_parser.c
    ${LIBDC_DIR}/src/divesoft_freedom.c
    ${LIBDC_DIR}/src/divesoft_freedom_parser.c
    ${LIBDC_DIR}/src/halcyon_symbios.c
    ${LIBDC_DIR}/src/halcyon_symbios_parser.c
    ${LIBDC_DIR}/src/hdlc.c
    ${LIBDC_DIR}/src/packet.c
    ${LIBDC_DIR}/src/socket.c
    ${LIBDC_DIR}/src/irda.c
    ${LIBDC_DIR}/src/usb.c
    ${LIBDC_DIR}/src/usbhid.c
    ${LIBDC_DIR}/src/ble.c
    ${LIBDC_DIR}/src/bluetooth.c
    ${LIBDC_DIR}/src/custom.c
    ${LIBDC_DIR}/src/serial_posix.c
)

# Build libdivecomputer as a static library
add_library(divecomputer STATIC ${LIBDC_SOURCES})
target_include_directories(divecomputer PRIVATE
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)
target_compile_definitions(divecomputer PRIVATE HAVE_CONFIG_H _GNU_SOURCE)
target_compile_options(divecomputer PRIVATE
    -include ${CONFIG_DIR}/config.h
    -std=c11
)

# Plugin shared library (GObject-based for Linux)
add_library(${PLUGIN_NAME} SHARED
    libdivecomputer_plugin.cc
    dive_computer_host_api_impl.cc
    dive_computer_api.g.cc
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL
    HAVE_CONFIG_H
    _GNU_SOURCE
)

target_include_directories(${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_include_directories(${PLUGIN_NAME} PRIVATE
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
    ${WRAPPER_DIR}
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter divecomputer)
