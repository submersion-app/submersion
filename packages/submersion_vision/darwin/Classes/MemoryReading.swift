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
    // TASK_VM_INFO_COUNT and its REVn counterparts are macros Swift cannot
    // import, so they are worked out here the way the header defines them.
    let rev7 = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let rev3 = rev7 - 4 - 2 - 1 - 2
    var count = rev7
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return [:] }

    var reading: [String: Any] = ["footprint": NSNumber(value: info.phys_footprint)]
    if count >= rev3 {
      reading["footprintPeak"] = NSNumber(value: info.ledger_phys_footprint_peak)
      reading["neuralCounted"] = NSNumber(value: info.ledger_tag_neural_footprint)
    }
    if count >= rev7 {
      reading["neuralNotCounted"] = NSNumber(value: info.ledger_tag_neural_nofootprint_total)
      reading["neuralNotCountedPeak"] = NSNumber(value: info.ledger_tag_neural_nofootprint_peak)
    }
    #if os(iOS)
    // 0 means the process has no limit (the Simulator), not that none is
    // left: a process with nothing left has already been stopped.
    let available = os_proc_available_memory()
    if available > 0 {
      reading["available"] = NSNumber(value: available)
    }
    #endif
    return reading
  }
}
