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
from typing import List, Dict, Tuple, Optional
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


def generate_dive_profile(
    max_depth: float,
    duration_minutes: int,
    surface_temp: float,
    bottom_temp: float,
    tank_configs: List[Dict],
    is_tech: bool = False
) -> Tuple[List[Dict], List[Dict]]:
    """Generate realistic depth, temperature, and pressure profiles."""

    profile_points = []
    sample_interval = 60  # 1-minute samples (UDDF uses seconds)
    total_seconds = duration_minutes * 60

    # Calculate descent and ascent phases
    descent_rate = 18  # m/min
    ascent_rate = 9  # m/min

    descent_time = (max_depth / descent_rate) * 60
    ascent_time = (max_depth / ascent_rate) * 60

    safety_stop_depth = 5
    safety_stop_duration = 180

    # Tech dives have deco stops
    deco_stops = []
    if is_tech and max_depth > 40:
        if max_depth > 60:
            deco_stops = [(21, 180), (15, 180), (12, 180), (9, 300), (6, 600)]
        elif max_depth > 50:
            deco_stops = [(15, 120), (9, 180), (6, 300)]
        else:
            deco_stops = [(9, 120), (6, 180)]

    bottom_time = total_seconds - descent_time - ascent_time - safety_stop_duration
    for stop in deco_stops:
        bottom_time -= stop[1]
    bottom_time = max(bottom_time, 60)

    # Initialize tank states
    tank_states = []
    for tank in tank_configs:
        start_pressure_bar = random.randint(190, 210)
        tank_states.append({
            "start_pressure": start_pressure_bar * 100000,  # Pascal
            "current_pressure": start_pressure_bar * 100000,
            "sac_rate": random.uniform(15, 22),  # L/min at surface
            "active": tank.get("role") == "main",
        })

    current_time = 0
    current_depth = 0
    current_tank_index = 0

    # Find first main tank
    for i, tc in enumerate(tank_configs):
        if tc.get("role") == "main":
            current_tank_index = i
            break

    gas_switches = []

    while current_time <= total_seconds:
        # Calculate current depth
        if current_time < descent_time:
            progress = current_time / descent_time
            current_depth = max_depth * progress
        elif current_time < descent_time + bottom_time:
            variation = random.uniform(-2, 2)
            current_depth = max_depth + variation
            current_depth = max(0, min(max_depth + 3, current_depth))
        else:
            time_since_ascent = current_time - descent_time - bottom_time

            in_stop = False
            cumulative_stop = 0
            stop_depth = 0

            for stop in deco_stops:
                if time_since_ascent < cumulative_stop + stop[1]:
                    if time_since_ascent >= cumulative_stop:
                        in_stop = True
                        stop_depth = stop[0]

                        # Gas switch logic for tech dives
                        if stop[0] <= 21 and len(tank_configs) > 2:
                            for i, tc in enumerate(tank_configs):
                                if tc.get("role") == "stage" and i != current_tank_index:
                                    mix = next((m for m in GAS_MIXES if m["id"] == tc["mix_id"]), None)
                                    if mix and mix["o2"] >= 0.50:
                                        if i not in [gs["tank"] for gs in gas_switches]:
                                            gas_switches.append({
                                                "time": current_time,
                                                "tank": i,
                                                "depth": stop_depth,
                                                "mix_id": tc["mix_id"]
                                            })
                                            current_tank_index = i
                                            break
                        break
                cumulative_stop += stop[1]

            if in_stop:
                current_depth = stop_depth + random.uniform(-0.3, 0.3)
            else:
                ascent_progress = (time_since_ascent - cumulative_stop) / max(ascent_time - cumulative_stop, 1)
                remaining = stop_depth if deco_stops else max_depth

                if time_since_ascent > cumulative_stop:
                    safety_start = cumulative_stop + (safety_stop_depth / ascent_rate) * 60
                    if safety_start <= time_since_ascent < safety_start + safety_stop_duration:
                        current_depth = safety_stop_depth + random.uniform(-0.3, 0.3)
                    else:
                        target = remaining * (1 - ascent_progress)
                        current_depth = max(0, target)
                else:
                    current_depth = remaining

        current_depth = max(0, round(current_depth, 2))

        # Temperature with thermocline
        temp_gradient = (surface_temp - bottom_temp) / max(max_depth, 1)
        current_temp = surface_temp - (temp_gradient * current_depth)
        current_temp += random.uniform(-0.2, 0.2)
        current_temp_kelvin = round(current_temp + 273.15, 2)

        # Pressure consumption
        ambient_pressure = 1 + (current_depth / 10)

        for i, ts in enumerate(tank_states):
            if i == current_tank_index and ts["current_pressure"] > 50 * 100000:
                consumption = ts["sac_rate"] * ambient_pressure
                volume = tank_configs[i]["volume"]
                pressure_drop = (consumption * sample_interval / 60) / volume
                pressure_drop_pascal = pressure_drop * 100000
                ts["current_pressure"] -= pressure_drop_pascal
                ts["current_pressure"] = max(ts["current_pressure"], 40 * 100000)

        # Build profile point
        point = {
            "divetime": current_time,
            "depth": current_depth,
            "temperature": current_temp_kelvin,
            "tankpressures": []
        }

        # Add pressure for ALL tanks (simulating AI transmitters on each)
        for i, ts in enumerate(tank_states):
            point["tankpressures"].append({
                "tank_index": i,
                "pressure": int(ts["current_pressure"])
            })

        profile_points.append(point)
        current_time += sample_interval

    # Set final pressures
    for i, ts in enumerate(tank_states):
        tank_configs[i]["start_pressure_actual"] = int(ts["start_pressure"])
        tank_configs[i]["end_pressure_actual"] = int(ts["current_pressure"])

    return profile_points, gas_switches


def prettify_xml(elem):
    """Return a pretty-printed XML string."""
    rough_string = ET.tostring(elem, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")


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

    # Dive operators (centers)
    diveops = ET.SubElement(root, "diveoperator")
    for i, center in enumerate(DIVE_CENTERS):
        db = ET.SubElement(diveops, "divebase")
        db.set("id", f"center{i+1:03d}")
        ET.SubElement(db, "name").text = center["name"]
        addr = ET.SubElement(db, "address")
        ET.SubElement(addr, "city").text = center["city"]
        ET.SubElement(addr, "country").text = center["country"]
        contact = ET.SubElement(db, "contact")
        ET.SubElement(contact, "phone").text = center["phone"]
        ET.SubElement(contact, "email").text = center["email"]
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

    for buddy in buddies:
        b = ET.SubElement(diver_section, "buddy")
        b.set("id", buddy["id"])
        personal = ET.SubElement(b, "personal")
        ET.SubElement(personal, "firstname").text = buddy["firstname"]
        ET.SubElement(personal, "lastname").text = buddy["lastname"]
        contact = ET.SubElement(b, "contact")
        ET.SubElement(contact, "email").text = buddy["email"]

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
        site = random.choice(DIVE_SITES)
        site_idx = DIVE_SITES.index(site)
        center = random.choice(DIVE_CENTERS)
        center_idx = DIVE_CENTERS.index(center)

        num_buddies = random.randint(1, 3)
        dive_buddies = random.sample(buddies, num_buddies)

        is_tech = "tec" in dive_type or "sidemount" in dive_type

        if "deep" in dive_type:
            max_depth = random.uniform(50, min(75, site.get("max_depth", 75)))
            duration = random.randint(50, 90)
        elif "tec" in dive_type:
            max_depth = random.uniform(35, min(50, site.get("max_depth", 50)))
            duration = random.randint(45, 70)
        else:
            max_depth = random.uniform(12, min(30, site.get("max_depth", 30)))
            duration = random.randint(40, 60)

        # Temperature by region
        if site["country"] in ["Egypt", "Maldives"]:
            surface_temp = random.uniform(26, 30)
            bottom_temp = random.uniform(24, 27)
        elif site["country"] in ["Thailand", "Indonesia", "Malaysia"]:
            surface_temp = random.uniform(27, 31)
            bottom_temp = random.uniform(25, 28)
        elif site["country"] in ["USA"] and "California" in site.get("region", ""):
            surface_temp = random.uniform(14, 18)
            bottom_temp = random.uniform(10, 14)
        elif site["country"] == "New Zealand":
            surface_temp = random.uniform(15, 19)
            bottom_temp = random.uniform(12, 16)
        else:
            surface_temp = random.uniform(24, 28)
            bottom_temp = random.uniform(22, 26)

        air_temp = surface_temp + random.uniform(-2, 5)
        air_temp_kelvin = air_temp + 273.15

        profile, gas_switches = generate_dive_profile(
            max_depth, duration, surface_temp, bottom_temp, tank_config, is_tech
        )

        visibility = random.randint(5, 30)
        rating = random.randint(3, 5)
        currents = ["none", "light", "moderate", "strong"]
        current_strength = random.choice(currents)

        if random.random() > 0.3:
            current_date += timedelta(days=random.randint(1, 14))

        hour = random.choice([7, 8, 9, 10, 11, 14, 15, 16])
        minute = random.choice([0, 15, 30, 45])
        dive_datetime = current_date.replace(hour=hour, minute=minute)

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
        center_link.set("ref", f"center{center_idx+1:03d}")
        ET.SubElement(before, "divenumber").text = str(dive_number)
        ET.SubElement(before, "datetime").text = dive_datetime.strftime("%Y-%m-%dT%H:%M:%S")
        ET.SubElement(before, "airtemperature").text = f"{air_temp_kelvin:.2f}"

        equipused = ET.SubElement(before, "equipmentused")
        weight = random.uniform(4, 8)
        ET.SubElement(equipused, "leadquantity").text = f"{weight:.1f}"

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
        ET.SubElement(after, "visibility").text = str(visibility)
        ET.SubElement(after, "current").text = current_strength
        ET.SubElement(after, "rating").text = str(rating)

        dive_type_name = dive_type.replace("_", " ").title()
        notes = f"{dive_type_name} dive at {site['name']}. "
        notes += f"Vis ~{visibility}m, {current_strength} current."
        if is_tech and len(tank_config) > 1:
            notes += f" {len(tank_config)} tanks with AI transmitters."
        ET.SubElement(after, "notes").text = notes

        dive_number += 1

        if (dive_idx + 1) % 50 == 0:
            print(f"Generated {dive_idx + 1} / {num_dives} dives...")

    # Write file
    tree = ET.ElementTree(root)
    with open(output_path, 'wb') as f:
        tree.write(f, encoding='utf-8', xml_declaration=True)

    # Pretty print version (optional, larger file)
    # with open(output_path, 'w', encoding='utf-8') as f:
    #     f.write(prettify_xml(root))

    print(f"\nGenerated UDDF 3.2.1 compliant file: {output_path}")
    print(f"- {num_dives} dives")
    print(f"- {len(DIVE_SITES)} dive sites with GPS")
    print(f"- {len(DIVE_CENTERS)} dive centers")
    print(f"- {len(buddies)} buddies")
    print(f"- Multi-tank configs with AI pressure refs")
    print(f"\nKey features for multi-tank testing:")
    print(f"- <tankdata id='...'> with unique IDs per tank")
    print(f"- <tankpressure ref='...'> linking to tank IDs")
    print(f"- Multiple pressure readings per waypoint for multi-tank dives")


if __name__ == "__main__":
    import sys

    num_dives = 500
    output_path = "/Users/ericgriffin/Downloads/submersion_multitank_500dives.uddf"

    if len(sys.argv) > 1:
        num_dives = int(sys.argv[1])
    if len(sys.argv) > 2:
        output_path = sys.argv[2]

    generate_uddf(num_dives, output_path)
