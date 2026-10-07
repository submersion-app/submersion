# Glossary

Common diving and app terms used throughout this wiki, in alphabetical order.

---

**Air** — A gas mixture of approximately 21% oxygen and 79% nitrogen (Submersion uses 21% O₂ / 79.02% N₂ internally) used as the baseline breathing gas for recreational diving. See [Planning & Calculators](planning.md).

**Ascent rate** — How fast you travel toward the surface, measured in metres per minute (m/min). Submersion colours the ascent-rate overlay green at or below 9 m/min (~30 ft/min), orange above 9 m/min up to 12 m/min (~40 ft/min), and red above 12 m/min; both thresholds are adjustable in Settings. See [Dive Profiles & Deco](dive-profiles.md).

**Bottom time** — The time spent at depth, not counting the descent or ascent. In Submersion's dive form, Bottom Time is the number you fill in for "time at depth"; Runtime (entry to exit) is tracked separately and is used to calculate your SAC rate. See [Logging Dives](dive-logging.md).

**Bühlmann ZH-L16C** — The decompression algorithm Submersion uses for all its calculated ceilings, NDL, and TTS figures. It models inert-gas absorption and release in 16 theoretical tissue compartments using nitrogen half-times from 4 to 635 minutes and helium half-times approximately 2.65× faster. The "C" variant contains coefficients validated for conservatism; gradient factors are applied on top for additional safety margin. See [Dive Profiles & Deco](dive-profiles.md).

**CCR (closed-circuit rebreather)** — A type of rebreather that recirculates your exhaled gas through a CO₂ scrubber and injects pure oxygen to maintain a target partial pressure (the setpoint), producing no bubbles. Submersion records CCR dives with setpoints (low/high/deco), diluent gas, and scrubber details. See [Logging Dives](dive-logging.md).

**CNS% (central nervous system oxygen toxicity)** — A running percentage of your daily central-nervous-system oxygen exposure limit, calculated from time spent at various ppO₂ levels using NOAA exposure tables. Submersion accumulates CNS% across segments of a dive (including any residual carried from earlier dives in the same day) and warns at 80%; reaching 100% carries a risk of oxygen convulsion. See [Dive Profiles & Deco](dive-profiles.md).

**Conservatism** — How cautiously the decompression model is applied. In Submersion, conservatism is set by adjusting the gradient factors: lower gradient-factor numbers produce more conservative (shorter NDL, deeper first stop) outcomes. The default GF 50/85 corresponds to the "Medium" (balanced) preset in the app's preset list. See [Settings](settings.md).

**Decompression (deco)** — The controlled ascent procedure required when inert-gas loading in one or more tissue compartments exceeds the limit that allows a direct ascent to the surface. Once in a deco obligation, Submersion calculates the stop schedule (depths and durations) needed to safely off-gas before surfacing. See [Dive Profiles & Deco](dive-profiles.md).

**Diluent** — On a closed-circuit rebreather (CCR), the gas mixed with pure oxygen inside the breathing loop to provide inert gas and bulk volume. Common diluents include air, nitrox, or trimix. Submersion records the diluent gas mix under the CCR settings panel in the dive form. See [Logging Dives](dive-logging.md).

**EAD (equivalent air depth)** — The depth at which air would produce the same nitrogen partial pressure as a nitrox mix breathed at the actual depth. EAD is a planning shortcut: a nitrox dive to 30 m on EAN32 has an EAD of roughly 25 m on air, giving a longer NDL. See [Planning & Calculators](planning.md).

**END (equivalent narcotic depth)** — The depth at which air would produce the same narcotic effect as the actual gas mix breathed at the actual depth. Helium is considered non-narcotic, so adding helium to a mix reduces END. Submersion can treat oxygen as narcotic (the more conservative assumption, on by default) or consider only nitrogen. See [Planning & Calculators](planning.md).

**Gas density** — The mass of breathing gas per unit volume at depth, in grams per litre (g/L). Submersion calculates density from the ambient pressure and the molecular weights of the gas components (O₂ = 32 g/mol, N₂ = 28 g/mol, He = 4 g/mol). Densities above roughly 5.7 g/L increase CO₂ retention risk, which is why deep dives on air or heavy nitrox mixes benefit from helium. See [Dive Profiles & Deco](dive-profiles.md).

**Gradient factors (GF Low / GF High)** — Two numbers (each 10–100, expressed as percentages) that scale how close Submersion's Bühlmann model allows tissue loading to approach the theoretical M-value limit before requiring a stop. **GF Low** controls the depth of the first (deepest) stop: a lower value places the stop deeper, reducing bubble formation during the initial ascent. **GF High** controls the surfacing target: it is the gradient factor used to determine whether you can ascend to the surface (and to compute the NDL). The effective gradient factor between stops is linearly interpolated from GF Low at the first stop depth to GF High at the surface. The app default is 50/85 (the "Medium" preset); the planner uses the same app-settings gradient factors. A lower pair of numbers is more conservative. See [Dive Profiles & Deco](dive-profiles.md) and [Settings](settings.md).

**MND (maximum narcotic depth)** — The deepest depth at which a given gas mix stays within an acceptable narcotic-effect limit (the END limit you set). Adding helium to a trimix blend pushes the MND deeper. In the dive form you can enter a target MND and Submersion back-calculates the helium percentage needed. See [Planning & Calculators](planning.md) and [Logging Dives](dive-logging.md).

**MOD (maximum operating depth)** — The deepest depth at which a gas may be safely breathed before its oxygen partial pressure (ppO₂) reaches an unsafe level. Submersion calculates MOD at a ppO₂ of 1.4 bar for standard display (the conservative limit for working dives) and warns if you plan or log a dive deeper than the MOD of the gas in use. See [Dive Profiles & Deco](dive-profiles.md) and [Planning & Calculators](planning.md).

**NDL (no-decompression limit)** — The maximum time you can remain at your current depth before incurring a mandatory decompression stop. Submersion calculates NDL by simulating continued time at depth until the tissue loading would prevent a direct ascent to the surface (using the GF High surfacing target). The NDL overlay reads `DECO` once you are in obligation. See [Dive Profiles & Deco](dive-profiles.md).

**Nitrox (EANx)** — Any oxygen-enriched air mixture with more than 21% oxygen and the remainder nitrogen; also called Enriched Air Nitrox (EANx, where x is the oxygen percentage, e.g. EAN32). A higher oxygen fraction lowers the MOD but extends the NDL at moderate depths. Submersion labels any mix above 21% O₂ without helium as EAN followed by the percentage. See [Logging Dives](dive-logging.md) and [Planning & Calculators](planning.md).

**OC (open circuit)** — Standard scuba: you breathe from a tank through a regulator and exhale each breath into the water. This is the default dive mode in Submersion; the other modes are CCR and SCR. See [Logging Dives](dive-logging.md).

**OTU (oxygen tolerance unit)** — A measure of cumulative pulmonary oxygen exposure, calculated using the formula OTU = t × ((ppO₂ − 0.5) / 0.5)^0.833, where t is time in minutes. OTU tracks long-term lung exposure across multiple dives in a day or over a week; a safe daily limit is typically 300–600 OTU depending on the source. Submersion displays cumulative OTU as a profile overlay. See [Dive Profiles & Deco](dive-profiles.md).

**ppO₂ / ppN₂ / ppHe (partial pressures)** — The pressure contributed by one gas component in a mixture, in bar. At any depth, the partial pressure of each gas equals the ambient pressure multiplied by that gas's fraction (e.g. ppO₂ = ambient pressure × O₂ fraction). Submersion plots ppO₂, ppN₂, and ppHe as profile overlays; ppHe is only available on trimix dives. The safe ppO₂ working limit is 1.4 bar (warning) and 1.6 bar (critical). See [Dive Profiles & Deco](dive-profiles.md).

**RBT (remaining bottom time)** — How much longer you can stay at your current depth before you must start ascending to reach the surface within your decompression limits and gas supply. RBT combines NDL and gas reserve into a single countdown; some dive computers display it in real time. Submersion does not currently display RBT as a standalone metric but the NDL overlay serves the same role for decompression planning. See [Dive Profiles & Deco](dive-profiles.md).

**RMV (respiratory minute volume)** — The actual volume of gas you breathe per minute at depth, in litres per minute (L/min), before normalising to the surface. RMV = SAC × (ambient pressure in bar). Submersion uses RMV internally in SCR calculations (the PASCR formula uses RMV × addition ratio) but displays breathing rates to the user as SAC. See [Planning & Calculators](planning.md).

**Runtime** — The total elapsed time of a dive from entry to exit, including descent and ascent. Submersion distinguishes runtime from bottom time: the SAC rate is calculated from runtime and average depth, so accurate entry and exit times are important for meaningful gas-use figures. See [Logging Dives](dive-logging.md).

**SAC (surface air consumption)** — Your breathing rate normalised to the surface, in litres per minute (L/min) or pressure per minute depending on your unit setting. Submersion computes SAC from the first tank's pressure drop, the tank volume, the average depth, and the runtime: SAC = (volume × pressure used) ÷ (runtime in minutes × average ambient pressure in bar). A lower SAC means more efficient breathing; it is the number used in gas-consumption planning and in the Statistics Air Consumption dashboard. See [Statistics](statistics.md) and [Planning & Calculators](planning.md).

> [!NOTE]
> Submersion uses **SAC** (surface air consumption) as its primary breathing-rate term throughout the app — in the dive form, profile overlay, and planning tools. The related term **RMV** (respiratory minute volume) is used internally in SCR calculations. Both describe breathing efficiency; SAC normalises to the surface, making it depth-independent and directly comparable across dives.

**SCR (semi-closed rebreather)** — A rebreather that injects a metered flow of fresh supply gas into the breathing loop and vents a portion of the exhaled gas, making it a partial loop between open-circuit and full CCR. Submersion records SCR dives with injection rate, assumed VO₂, supply gas, and measured loop O₂. Three SCR sub-types are supported: CMF (constant mass flow), PASCR (passive addition), and ESCR (electronically controlled). See [Logging Dives](dive-logging.md).

**Setpoint** — On a CCR, the target oxygen partial pressure (in bar) that the electronics maintain in the breathing loop by controlling oxygen injection. Submersion records three setpoints per CCR dive: Low (used during descent and ascent, typically ~0.7 bar), High (bottom phase, typically 1.2–1.3 bar), and Deco (ascent/decompression phase, typically 1.3–1.6 bar). See [Logging Dives](dive-logging.md).

**Surface interval** — The time spent at the surface between two consecutive dives. Submersion calculates and displays surface interval automatically on the dive form (from the preceding dive's exit time) and records it in the log. The Planning surface-interval tool uses the Bühlmann model to find the minimum surface interval before a planned repetitive dive. See [Planning & Calculators](planning.md) and [Logging Dives](dive-logging.md).

**Tissue compartments** — The 16 theoretical mathematical compartments used by the Bühlmann ZH-L16C model to represent different body tissues with varying rates of inert-gas uptake and release. Each compartment has its own nitrogen half-time (4 to 635 minutes) and helium half-time (roughly 2.65× faster), and its own M-value coefficients (a and b) defining the maximum tolerated supersaturation. Submersion visualises all 16 compartments in the tissue heat map and stacked area chart below the dive profile. See [Dive Profiles & Deco](dive-profiles.md).

**Trimix** — A breathing gas containing oxygen, helium, and nitrogen. Adding helium reduces narcosis (lower END) and, because helium is lighter, also reduces gas density at depth. Submersion records trimix mixes as Tx O₂%/He% (for example, Tx 18/45) and supports trimix in both the dive log and the planning tools. See [Logging Dives](dive-logging.md) and [Planning & Calculators](planning.md).

**TTS (time to surface)** — The total modelled time needed to ascend from your current depth to the surface, including any required decompression stop times and the travel time between stops, at the configured ascent rate (default 9 m/min). On a no-stop dive, Submersion still includes the recommended 3-minute safety stop at 5 m (16 ft) in the TTS figure, so it reflects a realistic ascent rather than an instantaneous one. See [Dive Profiles & Deco](dive-profiles.md).

---

## See also

- [Dive Profiles & Deco](dive-profiles.md) — ceilings, NDL, TTS, tissue loading, and the Bühlmann model in detail
- [Planning & Calculators](planning.md) — MOD, best mix, END/MND, gas consumption, and surface interval tools
- [Logging Dives](dive-logging.md) — recording gas mixes, SAC rate, bottom time, and rebreather settings
