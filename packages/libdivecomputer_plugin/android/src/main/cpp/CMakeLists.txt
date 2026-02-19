cmake_minimum_required(VERSION 3.18)
project(libdivecomputer_plugin LANGUAGES C CXX)

set(PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../..")
set(LIBDC_DIR "${PLUGIN_DIR}/../third_party/libdivecomputer")
set(WRAPPER_DIR "${PLUGIN_DIR}/../macos/Classes")
set(CONFIG_DIR "${PLUGIN_DIR}/config")

# libdivecomputer source files (excluding platform-specific backends
# not available on Android: serial_posix.c, irda.c, socket.c)
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
    ${LIBDC_DIR}/src/usb.c
    ${LIBDC_DIR}/src/usbhid.c
    ${LIBDC_DIR}/src/ble.c
    ${LIBDC_DIR}/src/bluetooth.c
    ${LIBDC_DIR}/src/custom.c
)

# Build libdivecomputer as a static library
add_library(divecomputer STATIC ${LIBDC_SOURCES})
target_include_directories(divecomputer PRIVATE
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
)
target_compile_definitions(divecomputer PRIVATE HAVE_CONFIG_H)
target_compile_options(divecomputer PRIVATE -include ${CONFIG_DIR}/config.h)

# Build the C wrapper as part of the JNI library
# (reuse the same wrapper files from macOS)
add_library(libdc_jni SHARED
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    libdc_jni.cpp
)
target_include_directories(libdc_jni PRIVATE
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${CONFIG_DIR}
    ${WRAPPER_DIR}
)
target_compile_definitions(libdc_jni PRIVATE HAVE_CONFIG_H)
target_link_libraries(libdc_jni PRIVATE divecomputer log)
