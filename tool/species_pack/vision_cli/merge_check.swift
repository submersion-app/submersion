// Checks the pipeline's merge of two detectors' boxes against the cases of
// tool/species_pack/boxes_test.py, whose merge the accuracy scorer measured.
// Built and run by check_merge.sh; exits 1 on any failure.
import Foundation

typealias Box = VisionPipeline.Box

func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ score: Float) -> Box {
  Box(x: x, y: y, w: w, h: h, score: score)
}

func check(_ name: String, _ got: [Box], _ want: [Box]) {
  let same = got.count == want.count && zip(got, want).allSatisfy { a, b in
    a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h && a.score == b.score
  }
  if same {
    print("ok   \(name)")
  } else {
    MergeCheck.failures += 1
    print("FAIL \(name): got \(got), want \(want)")
  }
}

func merge(_ runs: [[Box]], limit: Int = 8) -> [Box] {
  VisionPipeline.merge(runs, iou: 0.5, limit: limit)
}

@main
enum MergeCheck {
  static var failures = 0

  static func main() {
    let lowA = box(0.1, 0.1, 0.3, 0.3, 0.6)
    let highB = box(0.11, 0.1, 0.3, 0.3, 0.9)
    check("keeps the higher of two overlapping boxes", merge([[lowA], [highB]]), [highB])

    let farA = box(0.0, 0.0, 0.2, 0.2, 0.6)
    let farB = box(0.5, 0.5, 0.2, 0.2, 0.9)
    check("keeps both when they do not overlap, best first", merge([[farA], [farB]]), [farB, farA])

    let thirdB = box(0.1, 0.0, 0.2, 0.2, 0.9)
    check("overlap below the threshold keeps both", merge([[farA], [thirdB]]), [thirdB, farA])

    let run = (0..<10).map { i in box(Double(i) / 10, 0.0, 0.05, 0.05, Float(1 - Double(i) / 100)) }
    check("stops at the limit", merge([run]), Array(run.prefix(8)))

    let tieA = box(0.2, 0.2, 0.3, 0.3, 0.5)
    let tieB = box(0.21, 0.2, 0.3, 0.3, 0.5)
    check("equal scores keep the first detector's box", merge([[tieA], [tieB]]), [tieA])
    let tieP = box(0.0, 0.0, 0.1, 0.1, 0.7)
    let tieQ = box(0.6, 0.6, 0.1, 0.1, 0.7)
    check("equal scores keep pool order within a run", merge([[tieP, tieQ], []]), [tieP, tieQ])
    check("equal scores keep pool order, reversed", merge([[tieQ, tieP], []]), [tieQ, tieP])
    check("equal scores across runs keep run order", merge([[tieQ], [tieP]]), [tieQ, tieP])

    let only = [box(0.0, 0.0, 0.1, 0.1, 0.9), box(0.5, 0.5, 0.1, 0.1, 0.8)]
    check("one empty run returns the other's boxes", merge([[], only]), only)
    check("one empty run is still capped", merge([[], run], limit: 3), Array(run.prefix(3)))
    // As boxes.py does: the surviving run's own overlapping boxes are merged
    // too, where a one-detector pack would keep both.
    let overlapA = box(0.1, 0.1, 0.3, 0.3, 0.9)
    let overlapB = box(0.12, 0.1, 0.3, 0.3, 0.8)
    check("one empty run still merges its own overlapping boxes", merge([[overlapA, overlapB], []]), [overlapA])

    let whole = box(0.0, 0.0, 1.0, 1.0, 0.9)
    let half = box(0.0, 0.0, 0.5, 1.0, 0.4)
    let under = box(0.0, 0.0, 0.49, 1.0, 0.4)
    check("an overlap of exactly the threshold is dropped", merge([[whole], [half]]), [whole])
    check("an overlap just under the threshold is kept", merge([[whole], [under]]), [whole, under])

    check("nothing from either detector is nothing", merge([[], []]), [])
    exit(failures == 0 ? 0 : 1)
  }
}
