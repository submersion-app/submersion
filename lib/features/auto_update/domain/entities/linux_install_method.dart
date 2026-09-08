/// How this Linux copy of Submersion was installed.
///
/// A packaged install is upgraded by the system package manager, so the in-app
/// updater must not offer a tarball that would shadow the packaged copy. The
/// marker file is written into the package by
/// scripts/release/stage_linux_package.py.
enum LinuxInstallMethod {
  /// Installed from a .deb; upgraded with apt.
  deb,

  /// Installed from an .rpm; upgraded with dnf.
  rpm,

  /// Unpacked from the tarball; upgraded by downloading a new tarball.
  tarball;

  /// Whether a system package manager owns this install.
  bool get isPackaged => this != LinuxInstallMethod.tarball;
}
