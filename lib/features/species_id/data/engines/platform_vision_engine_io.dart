import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Core ML on iPhone, iPad and Mac; ONNX Runtime everywhere else, which
/// reports itself unsupported where it does not run.
VisionEngine createPlatformVisionEngine() => coreMlRuns(defaultTargetPlatform)
    ? ChannelVisionEngine()
    : OnnxVisionEngine();
