import Darwin
import Foundation

/// The app's memory as the system accounts for it, for the debug log's
/// readout during an iPhone memory test. One `task_info(TASK_VM_INFO)`
/// reading, in bytes. A key the running OS does not report is left out,
/// never sent as zero. Foundation and Darwin only, so a command-line tool
/// can compile it on its own.
enum MemoryReading {
  static func current() -> [String: Any] {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return [:] }
    var reading = reading(from: info, count: count)
    #if os(iOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
    // An iPhone or iPad always has a limit, so 0 here means none is left (or
    // the app is over it). The Simulator, Mac Catalyst and an iPhone build
    // running on a Mac have no limit and report 0 too, so they send nothing.
    if !ProcessInfo.processInfo.isiOSAppOnMac {
      reading["available"] = NSNumber(value: os_proc_available_memory())
    }
    #endif
    return reading
  }

  /// The figures [info] holds when the kernel filled [count] words of it.
  static func reading(from info: task_vm_info_data_t, count: mach_msg_type_number_t) -> [String: Any] {
    var reading: [String: Any] = [:]
    guard count >= rev1 else { return reading }
    reading["footprint"] = NSNumber(value: info.phys_footprint)
    guard count >= rev3 else { return reading }
    reading["footprintPeak"] = NSNumber(value: info.ledger_phys_footprint_peak)
    reading["neuralCounted"] = NSNumber(
      value: info.ledger_tag_neural_footprint + info.ledger_tag_neural_footprint_compressed)
    // iOS 15 to 17 and macOS 12 to 14 stop before revision 7: their
    // not-counted figure is the revision 3 pair, with no peak.
    reading["neuralNotCounted"] = NSNumber(
      value: info.ledger_tag_neural_nofootprint + info.ledger_tag_neural_nofootprint_compressed)
    guard count >= rev7 else { return reading }
    reading["neuralNotCounted"] = NSNumber(value: info.ledger_tag_neural_nofootprint_total)
    reading["neuralNotCountedPeak"] = NSNumber(value: info.ledger_tag_neural_nofootprint_peak)
    return reading
  }

  // The words a kernel must fill for each revision's fields, worked out from
  // where the revision's last field ends. A later revision appends fields,
  // so these never move (the header's TASK_VM_INFO_REVn_COUNT macros are not
  // importable into Swift).
  private static let rev1 = wordsThrough(\.phys_footprint)
  private static let rev3 = wordsThrough(\.ledger_tag_neural_nofootprint_compressed)
  private static let rev7 = wordsThrough(\.ledger_tag_neural_nofootprint_peak)

  private static func wordsThrough<T>(_ field: KeyPath<task_vm_info_data_t, T>) -> mach_msg_type_number_t {
    // A stored field of an imported C struct always has an offset.
    let offset = MemoryLayout<task_vm_info_data_t>.offset(of: field)!
    return mach_msg_type_number_t((offset + MemoryLayout<T>.size) / MemoryLayout<natural_t>.size)
  }
}

/// The least memory an iPhone or iPad needs to run marine life
/// identification. At launch the feature needs an 8 GB device
/// (docs/design/specs/2026-11-18-marine-life-release-gate-design.md): on an
/// iPhone 17 Pro Max iOS gave the app 3,376 MiB and identification peaked at
/// 2,432 MiB, and a 6 GB phone's limit is unmeasured. Devices report a
/// little less than they are sold with; a 6 GB device can never report more
/// than 6 GiB, and an 8 GB one reports a little under 8 GiB, so 6.5 GiB sits
/// between the two. Macs have no floor.
enum MemoryFloor {
  static let minimumMemoryBytes: UInt64 = 6_979_321_856  // 6.5 GiB

  static func isEligible(physicalMemory: UInt64) -> Bool {
    physicalMemory >= minimumMemoryBytes
  }
}
