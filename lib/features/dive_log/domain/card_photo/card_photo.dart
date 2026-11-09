import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';

/// A photo that can stand behind a dive card: the media row's id and the
/// boxes of any people tagged on it.
///
/// [focusBoxes] are normalised 0 to 1 against the full image, as the people
/// tags store them. They are the strongest hint of where the subject is.
class CardPhoto extends Equatable {
  const CardPhoto({required this.mediaId, this.focusBoxes = const []});

  final String mediaId;
  final List<FocusBox> focusBoxes;

  CardPhoto copyWith({String? mediaId, List<FocusBox>? focusBoxes}) =>
      CardPhoto(
        mediaId: mediaId ?? this.mediaId,
        focusBoxes: focusBoxes ?? this.focusBoxes,
      );

  @override
  List<Object?> get props => [mediaId, focusBoxes];
}
