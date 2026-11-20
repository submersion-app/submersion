/// ONNX Runtime through its C API, for the marine life engine on Android,
/// Windows and Linux. Imports `dart:ffi`: never import it from code the web
/// build reaches.
library;

export 'src/ort/ort_runtime.dart'
    show
        OrtDevice,
        OrtException,
        OrtModelSession,
        OrtRuntime,
        OrtSessionSettings,
        OrtTensor,
        ortLibraryLoads;
