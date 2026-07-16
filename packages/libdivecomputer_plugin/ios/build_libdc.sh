#!/bin/bash
# Build libdivecomputer as a static library for iOS.
# Called from the podspec script_phase before Swift compilation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
LIBDC_DIR="${PLUGIN_DIR}/third_party/libdivecomputer"
CONFIG_DIR="${SCRIPT_DIR}/config"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_LIB="${BUILD_DIR}/libdivecomputer.a"

# Determine target architectures and platform from the Xcode build
# environment. These drive the compile below, but they are also the cache key:
# a static library built for one platform must never be reused for another. On
# Apple Silicon the device and the simulator are BOTH arm64, so architecture
# alone cannot tell them apart -- only the Mach-O platform tag does. Reusing an
# iphoneos .a for an iphonesimulator link (or vice versa) fails the linker with
# "building for iOS-simulator, but linking in object file built for iOS".
if [ -z "${ARCHS:-}" ]; then
    ARCHS="arm64"
fi
PLATFORM_NAME="${PLATFORM_NAME:-iphoneos}"

STAMP_FILE="${BUILD_DIR}/.built-for"
BUILD_STAMP="${PLATFORM_NAME} ${ARCHS}"

# Reuse the existing library only when it is still valid. Rebuild if either:
#   1. a libdivecomputer source/header/config is newer than the built .a, so an
#      applied patch (e.g. the Swift GPS exit fix in
#      shearwater_predator_parser.c) is recompiled rather than left stale; or
#   2. the existing .a was built for a different platform/arch than Xcode is
#      asking for now.
# flutter clean does not remove this pod-local build dir, so these checks are
# all that stand between a stale .a and a confusing link failure.
if [ -f "${OUTPUT_LIB}" ]; then
    rebuild_reason=""
    if [ -n "$(find "${LIBDC_DIR}/src" "${LIBDC_DIR}/include" "${CONFIG_DIR}" -newer "${OUTPUT_LIB}" -print -quit 2>/dev/null)" ]; then
        rebuild_reason="sources changed since it was built"
    elif [ ! -f "${STAMP_FILE}" ] || [ "$(cat "${STAMP_FILE}")" != "${BUILD_STAMP}" ]; then
        rebuild_reason="previous build targeted a different platform/arch (need [${BUILD_STAMP}])"
    fi

    if [ -n "${rebuild_reason}" ]; then
        echo "Rebuilding libdivecomputer.a: ${rebuild_reason}."
        # Purge the combined lib and the per-arch object trees so no object from
        # the previous platform can survive into the new archive.
        find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    else
        echo "libdivecomputer.a already built for [${BUILD_STAMP}], skipping."
        exit 0
    fi
fi

mkdir -p "${BUILD_DIR}"

# Source files from libdivecomputer (excluding serial_posix.c, irda.c, socket.c
# which require unavailable APIs on iOS)
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
    # hw_frog.c was merged into hw_ostc3.c upstream (frog/ostc3 integration).
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
    hdlc.c packet.c
    usb.c usbhid.c ble.c bluetooth.c custom.c
)

if [ "${PLATFORM_NAME}" = "iphonesimulator" ]; then
    SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
    MIN_VERSION="-mios-simulator-version-min=14.0"
else
    SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
    MIN_VERSION="-miphoneos-version-min=14.0"
fi

CFLAGS=(
    -O2
    -std=c11
    -isysroot "${SDKROOT}"
    ${MIN_VERSION}
    -I"${LIBDC_DIR}/include"
    -I"${LIBDC_DIR}/src"
    -I"${CONFIG_DIR}"
    -include "${CONFIG_DIR}/config.h"
    -DHAVE_CONFIG_H
    -fembed-bitcode
)

echo "Building libdivecomputer for iOS (architectures: ${ARCHS}, ${PLATFORM_NAME})..."

ARCH_LIBS=()
for arch in ${ARCHS}; do
    ARCH_BUILD_DIR="${BUILD_DIR}/${arch}"
    mkdir -p "${ARCH_BUILD_DIR}"

    ARCH_CFLAGS=("${CFLAGS[@]}" -arch "${arch}")

    OBJECTS=()
    for src in "${SOURCES[@]}"; do
        obj="${ARCH_BUILD_DIR}/$(basename "${src}" .c).o"
        xcrun clang "${ARCH_CFLAGS[@]}" -c "${LIBDC_DIR}/src/${src}" -o "${obj}"
        OBJECTS+=("${obj}")
    done

    ARCH_LIB="${ARCH_BUILD_DIR}/libdivecomputer.a"
    xcrun ar rcs "${ARCH_LIB}" "${OBJECTS[@]}"
    ARCH_LIBS+=("${ARCH_LIB}")
    echo "  Built for ${arch}"
done

# Combine architectures into a universal binary if multiple
if [ ${#ARCH_LIBS[@]} -eq 1 ]; then
    cp "${ARCH_LIBS[0]}" "${OUTPUT_LIB}"
else
    xcrun lipo -create "${ARCH_LIBS[@]}" -output "${OUTPUT_LIB}"
fi

# Record what this .a was built for, so the next invocation can detect a
# device<->simulator (or arch) switch and rebuild instead of handing the linker
# an incompatible archive.
printf '%s\n' "${BUILD_STAMP}" > "${STAMP_FILE}"

echo "libdivecomputer built successfully for [${BUILD_STAMP}]: ${OUTPUT_LIB}"
