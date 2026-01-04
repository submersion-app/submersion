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
        "Deep Diver": "decompression",
        "Wreck Diver": "wreck",
        "Master Scuba Diver": "diveMaster",
        "Tec 40": "techDiver",
        "Tec 45": "techDiver",
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
    is_tech: bool = False
) -> Tuple[List[Dict], List[Dict]]:
    """Generate realistic depth, temperature, and pressure profiles.

    Consumption patterns by configuration:
    - Single tank: straightforward consumption
    - Sidemount: alternate between tanks every ~15-20 bar for balance
    - Doubles (manifolded): consume both tanks equally
    - Staged deco: use bottom gas until ascent, then switch to appropriate deco gas based on MOD
    """

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

    # Determine tank configuration type
    config_type = get_tank_config_type(tank_configs)

    # Initialize tank states with realistic SAC rates
    # Tech divers typically have better SAC rates (12-18 L/min)
    # Recreational divers: 15-25 L/min
    tank_states = []
    base_sac = random.uniform(12, 18) if is_tech else random.uniform(15, 22)

    # For manifolded doubles, use same starting pressure for both main tanks
    # since they equalize through the manifold
    manifold_start_pressure = random.randint(198, 207)

    for i, tank in enumerate(tank_configs):
        # Get gas mix info for MOD calculation
        mix_id = tank.get("mix_id", "air")
        gas_mix = next((m for m in GAS_MIXES if m["id"] == mix_id), {"o2": 0.21, "he": 0})
        mod = calculate_mod(gas_mix["o2"])

        # Determine starting pressure based on config type
        if config_type in ["doubles", "doubles_staged"] and tank.get("role") == "main":
            # Manifolded tanks start at same pressure (equalized)
            start_pressure_bar = manifold_start_pressure
            # Same SAC rate for manifolded tanks (gas flows between them)
            sac_rate = base_sac
        else:
            # Independent tanks have slight variation
            start_pressure_bar = random.randint(195, 210)
            sac_rate = base_sac + random.uniform(-2, 2)

        tank_states.append({
            "start_pressure": start_pressure_bar * 100000,  # Pascal
            "current_pressure": start_pressure_bar * 100000,
            "sac_rate": sac_rate,
            "role": tank.get("role", "main"),
            "mix_id": mix_id,
            "o2": gas_mix["o2"],
            "mod": mod,
            "volume": tank["volume"],
        })

    current_time = 0
    current_depth = 0

    # Track active tank(s) - for sidemount, we alternate; for doubles, both active
    main_tank_indices = [i for i, tc in enumerate(tank_configs) if tc.get("role") == "main"]
    stage_tank_indices = [i for i, tc in enumerate(tank_configs) if tc.get("role") == "stage"]

    # For sidemount: start with first tank, track pressure difference for switching
    sidemount_active_tank = 0 if main_tank_indices else 0
    sidemount_switch_threshold = random.uniform(12, 18)  # Switch every 12-18 bar difference
    last_sidemount_switch_pressure = tank_states[main_tank_indices[0]]["current_pressure"] if main_tank_indices else 0

    # Track which tanks have been used (for gas switches display)
    gas_switches = []
    active_stage_tank = None  # Track current stage tank during deco

    # Sort stage tanks by O2 content (lower O2 = deeper MOD, use first)
    stage_tank_indices_sorted = sorted(
        stage_tank_indices,
        key=lambda i: tank_states[i]["o2"]
    )

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

        # Determine dive phase for gas selection
        is_ascending = current_time > descent_time + bottom_time
        ambient_pressure = 1 + (current_depth / 10)

        # ============================================================
        # REALISTIC MULTI-TANK GAS CONSUMPTION LOGIC
        # ============================================================

        # Determine which tanks to consume from based on configuration and dive phase
        tanks_to_consume = []

        if is_ascending and stage_tank_indices:
            # During ascent with stage tanks: check if we should switch to deco gas
            # Find the best stage tank for current depth (highest O2 that's within MOD)
            best_stage = None
            for idx in stage_tank_indices_sorted:
                ts = tank_states[idx]
                # Check if this gas is safe at current depth (with 3m safety margin)
                if current_depth <= ts["mod"] - 3 and ts["current_pressure"] > 50 * 100000:
                    # Prefer higher O2 content for faster deco
                    if best_stage is None or ts["o2"] > tank_states[best_stage]["o2"]:
                        best_stage = idx

            if best_stage is not None:
                # Switch to or continue using stage gas
                if active_stage_tank != best_stage:
                    # Record gas switch
                    if best_stage not in [gs["tank"] for gs in gas_switches]:
                        gas_switches.append({
                            "time": current_time,
                            "tank": best_stage,
                            "depth": current_depth,
                            "mix_id": tank_states[best_stage]["mix_id"]
                        })
                    active_stage_tank = best_stage
                tanks_to_consume = [best_stage]
            else:
                # No suitable stage gas, continue on main tanks
                active_stage_tank = None
                if config_type == "sidemount":
                    tanks_to_consume = [main_tank_indices[sidemount_active_tank % len(main_tank_indices)]]
                elif config_type in ["doubles", "doubles_staged"]:
                    tanks_to_consume = main_tank_indices  # Both tanks (manifolded)
                else:
                    tanks_to_consume = main_tank_indices[:1] if main_tank_indices else [0]
        else:
            # Descent or bottom phase: use main tanks
            active_stage_tank = None

            if config_type == "sidemount":
                # Sidemount: alternate tanks to maintain balance
                current_main_idx = main_tank_indices[sidemount_active_tank % len(main_tank_indices)]
                current_pressure_bar = tank_states[current_main_idx]["current_pressure"] / 100000

                # Check if we should switch (pressure dropped enough since last switch)
                last_pressure_bar = last_sidemount_switch_pressure / 100000
                if last_pressure_bar - current_pressure_bar >= sidemount_switch_threshold:
                    sidemount_active_tank = (sidemount_active_tank + 1) % len(main_tank_indices)
                    last_sidemount_switch_pressure = tank_states[main_tank_indices[sidemount_active_tank]]["current_pressure"]

                tanks_to_consume = [main_tank_indices[sidemount_active_tank % len(main_tank_indices)]]

            elif config_type in ["doubles", "doubles_staged"]:
                # Doubles (manifolded): consume from both tanks equally
                tanks_to_consume = main_tank_indices

            else:
                # Single tank (with or without stage)
                tanks_to_consume = main_tank_indices[:1] if main_tank_indices else [0]

        # Apply gas consumption to selected tanks
        for tank_idx in tanks_to_consume:
            ts = tank_states[tank_idx]
            if ts["current_pressure"] > 40 * 100000:  # Reserve pressure ~40 bar
                consumption = ts["sac_rate"] * ambient_pressure

                # For manifolded doubles, each tank provides half the gas
                if config_type in ["doubles", "doubles_staged"] and len(tanks_to_consume) == 2:
                    consumption = consumption / 2

                volume = ts["volume"]
                pressure_drop = (consumption * sample_interval / 60) / volume
                pressure_drop_pascal = pressure_drop * 100000
                ts["current_pressure"] -= pressure_drop_pascal
                ts["current_pressure"] = max(ts["current_pressure"], 35 * 100000)

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

    # Dive trips (UDDF standard divetrip elements)
    for trip in trips:
        divetrip = ET.SubElement(root, "divetrip")
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

        # Move date forward if not in a trip, or sometimes within a trip
        if active_trip is None:
            if random.random() > 0.3:
                current_date += timedelta(days=random.randint(1, 14))
        else:
            # Multiple dives per day during trips (30% chance to move to next day)
            if random.random() < 0.3:
                current_date += timedelta(days=1)
                if current_date > active_trip["end_date"]:
                    current_date = active_trip["end_date"]

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
        center_link.set("ref", f"center_{center_idx+1:03d}")
        # Link to trip if this dive is part of one
        if active_trip:
            trip_link = ET.SubElement(before, "link")
            trip_link.set("ref", f"trip_{active_trip['id']}")
        ET.SubElement(before, "divenumber").text = str(dive_number)
        ET.SubElement(before, "datetime").text = dive_datetime.strftime("%Y-%m-%dT%H:%M:%S")
        ET.SubElement(before, "airtemperature").text = f"{air_temp_kelvin:.2f}"

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

    # Application data section for Submersion-specific extensions
    appdata = ET.SubElement(root, "applicationdata")
    submersion = ET.SubElement(appdata, "submersion")
    submersion.set("xmlns", SUBMERSION_NS)

    # Trip extended data (resort/liveaboard names - not in UDDF standard)
    trips_with_extended = [t for t in trips if t.get("resort_name") or t.get("liveaboard_name")]
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
    print(f"- {len(trips)} trips (4-7 days each)")
    print(f"- {len(DIVE_SITES)} dive sites with GPS")
    print(f"- {len(DIVE_CENTERS)} dive centers")
    print(f"- {len(buddies)} buddies")
    print(f"- {total_equipment} equipment items in {len(EQUIPMENT_SETS)} sets")
    print(f"- {len(PADI_CERTIFICATIONS)} certifications (PADI)")
    print(f"- Equipment sets: {', '.join(EQUIPMENT_SETS.keys())}")
    print(f"- Multi-tank configs with AI pressure refs")
    print(f"\nTrip breakdown:")
    for trip in trips:
        count = trip_dive_counts[trip["id"]]
        if count > 0:
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
