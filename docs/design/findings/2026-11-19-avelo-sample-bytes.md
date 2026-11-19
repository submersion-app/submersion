# Avelo sample record (0x03): what the repurposed bytes hold

Date: 2026-11-19
Issue: #4664 (follow-up to #4657 and PR #4662)

## Source

An Avelo diver (the commenter on #4664) sent eight Avelo-mode dives from a
Perdix 2 (firmware 99, log version 16, imperial units, one Swift transmitter
on T1) as a Shearwater Cloud database export plus Shearwater's UDDF export of
the same dives.

- The UDDF files hold no Avelo data: open-circuit dive mode, one tank, the T1
  pressure as ordinary `tankpressure` waypoints.
- The Cloud database holds the raw log (`log_data.data_bytes_1`, a 4-byte
  length then gzip, giving PNF 32-byte records). This is the input Submersion's
  Shearwater Cloud importer (`shearwater_db_reader.dart`) already feeds to the
  libdivecomputer fork, so these dives exercise the real import path.
- `log_data.calculated_values_from_samples` holds Shearwater's own per-dive
  Avelo statistics: `AveloMaxPressure`, `AveloMinBuoyancy`,
  `AveloMaxBuoyancy`, `AveloAverageBuoyancy`, `AveloMinRMV`, `AveloMaxRMV`.
  These are the ground truth the decode below was checked against.

Every sample record in all eight dives is type `0x03`; none is `0x01`.

## Byte map

Offsets are the parser's `offset + pnf + N` index (the record type byte is
not counted), so they line up with `shearwater_predator_parser.c`.

| N | Normal dive sample | Avelo sample |
| --- | --- | --- |
| 0-1 | depth | depth (unchanged) |
| 2-9 | stop depth, TTS, ppO2, FO2, FHe, NDL | unchanged |
| 10 | not read by libdc | **gas remaining, percent** (0 to 100); `0xFE` while the transmitter has no comms |
| 11 | status flags | **buoyancy, high byte** |
| 12 | O2 cell 1 mV | **buoyancy, low byte** |
| 13 | temperature | unchanged |
| 14 | O2 cell 2 mV | small flag field (values 0, 1, 3), meaning not found |
| 15 | O2 cell 3 mV | always 0 |
| 16 | | always 1 |
| 17 | | 151 to 156, falls slowly through each dive (looks like battery voltage x100) |
| 18 | setpoint | always 0 |
| 19-20 | T2 pressure | always 0 |
| 21 | gas time remaining (min) | still gas time remaining (see below) |
| 22 | CNS | unchanged |
| 24 | | behaves like GF99 (255 at depth, rising after surfacing) |
| 27-28 | T1 pressure | T1 pressure, the Hydrotank (unchanged) |
| 29-30 | | **RMV x0.01** (unsigned 16-bit, big endian) |

### Buoyancy (bytes 11-12)

Signed 16-bit, big endian. Negative is heavy. `0x7FFE` (32766) means not
available and appears exactly when the T1 pressure reads `0xFFFD` or
`0xFFFE` (no comms). Before the dive starts it holds a constant (-96 in every
dive) until the first underwater samples.

The unit is not stated anywhere in the data. Grams fits the physics: in dive
1636 buoyancy rises about 1650 while gas remaining falls from 100 to 36
percent, which puts the starting gas at about 2.6 kg of air, about 9 L of
cylinder at 3488 psi, in line with the 8 L and 10 L Hydrotanks. Hundredths of
a pound would need a 40 L cylinder. These are imperial-unit dives; a metric
log would show whether the stored value changes with the unit setting.

### Gas remaining (byte 10)

Starts at 100 and falls through the dive (dive 1636 ends at 35). During a
pump-in it stays flat while the pressure jumps, so it counts gas, not
pressure. This is the percentage the Avelo manual tells the diver to use in
place of cylinder pressure.

### RMV (bytes 29-30)

Hundredths, presumably litres per minute (3.8 to 29.75 across the eight
dives, recorded on an imperial-unit computer). Special codes: `0xFFFA` before
the dive, `0xFFF9` and `0xFFF8` in the first minutes while it is still being
computed, `0xFFFE` with no transmitter comms.

### Gas time remaining (byte 21)

Still minutes and plausible as GTR (dive 1636: 49 falling to 6). Two codes
appear that libdc's comment does not list: `0xFA` alongside RMV's `0xFFFA`
and `0xF9` alongside `0xFFF9`. The existing `< 0xF0` filter already drops
them, so #4662's handling is correct.

## Check against Shearwater's statistics

Shearwater counts only samples with depth above zero. With that filter the
decode reproduces every Avelo statistic on all eight dives: buoyancy minimum
and maximum exactly, buoyancy average within 1 (rounding), RMV minimum and
maximum exactly, and `AveloMaxPressure` as the highest T1 pressure.

| Dive | Buoyancy min / max / avg | RMV min / max | Max pressure (psi) |
| --- | --- | --- | --- |
| 1636 | -393 / 1242 / 295 (294) | 10.68 / 29.75 | 3498 |
| 1637 | -2124 / -17 / -1007 (-1006) | 4.93 / 23.25 | 3674 |
| 1639 | -1560 / -96 / -1166 (-1165) | 8.12 / 24.11 | 3402 |
| 1640 | -2403 / 813 / -1296 | 8.63 / 21.25 | 3794 |
| 1641 | -733 / 813 / -241 (-240) | 8.75 / 26.22 | 3588 |
| 1642 | -417 / 841 / 149 (148) | 7.35 / 21.81 | 3866 |
| 1643 | -1287 / 813 / -144 | 7.21 / 20.13 | 3384 |
| 1644 | 704 / 1877 / 1224 | 3.80 / 27.53 | 3246 |

Shearwater's value is in brackets where it differs.

## Pump-ins

The dives contain underwater pump-ins: the T1 pressure jumps, buoyancy goes
more negative one sample later, and gas remaining does not move. Dive 1640,
sample 536, at 11 ft: 2102 to 2532 psi, buoyancy -1334 to -2253, gas
remaining 42 to 41 percent. Dive 1637 has a run of them at 50 to 55 ft
(2874 to 3316 psi, buoyancy -751 to -1896).

## Open questions from #4664

- **Hydrotank on T1:** yes in all eight dives (T1 on, T2 to T4 off). One
  diver and one computer, so still an assumption in general.
- **GTR in Avelo mode:** still logged in minutes, see above.
- **Two-computer Avelo dive:** not in this data.
- **Byte 14, 16, 17 meaning:** not established.
