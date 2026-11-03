/// The groups of plan settings a repetitive series shares (issue #3565):
/// the sections of the planner's Setup, named as those sections are, and the
/// tanks. A tank's start pressure is not part of it: that carries from the
/// dive before.
/// The first dive's settings are the series': a later dive either takes the
/// series' value of a group or overrides it with its own.
///
/// Left out, because they change a dive's segments or depend on its circuit:
/// the circuit and its setpoints, stop minimums, gear and
/// weights, the DPV mission and the site.
enum PlanSettingGroup { deco, rates, gas, environment, contingencies, tanks }
