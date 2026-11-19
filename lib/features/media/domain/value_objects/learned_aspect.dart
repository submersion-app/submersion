/// A displayed aspect ratio (width / height) learned from a decoded
/// thumbnail, and the stored size it was learned against (issue #4738).
typedef LearnedAspect = ({double ratio, int? width, int? height});
