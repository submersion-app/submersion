#!/usr/bin/env python3
"""
Extract harmonic tidal constituents from FES2014/FES2022 ocean tide models.

This script uses PyFES (CNES/AVISO) to extract harmonic constituent data
(amplitude and phase) at specified locations. The output is JSON files
that can be bundled with the Submersion app for offline tide calculations.

Requirements:
    conda install -c conda-forge pyfes

FES Model Setup:
    1. Download FES2014 or FES2022 data from AVISO
    2. Set environment variable FES_DATA to the data directory
    3. Or specify --config pointing to your FES configuration

Usage:
    # Extract for bundled dive sites
    python extract_fes_constituents.py --sites ../assets/data/dive_sites.json \
        --output ../assets/data/tide/

    # Extract for specific coordinates
    python extract_fes_constituents.py --lat 37.7749 --lon -122.4194 \
        --output tide_sf.json

    # Generate global grid
    python extract_fes_constituents.py --grid --resolution 0.25 \
        --output ../assets/data/tide/

Author: Submersion Team
License: MIT
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

import numpy as np

try:
    import pyfes
except ImportError:
    print("ERROR: pyfes not installed.")
    print("Install via conda: conda install -c conda-forge pyfes")
    print("See: https://github.com/CNES/aviso-fes")
    sys.exit(1)


# FES constituent names (matches the Dart constants file)
CONSTITUENTS = [
    'M2', 'S2', 'N2', 'K2', 'K1', 'O1', 'P1', 'Q1',
    '2N2', 'Mu2', 'Nu2', 'L2', 'T2', 'Eps2', 'La2', 'R2',
    '2Q1', 'Sig1', 'Rho1', 'M1', 'Chi1', 'Pi1', 'Phi1', 'The1',
    'J1', 'OO1', 'Mf', 'Mm', 'Ssa', 'Sa', 'Msqm', 'Mtm',
    'M4', 'MS4',
]

# Map pyfes constituent names to our naming convention
CONSTITUENT_NAME_MAP = {
    'Lambda2': 'La2',
    'Sigma1': 'Sig1',
    'Theta1': 'The1',
    'Epsilon2': 'Eps2',
}


def load_tidal_model(config_path: Optional[str] = None):
    """Load FES tidal model.

    Args:
        config_path: Path to FES configuration file. If None, uses default.

    Returns:
        Loaded tidal model dictionary
    """
    if config_path is None:
        # Try to find FES configuration (prefer FES2022, fall back to FES2014)
        fes_data = os.environ.get('FES_DATA', '/usr/local/share/fes')

        # Try FES2022 first, then FES2014
        for version in ['fes2022', 'fes2014']:
            candidate = Path(fes_data) / version / 'ocean_tide.yaml'
            if candidate.exists():
                config_path = str(candidate)
                break

        if config_path is None:
            raise FileNotFoundError(
                f"FES config not found in {fes_data}. "
                "Set FES_DATA environment variable or use --config"
            )

    # Load configuration - returns dict of tidal models
    models = pyfes.load_config(config_path)

    # Store config path for metadata
    models['_config_path'] = config_path

    return models


def extract_constituents(
    models: dict,
    latitude: float,
    longitude: float,
) -> dict:
    """Extract tidal constituents at a single location.

    Args:
        models: Loaded pyfes tidal models
        latitude: Latitude in degrees (-90 to 90)
        longitude: Longitude in degrees (-180 to 180)

    Returns:
        Dictionary of constituent name -> {amplitude, phase}
        Empty dict if location is on land
    """
    try:
        # Get the tide model (usually 'tide' key)
        tidal_model = models.get('tide') or models.get('ocean') or list(models.values())[0]

        # Interpolate to get complex constituent values
        lon_arr = np.array([longitude], dtype=np.float64)
        lat_arr = np.array([latitude], dtype=np.float64)

        result, quality = tidal_model.interpolate(lon_arr, lat_arr)

        # Check quality - 0 means undefined/land
        if quality[0] == 0:
            return {}

        constituents = {}
        for constituent, values in result.items():
            # Get the constituent name
            const_name = constituent.name

            # PyFES uses a 'k' prefix for constituent names (e.g., 'kM2' -> 'M2')
            if const_name.startswith('k'):
                const_name = const_name[1:]

            # Map to our naming convention
            const_name = CONSTITUENT_NAME_MAP.get(const_name, const_name)

            # Extract amplitude and phase from complex value
            complex_val = values[0]

            if np.isnan(complex_val):
                continue

            # Amplitude is the absolute value (convert from cm to meters)
            amplitude = abs(complex_val) / 100.0

            # Phase is the angle in degrees
            phase = np.degrees(np.angle(complex_val))
            if phase < 0:
                phase += 360.0

            constituents[const_name] = {
                'amplitude': round(float(amplitude), 4),
                'phase': round(float(phase), 2),
            }

        return constituents

    except Exception as e:
        print(f"Warning: Failed to extract at ({latitude}, {longitude}): {e}")
        return {}


def extract_for_sites(
    models: dict,
    sites_file: str,
    output_file: str,
) -> None:
    """Extract constituents for all sites in a dive sites JSON file.

    Args:
        models: Loaded pyfes tidal models
        sites_file: Path to dive_sites.json
        output_file: Output path for constituents JSON
    """
    with open(sites_file, 'r') as f:
        sites_data = json.load(f)

    results = []
    sites = sites_data if isinstance(sites_data, list) else sites_data.get('sites', [])

    total = len(sites)
    extracted = 0

    for i, site in enumerate(sites):
        site_id = site.get('id', f'site_{i}')
        lat = site.get('latitude')
        lon = site.get('longitude')

        if lat is None or lon is None:
            print(f"  Skipping {site_id}: no coordinates")
            continue

        constituents = extract_constituents(models, lat, lon)

        if constituents:
            results.append({
                'id': site_id,
                'name': site.get('name', site_id),
                'lat': lat,
                'lon': lon,
                'constituents': constituents,
            })
            extracted += 1

        if (i + 1) % 10 == 0:
            print(f"  Progress: {i + 1}/{total} sites processed, {extracted} extracted")

    model_version = get_model_version(models)
    output = {
        'version': '1.0',
        'source': model_version,
        'generated': datetime.now().isoformat()[:10],
        'sites': results,
    }

    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"Extracted constituents for {extracted}/{total} sites ({model_version}) -> {output_file}")


def generate_global_grid(
    models: dict,
    resolution: float,
    output_file: str,
    lat_min: float = -80.0,
    lat_max: float = 80.0,
    lon_min: float = -180.0,
    lon_max: float = 180.0,
) -> None:
    """Generate a global grid of tidal constituents.

    Args:
        models: Loaded pyfes tidal models
        resolution: Grid resolution in degrees
        output_file: Output path for grid JSON
        lat_min, lat_max, lon_min, lon_max: Grid bounds
    """
    lats = np.arange(lat_min, lat_max + resolution, resolution)
    lons = np.arange(lon_min, lon_max + resolution, resolution)

    total = len(lats) * len(lons)
    print(f"Generating {len(lats)}x{len(lons)} = {total} grid points at {resolution}° resolution")

    points = []
    processed = 0
    ocean_points = 0

    for lat in lats:
        for lon in lons:
            constituents = extract_constituents(models, float(lat), float(lon))

            if constituents:  # Only include ocean points
                points.append({
                    'lat': round(float(lat), 4),
                    'lon': round(float(lon), 4),
                    'constituents': constituents,
                })
                ocean_points += 1

            processed += 1
            if processed % 1000 == 0:
                print(f"  Progress: {processed}/{total} ({100*processed/total:.1f}%), "
                      f"{ocean_points} ocean points")

    model_version = get_model_version(models)
    output = {
        'version': '1.0',
        'source': model_version,
        'generated': datetime.now().isoformat()[:10],
        'grid': {
            'lat_min': lat_min,
            'lat_max': lat_max,
            'lon_min': lon_min,
            'lon_max': lon_max,
            'resolution': resolution,
        },
        'points': points,
    }

    with open(output_file, 'w') as f:
        json.dump(output, f)

    print(f"Generated grid with {ocean_points} ocean points ({model_version}) -> {output_file}")

    # Estimate file size
    file_size = Path(output_file).stat().st_size
    print(f"File size: {file_size / 1024 / 1024:.1f} MB")


def extract_single_location(
    models: dict,
    latitude: float,
    longitude: float,
    output_file: Optional[str] = None,
) -> dict:
    """Extract constituents for a single location.

    Args:
        models: Loaded pyfes tidal models
        latitude: Latitude in degrees
        longitude: Longitude in degrees
        output_file: Optional output file path

    Returns:
        Constituent dictionary
    """
    constituents = extract_constituents(models, latitude, longitude)

    if not constituents:
        print(f"Warning: No data at ({latitude}, {longitude}) - may be on land")
        return {}

    result = {
        'lat': latitude,
        'lon': longitude,
        'constituents': constituents,
    }

    if output_file:
        with open(output_file, 'w') as f:
            json.dump(result, indent=2, fp=f)
        print(f"Extracted {len(constituents)} constituents -> {output_file}")
    else:
        print(json.dumps(result, indent=2))

    return result


def get_model_version(models: dict) -> str:
    """Detect FES model version from config path."""
    config_path = models.get('_config_path', '')
    if 'fes2022' in config_path.lower():
        return 'FES2022'
    elif 'fes2014' in config_path.lower():
        return 'FES2014'
    return 'FES'


def generate_metadata(output_dir: str, model_version: str = 'FES2014') -> None:
    """Generate metadata.json file for the tide data directory.

    Args:
        output_dir: Directory to write metadata.json
        model_version: FES model version (FES2014 or FES2022)
    """
    metadata = {
        'version': '1.0',
        'model': model_version,
        'datum': 'MSL',
        'extraction_date': datetime.now().isoformat()[:10],
        'constituents': CONSTITUENTS,
        'description': f'Tidal harmonic constituents extracted from {model_version} ocean tide model',
        'source': 'CNES/LEGOS via PyFES',
        'license': f'{model_version} data is available under specific terms from AVISO',
    }

    output_file = Path(output_dir) / 'metadata.json'
    with open(output_file, 'w') as f:
        json.dump(metadata, f, indent=2)

    print(f"Generated metadata -> {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Extract FES tidal constituents for Submersion app',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # FES configuration
    parser.add_argument(
        '--config',
        help='Path to FES configuration YAML file',
    )

    # Extraction modes
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        '--sites',
        metavar='FILE',
        help='Extract for dive sites from JSON file',
    )
    mode_group.add_argument(
        '--grid',
        action='store_true',
        help='Generate global grid of constituents',
    )
    mode_group.add_argument(
        '--lat',
        type=float,
        help='Extract for single location (requires --lon)',
    )

    # Location options
    parser.add_argument(
        '--lon',
        type=float,
        help='Longitude for single location extraction',
    )

    # Grid options
    parser.add_argument(
        '--resolution',
        type=float,
        default=0.25,
        help='Grid resolution in degrees (default: 0.25)',
    )

    # Output
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Output file or directory',
    )

    # Metadata
    parser.add_argument(
        '--metadata',
        action='store_true',
        help='Generate metadata.json file',
    )

    args = parser.parse_args()

    # Validate arguments
    if args.lat is not None and args.lon is None:
        parser.error("--lat requires --lon")
    if args.lon is not None and args.lat is None:
        parser.error("--lon requires --lat")

    # Create output directory if needed
    output_path = Path(args.output)
    if args.sites or args.grid or args.metadata:
        if not output_path.suffix:  # Directory
            output_path.mkdir(parents=True, exist_ok=True)

    # Load FES models
    print("Loading FES model...")
    try:
        models = load_tidal_model(args.config)
        print(f"Loaded models: {list(models.keys())}")
    except Exception as e:
        print(f"ERROR: Failed to load FES model: {e}")
        sys.exit(1)

    # Execute extraction
    if args.sites:
        sites_output = output_path / 'constituents_sites.json' if output_path.is_dir() else output_path
        print(f"Extracting for sites from {args.sites}...")
        extract_for_sites(models, args.sites, str(sites_output))

    elif args.grid:
        grid_output = output_path / 'constituents_grid.json' if output_path.is_dir() else output_path
        print(f"Generating global grid at {args.resolution}° resolution...")
        generate_global_grid(models, args.resolution, str(grid_output))

    elif args.lat is not None:
        extract_single_location(
            models,
            args.lat,
            args.lon,
            str(output_path) if output_path.suffix else None,
        )

    else:
        parser.error("Specify --sites, --grid, or --lat/--lon")

    # Generate metadata if requested
    if args.metadata:
        meta_dir = str(output_path) if output_path.is_dir() else str(output_path.parent)
        model_version = get_model_version(models)
        generate_metadata(meta_dir, model_version)


if __name__ == '__main__':
    main()
