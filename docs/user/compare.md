# Compare

A dive has three profiles: as planned, as dived, and as it might have gone.
Compare puts them side by side on the dive, so you can see how close you came
to your plan and what a different decision would have changed.

> [!NOTE]
> **Where to find it:** open a dive and scroll to its **Compare** section, or
> choose **Compare...** from the dive's menu. Tap the section's chart or title
> to open the full Compare page.

## What you see

The section has three parts.

**Chips**, one for each line. Tap a chip to turn its line and its column on or
off.

| Chip | What it is |
|------|------------|
| **Planned** | The plan linked to this dive. Only there when a plan is linked |
| **As dived** | The dive itself. Always on |
| One per saved what-if | A question you saved about this dive, named as you named it |
| **What if** | Opens the Compare page to ask a new one |

A dive opens with Planned, As dived and your newest what-if showing. Older
what-ifs wait for you to turn them on.

**The chart** draws the dive's profile with the plan and each what-if over it,
on one time axis that starts when the dive did. If the dive went into deco, a
marker shows where.

**The table** has a column for each line that is on:

| Row | What it means |
|-----|---------------|
| **Max depth** | The deepest point |
| **Bottom time** | From leaving the surface to the start of the final ascent |
| **NDL on leaving bottom** | Minutes of no-deco time left at the end of the deep part of the dive, or **Deco at m:ss** if the line went into deco |
| **Deco** | The stops required on leaving the bottom and, for a dive or a what-if, the time spent under an obligation after that |
| **Runtime** | Surface to surface |
| **Surface GF** | How close your tissues were to their limit on surfacing |

A blank cell means that line has no value there. A dive logged by hand with no
profile, for example, has no NDL or surface GF. A dived value that went past
the plan by more than a rounding difference is shown in red.

Tap a what-if's column heading to open it on the Compare page.

## Linking a plan to a dive

A plan links to one dive, and a dive to one plan. There are three ways to make
the link.

### Convert to Dive, before you go

In the planner, **Convert to Dive** puts a planned dive in your log, linked to
the plan. Its Compare section reads **Waiting for the dive** until the real dive
arrives.

### Download the dive

When you download from a dive computer, a dive that matches nothing in your log
is offered as **Fill planned dive** if you have a planned dive on the same day
or the day before. That covers a dive pushed back a day and a night dive logged
after midnight. If several planned dives fit, the closest in time wins. The
planned dive keeps its id, so the link to the plan survives. You can choose a
different planned dive, or import the download as a new dive, before you finish.

### Link by hand

From the dive, choose **Link a plan** in the Compare section or in the Compare
page's menu. Plans that are free come first, newest at the top, followed by
plans already linked to another dive, greyed, with the dive they belong to.

From the plan, choose **Link to a logged dive** in the saved plans list or the
plan's menu. Your dives are listed newest first, with dives from the plan's own
day at the top if the plan has a date.

You are asked to confirm before a link moves off another dive, or before a dive
gives up the plan it has. The plan that gives up the dive loses its link.

To remove a link, choose **Unlink plan** on the Compare page or **Unlink dive**
on the plan. You are asked first. The plan and the dive both stay.

## After a plan is linked

The Planned column reads the plan as it is saved now, so editing a linked plan
changes the comparison. A linked plan shows **Dived as #N** in the saved plans
list and in its menu so you know. If you want to keep a plan for next time,
duplicate it and edit the copy.

## What-ifs

On the Compare page you can branch the dive at any moment and change what
happened next: lose a tank, switch gas, ascend earlier or change gradient
factors. What-ifs always branch from the dive, never from the plan. Save one to
keep it as a chip on the dive.

Open a saved what-if from its column heading, or from the folder button on the
Compare page.

A dive needs a profile, and a mode other than gauge, to branch. A dive that
cannot branch still opens the Compare page if it has a linked plan; the what-if
controls are hidden and the page shows the plan against whatever the dive has.
