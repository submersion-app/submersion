// Writes test/core/util/fixtures/tz_lookup_parity.json: coordinates and the
// zone ids that upstream tz.js returns for them. The Dart port in
// lib/core/util/site_time_zone.dart must match every row.
//
// Usage (from the repo root, node 18 or newer):
//   node scripts/tide/generate_tz_lookup_fixture.js
'use strict';

const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');

const COMMIT = '6051e7e2fe8b754e23d40aff0120cf9b38bde608';
const URL = `https://raw.githubusercontent.com/photostructure/tz-lookup/${COMMIT}/tz.js`;
const OUT = path.join('test', 'core', 'util', 'fixtures', 'tz_lookup_parity.json');

// Public dive sites and time zone edge cases.
const NAMED = [
  ['Bonaire', 12.15, -68.27],
  ['Cozumel', 20.35, -87.03],
  ['San Juan station', 18.458944, -66.11642],
  ['Vieques', 18.10, -65.47],
  ['Santa Cruz', 36.95, -122.02],
  ['San Francisco station', 37.8063, -122.4659],
  ['Monterey', 36.62, -121.90],
  ['Sydney', -33.86, 151.21],
  ['Adelaide', -34.93, 138.60],
  ['Koh Tao', 10.10, 99.84],
  ['Tulamben', -8.27, 115.59],
  ['Komodo', -8.55, 119.55],
  ['Gili', -8.35, 116.04],
  ['Raja Ampat', -0.55, 130.55],
  ['Cornwall', 50.07, -5.70],
  ['Silfra', 64.26, -21.12],
  ['Nanaimo', 49.17, -123.94],
  ['Sharm el Sheikh', 27.85, 34.32],
  ['Cairns', -16.75, 145.98],
  ['Malta', 36.05, 14.19],
  ['Tenerife', 28.05, -16.73],
  ['Sipadan', 4.11, 118.63],
  ['Galapagos', -0.75, -90.30],
  ['Roatan', 16.33, -86.53],
  ['Maldives', 4.18, 73.52],
  ['Blue Hole', 17.32, -87.53],
  ['Eilat', 29.53, 34.93],
  ['Fiji Beqa', -18.40, 178.10],
  ['Tonga', -18.65, -174.0],
  ['Scapa Flow', 58.90, -3.20],
  ['Chuuk', 7.42, 151.78],
  ['Palau', 7.13, 134.22],
  ['Open Atlantic', 30.0, -40.0],
  ['Open Indian Ocean', -30.0, 100.5],
  ['North pole', 90.0, 0.0],
  ['South pole', -90.0, 0.0],
  ['Antimeridian east', -18.4, 180.0],
  ['Antimeridian west', -18.4, -180.0],
];

function fetch(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'User-Agent': 'submersion' } }, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode} for ${url}`));
          return;
        }
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => resolve(body));
      })
      .on('error', reject);
  });
}

async function main() {
  const source = await fetch(URL);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tzlookup-'));
  const file = path.join(dir, 'tz.js');
  fs.writeFileSync(file, source);
  const tzlookup = require(file);

  const points = [...NAMED];
  for (let lat = -75; lat <= 75; lat += 15) {
    for (let lon = -180; lon <= 180; lon += 20) {
      points.push([`grid ${lat},${lon}`, lat, lon]);
    }
  }
  const rows = points.map(([name, lat, lon]) => ({ name, lat, lon, zone: tzlookup(lat, lon) }));
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(
    OUT,
    JSON.stringify({ source: `photostructure/tz-lookup@${COMMIT}`, points: rows }, null, 1) + '\n',
  );
  console.log(`Wrote ${rows.length} points to ${OUT}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
