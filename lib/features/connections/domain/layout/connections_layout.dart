/// How the Graph view arranges its nodes. [web] and [radial] are the
/// original layouts (a force simulation, and the Around hub); the rest are
/// static arrangements computed in one pass.
enum ConnectionsLayout {
  web,
  radial,
  circle,
  columns,
  clusters,
  timeline;

  /// The layouts Map mode offers, its default first.
  static const List<ConnectionsLayout> forMap = [
    web,
    circle,
    columns,
    clusters,
    timeline,
  ];

  /// The layouts Around mode offers, its default first.
  static const List<ConnectionsLayout> forAround = [
    radial,
    circle,
    columns,
    clusters,
    timeline,
  ];

  static ConnectionsLayout? fromName(String? value) {
    for (final l in values) {
      if (l.name == value) return l;
    }
    return null;
  }
}
