// Generates lib/src/ort/ort_c_api.g.dart from ONNX Runtime's C header
// (third_party/onnxruntime, version 1.28). Run it again whenever that
// header is replaced, from this folder (a package of its own, so the plugin
// never depends on ffigen):
//
//   cd tool/ffigen && dart pub get && dart run ffigen_ort.dart
//
// Only the API table and the enums the engine uses are generated;
// OrtGetApiBase, the library's one exported function, is declared by hand
// in lib/src/ort/ort_native.dart.
import 'dart:io';

import 'package:ffigen/ffigen.dart';

const _structs = {'OrtApiBase', 'OrtApi'};
const _enums = {
  'ONNXTensorElementDataType',
  'OrtLoggingLevel',
  'GraphOptimizationLevel',
  'OrtErrorCode',
  'OrtAllocatorType',
  'OrtMemType',
  'OrtExecutionProviderDevicePolicy',
};

Future<void> main() async {
  final root = Platform.script.resolve('../../');
  final header = root.resolve('third_party/onnxruntime/onnxruntime_c_api.h');
  await FfiGenerator(
    output: Output(
      dart: DartOutput(path: root.resolve('lib/src/ort/ort_c_api.g.dart')),
    ),
    input: Input(
      entryPoints: [header],
      compilerOptions: [
        '-I${root.resolve('third_party/onnxruntime/').toFilePath()}',
      ],
      appendCompilerOptions: true,
    ),
    visitors: [
      Visitor(
        struct: (node) {
          if (_structs.contains(node.originalName)) node.isIncluded = true;
        },
        enumClass: (node) {
          if (_enums.contains(node.originalName)) node.isIncluded = true;
        },
      ),
    ],
  ).generate(
    libclangDylib: Platform.isMacOS
        ? Uri.file('/Library/Developer/CommandLineTools/usr/lib/libclang.dylib')
        : null,
  );
}
