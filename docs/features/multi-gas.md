# Multi-Gas Diving

Track air, nitrox, and trimix configurations with full gas switch support.

## Gas Mix Support

Submersion supports all common breathing gases:

| Gas Type | O2% | He% | Use Case |
|----------|-----|-----|----------|
| **Air** | 21% | 0% | Recreational diving |
| **Nitrox** | 22-40% | 0% | Extended NDL |
| **Trimix** | Variable | Variable | Deep technical |
| **Heliox** | Variable | Balance | Commercial |

## Tank Configuration

### Adding Tanks

Each dive can have multiple tanks:

1. In dive entry, go to **Tanks** section
2. Tap **+ Add Tank**
3. Configure the tank
4. Repeat for additional tanks

### Tank Fields

| Field | Description |
|-------|-------------|
| **Volume** | Tank size (L or cu ft) |
| **Working Pressure** | Rated pressure |
| **Start Pressure** | Pressure at dive start |
| **End Pressure** | Pressure at dive end |
| **O2%** | Oxygen percentage |
| **He%** | Helium percentage (0 for air/nitrox) |
| **Tank Role** | Purpose (see below) |
| **Tank Name** | Custom identifier |

### Tank Roles

| Role | Description |
|------|-------------|
| **Back Gas** | Primary breathing gas |
| **Stage** | Carried stage bottle |
| **Deco** | Decompression gas |
| **Bailout** | CCR bailout |
| **Sidemount Left** | Left sidemount |
| **Sidemount Right** | Right sidemount |
| **Pony** | Emergency bottle |

## Nitrox

### What Is Nitrox?

Enriched Air Nitrox (EAN) contains more oxygen than air:
- EAN32 = 32% O2 (most common)
- EAN36 = 36% O2
- Range: 22-40% O2 typical

### Benefits

- Extended no-decompression limits
- Shorter surface intervals
- Less nitrogen loading

### Limitations

- Reduced maximum operating depth
- O2 toxicity concerns
- Requires certification

### Nitrox in Submersion

1. Set O2% when configuring tank
2. MOD calculated automatically
3. CNS% tracked during dive
4. Profile shows ppO2 overlay

### MOD Calculator

For any nitrox mix:
```
MOD = ((1.4 / O2%) - 1) × 10 meters
```

| Mix | MOD at 1.4 ppO2 |
|-----|-----------------|
| EAN32 | 33.8m / 111ft |
| EAN36 | 28.9m / 95ft |
| EAN40 | 25.0m / 82ft |

## Trimix

### What Is Trimix?

Trimix contains oxygen, helium, and nitrogen:
- Reduces narcosis at depth
- Enables deeper diving
- Requires technical training

### Notation

Trimix is described as:
```
TX O2/He (e.g., TX 21/35)
```
- 21% Oxygen
- 35% Helium
- 44% Nitrogen (balance)

### Trimix in Submersion

1. Set both O2% and He%
2. END calculated automatically
3. Helium loading tracked
4. Deco calculated for helium

### END (Equivalent Narcotic Depth)

END represents the equivalent air depth for narcosis:
```
END = (1 - He%) × Depth
```

Example at 60m on TX 21/35:
```
END = 0.65 × 60m = 39m
```

## Gas Switches

### Recording Switches

When you switch gases during a dive:

1. Download includes switch events
2. Or manually add via **Profile Events**
3. Specify time and new tank

### Switch Display

On the profile:
- Yellow marker at switch point
- Gas mix label changes
- ppO2 curve adjusts

### Deco Optimization

Submersion accounts for gas switches in deco calculations:
- Higher O2 at deco depths
- Accelerated off-gassing
- Optimal switch depths

## Best Mix Calculator

Find the optimal mix for your dive:

### For Nitrox

Target: Maximum O2 while staying under ppO2 limit

```
Best O2% = (ppO2 limit / max depth ATM) × 100
```

### For Trimix

Target: Acceptable END and ppO2

1. Set target END (typically 30m/100ft)
2. Calculate He% needed
3. Set O2% for ppO2 limit

## SAC Calculation

### Per-Tank SAC

For dives with multiple tanks:
- SAC calculated per tank
- Based on pressure drop
- Depth and time normalized

### SAC Formula

```
SAC = (start - end) × volume / (avg depth ATM × time)
```

## Multi-Tank Display

<div class="screenshot-placeholder">
  <strong>Screenshot: Multi-Tank Configuration</strong><br>
  <em>Multiple tanks with different gas mixes configured</em>
</div>

### Tank Cards

Each tank shows:
- Gas mix (e.g., "EAN32" or "TX 21/35")
- Pressure (start → end)
- Volume and material
- Role badge

## CCR Support

### Rebreather Dives

For CCR dives, track:
- **Setpoint** changes
- **Diluent** gas mix
- **O2 and diluent** consumption
- **Bailout** gases

### Dive Mode

Set dive mode in dive entry:
- **OC** - Open Circuit
- **CCR** - Closed Circuit Rebreather
- **SCR** - Semi-Closed Rebreather

## Gas Planning Tips

### Redundancy

- Always plan bailout gas
- Account for buddy sharing
- Use thirds rule or similar

### Switch Depths

Optimal gas switch depths:
- Switch to richer mix on ascent
- Consider ppO2 at switch depth
- Plan for contingencies

### Minimum Gas

Calculate minimum gas:
- Required for safe ascent
- Including deco if applicable
- Add margin for emergencies

## Certification Requirements

<div class="warning">
<strong>Training Required:</strong>

- **Nitrox**: Nitrox certification required
- **Trimix**: Technical diving certification required
- **CCR**: Rebreather-specific certification required

Never dive gas mixes beyond your training level.
</div>
