# Decompression

Submersion implements the Buhlmann ZH-L16C decompression algorithm with gradient factor support.

## Overview

The decompression module provides:
- Real-time tissue loading calculations
- NDL (No-Decompression Limit) display
- Ceiling depth calculations
- TTS (Time to Surface) estimates
- 16-compartment visualization

<div class="warning">
<strong>Important:</strong> Submersion's deco calculations are for informational and logging purposes. Always follow your dive computer during the dive.
</div>

## Buhlmann ZH-L16C Algorithm

### What It Is

The Buhlmann algorithm models how nitrogen (and helium) dissolve into and release from body tissues during diving.

### 16 Compartments

Your body is modeled as 16 tissue compartments, each with different:
- **Half-time** - How fast gas loads/unloads
- **M-value** - Maximum tolerable pressure

| Compartment | N2 Half-Time | Speed |
|-------------|--------------|-------|
| 1 | 4 min | Fastest |
| 2 | 8 min | Fast |
| 3 | 12.5 min | Fast |
| ... | ... | ... |
| 16 | 635 min | Slowest |

Fast compartments (1-4) control deep stops and short dives.
Slow compartments (13-16) control long/repetitive dives.

## Gradient Factors

Gradient Factors (GF) add a conservatism margin to the algorithm.

### GF Low / GF High

| Setting | Meaning |
|---------|---------|
| **GF Low** | Conservatism at depth (first stop) |
| **GF High** | Conservatism at surface (last stop) |

### Common Settings

| Profile | GF Low | GF High | Use Case |
|---------|--------|---------|----------|
| Conservative | 30 | 70 | Cautious divers |
| Moderate | 40 | 85 | Balanced approach |
| Aggressive | 55 | 95 | Experienced tech divers |
| Computer default | 100 | 100 | No GF (not recommended) |

<div class="tip">
<strong>Tip:</strong> Start conservative (30/70) and adjust based on experience and research. Consult technical diving training for guidance.
</div>

### Setting Gradient Factors

1. Go to **Settings** > **Decompression**
2. Adjust **GF Low** slider (0-100)
3. Adjust **GF High** slider (0-100)
4. Settings saved per-diver

## Tissue Loading Display

### Deco Info Panel

During profile analysis, view the tissue loading panel:

<div class="screenshot-placeholder">
  <strong>Screenshot: Deco Info Panel</strong><br>
  <em>16-compartment bar chart showing tissue saturation</em>
</div>

### Reading the Display

| Element | Meaning |
|---------|---------|
| Bars | Each bar = one compartment |
| Height | Tissue saturation level |
| Color | Green (safe) → Yellow → Red (limit) |
| Line | M-value limit |

## NDL (No-Decompression Limit)

### What It Shows

NDL is the time you can remain at current depth without requiring mandatory decompression stops.

### NDL Display

- Shown on profile as countdown
- Updates based on depth and time
- Reaches zero when deco required

### Calculating NDL

Submersion calculates NDL using:
- Current depth
- Current gas mix
- Current tissue loading
- Gradient factor settings

## Ceiling

### What It Is

The ceiling is the shallowest depth you can safely ascend to.

### Types of Ceiling

| Type | Description |
|------|-------------|
| **Deco Ceiling** | Mandatory stop depth |
| **Deep Stop** | GF Low-based stop |
| **Safety Ceiling** | Recommended stop |

### Ceiling Visualization

On the profile chart:
- Shaded area shows ceiling
- Ascending above ceiling = violation
- Ceiling rises as you off-gas

## Deco Stops

### Stop Calculation

When deco is required:
1. First stop at ceiling depth
2. Clear ceiling by off-gassing
3. Ascend to next stop
4. Repeat until surface

### Stop Depths

Standard stop depths:
- Every 3 meters (10 feet)
- Last stop typically at 3m (10ft) or 6m (20ft)

### TTS (Time to Surface)

Total time including:
- Current depth
- All deco stops
- Ascent time
- Safety stop (if applicable)

## Profile Analysis

### Ceiling Curve

The profile shows ceiling throughout the dive:
- Dashed line = ceiling depth
- Solid fill = ceiling zone
- Red = ceiling violation

### What to Look For

| Pattern | Meaning |
|---------|---------|
| No ceiling | NDL dive |
| Rising ceiling | Off-gassing |
| Flat ceiling | Deco stop |
| Dropping ceiling | Loading at depth |

## Technical Diving Support

### Multi-Gas

Deco calculations account for:
- Gas switches
- Different mixes at different depths
- Optimal switch depths

[Learn about multi-gas &rarr;](features/multi-gas.md)

### Helium

For trimix dives:
- Helium half-times considered
- Faster on-gassing than N2
- Different M-values

### CCR

For rebreather dives:
- ppO2 setpoint tracking
- Loop gas calculations
- Bailout scenarios

## Limitations

<div class="warning">
<strong>Understand the Limitations:</strong>

- No algorithm perfectly models human physiology
- Individual variation is significant
- Cold, exertion, and dehydration affect DCS risk
- Always use personal dive computer during dives
- Submersion calculations are for analysis, not real-time planning
</div>

## Further Reading

- Buhlmann, A.A. "Decompression-Decompression Sickness"
- Baker, Erik. "Understanding M-values"
- GUE Technical Diving Resources
- TDI Decompression Procedures Manual
