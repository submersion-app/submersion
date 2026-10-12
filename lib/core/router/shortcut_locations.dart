/// Where nav shortcuts live (#2936).
///
/// A shortcut is a nav destination for a page that normally sits below a
/// top-level section, such as the Trimix blender under Planning > Gas
/// calculators. Its alias route has no parent route, so go_router builds the
/// page as a one-page stack and it behaves as a top-level destination.
library;

/// Path prefix of every shortcut's alias route.
const String kShortcutLocationPrefix = '/shortcut';

/// The alias location for the catalog shortcut [id].
String shortcutLocation(String id) => '$kShortcutLocationPrefix/$id';
