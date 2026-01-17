# Tide Data Extraction Scripts

Scripts for extracting tidal harmonic constituents from FES (Finite Element Solution)
ocean tide models for use in Submersion's offline tide predictions.

## Overview

The Submersion app uses harmonic analysis for tide prediction. This requires
constituent data (amplitude and phase values) for each location. These scripts
extract that data from FES2014/FES2022 models using PyFES.

## Prerequisites

### 1. Install PyFES

PyFES is **not available on PyPI** - it must be installed via conda or built from source.

**Option A - Conda (Recommended):**
```bash
# Create a conda environment
conda create -n tide python=3.11
conda activate tide

# Install PyFES from conda-forge
conda install -c conda-forge pyfes

# Install remaining dependencies
pip install numpy
```

**Option B - Build from Source:**
```bash
git clone https://github.com/CNES/aviso-fes.git
cd aviso-fes
pip install .
pip install numpy
```

### 2. Obtain FES Model Data

FES2014 or FES2022 data is available from AVISO (free registration required):
https://www.aviso.altimetry.fr/en/data/products/auxiliary-products/global-tide-fes.html

**FES2022 is recommended** - it's the newer model with improved accuracy.

Download the ocean tide files and extract to a directory, e.g.:
```
/usr/local/share/fes/fes2022/   # preferred
/usr/local/share/fes/fes2014/   # also supported
├── ocean_tide.yaml
├── 2N2.nc
├── K1.nc
├── K2.nc
├── M2.nc
├── ...
```

### 3. Configure FES Data Path

Set the environment variable:
```bash
export FES_DATA=/usr/local/share/fes
```

Or specify the config file directly with `--config`.

## Usage

### Extract for Bundled Dive Sites

```bash
python extract_fes_constituents.py \
    --sites ../../assets/data/dive_sites.json \
    --output ../../assets/data/tide/ \
    --metadata
```

This creates:
- `constituents_sites.json` - Constituents for each dive site with coordinates
- `metadata.json` - Model information and constituent list

### Extract for Single Location

```bash
# San Francisco Bay
python extract_fes_constituents.py --lat 37.7749 --lon -122.4194 -o tide_sf.json

# Great Barrier Reef
python extract_fes_constituents.py --lat -16.2864 --lon 145.6845 -o tide_gbr.json
```

### Generate Global Grid

For interpolation at any location:

```bash
# 0.25-degree resolution (recommended - ~50-100 MB)
python extract_fes_constituents.py --grid --resolution 0.25 \
    --output ../../assets/data/tide/constituents_grid.json

# 0.5-degree resolution (smaller - ~15 MB)
python extract_fes_constituents.py --grid --resolution 0.5 \
    --output ../../assets/data/tide/constituents_grid.json
```

## Output Format

### constituents_sites.json

```json
{
  "version": "1.0",
  "source": "FES2014",
  "generated": "2025-01-16",
  "sites": [
    {
      "id": "great-blue-hole",
      "name": "Great Blue Hole",
      "lat": 17.3156,
      "lon": -87.5347,
      "constituents": {
        "M2": {"amplitude": 0.112, "phase": 234.5},
        "S2": {"amplitude": 0.045, "phase": 267.8},
        ...
      }
    }
  ]
}
```

### constituents_grid.json

```json
{
  "version": "1.0",
  "source": "FES2014",
  "generated": "2025-01-16",
  "grid": {
    "lat_min": -80.0,
    "lat_max": 80.0,
    "lon_min": -180.0,
    "lon_max": 180.0,
    "resolution": 0.25
  },
  "points": [
    {
      "lat": -80.0,
      "lon": -180.0,
      "constituents": {
        "M2": {"amplitude": 0.523, "phase": 127.4},
        ...
      }
    }
  ]
}
```

## Constituent List

The extraction includes 34 constituents matching the Dart implementation:

**Semi-diurnal (period ~12 hours):**
M2, S2, N2, K2, 2N2, Mu2, Nu2, L2, T2, Eps2, La2, R2

**Diurnal (period ~24 hours):**
K1, O1, P1, Q1, 2Q1, Sig1, Rho1, M1, Chi1, Pi1, Phi1, The1, J1, OO1

**Long-period:**
Mf, Mm, Ssa, Sa, Msqm, Mtm

**Shallow-water:**
M4, MS4

## Troubleshooting

### "No matching distribution found for pyfes"
PyFES is NOT on PyPI. Use conda: `conda install -c conda-forge pyfes`

### "pyfes not installed"
See installation instructions above. Conda is the recommended method.

### "FES config not found"
Set `FES_DATA` environment variable or use `--config` to point to your FES installation.

### "No data at location"
The location may be on land. FES only covers ocean areas.

### Large grid file size
Use coarser resolution (0.5° instead of 0.25°) or compress with gzip.

## References

- [PyFES Documentation](https://pyfes.readthedocs.io/)
- [FES2014 Model](https://www.aviso.altimetry.fr/en/data/products/auxiliary-products/global-tide-fes/description-fes2014.html)
- [CNES/LEGOS](https://www.legos.omp.eu/)
