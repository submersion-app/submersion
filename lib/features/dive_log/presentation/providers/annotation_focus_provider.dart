import 'package:submersion/core/providers/provider.dart';

/// The annotation the profile should light up and open (#4109), set by the
/// Notes card when its link is tapped and cleared by the chart host once the
/// popup has opened.
final annotationFocusProvider = StateProvider.autoDispose
    .family<String?, String>((ref, diveId) => null);
