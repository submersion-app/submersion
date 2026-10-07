# Glossary

Common diving and app terms used throughout this guide, in alphabetical order.

---

**Air:** A gas of about 21% oxygen and 79% nitrogen (Submersion uses 21% O₂ and 79.02% N₂ internally), the baseline breathing gas for recreational diving. See [Planning & Calculators](planning.md).

**Ascent rate:** How fast you travel toward the surface, in metres per minute (m/min). Submersion colours the ascent-rate overlay green at or below 9 m/min (about 30 ft/min), orange above 9 and up to 12 m/min (about 40 ft/min), and red above 12 m/min. See [Dive Profiles & Deco](dive-profiles.md).

**Bottom time:** The time from leaving the surface to the start of the final ascent, so it includes the descent but not the ascent or shallow stops (the dive-table convention). Submersion keeps it apart from runtime (entry to exit), which is what your gas consumption is calculated from. See [Logging Dives](dive-logging.md).

**Bühlmann ZH-L16C:** The decompression model Submersion uses for its calculated ceilings, NDL and TTS. It models inert gas going into and out of 16 theoretical tissue compartments, with nitrogen half-times from 4 to 635 minutes and helium half-times about 2.65 times faster. The "C" variant has coefficients adjusted for conservatism, and gradient factors add a further margin on top. See [Dive Profiles & Deco](dive-profiles.md).

**CCR (closed-circuit rebreather):** A rebreather that recirculates your exhaled gas through a CO₂ scrubber and adds pure oxygen to hold a target partial pressure (the setpoint), producing no bubbles. Submersion records CCR dives with their setpoints, diluent gas and scrubber details. See [Logging Dives](dive-logging.md).

**CNS% (central nervous system oxygen toxicity):** Your oxygen exposure as a percentage of the daily central-nervous-system limit, built up from time spent at each ppO₂ using the NOAA exposure limits. Submersion carries CNS from one dive to the next, letting it fall at the surface with a half-time of 90 minutes, and warns at 80%; 100% carries a risk of an oxygen convulsion. **Current CNS/OTU load** in Planning shows where yours stands now, and Settings offers three ways of counting it. See [Dive Profiles & Deco](dive-profiles.md) and [Settings](settings.md).

**Conservatism:** How cautiously the decompression model is applied. In Submersion you set it with the gradient factors: lower numbers are more conservative (shorter NDL, deeper first stop). The default, GF 50/85, is the "Medium" preset. See [Settings](settings.md).

**Decompression (deco):** The controlled ascent needed when the inert gas in one or more tissue compartments is too high to allow a direct ascent to the surface. Once you have a deco obligation, Submersion works out the stops (depths and times) needed to off-gas safely before surfacing. See [Dive Profiles & Deco](dive-profiles.md).

**Diluent:** On a closed-circuit rebreather, the gas mixed with pure oxygen in the breathing loop to provide inert gas and volume. Common diluents are air, nitrox and trimix. Submersion records the diluent in the CCR section of the dive form. See [Logging Dives](dive-logging.md).

**EAD (equivalent air depth):** The depth at which air would give the same nitrogen partial pressure as a nitrox mix at the actual depth. A dive to 30 m on EAN32 has an EAD of about 24 m, so a longer NDL than air. See [Planning & Calculators](planning.md).

**END (equivalent narcotic depth):** The depth at which air would give the same narcotic effect as the gas you are breathing at the actual depth. Helium is treated as not narcotic, so adding helium lowers the END. Submersion can treat oxygen as narcotic too (the more conservative choice, on by default) or count only nitrogen. See [Planning & Calculators](planning.md).

**Gas density:** The mass of breathing gas per litre at depth, in grams per litre (g/L), worked out from the ambient pressure and the gases in the mix. Dense gas is harder to breathe and raises the risk of CO₂ build-up; the planner warns above 5.2 g/L and treats 6.2 g/L as critical, which is why deep dives use helium. See [Planning & Calculators](planning.md).

**Gradient factors (GF Low / GF High):** Two percentages that set how close Submersion's Bühlmann model lets your tissues come to their theoretical limit (the M-value) before it requires a stop. **GF Low** sets the depth of the first, deepest stop: a lower value puts it deeper. **GF High** sets the limit for surfacing, and is what the NDL is worked out from. Between them, the gradient factor rises in a straight line from GF Low at the first stop to GF High at the surface. In Settings each runs from 15 to 100; the default is 50/85 (the "Medium" preset), and the planner starts from the same values. Lower numbers are more conservative. See [Dive Profiles & Deco](dive-profiles.md) and [Settings](settings.md).

**GTR (gas time remaining):** How long your gas lasts at your current depth and breathing rate before you must start a direct ascent that reaches the surface with your reserve pressure left. Submersion can plot it on the profile, from your computer's figure or its own calculation, and you set the reserve in Settings. See [Dive Profiles & Deco](dive-profiles.md).

**MND (maximum narcotic depth):** The deepest you can take a gas while staying within your END limit. Adding helium pushes the MND deeper. In the dive form you can enter a target MND and Submersion works out the helium needed. See [Planning & Calculators](planning.md) and [Logging Dives](dive-logging.md).

**MOD (maximum operating depth):** The deepest you can breathe a gas before its oxygen partial pressure (ppO₂) becomes unsafe. Submersion shows MOD at a ppO₂ of 1.4 bar and warns when a dive or plan goes deeper than the MOD of the gas in use. See [Dive Profiles & Deco](dive-profiles.md) and [Planning & Calculators](planning.md).

**NDL (no-decompression limit):** How much longer you can stay at your current depth before a decompression stop becomes mandatory. Submersion calculates it by simulating more time at depth until a direct ascent to the surface would no longer be allowed (using GF High). By default the profile shows your dive computer's own NDL where it recorded one, and the calculated value otherwise; choose in **Data Source Preferences** (see [Settings](settings.md)). The NDL overlay reads `DECO` once you have an obligation. See [Dive Profiles & Deco](dive-profiles.md).

**Nitrox (EANx):** Any air enriched with more than 21% oxygen, the rest nitrogen; also called Enriched Air Nitrox (EANx, where x is the oxygen percentage, as in EAN32). More oxygen lowers the MOD but lengthens the NDL at moderate depths. Submersion names any mix above 21% oxygen with no helium EAN and its percentage. See [Logging Dives](dive-logging.md) and [Planning & Calculators](planning.md).

**OC (open circuit):** Standard scuba: you breathe from a tank through a regulator and exhale each breath into the water. This is Submersion's default dive mode; the others are CCR, SCR and Gauge. See [Logging Dives](dive-logging.md).

**OTU (oxygen tolerance unit):** A measure of total lung (pulmonary) oxygen exposure, from the formula OTU = t × ((ppO₂ − 0.5) / 0.5)^0.833, where t is time in minutes. Submersion shows OTU as a profile overlay, and **Current CNS/OTU load** compares it with a daily limit of 300 and a weekly limit of 850. See [Dive Profiles & Deco](dive-profiles.md).

**ppO₂ / ppN₂ / ppHe (partial pressures):** The pressure from one gas in a mix, in bar: the ambient pressure times that gas's fraction (ppO₂ = ambient pressure × O₂ fraction). Submersion plots all three as profile overlays; ppHe only on trimix dives. Your open-circuit ppO₂ limits are 1.4 bar working and 1.6 bar maximum by default, set in [Settings](settings.md). See [Dive Profiles & Deco](dive-profiles.md).

**RBT (remaining bottom time):** How much longer you can stay at your current depth, within both your decompression limits and your gas. Some dive computers show it live. Submersion does not show RBT as one figure; NDL and GTR give its two halves. See [Dive Profiles & Deco](dive-profiles.md).

**RMV (respiratory minute volume):** The volume of gas you breathe per minute, scaled to the surface, in litres per minute (L/min) or cubic feet per minute. It needs a tank volume to work out. Settings can show it alongside or instead of SAC. See [Settings](settings.md).

**Runtime:** The total time of a dive from entry to exit, including descent and ascent. Your gas consumption is calculated from runtime and average depth, so accurate entry and exit times give meaningful figures. See [Logging Dives](dive-logging.md).

**SAC (surface air consumption):** Your breathing rate as tank pressure used per minute, scaled to the surface (bar/min or psi/min). It works with any logged pressures, even without a tank volume. A lower SAC means more efficient breathing. See [Insights](statistics.md) and [Planning & Calculators](planning.md).

> [!NOTE]
> **SAC or RMV?** Both measure how fast you breathe, scaled to the surface so
> dives at different depths compare. SAC is in pressure per minute, so it is tied
> to the tank you used; RMV is in volume per minute, so it compares across tanks
> of different sizes. **Gas consumption** in **Settings > Units** chooses which
> one Submersion shows, or both (the default).

**SCR (semi-closed rebreather):** A rebreather that adds a metered flow of fresh gas to the breathing loop and vents some of the exhaled gas, part way between open circuit and a full CCR. Submersion records SCR dives with their injection rate, assumed oxygen consumption, supply gas and measured loop oxygen, for three types: constant mass flow (CMF), passive addition (PASCR) and electronically controlled (ESCR). See [Logging Dives](dive-logging.md).

**Setpoint:** On a CCR, the oxygen partial pressure (in bar) the electronics hold in the breathing loop. Submersion records three per CCR dive: Low, for the descent and ascent (typically about 0.7 bar); High, for the bottom (typically 1.2 to 1.3 bar); and Deco, for decompression (typically 1.3 to 1.6 bar). See [Logging Dives](dive-logging.md).

**Surface interval:** The time spent at the surface between two dives. Submersion works it out from the previous dive's exit time and shows it on the dive. The Surface Interval tool in Planning uses the Bühlmann model to find the shortest wait before a planned repetitive dive. See [Planning & Calculators](planning.md) and [Logging Dives](dive-logging.md).

**Tissue compartments:** The 16 theoretical compartments the Bühlmann ZH-L16C model uses to represent body tissues that take up and release inert gas at different rates. Each has its own nitrogen half-time (4 to 635 minutes), a helium half-time about 2.65 times faster, and its own limits on how much excess gas it tolerates. Submersion shows all 16 in the tissue heat map and chart below the dive profile. See [Dive Profiles & Deco](dive-profiles.md).

**Trimix:** A breathing gas of oxygen, helium and nitrogen. Helium reduces narcosis (a lower END) and, being light, makes the gas less dense at depth. Submersion writes trimix as Tx O₂/He (for example, Tx 18/45) and supports it in the dive log and the planning tools. See [Logging Dives](dive-logging.md) and [Planning & Calculators](planning.md).

**TTS (time to surface):** The time needed to reach the surface from your current depth: the ascent plus any required decompression stops. Submersion's calculated TTS uses your ascent rates (9 m/min by default) and does not include the recommended safety stop. By default the profile shows your dive computer's own TTS where it recorded one, which follows the computer's model and conventions; choose in **Data Source Preferences** (see [Settings](settings.md)). See [Dive Profiles & Deco](dive-profiles.md).

---

## See also

- [Dive Profiles & Deco](dive-profiles.md): ceilings, NDL, TTS, tissue loading and the Bühlmann model in detail
- [Planning & Calculators](planning.md): MOD, best mix, END and MND, gas consumption, and surface interval tools
- [Logging Dives](dive-logging.md): recording gas mixes, consumption, bottom time and rebreather settings
