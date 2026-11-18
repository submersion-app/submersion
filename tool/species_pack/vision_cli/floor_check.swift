import Foundation

// Checks the memory floor for marine life identification on iPhone and
// iPad (MemoryFloor in MemoryReading.swift) against the devices it must
// let in and keep out. Devices report a little less memory than they are
// sold with: a 6 GB phone reports about 5.5 GiB and can never report more
// than 6 GiB, while an 8 GB one reports a little under 8 GiB. See
// docs/design/specs/2026-11-18-marine-life-release-gate-design.md.
//
// Each case prints `ok` or `FAIL` with its name, and any failure exits 1, so
// the CI log names the case (a trapped precondition built with -O prints
// nothing).

@main
struct FloorCheck {
  static let gib: Double = 1024 * 1024 * 1024
  static var failures = 0

  static func bytes(_ gibibytes: Double) -> UInt64 {
    UInt64(gibibytes * gib)
  }

  static func check(_ name: String, _ condition: Bool) {
    if condition {
      print("ok   \(name)")
    } else {
      print("FAIL \(name)")
      failures += 1
    }
  }

  static func eligible(_ gibibytes: Double) -> Bool {
    MemoryFloor.isEligible(physicalMemory: bytes(gibibytes))
  }

  static func main() {
    check("the floor is 6.5 GiB", MemoryFloor.minimumMemoryBytes == 6_979_321_856)
    check("a 6 GB phone, as it reports, is kept out", !eligible(5.5))
    check("the most a 6 GB device can report is kept out", !eligible(6.0))
    check("the floor itself is let in", eligible(6.5))
    check("an 8 GB device with 1 GiB held back is let in", eligible(7.0))
    check("a 12 GB phone is let in", eligible(11.5))
    if failures > 0 {
      print("memory floor: \(failures) failed")
      exit(1)
    }
    print("memory floor: ok")
  }
}
