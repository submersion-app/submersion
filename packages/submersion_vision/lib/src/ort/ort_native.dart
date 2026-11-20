import 'dart:ffi';

import 'package:submersion_vision/src/ort/ort_c_api.g.dart';

/// ONNX Runtime's one exported function, bound to the library the build hook
/// ships (`hook/build.dart`) under this file's asset id. Every other call
/// goes through the function table it returns.
@Native<Pointer<OrtApiBase> Function()>(symbol: 'OrtGetApiBase')
external Pointer<OrtApiBase> ortGetApiBaseFromAsset();
