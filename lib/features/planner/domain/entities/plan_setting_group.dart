/// The groups of plan settings a repetitive series shares (issue #3565),
/// one per section of the planner's Setup, named as those sections are.
/// The first dive's settings are the series': a later dive either takes the
/// series' value of a group or overrides it with its own.
///
/// Left out, because they change a dive's tanks or segments rather than how
/// it is computed: the circuit and its setpoints, stop minimums, gear and
/// weights, the DPV mission and the site.
enum PlanSettingGroup { deco, rates, gas, environment, contingencies }
