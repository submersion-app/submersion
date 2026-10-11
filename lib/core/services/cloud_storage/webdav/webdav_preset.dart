/// Server types the WebDAV settings offer. Each knows where its WebDAV
/// root lives, so the user enters a host instead of a DAV path.
enum WebDavPreset {
  nextcloud,
  owncloud,
  synology,
  koofr,
  pcloudUs,
  pcloudEu,
  fastmail,
  yandex,
  other;

  /// The DAV root of a hosted service, or null when the user supplies the
  /// server URL.
  String? get fixedRoot => switch (this) {
    koofr => 'https://app.koofr.net/dav/Koofr/',
    pcloudUs => 'https://webdav.pcloud.com/',
    pcloudEu => 'https://ewebdav.pcloud.com/',
    fastmail => 'https://myfiles.fastmail.com/',
    yandex => 'https://webdav.yandex.com/',
    nextcloud || owncloud || synology || other => null,
  };

  bool get needsServerUrl => fixedRoot == null;

  /// Files live under `remote.php/dav/files/<user>/`.
  bool get usesNextcloudLayout => this == nextcloud || this == owncloud;

  /// Nextcloud's chunked upload protocol (v2) is available.
  bool get supportsNextcloudChunking => this == nextcloud;

  /// The service issues app passwords and refuses the account password once
  /// two-factor sign-in is on.
  bool get recommendsAppPassword =>
      this == nextcloud ||
      this == owncloud ||
      this == koofr ||
      this == fastmail;

  /// The preset stored under [name], or [other] for a name this build does
  /// not know.
  static WebDavPreset fromName(String? name) =>
      WebDavPreset.values.asNameMap()[name] ?? WebDavPreset.other;
}
