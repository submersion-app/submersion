/// How the counterfactual timeline is produced.
///
/// [replay] keeps the recorded depth path and changes only inputs (gas,
/// gradient factors, consumption). [replan] hands the remainder of the dive
/// to the planner engine, which computes the ascent and decompression.
enum ScenarioMode { replay, replan }
