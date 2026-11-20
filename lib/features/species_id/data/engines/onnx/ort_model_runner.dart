import 'dart:typed_data';

import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';

/// An ONNX Runtime session as the pipeline's [ModelRunner].
class OrtModelRunner implements LoadedModel {
  OrtModelRunner(this._session);

  final OrtModelSession _session;

  @override
  String get device => _session.device;

  @override
  List<ModelOutput> run(Float32List input, List<int> shape) => [
    for (final output in _session.run(OrtTensor(shape, input)))
      ModelOutput(output.shape, output.data),
  ];

  @override
  void close() => _session.close();
}
