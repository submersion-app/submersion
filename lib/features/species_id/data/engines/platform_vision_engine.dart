/// The vision engine for the running platform. The ONNX engine imports
/// `dart:ffi` and isolates, so the web build reaches only the Core ML
/// channel engine, which reports itself unsupported there.
library;

export 'platform_vision_engine_io.dart'
    if (dart.library.js_interop) 'platform_vision_engine_web.dart';
