# Scuba trim: what experts and measurements say, and what it means for the trim figure

Date: 2026-11-26. Issue #5028, PR #5031. Web research (ScubaBoard, Andy Davis,
DAN and DAN Europe, GUE standards, X-Ray Mag, Scubaverse, Wikipedia's diver
trim and weighting articles, swimming-science papers), checked against the
trim model in `lib/core/buoyancy/trim/`. Sources are linked per claim. Forum
posts are anecdotes; papers are measurements.

## 1. What holds up in the current model

- **Torque, not angle, is the right output.** A submerged diver's restoring
  couple is weight x BG x sin(tilt), where BG is the small, unknown
  back-to-belly gap between the centres of buoyancy and gravity, so an
  equilibrium angle is indeterminate; torque about the centre of buoyancy is
  the quantity physics and practice support
  ([Wikipedia, diver trim](https://en.wikipedia.org/wiki/Diver_trim);
  [submarine stability](https://www.marineinsight.com/naval-architecture/understanding-stability-submarine/)).
  The figure's tilt is already illustrative; the verdict comes from torque.
- **The float point is close to measured.** The bare body's centre of
  buoyancy sits about 0.385 of height from the crown with arms overhead,
  under 2 cm from its centre of mass (Watanabe et al., ISBS, 9 men,
  [link](https://ojs.ub.uni-konstanz.de/cpa/article/view/6983/6278);
  McLean and Hinrichs 1998,
  [summary](https://coachsci.sdsu.edu/csa/vol55/mclean.htm)). The tuned value
  is 0.363: about 4 cm toward the head.
- **The level band matches what a diver absorbs without kicking.** One breath
  shifts the body's torque by roughly 0.5 to 1 kg m (KAKEN 23500761,
  [report](https://kaken.nii.ac.jp/file/KAKENHI-PROJECT-23500761/23500761seika.pdf);
  Watanabe 2017, [PLoS One](https://pmc.ncbi.nlm.nih.gov/articles/PMC5423637));
  arm and knee posture another 0.4 to 0.8 kg m (derived from Winter's
  segment values). The 0.72 kg m level band sits inside that budget.
- **The suit spread matches body surface.** A full suit's skin coverage
  (Lund-Browder chart) is torso 42%, arms 17%, thighs 23.5%, shins 17%,
  against the model's 40/20/24/16
  ([chart](https://jts.health.mil/assets/docs/forms/ADULT_LUND_BROWDER_BURN_ESTIMATE_DIAGRAM.pdf)).
- **Overweighting tips feet-down,** as the model's wing lift ahead of the
  float point does: lead low and gas high rotate the torso up
  ([Andy Davis](https://scubatechphilippines.com/scuba_blog/horizontal-trim-scuba-diving/);
  [DAN](https://dan.org/alert-diver/article/mastering-neutral-buoyancy-and-trim/)).
- **Fin defaults are in range.** Measured per fin in fresh water: Hollis F1
  -0.59 kg, Hollis F1 LT -0.40, Scubapro Jet -0.30 to -0.45, Apeks RK3 HD
  -0.15, Oceanic Manta -0.18; some splits float slightly
  ([ScubaBoard fin study](https://scubaboard.com/community/threads/fin-buoyancy-study-results.629282/);
  [Jet and F1 comparison](https://scubaboard.com/community/threads/hollis-f1-hollis-f1lt-and-scuba-pro-jet-fins-weight-comparisons.666071/)).
  The model's pairs: paddle 0.6, split 0.2, vented 1.4 (the top of the range,
  F1-class rather than Jet-class).
- **Checking at the final stop is the standard check.** Instructors test trim
  hovering motionless at 3 to 5 m with a near-empty tank, after weighting
  ([Andy Davis](https://scubatechphilippines.com/scuba_blog/scuba-diving-weighting-guide/);
  [Alert Diver Europe](https://alertdiver.eu/en_US/articles/mastering-proper-trim)),
  the card's rest anchor.

## 2. What the research says is wrong or missing

1. **Roll is far too forgiving.** Practitioners report that a 2 lb (0.9 kg)
   left-right difference visibly rolls a diver
   ([ScubaBoard](https://scubaboard.com/community/threads/balance.132616)).
   In the model that is 0.16 kg m of roll, which reads "Level" against the
   0.72 kg m band shared with pitch. A diver has no limbs to correct roll
   with and a small roll restoring moment, so roll needs much tighter bands.
2. **The body's own torque is under-modelled by two to three times.**
   Measured passive torque of a bare body lying straight is 1.1 to 1.44 kg m
   for men and about 0.7 for women (Pendergast et al. 1977, n=64,
   J Appl Physiol 43:475; Watanabe 2014, n=36). The model gives 0.54 kg m in
   the same conditions (fresh water, legs straight, arms overhead), because
   it puts the head and torso at the float point and counts only the limbs.
   The tuned float point and bands partly absorb this today.
3. **Sex changes the body's torque by about half.** Women's centre of mass
   sits closer to their centre of buoyancy (d = 1.36 vs 1.93 cm at neutral
   lungs; 0.75 vs 1.35 kg m derived). The model ignores sex, which the app
   already knows (`DiverSex`, used by the weight prediction).
4. **A tank's mass and buoyancy act at different points.** An aluminium
   cylinder is tail-buoyant: its lift acts at its displacement centroid,
   its valve's mass near the top, so it turns from pulling the butt down to
   floating it around 120 to 160 bar
   ([Andy Davis, sidemount trim](https://scubatechphilippines.com/scuba_blog/ultimate-guide-sidemount-cylinder-trim/);
   [X-Ray Mag](https://old.xray-mag.com/node/15163)). The model puts each
   tank's net weight at one point.
5. **Tank height is the first gear fix, and the model cannot try it.**
   Instructors fix trim in this order: total lead, posture, cylinder height
   on the cam band ("even an inch ... can be a major improvement"), fins,
   then moving lead
   ([ScubaBoard](https://scubaboard.com/community/threads/trimming-for-a-leg-heavy-diver.650232/);
   [Andy Davis](https://scubatechphilippines.com/scuba_blog/scuba-diving-trim-problems/)).
   Try-out can move a tank only between back, sidemount and stage spots.
6. **Thick suits are thicker on the torso.** Weighted by neoprene thickness,
   a 7/5 suit puts about 50% of its lift on the torso, not 40%. The app
   already parses panel thicknesses (`GearBuoyancyTraits.panelThicknessesMm`).
   Farmer johns put even more on the torso
   ([ScubaBoard](https://scubaboard.com/community/threads/trim-changing-with-depth-new-wetsuit.483143/)).
7. **No tool answers "what should I change?".** Every existing tool, including
   the well-regarded Optimal Buoyancy Computer spreadsheet, models total lead
   only, not distribution
   ([ScubaBoard](https://scubaboard.com/community/threads/optimal-buoyancy-computer.576321/)).
   Divers ask exactly the questions the figure can answer: a new drysuit, AL80
   to steel, new fins, a camera rig (Backscatter sets rigs 0.25 to 0.7 kg
   negative, [link](https://backscatter.com/reviews/post/Best-Buoyancy-Solutions-For-Underwater-Cameras)),
   a stage bottle going from heavy to floating.
8. **Agencies state trim in degrees.** GUE Fundamentals allows 30 degrees off
   horizontal, Tech 1 allows 20
   ([GUE Scuba Diver standards](https://www.gue.com/files/Standards_and_Procedures/standards10/ScubaDiver-Standards-v10.4.pdf);
   [Tech 1](https://gue.com/files/Standards_and_Procedures/standards10/Tech1-Standards-v10.1.pdf)).
   The figure cannot honestly compute an angle (point 1), so it should say
   the tilt is a picture of the pull, not a predicted angle.

## 3. Proposed changes, by value

| # | Change | Why | Size |
| --- | --- | --- | --- |
| A | Tighter roll bands (level under about 0.1 kg m, slightly under about 0.25) | Matches "2 lb rolls you"; today any one-sided canister reads level | Small |
| B | "What would level me": rank fixes in the instructors' order (move lead to trim pockets, tank up or down, lighter fins) with each fix's resulting verdict | The question every trim thread asks; no tool answers it | Medium |
| C | Tank height in try-out (move the cylinder up or down the band, about plus or minus 10 cm) and the tank split into valve mass plus cylinder buoyancy | The first gear fix instructors try; makes the AL80 late-dive swing physical | Medium |
| D | Ground the body in measurement: an explicit feet-down body torque from the measured CoB to CoM distance (by sex when known), the float point at the measured 0.385 H, then re-tune the four rigs | Replaces a free constant with data; women read about half as feet-heavy | Medium |
| E | Suit lift split by the suit's panel thicknesses | A 7/5 suit lifts the torso more than the legs | Small |
| F | Copy: say the verdict is for the safety-stop check with the gas left, and that the tilt pictures the pull rather than an angle | Matches how instructors check, and honest about degrees | Small |

Calibration note: D and E move the model and need the four reference rigs
re-tuned (the rig tests stay the acceptance bar). A, B, C and F do not change
existing pitch verdicts.

## 4. Open questions the sources do not settle

- No measured centre of buoyancy for a kitted diver, or measured split of
  wetsuit or undergarment buoyancy between legs and torso.
- No measured comfort threshold for corrective torque; the level band rests
  on the breath and posture budget above.
- Whether a backmount tank's floating butt acts as "tank torque" or simply
  shifts the whole system's centre of mass; modelling mass and buoyancy at
  separate points (change C) agrees with both views.
