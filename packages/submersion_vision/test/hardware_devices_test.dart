import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/src/ort/hardware_devices.dart';

/// Which devices a hardware session attaches (findings
/// docs/design/findings/2026-11-20-windows-ml-unpackaged.md): handing
/// Windows' software renderer to an engine ends the process, so it is
/// never chosen; the processor and DirectML are attached by other means.
void main() {
  // The engines the worker registered from Windows ML's catalogue.
  const registered = {
    'VendorExecutionProvider',
    'QNNExecutionProvider',
    'NvTensorRTRTXExecutionProvider',
    'AExecutionProvider',
    'BExecutionProvider',
    'CPUExecutionProvider',
    'DmlExecutionProvider',
  };

  OrtEpDeviceInfo device(
    String engine,
    OrtHardwareKind kind, {
    int vendorId = 0x10de,
    int deviceId = 0x2684,
  }) => OrtEpDeviceInfo(
    engine: engine,
    kind: kind,
    vendorId: vendorId,
    deviceId: deviceId,
  );

  test('the software renderer is never chosen, whichever engine offers it', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device(
          'VendorExecutionProvider',
          OrtHardwareKind.gpu,
          vendorId: 0x1414,
          deviceId: 0x8c,
        ),
      ]),
      isEmpty,
    );
  });

  test('the processor and DirectML are never chosen here', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device('CPUExecutionProvider', OrtHardwareKind.cpu),
        device('DmlExecutionProvider', OrtHardwareKind.gpu),
      ]),
      isEmpty,
    );
  });

  test('a GPU engine is chosen before an NPU engine', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device('CPUExecutionProvider', OrtHardwareKind.cpu),
        device('QNNExecutionProvider', OrtHardwareKind.npu),
        device('NvTensorRTRTXExecutionProvider', OrtHardwareKind.gpu),
      ]),
      [2],
    );
  });

  test('an NPU engine is chosen when no GPU engine is offered', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device('DmlExecutionProvider', OrtHardwareKind.gpu),
        device('QNNExecutionProvider', OrtHardwareKind.npu),
      ]),
      [1],
    );
  });

  test('only the first engine is chosen, with each of its devices of that '
      'kind', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device('AExecutionProvider', OrtHardwareKind.gpu),
        device('BExecutionProvider', OrtHardwareKind.gpu),
        device('AExecutionProvider', OrtHardwareKind.gpu, deviceId: 0x1),
        device('AExecutionProvider', OrtHardwareKind.npu),
      ]),
      [0, 2],
    );
  });

  test('the software renderer is skipped beside a real GPU', () {
    expect(
      chooseHardwareDevices(engines: registered, [
        device(
          'VendorExecutionProvider',
          OrtHardwareKind.gpu,
          vendorId: 0x1414,
          deviceId: 0x8c,
        ),
        device('VendorExecutionProvider', OrtHardwareKind.gpu),
      ]),
      [1],
    );
  });

  test('an engine Windows ML did not supply is never chosen', () {
    expect(
      chooseHardwareDevices(
        engines: const {'QNNExecutionProvider'},
        [
          device('WebGpuExecutionProvider', OrtHardwareKind.gpu),
          device('QNNExecutionProvider', OrtHardwareKind.npu),
        ],
      ),
      [1],
    );
  });

  test('a device whose engine has no name is never chosen', () {
    expect(
      chooseHardwareDevices(
        engines: const {''},
        [device('', OrtHardwareKind.gpu)],
      ),
      isEmpty,
    );
  });
}
