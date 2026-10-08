# Campaign disposition log

Bug campaign 2026-07-31 — one line per Bug-type issue (43 total).

## Closed as fixed (9)

- #280: closed-fixed, commit 251840755c1 + reporter confirmation
- #737: closed-fixed, PR #770
- #358: closed-fixed, commits adf2fee/98b54b6/5b7ed90
- #680: closed-fixed, commit 3fe1b3a (#554 fix, shipped 1.7.0.117)
- #758: closed-fixed, PR #760 (embedded site edit + regression test)
- #648: closed-fixed, PRs #740/#743 (reporter retested pre-fix build)
- #57: closed-fixed, PRs #751/#754 (deco) + #390 (home counts, #217)
- #141: closed-fixed, planner rebuild #485-#491 + #739; 300+ planner tests green
- #154: closed-fixed, min_temperature identifier no longer exists anywhere in code

## Closed as stale/duplicate (3)

- #31: closed-stale (v1.3.x era; Perdix 2 retest succeeded; survivors tracked in #759)
- #39: closed-stale (v1.3.2 era)
- #148: closed-duplicate, folded into #153 (importer now links via divesiteid)

## Needs-info comments, left open (11)

- #543: needs-info (sample dive UDDF requested)
- #291: needs-info (debug logs requested; serial node IS present)
- #267: needs-info (debug logs re-requested)
- #146: needs-info (crash log requested)
- #147: needs-info (retest after PR #682 requested)
- #766: needs-info (pairing logs + stale-bond check requested)
- #425: needs-info (retest on 1.7.1.118 media store requested)
- #153: umbrella status comment posted, stays open
- #623: needs-info (Reddit thread unreachable by tooling; repro details requested)
- #732: needs-info/tracking (custom-PID FTDI needs libusb transport; findings posted)
- #123: needs-info (Suunto Ocean absent from descriptor DB even upstream; exact BLE
  name + test-build willingness requested; findings posted)

## DC investigation verdicts

- #759: PROVABLE — oldest-first patch aborts pass at oldest dive, zero delivered;
  promoted to Phase 1 (plan Task 28, fix/759-shearwater-partial-download);
  root-cause comment posted
- #723: NOT PROVABLE — all layers correct at fork HEAD 1a47a01; likely pre-support
  build; needs-info comment posted (version + 'Unmatched device' log line)

## Fix list (19) — Phase 1, one worktree + PR each

All 19 fix PRs open (each with a pre-fix-failing test unless noted):

- #757 buddy filter -> PR #773
- #736 save visibility -> PR #774
- #764 browse context -> PR #775 (amended to GoRouter.maybeOf)
- #647 settings back gesture -> PR #776
- #71 Shearwater UDDF gas mix -> PR #777 (already fixed by #404; test-only lock)
- #756 import duplicate linking -> PR #778
- #158 UDDF tank volume -> PR #779
- #190 MySSI CSV -> PR #780
- #644 PDF options + runtime -> PR #781
- #765 date entry format -> PR #782
- #222 tide time display -> PR #783 (+ follow-up comment re site timezone)
- #214 geocode locale pin -> PR #784 (+ comment re stored-rows backfill)
- #636 retired equipment -> PR #785
- #590 OSTC4 recognition -> PR #786 (native matcher; pre-fix failure proven)
- #218 Linux DB location -> PR #787
- #143 USBHID transport honesty -> PR #788 (4 platform impls; CI validates)
- #152 Transfer l10n -> PR #789 (8 keys x 11 locales)
- #110 segment SAC -> PR #790
- #759 Shearwater partial download -> PR #791 (fork branch
  fix/759-partial-download pushed to submersion-app/libdivecomputer first,
  pointer bumped; 3 new mock-transport cases verified failing pre-fix)

Known full-suite contention flakes seen during the campaign (each passes
standalone): media store fallback, sync backend switch/restore, backup
encryption, OCR scan page.

## Process note

flutter test piped to tail masks the exit code (pipe returns tail's status) —
verify by grepping "All tests passed" in output, or run with
`flutter test > log 2>&1; echo EXIT:$?`. Caught on #764 where 25
dive_detail_page tests failed silently.
