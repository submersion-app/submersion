import 'package:submersion/core/providers/provider.dart';

/// The annotation the profile should light up and open (#4109), set by the
/// Notes card when its link is tapped and cleared by the chart host once the
/// popup has opened.
final annotationFocusProvider = StateProvider.autoDispose
    .family<String?, String>((ref, diveId) => null);

/// The annotation whose passage the Notes card draws highlighted (#4109),
/// set when the profile's popup opens it and cleared a moment later.
final annotationNotesHighlightProvider = StateProvider.autoDispose
    .family<String?, String>((ref, diveId) => null);
