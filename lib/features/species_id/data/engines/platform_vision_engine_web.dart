import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// The web has no engine: the channel engine reports
/// `unsupportedPlatform` there.
VisionEngine createPlatformVisionEngine() => ChannelVisionEngine();
