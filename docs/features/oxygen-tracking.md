# Oxygen Toxicity Tracking

Monitor CNS%, OTU, and ppO2 exposure for safe nitrox and technical diving.

## Why Track Oxygen?

High oxygen partial pressures can cause:
- **CNS Toxicity** - Seizures underwater (acute)
- **Pulmonary Toxicity** - Lung damage (chronic/OTU)

Submersion tracks both to keep you within safe limits.

## Partial Pressure of Oxygen (ppO2)

### What It Is

ppO2 is the oxygen pressure at depth:

```
ppO2 = (Depth in ATM) × (O2 fraction)
```

Example at 30m (4 ATM) on 32% nitrox:
```
ppO2 = 4 × 0.32 = 1.28 bar
```

### ppO2 Limits

| Limit | Value | Use |
|-------|-------|-----|
| **Working** | 1.4 bar | During active diving |
| **Deco** | 1.6 bar | During deco stops |
| **Maximum** | 1.6 bar | Absolute limit |

<div class="warning">
<strong>Warning:</strong> Exceeding 1.6 bar ppO2 significantly increases seizure risk.
</div>

### ppO2 Display

On the profile:
- ppO2 curve shows oxygen pressure
- Yellow zone above 1.4 bar
- Red zone above 1.6 bar

## CNS% (Central Nervous System)

### What It Is

CNS% tracks acute oxygen exposure as a percentage of the NOAA limit. 100% = maximum single-dive exposure.

### NOAA Exposure Limits

| ppO2 | Time Limit |
|------|------------|
| 1.6 bar | 45 minutes |
| 1.5 bar | 120 minutes |
| 1.4 bar | 150 minutes |
| 1.3 bar | 180 minutes |
| 1.2 bar | 210 minutes |
| 1.1 bar | 240 minutes |
| 1.0 bar | 300 minutes |

### CNS Calculation

Each minute of exposure accumulates CNS%:

```
CNS% per minute = 100 / (limit at current ppO2)
```

### CNS Display

<div class="screenshot-placeholder">
  <strong>Screenshot: O2 Toxicity Card</strong><br>
  <em>CNS% and OTU display with warning thresholds</em>
</div>

Submersion shows:
- **CNS Start** - Percentage at dive start
- **CNS End** - Percentage at dive end
- **Peak CNS** - Maximum during dive

### CNS Warning Levels

| Level | Threshold | Action |
|-------|-----------|--------|
| Normal | < 80% | Safe to continue |
| Warning | 80-100% | Consider surfacing |
| Danger | > 100% | High seizure risk |

## OTU (Oxygen Tolerance Units)

### What It Is

OTUs track cumulative pulmonary (lung) oxygen exposure over multiple dives.

### OTU Calculation

```
OTU = time × ((ppO2 - 0.5) / 0.5)^0.83
```

### Daily Limits

| Exposure Type | OTU Limit |
|---------------|-----------|
| Single dive | ~300 OTU |
| Daily total | ~600 OTU |
| Weekly average | ~300 OTU/day |

### OTU Tracking

Submersion tracks:
- OTU per dive
- Cumulative OTU over multiple dives
- Rolling totals

## Multi-Dive Considerations

### CNS Decay

CNS% decays during surface intervals:
- Half-life: ~90 minutes
- Nearly zero after 12 hours

### OTU Accumulation

OTUs accumulate over days:
- Track daily totals
- Monitor weekly patterns
- Allow recovery between dive days

## Settings

Configure O2 tracking in **Settings** > **Decompression**:

| Setting | Default | Description |
|---------|---------|-------------|
| **ppO2 Max Working** | 1.4 bar | Working phase limit |
| **ppO2 Max Deco** | 1.6 bar | Deco phase limit |
| **CNS Warning** | 80% | When to show warning |

## Profile Visualization

### ppO2 Curve

Toggle the ppO2 overlay on profiles:
- Green zone: < 1.4 bar
- Yellow zone: 1.4 - 1.6 bar
- Red zone: > 1.6 bar

### CNS Accumulation

View CNS buildup throughout the dive as a cumulative curve.

## Gas Planning

### MOD (Maximum Operating Depth)

For a given O2%:
```
MOD = ((ppO2 limit / O2%) - 1) × 10m
```

Example for EAN32 at 1.4 ppO2:
```
MOD = ((1.4 / 0.32) - 1) × 10 = 33.75m
```

### Best Mix

For a given depth, the optimal O2% with target ppO2:
```
Best Mix = ppO2 / (depth in ATM)
```

## Technical Diving

### CCR Considerations

For rebreathers:
- Track setpoint changes
- Monitor diluent O2
- Account for bailout scenarios

### Multi-Gas Dives

Track O2 exposure across:
- Bottom gas
- Travel gas
- Deco gases

[Learn about multi-gas &rarr;](features/multi-gas.md)

## Safety Recommendations

1. **Stay below limits** - 1.4 bar working, 1.6 bar deco
2. **Monitor CNS%** - Keep below 80% as buffer
3. **Track across dives** - CNS and OTU accumulate
4. **Allow recovery** - Surface time matters
5. **Consider factors** - Cold, exertion, CO2 affect tolerance
6. **Get trained** - Formal nitrox/tech training essential

## Further Reading

- NOAA Diving Manual - Oxygen Exposure
- TDI Nitrox Diver Manual
- GUE Nitrox Primer
- IANTD Oxygen Management
