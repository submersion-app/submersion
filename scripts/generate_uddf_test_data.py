#!/usr/bin/env python3
"""
Generate realistic UDDF 3.2.1 compliant test data with multi-tank AI pressure support.

This script creates a comprehensive UDDF file conforming to UDDF 3.2.1 specification:
https://www.streit.cc/extern/uddf_v321/

UDDF Units:
- Pressure: Pascal (Pa) - 1 bar = 100000 Pa
- Temperature: Kelvin (K) - Celsius + 273.15
- Depth: Meters (m)
- Time: Seconds (s)
- Volume: Cubic meters (m³) for tanks, but liters commonly used

Features:
- 500 dives with realistic depth/temperature profiles
- Real dive sites with GPS coordinates
- Dive centers/operators with addresses
- 50 buddies
- Full equipment set
- Multiple tank configurations with per-tank pressure data (AI transmitters)
- Proper tankpressure ref attributes for multi-tank support
"""

import random
import math
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import xml.etree.ElementTree as ET
from xml.dom import minidom

# UDDF namespace
UDDF_NS = "http://www.streit.cc/uddf/3.2"
SUBMERSION_NS = "http://submersion.app/uddf/extensions"

# Real dive sites with coordinates
DIVE_SITES = [
    # Caribbean
    {"name": "Blue Hole", "country": "Belize", "region": "Lighthouse Reef", "lat": 17.3156, "lon": -87.5347, "max_depth": 124, "water_type": "saltwater"},
    {"name": "Palancar Gardens", "country": "Mexico", "region": "Cozumel", "lat": 20.3579, "lon": -87.0386, "max_depth": 25, "water_type": "saltwater"},
    {"name": "Santa Rosa Wall", "country": "Mexico", "region": "Cozumel", "lat": 20.3283, "lon": -87.0489, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Columbia Deep", "country": "Mexico", "region": "Cozumel", "lat": 20.3000, "lon": -87.0500, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Paso del Cedral", "country": "Mexico", "region": "Cozumel", "lat": 20.3500, "lon": -87.0167, "max_depth": 18, "water_type": "saltwater"},
    {"name": "Stingray City", "country": "Cayman Islands", "region": "Grand Cayman", "lat": 19.3833, "lon": -81.2833, "max_depth": 4, "water_type": "saltwater"},
    {"name": "Bloody Bay Wall", "country": "Cayman Islands", "region": "Little Cayman", "lat": 19.6833, "lon": -80.0667, "max_depth": 300, "water_type": "saltwater"},
    {"name": "USS Kittiwake", "country": "Cayman Islands", "region": "Grand Cayman", "lat": 19.3647, "lon": -81.4011, "max_depth": 20, "water_type": "saltwater"},
    {"name": "1000 Steps", "country": "Bonaire", "region": "Kralendijk", "lat": 12.2167, "lon": -68.3500, "max_depth": 30, "water_type": "saltwater"},
    {"name": "Salt Pier", "country": "Bonaire", "region": "Kralendijk", "lat": 12.0833, "lon": -68.2833, "max_depth": 18, "water_type": "saltwater"},

    # Red Sea
    {"name": "SS Thistlegorm", "country": "Egypt", "region": "Sharm el-Sheikh", "lat": 27.8142, "lon": 33.9208, "max_depth": 32, "water_type": "saltwater"},
    {"name": "Ras Mohammed", "country": "Egypt", "region": "Sharm el-Sheikh", "lat": 27.7333, "lon": 34.2500, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Jackson Reef", "country": "Egypt", "region": "Strait of Tiran", "lat": 27.9667, "lon": 34.4667, "max_depth": 50, "water_type": "saltwater"},
    {"name": "Blue Hole Dahab", "country": "Egypt", "region": "Dahab", "lat": 28.5722, "lon": 34.5386, "max_depth": 130, "water_type": "saltwater"},
    {"name": "Elphinstone Reef", "country": "Egypt", "region": "Marsa Alam", "lat": 25.3167, "lon": 34.8667, "max_depth": 60, "water_type": "saltwater"},

    # Southeast Asia
    {"name": "Richelieu Rock", "country": "Thailand", "region": "Similan Islands", "lat": 9.3617, "lon": 98.0250, "max_depth": 35, "water_type": "saltwater"},
    {"name": "Koh Bon Pinnacle", "country": "Thailand", "region": "Similan Islands", "lat": 9.2167, "lon": 97.8333, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Manta Point Komodo", "country": "Indonesia", "region": "Komodo", "lat": -8.7500, "lon": 119.4667, "max_depth": 20, "water_type": "saltwater"},
    {"name": "Crystal Bay", "country": "Indonesia", "region": "Nusa Penida", "lat": -8.7167, "lon": 115.4667, "max_depth": 30, "water_type": "saltwater"},
    {"name": "USAT Liberty Wreck", "country": "Indonesia", "region": "Tulamben", "lat": -8.2750, "lon": 115.5944, "max_depth": 30, "water_type": "saltwater"},
    {"name": "Barracuda Point", "country": "Malaysia", "region": "Sipadan", "lat": 4.1147, "lon": 118.6289, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Turtle Tomb", "country": "Malaysia", "region": "Sipadan", "lat": 4.1153, "lon": 118.6278, "max_depth": 20, "water_type": "saltwater"},

    # Pacific
    {"name": "Blue Corner", "country": "Palau", "region": "Koror", "lat": 7.1333, "lon": 134.2167, "max_depth": 35, "water_type": "saltwater"},
    {"name": "German Channel", "country": "Palau", "region": "Koror", "lat": 7.2000, "lon": 134.3500, "max_depth": 25, "water_type": "saltwater"},
    {"name": "SS Yongala", "country": "Australia", "region": "Queensland", "lat": -19.3056, "lon": 147.6222, "max_depth": 30, "water_type": "saltwater"},
    {"name": "Cod Hole", "country": "Australia", "region": "Great Barrier Reef", "lat": -14.6833, "lon": 145.6333, "max_depth": 25, "water_type": "saltwater"},
    {"name": "Navy Pier", "country": "Australia", "region": "Exmouth", "lat": -21.8167, "lon": 114.1500, "max_depth": 12, "water_type": "saltwater"},
    {"name": "Poor Knights Islands", "country": "New Zealand", "region": "Northland", "lat": -35.4667, "lon": 174.7333, "max_depth": 40, "water_type": "saltwater"},

    # Mediterranean
    {"name": "MV Zenobia", "country": "Cyprus", "region": "Larnaca", "lat": 34.8833, "lon": 33.6500, "max_depth": 42, "water_type": "saltwater"},
    {"name": "MV Um El Faroud", "country": "Malta", "region": "Wied iz-Zurrieq", "lat": 35.8167, "lon": 14.4333, "max_depth": 36, "water_type": "saltwater"},
    {"name": "Blue Grotto Malta", "country": "Malta", "region": "Zurrieq", "lat": 35.8208, "lon": 14.4542, "max_depth": 25, "water_type": "saltwater"},

    # Atlantic / Americas
    {"name": "Molasses Reef", "country": "USA", "region": "Florida Keys", "lat": 25.0119, "lon": -80.3756, "max_depth": 12, "water_type": "saltwater"},
    {"name": "USCGC Spiegel Grove", "country": "USA", "region": "Florida Keys", "lat": 25.0603, "lon": -80.3089, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Blue Heron Bridge", "country": "USA", "region": "Florida", "lat": 26.7833, "lon": -80.0500, "max_depth": 6, "water_type": "saltwater"},
    {"name": "Monterey Breakwater", "country": "USA", "region": "California", "lat": 36.6167, "lon": -121.9000, "max_depth": 20, "water_type": "saltwater"},
    {"name": "Catalina Casino Point", "country": "USA", "region": "California", "lat": 33.3833, "lon": -118.4167, "max_depth": 30, "water_type": "saltwater"},
    {"name": "Cenote Dos Ojos", "country": "Mexico", "region": "Quintana Roo", "lat": 20.3244, "lon": -87.3914, "max_depth": 10, "water_type": "freshwater"},
    {"name": "Cenote Angelita", "country": "Mexico", "region": "Quintana Roo", "lat": 20.1753, "lon": -87.4694, "max_depth": 60, "water_type": "freshwater"},

    # Maldives
    {"name": "Manta Point Maldives", "country": "Maldives", "region": "North Male Atoll", "lat": 4.4667, "lon": 73.4667, "max_depth": 20, "water_type": "saltwater"},
    {"name": "Fish Head", "country": "Maldives", "region": "Ari Atoll", "lat": 3.9500, "lon": 72.8500, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Maaya Thila", "country": "Maldives", "region": "Ari Atoll", "lat": 3.9667, "lon": 72.8333, "max_depth": 30, "water_type": "saltwater"},

    # Galapagos
    {"name": "Darwin Arch", "country": "Ecuador", "region": "Galapagos", "lat": 1.6783, "lon": -91.9864, "max_depth": 30, "water_type": "saltwater"},
    {"name": "Wolf Island", "country": "Ecuador", "region": "Galapagos", "lat": 1.3833, "lon": -91.8167, "max_depth": 40, "water_type": "saltwater"},
    {"name": "Gordon Rocks", "country": "Ecuador", "region": "Galapagos", "lat": -0.5333, "lon": -90.4833, "max_depth": 35, "water_type": "saltwater"},
]

# Dive centers/operators
DIVE_CENTERS = [
    {"name": "Aqua Safari", "city": "Cozumel", "country": "Mexico", "lat": 20.5083, "lon": -86.9458, "phone": "+52 987 872 0101", "email": "info@aquasafari.com"},
    {"name": "Scuba Du", "city": "Cozumel", "country": "Mexico", "lat": 20.5108, "lon": -86.9489, "phone": "+52 987 872 9505", "email": "dive@scubadu.com"},
    {"name": "Camel Dive Club", "city": "Sharm el-Sheikh", "country": "Egypt", "lat": 27.8614, "lon": 34.2939, "phone": "+20 69 360 0700", "email": "info@cameldive.com"},
    {"name": "Emperor Divers", "city": "Hurghada", "country": "Egypt", "lat": 27.2579, "lon": 33.8116, "phone": "+20 65 344 7896", "email": "info@emperordivers.com"},
    {"name": "Sea Bees Diving", "city": "Phuket", "country": "Thailand", "lat": 7.8917, "lon": 98.3000, "phone": "+66 76 381 765", "email": "info@sea-bees.com"},
    {"name": "Khao Lak Scuba Adventures", "city": "Khao Lak", "country": "Thailand", "lat": 8.6522, "lon": 98.2347, "phone": "+66 76 485 614", "email": "dive@khaolakscuba.com"},
    {"name": "Sipadan Scuba", "city": "Semporna", "country": "Malaysia", "lat": 4.4833, "lon": 118.6167, "phone": "+60 89 785 372", "email": "dive@sipadanscuba.com"},
    {"name": "Sams Tours Palau", "city": "Koror", "country": "Palau", "lat": 7.3419, "lon": 134.4789, "phone": "+680 488 1062", "email": "dive@samstours.com"},
    {"name": "Fish n Fins", "city": "Koror", "country": "Palau", "lat": 7.3383, "lon": 134.4611, "phone": "+680 488 2637", "email": "info@fishnfins.com"},
    {"name": "Pro Dive Cairns", "city": "Cairns", "country": "Australia", "lat": -16.9186, "lon": 145.7781, "phone": "+61 7 4031 5255", "email": "dive@prodivecairns.com"},
    {"name": "Mike Ball Dive Expeditions", "city": "Cairns", "country": "Australia", "lat": -16.9167, "lon": 145.7833, "phone": "+61 7 4053 0500", "email": "resv@mikeball.com"},
    {"name": "Maltaqua", "city": "Sliema", "country": "Malta", "lat": 35.9097, "lon": 14.5017, "phone": "+356 2133 9238", "email": "info@maltaqua.com"},
    {"name": "Cydive", "city": "Larnaca", "country": "Cyprus", "lat": 34.9167, "lon": 33.6333, "phone": "+357 24 647 647", "email": "dive@cydive.com"},
    {"name": "Rainbow Reef Dive Center", "city": "Key Largo", "country": "USA", "lat": 25.0867, "lon": -80.4456, "phone": "+1 305 451 1113", "email": "dive@rainbowreef.us"},
    {"name": "Abyss Dive Center", "city": "Key Largo", "country": "USA", "lat": 25.0950, "lon": -80.4411, "phone": "+1 305 451 4780", "email": "info@abyssdive.com"},
    {"name": "Maldives Scuba Tours", "city": "Male", "country": "Maldives", "lat": 4.1753, "lon": 73.5089, "phone": "+960 332 3939", "email": "dive@maldivesscuba.com"},
    {"name": "Scuba Iguana", "city": "Puerto Ayora", "country": "Ecuador", "lat": -0.7456, "lon": -90.3136, "phone": "+593 5 252 6497", "email": "dive@scubaiguana.com"},
    {"name": "Buddy Dive Resort", "city": "Kralendijk", "country": "Bonaire", "lat": 12.1500, "lon": -68.2833, "phone": "+599 717 5080", "email": "info@buddydive.com"},
    {"name": "Stuart Coves Dive Bahamas", "city": "Nassau", "country": "Bahamas", "lat": 25.0000, "lon": -77.5167, "phone": "+1 242 362 4171", "email": "dive@stuartcoves.com"},
    {"name": "Blue Water Divers", "city": "Monterey", "country": "USA", "lat": 36.6003, "lon": -121.8928, "phone": "+1 831 375 1933", "email": "info@bluewaterdivers.com"},
]

# Buddy names
BUDDY_FIRST_NAMES = [
    "James", "Maria", "David", "Emma", "Michael", "Sarah", "Daniel", "Lisa",
    "Robert", "Jennifer", "William", "Jessica", "Thomas", "Amanda", "Charles",
    "Nicole", "Christopher", "Michelle", "Matthew", "Stephanie", "Andrew", "Laura",
    "Joseph", "Rebecca", "Steven", "Katherine", "Mark", "Rachel", "Paul", "Megan",
    "Kevin", "Ashley", "Brian", "Emily", "George", "Samantha", "Edward", "Hannah",
    "Patrick", "Olivia", "Richard", "Elizabeth", "Timothy", "Natalie", "Jason", "Victoria",
    "Jeffrey", "Alexandra", "Ryan", "Sophia"
]

BUDDY_LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
    "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker",
    "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill",
    "Flores", "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell",
    "Mitchell", "Carter", "Roberts"
]

# UDDF 3.2.1 compliant gas mix definitions
# o2 and he are fractions (0-1), not percentages
GAS_MIXES = [
    {"id": "air", "name": "Air", "o2": 0.21, "he": 0.0},
    {"id": "ean32", "name": "EAN32", "o2": 0.32, "he": 0.0},
    {"id": "ean36", "name": "EAN36", "o2": 0.36, "he": 0.0},
    {"id": "ean50", "name": "EAN50", "o2": 0.50, "he": 0.0},
    {"id": "oxygen", "name": "Oxygen", "o2": 1.00, "he": 0.0},
    {"id": "tx18_45", "name": "Trimix 18/45", "o2": 0.18, "he": 0.45},
    {"id": "tx21_35", "name": "Trimix 21/35", "o2": 0.21, "he": 0.35},
    {"id": "tx15_55", "name": "Trimix 15/55", "o2": 0.15, "he": 0.55},
    {"id": "hx25_25", "name": "Helitrox 25/25", "o2": 0.25, "he": 0.25},
]

# =============================================================================
# SITE TYPE CLASSIFICATION
# =============================================================================
# Patterns to infer site type from dive site names
SITE_TYPE_PATTERNS = {
    "wall": ["Wall", "Drop", "Cliff", "Bloody Bay"],
    "wreck": ["SS ", "USS ", "MV ", "USAT", "Wreck", "USCGC", "Kittiwake", "Zenobia",
              "Thistlegorm", "Liberty", "Yongala", "Spiegel Grove", "Um El Faroud"],
    "cenote": ["Cenote"],
    "drift": ["Corner", "Channel", "Point", "Current", "Blue Corner", "Barracuda Point"],
    "reef": ["Reef", "Gardens", "Pinnacle", "Rock", "Thila", "Cod Hole", "Fish Head",
             "Richelieu", "Elphinstone", "Paso del", "1000 Steps", "Molasses"],
    "manta": ["Manta", "German Channel"],
    "shallow": ["Pier", "Bridge", "Steps", "City", "Stingray City", "Navy Pier",
                "Blue Heron", "Salt Pier", "Breakwater", "Casino Point"],
    "cavern": ["Blue Hole", "Grotto", "Tomb", "Angelita"],  # Cavern/overhead environments
}


def get_site_type(site: Dict) -> str:
    """
    Determine dive site type based on name patterns.

    Returns one of: wall, wreck, cenote, drift, reef, manta, shallow, cavern
    Default: reef (most common dive type)
    """
    name = site.get("name", "")
    for site_type, patterns in SITE_TYPE_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in name.lower():
                return site_type
    return "reef"  # Default fallback


# =============================================================================
# THERMOCLINE PROFILES BY REGION
# =============================================================================
# Realistic temperature layers for different diving regions
# (surface_temp_range, thermocline_start, thermocline_thickness, temp_drop)
THERMOCLINE_PROFILES = {
    "tropical": {  # Caribbean, Red Sea, SE Asia, Maldives
        "surface_temp": (27, 30),   # Surface temp range in °C
        "thermocline_start": 18,     # Depth where thermocline begins
        "thermocline_thickness": 8,  # Transition zone thickness
        "temp_drop": 3,              # Temperature drop through thermocline
        "deep_gradient": 0.05,       # °C per meter below thermocline
    },
    "cenote": {  # Yucatan cenotes - sharp halocline
        "surface_temp": (25, 27),
        "thermocline_start": 10,     # Halocline much shallower
        "thermocline_thickness": 3,  # Very sharp transition
        "temp_drop": 8,              # Dramatic temp change
        "deep_gradient": -0.05,      # Actually warms up below halocline!
    },
    "temperate": {  # California, New Zealand, Mediterranean
        "surface_temp": (14, 18),
        "thermocline_start": 8,
        "thermocline_thickness": 10,
        "temp_drop": 4,
        "deep_gradient": 0.08,
    },
    "cold": {  # Northern Europe, deep wrecks
        "surface_temp": (10, 14),
        "thermocline_start": 5,
        "thermocline_thickness": 15,
        "temp_drop": 6,
        "deep_gradient": 0.05,
    },
}


def get_thermocline_profile(site: Dict) -> Dict:
    """Get the appropriate thermocline profile for a dive site."""
    site_type = get_site_type(site)
    country = site.get("country", "")
    region = site.get("region", "")

    if site_type == "cenote":
        return THERMOCLINE_PROFILES["cenote"]
    elif country in ["USA"] and "California" in region:
        return THERMOCLINE_PROFILES["temperate"]
    elif country == "New Zealand":
        return THERMOCLINE_PROFILES["temperate"]
    elif country in ["Malta", "Cyprus"]:
        return THERMOCLINE_PROFILES["temperate"]
    else:
        return THERMOCLINE_PROFILES["tropical"]


def calculate_temperature_at_depth(
    depth: float,
    profile: Dict,
    surface_temp: float,
    variation_seed: float = 0.0
) -> float:
    """
    Calculate water temperature at a given depth with thermocline modeling.

    Uses smooth S-curve transition through the thermocline zone.
    """
    thermo_start = profile["thermocline_start"]
    thermo_thick = profile["thermocline_thickness"]
    temp_drop = profile["temp_drop"]
    deep_grad = profile["deep_gradient"]
    thermo_end = thermo_start + thermo_thick

    # Add small random variation
    noise = math.sin(depth * 0.5 + variation_seed) * 0.3

    if depth < thermo_start:
        # Surface layer - stable temperature
        return surface_temp + noise
    elif depth < thermo_end:
        # Thermocline transition - smooth S-curve
        progress = (depth - thermo_start) / thermo_thick
        # Sigmoid-like smooth step
        t = progress * math.pi
        smooth = (1 - math.cos(t)) / 2  # 0 to 1 smoothly
        temp = surface_temp - (temp_drop * smooth)
        return temp + noise
    else:
        # Below thermocline - gradual cooling (or warming for cenotes)
        base_temp = surface_temp - temp_drop
        extra_depth = depth - thermo_end
        temp = base_temp - (extra_depth * deep_grad)
        return temp + noise


# =============================================================================
# MARINE SPECIES BY REGION
# =============================================================================
SPECIES_BY_REGION = {
    "Caribbean": [
        ("Green Sea Turtle", 0.4), ("Hawksbill Turtle", 0.2),
        ("Spotted Eagle Ray", 0.3), ("Southern Stingray", 0.4),
        ("Nurse Shark", 0.2), ("Caribbean Reef Shark", 0.15),
        ("Great Barracuda", 0.5), ("Green Moray Eel", 0.4),
        ("Queen Angelfish", 0.6), ("French Angelfish", 0.5),
        ("Stoplight Parrotfish", 0.7), ("Blue Tang", 0.8),
        ("Sergeant Major", 0.9), ("Yellowtail Snapper", 0.7),
        ("Spiny Lobster", 0.4), ("Lionfish", 0.3),  # Invasive but common
        ("Spotted Drum", 0.3), ("Fairy Basslet", 0.5),
    ],
    "Red Sea": [
        ("Napoleon Wrasse", 0.3), ("Giant Moray Eel", 0.4),
        ("Whitetip Reef Shark", 0.3), ("Grey Reef Shark", 0.2),
        ("Oceanic Whitetip Shark", 0.05), ("Hammerhead Shark", 0.08),
        ("Manta Ray", 0.1), ("Eagle Ray", 0.3),
        ("Red Sea Clownfish", 0.5), ("Emperor Angelfish", 0.4),
        ("Masked Butterflyfish", 0.6), ("Lionfish", 0.5),
        ("Bluespotted Ribbontail Ray", 0.4), ("Crocodilefish", 0.3),
        ("Dugong", 0.02), ("Dolphin", 0.1),
    ],
    "Southeast Asia": [
        ("Whale Shark", 0.05), ("Manta Ray", 0.15),
        ("Blacktip Reef Shark", 0.3), ("Leopard Shark", 0.2),
        ("Giant Trevally", 0.4), ("Bumphead Parrotfish", 0.2),
        ("Sea Turtle", 0.4), ("Cuttlefish", 0.5),
        ("Clownfish", 0.6), ("Mandarin Fish", 0.1),
        ("Pygmy Seahorse", 0.05), ("Frogfish", 0.1),
        ("Nudibranch", 0.7), ("Octopus", 0.4),
        ("Mantis Shrimp", 0.3), ("Ghost Pipefish", 0.1),
        ("Barracuda", 0.5), ("Sweetlips", 0.4),
    ],
    "Galapagos": [
        ("Scalloped Hammerhead Shark", 0.4), ("Galapagos Shark", 0.3),
        ("Whale Shark", 0.1), ("Manta Ray", 0.2),
        ("Marine Iguana", 0.5), ("Galapagos Sea Lion", 0.7),
        ("Galapagos Penguin", 0.2), ("Mola Mola", 0.05),
        ("Green Sea Turtle", 0.5), ("Eagle Ray", 0.4),
        ("King Angelfish", 0.5), ("Yellowtail Surgeonfish", 0.6),
        ("Red-lipped Batfish", 0.1), ("Moray Eel", 0.4),
    ],
    "Pacific": [  # Palau, Australia, etc.
        ("Manta Ray", 0.2), ("Grey Reef Shark", 0.4),
        ("Whitetip Reef Shark", 0.4), ("Blacktip Reef Shark", 0.3),
        ("Napoleon Wrasse", 0.3), ("Giant Trevally", 0.5),
        ("Bumphead Parrotfish", 0.3), ("Potato Grouper", 0.2),
        ("Sea Turtle", 0.5), ("Giant Clam", 0.4),
        ("Jellyfish", 0.2), ("Mandarin Fish", 0.1),
        ("Crocodile Fish", 0.2), ("Lionfish", 0.3),
    ],
    "Maldives": [
        ("Manta Ray", 0.3), ("Whale Shark", 0.08),
        ("Grey Reef Shark", 0.4), ("Whitetip Reef Shark", 0.4),
        ("Nurse Shark", 0.3), ("Guitar Shark", 0.1),
        ("Eagle Ray", 0.4), ("Stingray", 0.5),
        ("Napoleon Wrasse", 0.2), ("Oriental Sweetlips", 0.4),
        ("Moray Eel", 0.5), ("Octopus", 0.3),
        ("Sea Turtle", 0.4), ("Clownfish", 0.5),
        ("Butterflyfish", 0.7), ("Batfish", 0.4),
    ],
    "Mediterranean": [
        ("Grouper", 0.4), ("Barracuda", 0.3),
        ("Moray Eel", 0.4), ("Octopus", 0.5),
        ("Scorpionfish", 0.3), ("Sea Bream", 0.6),
        ("Damselfish", 0.7), ("Nudibranch", 0.4),
        ("Starfish", 0.5), ("Sea Urchin", 0.6),
        ("Flying Gurnard", 0.2), ("John Dory", 0.1),
    ],
    "Cenote": [  # Freshwater cenotes
        ("Freshwater Fish", 0.3), ("Catfish", 0.2),
        ("Molly", 0.4),  # Small fish common in cenotes
        # Cenotes focus more on formations than wildlife
    ],
    "Temperate": [  # California, New Zealand
        ("Giant Pacific Octopus", 0.2), ("Wolf Eel", 0.1),
        ("Lingcod", 0.3), ("Cabezon", 0.2),
        ("Harbor Seal", 0.2), ("Sea Lion", 0.25),
        ("Garibaldi", 0.4), ("Sheephead", 0.3),
        ("Horn Shark", 0.1), ("Bat Ray", 0.3),
        ("Giant Sea Bass", 0.05), ("Moray Eel", 0.2),
        ("Spiny Lobster", 0.3), ("Sea Urchin", 0.6),
        ("Kelp Forest Fish", 0.7), ("Nudibranch", 0.5),
    ],
}


def get_region_for_species(site: Dict) -> str:
    """Determine which species region to use for a dive site."""
    site_type = get_site_type(site)
    if site_type == "cenote":
        return "Cenote"

    country = site.get("country", "")
    region = site.get("region", "")

    if country in ["Belize", "Mexico"] and "Quintana Roo" not in region:
        return "Caribbean"
    if country in ["Cayman Islands", "Bonaire", "Bahamas"]:
        return "Caribbean"
    if country in ["USA"] and "Florida" in region:
        return "Caribbean"
    if country == "Egypt":
        return "Red Sea"
    if country in ["Thailand", "Indonesia", "Malaysia"]:
        return "Southeast Asia"
    if country == "Ecuador" and "Galapagos" in region:
        return "Galapagos"
    if country in ["Palau", "Australia"]:
        return "Pacific"
    if country == "Maldives":
        return "Maldives"
    if country in ["Malta", "Cyprus"]:
        return "Mediterranean"
    if country == "New Zealand" or (country == "USA" and "California" in region):
        return "Temperate"

    return "Caribbean"  # Default fallback


def generate_sightings(site: Dict, site_type: str, num_sightings: int = None) -> List[Dict]:
    """
    Generate realistic marine life sightings for a dive.

    Args:
        site: Dive site dictionary
        site_type: Type of dive site (reef, wall, wreck, etc.)
        num_sightings: Number of species to include (random if None)

    Returns:
        List of sighting dictionaries with species name and count
    """
    region = get_region_for_species(site)
    species_list = SPECIES_BY_REGION.get(region, SPECIES_BY_REGION["Caribbean"])

    if num_sightings is None:
        # Vary sightings by site type
        if site_type == "manta":
            num_sightings = random.randint(2, 5)
        elif site_type == "cenote":
            num_sightings = random.randint(0, 2)
        elif site_type in ["reef", "wall"]:
            num_sightings = random.randint(3, 7)
        else:
            num_sightings = random.randint(2, 5)

    sightings = []
    available_species = species_list.copy()

    for _ in range(min(num_sightings, len(available_species))):
        # Weighted random selection based on probability
        candidates = [(sp, prob) for sp, prob in available_species if random.random() < prob * 2]
        if not candidates:
            candidates = available_species[:3]  # Fallback to most common

        if candidates:
            if isinstance(candidates[0], tuple):
                species, _ = random.choice(candidates)
            else:
                species = random.choice(candidates)

            # Remove selected species to avoid duplicates
            available_species = [(s, p) for s, p in available_species if s != species]

            # Generate count based on species type
            if any(x in species.lower() for x in ["shark", "manta", "turtle", "whale", "seal", "lion", "iguana"]):
                count = random.randint(1, 3)  # Large animals seen in small numbers
            elif any(x in species.lower() for x in ["fish", "tang", "snapper", "parrot"]):
                count = random.randint(5, 50)  # Schooling fish
            else:
                count = random.randint(1, 8)  # Other species

            sightings.append({
                "species": species,
                "count": count,
            })

    return sightings


# =============================================================================
# DIVE CONDITIONS AND RATINGS
# =============================================================================
WIND_DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
ENTRY_METHODS = ["shore", "boat", "giantStride", "backRoll", "ladder"]


def generate_dive_conditions(site: Dict, site_type: str) -> Dict:
    """
    Generate realistic dive conditions based on site type and location.

    Returns a dictionary with visibility, current, swell, entry method, etc.
    """
    country = site.get("country", "")
    region = site.get("region", "")

    # Visibility based on region and site type
    if site_type == "cenote":
        visibility = random.randint(25, 60)  # Crystal clear in cenotes
    elif country in ["Maldives", "Egypt", "Palau"]:
        visibility = random.randint(20, 40)  # Great tropical visibility
    elif country in ["Thailand", "Indonesia", "Malaysia"]:
        visibility = random.randint(10, 30)  # Variable
    elif country in ["USA"] and "California" in region:
        visibility = random.randint(5, 20)  # Temperate, kelp
    else:
        visibility = random.randint(12, 30)  # Average tropical

    # Current based on site type
    if site_type == "drift":
        current_strength = random.choice(["moderate", "strong", "strong"])
    elif site_type in ["cenote", "wreck", "shallow"]:
        current_strength = random.choice(["none", "none", "light"])
    else:
        current_strength = random.choice(["none", "light", "light", "moderate"])

    current_direction = random.choice(WIND_DIRECTIONS) if current_strength != "none" else None

    # Swell for ocean sites
    if site_type == "cenote" or site.get("water_type") == "freshwater":
        swell_height = 0.0
    else:
        swell_height = random.choice([0.0, 0.3, 0.5, 0.8, 1.0, 1.2])

    # Entry method based on site
    if site_type in ["shallow", "cenote"]:
        entry_method = "shore"
    elif site_type == "wreck":
        entry_method = random.choice(["boat", "giantStride", "backRoll"])
    elif "Pier" in site.get("name", "") or "Bridge" in site.get("name", ""):
        entry_method = "shore"
    else:
        entry_method = random.choice(["boat", "giantStride", "backRoll", "ladder"])

    exit_method = entry_method if entry_method == "shore" else random.choice([entry_method, "ladder"])

    # Water type from site or inferred
    water_type = site.get("water_type", "saltwater")

    return {
        "visibility": visibility,
        "current_strength": current_strength,
        "current_direction": current_direction,
        "swell_height": swell_height,
        "entry_method": entry_method,
        "exit_method": exit_method,
        "water_type": water_type,
    }


# =============================================================================
# DIVE NOTES TEMPLATES
# =============================================================================
DIVE_NOTES_TEMPLATES = [
    "Great dive at {site}! {highlight}",
    "Excellent conditions today. {highlight}",
    "{highlight} {buddy} was a great dive buddy.",
    "One of the best dives of the trip. {highlight}",
    "Beautiful {site_type} dive. {highlight}",
    "{highlight} Visibility was {vis}m.",
    "Amazing dive! {highlight} Water temp was perfect.",
    "{highlight} Will definitely dive here again.",
    "Good dive despite {challenge}. {highlight}",
    "First time at {site}. {highlight}",
]

HIGHLIGHTS = [
    "Saw {species} up close!",
    "Great viz today.",
    "Lots of marine life.",
    "Spotted a {species}!",
    "Beautiful coral formations.",
    "Perfect conditions.",
    "Incredible {species} encounter.",
    "Managed to photograph a {species}.",
    "The {species} came very close.",
    "Swam with {species} for several minutes.",
]

CHALLENGES = [
    "strong current",
    "limited visibility",
    "cold thermocline",
    "surge at safety stop",
    "brief rain topside",
]


def generate_dive_notes(site: Dict, site_type: str, sightings: List[Dict], buddy_name: str, conditions: Dict) -> str:
    """Generate natural-sounding dive notes."""
    template = random.choice(DIVE_NOTES_TEMPLATES)

    # Pick a highlight species if we have sightings
    if sightings:
        highlight_sighting = random.choice(sightings)
        species = highlight_sighting["species"]
    else:
        species = "fish"

    highlight_template = random.choice(HIGHLIGHTS)
    highlight = highlight_template.format(species=species)

    challenge = random.choice(CHALLENGES)

    notes = template.format(
        site=site.get("name", "this site"),
        site_type=site_type,
        highlight=highlight,
        buddy=buddy_name,
        vis=conditions.get("visibility", 15),
        challenge=challenge,
        species=species,
    )

    return notes


# =============================================================================
# DIVE SESSION FOR REPETITIVE DIVING
# =============================================================================
class DiveSession:
    """
    Tracks tissue state across multiple dives in a day for repetitive diving.

    Handles surface interval off-gassing and calculates reduced NDLs for
    subsequent dives.
    """

    def __init__(self):
        """Initialize a fresh dive session."""
        self.tissue = TissueState()
        self.last_dive_end: datetime = None
        self.dive_count_today = 0
        self.dives_today: List[Dict] = []

    def start_new_day(self):
        """Reset for a new diving day (after sufficient surface interval)."""
        self.tissue = TissueState()
        self.last_dive_end = None
        self.dive_count_today = 0
        self.dives_today = []

    def surface_interval_minutes(self, current_time: datetime) -> float:
        """Calculate minutes since last dive ended."""
        if self.last_dive_end is None:
            return float('inf')
        return (current_time - self.last_dive_end).total_seconds() / 60

    def apply_surface_interval(self, interval_minutes: float):
        """
        Off-gas tissues during surface interval.

        Tissues continue to off-gas nitrogen while on the surface,
        reducing tissue loading for the next dive.
        """
        if interval_minutes <= 0:
            return

        # Update tissues at surface pressure, breathing air
        self.tissue.update(
            depth=0.0,
            time_seconds=interval_minutes * 60,
            o2_fraction=0.21,
            he_fraction=0.0
        )

    def get_adjusted_ndl(self, depth: float, gf_high: float = 0.85) -> float:
        """
        Calculate NDL accounting for residual nitrogen from previous dives.

        Returns reduced NDL for repetitive dives.
        """
        return self.tissue.ndl(depth, o2_fraction=0.21, gf_high=gf_high)

    def record_dive_end(self, end_time: datetime, dive_summary: Dict):
        """Record that a dive has ended for surface interval tracking."""
        self.last_dive_end = end_time
        self.dive_count_today += 1
        self.dives_today.append(dive_summary)

    def is_new_day(self, current_time: datetime) -> bool:
        """Check if current time is a new diving day (>12 hours since last dive)."""
        if self.last_dive_end is None:
            return True
        interval = (current_time - self.last_dive_end).total_seconds() / 3600
        return interval > 12  # More than 12 hours = new diving day


# =============================================================================
# BÜHLMANN ZHL-16C DECOMPRESSION MODEL
# =============================================================================
# Each compartment tuple: (half_time_N2, half_time_He, a_N2, b_N2, a_He, b_He)
# Half-times in minutes, a/b coefficients for M-value calculation
# Source: Bühlmann ZHL-16C with GF extensions
BUHLMANN_ZHL16C = [
    (4.0, 1.51, 1.2599, 0.5050, 1.7424, 0.4245),
    (8.0, 3.02, 1.0000, 0.6514, 1.3830, 0.5747),
    (12.5, 4.72, 0.8618, 0.7222, 1.1919, 0.6527),
    (18.5, 6.99, 0.7562, 0.7825, 1.0458, 0.7223),
    (27.0, 10.21, 0.6200, 0.8126, 0.9220, 0.7582),
    (38.3, 14.48, 0.5043, 0.8434, 0.8205, 0.7957),
    (54.3, 20.53, 0.4410, 0.8693, 0.7305, 0.8279),
    (77.0, 29.11, 0.4000, 0.8910, 0.6502, 0.8553),
    (109.0, 41.20, 0.3750, 0.9092, 0.5950, 0.8757),
    (146.0, 55.19, 0.3500, 0.9222, 0.5545, 0.8903),
    (187.0, 70.69, 0.3295, 0.9319, 0.5333, 0.8997),
    (239.0, 90.34, 0.3065, 0.9403, 0.5189, 0.9073),
    (305.0, 115.29, 0.2835, 0.9477, 0.5181, 0.9122),
    (390.0, 147.42, 0.2610, 0.9544, 0.5176, 0.9171),
    (498.0, 188.24, 0.2480, 0.9602, 0.5172, 0.9217),
    (635.0, 240.03, 0.2327, 0.9653, 0.5119, 0.9267),
]

# Water vapor pressure at 37°C (body temperature) in bar
WATER_VAPOR_PRESSURE = 0.0627

# Surface atmospheric pressure in bar
SURFACE_PRESSURE = 1.01325


class TissueState:
    """
    Bühlmann ZHL-16C tissue compartment model for decompression calculations.

    Tracks nitrogen and helium loading in 16 tissue compartments and calculates
    the decompression ceiling based on gradient factors.
    """

    def __init__(self):
        """Initialize tissue compartments at surface saturation."""
        # At surface, tissues are saturated with nitrogen at ambient partial pressure
        # ppN2 = (surface_pressure - water_vapor) * 0.79 (fraction of N2 in air)
        surface_ppn2 = (SURFACE_PRESSURE - WATER_VAPOR_PRESSURE) * 0.79
        self.n2_loadings = [surface_ppn2] * 16
        self.he_loadings = [0.0] * 16  # No helium at surface

    def update(self, depth: float, time_seconds: float, o2_fraction: float, he_fraction: float):
        """
        Update tissue loadings after spending time at a given depth.

        Args:
            depth: Current depth in meters
            time_seconds: Time spent at this depth in seconds
            o2_fraction: Oxygen fraction in breathing gas (0-1)
            he_fraction: Helium fraction in breathing gas (0-1)
        """
        # Calculate ambient pressure in bar
        ambient_pressure = SURFACE_PRESSURE + (depth / 10.0)

        # Calculate inspired gas partial pressures (accounting for water vapor)
        inspired_pressure = ambient_pressure - WATER_VAPOR_PRESSURE
        n2_fraction = 1.0 - o2_fraction - he_fraction
        pp_n2_inspired = inspired_pressure * n2_fraction
        pp_he_inspired = inspired_pressure * he_fraction

        time_minutes = time_seconds / 60.0

        for i, compartment in enumerate(BUHLMANN_ZHL16C):
            ht_n2, ht_he, _, _, _, _ = compartment

            # Schreiner equation: P_tissue = P_inspired + (P_tissue_0 - P_inspired) * e^(-t/tau)
            # where tau = half_time / ln(2)

            # Nitrogen loading
            k_n2 = math.log(2) / ht_n2
            self.n2_loadings[i] = pp_n2_inspired + (self.n2_loadings[i] - pp_n2_inspired) * math.exp(-k_n2 * time_minutes)

            # Helium loading (only if breathing helium mix)
            if he_fraction > 0:
                k_he = math.log(2) / ht_he
                self.he_loadings[i] = pp_he_inspired + (self.he_loadings[i] - pp_he_inspired) * math.exp(-k_he * time_minutes)
            elif self.he_loadings[i] > 0.001:
                # Off-gassing helium while breathing non-helium mix
                k_he = math.log(2) / ht_he
                self.he_loadings[i] = self.he_loadings[i] * math.exp(-k_he * time_minutes)

    def ceiling(self, gf: float = 1.0) -> float:
        """
        Calculate the current decompression ceiling depth.

        Args:
            gf: Gradient factor (0-1), where 1.0 = 100% of M-value

        Returns:
            Ceiling depth in meters (0 = surface is safe)
        """
        max_ceiling = 0.0

        for i, compartment in enumerate(BUHLMANN_ZHL16C):
            _, _, a_n2, b_n2, a_he, b_he = compartment

            # Total inert gas pressure in this compartment
            p_inert = self.n2_loadings[i] + self.he_loadings[i]

            if p_inert <= 0:
                continue

            # Calculate weighted a and b values for mixed gas
            if self.he_loadings[i] > 0.001:
                # Weighted by gas fractions in tissue
                he_frac = self.he_loadings[i] / p_inert
                n2_frac = self.n2_loadings[i] / p_inert
                a = (a_n2 * n2_frac) + (a_he * he_frac)
                b = (b_n2 * n2_frac) + (b_he * he_frac)
            else:
                a = a_n2
                b = b_n2

            # M-value at surface: M0 = a + (1/b) * P_ambient
            # Ceiling: P_ambient_min = (P_tissue - a * gf) / (gf / b - gf + 1)
            # Simplified: P_ceiling = (P_tissue - a * gf) * b / gf
            # Then convert to depth

            # With gradient factor applied:
            # Allowed P_ambient = (P_inert - a * gf) / (gf / b - gf + 1)
            gf_adjusted = gf / b - gf + 1
            if gf_adjusted > 0:
                p_ceiling = (p_inert - a * gf) / gf_adjusted

                # Convert pressure to depth
                ceiling_depth = (p_ceiling - SURFACE_PRESSURE) * 10.0
                max_ceiling = max(max_ceiling, ceiling_depth)

        return max(0.0, max_ceiling)

    def gf_ceiling(self, gf_low: float, gf_high: float, current_depth: float, first_stop_depth: float = None) -> float:
        """
        Calculate ceiling using gradient factor slope between GF Low and GF High.

        GF Low is applied at the deepest required stop, GF High at the surface.
        The effective GF is interpolated based on current depth.

        Args:
            gf_low: Gradient factor at first stop (typically 0.30-0.40)
            gf_high: Gradient factor at surface (typically 0.70-0.85)
            current_depth: Current depth in meters
            first_stop_depth: Depth of first required stop (if known)

        Returns:
            Ceiling depth in meters
        """
        # First, find the raw ceiling at GF Low to determine first stop depth
        if first_stop_depth is None:
            first_stop_depth = self.ceiling(gf_low)

        if first_stop_depth <= 0:
            # No deco required, use GF High
            return self.ceiling(gf_high)

        # Interpolate GF based on current depth between first stop and surface
        if current_depth >= first_stop_depth:
            effective_gf = gf_low
        elif current_depth <= 0:
            effective_gf = gf_high
        else:
            # Linear interpolation
            progress = 1.0 - (current_depth / first_stop_depth)
            effective_gf = gf_low + (gf_high - gf_low) * progress

        return self.ceiling(effective_gf)

    def ndl(self, depth: float, o2_fraction: float = 0.21, he_fraction: float = 0.0, gf_high: float = 0.85) -> float:
        """
        Calculate No Decompression Limit at a given depth.

        Args:
            depth: Target depth in meters
            o2_fraction: O2 fraction in breathing gas
            he_fraction: He fraction in breathing gas
            gf_high: Gradient factor for ceiling calculation

        Returns:
            NDL in minutes (time until deco is required)
        """
        # Create a copy to simulate without affecting current state
        sim_n2 = self.n2_loadings.copy()
        sim_he = self.he_loadings.copy()

        ambient_pressure = SURFACE_PRESSURE + (depth / 10.0)
        inspired_pressure = ambient_pressure - WATER_VAPOR_PRESSURE
        n2_fraction = 1.0 - o2_fraction - he_fraction
        pp_n2_inspired = inspired_pressure * n2_fraction
        pp_he_inspired = inspired_pressure * he_fraction

        ndl_minutes = 0.0
        time_step = 1.0  # 1 minute steps

        while ndl_minutes < 200:  # Max 200 minutes
            # Update simulated tissue loadings
            for i, compartment in enumerate(BUHLMANN_ZHL16C):
                ht_n2, ht_he, _, _, _, _ = compartment
                k_n2 = math.log(2) / ht_n2
                sim_n2[i] = pp_n2_inspired + (sim_n2[i] - pp_n2_inspired) * math.exp(-k_n2 * time_step)
                if he_fraction > 0:
                    k_he = math.log(2) / ht_he
                    sim_he[i] = pp_he_inspired + (sim_he[i] - pp_he_inspired) * math.exp(-k_he * time_step)

            # Check if any compartment requires deco
            for i, compartment in enumerate(BUHLMANN_ZHL16C):
                _, _, a_n2, b_n2, a_he, b_he = compartment
                p_inert = sim_n2[i] + sim_he[i]
                if p_inert > 0:
                    if sim_he[i] > 0.001:
                        he_frac = sim_he[i] / p_inert
                        n2_frac = sim_n2[i] / p_inert
                        a = (a_n2 * n2_frac) + (a_he * he_frac)
                        b = (b_n2 * n2_frac) + (b_he * he_frac)
                    else:
                        a = a_n2
                        b = b_n2

                    gf_adjusted = gf_high / b - gf_high + 1
                    if gf_adjusted > 0:
                        p_ceiling = (p_inert - a * gf_high) / gf_adjusted
                        ceiling_depth = (p_ceiling - SURFACE_PRESSURE) * 10.0
                        if ceiling_depth > 0:
                            return ndl_minutes

            ndl_minutes += time_step

        return 200.0  # Max NDL


def ease_in_out_cubic(t: float) -> float:
    """
    Smooth easing function for natural descent/ascent curves.

    Args:
        t: Progress from 0 to 1

    Returns:
        Eased value from 0 to 1
    """
    if t < 0.5:
        return 4 * t * t * t
    else:
        return 1 - pow(-2 * t + 2, 3) / 2


def depth_variation(time_seconds: float, amplitude: float = 2.0, seed: float = 0.0) -> float:
    """
    Generate smooth, natural depth variations simulating terrain following.

    Combines multiple sine waves at different frequencies for an organic feel.

    Args:
        time_seconds: Current time in seconds
        amplitude: Maximum variation in meters
        seed: Random seed offset for variety between dives

    Returns:
        Depth variation in meters (can be positive or negative)
    """
    t = time_seconds + seed
    return (
        math.sin(t * 0.05) * 0.5 +
        math.sin(t * 0.023) * 0.3 +
        math.sin(t * 0.089) * 0.15 +
        math.sin(t * 0.011) * 0.05
    ) * amplitude


def calculate_gas_duration(
    max_depth: float,
    tank_configs: List[Dict],
    is_tech: bool = False,
    reserve_fraction: float = 0.25
) -> float:
    """
    Calculate maximum dive duration based on available gas supply.

    Args:
        max_depth: Maximum planned depth in meters
        tank_configs: List of tank configurations
        is_tech: Whether this is a technical dive
        reserve_fraction: Fraction of gas to keep as reserve (default 25%)

    Returns:
        Maximum dive duration in minutes
    """
    # Sum up total available gas from main tanks
    main_tanks = [tc for tc in tank_configs if tc.get("role", "main") == "main"]
    total_gas_liters = sum(
        tank["volume"] * tank.get("working_pressure", 200)
        for tank in main_tanks
    )

    # Usable gas after reserve
    usable_gas = total_gas_liters * (1 - reserve_fraction)

    # Estimate average depth (recreational dives are multi-level, tech stays deeper)
    avg_depth_fraction = 0.55 if is_tech else 0.45
    avg_depth = max_depth * avg_depth_fraction

    # Average ambient pressure
    avg_ambient = 1 + avg_depth / 10

    # SAC rate (liters per minute at surface)
    # Tech divers typically have better air consumption
    base_sac = random.uniform(14, 17) if is_tech else random.uniform(16, 20)

    # Account for descent (higher consumption) and ascent (lower consumption)
    # Average consumption rate including all phases
    avg_consumption = base_sac * avg_ambient

    # Calculate duration
    duration_minutes = usable_gas / avg_consumption

    return duration_minutes


# Equipment sets - warm water and cold water configurations
# UDDF equipment types: mask, fins, suit, bcd, regulator, computer, camera, light, tank, weight, etc.
EQUIPMENT_SETS = {
    "warm_water": [
        # Exposure protection
        {"id": "suit_warm", "type": "suit", "name": "Mares Reef 3mm Shorty", "manufacturer": "Mares",
         "model": "Reef Shorty", "serial": "MR3S-2019-4521", "purchase_date": "2019-03-15",
         "notes": "3mm shorty wetsuit for tropical waters"},
        {"id": "boots_warm", "type": "boots", "name": "Cressi Low Boot 3mm", "manufacturer": "Cressi",
         "model": "Low Boot", "serial": "CLB3-2019-1122", "purchase_date": "2019-03-15",
         "notes": "Low-cut 3mm neoprene boots"},
        {"id": "gloves_warm", "type": "gloves", "name": "Mares Flexa Touch 2mm", "manufacturer": "Mares",
         "model": "Flexa Touch", "serial": "MFT2-2020-0892", "purchase_date": "2020-01-10",
         "notes": "Thin reef gloves for warm water"},
        # Mask & Fins
        {"id": "mask_main", "type": "mask", "name": "Scubapro Synergy Twin", "manufacturer": "Scubapro",
         "model": "Synergy Twin Trufit", "serial": "SST-2018-7823", "purchase_date": "2018-06-20",
         "notes": "Low-volume twin lens mask with Trufit skirt"},
        {"id": "fins_warm", "type": "fins", "name": "Mares Avanti Quattro+", "manufacturer": "Mares",
         "model": "Avanti Quattro+", "serial": "MAQ-2019-3345", "purchase_date": "2019-03-15",
         "notes": "Open heel paddle fins"},
        {"id": "snorkel", "type": "snorkel", "name": "Scubapro Spectra Dry", "manufacturer": "Scubapro",
         "model": "Spectra Dry", "serial": "SSD-2018-0091", "purchase_date": "2018-06-20",
         "notes": "Dry-top snorkel"},
        # BCD
        {"id": "bcd_travel", "type": "bcd", "name": "Scubapro Hydros Pro", "manufacturer": "Scubapro",
         "model": "Hydros Pro", "serial": "SHP-2020-5567", "purchase_date": "2020-02-28",
         "notes": "Travel BCD with Monprene construction, 18kg lift"},
        # Regulators
        {"id": "reg_primary", "type": "regulator", "name": "Scubapro MK25 EVO/A700", "manufacturer": "Scubapro",
         "model": "MK25 EVO/A700", "serial": "SMA-2019-8834", "purchase_date": "2019-05-10",
         "notes": "Primary regulator, balanced piston first stage, air-balanced second stage"},
        {"id": "reg_octo", "type": "regulator", "name": "Scubapro R195 Octopus", "manufacturer": "Scubapro",
         "model": "R195", "serial": "SR1-2019-8835", "purchase_date": "2019-05-10",
         "notes": "Backup second stage, high-viz yellow"},
        # Computer
        {"id": "computer_main", "type": "computer", "name": "Shearwater Perdix AI", "manufacturer": "Shearwater",
         "model": "Perdix AI", "serial": "SPAI-2021-12045", "purchase_date": "2021-01-15",
         "notes": "Air-integrated dive computer with multiple transmitter support"},
        {"id": "transmitter1", "type": "computer", "name": "Shearwater Swift Transmitter", "manufacturer": "Shearwater",
         "model": "Swift", "serial": "SSW-2021-22341", "purchase_date": "2021-01-15",
         "notes": "Tank 1 AI transmitter"},
        # Accessories
        {"id": "light_primary", "type": "light", "name": "BigBlue AL1200NP", "manufacturer": "BigBlue",
         "model": "AL1200NP", "serial": "BB12-2020-4456", "purchase_date": "2020-06-01",
         "notes": "1200 lumen primary dive light"},
        {"id": "smb", "type": "buoy", "name": "Halcyon Diver's Alert Marker", "manufacturer": "Halcyon",
         "model": "DAM", "serial": "HDAM-2019-0023", "purchase_date": "2019-03-15",
         "notes": "Surface marker buoy, orange, 1.4m"},
        {"id": "reel", "type": "reel", "name": "Halcyon Mini Reel", "manufacturer": "Halcyon",
         "model": "Mini Reel", "serial": "HMR-2019-0024", "purchase_date": "2019-03-15",
         "notes": "Finger spool with 30m line"},
        {"id": "knife", "type": "knife", "name": "Atomic Aquatics Ti6", "manufacturer": "Atomic Aquatics",
         "model": "Ti6", "serial": "AATI-2018-1123", "purchase_date": "2018-06-20",
         "notes": "Titanium dive knife with line cutter"},
        {"id": "camera", "type": "camera", "name": "Olympus TG-6 + Housing", "manufacturer": "Olympus",
         "model": "TG-6 with PT-059", "serial": "OTG6-2021-89012", "purchase_date": "2021-04-01",
         "notes": "Compact underwater camera system"},
    ],
    "cold_water": [
        # Exposure protection - Drysuit system
        {"id": "suit_dry", "type": "suit", "name": "Santi E.Motion+ Drysuit", "manufacturer": "Santi",
         "model": "E.Motion+", "serial": "SEM-2020-1892", "purchase_date": "2020-09-15",
         "notes": "Trilaminate drysuit with TEK zipper, custom fit"},
        {"id": "undersuit", "type": "undergarment", "name": "Santi BZ400X", "manufacturer": "Santi",
         "model": "BZ400X", "serial": "SBZ-2020-1893", "purchase_date": "2020-09-15",
         "notes": "400g insulation undersuit"},
        {"id": "undersuit_light", "type": "undergarment", "name": "Santi Flex 190", "manufacturer": "Santi",
         "model": "Flex 190", "serial": "SFL-2020-1894", "purchase_date": "2020-09-15",
         "notes": "Light insulation layer for layering"},
        {"id": "hood_cold", "type": "hood", "name": "Waterproof H1 5/7mm", "manufacturer": "Waterproof",
         "model": "H1", "serial": "WPH1-2020-0445", "purchase_date": "2020-09-15",
         "notes": "Cold water hood with bib, 5/7mm"},
        {"id": "gloves_dry", "type": "gloves", "name": "Santi Dry Gloves", "manufacturer": "Santi",
         "model": "Dry Gloves with Ring System", "serial": "SDG-2020-0446", "purchase_date": "2020-09-15",
         "notes": "Drysuit glove system with Si-Tech rings"},
        {"id": "boots_dry", "type": "boots", "name": "Rock Boots", "manufacturer": "Santi",
         "model": "Rock Boots", "serial": "SRB-2020-0447", "purchase_date": "2020-09-15",
         "notes": "Drysuit rock boots, integrated"},
        # Fins for drysuit
        {"id": "fins_cold", "type": "fins", "name": "Hollis F1 LT", "manufacturer": "Hollis",
         "model": "F1 LT", "serial": "HF1-2020-5567", "purchase_date": "2020-09-20",
         "notes": "Spring strap fins for dry boots"},
        # Technical BCD
        {"id": "bcd_tech", "type": "bcd", "name": "Halcyon Evolve Wing", "manufacturer": "Halcyon",
         "model": "Evolve 40lb Wing", "serial": "HEW-2020-3312", "purchase_date": "2020-10-01",
         "notes": "Backplate and wing system, 40lb single tank wing"},
        {"id": "backplate", "type": "bcd", "name": "Halcyon Stainless Backplate", "manufacturer": "Halcyon",
         "model": "Stainless Steel Backplate", "serial": "HSB-2020-3313", "purchase_date": "2020-10-01",
         "notes": "6lb stainless steel backplate"},
        {"id": "harness", "type": "bcd", "name": "Halcyon Cinch Harness", "manufacturer": "Halcyon",
         "model": "Cinch Quick-Adjust Harness", "serial": "HCH-2020-3314", "purchase_date": "2020-10-01",
         "notes": "Adjustable webbing harness"},
        # Cold water regulator
        {"id": "reg_cold", "type": "regulator", "name": "Apeks XTX200 Tungsten", "manufacturer": "Apeks",
         "model": "XTX200 Tungsten", "serial": "AXT-2020-7789", "purchase_date": "2020-10-15",
         "notes": "Cold water rated regulator, environmentally sealed"},
        {"id": "reg_cold_octo", "type": "regulator", "name": "Apeks XTX40 Octopus", "manufacturer": "Apeks",
         "model": "XTX40", "serial": "AX4-2020-7790", "purchase_date": "2020-10-15",
         "notes": "Cold water rated backup"},
        # Additional cold water gear
        {"id": "light_canister", "type": "light", "name": "Light Monkey 32W HID", "manufacturer": "Light Monkey",
         "model": "32W HID", "serial": "LM32-2021-0089", "purchase_date": "2021-03-01",
         "notes": "Canister light for cold water/cave diving"},
        {"id": "argon_system", "type": "tank", "name": "Argon Bottle System", "manufacturer": "DGX",
         "model": "13cf Argon Kit", "serial": "DGX13-2020-1234", "purchase_date": "2020-11-01",
         "notes": "Drysuit inflation argon system"},
        {"id": "stage_rigging", "type": "rigging", "name": "Stage Bottle Rigging Kit", "manufacturer": "Halcyon",
         "model": "Stage Kit", "serial": "HSK-2020-4456", "purchase_date": "2020-11-15",
         "notes": "Complete stage bottle rigging with bolt snaps"},
        {"id": "wetnotes", "type": "wetnotes", "name": "Halcyon Wet Notes", "manufacturer": "Halcyon",
         "model": "Wet Notes", "serial": "HWN-2020-0012", "purchase_date": "2020-10-01",
         "notes": "Underwater writing slate"},
    ]
}

# PADI Certifications with realistic progression dates
PADI_CERTIFICATIONS = [
    {
        "id": "cert_ow",
        "level": "Open Water Diver",
        "organization": "PADI",
        "cert_number": "1803US12345",
        "date": "2018-03-15",
        "instructor": "John Smith",
        "facility": "Blue Water Divers",
        "facility_number": "S-12345",
    },
    {
        "id": "cert_aow",
        "level": "Advanced Open Water Diver",
        "organization": "PADI",
        "cert_number": "1806US12346",
        "date": "2018-06-20",
        "instructor": "Maria Garcia",
        "facility": "Blue Water Divers",
        "facility_number": "S-12345",
    },
    {
        "id": "cert_rescue",
        "level": "Rescue Diver",
        "organization": "PADI",
        "cert_number": "1812US12347",
        "date": "2018-12-10",
        "instructor": "David Chen",
        "facility": "Aqua Adventures",
        "facility_number": "S-23456",
    },
    {
        "id": "cert_ean",
        "level": "Enriched Air Diver",
        "organization": "PADI",
        "cert_number": "1903US12348",
        "date": "2019-03-05",
        "instructor": "Maria Garcia",
        "facility": "Blue Water Divers",
        "facility_number": "S-12345",
    },
    {
        "id": "cert_deep",
        "level": "Deep Diver",
        "organization": "PADI",
        "cert_number": "1905US12349",
        "date": "2019-05-22",
        "instructor": "James Wilson",
        "facility": "Deep Blue Diving",
        "facility_number": "S-34567",
    },
    {
        "id": "cert_wreck",
        "level": "Wreck Diver",
        "organization": "PADI",
        "cert_number": "1908US12350",
        "date": "2019-08-14",
        "instructor": "Robert Taylor",
        "facility": "Wreck Diving Specialists",
        "facility_number": "S-45678",
    },
    {
        "id": "cert_msd",
        "level": "Master Scuba Diver",
        "organization": "PADI",
        "cert_number": "2001US12351",
        "date": "2020-01-30",
        "instructor": "David Chen",
        "facility": "Aqua Adventures",
        "facility_number": "S-23456",
    },
    {
        "id": "cert_tec40",
        "level": "Tec 40",
        "organization": "PADI",
        "cert_number": "2009US12352",
        "date": "2020-09-18",
        "instructor": "Michael Brown",
        "facility": "Technical Diving Center",
        "facility_number": "S-56789",
    },
    {
        "id": "cert_tec45",
        "level": "Tec 45",
        "organization": "PADI",
        "cert_number": "2103US12353",
        "date": "2021-03-25",
        "instructor": "Michael Brown",
        "facility": "Technical Diving Center",
        "facility_number": "S-56789",
    },
    {
        "id": "cert_drysuit",
        "level": "Dry Suit Diver",
        "organization": "PADI",
        "cert_number": "2010US12354",
        "date": "2020-10-05",
        "instructor": "Sarah Johnson",
        "facility": "Cold Water Diving",
        "facility_number": "S-67890",
    },
    {
        "id": "cert_sidemount",
        "level": "Sidemount Diver",
        "organization": "PADI",
        "cert_number": "2106US12355",
        "date": "2021-06-12",
        "instructor": "Michael Brown",
        "facility": "Technical Diving Center",
        "facility_number": "S-56789",
    },
]

# Trip destinations with associated dive centers and nearby sites
# Each destination maps to dive center indices and site indices for consistency
TRIP_DESTINATIONS = [
    {
        "name": "Cozumel Adventure",
        "location": "Cozumel, Mexico",
        "center_indices": [0, 1],  # Aqua Safari, Scuba Du
        "site_indices": [1, 2, 3, 4],  # Palancar Gardens, Santa Rosa Wall, Columbia Deep, Paso del Cedral
        "resort_name": "Casa del Mar Cozumel",
    },
    {
        "name": "Red Sea Expedition",
        "location": "Sharm el-Sheikh, Egypt",
        "center_indices": [2],  # Camel Dive Club
        "site_indices": [10, 11, 12],  # SS Thistlegorm, Ras Mohammed, Jackson Reef
        "liveaboard_name": "MY Blue Force One",
    },
    {
        "name": "Thailand Similan Safari",
        "location": "Similan Islands, Thailand",
        "center_indices": [4, 5],  # Sea Bees, Khao Lak Scuba
        "site_indices": [15, 16],  # Richelieu Rock, Koh Bon Pinnacle
        "liveaboard_name": "MV Sawasdee Fasai",
    },
    {
        "name": "Sipadan Dreams",
        "location": "Sipadan, Malaysia",
        "center_indices": [6],  # Sipadan Scuba
        "site_indices": [20, 21],  # Barracuda Point, Turtle Tomb
        "resort_name": "Sipadan Mabul Resort",
    },
    {
        "name": "Palau Shark Safari",
        "location": "Palau",
        "center_indices": [7, 8],  # Sams Tours, Fish n Fins
        "site_indices": [22, 23],  # Blue Corner, German Channel
        "resort_name": "Palau Pacific Resort",
    },
    {
        "name": "Great Barrier Reef Explorer",
        "location": "Cairns, Australia",
        "center_indices": [9, 10],  # Pro Dive Cairns, Mike Ball
        "site_indices": [24, 25],  # SS Yongala, Cod Hole
        "liveaboard_name": "Spirit of Freedom",
    },
    {
        "name": "Malta Wreck Week",
        "location": "Malta",
        "center_indices": [11],  # Maltaqua
        "site_indices": [29, 30],  # MV Um El Faroud, Blue Grotto Malta
        "resort_name": "The Westin Dragonara Resort",
    },
    {
        "name": "Cyprus Zenobia Experience",
        "location": "Larnaca, Cyprus",
        "center_indices": [12],  # Cydive
        "site_indices": [28],  # MV Zenobia
        "resort_name": "Golden Bay Beach Hotel",
    },
    {
        "name": "Florida Keys Diving",
        "location": "Key Largo, Florida",
        "center_indices": [13, 14],  # Rainbow Reef, Abyss
        "site_indices": [31, 32, 33],  # Molasses Reef, Spiegel Grove, Blue Heron Bridge
        "resort_name": "Ocean Pointe Suites",
    },
    {
        "name": "Maldives Liveaboard",
        "location": "Maldives",
        "center_indices": [15],  # Maldives Scuba Tours
        "site_indices": [38, 39, 40],  # Manta Point, Fish Head, Maaya Thila
        "liveaboard_name": "MV Carpe Vita",
    },
    {
        "name": "Galapagos Ultimate",
        "location": "Galapagos, Ecuador",
        "center_indices": [16],  # Scuba Iguana
        "site_indices": [41, 42, 43],  # Darwin Arch, Wolf Island, Gordon Rocks
        "liveaboard_name": "Galapagos Aggressor III",
    },
    {
        "name": "Bonaire Shore Diving",
        "location": "Bonaire",
        "center_indices": [17],  # Buddy Dive Resort
        "site_indices": [8, 9],  # 1000 Steps, Salt Pier
        "resort_name": "Buddy Dive Resort",
    },
    {
        "name": "Dahab Freediving & Scuba",
        "location": "Dahab, Egypt",
        "center_indices": [3],  # Emperor Divers (Hurghada, but close enough)
        "site_indices": [13, 14],  # Blue Hole Dahab, Elphinstone Reef
        "resort_name": "Le Meridien Dahab Resort",
    },
    {
        "name": "Komodo Dragons & Diving",
        "location": "Komodo, Indonesia",
        "center_indices": [4],  # Reusing Thailand center as placeholder
        "site_indices": [17],  # Manta Point Komodo
        "liveaboard_name": "MV Mermaid I",
    },
    {
        "name": "Bali Diving Escape",
        "location": "Bali, Indonesia",
        "center_indices": [4],  # Reusing
        "site_indices": [18, 19],  # Crystal Bay, USAT Liberty
        "resort_name": "Alam Batu Beach Bungalow Resort",
    },
    {
        "name": "California Kelp Forests",
        "location": "Monterey, California",
        "center_indices": [19],  # Blue Water Divers
        "site_indices": [34, 35],  # Monterey Breakwater, Catalina Casino Point
        "resort_name": "Monterey Plaza Hotel",
    },
    {
        "name": "Cenote Cave Diving",
        "location": "Riviera Maya, Mexico",
        "center_indices": [0, 1],  # Cozumel centers
        "site_indices": [36, 37],  # Cenote Dos Ojos, Cenote Angelita
        "resort_name": "Grand Palladium White Sand",
    },
    {
        "name": "Cayman Islands Week",
        "location": "Grand Cayman",
        "center_indices": [18],  # Stuart Coves (Bahamas, but close)
        "site_indices": [5, 6, 7],  # Stingray City, Bloody Bay Wall, USS Kittiwake
        "resort_name": "The Ritz-Carlton Grand Cayman",
    },
    {
        "name": "Belize Blue Hole",
        "location": "Belize",
        "center_indices": [18],  # Reusing
        "site_indices": [0],  # Blue Hole
        "resort_name": "Hamanasi Adventure & Dive Resort",
    },
    {
        "name": "New Zealand Adventure",
        "location": "Northland, New Zealand",
        "center_indices": [9],  # Reusing Australia
        "site_indices": [27],  # Poor Knights Islands
        "resort_name": "Paihia Beach Resort",
    },
]

# Tank configurations for different dive types
# volume in liters, working_pressure in bar
TANK_CONFIGS = {
    "recreational_single": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "air", "role": "main"},
    ],
    "recreational_nitrox": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "ean32", "role": "main"},
    ],
    "recreational_al80": [
        {"volume": 11.1, "working_pressure": 207, "mix_id": "air", "role": "main"},
    ],
    "tec_single_stage": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "ean32", "role": "main"},
        {"volume": 11.1, "working_pressure": 207, "mix_id": "ean50", "role": "stage"},
    ],
    "tec_doubles": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "air", "role": "main"},
        {"volume": 12.0, "working_pressure": 232, "mix_id": "air", "role": "main"},
    ],
    "tec_doubles_deco": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "tx21_35", "role": "main"},
        {"volume": 12.0, "working_pressure": 232, "mix_id": "tx21_35", "role": "main"},
        {"volume": 11.1, "working_pressure": 207, "mix_id": "ean50", "role": "stage"},
        {"volume": 7.0, "working_pressure": 232, "mix_id": "oxygen", "role": "stage"},
    ],
    "tec_deep": [
        {"volume": 12.0, "working_pressure": 232, "mix_id": "tx18_45", "role": "main"},
        {"volume": 12.0, "working_pressure": 232, "mix_id": "tx18_45", "role": "main"},
        {"volume": 11.1, "working_pressure": 207, "mix_id": "ean50", "role": "stage"},
        {"volume": 7.0, "working_pressure": 232, "mix_id": "oxygen", "role": "stage"},
    ],
    "sidemount": [
        {"volume": 11.1, "working_pressure": 207, "mix_id": "ean32", "role": "main"},
        {"volume": 11.1, "working_pressure": 207, "mix_id": "ean32", "role": "main"},
    ],
}


def map_equipment_type(script_type: str, item_name: str = "") -> str:
    """Map script equipment types to Submersion enum values."""
    # Check for drysuit explicitly (it uses 'suit' type but is a drysuit)
    if script_type == "suit" and "drysuit" in item_name.lower():
        return "drysuit"

    mapping = {
        "suit": "wetsuit",
        "boots": "boots",
        "gloves": "gloves",
        "mask": "mask",
        "fins": "fins",
        "snorkel": "other",
        "bcd": "bcd",
        "regulator": "regulator",
        "computer": "computer",
        "light": "light",
        "buoy": "smb",
        "reel": "reel",
        "knife": "knife",
        "camera": "camera",
        "undergarment": "other",
        "tank": "tank",
        "rigging": "other",
        "wetnotes": "other",
        "hood": "hood",
    }
    return mapping.get(script_type, "other")


def map_cert_level(padi_level: str) -> str:
    """Map PADI certification names to Submersion CertificationLevel enum values."""
    mapping = {
        "Open Water Diver": "openWater",
        "Advanced Open Water Diver": "advancedOpenWater",
        "Rescue Diver": "rescue",
        "Enriched Air Diver": "nitrox",
        "Deep Diver": "other",  # Recreational specialty, not technical decompression
        "Wreck Diver": "wreck",
        "Master Scuba Diver": "other",  # Highest recreational rating, not professional Divemaster
        "Divemaster": "diveMaster",  # Actual professional-level certification
        "Tec 40": "techDiver",
        "Tec 45": "techDiver",
        "Tec 50": "decompression",  # Tec 50 involves planned deco diving
        "Dry Suit Diver": "other",
        "Sidemount Diver": "sidemount",
    }
    return mapping.get(padi_level, "other")


def calculate_service_date(purchase_date: str) -> str:
    """Calculate a realistic last service date based on purchase date."""
    if not purchase_date:
        return "2024-01-15"

    try:
        purchase = datetime.strptime(purchase_date, "%Y-%m-%d")
        # Service every year, last service is most recent anniversary
        now = datetime(2025, 1, 1)  # Reference date for test data
        years_owned = (now - purchase).days // 365
        if years_owned > 0:
            last_service = purchase.replace(year=purchase.year + years_owned)
            return last_service.strftime("%Y-%m-%d")
        else:
            return purchase_date  # Not yet due for service
    except ValueError:
        return "2024-01-15"


def get_tank_config_type(tank_configs: List[Dict]) -> str:
    """Determine the tank configuration type for consumption logic."""
    main_tanks = [tc for tc in tank_configs if tc.get("role") == "main"]
    stage_tanks = [tc for tc in tank_configs if tc.get("role") == "stage"]

    if len(main_tanks) == 2 and len(stage_tanks) == 0:
        # Check if it's sidemount (AL80s) or backmount doubles (steel 12L)
        volumes = [tc["volume"] for tc in main_tanks]
        if all(v < 12 for v in volumes):  # AL80s are ~11.1L
            return "sidemount"
        return "doubles"
    elif len(main_tanks) == 2 and len(stage_tanks) > 0:
        return "doubles_staged"
    elif len(main_tanks) == 1 and len(stage_tanks) > 0:
        return "single_staged"
    else:
        return "single"


def calculate_mod(o2_fraction: float, max_ppo2: float = 1.4) -> float:
    """Calculate Maximum Operating Depth for a gas mix."""
    if o2_fraction <= 0:
        return 0
    return ((max_ppo2 / o2_fraction) - 1) * 10


def generate_dive_profile(
    max_depth: float,
    duration_minutes: int,
    surface_temp: float,
    bottom_temp: float,
    tank_configs: List[Dict],
    is_tech: bool = False,
    gf_low: float = 0.35,
    gf_high: float = 0.85,
    site_type: str = "reef",
    thermocline_profile: Dict = None,
    tissue_state: TissueState = None,
) -> Tuple[List[Dict], List[Dict], TissueState]:
    """Generate realistic depth, temperature, and pressure profiles using Bühlmann ZHL-16C.

    Features:
    - Smooth curved descent/ascent using easing functions
    - Multi-level profiles for recreational dives
    - Site-specific depth patterns (wall, wreck, drift, reef, cenote, manta, shallow)
    - Thermocline temperature modeling with smooth transitions
    - Tissue compartment tracking with gradient factor support
    - Proper deco ceiling respect during ascent
    - Realistic gas consumption that won't exceed available supply
    - Optional tissue state input for repetitive diving

    Site-specific patterns:
    - wall: Steep descent to max depth, hug wall with minimal horizontal movement
    - wreck: Descend to deck, explore exterior/interior at various levels
    - drift: Gradual depth changes following current, less precise depth control
    - cenote: Sharp thermocline, layer exploration
    - manta: Hover at cleaning station depth (12-18m), minimal movement
    - shallow: Stay in 3-10m range, extended bottom times

    Consumption patterns by configuration:
    - Single tank: straightforward consumption
    - Sidemount: alternate between tanks every ~15-20 bar for balance
    - Doubles (manifolded): consume both tanks equally
    - Staged deco: use bottom gas until ascent, then switch to appropriate deco gas based on MOD

    Returns:
        Tuple of (profile_points, gas_switches, final_tissue_state)
    """

    profile_points = []
    sample_interval = 10  # 10-second samples for detailed profiles
    total_seconds = duration_minutes * 60

    # Descent/ascent rates
    descent_rate = 15  # m/min - slightly slower for realism
    ascent_rate = 9  # m/min - standard safe ascent rate

    # Calculate phase durations
    descent_time_seconds = (max_depth / descent_rate) * 60
    safety_stop_depth = 5
    safety_stop_duration = 180  # 3 minutes

    # Determine tank configuration type
    config_type = get_tank_config_type(tank_configs)

    # Initialize tank states with realistic SAC rates
    tank_states = []
    base_sac = random.uniform(13, 16) if is_tech else random.uniform(15, 19)

    # For manifolded doubles, use same starting pressure
    manifold_start_pressure = random.randint(200, 210)

    for i, tank in enumerate(tank_configs):
        mix_id = tank.get("mix_id", "air")
        gas_mix = next((m for m in GAS_MIXES if m["id"] == mix_id), {"o2": 0.21, "he": 0.0})
        mod = calculate_mod(gas_mix["o2"])

        if config_type in ["doubles", "doubles_staged"] and tank.get("role") == "main":
            start_pressure_bar = manifold_start_pressure
            sac_rate = base_sac
        else:
            start_pressure_bar = random.randint(198, 210)
            sac_rate = base_sac + random.uniform(-1.5, 1.5)

        tank_states.append({
            "start_pressure": start_pressure_bar * 100000,
            "current_pressure": start_pressure_bar * 100000,
            "sac_rate": sac_rate,
            "role": tank.get("role", "main"),
            "mix_id": mix_id,
            "o2": gas_mix["o2"],
            "he": gas_mix.get("he", 0.0),
            "mod": mod,
            "volume": tank["volume"],
        })

    # Initialize tissue state for decompression tracking
    # If tissue_state is provided (repetitive diving), use it; otherwise create fresh
    if tissue_state is not None:
        tissue = tissue_state
    else:
        tissue = TissueState()

    # Get primary gas mix for tissue calculations
    main_tank_indices = [i for i, tc in enumerate(tank_configs) if tc.get("role") == "main"]
    stage_tank_indices = [i for i, tc in enumerate(tank_configs) if tc.get("role") == "stage"]

    if main_tank_indices:
        primary_gas = tank_states[main_tank_indices[0]]
    else:
        primary_gas = tank_states[0] if tank_states else {"o2": 0.21, "he": 0.0}

    # Sidemount tracking
    sidemount_active_tank = 0
    sidemount_switch_threshold = random.uniform(12, 18)
    last_sidemount_switch_pressure = tank_states[main_tank_indices[0]]["current_pressure"] if main_tank_indices else 0

    # Gas switches tracking
    gas_switches = []
    active_stage_tank = None
    current_gas = primary_gas

    # Sort stage tanks by O2 content (lower O2 first for deeper use)
    stage_tank_indices_sorted = sorted(
        stage_tank_indices,
        key=lambda i: tank_states[i]["o2"]
    )

    # Generate site-specific depth profiles
    level_depths = []

    if site_type == "wall":
        # Wall dives: Drop to max depth quickly, stay deep, ascend along wall
        if is_tech:
            level_depths = [max_depth]  # Tech wall dive at constant deep depth
        else:
            # Recreational wall: deep, mid-wall, then shallow
            level_depths = [max_depth, max_depth * 0.6, max_depth * 0.35]

    elif site_type == "wreck":
        # Wreck dives: Descend to deck, explore various levels
        deck_depth = max_depth * 0.85  # Main deck usually not at max
        level_depths = [
            max_depth,  # Initial drop to max (superstructure/bottom)
            deck_depth,  # Main exploration at deck level
            deck_depth * 0.7,  # Shallower superstructure
        ]

    elif site_type == "drift":
        # Drift dives: More gradual, current-driven depth changes
        # Less control, so depths vary more organically
        num_levels = random.randint(3, 5)
        level_depths = [max_depth * (1.0 - i * 0.15) + random.uniform(-2, 2)
                        for i in range(num_levels)]
        level_depths = [max(5, d) for d in level_depths]

    elif site_type == "cenote":
        # Cenote dives: Layer exploration, often pause at halocline
        halocline_depth = 12  # Typical halocline depth
        if max_depth > halocline_depth:
            level_depths = [max_depth, halocline_depth + 2, halocline_depth - 2, 6]
        else:
            level_depths = [max_depth, max_depth * 0.5]

    elif site_type == "manta":
        # Manta dives: Hover at cleaning station, minimal depth variation
        cleaning_station_depth = min(max_depth, random.uniform(12, 18))
        level_depths = [cleaning_station_depth]  # Stay at one depth waiting

    elif site_type == "shallow":
        # Shallow dives: Stay in shallow range, extended time
        level_depths = [min(max_depth, random.uniform(6, 10))]

    elif site_type == "cavern":
        # Cavern/overhead: Careful depth management, layer exploration
        level_depths = [max_depth, max_depth * 0.7, max_depth * 0.4]

    else:
        # Default reef profile: classic multi-level recreational
        if not is_tech and max_depth > 15:
            num_levels = random.randint(2, 3)
            for lvl in range(num_levels):
                depth_factor = 1.0 - (lvl * 0.25)
                level_depth = max_depth * depth_factor * random.uniform(0.9, 1.0)
                level_depths.append(max(8, level_depth))
        else:
            level_depths = [max_depth]

    # Ensure we have at least one level
    if not level_depths:
        level_depths = [max_depth]

    # Random seed for depth variation
    variation_seed = random.uniform(0, 1000)

    current_time = 0
    current_depth = 0.0
    dive_phase = "descent"  # descent, bottom, ascent
    level_index = 0
    level_start_time = descent_time_seconds
    first_stop_depth = None  # Track for GF slope calculation
    safety_stop_start_time = None  # Track when safety stop begins

    # Calculate approximate bottom time per level
    estimated_ascent_time = (max_depth / ascent_rate) * 60 + safety_stop_duration
    available_bottom_time = total_seconds - descent_time_seconds - estimated_ascent_time
    time_per_level = max(60, available_bottom_time / len(level_depths))

    # Maximum allowed dive time (safety limit to prevent infinite loops)
    max_dive_time = total_seconds + 1800  # Allow up to 30 extra minutes for deco

    while current_depth >= 0:
        # =================================================================
        # PHASE-BASED DEPTH CALCULATION
        # =================================================================

        # Force ascent if we've exceeded planned bottom time
        if current_time > total_seconds and dive_phase == "bottom":
            dive_phase = "ascent"

        if dive_phase == "descent":
            # Smooth curved descent using easing function
            if current_time < descent_time_seconds:
                progress = current_time / descent_time_seconds
                eased_progress = ease_in_out_cubic(progress)
                target_depth = level_depths[0] if level_depths else max_depth
                current_depth = target_depth * eased_progress
            else:
                dive_phase = "bottom"
                level_start_time = current_time
                current_depth = level_depths[0] if level_depths else max_depth

        elif dive_phase == "bottom":
            target_depth = level_depths[level_index] if level_index < len(level_depths) else level_depths[-1]

            # Time spent at current level
            time_at_level = current_time - level_start_time

            # Check if we should move to next level or start ascent
            if time_at_level >= time_per_level:
                if level_index < len(level_depths) - 1:
                    # Move to next (shallower) level
                    level_index += 1
                    level_start_time = current_time
                    target_depth = level_depths[level_index]
                else:
                    # Start ascent
                    dive_phase = "ascent"

            if dive_phase == "bottom":
                # Add natural terrain-following variation
                variation = depth_variation(current_time, amplitude=1.5, seed=variation_seed)
                current_depth = target_depth + variation

                # Smooth transition between levels
                if level_index > 0:
                    prev_level_depth = level_depths[level_index - 1]
                    transition_progress = min(1.0, time_at_level / 60)  # 1 minute transition
                    if transition_progress < 1.0:
                        eased = ease_in_out_cubic(transition_progress)
                        current_depth = prev_level_depth + (target_depth - prev_level_depth) * eased + variation * transition_progress

                # Clamp to reasonable bounds
                current_depth = max(3, min(max_depth + 2, current_depth))

        elif dive_phase == "ascent":
            # Calculate ceiling from tissue loading
            ceiling = tissue.gf_ceiling(gf_low, gf_high, current_depth, first_stop_depth)

            if first_stop_depth is None and ceiling > 0:
                # Record first stop depth for GF slope
                first_stop_depth = math.ceil(ceiling / 3) * 3  # Round up to nearest 3m

            # Maximum ascent per interval (respecting 9m/min limit)
            max_ascent = (ascent_rate / 60) * sample_interval

            # Determine target depth (respecting ceiling)
            if ceiling > 0.5:
                # There's a deco obligation - must stay above ceiling
                # Use 2m safety margin to account for tissue loading variations
                min_safe_depth = ceiling + 2.0
                # Required stop depth (3m increments, above min_safe_depth)
                required_stop = max(3, math.ceil(min_safe_depth / 3) * 3)

                if current_depth > min_safe_depth + max_ascent * 2:
                    # Well below ceiling - safe to ascend at normal rate
                    current_depth = current_depth - max_ascent
                elif current_depth > required_stop:
                    # Approaching stop - slow ascent to required stop depth
                    current_depth = max(required_stop, current_depth - max_ascent * 0.5)
                else:
                    # At or below required stop - hold at required stop with variation
                    current_depth = required_stop + random.uniform(-0.2, 0.2)
            else:
                # No deco obligation (ceiling cleared)
                if current_depth > safety_stop_depth + 1:
                    # Ascending to safety stop
                    current_depth = max(safety_stop_depth, current_depth - max_ascent)
                elif current_depth > 0.5:
                    # At safety stop - do 3 min stop before surfacing
                    if safety_stop_start_time is None:
                        safety_stop_start_time = current_time
                    time_at_safety = current_time - safety_stop_start_time
                    if time_at_safety < safety_stop_duration:
                        current_depth = safety_stop_depth + random.uniform(-0.3, 0.3)
                    else:
                        # Final ascent to surface
                        current_depth = max(0, current_depth - max_ascent)

        current_depth = max(0, round(current_depth, 2))

        # =================================================================
        # TISSUE LOADING UPDATE
        # =================================================================
        tissue.update(current_depth, sample_interval, current_gas["o2"], current_gas.get("he", 0.0))

        # =================================================================
        # TEMPERATURE CALCULATION (with thermocline modeling)
        # =================================================================
        if thermocline_profile is not None:
            # Use realistic thermocline model
            current_temp = calculate_temperature_at_depth(
                current_depth, thermocline_profile, surface_temp, variation_seed
            )
        else:
            # Fallback to simple linear gradient
            temp_gradient = (surface_temp - bottom_temp) / max(max_depth, 1)
            current_temp = surface_temp - (temp_gradient * current_depth)
            current_temp += random.uniform(-0.2, 0.2)
        current_temp_kelvin = round(current_temp + 273.15, 2)

        # =================================================================
        # GAS CONSUMPTION AND TANK SELECTION
        # =================================================================
        is_ascending = dive_phase == "ascent"
        ambient_pressure = 1 + (current_depth / 10)

        # Activity-based SAC modifier
        if dive_phase == "descent":
            sac_modifier = 1.15  # Higher consumption during descent
        elif is_ascending:
            sac_modifier = 0.90  # Lower consumption during controlled ascent
        else:
            # Bottom phase - varies with activity
            sac_modifier = 1.0 + depth_variation(current_time, amplitude=0.1, seed=variation_seed + 500)

        tanks_to_consume = []

        if is_ascending and stage_tank_indices:
            # Check for deco gas switch
            best_stage = None
            for idx in stage_tank_indices_sorted:
                ts = tank_states[idx]
                if current_depth <= ts["mod"] - 3 and ts["current_pressure"] > 50 * 100000:
                    if best_stage is None or ts["o2"] > tank_states[best_stage]["o2"]:
                        best_stage = idx

            if best_stage is not None:
                if active_stage_tank != best_stage:
                    if best_stage not in [gs["tank"] for gs in gas_switches]:
                        gas_switches.append({
                            "time": current_time,
                            "tank": best_stage,
                            "depth": current_depth,
                            "mix_id": tank_states[best_stage]["mix_id"]
                        })
                    active_stage_tank = best_stage
                    current_gas = tank_states[best_stage]
                tanks_to_consume = [best_stage]
            else:
                active_stage_tank = None
                current_gas = primary_gas
                if config_type == "sidemount":
                    tanks_to_consume = [main_tank_indices[sidemount_active_tank % len(main_tank_indices)]]
                elif config_type in ["doubles", "doubles_staged"]:
                    tanks_to_consume = main_tank_indices
                else:
                    tanks_to_consume = main_tank_indices[:1] if main_tank_indices else [0]
        else:
            active_stage_tank = None
            current_gas = primary_gas

            if config_type == "sidemount":
                current_main_idx = main_tank_indices[sidemount_active_tank % len(main_tank_indices)]
                current_pressure_bar = tank_states[current_main_idx]["current_pressure"] / 100000
                last_pressure_bar = last_sidemount_switch_pressure / 100000

                if last_pressure_bar - current_pressure_bar >= sidemount_switch_threshold:
                    sidemount_active_tank = (sidemount_active_tank + 1) % len(main_tank_indices)
                    last_sidemount_switch_pressure = tank_states[main_tank_indices[sidemount_active_tank]]["current_pressure"]

                tanks_to_consume = [main_tank_indices[sidemount_active_tank % len(main_tank_indices)]]
            elif config_type in ["doubles", "doubles_staged"]:
                tanks_to_consume = main_tank_indices
            else:
                tanks_to_consume = main_tank_indices[:1] if main_tank_indices else [0]

        # Apply gas consumption
        for tank_idx in tanks_to_consume:
            ts = tank_states[tank_idx]
            if ts["current_pressure"] > 50 * 100000:  # Reserve pressure ~50 bar
                consumption = ts["sac_rate"] * ambient_pressure * sac_modifier

                if config_type in ["doubles", "doubles_staged"] and len(tanks_to_consume) == 2:
                    consumption = consumption / 2

                volume = ts["volume"]
                pressure_drop = (consumption * sample_interval / 60) / volume
                pressure_drop_pascal = pressure_drop * 100000
                ts["current_pressure"] -= pressure_drop_pascal
                ts["current_pressure"] = max(ts["current_pressure"], 40 * 100000)

        # =================================================================
        # BUILD PROFILE POINT
        # =================================================================
        point = {
            "divetime": current_time,
            "depth": current_depth,
            "temperature": current_temp_kelvin,
            "tankpressures": []
        }

        for i, ts in enumerate(tank_states):
            point["tankpressures"].append({
                "tank_index": i,
                "pressure": int(ts["current_pressure"])
            })

        profile_points.append(point)
        current_time += sample_interval

        # Check if we've surfaced
        if current_depth <= 0.1 and dive_phase == "ascent":
            break

        # Safety limit to prevent infinite loops
        if current_time > max_dive_time:
            break

        # Emergency gas check - if main tanks are low, start ascending
        main_tanks_pressure = sum(
            tank_states[i]["current_pressure"] for i in main_tank_indices
        ) if main_tank_indices else 0
        min_reserve = 60 * 100000 * len(main_tank_indices)  # 60 bar per tank

        if main_tanks_pressure < min_reserve and dive_phase == "bottom":
            dive_phase = "ascent"

    # Ensure we end at surface
    if profile_points and profile_points[-1]["depth"] > 0:
        final_point = {
            "divetime": current_time,
            "depth": 0,
            "temperature": round(surface_temp + 273.15, 2),
            "tankpressures": []
        }
        for i, ts in enumerate(tank_states):
            final_point["tankpressures"].append({
                "tank_index": i,
                "pressure": int(ts["current_pressure"])
            })
        profile_points.append(final_point)

    # Set final pressures
    for i, ts in enumerate(tank_states):
        tank_configs[i]["start_pressure_actual"] = int(ts["start_pressure"])
        tank_configs[i]["end_pressure_actual"] = int(ts["current_pressure"])

    return profile_points, gas_switches, tissue


def prettify_xml(elem):
    """Return a pretty-printed XML string."""
    rough_string = ET.tostring(elem, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")


def generate_trips(start_date: datetime, num_trips: int = 20) -> List[Dict]:
    """Generate trip data with dates spread across the dive date range."""
    trips = []

    # Space trips throughout the date range (about 2018-2025)
    # Each trip is 4-7 days
    date_cursor = start_date + timedelta(days=random.randint(14, 30))

    for i in range(num_trips):
        dest = TRIP_DESTINATIONS[i % len(TRIP_DESTINATIONS)]
        duration = random.randint(4, 7)

        trip = {
            "id": f"trip{i+1:03d}",
            "name": dest["name"],
            "location": dest["location"],
            "start_date": date_cursor,
            "end_date": date_cursor + timedelta(days=duration - 1),
            "center_indices": dest["center_indices"],
            "site_indices": dest.get("site_indices", []),
            "resort_name": dest.get("resort_name"),
            "liveaboard_name": dest.get("liveaboard_name"),
        }
        trips.append(trip)

        # Move to next trip (skip 2-6 weeks between trips)
        date_cursor = trip["end_date"] + timedelta(days=random.randint(14, 45))

    return trips


def generate_uddf(num_dives: int = 500, output_path: str = "test_data.uddf"):
    """Generate UDDF 3.2.1 compliant file."""

    random.seed(42)

    # Generate buddies
    buddies = []
    for i in range(50):
        first = random.choice(BUDDY_FIRST_NAMES)
        last = random.choice(BUDDY_LAST_NAMES)
        buddies.append({
            "id": f"buddy{i+1:03d}",
            "firstname": first,
            "lastname": last,
            "email": f"{first.lower()}.{last.lower()}@email.com"
        })

    # Generate trips
    start_date = datetime(2018, 1, 1)
    trips = generate_trips(start_date, num_trips=20)

    # Create root element with namespace
    root = ET.Element("uddf")
    root.set("xmlns", UDDF_NS)
    root.set("version", "3.2.1")

    # Generator
    gen = ET.SubElement(root, "generator")
    ET.SubElement(gen, "name").text = "Submersion UDDF Test Generator"
    ET.SubElement(gen, "version").text = "1.0.0"
    ET.SubElement(gen, "datetime").text = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    # Gas definitions
    gasdefs = ET.SubElement(root, "gasdefinitions")
    for mix in GAS_MIXES:
        m = ET.SubElement(gasdefs, "mix")
        m.set("id", mix["id"])
        ET.SubElement(m, "name").text = mix["name"]
        ET.SubElement(m, "o2").text = f"{mix['o2']:.2f}"
        if mix["he"] > 0:
            ET.SubElement(m, "he").text = f"{mix['he']:.2f}"

    # Dive sites
    divesites = ET.SubElement(root, "divesite")
    for i, site in enumerate(DIVE_SITES):
        s = ET.SubElement(divesites, "site")
        s.set("id", f"site{i+1:03d}")
        ET.SubElement(s, "name").text = site["name"]
        geo = ET.SubElement(s, "geography")
        ET.SubElement(geo, "location").text = site["region"]
        ET.SubElement(geo, "province").text = site["region"]
        ET.SubElement(geo, "country").text = site["country"]
        ET.SubElement(geo, "latitude").text = str(site["lat"])
        ET.SubElement(geo, "longitude").text = str(site["lon"])
        if site.get("max_depth"):
            ET.SubElement(s, "maximumdepth").text = str(site["max_depth"])
        # UDDF sitedata for water type
        sitedata = ET.SubElement(s, "sitedata")
        ET.SubElement(sitedata, "watertype").text = site.get("water_type", "saltwater")

    # Dive operators (centers) - Standard UDDF format
    # Note: Submersion also uses custom format in applicationdata/submersion/divecenters
    diveops = ET.SubElement(root, "diveoperator")
    for i, center in enumerate(DIVE_CENTERS):
        db = ET.SubElement(diveops, "divebase")
        db.set("id", f"center_{i+1:03d}")  # Matches Submersion's expected format
        ET.SubElement(db, "name").text = center["name"]
        addr = ET.SubElement(db, "address")
        ET.SubElement(addr, "street").text = f"Main Street, {center['city']}"
        ET.SubElement(addr, "city").text = center["city"]
        ET.SubElement(addr, "country").text = center["country"]
        contact = ET.SubElement(db, "contact")
        ET.SubElement(contact, "phone").text = center["phone"]
        ET.SubElement(contact, "email").text = center["email"]
        # Add website
        website_domain = center["email"].split("@")[1] if "@" in center["email"] else "example.com"
        ET.SubElement(contact, "url").text = f"https://www.{website_domain}"
        geo = ET.SubElement(db, "geography")
        ET.SubElement(geo, "latitude").text = str(center["lat"])
        ET.SubElement(geo, "longitude").text = str(center["lon"])

    # Divers (owner and buddies)
    diver_section = ET.SubElement(root, "diver")

    owner = ET.SubElement(diver_section, "owner")
    owner.set("id", "owner")
    personal = ET.SubElement(owner, "personal")
    ET.SubElement(personal, "firstname").text = "Test"
    ET.SubElement(personal, "lastname").text = "Diver"
    ET.SubElement(personal, "birthdate").text = "1985-07-22"
    # Add address for completeness
    address = ET.SubElement(personal, "address")
    ET.SubElement(address, "street").text = "123 Ocean Drive"
    ET.SubElement(address, "city").text = "San Diego"
    ET.SubElement(address, "postcode").text = "92109"
    ET.SubElement(address, "state").text = "California"
    ET.SubElement(address, "country").text = "USA"
    # Contact info
    contact = ET.SubElement(owner, "contact")
    ET.SubElement(contact, "email").text = "test.diver@email.com"
    ET.SubElement(contact, "phone").text = "+1 619 555 0123"

    # Add certifications to owner
    for cert in PADI_CERTIFICATIONS:
        cert_elem = ET.SubElement(owner, "certification")
        cert_elem.set("id", cert["id"])
        ET.SubElement(cert_elem, "level").text = cert["level"]
        ET.SubElement(cert_elem, "organization").text = cert["organization"]
        ET.SubElement(cert_elem, "certificationnumber").text = cert["cert_number"]
        ET.SubElement(cert_elem, "issuedate").text = cert["date"]
        # Add instructor info
        instructor = ET.SubElement(cert_elem, "instructor")
        ET.SubElement(instructor, "name").text = cert["instructor"]
        # Add facility info
        facility = ET.SubElement(cert_elem, "facility")
        ET.SubElement(facility, "name").text = cert["facility"]
        ET.SubElement(facility, "facilitynumber").text = cert["facility_number"]

    # Add equipment sets to owner
    equipment = ET.SubElement(owner, "equipment")

    # Create equipment configuration groups
    for set_name, items in EQUIPMENT_SETS.items():
        # Create a configuration for this set
        config = ET.SubElement(equipment, "equipmentconfiguration")
        config.set("id", f"config_{set_name}")
        ET.SubElement(config, "name").text = f"{set_name.replace('_', ' ').title()} Set"

        for item in items:
            # Create individual equipment piece
            piece = ET.SubElement(equipment, "piece")
            piece.set("id", item["id"])

            ET.SubElement(piece, "name").text = item["name"]
            ET.SubElement(piece, "equipmenttype").text = item["type"]
            ET.SubElement(piece, "manufacturer").text = item["manufacturer"]
            ET.SubElement(piece, "model").text = item["model"]
            if item.get("serial"):
                ET.SubElement(piece, "serialnumber").text = item["serial"]
            if item.get("purchase_date"):
                ET.SubElement(piece, "dateofpurchase").text = item["purchase_date"]
            if item.get("notes"):
                ET.SubElement(piece, "notes").text = item["notes"]

            # Link to configuration
            link = ET.SubElement(config, "link")
            link.set("ref", item["id"])

    for buddy in buddies:
        b = ET.SubElement(diver_section, "buddy")
        b.set("id", buddy["id"])
        personal = ET.SubElement(b, "personal")
        ET.SubElement(personal, "firstname").text = buddy["firstname"]
        ET.SubElement(personal, "lastname").text = buddy["lastname"]
        contact = ET.SubElement(b, "contact")
        ET.SubElement(contact, "email").text = buddy["email"]

    # Note: Dive trips are written AFTER the dive loop to filter out empty trips

    # Profile data (dives)
    profiledata = ET.SubElement(root, "profiledata")
    repgroup = ET.SubElement(profiledata, "repetitiongroup")
    repgroup.set("id", "rg1")

    # Generate dives
    start_date = datetime(2018, 1, 1)
    current_date = start_date
    dive_number = 1

    dive_types = [
        ("recreational_single", 0.25),
        ("recreational_nitrox", 0.25),
        ("recreational_al80", 0.15),
        ("tec_single_stage", 0.12),
        ("tec_doubles", 0.08),
        ("tec_doubles_deco", 0.07),
        ("sidemount", 0.05),
        ("tec_deep", 0.03),
    ]

    # Track trip dive counts for multiple dives per trip day
    trip_dive_counts = {trip["id"]: 0 for trip in trips}

    # Initialize dive session for repetitive diving tracking
    dive_session = DiveSession()

    for dive_idx in range(num_dives):
        # Pick dive type
        r = random.random()
        cumulative = 0
        dive_type = "recreational_single"
        for dt, prob in dive_types:
            cumulative += prob
            if r <= cumulative:
                dive_type = dt
                break

        tank_config = [tc.copy() for tc in TANK_CONFIGS[dive_type]]

        # Check if we should do a trip dive (40% chance if there's an upcoming trip)
        active_trip = None
        site = None
        site_idx = None
        center = None
        center_idx = None

        # Find next trip that hasn't had enough dives yet
        for trip in trips:
            # Target ~3-4 dives per day for 4-7 day trips = 12-28 dives per trip
            max_dives_per_trip = random.randint(12, 20)
            if trip_dive_counts[trip["id"]] < max_dives_per_trip:
                if trip["start_date"] > current_date:
                    # Jump to this trip's start date
                    if random.random() < 0.4:  # 40% chance to do a trip dive
                        current_date = trip["start_date"] + timedelta(
                            days=random.randint(0, (trip["end_date"] - trip["start_date"]).days)
                        )
                        active_trip = trip
                        break
                elif trip["start_date"] <= current_date <= trip["end_date"]:
                    active_trip = trip
                    break

        if active_trip:
            # Pick site from trip's site list
            valid_site_indices = [i for i in active_trip["site_indices"] if i < len(DIVE_SITES)]
            if valid_site_indices:
                site_idx = random.choice(valid_site_indices)
                site = DIVE_SITES[site_idx]
            # Pick center from trip's center list
            valid_center_indices = [i for i in active_trip["center_indices"] if i < len(DIVE_CENTERS)]
            if valid_center_indices:
                center_idx = random.choice(valid_center_indices)
                center = DIVE_CENTERS[center_idx]
            trip_dive_counts[active_trip["id"]] += 1

        # Fall back to random site/center if not in a trip
        if site is None:
            site = random.choice(DIVE_SITES)
            site_idx = DIVE_SITES.index(site)
        if center is None:
            center = random.choice(DIVE_CENTERS)
            center_idx = DIVE_CENTERS.index(center)

        num_buddies = random.randint(1, 3)
        dive_buddies = random.sample(buddies, num_buddies)

        is_tech = "tec" in dive_type or "sidemount" in dive_type

        # Determine max depth based on dive type
        if "deep" in dive_type:
            max_depth = random.uniform(50, min(75, site.get("max_depth", 75)))
        elif "tec" in dive_type:
            max_depth = random.uniform(35, min(50, site.get("max_depth", 50)))
        else:
            max_depth = random.uniform(12, min(30, site.get("max_depth", 30)))

        # Calculate realistic duration based on gas supply and NDL
        gas_limited_duration = calculate_gas_duration(max_depth, tank_config, is_tech)

        # Calculate NDL at max depth (using a temporary tissue state)
        temp_tissue = TissueState()
        ndl_at_depth = temp_tissue.ndl(max_depth, o2_fraction=0.21, gf_high=0.85)

        if is_tech:
            # Tech dives can exceed NDL (planned deco), but limited by gas
            # Add time for deco stops (rough estimate: 1 min per 3m of depth over 20m)
            deco_time_estimate = max(0, (max_depth - 20) / 3) * 2
            target_duration = random.uniform(35, 55) + deco_time_estimate
            duration = int(min(gas_limited_duration * 0.85, target_duration))
        else:
            # Recreational dives: stay within NDL and gas limits
            # Use 80% of limits for safety margin
            max_safe_duration = min(gas_limited_duration * 0.80, ndl_at_depth * 0.85)
            # Add some randomness but stay within limits
            target_duration = random.uniform(30, 50)
            duration = int(min(max_safe_duration, target_duration))

        # Ensure minimum reasonable dive time
        duration = max(20, duration)

        # Get site type and thermocline profile
        site_type = get_site_type(site)
        thermocline_profile = get_thermocline_profile(site)

        # Surface temperature from thermocline profile
        temp_range = thermocline_profile["surface_temp"]
        surface_temp = random.uniform(temp_range[0], temp_range[1])

        # Bottom temp calculated via thermocline model (for reference in XML)
        bottom_temp = calculate_temperature_at_depth(
            max_depth, thermocline_profile, surface_temp, random.uniform(0, 1000)
        )

        air_temp = surface_temp + random.uniform(-2, 5)
        air_temp_kelvin = air_temp + 273.15

        # Generate dive conditions based on site type
        conditions = generate_dive_conditions(site, site_type)

        # Determine dive datetime - ensure chronological order for same-day dives
        if dive_session.last_dive_end is not None and dive_session.last_dive_end.date() == current_date.date():
            # Same day as last dive - schedule after previous dive ends + surface interval
            min_surface_interval = random.randint(60, 180)  # 1-3 hours between dives
            dive_datetime = dive_session.last_dive_end + timedelta(minutes=min_surface_interval)

            # If that pushes us past reasonable diving hours, move to next day
            if dive_datetime.hour >= 18:
                current_date += timedelta(days=1)
                hour = random.choice([7, 8, 9, 10])
                dive_datetime = current_date.replace(hour=hour, minute=random.choice([0, 15, 30, 45]))
        else:
            # First dive of the day - pick a morning or afternoon start time
            hour = random.choice([7, 8, 9, 10, 11, 14, 15, 16])
            minute = random.choice([0, 15, 30, 45])
            dive_datetime = current_date.replace(hour=hour, minute=minute)

        # Check for new diving day and handle surface interval
        if dive_session.is_new_day(dive_datetime):
            dive_session.start_new_day()
            surface_interval_minutes = None
        else:
            surface_interval_minutes = dive_session.surface_interval_minutes(dive_datetime)
            # Only apply positive surface intervals
            if surface_interval_minutes > 0:
                dive_session.apply_surface_interval(surface_interval_minutes)
            else:
                surface_interval_minutes = None

        # For repetitive dives, use session tissue state with reduced NDL
        if dive_session.dive_count_today > 0 and not is_tech:
            # Repetitive dive: calculate reduced NDL
            ndl_at_depth = dive_session.get_adjusted_ndl(max_depth, gf_high=0.85)
            max_safe_duration = min(gas_limited_duration * 0.80, ndl_at_depth * 0.85)
            target_duration = random.uniform(25, 45)  # Slightly shorter for repetitive
            duration = int(min(max_safe_duration, target_duration))
            duration = max(20, duration)

        # Generate profile with site-specific patterns and thermocline
        profile, gas_switches, final_tissue = generate_dive_profile(
            max_depth=max_depth,
            duration_minutes=duration,
            surface_temp=surface_temp,
            bottom_temp=bottom_temp,
            tank_configs=tank_config,
            is_tech=is_tech,
            site_type=site_type,
            thermocline_profile=thermocline_profile,
            tissue_state=dive_session.tissue if dive_session.dive_count_today > 0 else None,
        )

        # Update session tissue state for next dive
        dive_session.tissue = final_tissue

        # Generate marine life sightings
        sightings = generate_sightings(site, site_type)

        # Generate rating (weighted toward higher ratings)
        rating = random.choices([3, 4, 5], weights=[0.15, 0.35, 0.5])[0]

        # Generate notes
        buddy_name = dive_buddies[0]["firstname"] if dive_buddies else "buddy"
        notes = generate_dive_notes(site, site_type, sightings, buddy_name, conditions)

        # Build dive element
        dive = ET.SubElement(repgroup, "dive")
        dive.set("id", f"dive{dive_idx+1:04d}")

        # informationbeforedive
        before = ET.SubElement(dive, "informationbeforedive")
        for buddy in dive_buddies:
            link = ET.SubElement(before, "link")
            link.set("ref", buddy["id"])
        site_link = ET.SubElement(before, "link")
        site_link.set("ref", f"site{site_idx+1:03d}")
        center_link = ET.SubElement(before, "link")
        center_link.set("ref", f"center_{center_idx+1:03d}")
        # Link to trip if this dive is part of one
        if active_trip:
            trip_link = ET.SubElement(before, "link")
            trip_link.set("ref", f"trip_{active_trip['id']}")
        ET.SubElement(before, "divenumber").text = str(dive_number)
        ET.SubElement(before, "datetime").text = dive_datetime.strftime("%Y-%m-%dT%H:%M:%S")
        ET.SubElement(before, "airtemperature").text = f"{air_temp_kelvin:.2f}"

        # Entry type (parser expects this in informationbeforedive)
        ET.SubElement(before, "entrytype").text = conditions["entry_method"]

        # Altitude (0 for sea level dives, higher for highland sites)
        altitude = site.get("altitude", 0)
        ET.SubElement(before, "altitude").text = str(altitude)

        # Surface pressure in Pascals (1 atm = 101325 Pa, adjusted for altitude)
        surface_pressure_pa = 101325 * (1 - (altitude / 44330)) ** 5.255 if altitude > 0 else 101325
        ET.SubElement(before, "surfacepressure").text = str(int(surface_pressure_pa))

        equipused = ET.SubElement(before, "equipmentused")
        weight = random.uniform(4, 8)
        ET.SubElement(equipused, "leadquantity").text = f"{weight:.1f}"

        # Determine which equipment set to use based on water temperature
        is_cold_water = site["country"] == "New Zealand" or \
                        (site["country"] == "USA" and "California" in site.get("region", ""))
        equipment_set_name = "cold_water" if is_cold_water else "warm_water"
        equipment_items = EQUIPMENT_SETS[equipment_set_name]

        # Add equipment references
        for item in equipment_items:
            equip_ref = ET.SubElement(equipused, "equipmentref")
            equip_ref.text = item["id"]

        # tankdata elements with IDs (critical for multi-tank pressure refs)
        for i, tc in enumerate(tank_config):
            tank_id = f"dive{dive_idx+1:04d}_tank{i+1}"
            tankdata = ET.SubElement(dive, "tankdata")
            tankdata.set("id", tank_id)

            mix_link = ET.SubElement(tankdata, "link")
            mix_link.set("ref", tc["mix_id"])

            # UDDF uses cubic meters, but liters is common practice
            ET.SubElement(tankdata, "tankvolume").text = f"{tc['volume']:.2f}"

            start_p = tc.get("start_pressure_actual", 200 * 100000)
            end_p = tc.get("end_pressure_actual", 50 * 100000)
            ET.SubElement(tankdata, "tankpressurebegin").text = str(int(start_p))
            ET.SubElement(tankdata, "tankpressureend").text = str(int(end_p))

        # samples
        samples = ET.SubElement(dive, "samples")

        active_tank = 0
        switch_times = {gs["time"]: gs for gs in gas_switches}

        for point in profile:
            wp = ET.SubElement(samples, "waypoint")
            ET.SubElement(wp, "depth").text = f"{point['depth']:.2f}"
            ET.SubElement(wp, "divetime").text = str(point["divetime"])

            # Multi-tank pressure with ref attributes (KEY FOR MULTI-TANK SUPPORT)
            for tp in point["tankpressures"]:
                tank_idx = tp["tank_index"]
                tank_id = f"dive{dive_idx+1:04d}_tank{tank_idx+1}"
                tp_elem = ET.SubElement(wp, "tankpressure")
                tp_elem.set("ref", tank_id)
                tp_elem.text = str(tp["pressure"])

            ET.SubElement(wp, "temperature").text = f"{point['temperature']:.2f}"

            # Gas switch
            if point["divetime"] in switch_times:
                gs = switch_times[point["divetime"]]
                switchmix = ET.SubElement(wp, "switchmix")
                sm_link = ET.SubElement(switchmix, "link")
                sm_link.set("ref", gs["mix_id"])

        # informationafterdive
        after = ET.SubElement(dive, "informationafterdive")
        ET.SubElement(after, "greatestdepth").text = f"{max_depth:.2f}"
        avg_depth = sum(p["depth"] for p in profile) / len(profile)
        ET.SubElement(after, "averagedepth").text = f"{avg_depth:.2f}"
        ET.SubElement(after, "diveduration").text = str(duration * 60)
        ET.SubElement(after, "lowesttemperature").text = f"{bottom_temp + 273.15:.2f}"
        ET.SubElement(after, "visibility").text = str(conditions["visibility"])
        ET.SubElement(after, "currentstrength").text = conditions["current_strength"]

        # Rating with nested ratingvalue (parser expects this structure)
        rating_elem = ET.SubElement(after, "rating")
        ET.SubElement(rating_elem, "ratingvalue").text = str(rating)

        # Water type (salt/fresh)
        water_type = "fresh" if conditions["water_type"] == "freshwater" else "salt"
        ET.SubElement(after, "watertype").text = water_type

        # Surface interval for repetitive dives
        if surface_interval_minutes is not None and surface_interval_minutes < 720:  # Less than 12 hours
            ET.SubElement(after, "surfaceinterval").text = str(int(surface_interval_minutes * 60))

        # Swell height for ocean dives (parser expects swellheight)
        if conditions["swell_height"] > 0:
            ET.SubElement(after, "swellheight").text = f"{conditions['swell_height']:.1f}"

        # Exit method (parser expects exittype; entry is already in informationbeforedive)
        ET.SubElement(after, "exittype").text = conditions["exit_method"]

        # Current direction if there's current
        if conditions["current_direction"]:
            ET.SubElement(after, "currentdirection").text = conditions["current_direction"]

        # Dive notes (generated based on site, sightings, conditions)
        if is_tech and len(tank_config) > 1:
            notes += f" {len(tank_config)}-tank tech dive with AI transmitters."
        ET.SubElement(after, "notes").text = notes

        # Marine life sightings (parser expects sightings with speciesref/count attributes)
        if sightings:
            sightings_elem = ET.SubElement(after, "sightings")
            for sighting in sightings:
                sighting_elem = ET.SubElement(sightings_elem, "sighting")
                # Create a species ref ID from species name (normalize to valid ID)
                species_id = f"species_{sighting['species'].lower().replace(' ', '_').replace('-', '_')}"
                sighting_elem.set("speciesref", species_id)
                sighting_elem.set("count", str(sighting["count"]))

        # Tags (based on site type, dive characteristics)
        dive_tags = []
        if site_type == "wall":
            dive_tags.append("wall")
        elif site_type == "wreck":
            dive_tags.append("wreck")
        elif site_type == "drift":
            dive_tags.append("drift")
        elif site_type == "cenote":
            dive_tags.append("cave")
        if max_depth > 30:
            dive_tags.append("deep")
        if is_tech:
            dive_tags.append("technical")
        if conditions["current_strength"] in ["moderate", "strong"]:
            dive_tags.append("current")

        if dive_tags:
            tags_elem = ET.SubElement(after, "tags")
            for tag_name in dive_tags:
                tagref = ET.SubElement(tags_elem, "tagref")
                tagref.text = f"tag_{tag_name}"

        # Record dive end for session tracking
        dive_end_time = dive_datetime + timedelta(minutes=duration)
        dive_session.record_dive_end(dive_end_time, {
            "max_depth": max_depth,
            "duration": duration,
            "site": site["name"],
        })

        dive_number += 1

        # Move date forward for next dive (if not in a trip, or sometimes within a trip)
        if active_trip is None:
            if random.random() > 0.3:
                current_date += timedelta(days=random.randint(1, 14))
        else:
            # Multiple dives per day during trips (30% chance to move to next day)
            if random.random() < 0.3:
                current_date += timedelta(days=1)
                if current_date > active_trip["end_date"]:
                    current_date = active_trip["end_date"]

        if (dive_idx + 1) % 50 == 0:
            print(f"Generated {dive_idx + 1} / {num_dives} dives...")

    # Now write dive trips (only those with dives)
    # We need to insert them before profiledata in the XML tree
    trips_with_dives = [t for t in trips if trip_dive_counts.get(t["id"], 0) > 0]

    # Find profiledata element and insert trips before it
    profiledata_elem = root.find("profiledata")
    profiledata_index = list(root).index(profiledata_elem) if profiledata_elem is not None else len(list(root))

    for i, trip in enumerate(trips_with_dives):
        divetrip = ET.Element("divetrip")
        divetrip.set("id", f"trip_{trip['id']}")
        ET.SubElement(divetrip, "name").text = trip["name"]

        dateoftrip = ET.SubElement(divetrip, "dateoftrip")
        startdate = ET.SubElement(dateoftrip, "startdate")
        ET.SubElement(startdate, "datetime").text = trip["start_date"].strftime("%Y-%m-%dT00:00:00")
        enddate = ET.SubElement(dateoftrip, "enddate")
        ET.SubElement(enddate, "datetime").text = trip["end_date"].strftime("%Y-%m-%dT23:59:59")

        geo = ET.SubElement(divetrip, "geography")
        ET.SubElement(geo, "location").text = trip["location"]

        notes_text = f"Dive trip to {trip['location']}."
        if trip.get("resort_name"):
            notes_text += f" Staying at {trip['resort_name']}."
        if trip.get("liveaboard_name"):
            notes_text += f" Aboard {trip['liveaboard_name']}."
        ET.SubElement(divetrip, "notes").text = notes_text

        root.insert(profiledata_index + i, divetrip)

    # Application data section for Submersion-specific extensions
    appdata = ET.SubElement(root, "applicationdata")
    submersion = ET.SubElement(appdata, "submersion")
    submersion.set("xmlns", SUBMERSION_NS)

    # Trip extended data (resort/liveaboard names - not in UDDF standard)
    # Only include trips that actually have dives
    trips_with_extended = [t for t in trips_with_dives if t.get("resort_name") or t.get("liveaboard_name")]
    if trips_with_extended:
        tripext = ET.SubElement(submersion, "tripextended")
        for trip in trips_with_extended:
            trip_elem = ET.SubElement(tripext, "trip")
            trip_elem.set("tripref", f"trip_{trip['id']}")
            if trip.get("resort_name"):
                ET.SubElement(trip_elem, "resortname").text = trip["resort_name"]
            if trip.get("liveaboard_name"):
                ET.SubElement(trip_elem, "liveaboardname").text = trip["liveaboard_name"]

    # Dive centers in Submersion's expected format
    divecenters_elem = ET.SubElement(submersion, "divecenters")
    for i, center in enumerate(DIVE_CENTERS):
        center_elem = ET.SubElement(divecenters_elem, "center")
        center_elem.set("id", f"center_{i+1:03d}")
        ET.SubElement(center_elem, "name").text = center["name"]
        ET.SubElement(center_elem, "location").text = center["city"]
        ET.SubElement(center_elem, "latitude").text = str(center["lat"])
        ET.SubElement(center_elem, "longitude").text = str(center["lon"])
        ET.SubElement(center_elem, "country").text = center["country"]
        ET.SubElement(center_elem, "phone").text = center["phone"]
        ET.SubElement(center_elem, "email").text = center["email"]
        # Add website
        website_domain = center["email"].split("@")[1] if "@" in center["email"] else "example.com"
        ET.SubElement(center_elem, "website").text = f"https://www.{website_domain}"
        # Add some affiliations for realism
        affiliations = []
        if "Egypt" in center["country"] or "Thailand" in center["country"]:
            affiliations.append("PADI")
        if "USA" in center["country"]:
            affiliations.append("PADI")
            affiliations.append("SSI")
        if "Australia" in center["country"]:
            affiliations.append("PADI")
            affiliations.append("SSI")
        if affiliations:
            ET.SubElement(center_elem, "affiliations").text = ",".join(affiliations)
        # Rating
        ET.SubElement(center_elem, "rating").text = str(random.uniform(4.0, 5.0))
        ET.SubElement(center_elem, "notes").text = f"Dive center in {center['city']}, {center['country']}"

    # Equipment in Submersion's expected format
    equipment_elem = ET.SubElement(submersion, "equipment")
    for set_name, items in EQUIPMENT_SETS.items():
        for item in items:
            item_elem = ET.SubElement(equipment_elem, "item")
            item_elem.set("id", item["id"])
            ET.SubElement(item_elem, "name").text = item["name"]
            ET.SubElement(item_elem, "type").text = map_equipment_type(item["type"], item["name"])
            ET.SubElement(item_elem, "brand").text = item["manufacturer"]
            ET.SubElement(item_elem, "model").text = item["model"]
            if item.get("serial"):
                ET.SubElement(item_elem, "serialnumber").text = item["serial"]
            if item.get("purchase_date"):
                ET.SubElement(item_elem, "purchasedate").text = item["purchase_date"]
            # Add service tracking for regulators and BCDs
            if item["type"] in ["regulator", "bcd"]:
                ET.SubElement(item_elem, "lastservicedate").text = calculate_service_date(item.get("purchase_date", ""))
                ET.SubElement(item_elem, "serviceintervaldays").text = "365"
            ET.SubElement(item_elem, "status").text = "active"
            if item.get("notes"):
                ET.SubElement(item_elem, "notes").text = item["notes"]

    # Equipment Sets in Submersion's expected format
    # Groups equipment items into logical sets (warm water, cold water)
    equipmentsets_elem = ET.SubElement(submersion, "equipmentsets")
    for set_name, items in EQUIPMENT_SETS.items():
        set_elem = ET.SubElement(equipmentsets_elem, "set")
        set_elem.set("id", f"set_{set_name}")
        ET.SubElement(set_elem, "name").text = set_name.replace("_", " ").title()
        ET.SubElement(set_elem, "description").text = f"Equipment configuration for {set_name.replace('_', ' ')} diving"
        items_elem = ET.SubElement(set_elem, "items")
        for item in items:
            itemref = ET.SubElement(items_elem, "itemref")
            itemref.text = item["id"]

    # Certifications in Submersion's expected format
    certs_elem = ET.SubElement(submersion, "certifications")
    for cert in PADI_CERTIFICATIONS:
        cert_elem = ET.SubElement(certs_elem, "cert")
        cert_elem.set("id", cert["id"])
        ET.SubElement(cert_elem, "name").text = cert["level"]
        ET.SubElement(cert_elem, "agency").text = "padi"  # lowercase enum value
        ET.SubElement(cert_elem, "level").text = map_cert_level(cert["level"])
        ET.SubElement(cert_elem, "cardnumber").text = cert["cert_number"]
        ET.SubElement(cert_elem, "issuedate").text = cert["date"]
        ET.SubElement(cert_elem, "instructorname").text = cert["instructor"]
        # Add facility number as instructor number for reference
        if cert.get("facility_number"):
            ET.SubElement(cert_elem, "instructornumber").text = cert["facility_number"]

    # Write file
    tree = ET.ElementTree(root)
    with open(output_path, 'wb') as f:
        tree.write(f, encoding='utf-8', xml_declaration=True)

    # Pretty print version (optional, larger file)
    # with open(output_path, 'w', encoding='utf-8') as f:
    #     f.write(prettify_xml(root))

    # Count dives per trip
    trip_dives_total = sum(trip_dive_counts.values())

    # Count equipment
    total_equipment = sum(len(items) for items in EQUIPMENT_SETS.values())

    print(f"\nGenerated UDDF 3.2.1 compliant file: {output_path}")
    print(f"- {num_dives} dives ({trip_dives_total} on trips)")
    print(f"- {len(trips_with_dives)} trips (4-7 days each)")
    print(f"- {len(DIVE_SITES)} dive sites with GPS")
    print(f"- {len(DIVE_CENTERS)} dive centers")
    print(f"- {len(buddies)} buddies")
    print(f"- {total_equipment} equipment items in {len(EQUIPMENT_SETS)} sets")
    print(f"- {len(PADI_CERTIFICATIONS)} certifications (PADI)")
    print(f"- Equipment sets: {', '.join(EQUIPMENT_SETS.keys())}")
    print(f"- Multi-tank configs with AI pressure refs")
    print(f"\nTrip breakdown:")
    for trip in trips_with_dives:
        count = trip_dive_counts[trip["id"]]
        dates = f"{trip['start_date'].strftime('%Y-%m-%d')} to {trip['end_date'].strftime('%Y-%m-%d')}"
        print(f"  - {trip['name']}: {count} dives ({dates})")
    print(f"\nKey features for multi-tank testing:")
    print(f"- <tankdata id='...'> with unique IDs per tank")
    print(f"- <tankpressure ref='...'> linking to tank IDs")
    print(f"- Multiple pressure readings per waypoint for multi-tank dives")
    print(f"- <divetrip> elements with dive links")


if __name__ == "__main__":
    import sys

    num_dives = 500
    output_path = "/Users/ericgriffin/Downloads/submersion_multitank_500dives.uddf"

    if len(sys.argv) > 1:
        num_dives = int(sys.argv[1])
    if len(sys.argv) > 2:
        output_path = sys.argv[2]

    generate_uddf(num_dives, output_path)
