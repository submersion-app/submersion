#!/bin/bash
# Build libdivecomputer as a static library for macOS.
# Called from the podspec script_phase before Swift compilation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBDC_DIR="${SCRIPT_DIR}/../third_party/libdivecomputer"
CONFIG_DIR="${SCRIPT_DIR}/config"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_LIB="${BUILD_DIR}/libdivecomputer.a"

# Skip rebuild if already built
if [ -f "${OUTPUT_LIB}" ]; then
    echo "libdivecomputer.a already built, skipping."
    exit 0
fi

mkdir -p "${BUILD_DIR}"

# All source files from Makefile.am (excluding Windows-specific files)
SOURCES=(
    version.c descriptor.c iostream.c iterator.c common.c context.c
    device.c parser.c datetime.c timer.c
    suunto_common.c suunto_common2.c
    suunto_solution.c suunto_solution_parser.c
    suunto_eon.c suunto_eon_parser.c
    suunto_vyper.c suunto_vyper_parser.c
    suunto_vyper2.c
    suunto_d9.c suunto_d9_parser.c
    suunto_eonsteel.c suunto_eonsteel_parser.c
    reefnet_sensus.c reefnet_sensus_parser.c
    reefnet_sensuspro.c reefnet_sensuspro_parser.c
    reefnet_sensusultra.c reefnet_sensusultra_parser.c
    uwatec_aladin.c
    uwatec_memomouse.c uwatec_memomouse_parser.c
    uwatec_smart.c uwatec_smart_parser.c
    oceanic_common.c
    oceanic_atom2.c oceanic_atom2_parser.c
    oceanic_veo250.c oceanic_veo250_parser.c
    oceanic_vtpro.c oceanic_vtpro_parser.c
    pelagic_i330r.c
    mares_common.c
    mares_nemo.c mares_nemo_parser.c
    mares_puck.c
    mares_darwin.c mares_darwin_parser.c
    mares_iconhd.c mares_iconhd_parser.c
    ihex.c
    hw_ostc.c hw_ostc_parser.c
    hw_frog.c
    hw_ostc3.c
    aes.c
    cressi_edy.c cressi_edy_parser.c
    cressi_leonardo.c cressi_leonardo_parser.c
    cressi_goa.c cressi_goa_parser.c
    zeagle_n2ition3.c
    atomics_cobalt.c atomics_cobalt_parser.c
    shearwater_common.c
    shearwater_predator.c shearwater_predator_parser.c
    shearwater_petrel.c
    diverite_nitekq.c diverite_nitekq_parser.c
    citizen_aqualand.c citizen_aqualand_parser.c
    divesystem_idive.c divesystem_idive_parser.c
    platform.c ringbuffer.c rbstream.c checksum.c array.c buffer.c
    cochran_commander.c cochran_commander_parser.c
    tecdiving_divecomputereu.c tecdiving_divecomputereu_parser.c
    mclean_extreme.c mclean_extreme_parser.c
    liquivision_lynx.c liquivision_lynx_parser.c
    sporasub_sp2.c sporasub_sp2_parser.c
    deepsix_excursion.c deepsix_excursion_parser.c
    seac_screen_common.c
    seac_screen.c seac_screen_parser.c
    deepblu_cosmiq.c deepblu_cosmiq_parser.c
    oceans_s1_common.c
    oceans_s1.c oceans_s1_parser.c
    divesoft_freedom.c divesoft_freedom_parser.c
    halcyon_symbios.c halcyon_symbios_parser.c
    hdlc.c packet.c socket.c
    irda.c usb.c usbhid.c ble.c bluetooth.c custom.c
    serial_posix.c
)

CFLAGS=(
    -O2
    -std=c11
    -I"${LIBDC_DIR}/include"
    -I"${LIBDC_DIR}/src"
    -I"${CONFIG_DIR}"
    -include "${CONFIG_DIR}/config.h"
    -DHAVE_CONFIG_H
)

# Add macOS SDK
SDKROOT=$(xcrun --show-sdk-path)
CFLAGS+=(-isysroot "${SDKROOT}")

echo "Building libdivecomputer for macOS..."

OBJECTS=()
for src in "${SOURCES[@]}"; do
    obj="${BUILD_DIR}/$(basename "${src}" .c).o"
    echo "  CC ${src}"
    xcrun clang "${CFLAGS[@]}" -c "${LIBDC_DIR}/src/${src}" -o "${obj}"
    OBJECTS+=("${obj}")
done

echo "  AR libdivecomputer.a"
xcrun ar rcs "${OUTPUT_LIB}" "${OBJECTS[@]}"

echo "libdivecomputer built successfully: ${OUTPUT_LIB}"
