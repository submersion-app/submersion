#!/usr/bin/env python3
"""Generate test/dives/scrubber-1500-dives.uddf: 1500 synthetic dives for
manually testing the dive list scrubber (#3456).

Fully synthetic: a placeholder diver, public dive sites with approximate
coordinates, and dives, depths, gases and profiles drawn from a fixed seed, so
re-running reproduces the file byte for byte.

    python3 tool/generate_scrubber_sample_dives.py
"""
import math
import os
import random
import datetime as dt
from xml.sax.saxutils import escape

SEED = 20261018
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "test", "dives", "scrubber-1500-dives.uddf")
N = 1500
START = dt.date(2016, 10, 18)
END = dt.date(2026, 10, 17)
rnd = random.Random(SEED)

# country: (base water temp C, seasonal amplitude C, southern hemisphere, typical depth, max depth cap, sites)
# site: (name, region, lat, lon)
C = {
    "Germany": (12, 8, False, 18, 38, [
        ("Hemmoor Kreidesee", "Lower Saxony", 53.7167, 9.1167),
        ("Silbersee III Haltern", "North Rhine-Westphalia", 51.76, 7.20),
        ("Walchensee Steilwand", "Bavaria", 47.59, 11.35),
        ("Starnberger See Seeshaupt", "Bavaria", 47.82, 11.31),
        ("Blausteinsee", "North Rhine-Westphalia", 50.84, 6.33),
        ("Sorpesee Dive Base", "North Rhine-Westphalia", 51.34, 7.97),
        ("Edersee Bringhausen", "Hesse", 51.18, 9.06),
        ("Bodensee Ueberlingen", "Baden-Wuerttemberg", 47.77, 9.17)]),
    "Egypt": (26, 3, False, 28, 55, [
        ("Shark and Yolanda Reef", "Ras Mohammed, Sinai", 27.73, 34.25),
        ("SS Thistlegorm", "Red Sea", 27.81, 33.92),
        ("Blue Hole Dahab", "South Sinai", 28.57, 34.54),
        ("Elphinstone Reef", "Marsa Alam", 25.31, 34.86),
        ("Brothers Islands Big Brother", "Red Sea", 26.31, 34.85),
        ("Abu Nuhas Giannis D", "Red Sea", 27.57, 33.93),
        ("Daedalus Reef", "Red Sea", 24.93, 35.86)]),
    "Maldives": (29, 1, False, 24, 40, [
        ("Maaya Thila", "Ari Atoll", 3.90, 72.80),
        ("Fish Head", "Ari Atoll", 3.93, 72.78),
        ("Manta Point Lankan", "North Male Atoll", 4.30, 73.55),
        ("Banana Reef", "North Male Atoll", 4.28, 73.55),
        ("Hanifaru Bay Edge", "Baa Atoll", 5.20, 73.10)]),
    "Thailand": (28, 1.5, False, 22, 40, [
        ("Richelieu Rock", "Andaman Sea", 9.36, 98.01),
        ("Koh Bon Ridge", "Phang Nga", 8.90, 97.80),
        ("Shark Point", "Phuket", 7.80, 98.40),
        ("Sail Rock", "Koh Tao, Gulf of Thailand", 10.10, 99.80),
        ("Chumphon Pinnacle", "Koh Tao", 10.20, 99.85),
        ("Hin Daeng", "Krabi", 7.20, 99.20)]),
    "Indonesia": (28, 1.5, True, 22, 45, [
        ("USAT Liberty Wreck", "Tulamben, Bali", -8.274, 115.593),
        ("Manta Point Nusa Penida", "Bali", -8.80, 115.50),
        ("Batu Bolong", "Komodo", -8.60, 119.50),
        ("Bunaken Wall", "North Sulawesi", 1.62, 124.76),
        ("Lembeh Hairball", "North Sulawesi", 1.45, 125.20),
        ("Cape Kri", "Raja Ampat, West Papua", -0.55, 130.70)]),
    "Philippines": (28, 2, False, 22, 40, [
        ("Apo Island Sanctuary", "Negros Oriental", 9.07, 123.27),
        ("Tubbataha Reefs Delsan Wreck", "Palawan", 8.90, 119.90),
        ("Moalboal Sardine Run", "Cebu", 9.95, 123.40),
        ("Monad Shoal", "Malapascua, Cebu", 11.33, 124.12),
        ("Akitsushima Wreck", "Coron, Palawan", 11.98, 120.20)]),
    "Malaysia": (29, 1, False, 24, 40, [
        ("Barracuda Point", "Sipadan, Sabah", 4.11, 118.63),
        ("Seaventures Rig", "Mabul, Sabah", 4.24, 118.63),
        ("Layang Layang Wall", "Sabah", 7.37, 113.84),
        ("Sugar Wreck", "Perhentian, Terengganu", 5.90, 102.70)]),
    "Mexico": (26, 3, False, 20, 40, [
        ("Cenote Dos Ojos", "Quintana Roo", 20.33, -87.39),
        ("Cenote Angelita", "Quintana Roo", 20.17, -87.47),
        ("Palancar Reef", "Cozumel", 20.35, -87.00),
        ("MUSA Underwater Museum", "Isla Mujeres", 21.20, -86.70),
        ("Roca Partida", "Revillagigedo, Colima", 18.80, -112.07),
        ("Cenote Ox Bel Ha", "Quintana Roo", 20.00, -87.50)]),
    "United States": (22, 5, False, 20, 45, [
        ("Molasses Reef", "Florida Keys", 25.01, -80.38),
        ("Christ of the Abyss", "Key Largo, Florida", 25.12, -80.29),
        ("Monterey Breakwater", "California", 36.61, -121.89),
        ("Casino Point", "Catalina Island, California", 33.35, -118.33),
        ("Kona Manta Night Dive", "Hawaii", 19.64, -156.03),
        ("Molokini Crater", "Maui, Hawaii", 20.63, -156.50)]),
    "Cayman Islands": (28, 2, False, 22, 40, [
        ("Stingray City Sandbar", "Grand Cayman", 19.39, -81.29),
        ("Bloody Bay Wall", "Little Cayman", 19.70, -80.06),
        ("MV Kittiwake", "Grand Cayman", 19.36, -81.39),
        ("Eagle Ray Pass", "Grand Cayman", 19.30, -81.40)]),
    "Bahamas": (27, 2.5, False, 22, 40, [
        ("Tiger Beach", "Grand Bahama", 26.87, -79.00),
        ("Shark Arena", "New Providence", 25.00, -77.50),
        ("Dean's Blue Hole", "Long Island", 23.10, -75.10),
        ("Thunderball Grotto", "Exuma", 24.17, -76.45)]),
    "Honduras": (28, 1.5, False, 22, 35, [
        ("Mary's Place", "West End, Roatan", 16.30, -86.60),
        ("Hole in the Wall", "Utila", 16.10, -86.90),
        ("Half Moon Bay Wall", "Roatan", 16.32, -86.56)]),
    "Belize": (28, 1.5, False, 25, 45, [
        ("Great Blue Hole", "Lighthouse Reef", 17.32, -87.53),
        ("Half Moon Caye Wall", "Lighthouse Reef", 17.20, -87.55),
        ("Hol Chan Marine Reserve", "Ambergris Caye", 17.86, -87.96)]),
    "Ecuador": (21, 3, True, 25, 40, [
        ("Gordon Rocks", "Galapagos, Santa Cruz", -0.57, -90.40),
        ("Darwin's Arch", "Galapagos", 1.68, -92.00),
        ("Wolf Island", "Galapagos", 1.38, -91.82),
        ("Kicker Rock", "Galapagos, San Cristobal", -0.77, -89.50)]),
    "Australia": (23, 4, True, 20, 45, [
        ("SS Yongala Wreck", "Queensland", -19.30, 147.62),
        ("Cod Hole", "Ribbon Reefs, Queensland", -14.70, 145.65),
        ("Ningaloo Reef Lighthouse Bay", "Western Australia", -21.90, 113.95),
        ("Shelly Beach", "Manly, New South Wales", -33.80, 151.30),
        ("Navy Pier", "Exmouth, Western Australia", -21.80, 114.17)]),
    "Fiji": (27, 2, True, 22, 40, [
        ("Beqa Lagoon Shark Dive", "Viti Levu", -18.40, 178.10),
        ("Great White Wall", "Rainbow Reef, Taveuni", -16.70, -179.90),
        ("Namena Marine Reserve", "Vanua Levu", -17.10, 179.10),
        ("Drawaqa Manta Channel", "Yasawa", -16.90, 177.40)]),
    "Palau": (29, 1, False, 24, 45, [
        ("Blue Corner", "Koror", 7.13, 134.22),
        ("German Channel", "Koror", 7.10, 134.25),
        ("Chandelier Cave", "Koror", 7.15, 134.25),
        ("Ulong Channel", "Rock Islands", 7.00, 134.20)]),
    "Federated States of Micronesia": (29, 1, False, 24, 40, [
        ("Yap Manta Ridge", "Yap", 9.50, 138.10),
        ("Mi'il Channel", "Yap", 9.55, 138.15),
        ("Manta Road", "Pohnpei", 6.90, 158.20),
        ("Shinkoku Maru", "Chuuk Lagoon", 7.33, 151.88),
        ("Yamagiri Maru", "Chuuk Lagoon", 7.36, 151.90)]),
    "Croatia": (17, 7, False, 24, 45, [
        ("Teti Wreck", "Vis", 43.00, 16.20),
        ("Baron Gautsch Wreck", "Istria", 45.10, 13.60),
        ("Kornat Wall", "Kornati", 43.80, 15.30),
        ("Lina Wreck", "Pula, Istria", 44.86, 13.80)]),
    "Malta": (20, 5, False, 22, 45, [
        ("Blue Hole", "Gozo", 36.05, 14.19),
        ("HMS Maori", "Valletta", 35.90, 14.52),
        ("Um El Faroud", "Wied iz-Zurrieq", 35.82, 14.50),
        ("Santa Maria Caves", "Comino", 36.00, 14.34),
        ("HMS Stubborn", "Malta", 35.99, 14.61)]),
    "Spain": (17, 6, False, 22, 40, [
        ("Medes Islands", "Catalonia", 42.05, 3.22),
        ("Islas Hormigas", "Cabo de Palos, Murcia", 37.65, -0.69),
        ("Mar de las Calmas", "El Hierro, Canary Islands", 27.70, -18.00),
        ("Los Gigantes", "Tenerife, Canary Islands", 28.24, -16.84)]),
    "Italy": (18, 6, False, 24, 45, [
        ("Cristo degli Abissi", "San Fruttuoso, Liguria", 44.31, 9.18),
        ("Scoglio del Medico", "Ustica, Sicily", 38.70, 13.18),
        ("Tavolara Marine Park", "Sardinia", 40.90, 9.70)]),
    "Portugal": (18, 3, False, 22, 40, [
        ("Princess Alice Bank", "Azores", 37.70, -29.00),
        ("Garajau Nature Reserve", "Madeira", 32.64, -16.83),
        ("Berlengas Archipelago", "Peniche", 39.41, -9.50)]),
    "Norway": (8, 3, False, 18, 40, [
        ("Saltstraumen Maelstrom", "Nordland", 67.23, 14.63),
        ("Svolvaer Harbour Wreck", "Lofoten", 68.23, 14.56),
        ("Kvaloya Fjord Wall", "Troms", 69.70, 18.50)]),
    "South Africa": (19, 4, True, 24, 45, [
        ("Aliwal Shoal Raggies", "KwaZulu-Natal", -30.27, 30.83),
        ("Protea Banks", "KwaZulu-Natal", -30.83, 30.60),
        ("Miller's Point", "Simon's Town, Western Cape", -34.23, 18.47),
        ("Two-Mile Reef", "Sodwana Bay", -27.50, 32.68)]),
}
HOME = "Germany"
# Tech-diving sites: name -> deepest sensible depth for a tech dive.
TECH = {
    "Egypt": {"Blue Hole Dahab": 90, "Brothers Islands Big Brother": 80,
              "Daedalus Reef": 75, "Elphinstone Reef": 60},
    "Malta": {"Blue Hole": 60, "HMS Stubborn": 58},
    "Mexico": {"Cenote Angelita": 60, "Cenote Dos Ojos": 45,
               "Cenote Ox Bel Ha": 70},
    "Federated States of Micronesia": {"Shinkoku Maru": 60,
                                       "Yamagiri Maru": 55},
    "Croatia": {"Kornat Wall": 55, "Teti Wreck": 45},
    "Palau": {"Blue Corner": 75, "Ulong Channel": 60},
    "Bahamas": {"Dean's Blue Hole": 90},
}
techrnd = random.Random(SEED + 2)
DEEP_PROB = 0.6
# Outliers: deep air in the early logs, mid-depth air, shallow trimix.
DEEP_AIR_NUMS = set(techrnd.sample(range(1, 301), 10))
DEEP_AIR_DECO = set(sorted(DEEP_AIR_NUMS)[::3])
AIR_MID_NUMS = set(techrnd.sample(range(301, 1501), 6))
TMX_MID_NUMS = set(techrnd.sample(range(1, 1501), 100))
TMX_LOW_NUMS = set(techrnd.sample(range(1, 1501), 150))
tmx_mid_left = [13]
tmx_low_left = [4]
# Sites with no country (and no coordinates, so import cannot geocode one).
NOCOUNTRY = [
    ("Unnamed Quarry", None), ("Club Training Pool", None),
    ("Boat Dive Offshore", "Unknown coast"), ("Drift Dive (unnamed)", None),
    ("House Reef", None), ("Wreck Dive (unnamed)", "Unknown coast"),
    ("Shore Entry Spot 1", None), ("Mountain Lake Dive", "Alps"),
    ("Cave Dive Practice", None),
]

# ---- site table -------------------------------------------------------------
sites = []  # dicts
by_country = {}
for country, (_, _, _, typ, cap, lst) in C.items():
    by_country[country] = []
    for name, region, lat, lon in lst:
        s = dict(id="site_%03d" % (len(sites) + 1), name=name, region=region,
                 lat=lat, lon=lon, country=country,
                 depth=max(8, int(rnd.gauss(typ, 6))), cap=cap)
        sites.append(s)
        by_country[country].append(s)
nocountry_sites = []
for name, region in NOCOUNTRY:
    s = dict(id="site_%03d" % (len(sites) + 1), name=name, region=region,
             lat=None, lon=None, country=None, depth=rnd.randint(10, 30),
             cap=40)
    sites.append(s)
    nocountry_sites.append(s)

# ---- timeline ---------------------------------------------------------------
total_days = (END - START).days + 1  # 3653
trip_countries = [c for c in C if c != HOME]
rnd.shuffle(trip_countries)

# Trip sizes until the trip dives reach about 75% of the total.
target_trip_dives = 1130
trips = []  # (country or None, n_dives)
t = 0
cyc = []
while t < target_trip_dives:
    if not cyc:
        cyc = trip_countries[:]
        rnd.shuffle(cyc)
    n = min(rnd.randint(5, 20), target_trip_dives - t)
    if n < 5:
        trips[-1] = (trips[-1][0], trips[-1][1] + n)
        t += n
        break
    # a few trips to a location the log does not name a country for
    country = None if rnd.random() < 0.04 else cyc.pop()
    trips.append((country, n))
    t += n


def spread(n):
    """Dives per day for a trip of n dives over consecutive days."""
    days = max(3, round(n / rnd.choice([1.0, 1.4, 1.7, 2.0])))
    days = min(days, n)
    per = [1] * days
    for _ in range(n - days):
        k = rnd.randrange(days)
        while per[k] >= 3:
            k = rnd.randrange(days)
        per[k] += 1
    return per


trip_plans = [(c, spread(n)) for c, n in trips]
trip_tech = [c in TECH and techrnd.random() < 0.9 for c, _ in trip_plans]
span = [len(p) for _, p in trip_plans]
free = total_days - 12 - sum(span)  # keep 5 days at each end
# gap weights: exponential plus a few long quiet stretches
weights = [rnd.expovariate(1.0) + 0.15 for _ in range(len(trip_plans) + 1)]
for i in rnd.sample(range(1, len(weights) - 1), 6):
    weights[i] += rnd.uniform(3.5, 6.0)
wsum = sum(weights)
gaps = [int(free * w / wsum) for w in weights]
gaps[-1] += free - sum(gaps)

dives_by_day = {}  # date -> list of (country, hour)
cursor = 6
trip_ranges = []
for ((country, per), gap), tech in zip(zip(trip_plans, gaps), trip_tech):
    cursor += gap
    start = cursor
    trip_ranges.append((start, start + len(per)))
    for d, k in enumerate(per):
        day = START + dt.timedelta(days=start + d)
        hours = [rnd.randint(8, 10), rnd.randint(12, 14), rnd.randint(16, 17)]
        for h in hours[:k]:
            dives_by_day.setdefault(day, []).append((country, h, True, tech))
    cursor += len(per)

# Quiet months (no home dives): winter-ish plus a few random ones.
quiet = set()
for _ in range(7):
    q0 = rnd.randrange(total_days - 60)
    for d in range(q0, q0 + rnd.randint(30, 60)):
        quiet.add(d)
in_trip = set()
for a, b in trip_ranges:
    in_trip.update(range(a - 1, b + 2))
candidates = []
for d in range(total_days):
    day = START + dt.timedelta(days=d)
    if day.weekday() >= 5 and d not in in_trip and d not in quiet and 0 < d < total_days - 1:
        candidates.append(d)
trip_dive_count = sum(len(v) for v in dives_by_day.values())
home_needed = N - trip_dive_count - 2  # first and last day are fixed
# Roughly one home dive a day, two on some weekends.
rnd.shuffle(candidates)
home_days = []
pool = candidates[:]
while len(home_days) < home_needed and pool:
    d = pool.pop()
    k = 2 if rnd.random() < 0.25 and len(home_days) + 2 <= home_needed else 1
    home_days.extend([d] * k)
assert len(home_days) == home_needed, (len(home_days), home_needed)
for d in home_days:
    day = START + dt.timedelta(days=d)
    n_today = len(dives_by_day.get(day, []))
    dives_by_day.setdefault(day, []).append((HOME, 9 + 4 * n_today, False, False))
for day in (START, END):
    assert day not in dives_by_day
    dives_by_day[day] = [(HOME, 10, False, False)]

# ---- per-dive values --------------------------------------------------------
dive_rows = []
for day in sorted(dives_by_day):
    for country, hour, is_trip, tech in sorted(dives_by_day[day], key=lambda x: x[1]):
        dive_rows.append((day, hour, country, is_trip, tech))
assert len(dive_rows) == N, len(dive_rows)


def pick_site(country, is_trip, trip_key):
    if country is None:
        return rnd.choice(nocountry_sites)
    if not is_trip and rnd.random() < 0.14:
        return rnd.choice(nocountry_sites)
    return rnd.choice(by_country[country])


def sea_temp(country, day):
    if country is None:
        base, amp, south = 20, 5, False
    else:
        base, amp, south, _, _, _ = C[country]
    phase = (day.timetuple().tm_yday - 200) / 365.25 * 2 * math.pi
    s = math.cos(phase)
    if south:
        s = -s
    return base + amp * s + rnd.gauss(0, 0.8)


def deco_plan(md, bottom_min):
    """Deco stops (depth, seconds) for a deep dive."""
    if md <= 40:
        return []
    scale = min(1.8, (md - 35) / 25.0 + (bottom_min - 20) / 40.0)
    stops = [(21, int(180 * scale)), (12, int(300 * scale)),
             (6, int(540 * scale))]
    if md >= 70:
        stops.insert(0, (30, int(120 * scale)))
        stops.insert(1, (24, int(150 * scale)))
    return stops


def deep_params(md):
    bottom_min = int(min(35, max(15, techrnd.gauss(32 - (md - 40) * 0.35, 3))))
    stops = deco_plan(md, bottom_min)
    total = bottom_min + sum(sec for _, sec in stops) / 60 + md / 9 + md / 18
    return int(round(min(75, max(20, total)))), stops


def profile(max_depth, runtime_s, stops=()):
    """Sparse profile: turning points plus a sample every 10 minutes."""
    descent = min(max(int(max_depth / 0.3), 100), runtime_s // 5)
    if stops:
        rate = 0.15
        t_up = (runtime_s - sum(sec for _, sec in stops)
                - int(stops[0][0] / rate) - 60)
        bottom_end = max(t_up, descent + 120)
        pts = {0: 0.0, descent: round(max_depth, 1)}
        t_ = 600
        while t_ < bottom_end - 30:
            if t_ > descent + 30:
                pts[t_] = round(max_depth - rnd.uniform(0, 3), 1)
            t_ += 600
        pts[bottom_end] = round(max_depth - rnd.uniform(0, 2), 1)
        cur, prev_d = bottom_end, max_depth
        for sd, sec in stops:
            cur += int((prev_d - sd) / rate)
            pts[cur] = float(sd)
            cur += sec
            pts[cur] = float(sd)
            prev_d = sd
        pts = {k: v for k, v in pts.items() if k < runtime_s}
        pts[runtime_s] = 0.0
        pts[descent] = round(max_depth, 1)
        return sorted(pts.items())
    stop = 180 if max_depth > 12 else 0
    ascent = int(max_depth / 0.15) if max_depth > 5 else 60
    bottom_end = max(runtime_s - ascent - stop, descent + 60)
    pts = {0: 0.0, descent: max_depth}
    t_ = 600
    while t_ < bottom_end - 30:
        if t_ > descent + 30:
            f = (t_ - descent) / max(1, bottom_end - descent)
            d = max_depth * (0.8 - 0.4 * f + rnd.uniform(-0.08, 0.08))
            pts[t_] = round(max(2.0, min(max_depth, d)), 1)
        t_ += 600
    pts[bottom_end] = round(max_depth * 0.4, 1)
    if stop:
        pts[bottom_end + ascent] = 5.0
        pts[runtime_s - 20] = 5.0
    pts[runtime_s] = 0.0
    pts[descent] = round(max_depth, 1)
    return sorted(pts.items())


def kelvin(c):
    return "%.2f" % (c + 273.15)


out = []
w = out.append
w('<?xml version="1.0" encoding="UTF-8"?>')
w('<uddf version="3.2.0">')
w('<generator><name>synthetic scrubber test data</name><type>logbook</type>'
  '<datetime>2026-10-18T00:00:00</datetime></generator>')
w('<diver><owner id="owner"><personal><firstname>Test</firstname>'
  '<lastname>Diver</lastname></personal></owner></diver>')
w('<divesite>')
for s in sites:
    w('<site id="%s"><name>%s</name>' % (s["id"], escape(s["name"])))
    if s["lat"] is not None:
        w('<geography><latitude>%s</latitude><longitude>%s</longitude></geography>'
          % (s["lat"], s["lon"]))
    if s["country"]:
        w('<country>%s</country>' % escape(s["country"]))
    if s["region"]:
        w('<state>%s</state>' % escape(s["region"]))
    w('</site>')
w('</divesite>')
MIXES = {}  # (o2, he) percent -> (id, name)


def mix_ref(o2, he):
    if (o2, he) not in MIXES:
        if he:
            name = "Tx %d/%d" % (o2, he)
        elif o2 == 21:
            name = "Air"
        else:
            name = "EAN%d" % o2
        MIXES[(o2, he)] = ("mix_%d_%d" % (o2, he), name)
    return MIXES[(o2, he)][0]


for _m in [(21, 0), (32, 0), (36, 0), (28, 0), (50, 0), (100, 0),
           (21, 35), (18, 45), (15, 55)]:
    mix_ref(*_m)
w('<gasdefinitions>')
for (o2, he), (mid, name) in MIXES.items():
    w('<mix id="%s"><name>%s</name><o2>%.2f</o2><n2>%.2f</n2><he>%.2f</he></mix>'
      % (mid, name, o2 / 100, (100 - o2 - he) / 100, he / 100))
w('</gasdefinitions>')
gasrnd = random.Random(SEED + 1)
gas_rows = []


def pick_tanks(md, bt, kind=None):
    g = gasrnd
    extra = []
    if kind == "air_deep":
        main, vol = (21, 0), 24.0
        if g.random() < 0.3:
            extra.append((50, 0, 11.0))
    elif kind == "air_mid":
        main, vol = (21, 0), 24.0
    elif kind == "tmx_shallow":
        main, vol = (21, 35), g.choice([12.0, 15.0])
    elif md > 45:
        if md < 55:
            main = (21, 35)
        elif md < 70:
            main = (18, 45)
        else:
            main = (15, 55)
        vol = 24.0
        if g.random() < 0.9:
            extra.append((50, 0, 11.0))
        if md >= 70:
            extra.append((100, 0, 7.0))
    elif md > 35:
        main = (21, 35) if g.random() < 0.7 else (28, 0)
        vol = 24.0 if main[1] else 15.0
        if g.random() < 0.4:
            extra.append((50, 0, 11.0))
    elif md > 18:
        main = (32, 0) if g.random() < 0.5 else (21, 0)
        vol = g.choice([12.0, 15.0])
    else:
        main = g.choices([(21, 0), (32, 0), (36, 0)], [75, 15, 10])[0]
        vol = g.choice([10.0, 12.0, 15.0])
    start = g.choice([200, 210, 220, 232])
    used = 18 * (md * 0.55 / 10 + 1) * bt / vol
    if md > 45:
        used *= 0.55
    floor = 60 if md > 45 else 45
    end = int(max(floor, min(start - 30, start - used * g.uniform(0.8, 1.1))))
    tanks = [(main[0], main[1], vol, start, end)]
    for o2, he, v in extra:
        tanks.append((o2, he, v, 200, int(200 - g.uniform(30, 90))))
    return tanks
w('<profiledata><repetitiongroup id="rg1">')

stats = dict(depth=[], bt=[], rating=[], countries=set(), sites_used=set())
for num, (day, hour, country, is_trip, tech) in enumerate(dive_rows, 1):
    kind = None
    stops = []
    if num in DEEP_AIR_NUMS or num in AIR_MID_NUMS:
        site = pick_site(country, is_trip, None)
        if num in DEEP_AIR_NUMS:
            md, kind = round(techrnd.uniform(55, 65), 1), "air_deep"
        else:
            md, kind = round(techrnd.uniform(42, 52), 1), "air_mid"
        bt, stops = deep_params(md)
    elif tech and techrnd.random() < DEEP_PROB:
        u = techrnd.random()
        want = (techrnd.uniform(40.5, 55) if u < 0.45
                else techrnd.uniform(55, 70) if u < 0.75
                else techrnd.uniform(70, 90))
        cand = [x for x in by_country[country]
                if TECH[country].get(x["name"], 0) >= want]
        if not cand:
            best = max(TECH[country].values())
            cand = [x for x in by_country[country]
                    if TECH[country].get(x["name"], 0) == best]
            want = techrnd.uniform(min(42, best), best)
        site = techrnd.choice(cand)
        md = round(want, 1)
        bt, stops = deep_params(md)
    else:
        site = pick_site(country, is_trip, None)
        md = round(min(max(rnd.gauss(site["depth"], 7), 5.0),
                       39.0 if tech else 40.0), 1)
        bt = int(round(min(75, max(20, 78 - md * 0.7 + rnd.gauss(0, 11)))))
        if num in TMX_MID_NUMS and 25 <= md <= 35 and tmx_mid_left[0] > 0:
            tmx_mid_left[0] -= 1
            kind = "tmx_shallow"
        elif num in TMX_LOW_NUMS and 10 <= md < 18 and tmx_low_left[0] > 0:
            tmx_low_left[0] -= 1
            kind = "tmx_shallow"
    r = rnd.random()
    if r < 0.15:
        rating = None
    elif r < 0.18:
        rating = 0
    else:
        rating = rnd.choices([1, 2, 3, 4, 5], [3, 8, 22, 35, 32])[0]
    minute = rnd.choice([0, 10, 15, 20, 30, 45])
    when = dt.datetime(day.year, day.month, day.day, hour, minute)
    runtime = bt * 60
    wt = sea_temp(site["country"] or country, day)
    if site["country"] == HOME:
        wt = max(4.0, wt - min(md, 20) * 0.25)
    wt = round(wt, 1)
    air = round(wt + rnd.uniform(-2, 8), 1)
    avg = round(md * rnd.uniform(0.5, 0.65), 1)

    w('<dive id="dive_%04d">' % num)
    w('<informationbeforedive>')
    w('<datetime>%s</datetime><divenumber>%d</divenumber>'
      '' % (when.strftime("%Y-%m-%dT%H:%M:%S"), num))
    w('<link ref="%s"/>' % site["id"])
    w('</informationbeforedive>')
    for ti, (o2, he, vol, sb, eb) in enumerate(pick_tanks(md, bt, kind)):
        w('<tankdata id="tank_%04d_%d"><link ref="%s"/>'
          '<tankvolume unit="m3">%s</tankvolume>'
          '<tankpressurebegin>%d</tankpressurebegin>'
          '<tankpressureend>%d</tankpressureend></tankdata>'
          % (num, ti, mix_ref(o2, he), vol / 1000, sb * 100000, eb * 100000))
        gas_rows.append((num, ti, o2, he, vol, sb, eb))
    w('<samples>')
    for tsec, d in profile(md, runtime, stops):
        w('<waypoint><divetime>%d</divetime><depth>%.1f</depth></waypoint>'
          % (tsec, d))
    w('</samples>')
    w('<informationafterdive>')
    w('<greatestdepth>%.1f</greatestdepth>'
      '<diveduration>%d</diveduration><lowesttemperature>%s</lowesttemperature>'
      % (md, runtime, kelvin(wt)))
    if rating is not None:
        w('<rating><ratingvalue>%d</ratingvalue></rating>' % rating)
    w('</informationafterdive>')
    w('</dive>')
    stats["depth"].append(md)
    stats["bt"].append(bt)
    stats["rating"].append(rating)
    if site["country"]:
        stats["countries"].add(site["country"])
    stats["sites_used"].add(site["id"])

w('</repetitiongroup></profiledata></uddf>')
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")

print("dives", N, "first", dive_rows[0][0], "last", dive_rows[-1][0])
print("sites", len(sites), "used", len(stats["sites_used"]),
      "no-country", len(nocountry_sites))
print("countries used", len(stats["countries"]), "trips", len(trip_plans))
print("depth", min(stats["depth"]), max(stats["depth"]),
      "bt", min(stats["bt"]), max(stats["bt"]))
print("unrated", sum(r is None for r in stats["rating"]),
      "zero", sum(r == 0 for r in stats["rating"]))

first = {r[0]: r for r in gas_rows if r[1] == 0}
by_dive = {}
for r in gas_rows:
    by_dive.setdefault(r[0], []).append(r)


def gas_class(n):
    rows = by_dive[n]
    if any(r[3] > 0 for r in rows):
        return "trimix"
    return "nitrox" if any(r[2] > 22 for r in rows) else "air"


bands = [(0, 18), (18, 30), (30, 40), (40, 55), (55, 91)]
for lo, hi in bands:
    cnt = {"air": 0, "nitrox": 0, "trimix": 0}
    for i, dv in enumerate(stats["depth"], 1):
        if lo <= dv < hi:
            cnt[gas_class(i)] += 1
    print("band", lo, hi, cnt)
tot = {"air": 0, "nitrox": 0, "trimix": 0}
for i in range(1, N + 1):
    tot[gas_class(i)] += 1
print("totals richest-gas", tot)
D = stats["depth"]
print(">40:", sum(x > 40 for x in D), ">55:", sum(x > 55 for x in D),
      ">=70:", sum(x >= 70 for x in D), "max", max(D))
print("shallow tmx left", tmx_mid_left, tmx_low_left)
print("trimix", sum(1 for r in first.values() if r[3] > 0),
      "nitrox", sum(1 for r in first.values() if r[3] == 0 and r[2] != 21),
      "air", sum(1 for r in first.values() if r[3] == 0 and r[2] == 21),
      "deco tanks", sum(1 for r in gas_rows if r[1] == 1))
