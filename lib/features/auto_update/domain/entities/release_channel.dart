/// The user-selected update channel: stable releases only, or per-merge
/// beta builds. Distinct from [UpdateChannel], which is the compile-time
/// distribution channel (github/appstore/playstore/...).
enum ReleaseChannel {
  stable,
  beta;

  /// Parses a stored name, falling back to [stable] for null/unknown values
  /// so downgraded or corrupted preferences never strand a user on beta.
  static ReleaseChannel fromName(String? name) {
    for (final channel in ReleaseChannel.values) {
      if (channel.name == name) return channel;
    }
    return ReleaseChannel.stable;
  }
}
