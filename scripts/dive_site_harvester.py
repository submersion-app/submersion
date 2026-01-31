#!/usr/bin/env python3
"""
OSM Dive Site Harvester

Scrapes all scuba diving site data from OpenStreetMap using the Overpass API.
Outputs to a JSON file compatible with Submersion app's dive site import format.

Usage:
    python scripts/divesiteharvester.py

Output files are written to assets/data/:
    - dive_sites.json: Dive site locations
    - dive_centers.json: Dive shops, clubs, and centers
"""

import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import overpy
import requests
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)
from tqdm import tqdm

# Path configuration - resolve relative to project root
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
OUTPUT_DIR = PROJECT_ROOT / "assets" / "data"
CHECKPOINT_FILE = SCRIPT_DIR / ".divesiteharvester_checkpoint.json"

# Overpass API configuration
OVERPASS_ENDPOINT = "https://overpass-api.de/api/interpreter"
QUERY_TIMEOUT = 300  # seconds
MIN_REQUEST_INTERVAL = 10.0  # seconds between Overpass requests
MAX_RETRIES = 5
CHUNK_SIZE_DEGREES = 10

# Output format: 'submersion' for Submersion app, 'raw' for original format
OUTPUT_FORMAT = "submersion"

# Reverse geocoding configuration
ENABLE_REVERSE_GEOCODING = True
NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/reverse"
NOMINATIM_USER_AGENT = "DiveSiteHarvester/1.0 (Submersion Dive Log App)"
NOMINATIM_MIN_INTERVAL = 1.1  # Nominatim requires max 1 request/second

# OSM tags to query for dive sites
DIVE_TAGS = [
    ("sport", "scuba_diving"),
    ("amenity", "dive_centre"),
    ("shop", "scuba_diving"),
    ("club", "scuba_diving"),
]

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


class ReverseGeocoder:
    """Reverse geocoder using OpenStreetMap Nominatim API with caching."""

    def __init__(self):
        self.cache: dict[tuple[float, float], dict] = {}
        self.last_request_time: float | None = None
        self.stats = {"hits": 0, "misses": 0, "errors": 0}

    def _rate_limit(self):
        """Enforce Nominatim's rate limit (max 1 request/second)."""
        if self.last_request_time:
            elapsed = time.time() - self.last_request_time
            if elapsed < NOMINATIM_MIN_INTERVAL:
                time.sleep(NOMINATIM_MIN_INTERVAL - elapsed)
        self.last_request_time = time.time()

    def _round_coords(self, lat: float, lon: float) -> tuple[float, float]:
        """Round coordinates to reduce cache misses for nearby points."""
        # Round to ~1km precision (0.01 degrees ≈ 1.1km at equator)
        return (round(lat, 2), round(lon, 2))

    def lookup(self, latitude: float, longitude: float) -> dict:
        """Look up country and region for coordinates.

        Returns dict with keys: country, region, locality (any may be None)
        """
        if not ENABLE_REVERSE_GEOCODING:
            return {"country": None, "region": None, "locality": None}

        # Check cache first
        cache_key = self._round_coords(latitude, longitude)
        if cache_key in self.cache:
            self.stats["hits"] += 1
            return self.cache[cache_key]

        self.stats["misses"] += 1

        # Rate limit before API call
        self._rate_limit()

        try:
            response = requests.get(
                NOMINATIM_ENDPOINT,
                params={
                    "format": "json",
                    "lat": latitude,
                    "lon": longitude,
                    "zoom": 10,
                },
                headers={"User-Agent": NOMINATIM_USER_AGENT},
                timeout=10,
            )

            if response.status_code == 200:
                data = response.json()
                address = data.get("address", {})

                result = {
                    "country": address.get("country"),
                    "region": (
                        address.get("state")
                        or address.get("province")
                        or address.get("region")
                    ),
                    "locality": (
                        address.get("city")
                        or address.get("town")
                        or address.get("village")
                        or address.get("county")
                    ),
                }

                # Cache the result
                self.cache[cache_key] = result
                return result
            else:
                logger.warning(
                    f"Nominatim returned {response.status_code} for {latitude}, {longitude}"
                )

        except requests.RequestException as e:
            logger.warning(f"Reverse geocoding failed for {latitude}, {longitude}: {e}")
            self.stats["errors"] += 1

        # Return empty result on failure
        empty_result = {"country": None, "region": None, "locality": None}
        self.cache[cache_key] = empty_result
        return empty_result

    def log_stats(self):
        """Log cache statistics."""
        total = self.stats["hits"] + self.stats["misses"]
        if total > 0:
            hit_rate = self.stats["hits"] / total * 100
            logger.info(
                f"Geocoding stats: {self.stats['hits']} cache hits, "
                f"{self.stats['misses']} API calls, "
                f"{self.stats['errors']} errors ({hit_rate:.1f}% hit rate)"
            )


# Global geocoder instance
geocoder = ReverseGeocoder()


def generate_chunks() -> list[tuple[float, float, float, float]]:
    """Generate worldwide bounding box chunks."""
    chunks = []
    for lat in range(-90, 90, CHUNK_SIZE_DEGREES):
        for lon in range(-180, 180, CHUNK_SIZE_DEGREES):
            bbox = (lat, lon, lat + CHUNK_SIZE_DEGREES, lon + CHUNK_SIZE_DEGREES)
            chunks.append(bbox)
    return chunks


def build_query(bbox: tuple[float, float, float, float]) -> str:
    """Build Overpass QL query for dive sites in a bounding box."""
    south, west, north, east = bbox
    bbox_str = f"{south},{west},{north},{east}"

    tag_queries = []
    for key, value in DIVE_TAGS:
        tag_queries.append(f'  nwr["{key}"="{value}"]({bbox_str});')

    return f"""[out:json][timeout:{QUERY_TIMEOUT}];
(
{chr(10).join(tag_queries)}
);
out body geom;
"""


def extract_geometry(element: Any, osm_type: str) -> dict | None:
    """Convert OSM element to GeoJSON geometry."""
    if osm_type == "node":
        return {
            "type": "Point",
            "coordinates": [float(element.lon), float(element.lat)],
        }
    elif osm_type == "way":
        coords = None
        if hasattr(element, "geometry") and element.geometry:
            coords = [[float(n.lon), float(n.lat)] for n in element.geometry]
        else:
            # Fallback to nodes - may fail if nodes weren't fully resolved
            try:
                if hasattr(element, "nodes") and element.nodes:
                    coords = [[float(n.lon), float(n.lat)] for n in element.nodes]
            except overpy.exception.DataIncomplete:
                pass

        if coords is None:
            return None

        if len(coords) >= 4 and coords[0] == coords[-1]:
            return {"type": "Polygon", "coordinates": [coords]}
        return {"type": "LineString", "coordinates": coords}
    elif osm_type == "relation":
        # For relations, try to get center point
        if (
            hasattr(element, "center_lat")
            and hasattr(element, "center_lon")
            and element.center_lat is not None
            and element.center_lon is not None
        ):
            return {
                "type": "Point",
                "coordinates": [float(element.center_lon), float(element.center_lat)],
            }
    return None


def extract_address(tags: dict) -> dict:
    """Extract address fields from tags."""
    return {
        k: v
        for k, v in {
            "street": tags.get("addr:street"),
            "housenumber": tags.get("addr:housenumber"),
            "city": tags.get("addr:city"),
            "state": tags.get("addr:state"),
            "postcode": tags.get("addr:postcode"),
            "country": tags.get("addr:country"),
        }.items()
        if v is not None
    }


def extract_contact(tags: dict) -> dict:
    """Extract contact information from tags."""
    return {
        k: v
        for k, v in {
            "phone": tags.get("phone") or tags.get("contact:phone"),
            "email": tags.get("email") or tags.get("contact:email"),
            "website": tags.get("website") or tags.get("contact:website"),
        }.items()
        if v is not None
    }


def extract_dive_attributes(tags: dict) -> dict:
    """Extract scuba diving specific attributes from tags."""
    site_types = []
    for key in tags:
        if key.startswith("scuba_diving:type:"):
            type_name = key.split(":")[-1]
            if tags[key] in ("yes", "true", "1"):
                site_types.append(type_name)

    attrs = {}
    if tags.get("scuba_diving:depth"):
        attrs["depth"] = tags["scuba_diving:depth"]
    if tags.get("scuba_diving:maxdepth"):
        attrs["max_depth"] = tags["scuba_diving:maxdepth"]
    if tags.get("scuba_diving:entry"):
        attrs["entry_type"] = tags["scuba_diving:entry"]
    if tags.get("scuba_diving:hazard"):
        attrs["hazards"] = tags["scuba_diving:hazard"]
    if tags.get("scuba_diving:drift") in ("yes", "true", "1"):
        attrs["drift_diving"] = True
    if tags.get("scuba_diving:divespot"):
        attrs["divespot"] = tags["scuba_diving:divespot"]
    if site_types:
        attrs["site_types"] = site_types

    return attrs


def parse_depth_value(depth_str: str | None) -> float | None:
    """Parse a depth string (e.g., '30m', '100 ft', '25') to meters."""
    if not depth_str:
        return None

    # Remove whitespace and convert to lowercase
    depth_str = depth_str.strip().lower()

    # Try to extract numeric value and unit
    match = re.match(r"([\d.]+)\s*(m|meters?|ft|feet)?", depth_str)
    if not match:
        return None

    try:
        value = float(match.group(1))
        unit = match.group(2) or "m"

        # Convert feet to meters
        if unit in ("ft", "feet"):
            value = value * 0.3048

        return round(value, 1)
    except ValueError:
        return None


def categorize_osm_entry(osm_site: dict) -> str:
    """Categorize an OSM entry as 'dive_site' or 'dive_center'.

    Categories:
    - dive_site: Actual diving locations (sport=scuba_diving)
    - dive_center: Businesses/organizations (amenity=dive_centre, shop, club)
    """
    tags = osm_site.get("tags", {})

    # Check for business/organization tags first (more specific)
    if tags.get("amenity") == "dive_centre":
        return "dive_center"
    if tags.get("shop") == "scuba_diving":
        return "dive_center"
    if tags.get("club") == "scuba_diving":
        return "dive_center"

    # Default to dive site (sport=scuba_diving)
    return "dive_site"


def extract_coordinates(geometry: dict | None) -> tuple[float | None, float | None]:
    """Extract latitude and longitude from geometry."""
    if not geometry:
        return None, None

    if geometry["type"] == "Point":
        # GeoJSON uses [longitude, latitude]
        longitude, latitude = geometry["coordinates"]
        return round(latitude, 6), round(longitude, 6)
    elif geometry["type"] in ("Polygon", "LineString"):
        # Use centroid of first coordinate for polygons/lines
        coords = geometry["coordinates"]
        if geometry["type"] == "Polygon":
            coords = coords[0]  # Outer ring
        if coords:
            avg_lon = sum(c[0] for c in coords) / len(coords)
            avg_lat = sum(c[1] for c in coords) / len(coords)
            return round(avg_lat, 6), round(avg_lon, 6)

    return None, None


def transform_to_dive_center_format(osm_site: dict) -> dict:
    """Transform an OSM entry to Submersion's dive_centers.json format.

    Submersion DiveCenters schema:
    {
        "id": string,
        "name": string,
        "location": string (address/description),
        "latitude": number,
        "longitude": number,
        "country": string,
        "phone": string,
        "email": string,
        "website": string,
        "affiliations": string (comma-separated: PADI, SSI, etc.),
        "type": string (center, shop, club)
    }
    """
    tags = osm_site.get("tags", {})
    geometry = osm_site.get("geometry")
    address = osm_site.get("address", {})
    contact = osm_site.get("contact", {})

    # Build unique ID
    center_id = f"osm_{osm_site['osm_type']}_{osm_site['osm_id']}"

    # Extract name
    name = (
        tags.get("name")
        or tags.get("name:en")
        or tags.get("operator")
        or f"Dive Center {osm_site['osm_id']}"
    )

    # Extract coordinates
    latitude, longitude = extract_coordinates(geometry)

    # Build location string from address
    location_parts = []
    if address.get("housenumber") and address.get("street"):
        location_parts.append(f"{address['housenumber']} {address['street']}")
    elif address.get("street"):
        location_parts.append(address["street"])
    if address.get("city"):
        location_parts.append(address["city"])
    if address.get("state"):
        location_parts.append(address["state"])
    if address.get("postcode"):
        location_parts.append(address["postcode"])
    location = ", ".join(location_parts) if location_parts else None

    # Determine center type
    center_type = "center"
    if tags.get("shop") == "scuba_diving":
        center_type = "shop"
    elif tags.get("club") == "scuba_diving":
        center_type = "club"

    # Extract affiliations (diving agencies)
    affiliations = []
    # Check for common affiliation tags
    for agency in ["PADI", "SSI", "NAUI", "BSAC", "CMAS", "SDI", "TDI", "GUE", "IANTD"]:
        agency_lower = agency.lower()
        if tags.get(f"scuba_diving:{agency_lower}") in ("yes", "true", "1"):
            affiliations.append(agency)
        if tags.get(f"diving:{agency_lower}") in ("yes", "true", "1"):
            affiliations.append(agency)
    # Also check operator tag for agency names
    operator = tags.get("operator", "")
    for agency in ["PADI", "SSI", "NAUI", "BSAC", "CMAS"]:
        if agency in operator.upper():
            if agency not in affiliations:
                affiliations.append(agency)

    # Build the center record
    center = {
        "id": center_id,
        "name": name,
        "type": center_type,
    }

    # Add optional fields
    if location:
        center["location"] = location
    if latitude is not None:
        center["latitude"] = latitude
    if longitude is not None:
        center["longitude"] = longitude

    # Country - use reverse geocoding if missing but coords available
    country = address.get("country")
    if not country and latitude is not None and longitude is not None:
        geo_result = geocoder.lookup(latitude, longitude)
        country = geo_result.get("country")
        # Also fill location if missing
        if not location:
            locality = geo_result.get("locality")
            region = geo_result.get("region")
            if locality and region:
                center["location"] = f"{locality}, {region}"
            elif locality or region:
                center["location"] = locality or region

    if country:
        center["country"] = country
    if contact.get("phone"):
        center["phone"] = contact["phone"]
    if contact.get("email"):
        center["email"] = contact["email"]
    if contact.get("website"):
        center["website"] = contact["website"]
    if affiliations:
        center["affiliations"] = ", ".join(affiliations)

    return center


def transform_to_submersion_format(osm_site: dict) -> dict:
    """Transform an OSM site record to Submersion's dive_sites.json format.

    Submersion expects:
    {
        "id": string (unique identifier),
        "name": string,
        "description": string (optional),
        "latitude": number (optional),
        "longitude": number (optional),
        "max_depth": number in meters (optional),
        "min_depth": number in meters (optional),
        "country": string (optional),
        "region": string (optional),
        "ocean": string (optional),
        "hazards": string (optional),
        "entry_type": string (optional),
        "website": string (optional),
        "features": list of strings (optional)
    }
    """
    tags = osm_site.get("tags", {})
    geometry = osm_site.get("geometry")
    address = osm_site.get("address", {})
    contact = osm_site.get("contact", {})
    dive_attrs = osm_site.get("dive_attributes", {})

    # Build unique ID from OSM type and ID
    site_id = f"osm_{osm_site['osm_type']}_{osm_site['osm_id']}"

    # Extract name (required) - fall back to description or ID
    name = (
        tags.get("name")
        or tags.get("name:en")
        or tags.get("description")
        or f"Dive Site {osm_site['osm_id']}"
    )

    # Extract coordinates
    latitude, longitude = extract_coordinates(geometry)

    # Build region from city/state
    region_parts = []
    if address.get("city"):
        region_parts.append(address["city"])
    if address.get("state"):
        region_parts.append(address["state"])
    region = ", ".join(region_parts) if region_parts else None

    # Build description from various sources
    description_parts = []
    if tags.get("description"):
        description_parts.append(tags["description"])
    if tags.get("note"):
        description_parts.append(tags["note"])
    description = "\n\n".join(description_parts) if description_parts else None

    # Collect features (site types, dive types, etc.)
    features = []
    if dive_attrs.get("site_types"):
        features.extend(dive_attrs["site_types"])
    if dive_attrs.get("drift_diving"):
        features.append("drift")

    # Build the Submersion-compatible site record
    site = {
        "id": site_id,
        "name": name,
    }

    # Add optional fields only if they have values
    if description:
        site["description"] = description
    if latitude is not None:
        site["latitude"] = latitude
    if longitude is not None:
        site["longitude"] = longitude

    # Depth fields
    max_depth = parse_depth_value(dive_attrs.get("max_depth"))
    min_depth = parse_depth_value(dive_attrs.get("depth"))
    if max_depth:
        site["max_depth"] = max_depth
    if min_depth:
        site["min_depth"] = min_depth

    # Location fields - use reverse geocoding if missing but coords available
    country = address.get("country")
    if not country and latitude is not None and longitude is not None:
        geo_result = geocoder.lookup(latitude, longitude)
        country = geo_result.get("country")
        if not region:
            region = geo_result.get("region") or geo_result.get("locality")

    if country:
        site["country"] = country
    if region:
        site["region"] = region

    # Dive-specific fields
    if dive_attrs.get("hazards"):
        site["hazards"] = dive_attrs["hazards"]
    if dive_attrs.get("entry_type"):
        site["entry_type"] = dive_attrs["entry_type"]

    # Contact info
    if contact.get("website"):
        site["website"] = contact["website"]

    # Features list
    if features:
        site["features"] = features

    return site


def process_element(element: Any, osm_type: str) -> dict:
    """Process a single OSM element into output format."""
    tags = dict(element.tags)
    geometry = extract_geometry(element, osm_type)

    result = {
        "osm_id": element.id,
        "osm_type": osm_type,
        "tags": tags,
    }

    if geometry:
        result["geometry"] = geometry

    address = extract_address(tags)
    if address:
        result["address"] = address

    contact = extract_contact(tags)
    if contact:
        result["contact"] = contact

    dive_attrs = extract_dive_attributes(tags)
    if dive_attrs:
        result["dive_attributes"] = dive_attrs

    return result


def process_results(result: overpy.Result) -> list[dict]:
    """Transform Overpass results to output format."""
    sites = []

    for node in result.nodes:
        sites.append(process_element(node, "node"))

    for way in result.ways:
        sites.append(process_element(way, "way"))

    for relation in result.relations:
        sites.append(process_element(relation, "relation"))

    return sites


class DiveSiteHarvester:
    """Main harvester class with checkpointing and rate limiting."""

    def __init__(self):
        self.api = overpy.Overpass(url=OVERPASS_ENDPOINT)
        self.last_request_time: float | None = None
        self.all_sites: list[dict] = []
        self.seen_ids: set[tuple[str, int]] = set()  # (osm_type, osm_id)
        self.completed_chunks: set[tuple] = set()

        # Create output directory if needed
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

        # Load checkpoint if exists
        self._load_checkpoint()

    def _load_checkpoint(self):
        """Load previously completed chunks from checkpoint file."""
        if CHECKPOINT_FILE.exists():
            try:
                with open(CHECKPOINT_FILE) as f:
                    data = json.load(f)
                    self.completed_chunks = set(tuple(c) for c in data.get("chunks", []))
                    self.seen_ids = set(
                        tuple(x) for x in data.get("seen_ids", [])
                    )
                    self.all_sites = data.get("sites", [])
                    logger.info(
                        f"Loaded checkpoint: {len(self.completed_chunks)} chunks, "
                        f"{len(self.all_sites)} sites"
                    )
            except (json.JSONDecodeError, KeyError) as e:
                logger.warning(f"Could not load checkpoint: {e}")

    def _save_checkpoint(self):
        """Save current progress to checkpoint file."""
        with open(CHECKPOINT_FILE, "w") as f:
            json.dump(
                {
                    "chunks": list(self.completed_chunks),
                    "seen_ids": list(self.seen_ids),
                    "sites": self.all_sites,
                },
                f,
            )

    def _rate_limit(self):
        """Enforce minimum delay between API requests."""
        if self.last_request_time:
            elapsed = time.time() - self.last_request_time
            if elapsed < MIN_REQUEST_INTERVAL:
                sleep_time = MIN_REQUEST_INTERVAL - elapsed
                time.sleep(sleep_time)
        self.last_request_time = time.time()

    @retry(
        stop=stop_after_attempt(MAX_RETRIES),
        wait=wait_exponential(multiplier=2, min=10, max=300),
        retry=retry_if_exception_type(
            (
                overpy.exception.OverpassTooManyRequests,
                overpy.exception.OverpassGatewayTimeout,
                ConnectionError,
                TimeoutError,
            )
        ),
        before_sleep=lambda retry_state: logger.warning(
            f"Retry {retry_state.attempt_number}/{MAX_RETRIES} after error"
        ),
    )
    def _query(self, query_string: str) -> overpy.Result:
        """Execute Overpass query with rate limiting and retry."""
        self._rate_limit()
        return self.api.query(query_string)

    def _process_chunk(self, bbox: tuple) -> int:
        """Process a single geographic chunk. Returns count of new sites."""
        query = build_query(bbox)

        try:
            result = self._query(query)
        except overpy.exception.OverpassBadRequest as e:
            logger.error(f"Bad request for chunk {bbox}: {e}")
            return 0
        except Exception as e:
            logger.error(f"Failed to query chunk {bbox}: {e}")
            return 0

        sites = process_results(result)
        new_count = 0

        for site in sites:
            site_key = (site["osm_type"], site["osm_id"])
            if site_key not in self.seen_ids:
                self.seen_ids.add(site_key)
                self.all_sites.append(site)
                new_count += 1

        return new_count

    def harvest(self):
        """Main harvest loop."""
        chunks = generate_chunks()
        remaining_chunks = [c for c in chunks if c not in self.completed_chunks]

        logger.info(
            f"Starting harvest: {len(remaining_chunks)} chunks remaining "
            f"({len(self.completed_chunks)} already completed)"
        )

        try:
            for chunk in tqdm(remaining_chunks, desc="Harvesting dive sites"):
                new_sites = self._process_chunk(chunk)
                self.completed_chunks.add(chunk)

                if new_sites > 0:
                    logger.info(
                        f"Chunk {chunk}: {new_sites} new sites "
                        f"(total: {len(self.all_sites)})"
                    )

                # Save checkpoint periodically
                if len(self.completed_chunks) % 10 == 0:
                    self._save_checkpoint()

        except KeyboardInterrupt:
            logger.info("Interrupted by user, saving checkpoint...")
            self._save_checkpoint()
            raise

        # Final checkpoint save
        self._save_checkpoint()

        # Write final output
        self._write_output()

    def _write_output(self):
        """Write final JSON output file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        if OUTPUT_FORMAT == "submersion":
            self._write_submersion_output(timestamp)
        else:
            self._write_raw_output(timestamp)

        # Clean up checkpoint after successful completion
        if CHECKPOINT_FILE.exists():
            CHECKPOINT_FILE.unlink()
            logger.info("Checkpoint file removed after successful completion")

    def _write_submersion_output(self, timestamp: str):
        """Write output in Submersion app format as separate files."""
        # Categorize all entries
        dive_sites_raw = []
        dive_centers_raw = []

        for site in self.all_sites:
            category = categorize_osm_entry(site)
            if category == "dive_site":
                dive_sites_raw.append(site)
            else:
                dive_centers_raw.append(site)

        # Transform dive sites
        dive_sites = [
            transform_to_submersion_format(site) for site in dive_sites_raw
        ]
        # Filter out unnamed sites
        named_sites = [
            s for s in dive_sites
            if not s["name"].startswith("Dive Site ")
        ]

        # Transform dive centers
        dive_centers = [
            transform_to_dive_center_format(center) for center in dive_centers_raw
        ]
        # Filter out unnamed centers
        named_centers = [
            c for c in dive_centers
            if not c["name"].startswith("Dive Center ")
        ]

        # Write dive_sites.json
        sites_output = {
            "sites": named_sites,
            "metadata": {
                "generated_at": datetime.now(timezone.utc).isoformat() + "Z",
                "source": "OpenStreetMap via Overpass API",
                "total_count": len(named_sites),
                "query_tags": ["sport=scuba_diving"],
            },
        }

        sites_file = OUTPUT_DIR / f"dive_sites_{timestamp}.json"
        with open(sites_file, "w", encoding="utf-8") as f:
            json.dump(sites_output, f, indent=2, ensure_ascii=False)

        direct_sites_file = OUTPUT_DIR / "dive_sites.json"
        with open(direct_sites_file, "w", encoding="utf-8") as f:
            json.dump(sites_output, f, indent=2, ensure_ascii=False)

        # Write dive_centers.json
        centers_output = {
            "centers": named_centers,
            "metadata": {
                "generated_at": datetime.now(timezone.utc).isoformat() + "Z",
                "source": "OpenStreetMap via Overpass API",
                "total_count": len(named_centers),
                "query_tags": [
                    "amenity=dive_centre",
                    "shop=scuba_diving",
                    "club=scuba_diving",
                ],
            },
        }

        centers_file = OUTPUT_DIR / f"dive_centers_{timestamp}.json"
        with open(centers_file, "w", encoding="utf-8") as f:
            json.dump(centers_output, f, indent=2, ensure_ascii=False)

        direct_centers_file = OUTPUT_DIR / "dive_centers.json"
        with open(direct_centers_file, "w", encoding="utf-8") as f:
            json.dump(centers_output, f, indent=2, ensure_ascii=False)

        # Log summary
        logger.info(f"Dive sites written to {direct_sites_file}")
        logger.info(f"Dive centers written to {direct_centers_file}")
        logger.info(
            f"Summary: {len(self.all_sites)} total entries -> "
            f"{len(named_sites)} dive sites, {len(named_centers)} dive centers"
        )

        # Log geocoding stats
        geocoder.log_stats()

    def _write_raw_output(self, timestamp: str):
        """Write output in original raw OSM format."""
        output = {
            "metadata": {
                "generated_at": datetime.now(timezone.utc).isoformat() + "Z",
                "total_count": len(self.all_sites),
                "query_tags": [f"{k}={v}" for k, v in DIVE_TAGS],
            },
            "dive_sites": self.all_sites,
        }

        output_file = OUTPUT_DIR / f"dive_sites_raw_{timestamp}.json"
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)

        logger.info(f"Raw format output written to {output_file}")
        logger.info(f"Total dive sites harvested: {len(self.all_sites)}")


def main():
    """Entry point."""
    logger.info("OSM Dive Site Harvester")
    logger.info(f"Output directory: {OUTPUT_DIR}")
    logger.info(f"Querying tags: {', '.join(f'{k}={v}' for k, v in DIVE_TAGS)}")

    harvester = DiveSiteHarvester()
    harvester.harvest()


if __name__ == "__main__":
    main()
