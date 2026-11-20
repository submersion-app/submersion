/// What kind of hardware a listed device is, as ONNX Runtime reports it.
enum OrtHardwareKind { cpu, gpu, npu }

/// One device ONNX Runtime lists (`GetEpDevices`): the engine that offers
/// it and the hardware under it.
class OrtEpDeviceInfo {
  const OrtEpDeviceInfo({
    required this.engine,
    required this.kind,
    required this.vendorId,
    required this.deviceId,
  });

  /// The execution provider's name, such as `DmlExecutionProvider`.
  final String engine;
  final OrtHardwareKind kind;
  final int vendorId;
  final int deviceId;

  @override
  String toString() =>
      '$engine on ${kind.name} '
      '${vendorId.toRadixString(16)}:${deviceId.toRadixString(16)}';
}

/// Windows' software renderer, the Microsoft Basic Render Driver: the only
/// graphics device of a PC without a usable display driver (a virtual
/// machine, a server). Handing it to an engine ends the process while the
/// session opens, with no error returned (findings,
/// docs/design/findings/2026-11-20-windows-ml-unpackaged.md).
bool isSoftwareRenderer(OrtEpDeviceInfo device) =>
    device.vendorId == 0x1414 && device.deviceId == 0x8c;

/// The devices a hardware session attaches, as indexes into [devices]:
/// those of one of [engines] (the engines registered from Windows ML's
/// catalogue), a GPU engine before an NPU one, never the software renderer.
/// The processor and DirectML are not chosen here: DirectML is attached by
/// name, which screens out software adapters itself, and the processor
/// needs no attaching. Empty when no such device is listed.
List<int> chooseHardwareDevices(
  List<OrtEpDeviceInfo> devices, {
  required Set<String> engines,
}) {
  final usable = [
    for (var i = 0; i < devices.length; i++)
      if (devices[i].engine.isNotEmpty &&
          engines.contains(devices[i].engine) &&
          devices[i].engine != 'CPUExecutionProvider' &&
          devices[i].engine != 'DmlExecutionProvider' &&
          devices[i].kind != OrtHardwareKind.cpu &&
          !isSoftwareRenderer(devices[i]))
        i,
  ];
  for (final kind in const [OrtHardwareKind.gpu, OrtHardwareKind.npu]) {
    final ofKind = [
      for (final i in usable)
        if (devices[i].kind == kind) i,
    ];
    if (ofKind.isEmpty) continue;
    final engine = devices[ofKind.first].engine;
    return [
      for (final i in ofKind)
        if (devices[i].engine == engine) i,
    ];
  }
  return const [];
}
