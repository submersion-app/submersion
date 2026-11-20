import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';

/// The least memory a Windows or Linux PC needs to run marine life
/// identification: 8 GB machines, with the same 6.5 GiB cut-off as iPhone. A
/// device reports a little less than it is sold with, and a 6 GB one can
/// never report more than 6 GiB.
const int pcMinimumMemoryBytes = 6979321856; // 6.5 GiB

/// The least memory an Android phone or tablet needs: 8 GB at launch, as on
/// iPhone, until a 6 GB phone (the maintainer's Pixel 6a) has been measured
/// (piece 3, section 5 of
/// docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md).
const int androidMinimumMemoryBytes = 6979321856; // 6.5 GiB

/// The device's memory, for the floor and the debug log's readout.
abstract interface class DeviceMemory {
  /// All the memory the device reports, or null when it cannot be read.
  Future<int?> totalBytes();

  /// The app's memory now.
  Future<VisionMemory> reading();
}

/// `MemTotal` of `/proc/meminfo`, in bytes.
int? parseMemTotal(String procMeminfo) => _kb(procMeminfo, 'MemTotal');

/// `MemAvailable` of `/proc/meminfo`, in bytes.
int? parseMemAvailable(String procMeminfo) => _kb(procMeminfo, 'MemAvailable');

/// The resident set (`VmRSS`) and its peak (`VmHWM`) of `/proc/self/status`,
/// in bytes.
({int? rss, int? hwm}) parseProcStatus(String procStatus) =>
    (rss: _kb(procStatus, 'VmRSS'), hwm: _kb(procStatus, 'VmHWM'));

int? _kb(String text, String key) {
  final match = RegExp(
    '^$key:\\s+(\\d+)\\s*kB',
    multiLine: true,
  ).firstMatch(text);
  final kb = match == null ? null : int.tryParse(match.group(1)!);
  return kb == null ? null : kb * 1024;
}

/// Android and Linux: `/proc`. On Android [systemState] (the frames
/// channel's device state) gives what the system can still free and whether
/// it reports itself low on memory.
class ProcDeviceMemory implements DeviceMemory {
  ProcDeviceMemory({
    Future<String> Function(String path)? read,
    Future<({bool lowMemory, int availableBytes})> Function()? systemState,
  }) : _read = read ?? ((path) => File(path).readAsString()),
       _systemState = systemState;

  final Future<String> Function(String path) _read;
  final Future<({bool lowMemory, int availableBytes})> Function()? _systemState;

  @override
  Future<int?> totalBytes() async {
    try {
      return parseMemTotal(await _read('/proc/meminfo'));
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<VisionMemory> reading() async {
    final status = parseProcStatus(await _read('/proc/self/status'));
    final system = await _systemState?.call();
    return VisionMemory(
      footprintBytes: status.rss ?? 0,
      footprintPeakBytes: status.hwm,
      availableBytes:
          system?.availableBytes ??
          parseMemAvailable(await _read('/proc/meminfo')),
      lowMemory: system?.lowMemory,
    );
  }
}

/// Windows: `GlobalMemoryStatusEx` and `K32GetProcessMemoryInfo`.
class WindowsDeviceMemory implements DeviceMemory {
  @override
  Future<int?> totalBytes() async => _withStatus((s) => s.ullTotalPhys);

  @override
  Future<VisionMemory> reading() async {
    final counters = calloc<_ProcessMemoryCounters>();
    try {
      counters.ref.cb = sizeOf<_ProcessMemoryCounters>();
      final ok = _getProcessMemoryInfo(
        _getCurrentProcess(),
        counters,
        sizeOf<_ProcessMemoryCounters>(),
      );
      return VisionMemory(
        footprintBytes: ok == 0 ? 0 : counters.ref.workingSetSize,
        footprintPeakBytes: ok == 0 ? null : counters.ref.peakWorkingSetSize,
        availableBytes: _withStatus((s) => s.ullAvailPhys),
      );
    } finally {
      calloc.free(counters);
    }
  }

  static int? _withStatus(int Function(_MemoryStatusEx status) read) {
    final status = calloc<_MemoryStatusEx>();
    try {
      status.ref.dwLength = sizeOf<_MemoryStatusEx>();
      return _globalMemoryStatusEx(status) == 0 ? null : read(status.ref);
    } finally {
      calloc.free(status);
    }
  }
}

final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;
  @Uint32()
  external int dwMemoryLoad;
  @Uint64()
  external int ullTotalPhys;
  @Uint64()
  external int ullAvailPhys;
  @Uint64()
  external int ullTotalPageFile;
  @Uint64()
  external int ullAvailPageFile;
  @Uint64()
  external int ullTotalVirtual;
  @Uint64()
  external int ullAvailVirtual;
  @Uint64()
  external int ullAvailExtendedVirtual;
}

final class _ProcessMemoryCounters extends Struct {
  @Uint32()
  external int cb;
  @Uint32()
  external int pageFaultCount;
  @Size()
  external int peakWorkingSetSize;
  @Size()
  external int workingSetSize;
  @Size()
  external int quotaPeakPagedPoolUsage;
  @Size()
  external int quotaPagedPoolUsage;
  @Size()
  external int quotaPeakNonPagedPoolUsage;
  @Size()
  external int quotaNonPagedPoolUsage;
  @Size()
  external int pagefileUsage;
  @Size()
  external int peakPagefileUsage;
}

DynamicLibrary get _kernel32 => DynamicLibrary.open('kernel32.dll');

final _globalMemoryStatusEx = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<_MemoryStatusEx>),
      int Function(Pointer<_MemoryStatusEx>)
    >('GlobalMemoryStatusEx');

final _getCurrentProcess = _kernel32
    .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
      'GetCurrentProcess',
    );

final _getProcessMemoryInfo = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<_ProcessMemoryCounters>, Uint32),
      int Function(Pointer<Void>, Pointer<_ProcessMemoryCounters>, int)
    >('K32GetProcessMemoryInfo');
