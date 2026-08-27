/// Submersion's own Adobe Lightroom "OAuth Native App" credential, bundled
/// so users connect by signing in with their Adobe account -- no Developer
/// Console setup. The client id is a public value (Native App credentials
/// carry no secret), so it is safe to embed. Adobe generates the redirect
/// scheme per credential. This credential is entitled for its owner and any
/// Adobe IDs allowlisted as Console "beta users" until Adobe grants partner
/// approval, after which it works for every user.
class LightroomEmbeddedCredential {
  const LightroomEmbeddedCredential._();

  static const String clientId = '00f3c953c816414db32d7ee98873040d';

  /// Adobe-generated redirect URI for this Native App credential.
  static const String redirectUri =
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d://adobeid/'
      '00f3c953c816414db32d7ee98873040d';

  /// The scheme part of [redirectUri]. Registered natively (iOS/Android/
  /// macOS) and handed to the in-app auth session as its callback scheme.
  static const String callbackScheme =
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d';
}
