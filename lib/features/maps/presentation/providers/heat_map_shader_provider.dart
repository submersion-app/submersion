import 'dart:ui' as ui;

import 'package:submersion/core/providers/provider.dart';

/// Loads and caches the compiled heat-map fragment program once.
///
/// `FutureProvider` keeps a single resolved [ui.FragmentProgram] for the app's
/// lifetime, so every `HeatMapLayer` reuses the same compiled program. On load
/// failure the AsyncValue surfaces the error and the layer renders nothing.
final heatMapShaderProgramProvider = FutureProvider<ui.FragmentProgram>((ref) {
  return ui.FragmentProgram.fromAsset('shaders/heatmap.frag');
});
