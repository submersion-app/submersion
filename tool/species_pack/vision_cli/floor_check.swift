import Foundation

// Checks the memory floor for marine life identification on iPhone and
// iPad (MemoryFloor in MemoryReading.swift) against the devices it must
// let in and keep out. Devices report a little less memory than they are
// sold with: a 6 GB phone reports about 5.5 GiB and can never report more
// than 6 GiB, while an 8 GB one reports a little under 8 GiB. See
// docs/design/specs/2026-11-18-marine-life-release-gate-design.md.
//
// Assertions use precondition() (not assert(), which the optimizer can
// elide), so a failure aborts the run even when built with -O.

@main
struct FloorCheck {
  static let gib: Double = 1024 * 1024 * 1024

  static func bytes(_ gibibytes: Double) -> UInt64 {
    UInt64(gibibytes * gib)
  }

  static func eligible(_ gibibytes: Double) -> Bool {
    MemoryFloor.isEligible(physicalMemory: bytes(gibibytes))
  }

  static func main() {
    precondition(
      MemoryFloor.minimumMemoryBytes == 6_979_321_856,
      "the floor is 6.5 GiB")
    precondition(!eligible(5.5), "a 6 GB phone, as it reports, is kept out")
    precondition(!eligible(6.0), "the most a 6 GB device can report is kept out")
    precondition(eligible(6.5), "the floor itself is let in")
    precondition(eligible(7.0), "an 8 GB device with 1 GiB held back is let in")
    precondition(eligible(11.5), "a 12 GB phone is let in")
    print("memory floor: ok")
  }
}
