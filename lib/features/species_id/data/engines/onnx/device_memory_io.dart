import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:submersion/features/species_id/data/engines/onnx/device_memory.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';

/// The device facts the ONNX engine reads through FFI, kept apart so that
/// only this native file imports `dart:ffi` (the engine is reached through
/// the `platform_vision_engine` conditional export, never on the web).

/// Whether this process is 64-bit: the ONNX engine runs only there.
bool processIs64Bit() => sizeOf<IntPtr>() == 8;

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
        availableIsDeviceWide: true,
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
